local function useTablet(source)
    source = tonumber(source)
    if not source or source <= 0 then return false end
    TriggerClientEvent('rs-businesses:client:useTablet', source)
    return true
end

lib.callback.register('rs-businesses:server:tabletBusinesses', function(source)
    local player = ESX.GetPlayerFromId(source)
    if not player then return {} end

    local rows = MySQL.query.await([[
        SELECT b.id, b.name, b.type, b.is_open,
               CASE WHEN b.owner_identifier = ? THEN 1 ELSE 0 END AS is_owner,
               e.role
        FROM rs_businesses b
        LEFT JOIN rs_business_employees e
          ON e.business_id = b.id AND e.identifier = ?
        WHERE b.owner_identifier = ? OR e.identifier IS NOT NULL
        ORDER BY b.name ASC
    ]], { player.identifier, player.identifier, player.identifier }) or {}

    for i = 1, #rows do
        rows[i].id = tonumber(rows[i].id)
        rows[i].isOwner = tonumber(rows[i].is_owner) == 1 or rows[i].is_owner == true
        rows[i].isOpen = tonumber(rows[i].is_open) == 1 or rows[i].is_open == true
        rows[i].is_owner, rows[i].is_open = nil, nil
    end
    return rows
end)

exports('businessTablet', function(event, _, inventory)
    if event ~= 'usingItem' then return end
    local source = type(inventory) == 'table' and inventory.id or inventory
    return useTablet(source)
end)

CreateThread(function()
    while not ESX do Wait(0) end
    ESX.RegisterUsableItem(Config.Tablet.item, function(source)
        useTablet(source)
    end)
end)
