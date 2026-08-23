local function productRows(businessId)
    local stock = MySQL.query.await('SELECT item, amount, sale_price FROM rs_business_stock WHERE business_id = ?', { businessId }) or {}
    local map = {}
    for i = 1, #stock do map[stock[i].item] = stock[i] end
    local result = {}
    for item, product in pairs(Config.Products) do
        local row = map[item] or {}
        result[#result + 1] = {
            item = item,
            label = product.label,
            category = product.category,
            purchasePrice = product.purchasePrice,
            price = tonumber(row.sale_price) or product.suggestedPrice,
            maxPrice = product.maxPrice,
            stock = tonumber(row.amount) or 0
        }
    end
    table.sort(result, function(a, b) return a.label < b.label end)
    return result
end

local function ownerData(source, business)
    local player = ESX.GetPlayerFromId(source)
    local isOwner = RSRepo.isOwner(player, business)
    local employee = not isOwner and RSRepo.employee(player, business.id) or nil
    if not isOwner and not employee then return nil end
    local employees = MySQL.query.await('SELECT identifier, name, role, permissions, hired_at FROM rs_business_employees WHERE business_id = ?', { business.id }) or {}
    local npcs = MySQL.query.await('SELECT id, role, name, model, wage, active, coords FROM rs_business_npcs WHERE business_id = ?', { business.id }) or {}
    local orders = MySQL.query.await('SELECT * FROM rs_business_orders WHERE business_id = ? ORDER BY id DESC LIMIT 30', { business.id }) or {}
    local transactions = MySQL.query.await('SELECT * FROM rs_business_transactions WHERE business_id = ? ORDER BY id DESC LIMIT ?', { business.id, Config.MaxTransactionsPerRequest }) or {}
    local stats = MySQL.single.await([[
        SELECT COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) income,
               COALESCE(ABS(SUM(CASE WHEN amount < 0 THEN amount ELSE 0 END)), 0) expenses
        FROM rs_business_transactions WHERE business_id = ? AND created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ]], { business.id }) or {}
    for i = 1, #employees do employees[i].permissions = RSBusiness.decode(employees[i].permissions) end
    for i = 1, #npcs do npcs[i].coords = RSBusiness.decode(npcs[i].coords) end
    for i = 1, #orders do orders[i].items = RSBusiness.decode(orders[i].items) end
    return {
        isOwner = isOwner,
        role = isOwner and 'owner' or employee.role,
        permissions = isOwner and { all = true } or RSBusiness.decode(employee.permissions),
        employees = employees,
        npcs = npcs,
        orders = orders,
        transactions = transactions,
        stats = { income = tonumber(stats.income) or 0, expenses = tonumber(stats.expenses) or 0 }
    }
end

lib.callback.register('rs-businesses:server:open', function(source, businessId)
    local business = RSRepo.get(businessId)
    local player = ESX.GetPlayerFromId(source)
    if not business or not player or not RSRepo.near(source, business) then return nil, _L('too_far') end
    return {
        business = business,
        products = productRows(business.id),
        management = ownerData(source, business),
        playerMoney = player.getAccount(Config.MoneyAccount).money,
        config = {
            businessTypes = Config.BusinessTypes,
            npcRoles = Config.NpcRoles,
            upgrades = Config.Upgrades,
            brand = Config.Brand
        }
    }
end)

