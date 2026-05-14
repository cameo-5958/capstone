--!strict

export type StructureFlatteningSettings = {
	Enabled: boolean,
	MaxHalfFootprintTiles: number,
	RingInnerPaddingTiles: number,
	RingOuterScale: number,
	TargetHeightBlend: number,
	SmoothingPasses: number,
	SmoothingBlend: number,
	PreservePathCells: boolean,
	ForceFlattenEnabled: boolean,
	ForceCorePaddingTiles: number,
	ForceCoreWeight: number,
	ForceRingTargetPercentile: number,
	ForceClampRisePerTile: number,
	ForceClampRadiusScale: number,
}

export type StructureAssemblyComponent = {
	DX: number,
	DZ: number,
	PrefabId: string,
	Required: boolean,
}

export type StructureAssemblyDefinition = {
	Id: string,
	Components: { StructureAssemblyComponent },
}

export type StructureAssemblyPlacementSettings = {
	Enabled: boolean,
	LockInEnabled: boolean,
	SearchRadiusTiles: number,
	AvoidPathCells: boolean,
	AvoidWaterCells: boolean,
}

export type ManualStructurePreviewSettings = {
	Enabled: boolean,
	StudioOnly: boolean,
	IncludeExecutorOnly: boolean,
	IncludeNature: boolean,
	IncludeStructures: boolean,
	IncludeMarkers: boolean,
	TileSize: number,
	SpacingStuds: number,
	GridOffsetStuds: number,
	HeightOffsetStuds: number,
}

export type TransitionCampPreviewSettings = {
	Enabled: boolean,
	StudioOnly: boolean,
	Position: Vector3,
	TileSize: number,
	Biome: string,
}

export type WorldStructureSettings = {
	ActiveProfile: string,
	RuntimeNatureChanceByBiome: { [string]: number },
	RuntimeNatureWeightsByBiome: { [string]: { number } },
	RuntimeNodeStructuresEnabled: boolean,
	RuntimeNodeStructureChance: number,
	RuntimeNodePoolByBiome: { [string]: { string } },
	RuntimeNodeWeightsByBiome: { [string]: { number } },
	RuntimeNodeSharedPool: { string },
	RuntimeNodeSharedWeights: { number },
	RuntimeNodeAssemblyPlacement: StructureAssemblyPlacementSettings,
	RuntimeNodeAssemblyDefinitions: { [string]: StructureAssemblyDefinition },
	RuntimeNodeAssemblyPoolByBiome: { [string]: { string } },
	RuntimeNodeAssemblyWeightsByBiome: { [string]: { number } },
	RuntimeNodeAssemblySharedPool: { string },
	RuntimeNodeAssemblySharedWeights: { number },
	ManualStructurePreview: ManualStructurePreviewSettings,
	TransitionCampPreview: TransitionCampPreviewSettings,
	StructureFlattening: StructureFlatteningSettings,
}

