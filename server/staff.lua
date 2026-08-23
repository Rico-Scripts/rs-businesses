local defaultPermissions = {
    cashier = { products = false, orders = false, finance = false, employees = false, settings = false },
    employee = { products = true, orders = true, finance = false, employees = false, settings = false },
    manager = { products = true, orders = true, finance = true, employees = true, settings = true }
}

lib.callback.register('rs-businesses:server:addEmployee', function(source, businessId, targetId, role)
    local business = RSRepo.get(businessId)
    local target = ESX.GetPlayerFromId(tonumber(targetId))
    if not business or not RSRepo.permission(source, businessId, 'employees') then return false, _L('no_access') end
    if not target or target.identifier == business.owner_identifier then return false, 'Speler niet gevonden of is al eigenaar.' end
    role = defaultPermissions[role] and role or 'employee'
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rs_business_employees WHERE business_id = ?', { business.id }) or 0
    if count >= Config.Defaults.maxPlayerEmployees then return false, 'Het maximale aantal medewerkers is bereikt.' end
    MySQL.insert.await([[
        INSERT INTO rs_business_employees (business_id, identifier, name, role, permissions)
        VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE name = VALUES(name), role = VALUES(role), permissions = VALUES(permissions)
    ]], { business.id, target.identifier, target.getName(), role, json.encode(defaultPermissions[role]) })
    RSLogs.send('employee', 'Medewerker aangenomen', ('%s werkt nu bij %s'):format(target.getName(), business.name), RSLogs.playerFields(source), 'success')
    return true, _L('employee_added')
end)

lib.callback.register('rs-businesses:server:updateEmployee', function(source, businessId, identifier, role, permissions)
    if not RSRepo.permission(source, businessId, 'employees') then return false, _L('no_access') end
    role = defaultPermissions[role] and role or 'employee'
    local clean = {}
    for key in pairs(defaultPermissions.employee) do clean[key] = permissions and permissions[key] == true or false end
    MySQL.update.await('UPDATE rs_business_employees SET role = ?, permissions = ? WHERE business_id = ? AND identifier = ?', {
        role, json.encode(clean), businessId, identifier
    })
    return true, 'Medewerker bijgewerkt.'
end)

lib.callback.register('rs-businesses:server:removeEmployee', function(source, businessId, identifier)
    if not RSRepo.permission(source, businessId, 'employees') then return false, _L('no_access') end
    MySQL.update.await('DELETE FROM rs_business_employees WHERE business_id = ? AND identifier = ?', { businessId, identifier })
    return true, _L('employee_removed')
end)

lib.callback.register('rs-businesses:server:hireNpc', function(source, businessId, role, name, coords)
    local business, definition = RSRepo.get(businessId), Config.NpcRoles[role]
    if not business or not definition or not RSRepo.permission(source, businessId, 'employees') then return false, _L('no_access') end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rs_business_npcs WHERE business_id = ?', { businessId }) or 0
    if count >= Config.Defaults.maxNpcEmployees then return false, 'Het maximale aantal NPC-medewerkers is bereikt.' end
    if business.balance < definition.purchasePrice then return false, _L('business_insufficient') end
    coords = type(coords) == 'table' and coords or business.coords
    MySQL.insert.await('INSERT INTO rs_business_npcs (business_id, role, name, model, wage, coords) VALUES (?, ?, ?, ?, ?, ?)', {
        businessId, role, RSBusiness.sanitizeText(name ~= '' and name or definition.label, 40), definition.model, definition.wage, json.encode(coords)
    })
    business.balance = business.balance - definition.purchasePrice
    RSRepo.update(business.id, { balance = business.balance })
    RSRepo.transaction(business.id, 'npc_hire', -definition.purchasePrice, ('NPC aangenomen: %s'):format(definition.label), ESX.GetPlayerFromId(source).identifier)
    TriggerClientEvent('rs-businesses:client:refreshNpcs', -1)
    return true, 'NPC-medewerker aangenomen.'
end)

lib.callback.register('rs-businesses:server:removeNpc', function(source, businessId, npcId)
    if not RSRepo.permission(source, businessId, 'employees') then return false, _L('no_access') end
    MySQL.update.await('DELETE FROM rs_business_npcs WHERE id = ? AND business_id = ?', { npcId, businessId })
    TriggerClientEvent('rs-businesses:client:refreshNpcs', -1)
    return true, 'NPC-medewerker ontslagen.'
end)

lib.callback.register('rs-businesses:server:npcs', function()
    local rows = MySQL.query.await('SELECT id, business_id, role, name, model, coords FROM rs_business_npcs WHERE active = 1') or {}
    for i = 1, #rows do rows[i].coords = RSBusiness.decode(rows[i].coords) end
    return rows
end)

local function businessTick()
    local rows = MySQL.query.await('SELECT business_id, SUM(wage) wages FROM rs_business_npcs WHERE active = 1 GROUP BY business_id') or {}
    for i = 1, #rows do
        local business, wages = RSRepo.get(rows[i].business_id), tonumber(rows[i].wages) or 0
        if business and wages > 0 then
            local paid = math.min(business.balance, wages)
            business.balance = business.balance - paid
            RSRepo.update(business.id, { balance = business.balance })
            RSRepo.transaction(business.id, 'wages', -paid, 'NPC-loonkosten', 'system')
            if paid < wages then MySQL.update('UPDATE rs_business_npcs SET active = 0 WHERE business_id = ?', { business.id }) end
        end
    end
end

CreateThread(function()
    while true do
        Wait(Config.BusinessTickMinutes * 60000)
        businessTick()
    end
end)
