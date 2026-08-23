RSLogs = {}

local colours = {
    info = 5793266,
    success = 5763719,
    warning = 16760576,
    danger = 15548997
}

function RSLogs.send(action, title, description, fields, level)
    local payload = {
        resource = GetCurrentResourceName(),
        category = Config.Logging.channel,
        action = action,
        title = title,
        description = description,
        fields = fields or {},
        colour = colours[level or 'info'],
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ')
    }

    if GetResourceState(Config.Logging.resource) == 'started' then
        local attempts = {
            function() return exports[Config.Logging.resource]:Log(payload) end,
            function() return exports[Config.Logging.resource]:SendLog(payload.category, payload.title, payload.description, payload.fields, payload.colour) end,
            function() return exports[Config.Logging.resource]:CreateLog(payload) end
        }
        for i = 1, #attempts do
            local ok = pcall(attempts[i])
            if ok then return end
        end
    end

    if Config.Logging.webhook == '' then
        if Config.Debug then print(('[rs-businesses] log: %s - %s'):format(title, description)) end
        return
    end

    local embedFields = {}
    for key, value in pairs(fields or {}) do
        embedFields[#embedFields + 1] = { name = tostring(key), value = tostring(value), inline = true }
    end
    PerformHttpRequest(Config.Logging.webhook, function() end, 'POST', json.encode({
        username = 'RS Businesses',
        embeds = {{
            title = title,
            description = description,
            color = payload.colour,
            fields = embedFields,
            footer = { text = action },
            timestamp = payload.timestamp
        }}
    }), { ['Content-Type'] = 'application/json' })
end

function RSLogs.playerFields(source)
    local player = ESX.GetPlayerFromId(source)
    return {
        Speler = player and player.getName() or GetPlayerName(source) or 'Onbekend',
        Identifier = player and player.identifier or 'onbekend',
        ServerID = source
    }
end
