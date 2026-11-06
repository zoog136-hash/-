# Original data follow-up

Base main: `5db920332` (includes the merged data271 and integration269 lanes).
The original private inputs, saved identities and existing ownership services
remain unchanged. No tests, compilation, model/parser validation, game, rendering or
CI was started. All changes below are unexecuted/unverified.

Latest user scope withdrawal: pending spell-stage, potion and emoticon source
connections are excluded from further investigation, implementation, handoffs
and outstanding counts. This includes pending Item233/Sprite16007 recovery.
Existing code, original inputs/caches and saved data are preserved. Previous
sections describing already-written potion inputs are implementation history,
not a request to continue that excluded target or count it as completed use.
Ordinary spells, weapon skills, transformations and combat effects are not
excluded by the narrower spell-stage withdrawal. The frozen62ZIP/v30/Drive/
index and separately held UI candidates remain untouched.

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

The existing conditional_magic_damage() and final-blow totals calls now also
receive native base MagicDamage Value and FinalBlowProbability Percentage
operands whose application explicitly resolves to SpecialResistanceType.Stun.
ItemOptions.additional_original_conditional() uses the same exact source-row,
mapped-ID and explicit-field guards. The existing owner still decides hit scope
and self/target status through its published configurable TWILIGHT policy;
the source reference alone is not described as proving that direction. No
new condition, subject, cast, probability roll, final-blow order or stun effect
is introduced. Missing/unsupported declarations supply no operand. Other
conditional meanings and the enhancement-only fear-ignore owner stay separate.
These actual conditional caller inputs remain unverified.

## Reward-rate inputs after the 2026-11-06 continuation

Original IncreaseNpcItemDropAmount now supplies the existing adena_drop_pct
sum. It must declare BonusApplicationType.ItemClass, target the original
ItemClass26 and resolve that non-Test/non-excluded row to ItemCategory.Currency.
Other item targets are not converted to Adena or activated. ValuePercent raw
values remain percentage points, matching the existing enhancement projection.
The existing kill path retains the separate blessing/Jade multiplier and
its current 0–500 percent clamp. Floor drops, physical acquisition, currency
ownership and save remain in the existing owner.

Direct AbsoluteExperienceAdditionPercent supplies a missing native xp operand
to the existing experience multiplier. The original Percentage fixed-point
value is divided by1,000,000 to match that receiver's ratio, as in the existing
ordinary ExperienceAdditionPercent projection. A mixed item can add the missing
absolute operand only if every existing mapped xp entry resolves to its actual
ItemBonus/Bonus/BonusType/Unit, belongs to the same item, is a unique direct
ExperienceAdditionPercent row, has the exact projected value, and sums exactly
to the existing typed xp field. Otherwise the explicit field wins. Already
mapped absolute bonuses are not added again. Existing enhancement, active
item, totem and blessing multipliers keep their current order and ownership.

This continuation observed main52c8f4be5 and unchanged open PR282. New UI/Sprite
owner changes are not copied or overwritten. ItemBook saved eqc identity,
admitted range/weapon context and dialogue-to-mobile-NPC identity remain exact
separate dependencies. No test/compile/game/render/CI or adoption recount ran.
Both reward-rate caller connections are unverified.

### Existing map-owner boundary (no duplicate placement)

PR276 was read at6b9cfc85f4113c7d054ae5057724225f0c7bd04d. Its
scripts/maps/current523_source_spawns.gd::context_key(npc_id,view_id,link_id)
already requests lineagem_base508:npc:N:spawn:V:territory:L, with V being
NpcSpawnPackNpcClassView.ID and L being NpcSpawnPackTerritory.ID, not the
Territories.ID. The two rows join on NpcSpawnPackID; view.NpcClassID is N.
Territory-link.TerritoriesID resolves through Territories to Land.ID.

The existing current reader scripts/monsters/base508_source_roster.gd::
for_spawn(key,host_map_id) accepts that exact tuple, calls the current original
CONTEXT.record(N,V,L,host), sets source_m_current523_final=true and leaves
source_m_asset_manifest_path empty. The legacy key spelling preserves identity;
it does not select the old actor pack. patch523_spawn_policy.gd subsequently
checks the actual view/link/NPC/territory/land/level relation. This PR adds no
second placement, density, respawn or population controller. Those remain PR276.

