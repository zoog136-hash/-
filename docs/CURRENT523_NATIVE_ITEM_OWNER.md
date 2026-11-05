# Current original item DTO and supply boundary

Implementation only; **unexecuted and unverified**. No new parser/test/game/
render/integrity/quality/CI command was run. These changes do not increase the
historical 58/146 verified item-path figure or establish current gameplay use.

## Original input and existing game calls

This adopts data271 `3c7ea50e121004c30c5ff640000d85487f2d92fb` drop membership
and `da81a4710a4b76b966f76ed9cdea28b20b59114d` ItemData/market leaf references.
The existing shared current523 archive reader owns original row loading, pins
and dummy exclusions. No old monster BIN/sidecar is an automatic final input.

`patch523_monster_drops.definition_id(id)` now passes the original typed
ItemData result to `current523_native_item_projection.record(definition)`.
The DTO retains original ItemClass/category/grade/equipment-slot/class/bonus
relations and current archive identity. Slot/stat/HP/MP mappings are a bounded
port of the already public `tools/monsters/patch523_item_definitions.py` at
`3c7ea50e` (blob `2b58180b22d1be96004e13398f59a5fa6d563d4d`).

The projection maps the existing known flat/percentage equipment fields,
weapon/two-hand metadata and HP/MP dice formulas. The existing equipment
stat call also reads current original ItemEnchantBonus/Bonus/BonusType/Unit
relations by exact group, enhancement level, blessing and application fields;
it retains the public compiler's stat/divisor mapping without old sidecars. It retains unsupported bonus
IDs and conditional clauses as partial. Other buffs, cards, bags, book learning,
invokes and full spell effects do not become implemented by this DTO. Missing
source references/labels/unsupported slots remain explicit holds. Actual source
IconID/Sprite references are exposed to image/Sprite owners without generating
pixels or claiming their delivery.

DeleteTime joins use original DateTimes_Korean rows or the existing compiler's
literal-date representation. No source timezone is inferred; existing caller
clock policy is retained. Region/server/unknown date conditions stay pending.

## Registration and crafting

World's existing `register_catalog` registers actual normal, non-dummy original
DTOs and retains unresolved/colliding identities. Counts are produced only when
that runtime executes; no 30,398 registration success is asserted here.
`patch523_craft_catalog.available()` now reads this original input rather than
automatically selecting old full/partial BIN files. Former readers/installers
are retained for historical reference only.

The actual registered record's full original row, archive and typed slot/class/
level identity can take precedence in the existing rules projection. It does
not forge the old `full_native_supplement`/38ee/30,398 marker. An actual catalog
registration is still distinct from material selection, recipe execution,
equipment effects or a successful save.

`stage_source_item_grants` retains its four-field grant input, supplier-origin
argument and full inventory/item_instances/gold candidate output. Current native
equipment uses the existing physical UUID/blessing/enchant/supplier proof path;
Adena uses the existing bounded gold wallet. Reviewed awakening supplies use
their current schema2 quantity owner. Supported original HP/MP potions now use the quantity owner described below.
Other new non-equipment native stacks remain held until their quantity/use
owner is connected; they are not published as name-only balances or treated
as completed effects.

## Real NPC, floor and save calls

Monster setup supplies its already admitted current NPC registry to the public
drop identity reader. Current NpcItemDropView membership reaches the existing
host drop chance/order/count code. Native bindings require exact registered
current DTOs, supported physical/wallet owners and all source conditions. No
drop rate or quantity is inferred from membership. The actual kill caller passes
its existing clock offset for date eligibility; an absent context holds a dated
candidate.

The existing source-ground owner stages floor removal, physical equipment or
reviewed supply, wallet/inventory and receipt in its existing single save.
Schema4 source receipts identify the original archive/projection marker, not
the historical BIN. Locked/distant/unavailable/changed/duplicate/failing inputs
remain within the existing guarded transaction; no execution pass is claimed.

The actual Monster setup path also delegates its view to Sprite272's published
`current523_source_bank_view.configure_admitted(record, admission)` when that
separate implementation is integrated. The old view is not a final fallback.
Missing module/config/action/pixels rejects this source spawn. No renderer was
duplicated here.

## Existing ownership and marker ABI

