Core = exports.vorp_core:GetCore()
local utils = exports['bcc-utils'].initiate()
DBG = utils.Debug:Get('bcc-butcher', Config.development.enabled)
if DBG then DBG:Enable() end

ActiveSales = {}

function GetButcherCharacter(sourceId)
    local user = Core.getUser(sourceId)
    return user and user.getUsedCharacter or nil
end
