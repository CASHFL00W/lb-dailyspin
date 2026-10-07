Mission = {}

---@type table|nil public mission state from the server
local current
local blip
local passenger
local textShown
local busy = false
local fuelSetFor

local BLIP_SPRITES = {
    vehicle = 225, pickup = 280, dropoff = 38, package_pickup = 478,
    package_deliver = 501, mail = 40, ['return'] = 50,
}

---Translates a server step ({ key, args }) into the current language.
local function stepText(step)
    if not step then return '' end
    local args = {}
    for i, v in ipairs(step.args or {}) do
        args[i] = type(v) == 'string' and LabelOf(v) or v
    end
    return L(step.key, table.unpack(args))
end

---Returns a copy of the mission with every text resolved for the app.
function Mission.localize(m)
    if type(m) ~= 'table' then return nil end
    local out = {}
    for k, v in pairs(m) do out[k] = v end
    out.label = LabelOf(m.label)
    out.description = LabelOf(m.description)
    out.steps = {}
    for i, step in ipairs(m.steps or {}) do
        out.steps[i] = { label = stepText(step), done = step.done }
    end
    if m.objective then
        out.objective = {}
        for k, v in pairs(m.objective) do out.objective[k] = v end
        out.objective.label = stepText(m.objective)
    end
    return out
end

local function showText(text)
    if textShown == text then return end
    textShown = text
    if text then lib.showTextUI(text, { position = 'left-center', icon = 'dharmachakra' }) else lib.hideTextUI() end
end

local function removeBlip()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    blip = nil
end

local function objectiveCoords()
    local c = current and current.objective and current.objective.coords
    return c and vec3(c.x, c.y, c.z)
end

local function createBlip()
    removeBlip()
    local coords = objectiveCoords()
    if not coords then return end
    blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, BLIP_SPRITES[current.objective.action] or 1)
    SetBlipColour(blip, 5)
    SetBlipScale(blip, 0.9)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(L('blip_name', stepText(current.objective)))
    EndTextCommandSetBlipName(blip)
end

local function missionVehicle()
    if not current or not current.netId or not NetworkDoesNetworkIdExist(current.netId) then return 0 end
    return NetToVeh(current.netId)
end

local function releasePassenger(delete)
    if not passenger or not DoesEntityExist(passenger) then
        passenger = nil
        return
    end
    local ped = passenger
    passenger = nil
    if delete then
        DeleteEntity(ped)
        return
    end
    CreateThread(function()
        TaskLeaveAnyVehicle(ped, 0, 0)
        Wait(2500)
        TaskWanderStandard(ped, 10.0, 10)
        Wait(12000)
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end)
end

