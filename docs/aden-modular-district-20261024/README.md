# Aden adjacent district batch — 2026-10-24

Produced a new **6144×4096** registered PNG covering the palace gardens, south streets and east/south residences. This is four times the earlier pilot area, not a repeated village panel. The earlier pilot and PR155 changes are preserved. Existing navigation, portal/spawn coordinates and hidden-area rules are unchanged.

## Outputs

- [Full PNG](../../assets/maps/aden_modular_district_01/compiled/palace_south_district_6144x4096.png)
- Four 3072×2048 panels: `assets/maps/aden_modular_district_01/compiled/district_{x}_{y}_3072x2048.png`.
- Actual Main captures: [south street](evidence/south_street.png), [east residences](evidence/east_residences.png), [garden](evidence/central_garden.png), [plaza](evidence/plaza.png).
- `layout.json`: hand-authored reference coordinates for 97 placements and terrain/road polygons. `world_worklist.json`: 144 clipped planning cells covering the full world, with six reusable terrain families; these are layout work units, not 144 independent image-generation requests or completed cells.

World rectangle (69600,16800,6144,4096), source reference origin (11600,2800), scale 6; new art 1px/world unit. Full world area 3,301,945,920. Unique authored visual area now 25,165,824 (0.7622%), **increment 18,874,368** because the earlier pilot overlaps. Remaining unauthored area 3,276,780,096. Five new map PNG exports (one full plus four panels) describe the same area; do not add their areas. Runtime uses 96 ground chunks and deduplicated foreground objects.

## Art and geometry

Reused existing newly generated paving/grass/water/dirt, palace, fountain, walls, trees and beds. One new image_gen atlas supplies house, merchant house, garden pavilion and bridge. Original generated atlas retained in `source/residential.png`; exact inspected crop rectangles in layout. No old Aden pixels, enlarged original images, automatic terrain classification or A3 data are compilation inputs. New objects are downsampled only. First compilation rejected a pavilion wider than its generated source; reduced it to 600px rather than upscaling.

Buildings are individually anchored from the existing PNG, with broad street and garden topology retained. **This is not pixel-exact rebuilding of every original building**: the southern civic building currently reuses palace art, and the ceremonial enclosure uses a pavilion interpretation. Those landmarks require dedicated art before production acceptance. Fine grass edges, wall joints and exterior district seams remain unfinished. Existing production collision has not been rewritten to match these provisional sprites; individual contact-footprint validation remains needed. Do not claim all residential areas are playable merely because they render.

## Verification and application state

Compiler reconstructs the ground from 96 PNG chunks and the complete PNG from ground + sorted foreground, with exact RGBA equality. Four panels also reassemble exactly. Actual Godot Main capture checks all 38 existing portal approach points, a real plaza walk, unchanged navigation/spawn candidates/portal positions, and chunk count. Residential/garden screenshots are camera inspection, not player traversal into blocked terrain. No repetition of the earlier 51-check pilot suite. Final import/boot results are recorded with evidence.

**Application: opt-in actual-game review renderer only; production replacement remains disabled (0% production coverage).** The new atlas has not been blocked by imagegen limits or refusals. Outstanding production blockers are geometric/art review and joining district edges, not missing generic terrain art. Full-world authoring remains substantial; the 144-cell inventory does not substitute for that work. Actual Android unavailable; Linux llvmpipe screenshots and texture accounting are not device performance results. Peak texture numbers are not whole-process RAM or FPS.

Library transfer remains blocked by earlier HTTP 401 authentication; no retry or bypass. Assets and evidence are committed through PR155's existing feature branch, without main merge or deployment.

## Reproduce

`python3 tools/map_restore/compile_aden_modular_pilot.py --base assets/maps/aden_modular_district_01`

Run Godot with a real display, isolated XDG user/config/cache directories, `--audio-driver Dummy --script res://tests/capture_aden_modular_district.gd`, and `ADEN_MODULAR_OUTPUT` pointing to an evidence directory. Shared compiler defaults retain the original pilot path and filenames; preview renderer's optional asset root leaves the original caller behavior unchanged.

Final results: import and boot 2/2 passed; batch capture failures=[]; 38/38 portal approaches; 96 chunks. Observed texture accounting: 12,582,912 ground bytes + 9,005,600 foreground bytes. Source-checkout PNG loading emits Godot export warnings after import: this preview renderer is not an exported-production asset loading implementation. Production integration must use the project's export-compatible loading path; no APK delivery is claimed. Initial audio-device fallback log retained; final capture uses Dummy audio.
