local saleSigns, workerPeds = {}, {}
local workerGeneration = 0
local cashierBusinesses = {}

local customWorkAnimations = {
    RS_CASH_REGISTER = {
        dict = 'mp_am_hold_up',
        clip = 'purchase_beerbox_shopkeeper',
        flag = 1
    },
    RS_STOCK_SHELVES = {
        dict = 'anim@heists@box_carry@',
        clip = 'idle',
        flag = 49,
        props = {{
            model = 'hei_prop_heist_box',
            bone = 28422,
            offset = { x = 0.0, y = -0.03, z = -0.16 },
            rotation = { x = 5.0, y = 0.0, z = 0.0 }
        }}
    },
    RS_MANAGER_CHECK = {
        dict = 'missheistdockssetup1clipboard@base',
        clip = 'base',
        flag = 49,
        props = {
            {
                model = 'p_amb_clipboard_01',
                bone = 18905,
                offset = { x = 0.10, y = 0.02, z = 0.05 },
                rotation = { x = 10.0, y = 0.0, z = 0.0 }
            },
            {
                model = 'prop_pencil_01',
                bone = 58866,
                offset = { x = 0.11, y = -0.02, z = 0.001 },
                rotation = { x = -120.0, y = 0.0, z = 0.0 }
            }
        }
    },
    RS_SECURITY_WATCH = {
        scenario = 'WORLD_HUMAN_GUARD_STAND'
    }
}

local managedWorkProps = {}

local looseWorkProps = {
    'p_amb_clipboard_01',
    'prop_notepad_01',
    'prop_pencil_01'
}

local function cleanupLooseWorkProps(coords)
    for i = 1, #looseWorkProps do
        local model = joaat(looseWorkProps[i])
        for _ = 1, 12 do
            local object = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.5, model, false, false, false)
            if not object or object == 0 then break end
            SetEntityAsMissionEntity(object, true, true)
            DeleteObject(object)
            if DoesEntityExist(object) then DeleteEntity(object) end
            Wait(0)
        end
    end
end

local function cleanupManagedWorkProps(ped)
    local props = managedWorkProps[ped]
    if not props then return end
    for i = 1, #props do
        local object = props[i]
        if DoesEntityExist(object) then
            DetachEntity(object, true, true)
            DeleteObject(object)
            if DoesEntityExist(object) then DeleteEntity(object) end
        end
    end
    managedWorkProps[ped] = nil
end

