# Original world runtime checkpoint

Base: PR #81 b1198ad12d5c644bb357694b2d1261fb22a627b7, containing main 1d267e53aaea32038f348065066f7c3e5286415c. Independent branch; no changes to other PR branches and no merge.

Priority: A3 map 4 (mainland), 101–110 and 111 (Tower of Insolence and its summit), 12852–12861 and 12862 (Tower of Domination and its separate summit). The source database does not equate the two summits. Older 112–200 floor IDs and event copies remain separate records.

Stage: converter and chunk runtime components restored; world/UI integration and gameplay validation in progress. Original terrain graphics restored: zero. Diagnostic cells/markers are explicitly not reconstructed original artwork.

Resume from this branch, not a new project. Restore generated pack `TWILIGHT_RECOVERED_MAP_DATA_20261011.zip` to project root when rebuilding. Supplied archives belong in an external directory; run `python3 tools/map_restore/convert_world.py --help` for arguments. Run `python3 tools/map_restore/test_formats.py`, import Godot 4.7.2, then wire and test original-world services. Generated data and final evidence are separate subsequent commits. Do not count untested runtime as playable validation.

Source blockers: attachment a2(1).zip was not materialized; cannot claim it was inspected. Tile.idx/.til terrain artwork absent from the 16 accessible archives audited in PR #81. 376 non-A3 selected grids retain unverified edge rules; 234 records lack known origin. Never activate these using guessed coordinates/rules. Preserve the detailed PR #81 source inventory and archive provenance.
