--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::CliffWatchHouse",
	Name = "CliffWatchHouse",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(20, 20),
	HeightStuds = 24,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(
		model,
		"StoneFooting",
		pivot * CFrame.new(0, 1, 0),
		Vector3.new(16, 2, 16),
		Enum.Material.Slate,
		Color3.fromRGB(104, 107, 117),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"FloorLower",
		pivot * CFrame.new(0, 2.5, 0),
		Vector3.new(12, 1, 12),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(114, 84, 60),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"FloorUpper",
		pivot * CFrame.new(0, 11.5, 0),
		Vector3.new(10, 1, 10),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(110, 80, 57),
		0,
		nil
	)

	PrefabUtils.addPart(
		model,
		"LowerNorth",
		pivot * CFrame.new(0, 6.5, -5.5),
		Vector3.new(12, 8, 1),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(150, 115, 85),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"LowerSouth",
		pivot * CFrame.new(0, 6.5, 5.5),
		Vector3.new(12, 8, 1),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(150, 115, 85),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"LowerWest",
		pivot * CFrame.new(-5.5, 6.5, 0),
		Vector3.new(1, 8, 10),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(150, 115, 85),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"LowerEast",
		pivot * CFrame.new(5.5, 6.5, 0),
		Vector3.new(1, 8, 10),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(150, 115, 85),
		0,
		nil
	)

	PrefabUtils.addPart(
		model,
		"UpperNorth",
		pivot * CFrame.new(0, 15.5, -4.5),
		Vector3.new(10, 6, 1),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(161, 126, 96),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"UpperSouth",
		pivot * CFrame.new(0, 15.5, 4.5),
		Vector3.new(10, 6, 1),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(161, 126, 96),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"UpperWest",
		pivot * CFrame.new(-4.5, 15.5, 0),
		Vector3.new(1, 6, 8),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(161, 126, 96),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"UpperEast",
		pivot * CFrame.new(4.5, 15.5, 0),
		Vector3.new(1, 6, 8),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(161, 126, 96),
		0,
		nil
	)

	PrefabUtils.addPart(
		model,
		"RoofBase",
		pivot * CFrame.new(0, 19.5, 0),
		Vector3.new(12, 2, 12),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(107, 78, 55),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"RoofTop",
		pivot * CFrame.new(0, 21.5, 0),
		Vector3.new(8, 2, 8),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(98, 71, 50),
		0,
		nil
	)

	PrefabUtils.addPart(
		model,
		"StairLower",
		pivot * CFrame.new(0, 3, 6.7),
		Vector3.new(4, 1, 2),
		Enum.Material.Wood,
		Color3.fromRGB(101, 74, 53),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"StairUpper",
		pivot * CFrame.new(0, 4, 5.7),
		Vector3.new(4, 1, 2),
		Enum.Material.Wood,
		Color3.fromRGB(101, 74, 53),
		0,
		nil
	)
	PrefabUtils.addPart(
		model,
		"Door",
		pivot * CFrame.new(0, 5.5, 5.6),
		Vector3.new(3, 5, 1),
		Enum.Material.WoodPlanks,
		Color3.fromRGB(94, 68, 49),
		0,
		nil
	)

	PrefabUtils.addPart(
		model,
		"WindowUpper",
		pivot * CFrame.new(0, 15.8, -4.6),
		Vector3.new(3, 3, 1),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(191, 216, 235),
		0.2,
		nil
	)
	PrefabUtils.addPart(
		model,
		"WindowSide",
		pivot * CFrame.new(4.6, 15.8, 0),
		Vector3.new(1, 3, 3),
		Enum.Material.SmoothPlastic,
		Color3.fromRGB(191, 216, 235),
		0.2,
		nil
	)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
