# Explicit reviewed warehouse host cart (local, unexecuted)

This is an explicit TWILIGHT session selection policy, not recovery of the
private native Storage_Cart controller. It creates no inventory, physical ID,
price, fee, grant or source relation. Existing single-transfer `_transfer`,
drag/drop and their confirmations are unchanged.

## Actual player entry, removal and full review

The existing `renewal_warehouse.gd` owns `reviewed_batch`, an instance of
`scripts/ui/warehouse_reviewed_cart.gd`. It connects the existing ItemList's
`item_activated` signal (double-click/Enter). Native touch currently emits only
selection; the actual owner's `_input` forwards an explicit double-tap gesture
to the cart without consuming or changing the native list's selection. A
cancel/drag/changed row never stages. The gesture captures the actual selected
row's count and rechecks its identity/range after native release selection.
This is a declared host gesture policy, not an original-client event claim.

Only deliberate activation stages the current raw entry and exact quantity.
Activating the same physical/source entry with the same quantity removes it;
a deliberately changed quantity replaces that entry. No row is staged by
programmatic first-row selection, ordinary selection, count editing, direction
change, refresh or reopening. Different directions cannot be mixed. Staging
order is explicit user activation order, not claimed original table ordering.

The existing owner summary/tooltip shows the host policy and the entire cart,
including direction, names, quantities, nonempty source IDs and physical IDs.
No new UI node/artwork/keypad/layout is created. Invalid/noncanonical records,
missing owned quantities or changed physical records are rejected. The exact
current catalog DTO must equal the row record; source IDs are never inferred
from names or generated. Quantity is integer1..99 and within the real editor's
range/current row count. Source-native partitions remain the World owner's
responsibility: an unsupported native row causes the whole quote to fail.

The quote uses World `quote_warehouse_batch(direction, entries)` with entries:

```gdscript
{
  "item_name": actual_row.name,
  "source_id": actual_row.record.sourceId,
  "instance_id": actual_row.instance_id,
  "quantity": actual_reviewed_integer,
  "record": actual_catalog_dto.duplicate(true)
}
```

Quote success must match the exact entire list/direction and declare atomic,
save_count1, confirmation_required, per-entry limit99, unchanged single-transfer
cost policy and native_partial_partition_supported=false. Missing/incompatible
API/shape is not treated as a working transfer. There is no single-transfer loop.

Every quoted entry receives its own existing `confirm_action` page displaying
the exact name, source ID, physical ID, count and direction. This avoids silently
truncating an arbitrary mixed cart to a representative item. `다음` reviews the
next entry. The existing cancel control is explicitly labelled `이 항목 빼기`
and removes only that exact reviewed entry, invalidating the quote. Escape or
closing a review merely invalidates it and keeps the cart. A final existing
confirmation gives direction, total entry/count, one-save policy and calls
`confirm_warehouse_batch(quote_id, request_id)` once. Request ID is generated
once for that review; it is not a source identity. Phase is set to confirming
before calling World, so a duplicate/reentrant callback cannot call twice.

Row selection, count, direction, row/source model changes, hidden/closed owner
or changed weak control identities invalidate review. Each review callback
compares the current context and each exact owned intent again. World still
revalidates its complete snapshot and staged payload before the one save.

Only exact confirmed success (ok/saved/save_confirmed/live_adopted, matching
quote/request/direction/entries and save_count1) clears entries as transferred.
Known no-save refusal retains the cart. An uncertain/malformed/attempted but
unconfirmed response holds the cart, issued quote, request and result; there
is no retry, refund or optimistic live adoption. Hidden/closed held carts are
preserved in World metadata `twilight_warehouse_held_ui_carts` and restored as
session evidence, not reissued requests. These metadata are not save payloads.

## Exact original All controls and admitted source scope

`UI/StorageScene.csb` SHA
`0df424e7ed29a314e112ef618d40f89806c9df6ad6ce56df7dedd5e08e9ebde7`
Project132 -> `UI/Storage/Storage_All.csb` SHA
`eb4ddfa71dc9be978fd03948ff938c12e2366f6542ff5844509c47f110b38328`.

- Button43992 / Text44324: original `모두 찾기`, withdraw only.
- Button42648 / Text42980: original `모두 맡기기`, deposit only.

`source_main_storage_batch_controls.gd` validates the actual Button/Text roles,
literal labels and selected source SHA. It mounts them through the existing
workspace source presenter, preserving original geometry/textures/fonts and
using the existing source button/touch router. Only the current direction is
visible; empty cart, missing batch API, busy/uncertain owner and wrong phase
disable the control. "All" means exactly the explicit reviewed cart above,
never all inventory or every displayed row. This mapping is the host policy.

