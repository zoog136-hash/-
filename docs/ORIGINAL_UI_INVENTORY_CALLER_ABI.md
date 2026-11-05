# Original bounded inventory presentation (unexecuted)

The existing `renewal_hud.toggle_inventory()` prepares the current bag and then
tries the original presenter. It hides the current workspace only after the
native scene accepts every current filtered row and all required original
pixels. Missing source inputs or unsupported states leave the current complete
inventory behavior available. This does not select another old asset pack or
claim final original UI completion.

## Authored scope and owner model

The existing owner's grid.columns / window expanded state selects either the
original four normal slot projects5464/5212/4972/4732 or the original eight
extension projects3900/3660/3420/3180/2940/2700/2460/2212. The entire current
filtered ordered model must fit that authored row. Search/detail modes or
additional rows are not silently reduced. No row pitch, repeated slot, capacity
purchase, page or sort rule is created. If both owner state fields are present
they must agree before presentation replaces the current bag.

The expanded branch uses Inventory_All original Project44156/Scroll43832,
background54484 under Nd_BG_Extension43300, and Inventory_Slot_Set's original
Nd_Slot_Extension1856. Its current state consumes Fx_Extension_On end frame70
(source clip40..70). Normal geometry and original child coordinates are retained.
Original Expand21648, when actually included in the selected pack, calls the
existing bag._toggle_expanded() and refreshes through the same owner window.
The extension-lock row is not interpreted as capacity or purchase rules.

`renewal_inventory.prepare_source_inventory_model()` reuses the same reference,
filter and acquisition-order producer used by its current grid. The native
view can obtain fresh data while older controls are hidden; it does not copy
ownership/filter/order implementation. Existing UI preference normalization
and order-saving behavior stay with that owner. The base bag uses legacy_rows;
Renewal uses its current sorted_references and exact owned references.

The supplied parent is UI/FloatingUiScene.csb, SHA256
`b689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8`,
Project1572. The host consumes the original Inventory_All_On frames5..17 once
per logical open. This is the actual named source clip; no original loop
declaration is claimed. A refreshed staged view keeps its prior clip frame.
The alternative nested FloatingUi parent is not substituted.

Inventory_All retains source frame60672/59888/59516/59136/58756/58376, its
original close/category variants and sprites, and existing gold/capacity text.
Normal slot Project56036 points to Inventory_Slot_Set. Each authored slot
points to UI/CommonUi/Common_Slot.csb. Full raw originals and ancestor
transforms remain unchanged; these are explicit partial scopes.

## Existing original image owner

Common_Slot icon15012 is an explicit external source_asset_slot. Its editor
sample is not used as an item picture. `source_main_inventory_images.gd` calls
the public PR270 methods only:

```text
bag._item_visual_record(reference: String, fallback: Dictionary) -> Dictionary
source523_image_assets.describe_item(record: Dictionary, title: String) -> Dictionary
```

The first API is grounded in public af2051a6c1181a1b0e024fb75dc3e386361094e8.
It retains the physical reward record when appropriate. No such record, asset
join, exclusion or alternate name lookup is recreated by this presenter.
Only an owner descriptor with route source523_images, status original_linked,
original_bytes_unchanged=true and actual Texture2D is normalized for the shared
source renderer upload API. That renderer still requires the owner's exact
format/provenance. Missing/dummy/test/unsupported images are not replaced by a
sample or old pack. Every assigned row needs its real original image before
the native view can replace the current view; an empty bag needs no item image.

## Actual input and lifetime

The presenter exposes its original button Control, final texture and opaque
reference to the existing PointerTransfer. Native hits and chrome take priority
over quickslots behind the source window. The same existing tap/double-tap,
hold/drag, quickslot assignment, equipment/drop and reorder paths are reused.
Single click selects only. Explicit use calls the existing selected-item path
after fresh owned-reference/filter validation; no cost, consumption, receipt or
save implementation is added. Drag preview uses the existing source material
for its original premultiplied pixels.

HUD entry helpers are `original_inventory_is_open`, `original_inventory_hit_at`,
`original_inventory_gesture_bounds`, `original_inventory_select` and
`original_inventory_activate_selected`. The original close button/Escape/other
window transition releases the native scene. If the owner model changes to an
unsupported state, the presenter safely closes and requests restoration of the
same complete current bag. Selection and owned records are preserved.

`source_main_inventory_view.gd` low-level API is configure/open/is_open/close/
refresh/select/activate_selected/hit_at/gesture_bounds/blocks_point/presentation.
Configure only means prepared. `open(...).handled=true` is the explicit native
presentation acceptance; it is not actual render or whole-screen proof.

## Pack and remaining scope

The separately delivered normal4 candidate adds four explicit inventory scopes to the
prior main/map subset: 33 originals, scene trees16, partial scopes15, blockers0,
manifest `4f5bffdd6ad96917ac8795f3313e4da0ace4a59821f9439783a410509931e4c1`.
Its status is STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER, and its external
inputs are Area44440 and Common_Slot15012. The existing installer's canonical
v5 Drive file/pin remains unchanged; a producer output is not installer receipt
or external pixel delivery.

The normal4 candidate is on private Drive as `1RIdxVtVA3q9cWsrr3FWq8Kea6_ceNeTV`,
ZIP SHA `40abf0125a370a12e1ebe24638c504e98b683711cec051c5184174711fef99fb`,
11,935,660 bytes. The later expanded8 code requires a later pack whose scopes
actually contain the extension nodes; this normal4 candidate is preserved.

More rows, original detail/search/sort controls and original icon
effects remain incomplete. The whole560 connection numerator is not established.
No new test, game execution, render, quality assessment, audit or CI was run.
These interfaces and the normal-view restoration remain unexecuted/unverified.

The separately delivered expanded8 + quickslot candidate is documented in
[the installer handoff](ORIGINAL_UI_MAIN_PACK_INSTALL_HANDOFF.md#separate-expanded8--quickslot-candidate).
It actually contains the extension frame/slot scopes and original expand
button. This is pack production and code connection, not executed presentation.
