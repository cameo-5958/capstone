--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns: TileColumn, config: WorldConfig, seed: number)
	local smoothstep = ctx.smoothstep
	local snapHeight = ctx.snapHeight
	local angularDistance = ctx.angularDistance
	local TerrainTuning = ctx.TerrainTuning

	local heightNoiseX = (seed % 1787) * 0.19
	local heightNoiseZ = (seed % 2677) * 0.11
	local mountainNoiseX = (seed % 8087) * 0.09
	local mountainNoiseZ = (seed % 7129) * 0.08
	local canyonNoiseX = (seed % 6211) * 0.12
	local canyonNoiseZ = (seed % 7481) * 0.1
	local pathNoiseX = (seed % 9151) * 0.06
	local pathNoiseZ = (seed % 8399) * 0.05
	local branchBaseAngle = ((seed % 360) / 180) * math.pi
	local branchAngles = {
		branchBaseAngle,
		branchBaseAngle + (math.pi * 2 / 3),
		branchBaseAngle + (math.pi * 4 / 3),
	}

	for _, column in pairs(columns) do
		if not column.Solid then
			continue
		end

		local radialDistance = math.sqrt(column.X * column.X + column.Z * column.Z)
		local distance01 = math.clamp(radialDistance / config.RadiusTiles, 0, 1)
		local angle = math.atan2(column.Z, column.X)
		local coarseNoise = math.noise((column.X + heightNoiseX) * 0.045, (column.Z + heightNoiseZ) * 0.045, seed * 0.0007)
		local fineNoise = math.noise((column.X - heightNoiseZ) * 0.09, (column.Z + heightNoiseX) * 0.09, seed * 0.0011)
		local mountainNoise =
			math.noise((column.X + mountainNoiseX) * 0.035, (column.Z + mountainNoiseZ) * 0.035, seed * 0.0019)
		local peakMask = math.clamp((mountainNoise + 0.1) * 0.9, 0, 1)
		local mountainRing: number =
			smoothstep(TerrainTuning.MountainRingStart, TerrainTuning.MountainRingEnd, distance01)
		local mountainBase = mountainRing * TerrainTuning.MountainBaseHeight
		local peakBoost = (peakMask ^ 2)
			* (TerrainTuning.MountainPeakBase + mountainRing * TerrainTuning.MountainPeakScale)
		local mountainHeight = config.BaseY + mountainBase + coarseNoise * 5 + fineNoise * 0.75 + peakBoost

		local canyonNoise =
			math.abs(math.noise((column.X + canyonNoiseX) * 0.035, (column.Z + canyonNoiseZ) * 0.035, seed * 0.0016))
		local noiseCanyon = 1 - smoothstep(TerrainTuning.CanyonNoiseLow, TerrainTuning.CanyonNoiseHigh, canyonNoise)
		local spokeCanyon = 0
		local spokeWidth = TerrainTuning.CanyonSpokeBaseWidth + distance01 * TerrainTuning.CanyonSpokeScaleWidth
		for _, spokeAngle in ipairs(branchAngles) do
			local diff = angularDistance(angle, spokeAngle)
			local spokeMask = 1 - smoothstep(spokeWidth * 0.45, spokeWidth, diff)
			if spokeMask > spokeCanyon then
				spokeCanyon = spokeMask
			end
		end
		local canyonMask = math.max(noiseCanyon * 0.75, spokeCanyon)
		local canyonFloorNoise =
			math.noise((column.X + pathNoiseX) * 0.025, (column.Z + pathNoiseZ) * 0.025, seed * 0.0021)
		local canyonHeight = config.BaseY
			+ (1 - distance01) * TerrainTuning.CanyonFloorCenterLift
			+ canyonFloorNoise * TerrainTuning.CanyonFloorNoiseAmplitude
		local canyonBlend = math.clamp(canyonMask, 0, 1)
		local wallLift = (1 - canyonBlend) ^ 1.6 * TerrainTuning.MountainWallLift * mountainRing
		local blendedHeight = mountainHeight * (1 - canyonBlend) + canyonHeight * canyonBlend + wallLift
		local edgeDampenT = smoothstep(TerrainTuning.EdgeDampenStart, TerrainTuning.EdgeDampenEnd, distance01)
		if edgeDampenT > 0 then
			local edgeAlpha = edgeDampenT ^ TerrainTuning.EdgeDampenCurve
			local edgeTarget = config.BaseY + TerrainTuning.EdgeDampenHeightOffset
			blendedHeight = blendedHeight * (1 - edgeAlpha) + edgeTarget * edgeAlpha
		end
		local elevation = snapHeight(blendedHeight)
		column.SurfaceY = elevation
	end
end