Storage_Inventory46840/Storage_Cart46564 originals are not admitted in the held
combined pack; their references are not a proven dynamic insertion contract.
That specific visual mount remains pending. The real host model uses the
existing live warehouse list events as authorized, rather than fabricating
template offsets. Optional activation FX Projects44044/42700 are outside this
four-node partial scope and are not played, looped or called recovered.

## Callable APIs and Integration review boundary

Actual `renewal_warehouse` view:

```gdscript
original_reviewed_warehouse_batch() -> Dictionary
review_original_warehouse_batch(direction: String) -> Dictionary
accepted_warehouse_batch_owner_load(actual_world: Node, receipt: Dictionary) -> Dictionary
```

The model also exposes `stage_current()`, `remove_reviewed(exact_intent)`,
`snapshot()`, `available(direction)`, `review(direction)`,
`accepted_owner_load(actual_world, receipt)` and
`request_discard_after_restored_load()`. Snapshot includes phase, direction,
entries, issued_quote, last_result (including ui_request), recovery_history,
generation and actual World instance ID. No serializer/transaction owner is
duplicated in UI.

Integration must forward the actual successful final load receipt returned by
its existing `accepted_load(self)` to the UI-owned static bridge. This also
handles held cart metadata when the warehouse window was closed during load:

```gdscript
if batch_restore.get("ok", false):
    var ui_cart_path := "res://scripts/ui/warehouse_reviewed_cart.gd"
    if ResourceLoader.exists(ui_cart_path):
        var ui_cart: Script = load(ui_cart_path)
        var ui_restore: Dictionary = ui_cart.accept_successful_owner_load(self, batch_restore)
        # Inspect ui_restore/live_cart_result; this optional UI handoff must
        # not turn a successful World load into another transaction/retry.
```

This is a requested narrow Integration-owned hook, not installed into World
by the UI owner. Failure/held restoration must not call it. UI checks actual
same World, receipt.owner_load_accepted/pending_intent_replayed=false and the
real batch owner's cleared busy/uncertain guard. It archives old saved:null
evidence and old quote; it never changes that outcome or resubmits an intent.
The restored cart remains held pending explicit player discard. A deliberate
next activation opens an existing confirmation labelled `검토 카트 비우기`;
only that approval clears session intents. Old receipts/recovery history stay
preserved. New staging must then be deliberate again. No new quote/confirm is
automatically issued by load, reopening or discard.

`static accept_successful_owner_load(world: Node, receipt: Dictionary) -> Dictionary`
additionally requires the real `explicit_warehouse_batch.gd` script and a
nonnegative integer receipt.invalidated_quotes. It updates only this same
World instance's held UI session snapshots. Prior entries, result/saved:null
and full quote evidence are preserved in recovery_history; old quotes are
invalidated and the phase becomes restored_pending_discard. Other Worlds,
unknown shapes and unrelated metadata are not promoted to recovered carts.
Repeated forwarding does not append a second recovery entry for an already
restored closed snapshot. A current live cart receives the same actual receipt
through its existing instance method; its distinct result is returned as
live_cart_result. A hidden/unavailable live view is not represented as restored.
Reopening reads the now-restored held snapshot, so receipt delivery no longer
depends on a window being open at load time. It still requires explicit discard
before any new deliberate staging, and never infers the old write outcome.

Before entering the World confirm call, the UI now records the exact pending
request ID/quote/list with saved:null. If the owner closes during that call,
the actual returned completion updates that same held request and preserves
its pre-result snapshot. Only the already strictly validated success branch
records confirmed completion. No later load fabricates a success receipt.

The complete World batch/recovery patches remain Integration-owned. They were
not copied into this UI checkout or World replaced. Until those methods and
the final-load forwarding hook are composed, this candidate reports those
exact dependencies rather than claiming a transfer/recovery execution.

All code/source candidates remain local. No test, compiler, parser, game,
renderer, CI, upload, publication, merge, phone or save operation was run.
Original files, frozen v30/62ZIPs and v47/prior candidates are preserved.

Separate v48 candidate: `TWILIGHT_current523_main_game_original_UI_reviewed_warehouse_host_v48_20261106.zip`,
14253619B, ZIP SHA256 `82d508c58d551f6e2ebe825670c68d691699f52df0fbefd79f91d90784898555`,
manifest pin `7e454388861c59090f6064d79910b1921736d352c8d8bafcd65c6d8c04159c54`.
Root: `main-game-original-ui-reviewed-warehouse-host-v48-20261106`.
Only the four original All control/label nodes extend v47's source projection.
There are102 original files /17141647 original member bytes /61 scene scopes,
with no new/modified original files. Pack possession is not consumption or
full-file use; original Storage_All was already a partial consumer. Nothing
was uploaded, selected, installed or applied to the phone.
