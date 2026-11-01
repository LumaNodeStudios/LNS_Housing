local Settings = lib.load('shared.settings')
local TrashStashes = {}
local TrashCache = {}
local CarryingPlayers = {}
local isTrashDbReady = false

function RegisterTrashStash(stashId, propertyId, furnitureId)
    if not stashId then return end
    local strId = tostring(stashId)
    TrashStashes[strId] = {
        propertyId = propertyId,
        furnitureId = furnitureId,
        registeredAt = os.time()
    }
    debugPrint('info', '[LNS_Housing:Trash] Registered trash stash:', strId, 'property:', propertyId)

    if Bridge and Bridge.Server and Bridge.Server.ClearInventory then
        Bridge.Server.ClearInventory(strId)
    end
end

function IsTrashStash(stashId)
    if not stashId then return false, nil end
    local strId = tostring(stashId)
    if TrashStashes[strId] then
        return true, TrashStashes[strId]
    end

    local propId, furnId = strId:match('housing_([^_]+)_(.+)')
    if propId and furnId then
        local furnitureList = nil
        local p = Properties and (Properties[propId] or (tonumber(propId) and Properties[tonumber(propId)]))
        if p and p.furniture then
            furnitureList = p.furniture
        else
            local row = MySQL.single.await('SELECT furniture FROM apartments WHERE room_id = ? OR room_id = ?', { propId, tostring(propId) })
            if row and row.furniture then
                local ok, decoded = pcall(json.decode, row.furniture)
                if ok and type(decoded) == 'table' then
                    furnitureList = decoded
                end
            end
        end

        if furnitureList then
            for _, f in ipairs(furnitureList) do
                if tostring(f.id) == tostring(furnId) then
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
                    if itemData and (itemData.isTrash or itemData.type == 'trash' or itemData.isDisposal or itemData.type == 'disposal') then
                        TrashStashes[strId] = {
                            propertyId = propId,
                            furnitureId = furnId,
                            registeredAt = os.time()
                        }
                        return true, TrashStashes[strId]
                    end
                end
            end
        end
    end

    local lower = strId:lower()
    if lower:find('trash') or lower:find('dumpster') then
        return true, nil
    end

    return false, nil
end

local function DestroyTrashItems(stashId, playerId)
    if not Settings.TrashCan or Settings.TrashCan.Enabled == false then return 0 end
    local strId = tostring(stashId)

    if not Bridge or not Bridge.Server then return 0 end

    local items = Bridge.Server.GetInventoryItems(strId)
    local itemCount = 0
    for _, item in pairs(items) do
        if item then
            itemCount = itemCount + 1
        end
    end

    if itemCount > 0 then
        Bridge.Server.ClearInventory(strId)
        debugPrint('info', ('[LNS_Housing:Trash] Stash %s emptied (%d items permanently destroyed)'):format(strId, itemCount))

        if playerId and playerId > 0 then
            if Settings.TrashCan.NotifyOnDestroy ~= false then
                Bridge.Server.Notify(playerId, 'Items placed in the trash can were permanently destroyed.', 'inform')
            end
        end
        return itemCount
    end

    return 0
end

if Bridge and Bridge.Server and Bridge.Server.OnClosedInventory then
    Bridge.Server.OnClosedInventory(function(playerId, invId)
        if not invId then return end
        local isTrash = IsTrashStash(invId)
        if not isTrash then return end

        if Settings.TrashCan and Settings.TrashCan.DestroyOnClose == false then return end

        SetTimeout(50, function()
            DestroyTrashItems(invId, playerId)
        end)
    end)
end

local trashHookInitialized = false
local function InitTrashHooks()
    if trashHookInitialized then return end
    if not Bridge or not Bridge.Server or not Bridge.Server.RegisterInventoryHook then return end

    Bridge.Server.RegisterInventoryHook('openInventory', function(payload)
        if not payload or not payload.inventoryId then return true end
        local invId = tostring(payload.inventoryId)
        if IsTrashStash(invId) then
            Bridge.Server.ClearInventory(invId)
        end
        return true
    end)

    trashHookInitialized = true
    debugPrint('info', '[LNS_Housing] Trash disposal hooks successfully initialized via bridge.')
end

InitTrashHooks()

local function GetKey(propertyId, isApartment)
    return (isApartment and 'apartment_' or 'house_') .. tostring(propertyId)
end

