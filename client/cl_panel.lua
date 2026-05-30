local Settings = lib.load('shared.settings')

RegisterNetEvent('LNS_Housing:client:openPanel', function(propertyData)
    if propertyData and propertyData.metadata then
        propertyData.wallColor = propertyData.metadata.wall_color
        propertyData.allowWallColors = propertyData.metadata.allow_wall_colors
    end
    
    propertyData.playerName = Bridge.Client.GetPlayerName()
    if propertyData.owner then
        -- This might need a callback to get owner name if not current player
        if propertyData.owner == Bridge.Client.GetIdentifier() then
            propertyData.ownerName = propertyData.playerName
        end
    end

    -- Get street name and zone from player's current location
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
    SetNuiFocus(false, false)
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

-- Real Estate Panel
RegisterCommand(Settings.RealEstate.Command, function()
    local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    local hasPermission = lib.callback.await('LNS_Housing:server:getRealEstatePermission', false)
    SendNUIMessage({
        action = 'openRealEstate',
        data = {
            properties = properties,
            hasPermission = hasPermission,
            onlyBuyViaContracts = Settings.RealEstate.OnlyBuyViaContracts
        }
    })
    SetNuiFocus(true, true)
end, false)

RegisterCommand('contracts', function()
    local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    local hasPermission = lib.callback.await('LNS_Housing:server:getRealEstatePermission', false)
    SendNUIMessage({
        action = 'openRealEstate',
        data = {
            properties = properties,
            hasPermission = hasPermission,
            activeTab = 'contracts',
            onlyBuyViaContracts = Settings.RealEstate.OnlyBuyViaContracts
        }
    })
    SetNuiFocus(true, true)
end, false)

RegisterNUICallback('buyProperty', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:buyHouse', false, data.id)
    if success then
        Settings.Notify('You bought ' .. data.label .. '!', 'success')
        -- Update the UI state locally or re-fetch
        local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
        SendNUIMessage({
            action = 'updateProperties',
            data = properties
        })
    else
        Settings.Notify('Could not buy house. Check your bank balance.', 'error')
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
                Settings.Notify('GPS waypoint set to ' .. p.label, 'success')
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
    TriggerServerEvent('LNS_Housing:server:payRent', data.propertyId)
    cb('ok')
end)

-- Real Estate Employee Callbacks
RegisterNUICallback('getEmployees', function(data, cb)
    local employees = lib.callback.await('LNS_Housing:server:getEmployees', false)
    cb(employees or {})
end)

RegisterNUICallback('hireEmployee', function(data, cb)
    local success, err = lib.callback.await('LNS_Housing:server:hireEmployee', false, data.targetId, data.manualCid, data.manualName)
    if success then
        Settings.Notify("Hired successfully!", "success")
    else
        Settings.Notify(err or "Failed to hire", "error")
    end
    cb(success)
end)

RegisterNUICallback('fireEmployee', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:fireEmployee', false, data.citizenid)
    if success then
        Settings.Notify("Fired successfully!", "success")
    end
    cb(success)
end)

RegisterNUICallback('updateEmployee', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:updateEmployee', false, data)
    if success then
        Settings.Notify("Employee settings updated!", "success")
    end
    cb(success)
end)

-- Real Estate Listings & Eviction Callbacks
RegisterNUICallback('updateListingDetails', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:updateListingDetails', false, data)
    if success then
        Settings.Notify("Listing details updated!", "success")
    end
    cb(success)
end)

RegisterNUICallback('deleteListing', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:deleteListing', false, data.id)
    if success then
        Settings.Notify("Listing deleted successfully!", "success")
    end
    cb(success)
end)

RegisterNUICallback('evictTenant', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:evictTenant', false, data.id)
    if success then
        Settings.Notify("Tenant evicted successfully!", "success")
    end
    cb(success)
end)

RegisterNUICallback('terminateOwnLease', function(data, cb)
    local success = lib.callback.await('LNS_Housing:server:terminateOwnLease', false, data.id)
    if success then
        Settings.Notify("You terminated your lease.", "success")
    end
    cb(success)
end)

RegisterNUICallback('updateSpawnPoint', function(data, cb)
    local propertyId = data.propertyId
    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
    
    local success = lib.callback.await('LNS_Housing:server:updateSpawnPoint', false, propertyId, vector4(coords.x, coords.y, coords.z, heading))
    if success then
        Settings.Notify('Spawn point updated successfully to your current position!', 'success')
    else
        Settings.Notify('Failed to update spawn point.', 'error')
    end
    cb(success)
end)

