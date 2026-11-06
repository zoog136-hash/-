# Original sell-window carried-inventory filters

The existing sell owner now receives the original carried-inventory component's All/Equipment tabs and supplies its current category state. The original capacity text reads the existing same-current-inventory bag formatter. This is a partial original component, not a new inventory list or complete shop screen. Code is unexecuted/unverified; no tests, compilation, game, rendering or CI were run.

## Actual serialized parent and scope

The existing `UI/StoreScene.csb` SHA256 `8e414c1d179d395048f8fb963c08ccbde12dfcc125f3b0bc1cc4c5fa8b999a68` Project148 mounts `UI/Store/Store_All.csb`, SHA256 `fb2a67543f60e42caa675d8e0b9f1d3834f78c1e2a85645f424da3ef5cbf7c05`.

That original Store_All contains **Project67084**, named `Store_Inventory`, with literal `fileName=Store/Store_Inventory.csb`, authored position `[396.0,-26.999900817871094]` and visible=true. Its child is `UI/Store/Store_Inventory.csb`, SHA256 `d6b4258672c3f45dee0ccfcbf28fed9c5701d43aa0ddc82cab183f374ea07115`. The exact serialized ProjectNode relationship establishes this mount; no positional resemblance or missing-template assumption is used. The child root Node276 retains authored position `[0,0]`, scale `[1,1]`, anchor `[0,0]`, size `[0,0]`, rotation0, alpha255 and visible=true. Renderer retains the complete source ancestry and widget transforms.

Explicit child scope has14 offsets:

| Original control | Nodes and original resources | Original state/position |
| --- | --- | --- |
| All On | Button11684, Sprite12084 `Btn_Tab_Normal.png`, Sprite11736 `Com_Icn_Inventory_All_On.png` | visible=true; `[-125.12920379638672,228.9998016357422]` |
| All Off | Button10224, Sprite10620 `Btn_Tab_Pressed.png`, Sprite10276 `Com_Icn_Inventory_All.png` | visible=false; same authored position |
| Equipment On | Button8804, Sprite9204 `Btn_Tab_Normal.png`, Sprite8856 `Com_Icn_Inventory_Equip_On.png` | visible=false; `[-45.12900161743164,228.9998016357422]` |
| Equipment Off | Button7384, Sprite7780 `Btn_Tab_Pressed.png`, Sprite7436 `Com_Icn_Inventory_Equip.png` | visible=true; same authored position |
| Heading | Text13296 `Label_Title`, original `소지품` | Static original text |
| Count/capacity | Text452 `Label_Count`, original preview `120/120` | Actual bag formatter replaces the preview; missing/current-model mismatch clears/hides it |

Tab backgrounds use `UI_Resource/Atlas_Common.plist`; the literal All/Equipment icon resources use `UI_Resource/Atlas_Common2.plist`. Unchanged original atlas bytes/pixels are packaged privately. No new asset identity or item-image registration is created.

## Actual owner and callback

`source_main_sell_inventory_filters.gd` exports `configure(pack, owner)`, `build()`, `bind_player(player)`, `refresh()`, `select_filter(category)` and `blocks_point(viewport_point)`. Results are dictionaries with `ok`; failure returns a precise `code`. `build()` supplies the exact Project67084/child scope and native source button bindings to the existing workspace renderer. `bind_player` accepts only the real same-pack, non-inspection child player and admitted offsets.

The actual owner must be the visible existing `renewal_sell.gd` in the HUD's active sell workspace and same world. `configure` captures **that owner's actual category OptionButton**. The selector already declares `전체`, `장비`, `소모품` and connects `item_selected` to its own `_refresh()`. The original All/Equipment icon families and this carried-inventory parent are bound only to the corresponding unique actual `전체`/`장비` choices. The current original On/Off variants mirror that exact selector state.

Activation checks the live owner, same captured selector, actual unique choice, separator/disabled state and current selection. It calls the existing selector's `select(index)` and already connected `item_selected(index)` path only when selection changes or the real selector allows reselection. [Godot OptionButton](https://docs.godotengine.org/en/stable/classes/class_optionbutton.html) permits programmatic selection of disabled items, so the adapter guards disabled choices instead of treating `select()` as an availability check.

The existing sell owner retains inventory classification, filtering, row ordering, physical identity, its normal selected-row consequences, search, quantity, quote, automation preview, confirmation, payment and saving. The adapter does not rebuild an item list, pick a representative item, sell anything or preserve an obsolete row across the owner's genuine category-change behavior.

Original consume/other tabs are not admitted: the existing legacy `소모품` branch includes non-equipment beyond an established exact source consume/other split. If the host selects that existing third category, both admitted tab On states are false and their Off states remain available; the adapter does not silently substitute All. Original SlotSet/cart/quickslot content is not cloned or rebound.

## Capacity, lifecycle and native input

The existing `hud.lineage_inventory_ui.capacity_label` is populated by the bag's `_refresh_inventory_grid` from its own `_inventory_entries()` and `max_slots`; world-to-HUD inventory/state updates own refresh. The new adapter only reads that current formatter when the bag inventory equals the actual owner's current world inventory. It accepts its final numeric count/capacity segment, preserving a possible existing weight prefix separation. It never substitutes the sale-filter row count, a source preview120, or a new capacity rule. Missing/invalid data clears/hides Text452. No speculative prepare-model method or new per-frame bag refresh is invoked.

The existing workspace refresh invokes `refresh()`; no new polling or global input loop is installed. Cached presentation avoids resetting a pressed control unnecessarily. Captured owner/selector/player use weak references. Replaced, hidden, closed or invalid owners cannot dispatch; failed refresh hides the four tabs and clears capacity. Workspace close releases the adapter and hides/frees its existing source scene. Original source button routing handles mouse/touch; `blocks_point` uses the actual transformed source input areas to prevent world clicks through visible tabs, without guessed rectangles.

Only packs that already admit the exact child and Project67084 attempt this optional component. Older v43-or-smaller selected packs retain their existing close/automation behavior. `presentation().sell_inventory_filters` and `last_result.sell_inventory_filters_connected` describe code attachment, not rendered pixels or complete-screen/actual-game-use evidence.

## Separate local v44 candidate

The local v44 candidate retains v43's scopes and adds this14-node child plus its exact parent Project67084. Exact local delivery:

- `TWILIGHT_current523_main_game_original_UI_sell_inventory_filters_v44_20261106.zip`,14,249,849B.
- ZIP SHA256 `85f4d7bc290fffbf0f25e723ef2e150a43a9ee959e05a113b29a9e42fc8808df`.
- Manifest pin `d3b4cb80b8d9e873e611c3b893bd9ee27928f5165d35e5795e09b45e29b860b5`.
- Proposed relative root `source-ui/current523-main-game-original-ui-v44`.
-102 originals/61 scoped scenes/60 partial scopes are packaging quantities, not whole-UI completion or actual game-use counts.

 It remains local-only, with no Drive/Library ID, upload, install or phone selection. Frozen v30/62ZIP/index/source bank and every earlier candidate, original, cfg and save remain unchanged. No image/map/data/provider ABI change or additional owner audit is required. Excluded spell-stage, potion, emoticon and sound work stays excluded; runtime/memory diagnosis remains paused.
