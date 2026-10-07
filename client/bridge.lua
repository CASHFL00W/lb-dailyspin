ClientBridge = {}

function ClientBridge.notify(description, nType)
    lib.notify({
        title = Config.App.name,
        description = description,
        type = nType or 'inform',
        icon = 'dharmachakra',
    })
end

---Phone notification through the lb-phone API (also provided by phones with lb-phone compatibility).
---Falls back to an ox_lib notification.
function ClientBridge.phoneNotify(title, content)
    if GetResourceState('lb-phone') == 'started' then
        local ok = pcall(function()
            exports['lb-phone']:SendNotification({
                app = Config.App.identifier,
                title = title,
                content = content,
            })
        end)
        if ok then return end
    end
    ClientBridge.notify(('%s - %s'):format(title, content))
end

---Phone language from lb-phone's settings, if the phone exposes it.
---@return string|nil
function ClientBridge.phoneLanguage()
    if GetResourceState('lb-phone') ~= 'started' then return nil end
    local ok, settings = pcall(function() return exports['lb-phone']:GetSettings() end)
    if ok and type(settings) == 'table' then
        return settings.locale or settings.language
    end
end

function ClientBridge.setFuel(vehicle, level)
    if GetResourceState('lc_fuel') == 'started' then
        pcall(function() exports.lc_fuel:SetFuel(vehicle, level) end)
    elseif GetResourceState('LegacyFuel') == 'started' then
        pcall(function() exports.LegacyFuel:SetFuel(vehicle, level) end)
    elseif GetResourceState('cdn-fuel') == 'started' then
        pcall(function() exports['cdn-fuel']:SetFuel(vehicle, level) end)
    end
    SetVehicleFuelLevel(vehicle, level + 0.0)
end
