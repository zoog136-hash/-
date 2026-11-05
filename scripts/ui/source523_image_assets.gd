extends RefCounted
## Explicit, read-only image selection. Separate from actor/card pack settings.
const PACK = preload("res://scripts/resources/source523_image_pack.gd")
const ORIGINAL_UI_ICONS = preload("res://scripts/ui/source523_original_ui_icons.gd")
const ORIGINAL_UI_SELECTION_SCHEMA = "source523-original-ui-icon-selection-v1"
const ORIGINAL_UI_SELECTION_MAX_BYTES: int = 2 * 1024 * 1024
static var _pack: RefCounted
static var _selected: bool = false
static var _selection_checked: bool = false
static var _error: String = ""
static var _original_ui_selection_checked: bool = false
static var _original_ui_selected: bool = false
static var _original_ui_selection_error: String = ""
static var _original_ui_selection_registered: bool = false
static var _original_ui_selection_pin: String = ""
static var _original_ui_estimate_missing_repeat: bool = false
static var _original_ui_selection_bindings: Dictionary = {}
static var _original_ui_revision: int = 0

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
		_original_ui_manual_override(document,true)
	return result

static func register_original_ui(document: Dictionary, root: String, manifest_sha256: String) -> Dictionary:
	# Explicit registration can retain multiple independently pinned original
	# subsets. Each icon still selects only the manifest named by its caller.
	var contract: Dictionary = ORIGINAL_UI_ICONS.registration_contract(document)
	if not contract.get("ok",false): return contract
	var opened: Dictionary = ORIGINAL_UI_ICONS.open_pack(root,manifest_sha256)
	if not opened.get("ok",false): return opened
	var registered: Dictionary = ORIGINAL_UI_ICONS.register(document)
	if not registered.get("ok",false): return registered
	_original_ui_manual_override(document,false)
	return opened # pack/registration readiness is not rendered/gameplay use

static func _original_ui_manual_override(document: Dictionary, replace: bool) -> void:
	# Manual calls remain explicit. They never inherit a file selection's
	# estimated host policy merely because another subset was registered.
	if replace:
		_original_ui_selection_bindings.clear()
	else:
		for icon: Variant in document.get("source_icon_scenes",{}).get("icons",{}):
			_original_ui_selection_bindings.erase(icon)
	_original_ui_selection_error = ""
	_original_ui_revision += 1
	if _original_ui_selection_bindings.is_empty():
		_original_ui_selection_registered = false
		_original_ui_selected = false
		_original_ui_selection_pin = ""
		_original_ui_estimate_missing_repeat = false

