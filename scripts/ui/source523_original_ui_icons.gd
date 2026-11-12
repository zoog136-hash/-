extends RefCounted
## Existing icon host adapter for the separately owned original UI pack/player.
## Original nodes, imagery, clips and playback rules remain with UI267.
const PACK_PATH = "res://scripts/ui/original_ui/source_pack.gd"
const PLAYER_PATH = "res://scripts/ui/original_ui/sprite_scene.gd"
const SCHEMA = "patch523-original-ui-icon-scenes-v1"
const NODE_NAME = "SourceItemIconScene"
const CONSUMER_FIELDS = {"ItemClass":["IconID"],"SpellClass":["IconID","ActivateIconID"],"BuffClass":["OnIconID","OffIconID"]}
static var pack: RefCounted
static var packs_by_manifest: Dictionary = {}
static var bindings: Dictionary = {}
static var _bindings_error: String = "source_scene_bindings_not_configured"
static var _view_cache: Dictionary = {}
static var _view_exit_hooks: Dictionary = {}

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

static func registration_contract(document: Dictionary) -> Dictionary:
	var scenes: Variant = document.get("source_icon_scenes")
	if not scenes is Dictionary or scenes.get("schema") != SCHEMA or not scenes.get("icons") is Dictionary:
		return _unavailable("source_scene_bindings_unavailable")
	for icon: Variant in scenes.icons:
		var incoming: Variant = scenes.icons[icon]
		if not incoming is Dictionary:
			return _unavailable("source_scene_binding_unavailable")
		if not bindings.has(icon): continue
		var previous: Variant = bindings[icon]
		if not previous is Dictionary:
			return _unavailable("source_scene_binding_conflict")
		for field: String in ["asset_id","asset_type_id","file_path","member","reviewed_current523_manifest_sha256","current523_scene_sha256"]:
			if not incoming.has(field) or previous.get(field) != incoming[field]:
				return _unavailable("source_scene_binding_conflict")
	return {"ok":true}

static func register(document: Dictionary) -> Dictionary:
	var contract: Dictionary = registration_contract(document)
	if not contract.get("ok",false): return contract
	for icon: Variant in document.source_icon_scenes.icons:
		# Replace only this caller's explicit entry. Never retain an old loop
		# value when a newer declaration omits its playback policy.
		bindings[icon] = document.source_icon_scenes.icons[icon].duplicate(true)
	_bindings_error = "" if not bindings.is_empty() else "source_scene_bindings_unavailable"
	return {"ok":true,"rendered":false}

