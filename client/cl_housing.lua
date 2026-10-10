lib.require('@qbx_core.modules.lib')
local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local CurrentProperty = nil
local CurrentInterior = 0
local PropertyBlips = {}
local ClearPropertyBlips, UpdatePropertyBlips, HasPropertyAccessLocal
local PropertyZones = {}
InsidePropertyId = nil
HasFurnitureManagePermission = false
local activeAlarmsCount = 0
local activeAlarmsCount = 0
local activeDoorbellsCount = 0
local AUDIO_BANK = "audiodirectory/lns_bank"
local AUDIO_REF = "lns_soundset"
local AUDIO_TIMEOUT = 10000 -- ms
local DoorbellCam = nil
local MotionZones = {}
local MotionLastTriggered = {}
local CAMERA_PROPS = Settings.Security.CameraProps or { `prop_cctv_cam_07a` }
local DEFAULT_CAMERA_PROP = CAMERA_PROPS[1]
local LoadedCameraProps = {}
Properties = {}
EntranceTargets = {}
LoadedFurniture = {}

RegisterNUICallback('closeUI', function(_, cb)
    debugPrint('info', 'NUI callback: closeUI')
    if lib and lib.hideTextUI then pcall(lib.hideTextUI) end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('closeStorageKeypad', function(_, cb)
    debugPrint('info', 'NUI callback: closeStorageKeypad')
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('submitStoragePasscode', function(data, cb)
    debugPrint('info', 'NUI callback: submitStoragePasscode', data)
    if not data or not data.propertyId or not data.stashId or not data.passcode then
        cb({ success = false, message = 'Invalid data provided' })
        return
    end

    if data.mode == 'register' or data.mode == 'reset' then
        local res = lib.callback.await('LNS_Housing:server:setStoragePasscode', false, data.propertyId, data.stashId, data.passcode, data.mode == 'reset')
        if res and res.success then
            SetNuiFocus(false, false)
            Bridge.Client.Notify(data.mode == 'reset' and 'Storage passcode updated successfully!' or 'Storage passcode registered successfully!', 'success')
            if data.mode == 'register' then
                Wait(300)
                Bridge.Client.OpenStash(data.propertyId, data.furnitureId)
            end
            cb({ success = true })
        else
            cb({ success = false, message = res and res.message or 'Failed to set passcode' })
        end
    elseif data.mode == 'unlock' then
        local res = lib.callback.await('LNS_Housing:server:verifyStoragePasscode', false, data.propertyId, data.stashId, data.passcode)
        if res and res.success then
            SetNuiFocus(false, false)
            cb({ success = true })
            Wait(300)
            Bridge.Client.OpenStash(data.propertyId, data.furnitureId)
        else
            cb({ success = false, message = res and res.message or 'Incorrect passcode' })
        end
    else
        cb({ success = false, message = 'Unknown mode' })
    end
end)

RegisterNUICallback('viewDoorbellCamera', function(data, cb)
    debugPrint('info', 'NUI callback: viewDoorbellCamera', data)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    OpenDoorbellCamera(data.propertyId)
    cb('ok')
end)

RegisterNUICallback('repositionDoorbellCamera', function(data, cb)
    debugPrint('info', 'NUI callback: repositionDoorbellCamera', data)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    
    local propertyId = data.propertyId
    local p = Properties[propertyId]
    if p then
        StartDoorbellCameraPlacement(propertyId, false, function(result)
            if result then
                TriggerServerEvent('LNS_Housing:server:saveDoorbellCamera', propertyId, result)
            end
        end)
    end
    cb('ok')
end)

RegisterNetEvent('LNS_Housing:client:startDoorbellCameraSetup', function(propertyId)
    debugPrint('info', 'LNS_Housing:client:startDoorbellCameraSetup received', {propertyId = propertyId})
    local p = Properties[propertyId]
    if not p then return end
    
    Bridge.Client.Notify('Please place your doorbell camera. Look at a wall near the door.', 'inform')
    
    StartDoorbellCameraPlacement(propertyId, false, function(result)
        if result then
            TriggerServerEvent('LNS_Housing:server:saveDoorbellCamera', propertyId, result)
        end
    end)
end)

function OpenDoorbellCamera(propertyId)
    debugPrint('info', 'OpenDoorbellCamera called', {propertyId = propertyId})
    local p = Properties[propertyId]
    if not p or p.isApartment or not (p.metadata and p.metadata.doorbell_camera == true) then
        Bridge.Client.Notify('This property does not have a doorbell camera installed.', 'error')
        return
    end

    local camCoords, aimCoords = nil, nil

    if p.metadata.camera_coords then
        local c = p.metadata.camera_coords
        camCoords = vec3(c.x, c.y, c.z)
    end

    if p.metadata.camera_aim then
        local a = p.metadata.camera_aim
        aimCoords = vec3(a.x, a.y, a.z)
    end

    if not camCoords then
        local entranceCoords = GetEntranceCoords(p)
        if not entranceCoords then return end

        camCoords = vec3(entranceCoords.x, entranceCoords.y, entranceCoords.z + 2.2)
        aimCoords = vec3(entranceCoords.x, entranceCoords.y, entranceCoords.z + 0.5)
    end

    aimCoords = aimCoords or camCoords

    if DoorbellCam then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(DoorbellCam, false)
        DoorbellCam = nil
    end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    local dir = aimCoords - camCoords
    local distance = #dir
    local baseYaw = (distance > 0.0) and math.deg(math.atan2(-dir.x, dir.y)) or ((tonumber(p.metadata.camera_heading) or 0.0) + 180.0) % 360.0
    local basePitch = (distance > 0.0) and math.deg(math.asin(dir.z / distance)) or -15.0
    local panOffset = 0.0
    local tiltOffset = 0.0
    local currentFov = p.metadata.camera_fov or 50.0
    local nightVisionActive = false

    DoorbellCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(DoorbellCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(DoorbellCam, basePitch + tiltOffset, 0.0, baseYaw + panOffset, 2)
    SetCamFov(DoorbellCam, currentFov)
    SetCamActive(DoorbellCam, true)

    RenderScriptCams(true, false, 0, true, false)
    SetTimecycleModifier("CAMERA_secuirity")

    Wait(200)
    DoScreenFadeIn(500)

    lib.showTextUI('[Mouse] Pan/Tilt  \n[Scroll] Zoom  \n[N] Night Vision  \n[G] Exit Feed', { position = 'top-center' })

    CreateThread(function()
        local startTime = GetGameTimer()

        while DoorbellCam do
            Wait(0)

            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) -- Look L/R
            EnableControlAction(0, 2, true) -- Look U/D

            DrawCameraOverlay(startTime, currentFov, nightVisionActive)

            local mouseX = GetDisabledControlNormal(0, 1)
            local mouseY = GetDisabledControlNormal(0, 2)
            local sens = 1.8

            panOffset = math.max(-60.0, math.min(60.0, panOffset - mouseX * sens * 10.0))
            tiltOffset = math.max(-45.0, math.min(15.0, tiltOffset - mouseY * sens * 10.0))

            SetCamRot(DoorbellCam, basePitch + tiltOffset, 0.0, baseYaw + panOffset, 2)

            if IsDisabledControlJustPressed(0, 15) then -- Scroll Up (Zoom In)
                currentFov = math.max(30.0, currentFov - 3.0)
                SetCamFov(DoorbellCam, currentFov)
            elseif IsDisabledControlJustPressed(0, 14) then -- Scroll Down (Zoom Out)
                currentFov = math.min(75.0, currentFov + 3.0)
                SetCamFov(DoorbellCam, currentFov)
            end

            if IsDisabledControlJustPressed(0, 306) then
                nightVisionActive = not nightVisionActive
                SetNightvision(nightVisionActive)
            end

            if IsDisabledControlJustPressed(0, 47) or IsDisabledControlJustPressed(0, 194) then
                break
            end
        end

        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do
            Wait(0)
        end

        ClearTimecycleModifier()
        if nightVisionActive then
            SetNightvision(false)
        end
        lib.hideTextUI()

        RenderScriptCams(false, false, 0, true, false)

        if DoorbellCam then
            DestroyCam(DoorbellCam, false)
            DoorbellCam = nil
        end

        Wait(200)
        DoScreenFadeIn(500)
    end)
end

function DrawCameraOverlay(startTime, currentFov, nightVisionActive)
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
    AddTextComponentString("DOORBELL CAM - LIVE")
    DrawText(0.045, 0.068, 0.0)

    local zoomPercent = math.floor(((75.0 - currentFov) / (75.0 - 30.0)) * 100)
    SetTextFont(4)
    SetTextScale(0.28, 0.28)
    SetTextColour(255, 255, 255, 200)
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(string.format("ZOOM: %d%%", zoomPercent))
    DrawText(0.045, 0.9, 0.0)

    if nightVisionActive then
        SetTextFont(4)
        SetTextScale(0.28, 0.28)
        SetTextColour(50, 255, 50, 200)
        SetTextOutline()
        SetTextEntry("STRING")
        AddTextComponentString("NIGHT VISION ACTIVE")
        DrawText(0.2, 0.068, 0.0)
    end

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

function RegisterDoorbellMotionZone(p)
    if not p or p.isApartment then return end
    if not (p.metadata and p.metadata.doorbell_camera == true) then return end
    if MotionZones[p.id] then return end

    local entranceCoords = GetEntranceCoords(p)
    if not entranceCoords then return end

    MotionZones[p.id] = lib.points.new({
        coords = entranceCoords,
        distance = 6.0,
        onEnter = function()
            local last = MotionLastTriggered[p.id] or 0
            if (GetGameTimer() - last) < 15000 then return end
            MotionLastTriggered[p.id] = GetGameTimer()
            TriggerServerEvent('LNS_Housing:server:motionDetected', p.id)
        end
    })
end

function ClearDoorbellMotionZone(propertyId)
    if MotionZones[propertyId] then
        pcall(function() MotionZones[propertyId]:remove() end)
        MotionZones[propertyId] = nil
    end
end

RegisterNetEvent('LNS_Housing:client:motionAlert', function(propertyLabel, propertyId)
    local message = ('Motion detected at the front door of %s!'):format(propertyLabel)
    
    if Bridge.PhoneScript == 'yseries' then
        TriggerServerEvent('LNS_Housing:server:motionAlert', propertyLabel)
        return
    else
        local success = Bridge.Client.PhoneNotification({
            title = 'Home Security',
            body = message
        })

        if not success then
            Bridge.Client.Notify(message, 'warning')
        end
    end
end)

function LockpickDoor(propertyId)
    local p = Properties[propertyId]
    local isApartment = false
    
    if not p then
        if ApartmentRooms then
            for _, room in ipairs(ApartmentRooms) do
                if room.id == propertyId then
                    isApartment = true
                    break
                end
            end
        end
    else
        isApartment = p.isApartment
    end

    if isApartment then
        if Settings.Apartments and not Settings.Apartments.CanBreakIn then
            Bridge.Client.Notify('Apartment break-ins are disabled.', 'error')
            return
        end
    else
        if Settings.Housing and not Settings.Housing.CanBreakIn then
            Bridge.Client.Notify('House break-ins are disabled.', 'error')
            return
        end
    end

    if not p and not isApartment then return end

    local permType = isApartment and 'apartment' or 'house'
    if not lib.callback.await('LNS_Housing:server:checkPermission', false, permType, propertyId, 'lockpick') then
        Bridge.Client.Notify('You cannot lockpick this property (either you already have access or it is unowned).', 'error')
        return
    end

    local securityLevel = 0
    if p and p.metadata and p.metadata.security_level then
        securityLevel = p.metadata.security_level or 0
    elseif isApartment then
        securityLevel = lib.callback.await('LNS_Housing:server:getApartmentSecurityLevel', false, propertyId) or 0
    end
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    TaskPlayAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'ig_3_con_loop', 8.0, -8.0, -1, 49, 0, false, false, false)

    local rounds = {}
    for i = 1, config.rounds do
        rounds[i] = { areaSize = config.area, speedMultiplier = config.speed }
    end
    local success = Bridge.Client.SkillCheck(rounds, { 'w', 'a', 's', 'd' })
    
    ClearPedTasks(cache.ped)

    if success then
        TriggerServerEvent('LNS_Housing:server:lockpickSuccess', propertyId, 'door')
        Bridge.Client.Notify('You successfully picked the lock!', 'success')
    else
        TriggerServerEvent('LNS_Housing:server:lockpickFailed', propertyId)
        Bridge.Client.Notify('You failed to pick the lock.', 'error')
    end
end

function OpenBelongingsRetrieval(propertyId)
    local p = Properties[propertyId]
    if not p or not p.furniture then return end

    local options = {}
    for _, f in ipairs(p.furniture) do
        local itemData = nil
        for _, cat in ipairs(Furniture) do
            for _, item in ipairs(cat.items) do
                if (tonumber(item.model) or GetHashKey(item.model)) == (tonumber(f.model) or GetHashKey(f.model)) then
                    itemData = item
                    break
                end
            end
            if itemData then break end
        end

        if itemData and itemData.isStorage then
            local isTrash = itemData.isTrash or itemData.type == 'trash' or itemData.isDisposal or itemData.type == 'disposal'
            if not isTrash then
                local isFridge = itemData.isFridge or itemData.type == 'fridge' or (itemData.id and tostring(itemData.id):lower():find('fridge'))
                table.insert(options, {
                    title = f.label or itemData.label or (isFridge and 'Refrigerator' or 'Storage Unit'),
                    description = isFridge and 'Retrieve items from this refrigerator' or 'Retrieve items from this storage unit',
                    icon = isFridge and 'snowflake' or 'box',
                    arrow = true,
                    onSelect = function()
                        Bridge.Client.OpenStash(propertyId, f.id)
                    end
                })
            end
        end
    end

    if #options == 0 then
        Bridge.Client.Notify('No stashes found in this property.', 'error')
        return
    end

    lib.registerContext({
        id = 'housing_belongings_retrieval',
        title = 'Retrieve Belongings - ' .. p.label,
        options = options
    })
    lib.showContext('housing_belongings_retrieval')
end

function OpenStorageHandler(propertyId, furnitureId, stashId, stashLabel, isFridge)
    local storageInfo = lib.callback.await('LNS_Housing:server:getStorageInfo', false, propertyId, stashId)
    if not storageInfo then
        Bridge.Client.OpenStash(propertyId, furnitureId)
        return
    end

    if not storageInfo.hasPasscode then
        if storageInfo.canManage then
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openStorageKeypad',
                data = {
                    mode = 'register',
                    propertyId = propertyId,
                    furnitureId = furnitureId,
                    stashId = stashId,
                    title = stashLabel,
                    isFridge = isFridge,
                    canReset = false
                }
            })
        else
            Bridge.Client.Notify('This storage is not configured yet. The owner must set the passcode first.', 'error')
        end
        return
    end

    if not storageInfo.isLocked then
        Bridge.Client.OpenStash(propertyId, furnitureId)
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openStorageKeypad',
        data = {
            mode = 'unlock',
            propertyId = propertyId,
            furnitureId = furnitureId,
            stashId = stashId,
            title = stashLabel,
            isFridge = isFridge,
            canReset = storageInfo.canManage
        }
    })
