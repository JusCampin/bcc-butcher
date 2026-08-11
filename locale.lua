Locales = Locales or {}

function _U(key, ...)
    local locale = Locales[Config.defaultlang] or Locales.en_lang or {}
    local fallback = Locales.en_lang or {}
    local value = locale[key] or fallback[key] or key
    if select('#', ...) == 0 then return value end

    local success, formatted = pcall(string.format, value, ...)
    return success and formatted or value
end
