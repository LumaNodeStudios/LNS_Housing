local Settings = lib.load('shared.settings')

local function IsPhysicalKeysEnabled()
    return Settings and Settings.Security and Settings.Security.PhysicalKeys and Settings.Security.PhysicalKeys.Enabled == true
end

local function ResolveIdentifier(target)
    if not target then return nil end

    local numSrc = tonumber(target)
    if numSrc and GetPlayerPing(numSrc) > 0 then
        return Bridge.Server.GetIdentifier(numSrc)
    end

    if type(target) == 'string' and target ~= '' then
        return target
    end

    if numSrc then
        return Bridge.Server.GetIdentifier(numSrc)
    end

    return nil
end

local function HasEntryPermission(permissions, identifier)
    if not permissions or type(permissions) ~= 'table' then return false end

    if permissions.entry and type(permissions.entry) == 'table' then
        for _, cid in ipairs(permissions.entry) do
            if cid == identifier then
                return true
            end
        end
    elseif #permissions > 0 then
        for _, cid in ipairs(permissions) do
            if cid == identifier then
                return true
            end
        end
    end

    return false
end

local function GetOwnedAndKeyholderHouses(identifier)
    if WaitForDb then WaitForDb() end

    local list = {}
    for id, p in pairs(Properties) do
        local isOwner = (p.owner == identifier)
        if isOwner or HasEntryPermission(p.permissions, identifier) then
            local imageUrl = (type(p.image) == 'string' and p.image ~= '') and p.image or nil
            table.insert(list, {
                id = id,
                label = p.label,
                isApartment = false,
                isOwner = isOwner,
                image = imageUrl,
            })
        end
    end
    return list
end

local function GetApartmentRoomLabelMap()
    local labels = {}
    local ok, roomRows = pcall(MySQL.query.await, 'SELECT id, room_name FROM apartment_rooms')
    if ok and roomRows then
        for _, r in ipairs(roomRows) do
            if r.id and type(r.room_name) == 'string' and r.room_name ~= '' then
                labels[tonumber(r.id) or r.id] = r.room_name
            end
        end
    end
    return labels
end

local function GetKeyholderApartments(identifier)
    if not Settings.Apartments or not Settings.Apartments.Enabled then
        return {}
    end

    local list = {}
    local seen = {}

    local ok, rows = pcall(MySQL.query.await, 'SELECT room_id, citizenid, permissions FROM apartments')
    if not ok or not rows then return list end

    local roomLabels = GetApartmentRoomLabelMap()

    for _, row in ipairs(rows) do
        local isOwner = (row.citizenid == identifier)
        local isHolder = isOwner
        if not isHolder and row.permissions then
            local perms = json.decode(row.permissions)
            if HasEntryPermission(perms, identifier) then
                isHolder = true
            end
        end

        if isHolder and not seen[row.room_id] then
            seen[row.room_id] = true
            local label = roomLabels[tonumber(row.room_id) or row.room_id] or ('Apartment Room #' .. row.room_id)
            table.insert(list, {
                id = row.room_id,
                label = label,
                isApartment = true,
                isOwner = isOwner,
                image = nil,
            })
        end
    end

    return list
end

local function GetKeyablePropertiesForTarget(target)
    if not IsPhysicalKeysEnabled() then
        return {}
    end

    local identifier = ResolveIdentifier(target)
    if not identifier then return {} end

    local list = GetOwnedAndKeyholderHouses(identifier)
    local apartments = GetKeyholderApartments(identifier)
    for _, a in ipairs(apartments) do
        table.insert(list, a)
    end

    return list
end

local function MatchPropertyId(metaVal, targetVal)
    if not metaVal or not targetVal then return false end
    if metaVal == targetVal then return true end
    if tonumber(metaVal) and tonumber(targetVal) and tonumber(metaVal) == tonumber(targetVal) then return true end
    if tostring(metaVal) == tostring(targetVal) then return true end
    return false
end

local function GetPhysicalKeyCount(propertyId, isApartment)
    local pk = Settings.Security.PhysicalKeys
    if not pk or not pk.Enabled then return 0 end

    local count = 0
    local onlineIdentifiers = {}

    local players = GetPlayers()
    for i = 1, #players do
        local pId = tonumber(players[i])
        if pId then
            local identifier = Bridge.Server.GetIdentifier(pId)
            if identifier then
                onlineIdentifiers[identifier] = true
            end

            local slots = Bridge.Server.Search(pId, 'slots', pk.Item)
            if slots then
                for _, slot in ipairs(slots) do
                    local meta = slot.metadata or {}
                    if MatchPropertyId(meta.propertyId, propertyId) and (meta.isApartment == true) == (isApartment == true) then
                        count = count + (slot.count or 1)
                    end
                end
            end
        end
    end

    local offlineCount = Bridge.Server.GetOfflineKeyCount(propertyId, isApartment, pk.Item, onlineIdentifiers)
    count = count + offlineCount

    return count
