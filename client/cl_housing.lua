lib.require('@qbx_core.modules.lib')
local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture')
local CurrentProperty = nil
local CurrentInterior = 0
local PropertyBlips = {}
local ClearPropertyBlips, UpdatePropertyBlips
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

RegisterCommand(Settings.Housing.Creator.Command, function(source, args, rawCommand)
    debugPrint('info', 'Creator command run', {args = args})
    local hasPermission = lib.callback.await('LNS_Housing:server:checkPermission', false, 'realestate')
    if not hasPermission then
        Bridge.Client.Notify('You do not have permission to use this command.', 'error')
        return
    end

    local properties = lib.callback.await('LNS_Housing:server:getProperties', false)
    SendNUIMessage({
        action = 'openRealEstate',
        data = {
            properties = properties,
            hasPermission = true,
            activeTab = 'creator',
            onlyBuyViaContracts = Settings.RealEstate.OnlyBuyViaContracts
        }
    })
    SetNuiFocus(true, true)
end, false)


RegisterNUICallback('createHouse', function(data, cb)
    debugPrint('info', 'NUI callback: createHouse', data)
    SetNuiFocus(false, false)

    local zoneCoords = nil

    if data.zone_data and data.zone_data.points and #data.zone_data.points > 0 then
        local sumX, sumY, sumZ = 0, 0, 0
        local count = #data.zone_data.points
        for _, pt in ipairs(data.zone_data.points) do
            sumX = sumX + pt.x
            sumY = sumY + pt.y
            sumZ = sumZ + pt.z
        end
        zoneCoords = vec3(sumX / count, sumY / count, sumZ / count)
    elseif data.entranceCoords then
        zoneCoords = vec3(data.entranceCoords.x, data.entranceCoords.y, data.entranceCoords.z)
    else
        zoneCoords = GetEntityCoords(cache.ped)
    end

    data.region = GetLabelText(GetNameOfZone(zoneCoords.x, zoneCoords.y, zoneCoords.z))

    local success = lib.callback.await('LNS_Housing:server:createHouse', false, data)
    if success then
        Bridge.Client.Notify('House created successfully!', 'success')
    else
        Bridge.Client.Notify('Failed to create house.', 'error')
    end
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('closeUI', function(_, cb)
    debugPrint('info', 'NUI callback: closeUI')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('placeBid', function(data, cb)
    debugPrint('info', 'NUI callback: placeBid', data)
    TriggerServerEvent('LNS_Housing:server:placeBid', data)
    cb('ok')
end)

RegisterNUICallback('controlAuction', function(data, cb)
    debugPrint('info', 'NUI callback: controlAuction', data)
    TriggerServerEvent('LNS_Housing:server:controlAuction', data)
    cb('ok')
end)

RegisterNUICallback('getNearbyPlayers', function(_, cb)
    debugPrint('info', 'NUI callback: getNearbyPlayers')
    local players = GetActivePlayers()
    local playerIds = {}
    for _, player in ipairs(players) do
        table.insert(playerIds, GetPlayerServerId(player))
    end
    
    local resolved = lib.callback.await('LNS_Housing:server:resolvePlayerNames', false, playerIds)
    cb(resolved or {})
end)

RegisterNUICallback('createContract', function(data, cb)
    debugPrint('info', 'NUI callback: createContract', data)
    SetNuiFocus(false, false)
    TriggerServerEvent('LNS_Housing:server:createContract', data)
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('getPendingContracts', function(_, cb)
    debugPrint('info', 'NUI callback: getPendingContracts')
    local results = lib.callback.await('LNS_Housing:server:getPendingContracts', false)
    cb(results or {})
end)

RegisterNUICallback('getAgencyContracts', function(data, cb)
    debugPrint('info', 'NUI callback: getAgencyContracts', data)
    local results = lib.callback.await('LNS_Housing:server:getAgencyContracts', false, data.agency)
    cb(results or {})
end)

RegisterNUICallback('respondToContract', function(data, cb)
    debugPrint('info', 'NUI callback: respondToContract', data)
    SetNuiFocus(false, false)
    local success = lib.callback.await('LNS_Housing:server:respondToContract', false, data.id, data.action)
    SendNUIMessage({ action = 'closeUI' })
    cb(success)
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
    if p and p.metadata then
        securityLevel = p.metadata.security_level or 0
    end
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    TaskPlayAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'ig_3_con_loop', 8.0, -8.0, -1, 49, 0, false, false, false)

    local rounds = {}
    for i = 1, config.rounds do
        rounds[i] = { areaSize = config.area, speedMultiplier = config.speed }
    end
    local success = lib.skillCheck(rounds, { 'w', 'a', 's', 'd' })
    
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
            table.insert(options, {
                title = f.label or itemData.label or 'Storage Unit',
                description = 'Retrieve items from this storage unit',
                icon = 'box',
                arrow = true,
                onSelect = function()
                    Bridge.Client.OpenStash(propertyId, f.id)
                end
            })
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

    local securityLevel = 0
    if p and p.metadata then
        securityLevel = p.metadata.security_level or 0
    end
    local config = Settings.Security.Difficulty[securityLevel] or Settings.Security.Difficulty[0]

    lib.requestAnimDict('anim@amb@prop_human_atm@interior@male@enter')
    TaskPlayAnim(cache.ped, 'anim@amb@prop_human_atm@interior@male@enter', 'enter', 8.0, -8.0, -1, 49, 0, false, false, false)

    local rounds = {}
    local totalRounds = config.rounds + 1
    for i = 1, totalRounds do
        rounds[i] = { areaSize = config.area, speedMultiplier = config.speed }
    end
    local success = lib.skillCheck(rounds, { 'w', 'a', 's', 'd' })
    
    ClearPedTasks(cache.ped)

    if success then
        TriggerServerEvent('LNS_Housing:server:lockpickSuccess', propertyId, 'stash', stashId)
        Bridge.Client.Notify('You successfully picked the stash lock!', 'success')
        exports.ox_inventory:openInventory('stash', stashId)
    else
        Bridge.Client.Notify('You failed to pick the stash lock.', 'error')
    end
end

function ApplyWallColor(interiorId, color)
    if not interiorId or interiorId == 0 then return end
    
    ActivateInteriorEntitySet(interiorId, "wall_tint")
    SetInteriorEntitySetColor(interiorId, "wall_tint", color)
    RefreshInterior(interiorId)
    
    pcall(function()
        SetInteriorProbeLength(50.0)
    end)
end

function IsCoordsInsidePropertyZone(propertyId, coords)
    if not propertyId then return true end
    local zone = PropertyZones[propertyId]
    if not zone then return true end

    if zone.contains then
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
        local hash = tonumber(f.model) or GetHashKey(f.model)
        lib.requestModel(hash)
        
        if not LoadedFurniture[propertyId] then
            break
        end
        
        local pos = ParseVector3(f.position)
        local rot = ParseVector3(f.rotation)
        local obj = CreateObjectNoOffset(hash, pos.x, pos.y, pos.z, false, false, false)
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
            local stashId = string.format('housing_%d_%s', propertyId, f.id)
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Open Storage',
                    icon = 'fas fa-box-open',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        Bridge.Client.OpenStash(propertyId, f.id)
                    end,
                    canInteract = function()
                        local isLocked = lib.callback.await('LNS_Housing:server:isStashLocked', false, stashId)
                        if not isLocked then return true end
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'storage')
                    end
                },
                {
                    label = 'Lock/Unlock Storage',
                    icon = 'fas fa-key',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        TriggerServerEvent('LNS_Housing:server:toggleStashLock', propertyId, stashId)
                    end,
                    canInteract = function()
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'storage')
                    end
                },
                {
                    label = 'Lockpick Storage',
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

                        local isLocked = lib.callback.await('LNS_Housing:server:isStashLocked', false, stashId)
                        if not isLocked then return false end

                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'lockpickStash')
                    end
                },
                {
                    label = 'Raid Storage',
                    icon = 'fas fa-shield-halved',
                    items = Settings.Security.RaidItem,
                    onSelect = function()
                        StartPoliceStashRaid(propertyId, f.id)
                    end,
                    canInteract = function()
                        local job = Bridge.Client.GetPlayerJob()
                        if not job or job.name ~= 'police' then return false end
                        
                        
                        local isDoorBreached = lib.callback.await('LNS_Housing:server:isDoorBreached', false, propertyId)
                        if not isDoorBreached then return false end
                        
                        local hasAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'storage')
                        return not hasAccess
                    end
                }
            })
        end

        if itemData and itemData.isWardrobe then
            exports.ox_target:addLocalEntity(obj, {
                {
                    label = 'Open Wardrobe',
                    icon = 'fas fa-shirt',
                    debug = Settings.Debug.Zones,
                    onSelect = function()
                        Bridge.Client.OpenWardrobe(propertyId, f.id)
                    end,
                    canInteract = function()
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'wardrobe')
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
                        return lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'entry')
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
                        local propData = Properties[propertyId]
                        if propData then
                            TriggerEvent('LNS_Housing:client:openPanel', propData)
                        end
                    end,
                    canInteract = function()
                        return Properties[propertyId] and Properties[propertyId].owner and 
                            lib.callback.await('LNS_Housing:server:checkPermission', false, p.isApartment and 'apartment' or 'house', propertyId, 'manage')
                    end
                }
            })
        end

        LoadedFurniture[propertyId][f.id] = obj
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

