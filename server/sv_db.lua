local Settings = lib.load('shared.settings')
Properties = {}
DbReady = false

function WaitForDb()
    while not DbReady do
        Wait(100)
    end
end

function LoadProperties()
    debugPrint('info', 'Loading properties from database...')
    local result = MySQL.query.await('SELECT * FROM housing_properties')
    if result then
        for _, v in ipairs(result) do
            v.permissions = json.decode(v.permissions)
            if not v.permissions then v.permissions = { entry = {}, storage = {}, wardrobe = {}, manage = {} } end
            v.metadata = json.decode(v.metadata)
            if not v.metadata then v.metadata = {} end
            if v.metadata.rent_debt == nil then v.metadata.rent_debt = 0 end
            if v.metadata.missed_payments == nil then v.metadata.missed_payments = 0 end
            if v.metadata.due_by == nil then v.metadata.due_by = nil end
            if v.metadata.auto_pay == nil then v.metadata.auto_pay = true end
            if v.metadata.tenant_history == nil then v.metadata.tenant_history = {} end
            if v.metadata.rent_history == nil then v.metadata.rent_history = {} end
            if v.metadata.partial_payment == nil then v.metadata.partial_payment = 0 end
            if v.metadata.size == nil then v.metadata.size = 0 end
            if v.metadata.region == nil then v.metadata.region = 'Unknown' end
            if v.metadata.max_power == nil then v.metadata.max_power = (Settings.Electricity and Settings.Electricity.DefaultMaxPower) or 5.0 end
            if v.metadata.power_level == nil then v.metadata.power_level = 1 end
            if v.metadata.breaker_tripped == nil then v.metadata.breaker_tripped = false end
            if v.metadata.breaker_coords == nil then v.metadata.breaker_coords = nil end
            v.size = v.metadata.size
            v.region = v.metadata.region
            
            v.furniture = json.decode(v.furniture)
            v.zone_data = json.decode(v.zone_data or '[]')
            v.doors = json.decode(v.doors or '[]')
            v.image = v.image or nil
            v.sale_type = v.sale_type or 'direct'
            v.auction_data = json.decode(v.auction_data or '{"current_bid": 0, "highest_bidder": null, "status": "paused"}')
            v.price = tonumber(v.price) or 0
            v.yard_zone_data = json.decode(v.yard_zone_data or 'null')
            v.last_mowed = tonumber(v.last_mowed) or 0
            v.lawn_data = json.decode(v.lawn_data or '{}')
            v.agency = v.agency or nil
            v.agent_cid = v.agent_cid or nil
            v.commission_rate = tonumber(v.commission_rate) or 10
            v.garage = tonumber(v.garage) or 2
            
            
            if not v.doors or #v.doors == 0 then
                if v.door_id and v.door_id ~= 0 then
                    v.doors = { v.door_id }
                else
                    v.doors = {}
                end
            end
            Properties[v.id] = v
            EnrichPropertyDoorlockData(v)

            if v.owner and v.sale_type == 'rent' and (not v.metadata or not v.metadata.last_rent_paid or v.metadata.last_rent_paid == 0) then
                v.metadata = v.metadata or {}
                v.metadata.last_rent_paid = os.time()
                SaveProperty(v.id)
            end

            if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
                Bridge.Server.RegisterPropertyStashes(v.id, v.furniture)
            end

            if v.metadata and v.metadata.garage_data then
                if Bridge and Bridge.Server and Bridge.Server.RegisterGarage then
                    Bridge.Server.RegisterGarage(v.id, v.label, v.metadata.garage_data)
                end
            end
        end
        lib.print.info('Loaded ' .. #result .. ' properties.')
    end
end

function CreateProperty(data)
    debugPrint('info', 'CreateProperty called', {label = data and data.label})
    local spawnData = nil
    if data.spawn_coords then
        spawnData = {
            x = data.spawn_coords.x,
            y = data.spawn_coords.y,
            z = data.spawn_coords.z,
            h = data.spawn_coords.w
        }
    end

    local id = MySQL.insert.await('INSERT INTO housing_properties (label, price, doors, image, sale_type, auction_data, zone_data, metadata, yard_zone_data, last_mowed, lawn_data, agency, agent_cid, commission_rate, garage) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        data.name or data.label, 
        data.price, 
        json.encode(data.doors or {}), 
        data.image or nil,
        data.saleType or 'direct',
        json.encode({
            current_bid = data.saleType == 'auction' and tonumber(data.price) or 0,
            highest_bidder = nil,
            status = 'paused'
        }),
        json.encode(data.zone_data or {}),
        json.encode({
            power = 0, 
            water = 0, 
            wall_color = 0,
            allow_wall_colors = data.allowWallColors or false,
            security_level = 0,
            spawn = spawnData,
            shell = data.mlo and 'mlo' or (data.shell or 'Standard Motel'),
            interior_id = data.interior_id or nil,
            interior_coords = data.interior_coords or nil,
            interior_center = data.interior_center or nil,
            room_count = data.room_count or nil,
            mlo = data.mlo == true or data.shell == 'mlo',
            entrance = data.entrance,
            locked = true,
            garage_data = data.garage_data or nil,
            size = data.size or 0,
            region = data.region or 'Unknown',
            camera_coords = data.camera_coords or nil,
            camera_aim = data.camera_aim or nil,
            camera_model = data.camera_model or nil,
            camera_heading = data.camera_heading or 0.0,
            doorbell_camera = data.doorbell_camera or false,
            breaker_coords = data.breaker_coords or data.breakerCoords or nil,
            max_power = (Settings.Electricity and Settings.Electricity.DefaultMaxPower) or 5.0,
            power_level = 1,
            breaker_tripped = false
        }),
        json.encode(data.yard_zone_data or nil),
        0,
        json.encode({}),
        data.agency or nil,
        data.agent_cid or nil,
        data.commission_rate or 10,
        tonumber(data.slots) or 2
    })
    
    if id then
        Properties[id] = {
            id = id,
            label = data.name or data.label,
            price = tonumber(data.price) or 0,
            doors = data.doors or {},
            owner = nil,
            permissions = {entry = {}, storage = {}, wardrobe = {}, manage = {}},
            metadata = {
                power = 0, 
                water = 0, 
                wall_color = 0,
                allow_wall_colors = data.allowWallColors or false,
                security_level = 0,
                spawn = spawnData,
                shell = data.mlo and 'mlo' or (data.shell or 'Standard Motel'),
                interior_id = data.interior_id or nil,
                interior_coords = data.interior_coords or nil,
                interior_center = data.interior_center or nil,
                room_count = data.room_count or nil,
                mlo = data.mlo == true or data.shell == 'mlo',
                entrance = data.entrance,
                locked = true,
                garage_data = data.garage_data or nil,
                size = data.size or 0,
                region = data.region or 'Unknown',
                camera_coords = data.camera_coords or nil,
                camera_aim = data.camera_aim or nil,
                camera_model = data.camera_model or nil,
                camera_heading = data.camera_heading or 0.0,
                doorbell_camera = data.doorbell_camera or false,
                breaker_coords = data.breaker_coords or data.breakerCoords or nil,
                max_power = (Settings.Electricity and Settings.Electricity.DefaultMaxPower) or 5.0,
                power_level = 1,
                breaker_tripped = false
            },
            image = data.image or nil,
            sale_type = data.saleType or 'direct',
            auction_data = {
                current_bid = data.saleType == 'auction' and tonumber(data.price) or 0,
                highest_bidder = nil,
                status = 'paused'
            },
            furniture = {},
            zone_data = data.zone_data or {},
            yard_zone_data = data.yard_zone_data or nil,
            last_mowed = 0,
            lawn_data = {},
            agency = data.agency or nil,
            agent_cid = data.agent_cid or nil,
            commission_rate = data.commission_rate or 10,
            garage = tonumber(data.slots) or 2
        }
        Properties[id].size = Properties[id].metadata.size
        Properties[id].region = Properties[id].metadata.region
        EnrichPropertyDoorlockData(Properties[id])
        return Properties[id]
    end
    return nil
