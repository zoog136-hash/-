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

For the requested stage comparison, receipt of the fixed source is
1,065/1,065 tables (100% held); the original ZIP and its uncompressed JSON remain
separate byte units. The recorded122/1,065 partial-path labels are about11.46%
of inventoried tables, not11.46% of completed tables or gameplay. There is no
whole-table completion numerator for the later code-writing stage and no
whole-source gameplay byte extent. Thus the current implementation/gameplay
percentage is unavailable, rather than estimated from test counts or held data.

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

### Direct inputs to existing skill and attack readers — unverified

The next delta connects the original data beyond the reference-returning APIs:

- `skill_catalog.configure()` already calls
  `player_skills523.configure_arguments()`. With no explicit skill-pack or SHA
  argument, this now reads the held original archive into compiler-shaped
  profiles for the existing public bound skills. An exact canonical row SHA must
  match the public binding before publication. Original material identities,
  spell/buff bonuses, costs, learning limits, cast groups and target definitions
  feed the existing `apply_to()` reader. Existing profiles remain preferred and a
  supplied invalid/empty explicit pack is not bypassed. The public compiler's
  fixed nine reviewed root/child graphs and InvokeOption/type joins are read in
  the same shape, without arbitrary recursive graph expansion. The existing
  whole-profile identity/reachability guards remain mandatory before adoption;
  missing or unsupported closures remain individually deferred. No partial
  graph is promoted into an effect implementation. Learning, progression/effect
  execution and save code are unchanged.
- `player_skills523.source_mode`, `source_identity` and
  `source_fallback_status` distinguish raw-source input from the compiled-pack
  path and retain per-binding deferred reasons. Its `active_sha256` remains the
  compiled-pack fingerprint. The fallback status's `applied` keys mean accepted
  reader profiles, not gameplay observations or full-table consumption.
- NPC catalog's `row("NpcAttack",id)` and `owned("NpcAttack",npc_id)` now use
  `selected_attack_row(compiled)`. It reads an original row only for an existing
  compiled NPC/attack identity and requires the same selection/behavior and
  numerical attack fields, including NextAttack, MotionType, SpellID, probability,
  fixed delay and dice fields. Missing/different original input retains the
  compiled row. Existing attack/root/chain readers therefore receive original
  definitions without admitting an additional attack or changing AI, timing,
  probability interpretation, effects or saved ownership.
- The catalog's existing `row()` and `owned()` calls also route selected
  ID-bearing definition rows through `_selected_definition_row(table,compiled)`.
  An integral exact ID, membership in the already compiled table and full-row
  equality with the pinned original are required before the original row is
  returned. Missing/different rows retain the compiled input. The authoritative
  selected owner set, order and empty sets are preserved, so existing
  bonus/spell/buff/status readers receive matching original rows without gaining
  another definition or execution branch. NpcAttack retains its separate stricter
  structure/ownership adapter. This data-read delta is unexecuted.

The already recorded next large candidates have existing input readers:
MerchantGoods in the shop catalog, GachaCraftOutput in the item-linked craft data
adapter, ItemBookItem/ItemBookCardForItem in growth96_source, and ItemEnchantBonus
in the existing equipment cache reader. Extending effect execution is PR269's
boundary. Map/spawn/media readers remain with their owners. This is a record of
the bounded existing evidence used for implementation, not a new survey, a new
coverage count, or a claim that every remaining table is already connected.

### Existing destination and mastery inputs — unverified

`World.auto_hunting_destinations()` calls the existing schedule's
`load_configured()`. A present projection keeps its original size/hash parser;
only an absent projection can now use the pinned held archive. The existing
compiler's ten-table relation projection follows AutoScheduleCategory and
AutoScheduleLandTeleport through LandTeleport, Territories, Land, Currency and
the original prerequisite links/types. Existing destination/list/request readers
consume these entries. No departure location, coordinate projection, price or
eligibility is invented; movement, its local policy, payment and saving stay
unchanged. Destination `runtime_enabled:false` and the existing unverified
arrival guard remain intact. `source_input`/`input_identity` distinguish original
archive bytes from a compiled projection's separate fingerprint/byte count.

