# TWILIGHT: L1J external resource staging (Godot 4.7.2)

Baseline main: `edefc7c120b9ad4f8e211c6e36478d4afb73c21d`. Refresh before merge.

## Hard boundaries
- External content is opt-in; native TWILIGHT gameplay is unchanged.
- Do not modify: project.godot, Main.tscn, world.gd, renewal_hud.gd, item catalog, data/maps, map coordinates, saves, item instance IDs, ground drops, skill implementation or CI belonging to other feature PRs.
- PR #59 (original PvE skills) is independent: do not edit its branch.
- Reserved paths: assets/l1j/, data/l1j/, addons/twilight_l1j/.
- Source IDs remain namespaced: ext:a3:weapon:1 and ext:go:weapon:1 never become the same inventory instance merely because numeric IDs match.
- L1J tile-coordinate origins must not be treated as TWILIGHT canvas pixels.

## How to stage the converted asset ZIPs
The converted ZIP parts are user-provided files not stored in this PR; the complete conflict-safe importer is distributed in the accompanying TWILIGHT_L1J_NONCONFLICT_PATCH zip.

1. Use the safe import script in *dry-run* mode to check CRC, traversal, existing-file hashes, duplicate paths.
2. Ensure zero conflicts before running it with --apply on a disposable or feature-branch checkout.
3. Import only under assets/l1j/, data/l1j/, addons/twilight_l1j/; never overwrite existing paths. The S32 source archive is optional for runtime.
4. Run Godot 4.7.2 editor import, game boot, player movement, field/map access, combat/loot and save regression tests before enabling any external dataset in live gameplay.
5. Do not merge a behavior change or release while Godot CI is unverified.

The optional `TwilightExternalRegistry` script is read-only and is not referenced by live game code; missing ZIP packages are safe. This PR does not claim image or map replacement, Godot boot tests, or full item database merge.
