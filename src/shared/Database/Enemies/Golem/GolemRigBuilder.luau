--!strict

export type BuildOptions = {
	Name: string?,
	Scale: number?,
	BodyMaterial: Enum.Material?,
	BodyColor: Color3?,
	PlateMaterial: Enum.Material?,
	PlateColor: Color3?,
	CoreMaterial: Enum.Material?,
	CoreColor: Color3?,
}

local function applyStudSurfaces(part: Part)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
end

local function createPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	material: Enum.Material,
	color: Color3,
	transparency: number,
	canCollide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = false
	part.CanCollide = canCollide
	part.CanQuery = canCollide
	part.CanTouch = canCollide
	part.CastShadow = true
	part.Material = material
	part.Color = color
	part.Transparency = transparency
	applyStudSurfaces(part)
	part.Parent = parent
	return part
end

local function weld(part0: BasePart, part1: BasePart, parent: Instance)
	local weldConstraint = Instance.new("WeldConstraint")
	weldConstraint.Part0 = part0
	weldConstraint.Part1 = part1
	weldConstraint.Parent = parent
end

local GolemRigBuilder = {}

function GolemRigBuilder.Build(options: BuildOptions?): Model
	local resolved = options or {}
	local scale = math.max(0.8, resolved.Scale or 1)
	local bodyMaterial = resolved.BodyMaterial or Enum.Material.Rock
	local bodyColor = resolved.BodyColor or Color3.fromRGB(110, 112, 120)
	local plateMaterial = resolved.PlateMaterial or Enum.Material.Slate
	local plateColor = resolved.PlateColor or Color3.fromRGB(86, 89, 98)
	local coreMaterial = resolved.CoreMaterial or Enum.Material.Neon
	local coreColor = resolved.CoreColor or Color3.fromRGB(124, 201, 255)

	local model = Instance.new("Model")
	model.Name = resolved.Name or "Golem"
	model:SetAttribute("StudBuilt", true)

	local rootPosition = Vector3.new(0, 8 * scale, 0)
	local rootPart = createPart(
		model,
		"HumanoidRootPart",
		Vector3.new(4, 5, 4) * scale,
		CFrame.new(rootPosition),
		Enum.Material.Slate,
		Color3.fromRGB(90, 92, 102),
		1,
		true
	)

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "RootAttachment"
	rootAttachment.Parent = rootPart

	local torso = createPart(
		model,
		"Torso",
		Vector3.new(7, 7, 5) * scale,
		CFrame.new(rootPosition + Vector3.new(0, 1, 0) * scale),
		bodyMaterial,
		bodyColor,
		0,
		false
	)
	local head = createPart(
		model,
		"Head",
		Vector3.new(4, 4, 4) * scale,
		CFrame.new(rootPosition + Vector3.new(0, 6.5, 0) * scale),
		bodyMaterial,
		bodyColor,
		0,
		false
	)
	local leftArm = createPart(
		model,
		"LeftArm",
		Vector3.new(3, 6, 3) * scale,
		CFrame.new(rootPosition + Vector3.new(-5.2, 0.4, 0) * scale),
		bodyMaterial,
		bodyColor,
		0,
		false
	)
	local rightArm = createPart(
		model,
		"RightArm",
		Vector3.new(3, 6, 3) * scale,
		CFrame.new(rootPosition + Vector3.new(5.2, 0.4, 0) * scale),
		bodyMaterial,
		bodyColor,
		0,
		false
	)
	local leftLeg = createPart(
		model,
		"LeftLeg",
		Vector3.new(3.2, 6, 3.2) * scale,
		CFrame.new(rootPosition + Vector3.new(-2.2, -6, 0) * scale),
		bodyMaterial,
		bodyColor,
		0,
		false
	)
	local rightLeg = createPart(
		model,
		"RightLeg",
		Vector3.new(3.2, 6, 3.2) * scale,
		CFrame.new(rootPosition + Vector3.new(2.2, -6, 0) * scale),
		bodyMaterial,
		bodyColor,
		0,
		false
	)

	local chestPlate = createPart(
		model,
		"ChestPlate",
		Vector3.new(7.4, 4.2, 1.6) * scale,
		CFrame.new(rootPosition + Vector3.new(0, 1.2, 2.7) * scale),
		plateMaterial,
		plateColor,
		0,
		false
	)
	local shoulderLeftPlate = createPart(
		model,
		"ShoulderLeftPlate",
		Vector3.new(3.4, 2.1, 3.4) * scale,
		CFrame.new(rootPosition + Vector3.new(-5.3, 3.7, 0) * scale),
		plateMaterial,
		plateColor,
		0,
		false
	)
	local shoulderRightPlate = createPart(
		model,
		"ShoulderRightPlate",
		Vector3.new(3.4, 2.1, 3.4) * scale,
		CFrame.new(rootPosition + Vector3.new(5.3, 3.7, 0) * scale),
		plateMaterial,
		plateColor,
		0,
		false
	)
	local core = createPart(
		model,
		"Core",
		Vector3.new(1.8, 1.8, 1.2) * scale,
		CFrame.new(rootPosition + Vector3.new(0, 1.1, 2.9) * scale),
		coreMaterial,
		coreColor,
		0.12,
		false
	)

	weld(rootPart, torso, rootPart)
	weld(rootPart, head, rootPart)
	weld(rootPart, leftArm, rootPart)
	weld(rootPart, rightArm, rootPart)
	weld(rootPart, leftLeg, rootPart)
	weld(rootPart, rightLeg, rootPart)
	weld(rootPart, chestPlate, rootPart)
	weld(rootPart, shoulderLeftPlate, rootPart)
	weld(rootPart, shoulderRightPlate, rootPart)
	weld(rootPart, core, rootPart)

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = true
	humanoid.AutoRotate = true
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	return model
end

return table.freeze(GolemRigBuilder)
