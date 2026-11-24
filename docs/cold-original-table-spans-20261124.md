# First conversion of four original tables, not end-to-end Android boot

For the fixed compatible archive only, build_current523_boot_row_spans.py derives bounded batched row ranges. Its generator parses the entire original and every batch independently and requires equality; the product is 12 KB of numeric offsets and digests, not original game rows. Runtime requires exact member SHA, parses EVERY row with Godot JSON and the unchanged RowPacker (≤512 rows / 1 MiB per batch); unusual or changed data uses the general parser. No gameplay work is deferred. Equal bytewise serialization of the entire output store (field and row order, values and types) for ItemClass, Bonus, SpellClass and NpcClass. Published format v2 accepts the v1 cache only through its original key, size, index and digest checks. Existing valid relation indexes remain reusable.

Godot headless PC, four complete conversions in seconds before → after. Reverse order alternates across successive tables. Every sample retained; host scheduling/CPU speed varied materially. Runs 1–3 did not instrument thread CPU. The 11.64→5.85 s run had an unrelated disk-fixture error (it retained a live handle instead of restarting); after resetting the reader, the cold publication, true v1 reopen without rewriting, and corrupted v1 rejection → v2 rebuild checks passed. Totals do **not** include startup of other subsystems, GPU or phone.

| Run | Wall before | Wall after | Main thread CPU before | CPU after |
|---|---:|---:|---:|---:|
| 1 | 12.94 | 6.02 | not instrumented | not instrumented |
| 2 | 76.13 | 97.15 | not instrumented | not instrumented |
| 3 | 11.64 | 5.85 | not instrumented | not instrumented |
| 4 | 12.89 | 6.5 | 12.79 | 6.46 |
| 5 | 28.2 | 12.84 | 27.48 | 12.59 |

Production path: loading-screen prepare_table and normal _store use the identical pinned conversion on cache misses only. TWILIGHT 523.850 phone trace is a recovered play checkpoint, not a boot stage trace; no claim that five minutes is fixed or that these are its only slow stages. Run tests/boot_original_row_span_test.gd with TWILIGHT_PATCH523_CONTENT set to the supplied original archive; enable TWILIGHT_SPAN_DISK_TEST=1 only with a new disposable user profile.

Scope of the v1 compatibility check: it covers the verified raw table and its relation indexes, **not every downstream cache after the code update**. The expedition, quest, protection, dungeon, card-slot and option-combat producer keys list the complete definition-rows script; native item templates also include the global code key. The runtime may rebuild separate projections when these inputs change. A real PC Main startup here did enter cold native registration and equipment rules. No digest checks were bypassed and no all-caches-survive or device first-launch claim is made.
