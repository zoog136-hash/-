# PR122 batch17 — six exact-name animation resource reuses

Explicit user decision: **use the same existing animation wherever the name is exactly identical**. No SPX input, new artwork, or copy of source PNG is required. This is an intra-project reference-only change on the PR #122 branch, not main.

| Receiver / independent ID | Existing donor / independent ID | Original `SpriteFrames.tres` resource | Original Git blob | Declared motion tracks |
|---|---|---|---|---|
| `transform:7` 바포메트 | `monster:바포메트` | `original_based/baphomet_project_source/SpriteFrames.tres` | `8acc3d10` | 40 |
| `transform:11` 베레스 | `monster:베레스` | `original_based/beres_project_source/SpriteFrames.tres` | `8acc3d10` | 40 |
| `transform:352` 알비노 뿔 개구리 | `monster:알비노 뿔 개구리` | `original_based/albino_frog/SpriteFrames.tres` | `88eeb996` | 40 |
| `monster:알비노 피쉬맨` | `transform:350` 알비노 피쉬맨 | `expanded/male_chain_chain_coif_longsword/SpriteFrames.tres` | `b9f83091` | 48 |
| `transform:351` 알비노 자이언트 크랩 | `monster:알비노 자이언트 크랩` | `original_based/albino_giant_crab_monster/SpriteFrames.tres` | `912e37c5` | 40 |
| `transform:349` 알비노 악어거북 | `monster:알비노 악어거북` | `original_based/albino_crocodile_turtle_monster/SpriteFrames.tres` | `7e68b30e` | 40 |

The full path in each case starts `res://assets/actors/eight_direction/`. All donors were read from the existing PR122 Git tree, and their 8-way `idle/walk/attack/hit/death` tracks were statically checked (5 × 8 = 40 per resource; 48 for the Fishman donor). The donor references have not been modified or duplicated.

## Implementation

Only the six receiving records in `data/combat_animation_profiles.json` changed. Their `frames_path`, `layout`, rendering scale, offset, tint, embedded-shadow indication, visual animation frame markers and other pose-presentation metadata now reference the existing donor track. The `shared_visual_source` key explicitly records the reused original ID; no name-based runtime heuristics or global family swaps were introduced.

The receiving transformations and monster **remain distinct records** with independent level/stats/skills, HP, AC, hit accuracy, drop rules, movement physics, monster AI, collision and inventory. No catalog or combat DB was rewritten, and no donor sprite image bytes were changed. `scripts/player.gd`, `scripts/monster.gd` and `scripts/world.gd` are unchanged in this batch.

A regression assertion was added to `tests/animation_catalog_test.gd` for the explicit six-pair mapping, donor-name equality, identical SpriteFrames paths and key visual properties, all 40 movement/combat/death tracks per resource, and runtime `TwilightAnimationCatalog.for_record` profile lookup.

## Remaining known limitations (do not silently promote to approved)

- `monster:바포메트` and `monster:베레스` have **byte-identical SpriteFrames resources**, both referring to existing `salah/poses-*.png`. These aliases intentionally inherit this existing limitation; they do not prove two visually distinct original monsters.
- `monster:알비노 피쉬맨` now uses the completed `transform:350` humanoid sprite source, not newly verified fishman-specific anatomy. Reusing it by exact game name is an explicit user preference, not an original-art fidelity claim.
- The existing 14 locomotion/frame-quality improvement targets include `transform:351` and `transform:349`. A donor alias does not synthesize 6–8 native walk frames or distinct run actions. Continue to list them as frame-quality follow-ups until independently verified.
- `transform:7`, `transform:11`, `transform:352` and `monster:알비노 피쉬맨` gain wired original project frames, but no new independent Main visual/attack/loot QA was executed in this batch. Keep 399/498 **previously approved** as the baseline until genuine in-game checks; record these six as **linked, validation pending**.
- This change does not grant new rights over third-party inputs or establish visual fidelity to Lineage M. All six reused Git assets already existed in the project; no new third-party original SPX or APK assets are published.

## CI policy

Commit once to the same open Draft PR122 branch. Automatic CI may run for this single push, but do not manually dispatch the broad suite repeatedly. `tests/animation_catalog_test.gd` is a targeted regression addition; a passing static data check does not replace Godot Main/Android render observations.

Read-only baseline: PR #122 checkpoint prior to this change `f9d3a14739c0c7e0d11e0698801962b3476f30c9`. Historical completed/HOLD/failed evidence stays untouched.
