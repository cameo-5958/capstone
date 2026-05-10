# World Prefab Continuity Brief

Use this file as the single source of truth for ongoing world prefab work.

## Non-Negotiable Style Rules
- Stud-designed means small rectangular blocks with stud surfaces.
- Do not use large chunky primitive shapes as final visual language.
- Geometric style must stay rectangular (no ball/cylinder silhouette look for world prefabs).
- Foliage must be collidable (players should not walk through foliage).
- No runtime structures for now (nature-only runtime spawning).
- Trees must be present in runtime biome pools.

## Active Runtime Rules
- Runtime spawn set is nature-prefabs only.
- Node/city structure placement is disabled for now.
- Shared marker boxes remain temporary helper markers and non-collidable.

## Current Fixes Applied
1. Prefab collision defaults now keep prefab parts collidable except marker category.
2. Tree "bud/stub" mutation behavior was removed from prefab utility variation logic.
3. Runtime nature pools were updated to include tree prefabs for all biomes.
4. Runtime node structure placement list was cleared so no structures are auto-placed.
5. Prefab part shape enforcement was set to rectangular block shape.

## Next Visual Pass Checklist
1. Audit grass/patch prefabs that still look like raised pads and convert them into clustered smaller rectangular stud blocks.
2. Keep tree trunks/canopies in rectangular voxel-like compositions with natural variation.
3. Validate gameplay collision in Studio:
   - Walk into foliage and confirm collision.
   - Confirm ground is solid.
   - Confirm marker boxes do not block movement.
4. Confirm runtime spawning:
   - Trees appear again per biome.
   - No houses/lamps/fences/tents spawn automatically at runtime.

## Reconnect/Resume Prompt
If session disconnects, paste only this:

`Continue world prefab work from documentation/world-prefab-continuity.md and apply the Next Visual Pass Checklist.`