For travel, the actual original forward LandTeleport.ID relations currently
held here are SpecialDungeon.LandTeleportID (already consumed by
source_dungeon_projection.gd::_special) and
AutoScheduleLandTeleport.LandTeleportID. A TeleportToTerritory bonus points to
a territory, not a LandTeleport.ID. patch523_world_links.gd's separate_routes
is an array of LandTeleportTerritories alternatives explicitly marked
UNVERIFIED_SEPARATE_TRAVEL_ROUTE; selecting its first route or using a
territory/item/NPC ID as LandTeleport.ID is not authorized by that relation.
The current NpcClass declaration has no teleport or talk identity field.
This is not a claim that every NPC action table has been examined. Actual
item/NPC action -> chosen route -> prerequisite/cost result remains the
integration owner's caller contract, so no World travel code is duplicated.

### Orim NPC elemental numeric input

The existing verified Orim NPC/stage/spawn/group descriptor now also supplies
NpcClass.FireResistance/WaterResistance/AirResistance/EarthResistance to
Monster's existing element_resistance dictionary. Monster independently
reconstructs the descriptor before accepting the input. The four existing
fire/water/wind/earth consumers then read these values; other supplied channels
and the host damage formulas/clamps stay unchanged. No native source_m actor
marker, Sprite identity, role, admission or world placement is added.

The raw unit is still unconfirmed. The separate configurable
data/monsters/current523_orim_numeric_input_policy.json explicitly estimates a
1.0 raw-to-host-percent scale, reusing the previously recorded estimate for
these same NpcClass fields while preserving the admitted-native policy's scope.
This is a numeric TWILIGHT estimate, not a recovered original percentage or
server formula. Disabled/missing/invalid policy or source preserves the prior
input. The per-life metadata records raw fields, scale, source and policy SHA,
is cleared on setup and is never saved. No immunity/status formula is inferred
from the missing NpcAttributeType table. These calls remain unverified.

The same verified local NPC context also supplies unique named
NpcSpecialResistance→SpecialResistanceType Stun/Hold/Fear operands to the
existing Monster.setup resistance fields. Its distinct local policy carries
the same explicitly estimated scale and unconfirmed-unit warning. Unknown
names, duplicate rows, source exclusions, negative/nonfinite values and values
at/above100 retain prior inputs; no numeric value creates an immunity. Existing
integer conversion and status-success formulas remain unchanged. Neither the
admitted native registry nor its complete owned row set is widened. These
three additional resistance consumers are also unverified.

## Image283 caller-data handoff (2026-11-06)

PR283 was read at0d3a1ce832ef955b173e4186334db5d745fc9284. Its consumer
files are not modified in this data lane.

- Dialogue: scripts/npc/dialogue_service.gd::resolve returns npc_id from
  data/npc/twilight_dialogues.json or source_six_dialogues.json. The former
  contains host keys such as warden/merchant; the latter has explicitly PC
  l1j_tw380 keys. Neither inspected declaration supplies a mobile NpcClass.ID.
  No name, numeric suffix or PC-to-mobile mapping is inferred. The existing
  source523_npc_images context.npc_class_id input is therefore still pending.
- Dungeon: source_dungeon_view.gd::FAMILIES has tower normal/hard, orim
  normal/hard, special and rechargers. _refresh uses
  world.source_dungeon_entries(kind,hard); _select reads rows[index]. These
  selectors do not currently carry PartyDungeonTypeID/CompetitionDungeon.ID.
  The original PartyDungeon.PartyDungeonTypeID and CompetitionDungeon.ID
  asset joins remain valid for an actual caller supplying those identities,
  but tower/orim stage IDs, a SpecialDungeon.ID/LandTeleportID or an item ID
  do not establish that caller relation. No first asset or shared numeric ID
  is selected as a substitute.
