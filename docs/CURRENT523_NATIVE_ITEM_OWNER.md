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
Their floor-splitting and warehouse transactions remain explicitly held pending
a typed transfer owner; no whole stack is moved while inventory decrements one.
This is a host ownership safety hold, not a claim that the source item forbids
storage or dropping. Other native materials/bags/books/effects remain outside
this narrow quantity/use connection. No new run, test, save or pass is claimed.
