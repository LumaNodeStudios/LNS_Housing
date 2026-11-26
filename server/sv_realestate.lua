local Settings = lib.load('shared.settings')

if Settings.RealEstate and Settings.RealEstate.Item and Settings.RealEstate.Item.Enabled and Settings.RealEstate.Item.Name then
    Bridge.Server.CreateUseableItem(Settings.RealEstate.Item.Name, function(source)
        TriggerClientEvent('LNS_Housing:client:openRealEstateFromItem', source)
    end)
end

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
        Bridge.Server.Notify(src, locale('notify.not_enough_bank_rent'), 'error')
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
                Bridge.Server.Notify(agent.PlayerData.source, locale('notify.rent_commission_received', commission, p.label), 'success')
            else
                Bridge.Server.AddOfflineBankMoney(p.agent_cid, commission)
            end
        end

        local agencyConfig = Settings.RealEstate and Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[p.agency]
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
                Bridge.Server.RefreshGarageAccess(id)
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
        Bridge.Server.Notify(src, locale('notify.rent_paid_success', originalPayAmount, p.label), 'success')
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
    Bridge.Server.Notify(src, locale('notify.rent_autopay_toggle', stateText == 'enabled' and locale('notify.enabled') or locale('notify.disabled')), 'success')
end)

lib.callback.register('LNS_Housing:server:getPendingContracts', function(source)
    debugPrint('info', 'LNS_Housing:server:getPendingContracts called', {source = source})
    local cid = Bridge.Server.GetIdentifier(source)
    local results = MySQL.query.await([[
        SELECT c.*, p.label as property_label, p.image as property_image, p.garage as garage, p.metadata as property_metadata
        FROM housing_contracts c
        JOIN housing_properties p ON c.property_id = p.id
        WHERE c.client_cid = ? AND c.status = 'pending'
    ]], {cid}) or {}

    for i = 1, #results do
        local c = results[i]
        c.agency_label = GetAgencyLabel(c.agency)
        c.agencyLabel = c.agency_label
    end
    return results
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
    ]], {agencyName}) or {}

    for i = 1, #results do
        local c = results[i]
        c.agency_label = GetAgencyLabel(c.agency)
        c.agencyLabel = c.agency_label
    end
    return results
end)

