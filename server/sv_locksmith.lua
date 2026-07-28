local Settings = lib.load('shared.settings')

if not Settings.Security.PhysicalKeys.Enabled or not Settings.Locksmith or not Settings.Locksmith.Enabled then
    return
end

local function GetOwnedAndKeyholderHouses(identifier)
    local list = {}
    for id, p in pairs(Properties) do
        if p.owner == identifier then
            table.insert(list, { id = id, label = p.label, isApartment = false })
        elseif p.permissions and p.permissions.entry then
            for _, cid in ipairs(p.permissions.entry) do
                if cid == identifier then
                    table.insert(list, { id = id, label = p.label, isApartment = false })
                    break
                end
            end
        end
    end
    return list
end

local function GetKeyholderApartments(identifier)
    local list = {}
    local seen = {}

    local rows = MySQL.query.await('SELECT room_id, citizenid, permissions FROM apartments')
    if not rows then return list end

    for _, row in ipairs(rows) do
        local isHolder = false
        if row.citizenid == identifier then
            isHolder = true
        else
            local perms = row.permissions and json.decode(row.permissions)
            if perms and perms.entry then
                for _, cid in ipairs(perms.entry) do
                    if cid == identifier then
                        isHolder = true
                        break
                    end
                end
            end
        end

        if isHolder and not seen[row.room_id] then
            seen[row.room_id] = true
            table.insert(list, { id = row.room_id, label = 'Apartment Room #' .. row.room_id, isApartment = true })
        end
    end

    return list
end

lib.callback.register('LNS_Housing:server:getMyKeyableProperties', function(source)
    local identifier = Bridge.Server.GetIdentifier(source)
    if not identifier then return {} end

    local list = GetOwnedAndKeyholderHouses(identifier)
    local apartments = GetKeyholderApartments(identifier)
    for _, a in ipairs(apartments) do
        table.insert(list, a)
    end

    return list
end)

RegisterNetEvent('LNS_Housing:server:cutPhysicalKey', function(propertyId, isApartment, targetSource)
    local src = source
    local pk = Settings.Security.PhysicalKeys

    if not pk or not pk.Enabled then
        Bridge.Server.Notify(src, 'Physical keys are not enabled.', 'error')
        return
    end

    if not IsKeyholder(src, propertyId, isApartment) then
        Bridge.Server.Notify(src, 'You are not a keyholder for this property.', 'error')
        return
    end

    local recipient = targetSource or src

    if recipient ~= src and not IsKeyholder(recipient, propertyId, isApartment) then
        Bridge.Server.Notify(src, 'That player is not a keyholder for this property.', 'error')
        return
    end

    local blankCount = exports.ox_inventory:Search(src, 'count', Settings.Locksmith.BlankKeyItem)
    if not blankCount or blankCount < 1 then
        Bridge.Server.Notify(src, 'You need a blank key to cut a new one.', 'error')
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, Settings.Locksmith.BlankKeyItem, 1)
    if not removed then
        Bridge.Server.Notify(src, 'Could not use the blank key.', 'error')
        return
    end

    local label = isApartment and ('Apartment Room #' .. propertyId) or (Properties[propertyId] and Properties[propertyId].label or 'Property')

    local given = exports.ox_inventory:AddItem(recipient, pk.Item, 1, {
        propertyId = propertyId,
        isApartment = isApartment,
        description = 'Key to: ' .. label
    })

    if not given then
        exports.ox_inventory:AddItem(src, Settings.Locksmith.BlankKeyItem, 1)
        Bridge.Server.Notify(src, 'Could not cut the key (inventory full?).', 'error')
        return
    end

    if recipient == src then
        Bridge.Server.Notify(src, 'You cut a new key for ' .. label .. '.', 'success')
    else
        Bridge.Server.Notify(src, 'You cut a key for ' .. label .. ' and gave it to the nearby player.', 'success')
        Bridge.Server.Notify(recipient, 'You were given a key to ' .. label .. '.', 'success')
    end
end)