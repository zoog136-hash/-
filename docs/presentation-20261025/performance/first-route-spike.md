# First-combat route spike attribution

## Preferred final comparison: original baseline predicate

The final replay (`first-route-exact-baseline.json`) uses the exact `989beac8` graph **and original `line_clear` body**, rather than the original graph with the newly refactored uncached predicate. Both baseline source files were byte-checked against `git show 989beac8`. This is the preferred performance comparison; earlier intermediate runs remain below and are not substituted for it.

- Same field, ordered33 requests: all33 returned PackedVector2Array values identical;297 forward/reverse/zero-length/boundary predicates identical.
- Worst route **324.946→199.868ms**. p95 **21.790→14.587ms**. Median **3.415→3.575ms**: there is a small observed overhead for typical requests, so a uniform speedup is not claimed.
- The12 graph-related requests from observed frame1 total **332.407→206.192ms**, excluding initial graph setup. Graph setup61.822/65.723ms is reported separately. This is **126.215ms less path CPU for the same request group**, not an end-to-end frame time.
- FIFO reaches4096entries; observed process RSS rises125152→126176KiB (1024KiB), and Godot static allocations rise1,150,544bytes during the current replay. Retained outputs/allocator effects are included; these are not Android GPU memory figures.
- Actual Main still has the adverse438.861ms maximum recorded below. The remaining first-frame stall is not declared fixed.

This diagnostic follows commit989beac8 and isolates the remaining first-combat stall. It uses the existing actual Main 120-frame fixture, Escaros `(3953,5016)`, initial133 actors,90 frozen warmup frames, normal AUTO and test-only HP999999. No frames are excluded. It does not alter production code, combat events, animation, foot geometry, population or PR155-owned helpers.

The harness preserves the existing field instance and all its script variables, then installs a diagnostic NativePngField subclass. It copies the current native path body and original PlayableField superclass body at runtime; only graph construction selects a profiling graph subclass. Graph methods delegate to the production implementation. Timers/counters are nested and introduce overhead. Added script/resource IDs can shift subsequent instance-ID-based AI scheduling, so this is attribution, not a directly comparable performance regression against the earlier351.771ms sample.

## Observed dominant interval

The slowest instrumented frame is frame5,389.238ms. It contains one `field.path` call taking367.267ms. Its exact endpoints are `(3529,4824)`→`(3936.5,5016)` and it returns99 route points.

| Nested work inside that route | Measured time/count |
| --- | ---: |
| Graph `route` | 367.213ms |
| Neighbor filtering | 361.324ms / 3832 calls |
| New immutable edge decisions | 3822 |
| `line_clear`, included above | 356.176ms |
| `point_clear`, inside `line_clear` | 106.865ms |
| Endpoint attachment | 2.096ms |
| Destination projection | 0.013ms |

Do not add these nested times together. The result identifies first-time physical edge validation as the dominant cost of this route, not graph construction or actor spawning. The earlier frame1 is312.673ms but all21 field path calls account for116.028ms; this probe does not explain its remaining time and does not expand into unrelated gameplay systems.

Across the first120 frames, the graph records21 route calls,561.809ms cumulative route time,37,755 filter calls,470.645ms filter time,4278 new edge decisions and60.817ms graph construction. Exact physical checks are currently performed in both directions for immutable grid edges. Native `line_clear` samples every2px, validates point clearance and eight foot offsets. Any optimization must preserve those same samples and floating-point decisions; simply dropping the reverse check is not justified.

## Same-field replay

With simulation frozen, a fresh graph replays all21 recorded exact endpoint pairs in original order against the **same field instance**. Every returned PackedVector2Array is exactly equal. The same dominant route costs348.818ms on replay, including343.410ms filtering and339.117ms line checks, and creates the same3822 edge decisions. A subsequent warm replay of the entire trace takes6.178ms. This supports the causal explanation that uncached edge checks dominate the first pass, while existing graph caches remove most repeated work. Warm replay is not a proposed gameplay skip or first-call fix.

