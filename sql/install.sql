CREATE TABLE IF NOT EXISTS `rs_businesses` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(48) NOT NULL,
  `type` enum('shop','fuel','combined') NOT NULL DEFAULT 'shop',
  `owner_identifier` varchar(80) DEFAULT NULL,
  `owner_name` varchar(80) DEFAULT NULL,
  `purchase_price` decimal(12,2) NOT NULL DEFAULT 150000.00,
  `balance` decimal(14,2) NOT NULL DEFAULT 0.00,
  `tax_percent` decimal(5,2) NOT NULL DEFAULT 6.00,
  `coords` longtext NOT NULL,
  `management_coords` longtext NOT NULL,
  `delivery_coords` longtext NOT NULL,
  `npc` longtext NOT NULL,
  `blip` longtext NOT NULL,
  `fuel_stock` decimal(12,2) NOT NULL DEFAULT 0.00,
  `fuel_capacity` decimal(12,2) NOT NULL DEFAULT 15000.00,
  `fuel_buy_price` decimal(8,2) NOT NULL DEFAULT 1.35,
  `fuel_sell_price` decimal(8,2) NOT NULL DEFAULT 2.05,
  `is_open` tinyint(1) NOT NULL DEFAULT 1,
  `settings` longtext NOT NULL,
  `upgrades` longtext NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_rs_business_owner` (`owner_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_business_stock` (
  `business_id` int unsigned NOT NULL,
  `item` varchar(80) NOT NULL,
  `amount` int unsigned NOT NULL DEFAULT 0,
  `sale_price` decimal(10,2) NOT NULL DEFAULT 1.00,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`business_id`,`item`),
  CONSTRAINT `fk_rs_stock_business` FOREIGN KEY (`business_id`) REFERENCES `rs_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_business_employees` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `identifier` varchar(80) NOT NULL,
  `name` varchar(80) NOT NULL,
  `role` varchar(32) NOT NULL DEFAULT 'employee',
  `permissions` longtext NOT NULL,
  `hired_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rs_employee` (`business_id`,`identifier`),
  CONSTRAINT `fk_rs_employee_business` FOREIGN KEY (`business_id`) REFERENCES `rs_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_business_npcs` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `role` varchar(32) NOT NULL,
  `name` varchar(48) NOT NULL,
  `model` varchar(80) NOT NULL,
  `wage` decimal(10,2) NOT NULL DEFAULT 0.00,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `coords` longtext NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_rs_npc_business` FOREIGN KEY (`business_id`) REFERENCES `rs_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_business_orders` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `order_number` varchar(40) NOT NULL,
  `items` longtext NOT NULL,
  `total` decimal(12,2) NOT NULL,
  `delivery_mode` enum('delivery','pickup') NOT NULL DEFAULT 'delivery',
  `status` enum('pending','ready','ready_pickup','received','cancelled') NOT NULL DEFAULT 'pending',
  `ready_at` datetime NOT NULL,
  `created_by` varchar(80) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_rs_order_number` (`order_number`),
  CONSTRAINT `fk_rs_order_business` FOREIGN KEY (`business_id`) REFERENCES `rs_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `rs_business_transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `type` varchar(40) NOT NULL,
  `amount` decimal(14,2) NOT NULL,
  `description` varchar(160) NOT NULL,
  `actor_identifier` varchar(80) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_rs_transaction_date` (`business_id`,`created_at`),
  CONSTRAINT `fk_rs_transaction_business` FOREIGN KEY (`business_id`) REFERENCES `rs_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
