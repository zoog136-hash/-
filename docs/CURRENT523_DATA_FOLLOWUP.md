# Original data follow-up

Base main: `5db920332` (includes the merged data271 and integration269 lanes).
The original private inputs, saved identities and existing ownership services
remain unchanged. No tests, compilation, parsing command, game, rendering or
CI was started. All changes below are unexecuted/unverified.

## Existing Orim execution input

The original dungeon projection already supplied stages but its bootstrap
called an optional execution reader whose missing sidecar left NPC definitions,
group members and item effects empty. Existing `dungeon_play_service` reads
those dictionaries for its actor and item paths and holds when they are empty.

Only the original bootstrap now permits `_load_execution(directory,true)` to
read the held archive when the optional sidecar is actually not found. The
default argument stays false for installed/explicit pack readers. Present bad
files, access errors and already held definitions are preserved without a new
input choice. No sidecar, installer, new source pack or save file is written.

`_original_execution_input()` ports the selection in the existing public
`tools/build_orim523_execution.py`: the two original item IDs and their entire
ItemBonus/Bonus/BonusType relations, OrimsTrailNpc roles, original group members,
NPCs scoped by those roles and actual OrimsTrailSpawn groups, their full attacks,
and only their selected supporting description rows. The source rows and order
remain intact. Descriptions stay lower priority outside this existing support.

The actual canonical in-memory bytes must match one of the established execution
model fingerprints before the existing reader publishes its dictionaries.
The source ZIP identity is separate from the model SHA/bytes, recorded in
`execution_input_identity`. Source-declared exclusions or selected test inputs
hold the optional model, rather than filtering rows to obtain a different hash.
The existing optional installed model path keeps its original fingerprints.

The unchanged existing consumers are `rules.orim_actor_types`, `orim_groups`,
`orim_item_effects` and `orim_actor_defs`. This input adds no dungeon activation,
spawn rule, NPC combat formula, probability, reward, physical quantity, receipt
or save owner. Original actor identities and pixels remain separate existing
contracts. A future runtime hash rejection or unavailable input is a hold,
not successful adoption. No whole table, source-byte or gameplay-use completion
count is asserted by this code.

## Original preparation-buff speed inputs

The existing `dungeon_play_service.modifier(stat)` now calls
`rules.original_orim_speed_input(buff_id,stat)` for its already supported three
preparation buffs. The helper reads exact current OrimsTrailBuff→BuffClass→
BuffBonus→Bonus/BonusType/Unit relations through the existing original readers.
Only a unique unconditional MoveSpeedBonus or AttackSpeedBonus in Percentage
units is accepted. It reuses the existing 10,000-raw-per-percentage-point
conversion. Unavailable/ambiguous/conditional data preserves the prior host
input; explicit source exclusions produce no contribution.

The original values feed the existing operand only while the corresponding
host setting has its existing default. Custom speed/pearl settings stay
unchanged and remain host overrides. The source/input evidence cache is tied
to the actual archive identity and is not saved. Existing purchase, owned-buff
state, duration, stacking/addition, reroll, status, animation, quantity and save
logic is unchanged. In particular the source RunSpritePoint branches are not
reinterpreted or activated, and this is not complete native buff behavior.

The first source-read command failed before execution with an exec-server
transport disconnection. After the environment provider reported current
connected/running state, that read was retried once and succeeded. No source,
save or existing local change was deleted. No validation/execution suite was
started. Model/reasoning configuration is not exposed by the available tools;
Sol6.1 medium therefore remains requested, not independently confirmed here.

## Local actor original attribute operands

The existing Orim actor path supplied HP/MP/AC/MR and attack dice but did not
provide the six source base attributes used by the existing guardian/status
reducers. It now constructs `current523_actor_attribute_input.orim()` from the
actual selected source NPC, stage and full spawn row before `Monster.setup()`.
The descriptor requires the same pinned archive, unique current stage/spawn/
NpcClass rows, direct NpcClassID or one exact NpcClassForNpcGroup membership,
source exclusions/TestNPC and all six nonnegative integer source attributes.
No NPC is discovered/selected, no name/Sprite/numeric namespace is inferred.

