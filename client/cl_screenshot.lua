local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local isCapturing = false

local function LoadModel(modelHash)
    if not IsModelInCdimage(modelHash) or not IsModelValid(modelHash) then
        return false
    end
    lib.requestModel(modelHash)
    local timeout = GetGameTimer() + 3000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasModelLoaded(modelHash)
end

local function DrawQuad(x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4, r, g, b, a)
    DrawPoly(x1, y1, z1, x2, y2, z2, x3, y3, z3, r, g, b, a)
    DrawPoly(x3, y3, z3, x4, y4, z4, x1, y1, z1, r, g, b, a)
    DrawPoly(x3, y3, z3, x2, y2, z2, x1, y1, z1, r, g, b, a)
    DrawPoly(x1, y1, z1, x4, y4, z4, x3, y3, z3, r, g, b, a)
end

local function DrawGreenScreenAndLights(pos)
    local r, g, b = 0, 177, 64
    local width, depth, height = 50.0, 50.0, 30.0
    local hw = width * 0.5
    local hd = depth * 0.5
    local fz = pos.z - 15.0
    local cz = pos.z + 15.0
    local x1, y1 = pos.x - hw, pos.y - hd
    local x2, y2 = pos.x + hw, pos.y - hd
    local x3, y3 = pos.x - hw, pos.y + hd
    local x4, y4 = pos.x + hw, pos.y + hd

    DrawQuad(x1, y1, fz, x2, y2, fz, x2, y2, cz, x1, y1, cz, r, g, b, 255)
    DrawQuad(x4, y4, fz, x3, y3, fz, x3, y3, cz, x4, y4, cz, r, g, b, 255)
    DrawQuad(x3, y3, fz, x1, y1, fz, x1, y1, cz, x3, y3, cz, r, g, b, 255)
    DrawQuad(x2, y2, fz, x4, y4, fz, x4, y4, cz, x2, y2, cz, r, g, b, 255)
    DrawQuad(x1, y1, fz, x2, y2, fz, x4, y4, fz, x3, y3, fz, r, g, b, 255)
    DrawQuad(x3, y3, cz, x4, y4, cz, x2, y2, cz, x1, y1, cz, r, g, b, 255)

    local lights = {
        { offset = vector3(0.0, 8.0, 5.0),   range = 25.0, intensity = 4.0 },
        { offset = vector3(-8.0, 0.0, 5.0),  range = 20.0, intensity = 3.0 },
        { offset = vector3(8.0, 0.0, 5.0),   range = 20.0, intensity = 3.0 },
        { offset = vector3(0.0, -6.0, 5.0),  range = 18.0, intensity = 2.0 },
        { offset = vector3(0.0, 0.0, 12.0),  range = 25.0, intensity = 3.5 },
    }

    for _, light in ipairs(lights) do
        DrawLightWithRange(
            pos.x + light.offset.x,
            pos.y + light.offset.y,
            pos.z + light.offset.z,
            255, 255, 255,
            light.range,
            light.intensity
        )
    end
end

