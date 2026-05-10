--!strict

local GolemRigBuilder = require(script.Parent.Parent.GolemRigBuilder)

return function(): Model
	return GolemRigBuilder.Build({
		Name = "BasaltGolem",
		Scale = 1.15,
		BodyMaterial = Enum.Material.Basalt,
		BodyColor = Color3.fromRGB(95, 98, 106),
		PlateMaterial = Enum.Material.Slate,
		PlateColor = Color3.fromRGB(72, 75, 84),
		CoreMaterial = Enum.Material.Neon,
		CoreColor = Color3.fromRGB(255, 168, 86),
	})
end