end

function SaveProperty(id)
    debugPrint('info', 'SaveProperty called', {id = id})
    local p = Properties[id]
    if not p then return end
    
    MySQL.update.await('UPDATE housing_properties SET label = ?, price = ?, owner = ?, permissions = ?, metadata = ?, furniture = ?, zone_data = ?, doors = ?, image = ?, sale_type = ?, auction_data = ?, yard_zone_data = ?, last_mowed = ?, lawn_data = ?, agency = ?, agent_cid = ?, commission_rate = ?, garage = ? WHERE id = ?', {
        p.label, p.price, p.owner, json.encode(p.permissions), json.encode(p.metadata), json.encode(p.furniture), json.encode(p.zone_data or {}), json.encode(p.doors or {}), p.image or nil, p.sale_type or 'direct', json.encode(p.auction_data), json.encode(p.yard_zone_data or nil), p.last_mowed or 0, json.encode(p.lawn_data or {}), p.agency or nil, p.agent_cid or nil, p.commission_rate or 10, p.garage or 2, id
    })
end

local function GetPlayerProperties(source)
    if not source then return {} end
    local src = tonumber(source) or source
    local identifier = nil

    if type(src) == 'number' then
        identifier = Bridge.Server.GetIdentifier(src)
    elseif type(src) == 'string' then
        identifier = Bridge.Server.GetIdentifier(src) or src
    end

    if not identifier then return {} end

    local playerProps = {}
    for _, p in pairs(Properties) do
        if p.owner == identifier then
            table.insert(playerProps, p)
        end
    end
    return playerProps
