extends RefCounted
## Original 523 background selection. The logical Land.ID owns this lookup;
## never use the numeric terrain directory or Land.BackgroundTypeId instead.
## This deliberately does not draw RenderType 11: the EXE uses a floor-derived
## need rectangle, not an unconditional camera background.
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const TABLE := "MapBackgroundView"
const IMAGE_TYPE := 3
const PREFIX := "Image/MapBG/"

static func describe(land_id: int) -> Dictionary:
	if land_id <= 0:
		return _failure("invalid_logical_land", land_id)
	if DEFINITIONS.identity().is_empty() or DEFINITIONS.row_count(TABLE) <= 0:
		return _failure("background_definitions_unavailable", land_id)
	var matches: Array[Dictionary] = DEFINITIONS.related(TABLE, "ID", land_id)
	if matches.is_empty():
		return _failure("background_not_declared", land_id)
	if matches.size() != 1:
		return _failure("background_ambiguous", land_id)
	var row: Dictionary = matches[0]
	if not _positive_int(row.get("RenderType")) or int(row.RenderType) not in [1, 11]:
		return _failure("background_render_type_unsupported", land_id)
	var render_type: int = int(row.RenderType)
	if DEFINITIONS.row("Land", land_id).is_empty():
		return _failure("background_land_unverified", land_id)
	if DEFINITIONS.row("AssetType", IMAGE_TYPE).get("Path") != PREFIX:
		return _failure("background_asset_type_unverified", land_id)
	var sky: Dictionary = _asset(row.get("SkyAssetId"))
	var cloud: Dictionary = _asset(row.get("CloudAssetId")) if render_type == 11 else {}
	if sky.is_empty() or (render_type == 11 and cloud.is_empty()):
		return _failure("background_asset_unverified", land_id)
	return {"ok": true, "land_id": land_id, "render_type": render_type, "sky": sky,
		"cloud": cloud, "draw_type_source": row.get("DrawType"), "draw_ready": false,
		"reason": "background_placement_and_floor_mask_not_validated"}

## Verify and load only the assets for a specific admitted Land. No calls on
## loading or per-frame paths until the compositor is independently validated.
static func resolve_layers(land_id: int) -> Dictionary:
	var binding: Dictionary = describe(land_id)
	if not binding.ok:
		return binding
	for role: String in ["sky", "cloud"]:
		var asset: Dictionary = binding[role]
		if asset.is_empty():
			continue
		var resolved: Dictionary = IMAGES.resolve_asset(int(asset.id), IMAGE_TYPE, str(asset.path))
		if not resolved.get("ok", false) or not resolved.get("texture") is Texture2D:
			return _failure("background_%s_unavailable:%s" % [role, resolved.get("status", "missing_texture")], land_id)
		asset["texture"] = resolved.texture
	return binding

static func _asset(value: Variant) -> Dictionary:
	if not _positive_int(value):
		return {}
	var id: int = int(value)
	var matches: Array[Dictionary] = DEFINITIONS.related("AssetView", "AssetId", id)
	if matches.size() != 1 or matches[0].get("AssetTypeId") != IMAGE_TYPE:
		return {}
	var filename: Variant = matches[0].get("FilePath")
	if not filename is String or filename.is_empty() or filename.get_file() != filename or filename.contains("\\") or not filename.ends_with(".png"):
		return {}
	return {"id": id, "path": PREFIX + filename}

static func _positive_int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) > 0.0 and float(value) <= 2147483647.0

static func _failure(reason: String, land_id: int) -> Dictionary:
	return {"ok": false, "reason": reason, "land_id": land_id, "draw_ready": false}