RegisterNetEvent('LNS_Housing:client:startScreenshots', function(targetModel)
    if Modeler and Modeler.IsMenuActive then
        Modeler:CloseMenu()
    end

    local ped = cache.ped
    local originalCoords = GetEntityCoords(ped)
    local originalHeading = GetEntityHeading(ped)

    TriggerServerEvent('LNS_Housing:server:setScreenshotBucket', 999)

    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCoordsNoOffset(ped, 0.0, 0.0, -150.0, false, false, false)

    local itemsToCapture = {}
    local seenModels = {}
    for _, category in ipairs(Furniture) do
        for _, item in ipairs(category.items) do
            if item.model and item.model ~= "" then
                if not targetModel or item.model == targetModel then
                    if not seenModels[item.model] then
                        seenModels[item.model] = true
                        table.insert(itemsToCapture, item)
                    end
                end
            end
        end
    end

    if #itemsToCapture == 0 then
        Bridge.Client.Notify('No matching furniture models found to capture.', 'error')
        TriggerServerEvent('LNS_Housing:server:resetScreenshotBucket')
        SetEntityCoords(ped, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
        SetEntityHeading(ped, originalHeading)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        return
    end

    isCapturing = true
    lib.showTextUI('[BACKSPACE] Cancel Screenshots')

    CreateThread(function()
        while isCapturing do
            DisableControlAction(0, 177, true)
            if IsDisabledControlJustReleased(0, 177) then
                isCapturing = false
                Bridge.Client.Notify('Screenshot session cancelled.', 'error')
            end
            Wait(0)
        end
    end)

    Bridge.Client.Notify('Starting furniture screenshots. Capturing ' .. #itemsToCapture .. ' item(s)...', 'inform')
    Wait(1000)

    local drawingGreenScreen = true
    CreateThread(function()
        while drawingGreenScreen do
            DrawGreenScreenAndLights(vector3(0.0, 0.0, -150.0))
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)

    for index, item in ipairs(itemsToCapture) do
        if not isCapturing then break end
        local hash = tonumber(item.model) or GetHashKey(item.model)
        if LoadModel(hash) then
            local min, max = GetModelDimensions(hash)
            local size = max - min
            local center = min + (size * 0.5)
            local diagonal = math.sqrt(size.x * size.x + size.y * size.y + size.z * size.z)
            local centerPoint = vector3(0.0, 0.0, -150.0)
            local spawnPos = centerPoint - center
            local obj = CreateObjectNoOffset(hash, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)

            SetEntityAsMissionEntity(obj, true, true)
            SetModelAsNoLongerNeeded(hash)
            SetEntityCollision(obj, false, false)
            SetEntityRotation(obj, 0.0, 0.0, 0.0, 2, true)
            FreezeEntityPosition(obj, true)

            local dist = math.max(2.0, diagonal * 2.4)
            local lookAt = centerPoint
            local angleH = math.rad(40.0)
            local angleV = math.rad(20.0)
            local camX = lookAt.x + dist * math.cos(angleV) * math.sin(angleH)
            local camY = lookAt.y - dist * math.cos(angleV) * math.cos(angleH)
            local camZ = lookAt.z + dist * math.sin(angleV)
            local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camX, camY, camZ, 0.0, 0.0, 0.0, 35.0, false, 0)

            PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
            SetCamActive(cam, true)
            RenderScriptCams(true, false, 0, true, true)

            Wait(800)

            local done = false
            local base64 = nil
            exports.screencapture:requestScreenshot({ encoding = 'png' }, function(data)
                base64 = data
                done = true
            end)

            local timeout = GetGameTimer() + 8000
            while not done and GetGameTimer() < timeout do
                Wait(50)
            end

            if base64 and base64 ~= '' then
                TriggerLatentServerEvent('LNS_Housing:server:processScreenshot', 800000, {
                    model = item.model,
                    imageData = base64
                })
            else

                print('^1[LNS_Housing]^0 Failed to screenshot model: ' .. item.model)
            end

            DestroyCam(cam, false)
            RenderScriptCams(false, false, 0, true, true)
            DeleteEntity(obj)
        else
            print('^1[LNS_Housing]^0 Model load timeout: ' .. item.model)
        end
        Wait(200)
    end

    drawingGreenScreen = false
    local wasCancelled = not isCapturing
    isCapturing = false
    lib.hideTextUI()
    Wait(500)

    TriggerServerEvent('LNS_Housing:server:resetScreenshotBucket')
    SetEntityCoords(ped, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
    SetEntityHeading(ped, originalHeading)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)

    if not wasCancelled then
        Bridge.Client.Notify('Finished screenshot session. Check web/dist/assets/furniture/ for images.', 'success')
    end
end)

RegisterCommand('takeshots', function(source, args, raw)
    local hasPermission = lib.callback.await('LNS_Housing:server:checkPermission', false, 'screenshot')
    if not hasPermission then
        Bridge.Client.Notify('You do not have permission to use this command.', 'error')
        return
    end

    local modelName = args[1]
    TriggerEvent('LNS_Housing:client:startScreenshots', modelName)
end, false)