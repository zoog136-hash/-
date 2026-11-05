# Main game original UI pack handoff

This is an installer input contract for the existing private UI loader, not a
second installer. No source assets, old packs or save files are deleted. The
old card/monster packs are not a prerequisite or a fallback for this selection.
Attendance/pass are deferred. No new test, render, game run or CI was executed.

## Retained current checkpoint

The private Library operation succeeded for this exact existing file identity:

- Library ID: `libfile_22ce42630a508191a9e63e18c3712cf0`, returned version **2**.
- File ID: `file_000000009c248206a5eacc4842d7b70f`.
- Canonical filename: `TWILIGHT_current523_main_game_core_original_pack_20261105.zip`.
- ZIP size: **7,395,106 bytes**.
- ZIP SHA256: `b7e88221b31e94dc9eb7cf9dbd7ffe25fca57f0d096ecbde1bd2ce38ff10eacd`.
- `original_ui.json` SHA256: `d8347b80ea906748a675ea2adbb81986ee7caf63d5cd5c7892b580fdd089cb0a`.
- Corresponding published code: `be42c8fc347319e3768a375b9994e6244082f587`.
- Drive file ID: **not provided**; do not synthesize one from the Library ID.

The ZIP has `original_ui.json`, `receipt.json` and `originals/UI/...` at its
root. An installer may use the relative destination
`source-ui/current523-main-game-core`; no absolute install location is embedded
in the pack or loader. The loader root is the extracted directory containing
`original_ui.json`, not its `originals` subdirectory. The caller must supply
the manifest pin above separately from the ZIP hash.

Runtime selection uses both of:

```text
--source-ui=<extracted-root>
--source-ui-sha256=d8347b80ea906748a675ea2adbb81986ee7caf63d5cd5c7892b580fdd089cb0a
```

Equivalent environment keys are `TWILIGHT_SOURCE_UI` and
`TWILIGHT_SOURCE_UI_SHA256`. SourceMainSelection.selected_pack() opens this
selection; `renewal_hud.bind_original_main_ui(pack)` accepts an already opened
pack. Missing/incorrect supplied inputs are reported; another asset pack is not
selected as a substitute. No image pack, animation clip or repeat argument is
needed for these static native HUD controls. Item/Spell/Buff image selection
remains the separate PR270 consumer contract.

## Actual packaged scope

There are 16 original files, one EXP entry, three explicit partial node scopes
(CharInfo HP/MP/status/inventory, AttackPad attack/auto/target/self, TopMenu
All/Inventory/Skill/Store/Quest), and read-only original MainScene/HUDScene
parent metadata. Full parent metadata does not activate their other children.
The exact partial scope lists remain in `receipt.json`/`original_ui.json`.

The builder receipt is dependency-resolved/not-rendered and explicitly sets
`whole_scene_completion_claimed:false`. This package is not all 560 UI roots,
full main UI completion or evidence of actual game consumption. Later optional
node bindings in code need a later pack that actually includes their inputs;
the smaller checkpoint remains independently usable.

## Map contract still missing

`source_main_map_bindings.gd` reuses PR270's existing `world_candidates` and
`apply_field_world` methods. It does not introduce another map image loader,
coordinate converter or view. An actual display call requires the caller's
explicit selected `UIMapWorld.ID`, existing native Sprite2D/owner and original
image-role declaration. No default World is chosen.

The retained main minimap Project21588 references
`UI/Main/Set_R_Top_MiniMapLayout.csb`, SHA256
`df599c77516838bfd1b22e021b1e761343c8d1e6d649f38ef15bb0ffb5cb351f`.
Image15012 is a literal preview, Image16260 is chrome and Panel16604 is empty
in the source. These do not prove a dynamic World-image role. Size15664,
Point13404 and On/Off12632/12052 are not repurposed as map-open buttons.

Still missing: the actual selected World ID; the original dynamic image node
and display role; the source map-entry button; and Ratio/BaseLocX/BaseLocY/
BasePixelX/BasePixelY axis, units, application formula, image rectangle and
click registration. `request_map()` only exposes the existing HUD map signal;
it is not assigned to an unrelated native control. No map connection or click
registration completion is claimed.
