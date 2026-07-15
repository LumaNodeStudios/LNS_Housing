local Settings = lib.load('shared.settings')

RegisterNetEvent('LNS_Housing:client:openPanel', function(propertyData)
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
    if insideApartment and MyApartmentId == data.id then
        TriggerServerEvent('LNS_Housing:server:updateApartmentPermissions', data.id, data.permissions)
    else
        TriggerServerEvent('LNS_Housing:server:updatePermissions', data.id, data.permissions)
    end
    cb('ok')
end)

RegisterNUICallback('changeWallColor', function(data, cb)
    local interiorId = GetInteriorFromEntity(cache.ped)
    if interiorId == 0 then
        interiorId = GetInteriorAtCoords(GetEntityCoords(cache.ped))
    end

    if Properties[data.propertyId] then
        Properties[data.propertyId].metadata.wall_color = data.color
    end

    ApplyWallColor(interiorId, data.color)
        
    if insideApartment and MyApartmentId == data.propertyId then
        TriggerServerEvent('LNS_Housing:server:updateApartmentWallColor', data.propertyId, data.color)
    else
        TriggerServerEvent('LNS_Housing:server:updateWallColor', data.propertyId, data.color)
    end
    cb('ok')
end)

RegisterCommand(Settings.RealEstate.Command, function()
    local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    local hasPermission = lib.callback.await('LNS_Housing:server:checkPermission', false, 'realestate')
    
    local shellList = {}
    for name, data in pairs(Settings.Shells or {}) do
        table.insert(shellList, { value = name, label = data.label or name })
    end
    for name, data in pairs(Settings.IPLs or {}) do
        table.insert(shellList, { value = name, label = data.label or name })
    end
    table.sort(shellList, function(a, b) return a.label < b.label end)

    SendNUIMessage({
        action = 'openRealEstate',
        data = {
            properties = properties,
            hasPermission = hasPermission,
            onlyBuyViaContracts = Settings.RealEstate.OnlyBuyViaContracts,
            shells = shellList
        }
    })
    SetNuiFocus(true, true)
end, false)

RegisterCommand('contracts', function()
    local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    local hasPermission = lib.callback.await('LNS_Housing:server:checkPermission', false, 'realestate')
    
    local shellList = {}
    for name, data in pairs(Settings.Shells or {}) do
        table.insert(shellList, { value = name, label = data.label or name })
    end
    for name, data in pairs(Settings.IPLs or {}) do
        table.insert(shellList, { value = name, label = data.label or name })
    end
    table.sort(shellList, function(a, b) return a.label < b.label end)

    SendNUIMessage({
        action = 'openRealEstate',
        data = {
            properties = properties,
            hasPermission = hasPermission,
            activeTab = 'contracts',
            onlyBuyViaContracts = Settings.RealEstate.OnlyBuyViaContracts,
            shells = shellList
        }
    })
    SetNuiFocus(true, true)
end, false)

RegisterNUICallback('buyProperty', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:buyHouse', false, data.id)
    if success then
        Bridge.Client.Notify('You bought ' .. data.label .. '!', 'success')
        
        local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
        SendNUIMessage({
            action = 'updateProperties',
            data = properties
        })
    else
        Bridge.Client.Notify('Could not buy house. Check your bank balance.', 'error')
    end
    cb('ok')
end)

RegisterNUICallback('setWaypoint', function(data, cb)
    local p = Properties[data.id]
    if p then
        local doorId = p.door_id
        if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
            doorId = p.doors[1]
        end

        if doorId and doorId ~= 0 then
            local door = exports.ox_doorlock:getDoor(doorId)
            if door then
                SetNewWaypoint(door.coords.x, door.coords.y)
                Bridge.Client.Notify('GPS waypoint set to ' .. p.label, 'success')
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('upgradeSecurity', function(data, cb)
    TriggerServerEvent('LNS_Housing:server:upgradeSecurity', data.propertyId, data.upgradeId)
    cb('ok')
end)

RegisterNUICallback('payRent', function(data, cb)
    TriggerServerEvent('LNS_Housing:server:payRent', data.propertyId, data.amount)
    cb('ok')
end)

RegisterNUICallback('toggleAutoPay', function(data, cb)
    TriggerServerEvent('LNS_Housing:server:toggleAutoPay', data.propertyId, data.enabled)
    cb('ok')
end)

RegisterNUICallback('getBlacklist', function(_, cb)
    local blacklist = lib.callback.await('LNS_Housing:server:getBlacklist', false)
    cb(blacklist or {})
end)

RegisterNUICallback('addBlacklist', function(data, cb)
    TriggerServerEvent('LNS_Housing:server:addBlacklist', data.citizenid, data.name, data.reason)
    cb('ok')
end)

RegisterNUICallback('removeBlacklist', function(data, cb)
    TriggerServerEvent('LNS_Housing:server:removeBlacklist', data.citizenid)
    cb('ok')
end)


RegisterNUICallback('updateListingDetails', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:updateListingDetails', false, data)
    if success then
        Bridge.Client.Notify("Listing details updated!", "success")
    end
    cb(success)
end)

RegisterNUICallback('deleteListing', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:deleteListing', false, data.id)
    if success then
        Bridge.Client.Notify("Listing deleted successfully!", "success")
    end
    cb(success)
end)

RegisterNUICallback('evictTenant', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:evictTenant', false, data.id)
    if success then
        Bridge.Client.Notify("Tenant evicted successfully!", "success")
    end
    cb(success)
end)

RegisterNUICallback('terminateOwnLease', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:terminateOwnLease', false, data.id)
    if success then
        Bridge.Client.Notify("You terminated your lease.", "success")
    end
    cb(success)
end)