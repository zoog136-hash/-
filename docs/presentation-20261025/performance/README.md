# Latest validated result: complete static minimap raster cache

The final helper source preserves every existing static map/dot drawing command, renders it once at the actual screen-pixel scale/phase, and keeps the border, heading and dynamic actor/camera overlays direct. It does not change PR155's separate boss MultiMesh implementation, source PNGs, geometry, coordinates, actor count, AI schedules or gameplay values. The earlier investigations and failed probes below are historical evidence, not the final result.

**Final Godot 4.7.2 llvmpipe run: PASS**, `minimap-raster.json` / `minimap-raster.log`. Normal HUD mounting was completed before measuring. All modes used the same loaded Main and already-created cache nodes.

| Frozen same-state, 180 frames each | Direct A | Cache B | Direct A repeat | Cache B repeat |
| --- | ---: | ---: | ---: | ---: |
| Draw calls/frame | 2467 | 272 | 2467 | 272 |
| Median frame, ms | 33.067 | 12.036 | 26.427 | 13.371 |
| p95, ms | 40.820 | 15.621 | 33.843 | 15.106 |
| p99, ms | 43.752 | 23.716 | 51.096 | 15.773 |
| Maximum, ms | 44.204 | 26.148 | 99.559 | 18.044 |

The repeated frozen comparison is the strongest controlled attribution: it removes **2195 per-frame draw calls while preserving the displayed map**. Frame-time variation between repeats is retained rather than averaged away.

## Real active combat, same instance

One continuous 960-frame / 16-simulated-second AUTO battle used 120-frame blocks in **ABBA BAAB** order. The first 8 frames of each block were excluded, preserving the normal 0.12-second minimap redraw cadence. This yields 448 measured frames per mode. Original node identities and AI staggering remained unchanged. Blocks occur at different moments of one battle; they are supporting same-run evidence, **not identical saved-state replays**.

| Warmed active combat observation | Direct | Cached |
| --- | ---: | ---: |
| Median frame, ms | 36.850 | 18.982 |
| p95, ms | 50.361 | 28.109 |
| p99, ms | 59.632 | 34.133 |
| Maximum, ms | 66.908 | 49.012 |
| Frames over 50 ms / over 100 ms | 24 / 0 | 0 / 0 |
| Median draw calls | 2561 | 365 |
| Sampled process RSS, KiB | 1568232 | 1568232 |

Real player strikes 56 and observed incoming signals 23 occurred; existing habitat activation retained 133→165 actors. Cache builds remained **4→4** throughout active measurement, so switches introduced no new cache nodes or texture rebuilds. This was a combat fixture, not an unmodified ordinary player session: player current/max HP was set to 999999 as a test-only survival reserve shared by both modes. Monster records, damage rules and attack timing were unchanged. The 16 seconds are fixed simulation time under `--fixed-fps 60`, not real wall-clock duration. No screenshots were read back during timing.

**Remaining performance limits:** the transition warmup excludes initial habitat activation and other startup spikes. Earlier complete-combat probes retained roughly 355–362 ms spikes, and the final physics monitor retained a 353.825 ms value whose exact frame cannot be assigned from its low-frequency readings. This does not establish loading/entry stutter resolution, stable 60 FPS, long-session memory stability, all-map improvement, or Android device performance. GPU memory is unknown; RSS is process memory including software-renderer allocations. Physics/process monitor values can update less frequently than frames, so wall-clock frame intervals are the primary timing evidence.

## Final rendered parity and cache lifecycle

- Captured direct/cached actual Main at 1280×720, requested 854×480 (actual render 853×480 due existing aspect handling), and 1920×1080. Final read-only pixel analysis `raster-pixel-comparison.json` asserts **maximum channel difference ≤2 on an 8-bit scale at all three sizes**; no pixels exceed 2. Differences are confined to cached geography. They are not byte-identical, and no exact-pixel-equality claim is made. Full screenshots were visually inspected; no geometry/dot was removed or blurred by downsampling.
- Initial 854 scaling produced a maximum 117 difference because a fractional screen-origin phase was omitted. The final helper aligns both the raster canvas and displayed texture to the same pixel phase. The failed images/report remain under `*-fractional-before.*` rather than being reported as passing.
- Final cache sizes were 168×148,113×100,252×222. Each scale change rebuilt once. Invalidation immediately cleared ready state and old painter field/overview references, then rebuilt exactly once. Actor/camera motion issued a dynamic redraw without a static rebuild. Direct/cache toggles retained allocations. Lifecycle final builds 4→5; dynamic draw notifications 3; restored field matches active field.
- `minimap-raster-parity.json` is the earlier short final-source parity/lifecycle-only pass; `minimap-raster.json` includes the final timings plus lifecycle checks. `minimap-raster-first.*` retains the initial unmounted-HUD fixture failure, and `minimap-raster-aborted-per-frame.log` retains the stopped, rejected per-frame-toggle design.

