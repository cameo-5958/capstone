#!/usr/bin/env python3
"""
World generation preview tool.

Replicates the world generation pipeline from:
- src/shared/Services/World/WorldTypes.luau
- src/shared/Services/World/WorldServiceServer.luau

3D controls (Ursina EditorCamera default controls):
- Right mouse drag: look around
- WASD: move on plane
- Q / E: move down / up
- Mouse wheel: zoom speed
- R: regenerate with the current seed and settings
- N: increment seed by 1 and regenerate
"""

from __future__ import annotations

import argparse
import dataclasses
import math
import random
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple, get_type_hints


@dataclass
class WorldConfig:
    seed: int
    tile_size: float
    chunk_size: int
    radius_tiles: int
    base_y: int
    biome: str
    sea_level: int
    ocean_mode: str


@dataclass
class GenerationTuning:
    footprint_edge_noise_mod_x: int = 997
    footprint_edge_noise_mod_z: int = 557
    footprint_edge_noise_offset_x_scale: float = 0.17
    footprint_edge_noise_offset_z_scale: float = 0.23
    footprint_noise_frequency: float = 0.21
    footprint_noise_seed_scale: float = 0.0003
    footprint_noise_amplitude: float = 2.5
    footprint_secondary_noise_frequency: float = 0.47
    footprint_secondary_noise_seed_scale: float = 0.00051
    footprint_secondary_noise_amplitude: float = 2.8
    footprint_domain_warp_frequency: float = 0.09
    footprint_domain_warp_seed_scale: float = 0.00041
    footprint_domain_warp_amplitude: float = 3.4
    footprint_ridge_noise_frequency: float = 0.28
    footprint_ridge_noise_seed_scale: float = 0.00063
    footprint_ridge_noise_amplitude: float = 2.2
    footprint_angular_lobes: int = 6
    footprint_angular_amplitude: float = 1.75
    footprint_angular_seed_scale: float = 0.00027
    footprint_bay_noise_frequency: float = 0.22
    footprint_bay_noise_seed_scale: float = 0.00083
    footprint_bay_threshold: float = 0.52
    footprint_bay_amplitude: float = 4.2
    footprint_inner_mass_bias: float = 1.2
    footprint_min_threshold: float = 2.0

    height_noise_mod_x: int = 1787
    height_noise_mod_z: int = 2677
    height_noise_offset_x_scale: float = 0.19
    height_noise_offset_z_scale: float = 0.11
    height_coarse_frequency: float = 0.12
    height_fine_frequency: float = 0.33
    height_coarse_seed_scale: float = 0.0007
    height_fine_seed_scale: float = 0.0011
    height_center_bias_amplitude: float = 8.0
    height_coarse_amplitude: float = 4.0
    height_fine_amplitude: float = 1.5

    thickness_noise_mod_x: int = 4337
    thickness_noise_mod_z: int = 3911
    thickness_noise_offset_x_scale: float = 0.13
    thickness_noise_offset_z_scale: float = 0.09
    thickness_noise_frequency: float = 0.15
    thickness_seed_scale: float = 0.0013
    thickness_base: float = 7.0
    thickness_center_mass_amplitude: float = 10.0
    thickness_noise_amplitude: float = 4.0
    min_thickness: int = 4

    water_noise_mod_x: int = 7919
    water_noise_mod_z: int = 6361
    water_noise_offset_x_scale: float = 0.07
    water_noise_offset_z_scale: float = 0.05
    water_noise_frequency: float = 0.18
    water_seed_scale: float = 0.0019
    pond_threshold: float = 0.48
    pond_surface_bias_max: int = 3

    structure_seed_offset: int = 4103
    structure_edge_padding: int = 2
    tree_threshold: float = 0.02
    rock_threshold: float = 0.045


@dataclass
class RenderOptions:
    center_world_on_base_y: bool = True
    y_offset: float = 0.0
    show_collision: bool = False
    collision_alpha: float = 0.35
    debug_marker: bool = True
    debug_world_panel: bool = True


@dataclass
class TileColumn:
    x: int
    z: int
    solid: bool
    surface_y: int
    bottom_y: int
    surface_material: str
    fill_material: str
    has_water: bool
    structure_tag: Optional[str]


@dataclass
class TileColumnPayload:
    x: int
    z: int
    solid: bool
    surface_y: int
    bottom_y: int
    surface_material: str
    fill_material: str
    has_water: bool
    structure_tag: Optional[str]


@dataclass
class ChunkData:
    chunk_x: int
    chunk_z: int
    columns: List[TileColumnPayload]


@dataclass
class CollisionPrism:
    x_tile_min: int
    x_tile_max: int
    z_tile_min: int
    z_tile_max: int
    top_y: int
    bottom_y: int


@dataclass
class WorldState:
    seed: int
    config: WorldConfig
    columns: Dict[Tuple[int, int], TileColumn]
    chunks: List[ChunkData]
    collision_parts: int
    collision_prisms: List[CollisionPrism]


DEFAULT_CONFIG = WorldConfig(
    seed=0,
    tile_size=4.0,
    chunk_size=8,
    radius_tiles=14,
    base_y=120,
    biome="Plains",
    sea_level=2,
    ocean_mode="None",
)

BIOME_MATERIALS: Dict[str, Dict[str, str]] = {
    "Plains": {
        "Surface": "Grass",
        "Mid": "Ground",
        "Deep": "Slate",
        "Water": "Water",
    },
    "Forest": {
        "Surface": "Grass",
        "Mid": "Ground",
        "Deep": "Slate",
        "Water": "Water",
    },
    "Tundra": {
        "Surface": "Snow",
        "Mid": "Slate",
        "Deep": "Slate",
        "Water": "Water",
    },
    "Desert": {
        "Surface": "Sand",
        "Mid": "Ground",
        "Deep": "Slate",
        "Water": "Water",
    },
    "Mountain": {
        "Surface": "Slate",
        "Mid": "Slate",
        "Deep": "Slate",
        "Water": "Water",
    },
}

