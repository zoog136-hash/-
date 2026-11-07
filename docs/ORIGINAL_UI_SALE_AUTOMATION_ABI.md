# Original sale automation controls to existing actual sell owner

PR286 continuation aftere38b73816c42df67d6aa02054be9391a7d7cb3eb. This connects a coherent source-declared sale control group to the existing sell/automation owner: main close, automatic-sale settings and automatic cart preview. It does not convert a single-item transaction to an all-items action or implement a new cart, quote, price, execution, confirmation or save operation. Code is unexecuted/unverified; no tests/compile/game/render/fullCI/upload/merge were performed.

## Actual caller and source role proof

The existing HUD.open_item_sell() opens section `sell`, mounts `renewal_sell.gd`, configures that screen and exposes its existing entries/selected quantity/physical item state. That screen creates `renewal_auto_inventory.gd` as `auto_controls`, then calls `configure(self,"sell")`.

The automation owner already creates these actual controls:

- `AutoActions/AutoClear`: existing pressed callback calls `hud.open_inventory_automation_settings(mode)` with that owner's actual `mode`.
- `AutoActions/AutoFill`: pressed is connected to the existing `_fill()`. That method calls `inventory_automation.preview(mode)`, displays existing cart rows/payment/skipped reasons, retains the existing stamp and opens its existing confirmation. Only its existing accepted callback invokes execute and refresh. No new automatic acceptance or immediate sale is added by UI.

The original Store component explicitly has parent `Nd_AutoSale` and literal `자동 판매 설정`/`자동 담기` controls. Those labels and the actual existing owner's sell-mode callback establish this correspondence; it is not inferred from generic button names or NPC IDs. This is a connection to TWILIGHT's existing saved-rule cart/price basis, not a claim that the original client's automatic-sale rules or prices were recovered.

## Exact source receiver

- Parent `UI/StoreScene.csb`, SHA8e414c1d179d395048f8fb963c08ccbde12dfcc125f3b0bc1cc4c5fa8b999a68, Project148 → `UI/Store/Store_All.csb`.
- Member SHAfb2a67543f60e42caa675d8e0b9f1d3834f78c1e2a85645f424da3ef5cbf7c05. The same proven original component parent is already used for the existing NPC-store close; the real current owner/section now also distinguishes the sell caller. No parent registration, viewport fit or new component is invented.

| Original path/role | Scope | Actual existing owner action |
|---|---|---|
|Node/Nd_TopMenu/Btn_Close67396|Existing close offset|HUD._close_workspace, preserving current selections/data|
|Node/Nd_AutoSale21984/Btn_Auto_Set26364, position[-396,-270]|Icon28124 and literal Text27780 `자동 판매 설정`|Actual `auto_controls/AutoActions/AutoClear.pressed` callback with its existing sell mode|
|Node/Nd_AutoSale21984/Btn_Auto22048, position[270,-270]|Normal22996/Text23384 `자동 담기`/Icon23052; Disabled22100/Text22488 `자동 담기`/Icon22156|Actual `auto_controls/AutoActions/AutoFill.pressed` -> existing `_fill()` preview/confirmation flow|

Original widget positions/anchors/scales/color/alpha, source button skin, original icon pixels and Normal/Disabled branches are retained through the existing source renderer. Settings activation FX nodes are outside this partial scope because no new animation/repeat policy is established. No new image provider, image target or art was added.

The separate original `Btn_Sale24508`/`모두 팔기`, generic `Btn_Sell33372`, quantity shortcuts, buy branch and original cart/list modes are **not** rebound to a selected-item sale or the preview callback. Existing owner transaction buttons remain their own paths. No event order between those unbound original controls is fabricated.

## Runtime UI boundary

`source_main_workspace_controls.SPECS["sell"]` identifies only the exact renewal_sell.gd owner, actual visible workspace and active sell section. New optional offsets are admitted only when present in the selected pack; older packs retain their original close-only scope. Current NPC buy/shop behavior is unchanged.

`_sale_automation_model(current)` requires the exact renewal_auto_inventory.gd script on an actual child of that owner; host/hud/world equality; mode `sell`; unique real Button descendants AutoClear/AutoFill; a current pressed connection for settings and the actual `_fill` connection for fill. It carries those existing buttons, visibility and disabled states. No saved rules, selected item name, price or quantity is reconstructed by the UI.

`_sale_automation_requested(kind)` is bound with only `settings` or `fill`. It rechecks the actual visible owner and the initially captured button objects before dispatching the real pressed callback. A replacement/missing/hidden/disabled owner button cannot receive stale source input. It acknowledges callback dispatch, not transaction success or save completion.

Refresh follows actual availability, preserves a current pressed texture when state has not changed and updates original fill Normal/Disabled branches on a real change. Missing/replaced buttons hide/disable their source controls. Workspace mode/owner changes close the scene and release captured references. Existing main HUD native source-button routing and actual source input bounds cover these controls; no mouse emulation, guessed hit rectangle or new global input handler is introduced.

No image/data/integration API change is required: providers, physical rows, selection, quantities, costs, quote stamps, rules, exclusions, confirmation deduplication and atomic save/error behavior remain the existing automation/transaction owners'. `last_result.sale_automation_controls_connected` reports UI code scope only, not observed execution or full Store completion.

## Separate local v41

v41 retains v40 and adds only8 original Store offsets26364,28124,27780,22048,23384,23052,22488,22156. Original bytes/pixels are unchanged.

- `TWILIGHT_current523_main_game_original_UI_sale_automation_v41_20261106.zip`,14,235,456B.
- ZIP SHA256 `4e6772fd7d554317ed7921cd162b51eb8006de4c2cf29d7dc259081ef6d2f563`.
- Manifest pin `714d6a17fce33f02cd9f16865fe5744abe80965233428df68ae71b2794657c9e`.
- Proposed relative root `source-ui/current523-main-game-original-ui-v41`.
-101 original files/60 scoped scenes/59 partial scopes are packaging quantities, not overall UI completion or game-use percentages.

No remote ID/upload/install/index/phone/source-bank change. Frozen v30/62ZIP and all existing local candidates/originals/configs/saves are preserved. No image-provider/card-consumer files were changed. Runtime/memory diagnosis remains paused. Excluded spell-stage/potion/emoticon/sound targets were not resumed. Unresolved result/dungeon/quest/portrait/enhancement-slot role inputs remain separate and were not re-audited for this group.
