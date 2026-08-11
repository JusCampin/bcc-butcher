local prompts = {}
local npcs = {}
local blips = {}

local function loadModel(model)
    local hash = joaat(model)
    RequestModel(hash)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(25) end
    return HasModelLoaded(hash) and hash or nil
end

local function createLocation(siteId, site)
    if site.npc and site.npc.enabled then
        local hash = loadModel(site.npc.model)
        if hash then
            local coords = site.npc.coords
            local ped = CreatePed(hash, coords.x, coords.y, coords.z-1, coords.w, false, false, false, false)
            if ped and ped ~= 0 then
                Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                npcs[#npcs + 1] = ped
            end
            SetModelAsNoLongerNeeded(hash)
        end
    end

    local prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, Config.promptControl)
    UiPromptSetText(prompt, CreateVarString(10, 'LITERAL_STRING', _U('prompt')))
    UiPromptSetVisible(prompt, true)
    UiPromptSetEnabled(prompt, true)
    UiPromptSetHoldMode(prompt, Config.promptHoldMs)
    Citizen.InvokeNative(0xAE84C5EE2C384FB3, prompt, site.coords.x, site.coords.y, site.coords.z)
    Citizen.InvokeNative(0x0C718001B77CA468, prompt, Config.interactionDistance)
    UiPromptRegisterEnd(prompt)
    prompts[#prompts + 1] = { handle = prompt, siteId = siteId }

    if site.blip and site.blip.enabled then
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, site.coords.x, site.coords.y, site.coords.z)
        SetBlipSprite(blip, joaat(site.blip.sprite), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, site.label)
        blips[#blips + 1] = blip
    end
end

CreateThread(function()
    for siteId, site in pairs(ButcherLocations) do createLocation(siteId, site) end
    while true do
        Wait(0)
        for _, prompt in ipairs(prompts) do
            if UiPromptHasHoldModeCompleted(prompt.handle) then
                local accepted = OpenButcherMenu(prompt.siteId)
                if accepted and Config.development and Config.development.enabled then
                    DBG:Info(('Opening butcher menu at site: %s'):format(prompt.siteId))
                end
                Wait(500)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, prompt in ipairs(prompts) do UiPromptDelete(prompt.handle) end
    for _, ped in ipairs(npcs) do if DoesEntityExist(ped) then DeleteEntity(ped) end end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
end)
