local function validSite(sourceId, siteId)
    local site = type(siteId) == 'string' and ButcherLocations[siteId] or nil
    local playerPed = site and GetPlayerPed(sourceId) or 0
    if not site or playerPed == 0 then return false end
    local maximumDistance = (tonumber(Config.interactionDistance) or 2.0) + 3.0
    return #(GetEntityCoords(playerPed) - site.coords) <= maximumDistance
end

local function getCargoQuote(sourceId, wagonId, siteId, callback)
    if not validSite(sourceId, siteId) then return callback(false, 'invalid_site') end
    exports['bcc-hunting-wagon']:GetButcherCargo(sourceId, wagonId, function(success, cargo)
        if not success or type(cargo) ~= 'table' then return callback(false, cargo) end
        callback(true, BuildButcherQuote(cargo, siteId))
    end)
end

Core.Callback.Register('bcc-butcher:GetWagonQuote', function(source, cb, data)
    if type(data) ~= 'table' then return cb(false, 'invalid_request') end
    getCargoQuote(source, tonumber(data.wagonId), data.siteId, cb)
end)

Core.Callback.Register('bcc-butcher:SellWagonCargo', function(source, cb, data)
    local src = source
    if ActiveSales[src] or type(data) ~= 'table' or not validSite(src, data.siteId) then
        return cb(false, 'busy')
    end

    local wagonId = tonumber(data.wagonId)
    local cargoIds = type(data.cargoIds) == 'table' and data.cargoIds or {}
    if not wagonId or #cargoIds == 0 then return cb(false, 'invalid_request') end
    ActiveSales[src] = true

    exports['bcc-hunting-wagon']:ReserveButcherCargo(src, wagonId, cargoIds, function(success, reservation)
        if not success or type(reservation) ~= 'table' then
            ActiveSales[src] = nil
            return cb(false, reservation or 'reserve_failed')
        end

        local cargo = { wagonId = wagonId, items = reservation.items }
        local quote = BuildButcherQuote(cargo, data.siteId)
        if #quote.items ~= #reservation.items or quote.total <= 0 then
            return exports['bcc-hunting-wagon']:FinalizeButcherCargo(reservation.token, false, function()
                ActiveSales[src] = nil
                cb(false, 'invalid_price')
            end)
        end

        local character = GetButcherCharacter(src)
        local paid = character and pcall(function()
            character.addCurrency(Config.currency, quote.total)
        end)
        if not paid then
            return exports['bcc-hunting-wagon']:FinalizeButcherCargo(reservation.token, false, function()
                ActiveSales[src] = nil
                cb(false, 'payment_failed')
            end)
        end

        exports['bcc-hunting-wagon']:FinalizeButcherCargo(reservation.token, true, function(finalized)
            ActiveSales[src] = nil
            if not finalized then
                pcall(function() character.removeCurrency(Config.currency, quote.total) end)
                return cb(false, 'finalize_failed')
            end
            cb(true, { total = quote.total, count = #quote.items })
        end)
    end)
end)

AddEventHandler('playerDropped', function()
    ActiveSales[source] = nil
end)
