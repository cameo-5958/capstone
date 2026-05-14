--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "AdventurerCharm"

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 1.15, 1.15)
	ring.Color = Color3.fromRGB(210, 178, 98)
	ring.Material = Enum.Material.Metal
	ring.Anchored = false
	ring.CanCollide = false
	ring.CFrame = CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = model

	local gem = Instance.new("Part")
	gem.Name = "Gem"
	gem.Shape = Enum.PartType.Ball
	gem.Size = Vector3.new(0.58, 0.58, 0.58)
	gem.Color = Color3.fromRGB(104, 188, 214)
	gem.Material = Enum.Material.Glass
	gem.Anchored = false
	gem.CanCollide = false
	gem.Position = Vector3.new(0, -0.05, 0)
	gem.Parent = model

	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Block
	cap.Size = Vector3.new(0.32, 0.24, 0.32)
	cap.Color = Color3.fromRGB(180, 142, 74)
	cap.Material = Enum.Material.Metal
	cap.Anchored = false
	cap.CanCollide = false
	cap.Position = Vector3.new(0, 0.24, 0)
	cap.Parent = model

	local weldA = Instance.new("WeldConstraint")
	weldA.Part0 = gem
	weldA.Part1 = cap
	weldA.Parent = gem

	local weldB = Instance.new("WeldConstraint")
	weldB.Part0 = ring
	weldB.Part1 = cap
	weldB.Parent = ring

	model.PrimaryPart = gem
	return model
end
