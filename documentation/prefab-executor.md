# Prefab Executor Usage

Use the server Command Bar in Studio:

```lua
local PrefabExecutor = require(game:GetService("ReplicatedStorage").Services.World.Prefabs.PrefabExecutor)
PrefabExecutor.GenerateGallery({
    ClearExisting = true,
    IncludeExecutorOnly = false,
    IncludeMarkers = true,
})
```

## Options

- `ClearExisting: boolean?`
Defaults to `true`. Clears `Workspace.PrefabGallery` children before new generation.

- `IncludeExecutorOnly: boolean?`
Defaults to `false`. Keeps gallery foliage-focused unless explicitly enabled.

- `IncludeMarkers: boolean?`
Defaults to `true`. Includes shared transparent marker prefabs.

- `TileSize: number?`
Overrides gallery build context tile size (default: `10`).

- `SpacingStuds: number?`
Overrides spacing between gallery placements (default: `26` studs).

- `BasePosition: Vector3?`
Overrides where gallery generation starts (default: `Vector3.new(0, 12, 0)`).