The new source-item catalog marker is schema4, with its actual original archive
SHA and explicit projection scope. It does not masquerade as schema3/38ee.
The equipment identity consumer and quest provider accept that exact source
contract while retaining full raw-row/variant/source checks. New quest use
records the actual current input fingerprint; the common consumption owner
continues preserving a prior immutable first-use fingerprint.

Old catalog markers are retained in `source_item_catalog_history`. The normal
save path requires a byte-preserving backup before its first source-mode change.
There was no game load, save rewrite, migration or backup execution in this turn.
The old full-catalog bulk physical-record migration remains disabled in the new
input mode. Definition views may resolve only the exact saved item identity;
unknown aliases or missing definitions are held, not renamed or regranted.

Historical schema1 awakening issuance can consult retained exact sidecars only
as old issuance evidence, and only with current full-row agreement. This is
not a final definition/effect fallback or an installation prerequisite for new
schema2 supplies. Originals, prior packs and the immutable 811/822 saves remain
preserved.

Other non-equipment quantity/use bridges, native effects and actual new
UI/image/Sprite/bank installation remain incomplete. The prior Main47
and receipt735 checks belong solely to ea838f6b and do not validate this code.

## Supported HP/MP physical stacks (later implementation, unverified)

`current523_native_stack` adds quantity ownership only where the existing exact
HP metadata or unrestricted MP dice owner represents the full use conditions.
The generic supplier and real source floor acquisition stage an actual random
physical ID, original archive/full ItemClass/blessing/supplier receipt and an
immutable granted quantity. The remaining and used quantities stay separate.
No historical name-only stock or quest receipt is converted into this schema.

Actual inventory selection, consumable quick-use and direct healing dispatch
join this owner before older name-based consumers. Selection/locks/current
source class/level/date/service/invisibility/life/cooldown conditions are
rechecked; missing proof preserves same-name legacy stock. The private RNG
candidate uses original HP/MP dice and existing host healing modifiers, NPC
healing and cooldown hooks. It does not advance live RNG before saving.

A single sealed save candidate contains physical remainder/removal, inventory
debit, immutable source receipt plus used/remaining ledger, HP/MP, cooldowns and
RNG state. The existing shared vital/RNG writer recognizes only that exact
in-memory candidate. Source quantity state/transition guards participate in the
existing save/load boundary; unrelated or completed receipt changes are held.
Save error retains live state and blocks another write/use until load, since
an error can follow an uncertain durable write. Live adoption occurs only after
confirmed success. Source effect sprite IDs go to the existing emitter only.

The normal physical synchronizer does not manufacture or prune these stacks.
Their floor splitting and partial warehouse transfer remain explicitly held.
Whole selected warehouse bundles now use the typed transfer described below;
no whole stack is moved while inventory decrements one.
This is a host ownership safety hold, not a claim that the source item forbids
storage or dropping. Other native materials/bags/books/effects remain outside
this narrow quantity/use connection. No new run, test, save or pass is claimed.

## Current source physical crafting materials (subsequent unverified connection)

The same quantity owner now admits normal current original `material` DTOs that
have actual ItemCraftInput relations, preserving unresolved effects as partial.
Acquisition is not standalone use/effect completion. The original supplier/floor
path creates physical quantity receipts; no balance is backfilled into ownership.

The existing selected-material API accepts its six-field shape with either the
original `quest_reward_receipt` or `source_native_stack_receipt`, never both.
Original material-row selection remains distinct from physical ID selection.
Each request supplies physical_id, quantity, expected_quantity,
expected_remaining, its immutable receipt, and material_allocations; every
allocation retains material_row_id and quantity. The existing recipe's actual
raw ItemClass, blessing, enhancement, selected row/cost, restrictions, locks and
current date must agree. The canonical key is allowed only for the exact native
receipt, and its selected pool remains row-bounded; same-name older objects are
not silently consumed instead.

The existing quote/execute/quest-material join now stages native physical
remainder and used ledger alongside actual recipe inventory debit, quest uses
when present, output, fee, usage, log and existing RNG/save. Only selected IDs
are replaced; whole source candidates are not blindly merged. Failure policy
that retains all materials also retains these units. A same-key declared failure return now follows the exact retained-unit
transaction described below.

