Core = exports.vorp_core:GetCore()
FeatherMenu = exports['feather-menu'].initiate()
local utils = exports['bcc-utils'].initiate()
DBG = utils.Debug:Get('bcc-butcher', Config.development.enabled)
if DBG then DBG:Enable() end

ButcherMenu = nil
CurrentButcherSite = nil
