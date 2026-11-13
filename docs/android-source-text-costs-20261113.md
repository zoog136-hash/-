# Reduce redundant source-font preparation

Base: main `97e83aef351aeb3bd599bccf3dfae03b744f3d7c` (#477). This changes the existing `source_text.gd` renderer, not bitmap fonts, game rules, original resource identities or save ownership.

## Observed paths and change

`sprite_scene.set_bound_text` forwards ordinary source-font labels to `source_text.set_source_text`. The setter previously deep-copied all options, changed only the top-level string, then called `configure`, which deep-copied them again after validating the font and layout. The candidate now copies only the top-level dictionary. Validation continues to read nested options synchronously; successful configure still commits a fresh deep snapshot. Failed updates preserve the old dictionary and visible lines. No cache or same-string validation shortcut is introduced.

`source_text._draw` previously called `FontFile.get_string_size` on every drawn line, although the result was used only for center/right horizontal alignment. It now measures only those two cases. Left alignment and the existing default case still start at x=0. Glyph checks, line splitting, CJK wrapping, multiline width validation, height handling, line spacing, shadow/outline calls, drawing order and redraw scheduling remain intact. Font methods still perform their normal drawing work; this removes an unused explicit width query, not all shaping.

The fixed inclusive diagnostic `ui.text_update` measures the setter. It must not be added to its enclosing HUD/menu section. Existing `ui.text_draw`/`ui_text_draw` accounting remains.

## Evidence

Godot 4.7.2, tracked NotoSansKR FontFile, synthetic strings/options:

| Operation | Previous | New |
| --- | ---: | ---: |
| Deep option copies for 12 successful text updates | 24 | 12 |
| Width queries for a single left-aligned drawn line | 1 | 0 |
| Width queries for a center/right aligned drawn line | 1 | 1 |

The new regression compiles the previous setter/draw routing as an oracle and instruments only copy/width calls. It passes 77 headless checks and 221 checks with OpenGL rendering, including 56 exact full-RGBA comparisons. Cases cover Korean/Latin text, multiline and wrapped text, all supported alignments and existing default alignment behavior, shadow, outline, line spacing and constrained height. Caller mutation and prior-snapshot aliases remain isolated. Missing glyph/font, invalid wrap contracts, oversized multiline text and insufficient wrap height preserve the previous presentation; same text still revalidates the live font.

The existing source UI draw/refresh test also passes 115 OpenGL checks and 75 pixel comparisons. Thus 131 RGBA comparisons passed on Linux llvmpipe. Both the new headless suite and its required 56-pixel render run are registered in CI, preserving every existing check.

Eleven focused suites passed: the new test, existing UI draw, quest text, HUD fields, inventory class/header/selection/snapshot, pack memory lifecycle, frame logging and actual Main save/reload. Python staging tests: 14 passed. Clean Godot import passed. Focused regression results and import logs are in `/workspace/twilight-source-text-costs-validation/`; `pixels/summary.json` contains the actual comparison results. Main/save testing covers the available absent-install path, not complete original private-pack gameplay. The legacy `tools/check_resource_integrity.py` is absent in current main and its attempted invocation failed with file-not-found; the available tracked-resource guard passes (`tracked=20`). No asset files were added or modified.

## Limits and remaining costs

These are synthetic operation counts and image equivalence, not Android frame-time, RSS or GPU measurements. The original Windows/Android cache reports motivate avoiding repeated preparation but do not prove this Godot optimization or its performance. Existing source wrapping rules and attribution were preserved; no Unity pool or scheduling behavior was inferred from XP Hero metadata.

No new Android trace is available. The prior 523.445 execution's 9,213 ms frame and 8,949 ms post-callback interval remain unattributed. This patch does not establish that unused width queries caused that delay. Font/glyph validation, required wrapping/measurement, deep commit snapshots and redraws remain; cold resource loading, scene construction and other frame work still need matching device evidence. No overall lag/crash-resolution claim is made.
