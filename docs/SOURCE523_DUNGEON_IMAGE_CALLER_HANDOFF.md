# Original dungeon entrance/popup image roles

The held source declares static image roles that the existing source523 image
loader can consume. These definitions do not provide a current game selection
or UI target on their own.

The current SpecialDungeon selection is now separately traced: its actual
`entry.row.EntranceAssetID` directly selects a type11 original entrance image.
The image provider and its precise remaining UI receiver are documented in
[the SpecialDungeon consumer contract](SOURCE523_SPECIAL_DUNGEON_IMAGE_CONSUMER.md).
It does not depend on either Party/Competition join below.

- `PartyDungeon.PartyDungeonTypeID → PartyDungeonAsset.DungeonType`, then the
  declared `EntranceAssetId` or `PopupAssetId` → actual AssetView type/path.
- `CompetitionDungeon.ID → CompetitionDungeonAsset.CompetitionDungeonId`,
  then the declared entrance/popup role → actual AssetView type/path.

PartyDungeon.ID and PartyDungeonTypeID are distinct. Do not pass the selected
party-dungeon ID directly as DungeonType. The image role is also explicit:
an entrance, popup, cutscene, HUD alarm or HelpBox is not interchangeable.
The read static entrance/popup examples use UI_Mission images. Read cutscene,
HUD alarm and HelpBox examples are source CSBs and are not static fallback art.

Existing Data271 `current523_definition_rows.gd` APIs can read the original
PartyDungeon row and its declared foreign key, then `related` rows of the asset
table. A consuming owner must establish the exact matching row and actual
role; it must not select the first asset or infer a role from an integer/name.
The current `source523_image_assets.resolve_asset_value` already consumes an
explicit original role's AssetID and retains exclusions and pixel provenance.
No new image loader, decoder or source pack is required for that lookup.

The existing caller is
`world.source_dungeon_entries → source_dungeon_runtime.entries →
source_dungeon_view`. It currently supplies tower/orim/special/recharger
stage/row/item IDs. No declared bridge to PartyDungeonTypeID or
CompetitionDungeon.ID was found in those actual models. Its existing ItemList
and buttons are not automatically entrance/popup targets.

The integration/data owner must supply the actual selection's original
foreign-key relation. The UI owner must supply the existing authored target
and the entrance/popup role for that caller. Until then these images remain
unconnected for this screen. Existing recharge-item and Orim-buff image calls
remain unchanged. No new source images, controls, layout, dungeon activation,
tests, execution, rendering, CI or upload were introduced by this handoff.
