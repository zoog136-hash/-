# Aden city region and live plaza — 2026-10-24

New regional art: **12288×8192**, four individually positioned 6144×4096 PNG exports. Palace and residential layout from the previous batch is retained as authored data, surrounded by separately laid-out north/west homes, outer walls, forests, riverbank and harbor. This is reusable object placement, not a repeated village image or enlarged old PNG. 505 placements include 233 newly distributed forest trees. A new image_gen atlas adds pier, lighthouse, retaining wall and river rocks; source RGBA retained unchanged.

## Deliverables

- [Northwest PNG](../../assets/maps/aden_city_region/compiled/city_0_0_6144x4096.png), [northeast PNG](../../assets/maps/aden_city_region/compiled/city_1_0_6144x4096.png), [southwest PNG](../../assets/maps/aden_city_region/compiled/city_0_1_6144x4096.png), [southeast PNG](../../assets/maps/aden_city_region/compiled/city_1_1_6144x4096.png).
- [Overview](evidence/region-overview.png); actual Main [forest](evidence/forest.png), [harbor](evidence/harbor.png), [north street](evidence/north_street.png).
- Actual production renderer [live plaza](evidence/live_0.png), [east edge](evidence/live_340.png), [west edge](evidence/live_-340.png).

World bounds (66000,14400,12288,8192), source reference origin (11000,2400), reference scale 6, generated artwork 1px/world unit. Prior district is wholly contained: unique authored rectangle **100,663,296 (3.0486%)**, increment **75,497,472**. Remaining unauthored world area **3,201,282,624**. Four map PNGs cover this area once; 384 runtime ground chunks do not add area. This is authored art area, not a claim of fully faithful or playable geography. Existing 144-cell full-world planning inventory remains; cell boundaries and this authored rectangle differ, so no entire planning cell is falsely marked complete.

## Actual game integration

`NativePngRenderer` now loads the bounded generated plaza through its existing single worker, visible/prefetch selection, LRU texture cache and shared memory cap. It supports per-row scale 1 for generated art while original Aden remains scale 6. Three `.l1jpng` payloads are decoded from bytes (two floor pieces, one fountain); the existing export include filter already packages this extension. No giant generated map texture is loaded. A mounted PCK payload test exercises this path; this is not an Android APK/device test.

**Only a small verified plaza is enabled by default**, not the entire first 3072×2048 pilot. Actual new ground coverage is 118,027 nonzero-alpha world pixels (bounding rectangle 720×336); this is distinct from the 100,663,296 authored rectangle. Original collision center (70572,17526), radius 84 and fountain foot are preserved. No new building is activated because its contact footprint and connected navigation have not yet been fully established. The old geometry, portals, spawns and hidden-area rules are unchanged. Floor fades inward over the boundary; the marked difference between old blurry art and new paving remains visible. **This is not completion of the requested first full region or seamless whole-world replacement.**

## Verification

Production Main exercised streamed entry, movement, fountain blocking, 38 portal approaches, camera movement, explicit cache release and return loading; navigation and spawn snapshots unchanged. Live peak texture accounting 9,445,928 bytes, within the existing shared cap; this is not process RAM or FPS. Regional review renderer exercised 384 chunks and 38 portal approaches: 12,582,912 ground bytes plus 10,874,800 foreground bytes. Both captures failures=[]. Regional cameras inspect forest/harbor without opening their navigation. Chunk/composite reconstruction exact; each PNG is SHA256 recorded. Initial live test called an unavailable `collides` helper; corrected to the existing `walkable` query, with the failed log retained. No test criteria were relaxed.

Final focused integration checks and logs are under evidence/integration. No repeated full CI run, main merge or deployment. Linux llvmpipe only; no actual Android device.

## Unfinished work / concrete limits

- Full-world art remains incomplete. There was no image-generation quota/refusal; remaining work is geographic layout and production integration, not a tool-access excuse.
- Large regional output retains broad landmarks but is a **simplified reconstruction**: road endings, wall gaps, garden transitions and shoreline contours still need source comparison. Southern civic building reuses palace art; dedicated landmark replacements remain needed. Do not call these 100 million pixels production-ready.
- Whole first pilot cannot be safely activated yet: building/hedge footprints and existing restricted garden paths need contact review. No uncertain area was opened or closed just to make the artwork traversable.
- The small live patch demonstrates export-compatible streaming and exact fountain grounding; exterior visual blending is still conspicuous. Expanding it should follow verified floor/building boundaries rather than blanket overlaying the original city.
- Library attachment remains blocked by earlier HTTP 401; no authentication bypass attempted. PNGs and source files are delivered through the feature branch in Git.

## Rebuild

`python3 tools/map_restore/compile_aden_modular_pilot.py --base assets/maps/aden_city_region`

`python3 tools/map_restore/build_aden_live_plaza.py`

For inspection, run `tests/capture_aden_city_region.gd` with ADEN_MODULAR_OUTPUT; production test is `tests/aden_live_plaza_test.gd` with ADEN_LIVE_OUTPUT. Use a real display and isolated writable XDG directories.

Focused final results: import, boot, generated PCK loading and spear-captain gameplay passed. The generic headless runner skipped native streaming for lack of rendered flags; rerun directly with the actual PNG pack and renderer passed **29/29** (zero main-thread movement decodes, 46,238,536-byte peak under the 48 MiB mobile-policy cap). This is Linux policy emulation, not Android hardware. Export presets exclude inactive city/district/pilot/style source assets from packages; live plaza `.l1jpng` files remain included. All raw artwork remains committed in Git.
