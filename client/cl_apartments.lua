local Settings = lib.load('shared.settings')

if not Settings.Apartments or not Settings.Apartments.Enabled then
    return
end

ApartmentRooms = Settings.Rooms

local apartmentBlip = nil
local apartmentPed = nil
insideApartment = false
MyApartmentId = nil
local MyRoomData = nil
apartmentZone = nil

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
    local pedModel = `a_m_y_business_01`
    local pedCoords = vector4(-823.55, -702.17, 28.06, 3.0)
    
    lib.requestModel(pedModel)
    while not HasModelLoaded(pedModel) do
        Wait(100)
    end
    
    apartmentPed = CreatePed(4, pedModel, pedCoords.x, pedCoords.y, pedCoords.z - 1.0, pedCoords.w, false, true)
    FreezeEntityPosition(apartmentPed, true)
    SetEntityInvincible(apartmentPed, true)
    SetBlockingOfNonTemporaryEvents(apartmentPed, true)

    exports.ox_target:addLocalEntity(apartmentPed, {
        {
            name = 'apartment_info',
            icon = 'fa-solid fa-door-open',
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
    })
end

local function OpenApartmentCreatorUI(isEdit)
    local rooms = nil
    if isEdit then
        rooms = lib.callback.await('LNS_Housing:server:getApartmentRooms', false)
        SendNUIMessage({
            action = 'openApartmentEditor',
            data = rooms or {}
        })
    else
        SendNUIMessage({
            action = 'openApartmentCreator',
            data = {}
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
            security_level = 0
        },
        isApartment = true
    })
end

local function createApartmentZone(roomData)
    if apartmentZone then
        apartmentZone:remove()
        apartmentZone = nil
    end

    local points = {}
    local zOffset = roomData.zOffset or 0.0
    local thickness = roomData.thickness or 4.0
    for i, corner in ipairs(roomData.corners) do
        points[i] = vec3(corner.x, corner.y, corner.z + zOffset + (thickness / 2))
    end

    apartmentZone = lib.zones.poly({
        points = points,
        thickness = thickness,
        debug = Settings.Debug.Zones,
        onEnter = function()
            insideApartment = true

            if MyApartmentId then
                local roomInfo = lib.callback.await('LNS_Housing:server:getApartmentInfo', false, MyApartmentId)
                if roomInfo then
                    local roomData = MyRoomData
                    if not roomData and Settings.Rooms then
                        for _, r in ipairs(Settings.Rooms) do
                            if r.id == MyApartmentId then
                                roomData = r
                                break
                            end
                        end
                    end

                    local doorId = nil
                    if GetResourceState('ox_doorlock') == 'started' then
                        local ok, result = pcall(function()
                            return exports.ox_doorlock:getDoorFromName("Apartment Room #" .. MyApartmentId)
                        end)
                        if ok and result then
                            doorId = result.id
                        end
                    end

                    Properties[MyApartmentId] = {
                        id = MyApartmentId,
                        label = "Apartment Room #" .. MyApartmentId,
                        owner = roomInfo.owner,
                        ownerName = roomInfo.ownerName,
                        permissions = roomInfo.permissions,
                        door_id = doorId,
                        metadata = {
                            wall_color = roomInfo.wallColor or 0,
                            allow_wall_colors = true,
                            security_level = 0,
                            shell = roomData and roomData.shell or 'Apartment Furnished',
                            entrance = roomData and roomData.doorCoords and { x = roomData.doorCoords.x, y = roomData.doorCoords.y, z = roomData.doorCoords.z, h = roomData.doorHeading or 0.0 } or nil,
                            spawn = roomData and roomData.spawn and { x = roomData.spawn.x, y = roomData.spawn.y, z = roomData.spawn.z, w = roomData.spawn.w or 0.0 } or nil
                        },
                        furniture = roomInfo.furniture or {},
                        isApartment = true
                    }
                end
                
                LoadFurnitures(MyApartmentId)
            end

            local hasManageAccess = lib.callback.await('LNS_Housing:server:checkPermission', false, 'apartment', MyApartmentId, 'manage')
            if hasManageAccess then
                lib.addRadialItem({
                    id = 'housing_furniture',
                    icon = 'couch',
                    label = 'Furniture Menu',
                    onSelect = function()
                        TriggerEvent('LNS_Housing:client:openFurnitureMenu', MyApartmentId)
                    end
                })
            end
        end,
        onExit = function()
            insideApartment = false
            if MyApartmentId then
                UnloadFurnitures(MyApartmentId)
            end
            lib.removeRadialItem('housing_furniture')
            lib.removeRadialItem('housing_lock')
        end
    })
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
        local coords = assignedRoom.roomData.spawn
        local ped = cache.ped
        
        DoScreenFadeOut(500)
        while not IsScreenFadedOut() do Wait(0) end
        
        FreezeEntityPosition(PlayerPedId(), true)
        SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), coords.w)
        
        TriggerEvent('LNS_Housing:client:setApartmentData', assignedRoom.roomId, assignedRoom.roomData)
        
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
        
        lib.notify({
            description = 'Welcome to your new starter apartment! You can customize it and store items here.',
            type = 'success'
        })
    end
