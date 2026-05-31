local Settings = lib.load('shared.settings')

TemporaryAccess = {
    doors = {},
    stashes = {}
}

function GetIdentifier(source)
    return Bridge.Server.GetIdentifier(source)
end

function IsRentOverdue(p)
    if not p or p.sale_type ~= 'rent' or not p.owner then return false end
    local lastPaid = p.metadata.last_rent_paid or 0
    if lastPaid == 0 then return false end
    local rentPeriod = 604800 -- 7 days
    local gracePeriod = 86400 -- 1 day
    return (os.time() - lastPaid) > (rentPeriod + gracePeriod)
end

function SyncPropertyDoor(propertyId)
    local p = Properties[propertyId]
    if not p then return end
    
    local doorsToSync = {}
    if p.doors and #p.doors > 0 then
        doorsToSync = p.doors
    elseif p.door_id and p.door_id ~= 0 then
        doorsToSync = { p.door_id }
    end

    if #doorsToSync == 0 then return end

    local identifiers = {}
    
    if not IsRentOverdue(p) then
        -- Add owner
        if p.owner then
            identifiers[p.owner] = 4 -- Max rank
        end

        -- Add roommates from permissions
        if p.permissions then
            -- Consolidate all permissions into identifiers
            for type, cids in pairs(p.permissions) do
                for _, cid in ipairs(cids) do
                    if not identifiers[cid] or identifiers[cid] < 1 then
                        identifiers[cid] = 1
                    end
                end
            end
        end
    end

    -- Sync all doors
    for _, doorId in ipairs(doorsToSync) do
        -- ox_doorlock uses 'identifiers' for citizenid/identifiers
        exports.ox_doorlock:editDoor(doorId, {
            identifiers = identifiers
        })
    end
end

lib.callback.register('LNS_Housing:server:getProperties', function(source)
    return Properties
end)

lib.callback.register('LNS_Housing:server:isDoorBreached', function(source, propertyId)
    if TemporaryAccess.doors[propertyId] and next(TemporaryAccess.doors[propertyId]) then
        return true
    end
    return false
end)

lib.callback.register('LNS_Housing:server:hasAccess', function(source, propertyId, type)
    local playerJob = Bridge.Server.GetPlayerJob(source)
    if playerJob and playerJob.name == 'police' then
        if type ~= 'storage' and type ~= 'stash' then
            return true
        end
    end

    local p = Properties[propertyId]
    if not p then return false end
    
    local identifier = GetIdentifier(source)
    
    if not IsRentOverdue(p) then
        if p.owner == identifier then return true end
        
        if p.permissions and p.permissions[type] then
            for _, cid in ipairs(p.permissions[type]) do
                if cid == identifier then return true end
            end
        end
    end

    -- Check temporary access (lockpicked or breached)
    if type == 'entry' or type == 'doors' then
        if TemporaryAccess.doors[propertyId] and TemporaryAccess.doors[propertyId][identifier] then
            return true
        end
    elseif type == 'storage' or type == 'stash' then
        if TemporaryAccess.stashes[propertyId] and TemporaryAccess.stashes[propertyId][identifier] then
            return true
        end
    end

    return false
end)

RegisterNetEvent('LNS_Housing:server:lockpickSuccess', function(propertyId, type, stashId)
    local src = source
    local identifier = GetIdentifier(src)
    local p = Properties[propertyId]
    if not p then return end

    if type == 'door' then
        if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
        TemporaryAccess.doors[propertyId][identifier] = true
        
        SetTimeout(60000 * 15, function()
            if TemporaryAccess.doors[propertyId] then
                TemporaryAccess.doors[propertyId][identifier] = nil
            end
        end)
    elseif type == 'stash' then
        if not TemporaryAccess.stashes[propertyId] then TemporaryAccess.stashes[propertyId] = {} end
        TemporaryAccess.stashes[propertyId][identifier] = true
        
        SetTimeout(60000 * 15, function()
            if TemporaryAccess.stashes[propertyId] then
                TemporaryAccess.stashes[propertyId][identifier] = nil
            end
        end)
    end
end)

