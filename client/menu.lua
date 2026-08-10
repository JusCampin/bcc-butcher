local function stars(quality)
    return string.rep('★', math.max(1, math.min(3, tonumber(quality) or 1)))
end

local function itemLabel(item)
    local label = ('%s  %s  —  $%.2f'):format(item.label, stars(item.quality), item.price)
    if item.isSkinned then label = label .. '  ·  ' .. _U('skinned') end
    return label
end

local function activeWagonId()
    local wagon = exports['bcc-wagons']:GetActiveWagon()
    return type(wagon) == 'table' and tonumber(wagon.id) or nil
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
    local page = ButcherMenu:RegisterPage('bcc-butcher:confirm:' .. tostring(item and item.id or 'all'))
    local count = item and 1 or #quote.items
    local total = item and item.price or quote.total
    page:RegisterElement('header', { value = _U('confirmSale'), slot = 'header' })
    page:RegisterElement('textdisplay', {
        value = item and itemLabel(item)
            or (_U('confirmAll') .. ('%.2f (%d carcasses)'):format(total, count)),
        slot = 'content',
    })
    page:RegisterElement('button', {
        label = item and _U('sellCarcass') or (_U('sellAll') .. ('%.2f'):format(total)),
        slot = 'content',
        style = { ['color'] = '#4F8A4F' },
    }, function()
        ButcherMenu:Close()
        local ids = {}
        if item then
            ids[1] = item.id
        else
            for _, cargoItem in ipairs(quote.items) do ids[#ids + 1] = cargoItem.id end
        end
        sellCargo(siteId, quote.wagonId, ids)
    end)
    page:RegisterElement('button', { label = _U('back'), slot = 'footer' }, function()
        listPage:RouteTo()
    end)
    return page
end

local function buildMenu(siteId, quote)
    if ButcherMenu then ButcherMenu:Close() end
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
        value = _U('cargoCapacity') .. tostring(quote.used) .. '/' .. tostring(quote.capacity),
        slot = 'header',
        style = { ['color'] = '#CC9900' },
    })
    listPage:RegisterElement('line', { slot = 'header' })

    table.sort(quote.items, function(left, right)
        if left.label ~= right.label then return left.label < right.label end
        return left.quality > right.quality
    end)
    for _, cargoItem in ipairs(quote.items) do
        local item = cargoItem
        local confirmation = registerConfirmationPage(listPage, siteId, quote, item)
        listPage:RegisterElement('button', {
            label = itemLabel(item), slot = 'content', id = tostring(item.id),
        }, function()
            confirmation:RouteTo()
        end)
    end

    if #quote.items > 0 then
        local sellAllPage = registerConfirmationPage(listPage, siteId, quote)
        listPage:RegisterElement('line', { slot = 'content' })
        listPage:RegisterElement('button', {
            label = _U('sellAll') .. ('%.2f'):format(quote.total), slot = 'content',
            style = { ['color'] = '#4F8A4F' },
        }, function()
            sellAllPage:RouteTo()
        end)
    else
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
    local wagonId = activeWagonId()
    if not wagonId then return Core.NotifyRightTip(_U('noWagon'), 4000) end
    Core.Callback.TriggerAsync('bcc-butcher:GetWagonQuote', function(success, quote)
        if not success or type(quote) ~= 'table' then
            return Core.NotifyRightTip(_U('quoteFailed'), 4000)
        end
        buildMenu(siteId, quote)
    end, { siteId = siteId, wagonId = wagonId })
end