`World.weapon_mastery.configure()` now calls `core.load_original()` only when no
explicit mastery pack/SHA argument was supplied. It projects the public
compiler's twelve core tables and exact Bonus/BonusType/UIUnit and supporting
class/weapon/currency rows into the existing staged `configure/_configure`.
Existing compiled/live tables are retained, invalid explicit input is not
bypassed, and existing growth/stat/planner consumers read the staged data.
Point purchase, mastery-change and color-reset source rows follow the same
compiler joins without new values, probabilities or transaction code.
Reset-ticket identity is built only when a previously installed exact full-item
sidecar supplies the original matching IdentifiedDescID label; otherwise that
operation retains `ticket_source_missing`. No new DescData scan or guessed label
is used for this bootstrap. `source_mode/source_identity/source_status` identify
the original-table path; `model_pack_sha256` stays a compiled-file fingerprint.

These are input connections to existing services, not proof of gameplay or
completion of every row in their shared source tables. Their current caller and
transaction guards have not been executed after these edits.

### Existing shop, encyclopedia and maintenance inputs — unverified

The original archive can now supply the existing shop catalog session when no
explicit pack/SHA input was supplied. `source523_shop_catalog.load_original()`
uses the same27-table projection, selected label closure and provenance as the
public compiler. The actual serialized in-memory model bytes determine
`loaded_sha256`; `model_input_identity.archive` separately identifies the original
ZIP. Both file and original inputs use the same `_load_payload` staging/schema/
row/relation guards. Existing `bind_source→market_offer/payment_quote/npc_goods`
readers consume that staged catalog. A policy or NPC pack with a different
required model digest still fails its original check; no permissions, purchase,
debit, receipt or save handler is changed.

The encyclopedia follows the same complete-input approach rather than adding a
second readiness gate. Its existing runtime configure path can build the public
compiler's core/current-reward/selection/market/gotcha/card/item/bonus/unit/date
and selected-label closure from the original archive. The exact memory JSON
bytes determine `pack_sha`, not the original ZIP hash. The existing16MiB limit,
schema/table/relationship guards stage it before existing books/levels/row and
service consumers use it. Explicit input failures and existing loaded models
retain their original precedence. `model_input_identity` records source mode
separately. Counting, effects, rewards, economy, saved state, UI and `loaded()`
semantics are unchanged.

`inventory_source523.load_file(default_path)` now has an original-input path only
for a genuinely absent default file without an explicit environment override.
It reconstructs the existing generator's same80-item/84-storage/25-sale
projection, catalog identities, eleven existing price policies and original
table/record provenance in memory. Only bytes accepted by the original
49,818-byte/SHA-pinned `parse()` can become `document`; a mismatch leaves the
previous state and fingerprint intact. The existing automation configure,
registration, eligibility and quote readers therefore use the same rule input,
without a substitute fingerprint, new target, virtual grant or changed
transaction. No pack file is generated or written.

The selected item/grade/offer/book label references are supporting dependencies
of these larger functional inputs. Exact existing sidecar texts are reused
first where their original IDs and rows match; missing required labels follow
only the compiler's declared DescID/DescId references. General description,
dialogue, text-substitution and DescID-system work remains lower priority. A
text table parsed for selected labels is not thereby entirely used in gameplay.
All these input paths remain unexecuted and unverified, with no new completion
numerator or use percentage.

`World._load_source_dungeon_pack()` now delegates to the existing runtime's
`load_configured()`. Only an absent default installation can use the original
projection builder; explicit selections and every existing/partial manifest,
payload or execution sidecar retain the file loader and its failures. The new
projection module mirrors the public dungeon compiler's tower/Orim/special,
reward, time-pool, recharge, declared-server and provenance joins. Its actual
canonical UTF8 bytes must match both6,050,456 bytes and the existing payload
SHA before the existing activation path can receive them. The archive hash is
not substituted for that fingerprint. No Orim execution sidecar, map, placement,
movement, reward, authority or save implementation is generated or changed.
The actual byte match and activation have not been executed under the current
instruction, so they remain unknown.

`World.get_expedition_catalog()` now delegates its existing lazy input loading
to the expedition catalog's `configure_arguments()`. With no explicit pack/SHA,
`load_original()` uses the compiler's twelve core tables, synergy, grade/card,
selected constants/rewards/completion-box/item/bonus/currency closure and the
existing `_valid_tables` guard before publishing the registry. Existing event,
completion, time and eligibility readers consume it. Compiled `pack_sha256` is
the file hash; the original-input mode records the actual serialized catalogue
payload hash and separates its archive identity/input kind. No receipt, reward,
ownership, execution or save implementation is changed. No DescData read is
needed by this compiler's input projection.