lib.callback.register('rs-businesses:server:purchaseBusiness', function(source, businessId)
    local business = RSRepo.get(businessId)
    local player = ESX.GetPlayerFromId(source)
    if not business or not player or not RSRepo.near(source, business) then return false, _L('invalid_data') end
    if business.owner_identifier then return false, 'Dit bedrijf is al verkocht.' end
    local account = player.getAccount(Config.MoneyAccount)
    if not account or account.money < business.purchase_price then return false, _L('insufficient_money') end

    local affected = MySQL.update.await('UPDATE rs_businesses SET owner_identifier = ?, owner_name = ?, balance = ? WHERE id = ? AND owner_identifier IS NULL', {
        player.identifier, player.getName(), Config.Defaults.startBalance, business.id
    })
    if affected ~= 1 then return false, 'Dit bedrijf is zojuist door iemand anders gekocht.' end
    player.removeAccountMoney(Config.MoneyAccount, business.purchase_price, 'Bedrijf gekocht')
    business.owner_identifier = player.identifier
    business.owner_name = player.getName()
    business.balance = Config.Defaults.startBalance
    RSRepo.transaction(business.id, 'purchase', -business.purchase_price, 'Bedrijf gekocht', player.identifier)
    RSLogs.send('purchase', 'Bedrijf gekocht', ('%s heeft %s gekocht.'):format(player.getName(), business.name), {
        Bedrijf = business.name, Bedrag = ('$%s'):format(business.purchase_price), Identifier = player.identifier
    }, 'success')
    TriggerClientEvent('rs-businesses:client:sync', -1, RSRepo.publicList())
    return true, _L('purchased')
end)

