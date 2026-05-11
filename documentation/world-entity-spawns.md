# World Entity Spawns

This system adds deterministic, prefab-defined runtime spawn points for enemies and treasure.

It is built to satisfy the lifecycle rules:

- Positions are defined directly in prefab modules.
- When a chunk loads for at least one player, entities in that chunk spawn.
- When a chunk unloads for all players, entities despawn if they are not dead/claimed.
- Enemy generation happens once per world seed + marker, and respawn uses the same generated result.

## Files

- `src/shared/Services/World/Prefabs/PrefabTypes.luau`
- `src/shared/Services/World/Prefabs/PrefabUtils.luau`
- `src/shared/Services/World/WorldSpawnSettings.luau`
- `src/shared/Services/World/WorldSpawnServiceServer.luau`
- `src/shared/Services/World/WorldServiceServer.luau`
- `src/shared/Services/World/WorldServiceClient.luau`
- `src/shared/Services/Enemy/EnemyServiceServer.luau`

## Prefab Marker Schema

Prefabs can optionally declare `SpawnMarkers` in their definition:

```luau
SpawnMarkers = {
	{
		Id = "CampGuardWest",
		Type = "Enemy",
		Offset = Vector3.new(-7, 0, 0),
		Enemy = {
			PoolId = "Camp.Guards",
			LevelMin = 10,
			LevelMax = 34,
			LevelStep = 2,
		},
	},
	{
		Id = "CampSupplies",
		Type = "Treasure",
		Offset = Vector3.new(4.2, 0, -3.8),
		Treasure = {
			LootTableId = "CampStock",
			PromptActionText = "Loot Supplies",
			PromptObjectText = "Camp Stash",
		},
	},
}
```

The marker offset is relative to the prefab anchor tile center.

## Chunk Lifecycle

Client now reports chunk lifecycle to the world server:

- `ChunkLoaded` when a chunk is rendered
- `ChunkUnloaded` when a chunk is removed
- `ResetLoadedChunks` when world is cleared

Server tracks chunk reference counts (across players):

- `refcount` transitions `0 -> 1`: activate chunk spawns
- `refcount` transitions `1 -> 0`: deactivate chunk spawns

## Enemy Lifecycle

For each enemy marker:

1. A deterministic generated payload is created at world initialization:
   - selected enemy path (or fixed `EnemyPath`)
   - selected level
   - optional loot table id tag
2. On chunk activation, `EnemyServiceServer.Spawn(...)` instantiates enemy using that payload.
3. If chunk unloads and enemy is alive, it is despawned (`Enemies.Despawn`) and marker returns to `Dormant`.
4. If enemy dies, marker becomes `Dead` and never respawns for that world seed instance.

`EnemyServiceServer` now supports:

- spawn target as `BasePart | CFrame | Vector3`
- optional spawn context attributes on the model
- optional death callback (`OnDeath`)
- `Enemies.Despawn(uuid)` without recording a death

## Treasure Lifecycle

For each treasure marker:

1. Loot is rolled once at world initialization from configured loot tables.
2. On chunk activation, an interactable runtime treasure anchor is spawned with `ProximityPrompt`.
3. On claim:
   - configured rewards are granted via `InventoryServiceServer`
   - marker status becomes `Claimed`
   - runtime anchor is removed and does not respawn
4. On chunk unload before claim, anchor despawns and marker returns to `Dormant`.

## Configuration

All behavior is centralized in:

- `src/shared/Services/World/WorldSpawnSettings.luau`

Tune here:

- Global enable/disable
- Chunk unload despawn policy
- Enemy pools and weighted selection
- Biome default level ranges
- Treasure prompt defaults
- Treasure loot tables:
  - currency stack grants
  - weighted stack rewards
  - weighted weapon rewards

## Added Prefab Spawn Markers

Markers were added to these runtime structures:

- `Shared::TreasureChestCache`
- `Shared::TravelerCampfireRing`
- `Shared::NodeTentOutpost`
- `Shared::StoneWellPlaza`
- `Forest::ForagerSupplyCamp`
- `HighlandDesert::OasisFireCamp`
- `TemperateGrassland::FarmPlotRows`

You can add markers to any other prefab by adding `SpawnMarkers` entries.

## State Model

Each spawn point tracks:

- `Dormant`: generated but currently not instantiated
- `Active`: currently spawned in a loaded chunk
- `Dead`: enemy killed (never respawns)
- `Claimed`: treasure claimed (never respawns)

Spawn point identity is deterministic and includes:

- world seed
- column coordinate
- prefab id
- marker id/index

## Extending

1. Add markers to more prefabs.
2. Add new enemy pools in `WorldSpawnSettings.Enemy.Pools`.
3. Add new treasure tables in `WorldSpawnSettings.Treasure.LootTables`.
4. Update marker config (`PoolId`, `LootTableId`, level overrides) without touching service logic.