local Settings = {
	ActiveProfile = "BalancedSceneryV1",

	RuntimeNatureChanceByBiome = {
		Plains = 0.035,
		Forest = 0.095,
		Tundra = 0.06,
		Desert = 0.055,
		Mountain = 0.075,
	},

	RuntimeNatureWeightsByBiome = {
		Plains = { 10, 8, 38, 30, 8, 6 },
		Forest = { 30, 24, 17, 10, 7, 5, 4, 3 },
		Tundra = { 43, 31, 10, 7, 5, 4 },
		Desert = { 40, 32, 11, 7, 6, 4 },
		Mountain = { 44, 32, 9, 6, 5, 4 },
	},

	RuntimeNodeStructuresEnabled = false,
	RuntimeNodeStructureChance = 0.1,
	RuntimeNodePoolByBiome = {
		Plains = {
			"Shared::NodeFenceCamp",
			"Shared::LanternPostWood",
			"Shared::LanternPostIron",
			"Shared::ProduceCartStand",
			"Shared::StoneWellPlaza",
			"Shared::TravelerCampfireRing",
			"Shared::TreasureChestFieldCache",
			"Shared::TreasureChestCampStock",
			"Shared::TreasureChestCache",
			"Shared::NodeTentOutpost",
			"Shared::NodeLampSquare",
		},
		Forest = {
			"Shared::NodeFenceCamp",
			"Shared::LanternPostIron",
			"Forest::OvergrownStoneGate",
			"Shared::TravelerCampfireRing",
			"Shared::TreasureChestFieldCache",
			"Shared::TreasureChestCampStock",
			"Shared::TreasureChestCache",
			"Shared::NodeTentOutpost",
			"Shared::StoneWellPlaza",
		},
		Tundra = {
			"Shared::LanternPostIron",
			"Shared::NodeFenceCamp",
			"Shared::TravelerCampfireRing",
			"Shared::StoneWellPlaza",
			"Shared::TreasureChestFieldCache",
			"Shared::TreasureChestCampStock",
			"Shared::TreasureChestCache",
			"Shared::NodeTentOutpost",
			"Shared::NodeLampSquare",
		},
		Desert = {
			"Shared::NodeFenceCamp",
			"Shared::LanternPostWood",
			"HighlandDesert::OasisFireCamp",
			"Shared::TravelerCampfireRing",
			"Shared::TreasureChestFieldCache",
			"Shared::TreasureChestCampStock",
			"Shared::TreasureChestCache",
			"Shared::NodeTentOutpost",
			"Shared::StoneWellPlaza",
		},
		Mountain = {
			"Shared::NodeFenceCamp",
			"Shared::LanternPostWood",
			"Shared::StoneWellPlaza",
			"PineHighlands::WoodStoreLeanTo",
			"Shared::TravelerCampfireRing",
			"Shared::TreasureChestFieldCache",
			"Shared::TreasureChestCampStock",
			"Shared::TreasureChestCache",
			"Shared::NodeTentOutpost",
			"Shared::NodeLampSquare",
		},
	},
	RuntimeNodeWeightsByBiome = {
		Plains = { 19, 14, 12, 13, 12, 12, 6, 5, 4, 8, 10 },
		Forest = { 18, 12, 10, 16, 5, 4, 4, 10, 9 },
		Tundra = { 16, 12, 14, 14, 5, 4, 4, 10, 8 },
		Desert = { 16, 11, 18, 15, 4, 5, 4, 10, 10 },
		Mountain = { 18, 12, 12, 11, 16, 5, 5, 4, 9, 12 },
	},
	RuntimeNodeSharedPool = {
		"Shared::NodeFenceCamp",
		"Shared::LanternPostWood",
		"Shared::LanternPostIron",
		"Shared::TravelerCampfireRing",
		"Shared::ProduceCartStand",
		"Shared::StoneWellPlaza",
		"Shared::TreasureChestFieldCache",
		"Shared::TreasureChestCampStock",
		"Shared::TreasureChestCache",
		"Shared::NodeTentOutpost",
		"Shared::NodeLampSquare",
	},
	RuntimeNodeSharedWeights = { 16, 14, 12, 16, 12, 14, 6, 5, 4, 10, 10 },

	RuntimeNodeAssemblyPlacement = {
		Enabled = true,
		LockInEnabled = true,
		SearchRadiusTiles = 5,
		AvoidPathCells = true,
		AvoidWaterCells = true,
	},

	RuntimeNodeAssemblyDefinitions = {
		["Shared::CampHub"] = {
			Id = "Shared::CampHub",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Shared::NodeTentOutpost", Required = true },
				{ DX = 10, DZ = 0, PrefabId = "Shared::TravelerCampfireRing", Required = true },
				{ DX = -11, DZ = 1, PrefabId = "Shared::NodeFenceCamp", Required = true },
				{ DX = -8, DZ = -8, PrefabId = "Shared::TreasureChestCampStock", Required = false },
				{ DX = 8, DZ = -8, PrefabId = "Shared::NodeLampSquare", Required = false },
				{ DX = -10, DZ = -9, PrefabId = "Shared::LanternPostWood", Required = false },
			},
		},
		["Shared::UtilitySquare"] = {
			Id = "Shared::UtilitySquare",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Shared::StoneWellPlaza", Required = true },
				{ DX = 10, DZ = 0, PrefabId = "Shared::NodeLampSquare", Required = true },
				{ DX = -10, DZ = 0, PrefabId = "Shared::NodeFenceCamp", Required = true },
				{ DX = 0, DZ = 10, PrefabId = "Shared::LanternPostIron", Required = false },
				{ DX = 0, DZ = -10, PrefabId = "Shared::ProduceCartStand", Required = false },
			},
		},
		["Shared::VillageCrossing"] = {
			Id = "Shared::VillageCrossing",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Shared::StoneWellPlaza", Required = true },
				{ DX = 10, DZ = 0, PrefabId = "Shared::NodeLampSquare", Required = true },
				{ DX = -10, DZ = 0, PrefabId = "Shared::ProduceCartStand", Required = true },
				{ DX = 0, DZ = 10, PrefabId = "Shared::LanternPostIron", Required = false },
				{ DX = 0, DZ = -10, PrefabId = "Shared::TravelerCampfireRing", Required = false },
				{ DX = -10, DZ = -10, PrefabId = "Shared::TreasureChestFieldCache", Required = false },
			},
		},
		["Shared::TownCluster"] = {
			Id = "Shared::TownCluster",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Shared::CobbleHouseA", Required = true },
				{ DX = 14, DZ = -2, PrefabId = "Shared::CobbleHouseB", Required = true },
				{ DX = -14, DZ = 2, PrefabId = "Shared::TownhouseNarrow", Required = true },
				{ DX = 0, DZ = 14, PrefabId = "Shared::StoneWellPlaza", Required = false },
				{ DX = -12, DZ = -12, PrefabId = "Shared::NodeLampSquare", Required = false },
				{ DX = 12, DZ = 12, PrefabId = "Shared::TravelerCampfireRing", Required = false },
			},
		},
		["TemperateGrassland::FarmsteadCluster"] = {
			Id = "TemperateGrassland::FarmsteadCluster",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "TemperateGrassland::FieldstoneCottage", Required = true },
				{ DX = 15, DZ = 1, PrefabId = "TemperateGrassland::BarnLeanTo", Required = true },
				{ DX = -14, DZ = 3, PrefabId = "TemperateGrassland::FarmPlotRows", Required = true },
				{ DX = 8, DZ = -12, PrefabId = "TemperateGrassland::StoneWellFence", Required = false },
				{ DX = -10, DZ = -12, PrefabId = "TemperateGrassland::WindmillShed", Required = false },
				{ DX = 0, DZ = 14, PrefabId = "Shared::TravelerCampfireRing", Required = false },
			},
		},
		["PineHighlands::LookoutCamp"] = {
			Id = "PineHighlands::LookoutCamp",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "PineHighlands::PrayerCairnShelter", Required = true },
				{ DX = 10, DZ = 0, PrefabId = "PineHighlands::WoodStoreLeanTo", Required = true },
				{ DX = -10, DZ = 2, PrefabId = "Shared::TravelerCampfireRing", Required = true },
				{ DX = 0, DZ = -10, PrefabId = "Shared::TreasureChestCampStock", Required = false },
				{ DX = 10, DZ = -10, PrefabId = "Shared::NodeFenceCamp", Required = false },
			},
		},
		["Forest::RangerCamp"] = {
			Id = "Forest::RangerCamp",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Forest::RangerCabin", Required = true },
				{ DX = 11, DZ = 2, PrefabId = "Forest::ForagerSupplyCamp", Required = true },
				{ DX = -11, DZ = -2, PrefabId = "Forest::CampfireShelter", Required = true },
				{ DX = 0, DZ = -10, PrefabId = "Shared::TravelerCampfireRing", Required = true },
				{ DX = 10, DZ = 10, PrefabId = "Shared::TreasureChestFieldCache", Required = false },
			},
		},
		["Forest::HideoutCluster"] = {
			Id = "Forest::HideoutCluster",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Forest::BanditShack", Required = true },
				{ DX = 12, DZ = 2, PrefabId = "Forest::HiddenHunterHut", Required = true },
				{ DX = -12, DZ = -2, PrefabId = "Forest::OvergrownStoneGate", Required = false },
				{ DX = 0, DZ = -10, PrefabId = "Shared::TravelerCampfireRing", Required = true },
				{ DX = 11, DZ = 10, PrefabId = "Shared::TreasureChestCache", Required = false },
			},
		},
		["Alpine::SummitOutpost"] = {
			Id = "Alpine::SummitOutpost",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Alpine::ObservatoryHut", Required = true },
				{ DX = 12, DZ = 0, PrefabId = "Alpine::RopeLiftStation", Required = true },
				{ DX = -10, DZ = 3, PrefabId = "Shared::TravelerCampfireRing", Required = true },
				{ DX = 0, DZ = -11, PrefabId = "Shared::StoneWellPlaza", Required = false },
			},
		},
		["HighlandDesert::OasisCluster"] = {
			Id = "HighlandDesert::OasisCluster",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "HighlandDesert::CaravanShelter", Required = true },
				{ DX = 10, DZ = 2, PrefabId = "HighlandDesert::OasisFireCamp", Required = true },
				{ DX = -10, DZ = -2, PrefabId = "HighlandDesert::SandstoneShrine", Required = true },
				{ DX = 0, DZ = -11, PrefabId = "Shared::TravelerCampfireRing", Required = true },
				{ DX = 11, DZ = 9, PrefabId = "Shared::TreasureChestCache", Required = false },
			},
		},
		["Marshland::StiltCamp"] = {
			Id = "Marshland::StiltCamp",
			Components = {
				{ DX = 0, DZ = 0, PrefabId = "Marshland::BogShack", Required = true },
				{ DX = 12, DZ = 2, PrefabId = "Marshland::StiltHut", Required = true },
				{ DX = -12, DZ = -2, PrefabId = "Marshland::TotemPlatform", Required = true },
				{ DX = 0, DZ = -10, PrefabId = "Shared::TravelerCampfireRing", Required = true },
				{ DX = 10, DZ = 10, PrefabId = "Shared::TreasureChestFieldCache", Required = false },
			},
		},
	},

	RuntimeNodeAssemblyPoolByBiome = {
		Plains = {
			"Shared::UtilitySquare",
			"Shared::VillageCrossing",
			"Shared::CampHub",
			"TemperateGrassland::FarmsteadCluster",
			"Shared::TownCluster",
		},
		Forest = { "Shared::CampHub", "Shared::UtilitySquare", "Shared::VillageCrossing", "Forest::HideoutCluster" },
		Tundra = { "Shared::CampHub", "Shared::UtilitySquare", "Shared::VillageCrossing", "Alpine::SummitOutpost" },
		Desert = { "Shared::CampHub", "Shared::UtilitySquare", "Shared::VillageCrossing", "HighlandDesert::OasisCluster" },
		Mountain = { "Shared::CampHub", "Shared::UtilitySquare", "Shared::VillageCrossing", "PineHighlands::LookoutCamp" },
	},

	RuntimeNodeAssemblyWeightsByBiome = {
		Plains = { 36, 26, 18, 12, 8 },
		Forest = { 36, 24, 18, 10 },
		Tundra = { 36, 24, 18, 10 },
		Desert = { 36, 24, 18, 10 },
		Mountain = { 36, 24, 18, 10 },
	},

	RuntimeNodeAssemblySharedPool = { "Shared::CampHub", "Shared::UtilitySquare", "Shared::VillageCrossing", "Shared::TownCluster" },
	RuntimeNodeAssemblySharedWeights = { 34, 28, 24, 14 },

	ManualStructurePreview = {
		Enabled = true,
		StudioOnly = true,
		IncludeExecutorOnly = true,
		IncludeNature = false,
		IncludeStructures = false,
		IncludeMarkers = false,
		TileSize = 8,
		SpacingStuds = 32,
		GridOffsetStuds = 84,
		HeightOffsetStuds = 8,
	},

	TransitionCampPreview = {
		Enabled = false,
		StudioOnly = true,
		Position = Vector3.new(0, 260, 0),
		TileSize = 6,
		Biome = "Mountain",
	},

	StructureFlattening = {
		Enabled = true,
		MaxHalfFootprintTiles = 24,
		RingInnerPaddingTiles = 1,
		RingOuterScale = 3.2,
		TargetHeightBlend = 0.15,
		SmoothingPasses = 3,
		SmoothingBlend = 0.55,
		PreservePathCells = false,
		ForceFlattenEnabled = true,
		ForceCorePaddingTiles = 4,
		ForceCoreWeight = 7.5,
		ForceRingTargetPercentile = 0.16,
		ForceClampRisePerTile = 0.35,
		ForceClampRadiusScale = 5.2,
	},
} :: WorldStructureSettings

return table.freeze(Settings)


