# Avoid repeated bitmap-font metadata copies

Base main: `c68e6af49e04559e219eda474f2ec1acf6ce70cc` (#475 merged). APK 523.452's published update feed identifies this commit. This follow-up is a separate feature branch; it changes neither original assets nor gameplay/save ownership.

## Concrete repeated work

Native inventory quantities and other TextBMFont nodes call `sprite_scene._build` → `source_pack.bitmap_font` → `source_bitmap_text.configure`. Before this change a warm font lookup deep-copied the cached glyph/kerning descriptor, copied it again to replace the cache with identical metadata, then copied it a third time for the result. The public bitmap renderer subsequently takes its own required independent snapshot. Prior bitmap text-update optimizations did not remove these font-acquisition copies during scene construction.

A warm lookup now reads the cached descriptor without modifying it, validates/reacquires the declared page textures through the same existing calls, then makes one detached result snapshot. A cold successful parse already owns fresh dictionaries, so those can become the cache entry after all pages pass validation; the result is still copied once. Previously the cold path copied twice. Cache entries never receive `page_textures`; only the returned caller descriptor owns them. The renderer's own independent public configure snapshot remains unchanged.

Resource type/path/member checks, cold descriptor SHA and parser errors, page existence/texture/dimension checks, successful pack replacement invalidation and failed replacement preservation remain intact. The existing warm descriptor/texture-cache revalidation policy is unchanged. There is no additional cache, expiry policy, glyph removal or font/quality substitution.

`ui.bitmap_font` is a new inclusive detail for the entire lookup, including failures. It separates font acquisition from later `ui.bitmap_configure` work. It may overlap inventory-stage/HUD elapsed time and must not be added to its enclosing section.

## Tests and limits of the numbers

Godot 4.7.2 headless new differential regression: **150 checks passed**. It compiles old/new actual accessor code into test-only instrumented scripts, writes synthetic BMFont/PNG files into a unique `user://` fixture, opens them with the real pack verifier, and counts actual deep-copy calls. Page data and errors are compared, along with caller mutation isolation, cache identity, page validation and real renderer ownership.

| Synthetic descriptor | Warm lookups | Old/new copies | Old/new glyph rows passed to copies |
| --- | ---: | ---: | ---: |
| 4 glyphs + 4 kerning pairs | 12 | 36 / 12 | 144 / 48 |
| 4,096 glyphs + 4,096 kerning pairs | 12 | 36 / 12 | 147,456 / 49,152 |

Both implementations still call the page-texture path **24 times** for twelve two-page lookups. Cold lookup copies are 2 → 1. These counts describe synthetic preparation work, not an original font's size, Android milliseconds, whole-process RSS or GPU allocation. Retained descriptor contents and glyph/page resources are unchanged; the reduction is redundant temporary metadata work.

- Actual bitmap renderer consumes the returned data and retains an independent caller snapshot.
- After pack texture eviction a live glyph owner retains its page. Releasing the final renderer releases the texture; the metadata cache does not pin it.
- Invalid reference/type, missing descriptor, cold descriptor hash failure, missing second page on warm lookup, wrong page dimensions, successful replacement and failed replacement are exercised.
- Linux llvmpipe Compatibility OpenGL: **10 new full-RGBA comparisons** with actual synthetic font/page files, cold/warm acquisition, changing text, transparency and empty/nonempty output. All match the previous accessor; the nonempty guard verifies the comparison is not two blank viewports. With optional rendering, the new suite has **204 checks**.
- Existing bitmap text updates: 32 full-RGBA comparisons passed. Existing glyph reuse: 40 full-RGBA comparisons passed.
- Headless existing bitmap text updates/glyph reuse, pack memory lifecycle, menu retirement, inventory header/selection/snapshot, source scope, frame logging and actual Main save/reload passed. Main's 33 checks cover the available absent-install handling, not full private-pack gameplay.
- Python CI staging: 14 passed. Clean stage import and `NO_LEGACY_RESOURCES ok tracked=20` passed. The historical `check_resource_integrity.py` and resource-delivery ledger are absent from current main; its attempted invocation reports file-not-found. No art files are added or changed.

The new headless suite is registered in `tools/ci_core.py`. Executor evidence is under `/workspace/twilight-bitmap-font-lookup-validation/`: `headless-summary.json`, `font-lookup.log`, `pixels/summary.json`, logs, private synthetic files and stage. PR checks are the authoritative status for the committed remote head.

## Original evidence and remaining bottlenecks

The retained Windows static report traces raw-cache hit `01C74AB0` without reader/parser and already built Graphics reuse after raw expiration. Earlier Android static analysis separates cache/path lookup from read/parse/decode/upload. Those findings support keeping validated preparations distinct from caller/render state. They do not establish that the native client uses this particular BMFont algorithm, nor supply comparative performance measurements. This change is based on TWILIGHT's own call graph. No native refcount thresholds, Unity GC values or XP Hero performance claims are imported.

No Android device or complete installed original UI pack was exercised. The 523.447 photo describes previous execution 523.445: maximum frame 9,213 ms, unmeasured 8,866 ms, inventory stage 337 ms once and post-callback interval 8,949 ms. Neither the source-scope fix nor this font-copy fix proves the cause of that long gap. Matching hitch JSON/logcat/Perfetto and device playback remain unavailable.

Full scene record loading, public per-renderer font snapshotting, node construction/retirement, actual glyph drawing and true item-row reconstruction remain. The new timer can distinguish whether font acquisition contributes to an affected frame; synthetic copy reductions must not be presented as measured Android responsiveness or crash resolution.
