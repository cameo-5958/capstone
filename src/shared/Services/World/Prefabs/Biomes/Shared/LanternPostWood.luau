--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::LanternPostWood",
	Name = "LanternPostWood",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = false,
	FootprintStuds = Vector2.new(8, 8),
	HeightStuds = 16,
}

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "StoneBase", pivot * CFrame.new(0, 1, 0), Vector3.new(4, 2, 4), Enum.Material.Slate, Color3.fromRGB(108, 109, 118), 0, nil)
	PrefabUtils.addPart(model, "Post", pivot * CFrame.new(0, 6, 0), Vector3.new(1, 10, 1), Enum.Material.Wood, Color3.fromRGB(89, 63, 44), 0, nil)
	PrefabUtils.addPart(model, "CrossArm", pivot * CFrame.new(1.5, 12, 0), Vector3.new(4, 1, 1), Enum.Material.Wood, Color3.fromRGB(89, 63, 44), 0, nil)
	PrefabUtils.addPart(model, "Hanger", pivot * CFrame.new(3, 10.5, 0), Vector3.new(1, 2, 1), Enum.Material.Metal, Color3.fromRGB(77, 77, 84), 0, nil)

	PrefabUtils.addPart(model, "LanternBody", pivot * CFrame.new(3, 8.5, 0), Vector3.new(2, 3, 2), Enum.Material.Neon, Color3.fromRGB(255, 220, 142), 0.12, nil)
	PrefabUtils.addPart(model, "LanternCap", pivot * CFrame.new(3, 10.5, 0), Vector3.new(2, 1, 2), Enum.Material.Metal, Color3.fromRGB(77, 77, 84), 0, nil)
	PrefabUtils.addPart(model, "LanternBase", pivot * CFrame.new(3, 6.5, 0), Vector3.new(2, 1, 2), Enum.Material.Metal, Color3.fromRGB(77, 77, 84), 0, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
