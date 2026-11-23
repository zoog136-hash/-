# NPC cold cost: lazy relation indexes (PR #847 revision)

The eager preparation in `d954e1d0ef868691197cde3dd21c98ba3c030fd3`
is rejected. The owner ran that exact revision with the SHA-pinned local
original 523 archive and NPC 74161:

| Boundary | Unprepared | Eager preparation + projection |
|---|---:|---:|
| Cold | 2090.87 ms | 4244.86 + 92.12 = 4336.98 ms |
| Restart | 99.47 ms | 179.06 + 46.36 = 225.42 ms |

Warm p50 stayed about 0.25 ms; record/closure hashes matched. Cold static peak
increased 62.3→95.7 MB; preparation retained about 1.73 MB. These are the owner's
original-source measurements, not measurements reproduced on this executor.
They demonstrate a total-cost regression despite faster spawn projection.

## Revised implementation

- Remove the loading-screen NPC preparation completely. `SpellClass` is never
  read just because a first NPC might later need it. No new loading work,
  precomputed pack installation or worker is introduced.
- Optimize only the numeric relation index for actually queried `NpcAttack`,
  `NpcAttribute`, `NpcSpecialResistance`, and `SpellClass` input columns.
  Typed validation avoids the old per-row Variant/type-list check. Already
  ordered owner columns need one script pass rather than composite sorting and
  a second decode pass. Unordered columns keep the original stable composite
  sort. Invalid/noncompact columns use the unchanged builder and diagnostics.
- Keep the existing definition store, persistent relation representation, keys,
  SHA checks, and atomic writes. No format-region change, forced rebake,
  generated original data or new cache format. Restart reads use the same
  persisted indexes, so a large restart speedup is **not** expected.
- Retain at most 2 MiB of compact indexes only after actual reads. No full
  columns or extra table are retained proactively. Direct index lookup checks
  the current source without reloading the whole table merely to return row
  positions. Reset/source changes still clear indexes.
- `TWILIGHT_NPC_RELATION_FAST=0` selects the former lazy builder and release
  policy for A/B; unset or `1` enables the candidate. Admission, source
  ID/Sprite/DescId/category/Test/dummy checks, projection, stats, loot and saves
  remain unchanged. No map renderer, sprite worker or card-effect change.

This is a modest CPU-work reduction candidate, not a claim that JSON conversion
or the Android 8.86-second stall is solved. Original cold table conversion and
verified disk opening still dominate. A synthetic four-table run measured
914.6→896.0 ms total cold reads and 30.0→27.9 ms restart reads. Those numbers
are only fixture evidence; real-source total-cost benefit remains unverified.

## Repeatable original-only total-cost A/B

```bash
python3 tools/monsters/benchmark_npc_cold.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --source /private/path/to/original-patch523.zip \
  --npc-ids 74161 --rounds 3 \
  --output /private/results/npc-total-ab.json
```

The runner verifies SHA-256
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`,
25,031,173 bytes and ZIP CRC, then uses separate disposable profiles per round
and on/off mode, alternating mode order. Each cold disk run is followed by a
new-process restart with the same profile and 40 same-process warm repeats.
It reports per-stage values and **total_stage_ms = original source open/verify
+ NpcClass reads + first projections**, plus total medians by mode/state,
actually opened table names, cold table-conversion times, index-build counts,
and memory. Warm repeats and output hashing are excluded from the timed total.
The boundary is broader than the prior projection-only cold number; compare
on/off within the same runner, not absolute old/new totals across boundaries.
All complete projected-record and closure hashes must match in every run.

Add comma-separated eligible IDs to check later distinct NPC closures. Only
hashes, timings, table names and IDs leave the probe; no original content is
published. This is still an isolated data-stage benchmark, **not full game
boot through first rendered encounter**, and not an Android device result.
Neither actual source nor an Android device is present in this executor.
Keep the PR draft until the owner reruns the original and total cost/memory
are acceptable. No merge or deployment.

## Regression checks

`tests/current523_npc_relation_index_test.gd` compares complete rows and index
bytes on/off, cold/restarted reads, sorted/unsorted/negative/duplicate keys,
fractional/nonfinite/extreme rejection, nested freshness, lazy table use,
retention bounds and source-path invalidation. Run with disposable XDG paths.
The core gate includes this test. Final focused regression: 9 Godot scripts /
323 checks passed; 25 NPC compiler/resource-integrity/core-harness Python
checks passed. Final-code loading checks passed 74 + 7 checks; actual Main/save
reload passed 33 checks. NPC closure/catalog, row lookup, atomic bake,
store-format, used-table, stream-conversion and actual Main/save tests remain.
Original-dependent test branches must still report `not_installed` here.

Current main removed the historical `tools/check_resource_integrity.py` named
by AGENTS. Its current required workflow uses `tools/check_no_legacy_resources.py`
and `tests/test_no_legacy_resources.py`; neither proves original-art delivery.