Combination runtime `configure()` now reuses the existing
`Source.archive_path()→Catalog.from_zip()→accept_catalog()` path only when its
private cache is absent. A present/invalid cache keeps the original cache path
and failure. The original parser's archive/index/row guards remain intact.
Existing acceptance builds source/requirement indexes and invalidates read
results without writing a cache, selecting a combination, reconciling progress,
migrating state or committing a save. Existing requirement/effect readers then
receive that same accepted data through their existing methods. All these
later connections are unexecuted and unverified.

The existing title configure path now reuses its existing `load_zip()` parser
with the held common archive only when neither an input attempt nor live source
data exists and the dedicated installed title archive is absent. The source
reader records input selection even on failure, so invalid explicit choices do
not trigger a different default. The removed word lists remain removed, and the
personal filter fields remain disabled. Trial/Goal/QuestView/NPC/bonus/item
readers and title actions/saves are unchanged.

Growth96's source loader likewise reuses the common archive only for an absent
default with no explicit path/environment source. Its original size/hash,
current-version, RewardType and TestItem guards and all claim/state/save code
remain intact. Death source `load_default_source()` reuses its complete existing
parser only for a missing dedicated archive. The runtime now tracks explicit
source arguments, including empty/bare ones, and does not try another default
after their failure. Existing ready data, the exact large-integer Experience
parser, NoDeath boundary, recovery seal and all death/economic/save behavior
are retained. These are original input-selection changes, not new mechanics or
new gameplay observations.

### Original inputs to the existing normal-crafting service — unverified

`World._load_patch523_equipment()` now calls
`patch523_rules.load_original(catalog_bytes,binding_catalog_bytes)` only when
neither equipment environment variable is selected and the existing installation
index is absent. Either environment variable, including a SHA-only/empty value,
and every present installation index retain the existing file-input failure.
The base catalog bytes are the actual `res://data/catalog_v19.json` bytes. The
binding input contains only the already registered `아이템` records and existing
`patch523_crafting_catalog_contract`; it does not register an item, invent a
native identity, or serialize a World/UI object.

`patch523_rules_projection.build(catalog_bytes,binding_catalog_bytes)` ports the
existing public `build_patch523_rules.py` compiler's ItemCraftInput,
ItemCraftOutputView, ItemCraftView, ItemCraftRestriction, ItemClass/Bonus and
enchantment relations and its current public crafting policy. The existing
recipe admission, raw relation evidence, item identity/state requirements,
conditional materials, result branches and probabilities remain separate.
`patch523_enchantment_projection.build(tables,bound_items,bonuses)` supplies the
same `equipment_runtime` model as the public enhancement compiler. Explicit
dummy evidence uses the shared PR269 registry SPI; it remains recorded in raw
evidence/admission and is excluded from new active equipment projection. Selected
display-name references are supporting identity dependencies, not completion of
the deferred description tables.

The result enters the same `_load_payload()` schema/catalog/material/outcome/
condition guards as `load_file()`, and the existing
`World._apply_loaded_patch523_equipment()` publishes the accepted recipes and
refreshes derived options. Existing quote, selected-material, execution,
ownership, RNG, receipt and save implementations are reused. `digest` identifies
the actual serialized memory payload; `source_archive_sha256`, the base
`catalog_sha256` and optional actual `binding_catalog_sha256` retain distinct
input identities. No private compiled file or installation pointer is written.
This bootstrap has not been compiled or executed; successful admission, model
identity and gameplay consumption remain unobserved.

### Original inputs to existing NPC merchant conditions — unverified

The existing `source523_shop_runtime.bind_source()` already calls
`npc_definitions.configure(catalog)`, but its NPC-definition loader previously
required a separate explicit NPC pack even when the shop catalog had obtained
its original inputs. The new no-explicit-input path supplies an original-memory
NPC model to that existing reader. Explicit NPC pack/SHA selections, including
empty/bare/SHA-only selections, retain the file loader and its failures.
The exact input chain is
`bind_source(catalog)→npc_definitions.configure(catalog)→load_original(catalog)`;
the helper instance's `build(shop_sha256:String)→Dictionary` returns the existing
NPC model or `{}` with `problem`. No new purchase API is introduced.