- Quest: source_quest523_projection.gd joins QuestView.ID through
  QuestReward.QuestID/RewardID to Reward.ID; each source_rewards[] entry keeps
  that actual Reward row, .relation and .type_name. For RewardType.ID2/NameItem,
  RewardClassID resolves to ItemClass and .source_item retains that row.
  quest_service.entries() retains source_rewards[] on each returned quest;
  it separately supplies the eligible reward_plan under .rewards. Actual
  eligible items[].source_reward_id identifies the Reward row, and
  items[].record carries its existing canonical/preserved item record.
  The aggregated plan.exp/plan.adena values do not themselves carry per-reward
  IDs; their image caller still needs the actual eligible source reward role
  from the owner instead of choosing an arbitrary source_rewards[] member.
  Do not use the quest ID as a reward ID or an unfiltered reward of a different
  character class as the actual selected payout. Existing source image item
  resolution can consume the proven ItemClass role; RewardIconID is retained
  as its own original field, not asserted here to be an AssetView key.
- The original quest controller currently exposes
  original_goal_story_and_reward_slot_roles as unresolved. Data identities
  are available above, but this does not supply an original target node or
  authorize a new reward selection/representative image for multiple rewards.
- Emoticon: the pending source connection was withdrawn by the latest user
  scope. No caller/target recovery or outstanding input is requested for it.
  Original definitions and existing shared code remain preserved; sound is
  still excluded. The withdrawn target is not counted as connected use.

This handoff adds no image/UI/ownership implementation and no execution or
new adoption count. Actual missing image caller contracts remain separated
from the independently implemented original reward-rate and NPC input paths.

## Typed flat damage-reduction inputs

The current native ItemBonus reader now supplies direct Unit.Value
MeleeDamageReduction/RangeDamageReduction/MagicDamageReduction operands to the
existing flat stage of _pve_damage_after_item_buffs(raw,ignore,attack_type).
The actual hit caller already passes its normalized attack type. Each operand
stays in that style, separate from the existing percent-reduction field, card
collections, critical/elemental reductions and source conditions. No PvP-only
effect is projected into this input.

PoisonDamageReduction similarly supplies the poison-only flat operand in the
existing _source_dot_damage() path before its existing percentage stage.
Bleed and other tick channels do not borrow that flat value. Existing host
minimum damage and flat-before-percent ordering are retained; this is not a
claim to recover original-server ordering. Exact native row/identity, Unit,
typed-field/alias and mapped-bonus safeguards still apply. No new status,
physical item, quantity, transaction, RNG or save owner is introduced.

Current main d758bcfc0 was merged into this feature branch with its existing
startup/save/source-only fixes preserved; no PR/main merge or force push was
performed. Sparse checkout omitted this already tracked document during the
merge; the exact tracked HEAD file was restored, not regenerated or discarded.
New data code remains uncompiled/unexecuted/unverified, with no extra tests,
game/render/CI or table-use recount started.

## Actual selected Orim NpcAttack range input

The existing Orim owner already chooses a non-spell NpcAttack row for both
its damage dice and dungeon_play_attack metadata. Immediately after that same
choice it now supplies that exact row to
current523_actor_attribute_input.attack_range(descriptor,attack,host_kind).
The reader reconstructs the verified stage/spawn/NPC descriptor, requires a
unique full original NpcAttack row for that NPC, IsSpell=false and a positive
integer Range. Its original AttackType relation must name the same existing
host kind (Melee/Range/Magic); All, mixed/unsupported types and mismatches do
not change the host role or supply a range. WeaponType/MotionType are not
translated into Sprite or gameplay weapon enums.

The distinct local Orim policy explicitly estimates58 host-length units per
raw range1, reusing the previously recorded NPC range calibration choice.
Source internal grid units remain unconfirmed. The exact selected row, scale,
policy/source SHA and resulting host length are retained as per-life metadata;
the next setup clears it. This numeric estimate is separate from native actor
admission and from the existing admitted-native uniform-range policy.

The actual receiver is Monster.configured_attack_range, read by the existing
current_attack_range() chase/release checks. Existing silence fallback,
attack selection/order, dice, spell routing, intervals, RNG, map placement and
saved run identity are unchanged. A rejected Monster.setup() now returns a
failed spawn before applying data, connecting callbacks or issuing a new
token; the staged/saved issued state is preserved. No alternate source/pixel
input bypasses that rejection. Player SpellClass range/weapon/minimum-range
receiver contracts are still separate; this does not claim to finish them.
This additional source-to-actual-NPC-caller connection remains unverified.

