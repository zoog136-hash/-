# Aden ground continuity — PR84 resume

Resume parent: `28b997830387a18ff278eb7faf8470b14ca355dc`. All prior screenshots,
25 region profiles, assets, map data and private source packs were reused.

The saved Aden viewport showed straight diagonal texture cuts through earth and
grass. Two rotated `fract` projections joined unmatched authored-atlas edges.
Aden now uses continuous mirrored coordinates for both projections. The same two
texture samples and world-space detail scale are retained. Other region samplers
keep their previous behavior. This is authored visual improvement, not restoration
of original Lineage map art or proof of visual parity.

`before/` and `after/` contain unedited Godot 4.7.2 Linux llvmpipe OpenGL frames at
identical positions: village (2416,4112), road (3300,4370), bridge (6180,3000).
The before frames were captured before changing either production file.

Actual Main-scene run: 25 checks passed, including real click movement, manual
motion blocked by the river, cross-river route clearance, canopy fade/recovery,
NPC shop interaction, minimap identity, isolated save/load, Oman portal and return,
streaming bounds and absence of the new sampler in Oman. Existing user saves were
not used. Full prior 25-map and project suites were not repeated.

GPU probe: four horizontal/vertical boundaries in both source projections pass
with adjacent-pixel differences below 0.002 and less than half of the legacy jump.
The initial probe camera ignored rotation, giving three invalid comparisons;
the camera was corrected and the targeted rerun passed. Both logs are preserved.
The coarse 16-pixel strip metric in the Main-scene reports measures natural detail
as well as the boundary; use `continuity/result.json` for the adjacent-pixel result.

`validation-summary.json` records unchanged gameplay/data/atlas SHA-256 hashes.
`screenshots-sha256.json` records actual PNG bytes. No newly generated bitmap or
third-party image is needed for this renderer correction. No Windows/Android
device tests, original tile restoration, main merge or other PR updates occurred.

Next production unit: soften the unnaturally sharp water/bank transition visible
in the bridge capture using the existing water polygons, retaining their physics
and bridge footprints. The existing bank currently meets opaque water abruptly.