Raw per-frame/path/route evidence is `first-route-profile.json`; `first-route-profile.log` contains no script errors and reports an empty failure list. The JSON's top-level route-profile `field_line_*`/`field_point_*` totals accidentally include replay calls and must not be interpreted as active-frame totals. Per-route delta fields used above are captured before replay and remain valid. The next harness version captures explicit `field_counts_before_replay` instead.

The initial probe failed because copying native `super.path` into a subclass changed its superclass target and created an uninstrumented graph. Its error log and JSON remain as `first-route-profile-inheritance-failed.*`; its timings and printed empty-failure result are invalid and not used. The corrected harness copies the original coarse superclass body too, preserving that call's original semantics. No assertions were relaxed.

No production optimization, full CI, Android device test or whole-game speedup is claimed by this diagnostic alone. PR155's prepared polygon work remains excluded.

## Initial 32,768-entry memo: same-field cold replay

The integration change preserves native2px interpolation,4px clearance and all eight foot offsets. The normal `line_clear` remains uncached. Only immutable graph edges use an exact-Vector2 sample memo, owned by that graph, bounded to32,768 entries and cleared on configure. Both edge directions still run their own original floating-point interpolation. Moving endpoint edges retain ordinary uncached checks. No PR155 polygon cache is imported.

`benchmark_first_route_replay.gd` first compares the saved original native predicate against both current direct and cached predicates for189 segments drawn from the recorded endpoints, reversed/zero segments, and cell-boundary offsets ±0.0001,4 and2.83px. All results match. It then creates original and optimized graphs against **the same loaded native field**, with cold graph/sample caches, and replays the21 recorded endpoint pairs in order. Every returned packed path array is exactly equal, including the99-point worst route.

| Ordered21-route cold replay | Original graph | Exact-sample memo |
| --- | ---: | ---: |
| Median route, ms | 6.640 | 6.372 |
| p95 route, ms | 29.170 | 14.981 |
| p99 / maximum route, ms | 335.724 | 180.928 |
| RSS after arm, KiB | 125104 | 129264 |

The cold worst route is154.796ms shorter in this probe but still costs180.928ms. This does not remove all first-use work. The sample memo reaches its32,768-entry bound; subsequent new samples are checked normally rather than growing memory indefinitely. The4,160KiB RSS increase includes the memo, path outputs and allocator effects; it is not an isolated cache allocation or device VRAM measurement. Godot static memory grows96,909,094→100,353,358bytes across both arms. No per-predicate timers run during this replay; the earlier detailed diagnostic is separate.

`first-route-replay-cap32768.json` and its log record all exact comparisons, per-route costs and memory. The first replay (`*-rss-unavailable.*`) passed equivalence and timing but its whole-file `/proc/self/status` reader returned no RSS; that result is retained. The corrected probe uses the existing line-by-line proc reader and produced the capped-cache measurement above.

## Smaller FIFO memo

The final candidate uses `native_line_sample_cache.gd`, a graph-owned FIFO of4096 exact sample coordinates. It keeps accepting new samples after filling, evicting the oldest entries; eviction only causes the original physical predicate to run again. Configure clears the helper. Original sampling, endpoint behavior and both edge directions remain unchanged.

The same21 cold route replay and189 original/direct/cached predicate comparisons pass again, with all packed path coordinates identical. Results are in `first-route-replay.json` and its log:

| Same-field cold replay | Original graph | FIFO4096 |
| --- | ---: | ---: |
| Median route, ms | 6.632 | 6.229 |
| p95 route, ms | 29.635 | 16.200 |
| p99 / maximum route, ms | 339.746 | 183.149 |
| RSS after arm, KiB | 125092 | 126108 |

