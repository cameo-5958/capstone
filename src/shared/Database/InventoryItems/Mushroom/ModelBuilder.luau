--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "Mushroom"

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.34, 0.72, 0.34)
	stem.Color = Color3.fromRGB(231, 224, 203)
	stem.Material = Enum.Material.SmoothPlastic
	stem.Anchored = false
	stem.CanCollide = false
	stem.Position = Vector3.new(0, 0, 0)
	stem.Parent = model

	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Size = Vector3.new(0.92, 0.28, 0.92)
	cap.Color = Color3.fromRGB(179, 102, 67)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Anchored = false
	cap.CanCollide = false
	cap.Position = Vector3.new(0, 0.42, 0)
	cap.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = stem
	weld.Part1 = cap
	weld.Parent = stem

	model.PrimaryPart = stem
	return model
end