lib.callback.register('rs-businesses:server:checkout', function(source, businessId, cart, payment)
    local business = RSRepo.get(businessId)
    local player = ESX.GetPlayerFromId(source)
    if not business or not player or not RSRepo.near(source, business) or not business.is_open then return false, 'De winkel is gesloten.' end
    if not business.owner_identifier then return false, 'Dit bedrijf heeft nog geen eigenaar.' end
    if type(cart) ~= 'table' or #cart == 0 or #cart > 20 then return false, _L('invalid_data') end

    local merged, total = {}, 0
    for i = 1, #cart do
        local item, quantity = tostring(cart[i].item or ''), math.floor(tonumber(cart[i].quantity) or 0)
        if Config.Products[item] and quantity > 0 and quantity <= 100 then merged[item] = (merged[item] or 0) + quantity end
    end
    local rows = MySQL.query.await('SELECT item, amount, sale_price FROM rs_business_stock WHERE business_id = ?', { business.id }) or {}
    local stock = {}; for i = 1, #rows do stock[rows[i].item] = rows[i] end
    for item, quantity in pairs(merged) do
        local row = stock[item]
        if not row or tonumber(row.amount) < quantity then return false, ('Onvoldoende voorraad: %s'):format(Config.Products[item].label) end
        total = total + (tonumber(row.sale_price) or Config.Products[item].suggestedPrice) * quantity
        if not exports.ox_inventory:CanCarryItem(source, item, quantity) then return false, ('Je kunt %s niet dragen.'):format(Config.Products[item].label) end
    end
    total = RSBusiness.round(total, 2)
    local accountName = payment == 'cash' and 'money' or Config.MoneyAccount
    local account = player.getAccount(accountName)
    if not account or account.money < total then return false, _L('insufficient_money') end

    local queries = {}
    for item, quantity in pairs(merged) do
        queries[#queries + 1] = { query = 'UPDATE rs_business_stock SET amount = amount - ? WHERE business_id = ? AND item = ? AND amount >= ?', values = { quantity, business.id, item, quantity } }
    end
    if not MySQL.transaction.await(queries) then return false, _L('insufficient_stock') end
    player.removeAccountMoney(accountName, total, ('Aankoop bij %s'):format(business.name))
    for item, quantity in pairs(merged) do exports.ox_inventory:AddItem(source, item, quantity) end
    local net = total * (1.0 - business.tax_percent / 100.0)
    business.balance = business.balance + net
    RSRepo.update(business.id, { balance = business.balance })
    RSRepo.transaction(business.id, 'sale', net, ('Klantverkoop (%d producten)'):format(#cart), player.identifier)
    RSLogs.send('checkout', 'Winkelaankoop', ('Aankoop bij %s'):format(business.name), {
        Speler = player.getName(), Bedrag = ('$%.2f'):format(total), Betaalmethode = accountName
    }, 'success')
    return true, _L('sold')
end)

lib.callback.register('rs-businesses:server:updateProduct', function(source, businessId, item, price)
    local business = RSRepo.get(businessId)
    local product = Config.Products[item]
    if not business or not product or not RSRepo.permission(source, business.id, 'products') then return false, _L('no_access') end
    price = RSBusiness.clamp(price, product.purchasePrice, product.maxPrice)
    MySQL.insert.await([[
        INSERT INTO rs_business_stock (business_id, item, amount, sale_price) VALUES (?, ?, 0, ?)
        ON DUPLICATE KEY UPDATE sale_price = VALUES(sale_price)
    ]], { business.id, item, price })
    return true, _L('price_updated')
end)

lib.callback.register('rs-businesses:server:bank', function(source, businessId, action, amount)
    local business = RSRepo.get(businessId)
    local player = ESX.GetPlayerFromId(source)
    if not business or not player or not RSRepo.permission(source, business.id, 'finance') then return false, _L('no_access') end
    amount = RSBusiness.round(tonumber(amount) or 0, 2)
    if amount <= 0 or amount > 10000000 then return false, _L('invalid_data') end
    if action == 'deposit' then
        local account = player.getAccount(Config.MoneyAccount)
        if account.money < amount then return false, _L('insufficient_money') end
        player.removeAccountMoney(Config.MoneyAccount, amount, 'Storting bedrijfsrekening')
        business.balance = business.balance + amount
    elseif action == 'withdraw' then
        if business.balance < amount then return false, _L('business_insufficient') end
        business.balance = business.balance - amount
        player.addAccountMoney(Config.MoneyAccount, amount, 'Opname bedrijfsrekening')
    else return false, _L('invalid_data') end
    RSRepo.update(business.id, { balance = business.balance })
    RSRepo.transaction(business.id, action, action == 'deposit' and amount or -amount, 'Bedrijfsrekening', player.identifier)
    RSLogs.send('bank', 'Bedrijfsrekening', ('%s: $%.2f'):format(action, amount), RSLogs.playerFields(source), 'info')
    return true, 'Transactie uitgevoerd.'
end)

lib.callback.register('rs-businesses:server:settings', function(source, businessId, data)
    local business = RSRepo.get(businessId)
    if not business or not RSRepo.permission(source, business.id, 'settings') then return false, _L('no_access') end
    local values = {
        name = RSBusiness.sanitizeText(data.name or business.name, 48),
        is_open = data.isOpen == true,
        fuel_sell_price = RSBusiness.clamp(data.fuelPrice or business.fuel_sell_price, business.fuel_buy_price, 10.0)
    }
    RSRepo.update(business.id, values)
    TriggerClientEvent('rs-businesses:client:sync', -1, RSRepo.publicList())
    return true, _L('settings_saved')
end)

lib.callback.register('rs-businesses:server:upgrade', function(source, businessId, key)
    local business, upgrade = RSRepo.get(businessId), Config.Upgrades[key]
    if not business or not upgrade or not RSRepo.permission(source, businessId, 'settings') then return false, _L('no_access') end
    local upgrades = business.upgrades or {}
    if upgrades[key] then return false, 'Deze upgrade is al actief.' end
    if upgrade.requires and not upgrades[upgrade.requires] then return false, 'De vorige upgrade is eerst vereist.' end
    if business.balance < upgrade.price then return false, _L('business_insufficient') end
    business.balance = business.balance - upgrade.price
    upgrades[key] = os.time()
    RSRepo.update(business.id, { balance = business.balance, upgrades = upgrades })
    RSRepo.transaction(business.id, 'upgrade', -upgrade.price, upgrade.label, ESX.GetPlayerFromId(source).identifier)
    return true, ('%s aangeschaft.'):format(upgrade.label)
end)
