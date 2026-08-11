local function stars(quality)
    return string.rep('★', math.max(0, math.min(2, tonumber(quality) or 0)) + 1)
end

local function itemLabel(item, includeSource)
    local label = ('%s  %s  —  $%.2f'):format(item.label, stars(item.quality), item.price)
    if item.isSkinned then label = label .. '  ·  ' .. _U('skinned') end
    if includeSource and item.source == 'carried' then label = _U('carried') .. '  ' .. label end
    if includeSource and item.source == 'horse' then label = _U('horse') .. '  ' .. label end
    if includeSource and item.source == 'wagon' then label = _U('wagon') .. '  ' .. label end
    return label
end

local function activeWagonId()
    local wagon = exports['bcc-wagons']:GetActiveWagon()
    return type(wagon) == 'table' and tonumber(wagon.id) or nil
end

local function carriedCarcassNetId()
    local carcass = Citizen.InvokeNative(0xD806CD2A4F2C2996, PlayerPedId())
    if not carcass or carcass == 0 or not DoesEntityExist(carcass) or not IsEntityDead(carcass) then
        return nil
    end
    local netId = NetworkGetNetworkIdFromEntity(carcass)
    return netId and netId ~= 0 and netId or nil
end

local function horseCarcassData()
    local horse = Citizen.InvokeNative(0x4C8B59171957BCF7, PlayerPedId())
    if not horse or horse == 0 or not DoesEntityExist(horse) then return nil, {} end
    local horseNetId = NetworkGetNetworkIdFromEntity(horse)
    if not horseNetId or horseNetId == 0 then return nil, {} end

    local carcassNetIds, seen = {}, {}
    local function includeCarcass(carcass)
        if not carcass or carcass == 0 or carcass == horse
            or not DoesEntityExist(carcass) or not IsEntityDead(carcass)
        then
            return
        end
        local netId = NetworkGetNetworkIdFromEntity(carcass)
        if netId and netId ~= 0 and not seen[netId] then
            seen[netId] = true
            carcassNetIds[#carcassNetIds + 1] = netId
        end
    end

    -- The carry native exposes the primary carcass, while the entity pool catches
    -- additional small carcasses attached to the saddle.
    includeCarcass(Citizen.InvokeNative(0xD806CD2A4F2C2996, horse))
    for _, ped in ipairs(GetGamePool('CPed')) do
        if IsEntityAttachedToEntity(ped, horse) then includeCarcass(ped) end
    end
    return horseNetId, carcassNetIds
end

local isOpeningMenu = false
local quoteRequestSequence = 0
local activeQuoteRequest
local buildMenu

RegisterNetEvent('bcc-butcher:client:WagonQuote', function(requestId, success, result)
    if tonumber(requestId) ~= activeQuoteRequest then return end
    activeQuoteRequest = nil
    isOpeningMenu = false

    if not success or type(result) ~= 'table' then
        if Config.development and Config.development.enabled then
            DBG:Warning(('Butcher quote failed: reason=%s'):format(tostring(result)))
        end
        return Core.NotifyRightTip(_U('quoteFailed'), 4000)
    end
    buildMenu(CurrentButcherSite, result)
end)

RegisterNetEvent('bcc-butcher:client:CarriedSaleResult', function(_, success, result)
    if not success or type(result) ~= 'table' then
        return Core.NotifyRightTip(_U('saleFailed'), 4000)
    end
    Core.NotifyRightTip(_U('saleComplete') .. ('%.2f.'):format(result.total), 4000)
end)

local function sellCarried(siteId, netId)
    quoteRequestSequence = quoteRequestSequence + 1
    TriggerServerEvent('bcc-butcher:server:SellCarriedCarcass', quoteRequestSequence, siteId, netId)
end

local function sellHorseCarcass(siteId, horseNetId, netId)
    quoteRequestSequence = quoteRequestSequence + 1
    TriggerServerEvent(
        'bcc-butcher:server:SellHorseCarcass',
        quoteRequestSequence,
        siteId,
        horseNetId,
        netId
    )
end

local function sellHorseCargo(siteId, horseNetId, netIds)
    quoteRequestSequence = quoteRequestSequence + 1
    TriggerServerEvent(
        'bcc-butcher:server:SellHorseCargo',
        quoteRequestSequence,
        siteId,
        horseNetId,
        netIds
    )
end

local function sellCargo(siteId, wagonId, cargoIds)
    Core.Callback.TriggerAsync('bcc-butcher:SellWagonCargo', function(success, result)
        if not success then
            Core.NotifyRightTip(_U('saleFailed'), 4000)
            return
        end
        Core.NotifyRightTip(_U('saleComplete') .. ('%.2f.'):format(result.total), 4000)
        OpenButcherMenu(siteId)
    end, { siteId = siteId, wagonId = wagonId, cargoIds = cargoIds })
end

local function registerConfirmationPage(listPage, siteId, quote, item)
    local pageKey = item and (item.source ~= 'wagon' and (item.source .. ':' .. item.netId) or item.id) or 'all'
    local page = ButcherMenu:RegisterPage('bcc-butcher:confirm:' .. tostring(pageKey))
    local wagonItems, wagonTotal = {}, 0
    for _, cargoItem in ipairs(quote.items) do
        if cargoItem.source == 'wagon' then
            wagonItems[#wagonItems + 1] = cargoItem
            wagonTotal = wagonTotal + cargoItem.price
        end
    end
    local count = item and 1 or #wagonItems
    local total = item and item.price or wagonTotal
    page:RegisterElement('header', { value = _U('confirmSale'), slot = 'header' })
    page:RegisterElement('textdisplay', {
        value = item and itemLabel(item, true)
            or (_U('confirmAllWagon') .. ('%.2f (%d carcasses)'):format(total, count)),
        slot = 'content',
    })
    page:RegisterElement('button', {
        label = item and _U('sellCarcass') or (_U('sellAllWagon') .. ('%.2f'):format(total)),
        slot = 'content',
        style = { ['color'] = '#4F8A4F' },
    }, function()
        ButcherMenu:Close()
        if item and item.source == 'carried' then
            return sellCarried(siteId, item.netId)
        end
        if item and item.source == 'horse' then
            return sellHorseCarcass(siteId, item.horseNetId, item.netId)
        end
        local ids = {}
        if item then
            ids[1] = item.id
        else
            for _, cargoItem in ipairs(wagonItems) do ids[#ids + 1] = cargoItem.id end
        end
        sellCargo(siteId, quote.wagonId, ids)
    end)
    page:RegisterElement('button', { label = _U('back'), slot = 'footer' }, function()
        listPage:RouteTo()
    end)
    return page
end

local function registerHorseCargoConfirmationPage(listPage, siteId, items)
    local page = ButcherMenu:RegisterPage('bcc-butcher:confirm:all-horse')
    local total, netIds, horseNetId = 0, {}, nil
    for _, item in ipairs(items) do
        total = total + item.price
        netIds[#netIds + 1] = item.netId
        horseNetId = horseNetId or item.horseNetId
    end
    page:RegisterElement('header', { value = _U('confirmSale'), slot = 'header' })
    page:RegisterElement('textdisplay', {
        value = _U('confirmAllHorse') .. ('%.2f (%d carcasses)'):format(total, #items),
        slot = 'content',
    })
    page:RegisterElement('button', {
        label = _U('sellAllHorse') .. ('%.2f'):format(total),
        slot = 'content',
        style = { ['color'] = '#4F8A4F' },
    }, function()
        ButcherMenu:Close()
        sellHorseCargo(siteId, horseNetId, netIds)
    end)
    page:RegisterElement('button', { label = _U('back'), slot = 'footer' }, function()
        listPage:RouteTo()
    end)
    return page, total
end

buildMenu = function(siteId, quote)
    if ButcherMenu then ButcherMenu:Close() end
    ---@type any
    ButcherMenu = FeatherMenu:RegisterMenu('bcc-butcher:menu', {
        top = '3%', left = '3%',
        ['720width'] = '400px', ['1080width'] = '500px',
        ['2kwidth'] = '600px', ['4kwidth'] = '800px',
        contentslot = { style = { ['height'] = '440px', ['min-height'] = '300px' } },
        draggable = true, canclose = true,
    })

    local listPage = ButcherMenu:RegisterPage('bcc-butcher:cargo')
    listPage:RegisterElement('header', { value = _U('title'), slot = 'header' })
    listPage:RegisterElement('subheader', {
        value = _U('availableCarcasses'),
        slot = 'header',
        style = { ['color'] = '#CC9900' },
    })
    listPage:RegisterElement('line', { slot = 'header' })

    local groups = { carried = {}, horse = {}, wagon = {} }
    local wagonTotal = 0
    for _, item in ipairs(quote.items) do
        if groups[item.source] then groups[item.source][#groups[item.source] + 1] = item end
        if item.source == 'wagon' then
            wagonTotal = wagonTotal + item.price
        end
    end

    local function registerSection(source, heading)
        local items = groups[source]
        if #items == 0 then return end
        table.sort(items, function(left, right)
            if left.label ~= right.label then return left.label < right.label end
            return left.quality > right.quality
        end)
        listPage:RegisterElement('subheader', {
            value = heading,
            slot = 'content',
            style = { ['color'] = '#CC9900' },
        })
        listPage:RegisterElement('line', { slot = 'content' })
        for _, cargoItem in ipairs(items) do
            local item = cargoItem
            local confirmation = registerConfirmationPage(listPage, siteId, quote, item)
            listPage:RegisterElement('button', {
                label = itemLabel(item), slot = 'content',
                id = tostring(item.source ~= 'wagon' and (item.source .. ':' .. item.netId) or item.id),
            }, function()
                confirmation:RouteTo()
            end)
        end
    end

    registerSection('carried', _U('carriedSection'))
    registerSection('horse', _U('horseSection'))
    if #groups.horse > 1 then
        local sellAllHorsePage, horseTotal = registerHorseCargoConfirmationPage(
            listPage,
            siteId,
            groups.horse
        )
        listPage:RegisterElement('button', {
            label = _U('sellAllHorse') .. ('%.2f'):format(horseTotal), slot = 'content',
            style = { ['color'] = '#4F8A4F' },
        }, function()
            sellAllHorsePage:RouteTo()
        end)
    end
    local wagonHeading = _U('wagonSection')
    if quote.wagonId then
        wagonHeading = wagonHeading .. '  ' .. tostring(quote.used) .. '/' .. tostring(quote.capacity)
    end
    registerSection('wagon', wagonHeading)

    if #groups.wagon > 0 then
        local sellAllPage = registerConfirmationPage(listPage, siteId, quote)
        listPage:RegisterElement('button', {
            label = _U('sellAllWagon') .. ('%.2f'):format(wagonTotal), slot = 'content',
            style = { ['color'] = '#4F8A4F' },
        }, function()
            sellAllPage:RouteTo()
        end)
    elseif #quote.items == 0 then
        listPage:RegisterElement('textdisplay', { value = _U('noCargo'), slot = 'content' })
    end

    listPage:RegisterElement('line', { slot = 'footer' })
    listPage:RegisterElement('button', { label = _U('refresh'), slot = 'footer' }, function()
        ButcherMenu:Close()
        OpenButcherMenu(siteId)
    end)
    listPage:RegisterElement('button', { label = _U('close'), slot = 'footer' }, function()
        ButcherMenu:Close()
    end)
    ButcherMenu:Open({ startupPage = listPage })
end

function OpenButcherMenu(siteId)
    if isOpeningMenu then return false end
    isOpeningMenu = true
    local wagonId = activeWagonId()
    local carriedNetId = carriedCarcassNetId()
    local horseNetId, horseCarcassNetIds = horseCarcassData()
    if not wagonId and not carriedNetId and #horseCarcassNetIds == 0 then
        isOpeningMenu = false
        Core.NotifyRightTip(_U('noWagon'), 4000)
        return false
    end
    CurrentButcherSite = siteId
    quoteRequestSequence = quoteRequestSequence + 1
    local requestId = quoteRequestSequence
    activeQuoteRequest = requestId
    local requestStarted = GetGameTimer()
    TriggerServerEvent(
        'bcc-butcher:server:RequestWagonQuote',
        requestId,
        siteId,
        wagonId,
        carriedNetId,
        horseNetId,
        horseCarcassNetIds
    )
    CreateThread(function()
        Wait(10000)
        if isOpeningMenu
            and activeQuoteRequest == requestId
            and GetGameTimer() - requestStarted >= 10000
        then
            activeQuoteRequest = nil
            isOpeningMenu = false
            DBG:Warning(('Butcher quote timed out: site=%s wagon=%s'):format(
                tostring(siteId), tostring(wagonId)
            ))
            Core.NotifyRightTip(_U('quoteFailed'), 4000)
        end
    end)
    return true
end
