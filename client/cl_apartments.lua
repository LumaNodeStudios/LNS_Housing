local Settings = lib.load('shared.settings')
local Furniture = lib.load('shared.furniture') or {}

if not Settings.Apartments or not Settings.Apartments.Enabled then
    return
end

ApartmentRooms = Settings.Rooms

local apartmentBlip = nil
local apartmentPed = nil
insideApartment = false
MyApartmentId = nil
local MyRoomData = nil
apartmentZones = {}
CurrentApartmentId = nil

local isInsideInstance = false
local spawnedInstanceShell = nil
local activeInstanceIpls = {}
local instanceExitTarget = nil
local instanceWardrobeZone = nil
local instanceStashZone = nil
local buildingEntranceTarget = nil

local function IsStarterInstanceMode()
    local cfg = Settings.Apartments and Settings.Apartments.Starter
    return cfg and cfg.Mode == 'instance'
end

local function RegisterBuildingEntranceTarget()
    if buildingEntranceTarget then
        exports.ox_target:removeZone(buildingEntranceTarget)
        buildingEntranceTarget = nil
    end

    if not IsStarterInstanceMode() then return end

    local cfg = Settings.Apartments and Settings.Apartments.Starter
    local entranceCoords = (cfg and cfg.Entrance) or (Settings.Apartments and Settings.Apartments.Building and Settings.Apartments.Building.coords)
    if not entranceCoords then return end

    buildingEntranceTarget = exports.ox_target:addSphereZone({
        coords = vec3(entranceCoords.x, entranceCoords.y, entranceCoords.z),
        radius = 2.0,
        debug = Settings.Debug.Zones,
        options = {
            {
                name = 'apt_enter_mine',
                label = 'Enter My Apartment',
                icon = 'fas fa-key',
                onSelect = function()
                    local assignedRoom = lib.callback.await('LNS_Housing:server:getMyApartment', false)
                    if assignedRoom and assignedRoom.roomData then
                        EnterApartmentRoom(assignedRoom.roomData)
                    else
                        Bridge.Client.Notify('You do not have an apartment assigned.', 'error')
                    end
                end
            },
            {
                name = 'apt_visit_room',
                label = 'Visit Apartment',
                icon = 'fas fa-door-open',
                onSelect = function()
                    local input = lib.inputDialog('Visit Apartment', {
                        { type = 'number', label = 'Room Number', placeholder = 'e.g. 1', required = true, min = 1 }
                    })
                    if not input or not input[1] then return end
                    local targetRoomId = tonumber(input[1])
                    if not targetRoomId then return end

                    local canEnter = lib.callback.await('LNS_Housing:server:canEnterApartment', false, targetRoomId)
                    if canEnter then
                        local roomData = lib.callback.await('LNS_Housing:server:getApartmentRoomData', false, targetRoomId)
                        if roomData then
                            EnterApartmentRoom(roomData)
                        else
                            Bridge.Client.Notify('Could not load apartment data.', 'error')
                        end
                    else
                        local alert = lib.alertDialog({
                            header = 'Apartment #' .. targetRoomId,
                            content = 'You do not have a key to Apartment #' .. targetRoomId .. '. Would you like to ring the doorbell?',
                            centered = true,
                            cancel = true,
                            labels = {
                                confirm = 'Ring Bell',
                                cancel = 'Cancel'
                            }
                        })
                        if alert == 'confirm' then
                            TriggerServerEvent('LNS_Housing:server:ringApartmentDoorbell', targetRoomId)
                        end
                    end
                end
            },
            {
                name = 'apt_manage_keys',
                label = 'Apartment Management',
                icon = 'fas fa-id-card',
                canInteract = function()
                    return MyApartmentId ~= nil
                end,
                onSelect = function()
                    openKeyManagementUI()
                end
            },
            {
                name = 'apt_police_breach',
                label = 'Police Breach Apartment',
                icon = 'fas fa-shield-halved',
                canInteract = function()
                    local job = Bridge.Client.GetPlayerJob()
                    return Bridge.IsPoliceJob(job)
                end,
                onSelect = function()
                    local input = lib.inputDialog('Police Breach Apartment', {
                        { type = 'number', label = 'Room Number to Breach', placeholder = 'e.g. 1', required = true, min = 1 }
                    })
                    if not input or not input[1] then return end
                    local targetRoomId = tonumber(input[1])
                    if not targetRoomId then return end
                    StartPoliceRaid(targetRoomId, 'apartment', nil)
                end
            }
        }
    })
end

local function CreateApartmentBlip()
    if apartmentBlip then
        RemoveBlip(apartmentBlip)
    end

    apartmentBlip = AddBlipForCoord(Settings.Apartments.Building.coords.x, Settings.Apartments.Building.coords.y, Settings.Apartments.Building.coords.z)
    SetBlipSprite(apartmentBlip, Settings.Apartments.Building.sprite)
    SetBlipDisplay(apartmentBlip, 4)
    SetBlipScale(apartmentBlip, Settings.Apartments.Building.scale)
    SetBlipColour(apartmentBlip, Settings.Apartments.Building.color)
    SetBlipAsShortRange(apartmentBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Settings.Apartments.Building.label)
    EndTextCommandSetBlipName(apartmentBlip)
end

local function CreateApartmentPed()
    local pedModel = Settings.Apartments.Building.pedmodel
    local pedCoords = Settings.Apartments.Building.ped
    
    lib.requestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(100)
    end
    
    apartmentPed = CreatePed(4, pedModel, pedCoords.x, pedCoords.y, pedCoords.z - 1.0, pedCoords.w, false, true)
    FreezeEntityPosition(apartmentPed, true)
    SetEntityInvincible(apartmentPed, true)
    SetBlockingOfNonTemporaryEvents(apartmentPed, true)

    local pedOptions = {
        {
            name = 'apartment_info',
            icon = 'fa-solid fa-circle-info',
            label = 'Check Apartment Info',
            debug = Settings.Debug.Zones,
            onSelect = function()
                if MyApartmentId then
                    Bridge.Client.Notify('Your apartment is room #' .. MyApartmentId, 'info')
                else
                    Bridge.Client.Notify('You don\'t have an apartment assigned', 'error')
                end
            end
        }
    }

    if IsStarterInstanceMode() then
        table.insert(pedOptions, {
            name = 'ped_enter_mine',
            icon = 'fa-solid fa-key',
            label = 'Enter My Apartment',
            debug = Settings.Debug.Zones,
            onSelect = function()
                local assignedRoom = lib.callback.await('LNS_Housing:server:getMyApartment', false)
                if assignedRoom and assignedRoom.roomData then
                    EnterApartmentRoom(assignedRoom.roomData)
                else
                    Bridge.Client.Notify('You do not have an apartment assigned.', 'error')
                end
            end
        })
        table.insert(pedOptions, {
            name = 'ped_visit_room',
            icon = 'fa-solid fa-door-open',
            label = 'Visit Apartment',
            debug = Settings.Debug.Zones,
            onSelect = function()
                local input = lib.inputDialog('Visit Apartment', {
                    { type = 'number', label = 'Room Number', placeholder = 'e.g. 1', required = true, min = 1 }
                })
                if not input or not input[1] then return end
                local targetRoomId = tonumber(input[1])
                if not targetRoomId then return end

                local canEnter = lib.callback.await('LNS_Housing:server:canEnterApartment', false, targetRoomId)
                if canEnter then
                    local roomData = lib.callback.await('LNS_Housing:server:getApartmentRoomData', false, targetRoomId)
                    if roomData then
                        EnterApartmentRoom(roomData)
                    else
                        Bridge.Client.Notify('Could not load apartment data.', 'error')
                    end
                else
                    local alert = lib.alertDialog({
                        header = 'Apartment #' .. targetRoomId,
                        content = 'You do not have a key to Apartment #' .. targetRoomId .. '. Would you like to ring the doorbell?',
                        centered = true,
                        cancel = true,
                        labels = { confirm = 'Ring Bell', cancel = 'Cancel' }
                    })
                    if alert == 'confirm' then
                        TriggerServerEvent('LNS_Housing:server:ringApartmentDoorbell', targetRoomId)
                    end
                end
            end
        })
        table.insert(pedOptions, {
            name = 'ped_manage_keys',
            icon = 'fa-solid fa-id-card',
            label = 'Apartment Management',
            debug = Settings.Debug.Zones,
            canInteract = function()
                return MyApartmentId ~= nil
            end,
            onSelect = function()
                openKeyManagementUI()
            end
        })
    end

    exports.ox_target:addLocalEntity(apartmentPed, pedOptions)

    if CreateApartmentBreakerTarget then CreateApartmentBreakerTarget() end
end

local function OpenApartmentCreatorUI(isEdit)
    local rooms = nil
    if isEdit then
        rooms = lib.callback.await('LNS_Housing:server:getApartmentRooms', false)
        SendNUIMessage({
            action = 'openApartmentEditor',
            data = rooms or {},
            theme = lib.load('shared.theme') or Theme
        })
    else
        SendNUIMessage({
            action = 'openApartmentCreator',
            data = {},
            theme = lib.load('shared.theme') or Theme
        })
    end
    SetNuiFocus(true, true)
end

