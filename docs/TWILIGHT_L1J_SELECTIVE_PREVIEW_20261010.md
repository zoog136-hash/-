# TWILIGHT 4.7.2 — L1J selective connection (October 10, 2026)

**Feature branch:** `feature/twilight-l1j-additive-import-20261010` / Draft PR #60.
**Base:** `main` @ `edefc7c120b9ad4f8e211c6e36478d4afb73c21d` at creation.
**Related work:** Do not modify skill PR #59 or existing game world, inventory, item instance IDs, save, skill, or map scripts.

## What is actually connected
- Opt-in read-only `TwilightL1JSelectiveBridge` in `addons/twilight_l1j/twilight_selective_bridge.gd`
- Item inventory icon, ground icon, NPC portrait by namespaced source ID
- SpriteFrames by source sprite ID for SPR/SPX
- Map *attribute image preview* only (not a tilemap or gameplay collision)
- Standalone `addons/twilight_l1j/preview/ExternalResourcePreview.tscn` opened via **Run Current Scene (F6)**

All feature switches are **off** at initialization. Missing packs => empty/null return. Never autoloaded, never used by `Main.tscn`.

## Source IDs for optional preview
- `ext:a3:weapon:1`: inventory icon 34
- `ext:go:weapon:1`: ground icon 68
- `ext:go:npc:45020`: portrait ms852
- SPX `19521-0`; SPR `12266-0`
- Map a3 `101` (passability/attributes only)

These are *working technical examples*, not a declaration that the art's identity and gameplay effect have been fully verified.

## Asset ZIPs are separate from PR
Binary packs are not committed to GitHub. Use the separately downloaded:
- `TWILIGHT_L1J_SELECTIVE_PREVIEW_ASSETS_20261010.zip` (32 files, technical preview sample)
- Full original STEP1 and RECOVER packs (19 archives) as needed.

In a disposable checkout of this PR's branch:

```sh
# All writes restricted to assets/l1j/, data/l1j/, addons/twilight_l1j/.
python TWILIGHT_L1J_SAFE_IMPORT_20261010.py /path/to/twilight TWILIGHT_L1J_SELECTIVE_PREVIEW_ASSETS_20261010.zip
python TWILIGHT_L1J_SAFE_IMPORT_20261010.py /path/to/twilight TWILIGHT_L1J_SELECTIVE_PREVIEW_ASSETS_20261010.zip --apply
# Then Godot 4.7.2 editor > open preview scene > F6.
```

For full packs the separate `TWILIGHT_L1J_SELECTIVE_INSTALL_20261010.py` script supports `--groups core,item_icons,portraits,spx,jp_maps,ko,en,extra_images,patch_data,raw_spx,raw_s32,reference`. It first runs dry-run and rejects file content differences. Use `--apply` only after reviewing the report.

**Important:** Importing the 32-file sample *before* full packs is supported. Tested: 31 source-file paths matched byte-identically; 1 preview metadata path is unique; zero conflicts.

## Repeated completeness check
- 13 source ZIPs present, 19 converted/recovered ZIPs inspected, 51,414 unique ZIP paths, 0 same-path overlaps, 0 ZIP CRC errors.
- All 1,700 raw SPX have matching converted SpriteFrames; plus 67 SPR conversions.
- 14,726 sprite frame texture references and 14,161 registry image path references resolved.
- JP map variants: 142 only in JP, 341 differing, 367 identical.
- Remaining unlinked source records: a3 item 320; GO inventory 266; GO ground 531; GO NPC portraits 2,633.
- Original TIL atlas still missing; animation offsets and action relationships not resolved; raw BIN/UML not decoded into gameplay data.
- This is **not** proof of semantic correctness or complete original-source conversion.

## Tests and merge condition
CI `L1J Opt-In Preview Validation`: Godot 4.7.2 project parse, bridge flags and invalid paths, preview scene construction, unmodified game boot in repository *without downloaded asset ZIPs*. CI on commit `9c8092e` passed: https://github.com/zoog136-hash/-/actions/runs/38017308976

Offline fixture tested installation/re-run for 23,942 files (core+SPX+JP maps): no path conflict and all byte-identical on re-run. **Actual preview display of binary assets in Godot has not yet been tested in CI**, as packs are not in the repository.

Do not merge into `main` until remaining original gameplay CI is green and actual selected-source art is visually reviewed.
