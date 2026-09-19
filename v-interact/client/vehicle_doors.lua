local GlobalVehicleDefinitions = {}
local tracked = {}
local playerInVehicle = false

local function getLocalOffset(vehicle, def, fwd, right, up, pos)
    local bx, by, bz = pos.x, pos.y, pos.z

    if def.bones then
        local boneIndex = GetEntityBoneIndexByName(vehicle, def.bones)
        if boneIndex == -1 then
            if Config.Debug then
                print(('[v-interact] AddGlobalVehicle: bone "%s" not found on vehicle model %s (definition "%s" skipped for this vehicle)')
                    :format(def.bones, GetEntityModel(vehicle), def.name or '?'))
            end
            return nil
        end
        local bonePos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        bx, by, bz = bonePos.x, bonePos.y, bonePos.z
    end

    local dx, dy, dz = bx - pos.x, by - pos.y, bz - pos.z
    return
        dx * fwd.x   + dy * fwd.y   + dz * fwd.z,
        dx * right.x + dy * right.y + dz * right.z,
        dx * up.x    + dy * up.y    + dz * up.z
end

local function computeTarget(vehicle, attachment, fwd, right, up, pos)
    local def = attachment.def
    local bx = pos.x + fwd.x * attachment.lf + right.x * attachment.lr + up.x * attachment.lu
    local by = pos.y + fwd.y * attachment.lf + right.y * attachment.lr + up.y * attachment.lu
    local bz = pos.z + fwd.z * attachment.lf + right.z * attachment.lr + up.z * attachment.lu

    local offRight, offForward, offUp = 0.0, 0.0, 0.0
    if def.offset then
        offRight, offForward, offUp = def.offset.x, def.offset.y, def.offset.z
    end

    local ratio = nil
    if def.trackSwing and def.doorIndex ~= nil then
        ratio = GetVehicleDoorAngleRatio(vehicle, def.doorIndex)
        local side = (def.doorIndex == 1 or def.doorIndex == 3) and 1 or -1
        local swingRad = math.rad(75.0 * ratio) * -side
        local cosA, sinA = math.cos(swingRad), math.sin(swingRad)
        local rotForward = offForward * cosA - offRight * sinA
        local rotRight   = offForward * sinA + offRight * cosA
        offForward, offRight = rotForward, rotRight
    end

    return
        bx + fwd.x * offForward + right.x * offRight + up.x * offUp,
        by + fwd.y * offForward + right.y * offRight + up.y * offUp,
        bz + fwd.z * offForward + right.z * offRight + up.z * offUp,
        ratio
end

local function buildOption(vehicle, def)
    return {
        label = def.label,
        canInteract = function(point)
            if not DoesEntityExist(vehicle) then return false end
            if not def.canInteract then return true end

            local distanceToPlayer = #(GetEntityCoords(PlayerPedId()) - point.coords)
            return def.canInteract(vehicle, distanceToPlayer, point.coords, def.name)
        end,
        onSelect = function(point)
            if def.onSelect then
                def.onSelect({ entity = vehicle, coords = point.coords, name = def.name })
            end
        end,
    }
end

