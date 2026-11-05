extends RefCounted
## Adapter to the separately owned original UI v2 player. No CSB interpreter.
const PACK_PATH = "res://scripts/ui/original_ui/source_pack.gd"
const PLAYER_PATH = "res://scripts/ui/original_ui/sprite_scene.gd"
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const NODE_NAME = "SourceItemIconScene"
static var pack: RefCounted
static var index: Dictionary = {}
static var bindings: Dictionary = {}

static func configure(document: Dictionary) -> void:
	index = {}
	bindings = {}
	var identities: Variant = document.get("source_icon_index", {})
	var scenes: Variant = document.get("source_icon_scenes", {})
	if not identities is Dictionary or identities.get("schema") != "patch523-item-icon-index-v1": return
	if not scenes is Dictionary or scenes.get("schema") != "patch523-original-ui-icon-scenes-v1": return
	if not scenes.get("icons") is Dictionary: return
	index = identities.duplicate(true)
	bindings = scenes.icons.duplicate(true)

static func open_pack(root: String, expected_sha256: String) -> Dictionary:
	if not ResourceLoader.exists(PACK_PATH) or not ResourceLoader.exists(PLAYER_PATH):
		return {"ok":false,"error":"source_scene_player_not_installed"}
	var candidate: RefCounted = load(PACK_PATH).new()
	var result: Dictionary = candidate.open(root, expected_sha256)
	if result.get("ok", false): pack = candidate
	return result # failed replacement retains the previous verified pack

static func detach(view: TextureRect, immediate: bool = true) -> void:
	var old: Node = view.get_node_or_null(NODE_NAME)
	if old == null: return
	old.process_mode = Node.PROCESS_MODE_DISABLED
	old.set_process(false)
	if immediate: view.remove_child(old)
	old.queue_free()

static func attach(view: TextureRect, identity: Dictionary) -> Dictionary:
	detach(view)
	var icon: String = str(identity.get("icon_id", -1))
	var spec: Variant = bindings.get(icon)
	if not spec is Dictionary or pack == null: return {"ok":false,"error":"source_scene_inputs_not_installed"}
	if identity.get("asset_type_id") != 101 or index.get("items", {}).get(str(identity.get("item_class_id", -1)), -2) != identity.get("icon_id"):
		return {"ok":false,"error":"source_scene_identity_mismatch"}
	var canonical: Dictionary = index.get("icons", {}).get(icon, {})
	for key: String in ["asset_id", "asset_type_id", "file_path"]:
		if not identity.has(key) or canonical.get(key) != identity[key] or spec.get(key) != identity[key]:
			return {"ok":false,"error":"source_scene_identity_mismatch"}
	var literal: String = str(identity.file_path)
	# v2's verified source namespace is UI/CsbFile. Never basename-match.
	if not INSTALL.safe_relative(literal) or not literal.begins_with("icon/") or literal.get_extension() != "csb":
		return {"ok":false,"error":"source_scene_path_invalid"}
	var member: String = "UI/CsbFile/" + literal
	if spec.get("member") != member or spec.get("reviewed_current523_manifest_sha256") != pack.manifest_sha256:
		return {"ok":false,"error":"source_scene_version_unverified"}
	var source: Dictionary = pack.scene(member)
	if source.is_empty() or spec.get("current523_scene_sha256", "") != source.get("_source_sha256"):
		return {"ok":false,"error":"source_scene_version_unverified"}
	if not ResourceLoader.exists(PLAYER_PATH): return {"ok":false,"error":"source_scene_player_not_installed"}
	var scene: Node2D = load(PLAYER_PATH).new()
	var result: Dictionary = scene.configure(pack, member, false)
	if not result.get("ok", false):
		scene.free()
		return result
	# An explicit source clip is required; no guessed default or loop policy.
	if not spec.get("clip") is String or not spec.get("repeat") is bool:
		scene.free()
		return {"ok":false,"error":"source_scene_playback_binding_missing"}
	var played: Dictionary = scene.play(spec.clip, spec.repeat)
	if not played.get("ok", false):
		scene.free()
		return played
	var host := Control.new()
	host.name = NODE_NAME
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(host)
	# Center the source origin in the host slot; keep all source transforms,
	# scale, alpha, timing and clipping inside the original player untouched.
	host.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	host.add_child(scene)
	return {"ok":true,"source":member,"manifest_sha256":pack.manifest_sha256,"inspection_only":false}
