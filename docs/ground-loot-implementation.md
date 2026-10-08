# Ground loot and pickup implementation

Baseline: `18161dc1ae0b268e660f19e1817983c71e166562` (latest main, combat animation merge).

Monster death keeps the existing loot rolls, experience and gold. Equipment and
potions become persistent world drops. The inventory changes only after a valid
world ID is claimed within 60 world pixels with clear line of sight. Each new or
restored visible drop remains on screen for at least 850 ms before pickup.

## Changed files

- `scripts/world.gd`: thin adapters for drops, AUTO pickup, input cancellation,
  map switching, existing inventory grants and close/suspend saving.
- `scripts/loot/ground_loot_manager.gd`: IDs, quantities, walkable spread,
  per-map records, validation, atomic claims, ten-minute real-time expiry and
  save migration from the original drop format.
- `scripts/loot/ground_loot.gd`: native mouse/touch selection and world-space
  sprite/effect display.
- `scripts/loot/drop_visual.gd`: original procedural beam, glow, particles,
  pulse, dual rays and emerald aura. Existing item image DB is reused;
  missing images use a drawn weapon, bottle or equipment fallback.
- `scripts/loot/loot_pickup_controller.gd`: manual selection/confirmation
  overlay and distinct manual/AUTO pickup states with existing pathfinding.
- `tests/ground_drop_smoke_test.gd`: preserve prior regression coverage with
  the new selection-then-pickup and visible-time requirements.
- `tests/ground_loot_system_test.gd`: expanded engine integration coverage.
- `tests/capture_ground_loot.gd`: actual engine screenshots of seven grades,
  manual selection and AUTO approach, using development-only forced drops.
- `.github/workflows/ground-loot-validate.yml`: engine integration and actual
  OpenGL capture, plus uploaded review evidence.
- Associated Godot-generated UID files and this report.

## Pickup behavior

Manual: select the floor item with mouse/touch; see its name, grade and quantity;
press **줍기** or click/tap the item again. The existing player walks along the
existing world path. The grant occurs only upon arrival. Expiry, map changes,
manual movement and a vanished ID cancel the selection and owned pickup path.

AUTO: the existing combat loop delegates to pickup while loot is pending. New
items from the current kill batch take precedence, followed by distance and
higher grade on a tied distance. The controller retains one target through the
walk, then picks remaining drops before returning control to combat. Scans are
throttled to 250 ms, repaths to 650 ms and path attempts to eight per scan.
Unreachable/stalled IDs receive a 15-second retry cooldown. Status effects pause
stall counting. AUTO OFF immediately cancels the pickup path; native manual
movement retains its existing behavior of turning AUTO off.

## Visuals

| Grade | Floor effect |
| --- | --- |
| 일반 / 고급 | Item image only; no beam or grade glow |
| 희귀 | Blue beam, floor glow, particles and pulse |
| 영웅 | Red beam, floor glow, particles and pulse |
| 전설 | Purple dual beam and extra sparkles |
| 신화 | Gold dual beam and extra sparkles |
| 유일 | Emerald/teal rays, bright core, star particles and outer aura |

The image, shadow and beam stay in the world canvas and therefore follow camera
pan, zoom and viewport stretch. Collection/expiry detaches the complete view
immediately. Low grades do not run an animation process. Drop grades are read
from the same item catalog used by the original probability roll.

## Persistence and compatibility

All unclaimed items from all maps are included in `ground_drops`, with stable ID,
map, quantity, creation/expiry timestamp and ground state. Switching maps only
rebuilds visible views and keeps the records. Expiry uses real time, including
when the app is closed. Restoring skips expired, collected and duplicate IDs;
original `{item_name, position}` snapshots remain supported. Inventory and
remaining floor records are serialized together by the existing save method.
Window close and mobile suspend save before leaving the game.

No changes to `scripts/loot_drop.gd`, the probability table, item DB, maps,
player, monsters, actor motion, pooled combat effects, scenes or existing HUD
files. The central world adapters are intentionally the only shared gameplay
file changed. Unmerged consumable and enchantment branches were not incorporated.

## Validation

- Godot **4.7.2** import and boot succeed.
- Full project regression suite: **36/36 checks**.
- Ground loot integration: **145 assertions** covering actual CharacterBody2D
  manual/AUTO movement, sequence and kill-batch order, stalled/inaccessible
  targets, duplicate/unknown IDs, expiry and stale selection, real save/load,
  map travel and viewport GUI mouse/touch dispatch at 1280×720, 960×540,
  1920×1080 and camera zoom 0.8/1.3.
- Live ranged AUTO flow: real attack/impact, kill, visible floor drops, walk,
  pickup, then attack against the next monster.
- Boss seed **146103** produces three equipment pieces plus one potion using
  the unchanged production rates. Visual grade samples are forced only in
  development capture/tests; production rates are never increased.
- All **24 regions / 5,882 assertions** pass, along with combat timing,
  projectiles, animation, skills, inventory, equipment and input regressions.
- Capture script parses locally. Actual OpenGL capture runs in GitHub CI;
  review images and logs are uploaded by `Ground Loot Validate`.

GitHub PR checks must pass before merging. The branch is based on the current
main rather than an older project archive. The unpublished previous scratch
implementation was unavailable; all results above refer to this recovered,
reimplemented and independently tested change.
