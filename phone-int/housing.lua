-- ============================================================================
-- Housing API (Server-Side)
-- Supported systems: esx_property, rtx_housing, ps_housing, custom
-- Set Config.HousingSystem in config.lua
-- ============================================================================

local housingSystem = Config.HousingSystem or 'esx_property'

-- ============================================================================
-- ESX_PROPERTY
-- ============================================================================

local function ESX_GetPlayerProperties(source)
    local identifier = Bridge.Player.GetIdentifier(source)
    if not identifier then return {} end

    local success, allProperties = pcall(function()
        return exports['esx_property']:GetPlayerProperties(identifier)
    end)

    if not success or not allProperties then return {} end

    local result = {}
    for id, prop in pairs(allProperties) do
        table.insert(result, {
            id = id,
            name = prop.setName or prop.Name or ('Property ' .. id),
            locked = prop.Locked or false,
            garage = prop.garage and prop.garage.enabled or false,
            coords = prop.Entrance,
        })
    end
    return result
end

local function ESX_GetPropertyKeys(source, propertyId)
    local success, keys = pcall(function()
        return exports['esx_property']:GetPropertyKeys(propertyId)
    end)

    if not success or not keys then return {} end

    local result = {}
    for identifier, data in pairs(keys) do
        table.insert(result, {
            identifier = identifier,
            name = data.name or identifier,
        })
    end
    return result
end

local function ESX_ToggleLock(source, propertyId)
    -- esx_property toggleLock is handled client-side via ESX.TriggerServerCallback
    -- This server fallback returns nil (client handles it in client/housing.lua)
    return nil
end

local function ESX_GiveKey(source, propertyId, targetSource)
    local identifier = Bridge.Player.GetIdentifier(source)
    if not identifier then return false end

    local success, properties = pcall(function()
        return exports['esx_property']:GetProperties()
    end)

    if not success or not properties then return false end

    local prop = properties[propertyId]
    if not prop or prop.Owner ~= identifier then return false end

    local targetIdentifier = Bridge.Player.GetIdentifier(targetSource)
    local targetName = Bridge.Player.GetName(targetSource)
    if not targetIdentifier then return false end

    prop.Keys[targetIdentifier] = { name = targetName, identifier = targetIdentifier }
    return true
end

local function ESX_RemoveKey(source, propertyId, targetIdentifier)
    local identifier = Bridge.Player.GetIdentifier(source)
    if not identifier then return false end

    local success, properties = pcall(function()
        return exports['esx_property']:GetProperties()
    end)

    if not success or not properties then return false end

    local prop = properties[propertyId]
    if not prop or prop.Owner ~= identifier then return false end

    if prop.Keys[targetIdentifier] then
        prop.Keys[targetIdentifier] = nil
        return true
    end
    return false
end

-- ============================================================================
-- RTX_HOUSING
-- ============================================================================

local function RTX_GetPlayerProperties(source)
    local success, allProperties = pcall(function()
        return exports['rtx_housing']:GetPlayerOwnedProperties(source)
    end)

    if not success or not allProperties then return {} end

    local result = {}
    for _, prop in pairs(allProperties) do
        local propData = nil
        local pSuccess, pData = pcall(function()
            return exports['rtx_housing']:GetPropertyData(prop.id or prop.propertyId)
        end)
        if pSuccess and pData then
            propData = pData
        end

        table.insert(result, {
            id = prop.id or prop.propertyId,
            name = prop.label or prop.name or ('Property ' .. (prop.id or prop.propertyId or '?')),
            locked = propData and propData.locked or false,
            garage = propData and propData.garage or false,
            coords = propData and propData.coords or prop.coords or nil,
        })
    end
    return result
end

local function RTX_GetPropertyKeys(source, propertyId)
    local success, hasKeys = pcall(function()
        return exports['rtx_housing']:CheckPropertyKeys(source, propertyId)
    end)

    -- RTX housing uses a permission system, try GetPropertyPermissions
    local pSuccess, permissions = pcall(function()
        return exports['rtx_housing']:GetPropertyPermissions(source, propertyId)
    end)

    if not pSuccess or not permissions then return {} end

    -- Format permissions as key holders
    local result = {}
    if type(permissions) == 'table' then
        for identifier, data in pairs(permissions) do
            if type(data) == 'table' then
                table.insert(result, {
                    identifier = identifier,
                    name = data.name or identifier,
                })
            end
        end
    end
    return result
