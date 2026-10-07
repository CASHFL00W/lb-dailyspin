Bridge = {}

local RESOURCE = GetCurrentResourceName()
local framework

local function resolveFramework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if GetResourceState('qbx_core') == 'started' then return 'qbx' end
    if GetResourceState('qb-core') == 'started' then return 'qb' end
    if GetResourceState('es_extended') == 'started' then return 'esx' end
    return 'standalone'
end

local function qbPlayer(source)
    if framework == 'qbx' then return exports.qbx_core:GetPlayer(source) end
    if framework == 'qb' then return exports['qb-core']:GetCoreObject().Functions.GetPlayer(source) end
end

local function esxPlayer(source)
    return exports.es_extended:getSharedObject().GetPlayerFromId(source)
end

function Bridge.init()
    framework = resolveFramework()
    print(('[%s] Framework: %s'):format(RESOURCE, framework))
end

---Character id (citizenid / ESX identifier). Nil while no character is loaded.
---@return string|nil
function Bridge.getCharId(source)
    if framework == 'qbx' or framework == 'qb' then
        local player = qbPlayer(source)
        return player and player.PlayerData and player.PlayerData.citizenid
    elseif framework == 'esx' then
        local player = esxPlayer(source)
        return player and player.identifier
    end
    return GetPlayerIdentifierByType(source, 'license')
end

---Key used for the cooldown and stats: the license (shared by all characters) or the character id.
---Always requires a loaded character, so nobody can spin from the character selection.
---@return string|nil
function Bridge.getSpinKey(source)
    local charId = Bridge.getCharId(source)
    if not charId then return nil end
    if Config.Cooldown.perLicense then
        return GetPlayerIdentifierByType(source, 'license2') or GetPlayerIdentifierByType(source, 'license')
    end
    return charId
end

---@return boolean paid
function Bridge.addMoney(source, account, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end

    if framework == 'qbx' or framework == 'qb' then
        local player = qbPlayer(source)
        return player ~= nil and player.Functions.AddMoney(account, amount, reason) == true
    elseif framework == 'esx' then
        local player = esxPlayer(source)
        if not player then return false end
        if account == 'cash' then
            player.addMoney(amount, reason)
        else
            player.addAccountMoney(account, amount, reason)
        end
        return true
    end

    print(('[%s] No framework found - cannot pay $%d to %d'):format(RESOURCE, amount, source))
    return false
end

local function keysResource()
    local wanted = Config.VehicleKeys or 'auto'
    if wanted == 'none' then return nil end
    if wanted ~= 'auto' then return GetResourceState(wanted) == 'started' and wanted or nil end
    for _, name in ipairs({ 'mk_vehiclekeys', 'qbx_vehiclekeys' }) do
        if GetResourceState(name) == 'started' then return name end
    end
end

function Bridge.giveKeys(source, entity)
    local resource = keysResource()
    if not resource or not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    local ok, err = pcall(function()
        if resource == 'mk_vehiclekeys' then
            exports.mk_vehiclekeys:AddKey(entity, source)
        elseif resource == 'qbx_vehiclekeys' then
            exports.qbx_vehiclekeys:GiveKeys(source, entity)
        end
    end)
    if not ok then print(('[%s] Could not give vehicle keys (%s): %s'):format(RESOURCE, resource, err)) end
    return ok
end

function Bridge.removeKeys(source, entity)
    local resource = keysResource()
    if not resource or not source or not GetPlayerName(source)
        or not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    return pcall(function()
        if resource == 'mk_vehiclekeys' then
            exports.mk_vehiclekeys:RemoveKey(entity, source)
        elseif resource == 'qbx_vehiclekeys' then
            exports.qbx_vehiclekeys:RemoveKeys(source, entity)
        end
    end)
end

function Bridge.notify(source, description, nType)
    TriggerClientEvent('ox_lib:notify', source, {
        title = Config.App.name,
        description = description,
        type = nType or 'inform',
        icon = 'dharmachakra',
    })
end