end

exports('GetProperties', function() return Properties end)
exports('GetProperty', function(id) return Properties[id] end)
exports('GetPlayerProperties', GetPlayerProperties)

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `housing_properties` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `label` VARCHAR(100) NOT NULL,
            `price` INT NOT NULL DEFAULT 0,
            `owner` VARCHAR(60) DEFAULT NULL,
            `door_id` INT DEFAULT NULL,
            `permissions` LONGTEXT DEFAULT '{"entry":[], "storage":[], "wardrobe":[], "manage":[]}',
            `metadata` LONGTEXT DEFAULT '{"power": 0, "water": 0, "wall_color": 0, "allow_wall_colors": false}',
            `furniture` LONGTEXT DEFAULT '[]',
            `doors` LONGTEXT DEFAULT '[]',
            `image` LONGTEXT DEFAULT NULL,
            `sale_type` VARCHAR(20) DEFAULT 'direct',
            `auction_data` LONGTEXT DEFAULT '{"current_bid": 0, "highest_bidder": null, "status": "paused"}',
            `zone_data` LONGTEXT DEFAULT '{"points":[], "thickness": 10.0}',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `housing_stashes` (
            `id` VARCHAR(100) PRIMARY KEY,
            `property_id` INT NOT NULL,
            `data` LONGTEXT DEFAULT '{}',
            FOREIGN KEY (`property_id`) REFERENCES `housing_properties`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    if Settings.Apartments and Settings.Apartments.Enabled then
        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS player_apartments (
                id INT AUTO_INCREMENT PRIMARY KEY,
                license VARCHAR(50) NOT NULL,
                room_id INT NOT NULL,
                is_new TINYINT(1) DEFAULT 1,
                assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_license (license)
            )
        ]])

        pcall(function()
            local cols = MySQL.query.await("SHOW COLUMNS FROM player_apartments LIKE 'citizenid'")
            if cols and #cols > 0 then
                MySQL.query.await("ALTER TABLE player_apartments CHANGE COLUMN citizenid license VARCHAR(50) NOT NULL")
            end
        end)

        pcall(function()
            MySQL.query.await("ALTER TABLE player_apartments DROP INDEX unique_citizen")
        end)

        pcall(function()
            MySQL.query.await("ALTER TABLE player_apartments DROP INDEX unique_room")
        end)

        pcall(function()
            local Framework = Bridge and Bridge.Framework or 'qbx'
            if Framework == 'qbx' then
                MySQL.query.await([[
                    UPDATE player_apartments pa
                    JOIN players p ON pa.license = p.citizenid
                    SET pa.license = p.license
                    WHERE pa.license NOT LIKE 'license:%'
                ]])
            end
        end)

        pcall(function()
            MySQL.query.await([[
                DELETE t1 FROM player_apartments t1
                INNER JOIN player_apartments t2 
                WHERE t1.id < t2.id AND t1.license = t2.license
            ]])
        end)

        pcall(function()
            local indexes = MySQL.query.await("SHOW INDEX FROM player_apartments WHERE Key_name = 'unique_license'")
            if not indexes or #indexes == 0 then
                MySQL.query.await("ALTER TABLE player_apartments ADD UNIQUE KEY unique_license (license)")
            end
        end)

        pcall(function()
            local cols = MySQL.query.await("SHOW COLUMNS FROM player_apartments LIKE 'is_new'")
            if not cols or #cols == 0 then
                MySQL.query.await("ALTER TABLE player_apartments ADD COLUMN is_new TINYINT(1) DEFAULT 1")
            end
        end)

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS apartments (
                id INT AUTO_INCREMENT PRIMARY KEY,
                citizenid VARCHAR(50) NOT NULL,
                room_id INT NOT NULL,
                permissions LONGTEXT DEFAULT '{"entry":[], "storage":[], "wardrobe":[], "manage":[]}',
                furniture LONGTEXT DEFAULT '[]',
                wall_color INT DEFAULT 0,
                is_new TINYINT(1) DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_citizen_room (citizenid, room_id)
            )
        ]])

        pcall(function()
            local cols = MySQL.query.await("SHOW COLUMNS FROM apartments LIKE 'is_new'")
            if not cols or #cols == 0 then
                MySQL.query.await("ALTER TABLE apartments ADD COLUMN is_new TINYINT(1) DEFAULT 1")
            end
        end)

        MySQL.query.await([[
            CREATE TABLE IF NOT EXISTS apartment_rooms (
                id INT PRIMARY KEY,
                corners LONGTEXT NOT NULL,
                thickness FLOAT NOT NULL DEFAULT 3.5,
                zOffset FLOAT NOT NULL DEFAULT 0.0,
                door_model INT DEFAULT NULL,
                door_coords LONGTEXT DEFAULT NULL,
                door_heading FLOAT DEFAULT NULL,
                spawn_coords LONGTEXT NOT NULL,
                price INT NOT NULL DEFAULT 0,
                is_starter TINYINT(1) DEFAULT 1,
                tablet_coords LONGTEXT DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end

    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `apartment_rooms` LIKE 'tablet_coords'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `apartment_rooms` ADD COLUMN `tablet_coords` LONGTEXT DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `apartment_rooms` LIKE 'interior_id'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `apartment_rooms` ADD COLUMN `interior_id` INT DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `apartment_rooms` LIKE 'interior_coords'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `apartment_rooms` ADD COLUMN `interior_coords` LONGTEXT DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `apartment_rooms` LIKE 'interior_center'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `apartment_rooms` ADD COLUMN `interior_center` LONGTEXT DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `apartment_rooms` LIKE 'room_count'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `apartment_rooms` ADD COLUMN `room_count` INT DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `apartment_rooms` LIKE 'room_name'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `apartment_rooms` ADD COLUMN `room_name` VARCHAR(100) DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `apartment_rooms` LIKE 'room_key'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `apartment_rooms` ADD COLUMN `room_key` INT DEFAULT NULL")
        end
    end)
    pcall(function()
        MySQL.query.await("ALTER TABLE `apartment_rooms` MODIFY COLUMN `corners` LONGTEXT DEFAULT NULL")
    end)

    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `housing_properties` LIKE 'yard_zone_data'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `housing_properties` ADD COLUMN `yard_zone_data` LONGTEXT DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `housing_properties` LIKE 'last_mowed'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `housing_properties` ADD COLUMN `last_mowed` INT DEFAULT 0")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `housing_properties` LIKE 'lawn_data'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `housing_properties` ADD COLUMN `lawn_data` LONGTEXT DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `housing_properties` LIKE 'agency'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `housing_properties` ADD COLUMN `agency` VARCHAR(50) DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `housing_properties` LIKE 'agent_cid'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `housing_properties` ADD COLUMN `agent_cid` VARCHAR(50) DEFAULT NULL")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `housing_properties` LIKE 'commission_rate'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `housing_properties` ADD COLUMN `commission_rate` INT DEFAULT 10")
        end
    end)
    pcall(function()
        local cols = MySQL.query.await("SHOW COLUMNS FROM `housing_properties` LIKE 'garage'")
        if not cols or #cols == 0 then
            MySQL.query.await("ALTER TABLE `housing_properties` ADD COLUMN `garage` INT DEFAULT 2")
        end
    end)

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `housing_contracts` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `property_id` INT NOT NULL,
            `client_cid` VARCHAR(50) NOT NULL,
            `client_name` VARCHAR(100) DEFAULT 'Unknown',
            `agent_cid` VARCHAR(50) NOT NULL,
            `agent_name` VARCHAR(100) DEFAULT 'Unknown',
            `agency` VARCHAR(50) NOT NULL,
            `price` INT NOT NULL,
            `type` VARCHAR(20) NOT NULL,
            `status` VARCHAR(20) DEFAULT 'pending',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (`property_id`) REFERENCES `housing_properties`(`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `housing_blacklist` (
            `citizenid` VARCHAR(50) PRIMARY KEY,
            `name` VARCHAR(100) NOT NULL,
            `reason` VARCHAR(255) DEFAULT NULL,
            `blacklisted_by` VARCHAR(100) NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    pcall(LoadProperties)

    for id, _ in pairs(Properties) do
        if SyncPropertyDoor then
            pcall(SyncPropertyDoor, id)
        end
    end

    DbReady = true
    debugPrint('info', 'Database ready, properties initialized.')
end)

function ResetPropertyOwnershipData(id)
    debugPrint('info', 'ResetPropertyOwnershipData called', {id = id})
    local p = Properties[id]
    if not p then return end

    p.owner = nil
    p.permissions = { entry = {}, storage = {}, wardrobe = {}, manage = {} }
    p.furniture = {}
    
    if not p.metadata then p.metadata = {} end
    p.metadata.security_level = 0
    p.metadata.wall_color = 0
    p.metadata.locked = true
    p.metadata.rent_debt = nil
    p.metadata.missed_payments = nil
    p.metadata.due_by = nil
    p.metadata.last_rent_paid = nil
    p.metadata.rent_amount = nil
    p.metadata.auto_pay = nil
    p.metadata.partial_payment = nil
    p.metadata.rent_history = {}
    p.metadata.doorbell_camera = false
    p.metadata.camera_coords = nil
    p.metadata.camera_aim = nil

    if TemporaryAccess then
        if TemporaryAccess.doors then TemporaryAccess.doors[id] = nil end
        if TemporaryAccess.stashes then TemporaryAccess.stashes[id] = nil end
    end
    if FailedAttempts then FailedAttempts[id] = nil end
    if ActiveAlarms then ActiveAlarms[id] = nil end
    if MotionAlertCooldown then MotionAlertCooldown[id] = nil end
    if LockedStashes then LockedStashes[id] = nil end

    local pk = Settings and Settings.Security and Settings.Security.PhysicalKeys
    if pk and pk.Enabled and GetResourceState('ox_inventory') == 'started' then
        pcall(function()
            local players = GetPlayers()
            for i = 1, #players do
                local pId = tonumber(players[i])
                if pId then
                    local slots = exports.ox_inventory:Search(pId, 'slots', pk.Item)
                    if slots then
                        for _, slot in ipairs(slots) do
                            local meta = slot.metadata or {}
                            if (meta.propertyId == id or tonumber(meta.propertyId) == tonumber(id)) and not meta.isApartment then
                                exports.ox_inventory:RemoveItem(pId, pk.Item, slot.count or 1, meta, slot.slot)
                            end
                        end
                    end
                end
            end

            local success, rows = pcall(MySQL.query.await, 'SELECT name, data FROM ox_inventory WHERE data LIKE ?', {'%' .. pk.Item .. '%'})
            if success and rows then
                for _, row in ipairs(rows) do
                    local data = json.decode(row.data)
                    if data then
                        local modified = false
                        local newItems = {}
                        for slotIdx, item in pairs(data) do
                            if item and item.name == pk.Item and item.metadata and (item.metadata.propertyId == id or tonumber(item.metadata.propertyId) == tonumber(id)) and not item.metadata.isApartment then
                                modified = true
                            else
                                newItems[slotIdx] = item
                            end
                        end
                        if modified then
                            MySQL.update.await('UPDATE ox_inventory SET data = ? WHERE name = ?', {json.encode(newItems), row.name})
                        end
                    end
                end
            end
        end)
    end

    if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
        Bridge.Server.RegisterPropertyStashes(id, p.furniture)
    end
end

function GetDoorlockDbData(doorId)
    local success, result = pcall(function()
        return MySQL.single.await('SELECT data FROM ox_doorlock WHERE id = ?', { doorId })
    end)
    if success and result and result.data then
        local ok, data = pcall(json.decode, result.data)
        if ok and data then
            return data
        end
    end
    return nil
end

function EnrichPropertyDoorlockData(p)
    if not p then return end
    local doorId = p.door_id
    if (not doorId or doorId == 0) and p.doors and #p.doors > 0 then
        doorId = p.doors[1]
    end
    if not doorId or doorId == 0 then return end

    local success, door = pcall(function()
        return exports.ox_doorlock:getDoor(doorId)
    end)
    if success and door then
        local doorCoords = door.coords
        local doorModel = door.model
        local doorHeading = door.heading

        local dbData = GetDoorlockDbData(doorId)
        if dbData then
            if dbData.doors and dbData.doors[1] then
                if not doorCoords then doorCoords = dbData.doors[1].coords end
                if not doorModel then doorModel = dbData.doors[1].model end
                if not doorHeading then doorHeading = dbData.doors[1].heading end
            else
                if not doorCoords then doorCoords = dbData.coords end
                if not doorModel then doorModel = dbData.model end
                if not doorHeading then doorHeading = dbData.heading end
            end
        end

        p.metadata = p.metadata or {}
        p.metadata.doorCoords = doorCoords
        p.metadata.doorModel = doorModel
        p.metadata.doorHeading = doorHeading
    end
end

CreateThread(function()
    while GetResourceState('ox_doorlock') ~= 'started' do
        Wait(1000)
    end
    Wait(5000)
    for _, p in pairs(Properties) do
        EnrichPropertyDoorlockData(p)
    end
    TriggerClientEvent('LNS_Housing:client:updateProperties', -1, Properties)
end)