function openKeyManagementUI()
    if not MyApartmentId then return end
    
    local roomInfo = lib.callback.await('LNS_Housing:server:getApartmentInfo', false, MyApartmentId)
    if not roomInfo then return end

    TriggerEvent('LNS_Housing:client:openPanel', {
        id = MyApartmentId,
        label = "Apartment Room #" .. MyApartmentId,
        owner = roomInfo.owner,
        ownerName = roomInfo.ownerName,
        permissions = roomInfo.permissions,
        metadata = {
            wall_color = roomInfo.wallColor or 0,
            allow_wall_colors = true,
            security_level = roomInfo.security_level or 0
        },
        isApartment = true
    })
end

function EnterApartmentRoom(roomData)
    if not roomData or not roomData.id then return end
    if CurrentApartmentId == roomData.id and insideApartment then return end

    local isInstance = roomData.isInstance or (IsStarterInstanceMode() and (roomData.isStarter or (MyApartmentId and (roomData.id == MyApartmentId or tostring(roomData.id) == tostring(MyApartmentId) or tonumber(roomData.id) == tonumber(MyApartmentId))) or (not roomData.buildingKey and (not roomData.corners or #roomData.corners == 0))))

    if isInstance then
        isInsideInstance = true
        CurrentApartmentId = roomData.id
        InsidePropertyId = roomData.id
        insideApartment = true

        pcall(function()
            LocalPlayer.state:set('inProperty', true, true)
            LocalPlayer.state:set('insidePropertyId', roomData.id, true)
            LocalPlayer.state:set('insideApartment', true, true)
        end)

        TriggerServerEvent('LNS_Housing:server:enterApartmentBucket', roomData.id)

        local roomInfo = lib.callback.await('LNS_Housing:server:getApartmentInfo', false, roomData.id) or {}
        local starterCfg = Settings.Apartments and Settings.Apartments.Starter

        local aptType = roomData.type or (starterCfg and starterCfg.Type) or 'shell'
        local isIpl = (aptType == 'ipl') or (roomData.ipl ~= nil)

        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end

        local spawnCoords = nil
        local spawnHeading = 0.0
        local exitCoords = nil

        if isIpl then
            local iplName = roomData.ipl or (starterCfg and starterCfg.IPL)
            local shellData = Settings.IPLs and Settings.IPLs[iplName]
            activeInstanceIpls = {}
            if shellData and shellData.ipls then
                if type(shellData.ipls) == 'table' then
                    for _, name in ipairs(shellData.ipls) do
                        if not IsIplActive(name) then RequestIpl(name) end
                        table.insert(activeInstanceIpls, name)
                    end
                elseif type(shellData.ipls) == 'string' then
                    if not IsIplActive(shellData.ipls) then RequestIpl(shellData.ipls) end
                    table.insert(activeInstanceIpls, shellData.ipls)
                end
            elseif iplName then
                if not IsIplActive(iplName) then RequestIpl(iplName) end
                table.insert(activeInstanceIpls, iplName)
            end

            local rawSpawn = roomData.spawn or (shellData and shellData.coords) or (starterCfg and starterCfg.SpawnCoords)
            spawnCoords = vec3(rawSpawn.x, rawSpawn.y, rawSpawn.z)
            spawnHeading = rawSpawn.w or (shellData and shellData.coords and shellData.coords.w) or 0.0
            if shellData and shellData.exitCoords then
                exitCoords = vec3(shellData.exitCoords.x, shellData.exitCoords.y, shellData.exitCoords.z)
            else
                exitCoords = spawnCoords
            end
        else
            local shellName = roomData.shell or (starterCfg and starterCfg.Shell) or 'Apartment Furnished'
            local shellData = (Settings.Shells and Settings.Shells[shellName]) or (Settings.IPLs and Settings.IPLs[shellName])
            local shellCoords = roomData.shellCoords or (starterCfg and starterCfg.ShellCoords) or vec3(-826.53, -700.2, -100.0)

            if spawnedInstanceShell and DoesEntityExist(spawnedInstanceShell) then
                DeleteEntity(spawnedInstanceShell)
                spawnedInstanceShell = nil
            end

            if shellData and shellData.hash then
                local shellHash = tonumber(shellData.hash) or GetHashKey(shellData.hash)
                lib.requestModel(shellHash)
                spawnedInstanceShell = CreateObjectNoOffset(shellHash, shellCoords.x, shellCoords.y, shellCoords.z, false, false, false)
                FreezeEntityPosition(spawnedInstanceShell, true)
                SetEntityRotation(spawnedInstanceShell, 0.0, 0.0, 0.0, 2, true)

                local doorOffset = shellData.doorOffset or vec4(0.0, 0.0, 0.0, 0.0)
                spawnCoords = GetOffsetFromEntityInWorldCoords(spawnedInstanceShell, doorOffset.x, doorOffset.y, doorOffset.z)
                spawnHeading = doorOffset.h or 0.0
                exitCoords = spawnCoords
            else
                local rawSpawn = roomData.spawn or (starterCfg and starterCfg.SpawnCoords) or shellCoords
                spawnCoords = vec3(rawSpawn.x, rawSpawn.y, rawSpawn.z)
                spawnHeading = rawSpawn.w or 0.0
                exitCoords = spawnCoords
            end
        end

        local ped = PlayerPedId()
        FreezeEntityPosition(ped, true)
        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        SetEntityHeading(ped, spawnHeading)

        RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        local start = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - start) < 2500 do
            Wait(50)
            RequestCollisionAtCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        end
        Wait(150)

        SetEntityCoords(ped, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false, false)
        FreezeEntityPosition(ped, false)

        -- Interior Exit Zone
        if instanceExitTarget then
            exports.ox_target:removeZone(instanceExitTarget)
            instanceExitTarget = nil
        end
        instanceExitTarget = exports.ox_target:addBoxZone({
            coords = exitCoords,
            size = vec3(1.5, 1.5, 2.0),
            rotation = spawnHeading,
            debug = Settings.Debug.Zones,
            options = {
                {
                    label = 'Exit Apartment',
                    icon = 'fas fa-door-closed',
                    onSelect = function()
                        LeaveApartmentRoom(roomData.id)
                    end
                }
            }
        })

        -- Optional: Configured Wardrobe Location (simple vec3, ox_target only, no prop)
        if instanceWardrobeZone then
            exports.ox_target:removeZone(instanceWardrobeZone)
            instanceWardrobeZone = nil
        end
        local wardrobePos = roomData.wardrobe or (starterCfg and starterCfg.Wardrobe)
        if wardrobePos and wardrobePos.x and wardrobePos.y and wardrobePos.z then
            instanceWardrobeZone = exports.ox_target:addSphereZone({
                coords = vec3(wardrobePos.x, wardrobePos.y, wardrobePos.z),
                radius = 1.2,
                debug = Settings.Debug.Zones,
                options = {
                    {
                        label = 'Open Wardrobe',
                        icon = 'fas fa-shirt',
                        onSelect = function()
                            if Bridge.Client.OpenWardrobe then
                                Bridge.Client.OpenWardrobe(roomData.id, 'starter_wardrobe')
                            end
                        end
                    }
                }
            })
        end

        -- Optional: Configured Stash Location (simple vec3, ox_target only, no prop)
        if instanceStashZone then
            exports.ox_target:removeZone(instanceStashZone)
            instanceStashZone = nil
        end
        local stashPos = roomData.stash or (starterCfg and starterCfg.Stash)
        if stashPos and stashPos.x and stashPos.y and stashPos.z then
            instanceStashZone = exports.ox_target:addSphereZone({
                coords = vec3(stashPos.x, stashPos.y, stashPos.z),
                radius = 1.2,
                debug = Settings.Debug.Zones,
                options = {
                    {
                        label = 'Open Storage',
                        icon = 'fas fa-box-open',
                        onSelect = function()
                            if OpenStorageHandler then
                                OpenStorageHandler(roomData.id, 'starter_stash', string.format('housing_%s_starter_stash', roomData.id), (Settings.Stash and Settings.Stash.label) or 'Apartment Storage', false)
                            else
                                Bridge.Client.OpenStash(roomData.id, 'starter_stash')
                            end
                        end
                    }
                }
            })
        end

        Properties[roomData.id] = {
            id = roomData.id,
            label = "Apartment Room #" .. roomData.id,
            owner = roomInfo.owner,
            ownerName = roomInfo.ownerName,
            permissions = roomInfo.permissions or { entry = {}, storage = {}, wardrobe = {}, furniture = {}, manage = {} },
            door_id = nil,
            metadata = {
                wall_color = roomInfo.wallColor or 0,
                allow_wall_colors = false,
                security_level = roomInfo.security_level or 0,
                shell = roomData.shell or (starterCfg and starterCfg.Shell),
                spawn = spawnCoords,
                entrance = roomData.entrance or (starterCfg and starterCfg.Entrance) or (Settings.Apartments.Building and Settings.Apartments.Building.coords),
                isInstance = true
            },
            furniture = roomInfo.furniture or {},
            isApartment = true,
            isInstance = true
        }

        LoadFurnitures(roomData.id)
        if LoadPropertyTrash then LoadPropertyTrash(roomData.id, true) end

        local isMyRoom = (MyApartmentId and (MyApartmentId == roomData.id or tostring(MyApartmentId) == tostring(roomData.id) or tonumber(MyApartmentId) == tonumber(roomData.id)))
        local hasManageAccess = isMyRoom or lib.callback.await('LNS_Housing:server:checkPermission', false, 'apartment', roomData.id, 'furniture')
        if hasManageAccess then
            HasFurnitureManagePermission = true
            if not Settings.FurnitureMenu or not Settings.FurnitureMenu.Radial or Settings.FurnitureMenu.Radial.Enabled then
                lib.removeRadialItem('housing_furniture')
                lib.addRadialItem({
                    id = 'housing_furniture',
                    icon = 'couch',
                    label = 'Furniture Menu',
                    onSelect = function()
                        TriggerEvent('LNS_Housing:client:openFurnitureMenu', roomData.id)
                    end
                })
            end
        end

        DoScreenFadeIn(1000)
        return
    end

    CurrentApartmentId = roomData.id
    InsidePropertyId = roomData.id
    insideApartment = true

    pcall(function()
        LocalPlayer.state:set('inProperty', true, true)
        LocalPlayer.state:set('insidePropertyId', roomData.id, true)
        LocalPlayer.state:set('insideApartment', true, true)
    end)

    local roomInfo = lib.callback.await('LNS_Housing:server:getApartmentInfo', false, roomData.id)
    roomInfo = roomInfo or {}

    local doorId = nil
    local ok, result = pcall(function()
        return exports.ox_doorlock:getDoorFromName("Apartment Room #" .. roomData.id)
    end)
    if ok and result then
        doorId = result.id
    end

    Properties[roomData.id] = {
        id = roomData.id,
        label = "Apartment Room #" .. roomData.id,
        owner = roomInfo.owner,
        ownerName = roomInfo.ownerName,
        permissions = roomInfo.permissions or { entry = {}, storage = {}, wardrobe = {}, furniture = {}, manage = {} },
        door_id = doorId,
        metadata = {
            wall_color = roomInfo.wallColor or 0,
            allow_wall_colors = true,
            security_level = roomInfo.security_level or 0,
            shell = roomData.shell or 'Apartment Furnished',
            interior_id = roomData.interior_id or roomData.interiorId,
            entrance = roomData.doorCoords and { x = roomData.doorCoords.x, y = roomData.doorCoords.y, z = roomData.doorCoords.z, h = roomData.doorHeading or 0.0 } or (roomData.spawn and { x = roomData.spawn.x, y = roomData.spawn.y, z = roomData.spawn.z, h = roomData.spawn.w or 0.0 }) or nil,
            spawn = roomData.spawn and { x = roomData.spawn.x, y = roomData.spawn.y, z = roomData.spawn.z, w = roomData.spawn.w or 0.0 } or nil,
            interior_coords = roomData.interior_coords or roomData.interiorCoords,
            interior_center = roomData.interior_center or roomData.interiorCenter,
            corners = roomData.corners
        },
        zone_data = roomData.corners and { points = roomData.corners } or nil,
        corners = roomData.corners,
        furniture = roomInfo.furniture or {},
        isApartment = true
    }

    LoadFurnitures(roomData.id)
    if LoadPropertyTrash then LoadPropertyTrash(roomData.id, true) end

    CreateThread(function()
        local attempts = 0
        while insideApartment and (CurrentApartmentId == roomData.id or tostring(CurrentApartmentId) == tostring(roomData.id)) and attempts < 10 do
            local interiorId = GetInteriorFromEntity(cache.ped)
            if interiorId == 0 then
                interiorId = GetInteriorAtCoords(GetEntityCoords(cache.ped))
            end
            if interiorId ~= 0 then
                ApplyWallColor(interiorId, roomInfo.wallColor or 0)
                break
            end
            attempts = attempts + 1
            Wait(200)
        end
    end)

    local isMyRoom = (MyApartmentId and (MyApartmentId == roomData.id or tostring(MyApartmentId) == tostring(roomData.id) or tonumber(MyApartmentId) == tonumber(roomData.id)))
    local hasManageAccess = isMyRoom or lib.callback.await('LNS_Housing:server:checkPermission', false, 'apartment', roomData.id, 'furniture')
    if hasManageAccess then
        HasFurnitureManagePermission = true
        if not Settings.FurnitureMenu or not Settings.FurnitureMenu.Radial or Settings.FurnitureMenu.Radial.Enabled then
            lib.removeRadialItem('housing_furniture')
            lib.addRadialItem({
                id = 'housing_furniture',
                icon = 'couch',
                label = 'Furniture Menu',
                onSelect = function()
                    TriggerEvent('LNS_Housing:client:openFurnitureMenu', roomData.id)
                end
            })
        end
    end
end

function LeaveApartmentRoom(roomId)
    local targetId = roomId or CurrentApartmentId
    if not targetId then return end

    if isInsideInstance then
        isInsideInstance = false
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end

        if instanceExitTarget then
            exports.ox_target:removeZone(instanceExitTarget)
            instanceExitTarget = nil
        end
        if instanceWardrobeZone then
            exports.ox_target:removeZone(instanceWardrobeZone)
            instanceWardrobeZone = nil
        end
        if instanceStashZone then
            exports.ox_target:removeZone(instanceStashZone)
            instanceStashZone = nil
        end

        if spawnedInstanceShell and DoesEntityExist(spawnedInstanceShell) then
            DeleteEntity(spawnedInstanceShell)
            spawnedInstanceShell = nil
        end

        if activeInstanceIpls then
            for _, name in ipairs(activeInstanceIpls) do
                if IsIplActive(name) then
                    RemoveIpl(name)
                end
            end
            activeInstanceIpls = {}
        end

        TriggerServerEvent('LNS_Housing:server:leaveApartmentBucket')

        local starterCfg = Settings.Apartments and Settings.Apartments.Starter
        local exitCoords = (starterCfg and starterCfg.Entrance) or (Settings.Apartments and Settings.Apartments.Building and Settings.Apartments.Building.coords)
        if exitCoords then
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
            RequestCollisionAtCoord(exitCoords.x, exitCoords.y, exitCoords.z)
            local start = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(ped) and (GetGameTimer() - start) < 2000 do
                Wait(50)
                RequestCollisionAtCoord(exitCoords.x, exitCoords.y, exitCoords.z)
            end
            Wait(100)
            SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
            FreezeEntityPosition(ped, false)
        end

        UnloadFurnitures(targetId)
        if UnloadPropertyTrash then UnloadPropertyTrash(targetId) end
        CurrentApartmentId = nil
        if InsidePropertyId == targetId then
            InsidePropertyId = nil
        end
        insideApartment = false
        HasFurnitureManagePermission = false
        lib.removeRadialItem('housing_furniture')

        pcall(function()
            LocalPlayer.state:set('inProperty', false, true)
            LocalPlayer.state:set('insidePropertyId', nil, true)
            LocalPlayer.state:set('insideApartment', false, true)
        end)

        DoScreenFadeIn(1000)
        return
    end

    if targetId and (CurrentApartmentId == targetId or not roomId) then
        pcall(function()
            LocalPlayer.state:set('inProperty', false, true)
            LocalPlayer.state:set('insidePropertyId', nil, true)
            LocalPlayer.state:set('insideApartment', false, true)
        end)
        UnloadFurnitures(targetId)
        if UnloadPropertyTrash then UnloadPropertyTrash(targetId) end
        CurrentApartmentId = nil
        if InsidePropertyId == targetId then
            InsidePropertyId = nil
        end
        insideApartment = false
        HasFurnitureManagePermission = false
        lib.removeRadialItem('housing_furniture')
    end
end

local roomCache = {}

local function getInteriorRooms(interiorId)
    if roomCache[interiorId] then return roomCache[interiorId] end

    local rooms = {}
    local count = GetInteriorRoomCount(interiorId)
    for index = 0, count - 1 do
        local name = GetInteriorRoomName(interiorId, index)
        if name then
            local signedHash = GetHashKey(name)
            local unsignedHash = signedHash < 0 and (signedHash + 4294967296) or signedHash
            local entry = { index = index, name = name }
            rooms[signedHash] = entry
            rooms[unsignedHash] = entry
            rooms[name] = entry
        end
    end

    roomCache[interiorId] = rooms
    return rooms
end

local function scanInterior()
    local ped = cache.ped or PlayerPedId()
    local interiorId = GetInteriorFromEntity(ped)
    if interiorId == 0 then
        interiorId = GetInteriorAtCoords(GetEntityCoords(ped))
    end
    if interiorId == 0 then return nil, nil, {} end

    local names = {}
    local numbered = {}

    for index = 0, GetInteriorRoomCount(interiorId) - 1 do
        local name = GetInteriorRoomName(interiorId, index)
        if name then
            names[#names + 1] = name
            local prefix, number = name:match('^(.-)(%d+)$')
            if prefix and number then
                numbered[prefix] = numbered[prefix] or {}
                numbered[prefix][#numbered[prefix] + 1] = tonumber(number)
            end
        end
    end

    local bestPrefix, bestCount
    for prefix, numbers in pairs(numbered) do
        if not bestCount or #numbers > bestCount then
            bestPrefix, bestCount = prefix, #numbers
        end
    end

    if not bestPrefix then return nil, nil, names end
    return bestPrefix .. '%d', bestCount, names
end

function ResolveCurrentUnit()
    local ped = cache.ped or PlayerPedId()
    local interiorId = GetInteriorFromEntity(ped)
    if interiorId == 0 then
        local coords = GetEntityCoords(ped)
        interiorId = GetInteriorAtCoords(coords.x, coords.y, coords.z)
    end
    if interiorId == 0 then return end

    local ix, iy, iz = GetInteriorPosition(interiorId)
    for key, building in pairs(Buildings or {}) do
        if building.perRoomInterior and building.rooms then
            for roomNumber = 1, #building.rooms do
                local anchor = building.rooms[roomNumber]
                if math.abs(anchor.x - ix) < 2.0 and math.abs(anchor.y - iy) < 2.0 then
                    local floor = math.floor((iz - building.floors.baseZ) / building.floors.step + 0.5) + 1
                    if floor >= 1 and floor <= building.floors.count then
                        return key, floor, roomNumber
                    end
                end
            end
        end
    end

    local rooms = getInteriorRooms(interiorId)
    local current = rooms[GetRoomKeyFromEntity(ped)]
    if not current then return end

    local coords = GetEntityCoords(ped)

    for key, building in pairs(Buildings or {}) do
        local roomNumber = building.roomName and building.rooms
            and current.name:match('^' .. building.roomName:gsub('%%d', '(%%d+)') .. '$')
        roomNumber = roomNumber and tonumber(roomNumber)

        if roomNumber and building.rooms[roomNumber] then
            for floor = 1, building.floors.count do
                local anchor = GetRoomCoords(key, floor, roomNumber)
                if anchor and math.abs(coords.z - anchor.z) < building.floors.step * 0.5 then
                    return key, floor, roomNumber
                end
            end
        end
    end
end

local function isPointInPolygon(coords, corners, zOffset, thickness)
    if not corners or #corners < 3 then return false end
    zOffset = zOffset or 0.0
    thickness = thickness or 4.0
    local minZ = corners[1].z + zOffset - (thickness / 2)
    local maxZ = corners[1].z + zOffset + (thickness / 2)
    for i = 2, #corners do
        local z1 = corners[i].z + zOffset - (thickness / 2)
        local z2 = corners[i].z + zOffset + (thickness / 2)
        if z1 < minZ then minZ = z1 end
        if z2 > maxZ then maxZ = z2 end
    end
    if coords.z < minZ or coords.z > maxZ then
        return false
    end

    local inside = false
    local j = #corners
    for i = 1, #corners do
        local pi = corners[i]
        local pj = corners[j]
        if ((pi.y > coords.y) ~= (pj.y > coords.y)) and
            (coords.x < (pj.x - pi.x) * (coords.y - pi.y) / (pj.y - pi.y) + pi.x) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function isBuildingInterior(interiorId)
    if not interiorId or interiorId == 0 then return false end
    if not Buildings then return false end
    local ix, iy, iz = GetInteriorPosition(interiorId)
    for key, building in pairs(Buildings) do
        if building.perRoomInterior and building.rooms then
            for roomNumber = 1, #building.rooms do
                local anchor = building.rooms[roomNumber]
                if math.abs(anchor.x - ix) < 2.0 and math.abs(anchor.y - iy) < 2.0 then
                    return true
                end
            end
        elseif building.floors and building.floors.baseZ and building.rooms then
            for roomNumber = 1, #building.rooms do
                local anchor = building.rooms[roomNumber]
                if anchor and math.abs(anchor.x - ix) < 60.0 and math.abs(anchor.y - iy) < 60.0 then
                    return true
                end
            end
        end
    end
    return false
end

local function ResolveCustomApartmentRoom(interiorId)
    if not Settings.Rooms or #Settings.Rooms == 0 then return nil end
    local ped = cache.ped or PlayerPedId()
    local coords = GetEntityCoords(ped)

    if isBuildingInterior(interiorId) then
        return nil
    end

    local roomsInInterior = (interiorId and interiorId ~= 0) and getInteriorRooms(interiorId) or {}
    local currentRoomKey = (interiorId and interiorId ~= 0) and GetRoomKeyFromEntity(ped) or 0
    local currentSubRoom = roomsInInterior[currentRoomKey]

    for _, room in ipairs(Settings.Rooms) do
        if room.corners and type(room.corners) == 'table' and #room.corners >= 3 then
            local inPoly = isPointInPolygon(coords, room.corners, room.zOffset, room.thickness)
            if inPoly then
                return room
            end
        end
    end

    if (currentSubRoom and currentSubRoom.name) or currentRoomKey ~= 0 then
        for _, room in ipairs(Settings.Rooms) do
            local rName = room.room_name or room.roomName
            local rKey = tonumber(room.room_key or room.roomKey)
            local isMatch = false

            if rName and currentSubRoom and currentSubRoom.name and currentSubRoom.name == rName then
                isMatch = true
            elseif rKey and (currentRoomKey == rKey or (currentSubRoom and currentSubRoom.index == rKey)) then
                isMatch = true
            end

            if isMatch then
                local roomZ = (room.spawn and room.spawn.z) or (room.doorCoords and room.doorCoords.z) or (room.interior_center and room.interior_center.z) or (room.interiorCenter and room.interiorCenter.z)
                if not roomZ or math.abs(coords.z - roomZ) < 3.5 then
                    return room
                end
            end
        end
    end

    for _, room in ipairs(Settings.Rooms) do
        local hasPoly = room.corners and type(room.corners) == 'table' and #room.corners >= 3
        local hasSubRoom = (room.room_name and room.room_name ~= '') or (room.roomName and room.roomName ~= '') or room.room_key or room.roomKey
        if not hasPoly and not hasSubRoom and not room.buildingKey then
            local refCoords = (room.interior_center and vec3(room.interior_center.x, room.interior_center.y, room.interior_center.z))
                or (room.interiorCenter and vec3(room.interiorCenter.x, room.interiorCenter.y, room.interiorCenter.z))
                or (room.interior_coords and vec3(room.interior_coords.x, room.interior_coords.y, room.interior_coords.z))
                or (room.interiorCoords and vec3(room.interiorCoords.x, room.interiorCoords.y, room.interiorCoords.z))
                or (room.spawn and vec3(room.spawn.x, room.spawn.y, room.spawn.z))
            if refCoords then
                local dist = #(coords - refCoords)
                local radius = room.radius or 6.0
                local zDiff = math.abs(coords.z - refCoords.z)
                if dist <= radius and zDiff <= 3.5 then
                    return room
                end
            end
        end
    end

    return nil
end

local function leaveIfNoZone()
    if isInsideInstance then return end
    if not insideApartment or not CurrentApartmentId then return end
    local ped = cache.ped or PlayerPedId()
    local coords = GetEntityCoords(ped)

    for _, r in ipairs(Settings.Rooms or {}) do
        if r.id == CurrentApartmentId or tostring(r.id) == tostring(CurrentApartmentId) or tonumber(r.id) == tonumber(CurrentApartmentId) then
            if r.corners and type(r.corners) == 'table' and #r.corners >= 3 then
                if not isPointInPolygon(coords, r.corners, r.zOffset, r.thickness) then
                    LeaveApartmentRoom(CurrentApartmentId)
                end
                return
            end

            local rName = r.room_name or r.roomName
            local rKey = tonumber(r.room_key or r.roomKey)
            local interiorId = GetInteriorFromEntity(ped)
            if (rName or rKey) and interiorId ~= 0 then
                local rooms = getInteriorRooms(interiorId)
                local currentKey = GetRoomKeyFromEntity(ped)
                local currentRoom = rooms[currentKey]
                local isMatch = false

                if rName and currentRoom and currentRoom.name == rName then
                    isMatch = true
                elseif rKey and (currentKey == rKey or (currentRoom and currentRoom.index == rKey)) then
                    isMatch = true
                end

                if not isMatch then
                    LeaveApartmentRoom(CurrentApartmentId)
                    return
                end
                return
            end

            local refCoords = (r.interior_center and vec3(r.interior_center.x, r.interior_center.y, r.interior_center.z))
                or (r.interiorCenter and vec3(r.interiorCenter.x, r.interiorCenter.y, r.interiorCenter.z))
                or (r.interior_coords and vec3(r.interior_coords.x, r.interior_coords.y, r.interior_coords.z))
                or (r.interiorCoords and vec3(r.interiorCoords.x, r.interiorCoords.y, r.interiorCoords.z))
                or (r.spawn and vec3(r.spawn.x, r.spawn.y, r.spawn.z))
            if refCoords then
                local dist = #(coords - refCoords)
                local radius = (r.radius or 6.0) + 1.0
                local zDiff = math.abs(coords.z - refCoords.z)
                if dist > radius or zDiff > 3.5 then
                    LeaveApartmentRoom(CurrentApartmentId)
                end
            else
                LeaveApartmentRoom(CurrentApartmentId)
            end
            return
        end
    end

    LeaveApartmentRoom(CurrentApartmentId)
end

local currentUnitKey = nil

CreateThread(function()
    while true do
        Wait(750)
        if not isInsideInstance then
            local ped = cache.ped or PlayerPedId()
            local buildingKey, floor, room = ResolveCurrentUnit()
            local unitKey = buildingKey and floor and room and string.format('%s:%d:%d', buildingKey, floor, room) or nil

            if unitKey then
                if unitKey ~= currentUnitKey then
                    currentUnitKey = unitKey
                    local targetRoomId = (floor * 100) + room
                    local matchedRoom = nil
                    for _, r in ipairs(Settings.Rooms or {}) do
                        if r.id == targetRoomId or r.id == tostring(targetRoomId) then
                            matchedRoom = r
                            break
                        end
                    end
                    
                    if not matchedRoom then
                        local anchor = GetRoomCoords(buildingKey, floor, room)
                        matchedRoom = {
                            id = targetRoomId,
                            buildingKey = buildingKey,
                            floor = floor,
                            room = room,
                            spawn = anchor or vec4(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, 0.0),
                            interior_id = GetInteriorFromEntity(ped)
                        }
                    end

                    if CurrentApartmentId ~= matchedRoom.id then
                        if CurrentApartmentId then
                            LeaveApartmentRoom(CurrentApartmentId)
                        end
                        EnterApartmentRoom(matchedRoom)
                    end
                end
            else
                if currentUnitKey then
                    currentUnitKey = nil
                    if CurrentApartmentId then
                        LeaveApartmentRoom(CurrentApartmentId)
                    end
                end

                local interiorId = GetInteriorFromEntity(ped)
                if interiorId == 0 then
                    local coords = GetEntityCoords(ped)
                    interiorId = GetInteriorAtCoords(coords.x, coords.y, coords.z)
                end

                local customRoom = ResolveCustomApartmentRoom(interiorId)
                if customRoom then
                    if CurrentApartmentId ~= customRoom.id then
                        if CurrentApartmentId then
                            LeaveApartmentRoom(CurrentApartmentId)
                        end
                        EnterApartmentRoom(customRoom)
                    end
                else
                    leaveIfNoZone()
                end
            end
        end
    end
end)

local function createApartmentZone(roomData)
    if not roomData or not roomData.id or not roomData.corners or #roomData.corners < 3 then return end

    if apartmentZones[roomData.id] then
        apartmentZones[roomData.id]:remove()
        apartmentZones[roomData.id] = nil
    end

    local points = {}
    local zOffset = roomData.zOffset or 0.0
    local thickness = roomData.thickness or 4.0
    for i, corner in ipairs(roomData.corners) do
        points[i] = vec3(corner.x, corner.y, corner.z + zOffset + (thickness / 2))
    end

    apartmentZones[roomData.id] = lib.zones.poly({
        points = points,
        thickness = thickness,
        debug = Settings.Debug.Zones,
        onEnter = function()
            EnterApartmentRoom(roomData)
        end,
        onExit = function()
            LeaveApartmentRoom(roomData.id)
        end
    })
end

local function RegisterAllApartmentZones()
    if not Settings.Rooms then return end
    for _, room in ipairs(Settings.Rooms) do
        createApartmentZone(room)
    end
end

local function teleportToStarterApartment()
    local assignedRoom = nil

    for i = 1, 15 do
        assignedRoom = lib.callback.await('LNS_Housing:server:getMyApartment', false)
        if assignedRoom and assignedRoom.roomData then
            break
        end
        Wait(200)
    end

    if assignedRoom and assignedRoom.roomData then
        TriggerEvent('LNS_Housing:client:setApartmentData', assignedRoom.roomId, assignedRoom.roomData)

        if IsStarterInstanceMode() or assignedRoom.roomData.isInstance then
            EnterApartmentRoom(assignedRoom.roomData)
            Bridge.Client.Notify('Welcome to your new starter apartment! You can customize it and store items here.', 'success')
            return
        end

        local coords = assignedRoom.roomData.spawn
        local ped = cache.ped
        
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end
        
        FreezeEntityPosition(PlayerPedId(), true)
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), coords.w)
        
        -- Temp fix for 50/50 chance to fall thru
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        local start = GetGameTimer()
        while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 2000 do
            Wait(50)
            RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        end
        Wait(150)
        
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
        FreezeEntityPosition(PlayerPedId(), false)
        
        DoScreenFadeIn(1000)
        
        Bridge.Client.Notify('Welcome to your new starter apartment! You can customize it and store items here.', 'success')
    end
end

exports('TeleportToStarterApartment', teleportToStarterApartment)

RegisterNetEvent('LNS_Housing:client:setApartmentData', function(roomId, roomData)
    debugPrint('info', 'LNS_Housing:client:setApartmentData received', {roomId = roomId, roomData = roomData})
    MyApartmentId = roomId
    MyRoomData = roomData

    RegisterAllApartmentZones()
    if IsStarterInstanceMode() then
        RegisterBuildingEntranceTarget()
    end
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentFurniture', function(roomId, furniture)
    debugPrint('info', 'LNS_Housing:client:updateApartmentFurniture received', {roomId = roomId, furnitureCount = furniture and #furniture or 0})
    if Properties[roomId] then
        Properties[roomId].furniture = furniture
    end
    if CurrentApartmentId == roomId or (MyApartmentId == roomId and insideApartment) then
        UnloadFurnitures(roomId)
        LoadFurnitures(roomId)
        
        if Modeler and Modeler.IsMenuActive and Modeler.property_id == roomId then
            Modeler:UpdateOwnedItems()
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentProperties', function(roomId, roomInfo)
    debugPrint('info', 'LNS_Housing:client:updateApartmentProperties received', {roomId = roomId, roomInfo = roomInfo})
    if Properties[roomId] then
        Properties[roomId].owner = roomInfo.owner
        Properties[roomId].ownerName = roomInfo.ownerName
        Properties[roomId].permissions = roomInfo.permissions
        if Properties[roomId].metadata then
            Properties[roomId].metadata.wall_color = roomInfo.wallColor
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentWallColor', function(roomId, color)
    debugPrint('info', 'LNS_Housing:client:updateApartmentWallColor received', {roomId = roomId, color = color})
    if Properties[roomId] then
        if not Properties[roomId].metadata then
            Properties[roomId].metadata = {}
        end
        Properties[roomId].metadata.wall_color = color
    end
    if (CurrentApartmentId == roomId or tostring(CurrentApartmentId) == tostring(roomId)) and insideApartment then
        local interiorId = GetInteriorFromEntity(cache.ped)
        if interiorId == 0 then
            interiorId = GetInteriorAtCoords(GetEntityCoords(cache.ped))
        end
        if interiorId ~= 0 then
            ApplyWallColor(interiorId, color)
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentSecurityLevel', function(roomId, securityLevel)
    debugPrint('info', 'LNS_Housing:client:updateApartmentSecurityLevel received', {roomId = roomId, securityLevel = securityLevel})
    if Properties[roomId] then
        if not Properties[roomId].metadata then Properties[roomId].metadata = {} end
        Properties[roomId].metadata.security_level = securityLevel
    end
    SendNUIMessage({
        action = 'updateProperties',
        data = {
            {
                id = roomId,
                metadata = {
                    security_level = securityLevel
                }
            }
        }
    })
end)

local function normalizeRoomData(roomData)
    if not roomData then return nil end
    local cornersVec = {}
    if roomData.corners and type(roomData.corners) == 'table' then
        for i, c in ipairs(roomData.corners) do
            cornersVec[i] = vec3(c.x, c.y, c.z)
        end
    end
    roomData.corners = cornersVec

    if roomData.doorCoords then
        roomData.doorCoords = vec3(roomData.doorCoords.x, roomData.doorCoords.y, roomData.doorCoords.z)
    end

    if roomData.spawn then
        roomData.spawn = vec4(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, roomData.spawn.w or 0.0)
    end

    local ic = roomData.interiorCenter or roomData.interior_center
    if ic then
        roomData.interior_center = vec3(ic.x, ic.y, ic.z)
    end

    local ico = roomData.interiorCoords or roomData.interior_coords
    if ico then
        roomData.interior_coords = vec3(ico.x, ico.y, ico.z)
    end

    roomData.interior_id = tonumber(roomData.interiorId or roomData.interior_id) or nil
    roomData.room_name = roomData.roomName or roomData.room_name
    roomData.room_key = tonumber(roomData.roomKey or roomData.room_key) or nil
    return roomData
end

local function LoadCustomApartments()
    local customRooms = lib.callback.await('LNS_Housing:server:getApartmentRooms', false)
    if customRooms then
        Settings.Rooms = Settings.Rooms or {}
        for _, roomData in ipairs(customRooms) do
            normalizeRoomData(roomData)
            local foundIndex = nil
            for idx, r in ipairs(Settings.Rooms) do
                if r.id == roomData.id or tostring(r.id) == tostring(roomData.id) or tonumber(r.id) == tonumber(roomData.id) then
                    foundIndex = idx
                    break
                end
            end
            
            if foundIndex then
                Settings.Rooms[foundIndex] = roomData
            else
                table.insert(Settings.Rooms, roomData)
            end
        end
        RegisterAllApartmentZones()
    end
end

local function initApartmentForPlayer()
    local assignedRoom = lib.callback.await('LNS_Housing:server:getMyApartment', false)
    if assignedRoom then
        if assignedRoom.roomData then
            normalizeRoomData(assignedRoom.roomData)
            local exists = false
            for idx, r in ipairs(Settings.Rooms or {}) do
                if r.id == assignedRoom.roomData.id or tostring(r.id) == tostring(assignedRoom.roomData.id) then
                    Settings.Rooms[idx] = assignedRoom.roomData
                    exists = true
                    break
                end
            end
            if not exists then
                Settings.Rooms = Settings.Rooms or {}
                table.insert(Settings.Rooms, assignedRoom.roomData)
            end
        end
        TriggerEvent('LNS_Housing:client:setApartmentData', assignedRoom.roomId, assignedRoom.roomData)

        if IsStarterInstanceMode() then
            CreateThread(function()
                Wait(2000)
                local ped = cache.ped or PlayerPedId()
                local coords = GetEntityCoords(ped)
                local starterCfg = Settings.Apartments and Settings.Apartments.Starter
                local shellCoords = starterCfg and (starterCfg.ShellCoords or starterCfg.SpawnCoords)
                if shellCoords and #(coords - vec3(shellCoords.x, shellCoords.y, shellCoords.z)) < 50.0 and not insideApartment then
                    EnterApartmentRoom(assignedRoom.roomData)
                end
            end)
        else
            local ped = cache.ped or PlayerPedId()
            local interiorId = GetInteriorFromEntity(ped)
            if interiorId == 0 then
                local coords = GetEntityCoords(ped)
                interiorId = GetInteriorAtCoords(coords.x, coords.y, coords.z)
            end
            local matched = ResolveCustomApartmentRoom(interiorId)
            if matched then
                EnterApartmentRoom(matched)
            end
        end
    end
end

local apartmentPoints = {}
local registeringDoorsToken = 0

local function ClearApartmentDoors()
    if apartmentPoints then
        for _, p in ipairs(apartmentPoints) do
            if p.targetId then
                exports.ox_target:removeZone(p.targetId)
                p.targetId = nil
            end
            p:remove()
        end
        apartmentPoints = {}
    end
end

local function RegisterApartmentDoors(delay)
    if IsStarterInstanceMode() then return end
    if not Settings.Rooms then return end
    registeringDoorsToken = registeringDoorsToken + 1
    local currentToken = registeringDoorsToken

    CreateThread(function()
        if delay then
            Wait(1000)
        end
        if currentToken ~= registeringDoorsToken then return end

        ClearApartmentDoors()

        for _, room in ipairs(Settings.Rooms) do
            if room.doorCoords then
                local roomPoint = lib.points.new({
                    coords = room.doorCoords,
                    distance = 5.0,
                    onEnter = function(self)
                        if self.targetId then
                            exports.ox_target:removeZone(self.targetId)
                            self.targetId = nil
                        end

                        local door = nil
                        local ok, result = pcall(function()
                            return exports.ox_doorlock:getDoorFromName("Apartment Room #" .. room.id)
                        end)
                        if ok then
                            door = result
                        end

                        local targetCoords, targetHeading = ResolveDoorTargetPlacement(
                            room.doorModel,
                            room.doorCoords,
                            room.doorHeading,
                            door
                        )

                        local doorName = "Apartment Room #" .. room.id
                        local _, doorData = pcall(function()
                            return exports.ox_doorlock:getDoorFromName(doorName)
                        end)

                        local options = {
                            {
                                label = 'Ring Doorbell',
                                icon = 'fas fa-bell',
                                onSelect = function()
                                    TriggerServerEvent('LNS_Housing:server:ringApartmentDoorbell', room.id)
                                end
                            },
                            {
                                label = 'Breach Door',
                                icon = 'fas fa-shield-halved',
                                items = Settings.Security.RaidItem,
                                canInteract = function()
                                    local job = Bridge.Client.GetPlayerJob()
                                    if not Bridge.IsPoliceJob(job) then return false end
                                    if IsPropertyBreached and IsPropertyBreached(room.id, nil) then
                                        return false
                                    end
                                    return true
                                end,
                                onSelect = function()
                                    StartPoliceRaid(room.id, 'apartment', nil)
                                end
                            },
                            {
                                label = 'Secure Door',
                                icon = 'fas fa-lock',
                                canInteract = function()
                                    local job = Bridge.Client.GetPlayerJob()
                                    if not Bridge.IsPoliceJob(job) then return false end
                                    return IsPropertyBreached and IsPropertyBreached(room.id, nil)
                                end,
                                onSelect = function()
                                    TriggerServerEvent('LNS_Housing:server:policeSecureDoor', room.id, 'apartment', nil)
                                end
                            },
                        }

                        if Settings.Apartments.CanBreakIn then
                            table.insert(options, {
                                label = 'Lockpick Apartment',
                                icon = 'fas fa-mask',
                                items = Settings.Security.LockpickItem,
                                canInteract = function()
                                    if doorData then
                                        return doorData.state == 1
                                    end
                                    return true
                                end,
                                onSelect = function()
                                    LockpickDoor(room.id)
                                end
                            })
                        end

                        self.targetId = exports.ox_target:addBoxZone({
                            coords = targetCoords,
                            size = vec3(1.0, 1.5, 2.0),
                            rotation = targetHeading,
                            debug = Settings.Debug.Zones,
                            options = options
                        })
                    end,
                    onExit = function(self)
                        if self.targetId then
                            exports.ox_target:removeZone(self.targetId)
                            self.targetId = nil
                        end
                    end
                })
                table.insert(apartmentPoints, roomPoint)
            end
        end
    end)
end

local isApartmentLoaded = false
local function OnClientPlayerLoaded()
    if isApartmentLoaded then return end
    isApartmentLoaded = true
    debugPrint('info', 'Apartments playerLoaded received')
    LoadCustomApartments()
    initApartmentForPlayer()
    RegisterBuildingEntranceTarget()
    RegisterApartmentDoors(true)
end

local function OnClientPlayerUnloaded()
    isApartmentLoaded = false
    ClearApartmentDoors()
    if buildingEntranceTarget then
        exports.ox_target:removeZone(buildingEntranceTarget)
        buildingEntranceTarget = nil
    end
    CleanUpApartmentSession()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', OnClientPlayerLoaded)
RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    debugPrint('info', 'Apartments esx:playerLoaded received', {identifier = xPlayer and xPlayer.identifier})
    OnClientPlayerLoaded()
end)

AddStateBagChangeHandler('isLoggedIn', nil, function(bagName, key, value)
    if bagName == ('player:%s'):format(GetPlayerServerId(PlayerId())) then
        if value then
            OnClientPlayerLoaded()
        else
            OnClientPlayerUnloaded()
        end
    end
end)

RegisterNetEvent('qbx_core:client:playerLoggedOut', OnClientPlayerUnloaded)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', OnClientPlayerUnloaded)

RegisterNetEvent('LNS_Housing:client:spawnInStarterApartment', function()
    debugPrint('info', 'LNS_Housing:client:spawnInStarterApartment received')
    teleportToStarterApartment()
end)

RegisterNetEvent('LNS_Housing:client:receiveApartmentDoorbell', function(roomId, visitorSrc, visitorName)
    PlaySoundFrontend(-1, "Door_Bell", "DLC_HEISTS_GENERAL_FRONTEND_SOUNDS", true)
    local alert = lib.alertDialog({
        header = 'Apartment Doorbell',
        content = string.format('**%s** is ringing your apartment (#%s) doorbell.\n\nWould you like to let them in?', visitorName or 'A visitor', tostring(roomId)),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Let In',
            cancel = 'Ignore'
        }
    })
    TriggerServerEvent('LNS_Housing:server:answerApartmentDoorbell', roomId, visitorSrc, alert == 'confirm')
end)

RegisterNetEvent('LNS_Housing:client:enterGuestApartment', function(roomId, roomData)
    if not roomData then return end
    Bridge.Client.Notify('You were let in!', 'success')
    EnterApartmentRoom(roomData)
end)

exports('SpawnInStarterApartment', function()
    teleportToStarterApartment()
end)

local function RegisterApartmentCreatorCommands()
    local createCmd = Settings.Apartments.Creator and Settings.Apartments.Creator.Command or 'createapartment'
    local editCmd = Settings.Apartments.Creator and Settings.Apartments.Creator.EditCommand or 'editapartment'

    RegisterCommand(createCmd, function()
        local isAdmin = lib.callback.await('LNS_Housing:server:checkPermission', false, 'admin')
        if not isAdmin then
            Bridge.Client.Notify('You do not have permission to use this command.', 'error')
            return
        end

        OpenApartmentCreatorUI(false)
    end, false)

    RegisterCommand(editCmd, function()
        local isAdmin = lib.callback.await('LNS_Housing:server:checkPermission', false, 'admin')
        if not isAdmin then
            Bridge.Client.Notify('You do not have permission to use this command.', 'error')
            return
        end

        OpenApartmentCreatorUI(true)
    end, false)
end

RegisterApartmentCreatorCommands()

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    Wait(1000)
    
    LoadCustomApartments()
    CreateApartmentBlip()
    CreateApartmentPed()
    CreateApartmentBreakerTarget()
    RegisterBuildingEntranceTarget()

    initApartmentForPlayer()

    if Bridge.Client.GetIdentifier() then
        RegisterApartmentDoors(false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if spawnedInstanceShell and DoesEntityExist(spawnedInstanceShell) then
        DeleteEntity(spawnedInstanceShell)
        spawnedInstanceShell = nil
    end
    if instanceExitTarget then
        exports.ox_target:removeZone(instanceExitTarget)
        instanceExitTarget = nil
    end
    if instanceWardrobeZone then
        exports.ox_target:removeZone(instanceWardrobeZone)
        instanceWardrobeZone = nil
    end
    if instanceStashZone then
        exports.ox_target:removeZone(instanceStashZone)
        instanceStashZone = nil
    end
    if buildingEntranceTarget then
        exports.ox_target:removeZone(buildingEntranceTarget)
        buildingEntranceTarget = nil
    end
    if activeInstanceIpls then
        for _, name in ipairs(activeInstanceIpls) do
            if IsIplActive(name) then
                RemoveIpl(name)
            end
        end
        activeInstanceIpls = {}
    end

    if CurrentApartmentId then
        UnloadFurnitures(CurrentApartmentId)
    elseif MyApartmentId then
        UnloadFurnitures(MyApartmentId)
    end
    
    if apartmentZones then
        for _, z in pairs(apartmentZones) do
            z:remove()
        end
        apartmentZones = {}
    end

    if apartmentPed then
        DeleteEntity(apartmentPed)
    end
    
    if apartmentBlip then
        RemoveBlip(apartmentBlip)
    end

    ClearApartmentDoors()
end)

local function CleanUpApartmentSession()
    if isInsideInstance then
        if instanceExitTarget then
            exports.ox_target:removeZone(instanceExitTarget)
            instanceExitTarget = nil
        end
        if instanceWardrobeZone then
            exports.ox_target:removeZone(instanceWardrobeZone)
            instanceWardrobeZone = nil
        end
        if instanceStashZone then
            exports.ox_target:removeZone(instanceStashZone)
            instanceStashZone = nil
        end
        if spawnedInstanceShell and DoesEntityExist(spawnedInstanceShell) then
            DeleteEntity(spawnedInstanceShell)
            spawnedInstanceShell = nil
        end
        if activeInstanceIpls then
            for _, name in ipairs(activeInstanceIpls) do
                if IsIplActive(name) then
                    RemoveIpl(name)
                end
            end
            activeInstanceIpls = {}
        end
        isInsideInstance = false
    end
    if UnloadPropertyTrash then
        UnloadPropertyTrash()
    end
    if CurrentApartmentId then
        UnloadFurnitures(CurrentApartmentId)
    elseif MyApartmentId then
        UnloadFurnitures(MyApartmentId)
    end
    if apartmentZones then
        for _, z in pairs(apartmentZones) do
            z:remove()
        end
        apartmentZones = {}
    end
    MyApartmentId = nil
    MyRoomData = nil
    CurrentApartmentId = nil
    insideApartment = false
end

RegisterNetEvent('LNS_Housing:client:cleanUpApartmentSession', function()
    debugPrint('info', 'LNS_Housing:client:cleanUpApartmentSession received')
    CleanUpApartmentSession()
end)

exports('GetPlayerSpawns', function()
    if not Properties or next(Properties) == nil then
        Properties = lib.callback.await('LNS_Housing:server:getProperties', false) or {}
    end

    local spawns = lib.callback.await('LNS_Housing:server:getPlayerSpawns', false)
    if not spawns then return {} end
    
    for _, spawn in ipairs(spawns) do
        if spawn.type == "house" then
            local p = Properties[spawn.id]
            if p then
                spawn.coords = GetPropertyInsideCoords(p)
            end
        end
    end
    
    return spawns
end)

exports('SpawnInProperty', function(type, id)
    if type == "apartment" then
        if IsStarterInstanceMode() then
            local roomData = lib.callback.await('LNS_Housing:server:getApartmentRoomData', false, id)
            if not roomData and (MyApartmentId == id or tostring(MyApartmentId) == tostring(id) or (tonumber(MyApartmentId) and tonumber(id) and tonumber(MyApartmentId) == tonumber(id))) then
                roomData = MyRoomData
            end
            if roomData then
                EnterApartmentRoom(roomData)
                return true
            end
        end

        local roomData = nil
        for _, room in ipairs(Settings.Rooms or {}) do
            if room.id == id or tostring(room.id) == tostring(id) or (tonumber(room.id) and tonumber(id) and tonumber(room.id) == tonumber(id)) then
                roomData = room
                break
            end
        end
        
        if roomData then
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do Wait(0) end
            
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true)
            SetEntityCoords(ped, roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, false, false, false, false)
            SetEntityHeading(ped, roomData.spawn.w or 0.0)
            
            TriggerEvent('LNS_Housing:client:setApartmentData', id, roomData)
            EnterApartmentRoom(roomData)
            
            RequestCollisionAtCoord(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z)
            local start = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 3000 do
                Wait(50)
                RequestCollisionAtCoord(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z)
            end
            Wait(150)
            
            SetEntityCoords(PlayerPedId(), roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, false, false, false, false)
            FreezeEntityPosition(PlayerPedId(), false)
            
            DoScreenFadeIn(1000)
            return true
        end
    elseif type == "house" then
        return SpawnInHouse(id)
    end
    return false
end)

RegisterNetEvent('LNS_Housing:client:addApartmentRoom', function(roomData)
    debugPrint('info', 'LNS_Housing:client:addApartmentRoom received', {roomData = roomData})
    local exists = false
    for _, r in ipairs(Settings.Rooms) do
        if r.id == roomData.id then
            exists = true
            break
        end
    end
    
    if not exists then
        local cornersVec = {}
        if roomData.corners and type(roomData.corners) == 'table' then
            for i, c in ipairs(roomData.corners) do
                cornersVec[i] = vec3(c.x, c.y, c.z)
            end
        end
        roomData.corners = cornersVec
        
        if roomData.doorCoords then
            roomData.doorCoords = vec3(roomData.doorCoords.x, roomData.doorCoords.y, roomData.doorCoords.z)
        end
        
        if roomData.spawn then
            roomData.spawn = vec4(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, roomData.spawn.w or 0.0)
        end

        roomData.interior_id = tonumber(roomData.interiorId or roomData.interior_id) or nil
        roomData.room_name = roomData.roomName or roomData.room_name
        roomData.room_key = tonumber(roomData.roomKey or roomData.room_key) or nil
        
        table.insert(Settings.Rooms, roomData)
        
        if roomData.corners and #roomData.corners >= 3 then
            createApartmentZone(roomData)
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentRoom', function(roomData)
    debugPrint('info', 'LNS_Housing:client:updateApartmentRoom received', {roomData = roomData})
    local foundIndex = nil
    for idx, r in ipairs(Settings.Rooms) do
        if r.id == roomData.id then
            foundIndex = idx
            break
        end
    end
    
    local cornersVec = {}
    if roomData.corners and type(roomData.corners) == 'table' then
        for i, c in ipairs(roomData.corners) do
            cornersVec[i] = vec3(c.x, c.y, c.z)
        end
    end
    roomData.corners = cornersVec
    
    if roomData.doorCoords then
        roomData.doorCoords = vec3(roomData.doorCoords.x, roomData.doorCoords.y, roomData.doorCoords.z)
    end
    
    if roomData.spawn then
        roomData.spawn = vec4(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, roomData.spawn.w or 0.0)
    end

    roomData.interior_id = tonumber(roomData.interiorId or roomData.interior_id) or nil
    roomData.room_name = roomData.roomName or roomData.room_name
    roomData.room_key = tonumber(roomData.roomKey or roomData.room_key) or nil
    
    if foundIndex then
        Settings.Rooms[foundIndex] = roomData
    else
        table.insert(Settings.Rooms, roomData)
    end
    
    if roomData.corners and #roomData.corners >= 3 then
        createApartmentZone(roomData)
    end
end)

RegisterNUICallback('createApartmentZone', function(_, cb)
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

RegisterNUICallback('pickApartmentDoor', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false)
    
    local doorId = exports.LNS_Housing:DoorPicker()
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true)
    
    if doorId then
        if type(doorId) == 'table' and doorId.isDouble then
            if doorId.doors then
                for i = 1, 2 do
                    local d = doorId.doors[i]
                    if d and type(d) == 'table' and d.coords then
                        local c = d.coords
                        d.coords = { x = c.x, y = c.y, z = c.z }
                    end
                end
            end
            cb(doorId)
            local c = doorId.doors and doorId.doors[1] and doorId.doors[1].coords
            if c then
                Bridge.Client.Notify('New Double Door selected at ' .. math.floor(c.x) .. ', ' .. math.floor(c.y), 'success')
            else
                Bridge.Client.Notify('New Double Door selected.', 'success')
            end
        elseif type(doorId) == 'table' and doorId.coords then
            local c = doorId.coords
            doorId.coords = { x = c.x, y = c.y, z = c.z }
            cb(doorId)
            Bridge.Client.Notify('New Door selected at ' .. math.floor(doorId.coords.x) .. ', ' .. math.floor(doorId.coords.y), 'success')
        else
            cb(doorId)
            Bridge.Client.Notify('Door ID ' .. tostring(doorId) .. ' selected.', 'success')
        end
    else
        cb(nil)
    end
end)

TabletPlacement = {
    Active = false,
    Object = nil,
    IsFreecamMode = false,
    Result = nil
}

local function GetDefaultPanelModel()
    for _, cat in ipairs(Furniture) do
        for _, item in ipairs(cat.items or {}) do
            if item.isPanel or item.id == 'lns_housing_panel' then
                local m = item.model
                return tonumber(m) or GetHashKey(m)
            end
        end
    end
    return `reh_prop_reh_tablet_01a`
end

local function PlaceDefaultTablet()
    local model = GetDefaultPanelModel()
    lib.requestModel(model)
    
    local ped = cache.ped
    local heading = GetEntityHeading(ped)

    Freecam:SetActive(true)
    Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 0.1)
    Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 2)
    Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 2)
    Freecam:SetFov(45.0)
    Freecam:SetFrozen(true)
    
    local camPos = Freecam:GetPosition()
    local camTarget = Freecam:GetTarget(5.0)
    local playerCoords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local spawnCoords = playerCoords + (forward * 1.5)
    local rot = vec3(0.000000, -90.000000, 90.000000)
    
    local spawnedObj = CreateObjectNoOffset(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false)
    SetEntityCollision(spawnedObj, false, false)
    SetEntityAlpha(spawnedObj, 200, false)
    SetEntityDrawOutline(spawnedObj, true)
    SetEntityDrawOutlineColor(255, 255, 255, 255)
    SetEntityRotation(spawnedObj, rot.x, rot.y, rot.z, 2, true)
    FreezeEntityPosition(spawnedObj, true)
    
    TabletPlacement.Active = true
    TabletPlacement.Object = spawnedObj
    TabletPlacement.IsFreecamMode = false
    TabletPlacement.Result = nil

    SendNUIMessage({
        action = "setupModel",
        data = {
            objectPosition = spawnCoords,
            objectRotation = rot,
            cameraPosition = camPos,
            cameraLookAt = spawnCoords,
            cameraFov = GetGameplayCamFov(),
        }
    })
    
    CreateThread(function()
        local lastCamPos = nil
        local lastCamTarget = nil
        while TabletPlacement.Active do
            local currentCamPos = Freecam:GetPosition()
            local currentCamTarget = Freecam:GetTarget(5.0)
            if not lastCamPos or #(lastCamPos - currentCamPos) > 0.001 or #(lastCamTarget - currentCamTarget) > 0.001 then
                lastCamPos = currentCamPos
                lastCamTarget = currentCamTarget
                SendNUIMessage({
                    action = "updateCamera",
                    data = {
                        cameraPosition = currentCamPos,
                        cameraLookAt = currentCamTarget,
                        cameraFov = GetGameplayCamFov(),
                    }
                })
            end
            local sleep = TabletPlacement.IsFreecamMode and 150 or 60
            Wait(sleep)
        end
    end)


    
    while TabletPlacement.Active do
        Wait(100)
    end
    
    Freecam:SetActive(false)
    Freecam:SetFrozen(false)
    Freecam:SetKeyboardSetting('BASE_MOVE_MULTIPLIER', 5)
    Freecam:SetKeyboardSetting('FAST_MOVE_MULTIPLIER', 10)
    Freecam:SetKeyboardSetting('SLOW_MOVE_MULTIPLIER', 10)
    
    DeleteEntity(spawnedObj)
    
    local finalResult = TabletPlacement.Result
    TabletPlacement.Object = nil
    TabletPlacement.Result = nil
    return finalResult
