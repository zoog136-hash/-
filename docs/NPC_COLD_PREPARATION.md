# Bounded NPC first-use preparation

Base: `28de35d0207e3a8ebfb0d03673ba274d3b8110ea` (fresh main).

The loading screen now prepares only `NpcAttack.NpcClassID`,
`NpcAttribute.NpcClassID`, `NpcSpecialResistance.NpcClassID`, and `SpellClass.ID`.
It uses the existing verified definition reader and device-local table/relation
bakes, one table per loading stage on the main thread. No Android GDScript
worker is introduced. Both loading and World cache release retain at most 2 MiB
of packed index payload for those four relations; dictionary overhead is small
and separate. Columns and small packed tables are still released. Existing disk
handles/row offsets remain open, as before. Oversized/fallback indexes stay lazy.

This deliberately moves a fixed amount of first-use work into loading. It is
not a reduction of total cold conversion time, a complete NPC closure prebake,
or proof that the separate Android 8.86 s stall is fixed. `SpellBonus`, `Bonus`,
buff/invoke dependencies and other later distinct-NPC reads can still be cold.
The original converter, table format, cache format and bake keys are unchanged,
so this update does not invalidate every existing definition bake.

## Preserved contracts

- No encounter or NPC is admitted by preparation. Projection, category/Test/dummy
  guards, source ID/Sprite/DescId checks, stats, loot and saves are untouched.
- Source verification precedes every prepared table. No installed/valid source
  means no preparation tasks, preserving existing missing-pack behavior.
- Persistent indexes retain the measured source identity, table format and
  foreign-key cache key plus the existing size/SHA verification. No independent
  cache or derived pack can replace the original archive.
- Reset/source-path changes clear retained indexes. Direct `related_indices`
  reads now also visit the ordinary store/source guard before reusing an index.
- Failed disk conversion remains a failed read and is not repeatedly retried in
  the same source lifetime. Optional preparation failure is logged, and normal
  consumer/admission failure handling remains authoritative.
- No map renderer, sprite worker, card effects, original data or art changed.

## Validation and limits

Godot 4.7.2 Linux, disposable profiles. The synthetic preparation test verifies
complete ordered row equality, independent nested results, persistent restart
reuse, a 2 MiB index ceiling, column release, stale-source and same-size corrupt
index rejection, failed disk publication and source-path invalidation. It is
registered in the core gate. Existing NPC closure/catalog, row lookup, atomic
bake, store-format, used-table and bounded-conversion checks are also run. Final focused run: 9 Godot scripts / 299 checks passed;
4 NPC compiler, 7 current resource-integrity and 14 core-harness Python tests
passed. The broader 432-script core gate is separate and must be reported by
its eventual result, not inferred from these focused checks.

A synthetic run (four 6,000-row tables, **not actual 523 content**) measured
808 ms for unprepared reads, 846 ms preparation plus 1.31 ms prepared reads,
27 ms restart preparation, and 410,328 bytes retained including table handles.
These illustrative Linux timings ran alongside other validation and are not
performance thresholds or Android predictions. Preparation adds that cold cost
to loading; subsequent starts reuse the existing bakes.

Actual patch-523 archive and Android device validation are unavailable on this
executor. No original data was transferred or substituted. Original-dependent
branches of existing tests explicitly report `original: not_installed`; they
are not counted as original-data passes. The owner's independently measured
74161 cold/restart/warm results are motivation, not measurements of this patch.

Current main removed `tools/check_resource_integrity.py` even though AGENTS
still names it. The attempted command therefore fails with missing file. Its
current required workflow replacement is `tools/check_no_legacy_resources.py`
plus `tests/test_no_legacy_resources.py`; run both, without restoring removed
legacy art or claiming original-resource delivery.

## Repeatable actual-original A/B

On a machine already holding the original archive:

```bash
python3 tools/monsters/benchmark_npc_cold.py \
  --godot /path/to/Godot_v4.7.2-stable_linux.x86_64 \
  --source /private/path/to/original-patch523.zip \
  --npc-ids 74161 \
  --output /private/results/npc-cold-ab.json
```

The runner verifies exact SHA-256
`d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832`,
25,031,173 bytes and ZIP CRC. It creates separate disposable A/B profiles and
runs four new processes: unprepared cold disk, unprepared restart, prepared cold
disk, prepared restart. Each reads NpcClass before projection and then measures
40 already-warm repeats. Preparation time and retained memory are separate.
Full projected-record and complete closure hashes must match across all runs.
Only hashes/timings/IDs are emitted; the source archive is read locally. Add
comma-separated eligible NPC IDs to exercise later distinct closures. This
probe isolates the data boundary; full device boot/encounter latency still
requires device testing. No merge or deployment is authorized by this report.