Reproduce final measurements with an isolated data directory and exclusive renderer access:

```bash
DISPLAY=:97 XDG_DATA_HOME=/tmp/lineagem-raster-verified-data XDG_CACHE_HOME=/tmp/lineagem-raster-cache \
TWILIGHT_PERF_OUTPUT=/workspace/-/docs/presentation-20261025/performance/minimap-raster.json \
/workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --audio-driver Dummy --disable-vsync --fixed-fps 60 --max-fps 0 --path /workspace/- \
  --script tests/benchmark_minimap_raster.gd -- --native-png-maps
```

Add `--parity-only` after `--native-png-maps` for the shorter image/scale/lifecycle check without timing or active combat.

---

# Presentation performance: measured scope

Base: `cba19558de2764839feb4887a8af8f69b905257a`. These measurements were made in this work session, with Godot **4.7.2 official** and Linux llvmpipe Compatibility rendering. `/usr/local/bin/godot` is 4.6.3 here and was not used for the reported tests.

## Changes and ownership

- `field_minimap.gd` delegates static terrain/hunting-area clipping to `minimap_geography_cache.gd`, once per `configure`. The cache stores world coordinates, so resizing/bounds changes still project correctly without rebuilding or stale screen coordinates. Reconfiguring or clearing a field releases the previous arrays. Map geometry is immutable between configure calls.
- `native_png_renderer.gd` skips its periodic visibility scan when field, camera, screen center, zoom, logical viewport and texture budget are unchanged. Explicit `refresh_visible()` still forces a refresh. `pump_stream()` continues every frame, including stationary frames.
- PR155's fetched minimap source only adds boss-dot MultiMesh batching. We did **not** duplicate that feature or modify boss marker loops. Its renderer changes are source-coordinate sorting/streaming work, not this request guard. Future merging still requires reviewing shared-file hunks.
- No pathfinding rules, camera zoom policy, textures, image sizes, budgets, entities, gameplay timing, character animation, attack markers or PR122 resources changed.

## Results

`minimap_geography_cache_test.gd`: **10 checks PASS**. Polygon vertex arrays, order and colors exactly equal the former draw-time clipping on four real map definitions. Cache clearing/native empty-field handling checked. The test writes its repeat-run JSON to `user://minimap-geography-cache.json`; the captured run is `geometry-cache.json`.

100 geometry queries (CPU microbenchmark, **not frame time**): Albino1 20,426→1,000μs, Albino2 24,417→915μs, legacy Escaros1 6,254→617μs, empty Oman1 72→67μs. Current native PNG Escaros has no such clipping; do not claim these legacy-definition timings apply to it.

`benchmark_native_png_visibility.gd`: **15 checks PASS**, actual Main native Escaros, 133 retained actors, player `(7433,2904)`, 1280×720, same loaded instance and camera, 120 frames per phase. Actor/process logic was frozen equally in both phases; only rendering and the normal renderer pump ran. This is a stationary rendering workload, **not active combat**. Before mode executes the previous periodic refresh; after mode executes the guarded `_process`. Original PNGs are decoded/settled before sampling.

| Metric | Before | After |
| --- | ---: | ---: |
| Visibility scans | 18 | 0 |
| Renderer CPU total, μs / 120 frames | 8,003 | 3,176 |
| Frame median, ms | 35.518 | 32.307 |
| Frame p95, ms | 43.804 | 45.264 |
| Frame maximum, ms | 51.113 | 67.112 |

