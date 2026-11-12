extends Node2D
## Opt-in inspection of literal source pixels. This is NOT an approved compositor.
## No AnimationCatalog overrides, procedural transforms or gameplay hit clocks.
signal native_annotations(event: Dictionary)
signal native_effect_frame(event: Dictionary)
const WEAPON_BANKS=preload("res://scripts/animation/source_weapon_banks.gd")
var source_weapon_status:Dictionary={}
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const SP2_COMPOSITOR = preload("res://scripts/animation/source_sp2_compositor.gd")
const REFERENCE_EXCLUSIONS = preload("res://scripts/animation/source_reference_exclusions.gd")
var reference_exclusion_status: Dictionary = {}
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
const REFERENCE_BANK = preload("res://scripts/resources/reference_sp2_bank.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const CURRENT523_BANK = preload("res://scripts/resources/current523_source_bank.gd")
const CURRENT523_EFFECT = preload("res://scripts/resources/current523_source_effect_selection.gd")
var source_effect_status: Dictionary = {}
var _reference_bank: RefCounted
var _reference_card_context: Dictionary = {}
var _reference_request_context: Dictionary = {}
var _reference_overlay_parents: Dictionary = {}
var _reference_overlay_parent: Dictionary = {}
var _reference_attachment_parent: Dictionary = {}
var _reference_source_children: Dictionary = {}
var _reference_child_role: String = ""
var _reference_overlay_clock: float = -0.000000001
var _reference_overlay_key: String = ""
var _reference_frame_status: Dictionary = {}
## The frame status is read only by diagnostics/tests, so each frame keeps
## references to its inputs and reference_source_frame_status() builds the
## same dictionary on demand (it was deep-copied for every actor every frame).
var _reference_frame_inputs: Dictionary = {}
var _reference_texture_budget: Dictionary = {}
var _reference_texture_charges: Dictionary = {}
var _reference_child_problem: Dictionary = {}
var reference_bank_status: Dictionary = {}
var playback_mode_override: String = ""
var source_selection_status: Dictionary = {}
var _current523_source_only: bool = false
var _playback_tracks: Dictionary = {}
var _playback_mode: String = "strict"
var _manifest_path: String = ""
var _manifest_records: Dictionary = {}
var _annotation_clock: float = -0.000000001
var _annotation_track_key: String = ""
var _overlay_nodes: Array[Node2D] = []
var _is_overlay: bool = false
var _overlay_facing: int = 0
var _effect_nodes: Dictionary = {}
var _last_token: String = ""
var _record: Dictionary = {}
var _root: String = ""
const GPU_ACTOR_TEXTURE = preload("res://scripts/resources/gpu_actor_texture.gd")
const SHARED_ASSETS = preload("res://scripts/resources/reference_sp2_asset_service.gd")
var _textures: Dictionary = {}
# Reference frames come from the process-wide asset store: local texture_key
# -> shared rendered key leased by this preview. Clocks/selection stay here.
var _texture_leases: Dictionary = {}
var _asset_owner: int = SHARED_ASSETS.new_owner()
var _layers: Array[Sprite2D] = []
var _source_body_style: Dictionary = {}
var _source_body_material: CanvasItemMaterial
var _role: String = "idle"
var source_facing: int = 0
var _clock: float = 0.0
var _sequence: int = -1
var _source_attack: bool = false
var _attack_completed: bool = false
var last_source_frame: int = -1

func current523_source_required(key: String) -> bool:
	if key == "class:current523": return true
	# Saved m508/m523 keys are stable identities, not permission to consume old
	# media. Final native card presentation requires the new original input.
	var consumer: String = key.get_slice(":",0)
	var identity: String = key.substr(key.find(":")+1)
	return CURRENT523_BANK.DECKS.has(consumer) and (identity.begins_with("m508:") or identity.begins_with("m523:"))

func current523_source_only_presentation() -> bool:
	# This is a final-input policy, not an assertion that the bank is installed.
	return _current523_source_only or bool(CURRENT523_BANK.options(_reference_request_context).get("enabled",false))

func configure(key: String, manifest_path: String, context: Dictionary = {}) -> bool:
	var source_only: bool = current523_source_required(key)
	_current523_source_only = source_only
	if source_only:
		clear()
	elif _configure_existing_source(key, manifest_path, context):
		# Keep an explicitly supplied source-bank configuration available to
		# later effect requests without replacing this working actor.
		_reference_request_context = context.duplicate(true)
		return true
	# A pending body must not discard the independent spell/item/invoke input.
	_reference_request_context = context.duplicate(true)
	var selected: Dictionary = CURRENT523_BANK.select_class(context) if key == "class:current523" else CURRENT523_BANK.select_card(key, context)
	if source_only:
		selected["source_only"] = true
		selected["legacy_media_fallback_allowed"] = false
		if not selected.get("ok",false): selected["status"] = "source_only_pending"
	if not bool(selected.get("enabled",false)):
		source_selection_status = selected
		return false
	if not selected.ok:
		source_selection_status = selected
		return false
	var configured: bool = _configure_selected_roles(selected,"idle")
	# Role installation clears the preview, including its request context.
	# Restore the caller's context on both success and missing-body outcomes.
	_reference_request_context = context.duplicate(true)
	if not configured:
		source_selection_status = selected.duplicate(true)
		source_selection_status["status"] = "selection_pending"
		source_selection_status["reason"] = str(reference_bank_status.get("error","current523_source_action_unavailable"))
		if reference_bank_status.has("source_exclusion"):
			source_selection_status["source_exclusion"] = reference_bank_status.source_exclusion.duplicate(true)
		return false
	_reference_card_context = selected.duplicate(true)
	source_selection_status = selected.duplicate(true)
	source_weapon_status = {"requested_weapon_type":selected.source_weapon_type,"state":"current523_explicit_host_primary_source_actions","source_actions":selected.role_actions.duplicate(),"M_client_equivalence_verified":false}
	source_weapon_status["run_status"] = selected.get("run_status",{}).duplicate(true)
	reference_bank_status["purpose"] = "existing_card_consumer"
	reference_bank_status["request_key"] = key
	reference_bank_status["host_policy"] = selected.host_policy
	_load_reference_overlay_bindings(selected)
	return true

func current523_card_matches(key: String, context: Dictionary) -> bool:
	if _reference_bank == null or _reference_card_context.is_empty() or _reference_card_context.get("request_key","") != key or _reference_request_context != context:
		return false
	# The private config can receive a newly connected bank while the character
	# context stays the same. Rebind on the existing owner event when its pin or
	# location changes; do not keep the old bank merely because class/weapon match.
	var configured: Dictionary = CURRENT523_BANK.options(context)
	if not bool(configured.get("ok",false)): return false
	for field: String in ["manifest_path","manifest_sha256","overlay_whitelist_path","overlay_whitelist_sha256"]:
		var selected_value: Variant = _reference_card_context.get(field,"")
		if field.begins_with("overlay_") and _reference_card_context.get("source_bank_context") is Dictionary:
			selected_value = _reference_card_context.source_bank_context.get("current523_source_bank",{}).get(field,selected_value)
		if selected_value != configured.options.get(field,""): return false
	return true

func current523_role_available(role: String) -> bool:
	return _reference_bank != null and not _reference_card_context.is_empty() and installed() and _playback_tracks.has(role)

func source_bank_request_context() -> Dictionary:
	return _reference_request_context.duplicate(true)

func _configure_selected_roles(selected: Dictionary, initial_role: String) -> bool:
	var started: int = FRAME_HITCH.now()
	var configured: bool = _configure_selected_roles_measured(selected,initial_role)
	FRAME_HITCH.detail("source.role_selection",started)
	return configured

func _indexed_optional_roles(selected: Dictionary) -> Dictionary:
	if selected.get("optional_role_actions",{}).is_empty(): return {}
	var actions: Dictionary = selected.role_actions.duplicate()
	var loops: Dictionary = selected.loop_policy.duplicate()
	var role_actors: Dictionary = selected.get("role_actor_ids",{}).duplicate()
	var statuses: Dictionary = {}
	for role: String in selected.optional_role_actions:
		if actions.has(role): continue
		var loop: Variant = selected.get("optional_role_loop_policy",{}).get(role,true if role == "run" else null)
		var actor: Variant = selected.get("optional_role_actor_ids",{}).get(role)
		if not loop is bool or not REFERENCE_BANK.integer(actor,1):
			statuses[role] = {"state":"optional_source_role_contract_missing"}
			continue
		var action: int = int(selected.optional_role_actions[role])
		actions[role] = action
		loops[role] = loop
		role_actors[role] = int(actor)
		statuses[role] = {"state":"selected_source_declared_optional_action","action_id":action,"source_actor_id":int(actor)}
	if actions.size() == selected.role_actions.size() or actions.size() > 16: return {}
	# This is only a preparation strategy check. The same pinned bank loader
	# still admits every actor/action/member and validates the complete result.
	# Missing optional entries use the independent path immediately, avoiding
	# an expensive failed combined read of all otherwise valid core actions.
	var opened: Dictionary = REFERENCE_BANK.MANIFEST_INDEX.open(str(selected.manifest_path),str(selected.manifest_sha256),REFERENCE_BANK.MAX_MANIFEST_JSON,REFERENCE_BANK.valid_sha(selected.manifest_sha256))
	if not opened.get("ok",false): return {}
	var index: RefCounted = opened.index
	if not index.registry_is_dictionary("actors"): return {}
	for role: String in selected.optional_role_actions:
		if selected.role_actions.has(role) or not actions.has(role): continue
		var actor: int = int(role_actors[role])
		var entries: Variant = index.lookup("actors","sprite:"+str(actor))
		if not entries is Dictionary: return {}
		var action: int = int(actions[role])
		var entry: Variant = entries.get(str(action))
		if not entry is Dictionary or entry.get("path") != "actors/%d/action-%d.json" % [actor,action] or not REFERENCE_BANK.valid_sha(entry.get("sha256")): return {}
	return {"actions":actions,"loops":loops,"role_actors":role_actors,"statuses":statuses}

func _configure_selected_roles_measured(selected: Dictionary, initial_role: String) -> bool:
	var candidate: Dictionary = _indexed_optional_roles(selected)
	if not candidate.is_empty():
		FRAME_HITCH.count("source.optional_combined_attempt")
		if _configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),candidate.actions,candidate.loops,initial_role,str(selected.consumer),candidate.role_actors):
			return _finish_selected_roles(selected,true,candidate.actions,candidate.loops,candidate.role_actors,candidate.statuses)
	# Selection/admission belongs to the existing card/NPC caller. Each optional
	# action remains independently admitted after a failed combined attempt,
	# so an unavailable HIT cannot remove a valid RUN.
	var actions: Dictionary = selected.role_actions.duplicate()
	var loops: Dictionary = selected.loop_policy.duplicate()
	var role_actors: Dictionary = selected.get("role_actor_ids",{}).duplicate()
	var optional_status: Dictionary = {}
	for role: String in selected.get("optional_role_actions",{}):
		if actions.has(role): continue
		var loop: Variant = selected.get("optional_role_loop_policy",{}).get(role,true if role == "run" else null)
		var actor: Variant = selected.get("optional_role_actor_ids",{}).get(role)
		if not loop is bool or not REFERENCE_BANK.integer(actor,1):
			optional_status[role] = {"state":"optional_source_role_contract_missing"}
			continue
		var action: int = int(selected.optional_role_actions[role])
		var probe := REFERENCE_BANK.new()
		var probe_started: int = FRAME_HITCH.now()
		var loaded: Dictionary = probe.load_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),{role:action},{role:loop},str(selected.consumer),{role:int(actor)})
		FRAME_HITCH.detail("source.optional_probe",probe_started)
		if not loaded.ok:
			optional_status[role] = {"state":"optional_source_action_unavailable","bank_problem":loaded.get("error","")}
			continue
		actions[role] = action
		loops[role] = loop
		role_actors[role] = int(actor)
		optional_status[role] = {"state":"selected_source_declared_optional_action","action_id":action,"source_actor_id":int(actor)}
	var configured: bool = _configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),actions,loops,initial_role,str(selected.consumer),role_actors)
	if not configured and not optional_status.is_empty():
		var problem: String = str(reference_bank_status.get("error","optional_source_actions_unavailable"))
		for role: String in optional_status:
			optional_status[role] = {"state":"optional_source_action_unavailable","bank_problem":problem}
		actions = selected.role_actions.duplicate()
		loops = selected.loop_policy.duplicate()
		role_actors = selected.get("role_actor_ids",{}).duplicate()
		configured = _configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),actions,loops,initial_role,str(selected.consumer),role_actors)
	return _finish_selected_roles(selected,configured,actions,loops,role_actors,optional_status)