Compared with the prior32,768-entry candidate, worst-route time differs by2.221ms between runs while the original baseline also differs by4.022ms; this does not establish a meaningful performance difference between cache sizes. RSS growth across the optimized arm falls from4160KiB to1016KiB, and static-memory growth across both arms falls from3,444,264bytes to1,136,368bytes. The complete replay process includes retained baseline graph/results and optimized graph state, so these numbers are not cache-only allocation sizes. A256KiB cache-memory target is **not demonstrated**. The FIFO remains capped at4096 entries; the worst first-use route still takes183.149ms on this CPU.

## Final actual Main validation — remaining maximum stall

After adopting FIFO4096, the existing Main fixture ran once with the optional route profiler **disabled**. It retains the lightweight population observer used by earlier runs, the same map/position,133 initial actors,164 final actors and first120 active intervals. No initial frames were excluded. `population-entry-sample-cache.json` and its log report no failures.

| First120 actual Main intervals | Prior989beac8 sample | Final FIFO sample |
| --- | ---: | ---: |
| Median, ms | 19.368 | 17.285 |
| p95, ms | 32.737 | 28.875 |
| p99, ms | 266.664 | 67.743 |
| **Maximum, ms** | **351.771** | **438.861** |
| >50ms / >100ms intervals | 3 / 2 | 2 / 1 |
| Escaros `_set_map`, ms | 3150.039 | 3383.519 |

The final maximum is **worse**, and occurs in frame1 when the precise graph is first created. Its observed population work is only0.135ms. Without detailed timers in this final run, it is not valid to assign the remainder to a particular path or conclude that previously separate work merged into this interval. Additional script/resource allocations can change existing instance-ID-based AI phase scheduling; equal actor counts do not prove equal per-frame event placement. The lower p99 is especially easy to misread with only120 samples: fewer but more concentrated stalls can lower p99 while increasing the maximum.

The same-field ordered route oracle demonstrates a narrower reduction in the identified expensive route with exactly equal outputs. The actual Main observation **does not demonstrate an improved worst first-combat frame**, smooth first combat or solved general lag. The438.861ms maximum remains visible in the report rather than discarded or rerun until favorable. No additional gameplay system is modified to hide it. Android hardware, GPU time and audio listening remain untested.

## Minimal observer reproduces the concentrated spike

To avoid introducing new field/graph resource instances, the follow-up uses only an optional timer around `qa_population_entry_world.gd::find_world_path`, calling `super` unchanged and recording its endpoints, physics-frame number, graph presence, exact-failure-cache status and returned path. It does not replace the field script or construct profiling graph objects. The existing Main population harness maps these calls to its displayed-frame observation intervals. The attempted detailed final probe was stopped before `ACTIVE_BEGIN` when this lower-interference method was selected; `first-route-profile-final-aborted.log` is retained and supplies no measurements.

`first-route-world-profile.json` reproduces the long first interval at **431.948ms** in frame1. Twenty path requests occur in that interval, all in physics frame96, totaling243.014ms. The two largest are:

- `(3481,5160)`→`(3532.4111,5088.7915)`:67.552ms, including creation of the first precise graph.
- `(3529,4824)`→`(3948.875,5016)`:174.137ms, after the graph exists, returning100 points.

Thus graph setup and the large cold query now occur in the **same** observed frame. In the earlier detailed baseline, the large cold query occurred separately in frame5. The minimal observer supports request concentration as part of the changed maximum. It also measures **188.934ms outside the timed `find_world_path` calls**. That residual is not attributed to rendering, VFX, audio or another system without further evidence. Recording overhead and other process/physics work are included in it. The maximum is not fully explained by path calls alone.

## Same request schedule, frame-group path replay

The minimal observer records42 world path requests across120 intervals. A new mode of `benchmark_first_route_replay.gd` takes the33 requests whose precise graph exists or is first created, preserves their original order and observed-frame grouping, and invokes the real `field.path` with separate original and current graphs against the same loaded field. All33 packed outputs are identical and297 original/direct/cached predicate comparisons pass. Nine pre-graph requests are excluded; graph initialization is timed separately, and first coarse-route discovery is not replayed. This is path CPU replay, **not a rendered-frame simulation**.