end

function ResetStoragePasscodeHandler(propertyId, furnitureId, stashId, stashLabel, isFridge)
    local storageInfo = lib.callback.await('LNS_Housing:server:getStorageInfo', false, propertyId, stashId)
    if not storageInfo or not storageInfo.canManage then
        Bridge.Client.Notify('You do not have permission to reset this storage passcode.', 'error')
        return
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openStorageKeypad',
        data = {
            mode = 'reset',
            propertyId = propertyId,
            furnitureId = furnitureId,
            stashId = stashId,
            title = stashLabel,
            isFridge = isFridge,
            canReset = false
        }
    })
end

function LockpickStash(propertyId, stashId)
    local p = Properties[propertyId]
    local isApartment = false
    
    if not p then
        if ApartmentRooms then
            for _, room in ipairs(ApartmentRooms) do
                if room.id == propertyId then
                    isApartment = true
                    break
                end
            end
        end
    else
        isApartment = p.isApartment
    end

    if isApartment then
        if Settings.Apartments and not Settings.Apartments.CanBreakIn then
            Bridge.Client.Notify('Apartment break-ins are disabled.', 'error')
            return
        end
    else
        if Settings.Housing and not Settings.Housing.CanBreakIn then
            Bridge.Client.Notify('House break-ins are disabled.', 'error')
            return
        end
    end

    if not p and not isApartment then return end

    local permType = isApartment and 'apartment' or 'house'
    if not lib.callback.await('LNS_Housing:server:checkPermission', false, permType, propertyId, 'lockpickStash') then
        Bridge.Client.Notify('You cannot lockpick this storage (either you already have access or it is unowned).', 'error')
        return
    end

    local lockpickItem = Settings.Security.LockpickItem or 'lockpick'
    local count = Bridge.Client.Search('count', lockpickItem)
    if not count or count < 1 then
        Bridge.Client.Notify('You need a lockpick to pick this storage lock!', 'error')
        return
    end

    local securityLevel = 0
    if p and p.metadata and p.metadata.security_level then
        securityLevel = p.metadata.security_level or 0
    elseif isApartment then
        securityLevel = lib.callback.await('LNS_Housing:server:getApartmentSecurityLevel', false, propertyId) or 0
    end
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    local rounds = {}
    local totalRounds = config.rounds + 1
    for i = 1, totalRounds do
        rounds[i] = { areaSize = config.area, speedMultiplier = config.speed }
    end
    local success = Bridge.Client.SkillCheck(rounds, { 'w', 'a', 's', 'd' })

    if success then
        TriggerServerEvent('LNS_Housing:server:lockpickSuccess', propertyId, 'stash', stashId)
        Bridge.Client.Notify('You successfully picked the stash lock!', 'success')
        Bridge.Client.OpenInventory('stash', stashId)
    else
        Bridge.Client.Notify('You failed to pick the stash lock.', 'error')
    end
end

function ApplyWallColor(interiorId, color, customEntitySet)
    if not interiorId or interiorId == 0 then return end
    
    local setsToTry = {}
    if customEntitySet then
        table.insert(setsToTry, customEntitySet)
    end
    
    if insideApartment and CurrentApartmentId then
        local roomId = tonumber(CurrentApartmentId)
        if roomId then
            local modRoom = roomId % 100
            if modRoom ~= roomId and modRoom > 0 then
                table.insert(setsToTry, "wall_tint_" .. modRoom)
            end
            table.insert(setsToTry, "wall_tint_" .. roomId)
        end
    end

    table.insert(setsToTry, "wall_tint")

    for _, setName in ipairs(setsToTry) do
        ActivateInteriorEntitySet(interiorId, setName)
        SetInteriorEntitySetColor(interiorId, setName, color or 0)
    end

    RefreshInterior(interiorId)
    
    pcall(function()
        SetInteriorProbeLength(50.0)
    end)