func _finish_selected_roles(selected: Dictionary, configured: bool, actions: Dictionary, loops: Dictionary, role_actors: Dictionary, optional_status: Dictionary) -> bool:
	var run_status: Dictionary = selected.get("run_status",{}).duplicate(true)
	if selected.get("optional_role_actions",{}).has("run"):
		run_status["state"] = "selected_source_declared_run" if configured and actions.has("run") else "source_declared_run_unavailable_existing_walk"
		if optional_status.get("run",{}).has("bank_problem"): run_status["bank_problem"] = optional_status.run.bank_problem
	selected["role_actions"] = actions
	selected["loop_policy"] = loops
	selected["role_actor_ids"] = role_actors
	selected["run_status"] = run_status
	selected["optional_role_status"] = optional_status
	reference_bank_status["run_status"] = run_status.duplicate(true)
	reference_bank_status["optional_role_status"] = optional_status.duplicate(true)
	return configured

func _configure_existing_source(key: String, manifest_path: String, context: Dictionary = {}) -> bool:
	var source_request_key: String = key
	var consumer_kind: String = key.get_slice(":", 0)
	clear()
	if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path): return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not INSTALL.card_manifest_problem(parsed).is_empty(): return false
	var records: Dictionary = parsed.get("records", {})
	_manifest_records = records
	var selection: Dictionary = preload("res://scripts/lineagem_base508.gd").select_visual_key(key, context)
	if not selection.is_empty():
		source_selection_status = selection
		if selection.status != "selected": return false
		key = "sprite:" + str(int(selection.sprite_id))
	if not records.has(key):
		var binding: Dictionary = parsed.get("card_bindings", {}).get(key, {})
		var sprites: Array = binding.get("sprite_ids", [])
		if sprites.size() != 1: return false
		key = "sprite:" + str(int(sprites[0]))
	if not records.has(key): return false
	var candidate: Dictionary = records[key]
	if candidate.has("manifest"):
		var actor_path: String = str(candidate.manifest)
		if actor_path.is_absolute_path() or ".." in actor_path.split("/"): return false
		var actor: Variant = JSON.parse_string(FileAccess.get_file_as_string(INSTALL.resolve_file(manifest_path.get_base_dir(), actor_path)))
		if not actor is Dictionary: return false
		candidate = actor
	var tracks: Dictionary
	_root = manifest_path.get_base_dir()
	_playback_mode = POLICY.mode(_root, playback_mode_override)
	var weapon_selection:Dictionary=WEAPON_BANKS.select(candidate,_root,context,consumer_kind)
	candidate=weapon_selection.record
	source_weapon_status=weapon_selection.status
	tracks = POLICY.tracks(candidate, consumer_kind, _playback_mode)
	reference_exclusion_status = REFERENCE_EXCLUSIONS.apply(candidate, tracks, source_request_key, parsed)
	if not tracks.has("idle"): return false
	var layer_count: int = 0
	for role: String in ["idle", "walk", "run", "attack"]:
		if not tracks.has(role): continue
		var track: Dictionary = tracks[role]
		var directions: Array = track.get("directions", [])
		if directions.size() != 8:
			clear()
			return false
		for frames: Array in directions:
			if frames.is_empty():
				clear()
				return false
			for frame: Dictionary in frames:
				if not bool(track.get("static_pending_timing", false)) and float(frame.get("duration", 0.0)) < 0.0:
					clear()
					return false
				var frame_layers: Array = frame.get("layers", [])
				if frame_layers.is_empty():
					clear()
					return false
				layer_count = maxi(layer_count, frame_layers.size())
				for layer: Dictionary in frame_layers:
					var path: String = str(layer.get("path", ""))
					if path.is_absolute_path() or ".." in path.split("/"):
						clear()
						return false
					if not _textures.has(path):
						var image: Image = Image.load_from_file(INSTALL.resolve_file(_root, path))
						if image == null or image.is_empty():
							clear()
							return false
						_textures[path] = GPU_ACTOR_TEXTURE.from_image(image)
	return _configure_source_nodes(candidate, tracks, layer_count, manifest_path)

func configure_reference_bank(manifest_path: String, expected_manifest_sha: String, source_actor_id: int, explicit_role_action_bindings: Dictionary, caller_loop_policy: Dictionary, initial_role: String) -> bool:
	return _configure_reference_bank(manifest_path,expected_manifest_sha,source_actor_id,explicit_role_action_bindings,caller_loop_policy,initial_role,"")

func _configure_reference_bank(manifest_path: String, expected_manifest_sha: String, source_actor_id: int, explicit_role_action_bindings: Dictionary, caller_loop_policy: Dictionary, initial_role: String, card_consumer: String, role_actor_ids: Dictionary = {}) -> bool:
	var started: int = FRAME_HITCH.now()
	var configured: bool = _configure_reference_bank_measured(manifest_path,expected_manifest_sha,source_actor_id,explicit_role_action_bindings,caller_loop_policy,initial_role,card_consumer,role_actor_ids)
	FRAME_HITCH.detail("source.bank_configure",started)
	return configured

