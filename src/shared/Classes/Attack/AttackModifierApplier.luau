--!strict

export type AttackModifierApplier = {
	Id: string,
	Apply: (self: AttackModifierApplier, attackContext: any) -> (),
	OnApplyMultipliers: (self: AttackModifierApplier, attackContext: any) -> (),
	OnCritRoll: (self: AttackModifierApplier, attackContext: any) -> (),
	OnGiveMelee: (self: AttackModifierApplier, attackContext: any) -> (),
	OnRecieveMelee: (self: AttackModifierApplier, attackContext: any) -> (),
	OnGiveRanged: (self: AttackModifierApplier, attackContext: any) -> (),
	OnRecieveRanged: (self: AttackModifierApplier, attackContext: any) -> (),
	OnGiveMagic: (self: AttackModifierApplier, attackContext: any) -> (),
	OnRecieveMagic: (self: AttackModifierApplier, attackContext: any) -> (),
	OnAttackEnemy: (self: AttackModifierApplier, attackContext: any) -> (),
	OnDefeatEnemy: (self: AttackModifierApplier, attackContext: any) -> (),
	OnOncomingHit: (self: AttackModifierApplier, attackContext: any) -> (),
	OnShieldBlock: (self: AttackModifierApplier, attackContext: any) -> (),
	ProcureData: (self: AttackModifierApplier, attackContext: any) -> (),
	OnHitSuccess: (self: AttackModifierApplier, attackContext: any) -> (),
	OnProjectileExpire: (self: AttackModifierApplier, attackContext: any) -> (),
	OnWeaponSwap: (self: AttackModifierApplier, attackContext: any) -> (),
	Components: { [string]: any },
	__Attributes: { [string]: any },
}

export type HookName =
	"Apply"
	| "OnApplyMultipliers"
	| "OnCritRoll"
	| "OnGiveMelee"
	| "OnRecieveMelee"
	| "OnGiveRanged"
	| "OnRecieveRanged"
	| "OnGiveMagic"
	| "OnRecieveMagic"
	| "OnAttackEnemy"
	| "OnDefeatEnemy"
	| "OnOncomingHit"
	| "OnShieldBlock"
	| "ProcureData"
	| "OnHitSuccess"
	| "OnProjectileExpire"
	| "OnWeaponSwap"

local NOOP = function(_: AttackModifierApplier, _: any): ()
	return
end

local AttackModifierApplier = {}
AttackModifierApplier.__index = AttackModifierApplier

local DEFAULT_HOOKS: { [HookName]: (self: AttackModifierApplier, attackContext: any) -> () } = {
	Apply = NOOP,
	OnApplyMultipliers = NOOP,
	OnCritRoll = NOOP,
	OnGiveMelee = NOOP,
	OnRecieveMelee = NOOP,
	OnGiveRanged = NOOP,
	OnRecieveRanged = NOOP,
	OnGiveMagic = NOOP,
	OnRecieveMagic = NOOP,
	OnAttackEnemy = NOOP,
	OnDefeatEnemy = NOOP,
	OnOncomingHit = NOOP,
	OnShieldBlock = NOOP,
	ProcureData = NOOP,
	OnHitSuccess = NOOP,
	OnProjectileExpire = NOOP,
	OnWeaponSwap = NOOP,
}

function AttackModifierApplier.new(
	id: string?,
	hooks: { [string]: any }?,
	attributes: { [string]: any }?,
	components: { [string]: any }?
): AttackModifierApplier
	local self = setmetatable({}, AttackModifierApplier)
	local selfAny = self :: any

	selfAny.Id = id or "AttackModifier"
	selfAny.__Attributes = table.clone(attributes or {})
	selfAny.Components = table.clone(components or {})

	for hookName, callback in pairs(DEFAULT_HOOKS) do
		local override = hooks and hooks[hookName]
		selfAny[hookName] = if type(override) == "function" then override else callback
	end

	return selfAny :: AttackModifierApplier
end

function AttackModifierApplier.Call(self: AttackModifierApplier, hookName: HookName, attackContext: any): ()
	local hook = (self :: any)[hookName]
	if type(hook) == "function" then
		hook(self, attackContext)
	end
end

function AttackModifierApplier.GetHookNames(): { HookName }
	return {
		"Apply",
		"OnApplyMultipliers",
		"OnCritRoll",
		"OnGiveMelee",
		"OnRecieveMelee",
		"OnGiveRanged",
		"OnRecieveRanged",
		"OnGiveMagic",
		"OnRecieveMagic",
		"OnAttackEnemy",
		"OnDefeatEnemy",
		"OnOncomingHit",
		"OnShieldBlock",
		"ProcureData",
		"OnHitSuccess",
		"OnProjectileExpire",
		"OnWeaponSwap",
	}
end

return table.freeze(AttackModifierApplier)
