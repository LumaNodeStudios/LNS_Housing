local Settings = lib.load('shared.settings')
local CAMERA_PROPS = Settings.Security.CameraProps or { `prop_cctv_cam_07a` }

RegisterNUICallback('pickDoor', function(_, cb)
    debugPrint('info', 'NUI callback: pickDoor')
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
    debugPrint('info', 'NUI callback: pickEntranceCoords')
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
    debugPrint('info', 'NUI callback: pickCameraPlacement', data)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false)
    
    StartDoorbellCameraPlacement(nil, true, function(result)
        SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
        SetNuiFocus(true, true)
        cb(result)
    end)
end)

function StartDoorbellCameraPlacement(propertyId, isRealEstate, cb)
    debugPrint('info', 'StartDoorbellCameraPlacement called', {propertyId = propertyId, isRealEstate = isRealEstate})
    if not CAMERA_PROPS or #CAMERA_PROPS == 0 then
        Bridge.Client.Notify('No camera props configured, contact an admin.', 'error')
        if cb then cb(nil) end
        return
    end

    local propIndex = 1
    local foundValid = false
    for i, model in ipairs(CAMERA_PROPS) do
        if IsModelValid(model) then
            propIndex = i
            foundValid = true
            break
        end
    end

    if not foundValid then
        Bridge.Client.Notify('Camera prop models are invalid, contact an admin.', 'error')
        if cb then cb(nil) end
        return
    end

    local currentModel = CAMERA_PROPS[propIndex]
    lib.requestModel(currentModel)

    local playerPed = cache.ped or PlayerPedId()
    local previewProp = CreateObjectNoOffset(currentModel, GetEntityCoords(playerPed), false, true, false)
    SetEntityAlpha(previewProp, 180, false)
    SetEntityCollision(previewProp, false, false)
    FreezeEntityPosition(previewProp, true)

    local camPos = nil
    local wallHeading = 0.0
    local rotationOffset = 0.0

    lib.showTextUI('[E] Confirm Position  \n[Scroll] Rotate Prop  \n[BACKSPACE] Cancel', { position = 'top-center' })

    while true do
        Wait(0)
        DisableControlAction(0, 14, true)  -- INPUT_SCROLL_UP
        DisableControlAction(0, 15, true)  -- INPUT_SCROLL_DOWN

        local hit, coords, surfaceNormal = GetPlayerRaycastCoords(10.0)
        
        local finalHeading = 0.0
        local finalPitch = 0.0
        if hit then
            wallHeading = math.deg(math.atan2(-surfaceNormal.x, surfaceNormal.y))
            finalHeading = (wallHeading + rotationOffset) % 360.0
            
            finalPitch = math.deg(math.asin(surfaceNormal.z))

            SetEntityCoords(previewProp, coords.x, coords.y, coords.z, false, false, false, false)
            SetEntityRotation(previewProp, finalPitch, 0.0, finalHeading, 2, true)
            SetEntityHeading(previewProp, finalHeading)
        end

        if IsDisabledControlJustPressed(0, 14) then
            rotationOffset = (rotationOffset + 5.0) % 360.0
        elseif IsDisabledControlJustPressed(0, 15) then
            rotationOffset = (rotationOffset - 5.0) % 360.0
        end

        if IsControlJustPressed(0, 38) then -- E
            if hit then
                camPos = coords
                wallHeading = finalHeading
                break
            else
                Bridge.Client.Notify('Please aim at a valid wall surface.', 'error')
            end
        elseif IsControlJustPressed(0, 194) then -- Backspace
            DeleteEntity(previewProp)
            SetModelAsNoLongerNeeded(currentModel)
            lib.hideTextUI()
            if cb then cb(nil) end
            return
        end
    end

    lib.hideTextUI()
    if DoesEntityExist(previewProp) then
        DeleteEntity(previewProp)
    end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    local setupProp = CreateObjectNoOffset(currentModel, camPos.x, camPos.y, camPos.z, false, true, false)
    SetEntityCollision(setupProp, false, false)
    FreezeEntityPosition(setupProp, true)
    SetEntityRotation(setupProp, 0.0, 0.0, wallHeading, 2, true)
    SetEntityHeading(setupProp, wallHeading)

    local viewCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(viewCam, camPos.x, camPos.y, camPos.z)
    
    local baseYaw = (wallHeading + 180.0) % 360.0
    local panOffset = 0.0
    local tiltOffset = -15.0
    local currentFov = 50.0

    SetCamRot(viewCam, tiltOffset, 0.0, baseYaw + panOffset, 2)
    SetCamFov(viewCam, currentFov)
    SetCamActive(viewCam, true)
    RenderScriptCams(true, false, 0, true, false)
    SetTimecycleModifier("CAMERA_secuirity")

    Wait(200)
    DoScreenFadeIn(500)

    lib.showTextUI('[Mouse] Aim Camera  \n[Scroll] Zoom (FOV)  \n[E] Confirm View  \n[BACKSPACE] Cancel/Back', { position = 'top-center' })

    local startTime = GetGameTimer()

    while true do
        Wait(0)

        DisableAllControlActions(0)
        EnableControlAction(0, 1, true) -- Look L/R
        EnableControlAction(0, 2, true) -- Look U/D
        EnableControlAction(0, 249, true) -- Push to talk

        DrawCameraSetupOverlay(startTime, currentFov)

        local mouseX = GetDisabledControlNormal(0, 1)
        local mouseY = GetDisabledControlNormal(0, 2)
        local sens = 1.8

        panOffset = math.max(-60.0, math.min(60.0, panOffset - mouseX * sens * 10.0))
        tiltOffset = math.max(-45.0, math.min(15.0, tiltOffset - mouseY * sens * 10.0))

        SetCamRot(viewCam, tiltOffset, 0.0, baseYaw + panOffset, 2)

        if IsDisabledControlJustPressed(0, 15) then -- Scroll Up (Zoom In)
            currentFov = math.max(30.0, currentFov - 3.0)
            SetCamFov(viewCam, currentFov)
        elseif IsDisabledControlJustPressed(0, 14) then -- Scroll Down (Zoom Out)
            currentFov = math.min(75.0, currentFov + 3.0)
            SetCamFov(viewCam, currentFov)
        end

        if IsDisabledControlJustPressed(0, 38) then
            break
        elseif IsDisabledControlJustPressed(0, 194) then -- Backspace to restart
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do Wait(0) end

            ClearTimecycleModifier()
            RenderScriptCams(false, false, 0, true, false)
            DestroyCam(viewCam, false)
            if DoesEntityExist(setupProp) then
                DeleteEntity(setupProp)
            end

            DoScreenFadeIn(500)
            
            SetModelAsNoLongerNeeded(currentModel)
            StartDoorbellCameraPlacement(propertyId, isRealEstate, cb)
            return
        end
    end

    local finalRot = GetCamRot(viewCam, 2)
    local direction = RotationToDirection(finalRot)
    local aimPos = camPos + direction * 10.0

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    ClearTimecycleModifier()
    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(viewCam, false)
    if DoesEntityExist(setupProp) then
        DeleteEntity(setupProp)
    end
    SetModelAsNoLongerNeeded(currentModel)
    lib.hideTextUI()

    DoScreenFadeIn(500)

    local result = {
        position = { x = camPos.x, y = camPos.y, z = camPos.z },
        aim = { x = aimPos.x, y = aimPos.y, z = aimPos.z },
        heading = wallHeading,
        model = currentModel,
        fov = currentFov
    }

    if cb then cb(result) end
