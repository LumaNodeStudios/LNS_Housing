local function Log(msg, level)
    level = level or 'info'
    local prefix = '^5[LNS_Housing Migration]^7'
    if level == 'warn' then
        print(prefix .. ' ^3[WARNING]^7 ' .. msg)
    elseif level == 'error' then
        print(prefix .. ' ^1[ERROR]^7 ' .. msg)
    elseif level == 'success' then
        print(prefix .. ' ^2[SUCCESS]^7 ' .. msg)
    else
        print(prefix .. ' ' .. msg)
    end
end

local function ParseJson(val, fallback)
    if not val then return fallback end
    if type(val) == 'table' then return val end
    local ok, res = pcall(json.decode, val)
    if ok and res ~= nil then return res end
    return fallback
end

function RunNoLagMigration(isDryRun)
    Log(('Starting NoLag Properties migration (%s mode)...'):format(isDryRun and '^3DRY-RUN^7' or '^1LIVE EXECUTION^7'))

    local check = MySQL.query.await([[
        SELECT TABLE_NAME 
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'properties';
    ]])

    if not check or #check == 0 then
        Log('Table "properties" does not exist in this database. Migration aborted.', 'error')
        return false, 'Table "properties" does not exist'
    end

    local noLagProps = MySQL.query.await('SELECT * FROM properties')
    if not noLagProps or #noLagProps == 0 then
        Log('Table "properties" is empty. Nothing to migrate.', 'warn')
        return false, 'Table "properties" is empty'
    end

    local existingLns = MySQL.query.await('SELECT id FROM housing_properties')
    local existingIds = {}
    if existingLns then
        for _, row in ipairs(existingLns) do
            existingIds[tonumber(row.id)] = true
        end
    end

    local keyholders = {}
    pcall(function()
        local rows = MySQL.query.await([[
            SELECT * FROM properties_owners;
        ]])
        if rows then
            for _, r in ipairs(rows) do
                local propId = tonumber(r.property_id or r.propertyId or r.house_id or r.id)
                local cid = r.citizenid or r.identifier or r.owner
                if propId and cid then
                    keyholders[propId] = keyholders[propId] or {}
                    table.insert(keyholders[propId], cid)
                end
            end
        end
    end)

    pcall(function()
        local rows = MySQL.query.await([[
            SELECT * FROM property_keys;
        ]])
        if rows then
            for _, r in ipairs(rows) do
                local propId = tonumber(r.property_id or r.house_id or r.id)
                local cid = r.citizenid or r.identifier
                if propId and cid then
                    keyholders[propId] = keyholders[propId] or {}
                    table.insert(keyholders[propId], cid)
                end
            end
        end
    end)

    local collisions = 0
    local mloCount = 0
    local shellCount = 0
    local ownedCount = 0
    local withDoors = 0
    local withFurniture = 0

    for _, p in ipairs(noLagProps) do
        local propId = tonumber(p.id)
        if existingIds[propId] then
            collisions = collisions + 1
        end
        if p.owner and p.owner ~= '' then
            ownedCount = ownedCount + 1
        end

        local isMlo = (p.type and string.upper(tostring(p.type)) == 'MLO') or false
        if isMlo then mloCount = mloCount + 1 else shellCount = shellCount + 1 end

        local rawDoors = ParseJson(p.doors, nil)
        if rawDoors and ((type(rawDoors) == 'table' and #rawDoors > 0) or tonumber(rawDoors)) then
            withDoors = withDoors + 1
        end

        local rawFurn = ParseJson(p.furniture, nil)
        if rawFurn and type(rawFurn) == 'table' and #rawFurn > 0 then
            withFurniture = withFurniture + 1
        end
    end

    Log(('Found %s properties in NoLag database:'):format(#noLagProps))
    print(('  - ^2Owned:^7 %s | ^3Unowned:^7 %s'):format(ownedCount, #noLagProps - ownedCount))
    print(('  - ^5MLOs:^7 %s | ^5Shells/Other:^7 %s'):format(mloCount, shellCount))
    print(('  - ^6With Doorlocks:^7 %s | ^6With Furniture:^7 %s'):format(withDoors, withFurniture))
    print(('  - ^1Existing LNS ID Overlaps:^7 %s (Will update in-place without data loss)'):format(collisions))

    if isDryRun then
        Log('Dry-run completed successfully! No changes were made to the database.', 'success')
        Log('To execute live migration, run: ^2migratenolag execute^7 in server console.', 'warn')
        return true, {
            total = #noLagProps,
            owned = ownedCount,
            mlo = mloCount,
            shells = shellCount,
            collisions = collisions
        }
    end

    local importedCount = 0
    local stashesMigrated = 0

    for _, p in ipairs(noLagProps) do
        local propId = tonumber(p.id)
        local rawMeta = ParseJson(p.metadata, {})
        local rawFurn = ParseJson(p.furniture, {})
        local rawDoors = ParseJson(p.doors, {})
        local rawStorages = ParseJson(p.storages, {})

        local enterCoords = rawMeta.enterData or rawMeta.entry or (rawMeta.yardZone and rawMeta.yardZone.center) or rawMeta.coords
        local spawnData = nil
        if enterCoords then
            spawnData = {
                x = tonumber(enterCoords.x) or 0.0,
                y = tonumber(enterCoords.y) or 0.0,
                z = tonumber(enterCoords.z) or 0.0,
                h = tonumber(enterCoords.w or enterCoords.h or enterCoords.heading) or 0.0
            }
        end

        local zoneData = { points = {}, thickness = 10.0 }
        if rawMeta.yardZone and rawMeta.yardZone.points and #rawMeta.yardZone.points > 0 then
            zoneData.points = rawMeta.yardZone.points
            zoneData.thickness = tonumber(rawMeta.yardZone.thickness) or 10.0
        elseif rawMeta.area and type(rawMeta.area) == 'table' and #rawMeta.area > 0 then
            zoneData.points = rawMeta.area
        end

        local doorList = {}
        if type(rawDoors) == 'table' then
            for _, d in ipairs(rawDoors) do
                local dId = type(d) == 'table' and (d.id or d.doorId) or tonumber(d)
                if dId then table.insert(doorList, dId) end
            end
        elseif tonumber(rawDoors) then
            table.insert(doorList, tonumber(rawDoors))
        end

        local extraKeys = keyholders[propId] or {}
        local entryList = {}
        local storageList = {}
        local wardrobeList = {}
        for _, kCid in ipairs(extraKeys) do
            table.insert(entryList, kCid)
            table.insert(storageList, kCid)
            table.insert(wardrobeList, kCid)
        end

        local permissions = {
            entry = entryList,
            storage = storageList,
            wardrobe = wardrobeList,
            manage = {}
        }

        local garageData = nil
        if rawMeta.garage then
            garageData = {
                x = tonumber(rawMeta.garage.x) or 0.0,
                y = tonumber(rawMeta.garage.y) or 0.0,
                z = tonumber(rawMeta.garage.z) or 0.0,
                h = tonumber(rawMeta.garage.h or rawMeta.garage.w or rawMeta.garage.heading) or 0.0,
                spawn = rawMeta.garage.spawn or {
                    x = tonumber(rawMeta.garage.x) or 0.0,
                    y = tonumber(rawMeta.garage.y) or 0.0,
                    z = tonumber(rawMeta.garage.z) or 0.0,
                    h = tonumber(rawMeta.garage.h or 0.0)
                }
            }
        end

        local isMlo = (p.type and string.upper(tostring(p.type)) == 'MLO') or false
        local shellName = isMlo and 'mlo' or (rawMeta.interior or rawMeta.shell or 'Standard Motel')

        local lnsMetadata = {
            power = 0,
            water = 0,
            wall_color = 0,
            allow_wall_colors = false,
            security_level = 0,
            spawn = spawnData,
            shell = shellName,
            mlo = isMlo,
            entrance = spawnData,
            locked = (p.locked == 1 or p.locked == true or p.locked == '1'),
            garage_data = garageData,
            size = tonumber(rawMeta.size) or 1200,
            region = rawMeta.region or 'Unknown',
            max_power = (Settings and Settings.Electricity and Settings.Electricity.DefaultMaxPower) or 5.0,
            power_level = 1,
            breaker_tripped = false
        }

        local saleType = (p.payment and string.lower(tostring(p.payment)) == 'rent') and 'rent' or 'direct'

        MySQL.query.await([[
            INSERT INTO housing_properties 
                (id, label, price, owner, doors, permissions, metadata, furniture, sale_type, zone_data, yard_zone_data, garage)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                label = VALUES(label),
                price = VALUES(price),
                owner = VALUES(owner),
                doors = VALUES(doors),
                permissions = VALUES(permissions),
                metadata = VALUES(metadata),
                furniture = VALUES(furniture),
                sale_type = VALUES(sale_type),
                zone_data = VALUES(zone_data),
                yard_zone_data = VALUES(yard_zone_data),
                garage = VALUES(garage);
        ]], {
            propId,
            p.label or p.name or ('Property #' .. propId),
            tonumber(p.price) or 0,
            (p.owner and p.owner ~= '') and p.owner or nil,
            json.encode(doorList),
            json.encode(permissions),
            json.encode(lnsMetadata),
            json.encode(rawFurn),
            saleType,
            json.encode(zoneData),
            json.encode(zoneData),
            garageData and 2 or 0
        })

        if type(rawStorages) == 'table' and #rawStorages > 0 then
            for idx, stash in ipairs(rawStorages) do
                local stashId = string.format('housing_%s_%s', propId, idx)
                MySQL.query.await([[
                    INSERT INTO housing_stashes (id, property_id, data)
                    VALUES (?, ?, ?)
                    ON DUPLICATE KEY UPDATE property_id = VALUES(property_id), data = VALUES(data);
                ]], { stashId, propId, json.encode(stash) })
                stashesMigrated = stashesMigrated + 1
            end
        end

        pcall(function()
            MySQL.query.await([[
                UPDATE ox_inventory 
                SET name = REPLACE(name, ?, ?) 
                WHERE name LIKE ?;
            ]], {
                ('property_' .. propId),
                ('housing_' .. propId),
                ('property_' .. propId .. '%')
            })
        end)

        pcall(function()
            MySQL.query.await([[
                UPDATE stashitems 
                SET stash = REPLACE(stash, ?, ?) 
                WHERE stash LIKE ?;
            ]], {
                ('property_' .. propId),
                ('housing_' .. propId),
                ('property_' .. propId .. '%')
            })
        end)

        importedCount = importedCount + 1
    end

    Log(('Successfully migrated %s / %s properties into LNS_Housing!'):format(importedCount, #noLagProps), 'success')
    if stashesMigrated > 0 then
        Log(('Registered %s dedicated storage records.'):format(stashesMigrated), 'info')
    end

    if LoadProperties then
        pcall(LoadProperties)
        for id, _ in pairs(Properties) do
            if EnrichPropertyDoorlockData then
                pcall(EnrichPropertyDoorlockData, Properties[id])
            end
            if SyncPropertyDoor then
                pcall(SyncPropertyDoor, id)
            end
        end
        TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
        Log('Live properties reloaded and synchronized with all connected players.', 'success')
    end

    return true, importedCount
end

exports('MigrateNoLag', function(dryRun)
    return RunNoLagMigration(dryRun)
end)

RegisterCommand('migratenolag', function(source, args)
    if source ~= 0 then
        Bridge.Server.Notify(source, 'This command can only be executed via the server console.', 'error')
        return
    end

    local mode = args[1] and string.lower(args[1]) or 'dryrun'
    if mode == 'execute' or mode == 'confirm' then
        RunNoLagMigration(false)
    else
        RunNoLagMigration(true)
    end
end, true)