end

local function RTX_ToggleLock(source, propertyId)
    -- RTX housing may not expose a direct lock toggle
    -- Check if the player has permission first
    local success, hasPermission = pcall(function()
        return exports['rtx_housing']:HasPlayerAnyPropertyPermissions(source, propertyId)
    end)

    if not success then return nil end

    local propSuccess, propData = pcall(function()
        return exports['rtx_housing']:GetPropertyData(propertyId)
    end)

    if not propSuccess or not propData then return nil end

    -- Toggle the locked state
    local newLocked = not (propData.locked or false)
    -- RTX housing may handle this via events
    TriggerEvent('rtx_housing:toggleLock', propertyId, newLocked)
    return newLocked
end

local function RTX_GiveKey(source, propertyId, targetSource)
    local success, result = pcall(function()
        return exports['rtx_housing']:GivePropertySource(targetSource, propertyId)
    end)
    return success
end

local function RTX_RemoveKey(source, propertyId, targetIdentifier)
    -- RTX housing permission removal depends on implementation
    -- This may need to be adjusted based on your RTX housing version
    return false
end

-- ============================================================================
-- PS_HOUSING
-- ============================================================================

local function PS_GetPlayerProperties(source)
    local success, allProperties = pcall(function()
        return lib.callback.await("ps-housing:server:GetPlayerProperties", source)
    end)

    if not success or not allProperties then return {} end

    local result = {}
    for _, prop in pairs(allProperties) do
        local doorData = prop.door_data
        if type(doorData) == 'string' then
            doorData = json.decode(doorData)
        end

        table.insert(result, {
            id = prop.property_id,
            name = prop.houseName or prop.apartment or ('Property ' .. prop.property_id),
            locked = false,
            garage = prop.garageStatus and prop.garageStatus ~= '' or false,
            coords = doorData and { x = doorData.x, y = doorData.y, z = doorData.z } or nil,
        })
    end
    return result
end

local function PS_GetPropertyKeys(source, propertyId)
    -- has_access is a JSON array of citizenids
    local success, propData = pcall(function()
        local rows = MySQL.query.await('SELECT has_access FROM properties WHERE property_id = ?', { propertyId })
        return rows and rows[1] or nil
    end)

    if not success or not propData then return {} end

    local accessList = propData.has_access
    if type(accessList) == 'string' then
        accessList = json.decode(accessList)
    end
    if not accessList or type(accessList) ~= 'table' then return {} end

    local result = {}
    for _, citizenid in ipairs(accessList) do
        -- Try to get name from QBCore
        local name = citizenid
        local nameSuccess, playerName = pcall(function()
            local player = exports['qb-core']:GetCore().Functions.GetPlayerByCitizenId(citizenid)
            if player then
                return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
            end
            -- Offline lookup
            local rows = MySQL.query.await('SELECT JSON_EXTRACT(charinfo, "$.firstname") as firstname, JSON_EXTRACT(charinfo, "$.lastname") as lastname FROM players WHERE citizenid = ?', { citizenid })
            if rows and rows[1] then
                local fn = rows[1].firstname and rows[1].firstname:gsub('"', '') or ''
                local ln = rows[1].lastname and rows[1].lastname:gsub('"', '') or ''
                return fn .. ' ' .. ln
            end
            return citizenid
        end)
        if nameSuccess and playerName then name = playerName end

        table.insert(result, {
            identifier = citizenid,
            name = name,
        })
    end
    return result
end

local function PS_ToggleLock(source, propertyId)
    -- ps-housing doesn't expose a direct lock export
    -- Lock state is handled client-side via door_data
    return nil
end

local function PS_GiveKey(source, propertyId, targetSource)
    local targetCitizenId = nil
    local tSuccess, tId = pcall(function()
        local player = exports['qb-core']:GetCore().Functions.GetPlayer(targetSource)
        return player and player.PlayerData.citizenid or nil
    end)
    if tSuccess then targetCitizenId = tId end
    if not targetCitizenId then return false end

    -- Check if source is owner
    local ownerCheck = MySQL.query.await('SELECT owner_citizenid, has_access FROM properties WHERE property_id = ?', { propertyId })
    if not ownerCheck or not ownerCheck[1] then return false end

    local ownerCitizenId = nil
    local oSuccess, oId = pcall(function()
        local player = exports['qb-core']:GetCore().Functions.GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end)
    if oSuccess then ownerCitizenId = oId end
    if ownerCitizenId ~= ownerCheck[1].owner_citizenid then return false end

    -- Add to has_access
    local accessList = ownerCheck[1].has_access
    if type(accessList) == 'string' then
        accessList = json.decode(accessList)
    end
    if not accessList or type(accessList) ~= 'table' then accessList = {} end

    -- Check if already has access
    for _, cid in ipairs(accessList) do
        if cid == targetCitizenId then return true end
    end

    table.insert(accessList, targetCitizenId)
    MySQL.update.await('UPDATE properties SET has_access = ? WHERE property_id = ?', { json.encode(accessList), propertyId })
    return true
