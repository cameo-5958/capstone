# World Preview Tool

This folder contains a Python 3D preview that mirrors the world-generation pipeline in:

- `src/shared/Services/World/WorldTypes.luau`
- `src/shared/Services/World/WorldServiceServer.luau`
- `src/shared/Services/World/WorldServiceClient.luau` (visual conventions)

## Setup

```bash
pip install ursina
```

## Run

```bash
python tools/world_preview/world_preview.py
```

If Ursina renders as a white screen on your machine, use matplotlib fallback:

```bash
python tools/world_preview/world_preview.py --renderer matplotlib
```

Example with explicit config values:

```bash
python tools/world_preview/world_preview.py --seed 12345 --radius-tiles 14 --tile-size 4 --chunk-size 8 --base-y 120 --sea-level 2 --biome TemperateGrassland --ocean-mode None
```

## 3D Controls

- Right mouse drag: look
- `W/A/S/D`: move
- `Q/E`: vertical move
- `R`: regenerate same seed/settings
- `N`: increment seed and regenerate

Matplotlib fallback controls:

- Mouse drag: orbit camera
- Mouse wheel: zoom
- `R`: regenerate same seed/settings
- `N`: increment seed and regenerate

## Configurability

All `WorldConfig` fields are exposed as CLI flags:

- `--seed`
- `--tile-size`
- `--chunk-size`
- `--radius-tiles`
- `--base-y`
- `--biome`
- `--sea-level`
- `--ocean-mode`

Additionally, every sieve constant used by the server algorithm is exposed via CLI (all fields in `GenerationTuning`), so you can tune generation behavior without editing code.

## Source Grep

See `tools/world_preview/world_generation_sources.txt` for grep output used to trace generation and render-copy call sites.