static func _unavailable(reason: String, details: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok":false,"status":"unavailable","error":reason,"inspection_only":false}
	if not details.is_empty():
		result["details"] = _metadata_value(details)
	return result

static func _metadata_value(value: Variant) -> Variant:
	if value == null or value is String or value is bool or value is int:
		return value
	if value is float: return value if is_finite(value) else null
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			if not item is Object and not item is Callable: items.append(_metadata_value(item))
		return items
	if value is Dictionary:
		var fields: Dictionary = {}
		for field: String in ["source_text","source_percent","visible","displaystate","selected","source_scroll","callback_name","frame_events"]:
			if value.has(field): return {"binding_values_omitted":true}
		for key: Variant in value:
			if not key is String or key in ["bindings","original_ui_bindings","frame_events"]: continue
			var item: Variant = value[key]
			if not item is Object and not item is Callable: fields[key] = _metadata_value(item)
		return fields
	return null

static func prepare_pack(root: String, expected_sha256: String) -> Dictionary:
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
	var actual_pin: Variant = candidate.get("manifest_sha256")
	if not _sha256(actual_pin) or actual_pin != expected_sha256:
		return _unavailable("source_scene_pack_contract_unavailable")
	var result: Dictionary = opened.duplicate(true)
	result["pack"] = candidate
	result["manifest_sha256"] = actual_pin
	result["status"] = "source_scene_pack_prepared"
	result["rendered"] = false
	return result

static func commit_selection(prepared_packs: Array, document: Dictionary) -> Dictionary:
	var contract: Dictionary = registration_contract(document)
	if not contract.get("ok",false): return contract
	var next_packs: Dictionary = packs_by_manifest.duplicate()
	var prepared_pins: Dictionary = {}
	var last_pack: RefCounted = pack
	for prepared: Variant in prepared_packs:
		if not prepared is Dictionary or not prepared.get("ok",false):
			return _unavailable("source_scene_pack_not_prepared")
		var candidate: Variant = prepared.get("pack")
		var pin: Variant = prepared.get("manifest_sha256")
		if not candidate is RefCounted or not candidate.has_method("scene") or not _sha256(pin) or candidate.get("manifest_sha256") != pin:
			return _unavailable("source_scene_pack_contract_unavailable")
		if prepared_pins.has(pin): return _unavailable("source_scene_duplicate_prepared_pack")
		prepared_pins[pin] = true
		next_packs[pin] = candidate
		last_pack = candidate
	var next_bindings: Dictionary = bindings.duplicate(true)
	for icon: Variant in document.source_icon_scenes.icons:
		var incoming: Dictionary = document.source_icon_scenes.icons[icon]
		var pin: Variant = incoming.get("reviewed_current523_manifest_sha256")
		if not _sha256(pin) or not next_packs.has(pin):
			return _unavailable("source_scene_pack_not_prepared")
		next_bindings[icon] = incoming.duplicate(true)
	# No externally visible selection changes until every candidate and the
	# complete registration document have passed the same contract.
	packs_by_manifest = next_packs
	pack = last_pack
	bindings = next_bindings
	_bindings_error = "" if not bindings.is_empty() else "source_scene_bindings_unavailable"
	return {"ok":true,"status":"source_scene_selection_ready","rendered":false}

static func open_pack(root: String, expected_sha256: String) -> Dictionary:
	var prepared: Dictionary = prepare_pack(root,expected_sha256)
	if not prepared.get("ok",false): return prepared
	var committed: Dictionary = commit_selection([prepared],{"source_icon_scenes":{"schema":SCHEMA,"icons":{}}})
	if not committed.get("ok",false): return committed
	prepared["status"] = "source_scene_pack_ready"
	return prepared

static func detach(view: TextureRect, immediate: bool = true) -> void:
	if not is_instance_valid(view):
		return
	_view_cache.erase(view.get_instance_id())
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

static func _consumer_identity(info: Dictionary, canonical: Dictionary) -> Dictionary:
	var table: Variant = canonical.get("source_table")
	var field: Variant = canonical.get("source_field")
	if not table is String or not CONSUMER_FIELDS.has(table) or not field is String or not field in CONSUMER_FIELDS[table]:
		return _unavailable("source_scene_consumer_role_required")
	if not _source_id(canonical.get("source_id")) or not _sha256(canonical.get("source_row_canonical_sha256")):
		return _unavailable("source_scene_consumer_identity_required")
	if table == "ItemClass" and (not _source_id(info.get("item_class_id")) or info.item_class_id != canonical.source_id):
		return _unavailable("source_scene_identity_mismatch")
	return {"ok":true,"identity":{"source_table":table,"source_id":int(canonical.source_id),"source_field":field,
		"source_row_canonical_sha256":canonical.source_row_canonical_sha256,
		"source_table_sha256":canonical.get("source_table_sha256","")}}

static func _playback_policy(spec: Dictionary, context: Dictionary) -> Dictionary:
	var declared: Variant = spec.get("original_repeat_declared") if spec.get("original_repeat_declared") is bool else null
	var repeat_value: bool
	if context.has("repeat"):
		if not context.repeat is bool: return _unavailable("source_scene_playback_binding_missing")
		repeat_value = context.repeat
	elif spec.has("repeat"):
		if not spec.repeat is bool: return _unavailable("source_scene_playback_binding_missing")
		repeat_value = spec.repeat
	elif context.get("allow_estimated_single_pass") is bool and context.allow_estimated_single_pass and spec.get("original_repeat_declared") is bool and not spec.original_repeat_declared:
		return {"ok":true,"repeat":false,"origin":"estimated_single_pass_icon_host",
			"original_repeat_declared":false,"original_policy_confirmed":false}
	else:
		return _unavailable("source_scene_playback_binding_missing")
	var confirmed: bool = declared == true and spec.get("original_policy_confirmed") is bool and spec.original_policy_confirmed and spec.get("repeat") is bool and spec.repeat == repeat_value
	return {"ok":true,"repeat":repeat_value,"origin":"explicit_caller_repeat",
		"original_repeat_declared":declared,"original_policy_confirmed":confirmed}

static func _host_context(context: Dictionary) -> Dictionary:
	return {"usage":context.get("usage","") if context.get("usage") is String else "",
		"trigger":context.get("trigger","") if context.get("trigger") is String else "",
		"original_trigger_confirmed":false}

static func _attach_failure(view: TextureRect, reason: String, details: Dictionary = {}) -> Dictionary:
	detach(view)
	return _unavailable(reason,details)

static func _on_view_tree_exiting(view_id: int) -> void:
	var cached: Dictionary = _view_cache.get(view_id,{})
	var reference: Variant = cached.get("view")
	_view_exit_hooks.erase(view_id)
	if reference is WeakRef:
		var view: Variant = reference.get_ref()
		if is_instance_valid(view) and view is TextureRect:
			detach(view,false)
			return
	_view_cache.erase(view_id)

static func _remember(view: TextureRect, host: Control, scene: Node2D, key: Dictionary, original_ui_bindings: Dictionary, result: Dictionary) -> void:
	var view_id: int = view.get_instance_id()
	_view_cache[view_id] = {"view":weakref(view),"host":weakref(host),"scene":weakref(scene),
		"key":key.duplicate(true),"bindings":original_ui_bindings.duplicate(true),"result":result.duplicate(true)}
	if not _view_exit_hooks.has(view_id):
		var cleanup: Callable = _on_view_tree_exiting.bind(view_id)
		_view_exit_hooks[view_id] = cleanup
		view.tree_exiting.connect(cleanup,Object.CONNECT_ONE_SHOT)

static func _reuse(view: TextureRect, key: Dictionary, original_ui_bindings: Dictionary, context: Dictionary) -> Dictionary:
	var cached: Dictionary = _view_cache.get(view.get_instance_id(),{})
	if cached.is_empty() or cached.get("key") != key or cached.get("bindings") != original_ui_bindings: return {}
	var view_reference: Variant = cached.get("view")
	var host_reference: Variant = cached.get("host")
	var scene_reference: Variant = cached.get("scene")
	if not view_reference is WeakRef or not host_reference is WeakRef or not scene_reference is WeakRef: return {}
	var cached_view: Variant = view_reference.get_ref()
	var host: Variant = host_reference.get_ref()
	var scene: Variant = scene_reference.get_ref()
	if cached_view != view or not is_instance_valid(host) or not is_instance_valid(scene): return {}
	if not host is Control or not scene is Node2D or host.is_queued_for_deletion() or scene.is_queued_for_deletion(): return {}
	if host.get_parent() != view or scene.get_parent() != host or view.get_node_or_null(NODE_NAME) != host: return {}
	var result: Dictionary = cached.result.duplicate(true)
	result["reused"] = true
	result["play_restarted"] = false
	result["sync_context"] = _host_context(context)
	return result

static func _resolve_scene(info: Dictionary) -> Dictionary:
	# Both host paths use the same canonical consumer/Icon/Asset/CSB identity.
	# A native Sprite slot supplies its own registration, never the old host fit.
	if info.get("route") != "source523_images" or info.get("source_snapshot") != "patch523" or info.get("reason") != "unsupported_csb":
		return _unavailable("source_scene_identity_mismatch")
	var canonical: Variant = info.get("provenance")
	if not canonical is Dictionary:
		return _unavailable("source_scene_identity_required")
	var consumer: Dictionary = _consumer_identity(info,canonical)
	if not consumer.get("ok",false):
		return consumer
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
	if not _sha256(spec.get("reviewed_current523_manifest_sha256")) or not _sha256(spec.get("current523_scene_sha256")):
		return _unavailable("source_scene_version_unverified")
	var selected_pack: RefCounted = packs_by_manifest.get(spec.reviewed_current523_manifest_sha256)
	# Preserve the original single-pack API for an explicitly supplied pack.
	if selected_pack == null and pack != null and pack.get("manifest_sha256") == spec.reviewed_current523_manifest_sha256:
		selected_pack = pack
	if selected_pack == null:
		return _unavailable("source_scene_pack_not_open")
	var manifest_sha256: Variant = selected_pack.get("manifest_sha256")
	if not _sha256(manifest_sha256) or spec.reviewed_current523_manifest_sha256 != manifest_sha256:
		return _unavailable("source_scene_version_unverified")
	var source: Variant = selected_pack.scene(member)
	if not source is Dictionary or source.is_empty() or source.get("_source_sha256") != spec.current523_scene_sha256:
		return _unavailable("source_scene_version_unverified")
	return {"ok":true,"canonical":canonical,"consumer":consumer.identity,"spec":spec,
		"pack":selected_pack,"manifest_sha256":manifest_sha256,"source":source}

## The client's common icon setter (LineageM 1.10.22.0, 0x00C381A0) is the one
## routine that puts an item/skill icon on a slot Sprite: a PNG icon becomes the
## Sprite's texture, an AssetType 101 CSB icon is attached to that same Sprite and
## played with timeline.play("normal", true) (0x00C386B1). Every icon binding of
## the selection records exactly this evidence in policy_source. A native slot
## whose icon Sprite is declared by the original UI scene (the node the existing
## owner already fills with the PNG icon) is therefore that setter's target; the
## CSB root is attached at the Sprite anchor with no fit, scale or offset of ours.
## Anything else keeps the explicit native_registrations requirement.
const COMMON_ICON_SETTER_EVIDENCE := "common icon setter 0x00C381A0 attaches the AssetType101 CSB to the slot Sprite"
static func common_icon_setter_registration(spec: Dictionary, slot: Dictionary, target: Dictionary) -> Variant:
	if not str(spec.get("policy_source","")).contains(COMMON_ICON_SETTER_EVIDENCE): return null
	if slot.get("ui_target_declared_by_original") != true or slot.get("registration_space") != "authored_sprite_anchor" or slot.get("fit_or_offset_inferred") != false: return null
	if not spec.get("clip") is String or str(spec.clip).is_empty() or not spec.get("repeat") is bool or spec.get("original_repeat_declared") != true or spec.get("original_policy_confirmed") != true: return null
	return [{"registration":{"space":"authored_sprite_anchor","original_registration_confirmed":true,"target":target.duplicate(true),
		"source_basis":str(spec.policy_source)+" · target: the original slot scene's icon Sprite that the same setter fills with a PNG icon"},
		"bindings":{},"playback":{"clip":str(spec.clip),"repeat":bool(spec.repeat),"original_repeat_declared":true,"original_policy_confirmed":true}}]

static func native_scene_descriptor(info: Dictionary, context: Dictionary) -> Dictionary:
	var resolved: Dictionary = _resolve_scene(info)
	if not resolved.get("ok",false): return resolved
	var slot: Variant = context.get("source_slot_contract")
	if not slot is Dictionary or slot.get("ok") != true or slot.get("schema") != "twilight-native-icon-scene-slot-v1" or slot.get("registration_space") != "authored_sprite_anchor":
		return _unavailable("source_scene_original_native_slot_required")
	if not slot.get("member") is String or not _safe_relative(slot.member) or not _sha256(slot.get("source_sha256")) or not _sha256(slot.get("manifest_sha256")) or not _source_id(slot.get("node_offset")):
		return _unavailable("source_scene_original_native_slot_identity_required")
	var target: Dictionary = {"member":slot.member,"source_sha256":slot.source_sha256,
		"manifest_sha256":slot.manifest_sha256,"node_offset":int(slot.node_offset)}
	var spec: Dictionary = resolved.spec
	var declarations: Variant = spec.get("native_registrations")
	if not declarations is Array: declarations = common_icon_setter_registration(spec,slot,target)
	if not declarations is Array:
		return _unavailable("source_scene_original_native_registration_pending",{"target":target,
			"pending_fields":["native_registrations[].registration: exact target and actual original source_basis"],
			"slot_metadata_is_registration_proof":false})
	var matches: Array = []
	for entry: Variant in declarations:
		if not entry is Dictionary or not entry.get("registration") is Dictionary: continue
		var entry_registration: Dictionary = entry.registration
		var declared_target: Variant = entry_registration.get("target")
		if not declared_target is Dictionary: continue
		var same_target: bool = true
		for field: String in target:
			if declared_target.get(field) != target[field]: same_target = false
		if same_target: matches.append(entry)
	if matches.size() != 1:
		return _unavailable("source_scene_original_native_registration_pending" if matches.is_empty() else "source_scene_original_native_registration_ambiguous",{"target":target})
	var declaration: Dictionary = matches[0]
	var registration: Dictionary = declaration.registration
	# Source root identity and the supplied slot options alone do not establish
	# the original client's registration. Never manufacture that assertion.
	if registration.get("space") != "authored_sprite_anchor" or not registration.get("original_registration_confirmed") is bool or not registration.original_registration_confirmed or not registration.get("source_basis") is String or registration.source_basis.strip_edges().is_empty():
		return _unavailable("source_scene_original_native_registration_pending",{"target":target})
	var source_bindings: Variant = declaration.get("bindings",{})
	if not source_bindings is Dictionary:
		return _unavailable("source_scene_native_bindings_required")
	var descriptor: Dictionary = {"pack":resolved.pack,"manifest_sha256":resolved.manifest_sha256,
		"member":spec.member,"source_sha256":spec.current523_scene_sha256,
		"registration":{"space":"authored_sprite_anchor","original_registration_confirmed":true,
			"source_basis":registration.source_basis,"target":target},"bindings":source_bindings.duplicate(true),
		"image_owner_identity":{"consumer":resolved.consumer.duplicate(true),
			"icon_id":int(resolved.canonical.icon_id),"asset_id":int(resolved.canonical.asset_id),
			"image_pack_manifest_sha256":resolved.canonical.get("manifest_sha256","")}}
	if declaration.has("playback"):
		var playback: Variant = declaration.playback
		if not playback is Dictionary or not playback.get("clip") is String or playback.clip.is_empty() or not playback.get("repeat") is bool or not playback.get("original_repeat_declared") is bool or not playback.original_repeat_declared or not playback.get("original_policy_confirmed") is bool or not playback.original_policy_confirmed:
			return _unavailable("source_scene_original_native_playback_pending",{"target":target})
		var clips: Array = []
		for clip: Variant in resolved.source.get("animationList",[]):
			if clip is Dictionary and clip.get("name") == playback.clip: clips.append(clip)
		if clips.size() != 1:
			return _unavailable("source_scene_original_native_clip_not_unique")
		descriptor["playback"] = playback.duplicate(true)
	# No playback means the UI owner's strict loader keeps serialized source
	# state stopped. Legacy host single-pass estimates never enter this path.
	return {"ok":true,"descriptor":descriptor,"rendered":false,"actual_game_consumption_observed":false}

static func attach(view: TextureRect, info: Dictionary, original_ui_bindings: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(view):
		return _unavailable("source_scene_host_unavailable")
	var resolved: Dictionary = _resolve_scene(info)
	if not resolved.get("ok",false):
		return _attach_failure(view,str(resolved.get("error","source_scene_identity_required")),resolved.get("details",{}))
	var canonical: Dictionary = resolved.canonical
	var consumer: Dictionary = {"identity":resolved.consumer}
	var spec: Dictionary = resolved.spec
	var selected_pack: RefCounted = resolved.pack
	var manifest_sha256: String = resolved.manifest_sha256
	var member: String = spec.member
	if not spec.get("clip") is String or spec.clip.is_empty():
		return _attach_failure(view,"source_scene_playback_binding_missing")
	var policy: Dictionary = _playback_policy(spec,context)
	if not policy.get("ok",false):
		return _attach_failure(view,str(policy.error))
	if not ResourceLoader.exists(PLAYER_PATH):
		return _attach_failure(view,"source_scene_player_not_installed")
	var host_context: Dictionary = _host_context(context)
	var key: Dictionary = {"consumer":consumer.identity,"icon_id":int(canonical.icon_id),
		"asset_id":int(canonical.asset_id),"asset_type_id":int(canonical.asset_type_id),"path":canonical.path,
		"image_pack_manifest_sha256":canonical.get("manifest_sha256",""),"manifest_sha256":manifest_sha256,
		"scene_sha256":spec.current523_scene_sha256,"member":member,"clip":spec.clip,"policy":policy}
	var reused: Dictionary = _reuse(view,key,original_ui_bindings,context)
	if not reused.is_empty(): return reused
	detach(view)
	var player_script: Variant = load(PLAYER_PATH)
	if not player_script is Script or not player_script.can_instantiate():
		return _attach_failure(view,"source_scene_player_not_installed")
	var scene: Variant = player_script.new()
	if not scene is Node2D:
		if scene is Node:
			scene.free()
		return _attach_failure(view,"source_scene_player_contract_unavailable")
	if not scene.has_method("configure") or not scene.has_method("play"):
		scene.free()
		return _attach_failure(view,"source_scene_player_contract_unavailable")
	var configured: Variant
	if original_ui_bindings.is_empty():
		configured = scene.configure(selected_pack, member, false)
	else:
		var accepts_bindings: bool = false
		for method: Dictionary in scene.get_method_list():
			if str(method.get("name", "")) != "configure":
				continue
			var arguments: Variant = method.get("args", [])
			var defaults: Variant = method.get("default_args", [])
			accepts_bindings = arguments is Array and defaults is Array and arguments.size() >= 4 and arguments.size() - defaults.size() <= 4
			break
		if not accepts_bindings:
			scene.free()
			return _attach_failure(view,"source_scene_player_contract_unavailable")
		configured = scene.configure(selected_pack, member, false, original_ui_bindings)
	if not configured is Dictionary or not configured.get("ok", false):
		scene.free()
		return _attach_failure(view,"source_scene_configure_unavailable", configured if configured is Dictionary else {})
	var played: Variant = scene.play(spec.clip, policy.repeat)
	if not played is Dictionary or not played.get("ok", false):
		scene.free()
		return _attach_failure(view,"source_scene_playback_unavailable", played if played is Dictionary else {})
	var host := Control.new()
	host.name = NODE_NAME
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(host)
	# Only the donor's external host placement is applied. The original UI
	# hierarchy, transforms, source frames and timing remain with its player.
	host.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	host.add_child(scene)
	var result: Dictionary = {"ok":true,"status":"original_scene_linked","source":member,
		"manifest_sha256":manifest_sha256,"scene_sha256":spec.current523_scene_sha256,
		"consumer":consumer.identity.duplicate(true),"clip":spec.clip,"repeat":policy.repeat,
		"origin":policy.origin,"original_repeat_declared":policy.original_repeat_declared,
		"original_policy_confirmed":policy.original_policy_confirmed,"host_context":host_context,
		"trigger":host_context.trigger,"original_trigger_confirmed":false,
		"inspection_only":false,"reused":false,"play_restarted":true}
	_remember(view,host,scene,key,original_ui_bindings,result)
	return result
