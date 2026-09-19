local SpawnDefinitions = {}
local spawned = {} -- def -> { ped, pointId }

local WorldDefinitions = {}
local tracked = {}
local playerInVehicle = false

local function buildOption(ped, def)
    return {
        label = def.label,
        canInteract = function(point)
            if not DoesEntityExist(ped) then return false end
            if not def.canInteract then return true end

            local distanceToPlayer = #(GetEntityCoords(PlayerPedId()) - point.coords)
            return def.canInteract(ped, distanceToPlayer, point.coords, def.name)
        end,
        onSelect = function(point)
            if def.onSelect then
                def.onSelect({ entity = ped, coords = point.coords, name = def.name })
            end
        end,
    }
end


-- AddGlobalPed: spawned peds

local function spawnPedForDefinition(def)
    RequestModel(def.model)
    while not HasModelLoaded(def.model) do
        Wait(0)
    end

    local ped = CreatePed(4, def.model, def.coords.x, def.coords.y, def.coords.z - 1.0, def.heading or 0.0, false, true)
    SetModelAsNoLongerNeeded(def.model)

    if def.frozen ~= false then FreezeEntityPosition(ped, true) end
    if def.invincible ~= false then SetEntityInvincible(ped, true) end
    SetBlockingOfNonTemporaryEvents(ped, true)
    if def.scenario then TaskStartScenarioInPlace(ped, def.scenario, 0, true) end

    local pointId = exports['v-interact']:AddPoint(def.coords, { buildOption(ped, def) }, {
        distance = def.distance or 2.0,
        zOffset = def.zOffset or 0.0,
    })

    spawned[def] = { ped = ped, pointId = pointId }
end

local function removePedForDefinition(def)
    local entry = spawned[def]
    if not entry then return end

    if entry.pointId then
        exports['v-interact']:RemovePoint(entry.pointId)
    end
    if entry.ped and DoesEntityExist(entry.ped) then
        DeletePed(entry.ped)
    end
    spawned[def] = nil
end

local function addGlobalPed(definitions)
    for _, def in ipairs(definitions) do
        SpawnDefinitions[#SpawnDefinitions + 1] = def
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local coords = GetEntityCoords(PlayerPedId())

        for _, def in ipairs(SpawnDefinitions) do
            local entry = spawned[def]
            local alive = entry and DoesEntityExist(entry.ped)
            if entry and not alive then
                removePedForDefinition(def)
                entry = nil
            end

            local d = #(coords - def.coords)
            if d <= 30.0 and not entry then
                spawnPedForDefinition(def)
            elseif d > 30.0 and entry then
                removePedForDefinition(def)
            end
        end
    end
end)

exports('AddGlobalPed', addGlobalPed)


-- AddGlobalWorldPed: interactions attached to existing world peds

local function getLocalOffset(ped, def, fwd, right, up, pos)
    local bx, by, bz = pos.x, pos.y, pos.z

    if def.bones then
        local boneIndex = GetEntityBoneIndexByName(ped, def.bones)
        if boneIndex == -1 then
            if Config.Debug then
                print(('[v-interact] AddGlobalWorldPed: bone "%s" not found on ped model %s (definition "%s" skipped)')
                    :format(def.bones, GetEntityModel(ped), def.name or '?'))
            end
            return nil
        end
        local bonePos = GetWorldPositionOfEntityBone(ped, boneIndex)
        bx, by, bz = bonePos.x, bonePos.y, bonePos.z
    end

    local dx, dy, dz = bx - pos.x, by - pos.y, bz - pos.z
    return
        dx * fwd.x   + dy * fwd.y   + dz * fwd.z,
        dx * right.x + dy * right.y + dz * right.z,
        dx * up.x    + dy * up.y    + dz * up.z
end

local function computeTarget(attachment, fwd, right, up, pos)
    local def = attachment.def
    local bx = pos.x + fwd.x * attachment.lf + right.x * attachment.lr + up.x * attachment.lu
    local by = pos.y + fwd.y * attachment.lf + right.y * attachment.lr + up.y * attachment.lu
    local bz = pos.z + fwd.z * attachment.lf + right.z * attachment.lr + up.z * attachment.lu

    local offRight, offForward, offUp = 0.0, 0.0, 0.0
    if def.offset then
        offRight, offForward, offUp = def.offset.x, def.offset.y, def.offset.z
    end

    return
        bx + fwd.x * offForward + right.x * offRight + up.x * offUp,
        by + fwd.y * offForward + right.y * offRight + up.y * offUp,
        bz + fwd.z * offForward + right.z * offRight + up.z * offUp
end

