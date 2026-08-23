RegisterNetEvent('rs-businesses:client:openAdmin', function()
    local allowed = lib.callback.await('rs-businesses:server:isAdmin', false)
    if not allowed then return RSClient.notify(_L('no_access'), false) end
    local list = lib.callback.await('rs-businesses:server:adminList', false) or {}
    local workpoints = lib.callback.await('rs-businesses:server:adminWorkpoints', false) or {}
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'admin', payload = {
        businesses = list,
        defaults = Config.Defaults,
        types = Config.BusinessTypes,
        workpoints = workpoints,
        npcRoles = Config.NpcRoles,
        npcScenarios = Config.NpcAI.scenarios,
        brand = Config.Brand
    }})
end)

RegisterNUICallback('adminAddWorkpoint', function(data, cb)
    local success, message, id = lib.callback.await('rs-businesses:server:addWorkpoint', false, data)
    local workpoints = success and (lib.callback.await('rs-businesses:server:adminWorkpoints', false) or {}) or nil
    RSClient.notify(message, success)
    cb({ success = success, message = message, id = id, workpoints = workpoints })
end)

RegisterNUICallback('adminDeleteWorkpoint', function(data, cb)
    local success, message = lib.callback.await('rs-businesses:server:deleteWorkpoint', false, data.id)
    local workpoints = success and (lib.callback.await('rs-businesses:server:adminWorkpoints', false) or {}) or nil
    RSClient.notify(message, success)
    cb({ success = success, message = message, workpoints = workpoints })
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