The CPU work was reduced, but tail frame times worsened in this single sequential sample. **This does not demonstrate overall stutter improvement or Android performance.** No Android device, prolonged combat, or same-seed active-combat before/after benchmark was run here. Remaining recurring `pump_stream()` scans and expensive unmatched AUTO target path searches were inspected but not changed.

Actual render `stationary-before.png` and `stationary-after.png` are byte-identical SHA-256 `8b9210d790d4fac29f5ddcdff35f45d2728f195e744460eae3bae546aa345aee`. Images were opened and visually inspected: native Escaros terrain, actor population, minimap, and HUD remained visible. Move, zoom, budget, actual logical viewport changes, explicit refresh, stream completion and map replacement were checked separately after sampling.

## Reproduction

```bash
XDG_DATA_HOME=/tmp/twilight-perf-data XDG_CACHE_HOME=/tmp/twilight-perf-cache \
  /workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --headless --path . --script tests/minimap_geography_cache_test.gd
DISPLAY=:97 XDG_DATA_HOME=/tmp/twilight-perf-data XDG_CACHE_HOME=/tmp/twilight-perf-cache \
  /workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --audio-driver Dummy --path . --script tests/benchmark_native_png_visibility.gd -- --native-png-maps
```

Use an available X11 display and isolated user data. The benchmark is deliberately not named `*_test.gd` because normal full-suite discovery does not pass its native-map/render prerequisites.

## Failed probes preserved

`geometry-cache-first.log`: our new fixture initially expected nonempty clipping on Oman1, but its current definition correctly has no relevant clipped geometry. The independent equality assertion already passed; the fixture now explicitly checks expected emptiness.

`visibility-cache-first.*`: the initial command lacked `--native-png-maps`, so `_set_map("escaros_world")` retained Aden (77 actors, `(70338,17598)`). Its metadata says Escaros because the initial probe omitted an exact map-ID assertion. **Those timings are invalid as Escaros evidence.** The same failed probe changed physical window size while the logical canvas was fixed; this correctly did not invalidate projection. The final test asserts exact map ID, uses the flag and changes logical viewport size. The first failed report is preserved unchanged for diagnosis.


## AUTO selection follow-up

`_nearest_reachable_monster` now orders candidates by the same float distance and original scene order before querying paths. It returns the first reachable candidate. Original strict max-distance boundaries and equal-distance ties are preserved. It stores no reachability result: opened routes, moved actors and dead-state changes are examined immediately. This reduces repeated successful-search path work without inventing a navigation-version mechanism. **All-unreachable searches remain expensive and unchanged.**

`auto_selection_order_test.gd` compares the production selector with the previous implementation across 100 seeded position/dead/blocked/max-range combinations, ties, all-failure and reopened paths: **106 checks PASS**. Descending-order 24 reachable targets need 24 old path calls versus one new call. This is an operation-count fixture, not a whole-game performance estimate. The standard runner accepted it: **1/1 PASS** (`auto-selection-runner.log`). No existing assertion was removed.

Existing distance-based population sleep, worker PNG decoding, bounded texture cache and combat effect pool already exist in current main. They were inspected and retained; this patch does not introduce duplicate systems or claim to solve every frame-time cause.


## Active combat / inventory pair: NOT equivalent outcomes

`benchmark_lineagem_combat.gd` ran in base/current checkouts with `--fixed-fps 60`, 90 frozen render warmup frames, then 600 active AUTO frames (10 simulated seconds), existing Escaros population and a test-only player HP survival reserve. No actor was removed, no monster record changed, no screenshot readback ran during timing. The existing population activated its remaining habitats, 133→165 in both runs. Inventory was measured separately for 120 frozen idle frames.

Both runs began with seed20261025, player `(3953,5016)` and existing target 톱니 `(3913,5016)`. Both ended at `(3936.5,5016)`, targetHP1270, 35 player strikes and 11 incoming attacks. However, playerHP997415 vs997499 and final RNG state differ. Thus the pair is **not a controlled same-outcome comparison** and supports no improvement percentage.

The identified source is unchanged monster AI's per-instance scheduling: `repath_cooldown = float(get_instance_id()%11)*.025`, subsequent sight interval `.12 + get_instance_id()%5*.008`, and repath `.65 + get_instance_id()%7*.015`. New UI/audio objects shift engine instance IDs, which can change AI update order and random-number consumption. Production scheduling and RNG were not altered to force matching results.

