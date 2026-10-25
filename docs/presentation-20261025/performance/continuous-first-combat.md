# Continuous first-combat engine profile

Measured production head: `99f31c3e9d75d82cfce2c3b67e876469fabdbea9`. No runtime code changed in this follow-up.

## Result

The supported remote Godot profiler captured **120 consecutive active frames, engine frames93–212, no gaps**. The existing Main/Escaros fixture retained `(3953,5016)`, initial133 actors, normal AUTO,90 frozen warmup frames and120 active samples. Fixture assertions passed. This is attribution with profiling overhead, not a before/after speedup.

The previously unexplained first-combat cost is now localized to **Godot's native 2D physics `integrate_forces` profiler bucket**:

| Engine frame | Frame time | Largest physics tick | Process time | Relevant work |
| --- | ---: | ---: | ---: | --- |
|94|371.848ms|333.426ms|21.731ms|2D integrate_forces has179.325ms and6.449ms entries; all reported2D/3D physics server stages total191.447ms|
|95|457.331ms|385.004ms|19.180ms|AStar get_point_path394.771ms inclusive; all physics server stages2.315ms|

Frame94 monster physics functions total156.767ms, including146.874ms world paths. Engine physics stages are separate from these script callbacks. Their191.447ms identifies the missing native category; they must not be subtracted from the largest single physics tick to claim an exact additive frame decomposition. The engine reports the **maximum tick**, while server entries include multiple ticks. Frame95 remains dominated by cold graph edge validation. No additional optimization or whole-game lag fix is claimed.

The raw script `script_time` cannot be summed as exclusive wall time: native AStar callbacks re-enter scripts, and inherited-call accounting includes overlapping values (frame95 script_time1096.607ms exceeds wall time457.331ms). Keep inclusive function timings and native-stage timings separate. Maximum327 function records per active frame is below the1024 requested cap. There are no dropped-message notices. Visual data is also captured; llvmpipe GPU timestamp intervals are not Android GPU measurements and are not used to attribute this physics cost.

## Exact remaining boundary

Matching engine source shows that `GodotStep2D::step` labels **both body force integration and broadphase collision-pair registration** as `integrate_forces`. The existing remote profiler cannot separate those two operations. Therefore this establishes the native bucket, **not which body/shape or broadphase operation causes it**. No collision deletion, physics-rule change, speculative chunking or actor modification was made.

The installed official binary is stripped. `perf`, `gdb` and `tracy-capture` are absent; CLI exposes script and GPU profiling but no native CPU trace capture. `strace` is available but syscall timing cannot attribute CPU work within this bucket. Further attribution requires a matching symbolized Godot build with native sampling/trace support separating `GodotBody2D::integrate_forces` and `GodotSpace2D::update`, or equivalent native profiler access. This step stops at that concrete tooling boundary; it was not an authorization denial.

PR155 remains OPEN (observed head9b5c475082372226c0f684e2a29f389d7d19b638). Its collision/map ownership is preserved. The profile does not prove a dependency on PR155 or that its changes fix this bucket.

## Reproduction and files

`tools/profiling/remote_frame_collector.gd` is the exact tested loopback collector. Run it with Godot4.7.2 headless against a temporary minimal `project.godot`, `--max-fps 240`, writable XDG data/cache and `PROFILE_CAPTURE=<jsonl path>`. It binds127.0.0.1:6017, enables servers1024/native calls and visual profiling on this build's main thread1, then drains packets until target disconnects (180s timeout). It is specific to the recorded protocol/build, not a general debugger client.

Launch the game with `DISPLAY=:97`, isolated writable `XDG_DATA_HOME`, `XDG_CACHE_HOME=/tmp/lineagem-raster-cache`, `TWILIGHT_PERF_OUTPUT=<benchmark json>`, and:

```
Godot_v4.7.2-stable_linux.x86_64 --path /workspace/- --remote-debug tcp://127.0.0.1:6017 --script tests/benchmark_population_entry.gd -- --native-png-maps
```

Decode with `python3 tools/profiling/decode_remote_frames.py capture.jsonl decoded.json`. The active window follows BEGIN/END events in the ordered debugger stream. Raw capture contains215 server frames,210 visual frames,1340 signatures and the120 active frames. Existing warning events are retained. A preliminary collector addressed nonexistent thread0 and received no profiler frames; it was discarded as a measurement, then corrected from the actual main-thread ID1. No gameplay code or timing markers were added.

Files alongside this note: `continuous-first-combat.jsonl` raw packets, `continuous-first-combat-decoded.json`, `continuous-first-combat-benchmark.json`, `continuous-first-combat-game.log`, and exact collector snapshot. The fixture measured max461.104ms, p95(nearest rank)48.767ms and p99412.371ms; its process-frame observation boundary differs from engine frame timing. Do not compare these overhead-bearing values as an improvement over earlier unprofiled runs.

Resource integrity PASS723 atlases /41442 frames /233420026 bytes. No full CI, merge, Android test or Library retry performed. No new runtime change required gameplay regression; the actual120-frame fixture and decoder consistency were checked.

## Engine source

Exact official build commit `ed1daf0bf`:

- https://github.com/godotengine/godot/blob/ed1daf0bf/servers/debugger/servers_debugger.cpp — profiler command options and serialized frame fields.
- https://github.com/godotengine/godot/blob/ed1daf0bf/core/debugger/remote_debugger.cpp — thread-addressed Variant messages.
- https://github.com/godotengine/godot/blob/ed1daf0bf/modules/godot_physics_2d/godot_step_2d.cpp — integrate_forces bucket includes broadphase update.
- https://github.com/godotengine/godot/blob/ed1daf0bf/main/main.cpp — physics time reports maximum tick.
