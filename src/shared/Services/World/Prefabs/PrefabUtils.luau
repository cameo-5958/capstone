--!strict

local PrefabTypes = require(script.Parent.PrefabTypes)

type PrefabDefinition = PrefabTypes.PrefabDefinition
type PrefabBuildContext = PrefabTypes.PrefabBuildContext

type PrefabPartShape = "Block" | "Ball" | "Cylinder"

local PrefabUtils = {}
local STUD_UNIT = 1
local MIN_PART_SIZE = 1
local TREE_PREFAB_SCALE = 2.6
local FOLIAGE_PREFAB_SCALE = 1.15
local STRUCTURE_PREFAB_SCALE = 1.3
local HABITATION_STRUCTURE_SCALE = 1.58
local ENVIRONMENT_STRUCTURE_SCALE = 1.42
local HASH_MODULUS = 2147483647
local TREE_YAW_DEGREE_RANGE = 12
local TREE_LEAN_DEGREE_RANGE = 3

local function foldHash(hash: number, value: number): number
	local nextHash = (hash * 48271 + value * 131 + 17) % HASH_MODULUS
	if nextHash <= 0 then
		nextHash += HASH_MODULUS - 1
	end
	return nextHash
end

local function hashString(value: string, seed: number): number
	local hash = seed
	for i = 1, #value do
		hash = foldHash(hash, string.byte(value, i))
	end
	return hash
end

local function quantizeSeedNumber(value: number): number
	return math.floor(value * 100 + if value >= 0 then 0.5 else -0.5)
end

local function isTreePrefab(definition: PrefabDefinition): boolean
	if definition.Category ~= "Nature" then
		return false
	end

	local name = string.lower(definition.Name)
	return string.find(name, "tree", 1, true) ~= nil
		or string.find(name, "oak", 1, true) ~= nil
		or string.find(name, "pine", 1, true) ~= nil
		or string.find(name, "cypress", 1, true) ~= nil
		or string.find(name, "mangrove", 1, true) ~= nil
		or string.find(name, "trunk", 1, true) ~= nil
		or string.find(name, "saguaro", 1, true) ~= nil
end

function isHabitationStructure(definition: PrefabDefinition): boolean
	if definition.Category ~= "Structure" then
		return false
	end

	local name = string.lower(definition.Name)
	return string.find(name, "house", 1, true) ~= nil
		or string.find(name, "townhouse", 1, true) ~= nil
		or string.find(name, "cabin", 1, true) ~= nil
		or string.find(name, "hut", 1, true) ~= nil
		or string.find(name, "shack", 1, true) ~= nil
		or string.find(name, "chalet", 1, true) ~= nil
		or string.find(name, "cottage", 1, true) ~= nil
		or string.find(name, "barn", 1, true) ~= nil
end

local function isEnvironmentStructure(definition: PrefabDefinition): boolean
	if definition.Category ~= "Structure" then
		return false
	end

	local name = string.lower(definition.Name)
	return string.find(name, "lamp", 1, true) ~= nil
		or string.find(name, "lantern", 1, true) ~= nil
		or string.find(name, "well", 1, true) ~= nil
		or string.find(name, "fence", 1, true) ~= nil
		or string.find(name, "cart", 1, true) ~= nil
		or string.find(name, "campfire", 1, true) ~= nil
		or string.find(name, "camp", 1, true) ~= nil
		or string.find(name, "gate", 1, true) ~= nil
		or string.find(name, "plaza", 1, true) ~= nil
		or string.find(name, "marker", 1, true) ~= nil
end

local function getBuildScale(definition: PrefabDefinition): number
	if isTreePrefab(definition) then
		return TREE_PREFAB_SCALE
	end

	if definition.Category == "Nature" then
		return FOLIAGE_PREFAB_SCALE
	end

	if definition.Category == "Structure" then
		if isHabitationStructure(definition) then
			return HABITATION_STRUCTURE_SCALE
		end
		if isEnvironmentStructure(definition) then
			return ENVIRONMENT_STRUCTURE_SCALE
		end
		return STRUCTURE_PREFAB_SCALE
	end

	return 1
end

