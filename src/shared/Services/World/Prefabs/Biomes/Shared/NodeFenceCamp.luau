--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::NodeFenceCamp",
	Name = "NodeFenceCamp",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(22, 22),
	HeightStuds = 10,
}

local function addFenceLine(model: Model, name: string, cframe: CFrame, size: Vector3)
	PrefabUtils.addPart(model, name .. "_Rail", cframe * CFrame.new(0, 2.2, 0), size, Enum.Material.Wood, Color3.fromRGB(98, 72, 51), 0, nil)
	PrefabUtils.addPart(model, name .. "_PostA", cframe * CFrame.new(-size.X * 0.5 + 0.5, 2.3, 0), Vector3.new(1, 4, 1), Enum.Material.Wood, Color3.fromRGB(91, 66, 47), 0, nil)
	PrefabUtils.addPart(model, name .. "_PostB", cframe * CFrame.new(size.X * 0.5 - 0.5, 2.3, 0), Vector3.new(1, 4, 1), Enum.Material.Wood, Color3.fromRGB(91, 66, 47), 0, nil)
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "GroundPad", pivot * CFrame.new(0, 1, 0), Vector3.new(18, 2, 18), Enum.Material.Ground, Color3.fromRGB(112, 98, 78), 0, nil)

	addFenceLine(model, "North", pivot * CFrame.new(0, 0, -8), Vector3.new(16, 1, 1))
	addFenceLine(model, "SouthLeft", pivot * CFrame.new(-5, 0, 8), Vector3.new(6, 1, 1))
	addFenceLine(model, "SouthRight", pivot * CFrame.new(5, 0, 8), Vector3.new(6, 1, 1))
	addFenceLine(model, "West", pivot * CFrame.new(-8, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(16, 1, 1))
	addFenceLine(model, "East", pivot * CFrame.new(8, 0, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(16, 1, 1))

	PrefabUtils.addPart(model, "CampfireRing", pivot * CFrame.new(0, 1.3, 0), Vector3.new(4, 1, 4), Enum.Material.Rock, Color3.fromRGB(112, 111, 118), 0, nil)
	PrefabUtils.addPart(model, "CampfireGlow", pivot * CFrame.new(0, 2.1, 0), Vector3.new(2, 1, 2), Enum.Material.Neon, Color3.fromRGB(255, 156, 84), 0.2, nil)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
