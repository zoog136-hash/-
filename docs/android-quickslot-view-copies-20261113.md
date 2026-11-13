# Avoid redundant quickslot view copies

Base main: `6733f32c04048cd7fe7f7d24dd17fddba93d4138` (#469 included). #471's map animation change is independent. No original art, game data, drawing commands, resource validation, saves or account/trade behavior is changed.

## Observed code path

The HUD's existing 0.15-second refresh calls `source_main_quickslot_view.refresh`. After #469, the bindings still deliberately produce isolated live snapshots (one complete model plus one selected-row reread per slot). The view then unnecessarily deep-copied ten entries again just to compare them with its saved identity, and retained a deep copy of ten presentation rows that no reader used. Repository-wide search found `_rows` only at its declaration, writes and clear in this view.

The view now compares the validated live model's pages, ordered visible/absolute indices and complete entry dictionaries directly against its existing owned identity. `_model_identity` still deep-copies the staged identity, so later nested entry mutations cannot silently change what the displayed scene represents. Entry/page changes, including AUTO, still request the original rebuild. Amount/caption/cooldown changes still refresh live text and visibility. The unused presentation-row cache is removed. No shared mutable cross-refresh snapshot or new cache is introduced; image registration, input capture, stale-hit checks and original M100 presentation arithmetic are unchanged.

The M100 native reconstruction and earlier Android/Windows/XP Hero static evidence remain context, not proof that those clients implement this comparison or a native performance measurement. This is a TWILIGHT allocation reduction on the inspected Godot path.

## Verification

- Godot 4.7.2 production resource stage imports cleanly. New differential test: **527 assertions**, no runtime errors. It compares production refresh/bindings against the former deep-copy comparator/retained-row path using synthetic host/slot sinks. Only stage entry is intercepted to observe rebuild requests; full original CSB construction is not claimed as tested by this fixture.
- Empty, partly filled and filled pages preserve text/visibility/identity writes. Coverage includes nested mutable ownership, stale-touch rejection, changed/reordered pages and indices, changed AUTO/entry, row count differences, unrelated caption/cooldown changes, missing labels/indices/hits, rejected rendering, busy refresh, close and reopening before deferred deletion.
- Twelve unchanged ten-slot refreshes: **120 extra identity-entry copies plus 120 retained presentation-row copies become zero**. The required binding snapshots and all live validations remain. The removed cache previously retained ten rows. This is an operation/ownership count, not measured Android RSS or GPU-memory savings.
- Optional CPU-only benchmark, four alternating-order samples of 100 refreshes with ten synthetic filled entries: old microseconds `[59967,60614,67043,64368]`, new `[56515,54379,55877,55467]`. Slot sinks record calls without rendering. These are local Linux CPU samples, not Android FPS; no timing threshold is enforced. The subsequent test-only reopening assertions do not change the benchmark path.
- Existing row-work 115, bitmap glyph 71, bitmap ownership 51, UI memory lifecycle 210, HUD 6, inventory snapshot 983, quest text 30, hitch logging 26/draw boundaries 205, actual Main save/reload 33 assertions pass. Main exercised absent-install behavior; full installed-original-map traversal is unavailable.
- Python staging 14 tests and the available no-legacy resource check (20 tracked resources) pass. The historical `tools/check_resource_integrity.py` and `data/resource_delivery_ledger.json` named by repository instructions are absent; no original-resource delivery claim is made.

Reproduce via the production stage from `tools/ci_core.py --prepare-only`, then Godot `--headless --path <stage> --script res://tests/source_quickslot_view_identity_test.gd`; optionally append `-- --benchmark`. Registered in core CI without removing existing suites. Drawing implementation is unchanged; no new pixel-baseline claim is needed for the comparison-only change.

## New device evidence and remaining gap

The parent provided a verified transcription of Library image `libfile_a9ac39bd7f248191a41a1dfe7461bdfa`: the loading screen is 523.447, but its previous-run record is **523.445**, 1,491 hitches, maximum 9,213 ms, unmeasured remainder 8,866 ms, skills 213 ms, player 104 ms, inclusive `ui.inventory_stage` 337 ms × 1; draw-callback before/between/after spans 245/18/8,949 ms. This follow-up did not independently open that image or receive the complete JSON/logcat record. It is not evidence about an execution of this branch or #471.

`frame_hitch_log._draw_sample` reports callback-delivery wall intervals, with the last span ending at the next early `_process` probe. That interval includes whatever occurs after the observed post-draw callback and before that probe; it is not exclusively GPU work, GC, engine work or sleep. `source_main_inventory_view._stage` records an inclusive detail only. Input-triggered staging may fall outside timed HUD `_process` sections, and 337 ms must not be added to the total or used to explain the entire 8,949 ms gap. The screenshot alone cannot locate that operation within the callback spans.

The existing full JSON includes logger duration, process-tail timing and pause/focus observations, which are necessary to narrow this case before assigning a cause. These observations do not by themselves prove GC or GPU time either. Android hardware, logcat/Perfetto captures and the complete installed source packs are unavailable here. This allocation change does **not** establish that the reported multi-second stalls are fixed.
