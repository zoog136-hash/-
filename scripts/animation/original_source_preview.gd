extends Node2D
## Opt-in inspection of literal source pixels. This is NOT an approved compositor.
## No AnimationCatalog overrides, procedural transforms or gameplay hit clocks.
signal native_annotations(event: Dictionary)
signal native_effect_frame(event: Dictionary)
const WEAPON_BANKS=preload("res://scripts/animation/source_weapon_banks.gd")
var source_weapon_status:Dictionary={}
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
const REFERENCE_EXCLUSIONS = preload("res://scripts/animation/source_reference_exclusions.gd")
var reference_exclusion_status: Dictionary = {}
const INSTALL = preload("res://scripts/lineagem_pack_install.gd")
var playback_mode_override: String = ""
var source_selection_status: Dictionary = {}
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
var _textures: Dictionary = {}
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

func configure(key: String, manifest_path: String, context: Dictionary = {}) -> bool:
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
						_textures[path] = ImageTexture.create_from_image(image)
	# Exact attachment nodes stay linked even while their source blend is unresolved.
	for track: Dictionary in tracks.values():
		for frames: Array in track.directions:
			for frame: Dictionary in frames:
				for effect: Dictionary in frame.get("effect_layers", []):
					var id: int = int(effect.layer_id)
					if _effect_nodes.has(id): continue
					var effect_node: Sprite2D = Sprite2D.new()
					effect_node.name = "SourceAttachment" + str(id)
					effect_node.centered = false
					effect_node.z_index = 1
					var style: Dictionary = POLICY.effect(effect.get("source_attributes", []), _playback_mode)
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
					_effect_nodes[id] = effect_node
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

func clear() -> void:
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
	for overlay: Node2D in _overlay_nodes:
		if is_instance_valid(overlay): overlay.free()
	_overlay_nodes.clear()
	_last_token = ""
	for effect_node: Sprite2D in _effect_nodes.values():
		var copy: BackBufferCopy = effect_node.get_meta("observed_backbuffer") as BackBufferCopy if effect_node.has_meta("observed_backbuffer") else null
		if copy != null: copy.free()
		effect_node.free()
	_effect_nodes.clear()
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
	if not installed(): return
	source_facing = facing
	if sequence != _sequence and (gameplay_active or state in ["attack", "recovery"]) and _playback_tracks.has("attack"):
		_sequence = sequence
		_source_attack = true
		_attack_completed = false
		_role = "attack"
		_clock = 0.0
	var requested: String = state if state in ["walk", "run"] else "idle"
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
	_clock += maxf(0.0, delta)
	# Visual inspection maps front bit5 to game S2. Keep this explicit and unapproved.
	var source_direction: int = posmod(facing + 3, 8)
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
	if _role == "attack" and (static_track or _clock >= total):
		_source_attack = false
		_attack_completed = true
	last_source_frame = int(selected.source_frame)
	var token: String = "%s:%d:%d:%d" % [_role, int(selected.source_group), int(selected.source_frame), source_direction]
	for effect_node: Sprite2D in _effect_nodes.values(): effect_node.hide()
	for effect: Dictionary in selected.get("effect_layers", []):
		var node: Sprite2D = _effect_nodes.get(int(effect.layer_id)) as Sprite2D
		if node == null: continue
		node.position = Vector2(float(effect.offset[0]), float(effect.offset[1]))
		node.set_meta("source_pixel_path", INSTALL.resolve_file(_root, str(effect.path)))
		node.set_meta("source_frame", selected.source_frame)
		# Explicit host compatibility, with original attr and strict-mode behavior retained.
		var style: Dictionary = node.get_meta("compatibility_style", {})
		if bool(style.get("enabled", false)):
			var effect_path: String = str(effect.path)
			if not _textures.has(effect_path):
				var image: Image = Image.load_from_file(INSTALL.resolve_file(_root, effect_path))
				if image != null and not image.is_empty(): _textures[effect_path] = ImageTexture.create_from_image(image)
			if _textures.has(effect_path):
				node.texture = _textures[effect_path]
				node.show()
	if token != _last_token:
		_last_token = token
		var event: Dictionary = {"role":_role,"source_frame":selected.source_frame,"source_group":selected.source_group,"direction":source_direction,"effect_layers":selected.get("effect_layers", [])}
		native_effect_frame.emit(event)

	if not static_track: _dispatch_annotations(frames, track, total, source_direction)
	if _is_overlay and not bool(track.loop) and not static_track and _clock >= total:
		queue_free()
	for index: int in range(_layers.size()):
		_layers[index].visible = index < selected.layers.size()
		if not _layers[index].visible: continue
		var layer: Dictionary = selected.layers[index]
		var is_body: bool = int(layer.get("layer_id", -1)) == int(_record.get("body_id", _record.get("source_sprite_id", -2)))
		_layers[index].material = _source_body_material if is_body else null
		_layers[index].modulate.a = float(_source_body_style.get("alpha", 1.0)) if is_body and _source_body_material != null else 1.0
		_layers[index].set_meta("source_layer_id", int(layer.get("layer_id", -1)))
		_layers[index].texture = _textures[str(layer.path)]
		_layers[index].position = Vector2(float(layer.offset[0]), float(layer.offset[1]))