RegisterNetEvent('LNS_Housing:server:policeRaidDoor', function(propertyId, propertyType, doorId)
    local src = source
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob or playerJob.name ~= 'police' then
        return
    end

    local raidItem = Settings.Security.RaidItem
    local itemCount = exports.ox_inventory:Search(src, 'count', raidItem)
    if itemCount < 1 then
        Settings.Notify(src, 'You do not have the required breaching item!', 'error')
        return
    end

    if propertyType == 'apartment' then
        local doorName = "Apartment Room #" .. propertyId
        local existingDoor = exports.ox_doorlock:getDoorFromName(doorName)
        if existingDoor then
            doorId = existingDoor.id
        end
    end

    if doorId and doorId ~= 0 then
        exports.ox_doorlock:setDoorState(doorId, 0) -- 0 = Unlocked
        
        local identifier = GetIdentifier(src)
        if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
        TemporaryAccess.doors[propertyId][identifier] = true

        Settings.Notify(src, 'Door breached successfully!', 'success')
    end
end)

RegisterNetEvent('LNS_Housing:server:policeRaidStash', function(propertyId)
    local src = source
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob or playerJob.name ~= 'police' then
        return
    end

    local raidItem = Settings.Security.RaidItem
    local itemCount = exports.ox_inventory:Search(src, 'count', raidItem)
    if itemCount < 1 then
        Settings.Notify(src, 'You do not have the required breaching item!', 'error')
        return
    end

    local identifier = GetIdentifier(src)
    if not TemporaryAccess.stashes[propertyId] then TemporaryAccess.stashes[propertyId] = {} end
    TemporaryAccess.stashes[propertyId][identifier] = true

    Settings.Notify(src, 'Storage breached successfully!', 'success')
end)

function ProcessPropertySalePayout(propertyId, amount)
    local p = Properties[propertyId]
    if not p then return end

    if p.agency then
        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(amount * (commissionRate / 100))
        local remainder = amount - commission

        -- Pay listing agent commission
        if p.agent_cid then
            local agent = Bridge.Server.IsPlayerOnline(p.agent_cid)
            if agent then
                local agentSource = agent.PlayerData.source
                Bridge.Server.AddBankMoney(agentSource, commission, "Property Sale Commission: " .. p.label)
                Settings.Notify(agentSource, string.format("You received $%s commission for selling %s!", commission, p.label), "success")
            else
                Bridge.Server.AddOfflineBankMoney(p.agent_cid, commission)
            end
        end

        -- Pay agency society account
        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[p.agency]
        local societyName = agencyConfig and agencyConfig.society or p.agency
        Bridge.Server.AddSocietyMoney(societyName, remainder)
    end
end

