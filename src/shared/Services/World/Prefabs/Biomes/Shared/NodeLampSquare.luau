--!strict

local PrefabTypes = require(script.Parent.Parent.Parent.PrefabTypes)
local PrefabUtils = require(script.Parent.Parent.Parent.PrefabUtils)

local Definition = {
	Id = "Shared::NodeLampSquare",
	Name = "NodeLampSquare",
	Biome = "Shared",
	Category = "Structure",
	RuntimeEligible = true,
	FootprintStuds = Vector2.new(18, 18),
	HeightStuds = 14,
}

local function addLamp(model: Model, pivot: CFrame, x: number, z: number)
	PrefabUtils.addPart(model, "LampBase_" .. tostring(x) .. "_" .. tostring(z), pivot * CFrame.new(x, 1, z), Vector3.new(2, 2, 2), Enum.Material.Slate, Color3.fromRGB(104, 106, 116), 0, nil)
	PrefabUtils.addPart(model, "LampStem_" .. tostring(x) .. "_" .. tostring(z), pivot * CFrame.new(x, 5, z), Vector3.new(1, 6, 1), Enum.Material.Metal, Color3.fromRGB(75, 79, 88), 0, nil)
	PrefabUtils.addPart(model, "LampGlow_" .. tostring(x) .. "_" .. tostring(z), pivot * CFrame.new(x, 8, z), Vector3.new(2, 2, 2), Enum.Material.Neon, Color3.fromRGB(255, 218, 138), 0.18, nil)
end

local function Build(parent: Instance, context: PrefabTypes.PrefabBuildContext): Model
	local model, pivot = PrefabUtils.createModel(parent, Definition, context)

	PrefabUtils.addPart(model, "StonePad", pivot * CFrame.new(0, 1, 0), Vector3.new(14, 2, 14), Enum.Material.Cobblestone, Color3.fromRGB(122, 119, 113), 0, nil)
	PrefabUtils.addPart(model, "CenterRing", pivot * CFrame.new(0, 1.6, 0), Vector3.new(8, 1, 8), Enum.Material.Slate, Color3.fromRGB(108, 110, 120), 0, nil)

	addLamp(model, pivot, -5, -5)
	addLamp(model, pivot, 5, -5)
	addLamp(model, pivot, -5, 5)
	addLamp(model, pivot, 5, 5)

	return model
end

return PrefabUtils.finalizeDefinition(Definition, Build)
