--!strict

type TileColumn = any
type WorldConfig = any

return function(ctx, columns, config: WorldConfig, seed: number)
	local smoothstep = ctx.smoothstep
	local snapHeight = ctx.snapHeight
	local TerrainTuning = ctx.TerrainTuning

	local coarseNoiseX = (seed % 3203) * 0.17
	local coarseNoiseZ = (seed % 5107) * 0.13
	local ridgeNoiseX = (seed % 8087) * 0.09
	local ridgeNoiseZ = (seed % 7129) * 0.08
	local peakNoiseX = (seed % 6211) * 0.11
	local peakNoiseZ = (seed % 7481) * 0.1

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		local radialDistance = math.sqrt(column.X * column.X + column.Z * column.Z)
		local distance01 = math.clamp(radialDistance / math.max(1, config.RadiusTiles), 0, 1)
		local innerMass = 1 - smoothstep(0.42, 1.0, distance01)
		local coarseNoise =
			math.noise((column.X + coarseNoiseX) * 0.04, (column.Z + coarseNoiseZ) * 0.04, seed * 0.0007)
		local ridgeNoise = 1
			- math.abs(
				math.noise((column.X + ridgeNoiseX) * 0.03, (column.Z + ridgeNoiseZ) * 0.03, seed * 0.0016)
			)
		local peakNoise =
			math.noise((column.X + peakNoiseX) * 0.07, (column.Z + peakNoiseZ) * 0.07, seed * 0.0022)
		local ridgeStrength = math.clamp((ridgeNoise + 0.15) * 0.95, 0, 1) ^ 2
		local peakStrength = math.clamp((peakNoise + 1) * 0.5, 0, 1) ^ 2
		local peakLift = innerMass
			* (
				TerrainTuning.MountainBaseHeight * 1.9
				+ ridgeStrength * (TerrainTuning.MountainPeakBase * 2.1 + TerrainTuning.MountainPeakScale * 2.8)
				+ peakStrength * 22
			)
		local edgeDampenT = smoothstep(TerrainTuning.EdgeDampenStart, TerrainTuning.EdgeDampenEnd, distance01)
		local height = config.BaseY + 22 + coarseNoise * 12 + peakLift
		if edgeDampenT > 0 then
			local edgeAlpha = edgeDampenT ^ TerrainTuning.EdgeDampenCurve
			local edgeTarget = config.BaseY + TerrainTuning.EdgeDampenHeightOffset
			height = height * (1 - edgeAlpha) + edgeTarget * edgeAlpha
		end

		column.SurfaceY = snapHeight(height)
	end
end
