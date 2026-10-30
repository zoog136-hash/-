# Common UI presentation — 2026-10-25

Implemented the existing live UI path, without changing item/skill IDs, card artwork, animation, equip/synthesis rules, or PR122 assets.

- Warehouse, crafting and selling now use distinct original SVG glyphs instead of the menu fallback. Unknown names share one explicit neutral icon, so arbitrary missing keys cannot grow the cache. Existing PNG icons are retained and their loaded handles are reused.
- Buttons, selected tabs, disabled controls and search fields share cached nine-slice relief surfaces. The window has a passive surface below its content, with no input/focus or per-frame callback. Existing flat slot APIs and grade colors remain compatible with callers.
- At 854×480, card detail previews and descriptions previously collapsed while the action column occupied only its minimum width. The existing preview row now retains 190 logical pixels of height; the compact detail column fills its available width and scrolls its remaining controls. Source art/animation is unchanged.
- Common factory buttons notify the existing presentation-audio service only on `pressed`, with no hover or construction sound. World/UI ownership and actual event synchronization are documented in the parent report.

## Actual Main captures

`before/` and `after/` each contain **62 unedited Godot viewport PNGs**: 31 states at 1280×720 and 854×480. This includes HUD, bag/detail/expanded/companion equipment, character/stats, skills/detail, map/menu, item/transformation/doll/relic list and detail, shop/purchase confirmation, warehouse, sale, crafting, enhancement and equipment collection. The capture entrypoint is `tests/capture_presentation_ui.gd`.

This is a **UI-only A/B**, not a whole-main performance comparison. Both captures use the same fixed seed 20261025, actual Main, isolated source-record QA equipment fixture and paused world simulation. Before uses `renewal_theme.gd`, `renewal_icons.gd` and `renewal_window.gd` from main `cba19558de2764839feb4887a8af8f69b905257a`; after uses their new presentation and the compact HUD fix. Other world/audio/performance code is shared. An early capture's tiled seams were inspected and corrected before the final after capture. Separate user-data directories protect normal saves.

The shared files were briefly restored for the before capture while its process loaded; final sources were restored immediately afterwards. No subsequent source swapping occurred. The independent compact regression also reproduces the bug against `/tmp/lineagem-scene-baseline`, an isolated source overlay. Initial root integration results overlapping the swap must not be treated as final; the focused final reruns are recorded separately.

`manifest.json` contains the SHA-256 and bytes of all **124 PNGs / 65,022,251 bytes**, plus the capture scope and limitations. Logical workspace/bag/quickslot geometry remains identical across all 62 corresponding states. These geometry checks do not claim visual or timing equality to Lineage M.

Visually inspected full-resolution PNGs include inventory/detail, small warehouse/crafting/collection and small relic detail. The large relic source art and small detail flow were checked separately. The source comparison is the official Lineage M inventory/UI material already recorded in `docs/ui-rebuild-20261012/REFERENCES.md`; the new material is an independent restrained approximation, not an original-game skin or an asserted pixel/color/timing measurement. Existing item-image watermarks, source-art differences and map blur remain.

## Verification

- Existing `lineagem_ui_visual_smoke_test.gd`: PASS.
- Existing `ui_fidelity_regression_test.gd`: **94 assertions PASS**, rerun after the compact fix. Existing assertions were not edited.
- New `presentation_ui_material_test.gd`: **37 checks PASS**: distinct icons, bounded unknown fallback, cache reuse, relief states, preserved margin/layout, passive input ownership and one button sound.
- New `presentation_catalog_compact_test.gd`: **25 checks**, baseline overlay **10 failures**, corrected implementation **0 failures**. Original selected records populate all four catalog descriptions; art retains readable height, compact detail fills width, actions fit or remain scrollable, and returning to the list works.
- Final `tools/test_project.py` compact rerun is **1/1 PASS**, no skipped/not-run checks, under `logs/runner-final/`; the material check passed in the preceding 2-test run whose compact report schema was rejected, under `logs/runner-count-schema/`. The new tests emit parser-compatible JSON result markers. Initial malformed-result and fixture/setup failures remain in the logs; they are not successful runs. The initial new-test assumption that even a short item action list must scroll was corrected to require either fit or scrolling; no pre-existing test was relaxed.

The first standalone smoke attempt accidentally used PATH's Godot 4.6.3 with an unwritable default data directory and aborted; its log is retained. All successful runs use `/workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64` with writable isolated XDG paths. Rendering uses Linux llvmpipe Compatibility. No Android device, actual sound listening, or original-game timing equality was verified here.