MATERIAL_RGB: Dict[str, Tuple[int, int, int]] = {
    "Grass": (87, 130, 74),
    "Ground": (98, 86, 72),
    "Slate": (123, 123, 132),
    "Water": (76, 147, 255),
    "Wood": (91, 63, 44),
}


class PerlinNoise3D:
    _perm = [
        151, 160, 137, 91, 90, 15, 131, 13, 201, 95, 96, 53, 194, 233, 7, 225,
        140, 36, 103, 30, 69, 142, 8, 99, 37, 240, 21, 10, 23, 190, 6, 148,
        247, 120, 234, 75, 0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32,
        57, 177, 33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68, 175,
        74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231, 83, 111, 229, 122,
        60, 211, 133, 230, 220, 105, 92, 41, 55, 46, 245, 40, 244, 102, 143, 54,
        65, 25, 63, 161, 1, 216, 80, 73, 209, 76, 132, 187, 208, 89, 18, 169,
        200, 196, 135, 130, 116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64,
        52, 217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 85, 212,
        207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 223, 183, 170, 213,
        119, 248, 152, 2, 44, 154, 163, 70, 221, 153, 101, 155, 167, 43, 172, 9,
        129, 22, 39, 253, 19, 98, 108, 110, 79, 113, 224, 232, 178, 185, 112, 104,
        218, 246, 97, 228, 251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241,
        81, 51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 106, 157,
        184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 254, 138, 236, 205, 93,
        222, 114, 67, 29, 24, 72, 243, 141, 128, 195, 78, 66, 215, 61, 156, 180,
    ]
    _p = _perm * 2

    @staticmethod
    def _fade(t: float) -> float:
        return t * t * t * (t * (t * 6 - 15) + 10)

    @staticmethod
    def _lerp(t: float, a: float, b: float) -> float:
        return a + t * (b - a)

    @staticmethod
    def _grad(hash_value: int, x: float, y: float, z: float) -> float:
        h = hash_value & 15
        u = x if h < 8 else y
        v = y if h < 4 else (x if h in (12, 14) else z)
        return ((u if (h & 1) == 0 else -u) + (v if (h & 2) == 0 else -v))

    @classmethod
    def noise(cls, x: float, y: float, z: float) -> float:
        x_floor = math.floor(x)
        y_floor = math.floor(y)
        z_floor = math.floor(z)

        x_idx = x_floor & 255
        y_idx = y_floor & 255
        z_idx = z_floor & 255

        x_rel = x - x_floor
        y_rel = y - y_floor
        z_rel = z - z_floor

        u = cls._fade(x_rel)
        v = cls._fade(y_rel)
        w = cls._fade(z_rel)

        a = cls._p[x_idx] + y_idx
        aa = cls._p[a] + z_idx
        ab = cls._p[a + 1] + z_idx
        b = cls._p[x_idx + 1] + y_idx
        ba = cls._p[b] + z_idx
        bb = cls._p[b + 1] + z_idx

        return cls._lerp(
            w,
            cls._lerp(
                v,
                cls._lerp(
                    u,
                    cls._grad(cls._p[aa], x_rel, y_rel, z_rel),
                    cls._grad(cls._p[ba], x_rel - 1, y_rel, z_rel),
                ),
                cls._lerp(
                    u,
                    cls._grad(cls._p[ab], x_rel, y_rel - 1, z_rel),
                    cls._grad(cls._p[bb], x_rel - 1, y_rel - 1, z_rel),
                ),
            ),
            cls._lerp(
                v,
                cls._lerp(
                    u,
                    cls._grad(cls._p[aa + 1], x_rel, y_rel, z_rel - 1),
                    cls._grad(cls._p[ba + 1], x_rel - 1, y_rel, z_rel - 1),
                ),
                cls._lerp(
                    u,
                    cls._grad(cls._p[ab + 1], x_rel, y_rel - 1, z_rel - 1),
                    cls._grad(cls._p[bb + 1], x_rel - 1, y_rel - 1, z_rel - 1),
                ),
            ),
        )


def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


