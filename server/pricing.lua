local function roundCurrency(value)
    return math.floor((tonumber(value) or 0) * 100 + 0.5) / 100
end

function GetButcherItemQuote(item, siteId)
    local animal = exports['bcc-animal-data']:GetAnimal(item.modelHash)
    if type(animal) ~= 'table' or animal.butcherable == false then return nil end

    local model = string.lower(tostring(animal.model or ''))
    local category = tostring(animal.category or '')
    local site = ButcherLocations[siteId]
    if type(site) ~= 'table'
        or ButcherPricing.refusedCategories[category] == true
        or ButcherPricing.refusedAnimals[model] == true
        or (type(site.refusedAnimals) == 'table' and site.refusedAnimals[model] == true)
    then
        return nil
    end

    local override = ButcherPricing.animals[model]
    if type(override) == 'table' and override.refused == true then return nil end
    local basePrice = type(override) == 'table' and tonumber(override.basePrice)
        or tonumber(ButcherPricing.categories[category])
    if not basePrice or basePrice <= 0 then return nil end

    local quality = math.max(0, math.min(2, tonumber(item.quality) or 0))
    local qualityMultiplier = tonumber(ButcherPricing.qualityMultipliers[quality]) or 1.0
    local stateKey = item.isSkinned and 'skinned' or 'unskinned'
    local stateMultiplier = tonumber(ButcherPricing.stateMultipliers[stateKey]) or 1.0
    local siteMultiplier = tonumber(site and site.priceMultiplier) or 1.0
    local categoryMultiplier = type(site.categoryMultipliers) == 'table'
        and tonumber(site.categoryMultipliers[category]) or 1.0
    if categoryMultiplier <= 0 then return nil end
    local legendaryMultiplier = animal.legendary == true
        and (tonumber(ButcherPricing.legendaryMultiplier) or 1.0) or 1.0
    local price = roundCurrency(
        basePrice
        * qualityMultiplier
        * stateMultiplier
        * siteMultiplier
        * categoryMultiplier
        * legendaryMultiplier
    )
    if price < (tonumber(ButcherPricing.minimumPayout) or 0.01) then return nil end

    return {
        id = tonumber(item.id),
        modelHash = tonumber(item.modelHash),
        animal = animal.model,
        label = animal.label,
        category = category,
        legendary = animal.legendary == true,
        units = math.max(1, tonumber(item.units) or 1),
        quality = quality,
        isSkinned = item.isSkinned == true,
        price = price,
    }
end

---@param cargo table
---@param siteId string
---@return table
function BuildButcherQuote(cargo, siteId)
    local quote = { wagonId = cargo.wagonId, used = cargo.used, capacity = cargo.capacity, items = {}, total = 0 }
    for _, item in ipairs(cargo.items or {}) do
        local priced = GetButcherItemQuote(item, siteId)
        if priced then
            quote.items[#quote.items + 1] = priced
            quote.total = roundCurrency(quote.total + priced.price)
        end
    end
    return quote
end
