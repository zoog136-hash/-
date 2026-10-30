# Spawn registration optimization

This follow-up starts from PR157 `423771a523b44b0113a0b65342e7ddb0e50f0521`. The runtime change is four lines in `FieldPopulation._spawn_slot`: a newly instantiated actor receives its final parent-local spawn position **before** entering the scene tree. The existing post-attach global position, setup, RNG, physics filters, source foot, animation, population and pool-reuse flow are preserved.

## Measured result

Same actual Main/Escaros fixture, `(3953,5016)`,133 initial actors,165 at completion, seed20261025,90 frozen warmup frames and120 active frames. Normal AUTO, test-only survival HP999999,1280×720, Godot4.7.2, Compatibility renderer under Linux llvmpipe. No frames excluded. Runs were sequential: before1 → after1 → profiler-after → roster checks → before2 → after2. The120-frame window advances normal gameplay; reducing the initial stall changes physics catch-up scheduling and later simulation timing. This is a repeat of the same scene/configuration, not identical final combat trajectories.

| Unprofiled120-frame window | Before1 | After1 | Before2 | After2 |
| --- | ---: | ---: | ---: | ---: |
| Mean, ms |26.989|25.216|24.421|23.035|
| p50, ms |21.216|21.360|19.006|19.089|
| p95, ms |34.097|33.705|31.796|30.221|
| p99, ms |69.219|65.744|71.033|64.811|
| Maximum / first frame, ms |495.879|307.963|501.782|306.535|

The initial stall is187.916ms and195.247ms shorter in these two pairs. Median time is slightly higher, so this is a **spawn-stall reduction**, not a uniform frame-rate improvement.

The supported continuous remote engine profiler corroborates the affected native category. Each arm has120 consecutive active frames93–212 with no gaps or message overflow. Before is the already preserved `../continuous-first-combat.jsonl` from the exact baseline; after is `after-continuous.jsonl`, with identical profiler options1024 functions/native calls and visual profiling. The fresh actor path and file references do not add scripts/resources or change instance allocation order.

| Continuous profiler | Before | After |
| --- | ---: | ---: |
| Largest2D `integrate_forces` entry, ms |179.325|3.215|
| First combat engine frame94, ms |371.848|170.719|
| Frame94 largest physics tick, ms |333.426|150.223|
| Following cold-route frame95, ms |457.331|440.473|

The engine's `integrate_forces` bucket includes broadphase collision-pair registration. Registering a new kinematic body at the origin and moving it to its spawn before the next tick extends its swept AABB across that displacement. Entering at the final transform avoids that artificial movement. This attribution follows the matching engine source and the observed registration/state regression below; it does not require modifying a native engine build. No individual broadphase CPU stack was captured. Do not sum the largest physics tick, inclusive script functions and per-tick server entries as independent wall times.

The remaining440.473ms profiled cold-route frame shows that the complete first-combat stall is **not solved**. Further route improvements must respect PR155's prepared geometry work and PR122's animation/foot contracts. No speculative changes to those systems were made.

## Correctness and scope

`field_spawn_registration_test.gd` observes actual `child_entered_tree` and PhysicsServer2D transforms while normal population code creates actors. Against the original code,266 assertions fail: all133 actors enter the tree and physics server at the wrong initial transform. Against the change,807 checks pass. The before/after133-entry roster is exactly equal (ordered slot, species/name, position, HP, attack, speed, attack interval and random cooldown), and RNG state after pool exercise is exactly equal. Live-slot duplicate protection, existing dead actor reuse, final pool position and collision filters also pass. No assertion was removed to achieve this result. The final test additionally supports default installed Oman maps when native PNG mode is not selected.

Four focused runner checks PASS: boot, spawn registration, existing map population/boss lifecycle, and combat timing. The explicit native-PNG run passes807 checks as well. Resource integrity PASS723 atlases /41442 frames /233420026 bytes. Full CI remains held. This patch changes no collision geometry, layer/mask, foot radius/offset, actor art, motion, attack markers, damage, range, cooldown, spawn selection/count or quality setting. Pooled actor teleport handling is unchanged and is not claimed optimized.

The raw profiler also retains once-per-second performance samples. Before/after sampled draw-call ranges are305–385 and314–368; static-memory ranges are388,532,760–390,517,094 and387,309,948–388,893,244bytes. The samples occur at different engine frames, include profiler allocations, and do not measure transient pair-creation peak memory. They show no quality/population reduction, but cannot establish a draw-call or memory optimization. Android device performance and hardware GPU timings are untested.

Latest remote main was checked as `f24c0a8372adc33dda4dcf76735b90ec7e537aba` (PR122 merged). This existing PR157 branch retains its prior base and does not import or edit PR122 changes. PR155 remains separately owned; its observed population diff changes activity/AI scheduling at other locations, not this initial attachment block. Its implementation was read for ownership only. A large main fetch was stopped before updating local `origin/main`; no rebase, merge or asset import was performed.

## Reproduction

Run the existing benchmark with isolated writable XDG data/cache, DISPLAY=:97:

```
TWILIGHT_PERF_OUTPUT=<output.json> Godot_v4.7.2-stable_linux.x86_64 --path /workspace/- --script tests/benchmark_population_entry.gd -- --native-png-maps
```

Use the existing `tools/profiling/remote_frame_collector.gd` and decoder as described in [continuous profiling](../continuous-first-combat.md). `comparison.json` stores per-frame native category summaries and monitor samples; the raw after capture can regenerate the complete function profile. Before source bytes were verified against `git show 423771a5:scripts/maps/field_population.gd`. The four unprofiled JSON/log pairs, native roster comparison, expected original regression failure and focused test logs are retained alongside this note. No Library retry was attempted.

Matching official engine source:

- [GodotBody2D transform registration and swept shape motion](https://github.com/godotengine/godot/blob/ed1daf0bf/modules/godot_physics_2d/godot_body_2d.cpp).
- [GodotStep2D profiler bucket and broadphase update](https://github.com/godotengine/godot/blob/ed1daf0bf/modules/godot_physics_2d/godot_step_2d.cpp).
