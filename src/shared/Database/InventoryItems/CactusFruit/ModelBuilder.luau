--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "CactusFruit"

	local fruit = Instance.new("Part")
	fruit.Name = "Fruit"
	fruit.Size = Vector3.new(0.38, 0.58, 0.38)
	fruit.Color = Color3.fromRGB(212, 96, 92)
	fruit.Material = Enum.Material.SmoothPlastic
	fruit.Anchored = false
	fruit.CanCollide = false
	fruit.Parent = model

	local flower = Instance.new("Part")
	flower.Name = "Flower"
	flower.Shape = Enum.PartType.Ball
	flower.Size = Vector3.new(0.12, 0.12, 0.12)
	flower.Color = Color3.fromRGB(238, 214, 96)
	flower.Material = Enum.Material.Neon
	flower.Anchored = false
	flower.CanCollide = false
	flower.Position = Vector3.new(0, 0.33, 0)
	flower.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = fruit
	weld.Part1 = flower
	weld.Parent = fruit
	model.PrimaryPart = fruit
	return model
end
