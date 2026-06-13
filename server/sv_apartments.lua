local Settings = lib.load('shared.settings')

if not Settings.Apartments or not Settings.Apartments.Enabled then
    lib.callback.register('LNS_Housing:server:getMyApartment', function(source) return nil end)
    lib.callback.register('LNS_Housing:server:getApartmentInfo', function(source, roomId) return nil end)
    lib.callback.register('LNS_Housing:server:hasApartmentAccess', function(source, roomId, type) return false end)
    lib.callback.register('LNS_Housing:server:claimNewCharacterSpawn', function(source) return { shouldSpawn = false } end)
    return
end

local activeRooms = {}
local playerRooms = {}
local roomDoors = {}

local function GetPlayerLicense(src)
    local license = GetPlayerIdentifierByType(src, 'license2')
    if not license or license == '' then
        license = GetPlayerIdentifierByType(src, 'license')
    end
    return license
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
                local doorId = exports.ox_doorlock:createDoorlock({
                    name = doorName,
                    model = room.doorModel,
                    coords = room.doorCoords,
                    heading = room.doorHeading or 0.0,
                    state = 1,
                    maxDistance = 2.0
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
        identifiers = identifiers
    })
end

CreateThread(function()
    local Rooms = MySQL.query.await('SELECT * FROM apartment_rooms')
    if Rooms then
        for _, r in ipairs(Rooms) do
            local corners = json.decode(r.corners)
            local cornersVec = {}
            for i, c in ipairs(corners) do
                cornersVec[i] = vec3(c.x, c.y, c.z)
            end
            
            local doorCoords = nil
            if r.door_coords then
                local dc = json.decode(r.door_coords)
                doorCoords = vec3(dc.x, dc.y, dc.z)
            end
            
            local sc = json.decode(r.spawn_coords)
            local spawnVec = vec4(sc.x, sc.y, sc.z, sc.w or sc.h or 0.0)
            
            table.insert(Settings.Rooms, {
                id = r.id,
                corners = cornersVec,
                thickness = r.thickness,
                zOffset = r.zOffset,
                doorModel = r.door_model,
                doorCoords = doorCoords,
                doorHeading = r.door_heading,
                spawn = spawnVec,
                price = r.price,
                isStarter = (r.is_starter == 1 or r.is_starter == true)
            })
        end
    end

    local result = MySQL.query.await('SELECT citizenid, room_id FROM player_apartments')
    if result then
        for _, row in ipairs(result) do
            playerRooms[row.citizenid] = row.room_id
        end
        print('^2[Apartments] ^7Loaded ' .. #result .. ' apartments.')
    end

    CreateApartmentDoorlocks()
    for _, room in ipairs(Settings.Rooms) do
        SyncApartmentDoor(room.id)
    end
end)

local function getRoomDataById(roomId)
    for _, room in ipairs(Settings.Rooms) do
        if room.id == roomId then
            return room
        end
    end
    return nil
end

local function getAvailableRoom()
    if #Settings.Rooms == 0 then
        local Rooms = MySQL.query.await('SELECT * FROM apartment_rooms')
        if Rooms and #Rooms > 0 then
            for _, r in ipairs(Rooms) do
                local corners = json.decode(r.corners)
                local cornersVec = {}
                for i, c in ipairs(corners) do
                    cornersVec[i] = vec3(c.x, c.y, c.z)
                end
                
                local doorCoords = nil
                if r.door_coords then
                    local dc = json.decode(r.door_coords)
                    doorCoords = vec3(dc.x, dc.y, dc.z)
                end
                
                local sc = json.decode(r.spawn_coords)
                local spawnVec = vec4(sc.x, sc.y, sc.z, sc.w or sc.h or 0.0)
                
                table.insert(Settings.Rooms, {
                    id = r.id,
                    corners = cornersVec,
                    thickness = r.thickness,
                    zOffset = r.zOffset,
                    doorModel = r.door_model,
                    doorCoords = doorCoords,
                    doorHeading = r.door_heading,
                    spawn = spawnVec,
                    price = r.price,
                    isStarter = (r.is_starter == 1 or r.is_starter == true)
                })
            end

            pcall(CreateApartmentDoorlocks)
        end
    end

    local available = {}
    for _, room in ipairs(Settings.Rooms) do
        if room.isStarter then
            table.insert(available, room)
        end
    end
    
    if #available > 0 then
        local selected = available[math.random(#available)]
        return selected
    end
    return nil
end

local function getPlayerRoom(src, citizenid, isNew)
    if not citizenid then return nil end

    if playerRooms[citizenid] then
        return playerRooms[citizenid]
    end

    local result = MySQL.single.await('SELECT room_id FROM player_apartments WHERE citizenid = ?', {citizenid})
    if result then
        playerRooms[citizenid] = result.room_id
        return result.room_id
    end

    local license = GetPlayerLicense(src)
    if license then
        local resultOld = MySQL.single.await('SELECT room_id FROM player_apartments WHERE citizenid = ?', {license})
        if resultOld then
            pcall(function()
                MySQL.update.await('UPDATE player_apartments SET citizenid = ? WHERE citizenid = ?', {citizenid, license})
            end)
            playerRooms[citizenid] = resultOld.room_id
            playerRooms[license] = nil
            SyncApartmentDoor(resultOld.room_id)
            return resultOld.room_id
        end
    end

    local room = getAvailableRoom()
    if room then
        local isNewChar = not not isNew

        local insertSuccess = pcall(function()
            MySQL.insert.await('INSERT INTO player_apartments (citizenid, room_id, is_new) VALUES (?, ?, ?)', {
                citizenid,
                room.id,
                isNewChar and 1 or 0
            })
        end)

        if insertSuccess then
            playerRooms[citizenid] = room.id
            SyncApartmentDoor(room.id)
            return room.id
        else
            local r = MySQL.single.await('SELECT room_id FROM player_apartments WHERE citizenid = ?', {citizenid})
            if r then
                playerRooms[citizenid] = r.room_id
                return r.room_id
            end
        end
    end
    return nil
end

local function OnPlayerLoaded(src)
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then 
        return 
    end

    local roomId = getPlayerRoom(src, citizenid, false)
    if roomId then
        local roomData = getRoomDataById(roomId)
        if roomData then
            local result = MySQL.single.await('SELECT id FROM apartments WHERE citizenid = ? AND room_id = ?', {citizenid, roomId})
            if not result then
                MySQL.insert.await('INSERT INTO apartments (citizenid, room_id, permissions, furniture, wall_color) VALUES (?, ?, ?, ?, ?)', {
                    citizenid,
                    roomId,
                    json.encode({entry = {}, storage = {}, wardrobe = {}, manage = {}}),
                    json.encode({}),
                    0
                })
            end
            
            SyncApartmentDoor(roomId)
            
            TriggerClientEvent('LNS_Housing:client:setApartmentData', src, roomId, roomData)
        end
    end
end

if Bridge.Framework == 'qbx' then
    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
        local src = source
        OnPlayerLoaded(src)
    end)
elseif Bridge.Framework == 'esx' then
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        OnPlayerLoaded(playerId)
    end)
    RegisterNetEvent('esx:onPlayerInitialised', function(playerId)
        OnPlayerLoaded(playerId)
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
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return nil end
    
    local roomId = playerRooms[citizenid]
    if not roomId then
        roomId = getPlayerRoom(source, citizenid, true)
    end
    
    if not roomId then
        local license = GetPlayerLicense(source)
        roomId = license and playerRooms[license]
    end
    
    if roomId then
        local roomData = getRoomDataById(roomId)
        return { roomId = roomId, roomData = roomData }
    end
    return nil
end)

lib.callback.register('LNS_Housing:server:claimNewCharacterSpawn', function(source)
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return { shouldSpawn = false } end

    local result = MySQL.single.await('SELECT room_id, is_new FROM player_apartments WHERE citizenid = ?', {citizenid})
    if not result then
        local license = GetPlayerLicense(source)
        if license then
            result = MySQL.single.await('SELECT room_id, is_new FROM player_apartments WHERE citizenid = ?', {license})
        end
    end

    if result and result.is_new == 1 then
        local searchId = citizenid
        local check = MySQL.single.await('SELECT id FROM player_apartments WHERE citizenid = ?', {citizenid})
        if not check then
            local license = GetPlayerLicense(source)
            if license then
                local checkLicense = MySQL.single.await('SELECT id FROM player_apartments WHERE citizenid = ?', {license})
                if checkLicense then
                    searchId = license
                end
            end
        end

        MySQL.update.await('UPDATE player_apartments SET is_new = 0 WHERE citizenid = ?', {searchId})
        
        local roomId = result.room_id
        local roomData = getRoomDataById(roomId)
        if roomData then
            return {
                shouldSpawn = true,
                roomId = roomId,
                spawnCoords = roomData.spawn
            }
        end
    end

    return { shouldSpawn = false }
end)

lib.callback.register('LNS_Housing:server:getApartmentInfo', function(source, roomId)
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return nil end

    local result = MySQL.single.await('SELECT * FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    if result then
        local furnitureList = json.decode(result.furniture or '[]')
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
            wallColor = result.wall_color
        }
    end
    return nil
end)

lib.callback.register('LNS_Housing:server:hasApartmentAccess', function(source, roomId, type)
    local playerJob = Bridge.Server.GetPlayerJob(source)
    if playerJob and playerJob.name == 'police' then
        if type ~= 'storage' and type ~= 'stash' then
            return true
        end
    end

    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return false end

    
    if type == 'storage' or type == 'stash' then
        if TemporaryAccess.stashes[roomId] and TemporaryAccess.stashes[roomId][citizenid] then
            return true
        end
    elseif type == 'entry' or type == 'doors' then
        if TemporaryAccess.doors[roomId] and TemporaryAccess.doors[roomId][citizenid] then
            return true
        end
    end

    local result = MySQL.single.await('SELECT citizenid, permissions FROM apartments WHERE room_id = ?', {roomId})
    if result then
        if result.citizenid == citizenid then return true end
        
        local permissions = json.decode(result.permissions or '{"entry":[], "storage":[], "wardrobe":[], "manage":[]}')
        if permissions[type] then
            for _, cid in ipairs(permissions[type]) do
                if cid == citizenid then return true end
            end
        end
    end
    return false
end)

RegisterNetEvent('LNS_Housing:server:updateApartmentPermissions', function(roomId, permissions)
    local src = source
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    local result = MySQL.single.await('SELECT citizenid FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
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
            Bridge.Server.Notify(src, 'You have reached the maximum number of keys (' .. Settings.MaxKeys .. ') for this apartment!', 'error')
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
            wallColor = 0
        })
        
        Bridge.Server.Notify(src, 'Apartment permissions updated successfully!', 'success')
    end
end)

