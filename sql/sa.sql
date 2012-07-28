CREATE TABLE `managed_server` (
    `id` char(32) NOT NULL,
    `hostname` char(255) NOT NULL,
    `ip` char(16) NOT NULL,
    `status` tinyint(2) NOT NULL,
    `update_time` timestamp not null,
    PRIMARY KEY (`id`),
    UNIQUE KEY (`ip`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `server_software_queue` (
    `id` char(32) NOT NULL,
    `sw_name` char(255) NOT NULL,
    PRIMARY KEY (`id`,`sw_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

CREATE TABLE `server_software` (
    `id` char(32) NOT NULL,
    `sw_name` char(255) NOT NULL,
    `status` tinyint(2) NOT NULL,
    `update_time` timestamp not null,
    PRIMARY KEY (`id`,`sw_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
