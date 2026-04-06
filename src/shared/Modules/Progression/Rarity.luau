--!strict

local Rarity = {
	CRUDE = "CRUDE",
	REFINED = "REFINED",
	EXALTED = "EXALTED",
	APEX = "APEX",
}

Rarity.Order = {
	Rarity.CRUDE,
	Rarity.REFINED,
	Rarity.EXALTED,
	Rarity.APEX,
}

return table.freeze(Rarity)
