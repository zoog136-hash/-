# Map foreground and texture publication slices

Base: `28de35d0207e3a8ebfb0d03673ba274d3b8110ea` (fresh main verified 2026-11-23).

## Changes

1. `69a4a52`: renderer foreground scheduling. In-flight S32 reads are polled,
   never joined by `_read_chunk`; worker-capable cold reads are queued. A block
   cannot be baked from incomplete chunks. Legacy readers keep their synchronous
   path. Visible blocks are offered before margin blocks; the 4 ms build/pending
   slice is checked before each block, including attempts which bake nothing.
   Completed command jobs remain available while atlases are pending. Terminal
   atlas failures filter the same records and report the same diagnostics without
   re-entering the synchronous assembler. Diagnosed unreadable chunks no longer
   prevent worker blocks from completing indefinitely.
2. The following commit slices atlas publication and optional compression swaps
   by `Engine.get_process_frames()`, not by pump call count. Per tile-pack instance:
   at most two completed publications per frame, stopping additional publications
   after 2 ms. Per tile GPU queue: at most one completed texture swap per frame.
   One eligible operation can always progress; a single driver operation cannot
   be interrupted. Repeated `pump_gpu`, `pump_jobs`, `texture_for`, and queue pumps
   share their respective allowances. Visible pending-block atlas IDs receive
   priority; every fourth selection serves oldest-ready work to prevent starvation.
   Pending jobs retain their image/texture references. Cache/held texture lifetime,
   decode verification, pixels, texture identity, and compression format are kept.

These are scoped scheduling changes, not equivalence between Windows Surface
updates and Godot's 512x512 block viewports. Layer/member/record command order,
collision and movement rules, prepared-region instant teleport, and return/travel
loading are unchanged. NPC/cooked-resource code and Android SP2 workers are
untouched. Live-map atlas compression remains disabled, as on the base revision.
Explicit synchronous consumers retain synchronous texture acquisition.

## Validation

Godot 4.7.2, isolated temporary user profiles; no user saves were used.

- Full project import in the focused core stage: no parser/runtime error markers.
- Focused `tools/ci_core.py` runner (12 selected scripts, not the full remote gate):
  `loading_world_readiness_test` 7, `core_runtime_save_test` 33,
  `current523_aden_play_renderer_test` 142, `current523_tile_gpu_test` 12,
  `current523_aden_play_controller_test` 25, `current523_long_teleport_test` 12,
  `current523_move_speed_map_travel_test` 18, `current523_prior_renderer_release_test`
  38, `current523_source_field_test` 9, `current523_map_frame_spread_test` 37,
  `current523_map_foreground_test` 16, `current523_map_upload_budget_test` 22.
  All passed. Both new tests are registered in the unchanged full core gate.
- Tile-pack runtime compatibility: 104 checks passed with the existing 35-atlas
  synthetic fixture (synchronous reads, SHA/metadata rejection, missing/repaired
  sources, cache eviction and held atlases). Its polling test now advances actual
  frames rather than assuming repeated pump calls grant a new allowance.
- Python: core-runner tests 14/14, tile-pack tests 21/21, no-legacy-art tests 7/7,
  compilation of tools/tests, and `git diff --check` passed.
- Current resource gate: `python3 tools/check_no_legacy_resources.py --root .`
  passed. The old `check_resource_integrity.py` and delivery ledger named by the
  historical AGENTS instructions are absent from this main; their command was
  attempted, and the actual current resource-integrity workflow was followed.
- Supplemental llvmpipe OpenGL: upload-budget assertions 22, tile GPU assertions
  12, and frame-spread assertions 37 passed. Those initial desktop runs also logged
  missing audio-device errors and an unavailable Vulkan initialization used by the
  compressor; they are not claimed as clean hardware/visual acceptance. The clean
  headless core run did not log those errors.

## Repeatable synthetic comparison

The delayed-read regression uses an 80 ms worker delay plus normal synthetic S32
projection. On the base renderer the foreground call took 96,146 us and failed the
new nonblocking assertion. With the change it took 11 us (warm cached read: 6 us)
in the focused run. This measures removal of a wait, not Android FPS.

Eight already-completed atlas jobs, then 20 pumps in one engine frame:
base published 8 / retained 0; changed published 2 / retained 6. Headless wall time
(79 vs 70 us) is not a useful GPU performance comparison. The regression drains
all eight over four actual frames, verifies visible first paint in the first
eligible frame, continuously-arriving visible-work starvation protection, and
retained texture identity after eviction/release. A synthetic 3 ms upload admits
one publication and defers the next even across repeated pumps (3,125 us measured).
The 6 ms readiness fixture similarly stops after one attempt (6,111 us); neither
budget claims it can preempt an indivisible operation.

## Remaining validation

No Android device was connected or tested. No APK build/release, deployment, or
main merge was performed. No original/private artwork was obtained, modified,
substituted or delivered. Real-pack teleport render tests explicitly remain
skipped without that pack. Desktop synthetic success does not establish device
frame time, GPU-upload cost, first-paint latency in dense real maps, or original
client visual equivalence. Upload slicing intentionally spreads a ready burst
across frames; tune only with device captures. Remote required CI is reported on
the draft PR independently of these local results.
