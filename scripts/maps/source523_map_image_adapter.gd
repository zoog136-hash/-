extends RefCounted
## Exact source-map image bridge. It never selects a World or places a node.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const MAX_CONTRACT_BYTES: int = 4 * 1024 * 1024
var _worlds: Dictionary = {}
var _worlds_by_land: Dictionary = {}
var _contract_pin: String = ""

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= 0 and float(value) <= 2147483647

static func _cell_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= -2147483648 and float(value) <= 2147483647

static func _sha(value: String) -> bool:
	if value.length() != 64: return false
	for offset: int in value.length():
		if not value.substr(offset,1) in "0123456789abcdef": return false
	return true

static func _failure(reason: String, provenance: Dictionary = {}) -> Dictionary:
	return {"ok":false,"status":reason,"reason":reason,"texture":null,"provenance":provenance,
		"texture_assigned":false,"actual_game_consumption_observed":false}

static func _row(reference: Variant, table: String) -> Dictionary:
	if not reference is Dictionary or reference.get("table") != table or not _integer(reference.get("row_index_zero")) or not reference.get("raw") is Dictionary:
		return {}
	return reference.raw

func open_contract(path: String, expected_sha256: String) -> Dictionary:
	# The pin comes from the already supplied private handoff, not this file.
	if not _sha(expected_sha256): return _failure("source_map_contract_pin_required")
	var absolute: String = ProjectSettings.globalize_path(path)
	if path.begins_with("res://") or not absolute.is_absolute_path(): return _failure("source_map_private_contract_path_required")
	var file := FileAccess.open(absolute,FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_CONTRACT_BYTES:
		return _failure("source_map_contract_unavailable")
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	if digest.finish().hex_encode() != expected_sha256: return _failure("source_map_contract_pin_mismatch")
	var document: Variant = JSON.parse_string(bytes.get_string_from_utf8().trim_prefix(String.chr(0xfeff)))
	if not document is Dictionary or not document.get("image_infos") is Array:
		return _failure("source_map_contract_rows_required")
	var worlds: Dictionary = {}
	var lands: Dictionary = {}
	for entry: Variant in document.image_infos:
		if not entry is Dictionary or not entry.get("asset") is Dictionary:
			return _failure("source_map_contract_row_unavailable")
		var image: Dictionary = _row(entry.get("image_info"),"UIMapImageInfo")
		var asset: Dictionary = _row(entry.asset.get("source"),"AssetView")
		var type: Dictionary = _row(entry.asset.get("type"),"AssetType")
		if not _integer(image.get("ID")) or not _integer(image.get("ImageID")) or not _integer(asset.get("AssetId")) or not _integer(asset.get("AssetTypeId")) or not _integer(type.get("ID")):
			return _failure("source_map_contract_identity_required")
		if image.ImageID != asset.AssetId or asset.AssetTypeId != type.ID or not type.get("Path") is String or not asset.get("FilePath") is String:
			return _failure("source_map_contract_relation_mismatch")
		var exact_path: String = type.Path + asset.FilePath
		if entry.asset.get("exact_typed_path") != exact_path or not entry.get("owners_by_ImageInfoID") is Array:
			return _failure("source_map_contract_path_mismatch")
		for owner: Variant in entry.owners_by_ImageInfoID:
			if not owner is Dictionary or not owner.get("source") is Dictionary:
				return _failure("source_map_contract_owner_required")
			if owner.source.get("table") != "UIMapWorld": continue
			var world: Dictionary = _row(owner.source,"UIMapWorld")
			if owner.get("field") != "MapImageInfoID" or not _integer(world.get("ID")) or not _integer(world.get("LandID")) or world.get("MapImageInfoID") != image.ID:
				return _failure("source_map_contract_world_relation_mismatch")
			var relation: Dictionary = {"world":owner.source.duplicate(true),"image_info":entry.image_info.duplicate(true),
				"asset_view":entry.asset.source.duplicate(true),"asset_type":entry.asset.type.duplicate(true),"exact_typed_path":exact_path}
			var world_id: int = int(world.ID)
			var land_id: int = int(world.LandID)
			if worlds.has(world_id):
				if worlds[world_id] != relation: return _failure("source_map_contract_world_conflict")
				continue
			worlds[world_id] = relation
			if not lands.has(land_id): lands[land_id] = []
			lands[land_id].append(world_id)
	# Historical bitmap evidence is intentionally not an image loader. The
	# active image pack supplies the current typed asset and original bytes.
	_worlds = worlds
	_worlds_by_land = lands
	_contract_pin = expected_sha256
	return {"ok":true,"status":"source_map_contract_open","rendered":false}

static func _field_context(field_map: Object, source_cell: Variant = null) -> Dictionary:
	# Current mobile fields are RefCounted Object models. Their real metadata
	# and definition are sufficient; a scene Node wrapper is neither required
	# nor a substitute for this source identity.
	if not is_instance_valid(field_map) or not field_map.get_meta("current523_source_field",false) is bool or not field_map.get_meta("current523_source_field",false):
		return _failure("source_map_mobile_field_required")
	var definition: Variant = field_map.get("definition")
	if not definition is Dictionary or not _integer(definition.get("source_map_id")):
		return _failure("source_map_land_namespace_required")
	var context: Dictionary = {"ok":true,"land_id":int(definition.source_map_id),"land_namespace":"Land.ID",
		"image_coordinate_registration":"not_supplied"}
	if definition.get("source_asset_path") is String:
		context["land_asset_path"] = definition.source_asset_path
	if source_cell is Vector2i:
		context["source_cell"] = [source_cell.x,source_cell.y]
	elif source_cell is Array and source_cell.size() == 2 and _cell_integer(source_cell[0]) and _cell_integer(source_cell[1]):
		context["source_cell"] = source_cell.duplicate()
	elif source_cell != null:
		context["source_cell_input"] = "explicit_integer_source_cell_required"
	return context

func world_candidates(field_map: Object) -> Dictionary:
	var context: Dictionary = _field_context(field_map)
	if not context.get("ok",false): return context
	if _contract_pin.is_empty(): return _failure("source_map_contract_not_open")
	var candidates: Array = []
	for world_id: int in _worlds_by_land.get(context.land_id,[]):
		var relation: Dictionary = _worlds[world_id]
		candidates.append({"world_id":world_id,"world_namespace":"UIMapWorld.ID",
			"source_world":relation.world.duplicate(true),"image_info_id":relation.image_info.raw.ID})
	return {"ok":true,"status":"explicit_world_selection_required","field_context":context,
		"candidates":candidates,"provenance":{"map_contract_sha256":_contract_pin},"rendered":false}

func resolve_world(world_id: int) -> Dictionary:
	if _contract_pin.is_empty(): return _failure("source_map_contract_not_open")
	if world_id == 0: return _failure("zero_sentinel")
	if world_id < 0 or not _worlds.has(world_id): return _failure("missing_source_world")
	var relation: Dictionary = _worlds[world_id]
	var image: Dictionary = relation.image_info.raw
	var asset: Dictionary = relation.asset_view.raw
	var result: Dictionary = IMAGES.resolve_asset_value(image.ImageID,int(asset.AssetTypeId),relation.exact_typed_path)
	var provenance: Dictionary = result.get("provenance",{}).duplicate(true)
	provenance["map_contract_sha256"] = _contract_pin
	provenance["source_map_relation"] = relation.duplicate(true)
	result["provenance"] = provenance
	result["source_map_relation"] = "explicit_world_image_asset"
	result["image_info_id"] = image.ID
	result["image_coordinate_registration"] = "not_supplied"
	result["texture_assigned"] = false
	result["actual_game_consumption_observed"] = false
	return result

func resolve_field_world(field_map: Object, world_id: int, source_cell: Variant = null) -> Dictionary:
	var context: Dictionary = _field_context(field_map,source_cell)
	if not context.get("ok",false): return context
	if _contract_pin.is_empty(): return _failure("source_map_contract_not_open")
	if not _worlds.has(world_id): return _failure("zero_sentinel" if world_id == 0 else "missing_source_world")
	if _worlds[world_id].world.raw.LandID != context.land_id:
		return _failure("source_map_world_land_mismatch",{"field_context":context,"map_contract_sha256":_contract_pin})
	var result: Dictionary = resolve_world(world_id)
	result["field_context"] = context
	return result

static func _apply_existing(view: Object, result: Dictionary) -> Dictionary:
	if not is_instance_valid(view) or not (view is TextureRect or view is Sprite2D or view is NinePatchRect):
		return _failure("source_map_existing_image_target_required",result.get("provenance",{}))
	# Invalid/foreign map requests and an unselected image pack never replace
	# a legacy overview. Only an explicit current source relation owns this view.
	if result.get("source_map_relation") != "explicit_world_image_asset" or not IMAGES.selected(): return result
	view.set("texture",result.get("texture") as Texture2D)
	result["texture_assigned"] = true
	var metadata: Dictionary = result.duplicate(true)
	metadata.erase("texture")
	view.set_meta("source523_map_image",metadata)
	return result

func apply_world(view: Object, world_id: int) -> Dictionary:
	return _apply_existing(view,resolve_world(world_id))

func apply_field_world(view: Object, field_map: Object, world_id: int, source_cell: Variant = null) -> Dictionary:
	return _apply_existing(view,resolve_field_world(field_map,world_id,source_cell))
