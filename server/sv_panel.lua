local Settings = lib.load('shared.settings')

if Settings.RealEstate.Item and Settings.RealEstate.Item.Enabled and Settings.RealEstate.Item.Name then
    Bridge.Server.CreateUseableItem(Settings.RealEstate.Item.Name, function(source)
        TriggerClientEvent('LNS_Housing:client:openRealEstateFromItem', source)
    end)
end

RegisterNetEvent('LNS_Housing:server:updatePermissions', function(propertyId, permissions)
    local src = source
    debugPrint('info', 'LNS_Housing:server:updatePermissions received', {src = src, propertyId = propertyId, permissions = permissions})
    local p = Properties[propertyId]
    local ownerCid = Bridge.Server.GetIdentifier(src)
    if not p or p.owner ~= ownerCid then return end

    -- Ensure owner cannot add themselves into sub-permission tables
    if type(permissions) == 'table' then
        for category, cids in pairs(permissions) do
            if type(cids) == 'table' then
                local filtered = {}
                for _, cid in ipairs(cids) do
                    if cid ~= ownerCid then
                        table.insert(filtered, cid)
                    end
                end
                permissions[category] = filtered
            end
        end
    end

    p.permissions = permissions
    SaveProperty(propertyId)
    SyncPropertyDoor(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    -- Bug 2 fix: notify sd-phone on every connected player to refresh their homes list.
    -- This ensures a keyholder removed via the LNS_Housing panel UI immediately loses
    -- the property from their phone without requiring sd-phone to track the old list.
    if GetResourceState('sd-phone') == 'started' then
        TriggerClientEvent('sd-phone:client:homes:refresh', -1)
    end
end)

RegisterNetEvent('LNS_Housing:server:updateWallColor', function(propertyId, color)
    local src = source
    debugPrint('info', 'LNS_Housing:server:updateWallColor received', {src = src, propertyId = propertyId, color = color})
    local p = Properties[propertyId]
    if not p or p.owner ~= Bridge.Server.GetIdentifier(src) then return end

    p.metadata.wall_color = color
    SaveProperty(propertyId)
end)

RegisterNetEvent('LNS_Housing:server:payRent', function(propertyId, payAmount)
    local src = source
    debugPrint('info', 'LNS_Housing:server:payRent received', {src = src, propertyId = propertyId, payAmount = payAmount})
    local id = tonumber(propertyId)
    local p = Properties[id]
    
    if not p then return end
    
    if p.sale_type ~= 'rent' then return end

    local cid = Bridge.Server.GetIdentifier(src)
    if p.owner ~= cid then return end

    if not p.metadata then p.metadata = {} end
    if p.metadata.rent_debt == nil then p.metadata.rent_debt = 0 end
    if p.metadata.missed_payments == nil then p.metadata.missed_payments = 0 end
    if p.metadata.partial_payment == nil then p.metadata.partial_payment = 0 end

    local rentAmount = p.metadata.rent_amount or p.price or 1000
    local currentDebt = p.metadata.rent_debt or 0
    
    local defaultPay = currentDebt > 0 and currentDebt or rentAmount
    payAmount = tonumber(payAmount) or defaultPay
    if payAmount <= 0 then return end

    local money = Bridge.Server.GetBankMoney(src)
    if money < payAmount then
        Bridge.Server.Notify(src, "Not enough money in bank to pay rent!", "error")
        return
    end

    if Bridge.Server.RemoveBankMoney(src, payAmount, "Paid Rent for: " .. p.label) then
        local originalPayAmount = payAmount
        
        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(originalPayAmount * (commissionRate / 100))
        local remainder = originalPayAmount - commission

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

        if currentDebt > 0 then
            local debtPaid = math.min(payAmount, currentDebt)
            p.metadata.rent_debt = currentDebt - debtPaid
            payAmount = payAmount - debtPaid
            
            if p.metadata.rent_debt <= 0 then
                p.metadata.rent_debt = 0
                p.metadata.missed_payments = 0
                p.metadata.due_by = nil
                SyncPropertyDoor(id)
            end
        end

        if payAmount > 0 then
            local rentPeriod = Settings.Rent and Settings.Rent.RentPeriod or 604800
            p.metadata.partial_payment = (p.metadata.partial_payment or 0) + payAmount
            
            while p.metadata.partial_payment >= rentAmount do
                p.metadata.partial_payment = p.metadata.partial_payment - rentAmount
                p.metadata.last_rent_paid = (p.metadata.last_rent_paid or os.time()) + rentPeriod
            end
        end

        p.metadata.rent_history = p.metadata.rent_history or {}
        table.insert(p.metadata.rent_history, 1, {
            id = math.random(10000, 99999),
            date = os.date("%d/%m/%Y"),
            type = "Rent Payment",
            amount = originalPayAmount,
            status = "Paid"
        })

        SaveProperty(id)
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Bridge.Server.Notify(src, string.format("Successfully paid $%s for %s.", originalPayAmount, p.label), "success")
    end
end)

lib.callback.register('LNS_Housing:server:getPendingContracts', function(source)
    debugPrint('info', 'LNS_Housing:server:getPendingContracts called', {source = source})
    local cid = Bridge.Server.GetIdentifier(source)
    local results = MySQL.query.await([[
        SELECT c.*, p.label as property_label, p.image as property_image, p.garage as garage, p.metadata as property_metadata
        FROM housing_contracts c
        JOIN housing_properties p ON c.property_id = p.id
        WHERE c.client_cid = ? AND c.status = 'pending'
    ]], {cid})
    return results or {}
end)

lib.callback.register('LNS_Housing:server:getAgencyContracts', function(source, agencyName)
    debugPrint('info', 'LNS_Housing:server:getAgencyContracts called', {source = source, agencyName = agencyName})
    local results = MySQL.query.await([[
        SELECT c.*, p.label as property_label, p.image as property_image, p.garage as garage, p.metadata as property_metadata
        FROM housing_contracts c
        JOIN housing_properties p ON c.property_id = p.id
        WHERE c.agency = ?
        ORDER BY c.created_at DESC
        LIMIT 50
    ]], {agencyName})
    return results or {}
end)

lib.callback.register('LNS_Housing:server:resolvePlayerNames', function(source, playerIds)
    debugPrint('info', 'LNS_Housing:server:resolvePlayerNames called', {source = source, playerIds = playerIds})
    local results = {}
    for _, sid in ipairs(playerIds) do
        local name = Bridge.Server.GetPlayerName(sid)
        local cid = Bridge.Server.GetIdentifier(sid)
        table.insert(results, { id = sid, name = name, citizenid = cid })
    end
    return results
end)

--- Resolve a list of citizenids to { citizenid, name } records for the panel's keyholder display.
--- Prefers online player names; falls back to the framework DB for offline residents.
lib.callback.register('LNS_Housing:server:resolveIdentifiers', function(source, citizenids)
    debugPrint('info', 'LNS_Housing:server:resolveIdentifiers called', {source = source, citizenids = citizenids})
    if type(citizenids) ~= 'table' then return {} end

    -- Build a cid → source map for all online players once.
    local onlineMap = {}
    for _, srcStr in ipairs(GetPlayers()) do
        local sid = tonumber(srcStr)
        if sid then
            local cid = Bridge.Server.GetIdentifier(sid)
            if cid then onlineMap[cid] = sid end
        end
    end

    local results = {}
    for _, cid in ipairs(citizenids) do
        cid = tostring(cid)
        local name = nil

        -- Online fast-path.
        local sid = onlineMap[cid]
        if sid then
            name = Bridge.Server.GetPlayerName(sid)
        end

        -- Offline DB fallback.
        if not name or name == 'Unknown' then
            if Bridge.Framework == 'esx' then
                local ok, rows = pcall(MySQL.query.await, 'SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', { cid })
                if ok and rows and rows[1] then
                    local first = rows[1].firstname or ''
                    local last  = rows[1].lastname or ''
                    if first ~= '' or last ~= '' then name = first .. ' ' .. last end
                end
            else
                local ok, rows = pcall(MySQL.query.await, 'SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { cid })
                if ok and rows and rows[1] then
                    local ci = rows[1].charinfo
                    if type(ci) == 'string' then
                        local decoded = json.decode(ci)
                        if decoded then
                            local first = decoded.firstname or ''
                            local last  = decoded.lastname or ''
                            if first ~= '' or last ~= '' then name = first .. ' ' .. last end
                        end
                    end
                end
            end
        end

        table.insert(results, { citizenid = cid, name = name or cid })
    end
    return results
end)

lib.callback.register('LNS_Housing:server:resolvePlayerByServerId', function(source, targetId)
    debugPrint('info', 'LNS_Housing:server:resolvePlayerByServerId called', {source = source, targetId = targetId})
    local sid = tonumber(targetId)
    if not sid then
        return { success = false, message = "Invalid Server ID." }
    end

    if sid == source then
        return { success = false, message = "You cannot add yourself as a resident." }
    end

    local ped = GetPlayerPed(sid)
    if not ped or ped == 0 then
        return { success = false, message = "Player is offline or server ID is invalid." }
    end

    local cid = Bridge.Server.GetIdentifier(sid)
    if not cid then
        return { success = false, message = "Could not resolve player identifier." }
    end

    local sourceCid = Bridge.Server.GetIdentifier(source)
    if cid == sourceCid then
        return { success = false, message = "You cannot add yourself as a resident." }
    end

    local name = Bridge.Server.GetPlayerName(sid) or cid
    return { success = true, citizenid = cid, name = name, serverId = sid }
end)


RegisterNetEvent('LNS_Housing:server:createContract', function(data)
    local src = source
    debugPrint('info', 'LNS_Housing:server:createContract received', {src = src, data = data})
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob then return end

    local permConfig = Settings.RealEstate.Permissions or { DraftContract = 1 }
    if playerJob.grade < (permConfig.DraftContract or 1) then
        Bridge.Server.Notify(src, "You do not have permission to draft contracts.", "error")
        return
    end

    local propertyId = tonumber(data.propertyId)
    local targetId = tonumber(data.targetId)
    --[[if targetId == src then
        Bridge.Server.Notify(src, "You cannot draft a contract for yourself.", "error")
        return
    end]]
    local p = Properties[propertyId]
    if not p or p.owner then
        Bridge.Server.Notify(src, "Property is not available or already owned.", "error")
        return
    end

    -- Strictly enforce the property's configured market/rental price from server state
    local price = tonumber(p.price) or tonumber(data.price)
    local contractType = p.sale_type or data.type or 'buy'
    local commissionRate = tonumber(data.commissionRate) or 10

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        Bridge.Server.Notify(src, "Invalid or offline target player.", "error")
        return
    end

    local srcPed = GetPlayerPed(src)
    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    local maxDistance = (Settings.RealEstate.ContractDistance) or 5.0

    if #(srcCoords - targetCoords) > maxDistance then
        Bridge.Server.Notify(src, "That player is too far away to draft a contract with.", "error")
        return
    end

    local clientCid = Bridge.Server.GetIdentifier(targetId)
    if not clientCid then
        Bridge.Server.Notify(src, "Invalid target player.", "error")
        return
    end

    if contractType == 'rent' then
        local isBlacklisted = MySQL.query.await('SELECT 1 FROM housing_blacklist WHERE citizenid = ?', {clientCid})
        if isBlacklisted and isBlacklisted[1] then
            Bridge.Server.Notify(src, "This player is blacklisted from renting properties!", "error")
            return
        end
    end

    local clientName = Bridge.Server.GetPlayerName(targetId)
    local agentCid = Bridge.Server.GetIdentifier(src)
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
        Bridge.Server.Notify(targetId, "You received a new real estate contract!", "inform")

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    else
        Bridge.Server.Notify(src, "Failed to create contract.", "error")
    end
end)

lib.callback.register('LNS_Housing:server:respondToContract', function(source, contractId, action)
    local src = source
    local clientCid = Bridge.Server.GetIdentifier(src)

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
        if contract.type == 'rent' then
            local isBlacklisted = MySQL.query.await('SELECT 1 FROM housing_blacklist WHERE citizenid = ?', {clientCid})
            if isBlacklisted and isBlacklisted[1] then
                Bridge.Server.Notify(src, "You are blacklisted from renting properties!", "error")
                return false
            end
        end

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

        if not p.metadata then p.metadata = {} end
        p.owner = clientCid
        if contract.type == 'rent' then
            p.sale_type = 'rent'
            p.price = price
            p.metadata.last_rent_paid = os.time()
            p.metadata.rent_amount = price
            p.metadata.rent_debt = 0
            p.metadata.missed_payments = 0
            p.metadata.due_by = nil
            p.metadata.auto_pay = true
            p.metadata.partial_payment = 0
            p.metadata.tenant_history = p.metadata.tenant_history or {}
            table.insert(p.metadata.tenant_history, 1, {
                date = os.date("%d/%m/%Y %H:%M"),
                type = "Leased",
                tenant = contract.client_name,
                citizenid = clientCid,
                price = price
            })
        else
            p.sale_type = 'direct'
            p.metadata.tenant_history = p.metadata.tenant_history or {}
            table.insert(p.metadata.tenant_history, 1, {
                date = os.date("%d/%m/%Y %H:%M"),
                type = "Sold",
                tenant = contract.client_name,
                citizenid = clientCid,
                price = price
            })
        end

        SaveProperty(propertyId)
        SyncPropertyDoor(propertyId)

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        exports.LNS_Housing:GivePhysicalKey(propertyId, src)
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
    p.metadata.size = calculateSquareFootage(p.zone_data)
    p.size = p.metadata.size
    p.yard_zone_data = data.yard_zone_data or p.yard_zone_data

    if not p.metadata then p.metadata = {} end
    p.metadata.shell = data.mlo and 'mlo' or (data.shell or p.metadata.shell or 'Standard Motel')
    p.metadata.allow_wall_colors = data.allowWallColors or false

    if data.cameraPosition then
        p.metadata.camera_coords = data.cameraPosition
    end
    if data.cameraAim then
        p.metadata.camera_aim = data.cameraAim
    end
    if data.cameraHeading ~= nil then
        p.metadata.camera_heading = data.cameraHeading
    end
    if data.cameraModel then
        p.metadata.camera_model = data.cameraModel
    end
    if data.cameraFov ~= nil then
        p.metadata.camera_fov = data.cameraFov
    end

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

    p.garage = tonumber(data.slots) or p.garage or 2

    if data.garageCoords then
        local spawn = data.garageSpawnCoords or data.garageCoords
        p.metadata.garage_data = {
            x = data.garageCoords.x,
            y = data.garageCoords.y,
            z = data.garageCoords.z,
            h = data.garageCoords.h or 0.0,
            spawn = {
                x = spawn.x,
                y = spawn.y,
                z = spawn.z,
                h = spawn.h or 0.0
            }
        }
    else
        p.metadata.garage_data = nil
    end

    SaveProperty(propertyId)

    if p.metadata.garage_data then
        Bridge.Server.RegisterGarage(propertyId, p.label, p.metadata.garage_data)
    else
        Bridge.Server.UnregisterGarage(propertyId)
    end

    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

lib.callback.register('LNS_Housing:server:deleteListing', function(source, propertyId)
    local jobPerm = GetRealEstatePermission(source)
    if not jobPerm or not jobPerm.permissions.manageListings then return false end

    local id = tonumber(propertyId)
    local p = Properties[id]
    if not p then return false end

    if p.sale_type == 'auction' and p.auction_data and p.auction_data.highest_bidder and p.auction_data.current_bid > 0 then
        Bridge.Server.AddOfflineBankMoney(p.auction_data.highest_bidder, p.auction_data.current_bid)
        local onlineBidder = Bridge.Server.IsPlayerOnline(p.auction_data.highest_bidder)
        if onlineBidder then
            Bridge.Server.Notify(onlineBidder.PlayerData.source, "The auction for " .. p.label .. " was deleted. Your bid of $" .. p.auction_data.current_bid .. " has been refunded.", "warning")
        end
    end

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

    local oldOwner = p.owner
    local tenantName = "Resident"
    local tenant = Bridge.Server.IsPlayerOnline(oldOwner)
    if tenant then
        tenantName = tenant.PlayerData.charinfo and (tenant.PlayerData.charinfo.firstname .. ' ' .. tenant.PlayerData.charinfo.lastname) or tenantName
        Bridge.Server.Notify(tenant.PlayerData.source, "You have been evicted from " .. p.label .. " by an agent!", "error")
    end

    ResetPropertyOwnershipData(id)

    p.metadata.tenant_history = p.metadata.tenant_history or {}
    table.insert(p.metadata.tenant_history, 1, {
        date = os.date("%d/%m/%Y %H:%M"),
        type = "Evicted",
        tenant = tenantName,
        citizenid = oldOwner,
        reason = "Evicted by Agent: " .. Bridge.Server.GetPlayerName(source)
    })

    SaveProperty(id)
    SyncPropertyDoor(id)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

lib.callback.register('LNS_Housing:server:terminateOwnLease', function(source, propertyId)
    local id = tonumber(propertyId)
    local p = Properties[id]
    if not p or not p.owner or p.sale_type ~= 'rent' then return false end

    local cid = Bridge.Server.GetIdentifier(source)
    if p.owner ~= cid then return false end

    local tenantName = Bridge.Server.GetPlayerName(source)

    ResetPropertyOwnershipData(id)

    p.metadata.tenant_history = p.metadata.tenant_history or {}
    table.insert(p.metadata.tenant_history, 1, {
        date = os.date("%d/%m/%Y %H:%M"),
        type = "Terminated",
        tenant = tenantName,
        citizenid = cid,
        reason = "Lease terminated by tenant"
    })

    SaveProperty(id)
    SyncPropertyDoor(id)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

lib.callback.register('LNS_Housing:server:getBlacklist', function(source)
    debugPrint('info', 'LNS_Housing:server:getBlacklist called', {source = source})
    local results = MySQL.query.await('SELECT * FROM housing_blacklist ORDER BY created_at DESC')
    return results or {}
end)

RegisterNetEvent('LNS_Housing:server:addBlacklist', function(targetIdentifier, name, reason)
    local src = source
    debugPrint('info', 'LNS_Housing:server:addBlacklist received', {src = src, targetIdentifier = targetIdentifier, name = name, reason = reason})
    local jobPerm = GetRealEstatePermission(src)
    if not jobPerm or not jobPerm.permissions.manageListings then return end

    local citizenid = tostring(targetIdentifier)
    local targetName = name

    local sid = tonumber(targetIdentifier)
    if sid then
        local foundCid = Bridge.Server.GetIdentifier(sid)
        if foundCid then
            citizenid = foundCid
            if not targetName or targetName == '' then
                targetName = Bridge.Server.GetPlayerName(sid)
            end
        end
    end

    if not targetName or targetName == '' then
        targetName = citizenid
    end

    local agentName = Bridge.Server.GetPlayerName(src)

    local success = MySQL.insert.await([[
        INSERT INTO housing_blacklist (citizenid, name, reason, blacklisted_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = ?, reason = ?, blacklisted_by = ?
    ]], { citizenid, targetName, reason, agentName, targetName, reason, agentName })

    if success then
        Bridge.Server.Notify(src, "Successfully blacklisted " .. targetName .. " (" .. citizenid .. ")", "success")
    else
        Bridge.Server.Notify(src, "Failed to blacklist player.", "error")
    end
end)

RegisterNetEvent('LNS_Housing:server:removeBlacklist', function(citizenid)
    local src = source
    debugPrint('info', 'LNS_Housing:server:removeBlacklist received', {src = src, citizenid = citizenid})
    local jobPerm = GetRealEstatePermission(src)
    if not jobPerm or not jobPerm.permissions.manageListings then return end

    local affectedRows = MySQL.update.await('DELETE FROM housing_blacklist WHERE citizenid = ?', { citizenid })
    if affectedRows > 0 then
        Bridge.Server.Notify(src, "Removed " .. citizenid .. " from blacklist.", "success")
    else
        Bridge.Server.Notify(src, "Failed to remove player from blacklist.", "error")
    end
end)

RegisterNetEvent('LNS_Housing:server:toggleAutoPay', function(propertyId, enabled)
    local src = source
    debugPrint('info', 'LNS_Housing:server:toggleAutoPay received', {src = src, propertyId = propertyId, enabled = enabled})
    local id = tonumber(propertyId)
    local p = Properties[id]
    if not p or p.owner ~= Bridge.Server.GetIdentifier(src) then return end

    p.metadata.auto_pay = enabled
    SaveProperty(id)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    local stateText = enabled and "enabled" or "disabled"
    Bridge.Server.Notify(src, "Rent auto-pay " .. stateText .. ".", "success")
end)