## Existing undead and magic-critical equipment inputs

Direct non-possession UndeadAdditionalMaxDamage Unit.Value now supplies the
existing source_undead_damage_max equipment operand. The actual successful-hit
caller already checks the target's existing is_undead() classification, the
configured hit scope and the established min..source-max damage roll. Those
classifiers, random-roll/order and explicitly local scope remain unchanged.
No NpcRaceType table, undead identity or source-server distribution is inferred.
Native regeneration/drain is not counted again through this field.

MagicCriticalResist Percentage now supplies the magic branch of the existing
_critical_resistance_stat(kind,elemental) equipment sum, using raw/10000 percent
points. This extends the already existing typed melee/ranged input to the
already supported magic attack kind; generic, elemental and collection
resistance remain separate and the chance formula/cap/RNG stay unchanged.
The shared exact-native-row, source exclusion, explicit-field and mapped-ID
guards apply to both. No physical ownership, quantity or save is altered.
These additions are uncompiled/unexecuted/unverified, not table completion.

Eligibility correction from the subsequent exact source lookup: the current
ItemBonus roots for MagicCriticalResist and WeaponBlock have no non-Test item
target. Their guarded code paths therefore do not establish eligible current
item use. Existing TestItem guards keep them inactive. UndeadAdditionalMaxDamage
and PierceMagicShieldPercent do have non-Test direct item targets. No source
flags were altered, and code availability is not reported as source adoption.

## Original equipment operands for the shared estimated combat receiver

Original ItemBonus rows also declare direct non-possession
PierceMagicShieldPercent for items such as153222/4121 (Unit.ValuePercent) and
WeaponBlock for163553/163563 (Unit.Percentage). The first is already percent
points; the latter uses raw/10000. They are not scaled as if they had the same
source unit. The existing equipment sum now supplies these missing native
operands to the existing MR-penetration and weapon-block functions.

The existing shared receiver API now accepts optional additional_percent=0.0:
collection_runtime.magic_resistance_after_pierce(mr,additional_percent), and
blocks_weapon_hit(kind,rng,additional_percent). All previous callers remain
valid. World passes magic_penetration_pct from _player_magic_hit_chance and
weapon_block_pct from its existing weapon-hit check. Missing/nonfinite input
adds zero. The source reader retains explicit-field/mapped-ID and exact-native
guards. ValuePercent may retain fractional percent points for float receivers;
integer evasion/critical/raw Value/Weight receivers keep integer safeguards.

There is one combined percentage cap/roll at the established receiver, not a
second block or MR engine. Existing estimates_enabled, magic_penetration_factor,
weapon_block_reduction, attack-kind gating, rounding, RNG and damage order stay
authoritative. This applies the same explicitly estimated host interpretation
to original item operands; it does not claim a recovered source-server MR/block
formula. Card collection totals/ownership/completion/policy save shapes are not
changed or supplied with gear records. All new calls remain unverified.

### Exact next receiver/declaration dependencies

The following are scoped known dependencies after the independent operand
connections above, not a new inventory or a claim that every remaining table
is blocked/completed:

| Original input | Existing boundary | Missing prerequisite |
| --- | --- | --- |
| ItemBonus→BonusType.FinalBlowAdditionalDmg, Unit.Value | The public receiver is unchanged; a later owner-supplied unpublished flat receiver is held as a separate local candidate | Current direct targets163573/172231/172241 are all TestItem=true, with no non-Test direct target or corresponding ItemEnchantBonus group. They are excluded, not an eligible source-binding backlog. The local receiver already reads original base/enhancement rows; no duplicate ItemOptions fallback was added. |
| NpcAttribute.NpcAttributeTypeID | Raw rows remain in current523_npc_input_projection/patch523_npc_catalog | NpcAttributeType is absent in the supplied archive. A declared type/role mapping is required before turning numeric IDs into critical, AI or other actor stats. |
| Original NpcRace classification | Monster.is_undead() and the already existing undead-hit gate | The original race-type definition/authoritative actor classification is still missing. New item operands do not infer an undead identity or activate that classification. |
| Additional NpcAttack.Prob/NextAttack/FixedDelayTime/MotionType/WeaponType branches | Existing supported NPC attack owners and the currently selected Orim attack | Source meaning plus actual selection/transition/timing/weapon receiver contract is required for branches not already supported by the owner. The new selected Range input does not reinterpret those fields or replace current supported branches. |
| ItemBook identity | Existing saved eqc collection IDs | Exact owner-provided source-to-saved identity mapping; no numeric/name similarity fallback. |
| Player SpellClass range/weapon/minimum context | Existing player skill/equipment owner | Admitted typed receiver context requested from integration; no Sprite-enum conversion. |
| Current dialogue key | source523_npc_images context.npc_class_id | Authoritative dialogue-to-mobile-NpcClass.ID relation; unchanged pending input. |