func _configure_reference_bank_measured(manifest_path: String, expected_manifest_sha: String, source_actor_id: int, explicit_role_action_bindings: Dictionary, caller_loop_policy: Dictionary, initial_role: String, card_consumer: String, role_actor_ids: Dictionary = {}) -> bool:
	clear()
	_current523_source_only = not card_consumer.is_empty()
	if not explicit_role_action_bindings.has(initial_role):
		reference_bank_status = {"ok":false,"error":"Explicit initial caller role is required."}
		return false
	var bank := REFERENCE_BANK.new()
	var loaded: Dictionary = bank.load_bank(manifest_path, expected_manifest_sha, source_actor_id, explicit_role_action_bindings, caller_loop_policy,card_consumer,role_actor_ids)
	reference_bank_status = {"ok":loaded.ok,"error":loaded.get("error", ""),"purpose":"diagnostic_reference_preview","source_actor_id":source_actor_id,"manifest_sha256":expected_manifest_sha}
	reference_bank_status["source_dummy_exclusion_policy"] = loaded.get("source_dummy_exclusion_policy")
	reference_bank_status["map_consumer_contract_dependency"] = loaded.get("map_consumer_contract_dependency")
	if loaded.has("source_exclusion"):
		reference_bank_status["source_exclusion"] = loaded.source_exclusion.duplicate(true)
		reference_bank_status["excluded_source_actor_id"] = loaded.excluded_source_actor_id
	if not loaded.ok: return false
	_reference_bank = bank
	_root = manifest_path.get_base_dir()
	_playback_mode = POLICY.mode(_root,playback_mode_override) if not card_consumer.is_empty() else (playback_mode_override if playback_mode_override in ["strict", "compatible"] else "strict")
	# Source FPS remains null when absent. Existing production policy owns only
	# the effective compatibility rate; strict mode holds unresolved actions.
	var tracks: Dictionary = POLICY.tracks(loaded.record,card_consumer,_playback_mode) if not card_consumer.is_empty() else loaded.tracks
	var layer_count: int = 0
	for track: Dictionary in tracks.values():
		for frames: Array in track.directions:
			for frame: Dictionary in frames: layer_count = maxi(layer_count, frame.layers.size())
	_configure_source_nodes(loaded.record, tracks, layer_count, manifest_path)
	_role = initial_role
	return true

func advance_reference_source(delta: float, explicit_role: String, stored_direction: int) -> bool:
	if _reference_bank == null or not _playback_tracks.has(explicit_role) or stored_direction < 0 or stored_direction > 7 or not is_finite(delta) or delta < 0.0: return false
	if explicit_role != _role:
		_role = explicit_role
		_clock = 0.0
	source_facing = stored_direction
	_advance_selected_source(delta, stored_direction)
	return _reference_bank != null

func restart_reference_source(explicit_role: String, sequence: int) -> bool:
	if _reference_bank == null or not _playback_tracks.has(explicit_role): return false
	_role = explicit_role
	_sequence = sequence
	_clock = 0.0
	_source_attack = false
	_attack_completed = false
	_annotation_clock = -0.000000001
	_annotation_track_key = ""
	_reference_overlay_clock = -0.000000001
	_reference_overlay_key = ""
	for child: Node2D in _reference_source_children.values():
		if is_instance_valid(child): child.free()
	_reference_source_children.clear()
	_reference_child_role = ""
	_last_token = ""
	return true

func reference_source_frame_status() -> Dictionary:
	if not _reference_frame_inputs.is_empty():
		_reference_frame_status = _build_reference_frame_status(_reference_frame_inputs)
		_reference_frame_inputs = {}
	return _reference_frame_status.duplicate(true)

func _build_reference_frame_status(inputs: Dictionary) -> Dictionary:
	var shown: Array = []
	for layer: Dictionary in inputs.layers: shown.append(_shown_source_provenance(layer, inputs.attachment))
	var track: Dictionary = inputs.track
	var card: Dictionary = inputs.card
	var overlay: Dictionary = inputs.overlay
	var attachment: Dictionary = inputs.attachment
	return {"purpose":inputs.purpose,"consumer":inputs.consumer,"request_key":card.get("request_key",overlay.get("request_key",attachment.get("request_key",""))),"overlay_parent":overlay.duplicate(true),"attachment_parent":attachment.duplicate(true),"role":inputs.role,"source_action_id":track.source_action_id,"source_action_key":track.source_action_key,"source_actor_id":track.get("source_sprite_id",inputs.record_sprite_id),"source_body_id":track.get("source_body_id"),"selected_identity_actor_id":inputs.record_sprite_id,"stored_direction":inputs.direction,"selected_layers":shown,"actual_observed_original_bytes":null,"whole_file_use":false,"actual_main_game_feature_use":bool(inputs.in_main) and not shown.is_empty(),"M_visual_equivalence_verified":false}

static func _effect_node_key(layer: Dictionary) -> Variant:
	# Only new, explicitly verified DTOs separate ordered source instances.
	# A legacy binding trace alone is not an upgrade to native multiplicity.
	var instance: Variant = layer.get("source_layer_instance_key")
	if instance is String and not instance.is_empty(): return "source_instance:" + instance
	return int(layer.layer_id)

func _configure_source_nodes(candidate: Dictionary, tracks: Dictionary, layer_count: int, manifest_path: String) -> bool:
	# Exact attachment nodes stay linked even while their source blend is unresolved.
	for track: Dictionary in tracks.values():
		for frames: Array in track.directions:
			for frame: Dictionary in frames:
				for effect: Dictionary in frame.get("effect_layers", []):
					var id: int = int(effect.layer_id)
					var node_key: Variant = _effect_node_key(effect)
					if _effect_nodes.has(node_key): continue
					var effect_node: Sprite2D = Sprite2D.new()
					effect_node.name = "SourceAttachment" + str(id)
					if node_key is String:
						effect_node.name += "_Instance" + str(_effect_nodes.size())
						effect_node.set_meta("source_layer_instance_key",effect.source_layer_instance_key)
					effect_node.centered = false
					effect_node.z_index = 1
					var style: Dictionary = POLICY.effect(effect.get("source_attributes", []), _playback_mode)
					if bool(effect.get("source_attributes_unresolved", false)): style = {"enabled":false,"reason":"source_attribute_inheritance_unverified"}
					# Identity-scoped observation candidate; never generalizes attr8/128.
					var observed_girtas: bool = _playback_mode == "compatible" and int(candidate.get("body_id", 0)) == 22258 and id in [22260, 22261] and not "--lineagem-girtas-legacy-blend" in OS.get_cmdline_user_args()
					if observed_girtas:
						style = {"enabled":true,"alpha":1.0,"origin":"Girtas_only_five_M_GIF_pose_observations_exact_equation_unverified"}

					effect_node.set_meta("compatibility_style", style)
					if observed_girtas:
						var copy: BackBufferCopy = BackBufferCopy.new()
						copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
						copy.z_index = 1 if id == 22261 else 2
						add_child(copy)
						effect_node.z_index = copy.z_index
						effect_node.set_meta("observed_backbuffer", copy)
						var shader_material: ShaderMaterial = ShaderMaterial.new()
						shader_material.shader = preload("res://shaders/source_girtas_observed_blend.gdshader")
						shader_material.set_shader_parameter("screen_operation", id == 22260)
						effect_node.material = shader_material
					elif bool(style.get("enabled", false)):
						var material: CanvasItemMaterial = CanvasItemMaterial.new()
						material.blend_mode = int(style.blend_mode)
						effect_node.material = material
						effect_node.modulate.a = float(style.alpha)
					effect_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					effect_node.set_meta("source_layer_id", id)
					effect_node.set_meta("source_attributes", effect.get("source_attributes", []))
					effect_node.set_meta("blend_status", effect.get("blend_status", "unverified"))
					effect_node.hide()
					add_child(effect_node)
					_effect_nodes[node_key] = effect_node
	_record = candidate
	var root_attributes: Array = candidate.get("source_attributes", []).duplicate()
	if root_attributes.is_empty():
		for directive: Dictionary in candidate.get("source_all_declarations", {}).get("directives", []):
			if int(directive.get("code", -1)) == 104: root_attributes.append(str(directive.body))
	_source_body_style = POLICY.effect(root_attributes, _playback_mode) if not root_attributes.is_empty() else {}
	_source_body_material = null
	if bool(_source_body_style.get("enabled", false)):
		_source_body_material = CanvasItemMaterial.new()
		_source_body_material.blend_mode = int(_source_body_style.blend_mode)
	_playback_tracks = tracks
	_manifest_path = manifest_path
	_is_overlay = bool(candidate.get("one_shot_overlay", false))
	for index: int in range(layer_count):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_layers.append(sprite)
	visible = true
	return true

func _prune_source_overlays() -> void:
	# Completed one-shots remain as freed handles until their next owner call.
	# Check validity before converting a handle to the typed Node2D array.
	var live: Array[Node2D] = []
	for overlay: Variant in _overlay_nodes:
		if is_instance_valid(overlay) and overlay is Node2D and not overlay.is_queued_for_deletion():
			live.append(overlay)
	_overlay_nodes = live

func clear() -> void:
	_reference_bank = null
	source_effect_status.clear()
	_reference_card_context.clear()
	_reference_request_context.clear()
	_reference_overlay_parents.clear()
	_reference_overlay_parent.clear()
	_reference_attachment_parent.clear()
	_reference_child_problem.clear()
	for child: Node2D in _reference_source_children.values():
		if is_instance_valid(child): child.free()
	_reference_source_children.clear()
	_reference_child_role = ""
	_reference_overlay_clock = -0.000000001
	_reference_overlay_key = ""
	reference_bank_status.clear()
	_reference_frame_status.clear()
	_reference_frame_inputs = {}
	reference_exclusion_status.clear()
	source_weapon_status.clear()
	_record = {}
	_source_body_style.clear()
	_source_body_material = null
	source_selection_status.clear()
	_playback_tracks.clear()
	_manifest_records.clear()
	_annotation_clock = -0.000000001
	_annotation_track_key = ""
	_is_overlay = false
	for overlay: Variant in _overlay_nodes:
		if is_instance_valid(overlay): overlay.free()
	_overlay_nodes.clear()
	_release_reference_texture_charges()
	_reference_texture_budget = {}
	_last_token = ""
	for effect_node: Sprite2D in _effect_nodes.values():
		var copy: BackBufferCopy = effect_node.get_meta("observed_backbuffer") as BackBufferCopy if effect_node.has_meta("observed_backbuffer") else null
		if copy != null: copy.free()
		effect_node.free()
	_effect_nodes.clear()
	_release_shared_textures()
	_textures.clear()
	for sprite: Sprite2D in _layers:
		sprite.free()
	_layers.clear()
	_role = "idle"
	_clock = 0.0
	_sequence = -1
	_source_attack = false
	_attack_completed = false
	last_source_frame = -1
	hide()

