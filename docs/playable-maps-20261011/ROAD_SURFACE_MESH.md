# PR84: connected road surfaces (2026-10-11)

Resume branch: `feature/twilight-reference-expansion-20261011`, PR #84.
The remote branch ref and PR head were both read at
`1052bb6f6f9a9969b598a8f7e63d0f7ce58058c2` before this change. Main was read at
`2f5ae1013da5c7281d3020719d8a723a23adb8cc`. No reset, clean, force push or merge.

## Implemented unit

The former renderer stacked four translucent Line2D shoulders for each road.
Junctions repainted the same terrain several times and separate strips met at
bends. `road_surface_mesh.gd` now builds a shared, indexed triangle mesh for each
road material. Coverage is the maximum of the original route footprints, so
junctions do not accumulate opacity. Round endpoints, acute reversals and loop
interiors retain their shape. World-coordinate wear varies the soft road edge.
Only nearby grid cells generate geometry; the shared vertices prevent cracks.
The three existing Aden courtyard surfaces use indexed meshes with their existing
worn-edge material. Their elliptical footprints are intentionally not claimed as
finished town topology; replacing those artificial footprints is a next unit.

All source route positions, widths and opacities come from existing JSON. No map
data, collision, navigation, spawn, portals, character or save code is changed.
Existing shader palettes, texture atlases, scenery streaming and occlusion apply.
No new binary art or third-party commercial resources are added.

## Actual scope from data

25 map IDs, 178 roads: `aden_world`; `oman_01` through `oman_10`;
`domination_summit`; `escaros_01` through `escaros_05`; `albino_01` through
`albino_04`; `faith_01` through `faith_04`. Optional A3 source maps are separate.
The first geometry run produced 6,043–12,511 vertices per map road network.

## Validation and evidence

- Baseline resource gate was verified from Actions run `38133604339`, job
  `114452814268`: 723 committed atlases, 41,442 frames, 233,420,026 bytes passed.
- Local Godot 4.6.3 headless geometry: 321 checks passed, all 178 routes sampled,
  all 25 maps included. This is a geometry check, not project/game rendering.
- `.github/workflows/pr84-world-terrain.yml` validates the actual project on
  Godot 4.7.2: resource SHA checks, import, boot, movement/collision, 24 dungeon
  regions plus Aden, portals, visual mode and UI. It also runs the prior 25-map
  terrain check and courtyard palette restoration.
- Matched baseline/current capture script: two cameras and two zoom levels per
  map, 50 JPGs per revision, with positions and SHA-256 recorded. JPEGs are real
  viewports, not generated concept images. Camera equality is checked.
- The full project suite is an additional inventory with its own `summary.json`.
  Its failures/skips must be reported separately; the diagnostic step alone does
  not gate the targeted road job. A green road job must not be described as all
  project tests passing without reading that summary.
- CI results for this change are pending at creation of this document. Read the
  completed run for the exact commit before claiming runtime validation.

Direct clone/network commands could not complete in this Codex sandbox. Source
files were read using the connected GitHub tools; the local folder is a partial
geometry workspace, not a full restored checkout. Actual whole-project checks
run in GitHub Actions. Existing remote blobs are preserved by a base-tree commit
and a non-forced ref update with an expected head SHA.

## Available resources and missing uploads

Existing authored ground/prop atlases, their manifests, shaders, map data and
renderer code are present in GitHub. The existing reference atlas manifest names
`terrain.png` (4,159,990 bytes, SHA-256
`4a4fe796ec4304c264719d2af4457c76ac87979bc33c557a0c3bdb72d8ac03af`) and `props.png`
(2,166,599 bytes, SHA-256
`edec31e6596f5bc036a0ee4eb5fe94ef7c1ff987dd0e20bfbe7a949d880e8199`). The workflow
checks their bytes against the committed manifest. This change only reuses them.

None of these 17 requested uploads was found in the accessible workspace:
`l1j-rust-main.zip`, `movan-l1j-tw-rust-main.zip`, `L1MapViewer-main.zip`,
`L1JGO-Whale-master.zip`, `l1j-tw-99nets-master.zip`, `L1J-JP_3.63c-master.zip`,
`jp-master.zip`, `L1j-TW-main.zip`, `LineageMSimulator-master.zip`, `PakViewer-main.zip`,
`a1.zip`, `a3.zip`, `a2001.zip`, `a2002.zip`, `a2003.zip`, `immma2004.zip`,
`TWILIGHT_Codex_Upload_Tools_20261011.zip`.
The source/tool archives would be needed for fresh format/license investigations;
the six resource archives for original-payload conversion and verification.
They are not required for this authored-road unit and are not claimed restored.

## Resume after this unit

Read the latest remote head and this unit's CI results first. Next, replace the
artificial circular/elliptical town paving with shapes derived from existing
roads and building footprints, and improve repeated terrain transitions across
the 25 maps. Then improve connected Oman/Faith interior floors and family-specific
Escaros/Albino environment boundaries. Full-world camera sweeps, every-region
AUTO/boss acceptance, Windows/Android device tests and final visual quality are
still outstanding. This unit is not completion of a Lineage M quality world.