local function buildTreeVariationSeed(
	definition: PrefabDefinition,
	context: PrefabBuildContext,
	snappedPivot: Vector3
): number
	local hash = 9176
	hash = hashString(definition.Id, hash)
	hash = hashString(definition.Name, hash)

	if context.Biome and context.Biome ~= "" then
		hash = hashString(context.Biome, hash)
	end
	if context.NameSuffix and context.NameSuffix ~= "" then
		hash = hashString(context.NameSuffix, hash)
	end
	if context.Seed ~= nil then
		hash = foldHash(hash, quantizeSeedNumber(context.Seed))
	end
	if context.ColumnX ~= nil then
		hash = foldHash(hash, context.ColumnX)
	else
		hash = foldHash(hash, quantizeSeedNumber(snappedPivot.X))
	end
	if context.ColumnZ ~= nil then
		hash = foldHash(hash, context.ColumnZ)
	else
		hash = foldHash(hash, quantizeSeedNumber(snappedPivot.Z))
	end

	hash = foldHash(hash, quantizeSeedNumber(snappedPivot.Y))
	return math.max(1, hash % (HASH_MODULUS - 1))
end

local function setTreeVariationAttributes(
	model: Model,
	definition: PrefabDefinition,
	context: PrefabBuildContext,
	snappedPivot: Vector3
)
	local variationSeed = buildTreeVariationSeed(definition, context, snappedPivot)
	local rng = Random.new(variationSeed)

	model:SetAttribute("TreeVariationSeed", variationSeed)
	model:SetAttribute("TreeVariationScale", rng:NextNumber(0.82, 1.24))
	model:SetAttribute("TreeVariationHeight", rng:NextNumber(0.92, 1.32))
	model:SetAttribute("TreeVariationTrunkWidth", rng:NextNumber(0.82, 1.2))
	model:SetAttribute("TreeVariationCanopyWidth", rng:NextNumber(0.82, 1.32))
	model:SetAttribute("TreeVariationCanopyHeight", rng:NextNumber(0.84, 1.24))
	model:SetAttribute("TreeVariationYawDeg", rng:NextNumber(-TREE_YAW_DEGREE_RANGE, TREE_YAW_DEGREE_RANGE))
	model:SetAttribute("TreeVariationLeanXDeg", rng:NextNumber(-TREE_LEAN_DEGREE_RANGE, TREE_LEAN_DEGREE_RANGE))
	model:SetAttribute("TreeVariationLeanZDeg", rng:NextNumber(-TREE_LEAN_DEGREE_RANGE, TREE_LEAN_DEGREE_RANGE))
	model:SetAttribute("TreeVariationCanopyDriftX", rng:NextNumber(-0.55, 0.55))
	model:SetAttribute("TreeVariationCanopyDriftZ", rng:NextNumber(-0.55, 0.55))
	model:SetAttribute("TreeVariationLeafTint", rng:NextNumber(-0.18, 0.18))
	model:SetAttribute("TreeVariationBarkTint", rng:NextNumber(-0.12, 0.12))
end

local function snapNumber(value: number): number
	if value >= 0 then
		return math.floor((value / STUD_UNIT) + 0.5) * STUD_UNIT
	end
	return math.ceil((value / STUD_UNIT) - 0.5) * STUD_UNIT
end

local function snapSizeAxis(value: number): number
	return math.max(MIN_PART_SIZE, math.abs(snapNumber(value)))
end

local function snapSize(size: Vector3): Vector3
	return Vector3.new(snapSizeAxis(size.X), snapSizeAxis(size.Y), snapSizeAxis(size.Z))
end

local function snapPosition(position: Vector3): Vector3
	return Vector3.new(snapNumber(position.X), snapNumber(position.Y), snapNumber(position.Z))
end

local function snapCFrame(cframe: CFrame): CFrame
	local snappedPosition = snapPosition(cframe.Position)
	return CFrame.fromMatrix(snappedPosition, cframe.XVector, cframe.YVector, cframe.ZVector)
end

local function applyStudSurfaces(part: Part)
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Inlet
	part.LeftSurface = Enum.SurfaceType.Smooth
	part.RightSurface = Enum.SurfaceType.Smooth
	part.FrontSurface = Enum.SurfaceType.Smooth
	part.BackSurface = Enum.SurfaceType.Smooth
end

local function readModelScale(model: Model): number
	local scale = model:GetAttribute("BuildScale")
	if type(scale) == "number" and scale > 0 then
		return scale
	end
	return 1
