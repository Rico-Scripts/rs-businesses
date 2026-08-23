lib.callback.register('rs-businesses:server:buyFuel', function(source, businessId, litres, netId)
    local business = RSRepo.get(businessId)
    local player = ESX.GetPlayerFromId(source)
    local businessType = business and Config.BusinessTypes[business.type]
    if not business or not player or not businessType or not businessType.hasFuel then return false, _L('invalid_data') end
    if not business.is_open or not business.owner_identifier then return false, 'Dit tankstation is gesloten.' end
    if not RSRepo.near(source, business, 18.0) then return false, _L('too_far') end
    litres = RSBusiness.round(RSBusiness.clamp(litres, Config.Fuel.minimumLitres, Config.Fuel.maxLitresPerPurchase), 2)
    if business.fuel_stock < litres then return false, _L('fuel_unavailable') end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle <= 0 or GetEntityType(vehicle) ~= 2 then return false, _L('not_in_vehicle') end
    local playerCoords, vehicleCoords = GetEntityCoords(GetPlayerPed(source)), GetEntityCoords(vehicle)
    if #(playerCoords - vehicleCoords) > 10.0 then return false, _L('not_in_vehicle') end
    local total = RSBusiness.round(litres * business.fuel_sell_price, 2)
    local account = player.getAccount(Config.MoneyAccount)
    if not account or account.money < total then return false, _L('insufficient_money') end

    player.removeAccountMoney(Config.MoneyAccount, total, ('Tanken bij %s'):format(business.name))
    business.fuel_stock = business.fuel_stock - litres
    local net = total * (1.0 - business.tax_percent / 100.0)
    business.balance = business.balance + net
    RSRepo.update(business.id, { fuel_stock = business.fuel_stock, balance = business.balance })
    RSRepo.transaction(business.id, 'fuel_sale', net, ('%.2f liter brandstof'):format(litres), player.identifier)
    RSLogs.send('fuel_sale', 'Brandstof verkocht', ('%.2f liter bij %s'):format(litres, business.name), {
        Speler = player.getName(), Bedrag = ('$%.2f'):format(total), Liter = litres
    }, 'success')
    return true, _L('fuel_complete'), { litres = litres, total = total, stock = business.fuel_stock }
end)

lib.callback.register('rs-businesses:server:orderFuel', function(source, businessId, litres)
    local business = RSRepo.get(businessId)
    local businessType = business and Config.BusinessTypes[business.type]
    if not business or not businessType or not businessType.hasFuel or not RSRepo.permission(source, businessId, 'orders') then return false, _L('no_access') end
    litres = RSBusiness.round(tonumber(litres) or 0, 2)
    local available = business.fuel_capacity - business.fuel_stock
    if litres <= 0 or litres > available then return false, ('Er past maximaal %.0f liter in de tank.'):format(available) end
    local total = RSBusiness.round(litres * business.fuel_buy_price, 2)
    if business.balance < total then return false, _L('business_insufficient') end
    business.balance = business.balance - total
    business.fuel_stock = business.fuel_stock + litres
    RSRepo.update(business.id, { balance = business.balance, fuel_stock = business.fuel_stock })
    RSRepo.transaction(business.id, 'fuel_order', -total, ('%.2f liter brandstof ingekocht'):format(litres), ESX.GetPlayerFromId(source).identifier)
    RSLogs.send('fuel_order', 'Brandstof ingekocht', ('%.2f liter voor %s'):format(litres, business.name), RSLogs.playerFields(source), 'info')
    TriggerClientEvent('rs-businesses:client:sync', -1, RSRepo.publicList())
    return true, 'Brandstofvoorraad aangevuld.'
end)