For the12 graph-related requests assigned to observed frame1:

| Same observed frame1 request group | Original graph | FIFO4096 |
| --- | ---: | ---: |
| Sum of path calls, ms | 340.724 | 189.186 |
| Graph setup, separately measured ms | 64.302 | 67.784 |
| Path group plus graph setup, ms | 405.026 | 256.970 |
| Worst single request, ms | 332.648 | 183.055 |

The same concentrated request schedule still benefits from151.538ms less path-call work. This supports the causal route optimization even though the separate-launch whole-frame maximum worsened. It does not resolve the188.934ms non-path residual or establish a better full-frame maximum under a fully identical game schedule. Raw `first-route-group-replay.json` includes every group (JSON numeric frame keys render as `1.0`, etc.), route, memory observation and equivalence result. The4096-entry bound holds; optimized-arm RSS increases1024KiB in this replay. No production source changed during these additional probes.

## Final bounded physics attribution probe

One final diagnostic adds a subclass of the production monster with wrappers around `_physics_process`, `_tick_ai` and `_move_on_map`; every wrapper calls only its unchanged superclass implementation and records elapsed time. Existing actors keep their instance identity and all script variables; the test compares every restored property, including existing animation/state object references. New normal population spawns receive the same diagnostic only after normal creation. All164 actor installations pass property equality with **zero mismatches**. No production monster/player/animation file is changed. The existing active/sleep policy still controls which actors receive physics callbacks.

The QA world also times its unchanged `constrain_original_motion` call. These are inclusive counters: AI contains paths and some movement, and movement contains constraint checks. They must not be summed. Installing scripts can allocate temporary default resources and perturb later instance-ID scheduling; initial population activation now includes observer installation, so its47.151ms is not comparable to a normal spawn cost.

`first-physics-profile.json` reproduces almost the same **non-path residual** while placing the large cold query later:

| Observed interval | Frame1 | Frame7 |
| --- | ---: | ---: |
| Wall interval, ms | 255.514 | 197.199 |
| All monster `_physics_process`, ms | 71.024 | 181.238 |
| Monster AI, included above, ms | 69.950 | 179.970 |
| World path calls, nested, ms | 66.007 | 175.595 |
| Monster movement, ms | 0.843 | 0.543 |
| Motion constraints, inside movement, ms | 0.103 | 0.260 |
| Wall time minus world path calls, ms | 189.507 | 21.604 |

Frame1 has62 monster physics calls and9 movement calls. The entire movement wrapper takes0.843ms; subtracting its0.103ms motion constraint leaves0.740ms for patrol checks, `move_and_slide` and wrapper overhead together. Thus monster movement/collision sliding does not explain the approximately189ms residual. Wall time outside all measured monster physics is184.490ms. The188.934ms non-path residual from the preceding minimal world probe and189.507ms here agree closely despite the changed placement of the large cold query.

The remaining cost lies outside the measured monster physics callbacks. These probes do **not** distinguish world/player work, rendering/driver work, first-use resource work or other engine work, and do not blame any of them without evidence. No gameplay area or production optimization was added to conceal this unresolved remainder. The complete log reports no failures. The narrow frame-stage/profiler checks below further delimit what this observer cannot attribute.


## Frame-stage check and actual measurement limit

The final observer connects existing `RenderingServer.frame_pre_draw` / `frame_post_draw` signals and times the QA world's unchanged `_process` superclass call. No actor subclass is installed in this run. `first-frame-stages.json` reproduces a432.919ms interval: world path calls244.189ms, draw-signal interval15.335ms, world `_process`0.508ms and population `_process`0.134ms. These signals bracket viewport updates, not all GPU/driver/engine work; nested counters are not an exhaustive additive profiler. The substantial remainder still is not attributed. Neither rendering as a whole nor other callbacks are declared innocent or responsible.