end

local function PS_RemoveKey(source, propertyId, targetIdentifier)
    -- Check if source is owner
    local ownerCheck = MySQL.query.await('SELECT owner_citizenid, has_access FROM properties WHERE property_id = ?', { propertyId })
    if not ownerCheck or not ownerCheck[1] then return false end

    local ownerCitizenId = nil
    local oSuccess, oId = pcall(function()
        local player = exports['qb-core']:GetCore().Functions.GetPlayer(source)
        return player and player.PlayerData.citizenid or nil
    end)
    if oSuccess then ownerCitizenId = oId end
    if ownerCitizenId ~= ownerCheck[1].owner_citizenid then return false end

    local accessList = ownerCheck[1].has_access
    if type(accessList) == 'string' then
        accessList = json.decode(accessList)
    end
    if not accessList or type(accessList) ~= 'table' then return false end

    local newList = {}
    local found = false
    for _, cid in ipairs(accessList) do
        if cid == targetIdentifier then
            found = true
        else
            table.insert(newList, cid)
        end
    end

    if not found then return false end

    MySQL.update.await('UPDATE properties SET has_access = ? WHERE property_id = ?', { json.encode(newList), propertyId })
    return true
end

-- ============================================================================
-- RX_HOUSING (RxHousing by rxscripts)
-- ============================================================================

local function RX_GetPlayerProperties(source)
    local identifier = Bridge.Player.GetIdentifier(source)
    if not identifier then return {} end

    local success, allProperties = pcall(function()
        return exports['RxHousing']:GetOwnedProperties(identifier)
    end)

    if not success or not allProperties then return {} end

    local result = {}
    for _, prop in pairs(allProperties) do
        local propId = prop.id or prop.property_id
        local coords = prop.coords or prop.entrance

        -- If coords is missing, try fetching full property data
        if not coords and propId then
            local pSuccess, fullProp = pcall(function()
                return exports['RxHousing']:GetProperty(propId)
            end)
            if pSuccess and fullProp then
                coords = fullProp.coords or fullProp.entrance
            end
        end

        table.insert(result, {
            id = propId,
            name = prop.label or prop.name or ('Property ' .. (propId or '?')),
            locked = prop.locked or false,
            garage = prop.garage or false,
            coords = coords,
        })
    end
    return result
end

local function RX_GetPropertyKeys(source, propertyId)
    local success, keyholders = pcall(function()
        return exports['RxHousing']:GetPropertyKeyholders(propertyId)
    end)

    if not success or not keyholders then return {} end

    local result = {}
    for _, holder in pairs(keyholders) do
        table.insert(result, {
            identifier = holder.identifier or holder.citizenid or holder.id,
            name = holder.name or holder.label or (holder.identifier or 'Unknown'),
        })
    end
    return result
end

local function RX_ToggleLock(source, propertyId)
    -- RxHousing does not expose a lock toggle export
    return nil
end

local function RX_GiveKey(source, propertyId, targetSource)
    local targetIdentifier = Bridge.Player.GetIdentifier(targetSource)
    if not targetIdentifier then return false end

    local success, result = pcall(function()
        return exports['RxHousing']:AddKeyholder(propertyId, targetIdentifier)
    end)

    return success and result
end

local function RX_RemoveKey(source, propertyId, targetIdentifier)
    local success, result = pcall(function()
        return exports['RxHousing']:RemoveKeyholder(propertyId, targetIdentifier)
    end)

    return success and result
end

-- ============================================================================
-- LNS_HOUSING
-- ============================================================================

