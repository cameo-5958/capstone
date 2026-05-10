--!strict

local GolemRigBuilder = require(script.Parent.Parent.GolemRigBuilder)

return function(): Model
	return GolemRigBuilder.Build({
		Name = "RunicGolem",
		Scale = 1.22,
		BodyMaterial = Enum.Material.Slate,
		BodyColor = Color3.fromRGB(88, 96, 116),
		PlateMaterial = Enum.Material.SmoothPlastic,
		PlateColor = Color3.fromRGB(66, 77, 100),
		CoreMaterial = Enum.Material.Neon,
		CoreColor = Color3.fromRGB(145, 115, 255),
	})
end
