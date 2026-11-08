local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local isCapturing = false
local currentProcessedModel = nil
local activeUploads = {}
local activeUploadCount = 0

RegisterNetEvent('LNS_Housing:client:screenshotProcessed', function(model)
    debugPrint('info', 'LNS_Housing:client:screenshotProcessed received', {model = model})
    currentProcessedModel = model
    if activeUploads[model] then
        activeUploads[model] = nil
        activeUploadCount = math.max(0, activeUploadCount - 1)
    end
end)

local PinnedInteriors = {
    2562,   -- Trevor's Trailer (v_res_tre_*, v_res_tt_*)
    166657, -- Michael's Mansion (v_res_d_*, v_res_m_*, v_res_j_*)
    197889, -- Franklin Aunt (v_res_fa_*)
    206849, -- Franklin (v_res_fh_*)
    171777, -- Floyd (v_res_*)
    197121, -- Strip club (v_club_*)
    92674,  -- Lester factory
    7170,   -- Simeon
    141313, -- Apartment Hi 1
    145665, -- Apartment Hi 2
    207105, 206081, 206337, 208129, 207617, 207361, 206593, 208385, -- Stilt houses
    149761, -- House low
    148225, -- House mid
}

local IplsToLoad = {
    "trevorstrailertidy",
    "TrevorsTrailerTrash",
    "apa_v_mp_h_01_a",
    "apa_v_mp_h_02_a",
    "apa_v_mp_h_03_a",
    "apa_v_mp_h_04_a",
    "apa_v_mp_h_05_a",
    "apa_v_mp_h_06_a",
    "apa_v_mp_h_07_a",
    "apa_v_mp_h_08_a",
}

