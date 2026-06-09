local Settings = lib.load('shared.settings')

RegisterNetEvent('LNS_Housing:server:updatePermissions', function(propertyId, permissions)
    local src = source
    local p = Properties[propertyId]
    if not p or p.owner ~= GetIdentifier(src) then return end

    p.permissions = permissions
    SaveProperty(propertyId)
    SyncPropertyDoor(propertyId)
end)

RegisterNetEvent('LNS_Housing:server:updateWallColor', function(propertyId, color)
    local src = source
    local p = Properties[propertyId]
    if not p or p.owner ~= GetIdentifier(src) then return end

    p.metadata.wall_color = color
    SaveProperty(propertyId)
end)

RegisterNetEvent('LNS_Housing:server:upgradeSecurity', function(propertyId, upgradeId)
    local src = source
    local p = Properties[propertyId]
    if not p then return end

    local identifier = GetIdentifier(src)
    if p.owner ~= identifier then return end

    local currentLevel = p.metadata.security_level or 0
    if currentLevel >= Settings.Security.MaxLevel then
        Bridge.Server.Notify(src, 'Security is already at maximum level!', 'error')
        return
    end

    local nextLevel = currentLevel + 1
    local price = 10000 * nextLevel

    if Bridge.Server.GetBankMoney(src) >= price then
        Bridge.Server.RemoveBankMoney(src, price, "Security Upgrade: " .. p.label)
        p.metadata.security_level = nextLevel
        SaveProperty(propertyId)
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Bridge.Server.Notify(src, 'Security upgraded to level ' .. nextLevel, 'success')
    else
        Bridge.Server.Notify(src, 'Not enough money in bank!', 'error')
    end
end)

RegisterNetEvent('LNS_Housing:server:payRent', function(propertyId)
    local src = source
    local p = Properties[propertyId]
    if not p or p.sale_type ~= 'rent' then return end

    local cid = GetIdentifier(src)
    if p.owner ~= cid then return end

    local rentAmount = p.metadata.rent_amount or p.price or 1000
    local money = Bridge.Server.GetBankMoney(src)

    if money >= rentAmount then
        Bridge.Server.RemoveBankMoney(src, rentAmount, "Paid Rent for: " .. p.label)

        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(rentAmount * (commissionRate / 100))
        local remainder = rentAmount - commission

        if p.agent_cid then
            local agent = Bridge.Server.IsPlayerOnline(p.agent_cid)
            if agent then
                Bridge.Server.AddBankMoney(agent.PlayerData.source, commission, "Property Rent Commission: " .. p.label)
                Bridge.Server.Notify(agent.PlayerData.source, string.format("You received $%s rent commission for %s!", commission, p.label), "success")
            else
                Bridge.Server.AddOfflineBankMoney(p.agent_cid, commission)
            end
        end

        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[p.agency]
        local societyName = agencyConfig and agencyConfig.society or p.agency
        Bridge.Server.AddSocietyMoney(societyName, remainder)

        p.metadata.last_rent_paid = os.time()
        SaveProperty(propertyId)

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Bridge.Server.Notify(src, string.format("You successfully paid $%s rent for %s.", rentAmount, p.label), "success")
    else
        Bridge.Server.Notify(src, "Not enough money in bank to pay rent!", "error")
    end
end)

lib.callback.register('LNS_Housing:server:getPendingContracts', function(source)
    local cid = GetIdentifier(source)
    local results = MySQL.query.await([[
        SELECT c.*, p.label as property_label, p.image as property_image
        FROM housing_contracts c
        JOIN housing_properties p ON c.property_id = p.id
        WHERE c.client_cid = ? AND c.status = 'pending'
    ]], {cid})
    return results or {}
end)

lib.callback.register('LNS_Housing:server:getAgencyContracts', function(source, agencyName)
    local results = MySQL.query.await([[
        SELECT c.*, p.label as property_label, p.image as property_image
        FROM housing_contracts c
        JOIN housing_properties p ON c.property_id = p.id
        WHERE c.agency = ?
        ORDER BY c.created_at DESC
        LIMIT 50
    ]], {agencyName})
    return results or {}
end)

