--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "Blueberry"

	local berry = Instance.new("Part")
	berry.Name = "Berry"
	berry.Shape = Enum.PartType.Ball
	berry.Size = Vector3.new(0.42, 0.42, 0.42)
	berry.Color = Color3.fromRGB(74, 102, 189)
	berry.Material = Enum.Material.SmoothPlastic
	berry.Anchored = false
	berry.CanCollide = false
	berry.Parent = model

	local leaf = Instance.new("Part")
	leaf.Name = "Leaf"
	leaf.Size = Vector3.new(0.1, 0.22, 0.22)
	leaf.Color = Color3.fromRGB(86, 133, 77)
	leaf.Material = Enum.Material.Grass
	leaf.Anchored = false
	leaf.CanCollide = false
	leaf.CFrame = CFrame.new(0, 0.18, 0) * CFrame.Angles(math.rad(10), 0, math.rad(35))
	leaf.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = berry
	weld.Part1 = leaf
	weld.Parent = berry
	model.PrimaryPart = berry
	return model
end
