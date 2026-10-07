local fallback = Locales.en

local function normalize(code)
    if type(code) ~= 'string' then return nil end
    local short = code:lower():match('^(%a%a)')
    return short and Locales[short] and short or nil
end

-- 'auto' starts with the fallback language and follows the phone language once it is known (client only).
local current = Config.Locale ~= 'auto' and normalize(Config.Locale) or normalize(Config.FallbackLocale) or 'en'

---Switches the language when Config.Locale is 'auto'. Accepts codes like 'de', 'de-DE' or 'en_US'.
---@param code string|nil
---@return string language now in use
function SetLanguage(code)
    if Config.Locale ~= 'auto' then return current end
    current = normalize(code) or current
    return current
end

function GetLanguage()
    return current
end

---Returns a translated string. Extra arguments are passed to string.format.
---@param key string
---@return string
function L(key, ...)
    local str = Locales[current][key] or fallback[key] or key
    if select('#', ...) > 0 then return str:format(...) end
    return str
end

---Translates a label that comes from config.lua (keyed by its English text).
---@param text string|nil
---@return string|nil
function LabelOf(text)
    if not text then return nil end
    local labels = Locales[current].labels
    return labels and labels[text] or text
end

---UI strings for the app: active locale on top of the English fallback.
---@return table<string, string>
function UiStrings()
    local out = {}
    for k, v in pairs(fallback.ui) do out[k] = v end
    for k, v in pairs(Locales[current].ui or {}) do out[k] = v end
    return out
end