class WorldGenerator:
    def __init__(self, config: WorldConfig, tuning: GenerationTuning):
        self.config = config
        self.tuning = tuning

    @staticmethod
    def _column_key(x: int, z: int) -> Tuple[int, int]:
        return (x, z)

    def _get_biome_materials(self) -> Dict[str, str]:
        return BIOME_MATERIALS.get(self.config.biome, BIOME_MATERIALS["Plains"])

    def create_empty_columns(self) -> Dict[Tuple[int, int], TileColumn]:
        columns: Dict[Tuple[int, int], TileColumn] = {}
        materials = self._get_biome_materials()

        for x in range(-self.config.radius_tiles, self.config.radius_tiles + 1):
            for z in range(-self.config.radius_tiles, self.config.radius_tiles + 1):
                columns[self._column_key(x, z)] = TileColumn(
                    x=x,
                    z=z,
                    solid=False,
                    surface_y=self.config.base_y,
                    bottom_y=self.config.base_y - 4,
                    surface_material=materials["Surface"],
                    fill_material=materials["Mid"],
                    has_water=False,
                    structure_tag=None,
                )

        return columns

    def run_footprint_sieve(self, columns: Dict[Tuple[int, int], TileColumn]) -> None:
        seed = self.config.seed
        edge_noise_x = (seed % self.tuning.footprint_edge_noise_mod_x) * self.tuning.footprint_edge_noise_offset_x_scale
        edge_noise_z = (seed % self.tuning.footprint_edge_noise_mod_z) * self.tuning.footprint_edge_noise_offset_z_scale
        angular_phase = (seed * self.tuning.footprint_angular_seed_scale) % (math.pi * 2.0)
        radius = max(1.0, float(self.config.radius_tiles))
        angular_lobes = max(1, self.tuning.footprint_angular_lobes)

        for column in columns.values():
            x = float(column.x)
            z = float(column.z)
            distance = math.sqrt(x * x + z * z)

            # Domain warp first, so all downstream shape noises operate on curved space
            # instead of a radial grid, which makes silhouettes less circular.
            warp_x = PerlinNoise3D.noise(
                (x + edge_noise_x) * self.tuning.footprint_domain_warp_frequency,
                (z + edge_noise_z) * self.tuning.footprint_domain_warp_frequency,
                seed * self.tuning.footprint_domain_warp_seed_scale,
            )
            warp_z = PerlinNoise3D.noise(
                (x - edge_noise_z + 41.7) * self.tuning.footprint_domain_warp_frequency,
                (z + edge_noise_x - 17.3) * self.tuning.footprint_domain_warp_frequency,
                (seed + 791) * self.tuning.footprint_domain_warp_seed_scale,
            )
            warped_x = x + warp_x * self.tuning.footprint_domain_warp_amplitude
            warped_z = z + warp_z * self.tuning.footprint_domain_warp_amplitude

            primary_noise = PerlinNoise3D.noise(
                (warped_x + edge_noise_x) * self.tuning.footprint_noise_frequency,
                (warped_z + edge_noise_z) * self.tuning.footprint_noise_frequency,
                seed * self.tuning.footprint_noise_seed_scale,
            ) * self.tuning.footprint_noise_amplitude

            secondary_noise = PerlinNoise3D.noise(
                (warped_x - edge_noise_z) * self.tuning.footprint_secondary_noise_frequency,
                (warped_z + edge_noise_x) * self.tuning.footprint_secondary_noise_frequency,
                seed * self.tuning.footprint_secondary_noise_seed_scale,
            ) * self.tuning.footprint_secondary_noise_amplitude

            ridge_source = PerlinNoise3D.noise(
                (warped_x + 9.1) * self.tuning.footprint_ridge_noise_frequency,
                (warped_z - 4.7) * self.tuning.footprint_ridge_noise_frequency,
                seed * self.tuning.footprint_ridge_noise_seed_scale,
            )
            ridge_term = ((1.0 - abs(ridge_source)) * self.tuning.footprint_ridge_noise_amplitude) - (
                self.tuning.footprint_ridge_noise_amplitude * 0.5
            )

            angle = math.atan2(z, x)
            angular_term = math.sin((angle * angular_lobes) + angular_phase) * self.tuning.footprint_angular_amplitude

            # Carve bays near the edge only, preserving center mass.
            distance01 = clamp(distance / radius, 0.0, 1.0)
            bay_noise = PerlinNoise3D.noise(
                (warped_x + 13.1) * self.tuning.footprint_bay_noise_frequency,
                (warped_z - 9.3) * self.tuning.footprint_bay_noise_frequency,
                seed * self.tuning.footprint_bay_noise_seed_scale,
            )
            bay_cut = 0.0
            if bay_noise > self.tuning.footprint_bay_threshold:
                edge_factor = clamp((distance01 - 0.45) / 0.55, 0.0, 1.0)
                bay_cut = (
                    (bay_noise - self.tuning.footprint_bay_threshold)
                    * self.tuning.footprint_bay_amplitude
                    * edge_factor
                )

            inner_mass = (1.0 - distance01) * self.tuning.footprint_inner_mass_bias
            threshold = (
                radius
                + inner_mass
                + primary_noise
                + secondary_noise
                + ridge_term
                + angular_term
                - bay_cut
            )
            threshold = max(self.tuning.footprint_min_threshold, threshold)
            column.solid = distance <= threshold

    def run_height_sieve(self, columns: Dict[Tuple[int, int], TileColumn]) -> None:
        seed = self.config.seed
        height_noise_x = (seed % self.tuning.height_noise_mod_x) * self.tuning.height_noise_offset_x_scale
        height_noise_z = (seed % self.tuning.height_noise_mod_z) * self.tuning.height_noise_offset_z_scale

        for column in columns.values():
            if not column.solid:
                continue

            distance01 = clamp(
                math.sqrt(column.x * column.x + column.z * column.z) / self.config.radius_tiles,
                0.0,
                1.0,
            )
            center_bias = 1.0 - distance01
            coarse_noise = PerlinNoise3D.noise(
                (column.x + height_noise_x) * self.tuning.height_coarse_frequency,
                (column.z + height_noise_z) * self.tuning.height_coarse_frequency,
                seed * self.tuning.height_coarse_seed_scale,
            )
            fine_noise = PerlinNoise3D.noise(
                (column.x - height_noise_z) * self.tuning.height_fine_frequency,
                (column.z + height_noise_x) * self.tuning.height_fine_frequency,
                seed * self.tuning.height_fine_seed_scale,
            )
            elevation = self.config.base_y + math.floor(
                center_bias * self.tuning.height_center_bias_amplitude
                + coarse_noise * self.tuning.height_coarse_amplitude
                + fine_noise * self.tuning.height_fine_amplitude
            )
            column.surface_y = int(elevation)

    def run_thickness_sieve(self, columns: Dict[Tuple[int, int], TileColumn]) -> None:
        seed = self.config.seed
        thickness_noise_x = (seed % self.tuning.thickness_noise_mod_x) * self.tuning.thickness_noise_offset_x_scale
        thickness_noise_z = (seed % self.tuning.thickness_noise_mod_z) * self.tuning.thickness_noise_offset_z_scale

        for column in columns.values():
            if not column.solid:
                continue

            distance01 = clamp(
                math.sqrt(column.x * column.x + column.z * column.z) / self.config.radius_tiles,
                0.0,
                1.0,
            )
            center_mass = 1.0 - distance01
            thickness_noise = PerlinNoise3D.noise(
                (column.x + thickness_noise_x) * self.tuning.thickness_noise_frequency,
                (column.z + thickness_noise_z) * self.tuning.thickness_noise_frequency,
                seed * self.tuning.thickness_seed_scale,
            )
            thickness = max(
                self.tuning.min_thickness,
                math.floor(
                    self.tuning.thickness_base
                    + center_mass * self.tuning.thickness_center_mass_amplitude
                    + thickness_noise * self.tuning.thickness_noise_amplitude
                ),
            )
            column.bottom_y = int(column.surface_y - thickness)

    def run_material_sieve(self, columns: Dict[Tuple[int, int], TileColumn]) -> None:
        materials = self._get_biome_materials()

        for column in columns.values():
            if not column.solid:
                continue

            depth = column.surface_y - column.bottom_y
            if depth >= 12:
                column.fill_material = materials["Deep"]
            elif depth >= 7:
                column.fill_material = materials["Mid"]
            else:
                column.fill_material = materials["Deep"]

            column.surface_material = materials["Surface"]

    def run_water_sieve(self, columns: Dict[Tuple[int, int], TileColumn]) -> None:
        seed = self.config.seed
        water_noise_x = (seed % self.tuning.water_noise_mod_x) * self.tuning.water_noise_offset_x_scale
        water_noise_z = (seed % self.tuning.water_noise_mod_z) * self.tuning.water_noise_offset_z_scale
        sea_floor = self.config.base_y + self.config.sea_level
        materials = self._get_biome_materials()

        for column in columns.values():
            if not column.solid:
                continue

            pond_noise = PerlinNoise3D.noise(
                (column.x + water_noise_x) * self.tuning.water_noise_frequency,
                (column.z + water_noise_z) * self.tuning.water_noise_frequency,
                seed * self.tuning.water_seed_scale,
            )
            is_pond_candidate = pond_noise > self.tuning.pond_threshold and column.surface_y <= self.config.base_y + self.tuning.pond_surface_bias_max
            if is_pond_candidate:
                column.has_water = True
                column.surface_y = min(column.surface_y, sea_floor - 1)
                column.surface_material = materials["Mid"]
            else:
                column.has_water = False

    def run_structure_sieve(self, columns: Dict[Tuple[int, int], TileColumn]) -> None:
        structure_rng = random.Random(self.config.seed + self.tuning.structure_seed_offset)

        for column in columns.values():
            if not column.solid or column.has_water:
                continue

            distance = math.sqrt(column.x * column.x + column.z * column.z)
            if distance > self.config.radius_tiles - self.tuning.structure_edge_padding:
                continue

            roll = structure_rng.random()
            if roll < self.tuning.tree_threshold:
                column.structure_tag = "Tree"
            elif roll < self.tuning.rock_threshold:
                column.structure_tag = "Rock"

    @staticmethod
    def serialize_column(column: TileColumn) -> TileColumnPayload:
        return TileColumnPayload(
            x=column.x,
            z=column.z,
            solid=column.solid,
            surface_y=column.surface_y,
            bottom_y=column.bottom_y,
            surface_material=column.surface_material,
            fill_material=column.fill_material,
            has_water=column.has_water,
            structure_tag=column.structure_tag,
        )

    def build_chunk_payloads(self, columns: Dict[Tuple[int, int], TileColumn]) -> List[ChunkData]:
        chunk_map: Dict[Tuple[int, int], List[TileColumnPayload]] = {}

        for column in columns.values():
            if not column.solid:
                continue

            chunk_x = math.floor(column.x / self.config.chunk_size)
            chunk_z = math.floor(column.z / self.config.chunk_size)
            key = (chunk_x, chunk_z)
            if key not in chunk_map:
                chunk_map[key] = []

            chunk_map[key].append(self.serialize_column(column))

        chunks: List[ChunkData] = []
        for (chunk_x, chunk_z), payloads in chunk_map.items():
            payloads.sort(key=lambda c: (c.z, c.x))
            chunks.append(ChunkData(chunk_x=chunk_x, chunk_z=chunk_z, columns=payloads))

        chunks.sort(key=lambda c: (c.chunk_z, c.chunk_x))
        return chunks

    def bake_collision(self, chunks: List[ChunkData]) -> List[CollisionPrism]:
        prisms: List[CollisionPrism] = []

        for chunk in chunks:
            rows: Dict[int, List[Tuple[int, int, int]]] = {}
            for payload in chunk.columns:
                if not payload.solid:
                    continue
                rows.setdefault(payload.z, []).append((payload.x, payload.surface_y, payload.bottom_y))

            active: Dict[Tuple[int, int, int, int], CollisionPrism] = {}

            for row_z in sorted(rows.keys()):
                row = sorted(rows[row_z], key=lambda it: it[0])
                next_active: Dict[Tuple[int, int, int, int], CollisionPrism] = {}

                index = 0
                while index < len(row):
                    x_start, top_y, bottom_y = row[index]
                    x_min = x_start
                    x_max = x_start
                    next_index = index + 1

                    while next_index < len(row):
                        x_candidate, top_candidate, bottom_candidate = row[next_index]
                        if x_candidate != x_max + 1 or top_candidate != top_y or bottom_candidate != bottom_y:
                            break
                        x_max = x_candidate
                        next_index += 1

                    key = (x_min, x_max, top_y, bottom_y)
                    continuing = active.get(key)
                    if continuing and continuing.z_tile_max == row_z - 1:
                        continuing.z_tile_max = row_z
                        next_active[key] = continuing
                    else:
                        next_active[key] = CollisionPrism(
                            x_tile_min=x_min,
                            x_tile_max=x_max,
                            z_tile_min=row_z,
                            z_tile_max=row_z,
                            top_y=top_y,
                            bottom_y=bottom_y,
                        )

                    index = next_index

                for key, prism in active.items():
                    if key not in next_active:
                        prisms.append(prism)

                active = next_active

            prisms.extend(active.values())

        return prisms

    def generate(self) -> WorldState:
        columns = self.create_empty_columns()
        self.run_footprint_sieve(columns)
        self.run_height_sieve(columns)
        self.run_thickness_sieve(columns)
        self.run_material_sieve(columns)
        self.run_water_sieve(columns)
        self.run_structure_sieve(columns)

        chunks = self.build_chunk_payloads(columns)
        collision_prisms = self.bake_collision(chunks)

        return WorldState(
            seed=self.config.seed,
            config=self.config,
            columns=columns,
            chunks=chunks,
            collision_parts=len(collision_prisms),
            collision_prisms=collision_prisms,
        )