end

function IsCoordsInsidePropertyZone(propertyId, coords)
    if not propertyId or not coords then return true end
    local p = Properties[propertyId]
    if not p then return true end

    local isMlo = not p.metadata or not p.metadata.shell or p.metadata.shell == 'mlo' or p.metadata.mlo == true or p.metadata.interior_id ~= nil
    if isMlo then
        local targetInterior = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        local entranceCoords = GetEntranceCoords(p) or (p.metadata and p.metadata.entrance and vec3(p.metadata.entrance.x, p.metadata.entrance.y, p.metadata.entrance.z))
        local expectedInterior = (p.metadata and p.metadata.interior_id) or (entranceCoords and GetInteriorAtCoords(entranceCoords.x, entranceCoords.y, entranceCoords.z))

        if expectedInterior and expectedInterior ~= 0 then
            if targetInterior == expectedInterior then
                if entranceCoords and #(coords - entranceCoords) > 75.0 then
                    return false
                end
                return true
            else
                return false
            end
        elseif targetInterior ~= 0 and entranceCoords and #(coords - entranceCoords) <= 60.0 then
            return true
        end
    end

    if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
        local shellName = p.metadata.shell
        local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or (Settings.Shells and Settings.Shells[shellName])
        local isIpl = shellData and shellData.ipls ~= nil
        local entranceCoords = GetEntranceCoords(p)
        local shellCenter = isIpl and vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z) or (entranceCoords and vec3(entranceCoords.x, entranceCoords.y, Settings.ShellSpawningZ or -100.0))
        if shellCenter then
            local maxRadius = (shellData and shellData.maxRadius) or (isIpl and 80.0) or 30.0
            return #(coords - shellCenter) <= maxRadius
        end
    end

    local zone = PropertyZones[propertyId]
    if zone and zone.contains then
        return zone:contains(coords)
    end

    return true
end

local function ParseVector3(data)
    if not data then return vec3(0.0, 0.0, 0.0) end
    if type(data) == 'vector3' then return data end
    return vec3(
        tonumber(data.x or data[1] or 0.0),
        tonumber(data.y or data[2] or 0.0),
        tonumber(data.z or data[3] or 0.0)
    )
end

function LoadFurnitures(propertyId)
    local p = Properties[propertyId]
    if not p or not p.furniture then return end
    
    if LoadedFurniture[propertyId] then return end
    LoadedFurniture[propertyId] = {}

    for _, f in ipairs(p.furniture) do
        CreateThread(function()
            local hash = tonumber(f.model) or GetHashKey(f.model)
            
            if IsModelInCdimage(hash) and IsModelValid(hash) then
                local success = pcall(lib.requestModel, hash, 1000)
                if success then
                    if not LoadedFurniture[propertyId] then return end
                    
                    local pos = ParseVector3(f.position)
                    local rot = ParseVector3(f.rotation)
                    local obj = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
                    if DoesEntityExist(obj) then
                        SetEntityRotation(obj, rot.x, rot.y, rot.z, 2, true)
                        FreezeEntityPosition(obj, true)

                        if f.textureVariation then
                            SetObjectTextureVariation(obj, tonumber(f.textureVariation))
                        end
                        
                        local itemData = nil
                        for _, cat in ipairs(Furniture) do
                            for _, item in ipairs(cat.items) do
                                if (tonumber(item.model) or GetHashKey(item.model)) == (tonumber(f.model) or GetHashKey(f.model)) then
                                    itemData = item
                                    break
                                end
                            end
                            if itemData then break end
                        end

                        if itemData and itemData.isStorage then
                            local stashId = string.format('housing_%s_%s', tostring(propertyId), tostring(f.id))
                            local isTrash = itemData.isTrash or itemData.type == 'trash' or itemData.isDisposal or itemData.type == 'disposal'
                            local isFridge = not isTrash and (itemData.isFridge or itemData.type == 'fridge' or (itemData.id and tostring(itemData.id):lower():find('fridge')))
                            local stashLabel = f.label or itemData.label or (isTrash and 'Trash Can' or (isFridge and 'Refrigerator' or 'Storage Unit'))

                            if isTrash then
                                exports.ox_target:addLocalEntity(obj, {
                                    {
                                        label = 'Open Waste Bin',
                                        icon = 'fas fa-trash-can',
                                        debug = Settings.Debug.Zones,
                                        onSelect = function()
                                            Bridge.Client.OpenStash(propertyId, f.id)
                                        end,
                                        canInteract = function()
                                            return true
                                        end
                                    }
                                })
                            else
                                exports.ox_target:addLocalEntity(obj, {
                                    {
                                        label = isFridge and 'Open Refrigerator' or 'Open Storage',
                                        icon = isFridge and 'fas fa-snowflake' or 'fas fa-box-open',
                                        debug = Settings.Debug.Zones,
                                        onSelect = function()
                                            OpenStorageHandler(propertyId, f.id, stashId, stashLabel, isFridge)
                                        end,
                                        canInteract = function()
                                            return true
                                        end
                                    },
                                    {
                                        label = isFridge and 'Lock/Unlock Refrigerator' or 'Lock/Unlock Storage',
                                        icon = 'fas fa-key',
                                        debug = Settings.Debug.Zones,
                                        onSelect = function()
                                            local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'storage')
                                            if not hasAccess then
                                                Bridge.Client.Notify('You do not have permission to lock/unlock this ' .. (isFridge and 'refrigerator.' or 'storage.'), 'error')
                                                return
                                            end
                                            TriggerServerEvent('LNS_Housing:server:toggleStashLock', propertyId, stashId)
                                        end,
                                        canInteract = function()
                                            return HasPropertyAccessLocal(p, 'storage')
                                        end
                                    },
                                    {
                                        label = isFridge and 'Reset Refrigerator Passcode' or 'Reset Storage Passcode',
                                        icon = 'fas fa-shield-alt',
                                        debug = Settings.Debug.Zones,
                                        onSelect = function()
                                            ResetStoragePasscodeHandler(propertyId, f.id, stashId, stashLabel, isFridge)
                                        end,
                                        canInteract = function()
                                            return HasPropertyAccessLocal(p, 'storage')
                                        end
                                    },
                                    {
                                        label = isFridge and 'Lockpick Refrigerator' or 'Lockpick Storage',
                                        icon = 'fas fa-mask',
                                        items = Settings.Security.LockpickItem,
                                        onSelect = function()
                                            LockpickStash(propertyId, stashId)
                                        end,
                                        canInteract = function()
                                            if itemData.canLockpick == false or itemData.canlockpick == false then return false end
                                            if p.isApartment then
                                                if Settings.Apartments and not Settings.Apartments.CanBreakIn then return false end
                                            else
                                                if Settings.Housing and not Settings.Housing.CanBreakIn then return false end
                                            end
                                            return not HasPropertyAccessLocal(p, 'storage')
                                        end
                                    },
                                    {
                                        label = isFridge and 'Raid Refrigerator' or 'Raid Storage',
                                        icon = 'fas fa-shield-halved',
                                        items = Settings.Security.PoliceAccessTool or 'police_access_tool',
                                        onSelect = function()
                                            StartPoliceStashRaid(propertyId, f.id)
                                        end
                                    }
                                })
                            end
                        end

                        if itemData and itemData.isWardrobe then
                            exports.ox_target:addLocalEntity(obj, {
                                {
                                    label = 'Open Wardrobe',
                                    icon = 'fas fa-shirt',
                                    debug = Settings.Debug.Zones,
                                    onSelect = function()
                                        local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'wardrobe')
                                        if not hasAccess then
                                            Bridge.Client.Notify('You do not have access to this wardrobe.', 'error')
                                            return
                                        end
                                        Bridge.Client.OpenWardrobe(propertyId, f.id)
                                    end,
                                    canInteract = function()
                                        return HasPropertyAccessLocal(p, 'wardrobe')
                                    end
                                }
                            })
                        end

                        if itemData and itemData.isLogout then
                            exports.ox_target:addLocalEntity(obj, {
                                {
                                    label = 'Logout',
                                    icon = 'fas fa-right-from-bracket',
                                    debug = Settings.Debug.Zones,
                                    onSelect = function()
                                        local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'entry')
                                        if not hasAccess then
                                            Bridge.Client.Notify('You do not have permission to log out here.', 'error')
                                            return
                                        end
                                        local alert = lib.alertDialog({
                                            header = 'Confirm Logout',
                                            content = 'Are you sure you want to log out of your character?',
                                            centered = true,
                                            cancel = true,
                                            labels = {
                                                confirm = 'Log out',
                                                cancel = 'Cancel'
                                            }
                                        })
                                        if alert == 'confirm' then
                                            TriggerServerEvent('LNS_Housing:server:logoutPlayer')
                                        end
                                    end,
                                    canInteract = function()
                                        return HasPropertyAccessLocal(p, 'entry')
                                    end
                                }
                            })
                        end

                        if itemData and itemData.id == 'lns_housing_panel' then
                            exports.ox_target:addLocalEntity(obj, {
                                {
                                    label = p.isApartment and 'Open Apartment Panel' or 'Open House Panel',
                                    icon = p.isApartment and 'fas fa-building' or 'fas fa-house-user',
                                    debug = Settings.Debug.Zones,
                                    onSelect = function()
                                        local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'manage')
                                        if not hasAccess then
                                            Bridge.Client.Notify('You do not have permission to manage this property.', 'error')
                                            return
                                        end
                                        local propData = Properties[propertyId]
                                        if propData then
                                            TriggerEvent('LNS_Housing:client:openPanel', propData)
                                        end
                                    end,
                                    canInteract = function()
                                        return Properties[propertyId] and Properties[propertyId].owner and HasPropertyAccessLocal(Properties[propertyId], 'manage')
                                    end
                                }
                            })
                        end

                        if LoadedFurniture[propertyId] then
                            LoadedFurniture[propertyId][f.id] = obj
                        else
                            DeleteEntity(obj)
                        end
                    end
                else
                    lib.print.error(("Model '%s' (hash: %s) timed out loading. Skipping..."):format(tostring(f.model), tostring(hash)))
                end
            else
                lib.print.error(("Model '%s' (hash: %s) is invalid or missing in game assets. Skipping..."):format(tostring(f.model), tostring(hash)))
            end
        end)
    end