local function LoadModel(modelInput)
    local hash = tonumber(modelInput) or GetHashKey(modelInput)
    if not hash or hash == 0 then return false end
    if HasModelLoaded(hash) then return true end

    local ok = pcall(lib.requestModel, hash, 5000)
    if ok and HasModelLoaded(hash) then return true end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(50)
    end
    return HasModelLoaded(hash)
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
    debugPrint('info', 'LNS_Housing:client:startScreenshots received', {targetModel = targetModel})
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

    if targetModel and targetModel ~= "" then
        targetModel = string.lower(targetModel:gsub("%s+", ""))
    else
        targetModel = nil
    end

    local itemsToCapture = {}
    local seenKeys = {}

    local function addCaptureEntry(model, texVar, label, price, isVariant, itemId, variantId)
        if not model or model == "" then return end
        local modelLower = string.lower(tostring(model):gsub("%s+", ""))
        local key = modelLower
        if texVar ~= nil then
            key = modelLower .. "_tint_" .. tostring(texVar)
        end

        if seenKeys[key] then return end

        local matches = false
        if not targetModel then
            matches = true
        elseif modelLower == targetModel or key == targetModel then
            matches = true
        elseif itemId and string.lower(tostring(itemId)) == targetModel then
            matches = true
        elseif variantId and string.lower(tostring(variantId)) == targetModel then
            matches = true
        end

        if matches then
            seenKeys[key] = true
            table.insert(itemsToCapture, {
                model = model,
                modelLower = modelLower,
                textureVariation = texVar,
                imageKey = key,
                label = label or model,
                price = price or 0,
                isVariant = isVariant or false
            })
        end
    end

    for _, category in ipairs(Furniture) do
        if category.items then
            for _, item in ipairs(category.items) do
                if item.model and item.model ~= "" then
                    addCaptureEntry(item.model, nil, item.label, item.price, false, item.id)

                    if item.variants and type(item.variants) == 'table' then
                        for _, variant in ipairs(item.variants) do
                            local vModel = variant.model or item.model
                            local vTex = variant.textureVariation ~= nil and tonumber(variant.textureVariation) or nil
                            local vLabel = (item.label or vModel) .. ' (' .. (variant.label or (vTex ~= nil and ('Tint #' .. tostring(vTex)) or 'Variant')) .. ')'

                            if vTex ~= nil then
                                addCaptureEntry(vModel, vTex, vLabel, variant.price or item.price, true, item.id, variant.id)
                            elseif variant.model and variant.model ~= "" and string.lower(variant.model) ~= string.lower(item.model) then
                                addCaptureEntry(variant.model, nil, vLabel, variant.price or item.price, true, item.id, variant.id)
                            end
                        end
                    end

                    if item.textureVariations then
                        if type(item.textureVariations) == 'number' and item.textureVariations > 0 then
                            for i = 0, item.textureVariations - 1 do
                                local vLabel = (item.label or item.model) .. ' (Tint #' .. tostring(i) .. ')'
                                addCaptureEntry(item.model, i, vLabel, item.price, true, item.id)
                            end
                        elseif type(item.textureVariations) == 'table' then
                            for idx, tv in ipairs(item.textureVariations) do
                                local texIdx = tv.index ~= nil and tv.index or (tv.textureVariation ~= nil and tv.textureVariation or (idx - 1))
                                local vLabel = (item.label or item.model) .. ' (' .. (tv.label or ('Tint #' .. tostring(texIdx))) .. ')'
                                addCaptureEntry(item.model, tonumber(texIdx), vLabel, item.price, true, item.id, tv.id)
                            end
                        end
                    end

                    if item.colors and type(item.colors) == 'table' then
                        for idx, c in ipairs(item.colors) do
                            local colIdx = c.index ~= nil and c.index or (c.textureVariation ~= nil and c.textureVariation or (idx - 1))
                            local vLabel = (item.label or item.model) .. ' (' .. (c.label or ('Color #' .. tostring(idx))) .. ')'
                            addCaptureEntry(item.model, tonumber(colIdx), vLabel, item.price, true, item.id, c.id)
                        end
                    end
                end
            end
        end
    end

    if #itemsToCapture == 0 and targetModel then
        local baseModel, tintStr = targetModel:match("^(.-)_tint_(%d+)$")
        if baseModel and tintStr then
            table.insert(itemsToCapture, {
                model = baseModel,
                modelLower = string.lower(baseModel),
                textureVariation = tonumber(tintStr),
                imageKey = targetModel,
                label = baseModel .. ' (Tint #' .. tintStr .. ')',
                price = 0,
                isVariant = true
            })
        else
            table.insert(itemsToCapture, {
                model = targetModel,
                modelLower = targetModel,
                textureVariation = nil,
                imageKey = targetModel,
                label = targetModel,
                price = 0,
                isVariant = false
            })
        end
    end

    table.sort(itemsToCapture, function(a, b)
        if a.modelLower ~= b.modelLower then
            return a.modelLower < b.modelLower
        end
        local aTex = a.textureVariation or -1
        local bTex = b.textureVariation or -1
        return aTex < bTex
    end)

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
    activeUploads = {}
    activeUploadCount = 0

    SendNUIMessage({
        action = 'startScreenshots',
        data = {
            total = #itemsToCapture
        },
        theme = lib.load('shared.theme') or Theme
    })

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

    for _, interiorId in ipairs(PinnedInteriors) do
        if IsValidInterior(interiorId) then
            PinInteriorInMemory(interiorId)
        end
    end
    for _, ipl in ipairs(IplsToLoad) do
        if not IsIplActive(ipl) then
            RequestIpl(ipl)
        end
    end
    SetFocusPosAndVel(0.0, 0.0, -150.0, 0.0, 0.0, 0.0)

    local drawingGreenScreen = true
    CreateThread(function()
        while drawingGreenScreen do
            DrawGreenScreenAndLights(vector3(0.0, 0.0, -150.0))
            HideHudAndRadarThisFrame()
            Wait(0)
        end
    end)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, true, true)

    local currentObj = nil
    local currentObjHash = nil

    for index, item in ipairs(itemsToCapture) do
        if not isCapturing then break end
        SendNUIMessage({
            action = 'updateScreenshotProgress',
            data = {
                current = index,
                total = #itemsToCapture,
                model = item.label or item.imageKey
            }
        })
        local hash = tonumber(item.model) or GetHashKey(item.model)
        local obj = nil

        if currentObj and DoesEntityExist(currentObj) and currentObjHash == hash then
            obj = currentObj
        else
            if currentObj and DoesEntityExist(currentObj) then
                DeleteEntity(currentObj)
                currentObj = nil
                currentObjHash = nil
            end

            if LoadModel(hash) then
                local min, max = GetModelDimensions(hash)
                local size = max - min
                local center = min + (size * 0.5)
                local diagonal = math.sqrt(size.x * size.x + size.y * size.y + size.z * size.z)
                local centerPoint = vector3(0.0, 0.0, -150.0)
                local spawnPos = centerPoint - center
                obj = CreateObjectNoOffset(hash, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)

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

                SetCamCoord(cam, camX, camY, camZ)
                PointCamAtCoord(cam, lookAt.x, lookAt.y, lookAt.z)
                SetCamFov(cam, 35.0)

                currentObj = obj
                currentObjHash = hash
            else
                lib.print.error(string.format('Model load invalid: %s (in CdImage: %s, isValid: %s)', tostring(item.model), tostring(IsModelInCdimage(hash)), tostring(IsModelValid(hash))))
            end
        end

        if obj and DoesEntityExist(obj) then
            if item.textureVariation ~= nil then
                SetObjectTextureVariation(obj, tonumber(item.textureVariation))
            else
                SetObjectTextureVariation(obj, 0)
            end

            Wait(250)

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
                local uploadKey = item.imageKey or item.model
                activeUploads[uploadKey] = true
                activeUploadCount = activeUploadCount + 1

                TriggerLatentServerEvent('LNS_Housing:server:processScreenshot', 800000, {
                    model = uploadKey,
                    imageData = base64
                })

                local maxActiveUploads = 4
                local uploadTimeout = GetGameTimer() + 20000
                while activeUploadCount >= maxActiveUploads and isCapturing and GetGameTimer() < uploadTimeout do
                    Wait(50)
                end
            else
                debugPrint('error', 'Failed to screenshot model: ' .. tostring(item.imageKey or item.model))
                print('Failed to screenshot model: ' .. tostring(item.imageKey or item.model))
            end
        end
        Wait(50)
    end

    if currentObj and DoesEntityExist(currentObj) then
        DeleteEntity(currentObj)
        currentObj = nil
        currentObjHash = nil
    end

    drawingGreenScreen = false
    local wasCancelled = not isCapturing
    isCapturing = false
    SendNUIMessage({
        action = 'endScreenshots'
    })
    Wait(500)

    RenderScriptCams(false, false, 0, true, true)
    if cam and DoesCamExist(cam) then
        DestroyCam(cam, false)
    end

    for _, interiorId in ipairs(PinnedInteriors) do
        if IsValidInterior(interiorId) then
            UnpinInterior(interiorId)
        end
    end
    ClearFocus()

    TriggerServerEvent('LNS_Housing:server:resetScreenshotBucket')
    SetEntityCoords(ped, originalCoords.x, originalCoords.y, originalCoords.z, false, false, false, false)
    SetEntityHeading(ped, originalHeading)
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)

    activeUploads = {}
    activeUploadCount = 0

    if Modeler then
        Modeler.FurnitureDataReady = false
    end

    if not wasCancelled then
        Bridge.Client.Notify('Finished screenshot session.', 'success')
    end
end)
