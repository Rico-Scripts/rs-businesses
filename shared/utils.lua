RSBusiness = RSBusiness or {}

function RSBusiness.round(value, decimals)
    local power = 10 ^ (decimals or 0)
    return math.floor((tonumber(value) or 0) * power + 0.5) / power
end

function RSBusiness.clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.max(minimum, math.min(maximum, value))
end

function RSBusiness.decode(value, fallback)
    if type(value) == 'table' then return value end
    if not value or value == '' then return fallback or {} end
    local success, result = pcall(json.decode, value)
    return success and result or (fallback or {})
end

function RSBusiness.encode(value)
    return json.encode(value or {})
end

function RSBusiness.coords(value)
    value = RSBusiness.decode(value, value)
    if type(value) ~= 'table' then return nil end
    return vec3(tonumber(value.x) or 0.0, tonumber(value.y) or 0.0, tonumber(value.z) or 0.0)
end

function RSBusiness.uuid(prefix)
    return ('%s-%d-%06d'):format(prefix or 'rs', os.time(), math.random(0, 999999))
end

function RSBusiness.sanitizeText(value, maxLength)
    value = tostring(value or ''):gsub('[\r\n\t]', ' '):gsub('%s+', ' ')
    return value:sub(1, maxLength or 80)
end
