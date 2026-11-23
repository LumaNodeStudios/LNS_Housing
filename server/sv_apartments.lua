local Settings = lib.load('shared.settings')
local activeRooms = {}
local playerRooms = {}
local playerRoomBuildings = {}
local roomBuildings = {}
local roomDoors = {}
local assignedRoomIds = {}
local lastNoRoomNotify = {}

if not Settings.Apartments or not Settings.Apartments.Enabled then
    lib.callback.register('LNS_Housing:server:getMyApartment', function(source)
        debugPrint('info', 'getMyApartment fallback called', {source = source})
        return nil
    end)
    lib.callback.register('LNS_Housing:server:getApartmentInfo', function(source, roomId)
        debugPrint('info', 'getApartmentInfo fallback called', {source = source, roomId = roomId})
        return nil
    end)
    lib.callback.register('LNS_Housing:server:claimNewCharacterSpawn', function(source)
        debugPrint('info', 'claimNewCharacterSpawn fallback called', {source = source})
        return { shouldSpawn = false }
    end)
    exports('GetApartments', function() return {} end)
    exports('GetPlayerApartment', function() return nil end)
    exports('GetPlayerApartments', function() return {} end)
    exports('GetAllApartments', function() return {} end)
    exports('GetApartment', function() return nil end)
    exports('GetApartmentInfo', function() return nil end)
    return
end

local function GetPlayerLicense(src)
    local lic = GetPlayerIdentifierByType(src, 'license')
    local lic2 = GetPlayerIdentifierByType(src, 'license2')
    return lic or lic2, lic2 or lic
end

function GetApartmentBuildingId(roomId)
    if not roomId then return nil end
    local numId = tonumber(roomId)
    local strId = tostring(roomId)
    if numId and roomBuildings[numId] then return roomBuildings[numId] end
    if roomBuildings[strId] then return roomBuildings[strId] end

    if Settings.Rooms then
        for _, r in ipairs(Settings.Rooms) do
            if r.id == roomId or tostring(r.id) == strId or (numId and tonumber(r.id) == numId) then
                local bId = r.buildingId or r.building_id
                if bId and bId ~= '' then
                    roomBuildings[numId or roomId] = bId
                    return bId
                end
            end
        end
    end

    local paRow = MySQL.single.await('SELECT building_id FROM player_apartments WHERE room_id = ? LIMIT 1', { numId or roomId })
    if paRow and paRow.building_id and paRow.building_id ~= '' then
        roomBuildings[numId or roomId] = paRow.building_id
        return paRow.building_id
    end

    local arRow = MySQL.single.await('SELECT building_id, door_coords, spawn_coords FROM apartment_rooms WHERE id = ? LIMIT 1', { numId or roomId })
    if arRow then
        if arRow.building_id and arRow.building_id ~= '' then
            roomBuildings[numId or roomId] = arRow.building_id
            return arRow.building_id
        end
        local refCoords = nil
        if arRow.door_coords then
            local dc = json.decode(arRow.door_coords)
            if dc then refCoords = vec3(dc.x, dc.y, dc.z) end
        end
        if not refCoords and arRow.spawn_coords then
            local sc = json.decode(arRow.spawn_coords)
            if sc then refCoords = vec3(sc.x, sc.y, sc.z) end
        end
        if refCoords then
            local nearest = Bridge.GetNearestApartmentBuilding(refCoords)
            if nearest then
                roomBuildings[numId or roomId] = nearest.id
                return nearest.id
            end
        end
    end

    local defaultB = Bridge.GetApartmentBuildings()[1]
    local defId = defaultB and defaultB.id or 'wiwang'
    roomBuildings[numId or roomId] = defId
    return defId
end

local Furniture = lib.load('shared.furniture') or {}

local function GetFurnitureItem(model)
    local hash = tonumber(model) or (type(model) == 'string' and joaat(model))
    for _, cat in ipairs(Furniture) do
        for _, item in ipairs(cat.items or {}) do
            local itemHash = tonumber(item.model) or (type(item.model) == 'string' and joaat(item.model))
            if item.model == model or (hash and itemHash and itemHash == hash) then
                return item, cat.id
            end
            if item.variants then
                for _, variant in ipairs(item.variants) do
                    local varHash = tonumber(variant.model or item.model) or (type(variant.model or item.model) == 'string' and joaat(variant.model or item.model))
                    if (variant.model or item.model) == model or (hash and varHash and varHash == hash) then
                        return item, cat.id, variant
                    end
                end
            end
        end
    end
    return nil, nil
end

local function IsPanelModel(model)
    local item = GetFurnitureItem(model)
    if item and (item.isPanel or item.id == 'lns_housing_panel') then
        return true
    end
    return false
end

local function GetDefaultPanelFurniture()
    for _, cat in ipairs(Furniture) do
        for _, item in ipairs(cat.items or {}) do
            if item.isPanel or item.id == 'lns_housing_panel' then
                return item, cat.id
            end
        end
    end
    return {
        model = 'reh_prop_reh_tablet_01a',
        label = locale('target.property_panel')
    }, 'prerequisites'
end

local function CreateDefaultPanelFurniture(pos, rot)
    local defaultPanel, catId = GetDefaultPanelFurniture()
    return {
        id = math.random(100000, 999999),
        model = defaultPanel.model,
        label = defaultPanel.label or 'Property Panel',
        position = vec3(pos.x or pos[1], pos.y or pos[2], pos.z or pos[3]),
        rotation = vec3(rot.x or rot[1], rot.y or rot[2], rot.z or rot[3]),
        category = catId or 'prerequisites'
    }
end

local function CreateApartmentDoorlocks()
    if GetResourceState('ox_doorlock') ~= 'started' then
        return
    end

    for _, room in ipairs(Settings.Rooms) do
        if room.doorCoords and room.doorModel then
            local doorName = "Apartment Room #" .. room.id
            local existingDoor = nil

            pcall(function()
                existingDoor = exports.ox_doorlock:getDoorFromName(doorName)
            end)

            if not existingDoor then
                local doorId = exports.ox_doorlock:createDoor({
                    name = doorName,
                    model = room.doorModel,
                    coords = room.doorCoords,
                    heading = room.doorHeading or 0.0,
                    state = 1,
                    maxDistance = 2.0,
                    items = {}
                })
                roomDoors[room.id] = doorId
            else
                roomDoors[room.id] = existingDoor.id
            end
        end
    end
end

local function SyncApartmentDoor(roomId)
    local doorId = roomDoors[roomId]
    if not doorId then return end

    local pk = Settings.Security.PhysicalKeys
    if pk and pk.Enabled then
        exports.ox_doorlock:editDoor(doorId, {
            identifiers = {},
            items = {
                { name = pk.Item, metadata = { propertyId = roomId, isApartment = true } }
            }
        })
        return
    end

    local identifiers = {}
    local results = MySQL.query.await('SELECT citizenid, permissions FROM apartments WHERE room_id = ?', {roomId})
    if results then
        for _, row in ipairs(results) do
            identifiers[row.citizenid] = 4

            if row.permissions then
                local permissions = json.decode(row.permissions)
                if permissions then
                    for category, cids in pairs(permissions) do
                        for _, cid in ipairs(cids) do
                            if not identifiers[cid] or identifiers[cid] < 1 then
                                identifiers[cid] = 1
                            end
                        end
                    end
                end
            end
        end
    end

    exports.ox_doorlock:editDoor(doorId, {
        identifiers = identifiers,
        items = {}
    })
end

