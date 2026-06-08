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
        if p.owner then
            identifiers[p.owner] = 4
        end

        if p.permissions then
            for type, cids in pairs(p.permissions) do
                for _, cid in ipairs(cids) do
                    if not identifiers[cid] or identifiers[cid] < 1 then
                        identifiers[cid] = 1
                    end
                end
            end
        end
    end

    for _, doorId in ipairs(doorsToSync) do
        exports.ox_doorlock:editDoor(doorId, {
            identifiers = identifiers
        })
    end
end

function ProcessPropertySalePayout(propertyId, amount)
    local p = Properties[propertyId]
    if not p then return end

    if p.agency then
        local commissionRate = tonumber(p.commission_rate) or 10
        local commission = math.floor(amount * (commissionRate / 100))
        local remainder = amount - commission

        if p.agent_cid then
            local agent = Bridge.Server.IsPlayerOnline(p.agent_cid)
            if agent then
                local agentSource = agent.PlayerData.source
                Bridge.Server.AddBankMoney(agentSource, commission, "Property Sale Commission: " .. p.label)
                Bridge.Server.Notify(agentSource, string.format("You received $%s commission for selling %s!", commission, p.label), "success")
            else
                Bridge.Server.AddOfflineBankMoney(p.agent_cid, commission)
            end
        end

        local agencyConfig = Settings.RealEstate.Agencies and Settings.RealEstate.Agencies[p.agency]
        local societyName = agencyConfig and agencyConfig.society or p.agency
        Bridge.Server.AddSocietyMoney(societyName, remainder)
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
        Bridge.Server.Notify(src, 'You do not have the required breaching item!', 'error')
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
        exports.ox_doorlock:setDoorState(doorId, 0)

        local identifier = GetIdentifier(src)
        if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
        TemporaryAccess.doors[propertyId][identifier] = true

        Bridge.Server.Notify(src, 'Door breached successfully!', 'success')
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
        Bridge.Server.Notify(src, 'You do not have the required breaching item!', 'error')
        return
    end

    local identifier = GetIdentifier(src)
    if not TemporaryAccess.stashes[propertyId] then TemporaryAccess.stashes[propertyId] = {} end
    TemporaryAccess.stashes[propertyId][identifier] = true

    Bridge.Server.Notify(src, 'Storage breached successfully!', 'success')
end)

lib.callback.register('LNS_Housing:server:buyHouse', function(source, propertyId)
    if Settings.RealEstate and Settings.RealEstate.OnlyBuyViaContracts then
        return false
    end

    local p = Properties[propertyId]
    if not p or p.owner then return false end
    if p.sale_type ~= 'direct' then return false end

    local money = Bridge.Server.GetBankMoney(source)

    if money >= tonumber(p.price) then
        Bridge.Server.RemoveBankMoney(source, p.price, "Bought House: " .. p.label)

        ProcessPropertySalePayout(propertyId, p.price)

        p.owner = GetIdentifier(source)
        SaveProperty(propertyId)
        SyncPropertyDoor(propertyId)

        MySQL.update.await('UPDATE housing_contracts SET status = ? WHERE property_id = ? AND status = ?', {'declined', propertyId, 'pending'})

        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        return true
    end
    return false
end)

CreateThread(function()
    while true do
        Wait(60000 * 60)
        local now = os.time()
        local rentPeriod = 604800
        local gracePeriod = 86400

        for id, p in pairs(Properties) do
            if p.owner and p.sale_type == 'rent' then
                local lastPaid = p.metadata.last_rent_paid or 0
                if lastPaid > 0 then
                    local timeSincePaid = now - lastPaid
                    if timeSincePaid > (rentPeriod + gracePeriod) then
                        SyncPropertyDoor(id)

                        local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                        if tenant then
                            Bridge.Server.Notify(tenant.PlayerData.source, "Your rent for " .. p.label .. " is overdue! Your access is suspended.", "error")
                        end
                    elseif timeSincePaid > rentPeriod then
                        local tenant = Bridge.Server.IsPlayerOnline(p.owner)
                        if tenant then
                            local hoursLeft = math.ceil(((rentPeriod + gracePeriod) - timeSincePaid) / 3600)
                            Bridge.Server.Notify(tenant.PlayerData.source, "Your rent for " .. p.label .. " is due! You have " .. hoursLeft .. " hours to pay before lockout.", "warning")
                        end
                    end
                end
            end
        end
    end
end)