local function spawnPassenger()
    if passenger and DoesEntityExist(passenger) then return end
    local c = current.objective.coords
    local model = lib.requestModel(current.passenger or 'a_m_y_business_01', 5000)
    if not model then return end
    passenger = CreatePed(4, model, c.x, c.y, c.z - 1.0, current.objective.heading or 0.0, true, false)
    SetModelAsNoLongerNeeded(model)
    SetBlockingOfNonTemporaryEvents(passenger, true)
    SetPedCanRagdoll(passenger, false)
    SetEntityInvincible(passenger, true)
    TaskStartScenarioInPlace(passenger, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
end

---Asks the server to complete the current step. The server decides; the client only asks.
local function completeStep()
    if busy or not current or not current.objective then return false end
    busy = true
    local res = lib.callback.await('daily-spins:server:step', false, current.objective.index)
    busy = false
    if not res or not res.ok then
        ClientBridge.notify(L(res and res.error or 'action_failed'), 'error')
        return false
    end
    return true
end

local BOX_PROP = { bone = 60309, pos = vec3(0.025, 0.08, 0.255), rot = vec3(-145.0, 290.0, 0.0) }
local MAIL_PROP = { bone = 57005, pos = vec3(0.13, 0.02, -0.03), rot = vec3(-90.0, 0.0, 0.0) }

local function progress(label, anim, prop)
    return lib.progressBar({
        duration = 3500,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = anim,
        prop = prop and current.prop and {
            model = current.prop, bone = prop.bone, pos = prop.pos, rot = prop.rot,
        } or nil,
    })
end

local actions = {}

actions.vehicle = function()
    if completeStep() then ClientBridge.notify(L('vehicle_ready'), 'success') end
end

actions.pickup = function(vehicle)
    if not passenger or not DoesEntityExist(passenger) then spawnPassenger() end
    if not passenger then return end
    ClearPedTasks(passenger)
    TaskEnterVehicle(passenger, vehicle, 15000, 2, 1.5, 1, 0)
    local timeout = GetGameTimer() + 15000
    while not IsPedInVehicle(passenger, vehicle, false) and GetGameTimer() < timeout do Wait(250) end
    if not IsPedInVehicle(passenger, vehicle, false) then SetPedIntoVehicle(passenger, vehicle, 2) end
    if completeStep() then ClientBridge.notify(L('passenger_in'), 'success') end
end

actions.dropoff = function()
    if completeStep() then releasePassenger(false) end
end

actions.package_pickup = function()
    if not progress(L('progress_package_pickup'), { dict = 'anim@heists@box_carry@', clip = 'idle' }, BOX_PROP) then return end
    if completeStep() then ClientBridge.notify(L('package_loaded'), 'success') end
end

actions.package_deliver = function()
    if not progress(L('progress_package_deliver'), { dict = 'anim@heists@box_carry@', clip = 'idle' }, BOX_PROP) then return end
    completeStep()
end

actions.mail = function()
    if not progress(L('progress_mail'), { dict = 'mp_common', clip = 'givetake1_a' }, MAIL_PROP) then return end
    completeStep()
end

actions['return'] = function()
    completeStep()
end

---Whether the player may trigger the current objective right now (cosmetic - the server re-checks).
local function interactionReady(obj, ped, dist)
    if obj.mode == 'foot' then
        return dist < 2.2 and not IsPedInAnyVehicle(ped, false)
    end
    local vehicle = missionVehicle()
    if vehicle == 0 or GetVehiclePedIsIn(ped, false) ~= vehicle or GetPedInVehicleSeat(vehicle, -1) ~= ped then return false end
    return dist < (obj.action == 'return' and 8.0 or 14.0) and GetEntitySpeed(vehicle) < 3.0, vehicle
end

local function runLoop(id)
    CreateThread(function()
        while current and current.id == id do
            local sleep = 750
            local obj = current.objective
            local coords = objectiveCoords()
            if obj and coords then
                local ped = PlayerPedId()
                local dist = #(GetEntityCoords(ped) - coords)

                if obj.action == 'pickup' and dist < 120.0 then spawnPassenger() end

                if dist < 60.0 then
                    sleep = 0
                    if obj.mode == 'foot' then
                        DrawMarker(2, coords.x, coords.y, coords.z + 0.25, 0, 0, 0, 0, 180.0, 0, 0.3, 0.3, 0.3, 255, 214, 10, 200, true, true, 2, false, nil, nil, false)
                    else
                        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 6.0, 6.0, 1.0, 255, 214, 10, 90, false, false, 2, false, nil, nil, false)
                    end

                    local ready, vehicle = interactionReady(obj, ped, dist)
                    if ready and not busy then
                        showText(L('prompt_' .. obj.action))
                        if IsControlJustReleased(0, 38) then
                            showText(nil)
                            actions[obj.action](vehicle)
                        end
                    else
                        showText(nil)
                    end
                else
                    showText(nil)
                end
            end

            -- Fill the tank once the work vehicle exists on this client
            if current and current.netId and fuelSetFor ~= current.netId then
                local vehicle = missionVehicle()
                if vehicle ~= 0 then
                    fuelSetFor = current.netId
                    ClientBridge.setFuel(vehicle, 100.0)
                end
            end
            Wait(sleep)
        end
        showText(nil)
    end)
end

function Mission.get()
    return current
end

function Mission.setWaypoint()
    local coords = objectiveCoords()
    if not coords then return false end
    SetNewWaypoint(coords.x, coords.y)
    return true
end

---Language changed: rebuild texts that are already on screen.
function Mission.refreshTexts()
    if not current then return end
    createBlip()
    showText(nil)
end

---New state from the server (after a spin or a completed step).
function Mission.update(data)
    local isNew = not current or current.id ~= data.id
    current = data
    createBlip()
    if isNew then
        fuelSetFor = nil
        runLoop(data.id)
        ClientBridge.phoneNotify(L('notify_mission', LabelOf(data.label)), stepText(data.objective))
    end
    App.push('mission', Mission.localize(data))
end

function Mission.finish(data)
    current = nil
    removeBlip()
    showText(nil)
    releasePassenger(not data.success)
    if data.success then
        ClientBridge.phoneNotify(L('notify_done_title'), L('notify_done_text', LabelOf(data.label), data.reward))
    else
        ClientBridge.phoneNotify(L('notify_end_title'), data.reason and L(data.reason) or L('notify_end_text'))
    end
    App.push('missionEnd', {
        success = data.success,
        reward  = data.reward,
        label   = LabelOf(data.label),
        reason  = data.reason and L(data.reason) or nil,
    })
end

RegisterNetEvent('daily-spins:client:mission', function(data)
    if type(data) == 'table' then Mission.update(data) end
end)

RegisterNetEvent('daily-spins:client:missionEnd', function(data)
    if type(data) == 'table' then Mission.finish(data) end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeBlip()
    if textShown then lib.hideTextUI() end
    if passenger and DoesEntityExist(passenger) then DeleteEntity(passenger) end
end)
