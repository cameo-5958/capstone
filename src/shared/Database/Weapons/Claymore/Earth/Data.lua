local ReplicatedStorage = game:GetService("ReplicatedStorage")

return {
	["Name"] = "Earthbender",
	["Type"] = "Claymore",
	["Family"] = "Greek",
	["Rarity"] = "Refined",
	["Icon"] = "rbxassetid://135113703476029",

	["BaseDamage"] = 113,
	["__Stats"] = {
		["Defense"] = 200,
		["Strength"] = 100,
	},
	["Weight"] = 11,
	["WeaponPassive"] = nil,
	["RightClickAbility"] = {
		Cooldown = 10,
		Execute = function(self, owner, _)
			local EnemyServiceServer = require(ReplicatedStorage.Services.Enemy.EnemyServiceServer)
			local ClassCombos = require(ReplicatedStorage.Database.Weapons.Default.Combos)
			local AnimationServiceServer = require(ReplicatedStorage.Services.Animation.AnimationServiceServer)

			-- Play the last animation in the Claymore combo chain
			local comboSet = ClassCombos["Claymore"]
			local attacks = comboSet.Combos["heavy_chain"].Attacks
			local lastAttack = attacks[#attacks]

			AnimationServiceServer.Animate(owner.UUID, lastAttack.AnimationId)

			-- Delay the shockwave hit for approximately 1 second
			task.wait(1)

			local SHOCKWAVE_RANGE = 22
			local origin = owner.RootPart.Position

			for _, target in pairs(EnemyServiceServer.GetInRadius(origin, SHOCKWAVE_RANGE)) do
				if target == owner then
					continue
				end

				-- Execute attack tick with Heavy flags and zero stamina consumption
				self:ExecuteAttack(target, 1.0, owner, {
					IsHeavy = true,
					DoesKnockback = true,
					AttackContext = { StaminaCost = 0 },
				})
			end
		end,
	},

	["Desc"] = "The Earthbender crushes foes and obliterates opponents while guaranteeing you'll never die. Its ability blasts enemies backwards, quaking the Earth to the core.",
}
