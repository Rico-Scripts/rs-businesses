local function nearestFuelBusiness(coords)
    local nearest, distance
    for i = 1, #RSClient.businesses do
        local business = RSClient.businesses[i]
        local kind = Config.BusinessTypes[business.type]
        if kind and kind.hasFuel and business.coords then
            local current = #(coords - vec3(business.coords.x, business.coords.y, business.coords.z))
            if current <= 35.0 and (not distance or current < distance) then nearest, distance = business, current end
        end
    end
    return nearest
end

local function vehicleNearPump(pump)
    local coords = GetEntityCoords(pump)
    local vehicle = lib.getClosestVehicle(coords, 5.0, false)
    if not vehicle or vehicle == 0 then return nil end
    return vehicle
end

local function fuelVehicle(pump)
    local vehicle = vehicleNearPump(pump)
    if not vehicle then return RSClient.notify(_L('not_in_vehicle'), false) end
    local business = nearestFuelBusiness(GetEntityCoords(pump))
    if not business then return RSClient.notify('Deze pomp is niet aan een RS-tankstation gekoppeld.', false) end
    local current = GetVehicleFuelLevel(vehicle)
    local maximum = Config.Fuel.vehicleTankCapacity
    local room = math.max(0, maximum * (1.0 - current / 100.0))
    if room < Config.Fuel.minimumLitres then return RSClient.notify('De tank is al vol.', false) end
    local input = lib.inputDialog(('Tanken bij %s'):format(business.name), {{
        type = 'number', label = 'Aantal liter', description = ('$%.2f per liter · maximaal %.1f L'):format(business.fuelPrice, room),
        required = true, min = Config.Fuel.minimumLitres, max = math.min(room, Config.Fuel.maxLitresPerPurchase), precision = 2
    }})
    if not input then return end
    local litres = tonumber(input[1])
    local success, message = lib.callback.await('rs-businesses:server:buyFuel', false, business.id, litres, VehToNet(vehicle))
    if not success then return RSClient.notify(message, false) end
    local duration = math.floor(litres * Config.Fuel.secondsPerLitre * 1000)
    if lib.progressCircle({ duration = duration, label = ('%.1f liter tanken'):format(litres), canCancel = false, disable = { move = true, car = true, combat = true } }) then
        local newFuel = math.min(100.0, current + litres / maximum * 100.0)
        SetVehicleFuelLevel(vehicle, newFuel)
        Entity(vehicle).state:set('fuel', newFuel, true)
        RSClient.notify(message, true)
    end
end

CreateThread(function()
    if not Config.Fuel.enabled then return end
    exports.ox_target:addModel(Config.Fuel.pumpModels, {{
        name = 'rs_businesses_fuel',
        icon = 'fa-solid fa-gas-pump',
        label = 'Voertuig tanken',
        distance = 2.5,
        onSelect = function(data) fuelVehicle(data.entity) end
    }})
end)
