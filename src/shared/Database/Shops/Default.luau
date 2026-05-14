--!strict

local ShopConfig = {
	Title = "Camp Provisioner",
	Recipes = {
		{
			Id = "berries_bundle",
			Reward = {
				Kind = "InventoryItem",
				ItemId = "Berries",
				Quantity = 5,
			},
			Costs = {
				Coins = 12,
			},
		},
		{
			Id = "mushroom_bundle",
			Reward = {
				Kind = "InventoryItem",
				ItemId = "Mushroom",
				Quantity = 3,
			},
			Costs = {
				Coins = 14,
			},
		},
		{
			Id = "field_meat",
			Reward = {
				Kind = "InventoryItem",
				ItemId = "Meat",
				Quantity = 2,
			},
			Costs = {
				Coins = 20,
				Items = {
					{
						ItemKind = "InventoryItem",
						ItemId = "Berries",
						Quantity = 4,
					},
				},
			},
		},
		{
			Id = "adventurer_charm",
			Reward = {
				Kind = "InventoryItem",
				ItemId = "AdventurerCharm",
				Quantity = 1,
			},
			Costs = {
				Coins = 65,
				Items = {
					{
						ItemKind = "InventoryItem",
						ItemId = "Leather",
						Quantity = 2,
					},
					{
						ItemKind = "InventoryItem",
						ItemId = "Feather",
						Quantity = 3,
					},
				},
			},
		},
		{
			Id = "war_flag",
			Reward = {
				Kind = "Consumable",
				ItemId = "RedWarFlag",
				Quantity = 1,
			},
			Costs = {
				Coins = 90,
				Items = {
					{
						ItemKind = "InventoryItem",
						ItemId = "Wool",
						Quantity = 2,
					},
				},
			},
		},
		{
			Id = "rookie_sword",
			Reward = {
				Kind = "Weapon",
				WeaponPath = "Sword.Rookie",
				Quantity = 1,
			},
			Costs = {
				Coins = 120,
				Items = {
					{
						ItemKind = "InventoryItem",
						ItemId = "Leather",
						Quantity = 4,
					},
				},
			},
		},
	},
}

return table.freeze(ShopConfig)
