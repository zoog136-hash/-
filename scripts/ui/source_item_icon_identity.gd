extends RefCounted
## Source identity is independent of web IDs and physical/blessing save IDs.
## Missing originals stay missing; verified static pixels use the active pack.
const PIXELS = preload("res://scripts/ui/source_item_icon_pixels.gd")
const SCENES = preload("res://scripts/ui/source_item_icon_scene.gd")

static var _index: Dictionary = {}

static func configure(document: Dictionary) -> void:
	PIXELS.configure(document)
	SCENES.configure(document)
	# Replace even with an old/absent index so switching packs cannot leave
	# another version's identity attached to a saved physical item.
	var value: Variant = document.get("source_icon_index", {})
	_index = value.duplicate(true) if value is Dictionary and value.get("schema") == "patch523-item-icon-index-v1" else {}

static func recognized(record: Dictionary) -> bool:
	return record.get("source_snapshot", "") == "patch523" and record.has("source_item_class_id")

static func describe(record: Dictionary, fallback_name: String = "") -> Dictionary:
	var result: Dictionary = {"source_id":str(record.get("sourceId", "")),
		"name":str(record.get("name", fallback_name)), "path":"", "family":"",
		"route":"source_original_unavailable", "status":"original_icon_not_installed",
		"reason":"source_icon_identity_not_installed",
		"item_class_id":int(record.get("source_item_class_id", -1)),
		"source_snapshot":"patch523"}
	var value: Variant = record.get("source_icon_identity", {})
	if value is Dictionary and value.is_empty() and not _index.is_empty():
		# Historical physical instances can lack the new presentation metadata.
		# Resolve their exact stored ItemClass without rewriting their save record.
		var resolved: Dictionary = record.duplicate(true)
		bind(resolved, {"source_icon_index":_index})
		value = resolved.get("source_icon_identity", {})
	if not value is Dictionary or value.is_empty(): return result
	var identity: Dictionary = value
	if identity.get("schema") != "patch523-item-icon-identity-v1" or identity.get("source_snapshot") != "patch523" or int(identity.get("item_class_id", -2)) != result.item_class_id:
		result.reason = "source_icon_identity_mismatch"
		return result
	# Keep the literal CSB path. A static frame or category symbol cannot stand
	# in for its scene player. Ownership stays with the existing source UI player.
	result["source_icon_identity"] = identity.duplicate(true)
	var source_path: String = str(identity.get("file_path", ""))
	var asset_type: int = int(identity.get("asset_type_id", -1))
	if source_path.is_empty():
		result.reason = "source_empty_path"
	elif asset_type == 101:
		result.reason = "source_scene_player_required"
	elif asset_type == 1:
		var pixels: Dictionary = PIXELS.resolve(identity)
		result.reason = pixels.reason
		if pixels.has("texture"):
			result.route = "source_original_pixels"
			result.status = "verified_source_icon"
			result.path = pixels.path
			result["texture"] = pixels.texture
	else:
		result.reason = "source_asset_type_unsupported"
	return result

static func missing_label(info: Dictionary) -> String:
	match str(info.get("reason", "")):
		"source_empty_path": return "경로 없음"
		"source_scene_player_required": return "효과 미연결"
		"source_icon_identity_not_installed", "source_icon_identity_mismatch": return "정체 미확인"
	return "원본 미설치"

static func bind(record: Dictionary, document: Dictionary) -> void:
	# Compact private packs deduplicate Icon/AssetView rows. Reattach only to
	# the already validated ItemClass; save IDs, options and aliases stay intact.
	var index: Dictionary = document.get("source_icon_index", {})
	if index.get("schema") != "patch523-item-icon-index-v1": return
	var item_id: int = int(record.get("source_item_class_id", -1))
	var icons: Dictionary = index.get("items", {})
	if not icons.has(str(item_id)): return
	var icon_id: int = int(icons[str(item_id)])
	var asset: Dictionary = index.get("icons", {}).get(str(icon_id), {})
	if asset.is_empty(): return
	var identity: Dictionary = asset.duplicate(true)
	identity.merge({"schema":"patch523-item-icon-identity-v1", "source_snapshot":"patch523",
		"item_class_id":item_id, "icon_id":icon_id, "pixel_verification":"not_performed"},true)
	record["source_icon_identity"] = identity
