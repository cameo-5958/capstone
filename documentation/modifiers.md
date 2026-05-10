# Modifiers System

## 1. Purpose

The Modifiers system provides deterministic, composable runtime stat mutation for entities.

It supports:

- Flat and additive stat changes
- Multiplicative scaling
- Source-based cleanup
- Per-stat and global stat-change signals

Primary implementation:

- `src/shared/Classes/Modifier/ModifierType.luau`
- `src/shared/Classes/Modifier/Modifier.luau`
- `src/shared/Classes/Modifier/Stat.luau`
- `src/shared/Classes/Modifier/StatBlock.luau`
- Entity integration in `src/shared/Classes/Entity/Entity.luau`

## 2. Core Data Model

### 2.1 Modifier Kinds

`ModifierKind` is one of:

- `BaseFlat`
- `BaseAdditive`
- `FinalAdditive`
- `Multiplicative`
- `FinalFlat`

### 2.2 Modifier Shape

```luau
{
  Id: string,
  Type: ModifierKind,
  Value: number,
  Source: string?
}
```

`Id` must be unique within a stat bucket; later inserts with the same ID replace prior entries.

### 2.3 Runtime Layering

- `Stat` manages one numeric stat and its modifier buckets.
- `StatBlock` manages many `Stat` instances and relays change events.
- `Entity` owns a `StatBlock` runtime state and exposes gameplay-facing APIs.

## 3. Calculation Order

For one stat, final value is:

```text
final = ((base + sum(BaseFlat)) * (1 + sum(BaseAdditive)) * (1 + sum(FinalAdditive)) * product(Multiplicative)) + sum(FinalFlat)
```

Then optional finalize callback is applied.

Notes:

- `Multiplicative` bucket defaults to 1 when empty.
- Additive buckets default to `1 + 0`.
- Recalculation is cached and only recomputed when dirty.

## 4. API Surface

## 4.1 Modifier Factory

`Modifier.new(id, modifierType, value, source?) -> Modifier`

Use for creating payloads passed into `Entity:AddModifier(...)`.

## 4.2 Stat API

Key methods:

- `SetBaseValue(value)`
- `GetBaseValue()`
- `AddModifier(modifier)`
- `RemoveModifier(modifierId)`
- `RemoveAllFromSource(source)`
- `GetFinalValue()`
- `Recalculate()`

Change signal:

- `stat.Changed:Fire(newValue, oldValue, statName)` when value changed.

## 4.3 StatBlock API

Key methods:

- `Get(statName)`
- `GetBase(statName)`
- `SetBase(statName, value)`
- `AddModifier(statName, modifier) -> ModifierHandle`
- `RemoveModifier(statName, modifierId)`
- `RemoveHandle(handle)`
- `RemoveAllFromSource(source)`

Signals:

- `StatBlock.Changed:Fire(statName, newValue, oldValue)`

## 4.4 Entity Integration API

Gameplay entry points on `Entity`:

- `AddModifier(stat, modifier)`
- `RemoveModifier(stat, modifierId)`
- `RemoveModifierHandle(handle)`
- `RemoveModifiersFromSource(source)`
- `RegisterBuffHandles(source, handles)`
- `ClearBuffSource(source)`

Additional behavior:

- Health/Mana/Stamina setters clamp against max stats.
- Max stat updates also clamp current resource values.

## 5. Source Tracking and Cleanup

`Source` enables bulk removal and lifecycle safety.

Recommended source naming:

- `weapon:<weaponId>`
- `buff:<buffName>`
- `class:<className>`

Cleanup patterns:

- Remove single handle with `RemoveModifierHandle`.
- Remove all from source with `RemoveModifiersFromSource`.
- Group temporary handles with `RegisterBuffHandles` + `ClearBuffSource`.

## 6. Operational Semantics

- Any modifier mutation marks stat dirty and triggers recomputation.
- Signals fire only when value changes.
- Unknown modifier types assert at insert time.
- Unknown stat access asserts in `GetStatObject`.

## 7. Best Practices

- Treat modifiers as the only runtime path for temporary or equipment stat changes.
- Keep modifier IDs deterministic for reliable replacement and cleanup.
- Always include `Source` for non-permanent effects.
- Avoid direct mutation of `entity.__Stats` tables.

## 8. Common Failure Modes

- Missing `Source` prevents safe bulk cleanup.
- Reusing IDs unintentionally overwrites another modifier.
- Writing to raw stat snapshot bypasses runtime recalculation/signals.