`source523_npc_input_projection` ports only the existing NPC compiler's merchant
facts: MerchantGoods→Unit25/MerchantsID→EarthObjectUnit/Class, declared SellList
actions, Unit201/CurrencyID links, original spawn flags/attributes, blessing
codes, reset-type names and refresh constants. Original blockers and
`activation_authorized:false` remain metadata. Supporting table evidence uses
the existing original index; no new audit/report/summary is executed. No
UIMapEarthObjectInfo row order/count is treated as a spawn foreign key.

The memory model references the current actual shop-model SHA and enters the
same existing8MB/schema/source/merchant/object/spawn/semantics parser as a file
input. The NPC model's actual serialized payload has its own SHA, separately
recorded from the original ZIP and the shop model. A prior NPC registry can be
reused only for that same shop-model identity. Failed replacements preserve its
records and report the problem rather than authorizing a different model.
`current_shop_sha256` retains the accepted model binding, `input_identity`
distinguishes archive/shop/NPC payload input identities, and `loaded_sha256`
remains the actual NPC payload SHA. A successfully accepted empty registry also
retains that binding and is not repeatedly rebuilt as a failed input.

Existing `context()`/`currency_for()` and local rule/hash methods consume these
accepted definitions without new access rules. Local hours/dates, server and
clan conditions, shared stock, prices, counters, buying/claiming, ownership and
the final save stay with their existing owners. Existing orders/receipts retain
their original fingerprints: this loader does not migrate or relabel them.
No NPC is spawned or drawn and no original/compiled pack is written. Runtime
payload construction, acceptance, matching current-model identity and actual
merchant purchases remain unexecuted and unverified.

### Original inputs to the existing quest service — unverified

`source_quest523.load_pack()` now uses
`source_quest523_projection` only when both existing USER/DEV payload paths are
absent. Any existing file, unreadable file or invalid payload retains the
original failure. The helper ports `tools/build_quest523_pack.py`'s twenty-one
input tables, four quest relation groups, referenced reward items, prerequisite/
goal/reward type names, original exclusions, KST timestamp policy, classes,
starting quests, currency links and source-table evidence. Only the compiler's
selected quest/scenario/goal/class text references are supporting dependencies;
this does not start a general description-table implementation.

The canonical memory bytes use sorted keys, original integral numbers and no
trailing newline. `_load_original()→_load_payload(bytes,"")` still requires the
existing `PAYLOAD_SHA`
`2d11ecff4e695244220dc8e3a9b5707809f8bcfe34d7789a517880a6590bcb9a`,
`MAX_BYTES` and `valid_document()` before the unchanged adoption loop can expose
the quest registry. The archive SHA never substitutes for the payload SHA, and
the memory mode leaves `loaded_path` empty rather than claiming a generated
file. Existing files enter the same `_load_payload()` guards. No installed file,
pack, new quest admission rule, reward operation, gate, ownership or save is
created or changed. Exact byte/hash reproduction and runtime adoption have not
been executed; this is not an additional3,621 gameplay-completed quests or any
whole-table completion claim.

### Existing card-slot input reads — unverified

`option_slot_definitions.group_for(identity,slot)` now reads the pinned original
BuffCard, BuffCardOptionAwakenGroup, BuffCardOptionAwakenLevelBonus, Bonus,
BonusType, Unit and ID-bearing UIUnit rows for its existing selected slot
projection. An integral exact ID and full-row equality are required; missing or
different input retains the compiled row. The existing group-key admission,
primary compatibility/changed-primary lists, slot1/11 selection, cache,
labels and existing effect consumers remain authoritative. A missing private
slot pack remains missing: this is no new catalog, draw, awakening, ownership,
effect, secondary-slot unlock, installation or save. The actual `group_for()`
caller receives the original row values rather than an unused reference API.
It has not been compiled or executed and adds no coverage numerator.

