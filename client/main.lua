App = {}

local RESOURCE = GetCurrentResourceName()
local PHONE = 'lb-phone'

---Sends a message into the app's iframe ({ action, data }).
function App.push(action, data)
    if GetResourceState(PHONE) ~= 'started' then return end
    pcall(function()
        exports[PHONE]:SendCustomAppMessage(Config.App.identifier, { action = action, data = data })
    end)
end

local function registerApp()
    if GetResourceState(PHONE) ~= 'started' then return end
    local ok, added, err = pcall(function()
        return exports[PHONE]:AddCustomApp({
            identifier  = Config.App.identifier,
            name        = Config.App.name,
            description = Config.App.description,
            developer   = Config.App.developer,
            defaultApp  = Config.App.defaultApp,
            size        = Config.App.size,
            icon        = ('https://cfx-nui-%s/ui/icon.svg'):format(RESOURCE),
            ui          = ('https://cfx-nui-%s/ui/index.html'):format(RESOURCE),
            fixBlur     = true,
        })
    end)
    if not ok or added == false then
        print(('[%s] Could not register the phone app: %s'):format(RESOURCE, tostring(not ok and added or err)))
    end
end

CreateThread(function()
    local timeout = GetGameTimer() + 60000
    while GetResourceState(PHONE) ~= 'started' and GetGameTimer() < timeout do Wait(500) end
    SetLanguage(ClientBridge.phoneLanguage())
    registerApp()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == PHONE then
        Wait(500)
        registerApp()
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE or GetResourceState(PHONE) ~= 'started' then return end
    pcall(function() exports[PHONE]:RemoveCustomApp(Config.App.identifier) end)
end)

-- lb-phone announces settings changes (language included) with this event
AddEventHandler('lb-phone:settingsUpdated', function(settings)
    if type(settings) == 'table' and (settings.locale or settings.language) then
        SetLanguage(settings.locale or settings.language)
        Mission.refreshTexts()
    end
end)

---------------------------------------------------------------------------------------------------
-- Localisation of server data (the server only sends locale keys and config labels)
---------------------------------------------------------------------------------------------------
local function localizeState(state)
    if type(state) ~= 'table' then return state end
    for _, seg in ipairs(state.segments or {}) do
        seg.label = LabelOf(seg.label)
    end
    for _, entry in ipairs(state.history or {}) do
        entry.label = LabelOf(entry.label)
    end
    state.mission = Mission.localize(state.mission)
    return state
end

local function localizeResponse(res)
    if type(res) ~= 'table' then return { ok = false, error = L('internal_error') } end
    if res.error then res.error = L(res.error) end
    if res.result then
        res.result.label = LabelOf(res.result.label)
        res.result.mission = Mission.localize(res.result.mission)
    end
    res.state = localizeState(res.state)
    return res
end

---------------------------------------------------------------------------------------------------
-- NUI callbacks (requests from the app). They only forward intents - the server validates everything.
---------------------------------------------------------------------------------------------------
RegisterNUICallback('setLanguage', function(data, cb)
    local lang = SetLanguage(type(data) == 'table' and data.lang or nil)
    Mission.refreshTexts()
    cb({ lang = lang, strings = UiStrings() })
end)

RegisterNUICallback('getState', function(_, cb)
    cb(localizeState(lib.callback.await('daily-spins:server:getState', false)) or false)
end)

RegisterNUICallback('spin', function(_, cb)
    cb(localizeResponse(lib.callback.await('daily-spins:server:spin', false)))
end)

RegisterNUICallback('cancelMission', function(_, cb)
    cb(localizeResponse(lib.callback.await('daily-spins:server:cancel', false)))
end)

RegisterNUICallback('setWaypoint', function(_, cb)
    cb({ ok = Mission.setWaypoint() })
end)

RegisterNetEvent('daily-spins:client:refresh', function()
    App.push('refresh', true)
end)