local function LNS_GetNameFromIdentifier(identifier)
    local qbx = GetResourceState('qbx_core') == 'started' and exports.qbx_core
    local esx = GetResourceState('es_extended') == 'started' and exports['es_extended']:getSharedObject()

    if qbx then
        local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
        if player then
            return player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        end
    elseif esx then
        local player = esx.GetPlayerFromIdentifier(identifier)
        if player then
            return player.getName()
        end
    end

    local dbQuerySuccess, result = pcall(function()
        if qbx then
            local rows = MySQL.query.await('SELECT JSON_EXTRACT(charinfo, "$.firstname") as firstname, JSON_EXTRACT(charinfo, "$.lastname") as lastname FROM players WHERE citizenid = ?', { identifier })
            if rows and rows[1] then
                local fn = rows[1].firstname and rows[1].firstname:gsub('"', '') or ''
                local ln = rows[1].lastname and rows[1].lastname:gsub('"', '') or ''
                return fn .. ' ' .. ln
            end
        elseif esx then
            local rows = MySQL.query.await('SELECT firstname, lastname FROM users WHERE identifier = ?', { identifier })
            if rows and rows[1] then
                return (rows[1].firstname or '') .. ' ' .. (rows[1].lastname or '')
            end
        end
    end)
    if dbQuerySuccess and result then return result end
    
    return identifier
end

local function LNS_GetEntranceCoords(p)
    if not p then return nil end
    if p.metadata and p.metadata.entrance then
        local ent = p.metadata.entrance
        return { x = ent.x, y = ent.y, z = ent.z }
    end
    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end
    if doorId and doorId ~= 0 then
        local success, door = pcall(function()
            return exports.ox_doorlock:getDoor(doorId)
        end)
        if success and door and door.coords then
            return { x = door.coords.x, y = door.coords.y, z = door.coords.z }
        end
    end
    if p.zone_data and p.zone_data.points and #p.zone_data.points > 0 then
        local pt = p.zone_data.points[1]
        return { x = pt.x, y = pt.y, z = pt.z }
    end
    return nil
end

local function LNS_GetPlayerProperties(source)
    local identifier = Bridge.Player.GetIdentifier(source)
    if not identifier then return {} end

    local success, allProperties = pcall(function()
        return exports['LNS_Housing']:GetProperties()
    end)

    if not success or not allProperties then return {} end

    local result = {}
    for id, prop in pairs(allProperties) do
        local hasAccess = false
        if prop.owner == identifier then
            hasAccess = true
        elseif prop.permissions and prop.permissions.entry then
            for _, cid in ipairs(prop.permissions.entry) do
                if cid == identifier then
                    hasAccess = true
                    break
                end
            end
        end

        if hasAccess then
            local coords = LNS_GetEntranceCoords(prop)
            table.insert(result, {
                id = id,
                name = prop.label or prop.name or ('Property ' .. id),
                locked = prop.metadata and prop.metadata.locked or false,
                garage = (prop.metadata and prop.metadata.garage_data and true) or false,
                coords = coords,
            })
        end
    end
    return result
end

local function LNS_GetPropertyKeys(source, propertyId)
    local success, prop = pcall(function()
        return exports['LNS_Housing']:GetProperty(propertyId)
    end)

    if not success or not prop or not prop.permissions then return {} end

    local result = {}
    local added = {}
    for category, list in pairs(prop.permissions) do
        if type(list) == 'table' then
            for _, cid in ipairs(list) do
                if not added[cid] then
                    added[cid] = true
                    table.insert(result, {
                        identifier = cid,
                        name = LNS_GetNameFromIdentifier(cid),
                    })
                end
            end
        end
    end
    return result
end

local function LNS_ToggleLock(source, propertyId)
    local p = exports['LNS_Housing']:GetProperty(propertyId)
    if not p then return nil end

    local identifier = Bridge.Player.GetIdentifier(source)
    if not identifier then return nil end

    -- Validate access to lock/unlock
    local hasAccess = false
    if p.owner == identifier then
        hasAccess = true
    elseif p.permissions then
        for _, category in ipairs({'entry', 'manage'}) do
            if p.permissions[category] then
                for _, cid in ipairs(p.permissions[category]) do
                    if cid == identifier then
                        hasAccess = true
                        break
                    end
                end
            end
            if hasAccess then break end
        end
    end

    if not hasAccess then return nil end

    local success, result = pcall(function()
        return exports['LNS_Housing']:ToggleLock(propertyId)
    end)
    return success and result
end