CreateThread(function()
    WaitForDb()
    local Rooms = MySQL.query.await('SELECT * FROM apartment_rooms')
    if Rooms then
        for _, r in ipairs(Rooms) do
            local corners = r.corners and json.decode(r.corners) or nil
            local cornersVec = {}
            if corners and type(corners) == 'table' then
                for i, c in ipairs(corners) do
                    cornersVec[i] = vec3(c.x, c.y, c.z)
                end
            end
            
            local doorCoords = nil
            if r.door_coords then
                local dc = json.decode(r.door_coords)
                doorCoords = vec3(dc.x, dc.y, dc.z)
            end
            
            local sc = r.spawn_coords and json.decode(r.spawn_coords)
            local spawnVec = sc and vec4(sc.x, sc.y, sc.z, sc.w or sc.h or 0.0) or (doorCoords and vec4(doorCoords.x, doorCoords.y, doorCoords.z, r.door_heading or 0.0))
            
            local tabletCoords = nil
            if r.tablet_coords then
                tabletCoords = json.decode(r.tablet_coords)
            end

            local interiorCoords = r.interior_coords and json.decode(r.interior_coords) or nil
            local interiorCenter = r.interior_center and json.decode(r.interior_center) or nil

            local buildingId = r.building_id
            if not buildingId or buildingId == '' then
                local refCoords = doorCoords or (spawnVec and vec3(spawnVec.x, spawnVec.y, spawnVec.z))
                local nearest = Bridge.GetNearestApartmentBuilding(refCoords)
                buildingId = nearest and nearest.id or 'wiwang'
            end
            roomBuildings[r.id] = buildingId

            table.insert(Settings.Rooms, {
                id = r.id,
                buildingId = buildingId,
                building_id = buildingId,
                corners = cornersVec,
                thickness = r.thickness,
                zOffset = r.zOffset,
                doorModel = r.door_model,
                doorCoords = doorCoords,
                doorHeading = r.door_heading,
                spawn = spawnVec,
                price = r.price,
                isStarter = (r.is_starter == 1 or r.is_starter == true),
                tabletCoords = tabletCoords,
                interior_id = tonumber(r.interior_id) or nil,
                interior_coords = interiorCoords,
                interior_center = interiorCenter,
                room_count = tonumber(r.room_count) or nil,
                room_name = r.room_name,
                room_key = tonumber(r.room_key) or nil
            })
        end
    end

    local result = MySQL.query.await('SELECT license, room_id, building_id FROM player_apartments')
    if result then
        for _, row in ipairs(result) do
            playerRooms[row.license] = row.room_id
            assignedRoomIds[row.room_id] = true
            local bId = row.building_id
            if not bId or bId == '' then
                bId = roomBuildings[row.room_id] or GetApartmentBuildingId(row.room_id)
            end
            playerRoomBuildings[row.license] = bId
            roomBuildings[row.room_id] = bId
        end
        lib.print.info('Loaded ' .. #result .. ' apartments.')
    end

    CreateApartmentDoorlocks()
    for _, room in ipairs(Settings.Rooms) do
        SyncApartmentDoor(room.id)
    end
end)

local function IsStarterInstanceMode()
    return Settings.Apartments and Settings.Apartments.Starter and Settings.Apartments.Starter.Mode == 'instance'
end

local function GetStarterApartmentRoomData(roomId, buildingId)
    local cfg = Settings.Apartments and Settings.Apartments.Starter
    if not cfg then return nil end

    local bId = buildingId or GetApartmentBuildingId(roomId)
    local building = Bridge.GetApartmentBuildingById(bId, true)
    local bLabel = building and building.label or "WIWANG Apartments"
    local buildingActualId = building and building.id or bId or 'wiwang'
    local entrance = (building and (building.coords or building.entrance))
    local interiorType = (building and building.type) or cfg.Type or 'shell'
    local shellName = (building and building.shell) or cfg.Shell or 'Apartment Furnished'
    local iplName = (building and building.ipl) or cfg.IPL or 'Eclipse Penthouse 1'
    local shellOrigin = (building and building.shellCoords) or cfg.ShellCoords or vec3(entrance.x, entrance.y, Settings.ShellSpawningZ or -100.0)
    local spawnCoords = (building and building.spawnCoords) or cfg.SpawnCoords

    if not spawnCoords then
        if interiorType == 'ipl' then
            local iplData = Settings.IPLs and Settings.IPLs[iplName]
            if iplData and iplData.coords then
                spawnCoords = iplData.coords
            end
        else
            local shellData = Settings.Shells and Settings.Shells[shellName]
            if shellData and shellData.doorOffset then
                spawnCoords = vec4(
                    shellOrigin.x + shellData.doorOffset.x,
                    shellOrigin.y + shellData.doorOffset.y,
                    shellOrigin.z + shellData.doorOffset.z,
                    shellData.doorOffset.h or 0.0
                )
            end
        end
    end

    if not spawnCoords then
        spawnCoords = vec4(entrance.x, entrance.y, entrance.z, 0.0)
    end

    local bucketOffset = cfg.BucketOffset or 20000
    local numId = tonumber(roomId) or 1

    return {
        id = roomId,
        buildingId = buildingActualId,
        building_id = buildingActualId,
        buildingLabel = bLabel,
        isStarter = true,
        isInstance = true,
        interiorType = interiorType,
        shell = interiorType == 'shell' and shellName or nil,
        ipl = interiorType == 'ipl' and iplName or nil,
        shellCoords = shellOrigin,
        doorCoords = entrance,
        entrance = entrance,
        doorHeading = 0.0,
        spawn = spawnCoords,
        price = 0,
        bucket = bucketOffset + numId,
        wardrobe = (building and building.wardrobe),
        stash = (building and building.stash)
    }
end

function GetRoomDataByIdServer(roomId, buildingId)
    if not roomId then return nil end
    local numId = tonumber(roomId)
    local strId = tostring(roomId)

    if Settings.Rooms then
        for _, room in ipairs(Settings.Rooms) do
            if room.id == roomId or tostring(room.id) == strId or (numId and tonumber(room.id) == numId) then
                local bId = room.buildingId or room.building_id or buildingId or GetApartmentBuildingId(roomId)
                local b = Bridge.GetApartmentBuildingById(bId, true)
                local cloned = table.clone(room)
                cloned.buildingId = b and b.id or bId
                cloned.building_id = cloned.buildingId
                cloned.buildingLabel = b and b.label or 'Apartments'
                return cloned
            end
        end
    end

    if IsStarterInstanceMode() then
        return GetStarterApartmentRoomData(roomId, buildingId)
    end
    return nil
end
local getRoomDataById = GetRoomDataByIdServer

local function getAvailableRoom(buildingId)
    if #Settings.Rooms == 0 then
        local Rooms = MySQL.query.await('SELECT * FROM apartment_rooms')
        if Rooms and #Rooms > 0 then
            for _, r in ipairs(Rooms) do
                local corners = r.corners and json.decode(r.corners) or nil
                local cornersVec = {}
                if corners and type(corners) == 'table' then
                    for i, c in ipairs(corners) do
                        cornersVec[i] = vec3(c.x, c.y, c.z)
                    end
                end
                
                local doorCoords = nil
                if r.door_coords then
                    local dc = json.decode(r.door_coords)
                    doorCoords = vec3(dc.x, dc.y, dc.z)
                end
                
                local sc = r.spawn_coords and json.decode(r.spawn_coords)
                local spawnVec = sc and vec4(sc.x, sc.y, sc.z, sc.w or sc.h or 0.0) or (doorCoords and vec4(doorCoords.x, doorCoords.y, doorCoords.z, r.door_heading or 0.0))
                
                local tabletCoords = nil
                if r.tablet_coords then
                    tabletCoords = json.decode(r.tablet_coords)
                end

                local interiorCoords = r.interior_coords and json.decode(r.interior_coords) or nil
                local interiorCenter = r.interior_center and json.decode(r.interior_center) or nil

                local rBuildingId = r.building_id
                if not rBuildingId or rBuildingId == '' then
                    local refCoords = doorCoords or (spawnVec and vec3(spawnVec.x, spawnVec.y, spawnVec.z))
                    local nearest = Bridge.GetNearestApartmentBuilding(refCoords)
                    rBuildingId = nearest and nearest.id or 'wiwang'
                end
                roomBuildings[r.id] = rBuildingId

                table.insert(Settings.Rooms, {
                    id = r.id,
                    buildingId = rBuildingId,
                    building_id = rBuildingId,
                    corners = cornersVec,
                    thickness = r.thickness,
                    zOffset = r.zOffset,
                    doorModel = r.door_model,
                    doorCoords = doorCoords,
                    doorHeading = r.door_heading,
                    spawn = spawnVec,
                    price = r.price,
                    isStarter = (r.is_starter == 1 or r.is_starter == true),
                    tabletCoords = tabletCoords,
                    interior_id = tonumber(r.interior_id) or nil,
                    interior_coords = interiorCoords,
                    interior_center = interiorCenter,
                    room_count = tonumber(r.room_count) or nil,
                    room_name = r.room_name,
                    room_key = tonumber(r.room_key) or nil
                })
            end

            pcall(CreateApartmentDoorlocks)
        end
    end

    local available = {}
    for _, room in ipairs(Settings.Rooms) do
        if room.isStarter and not assignedRoomIds[room.id] then
            if not buildingId or tostring(room.buildingId):lower() == tostring(buildingId):lower() then
                table.insert(available, room)
            end
        end
    end
    
    if #available > 0 then
        local selected = available[math.random(#available)]
        return selected
    end

    if buildingId then
        for _, room in ipairs(Settings.Rooms) do
            if room.isStarter and not assignedRoomIds[room.id] then
                table.insert(available, room)
            end
        end
        if #available > 0 then
            return available[math.random(#available)]
        end
    end

    return nil
end

local function getPlayerRoom(src, citizenid, isNew)
    local lic1, lic2 = GetPlayerLicense(src)
    if not lic1 and not lic2 then return nil end

    if playerRooms[lic1] then return playerRooms[lic1], playerRoomBuildings[lic1] end
    if lic2 and playerRooms[lic2] then return playerRooms[lic2], playerRoomBuildings[lic2] end

    local result = MySQL.single.await('SELECT room_id, building_id FROM player_apartments WHERE license = ? OR license = ?', {lic1, lic2})
    if result then
        local bId = result.building_id or GetApartmentBuildingId(result.room_id)
        playerRooms[lic1] = result.room_id
        playerRoomBuildings[lic1] = bId
        if lic2 then
            playerRooms[lic2] = result.room_id
            playerRoomBuildings[lic2] = bId
        end
        assignedRoomIds[result.room_id] = true
        roomBuildings[result.room_id] = bId
        return result.room_id, bId
    end

    if IsStarterInstanceMode() then
        local buildings = Bridge.GetApartmentBuildings()
        local chosenBuilding = nil
        local defaultBId = Settings.Apartments and Settings.Apartments.Starter and Settings.Apartments.Starter.DefaultBuilding
        if defaultBId then
            chosenBuilding = Bridge.GetApartmentBuildingById(defaultBId, false)
        end
        if not chosenBuilding and #buildings > 0 then
            chosenBuilding = buildings[math.random(#buildings)]
        end
        local chosenBuildingId = chosenBuilding and chosenBuilding.id or 'wiwang'

        local maxRow = MySQL.single.await('SELECT COALESCE(MAX(room_id), 0) AS max_id FROM player_apartments')
        local newRoomId = (maxRow and tonumber(maxRow.max_id) or 0) + 1
        local isNewChar = not not isNew

        local insertSuccess = pcall(function()
            MySQL.insert.await('INSERT INTO player_apartments (license, room_id, building_id, is_new) VALUES (?, ?, ?, ?)', {
                lic1,
                newRoomId,
                chosenBuildingId,
                isNewChar and 1 or 0
            })
        end)

        if insertSuccess then
            playerRooms[lic1] = newRoomId
            playerRoomBuildings[lic1] = chosenBuildingId
            if lic2 then
                playerRooms[lic2] = newRoomId
                playerRoomBuildings[lic2] = chosenBuildingId
            end
            assignedRoomIds[newRoomId] = true
            roomBuildings[newRoomId] = chosenBuildingId
            return newRoomId, chosenBuildingId
        else
            local r = MySQL.single.await('SELECT room_id, building_id FROM player_apartments WHERE license = ? OR license = ?', {lic1, lic2})
            if r then
                local bId = r.building_id or chosenBuildingId
                playerRooms[lic1] = r.room_id
                playerRoomBuildings[lic1] = bId
                if lic2 then
                    playerRooms[lic2] = r.room_id
                    playerRoomBuildings[lic2] = bId
                end
                assignedRoomIds[r.room_id] = true
                roomBuildings[r.room_id] = bId
                return r.room_id, bId
            end
        end
        return nil
    end

    local defaultBId = Settings.Apartments and Settings.Apartments.Starter and Settings.Apartments.Starter.DefaultBuilding
    local room = getAvailableRoom(defaultBId)
    if room then
        assignedRoomIds[room.id] = true
        local isNewChar = not not isNew
        local bId = room.buildingId or GetApartmentBuildingId(room.id)

        local insertSuccess = pcall(function()
            MySQL.insert.await('INSERT INTO player_apartments (license, room_id, building_id, is_new) VALUES (?, ?, ?, ?)', {
                lic1,
                room.id,
                bId,
                isNewChar and 1 or 0
            })
        end)

        if insertSuccess then
            playerRooms[lic1] = room.id
            playerRoomBuildings[lic1] = bId
            if lic2 then
                playerRooms[lic2] = room.id
                playerRoomBuildings[lic2] = bId
            end
            roomBuildings[room.id] = bId
            SyncApartmentDoor(room.id)
            return room.id, bId
        else
            assignedRoomIds[room.id] = nil
            local r = MySQL.single.await('SELECT room_id, building_id FROM player_apartments WHERE license = ? OR license = ?', {lic1, lic2})
            if r then
                local foundBId = r.building_id or bId
                playerRooms[lic1] = r.room_id
                playerRoomBuildings[lic1] = foundBId
                if lic2 then
                    playerRooms[lic2] = r.room_id
                    playerRoomBuildings[lic2] = foundBId
                end
                assignedRoomIds[r.room_id] = true
                roomBuildings[r.room_id] = foundBId
                return r.room_id, foundBId
            end
        end
    end
    return nil
end

local function OnPlayerLoaded(src)
    WaitForDb()
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then 
        return 
    end

    local roomId, buildingId = getPlayerRoom(src, citizenid, false)
    if not roomId then
        local currentTime = GetGameTimer()
        if not lastNoRoomNotify[src] or (currentTime - lastNoRoomNotify[src]) > 5000 then
            lastNoRoomNotify[src] = currentTime
            Bridge.Server.Notify(src, locale('notify.no_available_apartments'), 'error')
        end
        return
    end

    buildingId = buildingId or GetApartmentBuildingId(roomId)
    local roomData = getRoomDataById(roomId, buildingId)
    if roomData then
        local result = MySQL.single.await('SELECT id FROM apartments WHERE citizenid = ? AND room_id = ?', {citizenid, roomId})
        if not result then
            local initialFurniture = {}
            if roomData.tabletCoords then
                table.insert(initialFurniture, CreateDefaultPanelFurniture(roomData.tabletCoords.position, roomData.tabletCoords.rotation))
            end

            MySQL.insert.await('INSERT INTO apartments (citizenid, room_id, permissions, furniture, wall_color) VALUES (?, ?, ?, ?, ?)', {
                citizenid,
                roomId,
                json.encode({entry = {}, storage = {}, wardrobe = {}, manage = {}}),
                json.encode(initialFurniture),
                0
            })
            exports.LNS_Housing:GiveApartmentPhysicalKey(roomId, src)
        end
        
        SyncApartmentDoor(roomId)
        
        TriggerClientEvent('LNS_Housing:client:setApartmentData', src, roomId, roomData, buildingId)
    end
end

local function OnPlayerUnloaded(src)
    if not src then return end
    lastNoRoomNotify[src] = nil
    SetPlayerRoutingBucket(src, 0)
    pcall(function()
        Player(src).state:set('inProperty', false, true)
        Player(src).state:set('insidePropertyId', nil, true)
    end)
    TriggerClientEvent('LNS_Housing:client:cleanUpApartmentSession', src)
    TriggerClientEvent('LNS_Housing:client:cleanUpHousingSession', src)
end

if Bridge.Framework == 'qbx' then
    AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
        local src = player and (player.PlayerData and player.PlayerData.source or player.source) or source
        if src then OnPlayerLoaded(src) end
    end)
    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
        local src = source
        if src then OnPlayerLoaded(src) end
    end)
    AddEventHandler('qbx_core:server:playerLoaded', function(playerData)
        local src = playerData and (playerData.PlayerData and playerData.PlayerData.source or playerData.source) or source
        if src then OnPlayerLoaded(src) end
    end)
    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
        src = src or source
        if src then OnPlayerUnloaded(src) end
    end)
    AddEventHandler('playerDropped', function()
        local src = source
        if src then OnPlayerUnloaded(src) end
    end)
elseif Bridge.Framework == 'esx' then
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        OnPlayerLoaded(playerId)
    end)
    AddEventHandler('esx:playerLogout', function(playerId)
        OnPlayerUnloaded(playerId)
    end)
    AddEventHandler('esx:playerDropped', function(playerId)
        OnPlayerUnloaded(playerId)
    end)
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(1000)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local src = tonumber(playerId)
        if src then
            OnPlayerLoaded(src)
        end
    end
end)

lib.callback.register('LNS_Housing:server:getMyApartment', function(source)
    WaitForDb()
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return nil end
    
    local roomId, buildingId = getPlayerRoom(source, citizenid, true)
    if roomId then
        buildingId = buildingId or GetApartmentBuildingId(roomId)
        local roomData = getRoomDataById(roomId, buildingId)
        local building = Bridge.GetApartmentBuildingById(buildingId, true)
        return { 
            roomId = roomId, 
            room_id = roomId, 
            roomData = roomData,
            buildingId = buildingId,
            building_id = buildingId,
            buildingLabel = building and building.label or "Apartments"
        }
    end
    return nil
end)

lib.callback.register('LNS_Housing:server:claimNewCharacterSpawn', function(source)
    debugPrint('info', 'LNS_Housing:server:claimNewCharacterSpawn called', {source = source})
    WaitForDb()
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return { shouldSpawn = false } end

    local roomId, buildingId = getPlayerRoom(source, citizenid, false)
    if not roomId then return { shouldSpawn = false } end
    buildingId = buildingId or GetApartmentBuildingId(roomId)

    local result = MySQL.single.await('SELECT is_new FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    if not result then
        local roomData = getRoomDataById(roomId, buildingId)
        local initialFurniture = {}
        if roomData and roomData.tabletCoords then
            table.insert(initialFurniture, CreateDefaultPanelFurniture(roomData.tabletCoords.position, roomData.tabletCoords.rotation))
        end

        MySQL.insert.await('INSERT INTO apartments (citizenid, room_id, permissions, furniture, wall_color, is_new) VALUES (?, ?, ?, ?, ?, ?)', {
            citizenid,
            roomId,
            json.encode({entry = {}, storage = {}, wardrobe = {}, manage = {}}),
            json.encode(initialFurniture),
            0,
            1
        })
        result = { is_new = 1 }
    end

    if result and result.is_new == 1 then
        MySQL.update.await('UPDATE apartments SET is_new = 0 WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
        exports.LNS_Housing:GiveApartmentPhysicalKey(roomId, source)
        
        local roomData = getRoomDataById(roomId, buildingId)
        if roomData then
            return {
                shouldSpawn = true,
                roomId = roomId,
                spawnCoords = roomData.spawn,
                isInstance = roomData.isInstance,
                roomData = roomData,
                buildingId = buildingId
            }
        end
    end

    return { shouldSpawn = false }
end)

local apartmentGuestAccess = {}

RegisterNetEvent('LNS_Housing:server:enterApartmentBucket', function(roomId, buildingId)
    local src = source
    debugPrint('info', 'LNS_Housing:server:enterApartmentBucket received', {src = src, roomId = roomId, buildingId = buildingId})
    roomId = tonumber(roomId) or roomId
    if not roomId then return end

    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    local actualBuildingId = GetApartmentBuildingId(roomId)
    if buildingId and actualBuildingId and buildingId ~= actualBuildingId then
        local bldg = Bridge.GetApartmentBuildingById(actualBuildingId, true)
        local bLabel = bldg and bldg.label or actualBuildingId
        Bridge.Server.Notify(src, locale('notify.apt_wrong_building', bLabel), 'error')
        return
    end

    local hasAccess = false
    local isOwner = false
    local result = MySQL.single.await('SELECT citizenid, permissions, furniture FROM apartments WHERE room_id = ? OR room_id = ?', {roomId, tostring(roomId)})
    if result then
        if result.citizenid == citizenid then
            hasAccess = true
            isOwner = true
        elseif result.permissions then
            local perms = json.decode(result.permissions)
            if perms and perms.entry then
                for _, cid in ipairs(perms.entry) do
                    if cid == citizenid then
                        hasAccess = true
                        break
                    end
                end
            end
        end
    end

    local pk = Settings.Security and Settings.Security.PhysicalKeys
    if pk and pk.Enabled and not hasAccess then
        local count = exports.ox_inventory:GetItemCount(src, pk.Item, { propertyId = roomId, isApartment = true })
        if count and count > 0 then
            hasAccess = true
        end
    end

    local job = Bridge.Server.GetPlayerJob(src)
    if job and Bridge.IsPoliceJob(job) and IsPropertyBreached and IsPropertyBreached(roomId, true) then
        hasAccess = true
    end

    if apartmentGuestAccess[roomId] and apartmentGuestAccess[roomId][src] then
        hasAccess = true
    end

    if not hasAccess and not isOwner then
        local lic1, lic2 = GetPlayerLicense(src)
        if (lic1 and playerRooms[lic1] and (playerRooms[lic1] == roomId or tostring(playerRooms[lic1]) == tostring(roomId))) or
           (lic2 and playerRooms[lic2] and (playerRooms[lic2] == roomId or tostring(playerRooms[lic2]) == tostring(roomId))) then
            hasAccess = true
        end
    end

    if not hasAccess then
        Bridge.Server.Notify(src, locale('notify.no_key_access'), 'error')
        return
    end

    local bId = actualBuildingId or buildingId
    local bldg = Bridge.GetApartmentBuildingById(bId, true)
    local cfg = (bldg and bldg.starter) or (Settings.Apartments and Settings.Apartments.Starter)
    local bucketOffset = (cfg and cfg.BucketOffset) or 20000
    local targetBucket = bucketOffset + (tonumber(roomId) or 1)

    SetPlayerRoutingBucket(src, targetBucket)
    Player(src).state:set('inProperty', true, true)
    Player(src).state:set('insidePropertyId', roomId, true)
    Player(src).state:set('insideApartment', true, true)
    Player(src).state:set('apartmentBucket', targetBucket, true)
    Player(src).state:set('apartmentBuildingId', bId, true)
    Bridge.Server.SetPlayerInside(src, roomId)

    if (bldg and bldg.stash) or (cfg and cfg.Stash) then
        local stashSlots = (Settings.Stash and Settings.Stash.slots) or 50
        local stashWeight = (Settings.Stash and Settings.Stash.weight) or 100000
        local stashLabel = (Settings.Stash and Settings.Stash.label) or 'Apartment Storage'
        Bridge.Server.RegisterStash(roomId, 'starter_stash', { slots = stashSlots, weight = stashWeight }, stashLabel)
    end

    if result and result.furniture then
        local furnitureList = json.decode(result.furniture)
        if furnitureList and Bridge.Server.RegisterPropertyStashes then
            Bridge.Server.RegisterPropertyStashes(roomId, furnitureList)
        end
    end
end)

RegisterNetEvent('LNS_Housing:server:leaveApartmentBucket', function()
    local src = source
    debugPrint('info', 'LNS_Housing:server:leaveApartmentBucket received', {src = src})
    SetPlayerRoutingBucket(src, 0)
    Player(src).state:set('inProperty', false, true)
    Player(src).state:set('insidePropertyId', nil, true)
    Player(src).state:set('insideApartment', false, true)
    Player(src).state:set('apartmentBucket', nil, true)
    Player(src).state:set('apartmentBuildingId', nil, true)
    Bridge.Server.ClearPlayerInside(src)
end)

lib.callback.register('LNS_Housing:server:canEnterApartment', function(source, roomId, buildingId)
    roomId = tonumber(roomId) or roomId
    if not roomId then return false end
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return false end

    if buildingId then
        local actualBId = GetApartmentBuildingId(roomId)
        if actualBId and actualBId ~= buildingId then
            return false
        end
    end

    local lic1, lic2 = GetPlayerLicense(source)
    if (lic1 and playerRooms[lic1] and (playerRooms[lic1] == roomId or tostring(playerRooms[lic1]) == tostring(roomId))) or
       (lic2 and playerRooms[lic2] and (playerRooms[lic2] == roomId or tostring(playerRooms[lic2]) == tostring(roomId))) then
        return true
    end

    local result = MySQL.single.await('SELECT citizenid, permissions FROM apartments WHERE room_id = ? OR room_id = ?', {roomId, tostring(roomId)})
    if result then
        if result.citizenid == citizenid then return true end
        if result.permissions then
            local perms = json.decode(result.permissions)
            if perms and perms.entry then
                for _, cid in ipairs(perms.entry) do
                    if cid == citizenid then return true end
                end
            end
        end
    end

    local pk = Settings.Security and Settings.Security.PhysicalKeys
    if pk and pk.Enabled then
        local count = exports.ox_inventory:GetItemCount(source, pk.Item, { propertyId = roomId, isApartment = true })
        if count and count > 0 then return true end
    end

    return false
end)

lib.callback.register('LNS_Housing:server:getApartmentRoomData', function(source, roomId, buildingId)
    roomId = tonumber(roomId) or roomId
    if not roomId then return nil end
    buildingId = buildingId or GetApartmentBuildingId(roomId)
    return getRoomDataById(roomId, buildingId)
end)

local function FindManagedApartment(roomId, citizenid)
    local results = MySQL.query.await('SELECT citizenid, permissions, furniture FROM apartments WHERE room_id = ? OR room_id = ?', {roomId, tostring(roomId)})
    if not results then return nil end

    for _, row in ipairs(results) do
        if row.citizenid == citizenid then
            return row
        end
        if row.permissions then
            local perms = json.decode(row.permissions)
            if perms and perms.manage then
                for _, cid in ipairs(perms.manage) do
                    if cid == citizenid then
                        return row
                    end
                end
            end
        end
    end
    return nil
end

lib.callback.register('LNS_Housing:server:getApartmentInfo', function(source, roomId, buildingId)
    debugPrint('info', 'LNS_Housing:server:getApartmentInfo called', {source = source, roomId = roomId, buildingId = buildingId})
    WaitForDb()
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return nil end

    local bId = buildingId or GetApartmentBuildingId(roomId)
    local license = GetPlayerLicense(source)

    local result = MySQL.single.await('SELECT * FROM apartments WHERE (room_id = ? OR room_id = ?) AND citizenid = ?', {roomId, tostring(roomId), citizenid})
    if not result then
        result = FindManagedApartment(roomId, citizenid)
        if not result then
            result = MySQL.single.await('SELECT * FROM apartments WHERE (room_id = ? OR room_id = ?) ORDER BY id ASC LIMIT 1', {roomId, tostring(roomId)})
        end
    end

    if not result and license then
        local checkApt = MySQL.single.await('SELECT room_id FROM player_apartments WHERE license = ?', {license})
        if checkApt and (checkApt.room_id == roomId or tostring(checkApt.room_id) == tostring(roomId) or tonumber(checkApt.room_id) == tonumber(roomId)) then
            local roomData = getRoomDataById(roomId, bId)
            local initialFurniture = {}
            if roomData and roomData.tabletCoords then
                table.insert(initialFurniture, CreateDefaultPanelFurniture(roomData.tabletCoords.position, roomData.tabletCoords.rotation))
            end
            MySQL.insert.await('INSERT INTO apartments (citizenid, room_id, permissions, furniture, wall_color) VALUES (?, ?, ?, ?, ?)', {
                citizenid,
                roomId,
                json.encode({entry = {}, storage = {}, wardrobe = {}, furniture = {}, manage = {}}),
                json.encode(initialFurniture),
                0
            })
            result = MySQL.single.await('SELECT * FROM apartments WHERE (room_id = ? OR room_id = ?) AND citizenid = ?', {roomId, tostring(roomId), citizenid})
        end
    end
    if result then
        local furnitureList = json.decode(result.furniture or '[]')
        local roomData = getRoomDataById(roomId, bId)
        if roomData and roomData.tabletCoords then
            local hasTablet = false
            local changed = false
            for _, f in ipairs(furnitureList) do
                if f.isPanel or IsPanelModel(f.model) then
                    local newPos = vec3(roomData.tabletCoords.position.x, roomData.tabletCoords.position.y, roomData.tabletCoords.position.z)
                    local newRot = vec3(roomData.tabletCoords.rotation.x, roomData.tabletCoords.rotation.y, roomData.tabletCoords.rotation.z)
                    local function isClose(v1, v2)
                        if not v1 or not v2 then return false end
                        return math.abs((v1.x or v1[1] or 0.0) - (v2.x or 0.0)) < 0.01 and
                               math.abs((v1.y or v1[2] or 0.0) - (v2.y or 0.0)) < 0.01 and
                               math.abs((v1.z or v1[3] or 0.0) - (v2.z or 0.0)) < 0.01
                    end
                    if not isClose(f.position, newPos) or not isClose(f.rotation, newRot) then
                        f.position = newPos
                        f.rotation = newRot
                        changed = true
                    end
                    hasTablet = true
                    break
                end
            end
            if not hasTablet then
                table.insert(furnitureList, CreateDefaultPanelFurniture(roomData.tabletCoords.position, roomData.tabletCoords.rotation))
                changed = true
            end
            if changed then
                MySQL.update.await('UPDATE apartments SET furniture = ? WHERE room_id = ? AND citizenid = ?', {
                    json.encode(furnitureList),
                    roomId,
                    result.citizenid
                })
            end
        end
        local permissions = json.decode(result.permissions or '{"entry":[], "storage":[], "wardrobe":[], "manage":[]}')
        local ownerName = 'Unknown'
        local ownerPlayer = Bridge.Server.IsPlayerOnline(result.citizenid)

        if ownerPlayer then
            ownerName = Bridge.Server.GetPlayerName(ownerPlayer.PlayerData.source)
        else
            local dbResult = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', {result.citizenid})
            if dbResult and dbResult.charinfo then
                local charinfo = json.decode(dbResult.charinfo)
                ownerName = charinfo.firstname .. ' ' .. charinfo.lastname
            end
        end

        if Bridge.Server.RegisterPropertyStashes then
            Bridge.Server.RegisterPropertyStashes(roomId, furnitureList)
        end

        return {
            owner = result.citizenid,
            ownerName = ownerName,
            permissions = permissions,
            furniture = furnitureList,
            wallColor = result.wall_color,
            security_level = tonumber(result.security_level) or 0,
            buildingId = bId,
            building_id = bId
        }
    end
    return nil
end)

lib.callback.register('LNS_Housing:server:getApartmentSecurityLevel', function(source, roomId)
    local result = MySQL.single.await('SELECT security_level FROM apartments WHERE room_id = ? OR room_id = ? ORDER BY security_level DESC LIMIT 1', {roomId, tostring(roomId)})
    if result and result.security_level then
        return tonumber(result.security_level) or 0
    end
    return 0
end)

RegisterNetEvent('LNS_Housing:server:updateApartmentPermissions', function(roomId, permissions)
    local src = source
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    local result = MySQL.single.await('SELECT citizenid, wall_color FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    if result then
        local uniqueResidents = {}
        for category, cids in pairs(permissions) do
            for _, cid in ipairs(cids) do
                if cid ~= citizenid then
                    uniqueResidents[cid] = true
                end
            end
        end
        
        local count = 0
        for _ in pairs(uniqueResidents) do
            count = count + 1
        end
        
        if count > Settings.MaxKeys then
            Bridge.Server.Notify(src, locale('notify.max_keys_reached', Settings.MaxKeys), 'error')
            return
        end

        MySQL.update.await('UPDATE apartments SET permissions = ? WHERE room_id = ? AND citizenid = ?', {
            json.encode(permissions),
            roomId,
            citizenid
        })
        
        SyncApartmentDoor(roomId)

        local ownerName = Bridge.Server.GetPlayerName(src)

        TriggerClientEvent('LNS_Housing:client:updateApartmentProperties', -1, roomId, {
            owner = citizenid,
            ownerName = ownerName,
            permissions = permissions,
            wallColor = result.wall_color or 0
        })
        
        Bridge.Server.Notify(src, locale('notify.apt_perms_updated'), 'success')
    end
end)

RegisterNetEvent('LNS_Housing:server:updateApartmentWallColor', function(roomId, color)
    local src = source
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    local row = FindManagedApartment(roomId, citizenid)
    if row then
        MySQL.update.await('UPDATE apartments SET wall_color = ? WHERE room_id = ? AND citizenid = ?', {
            color,
            roomId,
            row.citizenid
        })
        TriggerClientEvent('LNS_Housing:client:updateApartmentWallColor', -1, roomId, color)
    end
end)

RegisterNetEvent('LNS_Housing:server:saveApartmentFurniture', function(roomId, furnitureData)
    local src = source
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    local result = FindManagedApartment(roomId, citizenid)
    if result then
        MySQL.update.await('UPDATE apartments SET furniture = ? WHERE room_id = ? AND citizenid = ?', {
            json.encode(furnitureData),
            roomId,
            result.citizenid
        })

        if Bridge.Server.RegisterPropertyStashes then
            Bridge.Server.RegisterPropertyStashes(roomId, furnitureData)
        end
        if CalculatePropertyPowerAndTemp then CalculatePropertyPowerAndTemp(roomId) end
        
        TriggerClientEvent('LNS_Housing:client:updateApartmentFurniture', -1, roomId, furnitureData)
    end
end)

local function ProcessBuyApartmentFurniture(src, roomId, items, totalPrice, paymentMethod)
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return false, 'No identifier' end

    if type(items) ~= 'table' then
        Bridge.Server.Notify(src, locale('notify.invalid_furniture_payload'), 'error')
        return false, 'Invalid payload'
    end

    local price = tonumber(totalPrice)
    if not price or price ~= price then
        Bridge.Server.Notify(src, locale('notify.invalid_purchase_amount'), 'error')
        return false, 'Invalid amount'
    end

    price = math.floor(price + 0.0)
    if price < 0 then
        Bridge.Server.Notify(src, locale('notify.invalid_purchase_amount'), 'error')
        return false, 'Invalid amount'
    end

    local result = FindManagedApartment(roomId, citizenid)
    if not result then
        Bridge.Server.Notify(src, locale('notify.no_apt_manage_perm'), 'error')
        return false, 'No access'
    end

    local payType = paymentMethod == 'cash' and 'cash' or 'bank'
    local money = Bridge.Server.GetMoney(src, payType)
    if price > 0 then
        if money < price then
            local targetAccountName = payType == 'cash' and 'cash' or 'bank account'
            Bridge.Server.Notify(src, locale('notify.not_enough_money_account', targetAccountName), 'error')
            return false, 'Not enough money'
        end

        local removed = Bridge.Server.RemoveMoney(src, payType, price, "Bought furniture for apartment #" .. roomId)
        if not removed then
            local targetAccountName = payType == 'cash' and 'cash' or 'bank'
            Bridge.Server.Notify(src, locale('notify.could_not_process_payment_account', targetAccountName), 'error')
            return false, 'Payment failed'
        end
    end

    local currentFurniture = {}
    if result.furniture and result.furniture ~= '' then
        local okDecode, decoded = pcall(function()
            return json.decode(result.furniture)
        end)

        if okDecode and type(decoded) == 'table' then
            currentFurniture = decoded
        end
    end

    for _, item in ipairs(items) do
        table.insert(currentFurniture, item)
    end

    local okEncode, furnitureJson = pcall(function()
        return json.encode(currentFurniture)
    end)
    if not okEncode then
        Bridge.Server.Notify(src, locale('notify.could_not_process_furniture'), 'error')
        return false, 'Encode failed'
    end

    local okUpdate, updateResult = pcall(function()
        return MySQL.update.await('UPDATE apartments SET furniture = ? WHERE room_id = ? AND citizenid = ?', {
            furnitureJson,
            roomId,
            result.citizenid
        })
    end)
    if not okUpdate then
        Bridge.Server.Notify(src, locale('notify.database_error'), 'error')
        return false, 'Database error'
    end

    if Bridge.Server.RegisterPropertyStashes then
        Bridge.Server.RegisterPropertyStashes(roomId, currentFurniture)
    end
    if CalculatePropertyPowerAndTemp then CalculatePropertyPowerAndTemp(roomId) end

    TriggerClientEvent('LNS_Housing:client:updateApartmentFurniture', -1, roomId, currentFurniture)
    Bridge.Server.Notify(src, locale('notify.furniture_purchased'), 'success')
    return true
end

lib.callback.register('LNS_Housing:server:buyApartmentFurniture', function(source, roomId, items, totalPrice, paymentMethod)
    return ProcessBuyApartmentFurniture(source, roomId, items, totalPrice, paymentMethod)
end)

RegisterNetEvent('LNS_Housing:server:buyApartmentFurniture', function(roomId, items, totalPrice, paymentMethod)
    ProcessBuyApartmentFurniture(source, roomId, items, totalPrice, paymentMethod)
end)

local function GetEntranceCoordsServer(p)
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
        local door = nil
        if exports.ox_doorlock and exports.ox_doorlock.getDoor then
            pcall(function() door = exports.ox_doorlock:getDoor(doorId) end)
        elseif exports.ox_doorlock and exports.ox_doorlock.getDoorData then
            pcall(function() door = exports.ox_doorlock:getDoorData(doorId) end)
        end
        if door and door.coords then
            return vec3(door.coords.x, door.coords.y, door.coords.z)
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

local function GetPropertyCoords(p)
    if not p then return nil end

    if p.metadata and p.metadata.shell and p.metadata.shell ~= 'mlo' then
        local shellName = p.metadata.shell or 'Standard Motel'
        local shellData = (Settings.IPLs and Settings.IPLs[shellName]) or Settings.Shells[shellName]
        if shellData then
            if shellData.ipls then
                return vector4(shellData.coords.x, shellData.coords.y, shellData.coords.z, shellData.coords.w or 0.0)
            end
            local doorCoords = GetEntranceCoordsServer(p)
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
    end

    if p.metadata and p.metadata.spawn then
        local sp = p.metadata.spawn
        return vector4(sp.x, sp.y, sp.z, sp.h or sp.w or 0.0)
    end
    
    return nil
end

local function GetPlayerSpawnsServer(source)
    local spawns = {}

    if Settings.Apartments and Settings.Apartments.Enabled then
        local citizenid = Bridge.Server.GetIdentifier(source)
        if citizenid then
            local roomId = playerRooms[citizenid]
            if not roomId then
                local license = GetPlayerLicense(source)
                roomId = license and playerRooms[license]
            end
            
            if roomId then
                local bId = playerRoomBuildings[citizenid] or (license and playerRoomBuildings[license]) or GetApartmentBuildingId(roomId)
                local roomData = getRoomDataById(roomId, bId)
                local building = Bridge.GetApartmentBuildingById(bId, true)
                local bLabel = building and building.label or locale('target.apartment_room_prefix')
                if roomData then
                    table.insert(spawns, {
                        id = roomId,
                        type = "apartment",
                        label = bLabel .. ' #' .. roomId,
                        coords = roomData.spawn,
                        buildingId = bId
                    })
                end
            end
        end
    end

    local citizenid = Bridge.Server.GetIdentifier(source)
    if citizenid then
        for id, p in pairs(Properties) do
            local hasAccess = false
            if p.owner == citizenid then
                hasAccess = true
            elseif p.permissions and p.permissions.entry then
                for _, cid in ipairs(p.permissions.entry) do
                    if cid == citizenid then
                        hasAccess = true
                        break
                    end
                end
            end
            
            if hasAccess then
                table.insert(spawns, {
                    id = id,
                    type = "house",
                    label = p.label
                })
            end
        end
    end
    
    return spawns
end

lib.callback.register('LNS_Housing:server:getPlayerSpawns', function(source)
    debugPrint('info', 'LNS_Housing:server:getPlayerSpawns called', {source = source})
    WaitForDb()
    return GetPlayerSpawnsServer(source)
end)

exports('GetPlayerSpawns', function(source)
    local spawns = GetPlayerSpawnsServer(source)
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

function IsApartmentAdmin(source)
    return CheckPermission(source, 'admin')
end

lib.callback.register('LNS_Housing:server:doesApartmentExist', function(source, roomId)
    debugPrint('info', 'LNS_Housing:server:doesApartmentExist called', {source = source, roomId = roomId})
    for _, room in ipairs(Settings.Rooms) do
        if room.id == roomId or tostring(room.id) == tostring(roomId) or (tonumber(room.id) and tonumber(roomId) and tonumber(room.id) == tonumber(roomId)) then
            return true
        end
    end
    return false
end)

lib.callback.register('LNS_Housing:server:getApartmentRooms', function(source)
    debugPrint('info', 'LNS_Housing:server:getApartmentRooms called', {source = source})
    WaitForDb()
    local Rooms = MySQL.query.await('SELECT * FROM apartment_rooms')
    local formatted = {}
    if Rooms then
        for _, r in ipairs(Rooms) do
            local corners = r.corners and json.decode(r.corners) or nil
            local doorCoords = nil
            if r.door_coords then
                doorCoords = json.decode(r.door_coords)
            end
            local sc = r.spawn_coords and json.decode(r.spawn_coords)
            local tabletCoords = nil
            if r.tablet_coords then
                tabletCoords = json.decode(r.tablet_coords)
            end
            local interiorCoords = r.interior_coords and json.decode(r.interior_coords) or nil
            local interiorCenter = r.interior_center and json.decode(r.interior_center) or nil

            local bId = r.building_id
            if not bId then
                local bldg = Bridge.GetNearestApartmentBuilding(sc or doorCoords)
                bId = bldg and bldg.id or 'wiwang'
            end

            table.insert(formatted, {
                id = r.id,
                corners = corners,
                thickness = r.thickness,
                zOffset = r.zOffset,
                doorModel = r.door_model,
                doorCoords = doorCoords,
                doorHeading = r.door_heading,
                spawn = sc and {x = sc.x, y = sc.y, z = sc.z, w = sc.w or sc.h or 0.0} or nil,
                price = r.price,
                isStarter = (r.is_starter == 1 or r.is_starter == true),
                tabletCoords = tabletCoords,
                interiorId = tonumber(r.interior_id) or nil,
                interiorCoords = interiorCoords,
                interiorCenter = interiorCenter,
                roomCount = tonumber(r.room_count) or nil,
                roomName = r.room_name,
                roomKey = tonumber(r.room_key) or nil,
                buildingId = bId,
                building_id = bId
            })
        end
    end
    return formatted
end)

lib.callback.register('LNS_Housing:server:createApartment', function(source, data)
    debugPrint('info', 'LNS_Housing:server:createApartment called', {source = source, data = data})
    WaitForDb()
    if not IsApartmentAdmin(source) then return false end

    local roomId = tonumber(data.id)
    local corners = data.corners
    local thickness = tonumber(data.thickness) or 3.5
    local zOffset = tonumber(data.zOffset) or 0.0
    local door = data.door
    local spawn = data.spawn
    local price = 0
    local isStarter = true
    local doorModel = nil
    local doorCoords = nil
    local doorHeading = nil

    local interiorId = tonumber(data.interiorId or data.interior_id or (data.spawn and data.spawn.interior and data.spawn.interior.interiorId)) or nil
    local interiorCoords = data.interiorCoords or data.interior_coords or nil
    local interiorCenter = data.interiorCenter or data.interior_center or (data.spawn and data.spawn.interior and data.spawn.interior.center) or nil
    local roomCount = tonumber(data.roomCount or data.room_count or (data.spawn and data.spawn.interior and data.spawn.interior.roomCount)) or nil
    local roomName = data.roomName or data.room_name or (data.spawn and data.spawn.interior and data.spawn.interior.roomName) or nil
    local roomKey = tonumber(data.roomKey or data.room_key or (data.spawn and data.spawn.interior and data.spawn.interior.roomKey)) or nil

    if door then
        if type(door) == 'table' then
            doorModel = door.model
            if door.coords then
                doorCoords = {x = door.coords.x, y = door.coords.y, z = door.coords.z}
            end
            doorHeading = door.heading
        else
            local doorData = nil
            if exports.ox_doorlock and exports.ox_doorlock.getDoor then
                pcall(function() doorData = exports.ox_doorlock:getDoor(door) end)
            elseif exports.ox_doorlock and exports.ox_doorlock.getDoorData then
                pcall(function() doorData = exports.ox_doorlock:getDoorData(door) end)
            end
            
            if doorData then
                doorModel = doorData.model
                if doorData.coords then
                    doorCoords = {x = doorData.coords.x, y = doorData.coords.y, z = doorData.coords.z}
                end
                doorHeading = doorData.heading
            end
        end
    end

    local tabletCoords = data.tabletCoords
    local buildingId = data.buildingId or data.building_id
    if not buildingId then
        local bldg = Bridge.GetNearestApartmentBuilding(spawn or doorCoords)
        buildingId = bldg and bldg.id or 'wiwang'
    end

    local success = MySQL.insert.await([[
        INSERT INTO apartment_rooms (id, corners, thickness, zOffset, door_model, door_coords, door_heading, spawn_coords, price, is_starter, tablet_coords, interior_id, interior_coords, interior_center, room_count, room_name, room_key, building_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        roomId,
        corners and json.encode(corners) or nil,
        thickness,
        zOffset,
        doorModel,
        doorCoords and json.encode(doorCoords) or nil,
        doorHeading,
        json.encode(spawn),
        price,
        isStarter and 1 or 0,
        tabletCoords and json.encode(tabletCoords) or nil,
        interiorId,
        interiorCoords and json.encode(interiorCoords) or nil,
        interiorCenter and json.encode(interiorCenter) or nil,
        roomCount,
        roomName,
        roomKey,
        buildingId
    })

    if success then
        local cornersVec = {}
        if corners and type(corners) == 'table' then
            for i, c in ipairs(corners) do
                cornersVec[i] = vec3(c.x, c.y, c.z)
            end
        end

        local doorCoordsVec = nil
        if doorCoords then
            doorCoordsVec = vec3(doorCoords.x, doorCoords.y, doorCoords.z)
        end

        local spawnVec = vec4(spawn.x, spawn.y, spawn.z, spawn.w or 0.0)

        local newRoom = {
            id = roomId,
            corners = cornersVec,
            thickness = thickness,
            zOffset = zOffset,
            doorModel = doorModel,
            doorCoords = doorCoordsVec,
            doorHeading = doorHeading,
            spawn = spawnVec,
            price = price,
            isStarter = isStarter,
            tabletCoords = tabletCoords,
            interior_id = interiorId,
            interior_coords = interiorCoords,
            interior_center = interiorCenter,
            room_count = roomCount,
            room_name = roomName,
            room_key = roomKey,
            buildingId = buildingId,
            building_id = buildingId
        }

        table.insert(Settings.Rooms, newRoom)
        roomBuildings[roomId] = buildingId

        if doorCoordsVec and doorModel then
            local doorName = "Apartment Room #" .. roomId
            local existingDoor = nil

            pcall(function()
                existingDoor = exports.ox_doorlock:getDoorFromName(doorName)
            end)

            if not existingDoor then
                local doorId = exports.ox_doorlock:createDoor({
                    name = doorName,
                    model = doorModel,
                    coords = doorCoordsVec,
                    heading = doorHeading or 0.0,
                    state = 1,
                    maxDistance = 2.0,
                    items = {}
                })
                roomDoors[roomId] = doorId
            else
                roomDoors[roomId] = existingDoor.id
            end

            SyncApartmentDoor(roomId)
        end

        TriggerClientEvent('LNS_Housing:client:addApartmentRoom', -1, {
            id = roomId,
            corners = corners,
            thickness = thickness,
            zOffset = zOffset,
            doorModel = doorModel,
            doorCoords = doorCoords,
            doorHeading = doorHeading,
            spawn = spawn,
            price = price,
            isStarter = isStarter,
            tabletCoords = tabletCoords,
            interiorId = interiorId,
            interiorCoords = interiorCoords,
            interiorCenter = interiorCenter,
            roomCount = roomCount,
            roomName = roomName,
            roomKey = roomKey,
            buildingId = buildingId,
            building_id = buildingId
        })

        return true
    end

    return false
end)

lib.callback.register('LNS_Housing:server:updateApartment', function(source, data)
    debugPrint('info', 'LNS_Housing:server:updateApartment called', {source = source, data = data})
    WaitForDb()
    if not IsApartmentAdmin(source) then return false end

    local roomId = tonumber(data.id)
    if not roomId then return false end

    local corners = data.corners
    local thickness = tonumber(data.thickness) or 3.5
    local zOffset = tonumber(data.zOffset) or 0.0
    local door = data.door
    local spawn = data.spawn
    local price = tonumber(data.price) or 0
    local isStarter = data.isStarter ~= nil and (data.isStarter == 1 or data.isStarter == true) or true
    local doorModel = nil
    local doorCoords = nil
    local doorHeading = nil

    local interiorId = tonumber(data.interiorId or data.interior_id or (data.spawn and data.spawn.interior and data.spawn.interior.interiorId)) or nil
    local interiorCoords = data.interiorCoords or data.interior_coords or nil
    local interiorCenter = data.interiorCenter or data.interior_center or (data.spawn and data.spawn.interior and data.spawn.interior.center) or nil
    local roomCount = tonumber(data.roomCount or data.room_count or (data.spawn and data.spawn.interior and data.spawn.interior.roomCount)) or nil
    local roomName = data.roomName or data.room_name or (data.spawn and data.spawn.interior and data.spawn.interior.roomName) or nil
    local roomKey = tonumber(data.roomKey or data.room_key or (data.spawn and data.spawn.interior and data.spawn.interior.roomKey)) or nil

    if door then
        if type(door) == 'table' then
            doorModel = door.model
            if door.coords then
                doorCoords = {x = door.coords.x, y = door.coords.y, z = door.coords.z}
            end
            doorHeading = door.heading
        else
            local doorData = nil
            if exports.ox_doorlock and exports.ox_doorlock.getDoor then
                pcall(function() doorData = exports.ox_doorlock:getDoor(door) end)
            elseif exports.ox_doorlock and exports.ox_doorlock.getDoorData then
                pcall(function() doorData = exports.ox_doorlock:getDoorData(door) end)
            end
            
            if doorData then
                doorModel = doorData.model
                if doorData.coords then
                    doorCoords = {x = doorData.coords.x, y = doorData.coords.y, z = doorData.coords.z}
                end
                doorHeading = doorData.heading
            end
        end
    end

    local tabletCoords = data.tabletCoords
    local buildingId = data.buildingId or data.building_id
    if not buildingId then
        local bldg = Bridge.GetNearestApartmentBuilding(spawn or doorCoords)
        buildingId = bldg and bldg.id or 'wiwang'
    end

    local success = MySQL.update.await([[
        UPDATE apartment_rooms 
        SET corners = ?, thickness = ?, zOffset = ?, door_model = ?, door_coords = ?, door_heading = ?, spawn_coords = ?, price = ?, is_starter = ?, tablet_coords = ?, interior_id = ?, interior_coords = ?, interior_center = ?, room_count = ?, room_name = ?, room_key = ?, building_id = ?
        WHERE id = ?
    ]], {
        corners and json.encode(corners) or nil,
        thickness,
        zOffset,
        doorModel,
        doorCoords and json.encode(doorCoords) or nil,
        doorHeading,
        json.encode(spawn),
        price,
        isStarter and 1 or 0,
        tabletCoords and json.encode(tabletCoords) or nil,
        interiorId,
        interiorCoords and json.encode(interiorCoords) or nil,
        interiorCenter and json.encode(interiorCenter) or nil,
        roomCount,
        roomName,
        roomKey,
        buildingId,
        roomId
    })

    if success then
        local foundIndex = nil
        for idx, room in ipairs(Settings.Rooms) do
            if room.id == roomId then
                foundIndex = idx
                break
            end
        end

        local cornersVec = {}
        if corners and type(corners) == 'table' then
            for i, c in ipairs(corners) do
                cornersVec[i] = vec3(c.x, c.y, c.z)
            end
        end

        local doorCoordsVec = nil
        if doorCoords then
            doorCoordsVec = vec3(doorCoords.x, doorCoords.y, doorCoords.z)
        end

        local spawnVec = vec4(spawn.x, spawn.y, spawn.z, spawn.w or spawn.h or 0.0)

        local updatedRoom = {
            id = roomId,
            corners = cornersVec,
            thickness = thickness,
            zOffset = zOffset,
            doorModel = doorModel,
            doorCoords = doorCoordsVec,
            doorHeading = doorHeading,
            spawn = spawnVec,
            price = price,
            isStarter = isStarter,
            tabletCoords = tabletCoords,
            interior_id = interiorId,
            interior_coords = interiorCoords,
            interior_center = interiorCenter,
            room_count = roomCount,
            room_name = roomName,
            room_key = roomKey,
            buildingId = buildingId,
            building_id = buildingId
        }

        if foundIndex then
            Settings.Rooms[foundIndex] = updatedRoom
        else
            table.insert(Settings.Rooms, updatedRoom)
        end
        roomBuildings[roomId] = buildingId

        if doorCoordsVec and doorModel then
            local doorName = "Apartment Room #" .. roomId
            local existingDoor = nil

            pcall(function()
                existingDoor = exports.ox_doorlock:getDoorFromName(doorName)
            end)

            if existingDoor then
                exports.ox_doorlock:editDoor(existingDoor.id, {
                    model = doorModel,
                    coords = doorCoordsVec,
                    heading = doorHeading or 0.0
                })
                roomDoors[roomId] = existingDoor.id
            else
                local doorId = exports.ox_doorlock:createDoor({
                    name = doorName,
                    model = doorModel,
                    coords = doorCoordsVec,
                    heading = doorHeading or 0.0,
                    state = 1,
                    maxDistance = 2.0,
                    items = {}
                })
                roomDoors[roomId] = doorId
            end

            SyncApartmentDoor(roomId)
        end

        TriggerClientEvent('LNS_Housing:client:updateApartmentRoom', -1, {
            id = roomId,
            corners = corners,
            thickness = thickness,
            zOffset = zOffset,
            doorModel = doorModel,
            doorCoords = doorCoords,
            doorHeading = doorHeading,
            spawn = spawn,
            price = price,
            isStarter = isStarter,
            tabletCoords = tabletCoords,
            interiorId = interiorId,
            interiorCoords = interiorCoords,
            interiorCenter = interiorCenter,
            roomCount = roomCount,
            roomName = roomName,
            roomKey = roomKey,
            buildingId = buildingId,
            building_id = buildingId
        })

        return true
    end

    return false
end)

lib.callback.register('LNS_Housing:server:vacateApartmentRoom', function(source, roomId)
    debugPrint('info', 'LNS_Housing:server:vacateApartmentRoom called', {source = source, roomId = roomId})
    WaitForDb()
    if not IsApartmentAdmin(source) then return false, 'No permission' end

    roomId = tonumber(roomId)
    if not roomId then return false, 'Invalid room ID' end

    local tenantRow = MySQL.single.await('SELECT license FROM player_apartments WHERE room_id = ?', {roomId})
    local tenantLic = tenantRow and tenantRow.license
    local roomData = getRoomDataById(roomId)
    local defaultFurniture = {}

    if roomData and roomData.tabletCoords then
        table.insert(defaultFurniture, CreateDefaultPanelFurniture(roomData.tabletCoords.position, roomData.tabletCoords.rotation))
    end

    MySQL.query.await('DELETE FROM apartments WHERE room_id = ?', {roomId})

    MySQL.query.await('DELETE FROM player_apartments WHERE room_id = ?', {roomId})

    if tenantLic then
        playerRooms[tenantLic] = nil
    end
    assignedRoomIds[roomId] = nil

    local doorId = roomDoors[roomId]
    if doorId and GetResourceState('ox_doorlock') == 'started' then
        pcall(function()
            exports.ox_doorlock:editDoor(doorId, { identifiers = {}, items = {} })
        end)
    end

    debugPrint('info', 'Apartment room ' .. roomId .. ' vacated successfully')
    return true
end)

lib.callback.register('LNS_Housing:server:deleteApartmentRoom', function(source, roomId)
    debugPrint('info', 'LNS_Housing:server:deleteApartmentRoom called', {source = source, roomId = roomId})
    WaitForDb()
    if not IsApartmentAdmin(source) then return false, 'No permission' end

    roomId = tonumber(roomId)
    if not roomId then return false, 'Invalid room ID' end

    local tenantRow = MySQL.single.await('SELECT license FROM player_apartments WHERE room_id = ?', {roomId})
    local tenantLic = tenantRow and tenantRow.license

    MySQL.query.await('DELETE FROM apartments WHERE room_id = ?', {roomId})
    MySQL.query.await('DELETE FROM player_apartments WHERE room_id = ?', {roomId})
    MySQL.query.await('DELETE FROM apartment_rooms WHERE id = ?', {roomId})

    if tenantLic then
        playerRooms[tenantLic] = nil
    end
    assignedRoomIds[roomId] = nil

    for idx, room in ipairs(Settings.Rooms) do
        if room.id == roomId then
            table.remove(Settings.Rooms, idx)
            break
        end
    end

    if doorId and GetResourceState('ox_doorlock') == 'started' then
        pcall(function()
            exports.ox_doorlock:setDoorState(doorId, 0)
        end)
    end
    roomDoors[roomId] = nil

    TriggerClientEvent('LNS_Housing:client:removeApartmentRoom', -1, roomId)

    debugPrint('info', 'Apartment room ' .. roomId .. ' deleted successfully')
    return true
end)

RegisterNetEvent('LNS_Housing:server:ringApartmentDoorbell', function(roomId, buildingId)
    local src = source
    roomId = tonumber(roomId) or roomId
    if not roomId then return end

    if buildingId then
        local actualBId = GetApartmentBuildingId(roomId)
        if actualBId and actualBId ~= buildingId then
            Bridge.Server.Notify(src, locale('notify.room_not_in_building', tostring(roomId)), 'error')
            return
        end
    end

    local bId = buildingId or GetApartmentBuildingId(roomId)
    local roomData = getRoomDataById(roomId, bId)
    if not roomData then return end

    if IsStarterInstanceMode() then
        local cfg = Settings.Apartments and Settings.Apartments.Starter
        local bucketOffset = (cfg and cfg.BucketOffset) or 20000
        local targetBucket = bucketOffset + (tonumber(roomId) or 1)
        local playersInside = {}
        for _, pId in ipairs(GetPlayers()) do
            local pSrc = tonumber(pId)
            if pSrc and GetPlayerRoutingBucket(pSrc) == targetBucket then
                table.insert(playersInside, pSrc)
            end
        end

        local visitorName = Bridge.Server.GetPlayerName(src) or 'A Visitor'

        if #playersInside > 0 then
            for _, insideSrc in ipairs(playersInside) do
                TriggerClientEvent('LNS_Housing:client:receiveApartmentDoorbell', insideSrc, roomId, src, visitorName)
            end
            Bridge.Server.Notify(src, locale('notify.doorbell_rang'), 'info')
        else
            Bridge.Server.Notify(src, locale('notify.doorbell_no_answer'), 'error')
        end
        return
    end

    if not roomData.doorCoords then return end
    local coords = vec3(roomData.doorCoords.x, roomData.doorCoords.y, roomData.doorCoords.z)

    local isShell = roomData.shell and roomData.shell ~= 'mlo'
    local insideCoords = nil
    if isShell then
        insideCoords = vec3(coords.x, coords.y, Settings.ShellSpawningZ or -100.0)
    end

    TriggerClientEvent('LNS_Housing:client:triggerHouseDoorbell', -1, coords, insideCoords)
end)

RegisterNetEvent('LNS_Housing:server:answerApartmentDoorbell', function(roomId, guestSrc, allow)
    local src = source
    roomId = tonumber(roomId) or roomId
    guestSrc = tonumber(guestSrc)
    if not roomId or not guestSrc then return end

    if allow then
        if not apartmentGuestAccess[roomId] then
            apartmentGuestAccess[roomId] = {}
        end
        apartmentGuestAccess[roomId][guestSrc] = true

        local roomData = getRoomDataById(roomId)
        TriggerClientEvent('LNS_Housing:client:enterGuestApartment', guestSrc, roomId, roomData)
        Bridge.Server.Notify(src, locale('notify.guest_let_in'), 'success')
    else
        Bridge.Server.Notify(guestSrc, locale('notify.guest_denied'), 'error')
    end
end)

function GetApartmentDoorId(roomId)
    return roomDoors[roomId]
end

exports('GiveApartmentPhysicalKey', function(roomId, targetSource)
    local pk = Settings.Security.PhysicalKeys
    if not pk or not pk.Enabled then return false end

    local roomData = getRoomDataById(roomId)
    if not roomData then return false end

    local added = Bridge.Server.AddItem(targetSource, pk.Item, 1, {
        propertyId = roomId,
        isApartment = true,
        description = locale('item.key_to', locale('target.apartment_room_prefix') .. ' #' .. roomId)
    })

    return added and true or false
end)

local function ResolveApartmentTarget(target)
    if not target then return nil, nil end
    local numSrc = tonumber(target)
    local citizenid = nil
    local license = nil

    if numSrc and GetPlayerPing(numSrc) > 0 then
        citizenid = Bridge.Server.GetIdentifier(numSrc)
        license = GetPlayerLicense(numSrc)
    elseif type(target) == 'string' then
        if target:sub(1, 8) == 'license:' then
            license = target
            local aptRow = MySQL.single.await('SELECT citizenid FROM apartments WHERE citizenid = ? LIMIT 1', {target})
            if aptRow then
                citizenid = aptRow.citizenid
            else
                local pRow = MySQL.single.await('SELECT citizenid FROM players WHERE license = ? LIMIT 1', {target})
                if pRow then citizenid = pRow.citizenid end
            end
        else
            citizenid = target
            local onlinePlayer = Bridge.Server.IsPlayerOnline(target)
            if onlinePlayer and onlinePlayer.PlayerData and onlinePlayer.PlayerData.source then
                license = GetPlayerLicense(onlinePlayer.PlayerData.source)
            else
                local pRow = MySQL.single.await('SELECT license FROM players WHERE citizenid = ? LIMIT 1', {target})
                if pRow then license = pRow.license end
            end
        end
    elseif numSrc then
        citizenid = Bridge.Server.GetIdentifier(numSrc) or tostring(target)
        license = GetPlayerLicense(numSrc)
    end

    return citizenid, license
end

local function FormatApartmentForMDT(aptData, roomData)
    local roomId = (roomData and roomData.id) or (aptData and aptData.room_id)
    if not roomId then return nil end

    local buildingId = (roomData and (roomData.buildingId or roomData.building_id)) or (aptData and aptData.building_id) or GetApartmentBuildingId(roomId)
    local building = Bridge.GetApartmentBuildingById(buildingId, true) or {}
    local buildingLabel = building.label or "WIWANG Apartments"
    local buildingCoords = building.coords

    local roomName = (roomData and roomData.room_name) or ("Apartment Room #" .. tostring(roomId))
    local fullLabel = buildingLabel .. " - " .. roomName

    local doorCoords = roomData and roomData.doorCoords
    local spawnCoords = roomData and roomData.spawn
    local coords = doorCoords or (spawnCoords and vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z)) or buildingCoords

    local citizenid = aptData and aptData.citizenid or nil
    local ownerName = nil

    if citizenid then
        local onlinePlayer = Bridge.Server.IsPlayerOnline(citizenid)
        if onlinePlayer and onlinePlayer.PlayerData and onlinePlayer.PlayerData.source then
            ownerName = Bridge.Server.GetPlayerName(onlinePlayer.PlayerData.source)
        else
            pcall(function()
                if Bridge.Framework == 'qbx' then
                    local pRow = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', {citizenid})
                    if pRow and pRow.charinfo then
                        local charinfo = json.decode(pRow.charinfo)
                        if charinfo and charinfo.firstname and charinfo.lastname then
                            ownerName = charinfo.firstname .. ' ' .. charinfo.lastname
                        end
                    end
                elseif Bridge.Framework == 'esx' then
                    local uRow = MySQL.single.await('SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', {citizenid})
                    if uRow and uRow.firstname and uRow.lastname then
                        ownerName = uRow.firstname .. ' ' .. uRow.lastname
                    end
                end
            end)
        end
    end

    local perms = aptData and aptData.permissions
    if type(perms) == 'string' then
        perms = json.decode(perms) or {}
    elseif type(perms) ~= 'table' then
        perms = { entry = {}, storage = {}, wardrobe = {}, manage = {} }
    end

    local keyholders = {}
    if perms.entry then
        for _, cid in ipairs(perms.entry) do
            table.insert(keyholders, cid)
        end
    end

    local doorId = roomDoors and roomDoors[roomId]

    return {
        id = roomId,
        roomId = roomId,
        room_id = roomId,
        label = fullLabel,
        name = roomName,
        room_name = roomName,
        buildingId = buildingId,
        building_id = buildingId,
        building = buildingLabel,
        building_label = buildingLabel,
        buildingCoords = buildingCoords,
        coords = coords,
        enter = coords,
        doorCoords = doorCoords,
        spawn = spawnCoords,
        doorId = doorId,
        price = (roomData and roomData.price) or 0,
        citizenid = citizenid,
        owner = citizenid,
        ownerName = ownerName or 'Unknown',
        permissions = perms,
        keyholders = keyholders,
        isStarter = roomData and (roomData.isStarter or roomData.is_starter) or false,
        isApartment = true,
        type = "apartment",
        security_level = aptData and aptData.security_level or 0,
        wall_color = aptData and aptData.wall_color or 0,
    }
end

local function GetPlayerApartmentsServer(target)
    WaitForDb()
    if not target then return {} end

    local citizenid, license = ResolveApartmentTarget(target)
    if not citizenid and not license then return {} end

    local apartmentsList = {}
    local seenRooms = {}

    if citizenid then
        local rows = MySQL.query.await('SELECT * FROM apartments WHERE citizenid = ?', {citizenid})
        if rows then
            for _, row in ipairs(rows) do
                local roomId = tonumber(row.room_id) or row.room_id
                if roomId and not seenRooms[roomId] then
                    seenRooms[roomId] = true
                    local roomData = getRoomDataById(roomId)
                    local formatted = FormatApartmentForMDT(row, roomData)
                    if formatted then
                        table.insert(apartmentsList, formatted)
                    end
                end
            end
        end
    end

    if license then
        local paRow = MySQL.single.await('SELECT room_id FROM player_apartments WHERE license = ?', {license})
        if paRow and paRow.room_id then
            local roomId = tonumber(paRow.room_id) or paRow.room_id
            if roomId and not seenRooms[roomId] then
                seenRooms[roomId] = true
                local aptRow = MySQL.single.await('SELECT * FROM apartments WHERE room_id = ?', {roomId}) or {
                    room_id = roomId,
                    citizenid = citizenid
                }
                local roomData = getRoomDataById(roomId)
                local formatted = FormatApartmentForMDT(aptRow, roomData)
                if formatted then
                    table.insert(apartmentsList, formatted)
                end
            end
        end
    end

    if license and playerRooms and playerRooms[license] then
        local roomId = playerRooms[license]
        if roomId and not seenRooms[roomId] then
            seenRooms[roomId] = true
            local aptRow = { room_id = roomId, citizenid = citizenid }
            local roomData = getRoomDataById(roomId)
            local formatted = FormatApartmentForMDT(aptRow, roomData)
            if formatted then
                table.insert(apartmentsList, formatted)
            end
        end
    end

    if citizenid then
        local allApts = MySQL.query.await('SELECT * FROM apartments WHERE citizenid != ?', {citizenid})
        if allApts then
            for _, row in ipairs(allApts) do
                local roomId = tonumber(row.room_id) or row.room_id
                if roomId and not seenRooms[roomId] and row.permissions then
                    local perms = json.decode(row.permissions)
                    if perms and perms.entry then
                        for _, cid in ipairs(perms.entry) do
                            if cid == citizenid then
                                seenRooms[roomId] = true
                                local roomData = getRoomDataById(roomId)
                                local formatted = FormatApartmentForMDT(row, roomData)
                                if formatted then
                                    formatted.isKeyholder = true
                                    table.insert(apartmentsList, formatted)
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    return apartmentsList
end

local function GetAllApartmentsServer()
    WaitForDb()
    local results = {}
    
    local aptRows = MySQL.query.await('SELECT * FROM apartments')
    local aptByRoom = {}
    if aptRows then
        for _, row in ipairs(aptRows) do
            local rId = tonumber(row.room_id) or row.room_id
            if rId and not aptByRoom[rId] then
                aptByRoom[rId] = row
            end
        end
    end

    if IsStarterInstanceMode() then
        local seenRooms = {}
        local paRows = MySQL.query.await('SELECT room_id FROM player_apartments')
        if paRows then
            for _, pa in ipairs(paRows) do
                local rId = tonumber(pa.room_id) or pa.room_id
                if rId and not seenRooms[rId] then
                    seenRooms[rId] = true
                    local aptRow = aptByRoom[rId] or { room_id = rId }
                    local roomData = getRoomDataById(rId)
                    local formatted = FormatApartmentForMDT(aptRow, roomData)
                    if formatted then
                        table.insert(results, formatted)
                    end
                end
            end
        end
        return results
    end

    local rooms = Settings.Rooms or {}
    for _, room in ipairs(rooms) do
        local aptRow = aptByRoom[room.id] or { room_id = room.id }
        local formatted = FormatApartmentForMDT(aptRow, room)
        if formatted then
            table.insert(results, formatted)
        end
    end

    return results
end

local function GetApartmentByIdServer(roomId)
    WaitForDb()
    if not roomId then return nil end
    local rId = tonumber(roomId) or roomId
    local roomData = getRoomDataById(rId)
    if not roomData then return nil end

    local aptRow = MySQL.single.await('SELECT * FROM apartments WHERE room_id = ? OR room_id = ? LIMIT 1', {rId, tostring(rId)})
    return FormatApartmentForMDT(aptRow or { room_id = rId }, roomData)
end

exports('GetApartments', function(target)
    if target and target ~= '' then
        return GetPlayerApartmentsServer(target)
    else
        return GetAllApartmentsServer()
    end
end)

exports('GetPlayerApartment', function(target)
    local apts = GetPlayerApartmentsServer(target)
    return apts and apts[1] or nil
end)

exports('GetPlayerApartments', function(target)
    return GetPlayerApartmentsServer(target)
end)

exports('GetAllApartments', function()
    return GetAllApartmentsServer()
end)

exports('GetApartment', function(roomId)
    return GetApartmentByIdServer(roomId)
end)

exports('GetApartmentInfo', function(roomId)
    return GetApartmentByIdServer(roomId)
end)