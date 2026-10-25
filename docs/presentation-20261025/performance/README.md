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