end

RegisterNUICallback('pickApartmentTablet', function(_, cb)
    local tabletData = PlaceDefaultTablet()
    if tabletData then
        cb(tabletData)
        Bridge.Client.Notify('Tablet placement position saved successfully.', 'success')
    else
        cb(nil)
    end
end)

RegisterNUICallback('stopPlacementTablet', function(data, cb)
    if data and data.save then
        local pos = GetEntityCoords(TabletPlacement.Object)
        local rot = GetEntityRotation(TabletPlacement.Object, 2)
        TabletPlacement.Result = {
            position = { x = pos.x, y = pos.y, z = pos.z },
            rotation = { x = rot.x, y = rot.y, z = rot.z }
        }
    else
        TabletPlacement.Result = nil
    end
    TabletPlacement.Active = false
    cb("ok")
end)

RegisterNUICallback('captureApartmentInterior', function(_, cb)
    debugPrint('info', 'NUI callback: captureApartmentInterior')
    local ped = cache.ped or PlayerPedId()
    local interiorId = GetInteriorFromEntity(ped)

    if interiorId == 0 then
        interiorId = GetInteriorAtCoords(GetEntityCoords(ped))
    end

    if interiorId == 0 then
        Bridge.Client.Notify('Stand inside the apartment interior first.', 'error')
        cb(nil)
        return
    end

    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local roomCount = GetInteriorRoomCount(interiorId)
    local ix, iy, iz = GetInteriorPosition(interiorId)
    local pattern, count, names = scanInterior()
    local currentRoom = nil

    local key = GetRoomKeyFromEntity(ped)
    for index = 0, roomCount - 1 do
        local name = GetInteriorRoomName(interiorId, index)
        if name and GetHashKey(name) == key then
            currentRoom = name
            break
        end
    end

    cb({
        interiorId = interiorId,
        coords = { x = coords.x, y = coords.y, z = coords.z, h = heading },
        center = { x = ix, y = iy, z = iz },
        roomCount = count or roomCount,
        roomName = currentRoom,
        pattern = pattern,
        names = names,
        roomKey = key
    })
    Bridge.Client.Notify(string.format('Apartment native interior captured! (Room: %s, ID: #%d)', currentRoom or 'Main', interiorId), 'success')
end)

