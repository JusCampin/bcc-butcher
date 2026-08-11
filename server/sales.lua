local function validSite(sourceId, siteId)
    local site = type(siteId) == 'string' and ButcherLocations[siteId] or nil
    local playerPed = site and GetPlayerPed(sourceId) or 0
    if not site or playerPed == 0 then return false end
    local maximumDistance = (tonumber(Config.interactionDistance) or 2.0) + 3.0
    return #(GetEntityCoords(playerPed) - site.coords) <= maximumDistance
end

---@param sourceId number
---@param wagonId number
---@param siteId string
---@param callback fun(success: boolean, result: table|string)
local function getCargoQuote(sourceId, wagonId, siteId, callback)
    if not validSite(sourceId, siteId) then
        DBG:Warning(('Butcher quote rejected: player %s is not near site %s.'):format(
            tostring(sourceId), tostring(siteId)
        ))
        return callback(false, 'invalid_site')
    end
    local ok, started = pcall(function()
        return exports['bcc-hunting-wagon']:GetButcherCargo(sourceId, wagonId, function(success, cargo)
            if not success or type(cargo) ~= 'table' then
                DBG:Warning(('Butcher quote rejected by hunting wagon: player=%s wagon=%s reason=%s'):format(
                    tostring(sourceId), tostring(wagonId), tostring(cargo)
                ))
                return callback(false, cargo)
            end
            ---@cast cargo table
            callback(true, BuildButcherQuote(cargo, siteId))
        end)
    end)
    if not ok or started == false then
        DBG:Error(('Butcher cargo export failed: %s'):format(tostring(started)))
        callback(false, 'export_failed')
    end
end

local function getExternalCarcassQuote(sourceId, netId, siteId, sourceType, maximumEntityDistance)
    netId = tonumber(netId)
    if not netId or netId <= 0 or not validSite(sourceId, siteId) then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 1 then return nil end
    if GetEntityHealth(entity) > 0 then return nil end
    local playerPed = GetPlayerPed(sourceId)
    maximumEntityDistance = tonumber(maximumEntityDistance) or 3.0
    if playerPed == 0
        or #(GetEntityCoords(playerPed) - GetEntityCoords(entity)) > maximumEntityDistance
    then
        return nil
    end
    if NetworkGetEntityOwner(entity) ~= sourceId then return nil end

    local state = Entity(entity).state
    local quality = tonumber(state.bccWagonQuality)
    if quality == nil then return nil end
    local priced = GetButcherItemQuote({
        id = 0,
        modelHash = GetEntityModel(entity),
        units = 1,
        quality = quality,
        isSkinned = state.bccWagonSkinned == true,
    }, siteId)
    if not priced then return nil end
    priced.source = sourceType
    priced.netId = netId
    return priced
end

local function getCarriedQuote(sourceId, netId, siteId)
    return getExternalCarcassQuote(
        sourceId,
        netId,
        siteId,
        'carried',
        Config.carriedEntityDistance
    )
end

local function getHorseQuote(sourceId, horseNetId, carcassNetId, siteId)
    horseNetId = tonumber(horseNetId)
    carcassNetId = tonumber(carcassNetId)
    if not horseNetId or horseNetId <= 0 or not carcassNetId or carcassNetId <= 0 then
        return nil
    end
    local horse = NetworkGetEntityFromNetworkId(horseNetId)
    local playerPed = GetPlayerPed(sourceId)
    local maximumDistance = tonumber(Config.horseEntityDistance) or 10.0
    if horse == 0
        or not DoesEntityExist(horse)
        or GetEntityType(horse) ~= 1
        or NetworkGetEntityOwner(horse) ~= sourceId
        or playerPed == 0
        or #(GetEntityCoords(playerPed) - GetEntityCoords(horse)) > maximumDistance
    then
        return nil
    end

    local quote = getExternalCarcassQuote(
        sourceId,
        carcassNetId,
        siteId,
        'horse',
        maximumDistance + 3.0
    )
    if not quote then return nil end
    local carcass = NetworkGetEntityFromNetworkId(carcassNetId)
    if carcass == 0 or #(GetEntityCoords(horse) - GetEntityCoords(carcass)) > 4.0 then return nil end
    quote.horseNetId = horseNetId
    return quote