Current non-equipment crafting outputs require their actual typed supplier or
supported native physical-quantity owner before the final save. This stages
ownership once on the executor's already credited output without adding the
inventory result twice. Unsupported outputs hold the transaction instead of
creating name-only stock. Existing physical equipment/wallet outputs keep their
owners. No additional recipe, amount, probability, source UI or free reward is
created. Existing duplicate cached-only recipe_evidence implementation was
removed in favor of the already integrated cache-preserving original-reader
method; no test or parse run was performed.

## Exact failure refund and whole warehouse custody (later, unverified)

For an already selected original failure output of the same ItemClass, blessing,
zero enhancement and exact inventory key, the craft join retains the returned
quantity on the actual selected physical IDs in request order. Only the net
lost units reach physical debit/used_quantity. Gross source costs, allocations,
original output and retained-unit receipt proofs remain in the craft journal.
The output supplier subtracts this already-retained quantity before staging any
additional output, so returned old units do not acquire a new supplier origin.
The first-grant receipt/quantity/ID is unchanged, including a fully returned
selection. Fees, failure policy, usage, output probability and RNG stay with the
existing executor. Other output identities continue through their own suppliers.

`current523_native_stack.transfer_warehouse(world,name,quantity,direction,id)`
is called by the existing World warehouse request after its existing source/
expedition/lock restrictions. It supports an explicitly selected **whole current
remainder**, with the existing UI limit of 1..99 and warehouse save limit. The
same unmodified physical ID/receipt/used count moves between carried and stored
instances; both count dictionaries and warehouse snapshot are saved together.
Source IsStorable, equipped state, locks and withdraw weight remain effective.
The save/load quantity guard now follows active and warehouse custody and
rejects duplicate IDs, unexplained removal or missing remaining units. Only the
exact transient warehouse candidate authorizes that custody move. A save error
blocks retry until load; no memory adoption occurs before confirmed save.
Partial bundle splitting remains explicitly held. Source floor custody now
follows the transaction described below;
this is an ownership hold, not a native no-drop/no-storage rule. No new tests,
parsing, game execution, rendering or CI were run.

## Existing floor lifecycle with typed custody (later implementation, unverified)

The existing one-item drop action now moves a selected native physical object
only when its actual remaining quantity is one. Larger bundles remain held for
an explicit split contract. Raw source IsDroppable, locks, equipped/life state,
existing placement radius/LOS and the real ground manager placement are retained.
`stage_spawn` prepares that existing ground record without a live grant; only
after the inventory/physical/floor candidate saves does `publish_spawn` attach
its existing view. No source image or UI is generated by this code.

Pickup validates the actual selected view, visible delay, range/LOS, weight,
unchanged record and unique physical ID. It saves floor removal plus the exact
same physical object and inventory increment before adopting either side. This
is relocation of an issued unit, never a new supplier receipt or new grant.
Save/load guards now follow carried, warehouse and physical floor custody,
reject duplicate IDs and unexplained removals. The actual World pickup route
uses this owner before source-NPC acquisition and the older generic route.

The existing ground lifetime remains the host rule, not a claimed native item
expiry. Its cleanup now saves a separate `discarded_quantity` and explicit
`TWILIGHT_existing_ground_lifetime` reason with the immutable original receipt;
`used_quantity` does not increase. Thus disposal cannot become item use or free
reacquisition. Protected typed records are not silently removed by generic map
clear/prune/restore. Restore retains an expired typed record until the ready
owner can commit its disposal; failure preserves it and blocks retry on an
uncertain save. The existing manager defers nested pruning during this write.

The physical ID/first grant/receipt/used count stay unchanged through supported
relocations. Actual original UI/image input and runtime observation remain
separate; all new code is unexecuted/unverified, with no new CI or pass count.

## Explicit partial partition ownership (subsequent implementation, unverified)

Partial warehouse requests (within the existing 1..99 request limit) and the
existing one-unit floor action can now partition an actually selected native
bundle. The original parent's immutable schema1 receipt and first grant quantity
are unchanged. Its transferred quantity is separate from used/discarded/remaining
quantity. No source supplier stage_grant is called to manufacture the child.

A child gets a new physical ID and a `source_native_stack_receipt` **schema2
partition** receipt. Its granted_quantity is the allocated branch quantity,
not a new original grant. `origin.kind=owned_quantity_partition` retains the
exact parent ID and complete immutable parent receipt plus partition ID.
`proof_entry` exposes allocated_quantity separately and first_grant_receipt
returns the original root receipt unchanged. This namespace is distinct from
native_awakening_supply's own schema2 supplier record and schema4 catalog input.
The child's record/source/ItemClass/blessing/enhancement is copied unchanged.

