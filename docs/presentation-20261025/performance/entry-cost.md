# First combat and habitat activation costs

This follow-up profiles the actual Main scene at native Escaros `(3953,5016)` using Godot 4.7.2, Compatibility renderer and the same 1280×720 Xvfb/software-rendering environment. `benchmark_population_entry.gd` uses profiling subclasses for existing world/population methods, invokes their production implementations unchanged, and preserves normal actor scheduling. It creates the normal initial 133 actors, prewarms map PNG streaming and minimap raster while frozen, then enables AUTO and records **all first 120 active frame intervals**, without discarding entry frames. Player HP/max HP 999999 is a test-only survival fixture. Fixed 60Hz simulation does not mean 60 rendered FPS or Android validation.

The profiling fixture only wraps `_set_map`, `_monster_texture`, `_spawn_point`, `_spawn_slot` and population `_process`. It does not add production timers or change actor/resource creation rules. `qa_population_entry_world.gd` copies current service setup solely to substitute the profiling population subclass. The recorded setup-spawn array includes both initial Aden and subsequent Escaros, distinguished by region IDs.

## Baseline attribution

Baseline is PR157 commit `95cfb2718016a360f75628f12d613f34d02f41d8`; raw samples are `population-entry-before.json` and its log.

- Initial synchronous `_set_map`: Aden 3609.942ms, Escaros 4978.634ms. These timings include field setup, initial resources and actors, and occur **before** the active-frame measurement. Escaros initial spawn calls account for 1196.216ms; remaining entry time was not decomposed by this probe.
- Subsequent nearby habitat activation attempts: 32, with 31 actors created. Summed spawn duration 27.369ms, including 4.132ms spawn-position checks. Texture lookups during activation total 0.735ms. The first population process takes 28.113ms.
- Active frame 0: 138.297ms, including that population activation.
- Active frame 1: 316.023ms; the field's precise route graph changes from absent to present during this interval. Population work is only 0.157ms.
- Active frame 3: 333.713ms, after the precise graph already exists; population work is only 0.131ms. This is consistent with additional first-use path/edge work but the probe does not time individual path calls, so it does not assign the entire stall to routing.
- Independent graph construction on the same field takes 104.592ms, for 21,811 points in a 285,915-cell grid.

These measurements prioritize route graph initialization and repeated unsuccessful path work over speculative population changes. This follow-up does not stagger or remove actors, duplicate PR155's activity/sleep changes, modify source population, or change sprite resolution. Initial map loading and the second first-combat stall remain explicit unresolved costs unless a separate probe demonstrates a fix.

## Comparison interpretation

The after probe uses the same map, initial player coordinates, seed, initial actor count, warmup and frame count. As in earlier measurements, separate launches do not guarantee identical instance-ID-based AI phase scheduling or complete outcome identity. First-frame timings are descriptive integration evidence; they do not establish a causal whole-game speedup. The independent graph comparison uses the **same loaded field** and checks every point ID, point position and ordered connection against the saved original graph source. That comparison isolates the graph construction change without changing the actor population or gameplay rules.

Wall-clock intervals are the primary frame metric. Godot process/physics performance monitors update at a lower cadence and may retain previous spikes; their readings are not per-frame attribution. GPU time and device VRAM are unavailable, and these results are not Android device acceptance.

## After graph optimization

The root integration change uses ascending sparse reachable-cell enumeration plus graph capacity reservation and an exact-coordinate bounded negative-route cache. The same-field oracle passed for all 21,811 point IDs, positions and ordered connections. Independent construction in the after process measured original 106.948ms versus optimized 62.865ms. This is a narrow CPU construction comparison; it is not a 41% whole-game improvement. The separate all-unreachable test owned by the integration agent measures repeated failure reuse and explicitly preserves the first uncached cost.

| First 120 active intervals | Before | After |
| --- | ---: | ---: |
| Median, ms (nearest rank) | 17.455 | 19.793 |
| p95, ms (nearest rank) | 30.737 | 35.396 |
| p99, ms (nearest rank) | 316.023 | 271.195 |
| Maximum, ms | 333.713 | 357.572 |
| >50ms / >100ms intervals | 3 / 3 | 3 / 2 |
| Initial / final actor count | 133 / 164 | 133 / 164 |
| Spawn attempts / creations | 32 / 31 | 32 / 31 |
| Activation spawn total, ms | 27.369 | 29.556 |
| Escaros `_set_map`, ms | 4978.634 | 4995.859 |

