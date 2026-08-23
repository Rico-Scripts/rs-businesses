local function isAdmin(source)
    if source == 0 then return true end
    local player = ESX.GetPlayerFromId(source)
    return player and Config.AdminGroups[player.getGroup()] == true
end

lib.callback.register('rs-businesses:server:isAdmin', function(source) return isAdmin(source) end)

lib.callback.register('rs-businesses:server:adminList', function(source)
    if not isAdmin(source) then return nil end
    return RSRepo.publicList()
end)

lib.callback.register('rs-businesses:server:adminWorkpoints', function(source)
    if not isAdmin(source) then return nil end
    local rows = MySQL.query.await([[
        SELECT w.id, w.business_id, w.role, w.sequence, w.label, w.coords, w.scenario, w.duration_ms,
               b.name business_name
        FROM rs_business_workpoints w
        INNER JOIN rs_businesses b ON b.id = w.business_id
        ORDER BY b.name, w.role, w.sequence
    ]]) or {}
    for i = 1, #rows do
        rows[i].coords = RSBusiness.decode(rows[i].coords)
        rows[i].duration_ms = tonumber(rows[i].duration_ms) or Config.NpcAI.workDurationMs
    end
    return rows
end)

local function scenarioAllowed(role, scenario)
    local available = Config.NpcAI.scenarios[role] or {}
    for i = 1, #available do if available[i] == scenario then return true end end
    return false
end

lib.callback.register('rs-businesses:server:addWorkpoint', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false, _L('no_access') end
    local business = RSRepo.get(data.businessId)
    local role = tostring(data.role or '')
    local coords = data.coords
    if not business or not Config.NpcRoles[role] or type(coords) ~= 'table' or not tonumber(coords.x) then
        return false, _L('invalid_data')
    end
    local scenario = tostring(data.scenario or '')
    if not scenarioAllowed(role, scenario) then return false, 'Ongeldige werkanimatie.' end
    local sequence = (MySQL.scalar.await('SELECT COALESCE(MAX(sequence), 0) + 1 FROM rs_business_workpoints WHERE business_id = ? AND role = ?', { business.id, role }) or 1)
    local id = MySQL.insert.await([[
        INSERT INTO rs_business_workpoints (business_id, role, sequence, label, coords, scenario, duration_ms)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        business.id, role, sequence, RSBusiness.sanitizeText(data.label ~= '' and data.label or ('Werkpunt %s'):format(sequence), 48),
        json.encode(coords), scenario, math.floor(RSBusiness.clamp(data.durationMs, 2500, 60000))
    })
    TriggerClientEvent('rs-businesses:client:refreshNpcs', -1)
    RSLogs.send('npc_workpoint', 'NPC-werkpunt geplaatst', ('%s · %s · #%s'):format(business.name, role, sequence), RSLogs.playerFields(source), 'info')
    return true, 'Werkpunt geplaatst.', id
end)

lib.callback.register('rs-businesses:server:deleteWorkpoint', function(source, id)
    if not isAdmin(source) then return false, _L('no_access') end
    local affected = MySQL.update.await('DELETE FROM rs_business_workpoints WHERE id = ?', { tonumber(id) or 0 })
    if affected < 1 then return false, 'Werkpunt niet gevonden.' end
    TriggerClientEvent('rs-businesses:client:refreshNpcs', -1)
    return true, 'Werkpunt verwijderd.'
end)

lib.callback.register('rs-businesses:server:createBusiness', function(source, data)
    if not isAdmin(source) or type(data) ~= 'table' then return false, _L('no_access') end
    if not Config.BusinessTypes[data.type] then return false, _L('invalid_data') end
    local coords = data.coords
    if type(coords) ~= 'table' or not tonumber(coords.x) then return false, _L('invalid_data') end
    local name = RSBusiness.sanitizeText(data.name, 48)
    if #name < 2 then return false, 'Vul een geldige bedrijfsnaam in.' end
    local npc = data.npc or { x = coords.x, y = coords.y, z = coords.z, w = coords.w, model = Config.Defaults.npcModel }
    local management = data.managementCoords or coords
    local delivery = data.deliveryCoords or coords
    local blip = data.blip or Config.Defaults.blip
    local id = MySQL.insert.await([[
        INSERT INTO rs_businesses
        (name, type, purchase_price, balance, tax_percent, coords, management_coords, delivery_coords, npc, blip,
         fuel_stock, fuel_capacity, fuel_buy_price, fuel_sell_price, settings, upgrades)
        VALUES (?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        name, data.type, RSBusiness.clamp(data.purchasePrice, 1, 100000000), Config.Defaults.taxPercent,
        json.encode(coords), json.encode(management), json.encode(delivery), json.encode(npc), json.encode(blip),
        Config.Defaults.fuelStock, Config.Defaults.fuelCapacity, Config.Defaults.fuelBuyPrice, Config.Defaults.fuelSellPrice,
        json.encode({ openWhenOwnerOffline = Config.Defaults.openWhenOwnerOffline }), '{}'
    })
    RSRepo.reload()
    RSLogs.send('admin_create', 'Bedrijf aangemaakt', ('%s is als %s aangemaakt.'):format(name, data.type), RSLogs.playerFields(source), 'success')
    return true, _L('created'), id
end)

lib.callback.register('rs-businesses:server:updateLocation', function(source, id, data)
    if not isAdmin(source) then return false, _L('no_access') end
    local business = RSRepo.get(id)
    if not business then return false, 'Bedrijf niet gevonden.' end
    local allowed, values = { name = true, purchase_price = true, coords = true, management_coords = true, delivery_coords = true, npc = true, blip = true }, {}
    for key, value in pairs(data or {}) do if allowed[key] then values[key] = value end end
    RSRepo.update(id, values)
    TriggerClientEvent('rs-businesses:client:sync', -1, RSRepo.publicList())
    return true, 'Locatie bijgewerkt.'
end)

lib.callback.register('rs-businesses:server:deleteBusiness', function(source, id)
    if not isAdmin(source) then return false, _L('no_access') end
    local business = RSRepo.get(id)
    if not business then return false, 'Bedrijf niet gevonden.' end
    MySQL.update.await('DELETE FROM rs_businesses WHERE id = ?', { id })
    RSRepo.reload()
    RSLogs.send('admin_delete', 'Bedrijf verwijderd', business.name, RSLogs.playerFields(source), 'danger')
    return true, _L('deleted')
end)

RegisterCommand(Config.AdminCommand, function(source)
    if not isAdmin(source) then return TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = _L('no_access') }) end
    TriggerClientEvent('rs-businesses:client:openAdmin', source)
end, false)
