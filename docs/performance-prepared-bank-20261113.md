# NPC prepared-bank reuse (2026-11-13)

Base main: `3ea41de9dee65cf3cbe2c65c9f68e6d3cbaa5b45`. Independent of draft #442 and #444. Neither was changed or merged. This fixes repeated action/proof/track preparation and duplicate metadata ownership for NPC visuals; it does not introduce asynchronous gameplay admission or claim to reproduce the phone's previous 12,432ms population section.

## Confirmed repeated work

`monster.setup()` creates a current source view; `configure_admitted()` still checks the active actor registry and performs exact selection. Every NPC then called `load_bank()` and `POLICY.tracks()`. Raw SP2 data could be warm while action JSON, per-frame layer proof, expanded tracks and a deep policy copy were rebuilt for each actor. In the synthetic five-role/32-token/eight-direction fixture, one result serialized to 13,106,548 bytes (the record alone 6,553,380); deserializing the record took ~188ms in an exploratory run. Serializing whole results was therefore rejected as a solution, and no persistent result cache is added.

## Ownership and invalidation

NPC previews explicitly request `load_shared_bank()`. The existing `load_bank()` remains the independent, mutable full-validation API and test oracle. The new API publishes only successful results as recursively read-only metadata. Full validation, source exclusions, optional-role selection and exact action/loop bindings remain authoritative; a cache result never admits a gameplay actor.

The process-local key includes the bank script identity, exact manifest path/SHA, source actor, ordered bindings, loop policy, consumer and role-actor overrides. Every hit rechecks manifest/action SHA pins through the existing size/mtime policy and checks all used members' verified identity stamps, existence, size and mtime. Any miss/change runs normal validation again. `forget_verified_members()` also clears the weak index. Received CRC/receipt inputs retain nullable SHA and their exact source domain. Their source-identity metadata is detached once per member before freezing, so the separate shared manifest index is not accidentally frozen.

A snapshot owns immutable tracks/provenance and the metadata needed by each bank. It owns no Node, clock, animation event state, gameplay state, texture or parsed-member lease. Each bank keeps its own lease owner and re-verifies drawing inputs normally. Each preview gets fresh track/direction/frame containers for timing policy edits; only recursively read-only layer/provenance values are shared. Clear/restart/retire cannot clear another actor's tracks or advance its clock.

The lookup table contains at most **64 weak references** and owns no idle snapshot. Live banks keep snapshots alive; after the last owner is released, a future request must prepare again. Evicting a weak key does not revoke a live owner. This preserves the existing retirement/release behavior and avoids a new strong reserve of large track data. It is not a whole-process memory cap: live actors, their frame containers, existing raw/pixel caches, renderer and external owners still consume memory.

No decoder or disk-parse key changes are included here. No additional asynchronous completion/generation handling is needed because preparation/admission remains synchronous. This does not establish a 4ms hard bound on a cold setup.

## Synthetic measurements

Official Godot `4.7.2.stable.official.ed1daf0bf`, Linux headless. Five core roles × 32 tokens × eight directions, three invented tiny SP2 members, ten live NPC reference previews. Existing manifest/raw caches were primed equally. Each cohort began with no prepared snapshot owner; first actor cost is retained. Baseline uses the exact main NPC preview function and the unchanged mutable full bank loader. Fingerprints were computed after timing. Three rounds alternated cohort order; no speed threshold is asserted.

| Round | Before: first / subsequent median | After: first / subsequent median |
| --- | ---: | ---: |
| 0 | 162.529 / 332.456ms | 150.063 / 3.215ms |
| 1 | 145.176 / 133.403ms | 145.231 / 2.894ms |
| 2 | 181.353 / 132.525ms | 145.537 / 3.654ms |

The median of the three subsequent medians is **133.403 → 3.215ms**. Round 0's slower baseline is preserved, not discarded. First-actor full validation and freezing remain visible costs. The complete benchmark ran before the full local core gate.

Godot's static allocator live delta for the ten-view cohorts was ~464,687,3xx bytes (~443.16MiB) before and ~36,538,8xx bytes (~34.85MiB) after, including small diagnostic arrays. The previous path had ten distinct records and deep policy copies; the new path had one shared source record plus ten private timing/container sets. Every view's output fingerprint matched baseline. All weak snapshot keys disappeared after freeing the views. These are engine allocator observations for deliberately repetitive synthetic metadata, **not Android RSS/PSS, GPU memory or a measurement of the whole game**.

Data and all cohort samples: `performance-prepared-bank-20261113-evidence.json`. Reproduce in an isolated XDG profile using:

```sh
godot --headless --path . --script res://tools/benchmarks/benchmark_sp2_prepared_bank.gd -- --output=/tmp/prepared-bank.json
```

## Source evidence and tests

The already materialized original Windows P10 report (`SPRITE_CACHE_LIFETIME_REPORT_KO.md`, analysis ZIP SHA `ee7fe088f39fd3d317631c66bddf4d436d55d08046081e267f934c4e3802716c`) describes RawSpriteFile cache hits at `01C74AB0` returning a strong owner without reader/parser work, and `01C716E0` returning when Graphics exists. Its raw LRU limit is not an aggregate RAM limit. These ownership/reuse boundaries informed the comparison; the Godot prepared-track snapshot is our implementation, not a recovered native track cache.

The previously verified XP Hero IL2CPP metadata declares shared resource handles, pool get/return and bundle release. Declarations do not prove native bodies or scheduling. Its mod APK remains static-only. The Android source report's worker/completion boundary likewise does not make today's Godot bank thread-safe. This PR adds no worker or concurrency.

New regression test: 159 checks covering byte-for-value results against full validation, mutable API preservation, read-only recursion, request domains, timing/node/clock isolation, all eight directions, layer visibility/placement/decoded pixels, missing/changed members, same-size mtime changes, changed JSON/manifest pins, explicit invalidation, received CRC provenance, native occurrence identities, excluded graph rejection and weak-key lifetime/bounds. Full runtime/save/resource and remote CI results are recorded in the PR when completed. The existing source-map CI fixture has zero private terrain inputs; synthetic gates do not prove full private-pack visual equivalence.

## Pending-PR integration check

Combining #442 (`d944731c800304b2f7ad476917d19fdd7ae76a43`), #444 (`40b32e2093d211d4288c6056a5b39f3c83509635`) and this implementation in an isolated scratch tree has no textual conflicts. Neither existing PR branch was changed. The combined new prepared-bank test passes 159 checks.

The unmodified #442 optional-role test has 17 **operation-count** failures when combined: its still-live baseline view primes the prepared snapshot for the next cohort. Its complete result/status/track and pixel comparisons still pass. The [three-line test-isolation patch](prepared-bank-optional-cohort-isolation.patch) clears only the weak prepared index before each measured cohort, leaving raw caches and every assertion intact. This patch is required when integrating the two PRs; it targets a test absent from current main, so it is supplied here rather than importing another PR's test or modifying its branch. After applying it in the scratch tree, all 106 optional-role checks pass. Combined CRC (149), population budget (8), quickslot (35), decoder equivalence (38,916) and parse-cache (17) checks also pass without script/runtime errors. These are targeted integration checks, not a full combined-branch gate or a merge approval.

The obsolete mandatory `tools/check_resource_integrity.py --root .` is absent from main. The actual `check_no_legacy_resources.py --root .` passes with tracked=20. No original resource is added or removed, no quality reduction or source identity promotion is made. Saves, exchange and character creation are unchanged. Actual device/logcat validation, the exact historical 12.432s child cost, cold-time preemption and shutdown/crash investigation remain outside this completed change.