Monster independently reconstructs and compares that descriptor before keeping
its six scalar operands for this life. The new operand has no source_m_* or
native admission marker. Native source_m_original data keeps precedence; only
an otherwise local actor's existing attribute getter uses this verified local
numeric input. Guardian's existing STR/DEX/CON/WIS/CHA/INT reducer then reads
the same data for attribute changes and its existing accuracy/damage/maxHP/MR/
AC deltas. Its formulas and status modifiers are unchanged. A pooled setup
clears the input after retiring old effects; rejected spawns clear it as well.

This does not claim an original Orim encounter, map, placement, actor identity
or original pixels. The existing local visual adapter remains a separate
unresolved admission/presentation boundary. HP/MP/AC/MR/attack-dice assignment,
difficulty factors, rewards, save state, issued tokens and restore behavior are
unchanged. The descriptor/cache is not persisted; restore rebuilds it only
from the exact held original relation. Missing/ambiguous/changed source keeps
the previous no-input behavior. No test/compile/game/render/CI was run.

## Existing equipment percentage operands

The current native DTO preserves CastSpeedBonus and EinasadSavingPercent as
unhandled source bonuses, while actual equipment consumers already exist.
`ItemOptions.additional_original_percent(record,key)` now supplies those
missing base operands from current ItemClass→ItemBonus→Bonus→BonusType→Unit.
It requires the exact native DTO/archive/full original row, mapped equipment,
existing base ID, non-Test/non-dummy and a direct non-possession Percentage
effect. Conditional/unknown data does not supply an operand. It uses the same
10,000-raw-per-percentage-point conversion as the existing projections.

The actual calls are World._equipment_inven_sum("castSpeed") (under its existing
cast-speed consumer policy) and AinOptionRules.reduction_percent(record).
Explicit typed operands/aliases keep precedence. Already represented source
bonus IDs are never counted again; a marked existing enhancement overlay can
retain its value alongside an otherwise missing original base contribution.
Legacy sourceOptions handling and the existing caps/formulas stay intact.

DTO/source-unhandled markers, registration, equipment/ownership, quantity and
save fingerprints are not rewritten by this read adapter. Runtime source
input evidence is separate from adoption/counting. This adds actual original
numeric inputs to established consumers, not a new effect or save engine.
It remains uncompiled/unexecuted/unverified and does not complete the item
or Bonus tables. No source rows/packs/saves or images were published.

The same guarded original reader now also supplies HPPlusPercent and
MPPlusPercent to the existing maximum-HP and maximum-MP equipment consumers.
Their source unit must be ValuePercent; raw/100 produces the ratio expected
by these existing formulas, as in the existing original capacity-skill reader.
This is distinct from Percentage fixed-point cast/blessing operands. Existing
explicit fields, mapped bonus IDs and enhancement overlays retain the same
precedence rules. Maximum-resource calculations change only by the missing
original equipment operand; no healing, mana granting, ownership, equipment
transaction, storage or save migration is introduced. Runtime evidence records
the unit and divisor separately. These additions are likewise unverified.

Existing equipment input calls also read direct Percentage StrengthScale,
DexterityScale and IntelligenceScale in _effective_attribute(),
HPHealIncreasePercent in SkillService's existing healing multiplier, and
PoisonDamageReductionPercent in _source_dot_damage(). These use the same
original-row and mapped-bonus safeguards and the existing enhancement reader's
10,000 conversion. Existing attribute basis/rounding and permitted DoT channel
policies remain authoritative. This supplies missing base-item operands to
those established calls; it does not add a new status, healing spell, resistance
namespace or policy. Conditional/possession effects are still not interpreted.

Direct MeleeDamageReductionPercent, RangeDamageReductionPercent and
MagicDamageReductionPercent also feed the existing attack-style branch of
World._pve_reduction_percent(). Each original operand stays in its corresponding
melee/ranged/magic channel with the preexisting caps and ordering. No PvP effect
is projected into PvE by this addition, and no conditional application target
is inferred. Existing extra-equipment and status contributions stay separate.

