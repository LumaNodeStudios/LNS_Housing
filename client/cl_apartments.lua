local Settings = lib.load('shared.settings')

if not Settings.Apartments or not Settings.Apartments.Enabled then
    return
end

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

    apartmentBlip = AddBlipForCoord(Settings.ApartmentBuilding.coords.x, Settings.ApartmentBuilding.coords.y, Settings.ApartmentBuilding.coords.z)
    SetBlipSprite(apartmentBlip, Settings.ApartmentBuilding.sprite)
    SetBlipDisplay(apartmentBlip, 4)
    SetBlipScale(apartmentBlip, Settings.ApartmentBuilding.scale)
    SetBlipColour(apartmentBlip, Settings.ApartmentBuilding.color)
    SetBlipAsShortRange(apartmentBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Settings.ApartmentBuilding.label)
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

local function OpenApartmentCreatorUI()
    SendNUIMessage({
        action = 'openApartmentCreator',
        data = {}
    })
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
                    Properties[MyApartmentId] = {
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
                        furniture = roomInfo.furniture or {},
                        isApartment = true
                    }
                end
                
                LoadFurnitures(MyApartmentId)
            end

            local hasManageAccess = lib.callback.await('LNS_Housing:server:hasApartmentAccess', false, MyApartmentId, 'manage')
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
        
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, coords.w)
        
        TriggerEvent('LNS_Housing:client:setApartmentData', assignedRoom.roomId, assignedRoom.roomData)
        
        Wait(500)
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
        Properties[roomId] = {
            id = roomId,
            label = "Apartment Room #" .. roomId,
            owner = roomInfo.owner,
            ownerName = roomInfo.ownerName,
            permissions = roomInfo.permissions,
            metadata = {
                wall_color = roomInfo.wallColor or 0,
                allow_wall_colors = true,
                security_level = 0
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

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    LoadCustomApartments()
    initApartmentForPlayer()
end)

RegisterNetEvent('esx:playerLoaded', function(xPlayer)
    LoadCustomApartments()
    initApartmentForPlayer()
end)

RegisterNetEvent('LNS_Housing:client:spawnInStarterApartment', function()
    teleportToStarterApartment()
end)

exports('SpawnInStarterApartment', function()
    teleportToStarterApartment()
end)

local function RegisterApartmentCreatorCommands()
    local cmd = Settings.ApartmentCreator and Settings.ApartmentCreator.Command or 'createapartment'
    
    RegisterCommand(cmd, function()
        local isAdmin = lib.callback.await('LNS_Housing:server:isApartmentAdmin', false)
        if not isAdmin then
            Bridge.Client.Notify('You do not have permission to use this command.', 'error')
            return
        end

        OpenApartmentCreatorUI()
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

    -- Police Raid Target Registration for Apartments (optimized: sequential run inside unified startup thread)
    Wait(1500) -- Wait briefly for doorlocks to initialize
    if Settings.Rooms then
        for _, room in ipairs(Settings.Rooms) do
            if room.doorCoords then
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

                exports.ox_target:addBoxZone({
                    coords = targetCoords,
                    size = vec3(1.0, 1.5, 2.0),
                    rotation = targetHeading,
                    debug = Settings.Debug.Zones,
                    options = {
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
                        }
                    }
                })
            end
        end
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
end)

local function GetPropertyCoords(p)
    if not p then return nil end
    
    if p.metadata and p.metadata.spawn then
        local sp = p.metadata.spawn
        return vector4(sp.x, sp.y, sp.z, sp.h or sp.w or 0.0)
    end
    
    return nil
end

exports('GetPlayerSpawns', function()
    local spawns = lib.callback.await('LNS_Housing:server:getPlayerSpawns', false)
    if not spawns then return {} end
    
    for _, spawn in ipairs(spawns) do
        if spawn.type == "house" then
            local p = Properties[spawn.id]
            if p then
                spawn.coords = GetPropertyCoords(p)
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
            
            SetEntityCoords(ped, roomData.spawn.x, roomData.spawn.y, roomData.spawn.z, false, false, false, false)
            SetEntityHeading(ped, roomData.spawn.w)
            
            TriggerEvent('LNS_Housing:client:setApartmentData', id, roomData)
            
            Wait(500)
            DoScreenFadeIn(1000)
            return true
        end
    elseif type == "house" then
        local p = Properties[id]
        if p then
            local coords = GetPropertyCoords(p)
            if coords then
                local ped = cache.ped
                DoScreenFadeOut(500)
                while not IsScreenFadedOut() do Wait(0) end
                
                SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityHeading(ped, coords.w)
                
                Wait(500)
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



