# Original map shortcut and main-menu state continuation

PR286 continues public `2da34d23b198acb75474eb11a63680757cbb53a1`, based on main `d758bcfc0424baa331fc4b954dbf50aa5343ba63`. Original v30/manual delivery, fixed installer index/62ZIP inputs, v33 candidate, earlier packs and user cfg/saves remain unchanged. These changes are unverified: no tests, compile, game, rendering or CI were run. No PR/main merge, upload or install selection change is performed.

## Original special-dungeon shortcut

- Original chain: `UI/MapScene.csb` Project132 → `UI/Map/Map_All.csb`, SHA256 `f3ed7282f1030de466fdb1c11335889e7d31218eafbed262642f5b84ca0bb46c` → root Node/Btn_SpecialDungeon offset7648 (`Button`) → original Text7700 `특수 던전 바로가기`.
- Original190×41 geometry, normal/pressed/disabled atlas references, label/font/anchor and source input are retained. Source soundid UI_SHOP_OPEN is retained as metadata; sound remains excluded. Only offsets7648/7700 are added to the permitted runtime scope, with their original ancestors.
- `source_main_map_bindings.open_special_dungeons()` checks the live presented map, actual HUD/field and original active button/label identity. Existing source_button mouse/native Android activation calls `HUD.open_source_dungeon_family("special",false)`.
- The HUD validates the existing `SourceDungeonUI.FAMILIES` pair before opening the existing dungeon owner. It checks the actual SourceDungeonView script/workspace and calls `select_existing_family(kind,hard)`. That method selects the existing OptionButton and emits its existing item_selected callback. Unknown pairs are rejected rather than falling back to tower or guessing an index.
- Existing `_refresh()` therefore uses `world.source_dungeon_entries("special",false)` and retains its existing first-row/default presentation policy. No new dungeon row/destination policy is introduced. The shortcut does not call begin/immediate/purchase/claim/recharge/leave, change adaptation settings, consume anything or save. No UIMapWorld/Land/Field IDs are converted into dungeon IDs. This is a UI filter/caller API, not a duplicated dungeon service.
- `_open_window` inside the normal dungeon caller closes the original map through its existing owner path. Additional map285 consumer changes are unnecessary for this shortcut. Original entrance/popup image target relationships remain unestablished; this text/button connection does not supply them to image283.

## Original whole-menu button variants

`UI/Main/Hud_TopMenu.csb` SHA256 `0b0fd7d02b604924dfb1a16f9ef35d71c0e1cfd19e634028b72837499a75ae85` serializes Node/Nd_Set/Btn_All37304 (visible, normal Hud_Btn_Menu0.png/pressed Menu1) and sibling Btn_All_Off36572 (preview hidden, normal Menu1/pressed Menu0).

The optional original Off node follows the same real condition used by HUD.toggle_menu: `active_section == "menu" and workspace.visible`. Build/refresh show one authored variant at a time; unavailable owner state hides both instead of retaining a stale close icon. Each activation retains the expected open/closed state and rejects a release from a stale variant. Both call the existing menu_pressed signal, whose World connection invokes HUD.toggle_menu. The UI does not rebuild the menu page or add its own close/navigation/save policy.

The normal native HUD route still collects these source controls. While the menu workspace (including its search editor) owns input, the workspace-specific Android route additionally receives only the actually visible original Off button. Existing source-search, class-selection, modal/death/result, overlay and PointerTransfer precedence remains in the prior routing. Per-frame synchronization changes visibility only when needed; it does not reset a current pressed texture on each refresh. Older scopes without36572 retain their existing All/toggle behavior.

## Local candidate v34 only

File `TWILIGHT_current523_main_game_original_UI_map_shortcut_menu_v34_20261106.zip`,13,694,969B, ZIP SHA256 `676c2cdcf169ef3329b60483e70f53e093587f6645d0667cbe90b80f6ca000b5`, manifest pin `979aca3dfbda64c1fa95549341e78470f7e5a1467c47f25d49506c52fe79e3c7`. It retains v33 and adds only original Map_All7648/7700 and Hud_TopMenu36572. Proposed relative root: `source-ui/current523-main-game-original-ui-v34`, same TWILIGHT_SOURCE_UI/TWILIGHT_SOURCE_UI_SHA256 selection and original_ui.json/receipt.json/originals/UI structure. No remote ID, upload, installation or selection replacement. Official v30 does not contain these new active scopes. v33 is preserved byte-for-byte as a separate candidate.

Packaging reports74 original files/47 scene trees/46 partial scopes and0 dependency blockers. These are pack units, not a full-UI denominator or actual game consumption. No new images, Sprite frames or replacement CSBs were created or committed.

## Exact remaining contracts in the held UI checked for this implementation

- Detail-stat original lists7140/6400 are empty; the held Detail_List3224/Text templates do not establish stat-key→authored row registration/order. The existing dynamically grouped status table cannot simply be relabeled as original rows.
- Original inventory sort entry19772 and options deletion-date8004/weight4764/category2864 differ from the existing one-shot grade/name sort. That different sort is not silently assigned to those controls.
- Original tooltip enhancement26896 needs the selected physical item→actual enhancement/scroll caller contract. A generic chooser is not proof that the selected item was passed to it. Item-use/wear, batch/cart and production-progress contracts remain distinct.
- Map SelfPosition5852 still requires the existing owner's actual recenter/scroll operation; it is not treated as teleport or movement.
- CSB-root→original-Sprite registration, quest reward identity→authored display slot, card-result background/grade-frame, emoticon and dungeon image target mappings remain unestablished. No node similarity or known coordinate is substituted for a relationship.

The36 previously unresolved dependency scopes are retained separately. This continuation does not claim that all original UI or all currently held source nodes are finished.