static func _original_ui_unavailable(reason: String, details: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok":false,"status":"unavailable","error":reason,"inspection_only":false}
	if not details.is_empty(): result["details"] = details.duplicate(true)
	return result

static func _original_ui_selection_failure(reason: String, details: Dictionary = {}) -> Dictionary:
	_original_ui_selection_checked = true
	_original_ui_selected = true
	_original_ui_selection_error = reason
	var result: Dictionary = _original_ui_unavailable(reason,details)
	result["previous_selection_preserved"] = true
	return result

static func _original_ui_sha256(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for offset: int in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(offset,1)): return false
	return true

static func original_ui_selection(arguments: PackedStringArray, environment_path: String = "", environment_sha256: String = "") -> Dictionary:
	var requested_path: String = ""
	var requested_pin: String = ""
	var cli_selected: bool = false
	var seen: Dictionary = {}
	for argument: String in arguments:
		var key: String = "path" if argument.begins_with("--source523-ui-icons=") else "sha256" if argument.begins_with("--source523-ui-icons-sha256=") else ""
		if key.is_empty(): continue
		cli_selected = true
		var value: String = argument.substr(argument.find("=")+1)
		if seen.has(key) and seen[key] != value:
			return {"selected":true,"error":"conflicting_source523_ui_icon_selection"}
		seen[key] = value
		if key == "path": requested_path = value
		else: requested_pin = value
	var environment_selected: bool = not environment_path.is_empty() or not environment_sha256.is_empty()
	if cli_selected and (requested_path.is_empty() or requested_pin.is_empty()):
		return {"selected":true,"error":"incomplete_source523_ui_icon_selection"}
	if environment_selected and (environment_path.is_empty() or environment_sha256.is_empty()):
		return {"selected":true,"error":"incomplete_source523_ui_icon_selection"}
	if cli_selected and environment_selected and (requested_path != environment_path or requested_pin != environment_sha256):
		return {"selected":true,"error":"conflicting_source523_ui_icon_selection"}
	if not cli_selected and not environment_selected: return {"selected":false}
	if not cli_selected:
		requested_path = environment_path
		requested_pin = environment_sha256
	return {"selected":true,"path":requested_path,"sha256":requested_pin}

static func configure_original_ui_selection(path: String, pin: String) -> Dictionary:
	_original_ui_selection_checked = true
	_original_ui_selected = true
	if path.is_empty() or not _original_ui_sha256(pin):
		return _original_ui_selection_failure("source_scene_selection_pin_required")
	var absolute: String = ProjectSettings.globalize_path(path)
	if not absolute.is_absolute_path():
		return _original_ui_selection_failure("source_scene_selection_path_required")
	var file := FileAccess.open(absolute,FileAccess.READ)
	if file == null:
		return _original_ui_selection_failure("source_scene_selection_file_unavailable")
	var byte_count: int = file.get_length()
	if byte_count <= 0 or byte_count > ORIGINAL_UI_SELECTION_MAX_BYTES:
		file.close()
		return _original_ui_selection_failure("source_scene_selection_size_invalid")
	var bytes: PackedByteArray = file.get_buffer(byte_count)
	var unchanged_length: bool = file.get_length() == byte_count
	file.close()
	if bytes.size() != byte_count or not unchanged_length:
		return _original_ui_selection_failure("source_scene_selection_bytes_changed")
	var hash := HashingContext.new()
	if hash.start(HashingContext.HASH_SHA256) != OK:
		return _original_ui_selection_failure("source_scene_selection_hash_unavailable")
	hash.update(bytes)
	if hash.finish().hex_encode() != pin:
		return _original_ui_selection_failure("source_scene_selection_sha_mismatch")
	var text: String = bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return _original_ui_selection_failure("source_scene_selection_utf8_invalid")
	var selection_document: Variant = JSON.parse_string(text.trim_prefix(String.chr(0xfeff)))
	if not selection_document is Dictionary or selection_document.get("schema") != ORIGINAL_UI_SELECTION_SCHEMA:
		return _original_ui_selection_failure("source_scene_selection_schema_invalid")
	var estimate: Variant = selection_document.get("estimate_missing_repeat",false)
	if not estimate is bool:
		return _original_ui_selection_failure("source_scene_selection_estimate_policy_invalid")
	var requests: Variant = selection_document.get("packs")
	var document: Variant = selection_document.get("document")
	if not requests is Array or requests.is_empty() or not document is Dictionary:
		return _original_ui_selection_failure("source_scene_selection_inputs_required")
	var contract: Dictionary = ORIGINAL_UI_ICONS.registration_contract(document)
	if not contract.get("ok",false):
		return _original_ui_selection_failure(str(contract.get("error","source_scene_bindings_unavailable")),contract)
	var icons: Variant = document.get("source_icon_scenes",{}).get("icons")
	if not icons is Dictionary or icons.is_empty():
		return _original_ui_selection_failure("source_scene_bindings_unavailable")
	var prepared: Array = []
	var prepared_pins: Dictionary = {}
	for request: Variant in requests:
		if not request is Dictionary or not request.get("root") is String or request.root.is_empty() or not _original_ui_sha256(request.get("manifest_sha256")):
			return _original_ui_selection_failure("source_scene_pack_selection_invalid")
		var manifest_pin: String = request.manifest_sha256
		if prepared_pins.has(manifest_pin):
			return _original_ui_selection_failure("duplicate_source_scene_pack_selection")
		var pack_root: String = request.root
		# A relative root is an explicit path relative to this config file,
		# never a directory search or a guessed original-resource location.
		if pack_root.begins_with("res://") or pack_root.begins_with("user://"):
			pack_root = ProjectSettings.globalize_path(pack_root)
		elif not pack_root.is_absolute_path():
			pack_root = absolute.get_base_dir().path_join(pack_root)
		pack_root = pack_root.simplify_path()
		var candidate: Dictionary = ORIGINAL_UI_ICONS.prepare_pack(pack_root,manifest_pin)
		if not candidate.get("ok",false):
			return _original_ui_selection_failure(str(candidate.get("error","source_scene_pack_unavailable")),candidate)
		prepared.append(candidate)
		prepared_pins[manifest_pin] = true
	for icon: Variant in icons:
		var spec: Variant = icons[icon]
		if not spec is Dictionary or not prepared_pins.has(spec.get("reviewed_current523_manifest_sha256")):
			return _original_ui_selection_failure("source_scene_binding_pack_selection_missing")
	var committed: Dictionary = ORIGINAL_UI_ICONS.commit_selection(prepared,document)
	if not committed.get("ok",false):
		return _original_ui_selection_failure(str(committed.get("error","source_scene_selection_unavailable")),committed)
	_original_ui_selection_error = ""
	_original_ui_selection_registered = true
	_original_ui_selection_pin = pin
	_original_ui_estimate_missing_repeat = estimate
	_original_ui_selection_bindings = icons.duplicate(true)
	_original_ui_revision += 1
	return {"ok":true,"status":"source_scene_selection_registered","manifest_sha256":pin,
		"pack_count":prepared.size(),"icon_count":icons.size(),"estimate_missing_repeat":estimate,"rendered":false}

static func _ensure_original_ui_selection() -> void:
	if _original_ui_selection_checked: return
	_original_ui_selection_checked = true
	var request: Dictionary = original_ui_selection(OS.get_cmdline_user_args(),OS.get_environment("TWILIGHT_SOURCE523_UI_ICONS"),OS.get_environment("TWILIGHT_SOURCE523_UI_ICONS_SHA256"))
	if not request.get("selected",false): return # keep explicit manual registration
	_original_ui_selected = true
	if request.has("error"):
		_original_ui_selection_error = str(request.error)
		return
	configure_original_ui_selection(str(request.path),str(request.sha256))

static func original_ui_selection_status() -> Dictionary:
	# Status does not open a selection file. Original CSB requests are the
	# only automatic entry point for the lazy private metadata read.
	return {"selected":_original_ui_selected,"selection_checked":_original_ui_selection_checked,
		"registered":_original_ui_selection_registered,"error":_original_ui_selection_error,
		"manifest_sha256":_original_ui_selection_pin,"estimate_missing_repeat":_original_ui_estimate_missing_repeat,
		"registered_pack_count":ORIGINAL_UI_ICONS.packs_by_manifest.size(),
		"registered_icon_count":ORIGINAL_UI_ICONS.bindings.size(),"rendered":false}

static func original_ui_revision() -> int:
	return _original_ui_revision

static func attach_original_icon(view: TextureRect, info: Dictionary, bindings: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if info.get("route") != "source523_images" or info.get("source_snapshot") != "patch523" or info.get("reason") != "unsupported_csb":
		return _original_ui_unavailable("source_scene_identity_mismatch")
	_ensure_original_ui_selection()
	if not _original_ui_selection_error.is_empty():
		ORIGINAL_UI_ICONS.detach(view)
		return _original_ui_unavailable(_original_ui_selection_error)
	var caller_context: Dictionary = context.duplicate(true)
	var provenance: Variant = info.get("provenance")
	if provenance is Dictionary and PACK._integer(provenance.get("icon_id")):
		var icon_key: String = str(int(provenance.icon_id))
		if _original_ui_selection_bindings.has(icon_key):
			caller_context["allow_estimated_single_pass"] = _original_ui_estimate_missing_repeat
	return ORIGINAL_UI_ICONS.attach(view,info,bindings,caller_context)

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

static func _item_presentation_info(id: int, title: String, source_id: String = "") -> Dictionary:
	return {"source_id":source_id,"name":title,
		"source_snapshot":"patch523","item_class_id":id,"family":"","path":"",
		"route":"source523_images","status":"original_icon_not_installed","reason":"source523_item_identity_required",
		"texture":null,"provenance":{},"original_bytes_unchanged":false,"actual_game_consumption_observed":false}

static func describe_item(record: Dictionary, fallback_name: String = "") -> Dictionary:
	var info: Dictionary = _item_presentation_info(item_class_id(record),str(record.get("name",fallback_name)),str(record.get("sourceId","")))
	if not recognized_item(record): return info
	if record.get("source_test_item",false) == true:
		info.reason = "source_test_item_excluded"
		return info
	var reader: RefCounted = active()
	var identity: Dictionary = reader.source_consumer_row("ItemClass",info.item_class_id) if reader != null else {}
	return _resolve_item_presentation(info,identity)

static func describe_item_class(id: int, title: String = "") -> Dictionary:
	# The caller supplies an explicit ItemClass.ID namespace. This is an image
	# presentation route, never a game record or an ownership/activation grant.
	var info: Dictionary = _item_presentation_info(id,title)
	info["presentation_only"] = true
	info["item_class_namespace"] = "ItemClass.ID"
	if id <= 0:
		info.reason = "zero_sentinel" if id == 0 else "source_item_class_identity_required"
		info["source_status"] = info.reason
		return info
	var reader: RefCounted = active()
	if reader == null:
		info.reason = _error if not _error.is_empty() else "source523_image_pack_not_selected"
		info["source_status"] = info.reason
		return info
	var identity: Dictionary = reader.source_consumer_row("ItemClass",id)
	info.provenance = identity.get("provenance",{}).duplicate(true)
	if not identity.get("ok",false):
		info.reason = str(identity.get("status","missing_consumer_key"))
		info["source_status"] = info.reason
		return info
	var canonical: Variant = identity.get("row")
	if not canonical is Dictionary or canonical.get("ID") != id:
		info.reason = "source_item_class_identity_required"
		info["source_status"] = info.reason
		return info
	if title.is_empty(): info.name = str(canonical.get("Name",""))
	return _resolve_item_presentation(info,identity)

static func describe_item_class_row(source_row: Dictionary, title: String = "") -> Dictionary:
	# Read-only suppliers can present an exact original ItemClass row without
	# manufacturing a native gameplay record or changing its snapshot marker.
	var value: Variant = source_row.get("ID")
	var id: int = int(value) if PACK._integer(value) else -1
	var info: Dictionary = _item_presentation_info(id,title)
	info["presentation_only"] = true
	info["item_class_namespace"] = "ItemClass.ID"
	if id <= 0:
		info.reason = "zero_sentinel" if id == 0 else "source_item_class_identity_required"
		info["source_status"] = info.reason
		return info
	var reader: RefCounted = active()
	var identity: Dictionary = reader.source_consumer_row("ItemClass",id) if reader != null else {}
	info.provenance = identity.get("provenance",{}).duplicate(true)
	if not identity.get("ok",false) or not identity.get("row") is Dictionary:
		info.reason = str(identity.get("status",_error if not _error.is_empty() else "source523_image_pack_not_selected"))
		info["source_status"] = info.reason
		return info
	if identity.row != source_row or info.provenance.get("source_table") != "ItemClass" or info.provenance.get("source_id") != id:
		info.reason = "source_item_class_row_mismatch"
		info["source_status"] = info.reason
		return info
	info.provenance["identity_basis"] = "complete_canonical_source_item_row"
	if title.is_empty(): info.name = str(source_row.get("Name",""))
	return _resolve_item_presentation(info,identity)

static func _reference_source_identity(value: Variant) -> Dictionary:
	# Keep only scalar identity data; callbacks and nested relationship trees
	# never become presentation metadata.
	var identity: Dictionary = {}
	if not value is Dictionary: return identity
	for key: Variant in value:
		if not key is String: continue
		var entry: Variant = value[key]
		if entry is String or entry is bool or entry is int or entry is float and is_finite(entry):
			identity[key] = entry
	return identity

static func describe_item_reference(data_reference: Dictionary, title: String = "") -> Dictionary:
	var info: Dictionary = _item_presentation_info(-1,title)
	info["data_reference_kind"] = data_reference.get("kind","") if data_reference.get("kind") is String else ""
	info["data_reference_source"] = _reference_source_identity(data_reference.get("source"))
	for flag: String in ["reference_only","can_activate","ownership_authorized"]:
		info[flag] = data_reference.get(flag) if data_reference.get(flag) is bool else null
	if data_reference.has("excluded"):
		info["data_reference_excluded"] = data_reference.excluded if data_reference.excluded is bool else null
	info.reason = "source_item_reference_contract_required"
	if info.data_reference_kind != "twilight.current523.item-data.v1" or info.reference_only != true or info.can_activate != false or info.ownership_authorized != false:
		return info
	if data_reference.has("excluded") and not data_reference.excluded is bool:
		info.reason = "source_item_reference_exclusion_invalid"
		return info
	var value: Variant = data_reference.get("item_class_id")
	info.reason = "source_item_reference_identity_required"
	if not PACK._integer(value) or float(value) <= 0: return info
	var id: int = int(value)
	var supplied: Variant = data_reference.get("item_class")
	if not supplied is Dictionary or not PACK._integer(supplied.get("ID")) or int(supplied.ID) != id: return info
	info.item_class_id = id
	var reader: RefCounted = active()
	if reader == null:
		info.reason = _error if not _error.is_empty() else "source523_image_pack_not_selected"
		info["source_status"] = info.reason
		return info
	var identity: Dictionary = reader.source_consumer_row("ItemClass",id)
	if not identity.get("ok",false):
		info.reason = str(identity.get("status","source_item_reference_canonical_row_unavailable"))
		info["source_status"] = info.reason
		info.provenance = identity.get("provenance",{}).duplicate(true)
		return info
	var canonical: Variant = identity.get("row")
	var canonical_provenance: Dictionary = identity.get("provenance",{})
	var expected_sha: String = str(canonical_provenance.get("source_row_canonical_sha256",""))
	var supplied_sha: String = PACK._canonical_row_sha(supplied)
	info.reason = "source_item_reference_row_mismatch"
	if not canonical is Dictionary or canonical.get("ID") != id or expected_sha.is_empty() or supplied_sha.is_empty() or supplied_sha != expected_sha or PACK._canonical_row_sha(canonical) != expected_sha:
		return info
	info.provenance = canonical_provenance.duplicate(true)
	info["item_class_row_canonical_sha256"] = supplied_sha
	if title.is_empty(): info.name = str(canonical.get("Name",""))
	# reference.ok may describe an unfinished Bonus relation. Image identity
	# depends on the complete canonical ItemClass row, never that service result.
	return _resolve_item_presentation(info,identity)

static func _resolve_item_presentation(info: Dictionary, identity: Dictionary) -> Dictionary:
	if identity.get("ok",false):
		info.provenance.merge(identity.get("provenance",{}),true)
		if identity.get("row",{}).get("TestItem",false) == true:
			info.reason = "source_test_item_excluded"
			info["source_status"] = info.reason
			return info
	if info.get("data_reference_excluded",false) == true:
		info.reason = "source_reference_excluded"
		info["source_status"] = info.reason
		return info
	var result: Dictionary = resolve_consumer("ItemClass",info.item_class_id,"IconID")
	info["source_status"] = str(result.get("status","source523_image_unavailable"))
	info["reason"] = info.source_status
	info.provenance.merge(result.get("provenance",{}),true)
	info["path"] = str(info.provenance.get("path",""))
	if info.source_status == "source_dummy_excluded":
		# Exclude only the reader's explicitly declared image asset. Keep the
		# existing missing-image label route and preserve the item record.
		info["source_image_dummy_excluded"] = true
		info["source_error"] = str(result.get("error",info.source_status))
		info["texture"] = null
		return info
	if bool(result.get("ok",false)) and result.get("texture") is Texture2D:
		info.status = "original_linked"
		info.texture = result.texture
		info.original_bytes_unchanged = true
	return info

static func missing_label(info: Dictionary) -> String:
	match str(info.get("reason","")):
		"source_reference_excluded": return "원문 참조 제외"
		"source_dummy_excluded": return "원본 더미 제외"
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
