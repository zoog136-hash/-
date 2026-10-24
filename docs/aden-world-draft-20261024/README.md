# Aden full-extent geographic PNG draft — 2026-10-24

**The full geographic raster draft is rendered; the full production map is NOT complete.** This continuous run proceeded through all 216 spatial cells instead of stopping at another small district. Existing PR155 Faith/Escaros/lightning/CI fixes and the live small plaza remain unchanged.

[Whole-world overview](evidence/world-overview.png) · [Panel index and coordinates](../../assets/maps/aden_world_draft/manifest.json) · [Full file audit](../../assets/maps/aden_world_draft/audit.json)

## Exact coverage and delivery

- World rectangle: (11802,2214), 72240×45708 = **3,301,945,920** world pixels at 1px/world unit.
- All **216/216** grid cells accounted for: **120 PNG panels** with actual mapped geography; **96 cells** are outside the original geographic map and intentionally have no PNG.
- Newly painted nontransparent geographic area: **1,471,232,592 pixels**. Original exterior void: **1,830,713,328 pixels**, not counted as newly painted map. No internal transparent holes remain.
- PNG payload: **3,290,945,321 bytes**; largest panel 45,127,388 bytes. Typical panel size 4096×4096, clipped at the outer world bounds. Do not load the entire set as one texture.
- **15,086** object placements plus the previous city art reused once at its registered location. No town image was copied around the world. All material RGB comes from newly generated paintings; no enlarged original PNG RGB is used.
- Remaining unrendered nonvoid grid cells: **0**. Remaining full-map art-fidelity/footprint/occlusion validation: **not complete**. Six camera windows were inspected, not all 120 panels at full scale.

Actual game activation remains the previously verified plaza's **118,027 ground pixels**. This new full-world draft is excluded from export and Godot import. **New production activation in this run: 0.**

## Representative full-resolution PNGs and game captures

| Region | PNG panel | Actual Main review capture |
|---|---|---|
| Snow field | [aden_08_01.png](../../assets/maps/aden_world_draft/panels/aden_08_01.png) | [snow](evidence/snow-game.png) |
| Volcano | [aden_06_02.png](../../assets/maps/aden_world_draft/panels/aden_06_02.png) | [volcano](evidence/volcano-game.png) |
| Eastern forest | [aden_12_04.png](../../assets/maps/aden_world_draft/panels/aden_12_04.png) | [forest](evidence/forest-game.png) |
| Desert | [aden_08_07.png](../../assets/maps/aden_world_draft/panels/aden_08_07.png) | [desert](evidence/desert-game.png) |
| Ruins | [aden_09_04.png](../../assets/maps/aden_world_draft/panels/aden_09_04.png) | [ruins](evidence/ruins-game.png) |
| Riverbank | [aden_07_05.png](../../assets/maps/aden_world_draft/panels/aden_07_05.png) | [river](evidence/river-game.png) |
| Arena / ruined settlement | [aden_08_04.png](../../assets/maps/aden_world_draft/panels/aden_08_04.png) | overview above |

## How the draft was built

`trace_aden_world_geography.py` reads the existing 15728×7987 reference only to infer semantic class IDs and broad biome regions. Its output is geography data, not artwork and not collision data. `compile_aden_world_draft.py` reads those IDs, newly generated source paintings and registered layouts; it never reads original reference RGB.

New image_gen sources supply snow, rock, sand, basalt, lava and marsh materials; oak, snow fir, cliff, cactus, volcanic rock and ruined columns; water sanctuary, timber hut, ruined foundation and stone bridge; and a separate ruined arena. Actual sprite bounds were inspected and downsampled, never upscaled. Raw generated sources are retained in `assets/maps/aden_world_draft/source/`. Existing new grass/soil/water, trees and city assets are reused with their original coordinates and hashes.

The first output check exposed two defects: dark source shadows classified as void, and obvious mirrored snow texture motifs. Exterior-connected geography filling removed the false interior holes; overlapping independently oriented texture patches replaced mirror repeats. Initial intermediate outputs remain outside the repository for diagnosis; the final tracked panels contain the fixes. A separately traced central ruined settlement adds an arena, northern enclosure and individual ruined house positions.

Materials use global coordinate phase and 32px overlap before cropping panels. Different terrain types retain different new art. Automatic decorative placement avoids expanded known movement/portal areas. This does not authorize or alter hidden-area navigation.

## Verification and limits

- **All 120 files:** SHA256, PNG dimensions, exact world-grid ownership and per-file alpha coverage passed. Sum of generated coverage matches the semantic geography mask; 216 cells cover the rectangle exactly; internal void holes = 0.
- **Actual Main:** six known arrival sites (snow/volcano/forest/desert/ruins/river) remained walkable; unchanged navigation, spawn candidates and portal data. Preview loads only a cropped 1280×720 texture (3,686,400 bytes on GPU) from flattened panels. CPU decoding is PC-only review, not a mobile streaming implementation.
- **Final focused integration:** import, boot and existing route-recovery test passed 3/3; route-recovery contains 1,554 checks. No repeated full CI suite was run.
- **Not established:** complete geographic fidelity, every building/bridge/cliff footprint, whole-map navigation consistency with the new art, or production foreground occlusion. PNG foreground is flattened. The original production data was preserved instead of opening or closing uncertain areas.
- Known visual limits: automated terrain classification can confuse roofs/shadows and small water/road details; broad biome boundaries remain conspicuously straight in places; landmark sizes/layouts are approximations; the reused city still has its previously documented simplifications. This is a full-extent draft, **not a finished high-fidelity recreation**.
- Linux llvmpipe only. No Android device measurements or new APK delivery. Export exclusions keep the inactive multi-gigabyte art out of the game package.

## Reproduction and next work

The committed semantic data permits rebuilding without the original PNG:

`python3 tools/map_restore/compile_aden_world_draft.py`

`python3 tools/map_restore/audit_aden_world_draft.py`

The compiler supports resumable output only when its recorded build inputs match. For changed sources, preserve existing outputs and build a fresh draft. Re-tracing geography additionally needs the locally available original PNG at the path recorded in the trace script; it is not redistributed here.

Next work is source-by-source correction of misclassified/straight boundaries and landmark footprints, separating foreground for occlusion, and integrating verified areas through the bounded production stream. Do not activate all flattened panels as a collision-complete map.

Library attachment remains blocked by the earlier HTTP 401 authentication failure; no bypass or retry was attempted. Art is preserved in Git on PR155's feature branch. No main merge or deployment.
