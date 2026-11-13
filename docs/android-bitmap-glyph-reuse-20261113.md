# Retain private bitmap glyph nodes during text updates

This follows #467's owned-font snapshot reuse and includes the merged #463/#465 changes. It does not change original assets, fonts, text layout, gameplay, saves, map/spawn ownership or loading #464.

## Remaining repeated work and implementation

`SpriteScene.set_bound_text` reaches `SourceBitmapText.set_source_text` for bitmap labels, including HUD and inventory bindings. After #467, each update still constructed a new glyph layer, every Sprite2D and every private display material, then destroyed the preceding layer. This cost exists even when the font pages and descriptor are warm. Device update frequency and the share of the reported long frame remain unmeasured.

The new path computes and validates the entire ordered glyph plan before committing visible state. A successful internal text update reuses its private layer and matching glyph slots, restores fresh-sprite presentation, and preserves compatible per-instance display materials. Growth creates only the extra slots; shrink/empty text immediately frees surplus nodes/materials. No inactive high-water pool or global glyph cache is introduced. Public configure always replaces the layer and copies the caller descriptor as before. Foreign structure, scripts, ownership metadata or styled layers conservatively take the fresh-layer path. Unsupported text/pages/materials preserve the prior visible state, even if the error occurs after the first planned glyph.

The layout equations, codepoint/channel validation, kerning, order, textures, PMA/blend/display arithmetic and native extent are retained. Existing inclusive `ui.bitmap_update` timing captures this work; it must not be added to a containing HUD/menu section. This is a Godot implementation change. Earlier original Android/Windows and XP Hero static cache/pool evidence supplies architectural context only; it does not prove native frame costs or that either original client implements this glyph strategy.

## Reproducible checks

`tests/source_bitmap_glyph_reuse_test.gd` embeds the exact pre-change `_stage` body from `36a5cd8` (only an ignored optional argument added). It compiles old/new versions against the same current caller. Thus the baseline already contains #467's font-copy optimization. Constructor/material instrumentation is used only for allocation counts; optional `--benchmark` uses separate uninstrumented renderers.

- Initial three glyphs plus twelve same-length updates: layer constructions **13 to 1**, sprite constructions **39 to 3**, private material creations **39 to 3**. These are constructor counts, not process RAM or Android FPS.
- Headless: 71 checks. Growth/shrink/empty text, weak-reference release of surplus nodes and materials, partial-plan failure atomicity, public replacement, property restoration and conservative fallback are covered.
- Compatibility OpenGL: 40 complete RGBA comparisons over PMA/non-PMA, transparent/opaque viewports, changing lengths, color/material changes, invalid page/recovery and styled-layer fallback.
- Optional synthetic CPU-only sample: four alternating-order batches of 200 updates, eight glyphs/update, 4,100-entry font descriptor. Old microseconds `[35472,31581,36536,33590]`; new `[14868,14401,14593,15938]`. Rendering delivery is outside the timed interval. No timing threshold is imposed in CI; these Linux samples are neither Android measurements nor a full frame benchmark.
- Existing font ownership 51; UI pack memory lifecycle 210; HUD fields 6; inventory snapshot 983; quest text 30; hitch logging 26 and draw phases 205 pass. Main save/reload 33 checks pass with installed-original-map traversal unavailable; no installed original pack is claimed.
- Python staging graph: 14 tests. Available resource check `check_no_legacy_resources.py --root .`: 20 tracked resources pass. Historical `tools/check_resource_integrity.py` required by AGENTS is absent in current repository. No resource data is added or removed.

Run with the production stage from `tools/ci_core.py --prepare-only`, Godot 4.7.2 and `--script res://tests/source_bitmap_glyph_reuse_test.gd`; add `-- --render` with Compatibility OpenGL for pixels or `-- --benchmark` for optional CPU samples. Core CI registers the headless test; the existing pixel workflow retains prior steps and adds the 40-case differential with strict error/result checks.

Android hardware and full installed original packs are unavailable in this executor. This change does not establish the cause of the earlier 10,626ms unmeasured remainder or prove the lag is resolved. Further device logs must identify the build and event and distinguish inclusive UI timings from frame remainder.
