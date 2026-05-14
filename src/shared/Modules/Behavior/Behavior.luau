--!strict

-- Set of helpers that will assist
-- in the creation of Neurons and Brains for Enemy AI

local Behavior = {}

-- Raycast for Enemy Vision
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = { workspace:WaitForChild("EntitiesFolder") }
raycastParams.RespectCanCollide = true
function Behavior.Raycast(
	origin: Vector3,
	direction: Vector3,
	range: number,
	excludeList: { Instance }?
): RaycastResult?
	-- Ignore only if necessary
	if excludeList then
		raycastParams.FilterDescendantsInstances = excludeList
	end

	local raycastResult = workspace:Raycast(origin, direction.Unit * range, raycastParams)
	return raycastResult
end

function Behavior.HitPlayer(enemy: Model, player: Model, range: number): boolean
	-- Grab player position
	local pos = (enemy.PrimaryPart :: Part).Position
	local playerPos = (player.PrimaryPart :: Part).Position

	-- Raycast here
	local result = Behavior.Raycast(pos, playerPos - pos, range)

	if not result then
		return false
	end

	return result.Instance:IsDescendantOf(player)
end

function Behavior.Distance(enemy: Model, player: Model): number
	-- Grab player position
	local pos = (enemy.PrimaryPart :: Part).Position
	local playerPos = (player.PrimaryPart :: Part).Position

	return (pos - playerPos).Magnitude
end

return table.freeze(Behavior)
