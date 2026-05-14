--!strict

return function(): Model
	local model = Instance.new("Model")
	model.Name = "Wheat"

	local stemColors = {
		Color3.fromRGB(186, 170, 96),
		Color3.fromRGB(204, 186, 112),
		Color3.fromRGB(175, 157, 88),
	}
	local primaryPart = nil :: Part?
	for index, xOffset in ipairs({ -0.12, 0, 0.12 }) do
		local stalk = Instance.new("Part")
		stalk.Name = "Stalk" .. tostring(index)
		stalk.Size = Vector3.new(0.08, 0.9, 0.08)
		stalk.Color = stemColors[index]
		stalk.Material = Enum.Material.Grass
		stalk.Anchored = false
		stalk.CanCollide = false
		stalk.Position = Vector3.new(xOffset, 0, 0)
		stalk.Parent = model
		if not primaryPart then
			primaryPart = stalk
		end

		local head = Instance.new("Part")
		head.Name = "Head" .. tostring(index)
		head.Size = Vector3.new(0.12, 0.38, 0.12)
		head.Color = Color3.fromRGB(216, 198, 120)
		head.Material = Enum.Material.Grass
		head.Anchored = false
		head.CanCollide = false
		head.Position = Vector3.new(xOffset, 0.55, 0)
		head.Parent = model
	end

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
