local Settings = lib.load('shared.settings')

if not Settings.Apartments or not Settings.Apartments.Enabled then
    lib.callback.register('LNS_Housing:server:getMyApartment', function(source) return nil end)
    lib.callback.register('LNS_Housing:server:getApartmentInfo', function(source, roomId) return nil end)
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
    WaitForDb()
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
            
            local tabletCoords = nil
            if r.tablet_coords then
                tabletCoords = json.decode(r.tablet_coords)
            end

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
                isStarter = (r.is_starter == 1 or r.is_starter == true),
                tabletCoords = tabletCoords
            })
        end
    end

    local result = MySQL.query.await('SELECT license, room_id FROM player_apartments')
    if result then
        for _, row in ipairs(result) do
            playerRooms[row.license] = row.room_id
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
                
                local tabletCoords = nil
                if r.tablet_coords then
                    tabletCoords = json.decode(r.tablet_coords)
                end

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
                    isStarter = (r.is_starter == 1 or r.is_starter == true),
                    tabletCoords = tabletCoords
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
    local license = GetPlayerLicense(src)
    if not license then return nil end

    if playerRooms[license] then
        return playerRooms[license]
    end

    local result = MySQL.single.await('SELECT room_id FROM player_apartments WHERE license = ?', {license})
    if result then
        playerRooms[license] = result.room_id
        return result.room_id
    end

    local room = getAvailableRoom()
    if room then
        local isNewChar = not not isNew

        local insertSuccess = pcall(function()
            MySQL.insert.await('INSERT INTO player_apartments (license, room_id, is_new) VALUES (?, ?, ?)', {
                license,
                room.id,
                isNewChar and 1 or 0
            })
        end)

        if insertSuccess then
            playerRooms[license] = room.id
            SyncApartmentDoor(room.id)
            return room.id
        else
            local r = MySQL.single.await('SELECT room_id FROM player_apartments WHERE license = ?', {license})
            if r then
                playerRooms[license] = r.room_id
                return r.room_id
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

    local roomId = getPlayerRoom(src, citizenid, false)
    if roomId then
        local roomData = getRoomDataById(roomId)
        if roomData then
            local result = MySQL.single.await('SELECT id FROM apartments WHERE citizenid = ? AND room_id = ?', {citizenid, roomId})
            if not result then
                local initialFurniture = {}
                if roomData.tabletCoords then
                    table.insert(initialFurniture, {
                        id = math.random(100000, 999999),
                        model = 'reh_prop_reh_tablet_01a',
                        label = 'Property Panel',
                        position = vec3(roomData.tabletCoords.position.x, roomData.tabletCoords.position.y, roomData.tabletCoords.position.z),
                        rotation = vec3(roomData.tabletCoords.rotation.x, roomData.tabletCoords.rotation.y, roomData.tabletCoords.rotation.z),
                        category = 'prerequisites'
                    })
                end

                MySQL.insert.await('INSERT INTO apartments (citizenid, room_id, permissions, furniture, wall_color) VALUES (?, ?, ?, ?, ?)', {
                    citizenid,
                    roomId,
                    json.encode({entry = {}, storage = {}, wardrobe = {}, manage = {}}),
                    json.encode(initialFurniture),
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
    WaitForDb()
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return nil end
    
    local roomId = getPlayerRoom(source, citizenid, true)
    if roomId then
        local roomData = getRoomDataById(roomId)
        return { roomId = roomId, roomData = roomData }
    end
    return nil
end)

lib.callback.register('LNS_Housing:server:claimNewCharacterSpawn', function(source)
    WaitForDb()
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return { shouldSpawn = false } end

    local roomId = getPlayerRoom(source, citizenid, false)
    if not roomId then return { shouldSpawn = false } end

    local result = MySQL.single.await('SELECT is_new FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    if not result then
        local roomData = getRoomDataById(roomId)
        local initialFurniture = {}
        if roomData and roomData.tabletCoords then
            table.insert(initialFurniture, {
                id = math.random(100000, 999999),
                model = 'reh_prop_reh_tablet_01a',
                label = 'Property Panel',
                position = vec3(roomData.tabletCoords.position.x, roomData.tabletCoords.position.y, roomData.tabletCoords.position.z),
                rotation = vec3(roomData.tabletCoords.rotation.x, roomData.tabletCoords.rotation.y, roomData.tabletCoords.rotation.z),
                category = 'prerequisites'
            })
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
    WaitForDb()
    local citizenid = Bridge.Server.GetIdentifier(source)
    if not citizenid then return nil end

    local result = MySQL.single.await('SELECT * FROM apartments WHERE room_id = ? AND citizenid = ?', {roomId, citizenid})
    if result then
        local furnitureList = json.decode(result.furniture or '[]')
        local roomData = getRoomDataById(roomId)
        if roomData and roomData.tabletCoords then
            local hasTablet = false
            local changed = false
            for _, f in ipairs(furnitureList) do
                if f.model == 'reh_prop_reh_tablet_01a' then
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
                table.insert(furnitureList, {
                    id = math.random(100000, 999999),
                    model = 'reh_prop_reh_tablet_01a',
                    label = 'Property Panel',
                    position = vec3(roomData.tabletCoords.position.x, roomData.tabletCoords.position.y, roomData.tabletCoords.position.z),
                    rotation = vec3(roomData.tabletCoords.rotation.x, roomData.tabletCoords.rotation.y, roomData.tabletCoords.rotation.z),
                    category = 'prerequisites'
                })
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
            wallColor = result.wall_color
        }
    end
    return nil
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

local function FindManagedApartment(roomId, citizenid)
    local results = MySQL.query.await('SELECT citizenid, permissions, furniture FROM apartments WHERE room_id = ?', {roomId})
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

    local result = FindManagedApartment(roomId, citizenid)
    if not result then
        Bridge.Server.Notify(src, 'You do not have management access to this apartment.', 'error')
        return
    end

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
        end
    end

    for _, item in ipairs(items) do
        table.insert(currentFurniture, item)
    end

    local okEncode, furnitureJson = pcall(function()
        return json.encode(currentFurniture)
    end)
    if not okEncode then
        Bridge.Server.Notify(src, 'Could not process furniture data.', 'error')
        return
    end

    local okUpdate, updateResult = pcall(function()
        return MySQL.update.await('UPDATE apartments SET furniture = ? WHERE room_id = ? AND citizenid = ?', {
            furnitureJson,
            roomId,
            result.citizenid
        })
    end)
    if not okUpdate then
        Bridge.Server.Notify(src, 'Database error while saving furniture.', 'error')
        return
    end

    if Bridge.Server.RegisterPropertyStashes then
        Bridge.Server.RegisterPropertyStashes(roomId, currentFurniture)
    end

    TriggerClientEvent('LNS_Housing:client:updateApartmentFurniture', -1, roomId, currentFurniture)
    Bridge.Server.Notify(src, 'Furniture bought successfully!', 'success')
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
    for _, room in ipairs(Settings.Rooms) do
        if room.id == roomId then
            return true
        end
    end
    return false
end)

lib.callback.register('LNS_Housing:server:getApartmentRooms', function(source)
    WaitForDb()
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
            local tabletCoords = nil
            if r.tablet_coords then
                tabletCoords = json.decode(r.tablet_coords)
            end
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
                isStarter = (r.is_starter == 1 or r.is_starter == true),
                tabletCoords = tabletCoords
            })
        end
    end
    return formatted
