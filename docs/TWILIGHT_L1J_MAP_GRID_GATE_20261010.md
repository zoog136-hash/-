# L1J map grid adapter — 2026-10-10

PR #61 is the stacked base. This step adds new scripts only; existing
scripts/world.gd, scripts/maps/world_coordinates.gd, game collision, player
movement, auto-hunt, items, skill PR #59, and saves are NOT modified.

## A3 actual attributes
`a3.zip/maps/4.txt` is 2048x1536 with 26 distinct raw values.
`a3.zip/maps/101.txt` is 192x192 with 9 distinct raw values.
The original zero-loss PNG and row-major raw byte conversion is in separate
TWILIGHT_L1J_A3_MAP_ATTRIBUTES_PREVIEW_20261010.zip (not committed).

## Added scripts
`TwilightL1JMapAttributes` checks explicit grid dimensions against exact
byte length before returning original raw values. It intentionally has NO
`is_walkable()` function because the meaning of bit flags is unresolved.

`TwilightL1JTileCoordinates` requires explicitly selected map origin and
invertible Transform2D; no mapping before configure. Test calibration 32x32
and skewed rotation are synthetic, not verified Aden coordinates.

## Validation
GitHub Actions 4.7.2 test creates synthetic 4x3 grid values 0..11 and checks
bounds, rejected invalid shape, inverse affine projection and unconfigured
guards. The test does not establish actual map collision, accessible world
movement or authentic Oasis/Tower of Insolence placement.

DO NOT attach attribute maps to live collision or teleports until world origin,
tile bit meaning, pixel scale and region portals are verified in engine.
