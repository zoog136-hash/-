# Original world runtime checkpoint

Base: PR #81 b1198ad12d5c644bb357694b2d1261fb22a627b7, containing main 1d267e53aaea32038f348065066f7c3e5286415c. Independent branch; no changes to other PR branches and no merge.

Priority: A3 map 4 (mainland), 101–110 and 111 (Tower of Insolence and its summit), 12852–12861 and 12862 (Tower of Domination and its separate summit). The source database does not equate the two summits. Older 112–200 floor IDs and event copies remain separate records.

Stage: converter, 1,376 source grids, 1,376 runtime definitions, 13 binary navigation/terrain shards, world/UI integration, and travel/door services are present. Local headless gameplay evidence: 201 assertions passed across 23 priority maps (`original_world_runtime_test.gd`); original terrain graphics restored: zero. Diagnostic cells/markers are explicitly not reconstructed original artwork. This checkpoint still requires latest-main integration, full regressions, rendered captures, and a verified remote commit.

Resume from this branch, not a new project. The raw grids and generated binary packs must be committed with the code; uploaded Git blobs alone are not a delivered branch. Rebuilding additionally uses `TWILIGHT_RECOVERED_MAP_DATA_20261011.zip` and the supplied archives; run `python3 tools/map_restore/convert_world.py --help` for arguments. Run `python3 tools/map_restore/test_formats.py`, `python3 tools/map_restore/validate_world.py`, then Godot 4.7.2 and `tests/original_world_runtime_test.gd` with a temporary user-data directory. Preserve all prior source inventories.

Source blockers: attachment a2(1).zip was not materialized; cannot claim it was inspected. Tile.idx/.til terrain artwork absent from the 16 accessible archives audited in PR #81. 376 non-A3 selected grids retain unverified edge rules; 234 records lack known origin. Never activate these using guessed coordinates/rules. Preserve the detailed PR #81 source inventory and archive provenance.
