# Selected original item storage capability and calendar display

PR286 continuation after3e4bffa3abcc0693730a381de247c3c7bfdb03b8, retaining main d758bcfc0424baa331fc4b954dbf50aa5343ba63 and the existing original inventory-detail mount. These are two independent read-only fields on the actual current selected physical item. They are not transactions, new actions, a complete detail screen or observed game consumption.

## Actual owner and receiver

Existing `renewal_inventory._refresh_detail(item_reference)` resolves the selected item's actual visual record through `_item_visual_record`; the existing supplier retains original identity/physical receipts. New optional snapshots carry the exact same `reference`:

- `source_detail_storage`: only a current523 native item with a positive matching raw ItemClass.ID/source_item_class_id and a real boolean ItemClass.IsStorable supplies `value`. Missing flags are not false. This field is original definition capability, not permission to transfer equipped/locked items or choose an account/warehouse category. The current native-stack service already checks this same source flag on deposit; all additional ownership/lock/equipment/capacity checks remain there.
- `source_detail_expiration`: only the existing native projection's resolved positive12-digit `source_delete_time_raw` supplies text. That projection's `date_value` produces **YYYYMMDDHHMM**, not Unix seconds. The UI separates those same calendar fields as `삭제시간 : YYYY.MM.DD HH:MM`. It never subtracts the clock, converts timezone, estimates a countdown or deletes an expired item. Unresolved/nonmatching/unsupported calendar values are absent, not zero/default dates.

The existing `source_main_inventory_lock_view` reads those snapshots only when their reference equals the live selected detail reference. It uses its existing source parent and lifecycle:

- Parent `UI/ToolTipScene.csb`, SHA9304dcb5730fba9a155f73a291a6e87f96768156cee972929b003386e3904a1d, Project1012 → `ToolTip/ToolTip_HudType_Right.csb`.
- Member `UI/ToolTip/ToolTip_HudType_Right.csb`, SHA7aa63b5159335c1558e9bc83f8155979b1a9bf4ee37eaed24c7e2652c392c1ce.
- Existing authored parent position[1008,345], preview visibilityfalse; the actual bag.detail_active/current selection controls activation. No separate position/fit or new parent is created.

| Data | Existing original target | Selected scope |
|---|---|---|
|IsStorable=true|SingleNode55344 Warehouse_On|ImageView55716 and literal Text55400 `창고`|
|IsStorable=false|SingleNode54036 Warehouse_Off|ImageView54796, original crossed-out ImageView54412, literal Text54096 `창고`|
|Resolved source deletion calendar|ItemInfo/Text42072 Text_1_0|Replaces only the authored deletion/remaining-period preview text; unknown hides it|

Both warehouse icons use their serialized `Com_Icn_ToolTip_Box.png` in `UI_Resource/Atlas_Common.plist`. The false branch's original cross is `Icn_Btn_Close_On.png`. Original color differences, icon geometry, source parent chain and fonts are retained by the existing renderer. No image descriptor API, newly drawn icon, physical inventory icon or pixel resolver is added. These source nodes already exist in the supplied component.

Runtime scope is optional: older v30/v37 packs omit these offsets and retain their existing behavior. If the new scope is present, valid true/false shows exactly its original branch; unknown hides both. Calendar text refreshes with the same selected item; missing data clears/hides it. Selection replacement closes/remounts through the existing lock-view lifecycle, and invalid/hidden/freed owners close the view. Existing lock/title/class/safe-enhancement/close callbacks are retained. `presentation().source_node_offsets` now reports the actual extended presented scope rather than only the initial base offsets.

## Local candidate, not phone delivery

v38 retains v37 and adds only six explicit original offsets55716,55400,54796,54412,54096,42072 to the existing tooltip scope. No source bytes are edited and no new art is made.

- ZIP `TWILIGHT_current523_main_game_original_UI_inventory_storage_expiration_v38_20261106.zip`,14,202,081B.
- ZIP SHA256 `8358191b5c59c0798174eac82fdde4da28e9179dd9c2e062675ee0db9b2bdadb`.
- Manifest pin `029e2877fd6d1ba20aa756e48149470c8cf6136fe1b66207790a39e5e711cbd8`.
- Proposed relative root `source-ui/current523-main-game-original-ui-v38`;99 original files/58 scoped scenes/57 partial scopes are packaging quantities, not full-UI progress or game use.

No remote ID/upload/install/index/source-bank/phone change. Frozen v30/62ZIP and v33–v37/Sprite candidates, originals, configs and saves are preserved. No tests, compile, game, render, fullCI or merge. Code is unexecuted/unverified.

## Independent result/dungeon image contracts remain pending actual mounts

Read image PR2833b5a336e5fcfbbbefa77757270201bc8ea3927d6 and3a79b5acc2ef3a9262b9efd6b1962629b3ecd0de. The latter's exact `source523_special_entrance_binding.bind(owner: Node, registered_player: Node)` handles selected-entry image assignment/clear only after receiving the genuine mounted ImageView player. It requires the actual source_dungeon_view to be the renderer's ancestor, matching component/pin/widget identity and our existing selection/lifetime signal. No adapter code was duplicated here. Panel392→ListView_Daily2560 insertion remains unestablished, so no artificial mount or automatic call was added. Result source-parent→Face registration and complete selected mixed quest-reward presentation/overflow also remain pending; existing coordinates are not relabeled as recovered controller relationships.