class WorldPreviewRuntime:
    def __init__(self, config: WorldConfig, tuning: GenerationTuning, render_options: RenderOptions):
        self.config = config
        self.tuning = tuning
        self.render_options = render_options
        self.generator = WorldGenerator(config, tuning)
        self.state = self.generator.generate()
        self.world_root = None

    def regenerate(self, seed: Optional[int] = None) -> None:
        if seed is not None:
            self.config.seed = max(1, int(seed))
        self.generator = WorldGenerator(self.config, self.tuning)
        self.state = self.generator.generate()

    def _render_y_shift(self) -> float:
        if self.render_options.center_world_on_base_y:
            return -float(self.config.base_y) + self.render_options.y_offset
        return self.render_options.y_offset

    def get_world_counts(self) -> Tuple[int, int, int]:
        solid_tiles = sum(1 for col in self.state.columns.values() if col.solid)
        water_tiles = sum(1 for col in self.state.columns.values() if col.solid and col.has_water)
        structures = sum(1 for col in self.state.columns.values() if col.solid and col.structure_tag is not None)
        return solid_tiles, water_tiles, structures

    def get_focus_target_and_radius(self) -> Tuple[Tuple[float, float, float], float]:
        solids = [col for col in self.state.columns.values() if col.solid]
        y_shift = self._render_y_shift()
        tile_size = self.config.tile_size

        if not solids:
            return (0.0, y_shift, 0.0), 30.0

        x_values = [col.x * tile_size for col in solids]
        z_values = [col.z * tile_size for col in solids]
        y_top_values = [float(col.surface_y) for col in solids]
        y_bottom_values = [float(col.bottom_y) for col in solids]

        x_min = min(x_values)
        x_max = max(x_values)
        z_min = min(z_values)
        z_max = max(z_values)
        y_min = min(y_bottom_values)
        y_max = max(y_top_values)

        center = (
            (x_min + x_max) * 0.5,
            ((y_min + y_max) * 0.5) + y_shift,
            (z_min + z_max) * 0.5,
        )
        span_x = x_max - x_min
        span_y = y_max - y_min
        span_z = z_max - z_min
        radius = max(span_x, span_y, span_z, 24.0) * 0.5
        return center, radius

    def build_scene(self):
        from ursina import Entity, Text, color

        if self.world_root is not None:
            self.world_root.disable()
            self.world_root = None

        y_shift = self._render_y_shift()
        tile_size = self.config.tile_size
        sea_level_y = self.config.base_y + self.config.sea_level

        self.world_root = Entity(name="WorldRoot")

        def make_cube(
            parent,
            name: str,
            x_size: float,
            y_size: float,
            z_size: float,
            x_pos: float,
            y_pos: float,
            z_pos: float,
            rgb: Tuple[int, int, int],
            alpha: float = 1.0,
        ):
            r, g, b = rgb
            Entity(
                parent=parent,
                name=name,
                model="cube",
                color=color.rgba(r, g, b, int(alpha * 255)),
                scale=(x_size, y_size, z_size),
                position=(x_pos, y_pos, z_pos),
            )

        for chunk in self.state.chunks:
            chunk_root = Entity(parent=self.world_root, name=f"Chunk_{chunk.chunk_x}_{chunk.chunk_z}")
            for column in chunk.columns:
                if not column.solid:
                    continue

                world_x = column.x * tile_size
                world_z = column.z * tile_size

                fill_height = max(0, column.surface_y - column.bottom_y)
                if fill_height > 0:
                    fill_center_y = column.bottom_y + (fill_height - 1) * 0.5 + y_shift
                    make_cube(
                        parent=chunk_root,
                        name=f"Fill_{column.x}_{column.z}",
                        x_size=tile_size,
                        y_size=fill_height,
                        z_size=tile_size,
                        x_pos=world_x,
                        y_pos=fill_center_y,
                        z_pos=world_z,
                        rgb=MATERIAL_RGB.get(column.fill_material, (118, 108, 95)),
                    )

                make_cube(
                    parent=chunk_root,
                    name=f"Surface_{column.x}_{column.z}",
                    x_size=tile_size,
                    y_size=1.0,
                    z_size=tile_size,
                    x_pos=world_x,
                    y_pos=column.surface_y + y_shift,
                    z_pos=world_z,
                    rgb=MATERIAL_RGB.get(column.surface_material, (87, 130, 74)),
                )

                if column.has_water and sea_level_y >= column.surface_y:
                    make_cube(
                        parent=chunk_root,
                        name=f"Water_{column.x}_{column.z}",
                        x_size=tile_size * 0.95,
                        y_size=0.5,
                        z_size=tile_size * 0.95,
                        x_pos=world_x,
                        y_pos=sea_level_y + y_shift,
                        z_pos=world_z,
                        rgb=MATERIAL_RGB["Water"],
                        alpha=0.6,
                    )

                if column.structure_tag == "Rock":
                    make_cube(
                        parent=chunk_root,
                        name=f"Rock_{column.x}_{column.z}",
                        x_size=tile_size * 0.6,
                        y_size=1.8,
                        z_size=tile_size * 0.6,
                        x_pos=world_x,
                        y_pos=column.surface_y + 1.3 + y_shift,
                        z_pos=world_z,
                        rgb=(123, 123, 132),
                    )
                elif column.structure_tag == "Tree":
                    make_cube(
                        parent=chunk_root,
                        name=f"TreeTrunk_{column.x}_{column.z}",
                        x_size=tile_size * 0.25,
                        y_size=3.0,
                        z_size=tile_size * 0.25,
                        x_pos=world_x,
                        y_pos=column.surface_y + 2.0 + y_shift,
                        z_pos=world_z,
                        rgb=MATERIAL_RGB["Wood"],
                    )
                    make_cube(
                        parent=chunk_root,
                        name=f"TreeCanopy_{column.x}_{column.z}",
                        x_size=tile_size * 0.9,
                        y_size=2.4,
                        z_size=tile_size * 0.9,
                        x_pos=world_x,
                        y_pos=column.surface_y + 4.4 + y_shift,
                        z_pos=world_z,
                        rgb=(72, 140, 70),
                    )

        if self.render_options.show_collision:
            for prism in self.state.collision_prisms:
                size_x = (prism.x_tile_max - prism.x_tile_min + 1) * tile_size
                size_z = (prism.z_tile_max - prism.z_tile_min + 1) * tile_size
                size_y = max(1, prism.top_y - prism.bottom_y + 1)
                center_x = (prism.x_tile_min + prism.x_tile_max) * 0.5 * tile_size
                center_z = (prism.z_tile_min + prism.z_tile_max) * 0.5 * tile_size
                center_y = (prism.bottom_y + prism.top_y) * 0.5 + y_shift

                make_cube(
                    parent=self.world_root,
                    name="CollisionPrism",
                    x_size=size_x,
                    y_size=size_y,
                    z_size=size_z,
                    x_pos=center_x,
                    y_pos=center_y,
                    z_pos=center_z,
                    rgb=(230, 70, 150),
                    alpha=self.render_options.collision_alpha,
                )

        if self.render_options.debug_marker:
            marker_root = Entity(parent=self.world_root, name="DebugMarkerRoot")
            y_shift = self._render_y_shift()
            marker_y = y_shift + 2.0

            make_cube(
                parent=marker_root,
                name="OriginAxisX",
                x_size=18.0,
                y_size=0.35,
                z_size=0.35,
                x_pos=0.0,
                y_pos=marker_y,
                z_pos=0.0,
                rgb=(255, 64, 64),
            )
            make_cube(
                parent=marker_root,
                name="OriginAxisY",
                x_size=0.35,
                y_size=18.0,
                z_size=0.35,
                x_pos=0.0,
                y_pos=marker_y + 9.0,
                z_pos=0.0,
                rgb=(64, 255, 64),
            )
            make_cube(
                parent=marker_root,
                name="OriginAxisZ",
                x_size=0.35,
                y_size=0.35,
                z_size=18.0,
                x_pos=0.0,
                y_pos=marker_y,
                z_pos=0.0,
                rgb=(64, 160, 255),
            )
            make_cube(
                parent=marker_root,
                name="OriginBeacon",
                x_size=1.25,
                y_size=26.0,
                z_size=1.25,
                x_pos=0.0,
                y_pos=marker_y + 13.0,
                z_pos=0.0,
                rgb=(255, 215, 72),
            )

        if self.render_options.debug_world_panel:
            target, radius = self.get_focus_target_and_radius()
            solid_tiles, water_tiles, structures = self.get_world_counts()
            panel_root = Entity(
                parent=self.world_root,
                name="DebugWorldPanel",
                model="quad",
                scale=(10.5, 4.8, 1.0),
                position=(target[0], target[1] + max(10.0, radius * 0.55), target[2]),
                billboard=True,
                color=color.rgba(22, 26, 32, 220),
                double_sided=True,
            )
            Text(
                world_parent=panel_root,
                text=(
                    f"seed {self.config.seed}\n"
                    f"chunks {len(self.state.chunks)}\n"
                    f"solid {solid_tiles}\n"
                    f"water {water_tiles}\n"
                    f"struct {structures}\n"
                    f"coll {self.state.collision_parts}"
                ),
                origin=(0, 0),
                scale=26,
                color=color.azure,
                y=0.17,
                z=-0.01,
            )

    def print_summary(self) -> None:
        solid_tiles, water_tiles, structures = self.get_world_counts()

        print("World generated")
        print(f"  seed: {self.config.seed}")
        print(f"  biome: {self.config.biome}")
        print(f"  chunk_count: {len(self.state.chunks)}")
        print(f"  solid_tiles: {solid_tiles}")
        print(f"  water_tiles: {water_tiles}")
        print(f"  structures: {structures}")
        print(f"  collision_parts: {self.state.collision_parts}")


