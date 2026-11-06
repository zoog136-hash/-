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

The missing UI-owner receiver is precise: the actual selected special entry's
authored entrance-image Sprite/ImageView member/SHA/node, its original parent
registration/role and selection/lifetime callback. Current source dungeon
controls bind outside-close only; current source_dungeon_view has an ItemList,
text details and service action buttons but no established original entrance
image target. No new TextureRect, arbitrary list-thumbnail assignment, popup
role or entrance layout is created. UI can call this provider when it supplies
that receiver and compare special_dungeon_id with its actual selected row.

Source/renderer support is identified and the pixel descriptor is implemented;
screen attachment remains pending the stated receiver. No source pack, phone
selection, resource update/upload, image generation, test, compile, game,
render, CI or merge was performed. This code is unexecuted and unverified.
