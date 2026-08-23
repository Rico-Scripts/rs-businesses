local tabletObject

local function stopTablet()
    ClearPedSecondaryTask(cache.ped)
    if tabletObject and DoesEntityExist(tabletObject) then
        DetachEntity(tabletObject, true, true)
        DeleteObject(tabletObject)
        if DoesEntityExist(tabletObject) then DeleteEntity(tabletObject) end
    end
    tabletObject = nil
end

local function startTablet()
    stopTablet()
    local settings, animation = Config.Tablet, Config.Tablet.animation
    local hash = joaat(settings.model)
    lib.requestModel(hash, 10000)
    lib.requestAnimDict(animation.dict, 10000)

    TaskPlayAnim(cache.ped, animation.dict, animation.clip, 3.0, 3.0, -1, 49, 0.0, false, false, false)
    local coords = GetEntityCoords(cache.ped)
    tabletObject = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(tabletObject, false, false)
    local offset, rotation = animation.offset, animation.rotation
    AttachEntityToEntity(
        tabletObject, cache.ped, GetPedBoneIndex(cache.ped, animation.bone),
        offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z,
        true, true, false, true, 1, true
    )
    SetModelAsNoLongerNeeded(hash)
end

RSClient.startTablet = startTablet
RSClient.stopTablet = stopTablet

local function openFromTablet()
    if IsPedDeadOrDying(cache.ped, true) then
        return RSClient.notify('Je kunt de tablet nu niet gebruiken.', false)
    end

    local businesses = lib.callback.await('rs-businesses:server:tabletBusinesses', false) or {}
    if #businesses == 0 then
        return RSClient.notify('Je bezit geen bedrijf en bent nergens als medewerker geregistreerd.', false)
    end
    if #businesses == 1 then
        return RSClient.openBusiness(businesses[1].id, 'tablet')
    end

    local options = {}
    for i = 1, #businesses do
        local business = businesses[i]
        options[#options + 1] = {
            title = business.name,
            description = ('%s · %s · %s'):format(
                business.type == 'fuel' and 'Tankstation' or business.type == 'combined' and 'Winkel & tankstation' or 'Winkel',
                business.isOwner and 'Eigenaar' or business.role or 'Medewerker',
                business.isOpen and 'Geopend' or 'Gesloten'
            ),
            icon = business.type == 'fuel' and 'gas-pump' or 'store',
            onSelect = function() RSClient.openBusiness(business.id, 'tablet') end
        }
    end
    lib.registerContext({ id = 'rs_businesses_tablet', title = 'RS Bedrijfstablet', options = options })
    lib.showContext('rs_businesses_tablet')
end

RegisterNetEvent('rs-businesses:client:useTablet', openFromTablet)

if Config.Tablet.command and Config.Tablet.command ~= '' then
    RegisterCommand(Config.Tablet.command, openFromTablet, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then stopTablet() end
end)
