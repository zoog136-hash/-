# Exact duplicate reads: skills, craft and loot

Audit on main `ccd0b43a`: 88 GDScript files in the three directories, 103
direct file-open/read/hash references across 31 of them, plus ZipReader
and resource loader call sites. Six immediate duplicates unified:

| Path | What stays exact |
| --- | --- |
| `skills/player_skills523.gd` compiled-pack binding | Existing decoded-text SHA-256; parse the exact same string instead of reopening. |
| `crafting/patch523_rules.gd` file load | Existing 128 MiB limit and raw-byte SHA-256. Decode and parse the same checked buffer; separate catalog pin unchanged. |
| `crafting/patch523_enhancement.gd` policy | Provenance SHA covers the same raw bytes interpreted by the policy parser. |
| `crafting/patch523_craft_catalog.gd` input ZIP edition | Compare the same raw archive SHA against full and partial pins once. Archive member and installed-file verification unchanged. |
| `loot/base508_monster_drops.gd` input membership | Raw compressed SHA before decompression; retain 64 MiB decompression bound, add packed-size guard for the previously unbounded read. Optional 508 route, not main 523 acquisition. |
| `loot/source3_drop_extensions.gd` manifest | Existing raw SHA and schema/policy; parse verified buffer. Separate item-links SHA and exact identity contracts remain, legacy fallback route only. |

Excluded: the two old skill atlas readers' `res://assets/external_spx/`
PNG paths are blocked by the existing retired-assets guard; ZIP SHA vs named
member extraction are different operations; installer before/after-write checks
compare different storage states. Other exclusions are position/size checks,
independent catalog and manifest pins, and fail-closed reads across independent
subsystems or lifecycle boundaries. No global path cache or mtime-based trust
is introduced. Native stack skill-material proof callers are untouched; their
repeated binding read can require transaction-scoped proof plumbing.

The focused Godot test verifies actual public loader entry points with UTF-8
Korean/CRLF, wrong pins, matching-SHA invalid contents, preserved live state
and unchanged published Source3/policy data. The Base508 positive fixture uses a
synthetic gzip and the same reader; the original pinned gzip is not present
locally. PC warmed 4,080,008-byte ABBA (checks and decode, without JSON parse)
measured 26.707 ms old vs 27.191 ms one-pass: no speedup established by this
trial. The disk traversal reduction is exact; Android time remains unmeasured.
