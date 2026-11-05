extends RefCounted
## Item host adapter for the separately owned original UI pack/player.
## Original nodes, imagery, clips and playback rules remain with UI267.
const PACK_PATH = "res://scripts/ui/original_ui/source_pack.gd"
const PLAYER_PATH = "res://scripts/ui/original_ui/sprite_scene.gd"
const SCHEMA = "patch523-original-ui-icon-scenes-v1"
const NODE_NAME = "SourceItemIconScene"
static var pack: RefCounted
static var bindings: Dictionary = {}
static var _bindings_error: String = "source_scene_bindings_not_configured"

static func configure(document: Dictionary) -> void:
	bindings = {}
	_bindings_error = "source_scene_bindings_unavailable"
	var scenes: Variant = document.get("source_icon_scenes")
	if not scenes is Dictionary or scenes.get("schema") != SCHEMA:
		return
	if not scenes.get("icons") is Dictionary:
		return
	bindings = scenes.icons.duplicate(true)
	_bindings_error = "" if not bindings.is_empty() else "source_scene_bindings_unavailable"

static func _unavailable(reason: String, details: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok":false,"status":"unavailable","error":reason,"inspection_only":false}
	if not details.is_empty():
		result["details"] = details.duplicate(true)
	return result

static func open_pack(root: String, expected_sha256: String) -> Dictionary:
	if not ResourceLoader.exists(PACK_PATH) or not ResourceLoader.exists(PLAYER_PATH):
		return _unavailable("source_scene_player_not_installed")
	var script: Variant = load(PACK_PATH)
	if not script is Script or not script.can_instantiate():
		return _unavailable("source_scene_pack_loader_unavailable")
	var candidate: Variant = script.new()
	if not candidate is RefCounted or not candidate.has_method("open") or not candidate.has_method("scene"):
		return _unavailable("source_scene_pack_contract_unavailable")
	var opened: Variant = candidate.open(root, expected_sha256)
	if not opened is Dictionary:
		return _unavailable("source_scene_pack_contract_unavailable")
	if not opened.get("ok", false):
		var failed: Dictionary = _unavailable(str(opened.get("error", "source_scene_pack_unavailable")), opened)
		failed["previous_pack_preserved"] = pack != null
		return failed
	pack = candidate
	var result: Dictionary = opened.duplicate(true)
	result["status"] = "source_scene_pack_ready"
	result["rendered"] = false
	return result

static func detach(view: TextureRect, immediate: bool = true) -> void:
	if not is_instance_valid(view):
		return
	var old: Node = view.get_node_or_null(NODE_NAME)
	if old == null:
		return
	old.process_mode = Node.PROCESS_MODE_DISABLED
	old.set_process(false)
	# The donor's deferred path is used while an item host exits the tree.
	if immediate:
		view.remove_child(old)
	old.queue_free()

static func _source_id(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) > 0

static func _sha256(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for offset: int in range(value.length()):
		if not "0123456789abcdef".contains(value.substr(offset, 1)):
			return false
	return true

static func _safe_relative(value: String) -> bool:
	if value.is_empty() or value.begins_with("/") or value.contains("\\") or value.contains(":"):
		return false
	for component: String in value.split("/", true):
		if component.is_empty() or component == "." or component == "..":
			return false
	for offset: int in range(value.length()):
		if value.unicode_at(offset) < 32 or value.unicode_at(offset) == 127:
			return false
	return true

static func attach(view: TextureRect, info: Dictionary) -> Dictionary:
	if not is_instance_valid(view):
		return _unavailable("source_scene_host_unavailable")
	detach(view)
	if info.get("route") != "source523_images" or info.get("source_snapshot") != "patch523" or info.get("reason") != "unsupported_csb":
		return _unavailable("source_scene_identity_mismatch")
	var canonical: Variant = info.get("provenance")
	if not canonical is Dictionary or not _source_id(info.get("item_class_id")):
		return _unavailable("source_scene_identity_required")
	for field: String in ["icon_id", "asset_id", "asset_type_id"]:
		if not _source_id(canonical.get(field)):
			return _unavailable("source_scene_identity_required")
	if canonical.asset_type_id != 101 or not canonical.get("path") is String:
		return _unavailable("source_scene_identity_mismatch")
	if not _bindings_error.is_empty():
		return _unavailable(_bindings_error)
	var spec: Variant = bindings.get(str(int(canonical.icon_id)))
	if not spec is Dictionary:
		return _unavailable("source_scene_binding_unavailable")
	for field: String in ["asset_id", "asset_type_id"]:
		if not _source_id(spec.get(field)) or spec[field] != canonical[field]:
			return _unavailable("source_scene_identity_mismatch")
	if not spec.get("file_path") is String or not spec.get("member") is String:
		return _unavailable("source_scene_path_binding_missing")
	var literal: String = spec.file_path
	var member: String = spec.member
	# The donor namespace is explicit. The current pack's canonical path is
	# already complete; never strip a prefix or trust an extra file_path field.
	if not _safe_relative(literal) or not literal.begins_with("icon/") or literal.get_extension() != "csb":
		return _unavailable("source_scene_path_invalid")
	if member != canonical.path or member != "UI/CsbFile/" + literal:
		return _unavailable("source_scene_identity_mismatch")
	if not spec.get("clip") is String or spec.clip.is_empty() or not spec.get("repeat") is bool:
		return _unavailable("source_scene_playback_binding_missing")
	if not _sha256(spec.get("reviewed_current523_manifest_sha256")) or not _sha256(spec.get("current523_scene_sha256")):
		return _unavailable("source_scene_version_unverified")
	if pack == null:
		return _unavailable("source_scene_pack_not_open")
	var manifest_sha256: Variant = pack.get("manifest_sha256")
	if not _sha256(manifest_sha256) or spec.reviewed_current523_manifest_sha256 != manifest_sha256:
		return _unavailable("source_scene_version_unverified")
	var source: Variant = pack.scene(member)
	if not source is Dictionary or source.is_empty() or source.get("_source_sha256") != spec.current523_scene_sha256:
		return _unavailable("source_scene_version_unverified")
	if not ResourceLoader.exists(PLAYER_PATH):
		return _unavailable("source_scene_player_not_installed")
	var player_script: Variant = load(PLAYER_PATH)
	if not player_script is Script or not player_script.can_instantiate():
		return _unavailable("source_scene_player_not_installed")
	var scene: Variant = player_script.new()
	if not scene is Node2D:
		if scene is Node:
			scene.free()
		return _unavailable("source_scene_player_contract_unavailable")
	if not scene.has_method("configure") or not scene.has_method("play"):
		scene.free()
		return _unavailable("source_scene_player_contract_unavailable")
	var configured: Variant = scene.configure(pack, member, false)
	if not configured is Dictionary or not configured.get("ok", false):
		scene.free()
		return _unavailable("source_scene_configure_unavailable", configured if configured is Dictionary else {})
	var played: Variant = scene.play(spec.clip, spec.repeat)
	if not played is Dictionary or not played.get("ok", false):
		scene.free()
		return _unavailable("source_scene_playback_unavailable", played if played is Dictionary else {})
	var host := Control.new()
	host.name = NODE_NAME
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(host)
	# Only the donor's external host placement is applied. The original UI
	# hierarchy, transforms, source frames and timing remain with its player.
	host.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	host.add_child(scene)
	return {"ok":true,"status":"original_scene_linked","source":member,
		"manifest_sha256":manifest_sha256,"scene_sha256":spec.current523_scene_sha256,
		"clip":spec.clip,"repeat":spec.repeat,"inspection_only":false}
