# Path Carving Research

This note tracks the path-carving approach used by `PathSieve` so future tuning has a stable reference point.

## Sources

- Houdini heightfield road workflow: sample or smooth a road curve height, then blend that height back into the heightfield through a distance-based mask. This is the main model for separating path intent from terrain mutation. Source: https://procegen.konstantinmagnus.de/projecting-a-road-curve-onto-a-heightfield
- Unity Smooth Height guidance: heightmap smoothing is useful after edits that introduce high-frequency artifacts or jagged edges. The path pass uses a constrained smoothing pass only around carved path cells. Source: https://docs.unity.cn/Packages/com.unity.terrain-tools%405.0/manual/smooth-height.html
- Smoothstep and smootherstep falloffs: Hermite falloff curves avoid abrupt slope changes at mask boundaries. The path pass uses smootherstep for node and corridor edge masks. Source: https://mind-the-gab.com/noise/Smoothstep
- Signed-distance-field terrain thinking: distance-to-shape masks are a stable way to blend continuous shapes into sampled terrain without per-tile randomness. Nodes use distance-to-circle; corridors use distance-to-segment. Source: https://voxel-tools.readthedocs.io/en/latest/smooth_terrain/

## Implementation Notes

- Node target height is the 20th percentile of solid column heights inside the node carve circle.
- Carving only lowers terrain. It does not raise terrain into bridges or platforms.
- Node circles use an inner full-strength region and a smootherstep outer falloff.
- Segment corridors interpolate between neighboring node carve heights and use the same smootherstep edge falloff.
- The final smoothing pass is constrained to path-carved cells and their immediate neighbors.
- The pass intentionally avoids height noise, aggressive flattening, and global hard flattening.