| Raw observation (incomparable outcomes) | Base | Current |
| --- | ---: | ---: |
| Combat median / p95 / p99, ms | 35.479 / 51.308 / 64.212 | 36.195 / 52.543 / 60.589 |
| Combat >50ms / >100ms frames | 40 / 2 | 52 / 3 |
| Combat median draw calls | 2552 | 2551 |
| Sampled peak process RSS, KiB | 1673788 | 1591392 |
| Inventory idle p95 / p99, ms | 43.458 / 46.013 | 50.173 / 56.699 |
| Inventory median draw calls | 2691 | 2678 |

GPU memory is unknown; process RSS includes CPU and software-renderer allocations, not measured device VRAM. Geometry/map texture prewarm did not warm active combat effects or newly activated habitats, so first-combat setup spikes remain included. Full-frame stability is not demonstrated. The first baseline attempt (`combat-before-first.log`) completed combat but failed its menu harness call; corrected `world._open_inventory()` and reran, preserving that failed attempt.


## Dominant-cost isolation: same loaded scene, repeated ablation

`benchmark_presentation_cost.gd` changed only minimap visibility for diagnosis, then restored it. This is **not a product optimization or removal**. It used one actual native Escaros Main instance, 133 unchanged actors, player `(7433,2904)`, camera zoom1, and frozen simulation/RNG. PNG streaming was prewarmed and each phase discarded30 frames before180 measured frames. No screenshot readback occurred. The four phases alternated visible→hidden→visible→hidden.

| Diagnostic phase | Visible A | Hidden B | Visible A repeat | Hidden B repeat |
| --- | ---: | ---: | ---: | ---: |
| Draw calls/frame | 2465 | 213 | 2465 | 213 |
| Median frame, ms | 31.394 | 9.546 | 31.373 | 12.061 |
| p95 frame, ms | 41.989 | 15.623 | 41.742 | 14.846 |
| p99 frame, ms | 45.779 | 18.491 | 54.167 | 17.243 |
| Maximum frame, ms | 47.051 | 18.774 | 57.394 | 18.373 |
| >50ms frames | 0 | 0 | 2 | 0 |
| Sampled RSS, KiB | 1591112 | 1591120 | 1591124 | 1591124 |

The minimap accounts for **2252 retained draw commands per displayed frame** in this frozen scene. The repeated ablation supports it being the dominant render cost here, independent of gameplay/AUTO behavior. It does not prove Android results, active-combat frame-time gain, or that hiding the map is acceptable. It supports caching the complete static minimap imagery while preserving every dot/shape and keeping dynamic actor/camera overlays live. PR155's separate boss-dot MultiMesh batching is not implemented by this work.

Raw `presentation-cost.json` includes process/physics monitor distributions. Godot's monitor values may be sampled less frequently than displayed frames; use wall-clock frame intervals as the primary timing evidence. GPU memory remains unknown. `presentation-cost.log` records a successful run with unchanged population, player/camera and RNG.


### Raster prototype first probe: retained failure

`minimap-raster-first.*` is a failed prototype probe, not final validation. It found a single cache rebuild1→2 when active simulation resumed. Inspection identified the test harness froze Main before `renewal_hud.gd::_process` completed its initial minimap reparent/layout. Initial static samples used the old Root222×191 control; active HUD correctly mounted it to its normal168×148 control, triggering required cache invalidation. The corrected harness explicitly executes normal HUD mounting before preparing/freezing the raster. The earlier hide/restore attribution likewise used the unmounted but equal-in-both-arms layout; its draw-cost attribution is valid for that stated scene, not a completed normal-HUD validation.

First screenshot comparisons (`raster-*-first.png`) retain the first full-panel caching approach. All differences were inside the minimap; panel-corner alpha composition and one overlapping inner pixel differed most. These are superseded by the follow-up implementation which keeps border/title direct and caches opaque geography. The aborted per-frame active-mode design was stopped during its first static phase (`minimap-raster-aborted-per-frame.log`) because per-frame toggling would redraw the old geometry more often than its normal 0.12-second cadence. The corrected active test switches120frame blocks and discards the first 8 frames per block, without changing production AI schedules.
