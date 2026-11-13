# Remove unused quickslot row projections

Base main: `447ed69fd622afc650289048241fb99ff1d36078` (#467 and loading #464 included). This is a separate follow-up to #468's bitmap node reuse.

## Runtime path and scope

`renewal_hud._process_step` refreshes source quickslots on its existing 0.15-second refresh clock. `source_main_quickslot_view.refresh` takes a full ten-row snapshot, then calls `refresh_slot` for each of ten rows. Each single-slot call previously made another full ten-row snapshot. With ten filled slots that meant 110 entry copies, amount projections and `_quickslot_ammo_source` calls per refresh. This is a code path and a reproduced synthetic count, not an Android cost attribution.

A single-slot refresh now requests only its own row projection. It still checks the live world/page model and every slot's index and caption/cooldown labels, preserving failures in an unrelated slot. It still reads the selected row again on every call, then checks passed/presented identities before writing text and visibility. There is no cross-call cache, stale shared batch model or skipped selected-row validation. Public `snapshot` continues to return a complete isolated model. Image lookup, page rebuild, input dispatch, AUTO policy, cooldown policy, save data and original resources are unchanged.

The retained M100 adapter (`oc_m100_m102_quickslot.gd`) separates original metadata/BulletID/count observations. Its internal observations and count/visibility arithmetic are unchanged: only unused outer UI projections are removed. The original adapter is a reconstructed design, not a recovered native API or original-client benchmark. The earlier Android/Windows/XP Hero static evidence does not establish this Godot bottleneck's device duration.

`ui.quickslot_snapshot` is an inclusive hitch detail, retaining calls/total/longest call without adding a second top-level HUD section. Do not sum it with its containing HUD time. It also records failed snapshot attempts.

## Evidence

The new headless test drives the actual quickslot view and bindings with synthetic HUD/world/slot sinks. Its comparison restores the former full-snapshot call in `refresh_slot`; with default scope the row builder follows the unchanged complete-model path. It checks exact substitution and compares returned values and all text/visibility/identity writes.

- 76 assertions pass, covering live changes after the earlier snapshot, nested snapshot ownership, empty/out-of-range/item rows, invalid labels/indices in another slot, invalid pages, changed entry/page identity, manifest mismatch, wrong scene, renderer rejection and stale-click refusal. Diagnostics remain inclusive-only.
- One actual-view refresh: **110 to 20** projected/copied rows and ammo-provider reads. The outer ten-row snapshot remains; each slot independently re-reads its own live row.
- Optional uninstrumented CPU benchmark: four alternating-order batches, 100 actual-view refreshes each, ten synthetic filled skill slots. Old microseconds `[193669,200329,200457,212438]`; new `[60691,59074,62623,58801]`. Slot sinks capture calls without glyph rendering; these are Linux CPU samples, not Android FPS or process-memory measurements. No timing threshold is used in CI.
- Existing M100 amount/snapshot subtests pass: 40,350 amount cases plus ten-row/live-zero-ammo checks. Other historical M81/M87 wiring tests are not claimed as run.
- Focused font ownership 51, UI memory lifecycle 210, HUD 6, inventory snapshot 983, quest text 30, hitch logging 26/draw phases 205, and actual Main save/reload 33 checks pass. Main uses absent-install handling: full installed original-map traversal is unavailable.
- Python staging: 14 tests pass. Available no-legacy resource check passes 20 tracked resources. The historical `tools/check_resource_integrity.py` named by AGENTS is absent. No original assets are added, removed or redistributed.

Reproduce using the production stage from `tools/ci_core.py --prepare-only`, Godot 4.7.2, `--script res://tests/source_quickslot_row_work_test.gd`; optionally append `-- --benchmark`. Core CI registers the differential test and checks its marker/errors. There is no changed drawing implementation requiring a new pixel baseline in this follow-up.

The photographed multi-second unmeasured frame remainder remains unexplained. This optimization does not prove it was the cause or that Android lag is resolved. A new device run with build ID, trigger and saved hitch details remains necessary.
