# Avoid unchanged panel redraws and measure source-text drawing

Initial validation base: `main` at `c8d9cc0212e6b86d3965d4d7aecba867063ce39f`; latest main `b50923f072d867e0aaeb6761ab612cc0bd3dc602` is also integrated. This follow-up is independent of the inactive-clock change in PR #463. Neither change establishes the cause of the photographed 10,626 ms unmeasured remainder.

## Runtime change

`SpriteScene._sync_source_display` visits source panels during animation/display updates. `SourcePanel.set_source_display` previously constructed and assigned a four-color array on every visit, even when all four current vertex colors already matched. In the actual Godot renderer, the repeated setter caused a `Polygon2D.draw` dispatch on every observed stable update.

Compare the actual four vertex colors before constructing/reassigning the array. Do not cache only the requested display color: external geometry edits, changes to source options, alpha hide/show, and replacement state must still be honored. All image/material binding, source color arithmetic, geometry, draw order, source-over shader policy and destination-copy ownership remain unchanged. This avoids repeated array construction and geometry redraw requests; it is not a measured whole-process RAM or GPU-memory reduction.

`SourceText._draw` now records the exclusive `ui_text_draw` section (UI 글자 그리기) and the inclusive `ui.text_draw` detail (total/calls/longest call). Font metrics, width queries, outlines, shadows, source strings, clipping and drawing calls are unchanged. These measurements cover CPU wall time executing the callback, including font/draw submission calls. They do not measure GPU execution, compositor completion, all font-atlas upload work or GC. Do not add the inclusive detail to its containing section. Raw frame intervals and thresholds remain unchanged.

## Executable evidence

`tests/source_ui_draw_refresh_test.gd` compiles the previous unconditional setter in memory and runs both actual renderers. Four combinations of transparent/opaque viewports and the existing screen-copy/fixed-blend policies each perform 12 stable updates. Actual geometry draw signals total **48 before versus 0 after**, with identical full RGBA images. Further phases change alpha, source options and externally corrupt the vertex array. The three text-renderer comparisons use the repository NotoSansKR fixture, not an original client font. They cover horizontal/vertical alignment, multiple lines, outline and shadow with the exact previous draw body as oracle.

The GL test passes **115 assertions and 75 full-pixel comparisons**; its 11 headless state assertions also pass. The real text draw callback creates the bounded section and total/calls/max detail. No production instrumentation is added to count panel setter/draw operations.

Existing focused regressions pass: UI pack memory lifecycle (210), HUD fields (6), inventory snapshot (983), quest text (30), copy policy (88), hitch draw diagnostics (205) and hitch logging (26). Python stage graph: 14 tests. All eight local GL groups pass. Existing groups remain registered unchanged, with this regression added as an eighth group in the pixel workflow. A scratch combination with exact #463 head `9bed3708` and current main merges without conflict and passes 279 clock lifecycle assertions plus the 75-pixel redraw differential. Latest-main legacy migration regression also passes (19 grants, no failures). The historical `check_resource_integrity.py` referenced by AGENTS is absent; the available `check_no_legacy_resources.py --root .` passes with 20 tracked resources. No original assets are newly supplied or claimed integrated.

A first local single-test GL launcher inherited an expected group count of seven and therefore returned failure despite its sole test passing; the launcher count was corrected to one. No assertion or runtime error was waived.

These are synthetic Linux Godot 4.7.2 Compatibility/llvmpipe checks. They demonstrate avoided work and output equivalence, not Android FPS or a fix for the reported multi-second stalls. New device hitch records are needed to attribute the remaining delay. The original Android/Windows and XP Hero reports are static architectural references; this change is an independently verified Godot implementation improvement, not a copied native performance result.
