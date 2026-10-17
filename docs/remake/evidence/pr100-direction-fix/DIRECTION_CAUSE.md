# PR #100 north/south correction

The screen coordinate calculation was already correct: Godot has +X right and
+Y down, so the game order is `E, SE, S, SW, W, NW, N, NE`. The imported Flare
source direction labels incorrectly used `W, SW, S, SE, E, NE, N, NW`. In the
actual artwork, source view 2 shows the character's back and source view 6 shows
the face. These should be north and south respectively. Diagonal labels were
affected in the same way; east and west were already correct.

This review supersedes the source-direction assertion in the previous
`docs/remake/REMAKE_CHECKPOINT.md` and `evidence/direction-correction/` evidence.
Those files retain the previous work's history, not the corrected result.

## Independent source evidence

Flare Game assets remain the already delivered, licensed source at
`af6eee6d339ac98011864bfe89da837fe7769c28`. Flare Engine's [Avatar.cpp,
lines 418–425](https://github.com/flareteam/flare-engine/blob/1969baeb89ebf94cf22e2bc2ed4e3d8413714d4f/src/Avatar.cpp#L418)
explicitly assigns screen movement keys to its isometric asset direction:

| Input | Source view |
|---|---:|
| Left | 0 |
| Up + left | 1 |
| Up | 2 |
| Up + right | 3 |
| Right | 4 |
| Down + right | 5 |
| Down | 6 |
| Down + left | 7 |

The code adds a separate offset for orthogonal tilesets after these assignments.
These delivered sprites belong to the isometric source art. Therefore the
correct source order is `W, NW, N, NE, E, SE, S, SW`, and the correct source view
indices for the game order are `[4, 5, 6, 7, 0, 1, 2, 3]`. This agrees with the
decoded skeleton skull/ribcage, minotaur face/back, and the bow/staff/knight
front/back poses in the contact sheets.

## Preserved files and corrected connection

All 36 delivered SpriteFrames resources received only animation-name direction
corrections: old game direction becomes `[0, 7, 6, 5, 4, 3, 2, 1]`. This covers
all 1,864 tracks, including walk, idle, melee/ranged attacks, cast, boss special,
hit and death. All AtlasTexture definitions, frame sequences, speeds, durations
and loop settings are unchanged. The 233 PNG files are byte-for-byte unchanged.
The accompanying 36 provenance files now describe the correct source view order.
The offline converter uses the same correct convention for future imports.

`resource-mapping-audit.json` records old/new TRES SHA-256, preserved texture
blocks, and all unchanged PNG SHA-256 values. Existing independent pixel
fingerprints in `tests/fixtures/skeleton_direction_reference.json` retain the
same hashes under the corrected compass labels. The native expansion regression
expects the corrected source indices.

`reviewed-before.png` is a decode of the original TRES before the correction.
`all-native-idle-1.png` and `all-native-idle-2.png` decode every existing appearance
after the correction in game compass order. `weapon-and-boss-contact.png` shows
actual middle attack/release frames for sword, bow, staff and three boss actions.
These are resource inspection evidence, not a claim of live gameplay testing;
the game execution logs and recordings are reported separately.

## Regression reproduction

Use Godot 4.7.2 from the project root with an isolated user-data directory:

```sh
XDG_DATA_HOME=/tmp/twilight-direction-check godot --headless --path . --script res://tests/eight_direction_animation_test.gd
XDG_DATA_HOME=/tmp/twilight-direction-check godot --headless --path . --script res://tests/native_animation_expansion_test.gd
```

The eight-direction test passed 1,362 assertions, including the independently
reviewed decoded pixel fingerprints, directional walk/idle/attack/hit/death
selection, frame/contact timing, and no horizontal/vertical flip or negative Y
scale. See `eight_direction_animation_test.log`. The native expansion test also
checks newly connected base class appearances against the production player's
class selection; transform and monster records continue to require real database
identity membership. `resource-preservation-result.json` records all 269 PNG and
TRES checksum checks passing.

The native expansion test passed 35,742 assertions with 34 expanded shared
appearances and 7,900 distinct decoded RGBA frames, exercising 126 transform,
149 monster (including boss), and three additional base class bindings. These
are resource regression counts; category coverage totals are reported in the
separate catalog audit. A final isolated run's unique log and actual exit code 0
are recorded in `native_animation_expansion_test-final-clean.log` and its `.json`
execution receipt.