MeleeCriticalResist and RangeCriticalResist likewise supply missing direct
Percentage operands to _critical_resistance_stat() through its established
equipment sum. They retain distinct attack styles and do not create a magical
critical-resistance interpretation. Existing critical rolls and formulas stay
unchanged. All new percentage operands remain uncompiled and unexecuted.

## Existing equipment evasion and critical operands

The same current-original guard is shared by
ItemOptions.additional_original_flat(record,key). Direct non-possession
MeleeEvasion and RangeEvasion with Unit.Value feed _record_dg/_record_er;
MeleeCritical, RangeCritical and MagicCritical with Unit.ValuePercent feed the
existing attack-style branch of _record_critical_bonus. These are integer raw
operands without a fixed-point conversion, matching the existing enhancement
projection. Evasion takes a rating; critical takes percentage points, unlike
the hpPct/mpPct ratio consumers of the same ValuePercent source unit.
Existing typed fields/aliases and mapped bonus IDs
retain precedence; an existing marked enhancement overlay can add its separate
value. A generic explicit crit/critical_rate alias also blocks a missing-base
fallback when it is not an enhancement overlay. No source namespace, critical
roll, chance cap, evasion formula, physical ownership or save field is added.

Native RegenHP/RegenMP/AbsoluteRegenHP/AbsoluteRegenMP and AttackDrainHP/MP
already have the merged native passive-item consumer. This follow-up reuses
that owner and does not add another regeneration/drain interpretation.
All additional evasion/critical calls are uncompiled/unexecuted/unverified.

## Existing general combat and potion inputs

Direct Percentage DamageReductionPercent/PVEDamageReductionPercent feed the
existing general PvE reduction operand; no PvP-only bonus is included.
PierceDamageReductionPercent/PVEPierceDamageReductionPercent feed the existing
cached damage_amp_pct operand. The latter follows the preexisting enhancement
projection and host damage-amplification ordering/cap; it is not a claim that
the original tables establish TWILIGHT's combat formula. Both source types in
each pair retain their actual ItemBonus/Bonus evidence and the shared guards.

PotionConsumeDelayDecreasePercent supplies the existing HP-potion shared
cooldown input, including _source_hp_potion_parameters() used by the verified
native dice consumer and the older _use_healing_item calculation. Its unit is
Percentage with raw/10000 percentage points. Existing growth/enhancement
contributions, the host cooldown base, clamps, source physical owner and final
atomic save are unchanged. No MP/other-consumable delay interpretation is
introduced and the whole original bonus/table is not marked adopted.
These changes are likewise uncompiled/unexecuted/unverified.

## Existing status hit and resistance inputs

ItemOptions.additional_original_status(record,status,kind) reads the current
original ItemBonus→Bonus→BonusType→Unit relation for HitSpecialResistance or
SpecialResistance. In addition to the shared exact-native-row safeguards, it
requires BonusApplicationType 2 to explicitly declare SpecialResistanceType,
then resolves the actual BonusApplicationTargetID through that original table.
Only the declared Stun/Hold/Fear/Poison/Silence names enter their corresponding
existing status consumers. No target ID, namespace, status name, possession
effect or immunity is inferred. The source unit must be Percentage and the
existing enhancement conversion raw/10000 supplies percentage points.

The five existing World status-accuracy sums and five corresponding resistance
sums now call this reader alongside their existing record operand. Typed and
legacy aliases retain precedence; existing enhancement overlays and mapped
bonus IDs remain separate. No bleed mapping or universal resistance is added.
The current character attributes, caps, active-item and collection modifiers,
guardian/skill contributions and status-success formulas are unchanged. This
does not implement additional source status effects or change actor/save
ownership. These ten caller connections remain uncompiled and unexecuted.

## Existing elemental combat inputs

