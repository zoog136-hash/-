# Selected SpecialDungeon entrance image

The actual existing source_dungeon_view special family selects an entry whose
`entry.row` is the full original SpecialDungeon row. Its `EntranceAssetID`
directly joins `AssetView.AssetId`; AssetType11 declares UI_Mission and the
literal `Image/Mission/` prefix. This is independent of PartyDungeonTypeID,
CompetitionDungeon.ID, tower/Orim stage IDs and LandTeleport selection.

The image owner exports this read-only provider:

```gdscript
const EntranceImages = preload("res://scripts/ui/source523_dungeon_images.gd")
var image: Dictionary = EntranceImages.describe_special(actual_selected_entry)
```

It requires the existing pinned current523 definition reader, the unique full
SpecialDungeon row identical to the caller's row, the exact source AssetView
type/literal path, declared exclusions and the already selected original image
pack. The common image loader supplies actual unchanged Texture2D pixels and
member size/SHA/dimensions provenance. Success declares
role=SpecialDungeon.EntranceAssetID, route=source523_images,
status=original_linked, the exact special_dungeon_id and original_bytes_unchanged.
Failure retains an explicit source_status and null texture. The descriptor
does not activate a dungeon or change selection, transport, quantity or saves.

The held22 SpecialDungeon rows join14 distinct entrance assets, all declared as
UI_Mission PNGs with original154x262 dimensions and present in the existing
image pack metadata. UIMapImageInfo.ImageID and UIMapSpecialImageInfo.AssetID
have no direct matches to those entrance IDs in this source. No map coordinate,
ImageInfo offset/ratio or unrelated preview picture is inserted into this role.
These are source/metadata findings, not game rendering or execution evidence.

UI286 checkpoint3e4bffa3abcc0693730a381de247c3c7bfdb03b8 supplies the
actual ImageView28700 receiver API and selection/list/visibility/exit notices.
The image-owned adapter now consumes those APIs without editing UI files:

```gdscript
const EntranceBinding = preload("res://scripts/ui/source523_special_entrance_binding.gd")
# UI owner retains this instance and calls only after its legitimate mount.
var entrance_binding = EntranceBinding.new()
var result: Dictionary = entrance_binding.bind(actual_view, registered_player)
# Before replacing that mount, or explicitly tearing it down:
entrance_binding.close()
```

`registered_player` must be the existing source sprite_scene renderer beneath
that live view, configured for the exact Mission_DungeonSpecial_Btn member/SHA
and original external ImageView28700 slot, initially hidden. No renderer or
node is created by this adapter. It re-queries the actual owner after each
selection notification, verifies its pack/manifest/member/node/widget against
the mounted receiver, then passes the existing exact-row provider result to
`set_bound_source_asset_result(28700, image)`. Only a successful assignment is
made visible. Invalid selection, list rebuild, family change, hiding, closing,
failed pixels and either owner's teardown clear the image. Selection signals
are wakeups, never a replacement authority for the selected row. Explicit
close disconnects every callback. No selection, travel, payout or save changes.

The missing mount remains specifically Panel392 to ListView_Daily2560 item
registration. The adapter neither declares that absent source relationship nor
calls itself from the current unmounted view. A live tree descendant alone is
not source-parent proof: `source_parent_registration_established` remains false.
Only a future actual successful receiver call reports `pixels_assigned=true`;
this turn did not invoke the adapter or mount any pixels. UI owns the remaining
source-backed mount and must retain the binding at that point. The selected
pack must contain the exact external ImageView scope (v37 is only a local UI
candidate, not an update to the frozen installed v30).

Source/renderer support is identified and the pixel descriptor is implemented;
screen attachment remains pending the stated receiver. No source pack, phone
selection, resource update/upload, image generation, test, compile, game,
render, CI or merge was performed. This code is unexecuted and unverified.