func source_role() -> String:
	return _role

func source_playback_mode() -> String:
	return _playback_mode

func installed() -> bool:
	# Existing renderer-readiness API; this is not a source-bank install/use receipt.
	return not _record.is_empty()

func cancel_source_attack() -> void:
	# Manual movement calls player.cancel_attack every tick, even without an attack.
	# Preserve the locomotion clock in that case.
	if not _source_attack and _role != "attack": return
	_source_attack = false
	_attack_completed = false
	_role = "idle"
	_clock = 0.0

func advance_source(delta: float, state: String, facing: int, sequence: int, gameplay_active: bool) -> void:
	# Diagnostic bank requests still require explicit source dispatch. A typed card
	# request uses this existing host motion clock, without source gameplay events.
	if _reference_bank != null and _reference_card_context.is_empty(): return
	if not installed(): return
	source_facing = facing
	if sequence != _sequence and (gameplay_active or state in ["attack", "recovery"]) and _playback_tracks.has("attack"):
		_sequence = sequence
		_source_attack = true
		_attack_completed = false
		_role = "attack"
		_clock = 0.0
	var requested: String = state if state in ["walk", "run", "hit"] else "idle"
	if _source_attack:
		requested = "attack"
	elif gameplay_active and _attack_completed:
		requested = "attack"
	if requested in ["walk", "run"] and not _playback_tracks.has(requested) and _playback_tracks.has("walk"):
		requested = "walk" # The displayed native action remains WALK, never a fabricated RUN track.
	if not _playback_tracks.has(requested): requested = "idle"
	if requested != _role:
		_role = requested
		_clock = 0.0
		_annotation_clock = -0.000000001
	# Visual inspection maps front bit5 to game S2. Keep this explicit and unapproved.
	var source_direction: int = posmod(facing + 3, 8)
	_advance_selected_source(delta, source_direction)

func _advance_selected_source(delta: float, source_direction: int) -> void:
	var is_reference: bool = _reference_bank != null
	_clock += maxf(0.0, delta)
	var track: Dictionary = _playback_tracks[_role]
	var frames: Array = track.directions[source_direction]
	var static_track: bool = bool(track.get("static_pending_timing", false))
	var total: float = 1.0
	if not static_track:
		total = 0.0
		for item: Dictionary in frames: total += preload("res://scripts/animation/source_presentation_policy.gd").duration(item)
	var time: float = fmod(_clock, total) if bool(track.loop) else minf(_clock, total)
	# Floating boundary tolerance only; never hold a short pose for a render frame.
	var boundary_epsilon: float = 0.000000001 if frames[0].has("presentation_duration") else 0.0
	if bool(track.loop) and total - time <= boundary_epsilon: time = 0.0
	var selected: Dictionary = frames[0] if static_track else frames[-1]
	for item: Dictionary in ([] if static_track else frames):
		if time + boundary_epsilon < preload("res://scripts/animation/source_presentation_policy.gd").duration(item):
			selected = item
			break
		time -= preload("res://scripts/animation/source_presentation_policy.gd").duration(item)
	if (_reference_bank == null or not _reference_card_context.is_empty()) and _role == "attack" and (static_track or _clock >= total):
		_source_attack = false
		_attack_completed = true
	last_source_frame = int(selected.source_frame)
	var token: String = "%s:%d:%d:%d" % [_role, int(selected.source_group), int(selected.source_frame), source_direction]
	# P13 shadow flags come from the body draw, never from the shadow SPR attr.
	var body_attributes: Array = []
	var body_attributes_unresolved: bool = true
	var body_projection_verified: bool = false
	if is_reference:
		for source_layer: Dictionary in selected.layers:
			if source_layer.get("kind", "") == "body":
				var body_input: Dictionary = SP2_COMPOSITOR.attribute_input(source_layer)
				body_attributes = body_input.attributes
				body_attributes_unresolved = body_input.unresolved or (not source_layer.has("source_attributes") and not source_layer.has("source_attribute_projection"))
				var body_projection: Variant = source_layer.get("source_attribute_projection")
				body_projection_verified = body_projection is Dictionary and bool(body_projection.get("ok",false)) and not body_attributes_unresolved
				break
		if _reference_attachment_parent.get("kind", "") == "shadow":
			body_attributes = _reference_attachment_parent.get("parent_draw_attributes", [])
			body_attributes_unresolved = bool(_reference_attachment_parent.get("parent_draw_attributes_unresolved", true))
			body_projection_verified = bool(_reference_attachment_parent.get("parent_draw_projection_verified", false)) and not body_attributes_unresolved
	for effect_node: Sprite2D in _effect_nodes.values(): effect_node.hide()
	for effect: Dictionary in selected.get("effect_layers", []):
		if effect.has("client_null"): continue
		if is_reference:
			var verified: Dictionary = _reference_bank.render_layer(effect, false)
			if not verified.ok:
				_abort_reference_source(verified)
				return
		var node: Sprite2D = _effect_nodes.get(_effect_node_key(effect)) as Sprite2D
		if node == null: continue
		node.set_meta("source_layer_id",int(effect.layer_id))
		node.position = Vector2(float(effect.offset[0]), float(effect.offset[1]))
		node.set_meta("source_pixel_path", INSTALL.resolve_file(_root, str(effect.path)))
		node.set_meta("source_frame", selected.source_frame)
		# Explicit host compatibility, with original attr and strict-mode behavior retained.
		var style: Dictionary = node.get_meta("compatibility_style", {})
		if is_reference:
			var own_input: Dictionary = SP2_COMPOSITOR.attribute_input(effect)
			style = POLICY.effect(own_input.attributes,_playback_mode)
			if own_input.unresolved: style = {"enabled":false,"reason":"source_attribute_inheritance_unverified"}
		var recovered: Dictionary = SP2_COMPOSITOR.style(effect, body_attributes, body_attributes_unresolved, _playback_mode, body_projection_verified) if is_reference else {}
		if bool(style.get("enabled", false)) or not recovered.is_empty():
			if is_reference:
				SP2_COMPOSITOR.reset(node)
				if recovered.is_empty():
					node.material = _blend_material(int(style.get("blend_mode",CanvasItemMaterial.BLEND_MODE_MIX)))
					node.modulate.a = float(style.get("alpha",1.0))
			var texture: Texture2D = _source_texture(effect)
			if texture == null and is_reference: return
			if texture != null:
				node.texture = texture
				if not recovered.is_empty(): SP2_COMPOSITOR.apply(node, recovered)
				node.show()
	if token != _last_token:
		_last_token = token
		var event: Dictionary = {"role":_role,"source_frame":selected.source_frame,"source_group":selected.source_group,"direction":source_direction,"effect_layers":selected.get("effect_layers", [])}
		if not is_reference: native_effect_frame.emit(event)

	if not static_track and not is_reference: _dispatch_annotations(frames, track, total, source_direction)
	if not static_track and is_reference and not _reference_card_context.is_empty(): _dispatch_reference_overlays(frames,track,total,source_direction)
	if _is_overlay and not bool(track.loop) and not static_track and _clock >= total:
		queue_free()
	for index: int in range(_layers.size()):
		_layers[index].visible = index < selected.layers.size()
		if not _layers[index].visible: continue
		var layer: Dictionary = selected.layers[index]
		if layer.has("client_null"):
			_layers[index].hide()
			continue
		if is_reference: SP2_COMPOSITOR.reset(_layers[index])
		var is_body: bool = layer.get("kind") == "body" if is_reference else int(layer.get("layer_id", -1)) == int(_record.get("body_id", _record.get("source_sprite_id", -2)))
		_layers[index].material = _source_body_material if is_body and not is_reference else null
		_layers[index].modulate.a = float(_source_body_style.get("alpha", 1.0)) if is_body and not is_reference and _source_body_material != null else 1.0
		_layers[index].set_meta("source_layer_kind",layer.get("kind","body" if is_body else ""))
		_layers[index].set_meta("source_role_actor_id",track.get("source_sprite_id",_record.get("source_sprite_id",-1)))
		var draw_layer: Dictionary = layer
		if is_reference and is_body and _reference_attachment_parent.get("kind", "") == "shadow":
			draw_layer = layer.duplicate()
			draw_layer["kind"] = "shadow"
		var recovered: Dictionary = SP2_COMPOSITOR.style(draw_layer, body_attributes, body_attributes_unresolved, _playback_mode, body_projection_verified) if is_reference else {}
		var own_input: Dictionary = SP2_COMPOSITOR.attribute_input(layer) if is_reference else {}
		if recovered.is_empty() and is_reference and (not own_input.attributes.is_empty() or own_input.unresolved):
			var style: Dictionary = POLICY.effect(own_input.attributes, _playback_mode)
			if own_input.unresolved or not bool(style.get("enabled", false)):
				_layers[index].hide()
			else:
				_layers[index].material = _blend_material(int(style.blend_mode))
				_layers[index].modulate.a = float(style.alpha)
		_layers[index].set_meta("source_layer_id", int(layer.get("layer_id", -1)))
		var texture: Texture2D = _source_texture(layer)
		if texture == null: return
		_layers[index].texture = texture
		_layers[index].position = Vector2(float(layer.offset[0]), float(layer.offset[1]))
		if not recovered.is_empty(): SP2_COMPOSITOR.apply(_layers[index], recovered)
	if _reference_bank != null:
		var source_children_ready: bool = _advance_reference_children(delta,source_direction,body_attributes,body_attributes_unresolved,body_projection_verified)
		if not source_children_ready and not _reference_texture_budget.is_empty():
			var problem: Dictionary = _reference_child_problem.duplicate(true)
			_abort_reference_source(problem)
			return
		var shown_layers: Array = []
		for index: int in range(selected.layers.size()):
			if _layers[index].visible: shown_layers.append(selected.layers[index])
		for layer: Dictionary in selected.get("effect_layers", []):
			var node: Sprite2D = _effect_nodes.get(_effect_node_key(layer)) as Sprite2D
			if node != null and node.visible: shown_layers.append(layer)
		var card_consumer: bool = not _reference_card_context.is_empty() or not _reference_overlay_parent.is_empty() or not _reference_attachment_parent.is_empty()
		var consumer: String = str(_reference_card_context.get("consumer",_reference_overlay_parent.get("consumer",_reference_attachment_parent.get("consumer",""))))
		var purpose: String = "existing_npc_consumer" if consumer == "npc" else "existing_card_consumer"
		if not _reference_attachment_parent.is_empty(): purpose = "existing_npc_independent_source_layer" if consumer == "npc" else "existing_card_independent_source_layer"
		elif not _reference_overlay_parent.is_empty(): purpose = "existing_npc_source_overlay" if consumer == "npc" else "existing_card_source_overlay"
		elif not card_consumer: purpose = "diagnostic_reference_preview"
		if consumer in ["spell_effect","global_effect","item_effect","invoke_effect"]: purpose = "existing_typed_effect_source_layer" if not _reference_attachment_parent.is_empty() else "existing_typed_source_effect"
		if consumer == "awakening": purpose = "existing_awakening_source_layer" if not _reference_attachment_parent.is_empty() else "existing_enabled_source_awakening"
		var scene: Node = get_tree().current_scene if is_inside_tree() else null
		var in_main: bool = card_consumer and scene != null and scene.scene_file_path == "res://Main.tscn" and scene.is_ancestor_of(self)
		_reference_frame_inputs = {"purpose":purpose,"consumer":consumer,"card":_reference_card_context,"overlay":_reference_overlay_parent,"attachment":_reference_attachment_parent,"role":_role,"track":track,"record_sprite_id":_record.source_sprite_id,"direction":source_direction,"layers":shown_layers,"in_main":in_main}

