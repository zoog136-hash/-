# Source523 map image caller handoff

The map image adapter is `scripts/maps/source523_map_image_adapter.gd`. It reads the existing private `all331_current_file_identity_and_pixel_anchor_contracts523.json` using the caller's pin from its supplied handoff manifest. Original rows, numeric ID lists, private paths, URLs and pack contents stay outside this document and public Git.

The declared relation is:

`UIMapWorld.LandID` → caller-selected `UIMapWorld.ID` → `UIMapWorld.MapImageInfoID` → `UIMapImageInfo.ID` → `UIMapImageInfo.ImageID` → `AssetView.AssetId` → `AssetType.Path + AssetView.FilePath`.

The current image pack exposes its canonical AssetView/AssetType loader. Its consumer registry covers ItemClass, SpellClass and BuffClass; the map tables are supplied by the separately pinned existing relation document. The adapter sends the exact source Asset ID, AssetType ID and literal path to that existing image loader. It preserves source row references and the contract pin in returned provenance. Historical bitmap evidence in the relation document does not replace current image-pack lookup.

## Configuration and apply API

The existing private input handoff is supplied. For the World connection, the Map222 owner creates one adapter instance and calls `open_contract(private_contract_path, expected_contract_sha256)`. The expected pin comes from that handoff. Failed configuration preserves the previously opened relation index. Image-pack selection remains with the existing source523 image owner.

- `world_candidates(field_map)` returns explicit World candidates for that mobile field's Land. It does not select the first candidate, even when there is only one.
- `resolve_world(world_id)` uses the original World/ImageInfo/AssetView relation and returns the existing image loader's texture, status and provenance.
- `resolve_field_world(field_map, world_id, source_cell = null)` additionally requires the exact original World-to-Land relation.
- `apply_world(existing_view, world_id)` and `apply_field_world(existing_view, field_map, world_id, source_cell = null)` assign that result to a caller-supplied existing TextureRect, Sprite2D or NinePatchRect. They create no node and change no layout, scale, anchors, click handling or selection state.

A selected image pack's missing, zero or excluded asset stays missing or excluded. A valid source relation clears the previous target texture when its loader returns no texture. An invalid/foreign field relation or an unselected image pack does not replace an existing legacy image. Metadata is attached as `source523_map_image`.

## Map222 identity boundary

The accepted mobile-field contract is the explicit boolean metadata marker `current523_source_field == true`, followed by `field_map.definition.source_map_id` in the `Land.ID` namespace. The actual field can be a RefCounted Object model; no scene Node or synthetic wrapper is required. A similarly named property on a legacy or host field is not promoted to this namespace.

The adapter joins that Land ID only to the original `UIMapWorld.LandID` field. It never equates Land ID with World ID, parses a physical folder number, matches a map name, or derives an image path from `Land.AssetPath`. An existing `definition.source_asset_path` string can be retained as field metadata; it is not an image-path alias.

## Map owner registration and private configuration

