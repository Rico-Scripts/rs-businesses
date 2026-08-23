ESX = exports.es_extended:getSharedObject()

MySQL.ready(function()
    math.randomseed(os.time())
    RSRepo.reload()
    print(('[rs-businesses] %d bedrijfslocaties geladen.'):format(#RSRepo.publicList()))
end)

lib.callback.register('rs-businesses:server:list', function() return RSRepo.publicList() end)

RegisterNetEvent('rs-businesses:server:requestSync', function()
    TriggerClientEvent('rs-businesses:client:sync', source, RSRepo.publicList())
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('[rs-businesses] Resource veilig gestopt.')
end)