local function GetRealEstatePermission(source)
    local isAllowed = false
    local jobName = nil
    local gradeLevel = 0

    local playerJob = Bridge.Server.GetPlayerJob(source)
    if playerJob then
        local allowedJobs = Settings.RealEstate.Jobs or { 'realestate', 'luxuryestate' }
        for _, job in ipairs(allowedJobs) do
            if playerJob.name == job then
                isAllowed = true
                jobName = playerJob.name
                gradeLevel = playerJob.grade
                break
            end
        end
    end

    if not isAllowed then
        local allowedGroups = Settings.RealEstate.Groups or { 'admin', 'god', 'superadmin' }
        local playerGroup = nil
        if Bridge.Framework == 'qbx' then
            local p = exports.qbx_core:GetPlayer(source)
            playerGroup = p and p.PlayerData.group
        elseif Bridge.Framework == 'esx' then
            local ESX = exports['es_extended']:getSharedObject()
            local p = ESX.GetPlayerFromId(source)
            playerGroup = p and p.getGroup()
        end

        if playerGroup then
            for _, group in ipairs(allowedGroups) do
                if playerGroup == group then
                    isAllowed = true
                    jobName = 'admin'
                    gradeLevel = 4
                    break
                end
            end
        end
    end

    if isAllowed then
        local permConfig = Settings.RealEstate.Permissions or {
            CreateHouse = 2,
            DraftContract = 1,
            ManageListings = 3,
            ManageEmployees = 4
        }
        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[jobName]
        
        -- Get society balance if boss
        local societyBalance = 0
        if gradeLevel >= (permConfig.ManageEmployees or 4) and jobName ~= 'admin' then
            local societyName = agencyConfig and agencyConfig.society or jobName
            societyBalance = Bridge.Server.GetSocietyMoney(societyName) or 0
        end

        local citizenid = GetIdentifier(source)
        
        local createHouse = gradeLevel >= (permConfig.CreateHouse or 2)
        local draftContract = gradeLevel >= (permConfig.DraftContract or 1)
        local manageListings = gradeLevel >= (permConfig.ManageListings or 3)
        local manageEmployees = gradeLevel >= (permConfig.ManageEmployees or 4)
        local commissionRate = agencyConfig and agencyConfig.defaultCommission or 10

        return {
            allowed = true,
            job = jobName,
            grade = gradeLevel,
            citizenid = citizenid,
            agencyLabel = agencyConfig and agencyConfig.label or 'Real Estate',
            societyBalance = societyBalance,
            defaultCommission = commissionRate,
            permissions = {
                createHouse = createHouse,
                draftContract = draftContract,
                manageListings = manageListings,
                manageEmployees = manageEmployees,
            }
        }
    end

    return {
        allowed = false,
        citizenid = GetIdentifier(source)
    }
end

lib.callback.register('LNS_Housing:server:getRealEstatePermission', function(source)
    return GetRealEstatePermission(source)
end)

