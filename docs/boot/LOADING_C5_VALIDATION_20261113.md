# C5 loading validation — 2026-11-13

Final integration base: `e81010218f3fb902275324e3cff81dd7528e1318`.
Final integrated full-startup measurements and remote CI are pending at this source freeze. The PR body and local publication receipt will record the measured runtime fingerprint, published head, actual CI test-merge tree and final results without changing the measured source merely to update numbers.

## Changes

Definition row boundaries use five monotonic native delimiter searches across one member. Escaped strings retain the existing scanner, and native JSON parsing, malformed-input whole-parse fallback, row packing, source validation and cache verification remain in place. Cursor memory is constant. Reader code remains part of the existing bake fingerprint: updating can invalidate derived bakes and rebuild them. Fresh-profile first and same-code next timings do not measure an existing-install upgrade.

The private synchronous equipment compiler reuses successful runtimes for identical complete inputs: slot and raw-field presence/value plus every ordered effect row, including duplicates. Only the exact production owner, source and equipment compiler enable it. Public builds, injected readers and generic callbacks retain their original behavior. Source generation changes disable reuse; release clears it. Values are packed privately and freshly decoded on hits, preserving independent nested results. The LRU is capped at 128 entries and 4 MiB of serialized keys/values; this excludes container overhead and temporary encoding/decoding memory. Failures, nulls and oversize values are not cached.

## Verified targeted evidence

All observations below used official Godot 4.7.2 on Linux headless and the already verified local original-definition archive (SHA-256 `d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`). Original data and generated bakes are not included in this PR.

- Definition fixture: 99 checks passed with no parser/runtime/resource errors, including UTF-8/BOM, escaped strings, nested/mismatched brackets, invalid escape, byte cap, exhausted cursors and truncation after an earlier 512-row batch.
- All 45 initial-load tables (968,272 rows) preserved complete packed bytes, schema, column types and row order. Uninstrumented original → scanner: 23.427427 → 18.234686 s. Reverse order scanner → original: 17.852097 → 23.517243 s. These are convert-only subset measurements, not whole startup. The existing `def_table` log also includes ZIP member reading/decompression. A separate warm read diagnostic took 0.497 s; it cannot be subtracted from a different startup observation.
- Attribution copy: 24.013306 s convert-only, including 14.743189 s object-boundary scanning, 3.172015 s native parsing, 2.482035 s packing, 0.469746 s batch building and 3.146321 s remaining control work. Instrumentation overhead is included; these values are not a product speed comparison.
- Equipment fixture: 2,024 checks passed with no errors. Actual production compilation had 2,954 keys and 2,066 hits. Key construction took 0.146 s and hit decoding 0.290 s; retained serialized data ended at 1,414,164 bytes. Equipment runtime stream 9.630 → 7.433 s, round trip 15.406 → 12.844 s, total equipment cold 43.532732 → 41.931652 s. Five complete bake payloads and model digest were identical. Shared native-phase timing varied, so phase savings are not claimed as equal whole-game savings.
- Linux process HWM in that catalog pair was 1,246,952 versus 1,246,956 KiB, dominated by other phases; this does not establish an Android memory bound.

## Earlier Main-only and full-route observations

Before the scanner and newer main integration, the runtime-cache-only clean Main pair measured process first 219.189526 → 220.873489 s and next 67.909187 → 66.752659 s. The first whole-entry improvement was not established despite round-trip 13.855 → 11.422 s. Next uses an existing bake and does not exercise this cache. One sequential pair does not isolate OS cache/system-load variation.

The added full-startup harness runs actual Loading.tscn → zero-wait title input → actual character lobby/store/buttons → Loading.open(Main) → source-world readiness. A separate cache-only diagnostic measured process first 226.996703 s / next 69.438270 s. Within the harness, first initial loading finished at 52.532595 s, lobby ready at 52.565926 s and Main playable at 224.826363 s; next was 9.539103 / 9.572656 / 67.694233 s. Process time includes startup/autoload and exit overhead outside the harness clock; their difference is not a pure autoload measurement. Character creation, selection dispatch and initial saving are reported separately. User input waiting is zero.

The available inputs contain definitions, source map/tiles and world-links, without a full source-pack descriptor or original images/UI pack. These measurements are not download/install time, all-original-resource integration, visual approval, GPU performance or Android measurements. The fresh character does not exercise a varied existing inventory. Account selection legitimately changes revision; account state preservation is checked separately from byte preservation. Seeded save/progression/collection/boss preservation remains the required Core gate.

## Failed and unadopted diagnostics

The original C5 first run overlapped a small fixture and is excluded as a performance baseline. Two equipment fixture setup attempts had class/font import errors despite zero assertion failures and were not counted as passes; a complete known-good imported stage resolved setup. The JSON-entry optimization (`61090780`) preserved payloads but its small timing change matched unchanged-phase noise and is not included. Native direct-graph omission was not adopted. One reverse scanner fixture failed because its helper collided with Godot's builtin name; the corrected separate run passed. The first full-startup harness assigned `current_scene` before adding it to the tree and was interrupted as a strict harness failure; corrected ordering passed in a new profile. A Main baseline launch against candidate source was rejected by provenance before the game ran; the valid baseline used a separate pristine checkout. No validation was waived.

Required CI retains all 186 checks from the fixed integration base, including actual Main, seeded saves and resource paths. Historical/manual visual workflows remain separate. No merge is authorized by this validation document.
