local Settings = lib.load('shared.settings')
Properties = {}

function LoadProperties()
    local result = MySQL.query.await('SELECT * FROM housing_properties')
    if result then
        for _, v in ipairs(result) do
            v.permissions = json.decode(v.permissions)
            v.metadata = json.decode(v.metadata)
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
            
            -- Backwards compatibility
            if not v.doors or #v.doors == 0 then
                if v.door_id and v.door_id ~= 0 then
                    v.doors = { v.door_id }
                else
                    v.doors = {}
                end
            end
            
            Properties[v.id] = v

            if Bridge and Bridge.Server and Bridge.Server.RegisterPropertyStashes then
                Bridge.Server.RegisterPropertyStashes(v.id, v.furniture)
            end
        end
    end
    print('^2[Housing] ^7Loaded ' .. #result .. ' properties.')
end

function CreateProperty(data)
    local spawnData = nil
    if data.spawn_coords then
        spawnData = {
            x = data.spawn_coords.x,
            y = data.spawn_coords.y,
            z = data.spawn_coords.z,
            h = data.spawn_coords.w
        }
    end

    local id = MySQL.insert.await('INSERT INTO housing_properties (label, price, doors, image, sale_type, auction_data, zone_data, metadata, yard_zone_data, last_mowed, lawn_data, agency, agent_cid, commission_rate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
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
            spawn = spawnData
        }),
        json.encode(data.yard_zone_data or nil),
        0,
        json.encode({}),
        data.agency or nil,
        data.agent_cid or nil,
        data.commission_rate or 10
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
                spawn = spawnData
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
            commission_rate = data.commission_rate or 10
        }
        return Properties[id]
    end
    return nil
end

function SaveProperty(id)
    local p = Properties[id]
    if not p then return end
    
    MySQL.update.await('UPDATE housing_properties SET owner = ?, permissions = ?, metadata = ?, furniture = ?, zone_data = ?, doors = ?, image = ?, sale_type = ?, auction_data = ?, yard_zone_data = ?, last_mowed = ?, lawn_data = ?, agency = ?, agent_cid = ?, commission_rate = ? WHERE id = ?', {
        p.owner, json.encode(p.permissions), json.encode(p.metadata), json.encode(p.furniture), json.encode(p.zone_data or {}), json.encode(p.doors or {}), p.image or nil, p.sale_type or 'direct', json.encode(p.auction_data), json.encode(p.yard_zone_data or nil), p.last_mowed or 0, json.encode(p.lawn_data or {}), p.agency or nil, p.agent_cid or nil, p.commission_rate or 10, id
    })
end

exports('GetProperties', function() return Properties end)
exports('GetProperty', function(id) return Properties[id] end)

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
                citizenid VARCHAR(50) NOT NULL,
                room_id INT NOT NULL,
                is_new TINYINT(1) DEFAULT 1,
                assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_citizen (citizenid)
            )
        ]])

        -- Safe migrations for existing player_apartments tables (license -> citizenid, unique_room drop, is_new add)
        pcall(function()
            MySQL.query.await("ALTER TABLE player_apartments DROP INDEX unique_license")
        end)

        pcall(function()
            MySQL.query.await("ALTER TABLE player_apartments DROP INDEX unique_room")
        end)

        pcall(function()
            local cols = MySQL.query.await("SHOW COLUMNS FROM player_apartments LIKE 'license'")
            if cols and #cols > 0 then
                MySQL.query.await("ALTER TABLE player_apartments CHANGE COLUMN license citizenid VARCHAR(50) NOT NULL")
            end
        end)

        pcall(function()
            local cols = MySQL.query.await("SHOW COLUMNS FROM player_apartments LIKE 'is_new'")
            if not cols or #cols == 0 then
                MySQL.query.await("ALTER TABLE player_apartments ADD COLUMN is_new TINYINT(1) DEFAULT 1")
            end
        end)

        pcall(function()
            local indexes = MySQL.query.await("SHOW INDEX FROM player_apartments WHERE Key_name = 'unique_citizen'")
            if not indexes or #indexes == 0 then
                MySQL.query.await("ALTER TABLE player_apartments ADD UNIQUE KEY unique_citizen (citizenid)")
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
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_citizen_room (citizenid, room_id)
            )
        ]])

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
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
    end

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
        CREATE TABLE IF NOT EXISTS `housing_employees` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `agency` VARCHAR(50) NOT NULL,
            `citizenid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(100) DEFAULT 'Unknown',
            `commission_rate` INT DEFAULT 10,
            `permissions` LONGTEXT DEFAULT '{"createHouse": false, "draftContract": true, "manageListings": false, "manageEmployees": false}',
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY `unique_agency_employee` (`agency`, `citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])

    LoadProperties()
end)