end)

lib.callback.register('LNS_Housing:server:createApartment', function(source, data)
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

    local success = MySQL.insert.await([[
        INSERT INTO apartment_rooms (id, corners, thickness, zOffset, door_model, door_coords, door_heading, spawn_coords, price, is_starter, tablet_coords)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        isStarter and 1 or 0,
        tabletCoords and json.encode(tabletCoords) or nil
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
            isStarter = isStarter,
            tabletCoords = tabletCoords
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
            isStarter = isStarter,
            tabletCoords = tabletCoords
        })

        return true
    end

    return false
end)

lib.callback.register('LNS_Housing:server:updateApartment', function(source, data)
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

    local success = MySQL.update.await([[
        UPDATE apartment_rooms 
        SET corners = ?, thickness = ?, zOffset = ?, door_model = ?, door_coords = ?, door_heading = ?, spawn_coords = ?, price = ?, is_starter = ?, tablet_coords = ?
        WHERE id = ?
    ]], {
        json.encode(corners),
        thickness,
        zOffset,
        doorModel,
        doorCoords and json.encode(doorCoords) or nil,
        doorHeading,
        json.encode(spawn),
        price,
        isStarter and 1 or 0,
        tabletCoords and json.encode(tabletCoords) or nil,
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
        for i, c in ipairs(corners) do
            cornersVec[i] = vec3(c.x, c.y, c.z)
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
            tabletCoords = tabletCoords
        }

        if foundIndex then
            Settings.Rooms[foundIndex] = updatedRoom
        else
            table.insert(Settings.Rooms, updatedRoom)
        end

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
                local doorId = exports.ox_doorlock:createDoorlock({
                    name = doorName,
                    model = doorModel,
                    coords = doorCoordsVec,
                    heading = doorHeading or 0.0,
                    state = 1,
                    maxDistance = 2.0
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
            tabletCoords = tabletCoords
        })

        return true
    end

    return false
end)

RegisterNetEvent('LNS_Housing:server:toggleApartmentLock', function(roomId)
    local src = source
    local hasAccess = CheckPermission(src, 'apartment', roomId, 'entry') or CheckPermission(src, 'apartment', roomId, 'manage')

    if not hasAccess then
        Bridge.Server.Notify(src, 'You do not have key access to lock/unlock this apartment.', 'error')
        return
    end

    local doorId = roomDoors[roomId]
    if doorId then
        local currentState = 1
        local doorData = nil
        if exports.ox_doorlock and exports.ox_doorlock.getDoor then
            pcall(function() doorData = exports.ox_doorlock:getDoor(doorId) end)
        elseif exports.ox_doorlock and exports.ox_doorlock.getDoorData then
            pcall(function() doorData = exports.ox_doorlock:getDoorData(doorId) end)
        end
        if doorData then
            currentState = doorData.state
        end

        local newState = currentState == 1 and 0 or 1
        exports.ox_doorlock:setDoorState(doorId, newState)

        local stateStr = newState == 1 and 'locked' or 'unlocked'
        Bridge.Server.Notify(src, 'Apartment is now ' .. stateStr .. '.', 'success')
    else
        Bridge.Server.Notify(src, 'Door lock not found for this apartment.', 'error')
    end
end)

function GetApartmentDoorId(roomId)
    return roomDoors[roomId]
end