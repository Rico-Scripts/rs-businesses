local mainPeds, workerPeds = {}, {}
local workerGeneration = 0
local cashierBusinesses = {}

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    lib.requestModel(hash, 10000)
    return hash
end

local function removePeds(collection)
    for _, ped in pairs(collection) do
        if DoesEntityExist(ped) then
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

local function businessById(id)
    for i = 1, #RSClient.businesses do
        if tonumber(RSClient.businesses[i].id) == tonumber(id) then return RSClient.businesses[i] end
    end
end

function RSClient.refreshMainNpcs()
    removePeds(mainPeds)
    for i = 1, #RSClient.businesses do
        local business = RSClient.businesses[i]
        local npc = business.npc or business.coords
        if npc and not cashierBusinesses[tonumber(business.id)] then
            local id = business.id
            mainPeds[id] = createPed(npc, npc.model or Config.Defaults.npcModel, {{
                name = ('rs_business_%s'):format(id),
                icon = 'fa-solid fa-store',
                label = business.owner and _L('interact') or ('Bedrijf kopen ($%s)'):format(business.purchasePrice),
                distance = Config.InteractionDistance,
                onSelect = function() RSClient.openBusiness(id) end
            }}, false)
        end
    end
end

local function waitAtWorkpoint(ped, point, generation)
    if not DoesEntityExist(ped) or generation ~= workerGeneration then return end
    local coords = point.coords
    SetEntityHeading(ped, (coords.w or GetEntityHeading(ped)) + 0.0)
    ClearPedTasks(ped)
    TaskStartScenarioInPlace(ped, point.scenario, 0, true)
    local duration = tonumber(point.duration_ms) or Config.NpcAI.workDurationMs
    local elapsed = 0
    while elapsed < duration and DoesEntityExist(ped) and generation == workerGeneration do
        Wait(500)
        elapsed = elapsed + 500
    end
    if DoesEntityExist(ped) then ClearPedTasks(ped) end
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
        waitAtWorkpoint(ped, { coords = home, scenario = Config.NpcAI.scenarios.cashier[1], duration_ms = Config.NpcAI.workDurationMs }, generation)
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
    RSClient.refreshMainNpcs()

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
            startWorkerAI(ped, worker, generation)
        end
    end
end

RegisterNetEvent('rs-businesses:client:refreshNpcs', refreshWorkers)

CreateThread(function()
    Wait(1500)
    refreshWorkers()
end)
