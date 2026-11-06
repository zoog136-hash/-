# Original Storage quantity controls: explicit host editor connection

This local, unexecuted UI change connects the original quantity controls to
the existing live `renewal_warehouse.gd` owner's actual `quantity: SpinBox`.
It does not recover the private original controller or its cart policy.

Original parent: `UI/StorageScene.csb`,
SHA `0df424e7ed29a314e112ef618d40f89806c9df6ad6ce56df7dedd5e08e9ebde7`,
Project132 -> `UI/Storage/Storage_All.csb`,
SHA `eb4ddfa71dc9be978fd03948ff938c12e2366f6542ff5844509c47f110b38328`.
The source path is `Node524/Nd_SaleButton34968` and the exact original controls
are:

| Button | Literal Text | Literal | Source icon |
| --- | --- | --- | --- |
|39288|39340|1|39664 Icn_Store_Finish.png|
|37892|37944|10|38268 Icn_Store_Finish.png|
|36496|36548|100|36872 Icn_Store_Finish.png|
|35036|35088|직접 입력|35480 Icn_Store_Input.png|

All source resources reference the retained `UI_Resource/Atlas_Common.plist`.
The twelve nodes retain original transforms, labels, fonts, button states and
icons. The code validates their exact Button/Text roles and original numeric
literals in the selected scope; source names or coordinates alone are not the
assignment proof. The explicit host policy is: use the literal count as the
same current owner's selected-row quantity, and focus its actual LineEdit for
direct input. This is not a claim about original click-to-cart ordering.

`source_main_workspace_controls.gd` constructs
`source_main_storage_quantity_controls.gd` only for the actual warehouse
workspace and only when all original nodes are admitted in its selected pack.
It mounts them in the same existing StorageScene Project132 presentation.
The ordinary source button router and original hit bounds own input; no new
screen, button, keypad, picture or layout is created.

The helper exposes `configure(pack, actual_owner)`, `bind_scene(actual_player)`,
`refresh()`, `set_preset(count)` and `focus_existing_editor()`. It retains weak
references to the actual owner, quantity, listing, mode and action controls.
The owner must be the actual `renewal_warehouse.gd` script; its action button
must already call `_transfer`. Each event/refresh rechecks the same controls,
tree/visibility, selected index against actual ItemList selection, actual raw
entry/record/instance_id/count, direction and current editor range/step.
Changed, freed, hidden or replaced owners are not redirected to another row.

Preset availability is read from the real current SpinBox and selected row.
The existing single-transfer limit remains99. The original100 control is
therefore disabled, never silently clamped/mapped to99. A physical row whose
owner maximum is1 enables only1 and direct input. No partial native-stack,
max-weight, count/price rule, inventory ownership or source identity is inferred.
Before a preset replaces the same editor's unfinished input, its IME is
cancelled where supported and focus is released; the actual selected entry,
direction and range are checked again before assigning the exact value.
Direct input only focuses/selects the existing SpinBox LineEdit; it does not
create an original popup or assert an original mobile keyboard policy.

No transfer/quote/confirm/save is requested by these controls. Existing
`renewal_warehouse._transfer` and its confirmation remain the transaction
owner. The new Integration `quote_warehouse_batch`/`confirm_warehouse_batch`
APIs have been received but not duplicated or inserted into World here.
Original43992/42648 All buttons remain unbound: the current owner has only
one selected row/quantity and no actual player-reviewed batch/cart model.
The original Storage_Inventory/Storage_Cart Project references alone do not
provide that model. A proposed list must not default to all inventory or all
currently displayed rows. This is a UI caller/model gap, not a missing batch
transaction receiver.

## Separate local candidate

The v47 candidate extends the v46 source projection with only the twelve
original quantity nodes above. No original file or pixel was added/changed:
102 original files /17,141,647 original member bytes,61 scene scopes. This is
pack possession, not102 consumed files or full-file use; Storage_All was
already conditionally/partially consumed in the immutable earlier audit.

- Root: `main-game-original-ui-storage-quantity-host-v47-20261106`.
- ZIP: `TWILIGHT_current523_main_game_original_UI_storage_quantity_host_v47_20261106.zip`.
- ZIP bytes:14252902.
- ZIP SHA256: `754e1b2918ca932ddefb49b6b583ce4285067d8cb0e600a0f45677309a70889a`.
- Manifest pin: `5aff8f997b9a3335b76cd9a8cf3acd12eda17fb872f0c48516c205499b1891d9`.
- v46 source manifest: `a9fd8e63a3cde5ac3038cd8befdc592d67a412eaff1251495a703dab11296b4e`.

The source was projected from already held decoded JSON, not by running a
GDScript parser or game. No execution test/render/CI was performed and the
candidate is not selected, uploaded or installed. Old packs, frozen v30/62
ZIPs/index, phone, original files, configs and saves are preserved.