local function attachDefinitionToVehicle(vehicle, state, def)
    local fwd, right, up, pos = GetEntityMatrix(vehicle)
    local lf, lr, lu = getLocalOffset(vehicle, def, fwd, right, up, pos)
    if not lf then return end

    local attachment = { def = def, lf = lf, lr = lr, lu = lu, lastRatio = 0.0, swingUntil = 0 }
    local tx, ty, tz, ratio = computeTarget(vehicle, attachment, fwd, right, up, pos)
    attachment.lastRatio = ratio or 0.0
    attachment.sx, attachment.sy, attachment.sz = tx, ty, tz

    attachment.id = exports['v-interact']:AddPoint(vector3(tx, ty, tz), { buildOption(vehicle, def) }, {
        distance = def.distance or 2.2,
        zOffset = 0.0,
        noDot = not Config.ShowVehicleDoorDots,
        vehicleDot = true,
    })

    state.attachments[#state.attachments + 1] = attachment
end

local function attachGlobalDefinitions(vehicle)
    local state = { attachments = {} }
    tracked[vehicle] = state

    for _, def in ipairs(GlobalVehicleDefinitions) do
        attachDefinitionToVehicle(vehicle, state, def)
    end
end


local function addGlobalVehicle(definitions)
    for _, def in ipairs(definitions) do
        GlobalVehicleDefinitions[#GlobalVehicleDefinitions + 1] = def

        for vehicle, state in pairs(tracked) do
            if DoesEntityExist(vehicle) then
                attachDefinitionToVehicle(vehicle, state, def)
            end
        end
    end
end

exports('AddGlobalVehicle', addGlobalVehicle)

local function removeVehicleAttachments(vehicle)
    local state = tracked[vehicle]
    if not state then return end

    for _, attachment in ipairs(state.attachments) do
        exports['v-interact']:RemovePoint(attachment.id)
    end
    tracked[vehicle] = nil
end

local function refreshVehicleAttachments(vehicle, state, now, dt)
    local fwd, right, up, pos = GetEntityMatrix(vehicle)

    for _, attachment in ipairs(state.attachments) do
        local tx, ty, tz, ratio = computeTarget(vehicle, attachment, fwd, right, up, pos)

        if ratio and math.abs(ratio - attachment.lastRatio) > 0.01 then
            attachment.swingUntil = now + 400
        end
        if ratio then attachment.lastRatio = ratio end

        if attachment.swingUntil > now then
            local t = math.min(1.0, dt * 25.0)
            attachment.sx = attachment.sx + (tx - attachment.sx) * t
            attachment.sy = attachment.sy + (ty - attachment.sy) * t
            attachment.sz = attachment.sz + (tz - attachment.sz) * t
            exports['v-interact']:UpdatePointCoords(attachment.id, vector3(attachment.sx, attachment.sy, attachment.sz))
        else
            local dx, dy, dz = tx - attachment.sx, ty - attachment.sy, tz - attachment.sz
            if (dx * dx + dy * dy + dz * dz) > 0.001 * 0.001 then
                attachment.sx, attachment.sy, attachment.sz = tx, ty, tz
                exports['v-interact']:UpdatePointCoords(attachment.id, vector3(tx, ty, tz))
            end
        end
    end
end

local function nearbyVehicles()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local seen = {}

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local d = #(coords - GetEntityCoords(vehicle))
            if d <= 10.0 then
                seen[vehicle] = true
                if not tracked[vehicle] then
                    attachGlobalDefinitions(vehicle)
                end
            end
        end
    end

    for vehicle in pairs(tracked) do
        if not seen[vehicle] or not DoesEntityExist(vehicle) then
            removeVehicleAttachments(vehicle)
        end
    end
end

local function setAllAttachmentsHidden(hidden)
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
            local dt = GetFrameTime()
            local playerCoords = GetEntityCoords(PlayerPedId())
            for vehicle, state in pairs(tracked) do
                if DoesEntityExist(vehicle) then
                    local vc = GetEntityCoords(vehicle)
                    local dx, dy, dz = vc.x - playerCoords.x, vc.y - playerCoords.y, vc.z - playerCoords.z
                    local near = (dx * dx + dy * dy + dz * dz) <= 6.0 * 6.0

                    if near or now >= (state.nextFarRefresh or 0) then
                        refreshVehicleAttachments(vehicle, state, now, dt)
                        if not near then
                            state.nextFarRefresh = now + 100
                        end
                    end
                else
                    removeVehicleAttachments(vehicle)
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
            nearbyVehicles()
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
                setAllAttachmentsHidden(true)
            else
                nearbyVehicles()
                local now = GetGameTimer()
                local frameTime = GetFrameTime()
                for vehicle, state in pairs(tracked) do
                    if DoesEntityExist(vehicle) then
                        refreshVehicleAttachments(vehicle, state, now, frameTime)
                    end
                end
                setAllAttachmentsHidden(false)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for vehicle in pairs(tracked) do
            removeVehicleAttachments(vehicle)
        end
    end
end)