lib.callback.register('LNS_Housing:server:resolvePlayerNames', function(source, playerIds)
    local results = {}
    for _, sid in ipairs(playerIds) do
        local name = Bridge.Server.GetPlayerName(sid)
        table.insert(results, { id = sid, name = name })
    end
    return results
end)

RegisterNetEvent('LNS_Housing:server:createContract', function(data)
    local src = source
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob then return end

    local permConfig = Settings.RealEstate.Permissions or { DraftContract = 1 }
    if playerJob.grade < (permConfig.DraftContract or 1) then
        Bridge.Server.Notify(src, "You do not have permission to draft contracts.", "error")
        return
    end

    local propertyId = tonumber(data.propertyId)
    local targetId = tonumber(data.targetId)
    local price = tonumber(data.price)
    local contractType = data.type or 'buy'
    local commissionRate = tonumber(data.commissionRate) or 10

    local p = Properties[propertyId]
    if not p or p.owner then
        Bridge.Server.Notify(src, "Property is not available or already owned.", "error")
        return
    end

    local clientCid = GetIdentifier(targetId)
    if not clientCid then
        Bridge.Server.Notify(src, "Invalid target player.", "error")
        return
    end

    local clientName = Bridge.Server.GetPlayerName(targetId)
    local agentCid = GetIdentifier(src)
    local agentName = Bridge.Server.GetPlayerName(src)

    local contractId = MySQL.insert.await([[
        INSERT INTO housing_contracts
        (property_id, client_cid, client_name, agent_cid, agent_name, agency, price, type, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    ]], {
        propertyId, clientCid, clientName, agentCid, agentName, playerJob.name, price, contractType
    })

    if contractId then
        p.agency = playerJob.name
        p.agent_cid = agentCid
        p.commission_rate = commissionRate
        SaveProperty(propertyId)

        Bridge.Server.Notify(src, "Contract sent to " .. clientName .. "!", "success")
        Bridge.Server.Notify(targetId, "You received a new real estate contract! Use /contracts to view.", "inform")

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    else
        Bridge.Server.Notify(src, "Failed to create contract.", "error")
    end
end)

lib.callback.register('LNS_Housing:server:respondToContract', function(source, contractId, action)
    local src = source
    local clientCid = GetIdentifier(src)

    local contracts = MySQL.query.await('SELECT * FROM housing_contracts WHERE id = ? AND client_cid = ? AND status = ?', {contractId, clientCid, 'pending'})
    if not contracts or not contracts[1] then return false end
    local contract = contracts[1]

    local propertyId = contract.property_id
    local p = Properties[propertyId]
    if not p or p.owner then return false end

    if action == 'decline' then
        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE id = ?', {'declined', contractId})
        local agent = Bridge.Server.IsPlayerOnline(contract.agent_cid)
        if agent then
            Bridge.Server.Notify(agent.PlayerData.source, contract.client_name .. " declined your contract for " .. p.label .. ".", "error")
        end
        return true
    elseif action == 'accept' then
        local price = contract.price
        local bankMoney = Bridge.Server.GetBankMoney(src)

        if bankMoney < price then
            Bridge.Server.Notify(src, "You do not have enough money in your bank account.", "error")
            return false
        end

        Bridge.Server.RemoveBankMoney(src, price, "Accepted Real Estate Contract: " .. p.label)

        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(price * (commissionRate / 100))
        local remainder = price - commission

        local agent = Bridge.Server.IsPlayerOnline(contract.agent_cid)
        if agent then
            local agentSrc = agent.PlayerData.source
            Bridge.Server.AddBankMoney(agentSrc, commission, "Property Payout Commission: " .. p.label)
            Bridge.Server.Notify(agentSrc, string.format("You received $%s commission for the sale of %s!", commission, p.label), "success")
        else
            Bridge.Server.AddOfflineBankMoney(contract.agent_cid, commission)
        end

        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[contract.agency]
        local societyName = agencyConfig and agencyConfig.society or contract.agency
        Bridge.Server.AddSocietyMoney(societyName, remainder)

        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE id = ?', {'accepted', contractId})
        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND id != ? AND status = ?', {'declined', propertyId, contractId, 'pending'})

        if contract.type == 'rent' then
            p.owner = clientCid
            p.sale_type = 'rent'
            p.price = price
            p.metadata.last_rent_paid = os.time()
            p.metadata.rent_amount = price
        else
            p.owner = clientCid
            p.sale_type = 'direct'
        end

        SaveProperty(propertyId)
        SyncPropertyDoor(propertyId)

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Bridge.Server.Notify(src, "Congratulations! You accepted the contract and now have access to " .. p.label .. ".", "success")
        return true
    end

    return false
end)

lib.callback.register('LNS_Housing:server:updateListingDetails', function(source, data)
    local jobPerm = GetRealEstatePermission(source)
    if not jobPerm or not jobPerm.permissions.manageListings then return false end

    local propertyId = tonumber(data.id)
    local p = Properties[propertyId]
    if not p then return false end

    p.label = data.label or p.label
    p.price = tonumber(data.price) or p.price
    p.sale_type = data.sale_type or p.sale_type
    p.image = data.image
    p.zone_data = data.zone_data or p.zone_data
    p.yard_zone_data = data.yard_zone_data or p.yard_zone_data

    if not p.metadata then p.metadata = {} end
    p.metadata.shell = data.mlo and 'mlo' or (data.shell or p.metadata.shell or 'Standard Motel')
    p.metadata.allow_wall_colors = data.allowWallColors or false

    if data.entranceType == 'coords' then
        p.metadata.entrance = data.entranceCoords
        if p.metadata.locked == nil then
            p.metadata.locked = true
        end
        p.doors = {}
        if data.entranceCoords then
            p.metadata.spawn = {
                x = data.entranceCoords.x,
                y = data.entranceCoords.y,
                z = data.entranceCoords.z,
                h = data.entranceCoords.h or 0.0
            }
        end
    else
        p.metadata.entrance = nil
        p.doors = data.doors or p.doors
    end

    if p.sale_type == 'auction' then
        if not p.auction_data then
            p.auction_data = { current_bid = p.price, highest_bidder = nil, status = 'paused' }
        else
            p.auction_data.current_bid = tonumber(data.price) or p.auction_data.current_bid or p.price
        end
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

lib.callback.register('LNS_Housing:server:deleteListing', function(source, propertyId)
    local jobPerm = GetRealEstatePermission(source)
    if not jobPerm or not jobPerm.permissions.manageListings then return false end

    local id = tonumber(propertyId)
    if not Properties[id] then return false end

    MySQL.update.await('DELETE FROM housing_properties WHERE id = ?', { id })
    Properties[id] = nil

    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

lib.callback.register('LNS_Housing:server:evictTenant', function(source, propertyId)
    local jobPerm = GetRealEstatePermission(source)
    if not jobPerm or not jobPerm.permissions.manageListings then return false end

    local id = tonumber(propertyId)
    local p = Properties[id]
    if not p or not p.owner then return false end

    p.owner = nil
    if p.sale_type == 'rent' then
        p.sale_type = 'direct'
        p.metadata.last_rent_paid = nil
        p.metadata.rent_amount = nil
    end

    SaveProperty(id)
    SyncPropertyDoor(id)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

lib.callback.register('LNS_Housing:server:terminateOwnLease', function(source, propertyId)
    local id = tonumber(propertyId)
    local p = Properties[id]
    if not p or not p.owner or p.sale_type ~= 'rent' then return false end

    local cid = GetIdentifier(source)
    if p.owner ~= cid then return false end

    p.owner = nil
    p.sale_type = 'direct'
    p.metadata.last_rent_paid = nil
    p.metadata.rent_amount = nil

    SaveProperty(id)
    SyncPropertyDoor(id)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

lib.callback.register('LNS_Housing:server:updateSpawnPoint', function(source, propertyId, spawnCoords)
    local src = source
    local p = Properties[propertyId]
    if not p then return false end

    local identifier = GetIdentifier(src)
    local hasAccess = p.owner == identifier
    if not hasAccess and p.permissions and p.permissions.manage then
        for _, cid in ipairs(p.permissions.manage) do
            if cid == identifier then
                hasAccess = true
                break
            end
        end
    end

    if not hasAccess then
        return false
    end

    if not p.metadata then p.metadata = {} end
    p.metadata.spawn = {
        x = spawnCoords.x,
        y = spawnCoords.y,
        z = spawnCoords.z,
        h = spawnCoords.w
    }

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)
