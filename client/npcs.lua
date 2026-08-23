local mainPeds, workerPeds = {}, {}

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    lib.requestModel(hash, 10000)
    return hash
end

local function removePeds(collection)
    for _, ped in pairs(collection) do
        if DoesEntityExist(ped) then exports.ox_target:removeLocalEntity(ped); DeleteEntity(ped) end
    end
    table.wipe(collection)
end

local function createPed(data, model, targetOptions)
    local hash = loadModel(model)
    if not hash or not data then return nil end
    local ped = CreatePed(4, hash, data.x + 0.0, data.y + 0.0, data.z - 1.0, data.w + 0.0, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    if targetOptions then exports.ox_target:addLocalEntity(ped, targetOptions) end
    SetModelAsNoLongerNeeded(hash)
    return ped
end

function RSClient.refreshMainNpcs()
    removePeds(mainPeds)
    for i = 1, #RSClient.businesses do
        local business = RSClient.businesses[i]
        local npc = business.npc or business.coords
        if npc then
            local id = business.id
            mainPeds[id] = createPed(npc, npc.model or Config.Defaults.npcModel, {{
                name = ('rs_business_%s'):format(id),
                icon = 'fa-solid fa-store',
                label = business.owner and _L('interact') or ('Bedrijf kopen ($%s)'):format(business.purchasePrice),
                distance = Config.InteractionDistance,
                onSelect = function() RSClient.openBusiness(id) end
            }})
        end
    end
end

local function refreshWorkers()
    removePeds(workerPeds)
    local workers = lib.callback.await('rs-businesses:server:npcs', false) or {}
    for i = 1, #workers do
        local worker = workers[i]
        workerPeds[worker.id] = createPed(worker.coords, worker.model, {{
            name = ('rs_worker_%s'):format(worker.id),
            icon = 'fa-solid fa-user-tie',
            label = ('Praten met %s'):format(worker.name),
            distance = 2.0,
            onSelect = function()
                lib.notify({ title = worker.name, description = ('Werkzaam als %s.'):format(worker.role), type = 'inform' })
            end
        }})
    end
end

RegisterNetEvent('rs-businesses:client:refreshNpcs', refreshWorkers)

CreateThread(function()
    Wait(1500)
    RSClient.refreshMainNpcs()
    refreshWorkers()
end)