No new flat final-blow rule, unknown NPC type table, actor identity, range
selector, collection migration or dialogue mapping is fabricated to fill these
gaps. Existing graph/row retention is not counted as execution or whole-table
adoption. Tests/compile/game/render/CI remain unrun for these changes.

The native owner confirmed the flat final-blow gap at PR281
af3ec2b35c533d98f21c6fc7949291c482d86b22. Its totals/damage receiver accepts
chance/amplification percentage points and, on success, adds the rounded
amount*amplification/100; amplification<=0 returns without a roll or firing.
The existing native stage is after amplification/growth and before separate
elemental/undead additions. There is no native flat parameter/policy. Required
owner decisions are shared/separate chance roll, flat placement relative to
amplification, zero-amplification activation, combination/rounding and firing
reporting. These are receiver/rule decisions, not missing ItemBonus values or
permission to copy the card engine. See the owner's
[native receiver](https://github.com/zoog136-hash/-/blob/af3ec2b35c533d98f21c6fc7949291c482d86b22/scripts/crafting/patch523_final_blow.gd#L43).

The independently inspected Orim Silence candidate has declared type/rows,
but no matching row falls inside the existing non-immunity numeric estimate's
accepted0<=value<100 input range. No range, scale, immunity or fake receiver is
created to force an additional connection. The existing typed/raw definitions
remain preserved; any future in-scope implementation requires authoritative
unit/status meaning or an owner-supplied approved receiver contract. This is
separate from the withdrawn spell-stage/potion/emoticon targets.

## Native enhancement MR-penetration input

Non-Test items140721/152732 declare EnchantBonusGroupID11291/11362 through
their actual ItemBonus→Bonus selector. Those groups contain direct
ItemEnchantBonus→PierceMagicShieldPercent rows with Unit.ValuePercent and no
+0 row. The existing enchantment projection now retains those exact operands
as magic_penetration_pct (divisor1), with an explicit Unit211 guard.

current523_equipment_extra_input.sum_native(world,key) supplies only that
missing native enhancement operand to the existing MR-penetration receiver.
It validates the currently equipped physical ID/name/source, blessing, exact
original item/archive, current prepared source model and exact0–20 level.
The prepared value and model value must equal the sum of the selected original
same-level rows. Group-selector units, application/possession/exclusion flags,
source row IDs and per-group blessing fallback retain their existing meanings.
Duplicate selectors/rows, unsupported groups, nonfinite/mismatched values,
whole-value +0 families and missing-rank extrapolation are not supplied.

Native base ItemBonus still comes from the established equipment sum. Legacy
extra values already in that sum are not added by the native-only reader;
an already marked effective-extra record is skipped as well. No source DTO,
mapped-ID marker, physical state, quantity, receipt, policy save or model
installation is rewritten. There is one existing shared MR formula/cap, still
controlled by the user's unchanged estimated combat policy. This is equipment
enhancement data, not the excluded spell-stage/potion work. New code remains
uncompiled/unexecuted/unverified.

The exact flat-only four-file receiver text from integration72858520/full
d37af099955b4a8e93311f9ce318d2c88e4af848 is retained outside Git as a separate
local candidate. File fingerprints match the supplied handoff. It has not
been applied, published or installed, and no multi-receipt payment was copied.
Its base() and enhancement projection already supply the proposed flat field;
adding another raw fallback would risk counting the same original operand
twice. Source eligibility is a separate result: all three current direct
targets are TestItem=true and remain excluded. This does not count a local
receiver copy or test-only source graph as actual game use.