end

function UnloadFurnitures(propertyId)
    if not LoadedFurniture[propertyId] then return end
    
    for _, obj in pairs(LoadedFurniture[propertyId]) do
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    end
    
    LoadedFurniture[propertyId] = nil
end

function LoadDoorbellCameraProp(propertyId)
    local p = Properties[propertyId]
    if not p or p.isApartment then return end
    if not (p.metadata and p.metadata.doorbell_camera == true) then return end
    if not p.metadata.camera_coords then return end
    if LoadedCameraProps[propertyId] then return end

    LoadedCameraProps[propertyId] = true

    local coords = ParseVector3(p.metadata.camera_coords)
    local heading = tonumber(p.metadata.camera_heading) or 0.0
    local model = p.metadata.camera_model or DEFAULT_CAMERA_PROP

    if not IsModelValid(model) then
        model = DEFAULT_CAMERA_PROP
    end

    lib.requestModel(model)

    local obj = CreateObjectNoOffset(model, coords.x, coords.y, coords.z, false, false, false)
    
    if DoesEntityExist(obj) then
        SetEntityRotation(obj, 0.0, 0.0, heading, 2, true)
        SetEntityHeading(obj, heading)
        FreezeEntityPosition(obj, true)
        SetEntityCollision(obj, false, false)
        SetEntityAlpha(obj, 255, false)

        Wait(0)

        if DoesEntityExist(obj) then
            local spawnedRot = GetEntityRotation(obj, 2)
            local spawnedHeading = GetEntityHeading(obj)
        end
    end
    SetModelAsNoLongerNeeded(model)

    if LoadedCameraProps[propertyId] == nil then
        if DoesEntityExist(obj) then
            DeleteEntity(obj)
        end
    else
        LoadedCameraProps[propertyId] = obj
    end
end

function UnloadDoorbellCameraProp(propertyId)
    local obj = LoadedCameraProps[propertyId]
    if obj and obj ~= true and DoesEntityExist(obj) then
        DeleteEntity(obj)
    end
    LoadedCameraProps[propertyId] = nil
end

local currentWalkInProperty = nil

local function ResolveWalkInProperty(interiorId)
    if not interiorId or interiorId == 0 or not Properties then return nil end
    local ped = cache.ped or PlayerPedId()
    local coords = GetEntityCoords(ped)

    for id, p in pairs(Properties) do
        if not p.isApartment then
            local isMlo = not p.metadata or not p.metadata.shell or p.metadata.shell == 'mlo' or p.metadata.mlo == true or p.metadata.interior_id ~= nil
            if isMlo then
                local entranceCoords = GetEntranceCoords(p) or (p.metadata and p.metadata.entrance and vec3(p.metadata.entrance.x, p.metadata.entrance.y, p.metadata.entrance.z))
                if entranceCoords and #(coords - entranceCoords) < 65.0 then
                    local propInterior = (p.metadata and p.metadata.interior_id) or GetInteriorAtCoords(entranceCoords.x, entranceCoords.y, entranceCoords.z)
                    if propInterior == interiorId then
                        return id
                    end
                end
            end
        end
    end
    return nil
end

local function EnterWalkInProperty(propertyId)
    if currentWalkInProperty == propertyId then return end
    currentWalkInProperty = propertyId
    InsidePropertyId = propertyId
    TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', propertyId)
    LoadFurnitures(propertyId)
    if CheckPropertyTemperatureNotify then CheckPropertyTemperatureNotify(propertyId) end

    if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', propertyId, 'furniture') then
        HasFurnitureManagePermission = true
        if not Settings.FurnitureMenu or not Settings.FurnitureMenu.Radial or Settings.FurnitureMenu.Radial.Enabled then
            lib.addRadialItem({
                id = 'housing_furniture',
                icon = 'couch',
                label = 'Furniture Menu',
                onSelect = function()
                    TriggerEvent('LNS_Housing:client:openFurnitureMenu', propertyId)
                end
            })
        end
    end
end

local function LeaveWalkInProperty()
    if not currentWalkInProperty then return end
    local oldPropId = currentWalkInProperty
    currentWalkInProperty = nil
    if InsidePropertyId == oldPropId then
        InsidePropertyId = nil
        HasFurnitureManagePermission = false
    end
    lib.removeRadialItem('housing_furniture')
    UnloadFurnitures(oldPropId)
    TriggerServerEvent('LNS_Housing:server:leavePropertyBucket')
end

CreateThread(function()
    while true do
        Wait(500)
        local ped = cache.ped or PlayerPedId()
        local interiorId = GetInteriorFromEntity(ped)

        if interiorId ~= 0 then
            local matchedPropertyId = ResolveWalkInProperty(interiorId)
            if matchedPropertyId then
                if currentWalkInProperty ~= matchedPropertyId then
                    LeaveWalkInProperty()
                    EnterWalkInProperty(matchedPropertyId)
                end
            else
                if currentWalkInProperty then
                    LeaveWalkInProperty()
                end
            end
        else
            if currentWalkInProperty then
                LeaveWalkInProperty()
            end
        end
    end
end)

function RegisterPropertyZones(p, forceShell)
    if RegisterYardZone then
        RegisterYardZone(p)
    end
    if PropertyZones[p.id] then return end

    if p.zone_data and p.zone_data.points and #p.zone_data.points >= 3 then
        local isMlo = not p.metadata or not p.metadata.shell or p.metadata.shell == 'mlo'
        if not isMlo then return end

        local thickness = p.zone_data.thickness or 10.0
        local points = {}
        for i = 1, #p.zone_data.points do
            local pt = p.zone_data.points[i]
            points[i] = vector3(pt.x, pt.y, pt.z + (thickness / 2))
        end

        PropertyZones[p.id] = lib.zones.poly({
            points = points,
            thickness = thickness,
            debug = Settings.Debug.Zones,
            onEnter = function()
                LoadFurnitures(p.id)
                if CheckPropertyTemperatureNotify then CheckPropertyTemperatureNotify(p.id) end
                if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', p.id, 'furniture') then
                    InsidePropertyId = p.id
                    HasFurnitureManagePermission = true
                    if not Settings.FurnitureMenu or not Settings.FurnitureMenu.Radial or Settings.FurnitureMenu.Radial.Enabled then
                        lib.addRadialItem({
                            id = 'housing_furniture',
                            icon = 'couch',
                            label = 'Furniture Menu',
                            onSelect = function()
                                TriggerEvent('LNS_Housing:client:openFurnitureMenu', p.id)
                            end
                        })
                    end
                end
            end,
            onExit = function()
                UnloadFurnitures(p.id)
                lib.removeRadialItem('housing_furniture')
                if InsidePropertyId == p.id then
                    InsidePropertyId = nil
                    HasFurnitureManagePermission = false
                end
            end
        })
    end
end

function HasPropertyAccessLocal(p, action)
    if not p then return false end
    
    local identifier = Bridge.Client.GetIdentifier()
    local job = Bridge.Client.GetPlayerJob()
    local isAgent = false

    if job and Settings.RealEstate and Settings.RealEstate.Jobs then
        for _, rJob in ipairs(Settings.RealEstate.Jobs) do
            if job.name == rJob then
                isAgent = true
                break
            end
        end
    end

    if not p.owner or p.owner == "" then
        return false
    end

    if p.owner == identifier then
        return true
    end

    local act = action or 'entry'
    if p.permissions and type(p.permissions) == 'table' then
        if p.permissions[act] and type(p.permissions[act]) == 'table' then
            for _, cid in ipairs(p.permissions[act]) do
                if cid == identifier then
                    return true
                end
            end
        elseif act == 'entry' and #p.permissions > 0 then
            for _, cid in ipairs(p.permissions) do
                if cid == identifier then
                    return true
                end
            end
        end
    end

    if job and job.name == 'police' then
        if action ~= 'storage' and action ~= 'stash' then
            return true
        end
    end

    return false
end

local function RemoveEntranceTarget(id)
    if not EntranceTargets[id] then return end
    pcall(function()
        local target = EntranceTargets[id]
        if type(target) == 'table' and target.type == 'entity' then
            exports.ox_target:removeLocalEntity(target.entity, target.names)
        elseif type(target) == 'number' or type(target) == 'string' then
            exports.ox_target:removeZone(target)
        end
    end)
    EntranceTargets[id] = nil
end

