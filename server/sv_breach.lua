local Settings = lib.load('shared.settings')

lib.callback.register('LNS_Housing:server:isDoorBreached', function(source, propertyId)
    debugPrint('info', 'LNS_Housing:server:isDoorBreached called', {source = source, propertyId = propertyId})
    if TemporaryAccess.doors[propertyId] and next(TemporaryAccess.doors[propertyId]) then
        return true
    end
    return false
end)

RegisterNetEvent('LNS_Housing:server:policeRaidDoor', function(propertyId, propertyType, doorId)
    local src = source
    debugPrint('info', 'LNS_Housing:server:policeRaidDoor received', {src = src, propertyId = propertyId, propertyType = propertyType, doorId = doorId})
    
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob or playerJob.name ~= 'police' then
        Bridge.Server.Notify(src, 'Only police officers are authorized to breach doors!', 'error')
        return
    end

    local raidItem = Settings.Security.RaidItem or 'WEAPON_BATTERINGRAM'
    local itemCount = exports.ox_inventory:Search(src, 'count', raidItem)
    if itemCount < 1 then
        Bridge.Server.Notify(src, 'You do not have the required breaching weapon!', 'error')
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

        local identifier = Bridge.Server.GetIdentifier(src)
        if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
        TemporaryAccess.doors[propertyId][identifier] = true

        TriggerClientEvent('LNS_Housing:client:breachForceOpenDoor', -1, doorId, propertyId)
        Bridge.Server.Notify(src, 'Door breached successfully!', 'success')
    else
        local p = Properties[propertyId]
        if p and p.metadata and p.metadata.entrance then
            p.metadata.locked = false
            SaveProperty(propertyId)

            local identifier = Bridge.Server.GetIdentifier(src)
            if not TemporaryAccess.doors[propertyId] then TemporaryAccess.doors[propertyId] = {} end
            TemporaryAccess.doors[propertyId][identifier] = true

            TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
            TriggerClientEvent('LNS_Housing:client:breachForceOpenDoor', -1, doorId, propertyId)
            Bridge.Server.Notify(src, 'Door breached successfully!', 'success')
        end
    end
end)

RegisterNetEvent('LNS_Housing:server:policeRaidStash', function(propertyId)
    local src = source
    debugPrint('info', 'LNS_Housing:server:policeRaidStash received', {src = src, propertyId = propertyId})
    
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob or playerJob.name ~= 'police' then
        Bridge.Server.Notify(src, 'Only police officers are authorized to breach storage!', 'error')
        return
    end

    local raidItem = Settings.Security.RaidItem or 'WEAPON_BATTERINGRAM'
    local itemCount = exports.ox_inventory:Search(src, 'count', raidItem)
    if itemCount < 1 then
        Bridge.Server.Notify(src, 'You do not have the required breaching weapon!', 'error')
        return
    end

    local identifier = Bridge.Server.GetIdentifier(src)
    if not TemporaryAccess.stashes[propertyId] then TemporaryAccess.stashes[propertyId] = {} end
    TemporaryAccess.stashes[propertyId][identifier] = true

    Bridge.Server.Notify(src, 'Storage breached successfully!', 'success')
end)

RegisterNetEvent('LNS_Housing:server:policeSecureDoor', function(propertyId, propertyType, doorId)
    local src = source
    local playerJob = Bridge.Server.GetPlayerJob(src)
    if not playerJob or playerJob.name ~= 'police' then
        Bridge.Server.Notify(src, 'Only police officers are authorized to secure doors!', 'error')
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
        exports.ox_doorlock:setDoorState(doorId, 1)
    end

    TriggerClientEvent('LNS_Housing:client:breachRestoreDoor', -1, doorId, propertyId)

    local p = Properties[propertyId]
    if p and p.metadata then
        p.metadata.locked = true
        SaveProperty(propertyId)
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    end

    if TemporaryAccess.doors[propertyId] then
        TemporaryAccess.doors[propertyId] = nil
    end

    Bridge.Server.Notify(src, 'Door secured and locked successfully.', 'success')
end)
