Security = {}

local RESOURCE = GetCurrentResourceName()
local lastCall = {} -- [source][key] = GetGameTimer() of the last accepted call
local locks = {}    -- [source] = true while a request of this player is being processed

---Per-player rate limit. Returns false when the action is repeated too quickly.
---@param source number
---@param key string
---@param ms number minimum interval
---@return boolean
function Security.throttle(source, key, ms)
    local now = GetGameTimer()
    local calls = lastCall[source]
    if not calls then
        calls = {}
        lastCall[source] = calls
    end
    if calls[key] and now - calls[key] < ms then return false end
    calls[key] = now
    return true
end

---Exclusive per-player lock, so parallel requests (double clicks, event spam) never run twice.
---@return boolean acquired
function Security.lock(source)
    if locks[source] then return false end
    locks[source] = true
    return true
end

function Security.unlock(source)
    locks[source] = nil
end

local function sendWebhook(message)
    local url = Config.Security.webhook
    if not url or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = Config.App.name,
        embeds = { {
            title = 'Possible exploit',
            description = message,
            color = 16729943,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }), { ['Content-Type'] = 'application/json' })
end

---Logs a suspected exploit and optionally drops the player.
---@param source number
---@param reason string
function Security.flag(source, reason)
    local name = GetPlayerName(source) or '?'
    local license = GetPlayerIdentifierByType(source, 'license') or '?'
    local message = ('%s (ID %d, %s): %s'):format(name, source, license, reason)
    print(('^1[%s] POSSIBLE EXPLOIT^7 %s'):format(RESOURCE, message))
    sendWebhook(message)
    if Config.Security.dropPlayer then
        DropPlayer(source, ('[%s] %s'):format(Config.App.name, L('kick_reason')))
    end
end

AddEventHandler('playerDropped', function()
    lastCall[source] = nil
    locks[source] = nil
end)