def default_seed() -> int:
    stamp = int(time.time() * 1000)
    fallback = abs(stamp % 2147483647)
    return max(1, fallback)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="3D world generation preview for capstone world system")
    parser.add_argument("--renderer", choices=["ursina", "matplotlib"], default="ursina", help="3D renderer backend")

    parser.add_argument("--seed", type=int, default=default_seed(), help="World seed")
    parser.add_argument("--tile-size", type=float, default=DEFAULT_CONFIG.tile_size, help="WorldConfig.TileSize")
    parser.add_argument("--chunk-size", type=int, default=DEFAULT_CONFIG.chunk_size, help="WorldConfig.ChunkSize")
    parser.add_argument("--radius-tiles", type=int, default=DEFAULT_CONFIG.radius_tiles, help="WorldConfig.RadiusTiles")
    parser.add_argument("--base-y", type=int, default=DEFAULT_CONFIG.base_y, help="WorldConfig.BaseY")
    parser.add_argument("--biome", type=str, default=DEFAULT_CONFIG.biome, help="WorldConfig.Biome")
    parser.add_argument("--sea-level", type=int, default=DEFAULT_CONFIG.sea_level, help="WorldConfig.SeaLevel")
    parser.add_argument("--ocean-mode", type=str, default=DEFAULT_CONFIG.ocean_mode, help="WorldConfig.OceanMode")

    parser.add_argument("--show-collision", action="store_true", help="Render baked collision prisms")
    parser.add_argument("--collision-alpha", type=float, default=0.35, help="Collision prism transparency")
    parser.add_argument("--center-world-on-base-y", action="store_true", default=True, help="Shift base_y down to y=0")
    parser.add_argument("--no-center-world-on-base-y", action="store_false", dest="center_world_on_base_y", help="Keep Luau world Y coordinates as-is")
    parser.add_argument("--y-offset", type=float, default=0.0, help="Extra Y shift after centering")
    parser.add_argument("--debug-marker", action="store_true", default=True, help="Show a bright 3D origin marker")
    parser.add_argument("--no-debug-marker", action="store_false", dest="debug_marker", help="Hide origin debug marker")
    parser.add_argument("--debug-world-panel", action="store_true", default=True, help="Show in-world stats billboard")
    parser.add_argument("--no-debug-world-panel", action="store_false", dest="debug_world_panel", help="Hide in-world stats billboard")

    tuning_defaults = GenerationTuning()
    tuning_types = get_type_hints(GenerationTuning)
    for field in dataclasses.fields(GenerationTuning):
        arg_name = "--" + field.name.replace("_", "-")
        parser.add_argument(
            arg_name,
            type=tuning_types.get(field.name, float),
            default=getattr(tuning_defaults, field.name),
            help=f"Generation tuning: {field.name}",
        )

    return parser.parse_args()