function RegisterPropertyZones(p, forceShell)
    if RegisterYardZone then
        RegisterYardZone(p)
    end
    if PropertyZones[p.id] then return end
    
    if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
        local shellName = p.metadata.shell or 'Standard Motel'
        local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
        local isIpl = shellData and shellData.ipls ~= nil

        local doorCoords = GetEntranceCoords(p)
        if doorCoords or isIpl then
            local shellCoords
            if isIpl then
                shellCoords = vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)
            else
                shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)
            end

            local shouldRegister = forceShell
            if not shouldRegister then
                local playerCoords = GetEntityCoords(cache.ped)
                if #(playerCoords - shellCoords) < (isIpl and 100.0 or 35.0) then
                    shouldRegister = true
                end
            end

            if shouldRegister then
                local zoneSize = isIpl and (shellData.zoneSize or vec3(150.0, 150.0, 80.0)) or vec3(25.0, 25.0, 10.0)
                PropertyZones[p.id] = lib.zones.box({
                    coords = shellCoords,
                    size = zoneSize,
                    debug = Settings.Debug.Zones,
                    onEnter = function()
                        local shellName = p.metadata.shell or 'Standard Motel'
                        SpawnShellForProperty(p.id, shellName, shellCoords)

                        LoadFurnitures(p.id)
                        TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', p.id)

                        if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', p.id, 'manage') then
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
                        TriggerServerEvent('LNS_Housing:server:leavePropertyBucket')
                        
                        SetTimeout(0, function()
                            if PropertyZones[p.id] then
                                local zone = PropertyZones[p.id]
                                PropertyZones[p.id] = nil
                                pcall(function()
                                    zone:remove()
                                end)
                            end
                        end)
                    end
                })
            end
        end
    
    elseif p.zone_data and p.zone_data.points and #p.zone_data.points >= 3 then
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
                if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', p.id, 'manage') then
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
    else
        
        local door = p.door_id and GetOxDoorlockDoor(p.door_id)
        local doorCoords = door and door.coords and vec3(door.coords.x, door.coords.y, door.coords.z)
        if not doorCoords and p.metadata and p.metadata.doorCoords then
            local dc = p.metadata.doorCoords
            doorCoords = vec3(dc.x, dc.y, dc.z)
        end

        if doorCoords then
            PropertyZones[p.id] = lib.points.new({
                coords = doorCoords,
                distance = 40,
                onEnter = function()
                    LoadFurnitures(p.id)
                    if lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', p.id, 'manage') then
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
end

local function HasPropertyAccessLocal(p, action)
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

    if p.permissions and p.permissions.entry then
        for _, cid in ipairs(p.permissions.entry) do
            if cid == identifier then
                return true
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

function RegisterPropertyEntranceTargets(p)
    if not p then return end
    local id = p.id
    
    if EntranceTargets[id] then
        pcall(function()
            exports.ox_target:removeZone(EntranceTargets[id])
        end)
        EntranceTargets[id] = nil
    end

    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end

    local targetCoords, targetHeading
    local isShell = p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo'

    if doorId and doorId ~= 0 then
        local door = GetOxDoorlockDoor(doorId)
        local dModel = door and door.model or (p.metadata and p.metadata.doorModel)
        local dCoords = door and door.coords or (p.metadata and p.metadata.doorCoords)
        local dHeading = door and door.heading or (p.metadata and p.metadata.doorHeading) or 0.0

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

    if not targetCoords then return end

    local options = {}

    table.insert(options, {
        label = 'Enter ' .. p.label,
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
            label = 'Lockpick ' .. p.label,
            icon = 'fas fa-mask',
            items = Settings.Security.LockpickItem,
            canInteract = function()
                local prop = Properties[id]
                if not prop then return false end
                local isLocked = prop.metadata.locked ~= false
                if not isLocked then return false end
                return lib.callback.await('LNS_Housing:server:checkPermission', false, 'house', id, 'lockpick')
            end,
            onSelect = function()
                LockpickDoor(id)
            end
        })
    end

    table.insert(options, {
        label = 'Raid House',
        icon = 'fas fa-shield-halved',
        items = Settings.Security.RaidItem,
        canInteract = function()
            local job = Bridge.Client.GetPlayerJob()
            return job and job.name == 'police'
        end,
        onSelect = function()
            StartPoliceRaid(id, 'house', doorId)
        end
    })

    table.insert(options, {
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

    for propertyId, targetId in pairs(EntranceTargets) do
        exports.ox_target:removeZone(targetId)
    end
    EntranceTargets = {}

    ClearPropertyBlips()

    if Properties then
        for id, p in pairs(Properties) do
            Bridge.Client.UnregisterGarage(id)
        end
    end

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
            
            TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', currentPropId)
            LoadFurnitures(currentPropId)

            local currentPed = PlayerPedId()
            RequestCollisionAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
            local startColl = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(currentPed) and (GetGameTimer() - startColl) < 2000 do
                Wait(50)
                currentPed = PlayerPedId()
                RequestCollisionAtCoord(playerCoords.x, playerCoords.y, playerCoords.z)
            end
            Wait(150)
            SetEntityCoords(currentPed, playerCoords.x, playerCoords.y, playerCoords.z, false, false, false, false)
        end
        FreezeEntityPosition(PlayerPedId(), false)
        DoScreenFadeIn(1000)
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


RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    debugPrint('info', 'QBCore:Client:OnPlayerLoaded received')
    InitializeHousing()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    debugPrint('info', 'esx:playerLoaded received', {identifier = xPlayer and xPlayer.identifier})
    InitializeHousing()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    debugPrint('info', 'QBCore:Client:OnPlayerUnload received')
    CleanUpHousingSession()
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    debugPrint('info', 'esx:onPlayerLogout received')
    CleanUpHousingSession()
end)


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
            if EntranceTargets[k] then
                exports.ox_target:removeZone(EntranceTargets[k])
                EntranceTargets[k] = nil
            end
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


function StartPoliceRaid(propertyId, propertyType, doorId)
    local duration = Settings.Security.RaidDuration or 5000

    if lib.progressBar({
        duration = duration,
        label = 'Breaching door lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = {
            dict = 'missheistfbi3b_ig7',
            clip = 'lift_fibagent_loop',
            flags = 49,
        },
    }) then
        TriggerServerEvent('LNS_Housing:server:policeRaidDoor', propertyId, propertyType, doorId)
    else
        Bridge.Client.Notify('Breaching cancelled.', 'error')
    end
end

function StartPoliceStashRaid(propertyId, stashId)
    local duration = Settings.Security.RaidStorageDuration or 5000

    if lib.progressBar({
        duration = duration,
        label = 'Breaching storage lock...',
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = {
            dict = 'missheistfbi3b_ig7',
            clip = 'lift_fibagent_loop',
            flags = 49,
        },
    }) then
        TriggerServerEvent('LNS_Housing:server:policeRaidStash', propertyId)
    else
        Bridge.Client.Notify('Breaching cancelled.', 'error')
    end
end


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
    local doorCoords = GetEntranceCoords(p)
    if not doorCoords then
        Bridge.Client.Notify('Entrance coordinates not found!', 'error')
        return
    end

    local shellCoords = vec3(doorCoords.x, doorCoords.y, Settings.ShellSpawningZ or -100.0)

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

    RegisterPropertyZones(p, true)

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

    DoScreenFadeIn(1000)
end

function LeaveShellProperty(propertyId)
    local p = Properties[propertyId]
    if not p then return end

    local doorCoords = GetEntranceCoords(p)
    if not doorCoords then return end

    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end

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
 
        local bankLoaded = qbx.loadAudioBank(AUDIO_BANK, AUDIO_TIMEOUT)
        if not bankLoaded then
            activeAlarmsCount = activeAlarmsCount - 1
            return
        end
 
        local outsideSoundId = qbx.playAudio({
            audioName = "house_alarm",
            audioRef = AUDIO_REF,
            audioSource = alarmCoords,
            range = 25.0,
            returnSoundId = true,
        })
 
        local insideSoundId = qbx.playAudio({
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
 
    local bankLoaded = qbx.loadAudioBank(AUDIO_BANK, AUDIO_TIMEOUT)
 
    if not bankLoaded then
        activeDoorbellsCount = activeDoorbellsCount - 1
        return
    end
 
    local soundIds = {}
 
    if isNearEntrance then
        qbx.playAudio({
            audioName = "house_doorbell",
            audioRef = AUDIO_REF,
            audioSource = doorCoords,
            range = 5.0,
            returnSoundId = false,
        })
    end
 
    if insideVec and isNearInside then
        qbx.playAudio({
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