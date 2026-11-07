local Settings = lib.load('shared.settings')
local TrashStashes = {}
local TrashCache = {}
local RobotCache = {}
local CarryingPlayers = {}
local DroppedBags = {}
local DroppedBagCounter = 0
local LastPickupTime = {}
local LastDisposalTime = {}
local PlayerHourlyDisposals = {}
local isTrashDbReady = false

local TrashItemConfig = Settings.Trash and Settings.Trash.Item
local IsTrashItem = TrashItemConfig and TrashItemConfig.Enabled == true
local TrashItemName = TrashItemConfig and (TrashItemConfig.Name or TrashItemConfig.ItemName) or 'trashbag'
local TrashMaxCarry = TrashItemConfig and tonumber(TrashItemConfig.MaxCarry) or nil

if IsTrashItem then
    Bridge.Server.CreateUseableItem(TrashItemName, function(source)
        TriggerClientEvent('LNS_Housing:client:toggleCarryTrashItem', source)
    end)
end

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

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `housing_clean_robot` (
            `id` VARCHAR(64) PRIMARY KEY,
            `property_id` VARCHAR(64) NOT NULL,
            `is_apartment` TINYINT(1) DEFAULT 0,
            `timer_interval` INT DEFAULT 3600,
            `last_clean` INT DEFAULT 0,
            `custom_path` LONGTEXT DEFAULT '[]',
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

    local robotRows = MySQL.query.await('SELECT * FROM housing_clean_robot')
    if robotRows then
        for _, row in ipairs(robotRows) do
            local customPath = {}
            if row.custom_path and row.custom_path ~= '' then
                local ok, decoded = pcall(json.decode, row.custom_path)
                if ok and type(decoded) == 'table' then
                    customPath = decoded
                end
            end
            RobotCache[row.id] = {
                id = row.id,
                propertyId = row.property_id,
                isApartment = (row.is_apartment == 1 or row.is_apartment == true),
                timerInterval = tonumber(row.timer_interval) or 3600,
                lastClean = tonumber(row.last_clean) or 0,
                customPath = customPath
            }
        end
        debugPrint('info', ('[LNS_Housing:Trash] Loaded %d clean robot records.'):format(#robotRows))
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
    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 8
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

local function IsPlayerNearProperty(src, propertyId, isApartment)
    if not src or src <= 0 then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pCoords = GetEntityCoords(ped)
    if not pCoords then return false end

    local pState = Player(src).state
    local insideId = pState and pState.insidePropertyId

    if isApartment then
        if insideId and (tostring(insideId) == tostring(propertyId) or tonumber(insideId) == tonumber(propertyId)) then
            return true
        end

        for _, r in ipairs(Settings.Rooms or {}) do
            if r.id == propertyId or tostring(r.id) == tostring(propertyId) or tonumber(r.id) == tonumber(propertyId) then
                local refCoords = (r.doorCoords and vec3(r.doorCoords.x, r.doorCoords.y, r.doorCoords.z))
                    or (r.spawn and vec3(r.spawn.x, r.spawn.y, r.spawn.z))
                    or (r.interior_center and vec3(r.interior_center.x, r.interior_center.y, r.interior_center.z))
                    or (r.interior_coords and vec3(r.interior_coords.x, r.interior_coords.y, r.interior_coords.z))
                if refCoords and #(pCoords - refCoords) <= 85.0 then
                    return true
                end
            end
        end

        local p = Properties and (Properties[propertyId] or (tonumber(propertyId) and Properties[tonumber(propertyId)]))
        if p and p.metadata and p.metadata.entrance then
            local ent = p.metadata.entrance
            if #(pCoords - vec3(ent.x, ent.y, ent.z)) <= 85.0 then
                return true
            end
        end

        return false
    else
        local numPropId = tonumber(propertyId)
        if insideId and numPropId and tonumber(insideId) == numPropId then
            return true
        end

        if numPropId and GetPlayerRoutingBucket(src) == numPropId then
            return true
        end

        local p = Properties and (Properties[propertyId] or (numPropId and Properties[numPropId]))
        if p then
            local ent = p.metadata and p.metadata.entrance
            if ent and #(pCoords - vec3(ent.x, ent.y, ent.z)) <= 85.0 then
                return true
            end

            local shellName = p.metadata and p.metadata.shell
            local shellData = shellName and Settings.Shells and Settings.Shells[shellName]
            if shellData and shellData.coords and #(pCoords - vec3(shellData.coords.x, shellData.coords.y, shellData.coords.z)) <= 85.0 then
                return true
            end
        end

        return false
    end
end

lib.callback.register('LNS_Housing:server:pickupTrashPile', function(source, propertyId, index, isApartment)
    local src = source
    if not Settings.Trash or Settings.Trash.Enabled == false then
        return { success = false, message = 'Trash system is disabled.' }
    end

    if not propertyId then
        return { success = false, message = 'Invalid property ID.' }
    end

    index = tonumber(index)
    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 8
    if not index or index < 1 or index > maxTrash then
        return { success = false, message = 'Invalid trash pile.' }
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetEntityHealth(ped) <= 0 then
        return { success = false, message = 'You cannot pick up trash in your current state.' }
    end

    if GetVehiclePedIsIn(ped, false) ~= 0 then
        return { success = false, message = 'You cannot pick up trash while inside a vehicle.' }
    end

    if not IsTrashItem then
        if CarryingPlayers[src] then
            return { success = false, message = 'You are already carrying a trash bag! Dispose of it first.' }
        end
    else
        if TrashMaxCarry and TrashMaxCarry > 0 then
            local currentCount = Bridge.Server.Search(src, 'count', TrashItemName) or 0
            if currentCount >= TrashMaxCarry then
                return { success = false, message = ('You cannot carry more than %d trash bags!'):format(TrashMaxCarry) }
            end
        end
    end

    local now = os.time()
    if LastPickupTime[src] and (now - LastPickupTime[src] < 3) then
        return { success = false, message = 'You are picking up trash too fast.' }
    end

    if not IsPlayerNearProperty(src, propertyId, isApartment) then
        debugPrint('warn', ('[LNS_Housing:Trash:Exploit] Player %d failed proximity check for property %s (%s). Blocked remote pickup.'):format(
            src, tostring(propertyId), isApartment and 'apartment' or 'house'
        ))
        return { success = false, message = 'You are too far from this property to pick up trash.' }
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

    if IsTrashItem then
        local added = Bridge.Server.AddItem(src, TrashItemName, 1, {
            propertyId = propertyId,
            isApartment = isApartment and true or false,
            cleanedAt = now
        })
        if not added then
            return { success = false, message = 'Your inventory is full! You cannot carry another trash bag.' }
        end
    end

    entry.trashData[tostring(index)] = now

    local remainingCount, remainingPiles = CalculateActiveTrash(propertyId, isApartment)
    if remainingCount == 0 then
        entry.lastCleaned = now
        entry.trashData = {}
    end

    SaveTrashEntry(entry)

    LastPickupTime[src] = now
    CarryingPlayers[src] = {
        propertyId = propertyId,
        isApartment = isApartment and true or false,
        timestamp = now
    }

    TriggerClientEvent('LNS_Housing:client:syncTrashRemoved', -1, propertyId, index, isApartment)
    debugPrint('info', ('[LNS_Housing:Trash] Player %d picked up trash pile #%d in %s %s (Item: %s)'):format(
        src, index, isApartment and 'apartment' or 'house', tostring(propertyId), tostring(IsTrashItem)
    ))

    return { success = true, remainingCount = remainingCount, isItem = IsTrashItem }
end)

RegisterNetEvent('LNS_Housing:server:disposeTrash', function(propertyId, isApartment, clientDumpsterCoords)
    local src = source
    if not src or src <= 0 then return end

    local carryData = CarryingPlayers[src]

    if not IsTrashItem then
        if not carryData then
            debugPrint('warn', ('[LNS_Housing:Trash:Security] Exploit blocked: Player %d attempted to dispose trash without carrying any.'):format(src))
            return
        end

        if carryData.propertyId and propertyId and tostring(carryData.propertyId) ~= tostring(propertyId) then
            debugPrint('warn', ('[LNS_Housing:Trash:Security] Exploit blocked: Player %d attempted disposal with mismatched property ID.'):format(src))
            CarryingPlayers[src] = nil
            return
        end
    else
        local count = Bridge.Server.Search(src, 'count', TrashItemName) or 0
        if count <= 0 then
            Bridge.Server.Notify(src, 'You do not have a trash bag in your inventory to throw away!', 'error')
            CarryingPlayers[src] = nil
            return
        end
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetEntityHealth(ped) <= 0 then
        CarryingPlayers[src] = nil
        debugPrint('warn', ('[LNS_Housing:Trash:Security] Player %d attempted to dispose trash while dead or invalid ped.'):format(src))
        return
    end

    if GetVehiclePedIsIn(ped, false) ~= 0 then
        CarryingPlayers[src] = nil
        Bridge.Server.Notify(src, 'You cannot throw away trash from inside a vehicle!', 'error')
        return
    end

    local bucket = GetPlayerRoutingBucket(src)
    if bucket ~= 0 then
        debugPrint('warn', ('[LNS_Housing:Trash:Security] Exploit blocked: Player %d attempted disposal inside private shell routing bucket (%d).'):format(src, bucket))
        Bridge.Server.Notify(src, 'You must take the trash outside to a street dumpster!', 'error')
        return
    end

    local now = os.time()
    local throwDurationSec = ((Settings.Trash and Settings.Trash.ThrowDuration) or 2500) / 1000

    if not IsTrashItem then
        local cleanDurationSec = ((Settings.Trash and Settings.Trash.CleanDuration) or 4000) / 1000
        local minRequiredTime = math.max(3.0, (cleanDurationSec + throwDurationSec) - 1.5)
        local elapsed = now - (carryData and carryData.timestamp or now)

        if elapsed < minRequiredTime then
            debugPrint('warn', ('[LNS_Housing:Trash:Security] Exploit blocked: Player %d tried to dispose trash in %d seconds (minimum %0.1fs required).'):format(src, elapsed, minRequiredTime))
            CarryingPlayers[src] = nil
            return
        end

        if elapsed > 1200 then
            CarryingPlayers[src] = nil
            Bridge.Server.Notify(src, 'The trash bag was carried for too long and broke.', 'error')
            return
        end
    end

    if LastDisposalTime[src] and (now - LastDisposalTime[src] < math.max(1, math.floor(throwDurationSec - 0.5))) then
        debugPrint('warn', ('[LNS_Housing:Trash:Security] Player %d attempted rapid trash disposal.'):format(src))
        return
    end

    local playerCoords = GetEntityCoords(ped)
    if clientDumpsterCoords and (type(clientDumpsterCoords) == 'vector3' or (type(clientDumpsterCoords) == 'table' and clientDumpsterCoords.x)) then
        local dCoords = vec3(clientDumpsterCoords.x, clientDumpsterCoords.y, clientDumpsterCoords.z)
        local dist = #(playerCoords - dCoords)
        if dist > 8.0 then
            debugPrint('warn', ('[LNS_Housing:Trash:Security] Exploit blocked: Player %d is %0.1fm away from the claimed dumpster target!'):format(src, dist))
            CarryingPlayers[src] = nil
            return
        end
    end

    if IsTrashItem then
        local removed = Bridge.Server.RemoveItem(src, TrashItemName, 1)
        if not removed then
            Bridge.Server.Notify(src, 'Could not remove the trash bag from your inventory.', 'error')
            return
        end
        local remaining = Bridge.Server.Search(src, 'count', TrashItemName) or 0
        if remaining <= 0 then
            CarryingPlayers[src] = nil
        end
    else
        CarryingPlayers[src] = nil
    end

    LastDisposalTime[src] = now

    local hourKey = math.floor(now / 3600)
    PlayerHourlyDisposals[src] = PlayerHourlyDisposals[src] or { hour = hourKey, count = 0 }
    if PlayerHourlyDisposals[src].hour ~= hourKey then
        PlayerHourlyDisposals[src] = { hour = hourKey, count = 0 }
    end
    PlayerHourlyDisposals[src].count = PlayerHourlyDisposals[src].count + 1

    if PlayerHourlyDisposals[src].count > 40 then
        debugPrint('warn', ('[LNS_Housing:Trash:Alert] High trash activity: Player %d has disposed %d trash bags this hour!'):format(src, PlayerHourlyDisposals[src].count))
    end

    if Settings.Trash and Settings.Trash.Reward and Settings.Trash.Reward.Enabled then
        local minReward = math.max(1, math.floor(tonumber(Settings.Trash.Reward.Min) or 15))
        local maxReward = math.max(minReward, math.floor(tonumber(Settings.Trash.Reward.Max) or minReward))
        local reward = (minReward == maxReward) and minReward or math.random(minReward, maxReward)
        local account = tostring(Settings.Trash.Reward.Account or 'cash')
        if account ~= 'money' and account ~= 'cash' and account ~= 'bank' then
            account = 'cash'
        end

        Bridge.Server.AddMoney(src, account, reward, 'Disposed Street Trash')
        Bridge.Server.Notify(src, ('You threw away the trash and earned $%d!'):format(reward), 'success')
    else
        Bridge.Server.Notify(src, 'You threw away the trash into the dumpster.', 'success')
    end

    debugPrint('info', ('[LNS_Housing:Trash] Player %d legitimately disposed trash in dumpster (Item mode: %s).'):format(src, tostring(IsTrashItem)))
end)

RegisterNetEvent('LNS_Housing:server:dropTrashBag', function(propertyId, isApartment, dropCoords)
    local src = source
    if not src or src <= 0 then return end

    local carry = CarryingPlayers[src]

    if not IsTrashItem then
        if not carry then return end
    else
        local count = Bridge.Server.Search(src, 'count', TrashItemName) or 0
        if count <= 0 then
            CarryingPlayers[src] = nil
            return
        end
        local removed = Bridge.Server.RemoveItem(src, TrashItemName, 1)
        if not removed then return end
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local useCoords = pCoords

    if dropCoords and (type(dropCoords) == 'vector3' or (type(dropCoords) == 'table' and dropCoords.x)) then
        local dist = #(pCoords - vec3(dropCoords.x, dropCoords.y, dropCoords.z))
        if dist <= 4.0 then
            useCoords = vec3(dropCoords.x, dropCoords.y, dropCoords.z)
        end
    end

    local bucket = GetPlayerRoutingBucket(src)
    DroppedBagCounter = DroppedBagCounter + 1
    local bagId = ('bag_%d_%d'):format(src, DroppedBagCounter)

    DroppedBags[bagId] = {
        id = bagId,
        propertyId = (carry and carry.propertyId) or propertyId,
        isApartment = (carry and carry.isApartment) or (isApartment and true or false),
        coords = { x = useCoords.x, y = useCoords.y, z = useCoords.z },
        bucket = bucket,
        droppedAt = os.time(),
        isItem = IsTrashItem
    }

    if IsTrashItem then
        local remaining = Bridge.Server.Search(src, 'count', TrashItemName) or 0
        if remaining <= 0 then
            CarryingPlayers[src] = nil
        end
    else
        CarryingPlayers[src] = nil
    end

    TriggerClientEvent('LNS_Housing:client:syncDroppedBag', -1, DroppedBags[bagId])
    debugPrint('info', ('[LNS_Housing:Trash] Player %d dropped physical trash bag #%s at %0.2f, %0.2f, %0.2f (bucket %d, Item: %s)'):format(
        src, bagId, useCoords.x, useCoords.y, useCoords.z, bucket, tostring(IsTrashItem)
    ))
end)

lib.callback.register('LNS_Housing:server:pickupDroppedBag', function(source, bagId)
    local src = source
    if not src or src <= 0 then
        return { success = false, message = 'Invalid player.' }
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetEntityHealth(ped) <= 0 then
        return { success = false, message = 'You cannot pick up trash in your current state.' }
    end

    if GetVehiclePedIsIn(ped, false) ~= 0 then
        return { success = false, message = 'You cannot pick up trash while inside a vehicle.' }
    end

    if not IsTrashItem then
        if CarryingPlayers[src] then
            return { success = false, message = 'You are already carrying a trash bag! Dispose of it first.' }
        end
    else
        if TrashMaxCarry and TrashMaxCarry > 0 then
            local currentCount = Bridge.Server.Search(src, 'count', TrashItemName) or 0
            if currentCount >= TrashMaxCarry then
                return { success = false, message = ('You cannot carry more than %d trash bags!'):format(TrashMaxCarry) }
            end
        end
    end

    local bag = DroppedBags[bagId]
    if not bag then
        return { success = false, message = 'This trash bag no longer exists.' }
    end

    local pCoords = GetEntityCoords(ped)
    local dist = #(pCoords - vec3(bag.coords.x, bag.coords.y, bag.coords.z))
    if dist > 5.0 then
        return { success = false, message = 'You are too far from the trash bag.' }
    end

    local currentBucket = GetPlayerRoutingBucket(src)
    if currentBucket ~= bag.bucket then
        return { success = false, message = 'This trash bag is in another dimension.' }
    end

    local propId = bag.propertyId
    local isApt = bag.isApartment

    if IsTrashItem then
        local added = Bridge.Server.AddItem(src, TrashItemName, 1, {
            propertyId = propId,
            isApartment = isApt
        })
        if not added then
            return { success = false, message = 'Your inventory is full! You cannot carry this trash bag.' }
        end
    end

    DroppedBags[bagId] = nil
    CarryingPlayers[src] = {
        propertyId = propId,
        isApartment = isApt,
        timestamp = os.time()
    }

    TriggerClientEvent('LNS_Housing:client:syncRemoveDroppedBag', -1, bagId)
    debugPrint('info', ('[LNS_Housing:Trash] Player %d picked up dropped trash bag #%s (Item: %s)'):format(src, bagId, tostring(IsTrashItem)))

    return {
        success = true,
        propertyId = propId,
        isApartment = isApt,
        isItem = IsTrashItem
    }
end)

lib.callback.register('LNS_Housing:server:getDroppedBags', function(source)
    local src = source
    local bucket = GetPlayerRoutingBucket(src)
    local relevant = {}
    for id, bag in pairs(DroppedBags) do
        if bag.bucket == bucket then
            relevant[#relevant + 1] = bag
        end
    end
    return relevant
end)

RegisterNetEvent('LNS_Housing:server:dropTrash', function()
    local src = source
    if not src or src <= 0 then return end
    local carry = CarryingPlayers[src]

    if IsTrashItem then
        local count = Bridge.Server.Search(src, 'count', TrashItemName) or 0
        if count <= 0 then
            CarryingPlayers[src] = nil
            return
        end
        Bridge.Server.RemoveItem(src, TrashItemName, 1)
    elseif not carry then
        return
    end

    local ped = GetPlayerPed(src)
    if ped and DoesEntityExist(ped) then
        local pCoords = GetEntityCoords(ped)
        local bucket = GetPlayerRoutingBucket(src)
        DroppedBagCounter = DroppedBagCounter + 1
        local bagId = ('bag_%d_%d'):format(src, DroppedBagCounter)
        DroppedBags[bagId] = {
            id = bagId,
            propertyId = carry and carry.propertyId or nil,
            isApartment = carry and carry.isApartment or false,
            coords = { x = pCoords.x, y = pCoords.y, z = pCoords.z },
            bucket = bucket,
            droppedAt = os.time(),
            isItem = IsTrashItem
        }
        TriggerClientEvent('LNS_Housing:client:syncDroppedBag', -1, DroppedBags[bagId])
    end

    if IsTrashItem then
        local remaining = Bridge.Server.Search(src, 'count', TrashItemName) or 0
        if remaining <= 0 then
            CarryingPlayers[src] = nil
        end
    else
        CarryingPlayers[src] = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if not src then return end

    local carry = CarryingPlayers[src]

    if not IsTrashItem and carry then
        local ped = GetPlayerPed(src)
        if ped and DoesEntityExist(ped) then
            local pCoords = GetEntityCoords(ped)
            local bucket = GetPlayerRoutingBucket(src)
            DroppedBagCounter = DroppedBagCounter + 1
            local bagId = ('bag_%d_%d'):format(src, DroppedBagCounter)
            DroppedBags[bagId] = {
                id = bagId,
                propertyId = carry.propertyId,
                isApartment = carry.isApartment,
                coords = { x = pCoords.x, y = pCoords.y, z = pCoords.z },
                bucket = bucket,
                droppedAt = os.time(),
                isItem = false
            }
            TriggerClientEvent('LNS_Housing:client:syncDroppedBag', -1, DroppedBags[bagId])
        end
    end

    CarryingPlayers[src] = nil
    LastPickupTime[src] = nil
    LastDisposalTime[src] = nil
    PlayerHourlyDisposals[src] = nil
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
    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 8
    count = math.min(maxTrash, math.max(0, tonumber(count) or 0))

    local buildupInterval = (Settings.Trash and Settings.Trash.BuildupInterval) or 7200
    local now = os.time()

    entry.trashData = {}
    if count == 0 then
        entry.lastCleaned = now
    else
        entry.lastCleaned = now - (count * buildupInterval) - 5
    end

    SaveTrashEntry(entry)
    TriggerClientEvent('LNS_Housing:client:syncTrashReset', -1, propertyId, isApartment)
    return true
end)

lib.addCommand('cleantrash', {
    help = 'Clean all trash in a property or apartment (Admin only)',
    params = {
        {
            name = 'propertyId',
            help = 'Property or Room ID (leave empty if standing inside)',
            optional = true,
        },
        {
            name = 'type',
            help = '"apartment" or "house" (optional, auto-detected)',
            optional = true,
        },
    },
}, function(source, args, raw)
    if source > 0 and not CheckPermission(source, 'admin') then
        Bridge.Server.Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    local a1 = args.propertyId or args[1]
    local a2 = args.type or args[2]

    local propertyId = nil
    local isApartment = false

    local pState = source > 0 and Player(source).state or nil
    local insideId = pState and pState.insidePropertyId
    local insideApt = pState and (pState.insideApartment and true or false)

    if a1 then
        propertyId = a1
        if a2 then
            isApartment = (a2:lower() == 'apartment' or a2 == '1' or a2:lower() == 'true')
        elseif insideId and tostring(insideId) == tostring(propertyId) then
            isApartment = insideApt
        else
            for _, r in ipairs(Settings.Rooms or {}) do
                if r.id == propertyId or tostring(r.id) == tostring(propertyId) then
                    isApartment = true
                    break
                end
            end
        end
    elseif insideId then
        propertyId = insideId
        isApartment = insideApt
    end

    if not propertyId then
        local msg = 'Usage: /cleantrash [propertyId] [optional: apartment] (or stand inside a property)'
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
end)

lib.addCommand('settrash', {
    help = 'Set trash count for a property or apartment (Admin only)',
    params = {
        {
            name = 'count',
            help = 'Trash count 0-8 (or Property/Room ID)',
            optional = true,
        },
        {
            name = 'propertyId',
            help = 'Property or Room ID (leave empty if standing inside)',
            optional = true,
        },
        {
            name = 'type',
            help = '"apartment" or "house" (optional, auto-detected)',
            optional = true,
        },
    },
}, function(source, args, raw)
    if source > 0 and not CheckPermission(source, 'admin') then
        Bridge.Server.Notify(source, 'You do not have permission to use this command.', 'error')
        return
    end

    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 8
    local propertyId = nil
    local count = nil
    local isApartment = false

    local pState = source > 0 and Player(source).state or nil
    local insideId = pState and pState.insidePropertyId
    local insideApt = pState and (pState.insideApartment and true or false)

    local a1 = args.count or args[1]
    local a2 = args.propertyId or args[2]
    local a3 = args.type or args[3]

    local n1 = tonumber(a1)
    local n2 = tonumber(a2)

    if not a1 and not a2 and not a3 then
        if insideId then
            propertyId = insideId
            count = maxTrash
            isApartment = insideApt
        end
    elseif n1 and n1 <= maxTrash and not n2 then
        count = n1
        if a2 then
            isApartment = (a2:lower() == 'apartment' or a2 == '1' or a2:lower() == 'true')
            propertyId = insideId
        elseif insideId then
            propertyId = insideId
            isApartment = insideApt
        end
    elseif n2 and n2 <= maxTrash then
        propertyId = a1
        count = n2
        if a3 then
            isApartment = (a3:lower() == 'apartment' or a3 == '1' or a3:lower() == 'true')
        elseif insideId and tostring(insideId) == tostring(propertyId) then
            isApartment = insideApt
        else
            isApartment = false
            for _, r in ipairs(Settings.Rooms or {}) do
                if r.id == propertyId or tostring(r.id) == tostring(propertyId) then
                    isApartment = true
                    break
                end
            end
        end
    elseif n1 and n1 <= maxTrash and a2 then
        count = n1
        propertyId = a2
        if a3 then
            isApartment = (a3:lower() == 'apartment' or a3 == '1' or a3:lower() == 'true')
        elseif insideId and tostring(insideId) == tostring(propertyId) then
            isApartment = insideApt
        else
            isApartment = false
            for _, r in ipairs(Settings.Rooms or {}) do
                if r.id == propertyId or tostring(r.id) == tostring(propertyId) then
                    isApartment = true
                    break
                end
            end
        end
    elseif a1 then
        propertyId = a1
        count = maxTrash
        if a2 then
            isApartment = (a2:lower() == 'apartment' or a2 == '1' or a2:lower() == 'true')
        elseif insideId and tostring(insideId) == tostring(propertyId) then
            isApartment = insideApt
        else
            isApartment = false
            for _, r in ipairs(Settings.Rooms or {}) do
                if r.id == propertyId or tostring(r.id) == tostring(propertyId) then
                    isApartment = true
                    break
                end
            end
        end
    end

    if not propertyId or not count then
        local msg = 'Usage: /settrash [count] (inside property) OR /settrash [propertyId] [count] [optional: apartment]'
        if source > 0 then
            Bridge.Server.Notify(source, msg, 'inform')
        else
            print(msg)
        end
        return
    end

    count = math.min(maxTrash, math.max(0, count))
    exports.LNS_Housing:SetPropertyTrashCount(propertyId, isApartment, count)
    local doneMsg = ('Set trash count to %d for %s %s.'):format(count, isApartment and 'apartment' or 'house', tostring(propertyId))
    if source > 0 then
        Bridge.Server.Notify(source, doneMsg, 'success')
    else
        print(doneMsg)
    end
end)

local function GetOrCreateRobotEntry(propertyId, isApartment)
    local key = GetKey(propertyId, isApartment)
    if RobotCache[key] then
        return RobotCache[key]
    end

    local defaultTimer = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.DefaultTimer) or 3600
    local entry = {
        id = key,
        propertyId = tostring(propertyId),
        isApartment = isApartment and true or false,
        timerInterval = defaultTimer,
        lastClean = os.time(),
        customPath = {}
    }
    RobotCache[key] = entry

    MySQL.insert('INSERT INTO housing_clean_robot (id, property_id, is_apartment, timer_interval, last_clean, custom_path) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE updated_at = CURRENT_TIMESTAMP', {
        key,
        tostring(propertyId),
        isApartment and 1 or 0,
        defaultTimer,
        entry.lastClean,
        json.encode({})
    })

    return entry
end

local function SaveRobotEntry(entry)
    if not entry then return end
    MySQL.update('UPDATE housing_clean_robot SET timer_interval = ?, last_clean = ?, custom_path = ? WHERE id = ?', {
        entry.timerInterval or 3600,
        entry.lastClean or 0,
        json.encode(entry.customPath or {}),
        entry.id
    })
end

local function PropertyHasCleanRobot(propertyId, isApartment)
    local furnitureList = nil
    if isApartment then
        local row = MySQL.single.await('SELECT furniture FROM apartments WHERE room_id = ? OR room_id = ?', { propertyId, tostring(propertyId) })
        if row and row.furniture then
            local ok, decoded = pcall(json.decode, row.furniture)
            if ok and type(decoded) == 'table' then
                furnitureList = decoded
            end
        end
    else
        local p = Properties and (Properties[propertyId] or (tonumber(propertyId) and Properties[tonumber(propertyId)]))
        if p and p.furniture then
            furnitureList = p.furniture
        end
    end

    if furnitureList then
        for _, f in ipairs(furnitureList) do
            local fModel = tostring(f.model or ''):lower()
            if fModel:find('cleandock') then
                return true, f
            end
        end
    end
    return false, nil
end

local function GetPlayersInsideProperty(propertyId, isApartment)
    local players = {}
    local propStr = tostring(propertyId)
    for _, src in ipairs(GetPlayers()) do
        local pSrc = tonumber(src)
        if pSrc and pSrc > 0 then
            local pState = Player(pSrc).state
            if pState and pState.inProperty and pState.insidePropertyId and tostring(pState.insidePropertyId) == propStr then
                players[#players + 1] = pSrc
            end
        end
    end
    return players
end

lib.callback.register('LNS_Housing:server:getRobotData', function(source, propertyId, isApartment)
    local entry = GetOrCreateRobotEntry(propertyId, isApartment)
    return {
        timerInterval = entry.timerInterval,
        lastClean = entry.lastClean,
        customPath = entry.customPath or {},
        serverTime = os.time()
    }
end)

lib.callback.register('LNS_Housing:server:setRobotTimer', function(source, propertyId, isApartment, interval)
    local src = source
    if Settings.Trash and Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = CheckPermission(src, targetType, propertyId, 'furniture') or CheckPermission(src, targetType, propertyId, 'manage')
        if not hasAccess then
            return { success = false, message = 'You do not have permission to configure this robot.' }
        end
    end

    interval = tonumber(interval) or 0
    if interval < 0 then interval = 0 end

    local entry = GetOrCreateRobotEntry(propertyId, isApartment)
    entry.timerInterval = interval
    SaveRobotEntry(entry)
    debugPrint('info', ('[LNS_Housing:Trash] Player %d set clean robot timer to %d seconds for %s.'):format(src, interval, entry.id))
    return { success = true, interval = interval }
end)

lib.callback.register('LNS_Housing:server:saveRobotPath', function(source, propertyId, isApartment, waypoints)
    local src = source
    if Settings.Trash and Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = CheckPermission(src, targetType, propertyId, 'furniture') or CheckPermission(src, targetType, propertyId, 'manage')
        if not hasAccess then
            return { success = false, message = 'You do not have permission to set the robot route.' }
        end
    end

    if type(waypoints) ~= 'table' then
        return { success = false, message = 'Invalid waypoints format.' }
    end

    local maxPoints = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.MaxWaypoints) or 60
    local sanitized = {}
    for i, pt in ipairs(waypoints) do
        if i > maxPoints then break end
        if pt and pt.x and pt.y and pt.z then
            sanitized[#sanitized + 1] = {
                x = math.floor(pt.x * 1000 + 0.5) / 1000,
                y = math.floor(pt.y * 1000 + 0.5) / 1000,
                z = math.floor(pt.z * 1000 + 0.5) / 1000,
            }
        end
    end

    local entry = GetOrCreateRobotEntry(propertyId, isApartment)
    entry.customPath = sanitized
    SaveRobotEntry(entry)
    debugPrint('info', ('[LNS_Housing:Trash] Player %d saved %d path waypoints for robot %s.'):format(src, #sanitized, entry.id))
    return { success = true, count = #sanitized }
end)

lib.callback.register('LNS_Housing:server:clearRobotPath', function(source, propertyId, isApartment)
    local src = source
    if Settings.Trash and Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = CheckPermission(src, targetType, propertyId, 'furniture') or CheckPermission(src, targetType, propertyId, 'manage')
        if not hasAccess then
            return { success = false, message = 'You do not have permission to clear the robot route.' }
        end
    end

    local entry = GetOrCreateRobotEntry(propertyId, isApartment)
    entry.customPath = {}
    SaveRobotEntry(entry)
    debugPrint('info', ('[LNS_Housing:Trash] Player %d cleared clean robot path for %s.'):format(src, entry.id))
    return { success = true }
end)

RegisterNetEvent('LNS_Housing:server:robotCleanPile', function(propertyId, index, isApartment)
    local src = source
    if not src or src <= 0 then return end
    if not Settings.Trash or Settings.Trash.Enabled == false then return end

    if not propertyId then return end
    index = tonumber(index)
    local maxTrash = (Settings.Trash and Settings.Trash.MaxTrash) or 8
    if not index or index < 1 or index > maxTrash then return end

    if not IsPlayerNearProperty(src, propertyId, isApartment) then
        debugPrint('warn', ('[LNS_Housing:Trash:Security] Player %d failed proximity check for robotCleanPile in property %s.'):format(src, tostring(propertyId)))
        return
    end

    if Settings.Trash and Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = CheckPermission(src, targetType, propertyId, 'entry')
        if not hasAccess then return end
    end

    local entry = GetOrCreateTrashEntry(propertyId, isApartment)
    local count, activePiles = CalculateActiveTrash(propertyId, isApartment)
    if not activePiles[index] then return end

    local now = os.time()
    entry.trashData[tostring(index)] = now

    local remainingCount = CalculateActiveTrash(propertyId, isApartment)
    if remainingCount == 0 then
        entry.lastCleaned = now
        entry.trashData = {}
    end

    SaveTrashEntry(entry)
    TriggerClientEvent('LNS_Housing:client:syncTrashRemoved', -1, propertyId, index, isApartment)
    debugPrint('info', ('[LNS_Housing:Trash] Cleaning robot cleaned pile #%d in %s %s'):format(index, isApartment and 'apartment' or 'house', tostring(propertyId)))
end)

RegisterNetEvent('LNS_Housing:server:finishRobotClean', function(propertyId, isApartment)
    local entry = GetOrCreateRobotEntry(propertyId, isApartment)
    entry.lastClean = os.time()
    SaveRobotEntry(entry)
end)

RegisterNetEvent('LNS_Housing:server:requestRobotStartClean', function(propertyId, isApartment, furnitureId)
    local src = source
    if Settings.Trash and Settings.Trash.RequireKeyAccess then
        local targetType = isApartment and 'apartment' or 'house'
        local hasAccess = CheckPermission(src, targetType, propertyId, 'entry')
        if not hasAccess then
            Bridge.Server.Notify(src, 'You do not have permission to operate the cleaning robot.', 'error')
            return
        end
    end

    TriggerClientEvent('LNS_Housing:client:startRobotClean', src, propertyId, isApartment, furnitureId)
end)

CreateThread(function()
    while true do
        local checkInterval = (Settings.Trash and Settings.Trash.Robot and Settings.Trash.Robot.AutoCheckInterval) or 30
        Wait(checkInterval * 1000)

        if Settings.Trash and Settings.Trash.Enabled ~= false and Settings.Trash.Robot and Settings.Trash.Robot.Enabled ~= false then
            local now = os.time()
            for key, entry in pairs(RobotCache) do
                if entry.timerInterval and entry.timerInterval > 0 then
                    if (now - (entry.lastClean or 0)) >= entry.timerInterval then
                        local hasRobot, dockFurn = PropertyHasCleanRobot(entry.propertyId, entry.isApartment)
                        if hasRobot then
                            local count = CalculateActiveTrash(entry.propertyId, entry.isApartment)
                            if count > 0 then
                                local insidePlayers = GetPlayersInsideProperty(entry.propertyId, entry.isApartment)
                                if #insidePlayers > 0 then
                                    TriggerClientEvent('LNS_Housing:client:startRobotClean', insidePlayers[1], entry.propertyId, entry.isApartment, dockFurn and dockFurn.id)
                                    entry.lastClean = now
                                    SaveRobotEntry(entry)
                                    debugPrint('info', ('[LNS_Housing:Trash] Clean robot triggered visually for property %s (%d players inside).'):format(entry.id, #insidePlayers))
                                else
                                    exports.LNS_Housing:CleanPropertyTrash(entry.propertyId, entry.isApartment)
                                    entry.lastClean = now
                                    SaveRobotEntry(entry)
                                    debugPrint('info', ('[LNS_Housing:Trash] Clean robot auto-cleaned property %s in background.'):format(entry.id))
                                end
                            else
                                entry.lastClean = now
                                SaveRobotEntry(entry)
                            end
                        end
                    end
                end
            end
        end
    end
end)
