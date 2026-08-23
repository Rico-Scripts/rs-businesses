RegisterNetEvent('rs-businesses:client:openAdmin', function()
    local allowed = lib.callback.await('rs-businesses:server:isAdmin', false)
    if not allowed then return RSClient.notify(_L('no_access'), false) end
    local list = lib.callback.await('rs-businesses:server:adminList', false) or {}
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'admin', payload = {
        businesses = list,
        defaults = Config.Defaults,
        types = Config.BusinessTypes,
        brand = Config.Brand
    }})
end)

RegisterNUICallback('adminCreate', function(data, cb)
    local success, message, id = lib.callback.await('rs-businesses:server:createBusiness', false, data)
    RSClient.notify(message, success)
    cb({ success = success, message = message, id = id })
end)

RegisterNUICallback('adminDelete', function(data, cb)
    local success, message = lib.callback.await('rs-businesses:server:deleteBusiness', false, data.id)
    RSClient.notify(message, success)
    cb({ success = success, message = message })
end)