func _shown_source_provenance(layer: Dictionary, attachment: Dictionary) -> Dictionary:
	var provenance: Dictionary = layer.frame_provenance.duplicate(true)
	var instance: Variant = layer.get("source_layer_instance_key")
	if instance is String and not instance.is_empty():
		provenance["source_layer_instance_key"] = instance
	if attachment.has("source_binding_id"):
		provenance["parent_source_binding_id"] = attachment.source_binding_id
		provenance["parent_reference_instance_ids"] = attachment.get("reference_instance_ids",[]).duplicate()
		provenance["parent_source_reference_instances"] = attachment.get("source_reference_instances",[]).duplicate(true)
		provenance["native_reference_multiplicity_verified"] = false
	return provenance

func _advance_reference_children(delta: float, stored_direction: int, parent_attributes: Array = [], parent_unresolved: bool = true, parent_projection_verified: bool = false) -> bool:
	var lineage: Dictionary = _reference_card_context if not _reference_card_context.is_empty() else (_reference_attachment_parent if not _reference_attachment_parent.is_empty() else _reference_overlay_parent)
	if lineage.is_empty(): return true
	_reference_child_problem.clear()
	var ready: bool = true
	if _reference_child_role != _role:
		for child: Node2D in _reference_source_children.values():
			if is_instance_valid(child): child.free()
		_reference_source_children.clear()
		_reference_child_role = _role
	var ancestors: Array = lineage.get("ancestor_actor_ids",[]).duplicate()
	ancestors.append(int(_record.source_sprite_id))
	var active_parent_actor: int = int(_playback_tracks[_role].get("source_sprite_id",_record.source_sprite_id))
	if not active_parent_actor in ancestors: ancestors.append(active_parent_actor)
	if ancestors.size() >= 16:
		_reference_child_problem = {"ok":false,"error":"Independent source layer ancestry exceeds the bounded source contract."}
		return false
	for attachment: Dictionary in _record.get("independent_source_layers",{}).get(_role,[]):
		if int(attachment.target_sprite_id) in ancestors:
			_reference_child_problem = {"ok":false,"error":"Independent source layer ancestry contains a cycle."}
			ready = false
			continue
		var key: String = "%s:%d:%d:%d:%s" % [str(attachment.kind),int(attachment.from_sprite_id),int(attachment.target_sprite_id),int(attachment.child_action_id),str(attachment.get("source_binding_id",""))]
		var child: Variant = _reference_source_children.get(key)
		if child == null:
			child = get_script().new()
			child.playback_mode_override = _playback_mode
			add_child(child)
			if not child._configure_reference_bank(_manifest_path,str(lineage.get("manifest_sha256","")),int(attachment.target_sprite_id),{"source_layer":int(attachment.child_action_id)},{"source_layer":bool(_playback_tracks[_role].loop)},"source_layer","overlay") or child._playback_tracks.source_layer.get("source_action_key","") != attachment.child_source_action_key:
				_reference_child_problem = child.reference_bank_status.duplicate(true)
				_reference_child_problem["ok"] = false
				if str(_reference_child_problem.get("error","")).is_empty(): _reference_child_problem["error"] = "Independent source layer action identity differs."
				ready = false
				child.free()
				continue
			child._reference_texture_budget = _reference_texture_budget
			child._reference_attachment_parent = {"request_key":lineage.get("request_key",""),"consumer":lineage.get("consumer",""),"manifest_sha256":lineage.get("manifest_sha256",""),"ancestor_actor_ids":ancestors.duplicate(),"kind":attachment.kind,"source_actor_id":active_parent_actor,"source_action_id":_playback_tracks[_role].source_action_id,"source_declaration":attachment.source_declaration.duplicate(true),"host_policy":attachment.dispatch_policy}
			if attachment.has("source_binding_id"):
				child._reference_attachment_parent["source_binding_id"] = attachment.source_binding_id
				child._reference_attachment_parent["reference_instance_ids"] = attachment.get("reference_instance_ids",[]).duplicate()
				child._reference_attachment_parent["source_reference_instances"] = attachment.get("source_reference_instances",[]).duplicate(true)
				child._reference_attachment_parent["native_reference_multiplicity_verified"] = false
			child.z_index = -1 if attachment.kind == "shadow" else 1
			_reference_source_children[key] = child
		child._reference_attachment_parent["parent_draw_attributes"] = parent_attributes.duplicate()
		child._reference_attachment_parent["parent_draw_attributes_unresolved"] = parent_unresolved
		child._reference_attachment_parent["parent_draw_projection_verified"] = parent_projection_verified
		# This advances the child's own source tokens/FPS, independently of the
		# parent's selected token index. Only the explicit host role starts it.
		if not child.advance_reference_source(delta,"source_layer",stored_direction):
			_reference_child_problem = child.reference_bank_status.duplicate(true)
			_reference_child_problem["ok"] = false
			if str(_reference_child_problem.get("error","")).is_empty(): _reference_child_problem["error"] = "Independent source layer frame is unavailable."
			ready = false
	return ready

func _release_reference_texture_charges() -> void:
	var released: int = 0
	for charge: Variant in _reference_texture_charges.values(): released += int(charge)
	if not _reference_texture_budget.is_empty():
		_reference_texture_budget["used"] = maxi(0,int(_reference_texture_budget.get("used",0))-released)
	_reference_texture_charges.clear()

func _release_shared_textures() -> void:
	for key: String in _texture_leases:
		SHARED_ASSETS.release("texture", str(_texture_leases[key]), _asset_owner)
	_texture_leases.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_reference_texture_charges()
		_release_shared_textures()

func _abort_reference_source(problem: Dictionary) -> void:
	var one_shot: bool = _is_overlay
	clear()
	reference_bank_status = problem
	if one_shot and is_inside_tree(): queue_free()