end

local function readModelPivot(model: Model): Vector3
	local x = model:GetAttribute("PivotX")
	local y = model:GetAttribute("PivotY")
	local z = model:GetAttribute("PivotZ")
	return Vector3.new(
		if type(x) == "number" then x else 0,
		if type(y) == "number" then y else 0,
		if type(z) == "number" then z else 0
	)
end

local function readModelNumberAttribute(model: Model, attributeName: string, defaultValue: number): number
	local value = model:GetAttribute(attributeName)
	if type(value) == "number" then
		return value
	end
	return defaultValue
end

local function isTreeModel(model: Model): boolean
	return model:GetAttribute("IsTreePrefab") == true
end

local function stringContains(value: string, token: string): boolean
	return string.find(value, token, 1, true) ~= nil
end

local function isTreeRootPart(partNameLower: string): boolean
	return stringContains(partNameLower, "root") or stringContains(partNameLower, "stump")
end

local function isTreeTrunkLikePart(partNameLower: string, material: Enum.Material): boolean
	return material == Enum.Material.Wood
		or material == Enum.Material.WoodPlanks
		or stringContains(partNameLower, "trunk")
		or stringContains(partNameLower, "branch")
		or stringContains(partNameLower, "stem")
		or stringContains(partNameLower, "bark")
		or isTreeRootPart(partNameLower)
end

local function isTreeCanopyLikePart(partNameLower: string, material: Enum.Material): boolean
	return material == Enum.Material.Grass
		or stringContains(partNameLower, "canopy")
		or stringContains(partNameLower, "leaf")
		or stringContains(partNameLower, "foliage")
		or stringContains(partNameLower, "needle")
		or stringContains(partNameLower, "crown")
end

local function applyColorTint(color: Color3, tintAmount: number): Color3
	local clamped = math.clamp(tintAmount, -1, 1)
	if clamped >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), clamped)
	end
	return color:Lerp(Color3.new(0, 0, 0), -clamped)
end

local function buildTreeTransform(model: Model): CFrame
	local pivot = readModelPivot(model)
	local yaw = math.rad(readModelNumberAttribute(model, "TreeVariationYawDeg", 0))
	local leanX = math.rad(readModelNumberAttribute(model, "TreeVariationLeanXDeg", 0))
	local leanZ = math.rad(readModelNumberAttribute(model, "TreeVariationLeanZDeg", 0))
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(leanX, 0, leanZ)
	return CFrame.new(pivot) * rotation * CFrame.new(-pivot)
end

local function getPerPartRandom(model: Model, partName: string): Random
	local variationSeed = readModelNumberAttribute(model, "TreeVariationSeed", 1)
	local hashedSeed = hashString(string.lower(partName), math.max(1, math.floor(variationSeed)))
	return Random.new(math.max(1, hashedSeed % (HASH_MODULUS - 1)))
end

local function applyShape(part: Part, _shape: PrefabPartShape?)
	-- World style: always geometric rectangular stud blocks.
	part.Shape = Enum.PartType.Block
end

local function getModelCategory(model: Model): string
	local category = model:GetAttribute("PrefabCategory")
	if type(category) == "string" then
		return category
	end
	return "Nature"
end

local function shouldPartCollide(model: Model): boolean
	-- Shared marker boxes are temporary editor helpers and should never block movement.
	return getModelCategory(model) ~= "Marker"
end

local function clampNumber(value: number, minValue: number, maxValue: number): number
	return math.max(minValue, math.min(maxValue, value))
end

local function computeModelBounds(model: Model): (Vector3?, Vector3?, number)
	local minX = math.huge
	local minY = math.huge
	local minZ = math.huge
	local maxX = -math.huge
	local maxY = -math.huge
	local maxZ = -math.huge
	local partCount = 0

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local part = descendant :: BasePart
			local size = part.Size
			local position = part.Position
			local half = size * 0.5
			local low = position - half
			local high = position + half
			minX = math.min(minX, low.X)
			minY = math.min(minY, low.Y)
			minZ = math.min(minZ, low.Z)
			maxX = math.max(maxX, high.X)
			maxY = math.max(maxY, high.Y)
			maxZ = math.max(maxZ, high.Z)
			partCount += 1
		end
	end

	if partCount <= 0 then
		return nil, nil, 0
	end
	return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ), partCount
