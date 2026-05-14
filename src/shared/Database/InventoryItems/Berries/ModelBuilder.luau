--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "Berries"

	local berryColors = {
		Color3.fromRGB(179, 52, 83),
		Color3.fromRGB(197, 68, 98),
		Color3.fromRGB(157, 39, 72),
	}
	local positions = {
		Vector3.new(-0.28, 0.08, 0),
		Vector3.new(0.28, 0.06, -0.06),
		Vector3.new(0, -0.18, 0.12),
	}

	local primaryPart = nil :: Part?
	for index, position in ipairs(positions) do
		local berry = Instance.new("Part")
		berry.Name = "Berry" .. tostring(index)
		berry.Shape = Enum.PartType.Ball
		berry.Size = Vector3.new(0.48, 0.48, 0.48)
		berry.Color = berryColors[index]
		berry.Material = Enum.Material.SmoothPlastic
		berry.Anchored = false
		berry.CanCollide = false
		berry.Position = position
		berry.Parent = model
		if not primaryPart then
			primaryPart = berry
		end
	end

	local leaf = Instance.new("Part")
	leaf.Name = "Leaf"
	leaf.Size = Vector3.new(0.2, 0.6, 0.4)
	leaf.Color = Color3.fromRGB(74, 131, 67)
	leaf.Material = Enum.Material.Grass
	leaf.Anchored = false
	leaf.CanCollide = false
	leaf.CFrame = CFrame.new(0, 0.35, 0.05) * CFrame.Angles(math.rad(18), 0, math.rad(32))
	leaf.Parent = model

	if primaryPart then
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and child ~= primaryPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = child
				weld.Parent = primaryPart
			end
		end
		model.PrimaryPart = primaryPart
	end

	return model
end