function RegisterPropertyEntranceTargets(p)
    if not p then return end
    local id = p.id
    
    RemoveEntranceTarget(id)

    if p.isApartment then return end

    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end

    local targetCoords, targetHeading
    local isShell = p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo'
    local doorEnt = nil

    if doorId and doorId ~= 0 then
        local door = GetOxDoorlockDoor(doorId)
        local dModel = door and door.model or (p.metadata and p.metadata.doorModel)
        local dCoords = door and door.coords or (p.metadata and p.metadata.doorCoords)
        local dHeading = door and door.heading or (p.metadata and p.metadata.doorHeading) or 0.0

        if door and GetResourceState('ox_doorlock') == 'started' then
            local doorsList = door.doors or { door }
            for _, d in ipairs(doorsList) do
                local ent = d.object or d.entity
                if (not ent or ent == 0 or not DoesEntityExist(ent)) and d.coords then
                    local modelHash = d.model and (tonumber(d.model) or joaat(d.model)) or 0
                    if modelHash ~= 0 then
                        ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 3.0, modelHash, false, false, false)
                    end
                    if not ent or ent == 0 then
                        ent = GetClosestObjectOfType(d.coords.x, d.coords.y, d.coords.z, 3.0, 0, false, false, false)
                    end
                end
                if ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3 then
                    doorEnt = ent
                    break
                end
            end
        end

        if dCoords then
            targetCoords, targetHeading = ResolveDoorTargetPlacement(dModel, dCoords, dHeading, door)
        end
    end

    if not targetCoords then
        local entranceCoords = p.metadata and p.metadata.entrance
        if entranceCoords then
            targetCoords = vec3(entranceCoords.x, entranceCoords.y, entranceCoords.z)
            targetHeading = entranceCoords.h or 0.0
        end
    end

    if not doorEnt and targetCoords then
        local ent = GetClosestObjectOfType(targetCoords.x, targetCoords.y, targetCoords.z, 2.5, 0, false, false, false)
        if ent and ent ~= 0 and DoesEntityExist(ent) and GetEntityType(ent) == 3 then
            doorEnt = ent
        end
    end

    if not targetCoords and not doorEnt then return end

    local options = {}

    table.insert(options, {
        name = 'lns_house_enter_' .. id,
        label = 'Enter Property',
        icon = 'fas fa-door-open',
        canInteract = function()
            if not isShell then return false end
            return HasPropertyAccessLocal(Properties[id], 'entry')
        end,
        onSelect = function()
            if Settings.Security.PhysicalKeys and Settings.Security.PhysicalKeys.Enabled then
                local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'entry')
                if not hasAccess then
                    Bridge.Client.Notify('You need a key to enter this property.', 'error')
                    return
                end
            else
                local prop = Properties[id]
                local isLocked = prop and prop.metadata and prop.metadata.locked ~= false
                if isLocked then
                    local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'entry')
                    if not hasAccess then
                        Bridge.Client.Notify('This property is locked.', 'error')
                        return
                    end
                end
            end

            EnterShellProperty(id)
        end
    })

    table.insert(options, {
        name = 'lns_house_rent_' .. id,
        label = 'Pay Rent / Debt',
        icon = 'fas fa-dollar-sign',
        canInteract = function()
            local prop = Properties[id]
            if not prop or prop.sale_type ~= 'rent' or prop.owner ~= Bridge.Client.GetIdentifier() then return false end
            local hasDebt = (prop.metadata.rent_debt and prop.metadata.rent_debt > 0) or (prop.metadata.last_rent_paid and (GetCloudTimeAsInt() - prop.metadata.last_rent_paid > (Settings.Rent and Settings.Rent.RentPeriod or 604800)))
            return hasDebt
        end,
        onSelect = function()
            local prop = Properties[id]
            prop.focusTab = 'rent'
            TriggerEvent('LNS_Housing:client:openPanel', prop)
        end
    })

    table.insert(options, {
        name = 'lns_house_belongings_' .. id,
        label = 'Retrieve Belongings',
        icon = 'fas fa-box-open',
        canInteract = function()
            local prop = Properties[id]
            if not prop or prop.sale_type ~= 'rent' or prop.owner ~= Bridge.Client.GetIdentifier() then return false end
            if not isShell then return false end
            local isOverdue = prop.metadata and prop.metadata.due_by and (GetCloudTimeAsInt() > prop.metadata.due_by)
            return isOverdue
        end,
        onSelect = function()
            OpenBelongingsRetrieval(id)
        end
    })

    table.insert(options, {
        name = 'lns_house_lock_' .. id,
        label = 'Lock/Unlock ' .. p.label,
        icon = 'fas fa-key',
        canInteract = function()
            if doorId and doorId ~= 0 then return false end
            return HasPropertyAccessLocal(Properties[id], 'entry')
        end,
        onSelect = function()
            TriggerServerEvent('LNS_Housing:server:toggleLock', id)
        end
    })

    if Settings.Housing and Settings.Housing.CanBreakIn then
        table.insert(options, {
            name = 'lns_house_lockpick_' .. id,
            label = 'Lockpick ' .. p.label,
            icon = 'fas fa-mask',
            items = Settings.Security.LockpickItem,
            canInteract = function()
                local prop = Properties[id]
                if not prop then return false end
                local isLocked = prop.metadata.locked ~= false
                if not isLocked then return false end
                return not HasPropertyAccessLocal(prop, 'entry')
            end,
            onSelect = function()
                LockpickDoor(id)
            end
        })
    end

    table.insert(options, {
        name = 'lns_house_breach_' .. id,
        label = 'Breach Door',
        icon = 'fas fa-shield-halved',
        items = Settings.Security.RaidItem,
        canInteract = function()
            local job = Bridge.Client.GetPlayerJob()
            if not job or job.name ~= 'police' then return false end
            if IsPropertyBreached and IsPropertyBreached(id, doorId) then
                return false
            end
            return true
        end,
        onSelect = function()
            StartPoliceRaid(id, 'house', doorId)
        end
    })

    table.insert(options, {
        name = 'lns_house_secure_' .. id,
        label = 'Secure Door',
        icon = 'fas fa-lock',
        canInteract = function()
            local job = Bridge.Client.GetPlayerJob()
            if not job or job.name ~= 'police' then return false end
            local isDoorBreached = IsPropertyBreached and IsPropertyBreached(id, doorId)
            local prop = Properties[id]
            local isUnlocked = prop and prop.metadata and prop.metadata.locked == false
            return isDoorBreached or isUnlocked
        end,
        onSelect = function()
            TriggerServerEvent('LNS_Housing:server:policeSecureDoor', id, 'house', doorId)
        end
    })

    table.insert(options, {
        name = 'lns_house_doorbell_' .. id,
        label = 'Ring Doorbell',
        icon = 'fas fa-bell',
        onSelect = function()
            TriggerServerEvent('LNS_Housing:server:ringDoorbell', id)
        end
    })

    EntranceTargets[id] = exports.ox_target:addBoxZone({
        coords = targetCoords,
        size = isShell and vec3(1.2, 1.5, 2.0) or vec3(1.5, 1.5, 2.0),
        rotation = targetHeading,
        debug = Settings.Debug.Zones,
        options = options
    })

    if RegisterBreakerTarget then RegisterBreakerTarget(id) end
end

function CleanUpHousingSession()
    lib.hideTextUI()
    lib.removeRadialItem('housing_furniture')

    SetNuiFocus(false, false)

    if Modeler then
        if Modeler.CurrentObject and DoesEntityExist(Modeler.CurrentObject) then
            DeleteEntity(Modeler.CurrentObject)
        end
        if Modeler.HoverObject and DoesEntityExist(Modeler.HoverObject) then
            DeleteEntity(Modeler.HoverObject)
        end
        if Modeler.Cart then
            for _, item in pairs(Modeler.Cart) do
                if item.entity and DoesEntityExist(item.entity) then
                    DeleteEntity(item.entity)
                end
            end
        end
        if Modeler.IsFreecamMode then
            pcall(function()
                Freecam:SetActive(false)
            end)
        end
    end
    
    if LoadedFurniture then
        for propertyId, _ in pairs(LoadedFurniture) do
            UnloadFurnitures(propertyId)
        end
    end

    if LoadedCameraProps then
        for propertyId, _ in pairs(LoadedCameraProps) do
            UnloadDoorbellCameraProp(propertyId)
        end
    end
    
    if PropertyZones then
        for id, zone in pairs(PropertyZones) do
            if zone and zone.remove then
                pcall(function()
                    zone:remove()
                end)
            end
        end
        PropertyZones = {}
    end

    for id, zone in pairs(MotionZones) do
        if zone and zone.remove then
            pcall(function() zone:remove() end)
        end
    end
    MotionZones = {}

    if CurrentInterior and CurrentInterior ~= 0 then
        DeactivateInteriorEntitySet(CurrentInterior, "wall_tint")
        RefreshInterior(CurrentInterior)
    end

    if CleanUpLawn then
        CleanUpLawn()
    end

    
    for propertyId, entity in pairs(SpawnedShells) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    SpawnedShells = {}

    for propertyId, targetId in pairs(ExitTargets) do
        exports.ox_target:removeZone(targetId)
    end
    ExitTargets = {}

    for propertyId, _ in pairs(EntranceTargets) do
        RemoveEntranceTarget(propertyId)
    end
    EntranceTargets = {}

    ClearPropertyBlips()

    if Properties then
        for id, p in pairs(Properties) do
            Bridge.Client.UnregisterGarage(id)
        end
    end

    LeaveWalkInProperty()
    Properties = {}
    CurrentProperty = nil
    CurrentInterior = 0
end

