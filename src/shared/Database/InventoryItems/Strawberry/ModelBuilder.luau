--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "Strawberry"

	local berry = Instance.new("Part")
	berry.Name = "Berry"
	berry.Size = Vector3.new(0.4, 0.5, 0.4)
	berry.Color = Color3.fromRGB(196, 54, 62)
	berry.Material = Enum.Material.SmoothPlastic
	berry.Anchored = false
	berry.CanCollide = false
	berry.CFrame = CFrame.new(0, -0.04, 0)
	berry.Parent = model

	local leaf = Instance.new("Part")
	leaf.Name = "Leaf"
	leaf.Size = Vector3.new(0.22, 0.08, 0.22)
	leaf.Color = Color3.fromRGB(88, 145, 74)
	leaf.Material = Enum.Material.Grass
	leaf.Anchored = false
	leaf.CanCollide = false
	leaf.Position = Vector3.new(0, 0.22, 0)
	leaf.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = berry
	weld.Part1 = leaf
	weld.Parent = berry
	model.PrimaryPart = berry
	return model
end