local function attachDefinitionToPed(ped, state, def)
    local fwd, right, up, pos = GetEntityMatrix(ped)
    local lf, lr, lu = getLocalOffset(ped, def, fwd, right, up, pos)
    if not lf then return end

    local attachment = { def = def, lf = lf, lr = lr, lu = lu }
    local tx, ty, tz = computeTarget(attachment, fwd, right, up, pos)
    attachment.sx, attachment.sy, attachment.sz = tx, ty, tz

    attachment.id = exports['v-interact']:AddPoint(vector3(tx, ty, tz), { buildOption(ped, def) }, {
        distance = def.distance or 2.0,
        zOffset = 0.0,
    })

    state.attachments[#state.attachments + 1] = attachment
end

local function attachGlobalDefinitions(ped)
    local state = { attachments = {} }
    tracked[ped] = state

    for _, def in ipairs(WorldDefinitions) do
        attachDefinitionToPed(ped, state, def)
    end
end


local function addGlobalWorldPed(definitions)
    for _, def in ipairs(definitions) do
        WorldDefinitions[#WorldDefinitions + 1] = def

        for ped, state in pairs(tracked) do
            if DoesEntityExist(ped) then
                attachDefinitionToPed(ped, state, def)
            end
        end
    end
end

exports('AddGlobalWorldPed', addGlobalWorldPed)

local function removePedAttachments(ped)
    local state = tracked[ped]
    if not state then return end

    for _, attachment in ipairs(state.attachments) do
        exports['v-interact']:RemovePoint(attachment.id)
    end
    tracked[ped] = nil
end

local function refreshPedAttachments(ped, state)
    local fwd, right, up, pos = GetEntityMatrix(ped)

    for _, attachment in ipairs(state.attachments) do
        local tx, ty, tz = computeTarget(attachment, fwd, right, up, pos)
        local dx, dy, dz = tx - attachment.sx, ty - attachment.sy, tz - attachment.sz

        if (dx * dx + dy * dy + dz * dz) > 0.001 * 0.001 then
            attachment.sx, attachment.sy, attachment.sz = tx, ty, tz
            exports['v-interact']:UpdatePointCoords(attachment.id, vector3(tx, ty, tz))
        end
    end
end

local function nearbyPeds()
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    local seen = {}

    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= player and DoesEntityExist(ped) then
            local d = #(coords - GetEntityCoords(ped))
            if d <= 10.0 then
                seen[ped] = true
                if not tracked[ped] then
                    attachGlobalDefinitions(ped)
                end
            end
        end
    end

    for ped in pairs(tracked) do
        if not seen[ped] or not DoesEntityExist(ped) then
            removePedAttachments(ped)
        end
    end
end

local function setAllPedPointsHidden(hidden)
    for _, state in pairs(tracked) do
        for _, attachment in ipairs(state.attachments) do
            if hidden then
                exports['v-interact']:HidePoint(attachment.id)
            else
                exports['v-interact']:ShowPoint(attachment.id)
            end
        end
    end
end

CreateThread(function()
    while true do
        if playerInVehicle or next(tracked) == nil then
            Wait(playerInVehicle and 500 or 100)
        else
            local now = GetGameTimer()
            local playerCoords = GetEntityCoords(PlayerPedId())
            for ped, state in pairs(tracked) do
                if DoesEntityExist(ped) then
                    local pc = GetEntityCoords(ped)
                    local dx, dy, dz = pc.x - playerCoords.x, pc.y - playerCoords.y, pc.z - playerCoords.z
                    local near = (dx * dx + dy * dy + dz * dz) <= 6.0 * 6.0

                    if near or now >= (state.nextFarRefresh or 0) then
                        refreshPedAttachments(ped, state)
                        if not near then
                            state.nextFarRefresh = now + 100
                        end
                    end
                else
                    removePedAttachments(ped)
                end
            end
            Wait(0)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1500)
        if not playerInVehicle then
            nearbyPeds()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(250)
        local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
        if inVehicle ~= playerInVehicle then
            playerInVehicle = inVehicle
            if playerInVehicle then
                setAllPedPointsHidden(true)
            else
                nearbyPeds()
                for ped, state in pairs(tracked) do
                    if DoesEntityExist(ped) then
                        refreshPedAttachments(ped, state)
                    end
                end
                setAllPedPointsHidden(false)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for def in pairs(spawned) do
        removePedForDefinition(def)
    end
    for ped in pairs(tracked) do
        removePedAttachments(ped)
    end
end)


-- Registers interaction definitions applied to EVERY nearby ped (no model
-- filter, including random pedestrians) - applied immediately to already-
-- tracked peds and to every ped discovered from here on. Same definition
-- shape as AddGlobalVehicle:
--
-- exports['v-interact']:AddGlobalWorldPed({
--     {
--         name = 'my-resource:pickpocket',
--         label = 'Pickpocket',
--         distance = 1.5,
--         canInteract = function(entity, distanceToPlayer, coords, name)
--             return not IsPedAPlayer(entity) and not IsPedDeadOrDying(entity, true)
--         end,
--         onSelect = function(data) print('pickpocketed', data.entity) end,
--     },
-- })
