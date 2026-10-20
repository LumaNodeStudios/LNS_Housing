local Furniture = lib.load('shared.furniture') or {}
local Settings = lib.load('shared.settings') or {}

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

local function TableExists(tableName)
    local check = MySQL.query.await([[
        SELECT TABLE_NAME 
        FROM information_schema.TABLES 
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?;
    ]], { tableName })
    return check and #check > 0
end

local function GetFurnitureCategory(model)
    local hash = tonumber(model) or (type(model) == 'string' and joaat(model))
    for _, cat in ipairs(Furniture) do
        for _, item in ipairs(cat.items or {}) do
            local itemHash = tonumber(item.model) or (type(item.model) == 'string' and joaat(item.model))
            if item.model == model or (hash and itemHash and itemHash == hash) then
                return cat.id or 'furniture'
            end
        end
    end
    return 'furniture'
end

local function ResolveShellName(rawShell, isMlo)
    if isMlo then return 'mlo' end
    if not rawShell or rawShell == '' then return 'Standard Motel' end

    if Settings.Shells and Settings.Shells[rawShell] then
        return rawShell
    end
    if Settings.IPLs and Settings.IPLs[rawShell] then
        return rawShell
    end

    local lower = string.lower(rawShell)
    if Settings.Shells then
        for shellKey, _ in pairs(Settings.Shells) do
            if string.lower(shellKey) == lower then
                return shellKey
            end
        end
    end
    if Settings.IPLs then
        for iplKey, _ in pairs(Settings.IPLs) do
            if string.lower(iplKey) == lower then
                return iplKey
            end
        end
    end

    return rawShell
end

