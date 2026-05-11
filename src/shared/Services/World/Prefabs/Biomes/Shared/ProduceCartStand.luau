--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::ProduceCartStand",
	Name = "ProduceCartStand",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(20, 14),
	HeightStuds = 10,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "StandPad", pivot * CFrame.new(0, 0.5, 0), Vector3.new(16, 1, 10), Enum.Material.Ground, Color3.fromRGB(115, 97, 78), 0, nil)
	PrefabUtils.addPart(model, "CartDeck", pivot * CFrame.new(-3.8, 1.8, 0), Vector3.new(8, 1.2, 5.2), Enum.Material.WoodPlanks, Color3.fromRGB(104, 76, 54), 0, nil)
	PrefabUtils.addPart(model, "CartRailNorth", pivot * CFrame.new(-3.8, 2.6, -2.2), Vector3.new(8, 0.7, 0.6), Enum.Material.Wood, Color3.fromRGB(94, 68, 49), 0, nil)
	PrefabUtils.addPart(model, "CartRailSouth", pivot * CFrame.new(-3.8, 2.6, 2.2), Vector3.new(8, 0.7, 0.6), Enum.Material.Wood, Color3.fromRGB(94, 68, 49), 0, nil)

	PrefabUtils.addPart(model, "WheelLeftFront", pivot * CFrame.new(-6.8, 1.2, -2.3), Vector3.new(1.2, 1.2, 1.2), Enum.Material.Wood, Color3.fromRGB(84, 61, 42), 0, nil)
	PrefabUtils.addPart(model, "WheelLeftRear", pivot * CFrame.new(-6.8, 1.2, 2.3), Vector3.new(1.2, 1.2, 1.2), Enum.Material.Wood, Color3.fromRGB(84, 61, 42), 0, nil)
	PrefabUtils.addPart(model, "WheelRightFront", pivot * CFrame.new(-0.8, 1.2, -2.3), Vector3.new(1.2, 1.2, 1.2), Enum.Material.Wood, Color3.fromRGB(84, 61, 42), 0, nil)
	PrefabUtils.addPart(model, "WheelRightRear", pivot * CFrame.new(-0.8, 1.2, 2.3), Vector3.new(1.2, 1.2, 1.2), Enum.Material.Wood, Color3.fromRGB(84, 61, 42), 0, nil)

	PrefabUtils.addPart(model, "StandTable", pivot * CFrame.new(4.4, 2.0, 0), Vector3.new(6.8, 1.1, 4.4), Enum.Material.WoodPlanks, Color3.fromRGB(106, 79, 56), 0, nil)
	PrefabUtils.addPart(model, "PostNorth", pivot * CFrame.new(1.8, 4.6, -1.9), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(90, 66, 47), 0, nil)
	PrefabUtils.addPart(model, "PostSouth", pivot * CFrame.new(1.8, 4.6, 1.9), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(90, 66, 47), 0, nil)
	PrefabUtils.addPart(model, "PostNorthBack", pivot * CFrame.new(7.0, 4.6, -1.9), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(90, 66, 47), 0, nil)
	PrefabUtils.addPart(model, "PostSouthBack", pivot * CFrame.new(7.0, 4.6, 1.9), Vector3.new(0.8, 5.2, 0.8), Enum.Material.Wood, Color3.fromRGB(90, 66, 47), 0, nil)
	PrefabUtils.addPart(model, "Awning", pivot * CFrame.new(4.4, 7.2, 0), Vector3.new(6.8, 0.8, 5.2), Enum.Material.Fabric, Color3.fromRGB(163, 140, 101), 0, nil)

	PrefabUtils.addPart(model, "ProduceCrateA", pivot * CFrame.new(3.0, 2.8, -1.2), Vector3.new(1.8, 1.4, 1.8), Enum.Material.WoodPlanks, Color3.fromRGB(101, 75, 53), 0, nil)
	PrefabUtils.addPart(model, "ProduceCrateB", pivot * CFrame.new(5.7, 2.8, 1.1), Vector3.new(1.8, 1.4, 1.8), Enum.Material.WoodPlanks, Color3.fromRGB(101, 75, 53), 0, nil)
	PrefabUtils.addPart(model, "ProducePileA", pivot * CFrame.new(3.0, 3.5, -1.2), Vector3.new(1.4, 0.8, 1.4), Enum.Material.Grass, Color3.fromRGB(120, 156, 86), 0, nil)
	PrefabUtils.addPart(model, "ProducePileB", pivot * CFrame.new(5.7, 3.5, 1.1), Vector3.new(1.4, 0.8, 1.4), Enum.Material.Grass, Color3.fromRGB(178, 132, 68), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
