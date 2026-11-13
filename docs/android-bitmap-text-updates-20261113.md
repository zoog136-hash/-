# Reuse the owned bitmap-font descriptor during text updates

Base: main `b50923f072d867e0aaeb6761ab612cc0bd3dc602`. This is separate from #463 (idle source clocks) and #465 (panel redraws and source-text draw timing).

## Repeated work removed

`SpriteScene.set_bound_text` routes bitmap labels to `SourceBitmapText.set_source_text`. HP/MP, level, experience, wallet and inventory bindings use that text API. The previous setter called public `configure` with the label's already-owned font descriptor. Every successful update then deep-copied the complete glyph, kerning and page dictionaries again, including entries unused by the displayed string. The frequency and font size on a particular Android device remain unmeasured.

Public `configure` still deep-copies caller-supplied descriptors and options after all existing validation and staging succeeds. Only the private path used by `set_source_text` retains the label's current owned font snapshot. It still validates common fields, page availability/dimensions, supported codepoints, glyph channels, materials and the complete next text; it still stages a new layer before replacing the old display. No text-equality fast path is introduced. Invalid input preserves the previous layer and options. Explicit replacement still refreshes the caller snapshot; later caller dictionary mutations cannot alter the label. Texture resources retain the same sharing/lifetime behavior as before.

This avoids repeated descriptor allocation/copying. It does **not** remove glyph layout, private material creation or Sprite2D/layer rebuilding, and introduces no new global cache or retained high-water pool. Original pixels, kerning, positioning, color arithmetic, alpha policy, source-file checks and save data are unchanged.

Two inclusive hitch details, `ui.bitmap_configure` and `ui.bitmap_update`, keep total, call count and longest call separately. They are not top-level sections because existing HUD/menu callers can already account for the elapsed time. Do not add these details to their containing section or infer a GPU/GC duration from them.

## Validation

The regression compares the actual optimized setter with the exact former setter sequence through the unchanged public `configure` API. A synthetic font contains 4,100 glyph rows and 4,098 kerning rows. Twelve successful updates replace the owned full-font snapshot **12 times through the former path and 0 times through the new path**. All resulting glyph order, texture references, geometry, kerning, private material parameters and return values match. This is a count of eliminated copies, not an Android timing or whole-process RAM measurement.

48 headless assertions cover ownership isolation, repeated/changing/empty strings, unsupported text, unchanged-text revalidation after owned data becomes invalid, unavailable pages, failure preservation, explicit font replacement and inclusive-only diagnostics. The GL version passes 124 assertions and 32 complete RGBA comparisons across PMA/non-PMA and transparent/opaque viewports, including display-color changes, live page texture updates and explicit descriptor replacement. Fixtures are synthetic glyph images, not original client fonts.

Existing focused checks pass: UI pack memory lifecycle 210; HUD fields 6; inventory snapshot 983; quest text 30; hitch draw diagnostics 205; hitch logging 26. Python stage graph: 14 tests. Existing seven GL groups are retained, and the bitmap differential is added as a separate eighth step in the same pixel workflow to avoid overlapping #465's additions. The historic `check_resource_integrity.py` referenced in AGENTS is absent; the available `check_no_legacy_resources.py --root .` passes for 20 tracked resources. No original-resource delivery is claimed.

The original Android/Windows/XP Hero static reports support distinguishing owned/shared resources from repeated reconstruction, but this patch is an independently verified Godot implementation change. Their native functions or timing are not used as a performance baseline. No Android device measurement establishes that this caused or resolves the reported multi-second frame gaps. New device logs are required; remaining glyph reconstruction and other unmeasured work are still candidates.
