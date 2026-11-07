extends RefCounted
## The selected original SpecialDungeon row supplies its entrance image role.
## UI owns the authored receiver; this provider does not create a display node.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const ROLE = "SpecialDungeon.EntranceAssetID"

static func describe_selected_special(owner: Object) -> Dictionary:
	if not is_instance_valid(owner) or not owner.has_method("original_selected_special_entrance"):return _missing("source_special_live_selected_owner_required")
	var script: Variant=owner.get_script()
	if not script is Script or script.resource_path!="res://scripts/dungeons/source_dungeon_view.gd":return _missing("source_special_actual_owner_required")
	var selected: Variant=owner.call("original_selected_special_entrance")
	if not selected is Dictionary or not selected.get("ok",false) or selected.get("role")!=ROLE or not selected.get("actual_selected_entry") is Dictionary:return _missing("source_special_current_selection_unavailable")
	var image: Dictionary=describe_special(selected.actual_selected_entry)
	if image.get("special_dungeon_id")!=selected.get("special_dungeon_id"):return _missing("source_special_current_selection_changed")
	if image.get("ok",false) and image.get("provenance",{}).get("special_dungeon_relation",{}).get("asset_id")!=selected.get("entrance_asset_id"):return _missing("source_special_current_selection_changed")
	image["original_ui_target"]=selected.get("original_ui_target",{}).duplicate(true)
	image["runtime_target_registered"]=false
	image["pixels_assigned"]=false
	image["selected_index"]=selected.get("selected_index")
	return image

static func _missing(reason: String, id: int = 0) -> Dictionary:
	return {"ok":false,"special_dungeon_id":id,"role":ROLE,"route":"source523_images",
		"status":"original_icon_not_installed","source_status":reason,"reason":reason,
		"texture":null,"provenance":{},"original_bytes_unchanged":false,"actual_game_consumption_observed":false}

static func describe_special(entry: Dictionary) -> Dictionary:
	if not IMAGES.selected():return _missing("source523_image_pack_not_selected")
	var row: Variant = entry.get("row")
	if not row is Dictionary or not IMAGES.PACK._integer(row.get("ID")) or int(row.ID)<=0:return _missing("source_special_dungeon_selected_row_required")
	var id: int = int(row.ID)
	var identity: Dictionary = SOURCE.identity()
	if identity.get("kind")!="twilight.current523.original-definitions.v1" or identity.get("source_snapshot")!="patch523" or identity.get("source_sha256")!=SOURCE.SOURCE_SHA or identity.get("source_bytes")!=SOURCE.SOURCE_BYTES:return _missing("source_special_dungeon_original_archive_required",id)
	var original: Dictionary = SOURCE.row("SpecialDungeon",id)
	if original.is_empty() or original!=row:return _missing("source_special_dungeon_original_row_changed",id)
	if not SOURCE.declared_exclusion("SpecialDungeon",original).is_empty():return _missing("source_special_dungeon_declared_exclusion",id)
	var asset_id: Variant = original.get("EntranceAssetID")
	if not IMAGES.PACK._integer(asset_id) or int(asset_id)<=0:return _missing("source_special_dungeon_entrance_asset_required",id)
	var assets: Array[Dictionary] = SOURCE.related("AssetView","AssetId",int(asset_id))
	if assets.size()!=1:return _missing("source_special_dungeon_unique_asset_required",id)
	var asset: Dictionary = assets[0]
	var type: Dictionary = SOURCE.row("AssetType",11)
	if asset.get("AssetTypeId")!=11 or type.get("Name")!="UI_Mission" or type.get("Path")!="Image/Mission/" or not asset.get("FilePath") is String:return _missing("source_special_dungeon_entrance_type_required",id)
	if not SOURCE.declared_exclusion("AssetView",asset).is_empty():return _missing("source_special_dungeon_declared_exclusion",id)
	var path: String = str(type.Path)+str(asset.FilePath)
	var image: Dictionary = IMAGES.resolve_asset_value(asset_id,11,path)
	var texture: Variant = image.get("texture")
	var original_pixels: bool = image.get("ok",false)==true and texture is Texture2D and not texture is AnimatedTexture and image.get("original_bytes_unchanged")==true
	var provenance: Dictionary = image.get("provenance",{}).duplicate(true)
	provenance["special_dungeon_relation"]={"source_table":"SpecialDungeon","source_id":id,"source_field":"EntranceAssetID",
		"asset_id":asset_id,"asset_type_id":11,"declared_path":path,"source_archive":identity.duplicate(true)}
	image["ok"]=original_pixels
	image["special_dungeon_id"]=id
	image["role"]=ROLE
	image["route"]="source523_images"
	image["source_status"]=str(image.get("status",image.get("reason","source_special_dungeon_original_pixels_unavailable")))
	image["status"]="original_linked" if original_pixels else "original_icon_not_installed"
	image["original_bytes_unchanged"]=original_pixels
	image["texture"]=texture if original_pixels else null
	image["provenance"]=provenance
	image["actual_game_consumption_observed"]=false
	return image
