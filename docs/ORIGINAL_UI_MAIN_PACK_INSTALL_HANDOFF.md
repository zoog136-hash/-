# Main game original UI pack handoff

This is an installer input contract for the existing private UI loader, not a
second installer. No source assets, old packs or save files are deleted. The
old card/monster packs are not a prerequisite or a fallback for this selection.
Attendance/pass are deferred. No new test, render, game run or CI was executed.

## Retained current checkpoint

The private Library operation succeeded for this exact existing file identity:

- Library ID: `libfile_22ce42630a508191a9e63e18c3712cf0`, returned version **5**.
- File ID: `file_000000008cf08211a010077f16a1475b`.
- Canonical filename: `TWILIGHT_current523_main_game_world_map_original_pack_20261105.zip`.
- ZIP size: **9,038,622 bytes**.
- ZIP SHA256: `0881022f018f52910ec658ca743c97c54e4694a51a21f1ab97344f58e88d26fc`.
- `original_ui.json` SHA256: `b85f32b8662bb9b79a3cf9200d95efb96369b1d65d974e23fa7ce10d14b0131c`.
- Corresponding published code: `f399eb1e862becb6187789ae2211fe9ca68816c7`.
- Canonical installer Drive file ID: `1JtVbeBUvq_IZpxAP1lBVOJZrKoT1JUko`.
- The parent confirmed this official private handoff and its same size/ZIP SHA/
  manifest pin for installer275. No further upload is performed. The existing
  Library identity and earlier private copies are preserved; no source or
  save deletion is authorized by this handoff.

The ZIP has `original_ui.json`, `receipt.json` and `originals/UI/...` at its
root. An installer may use the relative destination
`source-ui/current523-main-game-world-map`; no absolute install location is embedded
in the pack or loader. The loader root is the extracted directory containing
`original_ui.json`, not its `originals` subdirectory. The caller must supply
the manifest pin above separately from the ZIP hash.

Runtime selection uses both of:

```text
--source-ui=<extracted-root>
--source-ui-sha256=b85f32b8662bb9b79a3cf9200d95efb96369b1d65d974e23fa7ce10d14b0131c
```

Equivalent environment keys are `TWILIGHT_SOURCE_UI` and
`TWILIGHT_SOURCE_UI_SHA256`. `source_main_selection.gd` static `selected_pack()` opens this
selection; `renewal_hud.bind_original_main_ui(pack)` accepts an already opened
pack. Missing/incorrect supplied inputs are reported; another asset pack is not
selected as a substitute. No image pack, animation clip or repeat argument is
needed for these static native HUD controls. Item/Spell/Buff image selection
remains the separate PR270 consumer contract.

## Actual packaged scope

There are 27 original files, one EXP entry and eleven explicit partial node
scopes: CharInfo HP/MP/status/inventory, its normal-branch level child, PayLayout
gold/diamond icons/text, minimap name, selected-target name/backdrop, AttackPad
attack/auto/target/self/selected-pickup and TopMenu All/Inventory/Skill/Store/Quest;
and original MapScene/Map_All/Area/map-list-row scopes. Full original
MainScene/HUDScene parent metadata is retained separately. Full parent metadata does not activate their other children.
The exact partial scope lists remain in `receipt.json`/`original_ui.json`.

The builder receipt is STATIC_DEPENDENCIES_RESOLVED_REQUIRES_IMAGE_OWNER and explicitly sets
`whole_scene_completion_claimed:false`. This package is not all 560 UI roots,
full main UI completion or evidence of actual game consumption. Later optional
node bindings in code need a later pack that actually includes their inputs;
smaller checkpoints preserve their corresponding fields. In particular, older
combat scopes without authored sibling icons are rejected for that component
before prior controls are hidden. The prior EXP, vitals, core, fields and pickup
archives are preserved locally; this update replaces the same Library
identity instead of creating a competing final asset selection.

## Original map selection and image inputs

The current pack includes the actual MapScene/Map_All/Map_Tab_Area/map-list-row
originals and authored scopes, separate from the minimap name. Its only external
texture slot is `UI/Map/Map_Tab_Area.csb:44440`: the original CSB/editor reference
is retained, but no draft preview is shown or required as a runtime image.
The existing PR270 image owner must supply the actual selected World texture.
This is an additional input for map-image use, not an old card/monster pack.

The actual game entry is `hud.bind_original_world_map(image_adapter,
context_provider,input_handler)`. The existing map signal/hotkey/toggle then
opens the original map presentation. The caller supplies the exact offered
UIMapWorld.ID, original label, role declaration and existing input controller;
open never selects a first candidate. Native source buttons perform selection.

[World map caller ABI](ORIGINAL_UI_WORLD_MAP_CALLER_ABI.md) contains the exact
component hashes, image node, selection/input APIs, actual viewport-to-texture
pixel registration and unchanged ImageInfo handoff. Its raw pixel conversion
does not supply Ratio/BaseLoc/BasePixel cell-axis/formula or movement rules.
No native minimap preview or Size/Point/On/Off button is repurposed.

The UI pack alone is sufficient for these static HUD/source map controls, but
it is not proof that the separate image-owner pack, source relation document,
caller registration or cell conversion are installed. These inputs remain
explicit; missing originals are not replaced or claimed as game consumption.

## Separate normal4 inventory candidate (private delivery succeeded)

This new candidate is separate from the canonical v5 selection above. Its
successful private Drive upload and metadata readback do not change the
installer's selected v5 input or prove consumer installation/game execution.

- Drive file ID: `1RIdxVtVA3q9cWsrr3FWq8Kea6_ceNeTV`.
- Filename: `TWILIGHT_current523_main_game_inventory_candidate_original_pack_20261105.zip`.
- ZIP size: **11,935,660 bytes**.
- ZIP SHA256: `40abf0125a370a12e1ebe24638c504e98b683711cec051c5184174711fef99fb`.
- `original_ui.json` pin: `4f5bffdd6ad96917ac8795f3313e4da0ace4a59821f9439783a410509931e4c1`.
- Corresponding code: `e091ef68bc95644e0941598fff5d88b3b1ad8e42`.
- Scope: 33 originals / 16 scene trees / 15 partial scopes; normal four-slot
  inventory plus the retained main/map subset. Later expanded8/weight/quickslot
  code is not activated by this candidate's smaller source scopes.

Root entries remain `original_ui.json`, `receipt.json`, `originals/UI/...`.
The separate relative destination is
`source-ui/current523-main-game-inventory-candidate`; select the extracted
root and this candidate's manifest pin through the same CLI/environment keys.
Area44440 and Common_Slot15012 still require their existing PR270 image owner.
No old card/monster pack is required. The Drive metadata returned the exact
filename/size and owner-user permission; no permission was changed. A consumer
has not yet confirmed materialization. No new test/render/CI was performed.