ItemOptions.additional_original_element(record,channel,kind,channels) supplies
base-item ElementalDamage Value operands to the existing separate flat-element
damage call and ElementalResistance Percentage operands to the existing player
elemental-resistance call. BonusApplicationType 3 must itself declare
ElementalResistanceType. That foreign table is absent in the held source;
the reader does not create it or claim a new recovered enum. It reuses the
already published enhancement policy's exact source-earring/official-name
channel mapping for targets 1–4, and the existing equipment523 set-effect
target-5 contract for whole-element resistance. Evidence records that consumer
mapping separately from original rows. Ambiguous/unsupported mapping is not
used. Whole-element input is limited to fire/water/wind/earth.

Original amounts and units remain separate: flat elemental damage has no
fixed-point conversion, resistance uses raw/10000 percentage points. Existing
normal/spell scope, target resistance, rounding, damage order and resistance
caps remain the host policy. Existing fields, overlays, original mapped IDs,
possession exclusions and native-row identity guards stay in force. No weapon
enchantment, extra hit, new element, guessed pixel/actor or save is created.
These caller connections are uncompiled/unexecuted/unverified.

Direct non-possession CarryPlus with Unit.Weight now also feeds the existing
weightBonus equipment sum used by _carrying_capacity(). Its raw/100 conversion
reuses the existing enhancement capacity contract, with integer conversion at
the existing capacity boundary. It does not redefine source item weight, the
explicit local weight estimate, encumbrance thresholds, recovery permissions,
inventory quantity or saved ownership. Already mapped base operands and
existing explicit fields still win. This connection remains unverified.

## Existing equipment523 scalar consumers

The shared equipment523 combat sum now also reads guarded direct native base
operands for KarmaLife→equipment523_lfe, KarmaDeath→equipment523_dth,
CriticalDamageReduction and ElementalDamageReduction, all with original
Unit.Value and no scale conversion. These feed the already existing LFE skill
stat, configured death contribution and actual critical/elemental incoming
reduction calls. The host's configurable death coefficient and healing scaling
remain unchanged; neither is claimed as a recovered original formula.

ElementalCriticalProbability/ElementalCriticalResistance with Percentage
raw/10000 also feed that sum's existing elemental critical callers. Probability
remains scoped to the existing equipment523 flat-element path; this does not
introduce a critical roll for the separate ordinary source-element component.
The two paths are not declared equivalent or fully adopted.

Equipment523.records() supplies existing processing/set-state effects rather
than a second generic ItemBonus base projection. The new reader therefore only
adds missing current native base operands. It deliberately does not add native
regeneration/drain again, duplicate HPHealIncreasePercent through a second
healing engine, or duplicate style critical resistance through a second alias.
Explicit fields and mapped source BonusIDs retain precedence. All additions
are uncompiled/unexecuted/unverified and do not change physical or save owners.

Direct PierceDamageReduction Unit.Value now supplies the existing generic
damage_reduction_ignore item operand in _equipment_additional_damage(). This
retains that host's existing flat-damage projection rather than claiming a new
original armor/reduction formula. Explicit canonical/camelCase fields, source
mapped bonus IDs and existing enhancement overlays retain precedence. The
legacy description fallback runs only when the resulting typed operand is
zero, as before. Style/PvP/conditional ignore inputs and their existing owners
are not reconstructed here. This caller connection remains unverified.

The existing _player_critical_damage() path also receives direct
CriticalMeleeDamage/CriticalRangeDamage/CriticalMagicDamage Unit.Value inputs
through _equipped_numeric_sum(). These remain per-style flat additions after
the existing player critical multiplier. Monster critical damage, the host
multiplier itself and critical weapon-multiplier/ignore-reduction semantics
are unchanged. Explicit fields/overlays and mapped source bonus IDs keep the
same precedence. These connections are uncompiled/unexecuted/unverified.

Direct PVEMeleeHit/PVERangeHit/PVEMagicHit Unit.Value inputs now feed the
corresponding existing _equipment_accuracy_bonus() branch through the equipment
sum. General melee/ranged/magic hit operands and existing collection/card/
guardian accuracy contributions stay separate; no PvP hit effect is activated.
The existing chance formulas and evasion-ignore callers are unchanged. This
additional PvE item-accuracy connection remains unverified.
