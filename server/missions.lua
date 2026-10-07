Missions = {}

local RESOURCE = GetCurrentResourceName()

---@type table<number, table> Active missions by player source. Route, step and reward only exist here.
local active = {}

local function randomItem(list)
    return list[math.random(1, #list)]
end

local function toVec3(v)
    return vec3(v.x, v.y, v.z)
end

---Picks `count` distinct entries and orders them nearest-neighbour style, starting at `origin`.
local function pickRoute(list, count, origin)
    local pool = {}
    for i = 1, #list do pool[i] = toVec3(list[i]) end
    for i = #pool, 2, -1 do
        local j = math.random(1, i)
        pool[i], pool[j] = pool[j], pool[i]
    end

    local chosen = {}
    for i = 1, math.min(count, #pool) do chosen[i] = pool[i] end

    local ordered, current = {}, origin
    while #chosen > 0 do
        local bestIndex, bestDist = 1, math.huge
        for i = 1, #chosen do
            local dist = #(chosen[i] - current)
            if dist < bestDist then bestIndex, bestDist = i, dist end
        end
        current = table.remove(chosen, bestIndex)
        ordered[#ordered + 1] = current
    end
    return ordered
end

---Steps carry a locale key plus arguments; the client translates them into the phone language.
local function buildSteps(kind, cfg)
    local steps = {
        { action = 'vehicle', mode = 'foot', coords = cfg.depot.coords, key = 'step_vehicle', args = { cfg.depot.label } },
    }

    if kind == 'taxi' then
        local pickup = randomItem(cfg.stops)
        local dropoff, farthest, farthestDist = nil, nil, -1
        for _ = 1, 25 do
            local candidate = randomItem(cfg.stops)
            local dist = #(toVec3(candidate) - toVec3(pickup))
            if dist >= (cfg.minTripDistance or 0) then
                dropoff = candidate
                break
            end
            if dist > farthestDist then farthest, farthestDist = candidate, dist end
        end
        dropoff = dropoff or farthest
        steps[#steps + 1] = { action = 'pickup', mode = 'vehicle', coords = toVec3(pickup), heading = pickup.w, key = 'step_pickup' }
        steps[#steps + 1] = { action = 'dropoff', mode = 'vehicle', coords = toVec3(dropoff), heading = dropoff.w, key = 'step_dropoff' }
    elseif kind == 'courier' then
        steps[#steps + 1] = { action = 'package_pickup', mode = 'foot', coords = toVec3(randomItem(cfg.warehouses)), key = 'step_package_pickup' }
        steps[#steps + 1] = { action = 'package_deliver', mode = 'foot', coords = toVec3(randomItem(cfg.customers)), key = 'step_package_deliver' }
    elseif kind == 'postman' then
        local houses = pickRoute(cfg.houses, cfg.stops or 3, cfg.depot.coords)
        for i = 1, #houses do
            steps[#steps + 1] = { action = 'mail', mode = 'foot', coords = houses[i], key = 'step_mail', args = { i, #houses } }
        end
    end

    if Config.Missions.returnVehicle then
        steps[#steps + 1] = { action = 'return', mode = 'vehicle', coords = toVec3(cfg.vehicle.spawns[1]), key = 'step_return' }
    end

    return steps
end

---Public view of a mission (for the client and the app). Only the current objective has coordinates.
function Missions.public(m)
    if not m then return nil end
    local steps = {}
    for i = 1, #m.steps do
        steps[i] = { key = m.steps[i].key, args = m.steps[i].args, done = i < m.step }
    end
    local step = m.steps[m.step]
    return {
        id          = m.id,
        kind        = m.kind,
        label       = m.cfg.label,
        icon        = m.cfg.icon,
        description = m.cfg.description,
        reward      = m.reward,
        expiresAt   = m.expiresAt,
        step        = m.step,
        steps       = steps,
        netId       = m.netId,
        prop        = m.cfg.prop,
        passenger   = m.passenger,
        objective   = step and {
            index   = m.step,
            action  = step.action,
            mode    = step.mode,
            key     = step.key,
            args    = step.args,
            coords  = { x = step.coords.x, y = step.coords.y, z = step.coords.z },
            heading = step.heading,
        } or nil,
    }
end

function Missions.get(source)
    return active[source]
end

local function pushUpdate(source, m)
    TriggerClientEvent('daily-spins:client:mission', source, Missions.public(m))
end

local function deleteVehicle(source, entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        Bridge.removeKeys(source, entity)
        DeleteEntity(entity)
    end
end

---Removes the vehicle once the player got out (used when no return to the depot is required).
local function despawnWhenLeft(source, entity)
    CreateThread(function()
        local deadline = os.time() + 600
        while DoesEntityExist(entity) and os.time() < deadline do
            local ped = GetPlayerPed(source)
            if ped == 0 or GetVehiclePedIsIn(ped, false) ~= entity then break end
            Wait(2000)
        end
        Wait(5000)
        deleteVehicle(source, entity)
    end)
end

---Ends a mission. success = pay out, otherwise cancel/fail with a locale key as reason.
---@param source number
---@param success boolean
---@param reason string|nil locale key
function Missions.finish(source, success, reason)
    local m = active[source]
    if not m then return end
    active[source] = nil

    if success then
        local paid = Bridge.addMoney(source, Config.Missions.rewardAccount, m.reward, ('daily-spins-%s'):format(m.kind))
        if not paid then
            print(('[%s] Payout failed: %s $%d to %d'):format(RESOURCE, m.kind, m.reward, source))
        end
        Store.log(m.key, 'mission_done', m.cfg.label, m.reward)
        Store.missionDone(m.key, m.reward)
        if m.vehicle and DoesEntityExist(m.vehicle) then
            if Config.Missions.returnVehicle then
                deleteVehicle(source, m.vehicle)
            else
                despawnWhenLeft(source, m.vehicle)
            end
        end
    else
        Store.log(m.key, 'mission_failed', m.cfg.label, 0)
        deleteVehicle(source, m.vehicle)
    end

    TriggerClientEvent('daily-spins:client:missionEnd', source, {
        success = success,
        reason  = reason,
        label   = m.cfg.label,
        reward  = success and m.reward or 0,
    })
end

---Creates a mission after a spin. The whole route is rolled server-side.
function Missions.create(source, key, kind)
    local cfg = Config.Missions[kind]
    if type(cfg) ~= 'table' or not cfg.depot or not cfg.vehicle then return nil end

    local m = {
        id        = ('%d-%d'):format(source, GetGameTimer()),
        source    = source,
        key       = key,
        kind      = kind,
        cfg       = cfg,
        reward    = math.random(cfg.reward.min, cfg.reward.max),
        steps     = buildSteps(kind, cfg),
        step      = 1,
        expiresAt = os.time() + Config.Missions.timeLimit * 60,
        lastPos   = GetEntityCoords(GetPlayerPed(source)),
        lastAt    = GetGameTimer(),
        passenger = kind == 'taxi' and randomItem(cfg.passengerModels) or nil,
    }
    active[source] = m

    -- Only sent after the wheel animation, so blips and notifications never spoil the result
    SetTimeout(Config.Wheel.spinDuration + 400, function()
        if active[source] == m then pushUpdate(source, m) end
    end)
    return m
end

local function spotFree(coords)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if #(GetEntityCoords(vehicles[i]) - coords) < 3.0 then return false end
    end
    return true
end

local function spawnVehicle(source, m)
    local vcfg = m.cfg.vehicle
    local spawn
    for i = 1, #vcfg.spawns do
        if spotFree(toVec3(vcfg.spawns[i])) then
            spawn = vcfg.spawns[i]
            break
        end
    end
    if not spawn then return nil, 'spots_blocked' end

    local entity = CreateVehicleServerSetter(joaat(vcfg.model), 'automobile', spawn.x, spawn.y, spawn.z, spawn.w)
    local timeout = GetGameTimer() + 5000
    while not DoesEntityExist(entity) do
        if GetGameTimer() > timeout then return nil, 'vehicle_failed' end
        Wait(0)
    end

    SetVehicleNumberPlateText(entity, ('SPIN%04d'):format(math.random(0, 9999)))
    Entity(entity).state:set('fuel', 100.0, true)
    Entity(entity).state:set('dailySpins', source, true)
    Bridge.giveKeys(source, entity)
    return entity
end

---Validates and executes one mission step. index = the step the client wants to complete.
---Every check uses the server's view of the player; nothing the client sends is trusted.
---@return boolean ok, string? errorKey
function Missions.step(source, index)
    local m = active[source]
    if not m then return false, 'no_mission' end
    if type(index) ~= 'number' or index ~= m.step then return false, 'wrong_step' end

    local step = m.steps[m.step]
    if not step then return false, 'wrong_step' end

    local now = GetGameTimer()
    local elapsed = (now - m.lastAt) / 1000
    if elapsed < Config.Security.minStepSeconds then return false, 'too_fast' end

    local ped = GetPlayerPed(source)
    if ped == 0 then return false, 'player_not_found' end
    local pos = GetEntityCoords(ped)

    -- Teleport detection: distance travelled since the last step vs. the time that passed
    local travelled = #(pos - m.lastPos)
    if travelled > Config.Security.teleportMinDist and travelled / math.max(elapsed, 0.1) > Config.Security.maxSpeed then
        Security.flag(source, ('teleport during %s mission: %.0fm in %.1fs (step %d)'):format(m.kind, travelled, elapsed, m.step))
        Missions.finish(source, false, 'exploit_cancelled')
        return false, 'exploit_cancelled'
    end

    local radius = step.mode == 'vehicle' and Config.Security.driveRadius or Config.Security.footRadius
    if #(pos - step.coords) > radius then return false, 'not_at_location' end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if step.mode == 'foot' and vehicle ~= 0 then return false, 'exit_vehicle' end

    if step.action == 'vehicle' then
        if m.vehicle then return false, 'vehicle_issued' end
        local entity, err = spawnVehicle(source, m)
        if not entity then return false, err end
        m.vehicle = entity
        m.netId = NetworkGetNetworkIdFromEntity(entity)
    else
        if not m.vehicle or not DoesEntityExist(m.vehicle) then
            Missions.finish(source, false, 'vehicle_lost')
            return false, 'vehicle_lost'
        end
        if step.mode == 'vehicle' and vehicle ~= m.vehicle then return false, 'need_work_vehicle' end
    end

    m.step = m.step + 1
    m.lastPos = pos
    m.lastAt = now

    if m.step > #m.steps then
        Missions.finish(source, true)
    else
        pushUpdate(source, m)
    end
    return true
end

function Missions.cancel(source)
    if not active[source] then return false end
    Missions.finish(source, false, 'mission_cancelled')
    return true
end

-- Expiry and vehicle watchdog
CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()
        for source, m in pairs(active) do
            if not GetPlayerName(source) then
                active[source] = nil
                deleteVehicle(source, m.vehicle)
            elseif now > m.expiresAt then
                Missions.finish(source, false, 'time_expired')
            elseif m.vehicle and not DoesEntityExist(m.vehicle) then
                Missions.finish(source, false, 'vehicle_lost')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local m = active[source]
    if not m then return end
    active[source] = nil
    if m.vehicle and DoesEntityExist(m.vehicle) then DeleteEntity(m.vehicle) end
    Store.log(m.key, 'mission_failed', m.cfg.label, 0)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for _, m in pairs(active) do
        if m.vehicle and DoesEntityExist(m.vehicle) then DeleteEntity(m.vehicle) end
    end
end)
