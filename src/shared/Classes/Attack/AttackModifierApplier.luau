--!strict

export type AttackModifierApplier = {
	Apply: (self: AttackModifierApplier, attackContext: any) -> (),
	OnApplyMultipliers: (self: AttackModifierApplier, attackContext: any) -> (),
	OnCritRoll: (self: AttackModifierApplier, attackContext: any) -> (),
	OnAttackEnemy: (self: AttackModifierApplier, attackContext: any) -> (),
	OnDefeatEnemy: (self: AttackModifierApplier, attackContext: any) -> (),
	OnOncomingHit: (self: AttackModifierApplier, attackContext: any) -> (),
	OnShieldBlock: (self: AttackModifierApplier, attackContext: any) -> (),
	ProcureData: (self: AttackModifierApplier, attackContext: any) -> (),
	OnHitSuccess: (self: AttackModifierApplier, attackContext: any) -> (),
	OnProjectileExpire: (self: AttackModifierApplier, attackContext: any) -> (),
	OnWeaponSwap: (self: AttackModifierApplier, attackContext: any) -> (),

	__Attributes: { [string]: any },
}

return table.freeze({})
