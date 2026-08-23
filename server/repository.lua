RSRepo = { businesses = {} }

local function hydrate(row)
    row.id = tonumber(row.id)
    row.purchase_price = tonumber(row.purchase_price) or 0
    row.balance = tonumber(row.balance) or 0
    row.tax_percent = tonumber(row.tax_percent) or 0
    row.fuel_stock = tonumber(row.fuel_stock) or 0
    row.fuel_capacity = tonumber(row.fuel_capacity) or 0
    row.fuel_buy_price = tonumber(row.fuel_buy_price) or 0
    row.fuel_sell_price = tonumber(row.fuel_sell_price) or 0
    row.coords = RSBusiness.decode(row.coords)
    row.management_coords = RSBusiness.decode(row.management_coords)
    row.delivery_coords = RSBusiness.decode(row.delivery_coords)
    row.npc = RSBusiness.decode(row.npc)
    row.blip = RSBusiness.decode(row.blip)
    row.settings = RSBusiness.decode(row.settings)
    row.upgrades = RSBusiness.decode(row.upgrades)
    row.is_open = row.is_open == 1 or row.is_open == true
    return row
end

function RSRepo.reload()
    local rows = MySQL.query.await('SELECT * FROM rs_businesses') or {}
    RSRepo.businesses = {}
    for i = 1, #rows do RSRepo.businesses[tonumber(rows[i].id)] = hydrate(rows[i]) end
    TriggerClientEvent('rs-businesses:client:sync', -1, RSRepo.publicList())
end

function RSRepo.get(id)
    return RSRepo.businesses[tonumber(id)]
end

function RSRepo.publicList()
    local result = {}
    for id, business in pairs(RSRepo.businesses) do
        result[#result + 1] = {
            id = id,
            name = business.name,
            type = business.type,
            owner = business.owner_identifier ~= nil,
            purchasePrice = business.purchase_price,
            coords = business.coords,
            managementCoords = business.management_coords,
            deliveryCoords = business.delivery_coords,
            npc = business.npc,
            blip = business.blip,
            isOpen = business.is_open,
            fuelPrice = business.fuel_sell_price,
            fuelStock = business.fuel_stock
        }
    end
    return result
end

function RSRepo.update(id, values)
    local business = RSRepo.get(id)
    if not business then return false end
    local sets, params = {}, {}
    for key, value in pairs(values) do
        local stored = type(value) == 'table' and json.encode(value) or value
        sets[#sets + 1] = ('`%s` = ?'):format(key)
        params[#params + 1] = stored
        business[key] = value
    end
    params[#params + 1] = id
    MySQL.update.await(('UPDATE rs_businesses SET %s WHERE id = ?'):format(table.concat(sets, ', ')), params)
    return true
end

function RSRepo.isOwner(player, business)
    return player and business and business.owner_identifier == player.identifier
end

function RSRepo.employee(player, businessId)
    if not player then return nil end
    return MySQL.single.await('SELECT * FROM rs_business_employees WHERE business_id = ? AND identifier = ?', { businessId, player.identifier })
end

function RSRepo.permission(source, businessId, permission)
    local player = ESX.GetPlayerFromId(source)
    local business = RSRepo.get(businessId)
    if not player or not business then return false end
    if RSRepo.isOwner(player, business) then return true end
    local employee = RSRepo.employee(player, businessId)
    if not employee then return false end
    local permissions = RSBusiness.decode(employee.permissions)
    return permissions[permission] == true
end

function RSRepo.near(source, business, maxDistance)
    local ped = GetPlayerPed(source)
    if ped <= 0 then return false end
    local coords = GetEntityCoords(ped)
    local target = RSBusiness.coords(business.coords)
    return target and #(coords - target) <= (maxDistance or Config.ServerValidationDistance)
end

function RSRepo.transaction(id, kind, amount, description, actor)
    MySQL.insert('INSERT INTO rs_business_transactions (business_id, type, amount, description, actor_identifier) VALUES (?, ?, ?, ?, ?)', {
        id, kind, RSBusiness.round(amount, 2), RSBusiness.sanitizeText(description, 160), actor
    })
end