The precise-graph creation interval fell from 316.023ms to 271.195ms. The largest subsequent stall moved from frame3 to frame7 and grew to357.572ms. The worse p95 and maximum are retained, not hidden by excluding warmup frames. Equal initial/final population does not establish equal AI events across launches. **First combat stalls and initial region loading are not solved.** Raw `population-entry-after.json` contains the graph-equivalence flags and every measured interval; both logs report an empty failure list.

## Independent native entry decomposition

`benchmark_native_entry_stages.gd` copies the current registry source into an in-memory GDScript and substitutes only its FIELD preload with `qa_native_entry_field.gd`. All hash/header checks, plan loading, field construction and collision geometry remain production behavior. The JSON records the production registry source SHA256. The profiling subclass delegates to production methods and times nested calls. This is a separate headless loading-stage diagnostic; it does not include actors, textures or normal Main frame rendering. Do not add nested durations together.

| Loading stage, ms | Aden | Escaros |
| --- | ---: | ---: |
| Entire registry `load_field` | 1490.282 | 3568.559 |
| `configure_png`, inclusive | 1198.663 | 3388.260 |
| Base `PlayableField.configure`, inclusive | 1141.533 | 3197.716 |
| Reachability pass 1 / 2, nested | 7.247 / 6.771 | 15.129 / 14.734 |
| Registry work outside `configure_png` | 291.619 | 180.299 |
| `build_physics`, separate | 132.926 | 31.173 |
| Grid cells / physical shapes | 1434265 / 413 | 285915 / 929 |

Both report `navigation_cache_hit=false`. Existing `PlayableField` already has signature-checked in-memory and baked navigation snapshots; native fields explicitly disable that path with `use_baked_cache=false`. Native configuration then applies the PNG alpha guard and rebuilds reachability, so blindly enabling the base snapshot is not justified by this measurement. The current renderer also already streams PNG uploads; adding a competing loader is not the appropriate first response to the measured base-configure cost.

The dominant next region-entry target is the ~3.2-second base configure stage, not its ~30ms reachability substage, ~31ms physics construction, or ~180ms registry validation. Its inner polygon/collision/spawn-grid loops were not individually timed by this probe. Native field/registry are shared with PR155, so this profiling task made no production edits there and did not bypass resource validation. Further optimization requires isolating those loops and preserving geometry, candidate sets and snapshot invalidation semantics.

## Detailed configure probe

A further standalone probe enables `TWILIGHT_ENTRY_DETAIL=1` and wraps pure query methods with microsecond timers/call counters. This diagnostic adds substantial overhead: Escaros base configure rises from3197.716ms to3792.134ms; Aden from1141.533ms to2172.527ms. Do not compare these instrumented total times as a product regression or add nested counters together. Counts include PNG configuration queries after base configure as well.

| Escaros query | Calls | Inclusive measured ms |
| --- | ---: | ---: |
| `is_safe` | 138685 | 2067.297 |
| `region_at` (inside `is_safe`) | 138685 | 1919.578 |
| `spawn_contains` | 138685 | 1017.954 |
| `inside_navigable_area` | 387180 | 180.075 |
| `_inside_shape` | 89364 | 29.068 |
| `navigation_snapshot` | 1 | 29.643 |

The dominant safe next target is repeated spawn-candidate safe-region/membership queries, not the ~29ms collision predicate or snapshot. PR155 separately owns floor rasterization and skipping unused snapshots; neither is reimplemented here. `is_safe` uses ordered `region_at` matching, so any optimization must preserve overlap/priority semantics, and all spawn candidate arrays/order must remain unchanged. `native-entry-detail.json` and its successful log retain the full counters for both maps.

The earlier `population-entry-after` timing is specifically the graph-construction/graph-negative-cache integration before the subsequent native-field early failed-route lookup hook; it is not a measurement of that later hook.

Source inspection following the query counters found a specific allocation source: `map_region_geometry.gd::prepare` caches a single `polygon`, but not plural `polygons`. The plural branch of `contains` reconstructs `PackedVector2Array` values from raw JSON points on every call. All five Escaros region records use plural polygons (1,1,2,2,2), so the measured repeated `region_at` workload hits that branch. Preparing those polygons once while preserving the exact predicate, order, empty-list behavior and exclusions is a candidate independent of PR155's floor raster/snapshot changes. Source inspection alone is not a measured optimization result; follow-up implementation/equivalence and timing results must be reported separately.