RegisterNetEvent('LNS_Housing:server:createContract', function(data)
    local src = source
    debugPrint('info', 'LNS_Housing:server:createContract received', {src = src, data = data})
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob then return end

    local permConfig = (Settings.RealEstate and Settings.RealEstate.Permissions) or { DraftContract = 1 }
    if playerJob.grade < (permConfig.DraftContract or 1) then
        Bridge.Server.Notify(src, locale('notify.no_draft_contract_perm'), 'error')
        return
    end

    local propertyId = tonumber(data.propertyId)
    local targetId = tonumber(data.targetId)
    local p = Properties[propertyId]
    if not p or p.owner then
        Bridge.Server.Notify(src, locale('notify.prop_not_available'), 'error')
        return
    end

    local price = tonumber(p.price) or tonumber(data.price)
    local contractType = (data and (data.type == 'rent' or data.type == 'buy') and data.type) or p.sale_type or 'buy'
    local commissionRate = tonumber(data.commissionRate) or 10

    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        Bridge.Server.Notify(src, locale('notify.invalid_offline_player'), 'error')
        return
    end

    local srcPed = GetPlayerPed(src)
    local srcCoords = GetEntityCoords(srcPed)
    local targetCoords = GetEntityCoords(targetPed)
    local maxDistance = (Settings.RealEstate and Settings.RealEstate.ContractDistance) or 5.0

    if #(srcCoords - targetCoords) > maxDistance then
        Bridge.Server.Notify(src, locale('notify.player_too_far'), 'error')
        return
    end

    local clientCid = Bridge.Server.GetIdentifier(targetId)
    if not clientCid then
        Bridge.Server.Notify(src, locale('notify.invalid_target_player'), 'error')
        return
    end

    if contractType == 'rent' then
        local isBlacklisted = MySQL.query.await('SELECT 1 FROM housing_blacklist WHERE citizenid = ?', {clientCid})
        if isBlacklisted and isBlacklisted[1] then
            Bridge.Server.Notify(src, locale('notify.player_blacklisted_rent'), 'error')
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

        Bridge.Server.Notify(src, locale('notify.contract_sent', clientName), 'success')
        Bridge.Server.Notify(targetId, locale('notify.contract_received'), 'inform')

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    else
        Bridge.Server.Notify(src, locale('notify.failed_create_contract'), 'error')
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
            Bridge.Server.Notify(agent.PlayerData.source, locale('notify.contract_declined', contract.client_name, p.label), 'error')
        end
        return true
    elseif action == 'accept' then
        if contract.type == 'rent' then
            local isBlacklisted = MySQL.query.await('SELECT 1 FROM housing_blacklist WHERE citizenid = ?', {clientCid})
            if isBlacklisted and isBlacklisted[1] then
                Bridge.Server.Notify(src, locale('notify.you_blacklisted_rent'), 'error')
                return false
            end
        end

        local price = contract.price
        local bankMoney = Bridge.Server.GetBankMoney(src)

        if bankMoney < price then
            Bridge.Server.Notify(src, locale('notify.not_enough_money_bank'), 'error')
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
            Bridge.Server.Notify(agentSrc, locale('notify.contract_sale_commission', commission, p.label), 'success')
        else
            Bridge.Server.AddOfflineBankMoney(contract.agent_cid, commission)
        end

        local agencyConfig = Settings.RealEstate and Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[contract.agency]
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
        Bridge.Server.RefreshGarageAccess(propertyId)

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        exports.LNS_Housing:GivePhysicalKey(propertyId, src)
        Bridge.Server.Notify(src, locale('notify.contract_accepted', p.label), 'success')
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
    if data.type or data.property_type then
        local propType = data.type or data.property_type
        if propType == 'Commerce' then propType = 'Commercial' end
        p.type = propType
        p.property_type = propType
        p.metadata.property_type = propType
    end
    p.metadata.shell = data.mlo and 'mlo' or (data.shell or p.metadata.shell or 'Standard Motel')
    p.metadata.allow_wall_colors = data.allowWallColors or false
    if data.maxStashes ~= nil or data.max_stashes ~= nil then
        local rawMax = data.maxStashes ~= nil and data.maxStashes or data.max_stashes
        p.metadata.max_stashes = math.max(0, math.floor(tonumber(rawMax) or 0))
    end

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

    if data.breakerCoords then
        p.metadata.breaker_coords = data.breakerCoords
    end

    if data.interiorId or data.interior_id then
        p.metadata.interior_id = tonumber(data.interiorId or data.interior_id)
    end
    if data.interiorCoords or data.interior_coords then
        p.metadata.interior_coords = data.interiorCoords or data.interior_coords
    end
    if data.interiorCenter or data.interior_center then
        p.metadata.interior_center = data.interiorCenter or data.interior_center
    end
    if data.roomCount or data.room_count then
        p.metadata.room_count = tonumber(data.roomCount or data.room_count)
    end

    if data.entranceCoords then
        p.metadata.entrance = data.entranceCoords
        p.metadata.spawn = {
            x = data.entranceCoords.x,
            y = data.entranceCoords.y,
            z = data.entranceCoords.z,
            h = data.entranceCoords.h or 0.0
        }
    elseif data.entranceType ~= 'coords' then
        p.metadata.entrance = nil
    end

    if p.metadata.locked == nil then
        p.metadata.locked = true
    end

    if data.doors and #data.doors > 0 then
        local doorIds, processedSpawn = ProcessPropertyDoors(data.doors, p.label)
        p.doors = doorIds
        if processedSpawn and not p.metadata.spawn then
            p.metadata.spawn = {
                x = processedSpawn.x,
                y = processedSpawn.y,
                z = processedSpawn.z,
                h = processedSpawn.w or 0.0
            }
        end
    elseif data.entranceType == 'coords' and (not data.doors or #data.doors == 0) then
        p.doors = {}
    end

    SyncPropertyDoor(propertyId)

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
            Bridge.Server.Notify(onlineBidder.PlayerData.source, locale('notify.auction_refunded', p.label, p.auction_data.current_bid), 'warning')
        end
    end

    local doorsToRemove = {}
    local seenDoors = {}
    if type(p.doors) == 'table' then
        for _, doorId in ipairs(p.doors) do
            local numDoorId = tonumber(type(doorId) == 'table' and (doorId.id or doorId._existingId) or doorId)
            if numDoorId and numDoorId ~= 0 and not seenDoors[numDoorId] then
                seenDoors[numDoorId] = true
                doorsToRemove[#doorsToRemove + 1] = numDoorId
            end
        end
    end
    if p.door_id and p.door_id ~= 0 then
        local numDoorId = tonumber(p.door_id)
        if numDoorId and not seenDoors[numDoorId] then
            seenDoors[numDoorId] = true
            doorsToRemove[#doorsToRemove + 1] = numDoorId
        end
    end

    MySQL.update.await('DELETE FROM housing_properties WHERE id = ?', { id })
    Properties[id] = nil
    Bridge.Server.UnregisterGarage(id)

    for _, doorId in ipairs(doorsToRemove) do
        RemoveOxDoorlockDoor(doorId)
    end

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
        Bridge.Server.Notify(tenant.PlayerData.source, locale('notify.evicted_by_agent', p.label), 'error')
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
    Bridge.Server.RefreshGarageAccess(id)
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
    Bridge.Server.RefreshGarageAccess(id)
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
        Bridge.Server.Notify(src, locale('notify.blacklisted_success', targetName, citizenid), 'success')
    else
        Bridge.Server.Notify(src, locale('notify.blacklisted_failed'), 'error')
    end
end)

RegisterNetEvent('LNS_Housing:server:removeBlacklist', function(citizenid)
    local src = source
    debugPrint('info', 'LNS_Housing:server:removeBlacklist received', {src = src, citizenid = citizenid})
    local jobPerm = GetRealEstatePermission(src)
    if not jobPerm or not jobPerm.permissions.manageListings then return end

    local affectedRows = MySQL.update.await('DELETE FROM housing_blacklist WHERE citizenid = ?', { citizenid })
    if affectedRows > 0 then
        Bridge.Server.Notify(src, locale('notify.unblacklisted_success', citizenid), 'success')
    else
        Bridge.Server.Notify(src, locale('notify.unblacklisted_failed'), 'error')
    end
end)

RegisterNetEvent('LNS_Housing:server:placeBid', function(data)
    local src = source
    debugPrint('info', 'LNS_Housing:server:placeBid received', {src = src, data = data})
    local propertyId = data.id
    local amount = tonumber(data.amount)
    local p = Properties[propertyId]

    if not p or p.sale_type ~= 'auction' then return end
    if not p.auction_data or p.auction_data.status ~= 'live' then
        Bridge.Server.Notify(src, locale('notify.auction_not_live'), 'error')
        return
    end

    if amount <= p.auction_data.current_bid then
        Bridge.Server.Notify(src, locale('notify.bid_must_be_higher'), 'error')
        return
    end

    local bankMoney = Bridge.Server.GetMoney(src, 'bank')
    if bankMoney < amount then
        Bridge.Server.Notify(src, locale('notify.not_enough_bank_bid'), 'error')
        return
    end

    local removed = Bridge.Server.RemoveBankMoney(src, amount, "Auction Bid: " .. p.label)
    if not removed then
        Bridge.Server.Notify(src, locale('notify.bid_failed'), 'error')
        return
    end

    local prevBidder = p.auction_data.highest_bidder
    local prevAmount = p.auction_data.current_bid
    if prevBidder and prevAmount > 0 then
        Bridge.Server.AddOfflineBankMoney(prevBidder, prevAmount)
        local onlinePrev = Bridge.Server.IsPlayerOnline(prevBidder)
        if onlinePrev then
            Bridge.Server.Notify(onlinePrev.PlayerData.source, locale('notify.outbid', p.label, prevAmount), 'warning')
        end
    end

    p.auction_data.current_bid = amount
    p.auction_data.highest_bidder = Bridge.Server.GetIdentifier(src)

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    Bridge.Server.Notify(src, locale('notify.bid_placed', amount), 'success')
end)

RegisterNetEvent('LNS_Housing:server:controlAuction', function(data)
    local src = source
    debugPrint('info', 'LNS_Housing:server:controlAuction received', {src = src, data = data})
    local propertyId = data.id
    local action = data.action
    local p = Properties[propertyId]

    if not p or p.sale_type ~= 'auction' or p.owner then return end

    if action == 'start' then
        p.auction_data.status = 'live'
    elseif action == 'pause' then
        p.auction_data.status = 'paused'
    elseif action == 'end' then
        if p.auction_data.highest_bidder then
            p.auction_data.status = 'pending'
            Bridge.Server.Notify(src, locale('notify.auction_ended_waiting', p.auction_data.current_bid), 'inform')
        else
            p.auction_data.status = 'ended'
        end
    elseif action == 'confirm' then
        if p.auction_data.status == 'pending' and p.auction_data.highest_bidder then
            local bidderId = p.auction_data.highest_bidder
            local amount = p.auction_data.current_bid
            local bidder = Bridge.Server.IsPlayerOnline(bidderId)

            ProcessPropertySalePayout(propertyId, amount)

            p.owner = bidderId
            p.auction_data.status = 'ended'
            if bidder then
                Bridge.Server.Notify(bidder.PlayerData.source, locale('notify.bid_confirmed', p.label), 'success')
                exports.LNS_Housing:GivePhysicalKey(propertyId, bidder.PlayerData.source)
            end
            SyncPropertyDoor(propertyId)
            Bridge.Server.RefreshGarageAccess(propertyId)

            MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND status = ?', {'declined', propertyId, 'pending'})

            Bridge.Server.Notify(src, locale('notify.sale_confirmed', p.label), 'success')
        end
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
end)