Map222 owns registration, context, input and movement through
`scripts/maps/current523_world_map_input.gd` at
`d01758db57d46d2b7a57dafbbf6f4880daf8118e`. Its
[public contract](https://github.com/zoog136-hash/-/blob/d01758db57d46d2b7a57dafbbf6f4880daf8118e/docs/SOURCE523_WORLD_MAP_INPUT.md)
and [implementation](https://github.com/zoog136-hash/-/blob/d01758db57d46d2b7a57dafbbf6f4880daf8118e/scripts/maps/current523_world_map_input.gd)
define this connection. Integration269 includes that owner's five-file change at
`b37e5b941d189351906a4a60e411ad1d07566aeb`; its
[integration contract](https://github.com/zoog136-hash/-/blob/b37e5b941d189351906a4a60e411ad1d07566aeb/docs/REST_INTEGRATION_CURRENT523_SOURCE_ONLY.md)
retains UI267 and Image270 as external dependencies. The single owner-level registration contract is
`world.bind_current523_world_map(opened_image_adapter, offered_worlds, options)`
with `user://current523_world_map.cfg` as its startup selection.

At normal World startup, the map owner's deferred registration calls
`configure_from_settings(world)` with the optional private
`user://current523_world_map.cfg`. The `[world_map]` section accepts:

- `enabled`: explicit boolean selection, default `false`.
- `contract_path` and `contract_sha256`: the supplied private relation file and its existing pin.
- `offered_worlds`: a Dictionary keyed by the exact decimal `Land.ID`. Each value supplies an explicit `world_id` in `UIMapWorld.ID`, with an optional actual `label`. Without that label, the exact source World's `Name` is used.
- `coordinate_policy`: the map owner's `OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1` policy by default.
- `ratio_scale`: a positive OWN multiplier, default `1.0`.
- `source_anchor_offset`: an OWN source-cell anchor, default `[0.5, 0.5]`.

Within this same startup path, the map owner creates the existing RefCounted image adapter, calls
`open_contract(contract_path, contract_sha256)`, then registers
`hud.bind_original_world_map(adapter, Callable(self,"context"), Callable(self,"input"))`.
An explicitly supplied adapter enters through
`world.bind_current523_world_map`; `options.contract_sha256` identifies its
already opened relation. Original
UI/image pack selection stays with those packs' existing owners. An old card or
monster pack is not an image dependency.

On each open, the map owner's `context()` supplies the actual field object and
the explicit offer. It checks `world_candidates(field_map)`, the relation pin,
and the exact `UIMapWorld.ID`/`LandID` relation. Opening does not select a World
or display its image. The existing original row controls perform that selection;
zero and missing declarations retain their unavailable state. Absent or disabled
configuration leaves this optional connection unselected.

## Original UI267 field and image boundary

UI267 owns `hud.bind_original_world_map` and the original presenter lifecycle.
Use its
[RefCounted-field correction](https://github.com/zoog136-hash/-/commit/2c970ee1ea5a7a0009b14623447c7103f6633b0b)
with the Map222 owner. The actual field is a `PlayableField` RefCounted Object;
the UI boundary accepts that real Object without a scene Node wrapper.
UI267 retains its original nodes, map entry, buttons, source scroll, pixel
conversion and close handling.

The explicit image role is `UI/Map/Map_Tab_Area.csb`, source SHA
`709e406c6a67199fcec3b998f5ac032ce833ad0ea79e3981327dadea689ffd84`, node44440,
`world_image_display:true`. After explicit selection, UI267 calls the existing
`apply_field_world` adapter for that role and reports intrinsic continuous
image-edge pixels. `UI_Draft/V_talkingisland.png` remains preview artwork; it has
no World-image or fallback role.

The returned `source523_map_image` metadata preserves
`provenance.map_contract_sha256` and the source row references under
`provenance.source_map_relation.world` and `.image_info`. UI267's click payload
retains them in `verified_image_metadata`, alongside `source_world` and
`source_image_info`. The map owner checks that identity before movement.

The map owner's `input()` handles actual presenter events/context and consumes
`hud.original_world_map_image_clicked`. Its
`OWN_EXISTING_WORLD_TAP10PX_PAN_V1` policy uses the existing World tap threshold.
UI267 keeps the native scroll and image-click APIs. The map owner checks the
live field, selected image, gesture/session identity and existing movement
constraints before using the existing pathfinding and manual movement calls.

## OWN coordinates and remaining evidence

The original World/ImageInfo/AssetView relation supplies `Ratio`, `BaseLocX/Y`
and `BasePixelX/Y`. Its native axes, units and projection formula remain
unconfirmed. Map222's `OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1` interprets those
anchors with the current OWN field basis and the explicit configuration above.
Its default multiplier and cell-center offset are TWILIGHT policy, not confirmed
original M rules. Returned coordinate registration identifies that OWN policy;
`native_image_info_formula_confirmed` remains `false`.

The image adapter retains `source_cell` only as supplied integer-cell metadata.
ImageInfo anchors stay attached to their own source row. Coordinate projection
and movement belong to the map owner; the image adapter performs neither.

Integration requires the Map222 owner files, UI267's corrected Object boundary,
this existing image adapter, the original selected UI/image packs and the
consumer-local pinned settings. Offers must remain explicit for each Land;
`CanShowMiniMap` alone supplies no World selection. Native coordinate equivalence
still requires original formula/axes/units evidence. Actual open, selection,
input, movement and save/reentry behavior remain unexecuted and unverified under
the current execution ban; source95% usage and whole-map completion are not
claimed.

The existing `renewal_map.gd` / `field_minimap.gd` overview retains its field-bounds drawing and click path. The original presenter is connected by the map owner's registration above. Image/Map screen artwork keeps its screen role; S32/SEG/TI2 terrain remains with the field owner.

This update changes only this handoff document. It adds no owner implementation,
app execution, rendering, tests, CI, verification run or resource recount.