function InitializeHousing()
    CleanUpHousingSession()

    local ped = PlayerPedId()
    local playerCoords = GetEntityCoords(ped)
    local isSpawningInShell = playerCoords.z < -70.0

    if not isSpawningInShell then
        for _, shellData in pairs(Settings.Shells) do
            if shellData.ipls and shellData.coords then
                if #(playerCoords - vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)) < 35.0 then
                    isSpawningInShell = true
                    break
                end
            end
        end
        if not isSpawningInShell and Settings.IPLs then
            for _, iplData in pairs(Settings.IPLs) do
                if iplData.coords then
                    if #(playerCoords - vec3(iplData.coords.x, iplData.coords.y, iplData.coords.z)) < 85.0 then
                        isSpawningInShell = true
                        break
                    end
                end
            end
        end
    end

    if isSpawningInShell then
        DoScreenFadeOut(0)
        FreezeEntityPosition(ped, true)
    end

    Properties = lib.callback.await('LNS_Housing:server:getProperties', false)

    if Properties then
        UpdatePropertyBlips()

        for id, p in pairs(Properties) do
            RegisterPropertyZones(p)
            RegisterDoorbellMotionZone(p)
            if p.metadata and p.metadata.garage_data then
                Bridge.Client.RegisterGarage(p.id, p.label, p.metadata.garage_data)
            end
        end

        CreateThread(function()
            Wait(1500) 
            for id, p in pairs(Properties) do
                RegisterPropertyEntranceTargets(p)
            end
        end)
    end

    if isSpawningInShell then
        local currentPropId = nil
        local foundShellCoords = nil
        if Properties then
            for id, p in pairs(Properties) do
                if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
                    local shellName = p.metadata.shell or 'Standard Motel'
                    local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
                    if shellData then
                        local shellCoords
                        if shellData.ipls then
                            shellCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
                        else
                            local doorCoords = GetEntranceCoords(p)
                            if doorCoords then
                                shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)
                            end
                        end

                        local isIpl = shellData.ipls ~= nil
                        if shellCoords and #(playerCoords - shellCoords) < (isIpl and 85.0 or 35.0) then
                            currentPropId = p.id
                            foundShellCoords = shellCoords
                            break
                        end
                    end
                end
            end
        end

        if currentPropId then
            local p = Properties[currentPropId]
            local shellName = p.metadata.shell or 'Standard Motel'
            local shellEntity, spawnCoords, heading = SpawnShellForProperty(currentPropId, shellName, foundShellCoords)
            
            InsidePropertyId = currentPropId
            TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', currentPropId)
            LoadFurnitures(currentPropId)

            local currentPed = PlayerPedId()
            RequestCollisionAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
            local startColl = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(currentPed) and (GetGameTimer() - startColl) < 3000 do
                Wait(50)
                currentPed = PlayerPedId()
                RequestCollisionAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
            end
            Wait(150)
            SetEntityCoords(currentPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false, false)
        end
        FreezeEntityPosition(PlayerPedId(), false)
        DoScreenFadeIn(1000)
    else
        local playerData = Bridge.Framework == 'qbx' and exports.qbx_core:GetPlayerData() or nil
        local lnsProperty = playerData and playerData.metadata and playerData.metadata.lnsProperty
        if lnsProperty and lnsProperty.id and Properties then
            local propId = tonumber(lnsProperty.id)
            local p = propId and Properties[propId]
            if p and p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
                Wait(500)
                SpawnInHouse(propId)
            end
        end
    end
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end
    Wait(1000)

    local hasIdentifier = Bridge.Client.GetIdentifier()
    if hasIdentifier then
        InitializeHousing()
    end
end)


local isHousingLoaded = false
local function OnClientHousingPlayerLoaded()
    if isHousingLoaded then return end
    isHousingLoaded = true
    debugPrint('info', 'Housing playerLoaded received')
    InitializeHousing()
end

local function OnClientHousingPlayerUnloaded()
    isHousingLoaded = false
    debugPrint('info', 'Housing playerLoggedOut received')
    CleanUpHousingSession()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', OnClientHousingPlayerLoaded)
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    debugPrint('info', 'esx:playerLoaded received', {identifier = xPlayer and xPlayer.identifier})
    OnClientHousingPlayerLoaded()
end)

