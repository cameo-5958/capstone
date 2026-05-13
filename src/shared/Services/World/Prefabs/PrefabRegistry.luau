--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PrefabTypes = require(script.Parent.PrefabTypes)

type PrefabDefinition = PrefabTypes.PrefabDefinition

local PrefabRegistry = {}

local function resolvePrefabsDatabase(): Instance?
	local localDatabase = script.Parent:FindFirstChild("Biomes")
	if localDatabase then
		return localDatabase
	end

	local services = ReplicatedStorage:FindFirstChild("Services")
	local world = if services then services:FindFirstChild("World") else nil
	local prefabs = if world then world:FindFirstChild("Prefabs") else nil
	local remoteDatabase = if prefabs then prefabs:FindFirstChild("Biomes") else nil
	if remoteDatabase then
		return remoteDatabase
	end

	warn("[PrefabRegistry] Missing Biomes folder; prefab lookups will return empty until Biomes is available")
	return nil
end

local PrefabsDatabase = resolvePrefabsDatabase()
local DefinitionById = {} :: { [string]: PrefabDefinition }
local AllDefinitionsCache: { PrefabDefinition }? = nil
local ModuleByPathCache: { [string]: ModuleScript }? = nil
local ExcludedPrefabIds = {}

local RuntimeNaturePools: { [string]: { string } } = {
	TemperateGrassland = {
		"TemperateGrassland::MeadowOakTall",
		"TemperateGrassland::MeadowOakWide",
		"TemperateGrassland::WildflowerPatch",
		"TemperateGrassland::TallGrassCluster",
		"TemperateGrassland::GraniteBoulderCluster",
		"TemperateGrassland::FallenLogMossy",
	},
	PineHighlands = {
		"PineHighlands::HighlandPineTall",
		"PineHighlands::HighlandPineBent",
		"PineHighlands::NeedleShrubPatch",
		"PineHighlands::MossRockPile",
		"PineHighlands::FernCluster",
		"PineHighlands::FallenPineLog",
	},
	Forest = {
		"Forest::AncientTrunkGiant",
		"Forest::VineWrappedTrunk",
		"Forest::ThornBushCluster",
		"Forest::MossSpireRock",
		"Forest::RottingLogPile",
		"Forest::GlowingMushroomPatch",
	},
	Alpine = {
		"Alpine::SnowPineTall",
		"Alpine::SnowPineCluster",
		"Alpine::FrostShrubPatch",
		"Alpine::IceRockCluster",
		"Alpine::WindCarvedBoulder",
		"Alpine::SnowDriftMound",
	},
	HighlandDesert = {
		"HighlandDesert::SaguaroTall",
		"HighlandDesert::BarrelCactusCluster",
		"HighlandDesert::DryBrushPatch",
		"HighlandDesert::SandstoneRockPile",
		"HighlandDesert::DuneGrassClump",
		"HighlandDesert::DeadwoodStump",
	},
	Marshland = {
		"Marshland::CypressTreeTwisted",
		"Marshland::MangroveCluster",
		"Marshland::ReedBedDense",
		"Marshland::LilyMudPatch",
		"Marshland::BogRockPile",
		"Marshland::DriftwoodStack",
	},
}

local function parseId(id: string): (string?, string?)
	local parts = string.split(id, "::")
	if #parts ~= 2 then
		return nil, nil
	end

	local biomeName = parts[1]
	local prefabName = parts[2]
	if biomeName == "" or prefabName == "" then
		return nil, nil
	end

	return biomeName, prefabName
end

local function buildPathCache()
	if ModuleByPathCache then
		return
	end

	local cache = {} :: { [string]: ModuleScript }
	if not PrefabsDatabase then
		ModuleByPathCache = cache
		return
	end

	for _, descendant in ipairs(PrefabsDatabase:GetDescendants()) do
		if descendant:IsA("ModuleScript") then
			local parts = {} :: { string }
			local current: Instance? = descendant
			while current and current ~= PrefabsDatabase do
				table.insert(parts, 1, current.Name)
				current = current.Parent
			end
			if current == PrefabsDatabase then
				local path = table.concat(parts, ".")
				cache[path] = descendant
			end
		end
	end

	ModuleByPathCache = cache