lib.callback.register('LNS_Housing:server:createHouse', function(source, data)
    -- Get player's job/agency and citizenid
    local playerJob = Bridge.Server.GetPlayerJob(source)
    local citizenid = GetIdentifier(source)

    if playerJob then
        data.agency = playerJob.name
        data.agent_cid = citizenid
        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[playerJob.name]
        data.commission_rate = agencyConfig and agencyConfig.defaultCommission or 10
    end

    -- Check permissions (optional admin check here)
    local spawnCoords = nil
    if data.doors and #data.doors > 0 then
        local doorIds = {}
        for i, door in ipairs(data.doors) do
            if type(door) == 'table' and door.isNew then
                -- Register new door in ox_doorlock
                local newDoorId = exports.ox_doorlock:createDoorlock({
                    name = (data.name or data.label or 'Property') .. ' Door ' .. i,
                    model = door.model,
                    coords = door.coords,
                    heading = door.heading,
                    state = 1, -- Locked by default
                    maxDistance = 2.0
                })
                doorIds[#doorIds+1] = newDoorId
                if i == 1 then
                    spawnCoords = vector4(door.coords.x, door.coords.y, door.coords.z, door.heading or 0.0)
                end
            else
                doorIds[#doorIds+1] = door
                if i == 1 then
                    local doorData = nil
                    if exports.ox_doorlock and exports.ox_doorlock.getDoor then
                        pcall(function() doorData = exports.ox_doorlock:getDoor(door) end)
                    elseif exports.ox_doorlock and exports.ox_doorlock.getDoorData then
                        pcall(function() doorData = exports.ox_doorlock:getDoorData(door) end)
                    end
                    if doorData and doorData.coords then
                        spawnCoords = vector4(doorData.coords.x, doorData.coords.y, doorData.coords.z, doorData.heading or 0.0)
                    end
                end
            end
        end
        data.doors = doorIds
    end

    if not spawnCoords and data.zone_data and data.zone_data.points and #data.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #data.zone_data.points
        for _, pt in ipairs(data.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        spawnCoords = vector4(sumX / count, sumY / count, sumZ / count, 0.0)
    end

    data.spawn_coords = spawnCoords

    local newHouse = CreateProperty(data)
    if newHouse then
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        return newHouse
    end
    return nil
end)

lib.callback.register('LNS_Housing:server:buyHouse', function(source, propertyId)
    if Settings.RealEstate and Settings.RealEstate.OnlyBuyViaContracts then
        return false
    end

    local p = Properties[propertyId]
    if not p or p.owner then return false end
    if p.sale_type ~= 'direct' then return false end -- Only direct sales via this callback
    
    local money = Bridge.Server.GetBankMoney(source)
    
    if money >= tonumber(p.price) then
        Bridge.Server.RemoveBankMoney(source, p.price, "Bought House: " .. p.label)
        
        -- Process payouts!
        ProcessPropertySalePayout(propertyId, p.price)

        p.owner = GetIdentifier(source)
        SaveProperty(propertyId)
        SyncPropertyDoor(propertyId)
        
        -- Decline all other pending contracts for this property
        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND status = ?', {'declined', propertyId, 'pending'})

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        return true
    end
    return false
end)

-- Auction Handling
RegisterNetEvent('LNS_Housing:server:placeBid', function(data)
    local src = source
    local propertyId = data.id
    local amount = tonumber(data.amount)
    local p = Properties[propertyId]
    
    if not p or p.sale_type ~= 'auction' then return end
    if not p.auction_data or p.auction_data.status ~= 'live' then
        Settings.Notify(src, 'Auction is not live!', 'error')
        return 
    end
    
    if amount <= p.auction_data.current_bid then
        Settings.Notify(src, 'Bid must be higher than current!', 'error')
        return
    end

    local bankMoney = Bridge.Server.GetBankMoney(src)
    if bankMoney < amount then
        Settings.Notify(src, 'Not enough money in bank to place this bid!', 'error')
        return
    end

    -- Update highest bidder (No money taken yet)
    p.auction_data.current_bid = amount
    p.auction_data.highest_bidder = GetIdentifier(src)
    
    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    Settings.Notify(src, 'You placed a bid of $' .. amount, 'success')
end)

RegisterNetEvent('LNS_Housing:server:controlAuction', function(data)
    local src = source
    local propertyId = data.id
    local action = data.action
    local p = Properties[propertyId]

    if not p or p.sale_type ~= 'auction' or p.owner then return end
    
    -- TODO: Add admin/realestate check here
    
    if action == 'start' then
        p.auction_data.status = 'live'
    elseif action == 'pause' then
        p.auction_data.status = 'paused'
    elseif action == 'end' then
        if p.auction_data.highest_bidder then
            p.auction_data.status = 'pending'
            Settings.Notify(src, 'Auction ended. Waiting for confirmation of bid: $' .. p.auction_data.current_bid, 'inform')
        else
            p.auction_data.status = 'ended'
        end
    elseif action == 'confirm' then
        if p.auction_data.status == 'pending' and p.auction_data.highest_bidder then
            local bidderId = p.auction_data.highest_bidder
            local amount = p.auction_data.current_bid
            local bidder = Bridge.Server.IsPlayerOnline(bidderId)
            local success = false

            if bidder then
                local bidderSource = bidder.PlayerData.source
                if Bridge.Server.GetBankMoney(bidderSource) >= amount then
                    Bridge.Server.RemoveBankMoney(bidderSource, amount, "Won Auction: " .. p.label)
                    success = true
                end
            else
                -- Offline check
                local offlineMoney = Bridge.Server.GetOfflineBankMoney(bidderId)
                if offlineMoney >= amount then
                    Bridge.Server.RemoveOfflineBankMoney(bidderId, amount)
                    success = true
                end
            end

            if success then
                -- Process payouts!
                ProcessPropertySalePayout(propertyId, amount)

                p.owner = bidderId
                p.auction_data.status = 'ended'
                if bidder then
                    Settings.Notify(bidder.PlayerData.source, 'Congratulations! Your bid for ' .. p.label .. ' was confirmed!', 'success')
                end
                SyncPropertyDoor(propertyId)

                -- Decline all pending contracts for this property
                MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND status = ?', {'declined', propertyId, 'pending'})

                Settings.Notify(src, 'Sale confirmed for ' .. p.label, 'success')
            else
                Settings.Notify(src, 'Confirmation failed: Bidder does not have enough money!', 'error')
            end
        end
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
end)

-- Buy furniture
RegisterNetEvent('LNS_Housing:server:buyFurniture', function(propertyId, items, totalPrice)
    local src = source
    local p = Properties[propertyId]
    if not p then return end
    
    local identifier = GetIdentifier(src)
    local money = Bridge.Server.GetBankMoney(src)
    
    if money < totalPrice then
        Settings.Notify(src, 'Not enough money!', 'error')
        return
    end

    -- Check if player has access
    local hasAccess = p.owner == identifier
    if not hasAccess and p.permissions and p.permissions.manage then
        for _, cid in ipairs(p.permissions.manage) do
            if cid == identifier then
                hasAccess = true
                break
            end
        end
    end

    if not hasAccess then return end

    Bridge.Server.RemoveBankMoney(src, totalPrice, "Bought furniture for house #" .. propertyId)
    
    if not p.furniture then p.furniture = {} end
    for _, item in ipairs(items) do
        table.insert(p.furniture, item)
    end
    
    SaveProperty(propertyId)
    if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
        Bridge.Server.RegisterPropertyStashes(propertyId, p.furniture)
    end
    TriggerClientEvent('LNS_Housing:client:updateFurniture', -1, propertyId, p.furniture)
end)

-- Save furniture (for moving/editing existing ones)
RegisterNetEvent('LNS_Housing:server:saveFurniture', function(propertyId, furnitureData)
    local src = source
    local p = Properties[propertyId]
    if not p then return end
    
    -- Permission check
    local identifier = GetIdentifier(src)
    local hasAccess = p.owner == identifier
    -- Add more checks if needed
    
    if not hasAccess then return end
    
    p.furniture = furnitureData
    SaveProperty(propertyId)
    if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
        Bridge.Server.RegisterPropertyStashes(propertyId, p.furniture)
    end
    TriggerClientEvent('LNS_Housing:client:updateFurniture', -1, propertyId, p.furniture)
end)

-- Register stashes for furniture
function RegisterStash(propertyId, furnitureId, config)
    local stashId = string.format('housing_%d_%s', propertyId, furnitureId)
    exports.ox_inventory:RegisterStash(stashId, Settings.Stash.label, Settings.Stash.slots, Settings.Stash.weight)
end

-- Update permissions and doorlock
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
        Settings.Notify(src, 'Security is already at maximum level!', 'error')
        return
    end

    local nextLevel = currentLevel + 1
    -- We can define prices in settings or just use a fixed price for now
    local price = 10000 * nextLevel -- Example scaling price
    
    if Bridge.Server.GetBankMoney(src) >= price then
        Bridge.Server.RemoveBankMoney(src, price, "Security Upgrade: " .. p.label)
        p.metadata.security_level = nextLevel
        SaveProperty(propertyId)
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Settings.Notify(src, 'Security upgraded to level ' .. nextLevel, 'success')
    else
        Settings.Notify(src, 'Not enough money in bank!', 'error')
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

        -- Calculate commission and remainder
        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(rentAmount * (commissionRate / 100))
        local remainder = rentAmount - commission

        -- Pay agent commission
        if p.agent_cid then
            local agent = Bridge.Server.IsPlayerOnline(p.agent_cid)
            if agent then
                Bridge.Server.AddBankMoney(agent.PlayerData.source, commission, "Property Rent Commission: " .. p.label)
                Settings.Notify(agent.PlayerData.source, string.format("You received $%s rent commission for %s!", commission, p.label), "success")
            else
                Bridge.Server.AddOfflineBankMoney(p.agent_cid, commission)
            end
        end

        -- Pay agency society account
        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[p.agency]
        local societyName = agencyConfig and agencyConfig.society or p.agency
        Bridge.Server.AddSocietyMoney(societyName, remainder)

        p.metadata.last_rent_paid = os.time()
        SaveProperty(propertyId)
        
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Settings.Notify(src, string.format("You successfully paid $%s rent for %s.", rentAmount, p.label), "success")
    else
        Settings.Notify(src, "Not enough money in bank to pay rent!", "error")
    end
end)

-- Replace the existing finishMowing handler:
RegisterNetEvent('LNS_Housing:server:finishMowing', function(propertyId, mowedIndices, isFullMow)
    local src = source
    local p = Properties[propertyId]
    if not p then return end


    local now = os.time()
    if not p.lawn_data then p.lawn_data = {} end

    -- Stamp each mowed blade with current time
    if mowedIndices then
        for _, idx in ipairs(mowedIndices) do
            p.lawn_data[tostring(idx)] = now
        end
    end

    -- On a full mow, also update the legacy last_mowed for compatibility
    if isFullMow then
        p.last_mowed = now
    end

    SaveProperty(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
end)

-- New event: save a partial batch of mowed blades mid-mow
RegisterNetEvent('LNS_Housing:server:saveMowedBlades', function(propertyId, mowedIndices)
    local src = source
    local p = Properties[propertyId]
    if not p or not mowedIndices or #mowedIndices == 0 then return end


    local now = os.time()
    if not p.lawn_data then p.lawn_data = {} end

    for _, idx in ipairs(mowedIndices) do
        p.lawn_data[tostring(idx)] = now
    end

    SaveProperty(propertyId)
    -- Sync to all clients so other nearby players see the change
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
end)

lib.callback.register('LNS_Housing:server:getServerTime', function(source)
    return os.time()
end)

Bridge.Server.CreateUseableItem(Settings.Lawn.RequireItem, function(source)
    TriggerClientEvent('LNS_Housing:client:useMower', source)
end)

-- Real Estate Contract Operations

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
        Settings.Notify(src, "You do not have permission to draft contracts.", "error")
        return
    end

    local propertyId = tonumber(data.propertyId)
    local targetId = tonumber(data.targetId)
    local price = tonumber(data.price)
    local contractType = data.type or 'buy' -- 'buy' or 'rent'
    local commissionRate = tonumber(data.commissionRate) or 10

    local p = Properties[propertyId]
    if not p or p.owner then
        Settings.Notify(src, "Property is not available or already owned.", "error")
        return
    end

    local clientCid = GetIdentifier(targetId)
    if not clientCid then
        Settings.Notify(src, "Invalid target player.", "error")
        return
    end

    local clientName = Bridge.Server.GetPlayerName(targetId)
    local agentCid = GetIdentifier(src)
    local agentName = Bridge.Server.GetPlayerName(src)

    -- Insert into database
    local contractId = MySQL.insert.await([[
        INSERT INTO housing_contracts 
        (property_id, client_cid, client_name, agent_cid, agent_name, agency, price, type, status) 
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')
    ]], {
        propertyId, clientCid, clientName, agentCid, agentName, playerJob.name, price, contractType
    })

    if contractId then
        -- Update property listing temporarily to assign the agency/agent/commission rate
        p.agency = playerJob.name
        p.agent_cid = agentCid
        p.commission_rate = commissionRate
        SaveProperty(propertyId)

        Settings.Notify(src, "Contract sent to " .. clientName .. "!", "success")
        Settings.Notify(targetId, "You received a new real estate contract! Use /contracts to view.", "inform")

        -- Trigger UI update to all clients
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    else
        Settings.Notify(src, "Failed to create contract.", "error")
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
        -- Notify agent if online
        local agent = Bridge.Server.IsPlayerOnline(contract.agent_cid)
        if agent then
            Settings.Notify(agent.PlayerData.source, contract.client_name .. " declined your contract for " .. p.label .. ".", "error")
        end
        return true
    elseif action == 'accept' then
        local price = contract.price
        local bankMoney = Bridge.Server.GetBankMoney(src)

        if bankMoney < price then
            Settings.Notify(src, "You do not have enough money in your bank account.", "error")
            return false
        end

        -- Deduct purchase money
        Bridge.Server.RemoveBankMoney(src, price, "Accepted Real Estate Contract: " .. p.label)

        -- Calculate and pay commission
        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(price * (commissionRate / 100))
        local remainder = price - commission

        -- Pay Agent
        local agent = Bridge.Server.IsPlayerOnline(contract.agent_cid)
        if agent then
            local agentSrc = agent.PlayerData.source
            Bridge.Server.AddBankMoney(agentSrc, commission, "Property Payout Commission: " .. p.label)
            Settings.Notify(agentSrc, string.format("You received $%s commission for the sale of %s!", commission, p.label), "success")
        else
            Bridge.Server.AddOfflineBankMoney(contract.agent_cid, commission)
        end

        -- Deposit remainder to society
        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[contract.agency]
        local societyName = agencyConfig and agencyConfig.society or contract.agency
        Bridge.Server.AddSocietyMoney(societyName, remainder)

        -- Update SQL contract status
        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE id = ?', {'accepted', contractId})

        -- Decline all other pending contracts for this property
        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND id != ? AND status = ?', {'declined', propertyId, contractId, 'pending'})

        -- Assign ownership!
        if contract.type == 'rent' then
            p.owner = clientCid
            p.sale_type = 'rent'
            p.price = price -- Rent price
            p.metadata.last_rent_paid = os.time()
            p.metadata.rent_amount = price
        else
            p.owner = clientCid
            p.sale_type = 'direct'
        end

        SaveProperty(propertyId)
        SyncPropertyDoor(propertyId)

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Settings.Notify(src, "Congratulations! You accepted the contract and now have access to " .. p.label .. ".", "success")
        return true
    end

    return false
end)

-- ==========================================
-- Employee Management APIs
-- Listings Management & Eviction APIs
-- ==========================================

lib.callback.register('LNS_Housing:server:updateListingDetails', function(source, data)
    local jobPerm = GetRealEstatePermission(source)
    if not jobPerm or not jobPerm.permissions.manageListings then return false end

    local propertyId = tonumber(data.id)
    local p = Properties[propertyId]
    if not p then return false end

    p.label = data.label or p.label
    p.price = tonumber(data.price) or p.price
    p.sale_type = data.sale_type or p.sale_type

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

    -- Permission check: only the owner or someone with 'manage' access can update spawn point
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

    -- Update metadata in memory
    if not p.metadata then p.metadata = {} end
    p.metadata.spawn = {
        x = spawnCoords.x,
        y = spawnCoords.y,
        z = spawnCoords.z,
        h = spawnCoords.w
    }

    -- Save to database
    SaveProperty(propertyId)

    -- Sync back to all clients
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    return true
end)

-- ==========================================
-- Overdue Rent & Eviction Checker Loop
-- ==========================================

CreateThread(function()
    while true do
        Wait(60000 * 60) -- Run every 1 hour
        local now = os.time()
        local rentPeriod = 604800 -- 7 days in seconds
        local gracePeriod = 86400 -- 1 day grace in seconds

        local changed = false
        for id, p in pairs(Properties) do
            if p.owner and p.sale_type == 'rent' then
                local lastPaid = p.metadata.last_rent_paid or 0
                if lastPaid > 0 then
                    local timeSincePaid = now - lastPaid
                    if timeSincePaid > (rentPeriod + gracePeriod) then
                        -- Grace period expired! Eviction/Suspension
                        SyncPropertyDoor(id)
                        
                        local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                        if tenant then
                            Settings.Notify(tenant.PlayerData.source, "Your rent for " .. p.label .. " is overdue! Your access is suspended.", "error")
                        end
                    elseif timeSincePaid > rentPeriod then
                        -- Grace period warning
                        local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                        if tenant then
                            local hoursLeft = math.ceil(((rentPeriod + gracePeriod) - timeSincePaid) / 3600)
                            Settings.Notify(tenant.PlayerData.source, "Your rent for " .. p.label .. " is due! You have " .. hoursLeft .. " hours to pay before lockout.", "warning")
                        end
                    end
                end
            end
        end
    end
end)