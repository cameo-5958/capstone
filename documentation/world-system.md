# World System

## 1. Purpose

The World System generates and replicates one shared floating island per server.

It is seed-driven, deterministic for a given seed, and split into:

- Server-authoritative world data + collision bake
- Client-local visual chunk rendering

Primary modules:

- `src/shared/Services/World/WorldTypes.luau`
- `src/shared/Services/World/WorldServiceServer.luau`
- `src/shared/Services/World/WorldServiceClient.luau`

## 2. Runtime Architecture

## 2.1 Workspace Structure

Server ensures:

- `Workspace.WorldService`
- `Workspace.WorldService.VisualRoot`
- `Workspace.WorldService.CollisionRoot`

Client creates a local render folder under `VisualRoot`:

- `Client_<UserId>`

## 2.2 Network Model

Remote endpoint: `WorldEndpoint`.

Server -> client events:

- `ClearWorld`
- `InitializeWorld`
- `LoadChunk`

Client -> server requests:

- `RequestWorld`
- `RequestRegenerate` (Studio only)

No per-frame world replication is used.

## 3. World Types and Defaults

From `WorldTypes`:

```luau
WorldConfig = {
  Seed,
  TileSize = 4,
  ChunkSize = 8,
  RadiusTiles = 14,
  BaseY = 120,
  Biome = "TemperateGrassland",
  SeaLevel = 2,
  OceanMode = "None",
}
```

Tile column model:

- `Solid`
- `SurfaceY`
- `BottomY`
- `SurfaceMaterial`
- `FillMaterial`
- `HasWater`
- `StructureTag`

Chunk model:

- `ChunkX`, `ChunkZ`
- `Columns` payload list

## 4. Seed Derivation and Determinism

Server seed logic:

- Production server: hash of `game.JobId`
- Studio fallback: timestamp-derived integer

For a fixed seed and config, the sieve pipeline is deterministic.

## 5. Generation Pipeline

Execution order in `generateWorld(seed)`:

1. Create empty grid of columns in radius bounds.
2. Footprint sieve: radial mask with noise edge shaping.
3. Height sieve: center bias + noise elevation.
4. Thickness sieve: floating island underside depth.
5. Material sieve: assign surface/fill materials by depth.
6. Water sieve: optional pond cells near sea threshold.
7. Structure sieve: seeded biome-scoped prefab IDs (nature runtime pool).
8. Bake:
- Build chunk payloads for clients.
- Build merged collision prisms for server physics.

## 6. Collision Baking Strategy

Collision is server-only and merged to reduce part count.

Algorithm summary:

- Group solid columns by chunk and row (`Z`).
- Merge contiguous `X` spans with equal `SurfaceY`/`BottomY`.
- Merge matching spans across adjacent `Z` rows.
- Emit one anchored prism part per merged region.

Result: collision part count is much lower than tile count.

## 7. Client Rendering Strategy

Client receives chunks and renders visible geometry locally:

- Fill part (`FillMaterial`)
- Surface cap (`SurfaceMaterial`)
- Optional water cap for pond tiles
- Prefab-driven structure visuals from `StructureTag` IDs via `PrefabRenderer`

These visual parts are non-colliding; collision comes from server bake.

## 8. Public API

## 8.1 Server API (`WorldServiceServer`)

- `init()`
- `GetSeed(): number`
- `GetWorld(): WorldState?`
- `GetTile(x, z): TileColumn?`
- `Regenerate(seedOverride?): number`

`Regenerate`:

- Rebuilds columns/chunks/collision
- Updates root attributes (`WorldSeed`, `WorldBiome`, etc.)
- Updates debug harness part
- Broadcasts full world refresh (`ClearWorld` + init + chunks)

## 8.2 Client API (`WorldServiceClient`)

- `init()`
- `GetSeed(): number`
- `GetConfig(): WorldConfig?`
- `GetLoadedChunkCount(): number`
- `GetWorldChangedSignal()`
- `RequestRegenerate(seed?)`

## 9. Lifecycle

## 9.1 Startup

1. Server loader initializes `World` service.
2. World roots are ensured.
3. Initial seed is derived.
4. World is generated once and broadcast.

## 9.2 Join in Progress

On `PlayerAdded`, server sends full world snapshot:

1. `ClearWorld`
2. `InitializeWorld`
3. `LoadChunk` for each chunk

## 9.3 Studio Regeneration

In Studio, clients can request regeneration; server may rebuild with override seed.

## 10. Debug and Test Harness

Server creates/updates `Workspace.WorldService.TestHarness` with:

- Visual marker above center tile
- Attributes: `WorldSeed`, `ChunkCount`, `CollisionPartCount`

This supports quick manual validation during iteration.

## 11. Operational Constraints

- World visuals are currently loaded at once (no distance streaming).
- Runtime structure generation is nature-prefab-only; building prefabs are executor/modelify assets.
- Collision is authoritative on server; clients only render visuals.

## 12. Extension Guidelines

## 12.1 New Biomes

1. Add biome material set in `WorldTypes.BiomeMaterials`.
2. Extend profile/config selection logic.
3. Add biome-aware branches in sieve stages where needed.

## 12.2 Additional Sieves

- Insert new sieve stage in pipeline before bake.
- Keep transformations idempotent and seed-only.
- Preserve deterministic ordering and stable chunk serialization.

## 12.3 Performance

- Avoid per-tile replicated parts on server.
- Keep collision merge logic coarse and stable.
- Prefer chunk-level network messages only on world init/regenerate.
