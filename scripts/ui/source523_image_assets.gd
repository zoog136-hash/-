extends RefCounted
## Explicit, read-only image selection. Separate from actor/card pack settings.
const PACK = preload("res://scripts/resources/source523_image_pack.gd")
const ORIGINAL_UI_ICONS = preload("res://scripts/ui/source523_original_ui_icons.gd")
static var _pack: RefCounted
static var _selected: bool = false
static var _selection_checked: bool = false
static var _error: String = ""

static func configure(root: String, manifest_sha256: String) -> Dictionary:
	_selection_checked = true
	_selected = true
	var result: Dictionary = PACK.open(root,manifest_sha256)
	if not bool(result.get("ok",false)):
		_error = str(result.get("status",result.get("error","source523_image_pack_unavailable")))
		result["previous_pack_preserved"] = _pack != null
		return result
	_pack = result.pack
	_error = ""
	return result

static func clear_selection() -> void:
	_pack = null
	_selected = false
	_selection_checked = true
	_error = ""

static func configure_original_ui(document: Dictionary, root: String, manifest_sha256: String) -> Dictionary:
	# The UI owner supplies the original scene closure and explicit clip/loop
	# bindings. Image selection alone does not authorize inferred playback.
	var scenes: Variant = document.get("source_icon_scenes")
	if not scenes is Dictionary or scenes.get("schema") != "patch523-original-ui-icon-scenes-v1" or not scenes.get("icons") is Dictionary:
		return {"ok":false,"error":"source_scene_bindings_required"}
	var result: Dictionary = ORIGINAL_UI_ICONS.open_pack(root,manifest_sha256)
	if bool(result.get("ok",false)):
		ORIGINAL_UI_ICONS.configure(document)
	return result

static func selection(arguments: PackedStringArray, environment_root: String = "", environment_sha256: String = "") -> Dictionary:
	var root: String = ""
	var sha256: String = ""
	var explicit: bool = false
	var seen: Dictionary = {}
	for argument: String in arguments:
		var key: String = "root" if argument.begins_with("--source523-images=") else "sha256" if argument.begins_with("--source523-images-sha256=") else ""
		if key.is_empty(): continue
		explicit = true
		var value: String = argument.substr(argument.find("=")+1)
		if seen.has(key) and seen[key] != value:
			return {"selected":true,"error":"conflicting_source523_image_selection"}
		seen[key] = value
		if key == "root": root = value
		else: sha256 = value
	if not explicit:
		root = environment_root
		sha256 = environment_sha256
		explicit = not root.is_empty() or not sha256.is_empty()
	if not explicit: return {"selected":false}
	if root.is_empty() or sha256.is_empty(): return {"selected":true,"error":"incomplete_source523_image_selection"}
	return {"selected":true,"root":root,"sha256":sha256}

static func _ensure_selection() -> void:
	if _selection_checked: return
	_selection_checked = true
	var request: Dictionary = selection(OS.get_cmdline_user_args(),OS.get_environment("TWILIGHT_SOURCE523_IMAGES"),OS.get_environment("TWILIGHT_SOURCE523_IMAGES_SHA256"))
	_selected = bool(request.selected)
	if not _selected: return
	if request.has("error"):
		_error = str(request.error)
		return
	configure(str(request.root),str(request.sha256))

static func selected() -> bool:
	_ensure_selection()
	return _selected

static func active() -> RefCounted:
	_ensure_selection()
	return _pack

static func selection_status() -> Dictionary:
	_ensure_selection()
	return {"selected":_selected,"ready":_pack != null,"error":_error}

static func _missing(reason: String) -> Dictionary:
	return {"ok":false,"status":reason,"status_type":reason,"error":reason,"texture":null,"provenance":{}}

static func resolve_consumer(table: String, id: int, field: String) -> Dictionary:
	var reader: RefCounted = active()
	if reader == null: return _missing(_error if not _error.is_empty() else "source523_image_pack_not_selected")
	return reader.resolve_consumer(table,id,field)

static func resolve_asset(asset_id: int, expected_type: int = -1, declared_path: String = "") -> Dictionary:
	var reader: RefCounted = active()
	if reader == null: return _missing(_error if not _error.is_empty() else "source523_image_pack_not_selected")
	return reader.resolve_asset(asset_id,expected_type,declared_path)

static func resolve_asset_value(value: Variant, expected_type: int = -1, declared_path: String = "") -> Dictionary:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) < 0:
		return _missing("source_asset_identity_required")
	return resolve_asset(int(value),expected_type,declared_path)

static func resolve_path(declared_path: String, expected_type: int = -1) -> Dictionary:
	var reader: RefCounted = active()
	if reader == null: return _missing(_error if not _error.is_empty() else "source523_image_pack_not_selected")
	return reader.resolve_path(declared_path,expected_type)

static func item_class_id(record: Dictionary) -> int:
	var value: Variant = record.get("source_item_class_id")
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) <= 0:
		return -1
	return int(value)

static func recognized_item(record: Dictionary) -> bool:
	return record.get("source_snapshot","") == "patch523" and record.get("source_m_native_item") is bool and record.source_m_native_item and item_class_id(record) > 0

static func handles_item(record: Dictionary, ground: bool = false) -> bool:
	return not ground and recognized_item(record) and selected()

static func describe_item(record: Dictionary, fallback_name: String = "") -> Dictionary:
	var info: Dictionary = {"source_id":str(record.get("sourceId","")),"name":str(record.get("name",fallback_name)),
		"source_snapshot":"patch523","item_class_id":item_class_id(record),"family":"","path":"",
		"route":"source523_images","status":"original_icon_not_installed","reason":"source523_item_identity_required",
		"texture":null,"provenance":{},"original_bytes_unchanged":false,"actual_game_consumption_observed":false}
	if not recognized_item(record): return info
	if record.get("source_test_item",false) == true:
		info.reason = "source_test_item_excluded"
		return info
	var reader: RefCounted = active()
	if reader != null:
		var identity: Dictionary = reader.source_consumer_row("ItemClass",info.item_class_id)
		if identity.get("ok",false) and identity.get("row",{}).get("TestItem",false) == true:
			info.reason = "source_test_item_excluded"
			return info
	var result: Dictionary = resolve_consumer("ItemClass",info.item_class_id,"IconID")
	info["source_status"] = str(result.get("status","source523_image_unavailable"))
	info["reason"] = info.source_status
	info["provenance"] = result.get("provenance",{}).duplicate(true)
	info["path"] = str(info.provenance.get("path",""))
	if bool(result.get("ok",false)) and result.get("texture") is Texture2D:
		info.status = "original_linked"
		info.texture = result.texture
		info.original_bytes_unchanged = true
	return info

static func missing_label(info: Dictionary) -> String:
	match str(info.get("reason","")):
		"unsupported_csb": return "효과 미연결"
		"source_test_item_excluded": return "원본 제외"
		"missing_consumer_key", "missing_icon_key", "zero_sentinel": return "정체 미확인"
	return "원본 미설치"

static func bind_metadata(view: TextureRect, info: Dictionary) -> void:
	if info.get("route","") != "source523_images":
		for key: String in ["source523_image","source523_image_provenance","source523_image_status"]:
			if view.has_meta(key): view.remove_meta(key)
		return
	var evidence: Dictionary = info.duplicate(true)
	evidence.erase("texture")
	view.set_meta("source523_image",evidence)
	view.set_meta("source523_image_provenance",info.get("provenance",{}).duplicate(true))
	view.set_meta("source523_image_status",str(info.get("source_status",info.get("reason",""))))
