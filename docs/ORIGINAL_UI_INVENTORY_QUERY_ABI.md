# Original expanded inventory query caption and reset

PR286 continuation aftercbfcdc4aec506efad500bf7028a5dd2d81a2bba8. This completes a coherent missing part of the already connected original expanded inventory search bar: live query caption, query-reset input and original enabled/disabled branches. No generic replacement editor, result rows, category/quantity/sort rule, ownership operation, save or source popup-cancel rollback is introduced. New code is unexecuted/unverified; no tests/compile/game/render/fullCI/upload/merge were performed.

## Actual editor/owner

The existing bag's `search_line` is a real LineEdit whose text_changed is already connected to `_on_search_changed`. That handler invokes the existing bag grid/filter refresh. The existing original Inventory_Popup_Keypad input adopts this **same** editor with its own source text-field/IME boundary, and its apply_query calls that same owner handler. No second editor/filter is created.

`source_main_inventory_bindings.configure` captures this actual editor weakly. `_search_display` requires that it is still exactly bag.search_line. It supplies the actual raw text and whether the editor is editable and has a query or in-progress composition. Missing/replaced editors do not expose stale text or an enabled reset. Current query/editability/composition/editor identity now participate in the existing native inventory refresh signature; no new polling loop or global input path is added.

The original search button caption is the current same-editor text when nonempty, otherwise the exact original prompt from the held node. Its empty prompt is not retranslated or reconstructed. Query case/whitespace are retained for display; the owner's existing name filter still owns matching/normalization.

## Exact original node evidence

Member `UI/FloatingUi/Inventory_All.csb`, SHAc2c021fbc49f0699f2002a3f1cb73f523c3dd629bd1df567192dcb7f4da22293; existing top parent `UI/FloatingUiScene.csb` SHAb689e91a9fc15eda9c35bed5b1073588a33a416a57890c293c531fe5c69ccbc8 Project1572. The existing parent/Inventory_All_On/extension selection, authored coordinates, frames, slot placement and native input remain unchanged.

All new behavior is within the original extended search bar Node636/Nd_BG_Extension43300/Nd_SearchBar44724:

- Btn_Search44780/Text46132: original prompt `아이템 이름을 입력하세요.` establishes this actual name-query display, alongside the already connected search editor action.
- Btn_Reset_All47700: original Text48368/47804 both say `초기화`, under Normal48312/Disabled47752. Its actual search-bar parent and adjacent name-query field establish this search-bar reset scope. It is not used as a global inventory/category/order/rule reset or source select-all/MAX control.

`build` includes the reset subtree only in expanded mode and when all five exact offsets are already admitted by the selected pack. Source Normal/Disabled branches follow real editor availability; existing pressed texture is retained when state has not changed. Refresh reapplies their dynamic visibility after source extension-frame state without resetting other controls. Old smaller packs omit the new reset while retaining existing search open/apply behavior.

## New receiver method and reset semantics

`source_main_inventory_bindings.reset_search_query() -> Dictionary` is bound to original47700. It requires the live visible actual Inventory_All renderer, that existing original reset node, the captured/current same editor, editable nonempty/composing state and the real bag `_on_search_changed` callback.

The method cancels the actual editor's composition if supported, clears that same LineEdit, invokes the existing owner handler with its current empty text, refreshes the original caption/state and emits the existing model_changed notification used by the native inventory presenter. It does not rebuild a separate item model, choose another category, sort references, reset capacity, remove items, clear saves or invoke a transaction. The actual current selected reference and any refresh consequences remain with the existing bag/presenter.

Godot's official [LineEdit documentation](https://docs.godotengine.org/en/stable/classes/class_lineedit.html#class-lineedit-method-cancel-ime) defines cancel_ime as discarding pending composition and clear as erasing text. Method guards retain compatibility with a runtime that does not expose the composition method. This is editor behavior, not new game-search semantics.

The already existing original popup close/cancel continues to retain the current live query; it is not silently changed to restore a prior value. The new reset is its separate explicit original search-bar action. Native mouse/touch and pointer-transfer precedence use the existing original renderer/router. Source inventory row-capacity/image admission restrictions are unchanged; reset cannot fabricate extra original slots or bypass a rejected presentation.

## Separate local v43

v43 retains v42 and adds five explicit original offsets47700,48312,48368,47752,47804 to Inventory_All. Existing46132 already belongs to the search scope. Original bytes/pixels are unchanged.

- `TWILIGHT_current523_main_game_original_UI_inventory_query_v43_20261106.zip`,14,237,667B.
- ZIP SHA256 `93c35c6bfc5e8e5830807e4e7446c64ec0bc93e5c3f7bfa3d35faab2a3485a16`.
- Manifest pin `054e466c8cb09f84862e4320ef25fe9557b3d06cf2ddad855a3d4829a438e4ba`.
- Proposed relative root `source-ui/current523-main-game-original-ui-v43`.
-101 originals/60 scoped scenes/59 partial scopes are packaging quantities, not a full-UI progress or observed game-use count.

No image/provider/map/data/integration API changes or extra consumer audit are required. Map/data owners' files and pending fixed PR281/PR287 candidates were not touched. No remote ID/upload/install/index/source-bank/phone change. Frozen v30/62ZIP, all earlier candidates/originals/configs/saves remain preserved. Exclusions remain intact and runtime/memory diagnosis was not resumed.

The original inventory sort submenu was read to avoid an incorrect alias: its deletion-date/weight/category controls are distinct from the bag's current one-shot grade/name, count and name order modes. They were not mapped to those unrelated modes. No new row cloning/order or image role was fabricated.
