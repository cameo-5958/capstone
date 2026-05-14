--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "ChestKey"

	local bow = Instance.new("Part")
	bow.Name = "Bow"
	bow.Shape = Enum.PartType.Cylinder
	bow.Size = Vector3.new(0.18, 0.62, 0.62)
	bow.Color = Color3.fromRGB(199, 160, 77)
	bow.Material = Enum.Material.Metal
	bow.Anchored = false
	bow.CanCollide = false
	bow.CFrame = CFrame.new(0, 0.22, 0) * CFrame.Angles(0, 0, math.rad(90))
	bow.Parent = model

	local shaft = Instance.new("Part")
	shaft.Name = "Shaft"
	shaft.Size = Vector3.new(0.16, 0.9, 0.16)
	shaft.Color = bow.Color
	shaft.Material = bow.Material
	shaft.Anchored = false
	shaft.CanCollide = false
	shaft.Position = Vector3.new(0, -0.28, 0)
	shaft.Parent = model

	local toothA = Instance.new("Part")
	toothA.Name = "ToothA"
	toothA.Size = Vector3.new(0.14, 0.18, 0.16)
	toothA.Color = bow.Color
	toothA.Material = bow.Material
	toothA.Anchored = false
	toothA.CanCollide = false
	toothA.Position = Vector3.new(0.13, -0.64, 0)
	toothA.Parent = model

	local toothB = Instance.new("Part")
	toothB.Name = "ToothB"
	toothB.Size = Vector3.new(0.22, 0.12, 0.16)
	toothB.Color = bow.Color
	toothB.Material = bow.Material
	toothB.Anchored = false
	toothB.CanCollide = false
	toothB.Position = Vector3.new(-0.03, -0.79, 0)
	toothB.Parent = model

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= bow then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = bow
			weld.Part1 = child
			weld.Parent = bow
		end
	end

	model.PrimaryPart = bow
	return model
end
