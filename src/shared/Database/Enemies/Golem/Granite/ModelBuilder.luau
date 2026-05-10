--!strict

local GolemRigBuilder = require(script.Parent.Parent.GolemRigBuilder)

return function(): Model
	return GolemRigBuilder.Build({
		Name = "GraniteGolem",
		Scale = 1.35,
		BodyMaterial = Enum.Material.Granite,
		BodyColor = Color3.fromRGB(118, 118, 124),
		PlateMaterial = Enum.Material.Rock,
		PlateColor = Color3.fromRGB(95, 95, 104),
		CoreMaterial = Enum.Material.Neon,
		CoreColor = Color3.fromRGB(158, 225, 255),
	})
end
