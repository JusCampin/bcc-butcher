ButcherPricing = {
    minimumPayout = 0.01,
    legendaryMultiplier = 2.00,

    categories = {
        tiny = 0.25,
        small = 0.75,
        medium = 1.50,
        large = 4.00,
        massive = 7.00,
        bird = 0.75,
        fish = 1.00,
    },

    qualityMultipliers = {
        [0] = 0.50,
        [1] = 0.75,
        [2] = 1.00,
    },

    stateMultipliers = {
        unskinned = 1.00,
        skinned = 0.45,
    },

    -- Categories and models listed here are refused even if animal data marks
    -- them butcherable. This keeps economy policy local to this resource.
    refusedCategories = {
        pelt = true,
        aquatic = true,
    },

    refusedAnimals = {
        -- a_c_lionmangy_01 = true,
    },

    -- Per-model overrides replace the category base price. Set refused = true
    -- to disable one animal without changing bcc-animal-data.
    animals = {
        a_c_deer_01 = { basePrice = 5.00 },
        a_c_buck_01 = { basePrice = 6.50 },
        a_c_bear_01 = { basePrice = 12.00 },
    },
}
