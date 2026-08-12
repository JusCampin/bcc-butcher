ButcherLocations = {
    valentine = {
        label = 'Valentine Butcher',
        coords = vector3(-339.20, 767.70, 116.56),
        npc = {
            enabled = true,
            model = 'u_m_m_valbutcher_01',
            coords = vector4(-339.20, 767.70, 116.56, 103.0),
        },
        blip = {
            enabled = true,
            sprite = 'blip_shop_butcher',
        },
        priceMultiplier = 1.0,
        -- Optional economy controls for this butcher. Missing categories use
        -- 1.0; setting a category to 0 refuses it at this location.
        categoryMultipliers = {
            -- fish = 1.10,
        },
        refusedAnimals = {
            -- a_c_bear_01 = true,
        },
    },
}
