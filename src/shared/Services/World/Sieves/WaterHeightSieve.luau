--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

local CARDINAL_OFFSETS = {
	{ DX = 1, DZ = 0 },
	{ DX = -1, DZ = 0 },
	{ DX = 0, DZ = 1 },
	{ DX = 0, DZ = -1 },
}

local function makeColumnKey(x: number, z: number): string
	return tostring(x) .. ":" .. tostring(z)
end

return function(_ctx, columns, config, _seed)
	local defaultWaterY = config.BaseY + config.SeaLevel - 1
	local visited = {} :: { [string]: boolean }

	for key, startColumn in pairs(columns) do
		if visited[key] or not startColumn.Solid or not startColumn.HasWater then
			continue
		end

		local queue = { startColumn }
		local head = 1
		visited[key] = true
		local component = {} :: { TileColumn }
		local componentMinSurfaceY = math.huge
		local boundaryMinSurfaceY = math.huge

		while head <= #queue do
			local current = queue[head]
			head += 1
			table.insert(component, current)
			if current.SurfaceY < componentMinSurfaceY then
				componentMinSurfaceY = current.SurfaceY
			end

			for _, offset in ipairs(CARDINAL_OFFSETS) do
				local neighborKey = makeColumnKey(current.X + offset.DX, current.Z + offset.DZ)
				local neighbor = columns[neighborKey]
				if neighbor and neighbor.Solid then
					if neighbor.HasWater then
						if not visited[neighborKey] then
							visited[neighborKey] = true
							table.insert(queue, neighbor)
						end
					elseif neighbor.SurfaceY < boundaryMinSurfaceY then
						boundaryMinSurfaceY = neighbor.SurfaceY
					end
				end
			end
		end

		local targetSurfaceY = defaultWaterY
		if boundaryMinSurfaceY < math.huge then
			targetSurfaceY = math.min(targetSurfaceY, boundaryMinSurfaceY - 1)
		end
		if componentMinSurfaceY < math.huge then
			targetSurfaceY = math.min(targetSurfaceY, componentMinSurfaceY - 1)
		end

		for _, column in ipairs(component) do
			column.SurfaceY = targetSurfaceY
			local maxBottomY = targetSurfaceY - 2
			if column.BottomY > maxBottomY then
				column.BottomY = maxBottomY
			end
		end
	end
end