end

Core.Callback.Register('bcc-butcher:GetWagonQuote', function(source, cb, data)
    DBG:Info(('Butcher quote request received: player=%s site=%s wagon=%s'):format(
        tostring(source),
        tostring(type(data) == 'table' and data.siteId or nil),
        tostring(type(data) == 'table' and data.wagonId or nil)
    ))
    if type(data) ~= 'table' or type(data.siteId) ~= 'string' then
        return cb(false, 'invalid_request')
    end
    local wagonId = tonumber(data.wagonId)
    if not wagonId then return cb(false, 'invalid_request') end
    getCargoQuote(source, wagonId, data.siteId, cb)
end)

RegisterNetEvent('bcc-butcher:server:RequestWagonQuote', function(
    requestId,
    siteId,
    wagonId,
    carriedNetId,
    horseNetId,
    horseCarcassNetIds
)
    local src = source
    requestId = tonumber(requestId)
    wagonId = tonumber(wagonId)
    carriedNetId = tonumber(carriedNetId)
    horseNetId = tonumber(horseNetId)
    horseCarcassNetIds = type(horseCarcassNetIds) == 'table' and horseCarcassNetIds or {}
    if not requestId
        or type(siteId) ~= 'string'
        or (not wagonId and not carriedNetId and #horseCarcassNetIds == 0)
    then
        return TriggerClientEvent('bcc-butcher:client:WagonQuote', src, requestId, false, 'invalid_request')
    end

    DBG:Info(('Butcher quote event received: player=%s site=%s wagon=%s carried=%s horseItems=%s'):format(
        tostring(src), tostring(siteId), tostring(wagonId), tostring(carriedNetId), tostring(#horseCarcassNetIds)
    ))
    local responded = false
    local function respond(success, result)
        if responded then return end
        responded = true
        TriggerClientEvent('bcc-butcher:client:WagonQuote', src, requestId, success, result)
    end

    local function includeCarried(success, result)
        local quote = success and type(result) == 'table' and result
            or { wagonId = nil, used = 0, capacity = 0, items = {}, total = 0 }
        for _, item in ipairs(quote.items or {}) do item.source = 'wagon' end
        local carried = getCarriedQuote(src, carriedNetId, siteId)
        if carried then
            quote.items[#quote.items + 1] = carried
            quote.total = math.floor(((tonumber(quote.total) or 0) + carried.price) * 100 + 0.5) / 100
        end
        local seenHorseCarcasses = {}
        for index = 1, math.min(#horseCarcassNetIds, 6) do
            local carcassNetId = tonumber(horseCarcassNetIds[index])
            if carcassNetId and not seenHorseCarcasses[carcassNetId] then
                seenHorseCarcasses[carcassNetId] = true
                local horseItem = getHorseQuote(src, horseNetId, carcassNetId, siteId)
                if horseItem then
                    quote.items[#quote.items + 1] = horseItem
                    quote.total = math.floor(((tonumber(quote.total) or 0) + horseItem.price) * 100 + 0.5) / 100
                end
            end
        end
        if #quote.items == 0 then return respond(false, result or 'nothing_to_sell') end
        respond(true, quote)
    end
    if wagonId then
        getCargoQuote(src, wagonId, siteId, includeCarried)
    else
        includeCarried(false, 'no_wagon')
    end
    SetTimeout(8000, function()
        if not responded then respond(false, 'server_timeout') end
    end)
end)

RegisterNetEvent('bcc-butcher:server:SellHorseCarcass', function(requestId, siteId, horseNetId, netId)
    local src = source
    netId = tonumber(netId)
    if not netId then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'invalid_carcass')
    end
    local quote = getHorseQuote(src, horseNetId, netId, siteId)
    if not quote then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'invalid_carcass')
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local character = GetButcherCharacter(src)
    if not character then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'payment_failed')
    end
    ---@cast character table
    local paid = pcall(function()
        character.addCurrency(Config.currency, quote.price)
    end)
    if not paid then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'payment_failed')
    end

    DeleteEntity(entity)
    SetTimeout(250, function()
        if DoesEntityExist(entity) then
            pcall(function() character.removeCurrency(Config.currency, quote.price) end)
            return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'delete_failed')
        end
        TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, true, {
            total = quote.price,
            count = 1,
        })
    end)
