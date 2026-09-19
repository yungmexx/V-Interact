--[[
local hidingInGarbageCan = false

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

local function playHideAnim(ped)
    loadAnimDict('timetable@floyd@cryingonbed@base')
    TaskPlayAnim(ped, 'timetable@floyd@cryingonbed@base', 'base', 8.0, -8.0, -1, 1, 0, false, false, false)
end


local function maintainHiding(ped)
    CreateThread(function()
        while hidingInGarbageCan do
            if not IsEntityPlayingAnim(ped, 'timetable@floyd@cryingonbed@base', 'base', 3) then
                playHideAnim(ped)
            end
            Wait(0)
        end
    end)
end

local function exitGarbageCan()
    local ped = PlayerPedId()
    if not hidingInGarbageCan then return end

    hidingInGarbageCan = false

    SetEntityCollision(ped, true, true)
    DetachEntity(ped, true, true)
    SetEntityVisible(ped, true, false)
    ClearPedTasks(ped)
    SetEntityCoords(ped, GetOffsetFromEntityInWorldCoords(ped, 0.0, -0.7, -0.75))
end

local function onEnterGarbageCan(data)
    if hidingInGarbageCan then
        exitGarbageCan()
        return
    end
    local ped = PlayerPedId()
    local prop = data.entity
    SetEntityVisible(ped, false, false)
    Wait(50)

    hidingInGarbageCan = true
    AttachEntityToEntity(ped, prop, -1, 0.0, -0.3, 2.0, 0.0, 0.0, 0.0, false, false, false, false, 20, true)
    maintainHiding(ped)
    CreateThread(function()
        playHideAnim(ped)
        Wait(50)
        if hidingInGarbageCan then
            SetEntityVisible(ped, false, false)
        end
    end)
end

local function onSearchGarbageCan(data)
    print('searched garbage can', data.entity)
end

local function canSearchGarbageCan()
    return not hidingInGarbageCan
end

local function garbageCanLabel()
    return hidingInGarbageCan and 'Exit Garbage Can' or 'Enter Garbage Can'
end

exports['v-interact']:AddGlobalObject({
    {
        name = 'Garbage1',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_dumpster_02a` end,
        options = {
            { label = garbageCanLabel, onSelect = onEnterGarbageCan },
            { label = 'Search', onSelect = onSearchGarbageCan, canInteract = canSearchGarbageCan },
        },
    },
    {
        name = 'Garbage2',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_dumpster_02b` end,
        options = {
            { label = garbageCanLabel, onSelect = onEnterGarbageCan },
            { label = 'Search', onSelect = onSearchGarbageCan, canInteract = canSearchGarbageCan },
        },
    },
    {
        name = 'Garbage3',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_bin_07c` end,
        options = {
            { label = 'Search', onSelect = onSearchGarbageCan, canInteract = canSearchGarbageCan },
        },
    },
    {
        name = 'Garbage4',
        distance = 3.5,
        offset = vector3(0.0, -0.3, 0.0),
        filter = function(entity) return GetEntityModel(entity) == `prop_dumpster_4a` end,
        options = {
            { label = garbageCanLabel, onSelect = onEnterGarbageCan },
            { label = 'Search', onSelect = onSearchGarbageCan, canInteract = canSearchGarbageCan },
        },
    },
})
--]]