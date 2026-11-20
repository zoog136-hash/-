# OPT07 / OPT39: reduce combat VFX CPU submission work

Base main 3a7e2b9 (including #720/#721). Current frame-delay work elsewhere includes map chunk workers and background saves; this change is limited to the existing combat_vfx drawing node and its frame diagnostics.

## Confirmed code cost

The previous _draw called Node2D.to_local(entry.point) independently in its corpse/ring pass, impact pass and number pass. Its first pass also converted every number/impact and computed progress/alpha before a match that did nothing for those kinds. Node2D's world-to-local conversion computes the inverse world transform. Canvas draw_set_transform changes draw commands, not the Node2D's world transform, so one inverse remains valid throughout a draw call.

The new draw obtains the inverse once (only for nonempty active lists) and uses it for the same world/local point conversions. The first pass visits only death/ring records before converting. Impact priority, detailed/compact limits, draw order, texture/number geometry, source timing, pool, expiry, host-art suppression policy, gameplay callbacks and RNG are retained. The inverse is recomputed for every draw: parent/camera/node changes are not cached across frames. There is no new array/dictionary cache or retained texture owner.

Synthetic mixed effect draw counts, using instrumented copies of the actual old/new draw bodies:

| Active records | Old inverse calculations / point conversions | New inverse calculations / point conversions |
| ---: | ---: | ---: |
| 1 | 2 / 2 | 1 / 1 |
| 40 | 60 / 60 | 1 / 40 |
| 160 | 240 / 240 | 1 / 160 |

New fixed inclusive detail `vfx.draw` and exclusive CPU section `combat_vfx_draw` account for this callback. The Korean loading label is 전투 효과 그리기. These measure CPU submission time; they do not identify GPU execution time or prove a cause for earlier unmeasured frame intervals. The detail is nested in the section and must not be summed with it. Timers add a small fixed per-draw instrumentation cost which is not separately benchmarked.

## Verification

Godot 4.7.2: 489 headless checks; 599 checks with Compatibility OpenGL/llvmpipe, including 28 exact full-RGBA comparisons against the previous draw routing. Synthetic corpse textures, rings, impacts and font numbers cover 1/40/160 records, animation ages, translated/rotated/nonuniformly scaled parents and parent movement between draws. Large-coordinate world/local comparisons preserve positions. Impact counters/budgets match. Pool stress emits 3000 records, retains the 160 limit/no child allocation, returns expired records and stops idle processing. Unequal synthetic death-frame durations retain the same phase at low rendering cadence.

The existing projectile lifecycle check also passes (`logical_hits=256 visual_cap=64 reuse_cap=128`), as does frame logging (26 checks), clean import, Python staging tests (14), and the tracked-resource guard. The new regression is registered in core and pixel CI without removing any existing check.

Attempted old combat_vfx_test cannot complete on current main: it loads removed res://assets/actors/eight_direction/original_based/spear_captain/SpriteFrames.tres and then dereferences null. Its partial execution is not a pass. It remains unchanged. The new explicit synthetic lifetime test does not claim to restore/verify that removed original-based artwork. The initial local projectile attempt also lacked its test file in the staged graph; the exact tracked test was copied and rerun successfully. Historical check_resource_integrity.py is absent and was attempted with file-not-found. No assets were added or modified.

Evidence: /workspace/twilight-vfx-draw-transform-validation/{pixels/summary.json,focused-final.json,import.log,python.log}. The stopped legacy test log is retained as combat_vfx_test.log. Device-level frame distribution, GPU timings, private original-pack VFX and Android release/device rendering are unverified. No Android speedup or resolution of the prior long frame is claimed.

The original Android/Windows reports describe cache ownership and ordered rendering; they do not establish this implementation or these operation counts. This change follows the actual Godot callback and preserves drawing order. 225 task/927 table ledgers remain intact; OPT07/OPT39 are only partially addressed. #720 merge and its 370-suite CI outcome are recorded in the prior rows.
