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
