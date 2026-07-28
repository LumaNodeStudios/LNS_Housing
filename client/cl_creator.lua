local Settings = lib.load('shared.settings')
local CAMERA_PROP_MODEL = `prop_cctv_cam_06a`

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

RegisterNUICallback('pickCameraPlacement', function(data, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false)
    local result = StartCameraPlacementMode()
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true)
    cb(result)
end)

function StartCameraPlacementMode()
    if not IsModelValid(CAMERA_PROP_MODEL) then
        Bridge.Client.Notify('Camera prop model is invalid, contact an admin.', 'error')
        return nil
    end

    Bridge.Client.Notify('Aim and press [E] to place the camera. Scroll to rotate. [BACKSPACE] to cancel.', 'inform')

    lib.requestModel(CAMERA_PROP_MODEL)
    local previewProp = CreateObject(CAMERA_PROP_MODEL, GetEntityCoords(cache.ped), false, false, false)
    SetEntityAlpha(previewProp, 200, false)
    SetEntityCollision(previewProp, false, false)
    FreezeEntityPosition(previewProp, true)

    local camPos, aimPos = nil, nil
    local manualHeading = 0.0

    while not camPos do
        Wait(0)
        DisableControlAction(0, 14, true) -- INPUT_SCROLL_UP
        DisableControlAction(0, 15, true) -- INPUT_SCROLL_DOWN

        local hit, coords = GetPlayerRaycastCoords(10.0)
        if hit then
            SetEntityCoords(previewProp, coords.x, coords.y, coords.z, false, false, false, false)
            SetEntityRotation(previewProp, 0.0, 0.0, manualHeading, 2, true)
            DrawText3D(coords.x, coords.y, coords.z + 0.15, '[E] Place | Scroll to Rotate | [BACKSPACE] Cancel')
        end

        if IsDisabledControlJustPressed(0, 14) then -- Scroll Up
            manualHeading = manualHeading + 5.0
        elseif IsDisabledControlJustPressed(0, 15) then -- Scroll Down
            manualHeading = manualHeading - 5.0
        end

        SetEntityHeading(previewProp, manualHeading)

        if IsControlJustPressed(0, 38) then -- E
            camPos = coords
        elseif IsControlJustPressed(0, 194) then -- Backspace
            DeleteEntity(previewProp)
            SetModelAsNoLongerNeeded(CAMERA_PROP_MODEL)
            return nil
        end
    end

    SetEntityCoords(previewProp, camPos.x, camPos.y, camPos.z, false, false, false, false)

    while not aimPos do
        Wait(0)
        local hit, coords = GetPlayerRaycastCoords(15.0)
        if hit then
            local dx = coords.x - camPos.x
            local dy = coords.y - camPos.y
            local dz = coords.z - camPos.z
            local dist2d = math.sqrt(dx * dx + dy * dy)

            local heading = math.deg(math.atan(dx, -dy))
            local pitch = math.deg(math.atan(dz, dist2d))

            SetEntityRotation(previewProp, -pitch, 0.0, heading, 2, true)

            DrawLine(camPos.x, camPos.y, camPos.z, coords.x, coords.y, coords.z, 255, 60, 60, 200)
            DrawText3D(coords.x, coords.y, coords.z + 0.15, '[E] Confirm Aim Point | [BACKSPACE] Cancel')
        end

        if IsControlJustPressed(0, 38) then -- E
            aimPos = coords
        elseif IsControlJustPressed(0, 194) then -- Backspace
            DeleteEntity(previewProp)
            SetModelAsNoLongerNeeded(CAMERA_PROP_MODEL)
            return nil
        end
    end

    DeleteEntity(previewProp)
    SetModelAsNoLongerNeeded(CAMERA_PROP_MODEL)

    return {
        position = { x = camPos.x, y = camPos.y, z = camPos.z },
        aim = { x = aimPos.x, y = aimPos.y, z = aimPos.z }
    }
end

function GetPlayerRaycastCoords(distance)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = RotationToDirection(camRot)
    local destination = camCoords + direction * distance

    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, destination.x, destination.y, destination.z, -1, cache.ped, 0)
    local _, hit, endCoords = GetShapeTestResult(rayHandle)

    if hit == 1 then
        return true, endCoords
    end
    return true, destination
end

function RotationToDirection(rotation)
    local rad = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local x = -math.sin(rad.z) * math.abs(math.cos(rad.x))
    local y = math.cos(rad.z) * math.abs(math.cos(rad.x))
    local z = math.sin(rad.x)
    return vector3(x, y, z)
end

function DrawText3D(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.32, 0.32)
        SetTextFont(4)
        SetTextColour(255, 255, 255, 215)
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString(text)
        DrawText(sx, sy)
    end
end

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