func _source_texture(layer: Dictionary) -> Texture2D:
	var key: String = str(layer.get("texture_key", layer.get("path", "")))
	if _reference_bank != null:
		var member: String = str(layer.get("member", ""))
		var shared_key: String = ""
		if not _textures.has(key):
			shared_key = SHARED_ASSETS.rendered_key(_reference_bank.parsed_asset_key(member),int(layer.get("group_bit",-1)),int(layer.get("frame_index",-1)))
		# Per-actor admission, pins and member bytes are always rechecked here;
		# pixels are only decoded when no identical shared frame exists.
		var need_pixels: bool = not _textures.has(key) and not SHARED_ASSETS.has_entry("texture",shared_key)
		var result: Dictionary = _reference_bank.render_layer(layer, need_pixels)
		if not result.ok:
			_abort_reference_source(result)
			return null
		if not _textures.has(key):
			# The key the bank verified on this very call decides sharing.
			var verified_key: String = SHARED_ASSETS.rendered_key(_reference_bank.parsed_asset_key(member),int(layer.get("group_bit",-1)),int(layer.get("frame_index",-1)))
			var shared: bool = not need_pixels and verified_key == shared_key and SHARED_ASSETS.has_entry("texture",verified_key)
			if not shared and not result.has("image"):
				result = _reference_bank.render_layer(layer, true)
				if not result.ok:
					_abort_reference_source(result)
					return null
			var charge: int = SHARED_ASSETS.entry_bytes("texture",verified_key) if shared else int(result.image.get_width())*int(result.image.get_height())*4
			var used: int = int(_reference_texture_budget.get("used",0))
			var limit: int = int(_reference_texture_budget.get("limit",0))
			if limit > 0 and charge > limit-used:
				var problem: Dictionary = {"ok":false,"reason":"source_texture_budget_exceeded","error":"Source effect texture cache would exceed its shared owner budget.","texture_budget_limit_bytes":limit,"texture_budget_used_bytes":used,"texture_allocation_bytes":charge}
				_abort_reference_source(problem)
				return null
			var texture: Texture2D = SHARED_ASSETS.acquire("texture",verified_key,_asset_owner) as Texture2D if shared else null
			if texture == null and not result.has("image"):
				result = _reference_bank.render_layer(layer, true)
				if not result.ok:
					_abort_reference_source(result)
					return null
			if texture == null:
				var reservation: int = SHARED_ASSETS.reserve("texture",verified_key,charge)
				var upload_started: int = FRAME_HITCH.now()
				texture = ImageTexture.create_from_image(result.image)
				# API elapsed time, not a GPU-completion fence.
				FRAME_HITCH.detail("sp2.texture_create", upload_started)
				if texture == null:
					SHARED_ASSETS.cancel(reservation)
					_abort_reference_source({"ok":false,"error":"Source effect texture allocation failed."})
					return null
				FRAME_HITCH.count("sp2.texture_created")
				texture = SHARED_ASSETS.complete(reservation,texture,charge,_asset_owner) as Texture2D
			if SHARED_ASSETS.holds("texture",verified_key,_asset_owner): _texture_leases[key] = verified_key
			_textures[key] = texture
			if not _reference_texture_budget.is_empty():
				_reference_texture_budget["used"] = used+charge
				_reference_texture_charges[key] = charge
	elif not _textures.has(key):
		var image: Image = Image.load_from_file(INSTALL.resolve_file(_root, str(layer.path)))
		if image != null and not image.is_empty(): _textures[key] = ImageTexture.create_from_image(image)
	return _textures.get(key) as Texture2D

func attachment_status() -> Dictionary:
	var active: int = 0
	for node: Sprite2D in _effect_nodes.values():
		if bool(node.get_meta("compatibility_style", {}).get("enabled", false)): active += 1
	var pending: int = 0
	var origins: Dictionary = {}
	var presentation_observations: Array = []
	var compositors: Array = []
	var source_nodes: Array = _layers.duplicate()
	source_nodes.append_array(_effect_nodes.values())
	for node: Sprite2D in source_nodes:
		if node.visible and node.has_meta("source_compositor"):
			var entry: Dictionary = {"layer_id":node.get_meta("source_layer_id",-1),"style":node.get_meta("source_compositor").duplicate()}
			if node.has_meta("source_layer_instance_key"):entry["source_layer_instance_key"] = node.get_meta("source_layer_instance_key")
			compositors.append(entry)
	for track: Dictionary in _playback_tracks.values():
		if bool(track.static_pending_timing): pending += 1
		origins[str(track.timing_origin)] = int(origins.get(str(track.timing_origin), 0)) + 1
		if track.has("presentation_observation"): presentation_observations.append(track.presentation_observation.duplicate(true))
	return {"recovered_source_compositors":compositors,"source_layer_nodes":_effect_nodes.size(),"active_compatibility_layers":active,"mode":_playback_mode,"unresolved_tracks":pending,"timing_origins":origins,"M_visual_equivalence_verified":false,"native_pixels":true,"presentation_observations":presentation_observations,"user_reference_exclusions":reference_exclusion_status.duplicate(true),"source_weapon_selection":source_weapon_status.duplicate(true)}

## One read-only CanvasItemMaterial per blend mode, shared by every reference
## layer (a new material per layer per frame used to be allocated here).
static var _blend_materials: Dictionary = {}
static func _blend_material(blend_mode: int) -> CanvasItemMaterial:
	var material: CanvasItemMaterial = _blend_materials.get(blend_mode) as CanvasItemMaterial
	if material == null:
		material = CanvasItemMaterial.new()
		material.blend_mode = blend_mode
		_blend_materials[blend_mode] = material
	return material

static var _target_pattern: RegEx = null
static func _overlay_target_pattern() -> RegEx:
	if _target_pattern == null:
		_target_pattern = RegEx.new()
		_target_pattern.compile("\\](\\d+)")
	return _target_pattern

func _init() -> void:
	native_annotations.connect(_on_source_annotation)

func _process(delta: float) -> void:
	if _is_overlay:
		if _reference_bank != null: advance_reference_source(delta,"idle",_overlay_facing)
		else: advance_source(delta, "idle", _overlay_facing, 0, false)

func _load_reference_overlay_bindings(selection: Dictionary) -> void:
	_reference_overlay_parents.clear()
	var path: String = str(selection.get("overlay_whitelist_path",""))
	if path.is_empty(): return
	var expected: String = str(selection.get("overlay_whitelist_sha256",""))
	if not REFERENCE_BANK.valid_sha(expected) or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != expected:
		reference_bank_status["overlay_status"] = "normal_visual_whitelist_missing_or_changed"
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("schema") != 1 or value.get("source_snapshot") != "patch523" or not value.get("parents") is Dictionary:
		reference_bank_status["overlay_status"] = "normal_visual_whitelist_invalid"
		return
	_reference_overlay_parents = value.parents.duplicate(true)
	reference_bank_status["overlay_status"] = "explicit_normal_visual_source_token_whitelist"

func _dispatch_reference_overlays(frames: Array, track: Dictionary, total: float, direction: int) -> void:
	if _playback_mode != "compatible" or _reference_overlay_parents.is_empty() or _is_overlay: return
	var parent_key: String = "%d:%d" % [int(track.get("source_sprite_id",_record.source_sprite_id)),int(track.source_action_id)]
	var allowed: Variant = _reference_overlay_parents.get(parent_key,{})
	if not allowed is Dictionary or allowed.is_empty(): return
	var clock_key: String = _role + (":" + str(_sequence) if _role == "attack" else "")
	if clock_key != _reference_overlay_key:
		_reference_overlay_key = clock_key
		_reference_overlay_clock = -0.000000001
	var end: float = _clock if bool(track.loop) else minf(_clock,total)
	if end < _reference_overlay_clock: _reference_overlay_clock = -0.000000001
	var first_cycle: int = maxi(0,int(floor(maxf(0.0,_reference_overlay_clock)/total))) if bool(track.loop) else 0
	var last_cycle: int = int(floor(end/total)) if bool(track.loop) else 0
	var target_pattern: RegEx = _overlay_target_pattern()
	for cycle: int in range(first_cycle,last_cycle+1):
		var boundary: float = float(cycle)*total
		for token_index: int in range(frames.size()):
			if boundary > _reference_overlay_clock and boundary <= end:
				var bindings: Variant = allowed.get(str(token_index),[])
				if bindings is Array:
					for binding: Variant in bindings:
						if not binding is Dictionary or binding.get("classification") != "normal_visual" or binding.get("source_action_key") != track.source_action_key or not REFERENCE_BANK.integer(binding.get("target_sprite_id"),1) or not REFERENCE_BANK.integer(binding.get("child_action_id")): continue
						var literal_target: bool = false
						for annotation: Dictionary in track.get("source_annotations",[]):
							if int(annotation.get("token_index",-1)) != token_index: continue
							for match_value: RegExMatch in target_pattern.search_all(str(annotation.get("raw",""))):
								if int(match_value.get_string(1)) == int(binding.target_sprite_id): literal_target = true
						if literal_target: _spawn_reference_overlay(binding,track,token_index,direction)
			boundary += preload("res://scripts/animation/source_presentation_policy.gd").duration(frames[token_index])
	_reference_overlay_clock = end