def build_runtime_from_args(args: argparse.Namespace) -> WorldPreviewRuntime:
    config = WorldConfig(
        seed=max(1, int(args.seed)),
        tile_size=float(args.tile_size),
        chunk_size=max(1, int(args.chunk_size)),
        radius_tiles=max(1, int(args.radius_tiles)),
        base_y=int(args.base_y),
        biome=str(args.biome),
        sea_level=int(args.sea_level),
        ocean_mode=str(args.ocean_mode),
    )

    tuning_kwargs = {
        field.name: getattr(args, field.name)
        for field in dataclasses.fields(GenerationTuning)
    }
    tuning = GenerationTuning(**tuning_kwargs)

    render_options = RenderOptions(
        center_world_on_base_y=bool(args.center_world_on_base_y),
        y_offset=float(args.y_offset),
        show_collision=bool(args.show_collision),
        collision_alpha=clamp(float(args.collision_alpha), 0.0, 1.0),
        debug_marker=bool(args.debug_marker),
        debug_world_panel=bool(args.debug_world_panel),
    )

    return WorldPreviewRuntime(config, tuning, render_options)


def run_preview(runtime: WorldPreviewRuntime) -> None:
    try:
        from ursina import AmbientLight, DirectionalLight, Entity, Text, Ursina, Vec3, color, window
        from ursina.prefabs.editor_camera import EditorCamera
        from ursina.shaders import unlit_shader
    except Exception as exc:
        raise SystemExit(
            "Missing dependency: ursina. Install with `pip install ursina` and rerun."
        ) from exc

    app = Ursina(
        title="Capstone World Preview",
        icon="",
        borderless=False,
        show_ursina_splash=False,
        development_mode=False,
    )
    window.color = color.rgb(16, 21, 28)

    runtime.build_scene()
    runtime.print_summary()

    cam = EditorCamera(enabled=True)
    AmbientLight(color=color.rgba(180, 180, 200, 255))
    sun = DirectionalLight(color=color.rgba(255, 250, 235, 255))
    sun.look_at(Vec3(1.0, -1.4, -0.8))

    # Force world geometry to unlit shading and a simple texture so driver/shader
    # differences don't collapse colors to white.
    def iter_entity_tree(root):
        stack = list(getattr(root, "children", []))
        while stack:
            node = stack.pop()
            yield node
            stack.extend(getattr(node, "children", []))

    if runtime.world_root is not None:
        for descendant in iter_entity_tree(runtime.world_root):
            if getattr(descendant, "model", None):
                descendant.shader = unlit_shader
                descendant.texture = "white_cube"

    def frame_camera() -> None:
        target, radius = runtime.get_focus_target_and_radius()
        cam.position = (
            target[0],
            target[1] + max(18.0, radius * 0.8),
            target[2] - max(26.0, radius * 2.2),
        )
        cam.look_at(Vec3(target[0], target[1], target[2]))

    frame_camera()

    Text(
        text=(
            "R: regenerate same seed | N: next seed | F: refocus camera\n"
            "RMB+Mouse look, WASD move, Q/E vertical\n"
            "Look for yellow origin beacon + floating stats panel"
        ),
        position=(-0.85, 0.45),
        scale=0.9,
        color=color.azure,
    )

    stats_text = Text(
        text="",
        position=(-0.85, 0.39),
        scale=0.9,
        color=color.light_gray,
    )
    heartbeat_text = Text(
        text="",
        position=(-0.85, 0.33),
        scale=0.85,
        color=color.lime,
    )

    def update_stats() -> None:
        state = runtime.state
        solid_tiles = sum(1 for col in state.columns.values() if col.solid)
        water_tiles = sum(1 for col in state.columns.values() if col.solid and col.has_water)
        stats_text.text = (
            f"seed={runtime.config.seed}  chunks={len(state.chunks)}  "
            f"solid={solid_tiles}  water={water_tiles}  collision={state.collision_parts}"
        )

    update_stats()

    def handle_regenerate(next_seed: bool) -> None:
        seed = runtime.config.seed + 1 if next_seed else runtime.config.seed
        runtime.regenerate(seed)
        runtime.build_scene()
        update_stats()
        frame_camera()

    class HotkeyController(Entity):
        def __init__(self):
            super().__init__()
            self._started_at = time.time()

        def update(self):
            elapsed = time.time() - self._started_at
            heartbeat_text.text = f"runtime: {elapsed:0.1f}s"

        def input(self, key: str) -> None:
            if key == "r":
                handle_regenerate(next_seed=False)
            elif key == "n":
                handle_regenerate(next_seed=True)
            elif key == "f":
                frame_camera()

    HotkeyController()
    app.run()


