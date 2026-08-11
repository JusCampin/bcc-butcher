local function roundCurrency(value)
    return math.floor((tonumber(value) or 0) * 100 + 0.5) / 100
end

function GetButcherItemQuote(item, siteId)
    local animal = exports['bcc-animal-data']:GetAnimal(item.modelHash)
    if type(animal) ~= 'table' or animal.butcherable == false then return nil end

    local basePrice = tonumber(ButcherPricing.animals[animal.model])
        or tonumber(ButcherPricing.categories[animal.category])
    if not basePrice then return nil end

    local quality = math.max(0, math.min(2, tonumber(item.quality) or 0))
    local qualityMultiplier = tonumber(ButcherPricing.qualityMultipliers[quality]) or 1.0
    local stateKey = item.isSkinned and 'skinned' or 'unskinned'
    local stateMultiplier = tonumber(ButcherPricing.stateMultipliers[stateKey]) or 1.0
    local site = ButcherLocations[siteId]
    local siteMultiplier = tonumber(site and site.priceMultiplier) or 1.0

    return {
        id = tonumber(item.id),
        modelHash = tonumber(item.modelHash),
        animal = animal.model,
        label = animal.label,
        category = animal.category,
        units = math.max(1, tonumber(item.units) or 1),
        quality = quality,
        isSkinned = item.isSkinned == true,
        price = roundCurrency(basePrice * qualityMultiplier * stateMultiplier * siteMultiplier),
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