Ownership verification subsequently found PR155 already implements prepared plural polygons and polygon bounds (`/tmp/pr155-geometry.gd`, remote branch head `5a10f0c8`). This PR must not copy or duplicate that work. The allocation finding remains valid for current main, but its direct fix is reserved to PR155. A separate configure-local memo of exact `is_safe` results can address repeated overlapping spawn-cell queries without changing the geometry helper or waiting for PR155; that proposal requires an independent full navigation/spawn-array equivalence check.

## Configure-local safe-result memo: final implementation verification

The integration change adds a temporary three-state byte mask inside `PlayableField.configure`'s spawn-candidate loop. It evaluates the original ordered `is_safe` predicate once per reached grid cell and reuses that exact result across overlapping spawn regions. The mask is local to one configure call and is discarded afterward: no persistent cache invalidation, geometry changes, or source-data edits. Escaros needs285,915 temporary bytes (about279KiB); Aden needs1,434,265 bytes (about1.37MiB). PR155's raster loop and snapshot sections are untouched.

`benchmark_entry_safe_cache.gd` builds the original and final native fields from the same validated plan/manifest in one process. It loads the saved original PlayableField only in a test-local `user://` inheritance chain, preserving current native-field implementation and all other dependencies. For **both Aden and Escaros**, complete map data, prepared spawn geometries, ordered spawn-cell arrays, solid runs, reachability bytes and geometry signatures are exactly equal. All12 comparisons pass. The original/current source hashes are saved in `entry-safe-equivalence.json`.

With diagnostic call counters enabled, Escaros `is_safe` calls fall138,685→21,916; its inclusive measured time2053.201→333.332ms. Instrumented base configure falls3779.900→1932.157ms. `spawn_contains` remains138,685 calls and approximately1028→1023ms, preserving the remaining PR155-owned allocation bottleneck. Aden calls fall only7363→7327 and instrumented base time2180.638→2206.711ms, so no Aden speedup is claimed.

The separate final stage run disables detailed counters. Compared with the original stage probe:

| Escaros stage, ms | Original | Final |
| --- | ---: | ---: |
| Registry `load_field` | 3568.559 | 2065.147 |
| `configure_png` | 3388.260 | 1869.284 |
| Base configure | 3197.716 | 1654.816 |
| Physics construction | 31.173 | 32.729 |

The final profiling subclass includes disabled query-wrapper branches introduced after the original stage probe, so these separate-launch numbers include small instrumentation differences. The same-process equivalence/call-count comparison is the stronger causal evidence for reduced repeated work. Original Aden load1490.282ms versus final1570.515ms is retained; this optimization targets overlapping regions, not every map equally. `native-entry-stages-after.json` contains all final counters-off stages.

## Final actual Main check

`population-entry-final.json` tests the frozen final source containing the sparse graph build, exact failure reuse at the native-field entry point and configure-local safe-result memo. All graph point/position/ordered-connection checks pass again; independent same-field graph construction is101.117ms original versus60.131ms final. It uses exactly the original Main fixture/warmup and records all first120 active intervals, with no frame exclusion.

| Actual Main measure | Original | Final |
| --- | ---: | ---: |
| Escaros synchronous `_set_map`, ms | 4978.634 | 3150.039 |
| Aden synchronous `_set_map`, ms | 3609.942 | 3651.131 |
| First120 median / p95, ms | 17.455 / 30.737 | 19.368 / 32.737 |
| First120 p99 / maximum, ms | 316.023 / 333.713 | 266.664 / 351.771 |
| >50ms / >100ms intervals | 3 / 3 | 3 / 2 |
| Initial / final actors | 133 / 164 | 133 / 164 |
| Habitat attempts / creations | 32 / 31 | 32 / 31 |

The final Escaros entry is1.829seconds shorter in this run, consistent with eliminating redundant safe-region queries. It still takes3.150seconds and is not instant. First combat still has a351.771ms stall at frame7 after graph initialization; its p95 and maximum remain worse than the original run. This work therefore demonstrates a specific region-entry CPU improvement and repeated-unreachable-query reduction, **not solved overall lag, stable frame rate, or Android device performance**. The test-only survival HP and separate-launch AI scheduling limitations remain in force.

No population production files were changed by this profiling subtask. No full CI, APK build or Android physical-device test was run here. The parent integration owns production edits, targeted regression tests, commit/push and PR submission. All benchmark logs, including original and intermediate measurements, are retained rather than overwritten; `.log` files need explicit inclusion because repository ignore rules exclude them.