local function InitTrashSystem()
    if isTrashDbReady then return end
    isTrashDbReady = true

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `housing_trash` (
            `id` VARCHAR(64) PRIMARY KEY,
            `property_id` INT NOT NULL,
            `is_apartment` TINYINT(1) DEFAULT 0,
            `last_cleaned` INT DEFAULT 0,
            `trash_data` LONGTEXT DEFAULT '{}',
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    local rows = MySQL.query.await('SELECT * FROM housing_trash')
    if rows then
        for _, row in ipairs(rows) do
            local trashData = {}
            if row.trash_data and row.trash_data ~= '' then
                local ok, decoded = pcall(json.decode, row.trash_data)
                if ok and type(decoded) == 'table' then
                    trashData = decoded
                end
            end
            TrashCache[row.id] = {
                id = row.id,
                propertyId = row.property_id,
                isApartment = (row.is_apartment == 1 or row.is_apartment == true),
                lastCleaned = tonumber(row.last_cleaned) or os.time(),
                trashData = trashData
            }
        end
        debugPrint('info', ('[LNS_Housing:Trash] Loaded %d property trash records.'):format(#rows))
    end
end

CreateThread(function()
    while not MySQL or not MySQL.ready do
        Wait(100)
    end
    MySQL.ready(function()
        InitTrashSystem()
    end)
    SetTimeout(1000, function()
        if not isTrashDbReady then
            InitTrashSystem()
        end
    end)
end)

local function GetOrCreateTrashEntry(propertyId, isApartment)
    local key = GetKey(propertyId, isApartment)
    if TrashCache[key] then
        return TrashCache[key]
    end

    local now = os.time()
    local entry = {
        id = key,
        propertyId = tonumber(propertyId) or propertyId,
        isApartment = isApartment and true or false,
        lastCleaned = now,
        trashData = {}
    }
    TrashCache[key] = entry

    MySQL.insert('INSERT INTO housing_trash (id, property_id, is_apartment, last_cleaned, trash_data) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP', {
        key,
        tonumber(propertyId) or 0,
        isApartment and 1 or 0,
        now,
        json.encode({})
    })

    return entry
end

local function CalculateActiveTrash(propertyId, isApartment)
    if not Settings.Trash or Settings.Trash.Enabled == false then
        return 0, {}, os.time()
    end

    local entry = GetOrCreateTrashEntry(propertyId, isApartment)
    local now = os.time()
    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 5
    local buildupInterval = (Settings.Trash and Settings.Trash.BuildupInterval) or 7200
    if buildupInterval <= 0 then buildupInterval = 7200 end

    local activePiles = {}
    local count = 0

    for i = 1, maxTrash do
        local strIdx = tostring(i)
        local cleanedAt = entry.trashData[strIdx] or entry.trashData[i]

        if cleanedAt then
            local timeSinceCleaned = now - cleanedAt
            if timeSinceCleaned >= buildupInterval then
                activePiles[i] = true
                count = count + 1
            else
                activePiles[i] = false
            end
        else
            local dueTime = i * buildupInterval
            local timeSinceLastCleaned = now - entry.lastCleaned
            if timeSinceLastCleaned >= dueTime then
                activePiles[i] = true
                count = count + 1
            else
                activePiles[i] = false
            end
        end
    end

    return count, activePiles, entry.lastCleaned
end

local function SaveTrashEntry(entry)
    if not entry then return end
    MySQL.update('UPDATE housing_trash SET last_cleaned = ?, trash_data = ? WHERE id = ?', {
        entry.lastCleaned,
        json.encode(entry.trashData or {}),
        entry.id
    })
end

lib.callback.register('LNS_Housing:server:getPropertyTrash', function(source, propertyId, isApartment)
    if not Settings.Trash or Settings.Trash.Enabled == false then
        return { trashCount = 0, activePiles = {}, serverTime = os.time() }
    end

    local count, activePiles, lastCleaned = CalculateActiveTrash(propertyId, isApartment)
    return {
        trashCount = count,
        activePiles = activePiles,
        lastCleaned = lastCleaned,
        serverTime = os.time()
    }
end)

lib.callback.register('LNS_Housing:server:pickupTrashPile', function(source, propertyId, index, isApartment)
    local src = source
    if not Settings.Trash or Settings.Trash.Enabled == false then
        return { success = false, message = 'Trash system is disabled.' }
    end

    index = tonumber(index)
    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 5
    if not index or index < 1 or index > maxTrash then
        return { success = false, message = 'Invalid trash pile.' }
    end

    if Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = CheckPermission(src, targetType, propertyId, 'entry')
        if not hasAccess then
            return { success = false, message = 'You do not have permission to clean trash here.' }
        end
    end

    local entry = GetOrCreateTrashEntry(propertyId, isApartment)
    local count, activePiles = CalculateActiveTrash(propertyId, isApartment)
    if not activePiles[index] then
        return { success = false, message = 'This trash pile has already been cleaned.' }
    end

    local now = os.time()
    entry.trashData[tostring(index)] = now

    local remainingCount, remainingPiles = CalculateActiveTrash(propertyId, isApartment)
    if remainingCount == 0 then
        entry.lastCleaned = now
        entry.trashData = {}
    end

    SaveTrashEntry(entry)

    CarryingPlayers[src] = {
        propertyId = propertyId,
        isApartment = isApartment and true or false,
        timestamp = now
    }

    TriggerClientEvent('LNS_Housing:client:syncTrashRemoved', -1, propertyId, index, isApartment)
    debugPrint('info', ('[LNS_Housing:Trash] Player %d picked up trash pile #%d in %s %s'):format(src, index, isApartment and 'apartment' or 'house', tostring(propertyId)))

    return { success = true, remainingCount = remainingCount }
end)

RegisterNetEvent('LNS_Housing:server:disposeTrash', function(propertyId, isApartment)
    local src = source
    if not src or src <= 0 then return end

    if not CarryingPlayers[src] then
        debugPrint('warn', ('[LNS_Housing:Trash] Player %d attempted to dispose trash without carrying any.'):format(src))
        return
    end

    CarryingPlayers[src] = nil

    if Settings.Trash and Settings.Trash.Reward and Settings.Trash.Reward.Enabled then
        local minReward = Settings.Trash.Reward.Min or 15
        local maxReward = Settings.Trash.Reward.Max or 50
        local reward = math.random(minReward, maxReward)
        local account = Settings.Trash.Reward.Account or 'money'

        Bridge.Server.AddMoney(src, account, reward, 'Disposed Street Trash')
        Bridge.Server.Notify(src, ('You threw away the trash and earned $%d!'):format(reward), 'success')
    else
        Bridge.Server.Notify(src, 'You threw away the trash into the dumpster.', 'success')
    end

    debugPrint('info', ('[LNS_Housing:Trash] Player %d disposed trash in dumpster.'):format(src))
end)

RegisterNetEvent('LNS_Housing:server:dropTrash', function()
    local src = source
    if not src or src <= 0 then return end
    CarryingPlayers[src] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    CarryingPlayers[src] = nil
end)

exports('GetPropertyTrashCount', function(propertyId, isApartment)
    local count = CalculateActiveTrash(propertyId, isApartment)
    return count
end)

exports('CleanPropertyTrash', function(propertyId, isApartment)
    local key = GetKey(propertyId, isApartment)
    local entry = GetOrCreateTrashEntry(propertyId, isApartment)
    local now = os.time()
    entry.lastCleaned = now
    entry.trashData = {}
    SaveTrashEntry(entry)
    TriggerClientEvent('LNS_Housing:client:syncTrashReset', -1, propertyId, isApartment)
    return true
end)

exports('SetPropertyTrashCount', function(propertyId, isApartment, count)
    local key = GetKey(propertyId, isApartment)
    local entry = GetOrCreateTrashEntry(propertyId, isApartment)
    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 5
    count = math.min(maxTrash, math.max(0, tonumber(count) or 0))

    local buildupInterval = (Settings.Trash and Settings.Trash.BuildupInterval) or 7200
    local now = os.time()

    entry.trashData = {}
    if count == 0 then
        entry.lastCleaned = now
    else
        entry.lastCleaned = now - (count * buildupInterval)
    end

    SaveTrashEntry(entry)
    TriggerClientEvent('LNS_Housing:client:syncTrashReset', -1, propertyId, isApartment)
    return true
end)

RegisterCommand('cleantrash', function(source, args)
    if source > 0 and not CheckPermission(source, 'admin') then
        Bridge.Server.Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    local propertyId = tonumber(args[1]) or args[1]
    local isApartment = (args[2] == 'apartment' or args[2] == '1' or args[2] == 'true')
    if not propertyId then
        local msg = 'Usage: /cleantrash [propertyId/roomId] [optional: apartment]'
        if source > 0 then
            Bridge.Server.Notify(source, msg, 'inform')
        else
            print(msg)
        end
        return
    end

    exports.LNS_Housing:CleanPropertyTrash(propertyId, isApartment)
    local doneMsg = ('Successfully cleaned all trash for %s %s.'):format(isApartment and 'apartment' or 'house', tostring(propertyId))
    if source > 0 then
        Bridge.Server.Notify(source, doneMsg, 'success')
    else
        print(doneMsg)
    end
end, false)

RegisterCommand('settrash', function(source, args)
    if source > 0 and not CheckPermission(source, 'admin') then
        Bridge.Server.Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    local propertyId = tonumber(args[1]) or args[1]
    local count = tonumber(args[2])
    local isApartment = (args[3] == 'apartment' or args[3] == '1' or args[3] == 'true')

    if not propertyId or not count then
        local msg = 'Usage: /settrash [propertyId/roomId] [count] [optional: apartment]'
        if source > 0 then
            Bridge.Server.Notify(source, msg, 'inform')
        else
            print(msg)
        end
        return
    end

    exports.LNS_Housing:SetPropertyTrashCount(propertyId, isApartment, count)
    local doneMsg = ('Set trash count to %d for %s %s.'):format(count, isApartment and 'apartment' or 'house', tostring(propertyId))
    if source > 0 then
        Bridge.Server.Notify(source, doneMsg, 'success')
    else
        print(doneMsg)
    end
end, false)
