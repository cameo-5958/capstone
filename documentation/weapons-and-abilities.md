# Weapons and Abilities

## 1. Purpose

This system defines weapon data, equip/loadout synchronization, passive combat hooks, and ability activation.

Primary modules:

- `src/shared/Classes/Weapon/WeaponTypes.luau`
- `src/shared/Classes/Weapon/Weapon.luau`
- `src/shared/Classes/Weapon/WeaponPassive.luau`
- `src/shared/Services/Weapon/WeaponServiceServer.luau`
- `src/shared/Services/Weapon/WeaponServiceClient.luau`
- Combat execution path via `src/shared/Services/Attack/AttackServiceServer.luau` and `AttackServiceClient.luau`

## 2. Weapon Model

## 2.1 Weapon Runtime Object

A `Weapon` contains:

- Identity: `UUID`, `Name`, `WeaponId`, `Rarity`, `Class`, `Type`
- Combat data: `BaseDamage`, `AttackProfile`, `AttackContext`, `Weight`
- Stat grants: `GrantedStats`
- Passive behavior: `WeaponPassive`, `PassiveDetails`
- Ability behavior: `WeaponAbility` / `RightClickAbility`
- Tool refs: `ToolTemplate`, `ToolInstance`

Rarity normalization:

- Empty rarity defaults to `CRUDE`
- `COMMON` is normalized to `CRUDE`
- Other values are uppercased

## 2.2 Attack Profile

Attack timing and hitbox data:

- `AnimationId`
- `Windup`
- `ActiveDuration`
- `Recovery`
- `Cooldown`
- `HitReset`
- `HitboxSize`
- `HitboxOffset`

Default profile is merged when custom fields are absent.

## 2.3 Attack Context

Weapon-level contextual values include (non-exhaustive):

- `SightRange`, `SwingRange`, `MaxDashRange`
- `ManaCost`, `StaminaCost`, `Range`
- Optional lunge/lock timing fields

`Weapon:GetAttackContext()` returns a cloned table.

## 3. Abilities

## 3.1 Definition

Ability callback type:

```luau
(self, owner: Entity, context: { [string]: any }?) -> ()
```

Assigned through constructor as `weaponAbility` or `rightClickAbility`.

## 3.2 Invocation Path

Client:

- `WeaponServiceClient.UseAbility(payload)` -> RemoteEvent `UseAbility`

Server:

- `WeaponServiceServer` resolves player entity and equipped weapon
- Calls `equipped:UseRightClick(entity, payload)`

Weapon:

- `UseRightClick` returns `false` if owner/ability missing
- Otherwise executes callback and returns `true`

## 4. Passives and Attack Hooks

## 4.1 AttackModifierApplier Contract

Passives use `AttackModifierApplier` objects with standardized hook names:

- `Apply`
- `OnApplyMultipliers`
- `OnCritRoll`
- `OnGiveMelee` / `OnRecieveMelee`
- `OnGiveRanged` / `OnRecieveRanged`
- `OnGiveMagic` / `OnRecieveMagic`
- `OnAttackEnemy`, `OnDefeatEnemy`, `OnOncomingHit`
- `OnShieldBlock`, `ProcureData`, `OnHitSuccess`
- `OnProjectileExpire`, `OnWeaponSwap`

Missing hooks default to no-op.

## 4.2 Passive Definition Helper

`WeaponPassive.new(...)` returns:

- `Applier`: attack hook runtime
- `Metadata`: normalized display data (`Id`, `Kind`, `Tag`, etc.)

## 4.3 Equip Lifecycle

When equip state changes, `WeaponServiceServer`:

1. Removes old granted stat modifiers from source `weapon:equipped`
2. Removes prior passive by stored passive ID
3. Applies new weapon `GrantedStats` as `BaseFlat` modifiers
4. Registers new `WeaponPassive` on entity attack hook list

## 5. Loadout and Sync Architecture

## 5.1 Authority

Server is authoritative for:

- Equipped slot
- Toolbar contents
- Granted stat modifiers
- Passive registration

## 5.2 Client State

`WeaponServiceClient` stores:

- `EquippedWeaponData`
- `LoadoutData`

And exposes signals:

- `GetEquippedWeaponChangedSignal()`
- `GetLoadoutChangedSignal()`

Initial sync is requested with deferred remote calls:

- `RequestEquippedWeapon`
- `RequestLoadout`

## 5.3 Server Remote Actions

Accepted actions on `WeaponEndpoint`:

- `UseAbility`
- `EquipSlot`
- `EquipInventoryEntry`
- `UnequipSlot`
- `Unequip`
- `RequestEquippedWeapon`
- `RequestLoadout`

## 6. Primary Attack Execution (Combat Path)

Although abilities are right-click callbacks, basic attacks run through `AttackService`.

Server flow (`AttackServiceServer`):

1. Validate rate limit (`NextAttackAt`) and entity/weapon alive state.
2. Resolve combo attack definition (class-based combos where available).
3. Merge profile/context overrides per combo and hit windows.
4. Register active attack windows and broadcast `AttackStarted` to client.
5. On client hit reports, validate target, timing window, and hitbox containment.
6. Execute weapon attack via `Weapon:ExecuteAttack(...)`.
7. `Damage` module builds/executes `AttackContext` and applies damage/hook effects.

Client flow (`AttackServiceClient`):

1. Sends `RequestPrimaryAttack`.
2. Tracks active attack windows from server payload.
3. Performs overlap checks in active window.
4. Sends `ReportHit` for candidate targets (with per-target hit reset control).

## 7. Bow Charge Ability Path

`AttackService` also handles bow charge actions:

- `BeginBowCharge`
- `ReleaseBowCharge`

On release, server computes charge scaling and fires an arrow projectile with configured speed/range/gravity/radius.

## 8. Integration with Modifiers

Weapons should not mutate entity stat snapshots directly.

Correct pattern:

- Use `Entity:AddModifier` with stable IDs and source tagging.
- Remove via modifier handle or `RemoveModifiersFromSource`.

`WeaponServiceServer` already enforces this pattern for equipped weapon stat grants.

## 9. Extension Guidelines

## 9.1 Adding a New Weapon

1. Provide `Weapon.new(...)` data (class, profile, attack context, stats).
2. Optionally attach passive via `WeaponPassive.new(...)` or applier object.
3. Optionally attach ability callback for right-click behavior.
4. Ensure serialized weapon data contains stable `WeaponId` for loadout logic.

## 9.2 Adding a New Passive

1. Implement only required hooks; others can be omitted.
2. Keep passive metadata separate from runtime logic.
3. Ensure passive `Id` is stable for removal by `RemoveAttackModifierById`.

## 9.3 Safety Constraints

- Keep all equip-side effects reversible.
- Avoid side effects in client-only weapon state.
- Treat server as source of truth for combat and loadout.