func attachment_status() -> Dictionary:
	var active: int = 0
	for node: Sprite2D in _effect_nodes.values():
		if bool(node.get_meta("compatibility_style", {}).get("enabled", false)): active += 1
	var pending: int = 0
	var origins: Dictionary = {}
	var presentation_observations: Array = []
	for track: Dictionary in _playback_tracks.values():
		if bool(track.static_pending_timing): pending += 1
		origins[str(track.timing_origin)] = int(origins.get(str(track.timing_origin), 0)) + 1
		if track.has("presentation_observation"): presentation_observations.append(track.presentation_observation.duplicate(true))
	return {"source_layer_nodes":_effect_nodes.size(),"active_compatibility_layers":active,"mode":_playback_mode,"unresolved_tracks":pending,"timing_origins":origins,"M_visual_equivalence_verified":false,"native_pixels":true,"presentation_observations":presentation_observations,"user_reference_exclusions":reference_exclusion_status.duplicate(true),"source_weapon_selection":source_weapon_status.duplicate(true)}

func _init() -> void:
	native_annotations.connect(_on_source_annotation)

func _process(delta: float) -> void:
	if _is_overlay: advance_source(delta, "idle", _overlay_facing, 0, false)

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
	var regex: RegEx = RegEx.new()
	regex.compile("\\](\\d+)")
	for match_value: RegExMatch in regex.search_all(str(event.annotation.get("raw", ""))):
		var target_id: int = int(match_value.get_string(1))
		if REFERENCE_EXCLUSIONS.event_excluded(reference_exclusion_status, event, target_id): continue
		spawn_source_overlay(target_id, posmod(int(event.direction) - 3, 8))

func spawn_source_overlay(sprite_id: int, facing: int, world_point: Vector2 = Vector2.INF) -> bool:
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
	_overlay_nodes = _overlay_nodes.filter(func(node: Node2D) -> bool: return is_instance_valid(node))
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
	# ConstantData identifies the resource. Local apply-event placement and an
	# unspecified clock remain labelled compatibility, never recovered M semantics.
	if _playback_mode != "compatible" or _manifest_path.is_empty(): return false
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(_manifest_path))
	if not INSTALL.card_manifest_problem(index).is_empty(): return false
	var definition: Dictionary = index.get("source_global_effects", {}).get(event_name, {})
	if definition.get("source_table", "") != "ConstantData": return false
	return spawn_source_overlay(int(definition.get("sprite_id", 0)), facing)

func notify_source_spell_event(source_spell_id: int, stage: String, world_point: Vector2, facing: int, manifest_path: String = "") -> bool:
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
	_manifest_path = path
	_manifest_records = index.get("records", {})
	_root = path.get_base_dir()
	_playback_mode = POLICY.mode(_root, playback_mode_override)
	return spawn_source_overlay(sprite, facing, world_point)
