local points = {}
local pointId = 0

local scanDist = {}
local scanIds = {}

local state = {
    active = nil,
    optionIndex = 1,
    nearby = {},
}


local screenW, screenH = GetActiveScreenResolution()

CreateThread(function()
    while true do
        Wait(1000)
        screenW, screenH = GetActiveScreenResolution()
    end
end)

local function notify(msg)
end

local function dist(a, b)
    return #(a - b)
end

local function distSq(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

local function getUsableOptions(point)
    if not point.hasConditionalOptions then
        return point.options
    end

    local list = {}
    for _, opt in ipairs(point.options) do
        if not opt.canInteract or opt.canInteract(point) then
            list[#list + 1] = opt
        end
    end
    return list
end

local function optionsHaveConditional(options)
    for _, opt in ipairs(options) do
        if opt.canInteract then return true end
    end
    return false
end

local function optionsHaveDynamicLabel(options)
    for _, opt in ipairs(options) do
        if type(opt.label) ~= 'string' then return true end
    end
    return false
end

local function resolveLabels(usable)
    local labels = {}
    for i, opt in ipairs(usable) do
        local label = opt.label
        if type(label) ~= 'string' then
            local ok, result = pcall(label)
            label = ok and result or nil
        end
        if type(label) ~= 'string' or label == '' then
            label = 'Interact'
        end
        labels[i] = label
    end
    return labels
end

local function recomputePointMeta(point)
    point.usable = nil -- scan result no longer matches the option list
    point.hasConditionalOptions = optionsHaveConditional(point.options)
    point.needsPerFrameLabels = point.hasConditionalOptions or optionsHaveDynamicLabel(point.options)
    point.staticLabels = (not point.needsPerFrameLabels) and resolveLabels(point.options) or nil
end

local function addPoint(coords, options, data)
    data = data or {}
    local distance = data.distance or Config.VisibleDistance

    pointId = pointId + 1
    local point = {
        id = pointId,
        coords = coords,
        options = options,
        distance = distance,
        distanceSq = distance * distance,
        zOffset = data.zOffset or 0.0,
        noDot = data.noDot or false,
        vehicleDot = data.vehicleDot or false,
        markerSizePx = data.vehicleDot and Config.VehicleMarkerSize or Config.DefaultMarkerSize,
    }
    recomputePointMeta(point)
    points[pointId] = point

    return pointId
end

local function removePoint(id)
    if points[id] then
        if state.active == id then
            state.active = nil
            state.optionIndex = 1
        end
        points[id] = nil
        scanDist[id] = nil
    end
end


local function updatePointCoords(id, coords)
    if points[id] then
        points[id].coords = coords
    end
end

local function addPointOptions(id, options)
    local point = points[id]
    if not point then return end

    for _, opt in ipairs(options) do
        point.options[#point.options + 1] = opt
    end
    recomputePointMeta(point)
end

local function removePointOption(id, option)
    local point = points[id]
    if not point then return end

    for i, opt in ipairs(point.options) do
        if opt == option then
            table.remove(point.options, i)
            recomputePointMeta(point)
            return
        end
    end
end

local function clearPointOptions(id)
    local point = points[id]
    if not point then return end

    point.options = {}
    recomputePointMeta(point)
end

local function getPointCoords(id)
    local point = points[id]
    return point and point.coords or nil
end

local function setPointDistance(id, distance)
    local point = points[id]
    if not point then return end

    point.distance = distance
    point.distanceSq = distance * distance
end

local function getActivePointId()
    return state.active
end

exports('AddPoint', addPoint)
exports('RemovePoint', removePoint)
exports('UpdatePointCoords', updatePointCoords)
exports('AddPointOptions', addPointOptions)
exports('RemovePointOption', removePointOption)
exports('ClearPointOptions', clearPointOptions)
exports('GetPointCoords', getPointCoords)
exports('SetPointDistance', setPointDistance)
exports('GetActivePointId', getActivePointId)


local function byAscendingDist(a, b)
    return scanDist[a] < scanDist[b]
end

local function scanPoints(playerCoords)
    local nearbyCount = 0
    local lookedId, lookedDist = nil, nil
    local nearestId, nearestDist = nil, nil

    for id, point in pairs(points) do
        local dSq = distSq(playerCoords, point.coords)
        if not point.hidden and dSq <= point.distanceSq then
            local usable = getUsableOptions(point)
            -- Remembered so the active-detail path can reuse this result
            -- instead of running every canInteract a second time.
            point.usable = usable
            if #usable > 0 then
                nearbyCount = nearbyCount + 1
                scanIds[nearbyCount] = id
                scanDist[id] = dSq

                if not nearestDist or dSq < nearestDist then
                    nearestId, nearestDist = id, dSq
                end

                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(
                    point.coords.x, point.coords.y, point.coords.z + point.zOffset
                )
                if onScreen then
                    local dxPx = (sx - 0.5) * screenW
                    local dyPx = (sy - 0.5) * screenH
                    local looking = (dxPx * dxPx + dyPx * dyPx) <= (Config.LookRadiusPx * Config.LookRadiusPx)
                    if looking and (not lookedDist or dSq < lookedDist) then
                        lookedId, lookedDist = id, dSq
                    end
                end
            end
        end
    end

    for i = #scanIds, nearbyCount + 1, -1 do
        scanIds[i] = nil
    end
    table.sort(scanIds, byAscendingDist)

    local selectedId = lookedId or nearestId
    local maxMarkers = Config.MaxAmbientMarkers or nearbyCount
    local capped = {}
    local sawSelected = false
    for i = 1, nearbyCount do
        if #capped >= maxMarkers then break end
        local entryId = scanIds[i]
        capped[#capped + 1] = entryId
        if entryId == selectedId then sawSelected = true end
    end
    if selectedId and not sawSelected then
        capped[#capped + 1] = selectedId
    end

    return capped, selectedId
end

local function triggerOption(point, option)
    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)

    if option.onSelect then
        option.onSelect(point)
    end
    if option.event then
        TriggerEvent(option.event, point)
    end
    if option.serverEvent then
        TriggerServerEvent(option.serverEvent, point.id)
    end
end


local Resource = GetCurrentResourceName()

local TextureDictionaryName = 'v_interact_txd'
local DefaultMarkerTextureName = 'marker_default'
local VehicleMarkerTextureName = 'marker_vehicle'
local PromptTextureName = 'prompt'


local PromptDuiWidth, PromptDuiHeight = 640, 130

local MarkerDuiSize = 256


local PromptShowSpeed = 15.0
local PromptHideSpeed = 22.0

local PromptHiddenScale = 0.85
local PromptShownScale = 1.0

local duiObject = nil
local defaultMarkerDui = nil
local vehicleMarkerDui = nil
local graphicsReady = false

local render = {
    promptAlpha = 0.0,
    promptScale = PromptHiddenScale,
}

local lastSentKey, lastSentLabelsSig, lastSentIndex, lastSentVisible = nil, nil, nil, nil
local lastLabelsRef = nil

local function urlEncode(str)
    return (str:gsub('[^%w%-%.~]', function(c)
        return ('%%%02X'):format(c:byte())
    end))
end

local function initGraphics()
    local txd = CreateRuntimeTxd(TextureDictionaryName)

    defaultMarkerDui = CreateDui(('nui://%s/html/marker.html?icon=%s'):format(Resource, urlEncode(Config.DefaultMarkerIcon)), MarkerDuiSize, MarkerDuiSize)
    CreateRuntimeTextureFromDuiHandle(txd, DefaultMarkerTextureName, GetDuiHandle(defaultMarkerDui))

    vehicleMarkerDui = CreateDui(('nui://%s/html/marker.html?icon=%s'):format(Resource, urlEncode(Config.VehicleMarkerIcon)), MarkerDuiSize, MarkerDuiSize)
    CreateRuntimeTextureFromDuiHandle(txd, VehicleMarkerTextureName, GetDuiHandle(vehicleMarkerDui))

    duiObject = CreateDui(('nui://%s/html/dui.html'):format(Resource), PromptDuiWidth, PromptDuiHeight)
    local duiHandle = GetDuiHandle(duiObject)
    CreateRuntimeTextureFromDuiHandle(txd, PromptTextureName, duiHandle)

    graphicsReady = true
end

CreateThread(initGraphics)


local function pushPromptContent(key, labels, index, visible)
    local labelsSig
    if labels == lastLabelsRef then
        labelsSig = lastSentLabelsSig
    else
        labelsSig = table.concat(labels, '\30')
        lastLabelsRef = labels
    end

    if key == lastSentKey and labelsSig == lastSentLabelsSig and index == lastSentIndex and visible == lastSentVisible then
        return
    end
    lastSentKey, lastSentLabelsSig, lastSentIndex, lastSentVisible = key, labelsSig, index, visible

    SendDuiMessage(duiObject, json.encode({
        action = 'update',
        key = key,
        options = labels,
        index = index,
        visible = visible,
    }))
end

local function resetPromptContentCache()
    lastSentKey, lastSentLabelsSig, lastSentIndex, lastSentVisible = nil, nil, nil, nil
    lastLabelsRef = nil
end

local function flashKeyPress()
    if duiObject then
        SendDuiMessage(duiObject, json.encode({ action = 'press' }))
    end
end

local function approach(current, target, dt, speed)
    return current + (target - current) * math.min(1.0, dt * speed)
end

local function resetRenderState()
    render.promptAlpha = 0.0
    render.promptScale = PromptHiddenScale
    resetPromptContentCache()
end

local function resetState()
    resetRenderState()
    state.active = nil
    state.optionIndex = 1
end

local function clearNearby()
    if state.active then resetState() end
    state.nearby = {}
end

local function hidePoint(id)
    local point = points[id]
    if not point or point.hidden then return end
    point.hidden = true

    if state.active == id then
        resetState()
    end

    for i = #state.nearby, 1, -1 do
        if state.nearby[i] == id then
            table.remove(state.nearby, i)
        end
    end
end

local function showPoint(id)
    local point = points[id]
    if not point or not point.hidden then return end
    point.hidden = false
end

local function hideAllPoints()
    for id in pairs(points) do
        hidePoint(id)
    end
end

exports('HidePoint', hidePoint)
exports('ShowPoint', showPoint)
exports('HideAllPoints', hideAllPoints)


local function drawMarker(wx, wy, wz, distAlpha, distScale, promptVisible, hasDot, markerTex, markerBasePx)
    if screenW <= 0 or screenH <= 0 then return end

    local targetAlpha = promptVisible and 1.0 or 0.0
    local targetScale = promptVisible and PromptShownScale or PromptHiddenScale
    local settled = render.promptAlpha == targetAlpha and render.promptScale == targetScale

    if not settled then
        local dt = GetFrameTime()
        local enterSpeed = promptVisible and PromptShowSpeed or PromptHideSpeed
        render.promptAlpha = approach(render.promptAlpha, targetAlpha, dt, enterSpeed)
        render.promptScale = approach(render.promptScale, targetScale, dt, enterSpeed)
    end

    SetDrawOrigin(wx, wy, wz, false)

    if hasDot then
        local dotAlpha = distAlpha * (1.0 - render.promptAlpha)

        if dotAlpha > 0.004 then
            local markerPx = markerBasePx * distScale
            DrawSprite(TextureDictionaryName, markerTex, 0.0, 0.0, markerPx / screenW, markerPx / screenH, 0.0,
                255, 255, 255, math.floor(dotAlpha * 255))
        end
    end

    if render.promptAlpha > 0.004 then
        local wFrac = (PromptDuiWidth * render.promptScale) / screenW
        local hFrac = (PromptDuiHeight * render.promptScale) / screenH

        DrawSprite(TextureDictionaryName, PromptTextureName, 0.0, 0.0, wFrac, hFrac, 0.0,
            255, 255, 255, math.floor(render.promptAlpha * distAlpha * 255))
    end

    ClearDrawOrigin()
end

local function drawAmbientDot(wx, wy, wz, distAlpha, distScale, markerTex, markerBasePx)
    if screenW <= 0 or screenH <= 0 then return end

    SetDrawOrigin(wx, wy, wz, false)

    local markerPx = markerBasePx * distScale
    DrawSprite(TextureDictionaryName, markerTex, 0.0, 0.0, markerPx / screenW, markerPx / screenH, 0.0,
        255, 255, 255, math.floor(distAlpha * 255))

    ClearDrawOrigin()
end


local ActiveDetailRefreshIntervalMs = 150
local activeDetail = { id = nil, usable = nil, labels = nil }


local function buildActiveDetail(id, point)
    if point and (point.hasConditionalOptions or point.needsPerFrameLabels) then
        local usable = point.usable or getUsableOptions(point)
        return {
            id = id,
            usable = usable,
            labels = point.needsPerFrameLabels and resolveLabels(usable) or point.staticLabels,
        }
    end
    return { id = nil }
end

local function countPoints()
    local n = 0
    for _ in pairs(points) do n = n + 1 end
    return n
end


CreateThread(function()
    while true do
        Wait(200)

        local ped = PlayerPedId()
        if next(points) == nil or IsPedDeadOrDying(ped, true) or IsPauseMenuActive() then
            clearNearby()
        else
            local coords = GetEntityCoords(ped)
            local nearby, selectedId = scanPoints(coords)
            state.nearby = nearby

            if selectedId ~= state.active then
                if not selectedId then
                    resetState()
                else
                    state.active = selectedId
                    state.optionIndex = 1
                    resetRenderState()
                    activeDetail = buildActiveDetail(selectedId, points[selectedId])
                end
            end
        end
    end
end)

local AmbientDetailRefreshIntervalMs = 150
local ambientDetail = {}

CreateThread(function()
    while true do
        local newDetail = {}
        local playerCoords = GetEntityCoords(PlayerPedId())

        for _, id in ipairs(state.nearby) do
            if id ~= state.active then
                local point = points[id]
                if point and not point.noDot and not point.vehicleDot then
                    local pz = point.coords.z + point.zOffset
                    local onScreen = GetScreenCoordFromWorldCoord(point.coords.x, point.coords.y, pz)
                    if onScreen then
                        local d = dist(playerCoords, point.coords)

                        local fadeStart = point.distance * 0.85
                        local alpha = 1.0
                        if d > fadeStart then
                            alpha = 1.0 - ((d - fadeStart) / (point.distance - fadeStart))
                        end
                        alpha = math.max(0.4, math.min(1.0, alpha))

                        local distScale = 1.0 - math.min(0.35, (d / point.distance) * 0.35)

                        newDetail[id] = {
                            x = point.coords.x, y = point.coords.y, z = pz,
                            alpha = alpha, distScale = distScale,
                            markerTex = DefaultMarkerTextureName,
                            markerBasePx = point.markerSizePx,
                        }
                    end
                end
            end
        end

        ambientDetail = newDetail
        Wait(AmbientDetailRefreshIntervalMs)
    end
end)

local function renderAmbientPoint(id)
    local detail = ambientDetail[id]
    if not detail then return end

    drawAmbientDot(detail.x, detail.y, detail.z, detail.alpha, detail.distScale, detail.markerTex, detail.markerBasePx)
end

local function renderVehicleAmbientPoint(point, playerCoords)
    if point.noDot then return end

    local pz = point.coords.z + point.zOffset
    local onScreen = GetScreenCoordFromWorldCoord(point.coords.x, point.coords.y, pz)
    if not onScreen then return end

    local d = dist(playerCoords, point.coords)
    local distScale = 1.0 - math.min(0.35, (d / point.distance) * 0.35)

    drawAmbientDot(point.coords.x, point.coords.y, pz, 1.0, distScale, VehicleMarkerTextureName, point.markerSizePx)
end

CreateThread(function()
    while true do
        local id = state.active
        activeDetail = buildActiveDetail(id, id and points[id])
        Wait(ActiveDetailRefreshIntervalMs)
    end
end)

local function renderActivePoint(point, coords)
    local d = dist(coords, point.coords)
    if d > point.distance then
        resetState()
        return true
    end

    local usable, cachedLabels
    if not (point.hasConditionalOptions or point.needsPerFrameLabels) then
        usable, cachedLabels = point.options, point.staticLabels
    elseif activeDetail.id == point.id then
        usable, cachedLabels = activeDetail.usable, activeDetail.labels
    else
        usable = getUsableOptions(point)
        cachedLabels = point.needsPerFrameLabels and resolveLabels(usable) or point.staticLabels
    end

    if #usable == 0 then
        resetState()
        return true
    end

    if state.optionIndex > #usable then state.optionIndex = 1 end
    local option = usable[state.optionIndex]
    local triggerDistance = option.distance or Config.Distance
    local inRange = d <= triggerDistance

    local onScreen, sx, sy = GetScreenCoordFromWorldCoord(
        point.coords.x, point.coords.y, point.coords.z + point.zOffset
    )

    local lookingAt = false
    if onScreen then
        local dxPx = (sx - 0.5) * screenW
        local dyPx = (sy - 0.5) * screenH
        lookingAt = (dxPx * dxPx + dyPx * dyPx) <= (Config.LookRadiusPx * Config.LookRadiusPx)
    end

    if onScreen and graphicsReady then
        local fadeStart = point.distance * 0.85
        local alpha = 1.0
        if d > fadeStart then
            alpha = 1.0 - ((d - fadeStart) / (point.distance - fadeStart))
        end
        alpha = math.max(0.4, math.min(1.0, alpha))

        local distScale = 1.0 - math.min(0.35, (d / point.distance) * 0.35)
        local promptVisible = inRange and lookingAt
        pushPromptContent(option.key or Config.Key, cachedLabels, state.optionIndex, promptVisible)
        local markerTex = point.vehicleDot and VehicleMarkerTextureName or DefaultMarkerTextureName

        drawMarker(point.coords.x, point.coords.y, point.coords.z + point.zOffset,
            alpha, distScale, promptVisible, not point.noDot, markerTex, point.markerSizePx)

        if promptVisible then
            if #usable > 1 then
                DisableControlAction(0, 14, true)
                DisableControlAction(0, 15, true)

                if IsDisabledControlJustPressed(0, 14) then
                    state.optionIndex = state.optionIndex + 1
                    if state.optionIndex > #usable then state.optionIndex = 1 end
                    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                elseif IsDisabledControlJustPressed(0, 15) then
                    state.optionIndex = state.optionIndex - 1
                    if state.optionIndex < 1 then state.optionIndex = #usable end
                    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                end
            end

            DisableControlAction(0, Config.KeyControl, true)
            local defaultPressed = IsDisabledControlJustPressed(0, Config.KeyControl)
                or (Config.ClickControl and IsControlJustPressed(0, Config.ClickControl))

            for idx, opt in ipairs(usable) do
                local control = opt.control
                local triggered = idx == state.optionIndex and defaultPressed

                if not triggered and control and control ~= Config.KeyControl then
                    DisableControlAction(0, control, true)
                    triggered = IsDisabledControlJustPressed(0, control)
                end

                if triggered then
                    flashKeyPress()
                    triggerOption(point, opt)
                end
            end
        end
    end

    return false
end

CreateThread(function()
    while true do
        local waitTime = 250

        if #state.nearby > 0 then
            waitTime = 0

            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local sawActive = false

            for _, id in ipairs(state.nearby) do
                local point = points[id]
                if point then
                    if id == state.active then
                        sawActive = true
                        renderActivePoint(point, coords)
                    elseif point.vehicleDot then
                        renderVehicleAmbientPoint(point, coords)
                    else
                        renderAmbientPoint(id)
                    end
                end
            end

            if state.active and not sawActive then
                resetState()
            end
        else
            resetRenderState()
        end

        Wait(waitTime)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if duiObject then
            DestroyDui(duiObject)
        end
        if defaultMarkerDui then
            DestroyDui(defaultMarkerDui)
        end
        if vehicleMarkerDui then
            DestroyDui(vehicleMarkerDui)
        end
    end
end)


--[[
    Exports (call as exports['v-interact']:ExportName(...) from another resource)

    AddPoint(coords, options, data) -> pointId
        Registers a new interaction point and returns its id.

        coords  vector3 - world position of the point
        options table   - array of option tables, each:
            label       string or function(point) -> string (required)
            onSelect    function(point)              - called when chosen
            event       string                        - TriggerEvent(event, point)
            serverEvent string                        - TriggerServerEvent(serverEvent, point.id)
            canInteract function(point) -> boolean     - hide this option when false
            control     number                         - extra bind (in addition to Config.KeyControl)
            distance    number                         - override Config.Distance for this option
            key         string                         - override Config.Key shown on the keycap
        data    table (optional):
            distance    number  - visibility/trigger radius (default Config.VisibleDistance)
            zOffset     number  - vertical offset for the drawn marker/prompt
            noDot       boolean - true to skip the ambient dot, only show the prompt up close
            vehicleDot  boolean - true to use the vehicle marker icon/size and live per-frame tracking

        local pointId = exports['v-interact']:AddPoint(vector3(0.0, 0.0, 72.0), {
            { label = 'Open Stash', onSelect = function(point) print('opened', point.id) end },
        }, { distance = 8.0 })

    RemovePoint(id)
        Deletes a point entirely.

        exports['v-interact']:RemovePoint(pointId)

    UpdatePointCoords(id, coords)
        Moves an existing point (e.g. to keep it glued to a moving entity).

        exports['v-interact']:UpdatePointCoords(pointId, GetEntityCoords(someEntity))

    AddPointOptions(id, options)
        Appends more prompts to a point that already exists, without recreating it.
        `options` is an array in the same shape as AddPoint's options parameter.

        local trunkOption = { label = 'Open Trunk', onSelect = function() ... end }
        exports['v-interact']:AddPointOptions(pointId, { trunkOption })

    RemovePointOption(id, option)
        Removes one prompt from a point. `option` must be the exact table you
        passed to AddPoint/AddPointOptions - keep a reference to it if you'll
        want to remove it later.

        exports['v-interact']:RemovePointOption(pointId, trunkOption)

    ClearPointOptions(id)
        Removes every prompt from a point at once - a fresh start for rebuilding
        a fully dynamic option list, instead of calling RemovePointOption per entry.

        exports['v-interact']:ClearPointOptions(pointId)
        exports['v-interact']:AddPointOptions(pointId, { newOption })

    GetPointCoords(id) -> vector3 or nil
        Reads back a point's current position, or nil if the id doesn't exist.

        local coords = exports['v-interact']:GetPointCoords(pointId)
        if coords then print(coords.x, coords.y, coords.z) end

    SetPointDistance(id, distance)
        Changes a point's visibility/trigger radius after creation, without
        having to RemovePoint + AddPoint to change it.

        exports['v-interact']:SetPointDistance(pointId, 4.0)

    GetActivePointId() -> id or nil
        Returns whichever point currently has the prompt focused (nil if none),
        so another resource can react to what the player is looking at.

        local activeId = exports['v-interact']:GetActivePointId()
        if activeId == myStashPointId then print('player is looking at the stash') end

    HidePoint(id)
        Temporarily hides a point (keeps its coords/options registered under
        the same id) so it can't become ambient or active.

        exports['v-interact']:HidePoint(pointId)

    ShowPoint(id)
        Reverses HidePoint.

        exports['v-interact']:ShowPoint(pointId)

    HideAllPoints()
        Hides every currently registered point at once.

        exports['v-interact']:HideAllPoints()
]]