RegisterNetEvent('LNS_Housing:server:updateApartmentWallColor', function(roomId, color)
    local src = source
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    local result = MySQL.single.await('SELECT citizenid FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    if result then
        MySQL.update.await('UPDATE apartments SET wall_color = ? WHERE room_id = ? AND citizenid = ?', {
            color,
            roomId,
            citizenid
        })
    end
end)

RegisterNetEvent('LNS_Housing:server:saveApartmentFurniture', function(roomId, furnitureData)
    local src = source
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    local result = MySQL.single.await('SELECT citizenid FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    if result then
        MySQL.update.await('UPDATE apartments SET furniture = ? WHERE room_id = ? AND citizenid = ?', {
            json.encode(furnitureData),
            roomId,
            citizenid
        })

        if Bridge.Server.RegisterPropertyStashes then
            Bridge.Server.RegisterPropertyStashes(roomId, furnitureData)
        end
        
        TriggerClientEvent('LNS_Housing:client:updateApartmentFurniture', -1, roomId, furnitureData)
    end
end)

RegisterNetEvent('LNS_Housing:server:buyApartmentFurniture', function(roomId, items, totalPrice, paymentMethod)
    local src = source
    local citizenid = Bridge.Server.GetIdentifier(src)
    if not citizenid then return end

    if type(items) ~= 'table' then
        Bridge.Server.Notify(src, 'Invalid furniture payload.', 'error')
        return
    end

    local price = tonumber(totalPrice)
    if not price or price ~= price then
        Bridge.Server.Notify(src, 'Invalid purchase amount.', 'error')
        return
    end

    price = math.floor(price + 0.0)
    if price < 0 then
        Bridge.Server.Notify(src, 'Invalid purchase amount.', 'error')
        return
    end

    local okSelect, result = pcall(function()
        return MySQL.single.await('SELECT citizenid, furniture FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    end)

    if not okSelect then
        print(('[LNS_Housing] buyApartmentFurniture SELECT failed for %s/%s: %s'):format(tostring(citizenid), tostring(roomId), tostring(result)))
        Bridge.Server.Notify(src, 'Database error while loading apartment data.', 'error')
        return
    end

    if result then
        local payType = paymentMethod == 'cash' and 'cash' or 'bank'
        local money = Bridge.Server.GetMoney(src, payType)
        if price > 0 then
            if money < price then
                local targetAccountName = payType == 'cash' and 'cash' or 'bank account'
                Bridge.Server.Notify(src, 'Not enough money in your ' .. targetAccountName .. '!', 'error')
                return
            end

            local removed = Bridge.Server.RemoveMoney(src, payType, price, "Bought furniture for apartment #" .. roomId)
            if not removed then
                local targetAccountName = payType == 'cash' and 'cash' or 'bank'
                Bridge.Server.Notify(src, 'Could not process ' .. targetAccountName .. ' payment.', 'error')
                return
            end
        end

        local currentFurniture = {}
        if result.furniture and result.furniture ~= '' then
            local okDecode, decoded = pcall(function()
                return json.decode(result.furniture)
            end)

            if okDecode and type(decoded) == 'table' then
                currentFurniture = decoded
            else
                print(('[LNS_Housing] buyApartmentFurniture decode failed for %s/%s, resetting furniture list'):format(tostring(citizenid), tostring(roomId)))
            end
        end

        for _, item in ipairs(items) do
            table.insert(currentFurniture, item)
        end

        local okEncode, furnitureJson = pcall(function()
            return json.encode(currentFurniture)
        end)
        if not okEncode then
            print(('[LNS_Housing] buyApartmentFurniture encode failed for %s/%s: %s'):format(tostring(citizenid), tostring(roomId), tostring(furnitureJson)))
            Bridge.Server.Notify(src, 'Could not process furniture data.', 'error')
            return
        end

        local okUpdate, updateResult = pcall(function()
            return MySQL.update.await('UPDATE apartments SET furniture = ? WHERE room_id = ? AND citizenid = ?', {
                furnitureJson,
                roomId,
                citizenid
            })
        end)
        if not okUpdate then
            print(('[LNS_Housing] buyApartmentFurniture UPDATE failed for %s/%s: %s'):format(tostring(citizenid), tostring(roomId), tostring(updateResult)))
            Bridge.Server.Notify(src, 'Database error while saving furniture.', 'error')
            return
        end

        if Bridge.Server.RegisterPropertyStashes then
            Bridge.Server.RegisterPropertyStashes(roomId, currentFurniture)
        end

        TriggerClientEvent('LNS_Housing:client:updateApartmentFurniture', -1, roomId, currentFurniture)
        Bridge.Server.Notify(src, 'Furniture bought successfully!', 'success')
    end
end)

local function GetPropertyCoords(p)
    if not p then return nil end

    if p.metadata and p.metadata.spawn then
        local sp = p.metadata.spawn
        return vector4(sp.x, sp.y, sp.z, sp.h or sp.w or 0.0)
    end

    if resolvedCoords then
        if not p.metadata then p.metadata = {} end
        p.metadata.spawn = {
            x = resolvedCoords.x,
            y = resolvedCoords.y,
            z = resolvedCoords.z,
            h = resolvedCoords.w
        }
        SaveProperty(p.id)
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
    end
    
    return resolvedCoords
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
                local roomData = getRoomDataById(roomId)
                if roomData then
                    table.insert(spawns, {
                        id = roomId,
                        type = "apartment",
                        label = "Apartment Room #" .. roomId,
                        coords = roomData.spawn
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

local function IsApartmentAdmin(source)
    if Bridge.Framework == 'qbx' then
        if IsPlayerAceAllowed(source, 'admin') then
            return true
        end
    elseif Bridge.Framework == 'esx' then
        local ESX = exports['es_extended']:getSharedObject()
        local player = ESX.GetPlayerFromId(source)
        if player then
            local group = player.getGroup()
            return group == 'admin' or group == 'superadmin'
        end
    end
    return false
end

lib.callback.register('LNS_Housing:server:isApartmentAdmin', function(source)
    return IsApartmentAdmin(source)
end)

lib.callback.register('LNS_Housing:server:doesApartmentExist', function(source, roomId)
    for _, room in ipairs(Settings.Rooms) do
        if room.id == roomId then
            return true
        end
    end
    return false
end)

lib.callback.register('LNS_Housing:server:getApartmentRooms', function(source)
    local Rooms = MySQL.query.await('SELECT * FROM apartment_rooms')
    local formatted = {}
    if Rooms then
        for _, r in ipairs(Rooms) do
            local corners = json.decode(r.corners)
            local doorCoords = nil
            if r.door_coords then
                doorCoords = json.decode(r.door_coords)
            end
            local sc = json.decode(r.spawn_coords)
            table.insert(formatted, {
                id = r.id,
                corners = corners,
                thickness = r.thickness,
                zOffset = r.zOffset,
                doorModel = r.door_model,
                doorCoords = doorCoords,
                doorHeading = r.door_heading,
                spawn = {x = sc.x, y = sc.y, z = sc.z, w = sc.w or sc.h or 0.0},
                price = r.price,
                isStarter = (r.is_starter == 1 or r.is_starter == true)
            })
        end
    end
    return formatted
end)

lib.callback.register('LNS_Housing:server:createApartment', function(source, data)
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

    local success = MySQL.insert.await([[
        INSERT INTO apartment_rooms (id, corners, thickness, zOffset, door_model, door_coords, door_heading, spawn_coords, price, is_starter)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        roomId,
        json.encode(corners),
        thickness,
        zOffset,
        doorModel,
        doorCoords and json.encode(doorCoords) or nil,
        doorHeading,
        json.encode(spawn),
        price,
        isStarter and 1 or 0
    })

    if success then
        local cornersVec = {}
        for i, c in ipairs(corners) do
            cornersVec[i] = vec3(c.x, c.y, c.z)
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
            isStarter = isStarter
        }

        table.insert(Settings.Rooms, newRoom)

        if doorCoordsVec and doorModel then
            local doorName = "Apartment Room #" .. roomId
            local existingDoor = nil

            pcall(function()
                existingDoor = exports.ox_doorlock:getDoorFromName(doorName)
            end)

            if not existingDoor then
                local doorId = exports.ox_doorlock:createDoorlock({
                    name = doorName,
                    model = doorModel,
                    coords = doorCoordsVec,
                    heading = doorHeading or 0.0,
                    state = 1,
                    maxDistance = 2.0
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
            isStarter = isStarter
        })

        return true
    end

    return false
end)