The saved source_native_stack_partitions journal ties each parent/child receipt,
quantity and before/after remainder/transfer counters together. Parent transfer
chains, child existence or completed receipts, initial grant budgets and unique
custody are checked at the existing save/load boundary. Original partition rows
cannot be replaced; a new row is accepted only in that exact transient selected
warehouse/drop transaction. Partitioned units are not counted as used, discarded
or free new rewards. Subsequent use/refund/disposal retains their branch history.

Parent remainder, child target custody, both balance dictionaries and complete
partition/use state share one existing save. On failure no live partition is
adopted and uncertain writes block retry. Whole-remainder movement retains the
existing ID without a partition. No old name-only inventory, legacy quest reward
or prior source receipt is mass converted. These are implementation contracts,
not new source rules, source-file use counts, runtime evidence or verified passes.

## Source-reader native-use ABI

`current523_native_stack.use_owned_original(world, original_item:Dictionary,
request:Dictionary) -> Dictionary` accepts the **entire original ItemClass row**
separately from exactly five selected-ownership fields: physical_id, quantity=1,
expected_quantity, expected_remaining, source_native_stack_receipt. Pass the
actual opaque receipt from that physical object; do not reconstruct it from an
ID/name. The original row must equal the held current original and immutable
receipt row; expected remainder must be the actual selected current quantity
minus one. The receipt may be this owner's supplier schema1 or partition schema2.

This delegates to the existing typed quantity/effect/single-save transaction.
Success requires `ok && saved && consumed==1`; handled is recognition only.
Unknown effect owners return source_use_supported=false and preserve ownership.
It does not treat a raw quest-pending record as native ownership: the existing
quest_reward_ownership/quest_item_provider.try_use_held boundary remains separate,
and its handled boolean is not a successful-save result. These are existing
owner responsibilities, not a second source reader or a free native conversion.

The original ItemBookID -> preserved eqc collection/slot mapping and accepted
collection projection are not established by this native consumable interface.
No mapping from display identity or an undocumented ClassID is invented here.

## Original finite buff use and three restoration inputs (later, unverified)

ItemData's existing `typed_references[].buff_definition` graph now feeds the
published compiler's `_timed_buff_spec` mapping in the current native projection.
No new source loader is written: public271's Bonus reader at57641f76 supplies
required Unit and optional UIUnit references, while original BuffClass/Group/
BuffBonus rows arrive through its existing buff reader. The same public
compiler's flat stat names, positive duration, self-target/category constraints,
source group priority/overlap/lifecycle and unsupported action/state predicates
are retained. Unknown/conditional/extra positive effects keep the use blocked.
No probability or source time rule is inferred.

A supported source_timed_buff now follows the same selected physical debit/use
ledger as HP/MP. Its actual source-group replacement and typed fields go into
the existing active_item_buffs/timer/death/cancel/stat consumers. New buffs,
remaining quantity, cooldown, clamped HP/MP and unchanged private RNG share the
same sealed save; no live buff is applied before success. Original sprite IDs
only reach the existing emitter. The original record+opaque receipt use ABI
remains unchanged and now admits these supported finite effects.

Existing exact MP-regeneration376/385 and experience1186 reducers now require
`patch523_monster_drops.current_original_definition(record)` and the schema4
archive proof instead of the historical38ee final-input gate. Their full raw
ID/effect/value/group/lifecycle constraints remain. MP cadence is still the
existing configurable TWILIGHT clock (default30seconds), explicitly not a
verified native interval. The new pure regeneration contract does not assign a
clock during acquisition; actual use rechecks the real user's setting.
Unsupported infinite-food/context effects remain held.

The public271 original restoration reader supplies233/237/236 source values;
its exact selected raw input is compared to the native definition. Additional
237/236 native use requires the complete six-effect/unit/normal-blessing/1000ms
contract and matching original HP dice. It joins the existing HP modifiers and
quantity save, without consuming an old same-name legacy balance or adopting
JSON numeric fallback. No original table/file/item completion count or new
runtime pass is established by these unexecuted connections.