RegisterNUICallback('pickApartmentSpawn', function(_, cb)
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = false } })
    SetNuiFocus(false, false)
    
    Bridge.Client.Notify('Stand at the exact spawn/interior point where players should teleport. Press [E] to save spawn point.', 'inform')
    Wait(1000)

    local spawnCoords = nil
    while true do
        Wait(0)
        lib.showTextUI('[E] - Save Spawn Point | [H] Cancel')

        if IsControlJustReleased(0, 38) then
            local ped = cache.ped or PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local interiorId = GetInteriorFromEntity(ped)
            if interiorId == 0 then
                interiorId = GetInteriorAtCoords(coords)
            end
            
            local interiorData = nil
            if interiorId ~= 0 then
                local ix, iy, iz = GetInteriorPosition(interiorId)
                local roomCount = GetInteriorRoomCount(interiorId)
                local pattern, count, names = scanInterior()
                local key = GetRoomKeyFromEntity(ped)
                local currentRoom = nil
                for index = 0, roomCount - 1 do
                    local name = GetInteriorRoomName(interiorId, index)
                    if name and GetHashKey(name) == key then
                        currentRoom = name
                        break
                    end
                end

                interiorData = {
                    interiorId = interiorId,
                    center = { x = ix, y = iy, z = iz },
                    roomCount = count or roomCount,
                    roomName = currentRoom,
                    pattern = pattern,
                    names = names,
                    roomKey = key
                }
            end

            spawnCoords = {
                x = coords.x,
                y = coords.y,
                z = coords.z,
                w = heading,
                interior = interiorData
            }
            lib.hideTextUI()
            break
        elseif IsControlJustReleased(0, 104) then
            lib.hideTextUI()
            break
        end
    end
    
    SendNUIMessage({ action = 'toggleVisibility', data = { visible = true } })
    SetNuiFocus(true, true)
    
    if spawnCoords then
        cb(spawnCoords)
        Bridge.Client.Notify('Spawn point captured successfully.', 'success')
    else
        cb(nil)
    end
