# v-interact

World-space proximity interaction points for FiveM: a small ambient dot that
resolves into a keycap-style `[E] Label` prompt as the player gets close and
looks at it, with mouse-wheel cycling between multiple options on the same
point. Rendering is fully native (`DrawSprite`/`SetDrawOrigin`), so it stays
glued to its world position with no perceived lag even during fast camera
movement.

Also ships `vehicle_doors.lua`, which automatically places a point on every
door, the hood, and the trunk of every nearby vehicle, tracked live so the
points follow the vehicle as it moves.

## Installation

1. Drop the resource in your server's resources folder.
2. Add `ensure v-interact` to your `server.cfg`.
3. Add points from your own resource via the exports documented further down.


## Exports

Call these as `exports['v-interact']:ExportName(...)` from another resource.

### `AddPoint(coords, options, data) -> pointId`

Registers a new interaction point and returns its id.

- `coords` - `vector3`, world position of the point.
- `options` - array of option tables, each:
  - `label` - `string` or `function(point) -> string` (required)
  - `onSelect` - `function(point)` - called when chosen
  - `event` - `string` - fires `TriggerEvent(event, point)`
  - `serverEvent` - `string` - fires `TriggerServerEvent(serverEvent, point.id)`
  - `canInteract` - `function(point) -> boolean` - hide this option when it returns false
  - `control` - `number` - extra bind, in addition to `Config.KeyControl`
  - `distance` - `number` - overrides `Config.Distance` for this option only
  - `key` - `string` - overrides the `Config.Key` shown on the keycap for this option
- `data` - table (optional):
  - `distance` - `number` - visibility/trigger radius (default `Config.VisibleDistance`)
  - `zOffset` - `number` - vertical offset for the drawn marker/prompt
  - `noDot` - `boolean` - `true` to skip the ambient dot, only showing the prompt up close
  - `vehicleDot` - `boolean` - `true` to use the vehicle marker icon/size and live per-frame position tracking

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

Moves an existing point - e.g. to keep it glued to a moving entity.

```lua
exports['v-interact']:UpdatePointCoords(pointId, GetEntityCoords(someEntity))
```

### `AddPointOptions(id, options)`

Appends more prompts to a point that already exists, without recreating it.
`options` is an array in the same shape as `AddPoint`'s `options` parameter.

```lua
local trunkOption = { label = 'Open Trunk', onSelect = function() ... end }
exports['v-interact']:AddPointOptions(pointId, { trunkOption })
```

### `RemovePointOption(id, option)`

Removes one prompt from a point. `option` must be the exact table you passed
to `AddPoint`/`AddPointOptions` - keep a reference to it if you'll want to
remove it later.

```lua
exports['v-interact']:RemovePointOption(pointId, trunkOption)
```

### `ClearPointOptions(id)`

Removes every prompt from a point at once - a fresh start for rebuilding a
fully dynamic option list, instead of calling `RemovePointOption` per entry.

```lua
exports['v-interact']:ClearPointOptions(pointId)
exports['v-interact']:AddPointOptions(pointId, { newOption })
```

### `GetPointCoords(id) -> vector3 or nil`

Reads back a point's current position, or `nil` if the id doesn't exist.

```lua
local coords = exports['v-interact']:GetPointCoords(pointId)
if coords then print(coords.x, coords.y, coords.z) end
```

### `SetPointDistance(id, distance)`

Changes a point's visibility/trigger radius after creation, without having to
`RemovePoint` + `AddPoint` to change it.

```lua
exports['v-interact']:SetPointDistance(pointId, 4.0)
```

### `GetActivePointId() -> id or nil`

Returns whichever point currently has the prompt focused (`nil` if none), so
another resource can react to what the player is looking at.

```lua
local activeId = exports['v-interact']:GetActivePointId()
if activeId == myStashPointId then print('player is looking at the stash') end
```

### `HidePoint(id)`

Temporarily hides a point (keeps its coords/options registered under the same
id) so it can't become ambient or active.

```lua
exports['v-interact']:HidePoint(pointId)
```

### `ShowPoint(id)`

Reverses `HidePoint`.

```lua
exports['v-interact']:ShowPoint(pointId)
```

### `HideAllPoints()`

Hides every currently registered point at once.

```lua
exports['v-interact']:HideAllPoints()
```

## Automatic vehicle interaction points

`client/vehicle_doors.lua` needs no setup - it automatically finds nearby
vehicles and registers a point on each door (letting the player get in
through whichever one they're looking at), the hood, and the trunk, tracked
live so the points follow the vehicle as it drives. Doors stay interactable
even with someone in the seat; entering is only gated on the seat itself
being free. All panels hide while the vehicle is locked or while the player
is already in any vehicle.

Set `Config.ShowVehicleDoorDots = false` if you'd rather these panels stay
invisible until the player is close enough to trigger the prompt, instead of
showing an ambient dot from further away.
