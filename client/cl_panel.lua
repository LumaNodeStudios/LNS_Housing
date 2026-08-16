local Settings = lib.load('shared.settings')

RegisterNetEvent('LNS_Housing:client:openPanel', function(propertyData)
    debugPrint('info', 'LNS_Housing:client:openPanel received', propertyData)
    if propertyData and propertyData.metadata then
        propertyData.wallColor = propertyData.metadata.wall_color
        propertyData.allowWallColors = propertyData.metadata.allow_wall_colors
    end
    
    propertyData.playerName = Bridge.Client.GetPlayerName()
    if propertyData.owner then
        if propertyData.owner == Bridge.Client.GetIdentifier() then
            propertyData.ownerName = propertyData.playerName
        end
    end

    propertyData.securityUpgradePrice = Settings.Security.UpgradePrice
    propertyData.doorbellCameraPrice = Settings.Security.doorbellCameraPrice

    local coords = GetEntityCoords(cache.ped)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    propertyData.streetName = GetStreetNameFromHashKey(streetHash)
    propertyData.zoneName = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))

    SendNUIMessage({
        action = 'openPanel',
        data = propertyData
    })
    SetNuiFocus(true, true)
end)

RegisterNUICallback('updateProperty', function(data, cb)
    debugPrint('info', 'Panel NUI: updateProperty', data)
    local isApartment = (Properties[data.id] and Properties[data.id].isApartment) or (insideApartment and (CurrentApartmentId == data.id or MyApartmentId == data.id))
    if isApartment then
        TriggerServerEvent('LNS_Housing:server:updateApartmentPermissions', data.id, data.permissions)
    else
        TriggerServerEvent('LNS_Housing:server:updatePermissions', data.id, data.permissions)
    end
    cb('ok')
end)

RegisterNUICallback('resolvePlayerByServerId', function(data, cb)
    debugPrint('info', 'Panel NUI: resolvePlayerByServerId', data)
    local targetId = tonumber(data.serverId)
    if not targetId then
        cb({ success = false, message = 'Invalid Server ID.' })
        return
    end
    local res = lib.callback.await('LNS_Housing:server:resolvePlayerByServerId', false, targetId)
    cb(res or { success = false, message = 'Player not found.' })
end)

RegisterNUICallback('resolveIdentifiers', function(data, cb)
    debugPrint('info', 'Panel NUI: resolveIdentifiers', data)
    local citizenids = type(data.citizenids) == 'table' and data.citizenids or {}
    if #citizenids == 0 then cb({}) return end
    local res = lib.callback.await('LNS_Housing:server:resolveIdentifiers', false, citizenids)
    cb(res or {})
end)

RegisterNUICallback('changeWallColor', function(data, cb)
    debugPrint('info', 'Panel NUI: changeWallColor', data)
    local interiorId = GetInteriorFromEntity(cache.ped)
    if interiorId == 0 then
        interiorId = GetInteriorAtCoords(GetEntityCoords(cache.ped))
    end

    if Properties[data.propertyId] then
        Properties[data.propertyId].metadata.wall_color = data.color
    end

    ApplyWallColor(interiorId, data.color)
        
    local isApartment = (Properties[data.propertyId] and Properties[data.propertyId].isApartment) or (insideApartment and (CurrentApartmentId == data.propertyId or MyApartmentId == data.propertyId))
    if isApartment then
        TriggerServerEvent('LNS_Housing:server:updateApartmentWallColor', data.propertyId, data.color)
    else
        TriggerServerEvent('LNS_Housing:server:updateWallColor', data.propertyId, data.color)
    end
    cb('ok')
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    debugPrint('info', 'Panel NUI: setWaypoint', data)
    local p = Properties[data.id]
    if p then
        local coords = GetEntranceCoords(p)
        if coords then
            SetNewWaypoint(coords.x, coords.y)
            Bridge.Client.Notify('GPS waypoint set to ' .. p.label, 'success')
        end
    end
    cb('ok')
end)

RegisterNUICallback('upgradeSecurity', function(data, cb)
    debugPrint('info', 'Panel NUI: upgradeSecurity', data)
    TriggerServerEvent('LNS_Housing:server:upgradeSecurity', data.propertyId, data.upgradeId)
    cb('ok')
end)