local function LNS_GiveKey(source, propertyId, targetSource)
    local targetIdentifier = Bridge.Player.GetIdentifier(targetSource)
    if not targetIdentifier then return false end

    local p = exports['LNS_Housing']:GetProperty(propertyId)
    local identifier = Bridge.Player.GetIdentifier(source)
    if not p or p.owner ~= identifier then return false end

    local success, result = pcall(function()
        return exports['LNS_Housing']:GiveKey(propertyId, targetIdentifier)
    end)
    return success and result
end

local function LNS_RemoveKey(source, propertyId, targetIdentifier)
    local p = exports['LNS_Housing']:GetProperty(propertyId)
    local identifier = Bridge.Player.GetIdentifier(source)
    if not p or p.owner ~= identifier then return false end

    local success, result = pcall(function()
        return exports['LNS_Housing']:RemoveKey(propertyId, targetIdentifier)
    end)
    return success and result
end

-- ============================================================================
-- CUSTOM (override these functions for your housing system)
-- ============================================================================

local function Custom_GetPlayerProperties(source)
    -- Return: Array of { id, name, locked, garage, coords = {x,y,z} }
    return {}
end

local function Custom_GetPropertyKeys(source, propertyId)
    -- Return: Array of { identifier, name }
    return {}
end

local function Custom_ToggleLock(source, propertyId)
    -- Return: boolean (new lock state) or nil on error
    return nil
end

local function Custom_GiveKey(source, propertyId, targetSource)
    -- Return: boolean
    return false
end

local function Custom_RemoveKey(source, propertyId, targetIdentifier)
    -- Return: boolean
    return false
end

-- ============================================================================
-- ROUTING (selects the correct function based on Config.HousingSystem)
-- ============================================================================

local systems = {
    LNS_Housing = {
        getProperties = LNS_GetPlayerProperties,
        getKeys = LNS_GetPropertyKeys,
        toggleLock = LNS_ToggleLock,
        giveKey = LNS_GiveKey,
        removeKey = LNS_RemoveKey,
    },
    esx_property = {
        getProperties = ESX_GetPlayerProperties,
        getKeys = ESX_GetPropertyKeys,
        toggleLock = ESX_ToggleLock,
        giveKey = ESX_GiveKey,
        removeKey = ESX_RemoveKey,
    },
    rtx_housing = {
        getProperties = RTX_GetPlayerProperties,
        getKeys = RTX_GetPropertyKeys,
        toggleLock = RTX_ToggleLock,
        giveKey = RTX_GiveKey,
        removeKey = RTX_RemoveKey,
    },
    ps_housing = {
        getProperties = PS_GetPlayerProperties,
        getKeys = PS_GetPropertyKeys,
        toggleLock = PS_ToggleLock,
        giveKey = PS_GiveKey,
        removeKey = PS_RemoveKey,
    },
    rx_housing = {
        getProperties = RX_GetPlayerProperties,
        getKeys = RX_GetPropertyKeys,
        toggleLock = RX_ToggleLock,
        giveKey = RX_GiveKey,
        removeKey = RX_RemoveKey,
    },
    custom = {
        getProperties = Custom_GetPlayerProperties,
        getKeys = Custom_GetPropertyKeys,
        toggleLock = Custom_ToggleLock,
        giveKey = Custom_GiveKey,
        removeKey = Custom_RemoveKey,
    },
}

local function getSystem()
    return systems[housingSystem] or systems['custom']
end

-- ============================================================================
-- CALLBACKS (nicht veraendern - werden vom Phone-System benutzt)
-- ============================================================================

Bridge.RegisterCallback('roadphone:housing:getProperties', function(source, cb)
    cb(getSystem().getProperties(source))
end)

Bridge.RegisterCallback('roadphone:housing:getKeys', function(source, cb, propertyId)
    cb(getSystem().getKeys(source, propertyId))
end)

Bridge.RegisterCallback('roadphone:housing:toggleLock', function(source, cb, propertyId)
    cb(getSystem().toggleLock(source, propertyId))
end)

Bridge.RegisterCallback('roadphone:housing:giveKey', function(source, cb, propertyId, targetSource)
    cb(getSystem().giveKey(source, propertyId, targetSource))
end)

Bridge.RegisterCallback('roadphone:housing:removeKey', function(source, cb, propertyId, targetIdentifier)
    cb(getSystem().removeKey(source, propertyId, targetIdentifier))
end)