end

exports('TeleportToStarterApartment', teleportToStarterApartment)

RegisterNetEvent('LNS_Housing:client:setApartmentData', function(roomId, roomData)
    MyApartmentId = roomId
    MyRoomData = roomData

    local roomInfo = lib.callback.await('LNS_Housing:server:getApartmentInfo', false, roomId)
    if roomInfo then
        local doorId = nil
        if GetResourceState('ox_doorlock') == 'started' then
            local ok, result = pcall(function()
                return exports.ox_doorlock:getDoorFromName("Apartment Room #" .. roomId)
            end)
            if ok and result then
                doorId = result.id
            end
        end

        Properties[roomId] = {
            id = roomId,
            label = "Apartment Room #" .. roomId,
            owner = roomInfo.owner,
            ownerName = roomInfo.ownerName,
            permissions = roomInfo.permissions,
            door_id = doorId,
            metadata = {
                wall_color = roomInfo.wallColor or 0,
                allow_wall_colors = true,
                security_level = 0,
                shell = roomData and roomData.shell or 'Apartment Furnished',
                entrance = roomData and roomData.doorCoords and { x = roomData.doorCoords.x, y = roomData.doorCoords.y, z = roomData.doorCoords.z, h = roomData.doorHeading or 0.0 } or nil,
                spawn = roomData and roomData.spawn and { x = roomData.spawn.x, y = roomData.spawn.y, z = roomData.spawn.z, w = roomData.spawn.w or 0.0 } or nil
            },
            furniture = roomInfo.furniture or {},
            isApartment = true
        }
    end

    createApartmentZone(roomData)
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentFurniture', function(roomId, furniture)
    if MyApartmentId == roomId and Properties[roomId] then
        Properties[roomId].furniture = furniture
        
        if insideApartment then
            UnloadFurnitures(roomId)
            LoadFurnitures(roomId)
            
            if Modeler and Modeler.IsMenuActive and Modeler.property_id == roomId then
                Modeler:UpdateOwnedItems()
            end
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentProperties', function(roomId, roomInfo)
    if MyApartmentId == roomId and Properties[roomId] then
        Properties[roomId].owner = roomInfo.owner
        Properties[roomId].ownerName = roomInfo.ownerName
        Properties[roomId].permissions = roomInfo.permissions
        Properties[roomId].metadata.wall_color = roomInfo.wallColor
    end
end)

local function LoadCustomApartments()
    local customRooms = lib.callback.await('LNS_Housing:server:getApartmentRooms', false)
    if customRooms then
        for _, roomData in ipairs(customRooms) do
            local exists = false
            for _, r in ipairs(Settings.Rooms) do
                if r.id == roomData.id then
                    exists = true
                    break
                end
            end
            
            if not exists then
                local cornersVec = {}
                for i, c in ipairs(roomData.corners) do
                    cornersVec[i] = vec3(c.x, c.y, c.z)
                end
                roomData.corners = cornersVec
                
                if roomData.doorCoords then
                    roomData.doorCoords = vec3(roomData.doorCoords.x, roomData.doorCoords.y, roomData.doorCoords.z)
                end
                
                if roomData.spawn then
                    roomData.spawn = vec4(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, roomData.spawn.w or 0.0)
                end
                
                table.insert(Settings.Rooms, roomData)
            end
        end
    end
