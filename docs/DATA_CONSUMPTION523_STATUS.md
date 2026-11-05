# Current523 definition consumption audit

This Draft retains the earlier private consumption audit tool and connects
bounded source fields to existing gameplay consumers. It does not complete all
original definitions or establish 95% use.
The reviewed baseline is main `1333851bb2eb193a6ac1fc3e3b852787c08994ff`.

## Fixed input and evidence

The existing private current523 archive was received through authenticated Drive
after the Library transfer helper failed at tools/list with HTTP401 before byte
transfer. The received archive is 25,031,173 bytes, SHA256
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`;
all ZIP CRCs and its index, CSV inventory and summary match independently read
content: **1,065 tables, 2,323,700 rows, 457,729,872 uncompressed JSON bytes**.
Archive bytes, compressed members, JSON bytes and generated cache bytes remain
separate. No original tables, private delivery references, packs or saves are
included in this PR.

The private ledger retains every table, parser/compiler candidates, consumer,
caller, owner, storage contract and remaining uncertainty. Reviewed code chains
currently cover selected rows/fields in 122 tables. This is static connection
evidence, not normal gameplay observation or full-table completion. The prior
57-table parsing observation was a limited PR264 run; the other 1,008 tables
must not be labeled unused from that result.

The audit tool leaves missing evidence unresolved. Static mentions, loading,
registration, installation, fixtures and inspection renders cannot establish
gameplay coverage. A full-table claim requires a retained runtime artifact,
source/table SHA, original row indices, consumed fields and reviewed caller.
Partial tables never add their entire JSON size to the full-use numerator.

The recorded mutually exclusive report labels are partial122, other_owner79,
unresolved712, empty50 and excluded102. They are not a gameplay-use percentage.
The122 label requires a reviewed, bounded static source-to-parser/cache-to-runtime
path with a real caller/storage boundary in the recorded main. Unmerged owner
evidence is recorded separately and does not become main use. The79 label records
another owner's work without establishing the same main partial-path evidence;
the712 entries are uncertain/unreviewed, not proven unused. ItemClass is among
the122 because selected death, combination, title, symbol, monsterbook and totem
paths consume its rows. Its34,743 rows/44,095,017 bytes are not wholly consumed.
The machine-readable baseline remains the existing private
`content-consumption-audit523.main.json` and `ownership-evidence.json`; this Draft
does not recalculate their labels after implementation changes.

The first scope review identifies 50 empty tables and 102 nonempty tables for
explicitly excluded features or stopped/test content. These remain in the fixed
denominator. Under this classification the theoretical full-table ceiling is
913/1,065 (85.73%), even before other unresolved work. Exclusion is a scope
decision, not a claim that shared metadata has no reader. Original row-level
scope and mixed-use tables still require review; this ceiling is provisional.

## Bounded connection

The death source reader now validates `ConstantData.NoDeathPenaltyLevel` and
uses it in the existing local **item-loss exemption**. The pinned source value
and previous reviewed default are both 30. Missing source retains the existing
reviewed local policy. Invalid or duplicate source constants fail before active
rules are replaced. The save schema, ownership and recovery receipts are retained.

Experience loss keeps its separate boundary: the original Experience table has
loss at level30, while item DropRate is zero at30 and positive at31. The scalar
is applied to the existing local item policy; it does not certify the original
server's global interpretation. Only one of ConstantData's 490 rows is newly
connected; its entire 57,677-byte table is not counted as used.

## Additional source wiring — unverified after cad2dbff

These implementations were made under the latest instruction to connect source
references without starting new tests, compilation, audits or validation. Earlier
passing results do not validate these changes.

- `SymbolEnchant.Enchant` now supplies the physical stage limit used by symbol
  enhancement, completion, reset, absolute unlock and history actions. The
  contiguous source stage set and existing effect arrays are consumed; the Roman
  tier in `EnchantLevel` is not substituted for the physical stage. No UI nodes
  or artwork are added. `UIText` and `EnchantLevel` remain outside this binding.
- Three named `TotemConstant` identities now select the existing active-status
  paths instead of fixed totem IDs. The other five constants remain unconnected:
  the generic buff is different from the existing barrier, a generic effect
  timer has no caller, and the two Spine fields belong to the excluded media lane.
- `GrowthMotivationConstant.Version` now bounds the existing per-point reward
  version selector. The local save schema stays1, explicit cap0/cap1/cap2 choices
  still apply, and existing point-version receipts stay locked. Future rows are
  retained as definitions instead of becoming claimable just because their
  version is numerically the highest present row. The latest-available policy
  still permits current lower-version points such as the level96 Version0 rows.
  Growth item rewards also consume the declared `RewardType.Name == Item`
  namespace using the existing quest supplier contract, rather than treating a
  numeric type ID alone as permission to join an ItemClass and grant it.
- Ordinary EXP recovery now stages only changed progression fields. A real level
  gain uses the death owner's transient, exact full-transaction authorization at
  the common save boundary. A saved death namespace by itself cannot authorize
  arbitrary level/stat changes; the seal is not serialized and is cleared after
  the synchronous save returns. Existing debits and recovery receipts remain in
  the same one-save transaction.
- Existing retained failure logs also motivated preserving an already-over-one
  skill probability when additions are applied and freeing the detached test
  player's owned identity node. These fixes are unverified, not new passing
  results. Missing recovery receipts remain failed assertions instead of causing
  an additional Script Error in the existing fixture.

The earlier 1,065-table ledger remains its recorded baseline. These bindings do
not turn partial source tables into full-table gameplay completion or
establish a new overall percentage.

## Larger data readers and existing service calls — unverified

The current priority follows the existing inventory's original uncompressed JSON
bytes, not ZIP size or generated-cache size. DescData_Korean55,498,936 bytes and
DescID34,955,795 bytes are explicitly deferred, not deleted or completed. Game
word filters are excluded from loading, not subtracted from the denominator.
Among the remaining large inputs are ItemClass44,095,017, Bonus34,575,811,
SpellClass22,596,753, LuckyBagEntityView17,073,327, Reward13,234,439,
ItemCraftOutputView11,140,223 and ItemCraftInput10,217,120 bytes. These figures
describe input priorities, not additional consumed bytes.

Existing pinned private item sidecars and feature caches are reused first.
`current523_definition_rows.gd` provides lazy read-only `row(table,id)`,
`related(table,foreign_key,id)` and `rows(table)` access to the existing pinned
archive when a needed definition is absent from those caches. It uses the
existing content environment path or existing growth/death/title archive
locations. No new install, original publication, source version or save is
created. Missing or ambiguous definitions remain missing. Original filtering
tables cannot be read through this adapter.

The public data contracts for PR269 are:

| Call | Returned source data and existing reader |
| --- | --- |
| `current523_item_data.describe(item_id)` | Original ItemClass/category/grade, equipment/class links, ItemBonus→Bonus→BonusType→Unit and typed card/spell/bag/reward/buff references. Existing full-item sidecars supply already compiled rows/use specs; original rows supply missing joins. Shop market/NPC quotes now call this reader for item identity and explicit exclusions. Descriptions retain their IDs and are deferred by default. |
| `current523_spell_data.describe(spell_id)` | Raw SpellClass costs/ranges/conditions, SpellBonus typed effects, learning/class/card prerequisites and declared target/category/material references. Item book/card references call this adapter; it never learns or executes a spell. |
| `current523_bonus_data.describe(bonus_id)` | Shared Bonus→BonusType→Unit, declared BonusApplicationType and all UIUnit rows for that UnitID. Item, spell and buff data readers retain the raw value and application target. Neither the application name nor a UI denominator becomes a new target join or combat formula. |
| `current523_buff_data.describe(buff_id)` | Original BuffClass/group, typed BuffBonus rows, declared status attributes and InvokeOption/type references. Item and spell data readers follow explicit BuffClassID units to this contract. Lifetimes and conditions stay raw; no new status is applied. A TestBuff field absent from the source is recorded as not declared, not invented as a required flag or dummy exclusion. |
| `current523_reward_data.bag(bag_id)` / `reward(reward_id)` | Full declared bag entities/type/item/class-limit rows and Item/SelectReward ID graphs respectively. Quantities, blessing, initial enchant where declared, raw weights and conditions remain unmodified. Cycles stay explicit ID edges. Item bonus references call these adapters; no draw, choice or grant is added. |
| `current523_gacha_craft_data.describe(gacha_craft_id)` | Original GachaCraft config, group probabilities, groups, outputs and bound-item references. The declared GachaCraftID unit in an item's bonuses connects this read to existing item/shop queries. Book materials/final cost/delete time stay in the outer item/bonus contract; ChangeCost is not substituted for them. Unknown output ClassID namespaces remain unresolved raw references. Candidate generation/confirmation and ownership settlement are still not authorized. |
| `source523_shop_catalog.item_references(item_id)` / shop runtime's same method | MerchantGoods plus typed item MarketProduct/additional/payment references and purchase/server/date/restriction rows. Existing successful quote results carry `source_reference`; buy/debit/save code and ownership tokens stay with their existing owner. Reverse references do not activate off-sale or restricted offers. |
| `patch523_rules.recipe_evidence(craft_id)` | Cached original inputs/outputs/views/restrictions, with original-archive fallback only when a cached relation group is absent. Existing `material_selection→quote/execute` reads the exact source row/slot/item/quantity/enchant/blessing, result branches/probabilities and view/restriction conditions. It does not admit new recipes or change the established missing-failure policy. |
| `patch523_rules.recipe_definition(craft_id)` | Original input/output/view/restriction relations and an `items` map of ItemClass data contracts, including source recipes absent from the compiled executable set. Returns `source_identity`, `available_in_compiled_recipes`, `reference_only:true`, `can_execute:false` and a source problem when unavailable. ItemClass0 remains a source failure sentinel without an item record. Existing quote/execute admission is unchanged. |
| NPC catalog's `project_actor_record(record)` | Existing Monster.setup reads exact current523 HP/MP/AC/MR/Exp and native attributes only for an existing source actor with matching integral ID/Sprite/DescId and an eligible declared category. The saved encounter identity, spawn-context level, sprites and loot remain unchanged. |
| NPC catalog's `npc_definition(npc_id)` / `attack_definition(npc_id,attack_id)` | Raw attributes/races/resistances/attacks and referenced spell data. These remain reference-only; missing NPC attribute semantics and AI/probability/timing are not invented. Actual attack choices remain the existing compiled closure; cached selected effect relations remain preferred. |

Reference contracts explicitly retain `reference_only` and `can_activate:false`
or `can_execute:false`. An `ok`/`join_complete` data result is not ownership,
learning, execution, service authorization or a successful save. Existing
`TestItem`/`TestSpell`/`TestNPC` declarations stay excluded from new activation;
unsupported definitions are not silently turned into working effects.

The overlap comparison used the already published checkpoints: integration269
`b3b2b0f89e9ba7adc93e46cb4e72d04cdc9ffeb2`, UI267
`5dfd55e9ab20f495f16482782e43376af1f3d329`, map222
`c799528207a45dbb96c2ab3cdc58a242ae3be4d9`, and image270
`cf5657bbd0daa7c4725e0ac4ed77f46b20051994`. PR269 already owns typed item effects,
book learning, card/bag receipts and transactions. This Draft supplies source
reads and data-call additions; it does not recreate those engines, the shared
writer, UI, maps or the separate Sprite lane. Its Monster.setup insertion is a
data projection immediately after the existing base508 NPC record, outside the
integration's action/loot/save changes.

These changes have not been parsed, executed or tested. They do not establish
whole-table gameplay use, complete all rows, or raise the earlier122 count.
Additional effect/ownership adoption of these data contracts belongs to PR269;
unresolved type/AI/server/UI contracts remain unresolved.

The continuing read-only closures also include BuffClass7,297,860,
BuffBonus6,005,262, SpellBonus5,997,214 and GachaCraftOutput3,321,937 original JSON bytes. These are the
recorded sizes of the input tables, not an assertion that all their rows are now
used. The published first reader checkpoint is
`5c73efa4de1dd2d78dcaecc87f7797d78493239e`; subsequent contracts are likewise
unverified and do not inherit earlier execution results.

## Game word-filter removal — unverified

The title source reader no longer loads BannedWordType,
PersonalAppellationBannedWordTypeList or BannedWordData_Korean, nor requires their
previous selected-type count. Assigning legacy personal data clears only its
filter fields and sets `banned_word_filter_enabled=false`, so retained cache word
lists are not reused. The common definition adapter also refuses those three
tables and BannedWord before reading a member. The original archive and handoff
packs are preserved byte-for-byte; no pack is regenerated and no denominator is
reduced. Removal of the input filter loop/name cache itself remains the single
PR269 integration owner's change. Other title requirements, costs and saved
names are retained.

## Concrete differences from the recorded main

These examples use the already reviewed main
`1333851bb2eb193a6ac1fc3e3b852787c08994ff`; no new main-wide survey is implied.

| Existing main consumer | Specific missing source connection | Change in this Draft |
| --- | --- | --- |
| Death item-loss policy in `scripts/death/runtime.gd` | The local exemption level was fixed rather than supplied by `ConstantData.NoDeathPenaltyLevel`. | The existing policy consumes that single named constant through `scripts/death/source_rules.gd`. XP loss keeps its separate boundary. |
| Symbol actions in `scripts/growth/growth_runtime.gd` and `symbol_history.gd` | Actions used a fixed physical stage limit even though the source cache retained `SymbolEnchant` rows. | `symbol_source523.gd` supplies the limit from `Enchant`; Roman display tiers and payment semantics are not inferred from it. |
| Active totem effects in `scripts/progression/totem_combat.gd` | Three existing paths selected hardcoded totem IDs. | The same paths select the named `TeberathID`, `TikalID` and `AtlantisID` source values. |
| Growth rewards in `scripts/progression/growth96_runtime.gd` | The latest-available selector used a cap of100; the reader loaded but discarded `GrowthMotivationConstant`. Item rewards used numeric type ID2. | The native `Version` bounds selection and `RewardType.Name == Item` authorizes the ItemClass join, using the existing quest supplier namespace. Historical receipts and local schema remain unchanged. |
| EXP recovery and the common save boundary | Unchanged progression fields were staged into a boundary that rejected those fields for nonquest owners. Actual level gains also needed the death owner's exact authorization. | Unchanged fields are omitted and a transient full-transaction seal connects actual recovery gains to the existing writer. This is a local ownership contract fix, not another source table completed. |

Thus a source field can be unconnected while its gameplay system already exists.
Conversely, the already identified `GachaCraft` source has no complete usable
candidate/confirmation/ownership transaction in this reviewed main. Its missing
receiver contract is distinct from the unknown type meanings of `SymbolPayment`
and `CombinationConstants`. The remaining unresolved ledger entries have not
all been established as unused, absent consumers, or contract blockers.

## Declared exclusions and retained history

The latest instruction excludes entries explicitly declared dummy by the source
from new connection or activation. A familiar-looking name, absent media or a
missing receiver is not a dummy declaration. No new dummy count or full-source
classification is asserted here. The reviewed symbol stages and named totem
constants do not supply an explicit dummy declaration to apply.

The separate, existing test-content exclusion uses the actual
`ItemClass.TestItem == true` declaration. Growth records with this flag are not
newly installed into the active item catalog, granted, or consumed for token
registration. A mixed point claim is refused as one transaction rather than
silently granting only its other rewards. Original definitions, existing
inventory, claims, point-version locks, receipts and saves are retained; test
fixtures are not deleted or classified as original dummy data. The already
recorded nineteen flagged book items remain excluded from the unimplemented
GachaCraft activation path. Unflagged books are not thereby authorized for use.

Exclusions never count as gameplay consumption and do not reduce the fixed
1,065-table or 457,729,872-byte JSON denominator. The exclusion guards, like the
other changes after cad2dbff, are unverified.

## Ownership and unresolved candidates

PR269 owns remaining integration, source item ownership/effects and the latest
231/248/265 handoffs. PR264 owns attendance/pass, source reward consumption,
jade/grail and ordinary trial backend. PR265 owns its equipment systems. PR267
owns original UI, PR222 maps, and existing Sprite/image work remains separate.
Sound, clan/siege, pets, arena/ziggurat, stopped content and cancelled work stay
excluded. Shared Item/Bonus/Spell/Reward tables cannot be assigned wholly to one
completed feature.

Consumer gaps found in reviewed modules include `CombinationConstants`,
`SymbolPayment`, `SymbolEnchant` and `TotemConstant`. A compiler output alone is
not gameplay use. Missing type meanings or existing UI/owner contracts prevent
inventing a new transaction or interface. `GachaCraft` supply, material and final
cost definitions were found by following the associated Unit/Bonus/ItemBonus
joins beyond its five tables. These are book-crafting records; the source
category is not directly activatable, and its candidate refresh cost must not
be used as the final crafting cost. Individual recipe costs also differ, so a
global default cannot replace them. The current-candidate, confirmation and
ownership transaction contract remains a PR269 handoff; weights or drop-view
references do not establish normal acquisition. Class change,
domination stones, symbols, guardian slots and mastery already have partial
consumers and must not be reported wholly unused.

## Validation status

Completed before the latest instruction to stop starting new validation work:
Python audit21, existing Core staging10, world links5, codec18 (one separate
skip), pinned-source scalar21, and the committed723-sheet integrity check.
The production-resource import completed. Its first policy check exposed an
outdated test host; the fixture now uses the current real star-combat service
and checks charging/frozen gates. Production skill behavior is unchanged.

The controlled Main run exercised the new30/31 item boundary and two fresh Main
processes using the default installed pack, with17/17 checks in each process.
The entire death suite **failed**:119 checks,14 failures and one Script Error in
the later recovery UI/certificate/expiry coverage. Existing logs and code supplied
the recovery-boundary and receipt-guard fixes described above. No rerun followed;
the recorded result remains a failure and is not classified as pre-existing or
a regression. Logs are retained privately.

The Core continuation retained its original error rules:33 checks passed, two
failed (`halphas_star_enchant_transaction_test`, `auto_selection_order_test`),
and three were not run when further dispatch stopped under the latest user
instruction. The auto-selection check reported a resource still in use at exit;
the star transaction check reported probability assertions. These remain failures;
the log-based probability and cleanup fixes described above have not been run.
The original failing policy-host attempt and all completed logs are retained.
This Draft is not a passing full gate.

Controlled ownership fixtures are distinct from normal acquisition or gameplay
coverage. Resource checks verify the existing723 sheets, not complete original
art delivery. No remote/manual CI, main merge, workflow change, new art or source
pack publication is part of this Draft.
