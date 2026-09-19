local function canInteractWithDoor(vehicle)
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
    if not DoesEntityExist(vehicle) then return false end

    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    return lockStatus == 0 or lockStatus == 1
end

local function toggleDoor(vehicle, doorIndex)
    if GetVehicleDoorAngleRatio(vehicle, doorIndex) > 0.1 then
        SetVehicleDoorShut(vehicle, doorIndex, false)
    else
        SetVehicleDoorOpen(vehicle, doorIndex, false, false)
    end
end

local function buildDoorDefinition(name, label, bones, offset, doorIndex, trackSwing)
    return {
        name = name,
        label = label,
        bones = bones,
        offset = offset,
        doorIndex = doorIndex,
        trackSwing = trackSwing,
        distance = 2.2,
        canInteract = function(entity)
            return canInteractWithDoor(entity)
        end,
        onSelect = function(data)
            toggleDoor(data.entity, doorIndex)
        end,
    }
end

exports['v-interact']:AddGlobalVehicle({
    buildDoorDefinition('v-interact:driverFrontDoor', 'Toggle Driver Door', 'door_dside_f', vector3(0.0, -1.0, 0.2), 0, true),
    buildDoorDefinition('v-interact:passengerFrontDoor', 'Toggle Passenger Door', 'door_pside_f', vector3(0.0, -1.0, 0.2), 1, true),
    buildDoorDefinition('v-interact:driverRearDoor', 'Toggle Rear Driver Door', 'door_dside_r', vector3(0.0, -1.0, 0.2), 2, true),
    buildDoorDefinition('v-interact:passengerRearDoor', 'Toggle Rear Passenger Door', 'door_pside_r', vector3(0.0, -1.0, 0.2), 3, true),
    buildDoorDefinition('v-interact:hood', 'Toggle Hood', 'bonnet', vector3(0.0, 0.7, 0.0), 4, false),
    buildDoorDefinition('v-interact:trunk', 'Toggle Trunk', 'boot', vector3(0.0, -0.5, 0.0), 5, false),
})
