Store = {}

local RESOURCE = GetCurrentResourceName()

---------------------------------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------------------------------
CreateThread(function()
    Bridge.init()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `daily_spins` (
            `identifier`    VARCHAR(64) NOT NULL,
            `last_spin`     INT UNSIGNED NOT NULL DEFAULT 0,
            `total_spins`   INT UNSIGNED NOT NULL DEFAULT 0,
            `total_earned`  BIGINT UNSIGNED NOT NULL DEFAULT 0,
            `missions_done` INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (`identifier`)
        )
    ]])
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `daily_spins_log` (
            `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `identifier` VARCHAR(64) NOT NULL,
            `kind`       VARCHAR(16) NOT NULL,
            `label`      VARCHAR(64) NOT NULL,
            `amount`     INT NOT NULL DEFAULT 0,
            `created_at` INT UNSIGNED NOT NULL,
            PRIMARY KEY (`id`),
            KEY `identifier` (`identifier`)
        )
    ]])
end)

function Store.log(key, kind, label, amount)
    MySQL.insert('INSERT INTO `daily_spins_log` (`identifier`, `kind`, `label`, `amount`, `created_at`) VALUES (?, ?, ?, ?, ?)',
        { key, kind, label, amount or 0, os.time() })
end

function Store.addEarned(key, amount)
    MySQL.update('UPDATE `daily_spins` SET `total_earned` = `total_earned` + ? WHERE `identifier` = ?', { amount, key })
end

function Store.missionDone(key, amount)
    MySQL.update('UPDATE `daily_spins` SET `total_earned` = `total_earned` + ?, `missions_done` = `missions_done` + 1 WHERE `identifier` = ?',
        { amount, key })
end

---------------------------------------------------------------------------------------------------
-- Cooldown
---------------------------------------------------------------------------------------------------

---Most recent daily reset that is <= now ('daily' mode).
local function lastReset(now)
    local t = os.date('*t', now)
    t.hour, t.min, t.sec = Config.Cooldown.resetHour, 0, 0
    local boundary = os.time(t)
    if boundary > now then boundary = boundary - 86400 end
    return boundary
end

---A spin is allowed when last_spin <= this value.
local function spinThreshold(now)
    if Config.Cooldown.mode == 'daily' then return lastReset(now) - 1 end
    return now - math.floor(Config.Cooldown.hours * 3600)
end

---Unix time of the next allowed spin, 0 when a spin is available right now.
local function nextSpinAt(lastSpin, now)
    if lastSpin <= spinThreshold(now) then return 0 end
    if Config.Cooldown.mode == 'daily' then return lastReset(now) + 86400 end
    return lastSpin + math.floor(Config.Cooldown.hours * 3600)
end

---------------------------------------------------------------------------------------------------
-- Wheel
---------------------------------------------------------------------------------------------------
local totalWeight = 0
for i = 1, #Config.Wheel.segments do
    totalWeight = totalWeight + Config.Wheel.segments[i].weight
end

local function pickSegment()
    local roll = math.random() * totalWeight
    for i = 1, #Config.Wheel.segments do
        roll = roll - Config.Wheel.segments[i].weight
        if roll <= 0 then return i end
    end
    return #Config.Wheel.segments
end

-- What the app is allowed to see of the wheel (no weights unless odds are shown)
local publicSegments = {}
for i, seg in ipairs(Config.Wheel.segments) do
    publicSegments[i] = {
        type   = seg.type,
        label  = seg.label,
        icon   = seg.icon,
        color  = seg.color,
        amount = seg.amount,
        chance = Config.Wheel.showChances and math.floor(seg.weight / totalWeight * 1000 + 0.5) / 10 or nil,
    }
end

---------------------------------------------------------------------------------------------------
-- App state
---------------------------------------------------------------------------------------------------
local function buildState(source)
    local key = Bridge.getSpinKey(source)
    if not key then return { ready = false } end

    local now = os.time()
    local row = MySQL.single.await('SELECT `last_spin`, `total_spins`, `total_earned`, `missions_done` FROM `daily_spins` WHERE `identifier` = ?', { key })
    local history = MySQL.query.await('SELECT `kind`, `label`, `amount`, `created_at` FROM `daily_spins_log` WHERE `identifier` = ? ORDER BY `id` DESC LIMIT 10', { key })

    return {
        ready        = true,
        now          = now,
        nextSpinAt   = nextSpinAt(row and row.last_spin or 0, now),
        spinDuration = Config.Wheel.spinDuration,
        segments     = publicSegments,
        showChances  = Config.Wheel.showChances,
        mission      = Missions.public(Missions.get(source)),
        stats        = {
            spins    = row and row.total_spins or 0,
            earned   = row and row.total_earned or 0,
            missions = row and row.missions_done or 0,
        },
        history      = history or {},
    }
end

local function doSpin(source)
    local key = Bridge.getSpinKey(source)
    if not key then return { ok = false, error = 'no_character' } end
    if Missions.get(source) then return { ok = false, error = 'finish_mission' } end

    local now = os.time()
    MySQL.insert.await('INSERT IGNORE INTO `daily_spins` (`identifier`) VALUES (?)', { key })

    -- Atomic: only ONE update can pass the cooldown condition, no matter how many requests race
    local affected = MySQL.update.await(
        'UPDATE `daily_spins` SET `last_spin` = ?, `total_spins` = `total_spins` + 1 WHERE `identifier` = ? AND `last_spin` <= ?',
        { now, key, spinThreshold(now) })
    if affected ~= 1 then
        return { ok = false, error = 'already_spun', state = buildState(source) }
    end

    local index = pickSegment()
    local seg = Config.Wheel.segments[index]
    local result = { type = seg.type, label = seg.label, amount = seg.amount, icon = seg.icon }

    if seg.type == 'cash' then
        if not Bridge.addMoney(source, Config.Wheel.cashAccount, seg.amount, 'daily-spins') then
            print(('[%s] Payout failed: $%d to %d (%s)'):format(RESOURCE, seg.amount, source, key))
        end
        Store.log(key, 'cash', seg.label, seg.amount)
        Store.addEarned(key, seg.amount)
    elseif seg.type == 'mission' then
        local m = Missions.create(source, key, seg.mission)
        if m then
            result.mission = Missions.public(m)
            Store.log(key, 'mission', m.cfg.label, 0)
        else
            print(('[%s] Mission "%s" is not configured - counting the spin as empty'):format(RESOURCE, tostring(seg.mission)))
            result.type = 'empty'
            Store.log(key, 'empty', seg.label, 0)
        end
    else
        Store.log(key, 'empty', seg.label, 0)
    end

    if Config.Debug then
        print(('[%s] %s (%d) spun: %s'):format(RESOURCE, GetPlayerName(source), source, seg.label))
    end

    return { ok = true, index = index, result = result, state = buildState(source) }
end

---Runs fn under the per-player lock, so a spin and mission steps can never run in parallel.
local function guarded(source, fn, ...)
    if not Security.lock(source) then return { ok = false, error = 'please_wait' } end
    local ok, res = pcall(fn, ...)
    Security.unlock(source)
    if not ok then
        print(('[%s] Error: %s'):format(RESOURCE, res))
        return { ok = false, error = 'internal_error' }
    end
    return res
end

---------------------------------------------------------------------------------------------------
-- Callbacks (the client never sends amounts, results or positions - only intents)
---------------------------------------------------------------------------------------------------
lib.callback.register('daily-spins:server:getState', function(source)
    if not Security.throttle(source, 'state', 400) then return nil end
    return buildState(source)
end)

lib.callback.register('daily-spins:server:spin', function(source)
    if not Security.throttle(source, 'spin', 2500) then return { ok = false, error = 'please_wait' } end
    return guarded(source, doSpin, source)
end)

lib.callback.register('daily-spins:server:step', function(source, index)
    if not Security.throttle(source, 'step', 1000) then return { ok = false, error = 'please_wait' } end
    return guarded(source, function()
        local ok, err = Missions.step(source, tonumber(index))
        return { ok = ok, error = err }
    end)
end)

lib.callback.register('daily-spins:server:cancel', function(source)
    if not Security.throttle(source, 'cancel', 1500) then return { ok = false, error = 'please_wait' } end
    return guarded(source, function()
        return { ok = Missions.cancel(source) }
    end)
end)

-- A character logout without leaving the server ends the running mission
local function onLogout(playerId)
    playerId = tonumber(playerId)
    if playerId and Missions.get(playerId) then Missions.finish(playerId, false, 'mission_cancelled') end
end
AddEventHandler('QBCore:Server:OnPlayerUnload', onLogout)
AddEventHandler('esx:playerLogout', onLogout)

---------------------------------------------------------------------------------------------------
-- Admin
---------------------------------------------------------------------------------------------------
lib.addCommand('dailyspins_reset', {
    help = L('reset_help'),
    params = { { name = 'target', type = 'playerId', help = L('reset_param'), optional = true } },
    restricted = Config.AdminGroup,
}, function(source, args)
    local target = args.target or source
    if not target or target == 0 then return end
    local key = Bridge.getSpinKey(target)
    if not key then
        if source > 0 then Bridge.notify(source, L('no_character'), 'error') end
        return
    end
    MySQL.update.await('UPDATE `daily_spins` SET `last_spin` = 0 WHERE `identifier` = ?', { key })
    TriggerClientEvent('daily-spins:client:refresh', target)
    if source > 0 then Bridge.notify(source, L('reset_done', GetPlayerName(target)), 'success') end
    print(('[%s] Cooldown of %s (%s) reset'):format(RESOURCE, GetPlayerName(target), key))
end)
