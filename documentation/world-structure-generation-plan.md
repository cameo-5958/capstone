# World Structure Generation Plan

Last updated: 2026-05-10

## Goal
Build a robust, expandable, configurable structure system for world generation that can be tuned before generation and safely extended with new prefabs.

## Current Structure Audit (Repo)
Checked source: `src/shared/Services/World/Prefabs/Biomes`

### Totals
- Structure prefabs: 49
- Runtime-eligible structures today: 10 (`Shared::NodeTentOutpost`, `Shared::NodeLampSquare`, `Shared::NodeFenceCamp`, `Shared::TreasureChestCache`, `TemperateGrassland::FarmPlotRows`, `Shared::TravelerCampfireRing`, `Shared::ProduceCartStand`, `Shared::StoneWellPlaza`, `Forest::ForagerSupplyCamp`, `HighlandDesert::OasisFireCamp`)
- Currently excluded from registry/runtime use: none

### By biome
- `TemperateGrassland`: BarnLeanTo, FarmPlotRows, FieldstoneCottage, StoneWellFence, WindmillShed
- `PineHighlands`: CliffWatchHut, PrayerCairnShelter, TimberCabin, WoodStoreLeanTo
- `Forest`: CampfireShelter, ForagerSupplyCamp, RangerCabin, RuinedShrine, TreePlatformHut
- `DenseForest`: BanditShack, HiddenHunterHut, OvergrownStoneGate, RuinedAltar
- `Alpine`: FrozenArchRuin, MountainChalet, ObservatoryHut, RopeLiftStation
- `HighlandDesert`: AdobeHouse, CaravanShelter, DesertWatchtower, OasisFireCamp, SandstoneShrine
- `Marshland`: BogShack, StiltHut, SunkenRuinCorner, TotemPlatform
- `Shared`: CanalHouseWide, CliffWatchHouse, CobbleHouseA, CobbleHouseB, CobbleHouseCourtyard, LanternPostIron, LanternPostWood, NodeFenceCamp, NodeLampSquare, NodeTentOutpost, PlazaFountain, ProduceCartStand, StoneWellPlaza, TimberHouseTall, TownhouseNarrow, TravelerCampfireRing, TreasureChestCache, VillageGateArch

## Online Research (applied)
- Poisson-disc / blue-noise spacing with a background grid is a strong baseline for non-clumping placement and scalable checks.
  - Bridson, 2007: https://www.cs.ubc.ca/~rbridson/docs/bridson-siggraph07-poissondisk.pdf
- Roblox module-based configuration is a good fit for centralized, reusable generation settings and deterministic behavior.
  - ModuleScript: https://create.roblox.com/docs/reference/engine/classes/ModuleScript
  - Reuse code / modules: https://create.roblox.com/docs/scripting/module
  - Random datatype (seeded deterministic streams): https://create.roblox.com/docs/reference/engine/datatypes/Random
- Flattening structure footprints should use masked flatten + blended edges to avoid hard seams with surrounding terrain.
  - HeightField Flatten (masked flatten + blended transitions): https://www.sidefx.com/docs/houdini/nodes/sop/heightfield_flatten.html

## Implementation Steps
1. [x] Add a world-structure settings module as single source of truth.
2. [x] Move runtime nature chance/weights out of server hardcode and into settings.
3. [x] Add biome-aware runtime node-structure pools + weights in settings.
4. [x] Create runtime flavor prefabs.
   - `Shared::TreasureChestCache`
   - `TemperateGrassland::FarmPlotRows`
   - `Shared::TravelerCampfireRing`
   - `Shared::ProduceCartStand`
   - `Shared::StoneWellPlaza`
   - `Forest::ForagerSupplyCamp`
   - `HighlandDesert::OasisFireCamp`
5. [x] Keep existing location selection flow and expand node assignment to use biome pools.
6. [x] Add post-placement structure footprint flatten pass.
   - Flatten only for `Category == "Structure"`
   - Use prefab footprint dimensions to compute influence radius in tiles
   - Blend to local target height and smooth edges
