--!strict

type TileColumn = any
type WorldConfig = any
type PathPoint = any
type PathRoute = any
type BiomeChunkInfo = any
type DepthAnchor = any

return function(ctx, columns, config, seed)
	local snapHeight = ctx.snapHeight

		for _, column in pairs(columns) do
			if column.Solid then
				local snappedSurfaceY = snapHeight(column.SurfaceY)
				local snappedBottomY = snapHeight(column.BottomY)
				local maxBottomY = snappedSurfaceY - 2
				if snappedBottomY > maxBottomY then
					snappedBottomY = maxBottomY
				end
				column.SurfaceY = snappedSurfaceY
				column.BottomY = snappedBottomY
			end
		end
end