end)

RegisterNUICallback('doesApartmentExist', function(data, cb)
    local roomId = tonumber(data.id)
    local exists = lib.callback.await('LNS_Housing:server:doesApartmentExist', false, roomId)
    cb(exists)
end)

RegisterNUICallback('createApartment', function(data, cb)
    SetNuiFocus(false, false)
    local success = lib.callback.await('LNS_Housing:server:createApartment', false, data)
    if success then
        Bridge.Client.Notify('Apartment room created successfully!', 'success')
    else
        Bridge.Client.Notify('Failed to create apartment room.', 'error')
    end
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('updateApartment', function(data, cb)
    SetNuiFocus(false, false)
    local success = lib.callback.await('LNS_Housing:server:updateApartment', false, data)
    if success then
        Bridge.Client.Notify('Apartment room updated successfully!', 'success')
    else
        Bridge.Client.Notify('Failed to update apartment room.', 'error')
    end
    SendNUIMessage({ action = 'closeUI' })
    cb('ok')
end)

RegisterNUICallback('vacateApartmentRoom', function(data, cb)
    local roomId = tonumber(data.roomId)
    local success = lib.callback.await('LNS_Housing:server:vacateApartmentRoom', false, roomId)
    if success then
        Bridge.Client.Notify('Room #' .. roomId .. ' has been vacated and cleared.', 'success')
        cb({ success = true })
    else
        Bridge.Client.Notify('Failed to vacate apartment room.', 'error')
        cb({ success = false })
    end
end)

RegisterNUICallback('deleteApartmentRoom', function(data, cb)
    local roomId = tonumber(data.roomId)
    local success = lib.callback.await('LNS_Housing:server:deleteApartmentRoom', false, roomId)
    if success then
        Bridge.Client.Notify('Room #' .. roomId .. ' has been permanently deleted.', 'success')
        cb({ success = true })
    else
        Bridge.Client.Notify('Failed to delete apartment room.', 'error')
        cb({ success = false })
    end
end)

RegisterNetEvent('LNS_Housing:client:removeApartmentRoom', function(roomId)
    debugPrint('info', 'LNS_Housing:client:removeApartmentRoom received', {roomId = roomId})
    roomId = tonumber(roomId)
    if not roomId then return end

    for idx, room in ipairs(Settings.Rooms or {}) do
        if tonumber(room.id) == roomId then
            table.remove(Settings.Rooms, idx)
            break
        end
    end

    for i = #apartmentPoints, 1, -1 do
        local p = apartmentPoints[i]
        if p and p.roomId == roomId then
            if p.targetId then
                exports.ox_target:removeZone(p.targetId)
            end
            pcall(function() p:remove() end)
            table.remove(apartmentPoints, i)
        end
    end

    if apartmentZones and apartmentZones[roomId] then
        pcall(function() apartmentZones[roomId]:remove() end)
        apartmentZones[roomId] = nil
    end
end)