end)

RegisterNetEvent('bcc-butcher:server:SellHorseCargo', function(requestId, siteId, horseNetId, netIds)
    local src = source
    if ActiveSales[src] or type(netIds) ~= 'table' then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'busy')
    end

    local quotes, entities, seen, total = {}, {}, {}, 0
    for index = 1, math.min(#netIds, 6) do
        local netId = tonumber(netIds[index])
        if netId and not seen[netId] then
            seen[netId] = true
            local quote = getHorseQuote(src, horseNetId, netId, siteId)
            local entity = NetworkGetEntityFromNetworkId(netId)
            if not quote or entity == 0 then
                return TriggerClientEvent(
                    'bcc-butcher:client:CarriedSaleResult',
                    src,
                    requestId,
                    false,
                    'invalid_carcass'
                )
            end
            quotes[#quotes + 1] = quote
            entities[#entities + 1] = entity
            total = total + quote.price
        end
    end
    if #quotes == 0 then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'invalid_request')
    end

    total = math.floor(total * 100 + 0.5) / 100
    ActiveSales[src] = true
    local character = GetButcherCharacter(src)
    if not character then
        ActiveSales[src] = nil
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'payment_failed')
    end
    ---@cast character table
    local paid = pcall(function()
        character.addCurrency(Config.currency, total)
    end)
    if not paid then
        ActiveSales[src] = nil
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'payment_failed')
    end

    for _, entity in ipairs(entities) do DeleteEntity(entity) end
    SetTimeout(250, function()
        for _, entity in ipairs(entities) do
            if DoesEntityExist(entity) then
                ActiveSales[src] = nil
                pcall(function() character.removeCurrency(Config.currency, total) end)
                return TriggerClientEvent(
                    'bcc-butcher:client:CarriedSaleResult',
                    src,
                    requestId,
                    false,
                    'delete_failed'
                )
            end
        end
        ActiveSales[src] = nil
        TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, true, {
            total = total,
            count = #entities,
        })
    end)
end)

RegisterNetEvent('bcc-butcher:server:SellCarriedCarcass', function(requestId, siteId, netId)
    local src = source
    netId = tonumber(netId)
    if not netId then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'invalid_carcass')
    end
    local quote = getCarriedQuote(src, netId, siteId)
    if not quote then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'invalid_carcass')
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    local character = GetButcherCharacter(src)
    if not character then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'payment_failed')
    end
    ---@cast character table
    local paid = pcall(function()
        character.addCurrency(Config.currency, quote.price)
    end)
    if not paid then
        return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'payment_failed')
    end

    DeleteEntity(entity)
    SetTimeout(250, function()
        if DoesEntityExist(entity) then
            pcall(function() character.removeCurrency(Config.currency, quote.price) end)
            return TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, false, 'delete_failed')
        end
        TriggerClientEvent('bcc-butcher:client:CarriedSaleResult', src, requestId, true, {
            total = quote.price,
            count = 1,
        })
    end)
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
        if not character then
            return exports['bcc-hunting-wagon']:FinalizeButcherCargo(reservation.token, false, function()
                ActiveSales[src] = nil
                cb(false, 'payment_failed')
            end)
        end
        ---@cast character table
        local paid = pcall(function()
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