def run_preview_matplotlib(runtime: WorldPreviewRuntime) -> None:
    try:
        import matplotlib.pyplot as plt
        from mpl_toolkits.mplot3d import Axes3D  # noqa: F401
    except Exception as exc:
        raise SystemExit(
            "Missing dependency: matplotlib. Install with `pip install matplotlib` and rerun."
        ) from exc

    fig = plt.figure("Capstone World Preview (matplotlib)")
    ax = fig.add_subplot(111, projection="3d")

    def draw_world() -> None:
        ax.cla()
        y_shift = runtime._render_y_shift()
        tile_size = runtime.config.tile_size
        half = tile_size * 0.5

        fill_x = []
        fill_y = []
        fill_z = []
        fill_dx = []
        fill_dy = []
        fill_dz = []
        fill_colors = []

        top_x = []
        top_y = []
        top_z = []
        top_dx = []
        top_dy = []
        top_dz = []
        top_colors = []

        for column in runtime.state.columns.values():
            if not column.solid:
                continue

            x0 = (column.x * tile_size) - half
            y0 = (column.z * tile_size) - half
            fill_h = max(1.0, float(column.surface_y - column.bottom_y))

            fill_x.append(x0)
            fill_y.append(y0)
            fill_z.append(float(column.bottom_y) + y_shift)
            fill_dx.append(tile_size)
            fill_dy.append(tile_size)
            fill_dz.append(fill_h)
            fill_rgb = MATERIAL_RGB.get(column.fill_material, (118, 108, 95))
            fill_colors.append((fill_rgb[0] / 255.0, fill_rgb[1] / 255.0, fill_rgb[2] / 255.0, 1.0))

            top_x.append(x0)
            top_y.append(y0)
            top_z.append(float(column.surface_y) + y_shift)
            top_dx.append(tile_size)
            top_dy.append(tile_size)
            top_dz.append(1.0)
            top_rgb = MATERIAL_RGB.get(column.surface_material, (87, 130, 74))
            top_colors.append((top_rgb[0] / 255.0, top_rgb[1] / 255.0, top_rgb[2] / 255.0, 1.0))

        if fill_x:
            ax.bar3d(fill_x, fill_y, fill_z, fill_dx, fill_dy, fill_dz, color=fill_colors, shade=True, zsort="average")
        if top_x:
            ax.bar3d(top_x, top_y, top_z, top_dx, top_dy, top_dz, color=top_colors, shade=True, zsort="average")

        target, radius = runtime.get_focus_target_and_radius()
        solid_tiles, water_tiles, structures = runtime.get_world_counts()

        ax.scatter([0.0], [0.0], [y_shift + 14.0], c=[(1.0, 0.84, 0.0)], s=[180], depthshade=False)

        ax.set_title(
            "Capstone World Preview (matplotlib)\n"
            "Mouse drag: rotate | Scroll: zoom | R: regenerate | N: next seed\n"
            f"seed={runtime.config.seed} chunks={len(runtime.state.chunks)} solid={solid_tiles} "
            f"water={water_tiles} struct={structures} coll={runtime.state.collision_parts}"
        )
        ax.set_xlabel("X")
        ax.set_ylabel("Z")
        ax.set_zlabel("Y")
        ax.set_facecolor((0.06, 0.08, 0.11))

        ax.set_xlim(target[0] - radius * 1.35, target[0] + radius * 1.35)
        ax.set_ylim(target[2] - radius * 1.35, target[2] + radius * 1.35)
        ax.set_zlim(target[1] - radius * 0.8, target[1] + radius * 1.1)
        ax.view_init(elev=28, azim=-52)

        fig.canvas.draw_idle()

    def on_key(event) -> None:
        if event.key == "r":
            runtime.regenerate(runtime.config.seed)
            draw_world()
        elif event.key == "n":
            runtime.regenerate(runtime.config.seed + 1)
            draw_world()

    fig.canvas.mpl_connect("key_press_event", on_key)
    draw_world()
    plt.show()


def main() -> None:
    args = parse_args()
    runtime = build_runtime_from_args(args)
    if args.renderer == "matplotlib":
        run_preview_matplotlib(runtime)
    else:
        run_preview(runtime)


if __name__ == "__main__":
    main()
