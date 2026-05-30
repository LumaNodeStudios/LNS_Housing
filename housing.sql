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

CREATE TABLE IF NOT EXISTS `housing_stashes` (
    `id` VARCHAR(100) PRIMARY KEY,
    `property_id` INT NOT NULL,
    `data` LONGTEXT DEFAULT '{}',
    FOREIGN KEY (`property_id`) REFERENCES `housing_properties`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
