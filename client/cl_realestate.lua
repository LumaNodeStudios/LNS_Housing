local Settings = lib.load('shared.settings')

if Settings.RealEstate and Settings.RealEstate.Command then
    RegisterCommand(Settings.RealEstate.Command, function()
        debugPrint('info', 'Real estate menu command triggered')
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
end

RegisterNetEvent('LNS_Housing:client:openRealEstateFromItem', function()
    debugPrint('info', 'LNS_Housing:client:openRealEstateFromItem received')
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
end)

RegisterNUICallback('buyProperty', function(data, cb)
    debugPrint('info', 'RealEstate NUI: buyProperty', data)
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

RegisterNUICallback('updateListingDetails', function(data, cb)
    debugPrint('info', 'RealEstate NUI: updateListingDetails', data)
    local success = lib.callback.await('LNS_Housing:server:updateListingDetails', false, data)
    if success then
        Bridge.Client.Notify("Listing details updated!", "success")
    end
    cb(success)
end)

RegisterNUICallback('deleteListing', function(data, cb)
    debugPrint('info', 'RealEstate NUI: deleteListing', data)
    local success = lib.callback.await('LNS_Housing:server:deleteListing', false, data.id)
    if success then
        Bridge.Client.Notify("Listing deleted successfully!", "success")
    end
    cb(success)
end)

RegisterNUICallback('evictTenant', function(data, cb)
    debugPrint('info', 'RealEstate NUI: evictTenant', data)
    local success = lib.callback.await('LNS_Housing:server:evictTenant', false, data.id)
    if success then
        Bridge.Client.Notify("Tenant evicted successfully!", "success")
    end
    cb(success)
end)

RegisterNUICallback('terminateOwnLease', function(data, cb)
    debugPrint('info', 'RealEstate NUI: terminateOwnLease', data)
    local success = lib.callback.await('LNS_Housing:server:terminateOwnLease', false, data.id)
    if success then
        Bridge.Client.Notify("You terminated your lease.", "success")
    end
    cb(success)
end)

RegisterNUICallback('payRent', function(data, cb)
    debugPrint('info', 'RealEstate NUI: payRent', data)
    TriggerServerEvent('LNS_Housing:server:payRent', data.propertyId, data.amount)
    cb('ok')
end)

RegisterNUICallback('toggleAutoPay', function(data, cb)
    debugPrint('info', 'RealEstate NUI: toggleAutoPay', data)
    TriggerServerEvent('LNS_Housing:server:toggleAutoPay', data.propertyId, data.enabled)
    cb('ok')
end)

RegisterNUICallback('getBlacklist', function(_, cb)
    debugPrint('info', 'RealEstate NUI: getBlacklist')
    local blacklist = lib.callback.await('LNS_Housing:server:getBlacklist', false)
    cb(blacklist or {})
end)

RegisterNUICallback('addBlacklist', function(data, cb)
    debugPrint('info', 'RealEstate NUI: addBlacklist', data)
    TriggerServerEvent('LNS_Housing:server:addBlacklist', data.citizenid, data.name, data.reason)
    cb('ok')
end)

RegisterNUICallback('removeBlacklist', function(data, cb)
    debugPrint('info', 'RealEstate NUI: removeBlacklist', data)
    TriggerServerEvent('LNS_Housing:server:removeBlacklist', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    debugPrint('info', 'RealEstate NUI: getNearbyPlayers')
    local players = GetActivePlayers()
    local playerIds = {}
    local myServerId = GetPlayerServerId(PlayerId())
    for _, player in ipairs(players) do
        local sid = GetPlayerServerId(player)
        if sid ~= myServerId then
            table.insert(playerIds, sid)
        end
    end
    
    local resolved = lib.callback.await('LNS_Housing:server:resolvePlayerNames', false, playerIds)
    cb(resolved or {})
end)

RegisterNUICallback('createContract', function(data, cb)
    debugPrint('info', 'RealEstate NUI: createContract', data)
    SetNuiFocus(false, false)
    TriggerServerEvent('LNS_Housing:server:createContract', data)
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('getPendingContracts', function(_, cb)
    debugPrint('info', 'RealEstate NUI: getPendingContracts')
    local results = lib.callback.await('LNS_Housing:server:getPendingContracts', false)
    cb(results or {})
end)

RegisterNUICallback('getAgencyContracts', function(data, cb)
    debugPrint('info', 'RealEstate NUI: getAgencyContracts', data)
    local results = lib.callback.await('LNS_Housing:server:getAgencyContracts', false, data.agency)
    cb(results or {})
end)

RegisterNUICallback('respondToContract', function(data, cb)
    debugPrint('info', 'RealEstate NUI: respondToContract', data)
    SetNuiFocus(false, false)
    local success = lib.callback.await('LNS_Housing:server:respondToContract', false, data.id, data.action)
    SendNUIMessage({ action = 'closeUI' })
    cb(success)
end)

RegisterNUICallback('placeBid', function(data, cb)
    debugPrint('info', 'RealEstate NUI: placeBid', data)
    TriggerServerEvent('LNS_Housing:server:placeBid', data)
    cb('ok')
end)

RegisterNUICallback('controlAuction', function(data, cb)
    debugPrint('info', 'RealEstate NUI: controlAuction', data)
    TriggerServerEvent('LNS_Housing:server:controlAuction', data)
    cb('ok')
end)