func _spawn_reference_overlay(binding: Dictionary, parent_track: Dictionary, token_index: int, stored_direction: int) -> bool:
	# Existing ]SpriteID host compatibility: one supplied action, snapshotted anchor
	# and stored facing, one shot. No native signal, sound, damage or nested dispatch.
	var overlay = get_script().new()
	overlay.playback_mode_override = _playback_mode
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(overlay)
	# The source event copies position/direction; the scene parent owns lifetime.
	overlay.set_as_top_level(true)
	if not overlay._configure_reference_bank(_manifest_path,str(_reference_card_context.manifest_sha256),int(binding.target_sprite_id),{"idle":int(binding.child_action_id)},{"idle":false},"idle","overlay"):
		overlay.free()
		return false
	overlay._reference_texture_budget = _reference_texture_budget
	if binding.has("child_source_action_key") and overlay._playback_tracks.idle.get("source_action_key","") != binding.child_source_action_key:
		overlay.free()
		return false
	var source_parent_actor: int = int(parent_track.get("source_sprite_id",_record.source_sprite_id))
	var ancestors: Array = [int(_record.source_sprite_id)]
	if not source_parent_actor in ancestors: ancestors.append(source_parent_actor)
	overlay._reference_overlay_parent = {"request_key":_reference_card_context.request_key,"consumer":_reference_card_context.get("consumer",""),"manifest_sha256":_reference_card_context.manifest_sha256,"ancestor_actor_ids":ancestors,"source_actor_id":source_parent_actor,"source_action_id":parent_track.source_action_id,"source_action_key":parent_track.source_action_key,"source_token_index":token_index,"host_policy":"existing_bracket_sprite_single_action_visual_only"}
	overlay._is_overlay = true
	overlay._overlay_facing = stored_direction
	overlay.global_position = global_position
	overlay.z_index = 2
	_prune_source_overlays()
	_overlay_nodes.append(overlay)
	overlay.advance_reference_source(0.0,"idle",stored_direction)
	return true

func _dispatch_annotations(frames: Array, track: Dictionary, total: float, direction: int) -> void:
	var key: String = _role + (":" + str(_sequence) if _role == "attack" else "")
	if key != _annotation_track_key:
		_annotation_track_key = key
		_annotation_clock = -0.000000001
	var end: float = _clock if bool(track.loop) else minf(_clock, total)
	if end < _annotation_clock: _annotation_clock = -0.000000001
	var first_cycle: int = maxi(0, int(floor(maxf(0.0, _annotation_clock) / total))) if bool(track.loop) else 0
	var last_cycle: int = int(floor(end / total)) if bool(track.loop) else 0
	for cycle: int in range(first_cycle, last_cycle + 1):
		var boundary: float = float(cycle) * total
		for token_index: int in range(frames.size()):
			var frame: Dictionary = frames[token_index]
			if boundary > _annotation_clock and boundary <= end:
				for annotation: Dictionary in frame.get("source_annotations", []):
					native_annotations.emit({"role":_role,"token_index":token_index,"source_group":frame.source_group,"source_frame":frame.source_frame,"source_time":boundary,"direction":direction,"annotation":annotation,"playback_mode":_playback_mode})
			boundary += preload("res://scripts/animation/source_presentation_policy.gd").duration(frame)
	_annotation_clock = end

func _on_source_annotation(event: Dictionary) -> void:
	if _playback_mode != "compatible" or _is_overlay: return
	var regex: RegEx = _overlay_target_pattern()
	for match_value: RegExMatch in regex.search_all(str(event.annotation.get("raw", ""))):
		var target_id: int = int(match_value.get_string(1))
		if REFERENCE_EXCLUSIONS.event_excluded(reference_exclusion_status, event, target_id): continue
		spawn_source_overlay(target_id, posmod(int(event.direction) - 3, 8))

func spawn_source_overlay(sprite_id: int, facing: int, world_point: Vector2 = Vector2.INF) -> bool:
	if current523_source_only_presentation():
		source_effect_status = {"ok":false,"status":"source_only_pending","reason":"current523_typed_effect_reference_required","legacy_media_fallback_allowed":false}
		return false
	var ancestor: Node = self
	while ancestor!=null:
		if ancestor.has_method("presentation_effect_manifest"):
			var path: String = str(ancestor.call("presentation_effect_manifest",sprite_id))
			if not path.is_empty() and FileAccess.file_exists(path):
				var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
				if index is Dictionary and index.get("records") is Dictionary:
					var old_path: String = _manifest_path
					var old_records: Dictionary = _manifest_records
					var old_mode: String = _playback_mode
					_manifest_path = path
					_manifest_records = index.get("records",{})
					_playback_mode = "compatible" # Explicit per-effect opt-in; actor mode is restored.
					var shown: bool = _spawn_source_overlay(sprite_id,facing,world_point)
					_manifest_path = old_path
					_manifest_records = old_records
					_playback_mode = old_mode
					if shown: return true
			break
		ancestor = ancestor.get_parent()
	return _spawn_source_overlay(sprite_id,facing,world_point)

func _spawn_source_overlay(sprite_id: int, facing: int, world_point: Vector2 = Vector2.INF) -> bool:
	if _playback_mode != "compatible" or not _manifest_records.has("overlay:" + str(sprite_id)): return false
	var selected_id: int = sprite_id
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.has_method("select_source_presentation_effect"):
			selected_id = int(ancestor.call("select_source_presentation_effect",sprite_id,_manifest_records))
			break
		ancestor = ancestor.get_parent()
	if selected_id != sprite_id and not _overlay_files_available(selected_id,sprite_id): selected_id = sprite_id
	var overlay = get_script().new()
	overlay.playback_mode_override = _playback_mode
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(overlay)
	overlay.global_position = global_position if not world_point.is_finite() else world_point
	if not overlay.configure("overlay:" + str(selected_id), _manifest_path):
		if selected_id == sprite_id or not overlay.configure("overlay:" + str(sprite_id), _manifest_path):
			overlay.free()
			return false
		selected_id = sprite_id
	overlay.set_meta("requested_source_effect",sprite_id)
	overlay.set_meta("selected_source_effect",selected_id)
	overlay._overlay_facing = facing
	overlay.z_index = 2
	_prune_source_overlays()
	_overlay_nodes.append(overlay)
	overlay.advance_source(0.0, "idle", facing, 0, false)
	return true

func _overlay_record(sprite_id: int) -> Dictionary:
	var candidate: Variant = _manifest_records.get("overlay:" + str(sprite_id),{})
	if not candidate is Dictionary or candidate.is_empty(): return {}
	if candidate.has("manifest"):
		var relative: String = str(candidate.manifest)
		if not INSTALL.safe_relative(relative): return {}
		var path: String = INSTALL.resolve_file(_manifest_path.get_base_dir(),relative)
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length()>8*1024*1024: return {}
		file.close()
		candidate = JSON.parse_string(FileAccess.get_file_as_string(path))
	return candidate if candidate is Dictionary else {}

func _overlay_files_available(sprite_id: int, original_id: int = -1) -> bool:
	var candidate: Variant = _overlay_record(sprite_id)
	if not candidate is Dictionary: return false
	var identity: Variant = candidate.get("source_sprite_id")
	if not (identity is int or identity is float) or float(identity)!=float(sprite_id): return false
	if not candidate.get("one_shot_overlay") is bool or candidate.get("one_shot_overlay") != true: return false
	var missing: Variant = candidate.get("source_missing_attachments",[])
	if not (missing is Array or missing is Dictionary) or not missing.is_empty(): return false
	if bool(candidate.get("card_skill_partial_overlay",false)): return false
	var tracks: Variant = candidate.get("tracks",{})
	if not tracks is Dictionary: return false
	var idle: Variant = tracks.get("idle",{})
	if not idle is Dictionary: return false
	if original_id >= 0:
		var original: Dictionary = _overlay_record(original_id)
		var original_tracks: Variant = original.get("tracks",{})
		if not original_tracks is Dictionary: return false
		var original_idle: Variant = original_tracks.get("idle",{})
		if not original_idle is Dictionary: return false
		var action: int = int(idle.get("source_action_id",-1))
		if action < 0 or action != int(original_idle.get("source_action_id",-2)): return false
	var directions: Variant = idle.get("directions",[])
	if not directions is Array or directions.size()!=8: return false
	for frames: Variant in directions:
		if not frames is Array or frames.is_empty(): return false
		for frame: Variant in frames:
			if not frame is Dictionary: return false
			var layers: Variant = frame.get("layers",[])
			var effects: Variant = frame.get("effect_layers",[])
			if not layers is Array or layers.is_empty() or not effects is Array: return false
			for layer: Variant in layers + effects:
				if not layer is Dictionary: return false
				var relative: String = str(layer.get("path",""))
				if not INSTALL.safe_relative(relative) or not FileAccess.file_exists(INSTALL.resolve_file(_manifest_path.get_base_dir(),relative)): return false
	return true

func notify_source_global_event(event_name: String, facing: int) -> bool:
	source_effect_status.clear()
	# ConstantData identifies the resource. Local apply-event placement and an
	# unspecified clock remain labelled compatibility, never recovered M semantics.
	# A missing body has no resolved playback mode. Let the typed effect load
	# its own pinned bank policy; the effect factory still enforces strict mode.
	if _playback_mode != "compatible" and not current523_source_only_presentation(): return false
	var definition: Dictionary = {}
	if not current523_source_only_presentation() and not _manifest_path.is_empty() and FileAccess.file_exists(_manifest_path):
		var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(_manifest_path))
		if INSTALL.card_manifest_problem(index).is_empty():
			definition = index.get("source_global_effects", {}).get(event_name, {})
			if definition.get("source_table", "") == "ConstantData" and spawn_source_overlay(int(definition.get("sprite_id", 0)), facing): return true
	var context: Dictionary = _reference_request_context.duplicate(true)
	context["current523_card_context"] = _reference_card_context.duplicate(true)
	var selected: Dictionary = CURRENT523_EFFECT.select_global(event_name,definition,context)
	return _spawn_current523_source_effect(selected,Vector2.INF,facing)