end

local function ResolvePropertyLabel(propertyId, isApartment)
    if isApartment then
        local roomLabels = GetApartmentRoomLabelMap()
        return roomLabels[tonumber(propertyId) or propertyId] or ('Apartment Room #' .. tostring(propertyId))
    end

    local prop = Properties[propertyId] or Properties[tonumber(propertyId)]
    return (prop and prop.label) or 'Property'
end

local function CutPhysicalKeyForPlayer(src, propertyId, isApartment, options)
    options = type(options) == 'table' and options or {}
    local requireBlankKey = options.requireBlankKey ~= false
    local shouldNotify = options.notify ~= false

    local function notify(msg, msgType)
        if shouldNotify and src then
            Bridge.Server.Notify(src, msg, msgType)
        end
    end

    local numSrc = tonumber(src)
    if not numSrc or GetPlayerPing(numSrc) <= 0 then
        return false, 'invalid_player'
    end

    if not IsPhysicalKeysEnabled() then
        notify('Physical keys are not enabled.', 'error')
        return false, 'physical_keys_disabled'
    end

    if propertyId == nil then
        notify('Invalid property.', 'error')
        return false, 'invalid_property'
    end

    local aptFlag = isApartment == true
    local targetPropId = aptFlag and (tonumber(propertyId) or propertyId) or (Properties[propertyId] and propertyId or tonumber(propertyId) or propertyId)

    if not aptFlag and not Properties[targetPropId] then
        notify('Property not found.', 'error')
        return false, 'property_not_found'
    end

    if not IsKeyholder(numSrc, targetPropId, aptFlag) then
        notify('You are not a keyholder for this property.', 'error')
        return false, 'not_keyholder'
    end

    local maxKeys = Settings.MaxKeys or 5
    local keyCount = GetPhysicalKeyCount(targetPropId, aptFlag)
    if keyCount >= maxKeys then
        notify('You have reached the maximum number of keys (' .. maxKeys .. ') for this property!', 'error')
        return false, 'max_keys_reached'
    end

    local blankKeyItem = (Settings.Locksmith and Settings.Locksmith.BlankKeyItem) or 'blank_house_key'
    if requireBlankKey then
        local blankCount = Bridge.Server.Search(numSrc, 'count', blankKeyItem)
        if not blankCount or blankCount < 1 then
            notify('You need a blank key to cut a new one.', 'error')
            return false, 'no_blank_key'
        end

        local removed = Bridge.Server.RemoveItem(numSrc, blankKeyItem, 1)
        if not removed then
            notify('Could not use the blank key.', 'error')
            return false, 'blank_key_remove_failed'
        end
    end

    local pk = Settings.Security.PhysicalKeys
    local label = ResolvePropertyLabel(targetPropId, aptFlag)

    local given = Bridge.Server.AddItem(numSrc, pk.Item, 1, {
        propertyId = targetPropId,
        isApartment = aptFlag,
        description = 'Key to: ' .. label
    })

    if not given then
        if requireBlankKey then
            Bridge.Server.AddItem(numSrc, blankKeyItem, 1)
        end
        notify('Could not cut the key (inventory full?).', 'error')
        return false, 'inventory_full'
    end

    notify('You cut a new key for ' .. label .. '.', 'success')
    return true, {
        propertyId = targetPropId,
        isApartment = aptFlag,
        label = label
    }
end

lib.callback.register('LNS_Housing:server:getMyKeyableProperties', function(source)
    debugPrint('info', 'LNS_Housing:server:getMyKeyableProperties called', {source = source})
    return GetKeyablePropertiesForTarget(source)
end)

lib.callback.register('LNS_Housing:server:cutPhysicalKey', function(source, propertyId, isApartment)
    debugPrint('info', 'LNS_Housing:server:cutPhysicalKey callback called', {source = source, propertyId = propertyId, isApartment = isApartment})
    return CutPhysicalKeyForPlayer(source, propertyId, isApartment, {
        requireBlankKey = true,
        notify = true
    })
end)

RegisterNetEvent('LNS_Housing:server:cutPhysicalKey', function(propertyId, isApartment)
    local src = source
    debugPrint('info', 'LNS_Housing:server:cutPhysicalKey received', {src = src, propertyId = propertyId, isApartment = isApartment})
    CutPhysicalKeyForPlayer(src, propertyId, isApartment, {
        requireBlankKey = true,
        notify = true
    })
end)

exports('GetKeyableProperties', function(target)
    return GetKeyablePropertiesForTarget(target)
end)

exports('CutPhysicalKey', function(targetSource, propertyId, isApartment, options)
    return CutPhysicalKeyForPlayer(targetSource, propertyId, isApartment, options)
end)

exports('GetPhysicalKeyCount', function(propertyId, isApartment)
    return GetPhysicalKeyCount(propertyId, isApartment == true), Settings.MaxKeys or 5
end)