function RunNoLagMigration(isDryRun)
    Log(('Starting NoLag Properties migration (%s mode)...'):format(isDryRun and '^3DRY-RUN^7' or '^1LIVE EXECUTION^7'))

    if not TableExists('properties') then
        Log('Table "properties" does not exist in this database. Migration aborted.', 'error')
        return false, 'Table "properties" does not exist'
    end

    local noLagProps = MySQL.query.await('SELECT * FROM properties')
    if not noLagProps or #noLagProps == 0 then
        Log('Table "properties" is empty. Nothing to migrate.', 'warn')
        return false, 'Table "properties" is empty'
    end

    local hasOwnersTable = TableExists('properties_owners')
    local hasPricesTable = TableExists('properties_prices')
    local hasRentPricesTable = TableExists('properties_rentprices')
    local hasRentersTable = TableExists('properties_renters')
    local hasDoorsTable = TableExists('properties_doors')
    local hasFurnitureTable = TableExists('properties_furniture')
    local hasPropertyKeysTable = TableExists('property_keys')

    local ownersById = {}
    local ownersByProp = {}
    if hasOwnersTable then
        local rows = MySQL.query.await('SELECT * FROM properties_owners ORDER BY id ASC')
        if rows then
            for _, r in ipairs(rows) do
                ownersById[tonumber(r.id)] = r
                local propId = tonumber(r.property_id or r.propertyId)
                if propId then
                    ownersByProp[propId] = ownersByProp[propId] or {}
                    table.insert(ownersByProp[propId], r)
                end
            end
        end
    end

    local pricesById = {}
    local pricesByProp = {}
    if hasPricesTable then
        local rows = MySQL.query.await('SELECT * FROM properties_prices ORDER BY id ASC')
        if rows then
            for _, r in ipairs(rows) do
                pricesById[tonumber(r.id)] = tonumber(r.price) or 0
                local propId = tonumber(r.property_id or r.propertyId)
                if propId then
                    pricesByProp[propId] = tonumber(r.price) or 0
                end
            end
        end
    end

    local rentPricesById = {}
    local rentPricesByProp = {}
    if hasRentPricesTable then
        local rows = MySQL.query.await('SELECT * FROM properties_rentprices ORDER BY id ASC')
        if rows then
            for _, r in ipairs(rows) do
                rentPricesById[tonumber(r.id)] = tonumber(r.price) or 0
                local propId = tonumber(r.property_id or r.propertyId)
                if propId then
                    rentPricesByProp[propId] = tonumber(r.price) or 0
                end
            end
        end
    end

    local rentersById = {}
    local rentersByProp = {}
    if hasRentersTable then
        local rows = MySQL.query.await('SELECT * FROM properties_renters ORDER BY id ASC')
        if rows then
            for _, r in ipairs(rows) do
                rentersById[tonumber(r.id)] = r
                local propId = tonumber(r.property_id or r.propertyId)
                if propId then
                    rentersByProp[propId] = rentersByProp[propId] or {}
                    table.insert(rentersByProp[propId], r)
                end
            end
        end
    end

    local doorsByProp = {}
    if hasDoorsTable then
        local rows = MySQL.query.await('SELECT * FROM properties_doors ORDER BY id ASC')
        if rows then
            for _, r in ipairs(rows) do
                local propId = tonumber(r.property_id or r.propertyId)
                if propId then
                    doorsByProp[propId] = doorsByProp[propId] or {}
                    table.insert(doorsByProp[propId], r)
                end
            end
        end
    end

    local furnitureByProp = {}
    if hasFurnitureTable then
        local rows = MySQL.query.await('SELECT * FROM properties_furniture ORDER BY id ASC')
        if rows then
            for _, r in ipairs(rows) do
                local propId = tonumber(r.propertyId or r.property_id)
                if propId then
                    furnitureByProp[propId] = furnitureByProp[propId] or {}
                    table.insert(furnitureByProp[propId], r)
                end
            end
        end
    end

    local extraKeysByProp = {}
    if hasPropertyKeysTable then
        local rows = MySQL.query.await('SELECT * FROM property_keys')
        if rows then
            for _, r in ipairs(rows) do
                local propId = tonumber(r.property_id or r.house_id or r.id)
                local cid = r.citizenid or r.identifier
                if propId and cid and cid ~= 'realestate' then
                    extraKeysByProp[propId] = extraKeysByProp[propId] or {}
                    table.insert(extraKeysByProp[propId], cid)
                end
            end
        end
    end

    local existingLns = MySQL.query.await('SELECT id FROM housing_properties')
    local existingIds = {}
    if existingLns then
        for _, row in ipairs(existingLns) do
            existingIds[tonumber(row.id)] = true
        end
    end

    local shellSpawningZ = (Settings and Settings.ShellSpawningZ) or -100.0
    local collisions = 0
    local mloCount = 0
    local shellCount = 0
    local ownedCount = 0
    local withDoors = 0
    local withFurniture = 0
    local withGarage = 0

    for _, p in ipairs(noLagProps) do
        local propId = tonumber(p.id)
        if existingIds[propId] then
            collisions = collisions + 1
        end

        local isMlo = (p.type and string.upper(tostring(p.type)) == 'MLO') or false
        if isMlo then mloCount = mloCount + 1 else shellCount = shellCount + 1 end

        local ownerCid = nil
        if p.ownerid and ownersById[tonumber(p.ownerid)] then
            local oRow = ownersById[tonumber(p.ownerid)]
            if oRow.type == 'user' and oRow.identifier and oRow.identifier ~= '' and oRow.identifier ~= 'realestate' then
                ownerCid = oRow.identifier
            end
        end
        if not ownerCid and ownersByProp[propId] then
            for i = #ownersByProp[propId], 1, -1 do
                local oRow = ownersByProp[propId][i]
                if oRow.type == 'user' and oRow.identifier and oRow.identifier ~= '' and oRow.identifier ~= 'realestate' then
                    ownerCid = oRow.identifier
                    break
                end
            end
        end
        if not ownerCid and p.renterid and rentersById[tonumber(p.renterid)] then
            local rRow = rentersById[tonumber(p.renterid)]
            if not rRow.canceled_on and rRow.identifier and rRow.identifier ~= 'realestate' then
                ownerCid = rRow.identifier
            end
        end
        if ownerCid then ownedCount = ownedCount + 1 end

        local pDoors = doorsByProp[propId] or {}
        if #pDoors > 0 then withDoors = withDoors + 1 end

        local pFurn = furnitureByProp[propId] or {}
        if #pFurn > 0 then withFurniture = withFurniture + 1 end

        local rawMeta = ParseJson(p.metadata, {})
        local hasGarage = false
        if rawMeta.points then
            for _, pt in ipairs(rawMeta.points) do
                if pt.name == 'OpenGarageMenu' then hasGarage = true break end
            end
        end
        if hasGarage or rawMeta.garage then withGarage = withGarage + 1 end
    end

    Log(('Found %s properties in NoLag database:'):format(#noLagProps))
    print(('  - ^2Owned:^7 %s | ^3Unowned:^7 %s'):format(ownedCount, #noLagProps - ownedCount))
    print(('  - ^5MLOs:^7 %s | ^5Shells/Other:^7 %s'):format(mloCount, shellCount))
    print(('  - ^6With Doorlocks:^7 %s | ^6With Furniture:^7 %s | ^6With Garage:^7 %s'):format(withDoors, withFurniture, withGarage))
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
    local oxDoorlockStarted = (GetResourceState('ox_doorlock') == 'started')

    for _, p in ipairs(noLagProps) do
        local propId = tonumber(p.id)
        local rawMeta = ParseJson(p.metadata, {})
        local isMlo = (p.type and string.upper(tostring(p.type)) == 'MLO') or false

        local ownerCid = nil
        local ownerPurchasePrice = nil
        if p.ownerid and ownersById[tonumber(p.ownerid)] then
            local oRow = ownersById[tonumber(p.ownerid)]
            if oRow.type == 'user' and oRow.identifier and oRow.identifier ~= '' and oRow.identifier ~= 'realestate' then
                ownerCid = oRow.identifier
                ownerPurchasePrice = tonumber(oRow.purchase_price)
            end
        end
        if not ownerCid and ownersByProp[propId] then
            for i = #ownersByProp[propId], 1, -1 do
                local oRow = ownersByProp[propId][i]
                if oRow.type == 'user' and oRow.identifier and oRow.identifier ~= '' and oRow.identifier ~= 'realestate' then
                    ownerCid = oRow.identifier
                    ownerPurchasePrice = tonumber(oRow.purchase_price)
                    break
                end
            end
        end

        local isRented = false
        if p.renterid and rentersById[tonumber(p.renterid)] then
            local rRow = rentersById[tonumber(p.renterid)]
            if not rRow.canceled_on and rRow.identifier and rRow.identifier ~= 'realestate' then
                ownerCid = rRow.identifier
                isRented = true
            end
        elseif not ownerCid and rentersByProp[propId] then
            for i = #rentersByProp[propId], 1, -1 do
                local rRow = rentersByProp[propId][i]
                if not rRow.canceled_on and rRow.identifier and rRow.identifier ~= 'realestate' then
                    ownerCid = rRow.identifier
                    isRented = true
                    break
                end
            end
        end

        local propPrice = 0
        if isRented or (p.forrent == 1 or p.forrent == '1') then
            propPrice = (p.rentpriceid and rentPricesById[tonumber(p.rentpriceid)])
                or rentPricesByProp[propId]
                or (p.priceid and pricesById[tonumber(p.priceid)])
                or pricesByProp[propId]
                or 0
        else
            propPrice = (p.priceid and pricesById[tonumber(p.priceid)])
                or pricesByProp[propId]
                or ownerPurchasePrice
                or (p.rentpriceid and rentPricesById[tonumber(p.rentpriceid)])
                or rentPricesByProp[propId]
                or tonumber(p.price)
                or 0
        end

        local saleType = isRented and 'rent' or ((p.forrent == 1 or p.forrent == '1' or (p.payment and string.lower(tostring(p.payment)) == 'rent')) and 'rent' or 'direct')
        local rawShellType = rawMeta.shellType or rawMeta.shell or rawMeta.interior
        local shellName = ResolveShellName(rawShellType, isMlo)
        local enterCoords = nil
        if isMlo and rawMeta.managePoint then
            enterCoords = rawMeta.managePoint
        else
            enterCoords = rawMeta.enterData or rawMeta.entry or rawMeta.coords or (rawMeta.yardZone and rawMeta.yardZone.center)
        end

        local spawnData = nil
        if enterCoords then
            spawnData = {
                x = tonumber(enterCoords.x) or 0.0,
                y = tonumber(enterCoords.y) or 0.0,
                z = tonumber(enterCoords.z) or 0.0,
                h = tonumber(enterCoords.w or enterCoords.h or enterCoords.heading) or 0.0
            }
        end

        local hasYard = false
        local yardZoneData = nil
        if rawMeta.yardZone and rawMeta.yardZone.points and #rawMeta.yardZone.points >= 3 then
            hasYard = true
            yardZoneData = {
                points = rawMeta.yardZone.points,
                thickness = tonumber(rawMeta.yardZone.thickness) or 10.0
            }
        end

        local zoneData = { points = {}, thickness = 10.0 }
        if isMlo then
            if rawMeta.interiorZone and rawMeta.interiorZone.points and #rawMeta.interiorZone.points >= 3 then
                zoneData = rawMeta.interiorZone
            elseif yardZoneData then
                zoneData = yardZoneData
            end
        end

        local propSize = 1200
        if rawMeta.size and tonumber(rawMeta.size) and tonumber(rawMeta.size) > 0 then
            propSize = tonumber(rawMeta.size)
        elseif rawMeta.yardZone and rawMeta.yardZone.area and tonumber(rawMeta.yardZone.area) then
            propSize = math.floor(tonumber(rawMeta.yardZone.area) + 0.5)
        elseif zoneData and zoneData.points and #zoneData.points >= 3 and calculateSquareFootage then
            propSize = calculateSquareFootage(zoneData)
        end

        local garageData = nil
        local garageSlots = 0
        if rawMeta.points then
            for _, pt in ipairs(rawMeta.points) do
                if pt.name == 'OpenGarageMenu' then
                    local gCoords = pt.coords or pt.offset
                    if gCoords then
                        garageData = {
                            x = tonumber(gCoords.x) or 0.0,
                            y = tonumber(gCoords.y) or 0.0,
                            z = tonumber(gCoords.z) or 0.0,
                            h = tonumber(gCoords.w or gCoords.h or gCoords.heading) or 0.0,
                            spawn = {
                                x = tonumber(gCoords.x) or 0.0,
                                y = tonumber(gCoords.y) or 0.0,
                                z = tonumber(gCoords.z) or 0.0,
                                h = tonumber(gCoords.w or gCoords.h or gCoords.heading) or 0.0
                            }
                        }
                        garageSlots = 2
                    end
                    break
                end
            end
        end
        if not garageData and rawMeta.garage then
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
            garageSlots = 2
        end

        local doorList = {}
        local rawPropDoors = doorsByProp[propId] or {}
        for _, dRow in ipairs(rawPropDoors) do
            local dId = tonumber(dRow.id)
            local dData = ParseJson(dRow.data, nil)
            local doorRegistered = false

            if oxDoorlockStarted and dData then
                local existingDoor = nil
                if exports.ox_doorlock and exports.ox_doorlock.getDoor then
                    pcall(function() existingDoor = exports.ox_doorlock:getDoor(dId) end)
                end

                if existingDoor then
                    table.insert(doorList, dId)
                    doorRegistered = true
                else
                    local doorName = (p.label or p.address or ('Property #' .. propId)) .. ' - ' .. (dRow.name or 'Door')
                    if dData.doors and type(dData.doors) == 'table' and #dData.doors > 0 then
                        local panels = {}
                        for idx, panel in ipairs(dData.doors) do
                            panels[idx] = {
                                model = panel.model,
                                coords = vector3(panel.coords.x, panel.coords.y, panel.coords.z),
                                heading = tonumber(panel.heading) or 0.0
                            }
                        end
                        local ok, createdId = pcall(function()
                            return exports.ox_doorlock:createDoor({
                                name = doorName,
                                doors = panels,
                                state = tonumber(dData.state) or 1,
                                maxDistance = tonumber(dData.maxDistance) or 2.0
                            })
                        end)
                        if ok and createdId then
                            table.insert(doorList, createdId)
                            doorRegistered = true
                        end
                    elseif dData.coords then
                        local ok, createdId = pcall(function()
                            return exports.ox_doorlock:createDoor({
                                name = doorName,
                                model = dData.model,
                                coords = vector3(dData.coords.x, dData.coords.y, dData.coords.z),
                                heading = tonumber(dData.heading) or 0.0,
                                state = tonumber(dData.state) or 1,
                                maxDistance = tonumber(dData.maxDistance) or 2.0
                            })
                        end)
                        if ok and createdId then
                            table.insert(doorList, createdId)
                            doorRegistered = true
                        end
                    end
                end
            end

            if not doorRegistered and dId then
                table.insert(doorList, dId)
            end
        end

        local keyholderSet = {}
        if p.keyholders then
            local decodedKeys = ParseJson(p.keyholders, {})
            if type(decodedKeys) == 'table' then
                for cidKey, _ in pairs(decodedKeys) do
                    if type(cidKey) == 'string' and cidKey ~= '' and cidKey ~= 'realestate' then
                        keyholderSet[cidKey] = true
                    end
                end
            end
        end
        if extraKeysByProp[propId] then
            for _, cid in ipairs(extraKeysByProp[propId]) do
                if cid ~= 'realestate' then keyholderSet[cid] = true end
            end
        end

        local entryList = {}
        local storageList = {}
        local wardrobeList = {}
        for kCid, _ in pairs(keyholderSet) do
            table.insert(entryList, kCid)
            table.insert(storageList, kCid)
            table.insert(wardrobeList, kCid)
        end

        local permissions = {
            entry = entryList,
            storage = storageList,
            wardrobe = wardrobeList,
            furniture = {},
            manage = {}
        }

        local furnitureList = {}
        local rawFurnitureRows = furnitureByProp[propId] or {}

        for _, f in ipairs(rawFurnitureRows) do
            local furnId = tonumber(f.furnitureId) or tonumber(f.id) or math.random(100000, 999999)
            local rot = {
                x = tonumber(f.rotation_x) or 0.0,
                y = tonumber(f.rotation_y) or 0.0,
                z = tonumber(f.rotation_z) or 0.0
            }

            local pos = nil
            if isMlo or f.environment == 'outside' then
                pos = {
                    x = tonumber(f.coords_x) or 0.0,
                    y = tonumber(f.coords_y) or 0.0,
                    z = tonumber(f.coords_z) or 0.0
                }
            else
                local baseX = spawnData and spawnData.x or 0.0
                local baseY = spawnData and spawnData.y or 0.0
                pos = {
                    x = baseX + (tonumber(f.coords_x) or 0.0),
                    y = baseY + (tonumber(f.coords_y) or 0.0),
                    z = shellSpawningZ + (tonumber(f.coords_z) or 0.0)
                }
            end

            table.insert(furnitureList, {
                id = furnId,
                model = f.model,
                label = f.label or f.model,
                position = pos,
                rotation = rot,
                category = GetFurnitureCategory(f.model),
                price = tonumber(f.price) or 0
            })
        end

        local hasPanel = false
        for _, furn in ipairs(furnitureList) do
            if furn.model == 'reh_prop_reh_tablet_01a' then hasPanel = true break end
        end

        if rawMeta.points and type(rawMeta.points) == 'table' then
            for _, pt in ipairs(rawMeta.points) do
                if pt.name == 'OpenInventory' then
                    local stashFurnId = 90000 + (tonumber(pt.id) or 1)
                    local sPos = nil
                    if pt.coords then
                        sPos = {
                            x = tonumber(pt.coords.x) or 0.0,
                            y = tonumber(pt.coords.y) or 0.0,
                            z = tonumber(pt.coords.z) or 0.0
                        }
                    elseif pt.offset then
                        local baseX = spawnData and spawnData.x or 0.0
                        local baseY = spawnData and spawnData.y or 0.0
                        local baseZ = isMlo and (spawnData and spawnData.z or 0.0) or shellSpawningZ
                        sPos = {
                            x = baseX + (tonumber(pt.offset.x) or 0.0),
                            y = baseY + (tonumber(pt.offset.y) or 0.0),
                            z = baseZ + (tonumber(pt.offset.z) or 0.0)
                        }
                    end

                    if sPos then
                        table.insert(furnitureList, {
                            id = stashFurnId,
                            model = 'v_res_tre_storagebox',
                            label = pt.label or 'Storage Unit',
                            position = sPos,
                            rotation = { x = 0.0, y = 0.0, z = tonumber(pt.coords and (pt.coords.w or pt.coords.h)) or 0.0 },
                            category = 'prerequisites',
                            price = 0
                        })

                        local newStashId = string.format('housing_%s_%s', propId, stashFurnId)
                        pcall(function()
                            MySQL.query.await([[
                                UPDATE ox_inventory 
                                SET name = ? 
                                WHERE name IN (?, ?, ?, ?);
                            ]], {
                                newStashId,
                                ('property_' .. propId),
                                ('property_' .. propId .. '_' .. (pt.id or 1)),
                                ('property_' .. propId .. '_inventory'),
                                ('property_' .. propId .. '_stash')
                            })
                        end)
                        pcall(function()
                            MySQL.query.await([[
                                UPDATE stashitems 
                                SET stash = ? 
                                WHERE stash IN (?, ?, ?, ?);
                            ]], {
                                newStashId,
                                ('property_' .. propId),
                                ('property_' .. propId .. '_' .. (pt.id or 1)),
                                ('property_' .. propId .. '_inventory'),
                                ('property_' .. propId .. '_stash')
                            })
                        end)
                        stashesMigrated = stashesMigrated + 1
                    end
                elseif pt.name == 'ClothingMenu' then
                    local wFurnId = 91000 + (tonumber(pt.id) or 1)
                    local wPos = nil
                    if pt.coords then
                        wPos = {
                            x = tonumber(pt.coords.x) or 0.0,
                            y = tonumber(pt.coords.y) or 0.0,
                            z = tonumber(pt.coords.z) or 0.0
                        }
                    elseif pt.offset then
                        local baseX = spawnData and spawnData.x or 0.0
                        local baseY = spawnData and spawnData.y or 0.0
                        local baseZ = isMlo and (spawnData and spawnData.z or 0.0) or shellSpawningZ
                        wPos = {
                            x = baseX + (tonumber(pt.offset.x) or 0.0),
                            y = baseY + (tonumber(pt.offset.y) or 0.0),
                            z = baseZ + (tonumber(pt.offset.z) or 0.0)
                        }
                    end

                    if wPos then
                        table.insert(furnitureList, {
                            id = wFurnId,
                            model = 'v_res_tre_wardrobe',
                            label = pt.label or 'Wardrobe',
                            position = wPos,
                            rotation = { x = 0.0, y = 0.0, z = tonumber(pt.coords and (pt.coords.w or pt.coords.h)) or 0.0 },
                            category = 'prerequisites',
                            price = 0
                        })
                    end
                end
            end
        end

        if not hasPanel then
            local panelPos = nil
            if rawMeta.managePoint then
                panelPos = {
                    x = tonumber(rawMeta.managePoint.x) or 0.0,
                    y = tonumber(rawMeta.managePoint.y) or 0.0,
                    z = tonumber(rawMeta.managePoint.z) or 0.0
                }
            elseif isMlo and spawnData then
                panelPos = {
                    x = spawnData.x,
                    y = spawnData.y,
                    z = spawnData.z
                }
            elseif not isMlo and spawnData then
                panelPos = {
                    x = spawnData.x + 0.5,
                    y = spawnData.y + 0.5,
                    z = shellSpawningZ + 0.5
                }
            end

            if panelPos then
                table.insert(furnitureList, {
                    id = 99999,
                    model = 'reh_prop_reh_tablet_01a',
                    label = 'Property Panel',
                    position = panelPos,
                    rotation = { x = 0.0, y = 0.0, z = 0.0 },
                    category = 'prerequisites',
                    price = 0
                })
            end
        end

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
            locked = (p.locked == 1 or p.locked == true or p.locked == '1' or rawMeta.doorLocked == true),
            garage_data = garageData,
            size = propSize,
            region = rawMeta.region or 'Unknown',
            has_yard = hasYard,
            max_power = (Settings and Settings.Electricity and Settings.Electricity.DefaultMaxPower) or 5.0,
            power_level = 1,
            breaker_tripped = false,
            rent_amount = isRented and propPrice or nil,
            last_rent_paid = isRented and os.time() or nil
        }

        local primaryDoorId = (#doorList > 0) and doorList[1] or nil

        MySQL.query.await([[
            INSERT INTO housing_properties 
                (id, label, price, owner, door_id, doors, permissions, metadata, furniture, sale_type, zone_data, yard_zone_data, garage)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                label = VALUES(label),
                price = VALUES(price),
                owner = VALUES(owner),
                door_id = VALUES(door_id),
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
            p.label or p.address or ('Property #' .. propId),
            propPrice,
            ownerCid,
            primaryDoorId,
            json.encode(doorList),
            json.encode(permissions),
            json.encode(lnsMetadata),
            json.encode(furnitureList),
            saleType,
            json.encode(zoneData),
            json.encode(yardZoneData),
            garageSlots
        })

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
        Log(('Registered/converted %s dedicated storage records.'):format(stashesMigrated), 'info')
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
            if Properties[id].metadata and Properties[id].metadata.garage_data and Bridge.Server.RegisterGarage then
                pcall(Bridge.Server.RegisterGarage, id, Properties[id].label, Properties[id].metadata.garage_data)
            end
            if Bridge.Server.RegisterPropertyStashes and Properties[id].furniture then
                pcall(Bridge.Server.RegisterPropertyStashes, id, Properties[id].furniture)
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