end

local function initApartmentForPlayer()
    local assignedRoom = lib.callback.await('LNS_Housing:server:getMyApartment', false)
    if assignedRoom then
        TriggerEvent('LNS_Housing:client:setApartmentData', assignedRoom.roomId, assignedRoom.roomData)
    end
end

local apartmentPoints = {}
local function RegisterApartmentDoors(delay)
    if #apartmentPoints > 0 then return end
    if not Settings.Rooms then return end

    CreateThread(function()
        if delay then
            Wait(1000)
        end

        for _, room in ipairs(Settings.Rooms) do
            if room.doorCoords then
                local roomPoint = lib.points.new({
                    coords = room.doorCoords,
                    distance = 30.0,
                    onEnter = function(self)
                        local door = nil
                        if GetResourceState('ox_doorlock') == 'started' then
                            local ok, result = pcall(function()
                                return exports.ox_doorlock:getDoorFromName("Apartment Room #" .. room.id)
                            end)
                            if ok then
                                door = result
                            end
                        end

                        local targetCoords, targetHeading = ResolveDoorTargetPlacement(
                            room.doorModel,
                            room.doorCoords,
                            room.doorHeading,
                            door
                        )

                        local options = {
                            {
                                label = 'Raid Apartment',
                                icon = 'fas fa-shield-halved',
                                items = Settings.Security.RaidItem,
                                canInteract = function()
                                    local job = Bridge.Client.GetPlayerJob()
                                    return job and job.name == 'police'
                                end,
                                onSelect = function()
                                    StartPoliceRaid(room.id, 'apartment', nil)
                                end
                            },
                        }

                        if Settings.Apartments.CanBreakIn then
                            table.insert(options, {
                                label = 'Lockpick Apartment',
                                icon = 'fas fa-mask',
                                items = Settings.Security.LockpickItem,
                                canInteract = function()
                                    local isLocked = true
                                    local doorName = "Apartment Room #" .. room.id
                                    local ok, doorData = pcall(function()
                                        return exports.ox_doorlock:getDoorFromName(doorName)
                                    end)
                                    if ok and doorData then
                                        isLocked = doorData.state == 1
                                    end

                                    if not isLocked then return false end
                                    return lib.callback.await('LNS_Housing:server:checkPermission', false, 'apartment', room.id, 'lockpick')
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

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LoadCustomApartments()
    initApartmentForPlayer()
    RegisterApartmentDoors(true)
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    LoadCustomApartments()
    initApartmentForPlayer()
    RegisterApartmentDoors(true)
end)

RegisterNetEvent('LNS_Housing:client:spawnInStarterApartment', function()
    teleportToStarterApartment()
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

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    Wait(1000)
    
    LoadCustomApartments()
    CreateApartmentBlip()
    CreateApartmentPed()

    initApartmentForPlayer()

    RegisterApartmentCreatorCommands()

    if Bridge.Client.GetIdentifier() then
        RegisterApartmentDoors(false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    
    if MyApartmentId then
        UnloadFurnitures(MyApartmentId)
    end
    
    if apartmentZone then
        apartmentZone:remove()
    end

    if apartmentPed then
        DeleteEntity(apartmentPed)
    end
    
    if apartmentBlip then
        RemoveBlip(apartmentBlip)
    end

    if apartmentPoints then
        for _, p in ipairs(apartmentPoints) do
            p:remove()
        end
    end
end)

local function CleanUpApartmentSession()
    if MyApartmentId then
        UnloadFurnitures(MyApartmentId)
    end
    if apartmentZone then
        apartmentZone:remove()
        apartmentZone = nil
    end
    MyApartmentId = nil
    MyRoomData = nil
    insideApartment = false
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    CleanUpApartmentSession()
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    CleanUpApartmentSession()
end)


local function GetPropertyCoords(p)
    if not p then return nil end
    
    if p.metadata and p.metadata.spawn then
        local sp = p.metadata.spawn
        return vector4(sp.x, sp.y, sp.z, sp.h or sp.w or 0.0)
    end
    
    return nil
end

local function GetEntranceCoordsAndHeading(p)
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

local function GetPropertyInsideCoords(p)
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
        local roomData = nil
        for _, room in ipairs(Settings.Rooms) do
            if room.id == id then
                roomData = room
                break
            end
        end
        
        if roomData then
            local ped = cache.ped
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do Wait(0) end
            
            FreezeEntityPosition(PlayerPedId(), true)
            SetEntityCoords(PlayerPedId(), roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, false, false, false, false)
            SetEntityHeading(PlayerPedId(), roomData.spawn.w)
            
            TriggerEvent('LNS_Housing:client:setApartmentData', id, roomData)
            
            -- Temp fix for 50/50 chance to fall thru
            RequestCollisionAtCoord(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z)
            local start = GetGameTimer()
            while not HasCollisionLoadedAroundEntity(PlayerPedId()) and (GetGameTimer() - start) < 2000 do
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
                local ped = cache.ped
                DoScreenFadeOut(500)
                while not IsScreenFadedOut() do Wait(0) end
                
                FreezeEntityPosition(PlayerPedId(), true)
                SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityHeading(PlayerPedId(), coords.w)
                
                TriggerServerEvent('LNS_Housing:server:enterPropertyBucket', id)
                LoadFurnitures(id)
                
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
                return true
            end
        end
    end
    return false
end)

RegisterNetEvent('LNS_Housing:client:addApartmentRoom', function(roomData)
    local exists = false
    for _, room in ipairs(Settings.Rooms) do
        if room.id == roomData.id then
            exists = true
            break
        end
    end
    
    if not exists then
        local cornersVec = {}
        for i, c in ipairs(roomData.corners) do
            cornersVec[i] = vec3(c.x, c.y, c.z)
        end
        roomData.corners = cornersVec
        
        if roomData.doorCoords then
            roomData.doorCoords = vec3(roomData.doorCoords.x, roomData.doorCoords.y, roomData.doorCoords.z)
        end
        
        if roomData.spawn then
            roomData.spawn = vec4(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, roomData.spawn.w or 0.0)
        end
        
        table.insert(Settings.Rooms, roomData)
        
        if MyApartmentId == roomData.id then
            createApartmentZone(roomData)
        end
    end
end)

RegisterNetEvent('LNS_Housing:client:updateApartmentRoom', function(roomData)
    local foundIndex = nil
    for idx, room in ipairs(Settings.Rooms) do
        if room.id == roomData.id then
            foundIndex = idx
            break
        end
    end
    
    local cornersVec = {}
    for i, c in ipairs(roomData.corners) do
        cornersVec[i] = vec3(c.x, c.y, c.z)
    end
    roomData.corners = cornersVec
    
    if roomData.doorCoords then
        roomData.doorCoords = vec3(roomData.doorCoords.x, roomData.doorCoords.y, roomData.doorCoords.z)
    end
    
    if roomData.spawn then
        roomData.spawn = vec4(roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, roomData.spawn.w or 0.0)
    end
    
    if foundIndex then
        Settings.Rooms[foundIndex] = roomData
    else
        table.insert(Settings.Rooms, roomData)
    end
    
    if MyApartmentId == roomData.id then
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
        if type(doorId) == 'table' and doorId.coords then
            local c = doorId.coords
            doorId.coords = { x = c.x, y = c.y, z = c.z }
        end
        cb(doorId)
        if type(doorId) == 'table' then
            Bridge.Client.Notify('New Door selected at ' .. math.floor(doorId.coords.x) .. ', ' .. math.floor(doorId.coords.y), 'success')
        else
            Bridge.Client.Notify('Door ID ' .. doorId .. ' selected.', 'success')
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

local function PlaceDefaultTablet()
    local model = `reh_prop_reh_tablet_01a`
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
            Wait(33)
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
            local ped = cache.ped
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            spawnCoords = {x = coords.x, y = coords.y, z = coords.z, w = heading}
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