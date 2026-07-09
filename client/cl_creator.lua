local Settings = lib.load('shared.settings')


RegisterNUICallback('pickDoor', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) 
    
    local doorId = exports.LNS_Housing:DoorPicker()
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) 
    
    if doorId then
        SendNUIMessage({
            action = 'addDoor',
            data = doorId
        })
        if type(doorId) == 'table' then
            Bridge.Client.Notify('New Door selected at ' .. math.floor(doorId.coords.x) .. ', ' .. math.floor(doorId.coords.y), 'success')
        else
            Bridge.Client.Notify('Door ID ' .. doorId .. ' added to list.', 'success')
        end
    end
    cb('ok')
end)


RegisterNUICallback('pickEntranceCoords', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) 
    
    Wait(500)
    lib.showTextUI('[E] - Confirm standing location | [H] Cancel')
    
    local pickedCoords = nil
    while true do
        Wait(0)
        DisableControlAction(0, 38, true)
        DisableControlAction(0, 104, true)
        local ped = cache.ped
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        
        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.2, 0, 255, 0, 100, false, false, 2, false, nil, nil, false)
        DrawMarker(2, coords.x, coords.y, coords.z + 0.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 150, true, true, 2, nil, nil, false)
        
        if IsDisabledControlJustPressed(0, 38) then 
            pickedCoords = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                h = heading
            }
            break
        end
        
        if IsDisabledControlJustPressed(0, 104) then 
            break
        end
    end
    
    lib.hideTextUI()
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) 
    
    if pickedCoords then
        Bridge.Client.Notify('Entrance coordinates registered at standing location.', 'success')
        cb(pickedCoords)
    else
        cb(nil)
    end
end)


RegisterNUICallback('createZone', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) 
    
    local zoneData = exports.LNS_Housing:PolyCreator()
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) 
    
    if zoneData then
        
        local simplePoints = {}
        for i, p in ipairs(zoneData.points) do
            simplePoints[i] = {x = p.x, y = p.y, z = p.z}
        end
        
        cb({
            points = simplePoints,
            thickness = zoneData.thickness
        })
    else
        cb(nil)
    end
end)

RegisterNUICallback('createYardZone', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) 
    
    local zoneData = exports.LNS_Housing:PolyCreator()
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) 
    
    if zoneData then
        
        local simplePoints = {}
        for i, p in ipairs(zoneData.points) do
            simplePoints[i] = {x = p.x, y = p.y, z = p.z}
        end
        
        cb({
            points = simplePoints,
            thickness = zoneData.thickness
        })
    else
        cb(nil)
    end
end)

RegisterNUICallback('takePhoto', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false)
    
    Wait(300)

    local oldCamMode = GetFollowPedCamViewMode()
    SetFollowPedCamViewMode(4)

    Wait(200)

    local done = false
    local uploading = false

    CreateThread(function()
        Wait(500)

        while not done do
            Wait(0)

            if uploading then
                lib.showTextUI('Uploading photo, please wait...')
            else
                lib.showTextUI('[ENTER] Take Photo | [BACKSPACE] Cancel')
            end

            DisableControlAction(0, 191, true)
            DisableControlAction(0, 177, true)

            if IsDisabledControlJustReleased(0, 191) then
                uploading = true

                exports.screencapture:requestScreenshot({ encoding = 'png' }, function(data)
                    if data and data ~= '' then
                        lib.callback('LNS_Housing:server:uploadPhoto', false, function(url)
                            done = true
                            SetFollowPedCamViewMode(oldCamMode)
                            SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
                            SetNuiFocus(true, true)

                            if url then
                                cb(url)
                                Bridge.Client.Notify('Photo uploaded successfully!', 'success')
                            else
                                cb(nil)
                                Bridge.Client.Notify('Failed to upload photo. Check console for errors.', 'error')
                            end
                        end, data)
                    else
                        done = true
                        SetFollowPedCamViewMode(oldCamMode)
                        SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
                        SetNuiFocus(true, true)
                        cb(nil)
                        Bridge.Client.Notify('Failed to capture property photo.', 'error')
                    end
                end)

            elseif IsDisabledControlJustReleased(0, 177) and not uploading then
                done = true
                SetFollowPedCamViewMode(oldCamMode)
                SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
                SetNuiFocus(true, true)
                cb(nil)
            end
        end
        lib.hideTextUI()
    end)
end)

RegisterNUICallback('pickGarageCoords', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) 
    
    Wait(500)
    lib.showTextUI('[E] - Confirm standing location for Garage Menu | [H] Cancel')
    
    local pickedCoords = nil
    while true do
        Wait(0)
        DisableControlAction(0, 38, true)
        DisableControlAction(0, 104, true)
        local ped = cache.ped
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.2, 0, 255, 0, 100, false, false, 2, false, nil, nil, false)
        DrawMarker(2, coords.x, coords.y, coords.z + 0.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 150, true, true, 2, nil, nil, false)
        
        if IsDisabledControlJustPressed(0, 38) then 
            pickedCoords = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                h = heading
            }
            break
        end
        
        if IsDisabledControlJustPressed(0, 104) then 
            break
        end
    end
    
    lib.hideTextUI()
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) 
    
    if pickedCoords then
        Bridge.Client.Notify('Garage menu location registered.', 'success')
        cb(pickedCoords)
    else
        cb(nil)
    end
end)

RegisterNUICallback('pickGarageSpawnCoords', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false) 
    
    Wait(500)
    lib.showTextUI('[E] - Confirm standing location for Vehicle Spawn | [H] Cancel')
    
    local pickedCoords = nil
    while true do
        Wait(0)
        DisableControlAction(0, 38, true)
        DisableControlAction(0, 104, true)
        local ped = cache.ped
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        
        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.2, 0, 255, 0, 100, false, false, 2, false, nil, nil, false)
        DrawMarker(2, coords.x, coords.y, coords.z + 0.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 150, true, true, 2, nil, nil, false)
        
        if IsDisabledControlJustPressed(0, 38) then 
            pickedCoords = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                h = heading
            }
            break
        end
        
        if IsDisabledControlJustPressed(0, 104) then 
            break
        end
    end
    
    lib.hideTextUI()
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true) 
    
    if pickedCoords then
        Bridge.Client.Notify('Vehicle spawn location registered.', 'success')
        cb(pickedCoords)
    else
        cb(nil)
    end
end)