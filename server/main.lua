ESX = exports.es_extended:getSharedObject()

MySQL.ready(function()
    math.randomseed(os.time())
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rs_business_workpoints` (
          `id` int unsigned NOT NULL AUTO_INCREMENT,
          `business_id` int unsigned NOT NULL,
          `role` enum('cashier','stocker','manager','guard') NOT NULL,
          `sequence` int unsigned NOT NULL DEFAULT 1,
          `label` varchar(48) NOT NULL,
          `coords` longtext NOT NULL,
          `scenario` varchar(80) NOT NULL,
          `duration_ms` int unsigned NOT NULL DEFAULT 9000,
          `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
          PRIMARY KEY (`id`),
          KEY `idx_rs_workpoint_route` (`business_id`,`role`,`sequence`),
          CONSTRAINT `fk_rs_workpoint_business` FOREIGN KEY (`business_id`) REFERENCES `rs_businesses` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    MySQL.update.await([[
        UPDATE rs_business_workpoints
        SET scenario = 'RS_CASH_REGISTER'
        WHERE role = 'cashier' AND scenario = 'WORLD_HUMAN_CLIPBOARD'
    ]])
    RSRepo.reload()
    print(('[rs-businesses] %d bedrijfslocaties geladen; NPC-AI en werkroutes gereed.'):format(#RSRepo.publicList()))
end)

lib.callback.register('rs-businesses:server:list', function() return RSRepo.publicList() end)

RegisterNetEvent('rs-businesses:server:requestSync', function()
    TriggerClientEvent('rs-businesses:client:sync', source, RSRepo.publicList())
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[rs-businesses] Resource veilig gestopt.')
end)
