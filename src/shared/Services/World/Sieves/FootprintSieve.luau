--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local rotate2D = ctx.rotate2D

		local radius = math.max(config.RadiusTiles, 1)
		local angle = ((seed % 360) / 180) * math.pi
		local cosAngle = math.cos(angle)
		local sinAngle = math.sin(angle)
	
		local macroNoiseX = (seed % 1877) * 0.13
		local macroNoiseZ = (seed % 3251) * 0.11
		local detailNoiseX = (seed % 5623) * 0.07
		local detailNoiseZ = (seed % 4447) * 0.09
		local warpNoiseX = (seed % 7333) * 0.09
		local warpNoiseZ = (seed % 8971) * 0.08
		local coveNoiseX = (seed % 2687) * 0.15
		local coveNoiseZ = (seed % 3529) * 0.12
		local lobePhaseA = (seed % 360) * (math.pi / 180)
		local lobePhaseB = ((seed * 7) % 360) * (math.pi / 180)
		local lobePhaseC = ((seed * 13) % 360) * (math.pi / 180)
		local processedCount = 0
	
		for _, column in pairs(columns) do
			processedCount += 1
			if processedCount % 5000 == 0 then
				task.wait()
			end
	
			local rx, rz = rotate2D(column.X, column.Z, cosAngle, sinAngle)
			local nx = rx / radius
			local nz = rz / radius
	
			local radial = math.sqrt(nx * nx + nz * nz)
			if radial <= 0.2 then
				column.Solid = true
				continue
			end
	
			if radial >= 1.45 then
				column.Solid = false
				continue
			end
	
			local warpPrimary = math.noise((rx + warpNoiseX) * 0.065, (rz + warpNoiseZ) * 0.065, seed * 0.00037)
			local warpSecondary = math.noise((rx - warpNoiseZ) * 0.12, (rz + warpNoiseX) * 0.12, seed * 0.00073)
			local warpScale = 0.16 + math.max(0, radial - 0.38) * 0.2
			local warpedX = nx + warpPrimary * warpScale + warpSecondary * 0.08
			local warpedZ = nz + warpSecondary * warpScale - warpPrimary * 0.08
			local warpedRadius = math.sqrt(warpedX * warpedX + warpedZ * warpedZ)
			local warpedAngle = math.atan2(warpedZ, warpedX)
	
			local lobeA = math.sin(warpedAngle * 2.3 + lobePhaseA) * 0.16
			local lobeB = math.sin(warpedAngle * 4.9 + lobePhaseB) * 0.09
			local lobeC = math.sin(warpedAngle * 7.1 + lobePhaseC) * 0.05
			local macroNoise = math.noise((warpedX + macroNoiseX) * 1.28, (warpedZ + macroNoiseZ) * 1.28, seed * 0.00057)
				* 0.14
			local detailNoise = math.noise((warpedX - detailNoiseX) * 2.55, (warpedZ + detailNoiseZ) * 2.55, seed * 0.00101)
				* 0.06
			local coastline = math.clamp(0.93 + lobeA + lobeB + lobeC + macroNoise + detailNoise, 0.62, 1.36)
			local isSolid = warpedRadius <= coastline
	
			if isSolid and radial > 0.62 then
				local coveNoise = math.noise((warpedX + coveNoiseX) * 3.2, (warpedZ + coveNoiseZ) * 3.2, seed * 0.00183)
				local coveThreshold = 0.93 - math.clamp((radial - 0.62) / 0.6, 0, 1) * 0.2
				if coveNoise > coveThreshold then
					isSolid = false
				end
			end
	
			if not isSolid and radial <= 0.34 then
				isSolid = true
			end
	
			column.Solid = isSolid
		end
end
