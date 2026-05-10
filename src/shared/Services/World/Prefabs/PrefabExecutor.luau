--!strict

local Workspace = game:GetService("Workspace")

local PrefabTypes = require(script.Parent.PrefabTypes)
local PrefabRegistry = require(script.Parent.PrefabRegistry)

type PrefabDefinition = PrefabTypes.PrefabDefinition
type GenerateGalleryOptions = {
	ClearExisting: boolean?,
	IncludeExecutorOnly: boolean?,
	IncludeMarkers: boolean?,
	TileSize: number?,
	SpacingStuds: number?,
	BasePosition: Vector3?,
}

local PrefabExecutor = {}

local BiomeSort: { [string]: number } = {
	TemperateGrassland = 1,
	PineHighlands = 2,
	Forest = 3,
	DenseForest = 4,
	Alpine = 5,
	HighlandDesert = 6,
	Marshland = 7,
	Shared = 8,
}

local CategorySort: { [string]: number } = {
	Nature = 1,
	Structure = 2,
	Marker = 3,
}

local function getOrCreateRoot(): Folder
	local existing = Workspace:FindFirstChild("PrefabGallery")
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = "PrefabGallery"
	root.Parent = Workspace
	return root
end

local function shouldInclude(definition: PrefabDefinition, includeExecutorOnly: boolean, includeMarkers: boolean): boolean
	if definition.Category == "Marker" then
		return includeMarkers
	end
	if definition.RuntimeEligible then
		return true
	end
	return includeExecutorOnly
end

function PrefabExecutor.GenerateGallery(options: GenerateGalleryOptions?): Folder
	local resolved = options or {}
	local clearExisting = if resolved.ClearExisting == nil then true else resolved.ClearExisting
	local includeExecutorOnly = if resolved.IncludeExecutorOnly == nil then false else resolved.IncludeExecutorOnly
	local includeMarkers = if resolved.IncludeMarkers == nil then true else resolved.IncludeMarkers
	local tileSize = math.max(4, resolved.TileSize or 10)
	local spacing = math.max(tileSize * 1.8, resolved.SpacingStuds or 26)
	local basePosition = resolved.BasePosition or Vector3.new(0, 12, 0)

	local root = getOrCreateRoot()
	if clearExisting then
		for _, child in ipairs(root:GetChildren()) do
			child:Destroy()
		end
	end

	local grouped = {} :: { [string]: { [string]: { PrefabDefinition } } }
	for _, definition in ipairs(PrefabRegistry.GetAll()) do
		if shouldInclude(definition, includeExecutorOnly, includeMarkers) then
			local biomeBucket = grouped[definition.Biome]
			if not biomeBucket then
				biomeBucket = {}
				grouped[definition.Biome] = biomeBucket
			end
			local categoryBucket = biomeBucket[definition.Category]
			if not categoryBucket then
				categoryBucket = {}
				biomeBucket[definition.Category] = categoryBucket
			end
			table.insert(categoryBucket, definition)
		end
	end

	local biomeNames = {} :: { string }
	for biomeName in pairs(grouped) do
		table.insert(biomeNames, biomeName)
	end
	table.sort(biomeNames, function(a: string, b: string)
		local aSort = BiomeSort[a] or 999
		local bSort = BiomeSort[b] or 999
		if aSort == bSort then
			return a < b
		end
		return aSort < bSort
	end)

	local biomeStride = spacing * 6
	for biomeIndex, biomeName in ipairs(biomeNames) do
		local biomeFolder = Instance.new("Folder")
		biomeFolder.Name = biomeName
		biomeFolder.Parent = root

		local categoryNames = {} :: { string }
		for categoryName in pairs(grouped[biomeName]) do
			table.insert(categoryNames, categoryName)
		end
		table.sort(categoryNames, function(a: string, b: string)
			local aSort = CategorySort[a] or 999
			local bSort = CategorySort[b] or 999
			if aSort == bSort then
				return a < b
			end
			return aSort < bSort
		end)

		for categoryIndex, categoryName in ipairs(categoryNames) do
			local categoryFolder = Instance.new("Folder")
			categoryFolder.Name = categoryName
			categoryFolder.Parent = biomeFolder

			local definitions = grouped[biomeName][categoryName]
			table.sort(definitions, function(a: PrefabDefinition, b: PrefabDefinition)
				return a.Name < b.Name
			end)

			for prefabIndex, definition in ipairs(definitions) do
				local column = (prefabIndex - 1) % 5
				local row = math.floor((prefabIndex - 1) / 5)
				local x = basePosition.X + ((biomeIndex - 1) * biomeStride) + (column * spacing)
				local z = basePosition.Z + ((categoryIndex - 1) * spacing * 3.5) + (row * spacing)
				local context: PrefabTypes.PrefabBuildContext = {
					Position = Vector3.new(x, basePosition.Y, z),
					TileSize = tileSize,
					SurfaceY = basePosition.Y,
					Biome = definition.Biome,
					Seed = 0,
					NameSuffix = "Gallery",
				}
				local model = definition.Build(categoryFolder, context)
				model:SetAttribute("GalleryBiome", biomeName)
				model:SetAttribute("GalleryCategory", categoryName)
			end
		end
	end

	return root
end

return table.freeze(PrefabExecutor)