func notify_source_spell_event(source_spell_id: int, stage: String, world_point: Vector2, facing: int, manifest_path: String = "") -> bool:
	source_effect_status.clear()
	if current523_source_only_presentation():
		source_effect_status = {"ok":false,"status":"source_only_pending","reason":"current523_complete_spell_row_required","legacy_media_fallback_allowed":false}
		return false
	# Only an explicit base508 spell identity reaches this adapter; no old-ID/name match.
	var path: String = _manifest_path if manifest_path.is_empty() else manifest_path
	if path.is_empty() or not FileAccess.file_exists(path): return false
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not INSTALL.card_manifest_problem(index).is_empty(): return false
	var row: Dictionary = index.get("source_spell_bindings", {}).get(str(source_spell_id), {})
	if row.is_empty(): return false
	var fields: Dictionary = {"cast":"CasterEffectSpriteID","impact":"EffectExplosionSpriteID","success":"SuccessEffectSpriteID","fail":"FailEffectSpriteID","critical":"CriticalEffectSpriteID","effect":"EffectSpriteID"}
	if not fields.has(stage): return false
	var sprite: int = int(row.get(fields[stage], 0))
	if sprite <= 0: return false
	# An effect request must not replace an installed card's bank, root or clock.
	var previous_path: String = _manifest_path
	var previous_records: Dictionary = _manifest_records
	var previous_root: String = _root
	var previous_mode: String = _playback_mode
	_manifest_path = path
	_manifest_records = index.get("records", {})
	_root = path.get_base_dir()
	_playback_mode = POLICY.mode(_root, playback_mode_override)
	var shown: bool = spawn_source_overlay(sprite, facing, world_point)
	_manifest_path = previous_path
	_manifest_records = previous_records
	_root = previous_root
	_playback_mode = previous_mode
	if shown: return true
	var selected: Dictionary = CURRENT523_EFFECT.select_spell_row(row,stage,"base508",_reference_request_context)
	return _spawn_current523_source_effect(selected,world_point,facing)

func notify_current_source_spell_event(spell: Dictionary, stage: String, world_point: Vector2, facing: int, context: Dictionary = {}) -> bool:
	# The existing spell owner supplies its actual current source row. This API
	# creates presentation only and never admits/casts a spell or applies damage.
	var supplied_context: Dictionary = _reference_request_context.duplicate(true)
	supplied_context.merge(context,true)
	var selected: Dictionary = CURRENT523_EFFECT.select_spell_row(spell,stage,"patch523",supplied_context)
	return _spawn_current523_source_effect(selected,world_point,facing)

func notify_current_source_item_consume(original_item: Dictionary, requested_sprite: int, world_point: Vector2, facing: int, context: Dictionary = {}) -> bool:
	# Called only by the existing item's successful use presentation. Resolve the
	# whole original ItemClass row and its typed consume Bonus, never a Sprite ID
	# coincidence or an instruction to use/consume the item.
	var supplied_context: Dictionary = _reference_request_context.duplicate(true)
	supplied_context.merge(context,true)
	var selected: Dictionary = CURRENT523_EFFECT.select_item_consume(original_item,requested_sprite,supplied_context)
	return _spawn_current523_source_effect(selected,world_point,facing)

func notify_current_source_invoke_effect(original_option: Dictionary, field: String, world_point: Vector2, facing: int, context: Dictionary = {}) -> bool:
	var supplied_context: Dictionary = _reference_request_context.duplicate(true)
	supplied_context.merge(context,true)
	var selected: Dictionary = CURRENT523_EFFECT.select_invoke_effect(original_option,field,supplied_context)
	return _spawn_current523_source_effect(selected,world_point,facing)

func notify_current_source_death_pose(world_point: Vector2, facing: int) -> bool:
	# Keep this detached from the live player's motion/physics lifecycle. The
	# existing death event owns when the copied original pose is requested.
	var request_key: String = str(_reference_card_context.get("request_key",source_selection_status.get("request_key","")))
	var selected: Dictionary = CURRENT523_EFFECT.select_player_death(request_key,_reference_request_context)
	return _spawn_current523_source_effect(selected,world_point,facing,true)

func make_current_source_spell_effect(spell: Dictionary, stage: String, facing: int, context: Dictionary = {}, texture_budget_bytes: int = 0) -> Node2D:
	# The existing owner adopts/positions/advances the returned node. This factory
	# does not parent it, render its first frame or create a gameplay trigger.
	var supplied_context: Dictionary = _reference_request_context.duplicate(true)
	supplied_context.merge(context,true)
	var selected: Dictionary = CURRENT523_EFFECT.select_spell_row(spell,stage,"patch523",supplied_context)
	return _make_selected_current_source_effect(selected,facing,texture_budget_bytes)

func _spawn_current523_source_effect(selected: Dictionary, world_point: Vector2, facing: int, fixed_world_point: bool = false) -> bool:
	var overlay: Variant = _make_selected_current_source_effect(selected,facing)
	if overlay == null: return false
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(overlay)
	# Existing spell/item/invoke callers supply a world-space event snapshot.
	# Only apply events without a point remain attached to their moving owner.
	var world_anchored: bool = fixed_world_point or world_point.is_finite()
	if world_anchored: overlay.set_as_top_level(true)
	overlay.global_position = global_position if not world_point.is_finite() else world_point
	var placement: String = "existing_caller_world_point" if world_anchored else "existing_owner_relative_apply_event"
	overlay._reference_overlay_parent["placement_policy"] = placement
	if not overlay.advance_reference_source(0.0,"idle",overlay._overlay_facing):
		source_effect_status["ok"] = false
		source_effect_status["status"] = "selection_pending"
		source_effect_status["reason"] = str(overlay.reference_bank_status.get("error","current523_source_effect_frame_unavailable"))
		overlay.free()
		return false
	_prune_source_overlays()
	_overlay_nodes.append(overlay)
	source_effect_status["status"] = "configured_existing_source_effect"
	source_effect_status["placement_policy"] = placement
	return true

func _make_selected_current_source_effect(selected: Dictionary, facing: int, texture_budget_bytes: int = 0) -> Node2D:
	source_effect_status = selected.duplicate(true)
	if not bool(selected.get("ok",false)): return null
	if selected.get("source_snapshot") != "patch523" or selected.get("consumer") not in ["spell_effect","global_effect","item_effect","invoke_effect","death_pose"] or not selected.get("source_reference") is Dictionary: return null
	if texture_budget_bytes < 0:
		source_effect_status["ok"] = false
		source_effect_status["status"] = "selection_pending"
		source_effect_status["reason"] = "current523_source_effect_texture_budget_invalid"
		return null
	var overlay = get_script().new()
	overlay.playback_mode_override = playback_mode_override
	if not overlay._configure_reference_bank(str(selected.manifest_path),str(selected.manifest_sha256),int(selected.sprite_id),selected.role_actions,selected.loop_policy,"idle","overlay"):
		source_effect_status["ok"] = false
		source_effect_status["status"] = "selection_pending"
		source_effect_status["reason"] = str(overlay.reference_bank_status.get("error","current523_source_effect_unavailable"))
		overlay.free()
		return null
	if bool(overlay._playback_tracks.idle.get("static_pending_timing",false)):
		source_effect_status["ok"] = false
		source_effect_status["status"] = "selection_pending"
		source_effect_status["reason"] = "strict_source_effect_timing_unresolved"
		overlay.free()
		return null
	var shared_budget: Dictionary = _reference_texture_budget
	if shared_budget.is_empty(): shared_budget = {"limit":texture_budget_bytes,"used":0}
	elif texture_budget_bytes > 0:
		if int(shared_budget.get("used",0)) > texture_budget_bytes:
			source_effect_status["ok"] = false
			source_effect_status["status"] = "selection_pending"
			source_effect_status["reason"] = "current523_shared_texture_budget_already_in_use"
			overlay.free()
			return null
		var current_limit: int = int(shared_budget.get("limit",0))
		if current_limit <= 0 or texture_budget_bytes < current_limit: shared_budget["limit"] = texture_budget_bytes
	overlay._reference_texture_budget = shared_budget
	overlay._reference_request_context = selected.get("source_bank_context",{}).duplicate(true)
	overlay._reference_overlay_parent = {"request_key":selected.request_key,"consumer":selected.consumer,"manifest_sha256":selected.manifest_sha256,"source_snapshot":"patch523","request_source_snapshot":selected.get("request_source_snapshot"),"source_reference":selected.source_reference.duplicate(true),"host_policy":selected.host_policy,"ancestor_actor_ids":[]}
	overlay._is_overlay = true
	overlay._overlay_facing = posmod(facing+3,8)
	overlay.source_facing = overlay._overlay_facing
	overlay.z_index = 2
	source_effect_status["texture_budget_limit_bytes"] = int(shared_budget.get("limit",0))
	source_effect_status["status"] = "configured_unparented_source_effect"
	return overlay
