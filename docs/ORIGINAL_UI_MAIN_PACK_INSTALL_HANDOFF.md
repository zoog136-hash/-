# Main game original UI pack handoff

This is an installer input contract for the existing private UI loader, not a
second installer. No source assets, old packs or save files are deleted. The
old card/monster packs are not a prerequisite or a fallback for this selection.
Attendance/pass are deferred. No new test, render, game run or CI was executed.

## Retained current checkpoint

The private Library operation succeeded for this exact existing file identity:

- Library ID: `libfile_22ce42630a508191a9e63e18c3712cf0`, returned version **3**.
- File ID: `file_00000000426c8209a8f9b721e843431b`.
- Canonical filename: `TWILIGHT_current523_main_game_fields_original_pack_20261105.zip`.
- ZIP size: **7,480,911 bytes**.
- ZIP SHA256: `795af1d16bcd78ef9ae2ba4280e2a83ac2351dc4b260d570c4ab1c4fe2065e6f`.
- `original_ui.json` SHA256: `7d85f521d0d30460b1a15758f0af85e899104b4ce88af4fb1a34152376b9493c`.
- Corresponding published code: `a515446da50f0aa3c8897d66d33ef04d161675c6`.
- Drive file ID: **not provided**; do not synthesize one from the Library ID.

The ZIP has `original_ui.json`, `receipt.json` and `originals/UI/...` at its
root. An installer may use the relative destination
`source-ui/current523-main-game-fields`; no absolute install location is embedded
in the pack or loader. The loader root is the extracted directory containing
`original_ui.json`, not its `originals` subdirectory. The caller must supply
the manifest pin above separately from the ZIP hash.

Runtime selection uses both of:

```text
--source-ui=<extracted-root>
--source-ui-sha256=7d85f521d0d30460b1a15758f0af85e899104b4ce88af4fb1a34152376b9493c
```

Equivalent environment keys are `TWILIGHT_SOURCE_UI` and
`TWILIGHT_SOURCE_UI_SHA256`. SourceMainSelection.selected_pack() opens this
selection; `renewal_hud.bind_original_main_ui(pack)` accepts an already opened
pack. Missing/incorrect supplied inputs are reported; another asset pack is not
selected as a substitute. No image pack, animation clip or repeat argument is
needed for these static native HUD controls. Item/Spell/Buff image selection
remains the separate PR270 consumer contract.

## Actual packaged scope

There are 20 original files, one EXP entry and seven explicit partial node
scopes: CharInfo HP/MP/status/inventory, its normal-branch level child, PayLayout
gold/diamond icons/text, minimap name, selected-target name/backdrop, AttackPad
attack/auto/target/self and TopMenu All/Inventory/Skill/Store/Quest. Full original
MainScene/HUDScene parent metadata is retained separately. Full parent metadata does not activate their other children.
The exact partial scope lists remain in `receipt.json`/`original_ui.json`.

The builder receipt is dependency-resolved/not-rendered and explicitly sets
`whole_scene_completion_claimed:false`. This package is not all 560 UI roots,
full main UI completion or evidence of actual game consumption. Later optional
node bindings in code need a later pack that actually includes their inputs;
the smaller checkpoints remain independently usable. The prior EXP, vitals and
core archives are preserved locally; this update replaces the same Library
identity instead of creating a competing final asset selection.

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
