# Nonwearable native event enhancement: save contract

Scope: 64 non-test ItemClass IDs: 60 in 21 exclusively nonwearable probability
families, plus four shared-family targets (#234774, #234784, #234794, #234824;
groups 2/724). All 64 declare equipment-side BonusType 2032, have zero ItemEquipSlot rows, and declare
MaxStackAmount=1. These are exact enhancement targets without source-backed
equipment slots. They are not the 17 IDs with absent original rule data. The implementation deliberately stores the distinctive rank marker in the
single physical entry beside the existing original receipt, not in a second
independent per-account map. This naturally follows the durable physical UID
into selected/dormant character storage without duplicating a proof owner.
The original storage entry's equipment level remains 0.

## Proposed owner and invariant

Own a distinct per-native-receipt rank namespace, not equipment and not a name
aggregate. The active `source_native_event_enhance_rank` field is paired with
the same item's single live unit and exact original ItemClass/receipt identity. At rest, native storage entry `level` remains 0;
the token display, eligible event exchange and enchant quote read only the
single physical receipt's independent rank. Start at rank 0 with absent row;
no old items are reissued. Keep original lifecycle, locks and owner generation
binding. Reject known/unknown server gates as the current rule interpreter does.

## Transaction

1. Obtain the token and scroll by exact physical IDs, original pack identity,
   current receipt, exact residual quantity, original blessing, current rank
   and account/save generation. Do not trust the name, an expired preview,
   a clicked slot index, or the old inventory aggregate.
2. Shared current native rule interpreter resolves a unique exact target/scroll
   group and original stage/cost/outcomes. Same source lifecycle checks apply.
3. Stage an exact scroll debit via the existing native quantity owner. If the
   target receipt has more than one remaining unit (old bulk supply), call
   `prepare_partition(..., 1, ...)` on the staged state. Preserve the parent
   receiver, original consumption and transfer history; the independent child
   is always one unit. MaxStackAmount=1 means future supply should issue
   one-unit native receipts rather than aggregating such tokens, but this is
   not a requirement to delete or rewrite preexisting receipts.
4. Draw on a detached RNG and candidate. On success/side-effect write the
   child/single receipt rank (not all units); on remain do not modify rank.
   On original destruction close that exact receipt with a target debit, keep
   immutable acquisition/partition lineage, and remove its active rank row.
   Use no second save or sidecar. Candidate contains bag aggregate, physical
   instances, ranks, use ledger, partition journal, exactly one permitted RNG
   result, fee and outcome; commit with the existing atomic save.
5. Only after confirmed durable save publish aggregate, item identity, rank,
   fee and RNG. Failed save leaves all old state untouched. An uncertain
   write follows the existing protect/reload rule; never automatically reroll.

## Boundaries required before enabling

- `current523_native_stack.override_error` currently permits newly appended
  partitions only for `partition_warehouse` and `partition_drop`; the token owner
  needs a third candidate kind scoped to the one exact parent/child and scroll
  debit. Do not relax generic permission or use an unchecked mutable save.
- Validate rank state and old-to-new changes in the same single-writer owner
  before snapshot. The rank validator must bind an entire row to one live
  receipt and reject replacement, duplicate/missing active receipt, wrong
  original ItemClass, wrong rank range, unqualified/forged transition, and
  unapproved consumption from any other owner. A completed target receipt is
  still needed by the immutable parent/child use and partition journal.
- `consumable_service` explicitly imports/exports recognized keys and
  `account_store` has a shared native proof list. The implementation avoids a
  second shared proof map: the physical entry holds the rank and the existing
  selected/dormant ownership check validates it with the exact UID.
- Initially refuse warehouse, sale, floor drop, merge, expiry discarding, and
  name-only handoff for a ranked token before any side effect; no arbitrary
  custody effect yet. Original MaxStackAmount=1 already prevents stock merge,
  but do not depend on that alone. Extend only a verified event exchange to
  close a rank receipt. Unenhanced tokens retain the current owner behavior.
- Add exact tests for single and bulk native acquisition, two physically
  identical tokens, partial partition selection, disallowed moves/reuse,
  safe stage and four original outcomes, explicit existing policy unit
  interpretations, writer failure after validation, competing stale receipt,
  crash/reload, save/account switch and deactivate/activate, warehouse/dormant
  records, and wallet/RNG consistency. Use actual Main signals for accepted
  cases; rely on exact current source, not fabricated equipment stats.

No implementation should merely store the rank on the whole existing native
storage stack (`proof_entry` requires `level==0`), reclassify it as equipment,
or use a separate persistence file that could run ahead of the inventory.

## Scoped verified implementation

- Only the 64 pinned ItemClass IDs, authenticated source rules and physical
  normal/variant receipts can enter this route. No new wearable slot, source
  probability, transfer, market or event exchange rule is defined.
- Bulk legacy receipts preserve their parent and split one child using the
  original native partition owner when an outcome changes the selected unit.
  Ranked units themselves must have exactly one live unit. Existing unranked
  supply ABI is unchanged (legacy counts are not rewritten).
- The dedicated rank marker is written with debit, wallet, RNG and native
  partition/use journals through the exact scoped candidate authorization.
  Warehouse, ground, ordinary sale/debit and competing save reductions cannot
  move or consume ranked tokens. Inventory only displays their distinct rank.
- Original Main test: #234774 쿠작의 두건 and #6411 갑옷 마법 주문서 (각인), group
  2. Tests cover bulk split, injected writer rollback, one selected child rank
  0→4, original +4 destruction branch, stale selection, blocked transfer/sale,
  physical lineage, fees/scroll conservation and actual reload.
