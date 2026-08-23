local function orderReduction(businessId, business)
    local reduction = 0
    local npcs = MySQL.query.await('SELECT role FROM rs_business_npcs WHERE business_id = ? AND active = 1', { businessId }) or {}
    for i = 1, #npcs do reduction = reduction + (Config.NpcRoles[npcs[i].role] and Config.NpcRoles[npcs[i].role].orderSpeed or 0) end
    if business.upgrades and business.upgrades.express then reduction = reduction + 25 end
    return math.min(reduction, 65)
end

local function hasShop(business)
    local definition = business and Config.BusinessTypes[business.type]
    return definition and definition.hasShop == true
end

lib.callback.register('rs-businesses:server:createOrder', function(source, businessId, items, mode)
    local business = RSRepo.get(businessId)
    local player = ESX.GetPlayerFromId(source)
    if not business or not hasShop(business) or not player or not RSRepo.permission(source, businessId, 'orders') then return false, _L('no_access') end
    if type(items) ~= 'table' or #items == 0 or #items > 30 then return false, _L('invalid_data') end
    local clean, total, units = {}, 0, 0
    for i = 1, #items do
        local product = Config.Products[items[i].item]
        local quantity = math.floor(tonumber(items[i].quantity) or 0)
        if product and quantity > 0 and quantity <= 1000 then
            clean[#clean + 1] = { item = items[i].item, label = product.label, quantity = quantity, unitPrice = product.purchasePrice }
            total = total + product.purchasePrice * quantity
            units = units + quantity
        end
    end
    if #clean == 0 or total <= 0 then return false, _L('invalid_data') end
    local deliveryFee = mode == 'delivery' and math.max(250, total * 0.08) or 0
    total = RSBusiness.round(total + deliveryFee, 2)
    if business.balance < total then return false, _L('business_insufficient') end
    local reduction = orderReduction(business.id, business)
    local delay = math.max(1, math.floor(Config.Defaults.orderDelayMinutes * (100 - reduction) / 100))
    local status = mode == 'pickup' and 'ready_pickup' or 'pending'
    local readyAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + delay * 60)
    local orderId = MySQL.insert.await([[
        INSERT INTO rs_business_orders (business_id, order_number, items, total, delivery_mode, status, ready_at, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { business.id, RSBusiness.uuid('ORD'), json.encode(clean), total, mode == 'pickup' and 'pickup' or 'delivery', status, readyAt, player.identifier })
    business.balance = business.balance - total
    RSRepo.update(business.id, { balance = business.balance })
    RSRepo.transaction(business.id, 'stock_order', -total, ('Voorraadbestelling #%d (%d stuks)'):format(orderId, units), player.identifier)
    RSLogs.send('order', 'Voorraad besteld', ('Bestelling voor %s'):format(business.name), {
        Order = orderId, Bedrag = ('$%.2f'):format(total), Levering = mode, Stuks = units
    }, 'info')
    return true, _L('order_created')
end)

local function receiveOrder(source, business, order)
    local items = RSBusiness.decode(order.items)
    local queries = {}
    for i = 1, #items do
        local suggested = Config.Products[items[i].item] and Config.Products[items[i].item].suggestedPrice or 1
        queries[#queries + 1] = {
            query = [[INSERT INTO rs_business_stock (business_id, item, amount, sale_price) VALUES (?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE amount = amount + VALUES(amount)]],
            values = { business.id, items[i].item, items[i].quantity, suggested }
        }
    end
    queries[#queries + 1] = { query = 'UPDATE rs_business_orders SET status = ? WHERE id = ? AND status IN (?, ?)', values = { 'received', order.id, 'ready', 'ready_pickup' } }
    if not MySQL.transaction.await(queries) then return false, 'Levering kon niet worden verwerkt.' end
    RSLogs.send('delivery', 'Voorraad ontvangen', ('Bestelling #%d geleverd bij %s'):format(order.id, business.name), RSLogs.playerFields(source), 'success')
    return true, _L('order_received')
end

lib.callback.register('rs-businesses:server:receiveOrder', function(source, businessId, orderId)
    local business = RSRepo.get(businessId)
    if not business or not hasShop(business) or not RSRepo.permission(source, businessId, 'orders') then return false, _L('no_access') end
    local order = MySQL.single.await('SELECT * FROM rs_business_orders WHERE id = ? AND business_id = ?', { orderId, business.id })
    if not order or (order.status ~= 'ready' and order.status ~= 'ready_pickup') then return false, 'Deze bestelling is nog niet beschikbaar.' end
    local pedCoords = GetEntityCoords(GetPlayerPed(source))
    local target = order.delivery_mode == 'pickup' and vec3(Config.Supplier.pickup.x, Config.Supplier.pickup.y, Config.Supplier.pickup.z) or RSBusiness.coords(business.delivery_coords)
    if not target or #(pedCoords - target) > 12.0 then return false, _L('too_far') end
    return receiveOrder(source, business, order)
end)

lib.callback.register('rs-businesses:server:pickupOrders', function(source)
    local player = ESX.GetPlayerFromId(source)
    if not player then return {} end
    local rows = MySQL.query.await([[
        SELECT o.id, o.business_id, o.order_number, o.total, o.ready_at, b.name business_name
        FROM rs_business_orders o
        INNER JOIN rs_businesses b ON b.id = o.business_id
        LEFT JOIN rs_business_employees e ON e.business_id = b.id AND e.identifier = ?
        WHERE o.status = 'ready_pickup' AND b.type IN ('shop', 'combined')
          AND (b.owner_identifier = ? OR e.identifier IS NOT NULL)
        ORDER BY o.id DESC
    ]], { player.identifier, player.identifier }) or {}
    return rows
end)

CreateThread(function()
    while true do
        Wait(60000)
        MySQL.update('UPDATE rs_business_orders SET status = ? WHERE status = ? AND ready_at <= NOW()', { 'ready', 'pending' })
    end
end)