`collection_runtime.configure()` calls
`current523_collection_input.adopt_selected(data)` immediately before
`NativeRules.configure()` for its existing native patch523 input. The helper
returns the same collection/member/effect/condition sets, replacing only complete
matching raw rows from BuffCardCollection, BuffCardForCollection,
BuffCardCollectionBonus, Bonus/Type/Unit/UIUnit/application targets, Grade, Deck,
selected ServerLimit and card-date records. Compound relations use the public
compiler's existing foreign keys and full-row equality; no ID is invented.
Interval branches separate only the compiler's six supplemental join fields,
match the complete original IntervalBonus base row, and retain those existing
joins/derived values. Missing files retain the existing failure. Native rules,
owned-card derivation, time/server/awakening restrictions, numerical effect
policy, announcements and saves are unchanged.

The existing guardian source now obtains matching selected rows during initial
data adoption and through `rewards()`, `upgrade()`, `constant()` and
`spell_name()`. Existing `data.spells`/`data.buffs` source/effect fields also feed
the combat reader from the same matched originals. The public guardian
compiler's explicit table mappings, selected ID membership and full-row equality
are required; scope references remain only its declared application-type joins.
Derived effects/values, selected nodes, server restrictions and execution remain
unchanged. Text is limited to the already selected lazy spell-name read.

The symbol source likewise adopts matching existing definition/cost/normal/
absolute/bonus/item/interval/invoke rows before its existing apply/action/detail
readers use them. The four original full-table arrays supplied by its compiler
(`SymbolConstant`, `SymbolEnchantProbability`, `SymbolPayment`, `SymbolEnchant`)
are replaced only when the entire original array equals the existing array in
content, order and length. This also reads ID-less SymbolEnchant without
reinterpreting Enchant as an ID. Filtered selections remain exact selected-ID
reads. External crosslinks, recharge/shop/backing/UI data, derived effects,
local-policy/estimate toggles, numerical meanings, transactions and saves remain
unchanged. Payment type meanings are still unresolved.

These are actual existing reader inputs, not new collection/guardian/symbol
features. Their prior compiled-cache consumption remains valid evidence in its
original bounded scope. Reading the same selected source row directly does not
turn that row or its entire table into additional gameplay coverage. All later
card/growth input changes remain uncompiled, unexecuted and unverified.

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

The later integration checkpoint269
`c9864b79182cefdb03199c9c9cdde9d620b2b2d6` supplies the single original-dummy
declaration registry in `scripts/quests/source_dummy523.gd`. The common reader's
`declared_exclusion(table,row,scope)` optionally delegates to that module's
`evidence()` when present and accepts only the matching source SHA and explicit
`excluded_from_connection` evidence. It does not duplicate its IDs/names.
ItemData retains the raw ItemClass but returns `excluded`/`declared_exclusion`
before following additional references. The already existing
shop quote→item identity→ItemData caller consumes this exclusion and refuses
the offer. Missing registry support is not replaced with a guessed dummy rule.
This adapter is unexecuted and does not add an exclusion/use count.
The existing item/book reference readers also call SpellData/BuffData
`describe()`. Those readers now retain their original raw row/source/test
declaration but return `excluded`, the same owner evidence and a table-specific
blocker before traversing child bonuses/references when that SPI explicitly
declares the row dummy. This does not create a second registry or authorize an
effect; adoption and execution remain the integration owner's responsibility.

## Ownership and unresolved candidates

PR269 owns remaining integration, source item ownership/effects and the latest
231/248/265 handoffs. PR264 owns attendance/pass, source reward consumption,
jade/grail and ordinary trial backend. PR265 owns its equipment systems. PR267
owns original UI, PR222 maps, and existing Sprite/image work remains separate.
Sound, clan/siege, pets, arena/ziggurat, stopped content and cancelled work stay
excluded. Shared Item/Bonus/Spell/Reward tables cannot be assigned wholly to one
completed feature.

The later supplied PR269 checkpoint
`bfb4ae7e02ec529f32e18c8b9f3cdb5aefbf675c` records the selected quest-held
craft-material ABI in `docs/QUEST_CRAFT_SELECTED_MATERIAL_ABI.md` and
`docs/REST_INTEGRATION.md`: exact physical material/source-row/quantity/receipt
allocation reaches the existing final save. Its skill execution/learning, shop
purchase/receipt/save and existing NPC construction adoption are integration
work, not additional implementations or gameplay observations in this Draft.
The original crafting-input projection above retains those execution boundaries.

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
