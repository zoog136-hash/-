# Cooked NPC first-page preparation pilot

Default: **off**. Enable with `--twilight-cooked-npc-prewarm` after Godot's
`--`, or `TWILIGHT_COOKED_NPC_PREWARM=1`. This is a gameplay NPC admission pilot,
not a general asynchronous sprite renderer. It requires the existing accepted
installed cooked pack and exact selection-input match. No pack format, pin,
source asset, original SP2 worker policy, collision, or teleport rule changes.

## Behavior

The NPC view determines the exact idle/direction-5/time-zero cooked state before
constructing its preview. All pages of that pose are reserved together. Pending
work uses the existing `current523_view_deferred` population retry path, so no
unpainted NPC is admitted to combat and its animation clock does not advance.
The ready ticket holds every texture through the actual first pose application,
including pages evicted from the reserve while other pages were installed.
Sprites then retain their existing strong texture ownership.

The worker receives a read-only array of scalar path, range, dimensions and
format values and a private result slot. It opens its own file and calls the
existing bounds/size/Zstd/Image validation. It never reads an actor, animation
track, cache dictionary, sprite, or GPU object. The main thread only consumes
results after task completion. Normal requests, pumps and cancellation do not
join unfinished tasks; explicit test/teardown draining may join.

Texture creation occurs on the main thread, at most **one prepared page per
Engine process frame**, shared across every request and population pump. An
unfinished earlier job does not prevent publication of a later completed job.
A single upload is indivisible; this is a count bound, not a guaranteed maximum
number of microseconds. The existing map upload allowance is separate.

At most eight unique page jobs, 8 MiB compressed bytes and 32 MiB unpacked
reservation are admitted. Unpacked reservation charges twice each raw page's
bytes (decompression buffer plus Image/upload copy). Reservations remain charged
through retained ready textures and cancellation until jobs are reaped. Warm
pages held for a partial pose count too. Whole-pose reservation avoids partial
admissions filling the queue with poses none of which can complete. Shared pages
are deduplicated and reference-counted across tickets. An individually oversized
pose uses the existing synchronous path instead of waiting forever.

Read failures retain the existing 250 ms retry contract and `page_unreadable`
accounting. Tickets unused for two seconds expire. Pack-root changes, disabling
the store and leaving a field cancel tickets without an I/O wait. In-flight
cancelled results stay bounded until a subsequent pump (or explicit teardown)
reaps them; they are never uploaded. If no population remains active, that
bounded reservation can persist until the next population/test teardown.
Installed packs remain immutable and versioned as before; in-place modification
of an accepted pack is not a new supported workflow.

Player previews, UI cards, effects, overlays and later NPC animation pages keep
the existing synchronous path. This avoids dropping a short effect while its
clock runs unseen. Existing `apply_state` resolves a complete pose before
mutating sprites, preserving the prior pose on page failure. Index lookup and
preview construction still run on the main thread, as do synchronous oversized
fallbacks. The pilot does not promise hitch-free spawning or enable Android's
original SP2 worker disabled by #605.

## Reproduction and coverage

Use Godot 4.7.2 with an isolated XDG/user profile:

```sh
godot --headless --path . --script res://tests/cooked_page_prepare_test.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tests/cooked_page_prepare_test.gd
godot --headless --path . --script res://tests/cooked_actor_pack_test.gd
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tests/cooked_actor_pack_test.gd -- --render
```

The new test is registered in `tools/ci_core.py`. Its synthetic TWCA fixture
covers delayed private I/O, per-frame limits under repeated pumping, duplicate
and overlapping requests, byte and job bounds, finite queue progress, complete
first-pose admission through the production population retry logic, cache/index
eviction and live texture reuse, cancellation, root changes, expiry, failure and
repair, zero-duration frame selection, unchanged short effects and player/card
previews, and exact CPU pixels/alpha/positions/regions/layer order versus sync.
The spawn test replaces source-selection/stat setup; it does not represent a
real installed-pack combat playthrough. Existing cooked-actor tests cover
atomic later-pose failure/recovery and source-equivalent synthetic rendering.

The timing fixture is one solid-color 1024x1024 RGBA page, with OS file cache
likely warm. “Cold” means no runtime texture/index cache, not cold storage.
Compare synchronous first page, asynchronous submission, eventual ready latency
and warm repeat separately. Worker scheduling and render pacing vary; total
first-paint latency can increase even when foreground submission becomes cheap.
No test here uses or publishes original game pixels. Linux headless and Mesa
llvmpipe desktop results are synthetic evidence, not Android GPU measurements.
A physical Android A/B and original-pack playthrough are still required before
considering a default-on rollout.

## Recorded local validation (2026-11-23)

Developed on #848 head `eca0587554f32554224499403afd5c4e2e67d51e` in the existing
map workspace. The new PR must be rebased onto exact main after #848 merges.

| Synthetic one-page measurement | Headless | Desktop OpenGL / llvmpipe |
| --- | ---: | ---: |
| Synchronous first read + image + texture | 1,220 µs | 2,536 µs |
| Asynchronous request foreground time | 94 µs | 92 µs |
| Asynchronous ready wall time | 3,706 µs | 20,509 µs |
| Process frames until ready | 1 | 2 |
| Synchronous warm hit | 8 µs | 10 µs |
| Prepared warm pose request | 26 µs | 33 µs |
| Request with semaphore-delayed worker | 35 µs | 54 µs |

These are single repeatable-fixture samples, not percentiles or original-pack
benchmarks. The prepared warm request includes whole-pose bookkeeping while the
sync warm measurement is one page lookup. The earlier reported ~13 ms synthetic
CPU preparation signal used a different workload and is not this result or an
Android GPU measurement.

- Final pilot: **76 checks**, headless and desktop, no failures.
- Existing cooked actor contract: **331 headless checks**, 81 CPU pixel
  comparisons; **350 desktop checks**, 81 CPU comparisons and seven render
  checks; no failures. Desktop emitted only the llvmpipe V-sync warning.
- Focused `ci_core.py` run: full staged project import plus eight selected
  suites passed (actor pack, pilot, spawn frame budget, effect index, loading
  readiness, SP2 load memo, actual Main/save preservation, and Main UI). That
  staged pilot ran the earlier 74-check version; the final 76-check version was
  rerun separately in both headless and desktop modes. This is **not** the
  entire remote required CI gate.
- Current resource policy checker and seven Python regression tests passed.
  The historically mandated `tools/check_resource_integrity.py` is absent in
  this revision; the current workflow uses `check_no_legacy_resources.py`.
- Android hardware, original-pack gameplay, and full remote required CI: **not
  run**. No APK release, OTA deployment, original asset transfer, or main merge.
