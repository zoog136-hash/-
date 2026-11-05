# Source523 map image caller handoff

The map image adapter is `scripts/maps/source523_map_image_adapter.gd`. It reads the existing private `all331_current_file_identity_and_pixel_anchor_contracts523.json` using the caller's pin from its supplied handoff manifest. Original rows, numeric ID lists, private paths, URLs and pack contents stay outside this document and public Git.

The declared relation is:

`UIMapWorld.LandID` → caller-selected `UIMapWorld.ID` → `UIMapWorld.MapImageInfoID` → `UIMapImageInfo.ID` → `UIMapImageInfo.ImageID` → `AssetView.AssetId` → `AssetType.Path + AssetView.FilePath`.

The current image pack exposes its canonical AssetView/AssetType loader. Its consumer registry covers ItemClass, SpellClass and BuffClass; the map tables are supplied by the separately pinned existing relation document. The adapter sends the exact source Asset ID, AssetType ID and literal path to that existing image loader. It preserves source row references and the contract pin in returned provenance. Historical bitmap evidence in the relation document does not replace current image-pack lookup.

## Configuration and apply API

The existing private input handoff is supplied. Create one adapter instance and call `open_contract(private_contract_path, expected_contract_sha256)`. The expected pin comes from that handoff. Failed configuration preserves the previously opened relation index. Image-pack selection remains with the existing source523 image owner.

- `world_candidates(field_map)` returns explicit World candidates for that mobile field's Land. It does not select the first candidate, even when there is only one.
- `resolve_world(world_id)` uses the original World/ImageInfo/AssetView relation and returns the existing image loader's texture, status and provenance.
- `resolve_field_world(field_map, world_id, source_cell = null)` additionally requires the exact original World-to-Land relation.
- `apply_world(existing_view, world_id)` and `apply_field_world(existing_view, field_map, world_id, source_cell = null)` assign that result to a caller-supplied existing TextureRect, Sprite2D or NinePatchRect. They create no node and change no layout, scale, anchors, click handling or selection state.

A selected image pack's missing, zero or excluded asset stays missing or excluded. A valid source relation clears the previous target texture when its loader returns no texture. An invalid/foreign field relation or an unselected image pack does not replace an existing legacy image. Metadata is attached as `source523_map_image`.

## Map222 identity boundary

The accepted mobile-field contract is the explicit boolean metadata marker `current523_source_field == true`, followed by `field_map.definition.source_map_id` in the `Land.ID` namespace. A similarly named property on a legacy or host field is not promoted to this namespace.

The adapter joins that Land ID only to the original `UIMapWorld.LandID` field. It never equates Land ID with World ID, parses a physical folder number, matches a map name, or derives an image path from `Land.AssetPath`. An existing `definition.source_asset_path` string can be retained as field metadata; it is not an image-path alias.

## Required caller inputs still missing

The original World/ImageInfo/AssetView relation exists. The remaining integration inputs are:

- The source UI's actual selected `UIMapWorld.ID` for the current caller/context. Land can have multiple World declarations; `CanShowMiniMap` alone does not choose an image or authorize a fallback.
- The caller-owned existing target node and its image-display role. No arbitrary World or target is chosen by this adapter.
- Registration of Map222 source-cell coordinates to the selected ImageInfo location/pixel coordinate system, including axes and the original application of `Ratio`, `BaseLocX/Y` and `BasePixelX/Y`.

`source_cell` is retained only as explicitly supplied integer-cell metadata. ImageInfo anchor values stay attached to their own source row. The adapter computes no image-pixel position from them and performs no source-cell projection.

The existing `renewal_map.gd` / `field_minimap.gd` overview draws and clicks through the current field bounds. That path is not replaced: its source-image selection, image rectangle and coordinate/click registration are not supplied by this handoff. Map222's cell/world projection remains a movement/field contract, not a map-image pixel contract. Image/Map screen artwork does not replace S32/SEG/TI2 terrain.

Only the new adapter and this handoff document are changed. No app execution, rendering, tests, verification run or resource recount is performed for this change.