The first root invocation omitted `-- --native-png-maps`, so Escaros was absent from the diagnostic catalog. Its failed JSON/log remain `first-frame-stages-missing-map-flag.*` and are invalid as Escaros performance evidence. The harness now quits immediately on the existing failed map assertion. The corrected invocation passed with the explicit map flag and same target coordinate/population.

The installed engine exposes `--profiling` and `--debug`. The former alone provided no function trace. Together they produced local script-profiler output (`first-engine-profiler-debug.log`) but only periodic current-frame snapshots: the active snapshots were15.254/22.066/17.420ms while the observer measured a313.542ms maximum. The sampled function list therefore missed the long frame. Debug/profiler timings are perturbed and are not another before/after score. No missing per-function attribution is invented.

**Next required measurement:** a continuously captured Godot editor/remote profiler timeline covering the exact first-active frame, correlated with a native CPU/thread trace if the missing interval remains outside script callbacks. The current CLI snapshots and GDScript boundary observers cannot identify that remaining cost. Android GPU timing additionally requires real device access; PC llvmpipe is not that evidence. This is an attribution limit, not an authorization denial, and no unverified PR155/PR122 dependency is asserted for the residual.

## Implementation and validation retained

Production changes are confined to `native_png_field.gd`, `native_png_route_graph.gd` and the new bounded `native_line_sample_cache.gd`. The original2px interpolation, float point order,4px clearance, all8 foot offsets, actual geometry and every combat/animation value remain unchanged. Direct/moving-endpoint checks use the uncached path. Only immutable graph edges share exact sample-coordinate results; FIFO eviction merely forces the original check again. Both dictionary and key order are bounded to4096, cleared when the graph is configured, and owned by that field's graph.

Final focused regression: **6/6 PASS**, no skipped/not-run checks (`spike-regression/summary.json`): boot, exact-sample cache eviction/lifetime, native negative-cache lifetime, existing native route recovery, AUTO selection oracle and existing combat timing. Required resource integrity also passes (`spike-resource-integrity.log`). Production player/monster/animation/data/art files remain unchanged. Full CI is held by user instruction. The local parameter name that shadowed `clear()` was renamed without changing behavior; the final cache test ran after that rename.

Reproduce the final stage observer in a separate writable XDG_DATA_HOME, with exclusive renderer access:

```bash
DISPLAY=:97 XDG_DATA_HOME=/tmp/pr157-first-render-valid XDG_CACHE_HOME=/tmp/lineagem-raster-cache \
TWILIGHT_WORLD_PATH_PROFILE=1 TWILIGHT_FRAME_STAGE_PROFILE=1 \
TWILIGHT_PERF_OUTPUT=/workspace/-/docs/presentation-20261025/performance/first-frame-stages.json \
/workspace/tooling/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 \
  --audio-driver Dummy --disable-vsync --fixed-fps 60 --max-fps 0 --path /workspace/- \
  --script tests/benchmark_population_entry.gd -- --native-png-maps
```

No Library retry or upload fallback was attempted. Evidence is retained in Git; first-combat end-to-end stutter remains unresolved despite the proven reduction in route CPU work.

For the preferred exact-baseline replay, export the two baseline files with `git show 989beac8:scripts/maps/native_png_route_graph.gd` and `git show 989beac8:scripts/maps/native_png_field.gd`. Set `TWILIGHT_ROUTE_BASELINE` and `TWILIGHT_FIELD_BASELINE` to those files, `TWILIGHT_ROUTE_TRACE` to the saved `first-route-world-profile.json`, and `TWILIGHT_PERF_OUTPUT` to a fresh report path, then run `tests/benchmark_first_route_replay.gd` headless with the same Godot binary. The harness now explicitly selects the original physical predicate for the baseline phase only.