local function createManagedWorkProps(ped, definitions)
    cleanupManagedWorkProps(ped)
    if not definitions then return end
    managedWorkProps[ped] = {}
    for i = 1, #definitions do
        local definition = definitions[i]
        local hash = joaat(definition.model)
        lib.requestModel(hash, 10000)
        local coords = GetEntityCoords(ped)
        local object = CreateObject(hash, coords.x, coords.y, coords.z, false, false, false)
        local offset, rotation = definition.offset, definition.rotation
        SetEntityCollision(object, false, false)
        AttachEntityToEntity(
            object, ped, GetPedBoneIndex(ped, definition.bone),
            offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z,
            true, true, false, true, 1, true
        )
        managedWorkProps[ped][#managedWorkProps[ped] + 1] = object
        SetModelAsNoLongerNeeded(hash)
    end
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    lib.requestModel(hash, 10000)
    return hash
end

local function removePeds(collection)
    for _, ped in pairs(collection) do
        if DoesEntityExist(ped) then
            cleanupManagedWorkProps(ped)
            exports.ox_target:removeLocalEntity(ped)
            DeleteEntity(ped)
        end
    end
    table.wipe(collection)
end

local function createPed(data, model, targetOptions, mobile)
    local hash = loadModel(model)
    if not hash or not data then return nil end
    local ped = CreatePed(4, hash, data.x + 0.0, data.y + 0.0, data.z - 1.0, data.w + 0.0, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, mobile ~= true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    if targetOptions then exports.ox_target:addLocalEntity(ped, targetOptions) end
    SetModelAsNoLongerNeeded(hash)
    return ped
end

local function createSaleSign(data, business)
    local settings = Config.SaleSign or {}
    local hash = loadModel(settings.model or 'prop_forsale_sign_02')
    if not hash or not data then return nil end

    local sign = CreateObject(hash, data.x + 0.0, data.y + 0.0, data.z + (settings.zOffset or -1.0), false, true, false)
    SetEntityAsMissionEntity(sign, true, true)
    SetEntityHeading(sign, data.w or 0.0)
    PlaceObjectOnGroundProperly(sign)
    FreezeEntityPosition(sign, true)
    SetEntityInvincible(sign, true)
    exports.ox_target:addLocalEntity(sign, {{
        name = ('rs_business_sale_%s'):format(business.id),
        icon = 'fa-solid fa-sign-hanging',
        label = ('%s kopen ($%s)'):format(business.name, business.purchasePrice),
        distance = settings.interactionDistance or Config.InteractionDistance,
        onSelect = function() RSClient.openBusiness(business.id) end
    }})
    SetModelAsNoLongerNeeded(hash)
    return sign
end

local function businessById(id)
    for i = 1, #RSClient.businesses do
        if tonumber(RSClient.businesses[i].id) == tonumber(id) then return RSClient.businesses[i] end
    end
end

function RSClient.refreshSaleSigns()
    removePeds(saleSigns)
    for i = 1, #RSClient.businesses do
        local business = RSClient.businesses[i]
        local signCoords = business.npc or business.coords
        if not business.owner and signCoords then
            saleSigns[business.id] = createSaleSign(signCoords, business)
        end
    end
end

-- Compatibiliteit met de bestaande synchronisatie-aanroepen.
RSClient.refreshMainNpcs = RSClient.refreshSaleSigns

local function waitAtWorkpoint(ped, point, generation)
    if not DoesEntityExist(ped) or generation ~= workerGeneration then return end
    local coords = point.coords
    SetEntityHeading(ped, (coords.w or GetEntityHeading(ped)) + 0.0)
    ClearPedTasks(ped)
    local duration = tonumber(point.duration_ms) or Config.NpcAI.workDurationMs
    local animation = customWorkAnimations[point.scenario]
    if animation then
        cleanupLooseWorkProps(coords)
        if animation.scenario then
            TaskStartScenarioInPlace(ped, animation.scenario, 0, true)
        else
            lib.requestAnimDict(animation.dict, 10000)
            createManagedWorkProps(ped, animation.props)
            TaskPlayAnim(ped, animation.dict, animation.clip, 3.0, 3.0, duration, animation.flag, 0.0, false, false, false)
        end
    else
        TaskStartScenarioInPlace(ped, point.scenario, 0, true)
    end
    local elapsed = 0
    while elapsed < duration and DoesEntityExist(ped) and generation == workerGeneration do
        Wait(500)
        elapsed = elapsed + 500
    end
    if DoesEntityExist(ped) then
        ClearPedTasks(ped)
        cleanupManagedWorkProps(ped)
        if animation and animation.dict then RemoveAnimDict(animation.dict) end
    end
end

local function walkToWorkpoint(ped, point, generation)
    local coords = point.coords
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    TaskFollowNavMeshToCoord(
        ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0,
        Config.NpcAI.walkSpeed + 0.0, -1, Config.NpcAI.arrivalDistance + 0.0, false, coords.w or 0.0
    )
    local started = GetGameTimer()
    while DoesEntityExist(ped) and generation == workerGeneration do
        if #(GetEntityCoords(ped) - vec3(coords.x, coords.y, coords.z)) <= Config.NpcAI.arrivalDistance then return true end
        if GetGameTimer() - started >= Config.NpcAI.stuckTimeoutMs then
            if Config.NpcAI.teleportWhenStuck then
                SetEntityCoordsNoOffset(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false)
                SetEntityHeading(ped, coords.w or 0.0)
                return true
            end
            return false
        end
        Wait(400)
    end
    return false
end

local function fallbackWork(ped, worker, generation)
    local home = worker.coords
    if worker.role == 'cashier' then
        cleanupLooseWorkProps(home)
        waitAtWorkpoint(ped, { coords = home, scenario = 'RS_CASH_REGISTER', duration_ms = Config.NpcAI.workDurationMs }, generation)
        return
    end
    ClearPedTasks(ped)
    TaskWanderInArea(ped, home.x + 0.0, home.y + 0.0, home.z + 0.0, 4.0, 2.0, 5.0)
    local elapsed = 0
    while elapsed < 9000 and DoesEntityExist(ped) and generation == workerGeneration do
        Wait(500)
        elapsed = elapsed + 500
    end
    if DoesEntityExist(ped) and #(GetEntityCoords(ped) - vec3(home.x, home.y, home.z)) > 8.0 then
        SetEntityCoordsNoOffset(ped, home.x + 0.0, home.y + 0.0, home.z + 0.0, false, false, false)
    end
    local roleScenarios = Config.NpcAI.scenarios[worker.role] or {}
    if roleScenarios[1] then
        local point = { coords = home, scenario = roleScenarios[1], duration_ms = Config.NpcAI.workDurationMs }
        walkToWorkpoint(ped, point, generation)
        waitAtWorkpoint(ped, point, generation)
    end
end

local function startWorkerAI(ped, worker, generation)
    CreateThread(function()
        local route = worker.workpoints or {}
        local index = #route > 0 and (((tonumber(worker.id) or 1) - 1) % #route + 1) or 1
        while DoesEntityExist(ped) and generation == workerGeneration do
            local business = businessById(worker.business_id)
            if Config.NpcAI.disableOutsideOpeningHours and business and not business.isOpen then
                ClearPedTasks(ped)
                TaskStandStill(ped, 5000)
                Wait(5000)
            elseif #route == 0 then
                fallbackWork(ped, worker, generation)
                Wait(Config.NpcAI.idleDurationMs)
            else
                local point = route[index]
                if worker.role == 'cashier' then
                    SetEntityCoordsNoOffset(ped, point.coords.x + 0.0, point.coords.y + 0.0, point.coords.z + 0.0, false, false, false)
                else
                    walkToWorkpoint(ped, point, generation)
                end
                waitAtWorkpoint(ped, point, generation)
                if worker.role ~= 'cashier' then index = index % #route + 1 end
                Wait(Config.NpcAI.idleDurationMs)
            end
        end
    end)
end

local function refreshWorkers()
    workerGeneration = workerGeneration + 1
    local generation = workerGeneration
    removePeds(workerPeds)
    cashierBusinesses = {}
    local workers = lib.callback.await('rs-businesses:server:npcs', false) or {}

    for i = 1, #workers do
        local worker = workers[i]
        if worker.role == 'cashier' then cashierBusinesses[tonumber(worker.business_id)] = true end
    end
    RSClient.refreshSaleSigns()

    if not Config.NpcAI.enabled then return end
    for i = 1, #workers do
        local worker = workers[i]
        local ped = createPed(worker.coords, worker.model, {{
            name = ('rs_worker_%s'):format(worker.id),
            icon = 'fa-solid fa-user-tie',
            label = ('Praten met %s'):format(worker.name),
            distance = 2.0,
            onSelect = function()
                if worker.role == 'cashier' then RSClient.openBusiness(worker.business_id) return end
                lib.notify({ title = worker.name, description = ('Aan het werk als %s bij %s.'):format(worker.role, worker.business_name), type = 'inform' })
            end
        }}, true)
        if ped then
            workerPeds[worker.id] = ped
            if worker.role == 'cashier' then cleanupLooseWorkProps(worker.coords) end
            startWorkerAI(ped, worker, generation)
        end
    end
end

RegisterNetEvent('rs-businesses:client:refreshNpcs', refreshWorkers)

CreateThread(function()
    Wait(1500)
    refreshWorkers()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removePeds(saleSigns)
    removePeds(workerPeds)
end)
