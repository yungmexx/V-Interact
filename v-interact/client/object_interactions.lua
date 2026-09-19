local GlobalObjectDefinitions = {}
local tracked = {}
local active = {}
local playerInVehicle = false

local function getLocalOffset(object, def, fwd, right, up, pos)
    local bx, by, bz = pos.x, pos.y, pos.z

    if def.bones then
        local boneIndex = GetEntityBoneIndexByName(object, def.bones)
        if boneIndex == -1 then
            if Config.Debug then
                print(('[v-interact] AddGlobalObject: bone "%s" not found on object model %s (definition "%s" skipped)')
                    :format(def.bones, GetEntityModel(object), def.name or '?'))
            end
            return nil
        end
        local bonePos = GetWorldPositionOfEntityBone(object, boneIndex)
        bx, by, bz = bonePos.x, bonePos.y, bonePos.z
    else
        local min, max = GetModelDimensions(GetEntityModel(object))
        local centerRight, centerForward, centerUp = (min.x + max.x) * 0.5, (min.y + max.y) * 0.5, (min.z + max.z) * 0.5
        bx = pos.x + right.x * centerRight + fwd.x * centerForward + up.x * centerUp
        by = pos.y + right.y * centerRight + fwd.y * centerForward + up.y * centerUp
        bz = pos.z + right.z * centerRight + fwd.z * centerForward + up.z * centerUp
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

local function buildOption(object, def, opt)
    return {
        label = opt.label,
        canInteract = function(point)
            if not DoesEntityExist(object) then return false end
            if not opt.canInteract then return true end

            local distanceToPlayer = #(GetEntityCoords(PlayerPedId()) - point.coords)
            return opt.canInteract(object, distanceToPlayer, point.coords, def.name)
        end,
        onSelect = function(point)
            if opt.onSelect then
                opt.onSelect({ entity = object, coords = point.coords, name = def.name })
            end
        end,
    }
end


local function buildOptions(object, def)
    if def.options then
        local options = {}
        for i, opt in ipairs(def.options) do
            options[i] = buildOption(object, def, opt)
        end
        return options
    end

    return { buildOption(object, def, def) }
end

local function attachDefinitionToObject(object, state, def)
    if def.filter and not def.filter(object) then return end

    local fwd, right, up, pos = GetEntityMatrix(object)
    local lf, lr, lu = getLocalOffset(object, def, fwd, right, up, pos)
    if not lf then return end

    local attachment = { def = def, lf = lf, lr = lr, lu = lu }
    local tx, ty, tz = computeTarget(attachment, fwd, right, up, pos)
    attachment.sx, attachment.sy, attachment.sz = tx, ty, tz

    attachment.id = exports['v-interact']:AddPoint(vector3(tx, ty, tz), buildOptions(object, def), {
        distance = def.distance or 2.0,
        zOffset = 0.0,
    })

    state.attachments[#state.attachments + 1] = attachment
    active[object] = state
end

local function attachGlobalDefinitions(object)
    local state = { attachments = {} }
    tracked[object] = state

    for _, def in ipairs(GlobalObjectDefinitions) do
        attachDefinitionToObject(object, state, def)
    end
end

-- Registers interaction definitions applied to EVERY nearby object (no
-- model filter) - applied immediately to already-tracked objects and to
-- every object discovered from here on. Same definition shape as
-- AddGlobalVehicle/AddGlobalWorldPed:
--
-- exports['v-interact']:AddGlobalObject({
--     {
--         name = 'my-resource:searchCrate',
--         label = 'Search Crate',
--         distance = 1.5,
--         filter = function(entity) return GetEntityModel(entity) == `prop_crate_01` end,
--         onSelect = function(data) print('searched crate', data.entity) end,
--     },
-- })
--

local function addGlobalObject(definitions)
    for _, def in ipairs(definitions) do
        GlobalObjectDefinitions[#GlobalObjectDefinitions + 1] = def

        for object, state in pairs(tracked) do
            if DoesEntityExist(object) then
                attachDefinitionToObject(object, state, def)
            end
        end
    end
end

exports('AddGlobalObject', addGlobalObject)

local function removeObjectAttachments(object)
    local state = tracked[object]
    if not state then return end

    for _, attachment in ipairs(state.attachments) do
        exports['v-interact']:RemovePoint(attachment.id)
    end
    tracked[object] = nil
    active[object] = nil
end

local function refreshObjectAttachments(object, state)
    local fwd, right, up, pos = GetEntityMatrix(object)

    for _, attachment in ipairs(state.attachments) do
        local tx, ty, tz = computeTarget(attachment, fwd, right, up, pos)
        local dx, dy, dz = tx - attachment.sx, ty - attachment.sy, tz - attachment.sz

        if (dx * dx + dy * dy + dz * dz) > 0.001 * 0.001 then
            attachment.sx, attachment.sy, attachment.sz = tx, ty, tz
            exports['v-interact']:UpdatePointCoords(attachment.id, vector3(tx, ty, tz))
        end
    end
end

local function nearbyObjects()
    local coords = GetEntityCoords(PlayerPedId())
    local seen = {}

    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object) then
            local d = #(coords - GetEntityCoords(object))
            if d <= 10.0 then
                seen[object] = true
                if not tracked[object] then
                    attachGlobalDefinitions(object)
                end
            end
        end
    end

    for object in pairs(tracked) do
        if not seen[object] or not DoesEntityExist(object) then
            removeObjectAttachments(object)
        end
    end
end

local function setAllObjectPointsHidden(hidden)
    for _, state in pairs(active) do
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
        if playerInVehicle or next(active) == nil then
            Wait(playerInVehicle and 500 or 100)
        else
            local now = GetGameTimer()
            local playerCoords = GetEntityCoords(PlayerPedId())
            for object, state in pairs(active) do
                if DoesEntityExist(object) then
                    local oc = GetEntityCoords(object)
                    local dx, dy, dz = oc.x - playerCoords.x, oc.y - playerCoords.y, oc.z - playerCoords.z
                    local near = (dx * dx + dy * dy + dz * dz) <= 6.0 * 6.0
                    local due = now >= (state.nextRefresh or 0)
                    if near then
                        due = due or oc.x ~= state.lastX or oc.y ~= state.lastY or oc.z ~= state.lastZ
                    end

                    if due then
                        state.lastX, state.lastY, state.lastZ = oc.x, oc.y, oc.z
                        state.nextRefresh = now + 100
                        refreshObjectAttachments(object, state)
                    end
                else
                    removeObjectAttachments(object)
                end
            end
            Wait(0)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        if not playerInVehicle then
            nearbyObjects()
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
                setAllObjectPointsHidden(true)
            else
                nearbyObjects()
                for object, state in pairs(active) do
                    if DoesEntityExist(object) then
                        refreshObjectAttachments(object, state)
                    end
                end
                setAllObjectPointsHidden(false)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for object in pairs(tracked) do
        removeObjectAttachments(object)
    end
end)