end

function DrawCameraSetupOverlay(startTime, currentFov)
    DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 15)

    local elapsed = GetGameTimer() - startTime
    if (elapsed % 1000) < 600 then
        DrawRect(0.028, 0.075, 0.012, 0.02, 220, 20, 20, 255)
    end

    SetTextFont(4)
    SetTextScale(0.32, 0.32)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString("DOORBELL SETUP")
    DrawText(0.045, 0.068, 0.0)

    local zoomPercent = math.floor(((75.0 - currentFov) / (75.0 - 30.0)) * 100)
    SetTextFont(4)
    SetTextScale(0.28, 0.28)
    SetTextColour(255, 255, 255, 200)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(string.format("ZOOM: %d%%", zoomPercent))
    DrawText(0.045, 0.9, 0.0)

    local year, month, day, hour, minute, second = GetLocalTime()
    local dateStr = string.format("%02d/%02d/%04d  %02d:%02d:%02d", day, month, year, hour, minute, second)

    SetTextFont(4)
    SetTextScale(0.28, 0.28)
    SetTextColour(255, 255, 255, 200)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(dateStr)
    DrawText(0.83, 0.9, 0.0)
end

function GetPlayerRaycastCoords(distance)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local direction = RotationToDirection(camRot)
    local destination = camCoords + direction * distance

    local rayHandle = StartShapeTestRay(camCoords.x, camCoords.y, camCoords.z, destination.x, destination.y, destination.z, -1, cache.ped, 0)
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    if hit == 1 then
        return true, endCoords, surfaceNormal, entityHit
    end
    return true, destination, vector3(0.0, 0.0, 1.0), 0
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