7. [x] Add configurable runtime node-structure spawn density (`RuntimeNodeStructureChance`).
8. [x] Tune default spawn density and flattening profile for more frequent, stable placements.
9. [x] Add manual structure prefab preview spawn for Studio verification.
10. [x] Enforce hard fog-limited vision and tighter streaming radius.
11. [x] Force structure/node flattening so steep node hills are shaved aggressively.
12. [x] Upscale and redesign small shared house prefabs for stronger town silhouettes.
13. [x] Add true structure assemblies (multi-part clusters with camps/towns/farms).
14. [x] Add node lock-in reservation for detailed assemblies to prevent overlap.
15. [x] Add automatic detail pass for habitation-scale structures at build time.
16. [x] Add footprint-aware placement reservation so full prefab extents cannot overlap.
17. [x] Retune runtime generation toward environmental clusters (fences/lamps/wells/camps) with reduced dense building frequency.
18. [ ] Validate in Studio with deterministic seed reruns.

## True Structure Assemblies (runtime)
- Node placement now supports assembly definitions with multiple component prefabs per structure node.
- Assembly placement uses per-component offset targets plus local search to adapt to terrain.
- Required components must resolve or the assembly falls back; optional components are best-effort.
- Lock-in reserves occupied structure columns so neighboring nodes/ambient passes cannot overlap the cluster.
- Footprint-aware lock-in reserves full scaled prefab extents (not only center columns), preventing large structures from intersecting.
- Assembly pool now prioritizes environmental flavor sets (wells, lamp squares, fences, lantern posts, camp hubs) over dense building clusters.
- Added temperate farm settlements:
  - `TemperateGrassland::FarmsteadCluster`
  - Includes `FieldstoneCottage`, `BarnLeanTo`, `FarmPlotRows`, `StoneWellFence`, `WindmillShed` (plus flavor campfire).

## Applied Tuning Snapshot (`BalancedSceneryV1`)
- Runtime nature chance by biome increased slightly to add overall density while preserving biome bias.
- Runtime node structure chance: `0.20` (moved to `WorldStructureSettings`).
- Node pools now prioritize environmental flavor structures (fences, lantern posts, wells, lamp squares, camp rings) with lower dense-building frequency.
- Flattening settings tuned for forceful node/structure leveling:
  - `MaxHalfFootprintTiles = 24`
  - `RingOuterScale = 3.2`
  - `TargetHeightBlend = 0.15`
  - `SmoothingPasses = 3`
  - `SmoothingBlend = 0.55`
  - `ForceFlattenEnabled = true`
  - `ForceCorePaddingTiles = 4`
  - `ForceCoreWeight = 7.5`
  - `ForceRingTargetPercentile = 0.16`
  - `ForceClampRisePerTile = 0.35`
  - `ForceClampRadiusScale = 5.2`

## Visibility Tuning
- Gameplay fog now clamps near-range vision (default `FogStart=190`, `FogEnd=194`).
- Freecam no longer disables fog distance; detached camera keeps the same fog cap.
- Stream tuning reduced to match fog horizon:
  - Server suggestion: `StreamRadius=8`, `UnloadRadius=11`
  - Server initial burst: `24` chunks
  - Client request budget: `16` chunks/batch

## Manual Preview Spawn
- `WorldServiceServer.Regenerate()` now calls `PrefabExecutor.GenerateGallery()` through a settings gate.
- Preview is Studio-only by default and spawns near the active player spawn offset so prefabs are visible immediately.
- Default preview mode is structure-only (`IncludeNature=false`, `IncludeStructures=true`, `IncludeExecutorOnly=true`).

## Flattening Rules (runtime)
- Do not flatten marker/nature prefabs.
- Flatten only around structure-tagged columns.
- Respect water/path safety:
  - Skip water cells
  - Keep path cells authoritative if needed
- Apply 1-2 smoothing passes in footprint area to reduce cliffs.

## Validation Checklist
- New structures appear in runtime generation.
- Structures do not spawn underwater.
- Structures are not visibly floating/sunken into harsh slopes.
- Same seed produces the same structure distribution.
- Different seeds produce varied but plausible distribution.
- Existing nature runtime spawning remains intact.
