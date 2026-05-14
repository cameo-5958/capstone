--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local TentTemplate = ReplicatedStorage:WaitForChild("Database"):WaitForChild("PrefabModels"):WaitForChild("Tent")

local Definition = {
	Id = "Shared::SpawnCampScene",
	Name = "SpawnCampScene",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(110, 96),
	HeightStuds = 34,
}

local function findTopmostPart(model: Model, excludedPart: BasePart?): BasePart?
	local bestPart: BasePart? = nil
	local bestY = -math.huge

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= excludedPart then
			local positionY = descendant.Position.Y
			if positionY > bestY then
				bestY = positionY
				bestPart = descendant
			end
		end
	end

	return bestPart
end

local function normalizeTentParts(tentModel: Model)
	for _, descendant in ipairs(tentModel:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end
end

local function addTent(model: Model, pivot: CFrame, name: string, offset: Vector3, yawDegrees: number)
	local tentClone = TentTemplate:Clone()
	if not tentClone:IsA("Model") then
		tentClone:Destroy()
		return
	end

	tentClone.Name = name
	tentClone.Parent = model
	normalizeTentParts(tentClone)
	tentClone:ScaleTo(3)

	local basePart = tentClone:FindFirstChild("Base")
	if not basePart or not basePart:IsA("BasePart") then
		return
	end

	local capPart = findTopmostPart(tentClone, basePart)
	if not capPart then
		return
	end

	local baseOffsetFromCap = capPart.CFrame:ToObjectSpace(basePart.CFrame)
	basePart.CFrame = capPart.CFrame
	tentClone.PrimaryPart = basePart

	local desiredBaseCFrame =
		pivot * CFrame.new(offset) * CFrame.Angles(0, math.rad(90 + yawDegrees), 0)
	local desiredCapCFrame = desiredBaseCFrame * baseOffsetFromCap:Inverse()
	tentClone:PivotTo(desiredCapCFrame)

	tentClone.PrimaryPart = nil
	basePart:Destroy()
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(
		model,
		"CampfireRingNorth",
		pivot * CFrame.new(0, 1.1, -1.8),
		Vector3.new(4.6, 0.8, 0.8),
		Enum.Material.Rock,
		Color3.fromRGB(111, 108, 102),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"CampfireRingSouth",
		pivot * CFrame.new(0, 1.1, 1.8),
		Vector3.new(4.6, 0.8, 0.8),
		Enum.Material.Rock,
		Color3.fromRGB(111, 108, 102),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"CampfireRingWest",
		pivot * CFrame.new(-1.8, 1.1, 0),
		Vector3.new(0.8, 0.8, 3),
		Enum.Material.Rock,
		Color3.fromRGB(111, 108, 102),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"CampfireRingEast",
		pivot * CFrame.new(1.8, 1.1, 0),
		Vector3.new(0.8, 0.8, 3),
		Enum.Material.Rock,
		Color3.fromRGB(111, 108, 102),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"CampfireEmbers",
		pivot * CFrame.new(0, 1.05, 0),
		Vector3.new(2.3, 0.6, 2.3),
		Enum.Material.Neon,
		Color3.fromRGB(255, 167, 74),
		0.15,
		nil
	)
	PrefabUtils.addPart(
		model,
		"CampfireLogsA",
		pivot * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(35), math.rad(8)),
		Vector3.new(0.7, 0.7, 3.4),
		Enum.Material.Wood,
		Color3.fromRGB(104, 77, 55),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"CampfireLogsB",
		pivot * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(-35), math.rad(-8)),
		Vector3.new(0.7, 0.7, 3.4),
		Enum.Material.Wood,
		Color3.fromRGB(104, 77, 55),
		0,
		nil
	)

	addTent(model, pivot, "TentNorthWest", Vector3.new(-26, 0, -20), 28)
	addTent(model, pivot, "TentNorthEast", Vector3.new(27, 0, -18), -24)
	addTent(model, pivot, "TentSouth", Vector3.new(0, 0, 28), 180)

	PrefabUtils.addPart(
		model,
		"SleepingBagBase",
		pivot * CFrame.new(-12, 0.55, 14) * CFrame.Angles(0, math.rad(18), 0),
		Vector3.new(4.2, 0.6, 2),
		Enum.Material.Fabric,
		Color3.fromRGB(92, 118, 122),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"SleepingBagRoll",
		pivot * CFrame.new(-13.7, 0.9, 14.6) * CFrame.Angles(0, math.rad(18), math.rad(90)),
		Vector3.new(0.9, 0.9, 1.8),
		Enum.Material.Fabric,
		Color3.fromRGB(73, 95, 99),
		0,
		"Cylinder"
	)

	PrefabUtils.addPart(
		model,
		"SeatLogWest",
		pivot * CFrame.new(-7, 1.15, -1) * CFrame.Angles(0, math.rad(82), math.rad(90)),
		Vector3.new(1, 1, 4.8),
		Enum.Material.Wood,
		Color3.fromRGB(100, 74, 53),
		0,
		"Cylinder"
	)
	PrefabUtils.addPart(
		model,
		"SeatLogEast",
		pivot * CFrame.new(7.2, 1.15, 0.8) * CFrame.Angles(0, math.rad(-78), math.rad(90)),
		Vector3.new(1, 1, 4.4),
		Enum.Material.Wood,
		Color3.fromRGB(100, 74, 53),
		0,
		"Cylinder"
	)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
