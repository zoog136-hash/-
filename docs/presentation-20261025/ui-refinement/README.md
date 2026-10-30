# Common UI refinement

Starting point: PR157 `e5e02cf75ff3094e4bb381e2e49c94d7a32a2334`. This follow-up refines the actual installed UI, using the same historical LineageM references already reviewed for this PR. The official2021 item guide is the direct reference for the recessed bag, blue equipped corner and gold lower-right quantity. The2022 HUD image is retained as context; these are not claimed to be the same client build or the2026 UI. [Official item guide](https://lineagem.plaync.com/guidebook/view?title=아이템%20소개). URLs, source dates and rechecked hashes are in `references.json`; official image bytes are not committed.

| Visible change | Implementation |
| --- | --- |
| Window/button material | Shallow warm title plate, uneven light/shadow edges and restrained surface gradient. Tall list surfaces stretch once rather than repeating button seams. Colors are development choices, not measured original values. |
| Inventory slots | Retain grade/selection borders over a shared dark recessed surface. Common items use a bronze outer rim. Original icons and their own rarity effects are unchanged. |
| Equipped/count/enhancement/lock | Blue `E` at upper-left; enhancement at upper-right; gold quantity at lower-right; lock at lower-left. A physical item's redundant count1 is hidden. Numeric grouping is display-only. |
| Full menu | Icon and caption hierarchy with quieter row separators; existing tile hit areas and scrolling retained. Equipment collection uses its existing dedicated symbol. This is a common-style interpretation, not a traced original menu. |
| Long item detail | Restore the popup's height budget after wrapped labels settle; retain body scrolling and keep equip/quickslot/lock actions inside the popup. |

The long-detail defect was present in the baseline: a real item with many options left the1280-wide detail popup879 logical pixels high even after its current minimum returned to265. Its actions were below the viewport. This is consistent with a transient wrapped-label minimum enlarging the popup while widths settle. The fix coalesces minimum-size changes into a deferred existing `_reflow`; it adds no polling loop. The final capture asserts viewport/popup/action containment at both tested sizes and confirms the long text remains scrollable.

## Actual rendering and interaction

`before/` and `after/` contain **16 direct captures each**: inventory, inventory detail, menu, skills, transformation list, shop, warehouse and crafting at1280×720 and854×480. These are actual Main controls using real catalog data and an isolated equipment fixture through normal world equip/lock actions. The capture asserts that opening/navigating these views changes neither inventory nor physical item IDs. No screenshot pixels were edited. The existing item-art watermark remains visible because the existing artwork is preserved.

Existing focused checks cover native taps and swipes, dragging, back/close navigation, shop selection/confirmation, item locks, persistent selected borders, long names and compact catalog previews. Final regression runs are recorded under `final-regression/`; original checks were retained and six detail/action containment checks were added. The capture also exercises long-option scrolling. Tests do not establish Android touch latency or exact original UI timing.

The first per-cell inset prototype increased1280 inventory draw calls313→346. The final implementation paints consecutive recesses on the existing grid CanvasItem using one cached9-slice style; no additional per-slot controls, input surfaces or frame callbacks remain. Final observed calls are in `comparison.json` (inventory313→319 at1280; other states differ). These are individual rendered-frame observations, **not a performance benchmark or a claim of zero additional render cost**. Material tests verify textures are reused when themes reopen.

## Boundaries and delivery

Only the common theme/material/surface, inventory presentation and menu-building block changed. Original item/skill IDs, prices, inventory/warehouse/crafting handlers, character/card artwork, grades (including unique emerald), reveal sequences, combat and prior spawn optimization are preserved. No PR122/152/153/154/155 feature implementation or art is imported.

Remote main was checked as `f24c0a8372adc33dda4dcf76735b90ec7e537aba` (PR122 merged); this existing PR157 branch is not rebased onto its art changes. PR155 `9b5c4750` theme/HUD/inventory sources match the prior main baseline. PR154 `11695b3c` theme matches, and its window difference is in viewport fitting, which this follow-up does not edit. Theme signatures used by those features retain their types and arguments.

Full CI remains held and the commit uses `[skip ci]`. Android device tests and audio listening were not run. The existing Library HTTP401 path was not retried; Git is the delivery location. Full original-client reproduction, every menu's decorative art and every long-text/device combination remain outside what these captures prove.

Reproduce the capture with Godot4.7.2, an isolated writable XDG data/cache directory and an actual GL display:

```
TWILIGHT_UI_CAPTURE_DIR=<directory> Godot_v4.7.2-stable_linux.x86_64 --path <checkout> --script tests/capture_ui_refinement.gd
```

Run the selected checks through `tools/test_project.py --only presentation_ui_material_test,presentation_detail_states_test,ui_fidelity_regression_test,ui_renewal_integration_test,presentation_catalog_compact_test`, with the matching `--godot` executable and DISPLAY available. No external PNG pack or other PR resources are required for this UI fixture.
