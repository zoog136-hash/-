extends RefCounted
## Texture binding for existing source UI nodes. The caller retains the original
## hierarchy, geometry, clipping, color/blend tracks, input and service actions.
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")

static func _missing(reason: String) -> Dictionary:
	return {"handled":true,"ok":false,"status":reason,"texture":null,"provenance":{},"actual_game_consumption_observed":false}

static func resolve(reference: Dictionary) -> Dictionary:
	if not IMAGES.selected(): return {"handled":false}
	var asset: Variant = reference.get("AssetView")
	var type_row: Variant = reference.get("AssetType")
	var declared: Variant = reference.get("declared_path")
	var id: Variant = reference.get("asset_id")
	if not asset is Dictionary or not type_row is Dictionary or not declared is String:
		return _missing("source_ui_asset_reference_required")
	if not (id is int or id is float) or not is_finite(float(id)) or float(id) != floor(float(id)) or float(id) < 0:
		return _missing("source_asset_identity_required")
	var type_id: Variant = type_row.get("ID")
	if not (type_id is int or type_id is float) or not is_finite(float(type_id)) or float(type_id) != floor(float(type_id)):
		return _missing("source_asset_type_required")
	if asset.get("AssetId") != id or asset.get("AssetTypeId") != type_id or not type_row.get("Path") is String or not asset.get("FilePath") is String:
		return _missing("source_ui_asset_identity_mismatch")
	if declared != str(type_row.Path) + str(asset.FilePath): return _missing("source_ui_declared_path_mismatch")
	var result: Dictionary = IMAGES.resolve_asset_value(id,int(type_id),str(declared))
	result["handled"] = true
	return result

static func apply(view: CanvasItem, reference: Dictionary) -> Dictionary:
	var result: Dictionary = resolve(reference)
	if not result.handled: return result
	if not (view is TextureRect or view is Sprite2D or view is NinePatchRect):
		return _missing("source_ui_image_node_required")
	view.set("texture",result.get("texture"))
	var evidence: Dictionary = result.duplicate(true)
	evidence.erase("texture")
	view.set_meta("source523_original_asset",evidence)
	return result