AddStateBagChangeHandler('isLoggedIn', nil, function(bagName, key, value)
    if bagName == ('player:%s'):format(GetPlayerServerId(PlayerId())) then
        if value then
            OnClientHousingPlayerLoaded()
        else
            OnClientHousingPlayerUnloaded()
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:cleanUpHousingSession', CleanUpHousingSession)
RegisterNetEvent('qbx_core:client:playerLoggedOut', OnClientHousingPlayerUnloaded)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', OnClientHousingPlayerUnloaded)

CreateThread(function()
    while true do
        local ped = cache.ped or PlayerPedId()
        
        local interiorId = GetInteriorFromEntity(ped)
        if interiorId ~= CurrentInterior then
            CurrentInterior = interiorId
            
            if interiorId ~= 0 then
                for id, p in pairs(Properties) do
                    local door = p.door_id and GetOxDoorlockDoor(p.door_id)
                    if door and door.coords and #(GetEntityCoords(ped) - vec3(door.coords.x, door.coords.y, door.coords.z)) < 30.0 then
                        if p.metadata and p.metadata.wall_color and p.metadata.allow_wall_colors then
                            ApplyWallColor(interiorId, p.metadata.wall_color)
                        end
                        break
                    end
                end

                if insideApartment and CurrentApartmentId and Properties[CurrentApartmentId] then
                    local p = Properties[CurrentApartmentId]
                    if p.metadata and p.metadata.wall_color and p.metadata.allow_wall_colors then
                        ApplyWallColor(interiorId, p.metadata.wall_color)
                    end
                end
            end
        end

        if Properties and NetworkIsPlayerActive(PlayerId()) then
            local playerCoords = GetEntityCoords(ped)
            local renderDist = (Settings.Security and Settings.Security.DoorbellCameraRenderDistance) or 80.0

            for propertyId, p in pairs(Properties) do
                if not p.isApartment and p.metadata and p.metadata.doorbell_camera == true and p.metadata.camera_coords then
                    local camCoords = vec3(p.metadata.camera_coords.x, p.metadata.camera_coords.y, p.metadata.camera_coords.z)
                    local dist = #(playerCoords - camCoords)
                    if dist <= renderDist then
                        if not LoadedCameraProps[propertyId] then
                            LoadDoorbellCameraProp(propertyId)
                        end
                    else
                        if LoadedCameraProps[propertyId] then
                            UnloadDoorbellCameraProp(propertyId)
                        end
                    end
                end
            end
        end

        Wait(2000)
    end
end)

RegisterNetEvent('LNS_Housing:client:updateFurniture', function(propertyId, furniture)
    debugPrint('info', 'LNS_Housing:client:updateFurniture received', {propertyId = propertyId, furnitureCount = furniture and #furniture or 0})
    if Properties[propertyId] then
        Properties[propertyId].furniture = furniture
        
        
        if LoadedFurniture[propertyId] then
            UnloadFurnitures(propertyId)
            LoadFurnitures(propertyId)
            
            if Modeler and Modeler.IsMenuActive and Modeler.property_id == propertyId then
                Modeler:UpdateOwnedItems()
            end
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateProperties', function(allProperties)
    debugPrint('info', 'LNS_Housing:client:updateProperties received', {propertiesCount = allProperties and table.type(allProperties) == 'table' and #allProperties or 'many'})
    for k, v in pairs(allProperties) do
        local isNew = Properties[k] == nil
        Properties[k] = v
        if isNew then
            RegisterPropertyZones(v)
            RegisterPropertyEntranceTargets(v)
            RegisterDoorbellMotionZone(v)
        else
            RegisterPropertyEntranceTargets(v)
            if ActiveYardPropertyId == k and RefreshYardGrass then
                RefreshYardGrass(k)
            end
            RegisterDoorbellMotionZone(v)
        end

        if LoadedCameraProps[k] then
            if not v.metadata or v.metadata.doorbell_camera ~= true or not v.metadata.camera_coords then
                UnloadDoorbellCameraProp(k)
            else
                if DoesEntityExist(LoadedCameraProps[k]) then
                    local entityCoords = GetEntityCoords(LoadedCameraProps[k])
                    local coordsChanged = #(entityCoords - vec3(v.metadata.camera_coords.x, v.metadata.camera_coords.y, v.metadata.camera_coords.z)) > 0.1

                    local wantedModel = v.metadata.camera_model and (tonumber(v.metadata.camera_model) or GetHashKey(v.metadata.camera_model))
                    local modelChanged = wantedModel and GetEntityModel(LoadedCameraProps[k]) ~= wantedModel

                    if coordsChanged or modelChanged then
                        UnloadDoorbellCameraProp(k)
                    end
                else
                    LoadedCameraProps[k] = nil
                end
            end
        end

        if not LoadedCameraProps[k] and v.metadata and v.metadata.doorbell_camera == true and v.metadata.camera_coords then
            local playerPed = cache.ped or PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local renderDist = (Settings.Security and Settings.Security.DoorbellCameraRenderDistance) or 80.0
            local camCoords = vec3(v.metadata.camera_coords.x, v.metadata.camera_coords.y, v.metadata.camera_coords.z)
            if #(playerCoords - camCoords) <= renderDist then
                LoadDoorbellCameraProp(k)
            end
        end

        if v.metadata and v.metadata.garage_data then
            Bridge.Client.RegisterGarage(v.id, v.label, v.metadata.garage_data)
        else
            Bridge.Client.UnregisterGarage(v.id)
        end
    end
    
    for k, v in pairs(Properties) do
        if not allProperties[k] then
            RemoveEntranceTarget(k)
            Bridge.Client.UnregisterGarage(k)
            ClearDoorbellMotionZone(k)
            Properties[k] = nil
        end
    end

    UpdatePropertyBlips()

    SendNUIMessage({
        action = 'updateProperties',
        data = Properties
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CleanUpHousingSession()
end)



SpawnedShells = {}
ExitTargets = {}

function GetEntranceCoords(p)
    if not p then return nil end

    if p.metadata and p.metadata.entrance then
        local ent = p.metadata.entrance
        return vec3(ent.x, ent.y, ent.z)
    end

    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end

    if doorId and doorId ~= 0 then
        local door = GetOxDoorlockDoor(doorId)
        if door and door.coords then
            return vec3(door.coords.x, door.coords.y, door.coords.z)
        end
        if p.metadata and p.metadata.doorCoords then
            local dc = p.metadata.doorCoords
            return vec3(dc.x, dc.y, dc.z)
        end
    end

    if p.zone_data and p.zone_data.points and #p.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #p.zone_data.points
        for _, pt in ipairs(p.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        return vec3(sumX / count, sumY / count, sumZ / count)
    end

    return nil
end

function ClearPropertyBlips()
    for id, blip in pairs(PropertyBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    PropertyBlips = {}
end

function UpdatePropertyBlips()
    ClearPropertyBlips()

    if not Settings.Housing.Blips then return end

    local playerIdentifier = Bridge.Client.GetIdentifier()

    for id, p in pairs(Properties) do
        if not p.isApartment then
            local entranceCoords = GetEntranceCoords(p)
            if entranceCoords then
                local isOwned = p.owner ~= nil and p.owner ~= false and p.owner ~= ""
                local isMyOwned = isOwned and (p.owner == playerIdentifier)
                
                local blipConfig = nil
                if isOwned then
                    blipConfig = Settings.Housing.Blips.Owned
                else
                    blipConfig = Settings.Housing.Blips.ReadyToBuy
                end

                if blipConfig and blipConfig.Enabled then
                    if not isOwned or not blipConfig.ShowOnlyMyOwned or isMyOwned then
                        local blip = AddBlipForCoord(entranceCoords.x, entranceCoords.y, entranceCoords.z)
                        SetBlipSprite(blip, blipConfig.Sprite)
                        SetBlipDisplay(blip, 4)
                        SetBlipScale(blip, blipConfig.Scale)
                        SetBlipColour(blip, blipConfig.Color)
                        SetBlipAsShortRange(blip, true)
                        
                        local blipLabel = p.label
                        if blipConfig.Label and blipConfig.Label ~= "" then
                            blipLabel = string.format("%s - %s", blipConfig.Label, p.label)
                        end

                        BeginTextCommandSetBlipName("STRING")
                        AddTextComponentString(blipLabel)
                        EndTextCommandSetBlipName(blip)

                        PropertyBlips[id] = blip
                    end
                end
            end
        end
    end
end

function SpawnShellForProperty(propertyId, shellName, shellCoords)
    local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
    if not shellData then return nil end

    if shellData.ipls then
        if type(shellData.ipls) == 'table' then
            for _, iplName in ipairs(shellData.ipls) do
                if not IsIplActive(iplName) then
                    RequestIpl(iplName)
                end
            end
        elseif type(shellData.ipls) == 'string' then
            if not IsIplActive(shellData.ipls) then
                RequestIpl(shellData.ipls)
            end
        end

        local spawnCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
        local heading = shellData.coords.w or 0.0

        if not ExitTargets[propertyId] then
            local options = {
                {
                    label = 'Exit Property',
                    icon = 'fas fa-door-closed',
                    onSelect = function()
                        LeaveShellProperty(propertyId)
                    end
                }
            }

            local p = Properties[propertyId]
            if p and p.metadata and p.metadata.entrance then
                table.insert(options, {
                    label = 'Lock/Unlock Property',
                    icon = 'fas fa-key',
                    canInteract = function()
                        return true
                    end,
                    onSelect = function()
                        TriggerServerEvent('LNS_Housing:server:toggleLock', propertyId)
                    end
                })
            end

            local exitCoords = spawnCoords
            if shellData.exitCoords then
                exitCoords = vec3(shellData.exitCoords.x, shellData.exitCoords.y, shellData.exitCoords.z)
            end

            ExitTargets[propertyId] = exports.ox_target:addBoxZone({
                coords = exitCoords,
                size = vec3(1.5, 1.5, 2.0),
                rotation = heading,
                debug = Settings.Debug.Zones,
                options = options
            })
        end

        return nil, spawnCoords, heading
    end

    local shellEntity = SpawnedShells[propertyId]
    if not shellEntity or not DoesEntityExist(shellEntity) then
        local shellHash = tonumber(shellData.hash) or GetHashKey(shellData.hash)
        lib.requestModel(shellHash)
        shellEntity = CreateObjectNoOffset(shellHash, shellCoords.x, shellCoords.y, shellCoords.z, false, false, false)
        FreezeEntityPosition(shellEntity, true)
        SetEntityRotation(shellEntity, 0.0, 0.0, 0.0, 2, true)
        SpawnedShells[propertyId] = shellEntity
    end

    local doorOffset = shellData.doorOffset
    local spawnCoords = GetOffsetFromEntityInWorldCoords(shellEntity, doorOffset.x, doorOffset.y, doorOffset.z)
    local heading = doorOffset.h or 0.0

    if not ExitTargets[propertyId] then
        local options = {
            {
                label = 'Exit Property',
                icon = 'fas fa-door-closed',
                onSelect = function()
                    LeaveShellProperty(propertyId)
                end
            }
        }

        local p = Properties[propertyId]
        if p and p.metadata and p.metadata.entrance then
            table.insert(options, {
                label = 'Lock/Unlock Property',
                icon = 'fas fa-key',
                canInteract = function()
                    return true
                end,
                onSelect = function()
                    TriggerServerEvent('LNS_Housing:server:toggleLock', propertyId)
                end
            })
        end

        ExitTargets[propertyId] = exports.ox_target:addBoxZone({
            coords = spawnCoords,
            size = vec3(1.2, 1.5, 2.0),
            rotation = heading,
            debug = Settings.Debug.Zones,
            options = options
        })
    end

    return shellEntity, spawnCoords, heading
end

function EnterShellProperty(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local shellName = p.metadata.shell or 'Standard Motel'
    local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
    local isIpl = shellData and shellData.ipls ~= nil

    local doorCoords = GetEntranceCoords(p)
    if not doorCoords and not isIpl then
        Bridge.Client.Notify('Entrance coordinates not found!', 'error')
        return
    end

    local shellCoords
    if isIpl and shellData then
        shellCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
    else
        shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)
    end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    local shellEntity, spawnCoords, heading = SpawnShellForProperty(propertyId, shellName, shellCoords)

    if spawnCoords then
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        SetEntityHeading(ped, heading)

        RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        local start = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 2000 do
            Wait(50)
            RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        end
        Wait(150)

        SetEntityCoords(PlayerPedId(), spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        FreezeEntityPosition(PlayerPedId(), false)
    end

    InsidePropertyId = propertyId
    TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', propertyId)
    LoadFurnitures(propertyId)

    if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', propertyId, 'furniture') then
        HasFurnitureManagePermission = true
        if not Settings.FurnitureMenu or not Settings.FurnitureMenu.Radial or Settings.FurnitureMenu.Radial.Enabled then
            lib.addRadialItem({
                id = 'housing_furniture',
                icon = 'couch',
                label = 'Furniture Menu',
                onSelect = function()
                    TriggerEvent('LNS_Housing:client:openFurnitureMenu', propertyId)
                end
            })
        end
    end

    DoScreenFadeIn(1000)
    if CheckPropertyTemperatureNotify then CheckPropertyTemperatureNotify(propertyId) end
end

function LeaveShellProperty(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local doorCoords = GetEntranceCoords(p)
    if not doorCoords then return end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    UnloadFurnitures(propertyId)
    lib.removeRadialItem('housing_furniture')
    if InsidePropertyId == propertyId then
        InsidePropertyId = nil
        HasFurnitureManagePermission = false
    end
    TriggerServerEvent('LNS_Housing:server:leavePropertyBucket')

    if ExitTargets[propertyId] then
        exports.ox_target:removeZone(ExitTargets[propertyId])
        ExitTargets[propertyId] = nil
    end

    if SpawnedShells[propertyId] and DoesEntityExist(SpawnedShells[propertyId]) then
        DeleteEntity(SpawnedShells[propertyId])
        SpawnedShells[propertyId] = nil
    end

    local shellName = p.metadata.shell or 'Standard Motel'
    local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
    if shellData and shellData.ipls then
        if type(shellData.ipls) == 'table' then
            for _, iplName in ipairs(shellData.ipls) do
                if IsIplActive(iplName) then
                    RemoveIpl(iplName)
                end
            end
        elseif type(shellData.ipls) == 'string' then
            if IsIplActive(shellData.ipls) then
                RemoveIpl(shellData.ipls)
            end
        end
    end

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, doorCoords.x, doorCoords.y, doorCoords.z, false, false, false, false)

    RequestCollisionAtCoord(doorCoords.x, doorCoords.y, doorCoords.z)
    local start = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 2000 do
        Wait(50)
        RequestCollisionAtCoord(doorCoords.x, doorCoords.y, doorCoords.z)
    end
    Wait(150)

    SetEntityCoords(PlayerPedId(), doorCoords.x, doorCoords.y, doorCoords.z, false, false, false, false)
    FreezeEntityPosition(PlayerPedId(), false)

    DoScreenFadeIn(1000)
end

RegisterNetEvent('LNS_Housing:client:triggerHouseAlarm', function(coords, durationMs)
    debugPrint('info', 'LNS_Housing:client:triggerHouseAlarm received', {coords = coords, durationMs = durationMs})
    local playerCoords = GetEntityCoords(PlayerPedId())
    local alarmCoords = vec3(coords.x, coords.y, coords.z)
    local shellCoords = vec3(coords.x, coords.y, Settings.ShellSpawningZ or -100.0)
    local isNearEntrance = #(playerCoords - alarmCoords) < 35.0
    local isNearShell = #(playerCoords - shellCoords) < 35.0
    if not isNearShell and Settings.IPLs then
        for _, iplData in pairs(Settings.IPLs) do
            if iplData.coords then
                local iplCoords = vec3(iplData.coords.x, iplData.coords.y, iplData.coords.z)
                if #(playerCoords - iplCoords) < 85.0 then
                    isNearShell = true
                    break
                end
            end
        end
    end
 
    if isNearEntrance or isNearShell then
        activeAlarmsCount = activeAlarmsCount + 1
 
        local bankLoaded = Bridge.Client.LoadAudioBank(AUDIO_BANK, AUDIO_TIMEOUT)
        if not bankLoaded then
            activeAlarmsCount = activeAlarmsCount - 1
            return
        end
 
        local outsideSoundId = Bridge.Client.PlayAudio({
            audioName = "house_alarm",
            audioRef = AUDIO_REF,
            audioSource = alarmCoords,
            range = 25.0,
            returnSoundId = true,
        })
 
        local insideSoundId = Bridge.Client.PlayAudio({
            audioName = "house_alarm",
            audioRef = AUDIO_REF,
            audioSource = shellCoords,
            range = 15.0,
            returnSoundId = true,
        })
 
        Wait(durationMs or 30000)
 
        if outsideSoundId then
            StopSound(outsideSoundId)
            ReleaseSoundId(outsideSoundId)
        end
        if insideSoundId then
            StopSound(insideSoundId)
            ReleaseSoundId(insideSoundId)
        end
 
        activeAlarmsCount = activeAlarmsCount - 1
        if activeAlarmsCount == 0 then
            ReleaseScriptAudioBank()
        end
    end
end)
 
RegisterNetEvent('LNS_Housing:client:triggerHouseDoorbell', function(entranceCoords, insideCoords)
    debugPrint('info', 'LNS_Housing:client:triggerHouseDoorbell received', {entranceCoords = entranceCoords, insideCoords = insideCoords})
    if not entranceCoords then return end
 
    local playerCoords = GetEntityCoords(PlayerPedId())
    local doorCoords = vec3(entranceCoords.x, entranceCoords.y, entranceCoords.z)
    local distToDoor = #(playerCoords - doorCoords)
    local isNearEntrance = distToDoor < 35.0
    local insideVec = nil
    local isNearInside = false

    if insideCoords then
        insideVec = vec3(insideCoords.x, insideCoords.y, insideCoords.z)
        local distToInside = #(playerCoords - insideVec)
        isNearInside = distToInside < 35.0
    end
 
    if not isNearEntrance and not isNearInside then return end
 
    activeDoorbellsCount = activeDoorbellsCount + 1
 
    local bankLoaded = Bridge.Client.LoadAudioBank(AUDIO_BANK, AUDIO_TIMEOUT)
 
    if not bankLoaded then
        activeDoorbellsCount = activeDoorbellsCount - 1
        return
    end
 
    local soundIds = {}
 
    if isNearEntrance then
        Bridge.Client.PlayAudio({
            audioName = "house_doorbell",
            audioRef = AUDIO_REF,
            audioSource = doorCoords,
            range = 5.0,
            returnSoundId = false,
        })
    end
 
    if insideVec and isNearInside then
        Bridge.Client.PlayAudio({
            audioName = "house_doorbell",
            audioRef = AUDIO_REF,
            audioSource = insideVec,
            range = 10.0,
            returnSoundId = false,
        })
    end
 
    Wait(5000)
 
    for _, soundId in ipairs(soundIds) do
        StopSound(soundId)
        ReleaseSoundId(soundId)
    end
 
    activeDoorbellsCount = activeDoorbellsCount - 1
    if activeDoorbellsCount == 0 then
        ReleaseScriptAudioBank()
    end
end)

function GetPropertyCoords(p)
    if not p then return nil end
    
    if p.metadata and p.metadata.spawn then
        local sp = p.metadata.spawn
        return vector4(sp.x, sp.y, sp.z, sp.h or sp.w or 0.0)
    end
    
    return nil
end

function GetEntranceCoordsAndHeading(p)
    if not p then return nil, 0.0 end

    if p.metadata and p.metadata.entrance then
        local ent = p.metadata.entrance
        return vec3(ent.x, ent.y, ent.z), ent.h or ent.w or 0.0
    end

    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end

    if doorId and doorId ~= 0 then
        local door = GetOxDoorlockDoor(doorId)
        if door and door.coords then
            return vec3(door.coords.x, door.coords.y, door.coords.z), door.heading or 0.0
        end
    end

    local propCoords = GetPropertyCoords(p)
    if propCoords then
        return vec3(propCoords.x, propCoords.y, propCoords.z), propCoords.w or 0.0
    end

    if p.zone_data and p.zone_data.points and #p.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #p.zone_data.points
        for _, pt in ipairs(p.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        return vec3(sumX / count, sumY / count, sumZ / count), 0.0
    end

    return nil, 0.0
end

function GetPropertyInsideCoords(p)
    if not p then return nil end

    if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
        local shellName = p.metadata.shell or 'Standard Motel'
        local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
        if shellData then
            if shellData.ipls then
                return vector4(shellData.coords.x, shellData.coords.y, shellData.coords.z, shellData.coords.w or 0.0)
            end
            local doorCoords = GetEntranceCoords(p)
            if doorCoords then
                local shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)
                local doorOffset = shellData.doorOffset
                return vector4(
                    shellCoords.x + doorOffset.x,
                    shellCoords.y + doorOffset.y,
                    shellCoords.z + doorOffset.z,
                    doorOffset.h or 0.0
                )
            end
        end
    else
        local coords = GetPropertyCoords(p)
        local heading = coords and coords.w or 0.0

        local entranceCoords, entranceHeading = GetEntranceCoordsAndHeading(p)
        local isCustomSpawn = false
        if coords and entranceCoords then
            if #(vec3(coords.x, coords.y, coords.z) - entranceCoords) > 2.5 then
                isCustomSpawn = true
            end
        end

        if not isCustomSpawn and entranceCoords then
            local rad = math.rad(entranceHeading)
            local forward = vec3(-math.sin(rad), math.cos(rad), 0.0)
            local pointForward = entranceCoords + forward * 1.5
            local pointBackward = entranceCoords - forward * 1.5

            if IsCoordsInsidePropertyZone(p.id, pointForward) then
                return vector4(pointForward.x, pointForward.y, pointForward.z, entranceHeading)
            elseif IsCoordsInsidePropertyZone(p.id, pointBackward) then
                return vector4(pointBackward.x, pointBackward.y, pointBackward.z, (entranceHeading + 180.0) % 360.0)
            end
        end

        return coords
    end

    return GetPropertyCoords(p)
end

function SpawnInHouse(id)
    id = tonumber(id)
    if not id then return false end

    if not Properties or not Properties[id] then
        Properties = lib.callback.await('LNS_Housing:server:getProperties', false) or {}
    end
    local p = Properties[id]
    if p then
        RegisterPropertyZones(p, true)

        if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
            local shellName = p.metadata.shell or 'Standard Motel'
            local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
            local isIpl = shellData and shellData.ipls ~= nil
            local doorCoords = GetEntranceCoords(p)
            if doorCoords or isIpl then
                local shellCoords
                if isIpl and shellData then
                    shellCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
                else
                    shellCoords = doorCoords and vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0) or vec3(0,0,0)
                end
                SpawnShellForProperty(id, p.metadata.shell, shellCoords)
            end
        end
        local coords = GetPropertyInsideCoords(p)
        if coords then
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do Wait(0) end
            
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
            SetEntityHeading(ped, coords.w or 0.0)
            
            InsidePropertyId = id
            TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', id)
            LoadFurnitures(id)

            if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'furniture') then
                HasFurnitureManagePermission = true
                if not Settings.FurnitureMenu or not Settings.FurnitureMenu.Radial or Settings.FurnitureMenu.Radial.Enabled then
                    lib.removeRadialItem('housing_furniture')
                    lib.addRadialItem({
                        id = 'housing_furniture',
                        icon = 'couch',
                        label = 'Furniture Menu',
                        onSelect = function()
                            TriggerEvent('LNS_Housing:client:openFurnitureMenu', id)
                        end
                    })
                end
            end
            
            RequestCollisionAtCoord(coords.x, coords.y, coords.z)
            local start = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 3000 do
                Wait(50)
                RequestCollisionAtCoord(coords.x, coords.y, coords.z)
            end
            Wait(150)
            
            SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
            FreezeEntityPosition(PlayerPedId(), false)
            
            DoScreenFadeIn(1000)
            if CheckPropertyTemperatureNotify then CheckPropertyTemperatureNotify(id) end
            return true
        end
    end
    return false
end