end

local function resolvePrefabModuleFromPath(prefabPath: string): ModuleScript?
	if prefabPath == "" then
		return nil
	end
	buildPathCache()
	if ModuleByPathCache then
		local cached = ModuleByPathCache[prefabPath]
		if cached then
			return cached
		end
	end

	if not PrefabsDatabase then
		return nil
	end

	local current: Instance = PrefabsDatabase
	for _, part in ipairs(string.split(prefabPath, ".")) do
		if part == "" then
			return nil
		end
		local nextNode = current:FindFirstChild(part)
		if not nextNode then
			return nil
		end
		current = nextNode
	end

	if current:IsA("ModuleScript") then
		return current
	end
	return nil
end

local function resolvePrefabModule(id: string): ModuleScript?
	local biomeName, prefabName = parseId(id)
	if not biomeName or not prefabName then
		return nil
	end

	return resolvePrefabModuleFromPath(string.format("%s.%s", biomeName, prefabName))
end

local function requireDefinitionModule(module: ModuleScript): PrefabDefinition?
	local ok, result = pcall(require, module)
	if not ok then
		warn(string.format("[PrefabRegistry] Failed requiring %s: %s", module:GetFullName(), tostring(result)))
		return nil
	end

	if type(result) ~= "table" or type(result.Id) ~= "string" then
		warn(string.format("[PrefabRegistry] Invalid prefab definition at %s", module:GetFullName()))
		return nil
	end

	local definition = result :: PrefabDefinition
	return definition
end

local function shouldExcludeDefinition(id: string): boolean
	return ExcludedPrefabIds[id] == true
end

local function loadDefinitionById(id: string): PrefabDefinition?
	if shouldExcludeDefinition(id) then
		return nil
	end

	local existing = DefinitionById[id]
	if existing then
		return existing
	end

	local module = resolvePrefabModule(id)
	if not module then
		return nil
	end

	local definition = requireDefinitionModule(module)
	if not definition then
		return nil
	end
	if shouldExcludeDefinition(definition.Id) then
		return nil
	end

	DefinitionById[definition.Id] = definition
	if definition.Id ~= id then
		DefinitionById[id] = definition
	end
	return definition
end

local function collectAllDefinitions(): { PrefabDefinition }
	if AllDefinitionsCache then
		return table.clone(AllDefinitionsCache)
	end

	local definitions = {} :: { PrefabDefinition }
	local seenIds = {} :: { [string]: boolean }

	if not PrefabsDatabase then
		AllDefinitionsCache = definitions
		return table.clone(definitions)
	end

	for _, descendant in ipairs(PrefabsDatabase:GetDescendants()) do
		if descendant:IsA("ModuleScript") then
			local definition = requireDefinitionModule(descendant)
			if definition and not shouldExcludeDefinition(definition.Id) then
				if seenIds[definition.Id] then
					warn(string.format("[PrefabRegistry] Duplicate prefab id '%s' at %s", definition.Id, descendant:GetFullName()))
				else
					seenIds[definition.Id] = true
					DefinitionById[definition.Id] = definition
					table.insert(definitions, definition)
				end
			end
		end
	end

	table.sort(definitions, function(a: PrefabDefinition, b: PrefabDefinition)
		return a.Id < b.Id
	end)
	AllDefinitionsCache = definitions
	return table.clone(definitions)
end

function PrefabRegistry.GetById(id: string): PrefabDefinition?
	return loadDefinitionById(id)
end

function PrefabRegistry.GetByPath(prefabPath: string): PrefabDefinition?
	local module = resolvePrefabModuleFromPath(prefabPath)
	if not module then
		return nil
	end

	local definition = requireDefinitionModule(module)
	if not definition then
		return nil
	end
	if shouldExcludeDefinition(definition.Id) then
		return nil
	end

	DefinitionById[definition.Id] = definition
	return definition
end

function PrefabRegistry.GetAll(): { PrefabDefinition }
	return collectAllDefinitions()
end

function PrefabRegistry.GetRuntimeNaturePool(biome: string): { string }
	local pool = RuntimeNaturePools[biome]
	if not pool then
		return {}
	end
	return table.clone(pool)
end

return table.freeze(PrefabRegistry)

