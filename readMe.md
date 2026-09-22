

# V-Interact

<img width="641" height="377" alt="{2E34A92F-7C93-45C4-96A7-C202182339FD}" src="https://github.com/user-attachments/assets/56457592-e4cb-4247-8928-c2646fd69b70" />

3d interaction points for FiveM. Each point starts as a small dot in
the world. When the player gets close and looks at it, the dot turns into a prompt. If a point has more than one option, the
player can scroll the mouse wheel to switch between them. Everything is
drawn natively (`DrawSprite`/`SetDrawOrigin`)

It also includes `vehicle_doors.lua`, which automatically adds a point on
all the doors, hoods, and trunk of any nearby vehicle.

<video src="https://r2.fivemanage.com/zl1azbSOnYlIdUyfImSJ8/MedalTVGrandTheftAutoVFiveM20260921175116951-trim-1790038701464.mp4" controls width="1280" height="720"></video>

https://r2.fivemanage.com/zl1azbSOnYlIdUyfImSJ8/MedalTVGrandTheftAutoVFiveM20260921175116951-trim-1790038701464.mp4

<img width="1280" height="720" alt="image" src="https://github.com/user-attachments/assets/c1423f24-8bde-4915-a2ee-03b530f1b1d6" />

[![Watch the demo video](demo-thumbnail.jpg)](https://r2.fivemanage.com/zl1azbSOnYlIdUyfImSJ8/MedalTVGrandTheftAutoVFiveM20260921175116951-trim-1790038701464.mp4)
*(click the image above to watch a demo video)*


## Installation

1. Put the resource in your server's resources folder.
2. Add `ensure v-interact` to your `server.cfg`.
3. Add points from your own resource using the exports listed below.


## Exports

### `AddPoint(coords, options, data) -> pointId`

This creates a new interaction point.

- `coords` - `vector3`, world position of the point.
- `options` - array of option tables, each:
  - `label` - `string` or `function(point) -> string` (required)
  - `onSelect` - `function(point)` - runs when the player picks this option
  - `event` - `string` - Triggers a client event `TriggerEvent(event, point)`
  - `serverEvent` - `string` - Triggers a server event `TriggerServerEvent(serverEvent, point.id)`
  - `canInteract` - `function(point) -> boolean` - hides this option when it returns false
  - `control` - `number` - an extra key bind, used along with `Config.KeyControl`
  - `distance` - `number` - sets a different distance for just this option, instead of `Config.Distance`
  - `key` - `string` - shows a different key on the keycap for this option, instead of `Config.Key`
- `data` - table (optional):
  - `distance` - `number` - how far away the point can be seen or used (default `Config.VisibleDistance`)
  - `zOffset` - `number` - moves the point up/down
  - `noDot` - `boolean` - set to `true` to not show a dot and only show the prompt when close
  - `vehicleDot` - `boolean` - set to `true` to use the vehicle marker's icon and size, and track its position every frame

```lua
local pointId = exports['v-interact']:AddPoint(vector3(0.0, 0.0, 72.0), {
    { label = 'Open Stash', onSelect = function(point) print('opened', point.id) end },
}, { distance = 8.0 })
```

### `RemovePoint(id)`

Deletes a point entirely.

```lua
exports['v-interact']:RemovePoint(pointId)
```

### `UpdatePointCoords(id, coords)`

Changes the position of an existing point

```lua
exports['v-interact']:UpdatePointCoords(pointId, GetEntityCoords(someEntity))
```

### `AddPointOptions(id, options)`

Adds more prompts to a point that already exists, without having to
recreate it. `options` uses the same format as the `options` parameter in
`AddPoint`.

```lua
local trunkOption = { label = 'Open Trunk', onSelect = function() ... end }
exports['v-interact']:AddPointOptions(pointId, { trunkOption })
```

### `RemovePointOption(id, option)`

Removes one prompt from a point. `option` has to be the same table you
passed into `AddPoint` or `AddPointOptions`.

```lua
exports['v-interact']:RemovePointOption(pointId, trunkOption)
```

### `ClearPointOptions(id)`

Removes all prompts within a point.

```lua
exports['v-interact']:ClearPointOptions(pointId)
exports['v-interact']:AddPointOptions(pointId, { newOption })
```

### `GetPointCoords(id) -> vector3 or nil`

Gives you the coords of a points current position

```lua
local coords = exports['v-interact']:GetPointCoords(pointId)
if coords then print(coords.x, coords.y, coords.z) end
```

### `SetPointDistance(id, distance)`

Changes the distance a point can be seen or used, after it's already been
created.

```lua
exports['v-interact']:SetPointDistance(pointId, 4.0)
```

### `GetActivePointId() -> id or nil`

Returns the id of whatever point the player is looking at

```lua
local activeId = exports['v-interact']:GetActivePointId()
if activeId == myStashPointId then print('player is looking at the stash') end
```

### `HidePoint(id)`

Hides an existing point.

```lua
exports['v-interact']:HidePoint(pointId)
```

### `ShowPoint(id)`

Shows an existing point that is hidden

```lua
exports['v-interact']:ShowPoint(pointId)
```

### `HideAllPoints()`

Hides all points at once.

```lua
exports['v-interact']:HideAllPoints()
```

## Automatic vehicle interaction points

`client/vehicle_doors.lua` works right away with no setup. It finds nearby
vehicles on its own and adds a point on each door (so the player can get in
through whichever one they're looking at), the hood, and the trunk. These
points update live and follow the vehicle as it drives. Doors stay
interactable even if someone is already sitting in that seat - the only
thing that matters is whether the seat itself is free. All points hide
while the vehicle is locked, or while the player is already inside a
vehicle.

Set `Config.ShowVehicleDoorDots = false` if you don't want the ambient dot
shown from far away. With this off, the points stay invisible until the
player is close enough to actually see the prompt.
```
