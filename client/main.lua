local businesses, spawnedPeds, blips = {}, {}, {}
local uiOpen, currentBusiness = false, nil

RSClient = {
    businesses = businesses,
    spawnedPeds = spawnedPeds
}

local function notify(description, success)
    lib.notify({ title = 'RS Businesses', description = description, type = success == false and 'error' or 'success' })
end

local function closeUi()
    uiOpen, currentBusiness = false, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openBusiness(id)
    local data, errorMessage = lib.callback.await('rs-businesses:server:open', false, id)
    if not data then return notify(errorMessage or 'Bedrijf kon niet worden geopend.', false) end
    currentBusiness, uiOpen = id, true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', payload = data })
end

RSClient.openBusiness = openBusiness
RSClient.notify = notify

local function clearWorld()
    for _, ped in pairs(spawnedPeds) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    for _, blip in pairs(blips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    spawnedPeds, blips = {}, {}
    RSClient.spawnedPeds = spawnedPeds
end

local function buildBlips()
    for _, blip in pairs(blips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    blips = {}
    for i = 1, #businesses do
        local business = businesses[i]
        if business.blip and business.coords then
            local blip = AddBlipForCoord(business.coords.x + 0.0, business.coords.y + 0.0, business.coords.z + 0.0)
            SetBlipSprite(blip, tonumber(business.blip.sprite) or 52)
            SetBlipColour(blip, tonumber(business.blip.colour) or 2)
            SetBlipScale(blip, tonumber(business.blip.scale) or 0.75)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(business.name); EndTextCommandSetBlipName(blip)
            blips[business.id] = blip
        end
    end
end

RegisterNetEvent('rs-businesses:client:sync', function(list)
    businesses = list or {}
    RSClient.businesses = businesses
    buildBlips()
    if RSClient.refreshMainNpcs then RSClient.refreshMainNpcs() end
end)

CreateThread(function()
    businesses = lib.callback.await('rs-businesses:server:list', false) or {}
    RSClient.businesses = businesses
    buildBlips()
    if RSClient.refreshMainNpcs then RSClient.refreshMainNpcs() end
end)

CreateThread(function()
    exports.ox_target:addSphereZone({
        coords = vec3(Config.Supplier.pickup.x, Config.Supplier.pickup.y, Config.Supplier.pickup.z),
        radius = 3.0,
        options = {{
            name = 'rs_businesses_supplier',
            icon = 'fa-solid fa-boxes-stacked',
            label = 'Bedrijfsbestelling afhalen',
            onSelect = function()
                local orders = lib.callback.await('rs-businesses:server:pickupOrders', false) or {}
                if #orders == 0 then return notify('Je hebt geen bestellingen klaarstaan.', false) end
                local options = {}
                for i = 1, #orders do
                    local order = orders[i]
                    options[#options + 1] = {
                        title = ('%s · #%s'):format(order.business_name, order.id),
                        description = ('$%.2f · %s'):format(order.total, order.order_number),
                        icon = 'box',
                        onSelect = function()
                            local success, message = lib.callback.await('rs-businesses:server:receiveOrder', false, order.business_id, order.id)
                            notify(message, success)
                        end
                    }
                end
                lib.registerContext({ id = 'rs_businesses_pickup', title = 'Leverancier', options = options })
                lib.showContext('rs_businesses_pickup')
            end
        }}
    })
end)

RegisterNUICallback('close', function(_, cb) closeUi(); cb(true) end)

local callbacks = {
    purchaseBusiness = 'rs-businesses:server:purchaseBusiness',
    checkout = 'rs-businesses:server:checkout',
    updateProduct = 'rs-businesses:server:updateProduct',
    bank = 'rs-businesses:server:bank',
    settings = 'rs-businesses:server:settings',
    upgrade = 'rs-businesses:server:upgrade',
    createOrder = 'rs-businesses:server:createOrder',
    receiveOrder = 'rs-businesses:server:receiveOrder',
    orderFuel = 'rs-businesses:server:orderFuel',
    addEmployee = 'rs-businesses:server:addEmployee',
    updateEmployee = 'rs-businesses:server:updateEmployee',
    removeEmployee = 'rs-businesses:server:removeEmployee',
    hireNpc = 'rs-businesses:server:hireNpc',
    removeNpc = 'rs-businesses:server:removeNpc'
}

for nuiName, serverName in pairs(callbacks) do
    RegisterNUICallback(nuiName, function(data, cb)
        data = data or {}
        local args = data.args or {}
        local success, message, extra = lib.callback.await(serverName, false, currentBusiness, table.unpack(args))
        notify(message or (success and 'Opgeslagen.' or 'Actie mislukt.'), success)
        cb({ success = success == true, message = message, extra = extra })
        if success and currentBusiness then
            local refreshed = lib.callback.await('rs-businesses:server:open', false, currentBusiness)
            if refreshed then SendNUIMessage({ action = 'refresh', payload = refreshed }) end
        end
    end)
end

RegisterNUICallback('getPosition', function(_, cb)
    local coords, heading = GetEntityCoords(cache.ped), GetEntityHeading(cache.ped)
    cb({ x = RSBusiness.round(coords.x, 3), y = RSBusiness.round(coords.y, 3), z = RSBusiness.round(coords.z, 3), w = RSBusiness.round(heading, 2) })
end)

RegisterNetEvent('esx:onPlayerLogout', closeUi)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeUi(); clearWorld()
end)