end

local function addAbsoluteModelPart(
	model: Model,
	name: string,
	cframe: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	transparency: number?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = shouldPartCollide(model)
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = material
	part.Color = color
	part.Transparency = transparency or 0
	part.Size = snapSize(size)
	part.CFrame = snapCFrame(cframe)
	applyStudSurfaces(part)
	applyShape(part, nil)
	part.Parent = model
	return part
end

local function applyStructureDetailPass(model: Model, definition: PrefabDefinition)
	if definition.Category ~= "Structure" then
		return
	end
	if not isHabitationStructure(definition) then
		return
	end
	if model:GetAttribute("StructureDetailApplied") == true then
		return
	end

	local minBounds, maxBounds, partCount = computeModelBounds(model)
	if not minBounds or not maxBounds or partCount < 4 then
		return
	end

	local boundsSize = maxBounds - minBounds
	if boundsSize.X < 6 or boundsSize.Z < 6 or boundsSize.Y < 4 then
		return
	end

	model:SetAttribute("StructureDetailApplied", true)

	local center = (minBounds + maxBounds) * 0.5
	local baseY = minBounds.Y
	local topY = maxBounds.Y
	local minSpan = math.min(boundsSize.X, boundsSize.Z)
	local frameInset = clampNumber(minSpan * 0.07, 0.8, 2.6)
	local frameThickness = clampNumber(minSpan * 0.08, 0.8, 2.4)
	local postThickness = clampNumber(minSpan * 0.08, 0.8, 1.8)
	local postHeight = clampNumber(boundsSize.Y * 0.32, 2.4, 9.0)
	local bandThickness = clampNumber(minSpan * 0.06, 0.8, 1.8)
	local bandY = clampNumber(baseY + boundsSize.Y * 0.48, baseY + 1.6, topY - 1.2)
	local ridgeThickness = clampNumber(minSpan * 0.06, 0.8, 1.6)

	addAbsoluteModelPart(
		model,
		"DetailBaseSkirt",
		CFrame.new(center.X, baseY + 0.4, center.Z),
		Vector3.new(boundsSize.X + frameThickness * 1.8, 0.8, boundsSize.Z + frameThickness * 1.8),
		Enum.Material.Slate,
		Color3.fromRGB(88, 89, 98),
		0
	)

	addAbsoluteModelPart(
		model,
		"DetailMidBand",
		CFrame.new(center.X, bandY, center.Z),
		Vector3.new(boundsSize.X + bandThickness * 0.9, 0.8, boundsSize.Z + bandThickness * 0.9),
		Enum.Material.Wood,
		Color3.fromRGB(83, 61, 44),
		0
	)

	local corners = {
		{ Name = "NW", SX = -1, SZ = -1 },
		{ Name = "NE", SX = 1, SZ = -1 },
		{ Name = "SW", SX = -1, SZ = 1 },
		{ Name = "SE", SX = 1, SZ = 1 },
	}
	for _, corner in ipairs(corners) do
		addAbsoluteModelPart(
			model,
			"DetailCornerPost" .. corner.Name,
			CFrame.new(
				center.X + corner.SX * (boundsSize.X * 0.5 - frameInset),
				baseY + postHeight * 0.5 + 0.35,
				center.Z + corner.SZ * (boundsSize.Z * 0.5 - frameInset)
			),
			Vector3.new(postThickness, postHeight, postThickness),
			Enum.Material.WoodPlanks,
			Color3.fromRGB(96, 72, 52),
			0
		)
	end

	if boundsSize.X >= boundsSize.Z then
		addAbsoluteModelPart(
			model,
			"DetailRoofRidge",
			CFrame.new(center.X, topY - 0.45, center.Z),
			Vector3.new(clampNumber(boundsSize.X * 0.42, 4, boundsSize.X), 0.8, ridgeThickness),
			Enum.Material.Wood,
			Color3.fromRGB(78, 58, 42),
			0
		)
	else
		addAbsoluteModelPart(
			model,
			"DetailRoofRidge",
			CFrame.new(center.X, topY - 0.45, center.Z),
			Vector3.new(ridgeThickness, 0.8, clampNumber(boundsSize.Z * 0.42, 4, boundsSize.Z)),
			Enum.Material.Wood,
			Color3.fromRGB(78, 58, 42),
			0
		)
	end

	if isHabitationStructure(definition) then
		local canopyWidth = clampNumber(boundsSize.X * 0.34, 3.2, boundsSize.X * 0.7)
		local canopyDepth = clampNumber(boundsSize.Z * 0.12, 1.2, 3.8)
		local canopyY = clampNumber(baseY + boundsSize.Y * 0.28, baseY + 2.4, topY - 2.2)
		addAbsoluteModelPart(
			model,
			"DetailEntryCanopy",
			CFrame.new(center.X, canopyY, center.Z + boundsSize.Z * 0.5 + canopyDepth * 0.35),
			Vector3.new(canopyWidth, 0.8, canopyDepth),
			Enum.Material.WoodPlanks,
			Color3.fromRGB(108, 80, 58),
			0
		)
	end
end

function PrefabUtils.createModel(
	parent: Instance,
	definition: PrefabDefinition,
	context: PrefabBuildContext
): (Model, CFrame)
	local model = Instance.new("Model")
	model.Name = if context.NameSuffix and context.NameSuffix ~= ""
		then string.format("%s_%s", definition.Name, context.NameSuffix)
		else definition.Name
	model:SetAttribute("PrefabId", definition.Id)
	model:SetAttribute("PrefabBiome", definition.Biome)
	model:SetAttribute("PrefabCategory", definition.Category)
	model:SetAttribute("RuntimeEligible", definition.RuntimeEligible)
	if context.ColumnX ~= nil then
		model:SetAttribute("ColumnX", context.ColumnX)
	end
	if context.ColumnZ ~= nil then
		model:SetAttribute("ColumnZ", context.ColumnZ)
	end
	local treePrefab = isTreePrefab(definition)
	model:SetAttribute("IsTreePrefab", treePrefab)

	local pivotPosition = context.Position
	local surfaceY = if context.SurfaceY ~= nil then context.SurfaceY else context.Position.Y - 1
	model:SetAttribute("SurfaceY", surfaceY)
	local snappedPivot = snapPosition(pivotPosition)
	if treePrefab then
		setTreeVariationAttributes(model, definition, context, snappedPivot)
	end
	local buildScale = getBuildScale(definition)
	if treePrefab then
		buildScale *= readModelNumberAttribute(model, "TreeVariationScale", 1)
		local treeHeight = readModelNumberAttribute(model, "TreeVariationHeight", 1)
		local groundOffset = 1 + (buildScale * treeHeight * 0.56)
		pivotPosition = Vector3.new(context.Position.X, surfaceY - groundOffset, context.Position.Z)
		snappedPivot = snapPosition(pivotPosition)
	end
	model:SetAttribute("PivotX", snappedPivot.X)
	model:SetAttribute("PivotY", snappedPivot.Y)
	model:SetAttribute("PivotZ", snappedPivot.Z)
	model:SetAttribute("BuildScale", buildScale)
	model.Parent = parent
	return model, CFrame.new(snappedPivot)
end

function PrefabUtils.addPart(
	model: Model,
	name: string,
	cframe: CFrame,
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	transparency: number?,
	shape: PrefabPartShape?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = shouldPartCollide(model)
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Material = material
	part.Transparency = transparency or 0
	local scale = readModelScale(model)
	local scaledSize = size
	local scaledCFrame = cframe
	if math.abs(scale - 1) > 1e-4 then
		local pivotPosition = readModelPivot(model)
		local relative = cframe.Position - pivotPosition
		local scaledPosition = pivotPosition + (relative * scale)
		scaledCFrame = CFrame.fromMatrix(scaledPosition, cframe.XVector, cframe.YVector, cframe.ZVector)
		scaledSize = size * scale
	end

	local resolvedColor = color
	if isTreeModel(model) then
		local partNameLower = string.lower(name)
		local partRng = getPerPartRandom(model, name)
		local treeHeight = readModelNumberAttribute(model, "TreeVariationHeight", 1)
		local trunkWidth = readModelNumberAttribute(model, "TreeVariationTrunkWidth", 1)
		local canopyWidth = readModelNumberAttribute(model, "TreeVariationCanopyWidth", 1)
		local canopyHeight = readModelNumberAttribute(model, "TreeVariationCanopyHeight", 1)
		local canopyDriftX = readModelNumberAttribute(model, "TreeVariationCanopyDriftX", 0)
		local canopyDriftZ = readModelNumberAttribute(model, "TreeVariationCanopyDriftZ", 0)
		local leafTint = readModelNumberAttribute(model, "TreeVariationLeafTint", 0)
		local barkTint = readModelNumberAttribute(model, "TreeVariationBarkTint", 0)
		local trunkLike = isTreeTrunkLikePart(partNameLower, material)
		local canopyLike = isTreeCanopyLikePart(partNameLower, material)

		if trunkLike then
			local widthJitter = partRng:NextNumber(0.92, 1.08)
			local heightJitter = partRng:NextNumber(0.92, 1.1)
			scaledSize = Vector3.new(
				scaledSize.X * trunkWidth * widthJitter,
				scaledSize.Y * treeHeight * heightJitter,
				scaledSize.Z * trunkWidth * widthJitter
			)
			resolvedColor = applyColorTint(color, barkTint + partRng:NextNumber(-0.04, 0.04))
		elseif canopyLike then
			local widthJitter = partRng:NextNumber(0.88, 1.16)
			local heightJitter = partRng:NextNumber(0.88, 1.16)
			scaledSize = Vector3.new(
				scaledSize.X * canopyWidth * widthJitter,
				scaledSize.Y * treeHeight * canopyHeight * heightJitter,
				scaledSize.Z * canopyWidth * widthJitter
			)
			local driftScale = math.max(1, scale * 0.35)
			local localJitterOffset = Vector3.new(
				partRng:NextNumber(-1.05, 1.05) * driftScale,
				partRng:NextNumber(-0.45, 0.95) * driftScale,
				partRng:NextNumber(-1.05, 1.05) * driftScale
			)
			local globalDriftOffset = Vector3.new(canopyDriftX * scale, 0, canopyDriftZ * scale)
			local nextPosition = scaledCFrame.Position + globalDriftOffset + localJitterOffset
			scaledCFrame =
				CFrame.fromMatrix(nextPosition, scaledCFrame.XVector, scaledCFrame.YVector, scaledCFrame.ZVector)
			resolvedColor = applyColorTint(color, leafTint + partRng:NextNumber(-0.05, 0.05))
		else
			scaledSize = Vector3.new(
				scaledSize.X * partRng:NextNumber(0.95, 1.08),
				scaledSize.Y * treeHeight * partRng:NextNumber(0.95, 1.08),
				scaledSize.Z * partRng:NextNumber(0.95, 1.08)
			)
		end

		scaledCFrame = buildTreeTransform(model) * scaledCFrame
	end

	part.Color = resolvedColor
	part.Size = snapSize(scaledSize)
	part.CFrame = snapCFrame(scaledCFrame)
	applyStudSurfaces(part)
	applyShape(part, shape)
	part.Parent = model
	return part
end

function PrefabUtils.finalizeDefinition(
	definition: {
		Id: string,
		Name: string,
		Biome: PrefabTypes.PrefabBiome,
		Category: PrefabTypes.PrefabCategory,
		RuntimeEligible: boolean,
		FootprintStuds: Vector2,
		HeightStuds: number,
		SpawnMarkers: { PrefabTypes.PrefabSpawnMarker }?,
	},
	buildFn: (parent: Instance, context: PrefabBuildContext) -> Model
): PrefabDefinition
	local spawnMarkers = nil
	if definition.SpawnMarkers then
		spawnMarkers = table.clone(definition.SpawnMarkers)
	end

	local finalizedDefinition = {
		Id = definition.Id,
		Name = definition.Name,
		Biome = definition.Biome,
		Category = definition.Category,
		RuntimeEligible = definition.RuntimeEligible,
		FootprintStuds = definition.FootprintStuds,
		HeightStuds = definition.HeightStuds,
		SpawnMarkers = spawnMarkers,
		Build = buildFn,
	}

	finalizedDefinition.Build = function(parent: Instance, context: PrefabBuildContext): Model
		local model = buildFn(parent, context)
		applyStructureDetailPass(model, finalizedDefinition)
		return model
	end

	return finalizedDefinition
end

return table.freeze(PrefabUtils)
