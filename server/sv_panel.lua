local Settings = lib.load('shared.settings')

RegisterNetEvent('LNS_Housing:server:updatePermissions', function(propertyId, permissions)
    local src = source
    debugPrint('info', 'LNS_Housing:server:updatePermissions received', {src = src, propertyId = propertyId, permissions = permissions})
    local p = Properties[propertyId]
    local ownerCid = Bridge.Server.GetIdentifier(src)
    if not p or p.owner ~= ownerCid then return end

    if type(permissions) == 'table' then
        for category, cids in pairs(permissions) do
            if type(cids) == 'table' then
                local filtered = {}
                for _, cid in ipairs(cids) do
                    if cid ~= ownerCid then
                        table.insert(filtered, cid)
                    end
                end
                permissions[category] = filtered
            end
        end
    end

    p.permissions = permissions
    SaveProperty(propertyId)
    SyncPropertyDoor(propertyId)
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)

    if GetResourceState('sd-phone') == 'started' then
        TriggerClientEvent('sd-phone:client:homes:refresh', -1)
    end
end)

RegisterNetEvent('LNS_Housing:server:updateWallColor', function(propertyId, color)
    local src = source
    debugPrint('info', 'LNS_Housing:server:updateWallColor received', {src = src, propertyId = propertyId, color = color})
    local p = Properties[propertyId]
    if not p or p.owner ~= Bridge.Server.GetIdentifier(src) then return end

    p.metadata.wall_color = color
    SaveProperty(propertyId)
end)

lib.callback.register('LNS_Housing:server:resolvePlayerNames', function(source, playerIds)
    debugPrint('info', 'LNS_Housing:server:resolvePlayerNames called', {source = source, playerIds = playerIds})
    local results = {}
    for _, sid in ipairs(playerIds) do
        local name = Bridge.Server.GetPlayerName(sid)
        local cid = Bridge.Server.GetIdentifier(sid)
        table.insert(results, { id = sid, name = name, citizenid = cid })
    end
    return results
end)

lib.callback.register('LNS_Housing:server:resolveIdentifiers', function(source, citizenids)
    debugPrint('info', 'LNS_Housing:server:resolveIdentifiers called', {source = source, citizenids = citizenids})
    if type(citizenids) ~= 'table' then return {} end

    local onlineMap = {}
    for _, srcStr in ipairs(GetPlayers()) do
        local sid = tonumber(srcStr)
        if sid then
            local cid = Bridge.Server.GetIdentifier(sid)
            if cid then onlineMap[cid] = sid end
        end
    end

    local results = {}
    for _, cid in ipairs(citizenids) do
        cid = tostring(cid)
        local name = nil

        local sid = onlineMap[cid]
        if sid then
            name = Bridge.Server.GetPlayerName(sid)
        end

        if not name or name == 'Unknown' then
            if Bridge.Framework == 'esx' then
                local ok, rows = pcall(MySQL.query.await, 'SELECT firstname, lastname FROM users WHERE identifier = ? LIMIT 1', { cid })
                if ok and rows and rows[1] then
                    local first = rows[1].firstname or ''
                    local last  = rows[1].lastname or ''
                    if first ~= '' or last ~= '' then name = first .. ' ' .. last end
                end
            else
                local ok, rows = pcall(MySQL.query.await, 'SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { cid })
                if ok and rows and rows[1] then
                    local ci = rows[1].charinfo
                    if type(ci) == 'string' then
                        local decoded = json.decode(ci)
                        if decoded then
                            local first = decoded.firstname or ''
                            local last  = decoded.lastname or ''
                            if first ~= '' or last ~= '' then name = first .. ' ' .. last end
                        end
                    end
                end
            end
        end

        table.insert(results, { citizenid = cid, name = name or cid })
    end
    return results
end)

lib.callback.register('LNS_Housing:server:resolvePlayerByServerId', function(source, targetId)
    debugPrint('info', 'LNS_Housing:server:resolvePlayerByServerId called', {source = source, targetId = targetId})
    local sid = tonumber(targetId)
    if not sid then
        return { success = false, message = "Invalid Server ID." }
    end

    if sid == source then
        return { success = false, message = "You cannot add yourself as a resident." }
    end

    local ped = GetPlayerPed(sid)
    if not ped or ped == 0 then
        return { success = false, message = "Player is offline or server ID is invalid." }
    end

    local cid = Bridge.Server.GetIdentifier(sid)
    if not cid then
        return { success = false, message = "Could not resolve player identifier." }
    end

    local sourceCid = Bridge.Server.GetIdentifier(source)
    if cid == sourceCid then
        return { success = false, message = "You cannot add yourself as a resident." }
    end

    local name = Bridge.Server.GetPlayerName(sid) or cid
    return { success = true, citizenid = cid, name = name, serverId = sid }
end)