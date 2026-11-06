extends Node2D
## Exact transformation identity, with explicitly estimated SP2 pixels/composition.
## Presentation reads motion only; source annotations never reach game callbacks.
const PACK = preload("res://scripts/resources/current523_identity_pack.gd")
const TEXTURE_LIMIT: int = 64
const GPU_ACTOR_TEXTURE = preload("res://scripts/resources/gpu_actor_texture.gd")
var _revision: int = -1
var _options: Dictionary = {}
var _request_key: String = ""
var _context: Dictionary = {}
var _actor: Dictionary = {}
var _textures: Dictionary = {}
var _layers: Array[Sprite2D] = []
var _clock: float = 0.0
var _integrity_clock: float = 0.0
var _sequence: int = -1
var _last_frame_token: String = ""
var _overriding_host: bool = false
var _native_preferred: bool = false
var _state: String = "idle"
var _host_facing: int = 2
var _run_policy: bool = false
var source_role: String = ""
var source_facing: int = -1
var frame_index: int = -1
var problem: String = ""
var label: Label

func _ready() -> void:
	name = "Current523IdentityActor"
	process_priority = 110 # After manual sample and host action-FX presentation.
	label = Label.new()
	label.position = Vector2(0,24)
	label.z_as_relative = false
	label.z_index = 4000
	label.add_theme_font_size_override("font_size",12)
	label.add_theme_color_override("font_color",Color(1.0,0.8,0.35))
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",2)
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color(0.04,0.04,0.04,0.88)
	backdrop.content_margin_left = 4
	backdrop.content_margin_right = 4
	backdrop.content_margin_top = 3
	backdrop.content_margin_bottom = 3
	label.add_theme_stylebox_override("normal",backdrop)
	add_child(label)
	hide()
	_revalidate()

func configure(profile_key: String, context: Dictionary = {}) -> bool:
	if profile_key == _request_key and context == _context and _revision == PACK.revision and not _actor.is_empty():
		return true
	_request_key = profile_key
	_context = context.duplicate(true)
	if not is_node_ready(): return false
	_revalidate()
	return not _actor.is_empty()

func clear() -> void:
	_request_key = ""
	_context.clear()
	_reset_actor()
	problem = ""

func update_context(context: Dictionary) -> void:
	# Equipment updates cannot resurrect a transformation that was cleared.
	if not _request_key.is_empty(): configure(_request_key,context)

func is_player_override_active() -> bool:
	return _overriding_host

func status_details() -> Dictionary:
	var track: Dictionary = _actor.get("roles",{}).get(source_role,{})
	var source_fps: Variant = track.get("fps")
	return {"enabled":bool(_options.get("enabled",false)),"requested_key":_request_key,
		"active":_overriding_host,"loaded":not _actor.is_empty(),"error":problem,
		"source_sprite_id":int(_actor.get("source_sprite_id",-1)),"role":source_role,
		"source_weapon_type":int(_actor.get("source_weapon_type",0)),
		"requested_weapon_type":int(_context.get("source_weapon_type",0)),
		"source_action_id":int(track.get("source_action_id",-1)),
		"source_weapon_policy":str(_actor.get("source_weapon_policy","")),
		"host_state":_state,"host_facing":_host_facing,"source_facing":source_facing,
		"direction_policy":"host_facing_plus_3_mod_8_unverified_M",
		"frame_index":frame_index,"sequence":_sequence,"clock":_clock,
		"fps":float(source_fps) if source_fps != null else float(_options.get("fps",12.0)),
		"fps_policy":"source_explicit" if source_fps != null else "configurable_host_fps",
		"run_policy":"host_RUN_uses_actual_source_WALK" if _run_policy else "",
		"manual_override":_manual_override_active(),"native_pack_preferred":_existing_source_active(),"cached_textures":_textures.size(),
		"estimated":true,"pixel_composition_policy":"523 정체확인 · 픽셀/합성 추정"}

func _reset_actor() -> void:
	_actor.clear()
	_textures.clear()
	_clock = 0.0
	_integrity_clock = 0.0
	_sequence = -1
	source_role = ""
	source_facing = -1
	frame_index = -1
	_last_frame_token = ""
	_native_preferred = false
	for sprite: Sprite2D in _layers: sprite.texture = null
	_suspend()

func _fail(message: String) -> void:
	_reset_actor()
	problem = message

func _revalidate() -> void:
	_reset_actor()
	_options = PACK.options()
	_revision = PACK.revision
	problem = ""
	if _request_key.is_empty() or not bool(_options.get("enabled",false)): return
	if _existing_source_active():
		_native_preferred = true
		return
	var loaded: Dictionary = PACK.load_actor(_request_key,_context)
	if not bool(loaded.get("ok",false)):
		_fail(str(loaded.get("error","523 정체를 확인하지 못했습니다.")))
		return
	var candidate: Variant = loaded.get("actor")
	if not candidate is Dictionary or not candidate.get("roles") is Dictionary:
		_fail("523 정체 재생 역할이 없습니다.")
		return
	var required_roles: Array[String] = ["idle","walk","attack"]
	if candidate.roles.has("run"): required_roles.append("run")
	for role: String in required_roles:
		var track: Variant = candidate.roles.get(role)
		if not track is Dictionary or not track.get("directions") is Array or track.directions.size() != 8:
			_fail("523 정체의 8방향 역할이 완전하지 않습니다: " + role)
			return
		var fps_value: Variant = track.get("fps")
		if fps_value != null and (not (fps_value is int or fps_value is float) or not is_finite(float(fps_value)) or float(fps_value) <= 0.0):
			_fail("523 원문 FPS가 잘못됐습니다: " + role)
			return
		for frames: Variant in track.directions:
			if not frames is Array or frames.is_empty():
				_fail("523 정체의 방향 프레임이 없습니다: " + role)
				return
			var total_ticks: int = 0
			for frame: Variant in frames:
				if not frame is Dictionary or not frame.get("layers") is Array or frame.layers.is_empty():
					_fail("523 원문 프레임/지속시간이 잘못됐습니다: " + role)
					return
				var duration: Variant = frame.get("duration_ticks")
				if not (duration is int or duration is float) or not is_finite(float(duration)) or float(duration) < 0.0 or float(duration) != floorf(float(duration)):
					_fail("523 원문 프레임/지속시간이 잘못됐습니다: " + role)
					return
				total_ticks += int(frame.duration_ticks)
				for layer: Variant in frame.layers:
					if not layer is Dictionary:
						_fail("523 원문 레이어가 잘못됐습니다: " + role)
						return
			if total_ticks <= 0:
				_fail("523 원문 지속시간이 없습니다: " + role)
				return
	var checked: Dictionary = PACK.validate_actor_files(candidate)
	if not bool(checked.get("ok",false)):
		_fail(str(checked.get("error","523 정체 원문이 누락되거나 변경됐습니다.")))
		return
	_actor = candidate.duplicate(true)
	# Activate during our process tick, after the caller finishes its native setup.

func _process(delta: float) -> void:
	# PR217 already owns the installed original actor. Do not replace or revalidate it.
	if _existing_source_active():
		_native_preferred = true
		_suspend()
		return
	if _native_preferred:
		_native_preferred = false
		_revalidate()
	if _revision != PACK.revision: _revalidate()
	if _actor.is_empty():
		_suspend()
		return
	_integrity_clock += maxf(0.0,delta)
	if _integrity_clock >= 0.5:
		_integrity_clock = 0.0
		var checked: Dictionary = PACK.validate_actor_files(_actor)
		if not bool(checked.get("ok",false)):
			_fail(str(checked.get("error","523 정체 파일이 변경돼 기본 표시를 복구합니다.")))
			return
	_advance_host(delta)

func _advance_host(delta: float) -> void:
	var host: Node = get_parent()
	if host == null: return
	var host_motion: Variant = host.get("motion")
	if host_motion == null:
		_suspend()
		return
	advance_motion(delta,str(host_motion.state),int(host_motion.facing8),int(host_motion.sequence),bool(host_motion.active))

func advance_motion(delta: float, state: String, facing: int, sequence: int, gameplay_active: bool) -> void:
	if _existing_source_active():
		_native_preferred = true
		_suspend()
		return
	if _actor.is_empty(): return
	_state = state
	_host_facing = facing
	_run_policy = state == "run" and not _actor.roles.has("run")
	# Only complete source roles are installed. Other states show baseline.
	if state not in ["idle","turn","walk","run","attack","recovery"]:
		_suspend()
		return
	var requested: String = "attack" if gameplay_active or state in ["attack","recovery"] else ("walk" if state in ["walk","run"] else "idle")
	if state == "run" and not gameplay_active and _actor.roles.has("run"): requested = "run"
	if requested != source_role or (requested == "attack" and sequence != _sequence):
		_clock = 0.0
		source_role = requested
	_sequence = sequence
	source_facing = posmod(facing + 3,8) # Existing host inspection mapping; M remains unverified.
	_clock += maxf(0.0,delta)
	var track: Dictionary = _actor.roles[source_role]
	var frames: Array = track.directions[source_facing]
	var fps_value: Variant = track.get("fps")
	var fps: float = float(fps_value) if fps_value != null else float(_options.get("fps",12.0))
	var total_ticks: int = 0
	for frame: Dictionary in frames: total_ticks += int(frame.duration_ticks)
	var ticks: float = _clock * fps
	ticks = fposmod(ticks,float(total_ticks)) if bool(track.get("loop",false)) else minf(ticks,float(total_ticks))
	var selected: int = frames.size()-1
	for index: int in range(frames.size()):
		if ticks < float(frames[index].duration_ticks):
			selected = index
			break
		ticks -= float(frames[index].duration_ticks)
	var token: String = "%s:%d:%d" % [source_role,source_facing,selected]
	if token != _last_frame_token:
		if not _show_frame(frames[selected],selected): return
		_last_frame_token = token
	if _manual_override_active():
		_suspend()
		return
	visible = true
	_overriding_host = true
	_refresh_host()
	var timing: String = "원문 FPS %s" % str(fps) if fps_value != null else "호스트 FPS %s (설정 추정)" % str(fps)
	var run_text: String = " · RUN→원문 WALK (호스트 정책)" if _run_policy else ""
	var weapon_policy: String = str(_actor.get("source_weapon_policy",""))
	var weapon_text: String = " · 무기 %d / 동작 %d" % [int(_actor.get("source_weapon_type",0)),int(track.get("source_action_id",-1))]
	if not weapon_policy.is_empty(): weapon_text += " · " + weapon_policy
	label.text = "523 정체확인 · 픽셀/합성 추정 · sprite %d\n%s · %s%s · 방향/원점 추정%s" % [int(_actor.source_sprite_id),source_role,timing,weapon_text,run_text]

func _show_frame(frame: Dictionary, index: int) -> bool:
	var pending: Array[Dictionary] = []
	for layer: Dictionary in frame.layers:
		var key: String = "%s:%d:%d" % [str(layer.get("member","")),int(layer.get("group_bit",-1)),int(layer.get("frame_index",-1))]
		var entry: Dictionary
		if _textures.has(key):
			entry = _textures[key]
		else:
			var rendered: Dictionary = PACK.render_layer(layer,_options)
			var image_value: Variant = rendered.get("image")
			if not bool(rendered.get("ok",false)) or not image_value is Image or image_value.is_empty():
				_fail(str(rendered.get("error","523 원문 레이어를 그리지 못했습니다.")))
				return false
			entry = {"texture":GPU_ACTOR_TEXTURE.from_image(image_value),"offset":rendered.offset}
			if _textures.size() >= TEXTURE_LIMIT: _textures.erase(_textures.keys()[0])
			_textures[key] = entry
		pending.append({"texture":entry.texture,"offset":entry.offset,"shadow":str(layer.get("kind","")) == "shadow"})
	# Commit only after every selected source layer has rendered successfully.
	while _layers.size() < pending.size():
		var sprite: Sprite2D = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
		_layers.append(sprite)
	var zoom: float = float(_options.get("zoom",1.0))
	var material_value: CanvasItemMaterial = CanvasItemMaterial.new()
	material_value.blend_mode = {"mix":CanvasItemMaterial.BLEND_MODE_MIX,"add":CanvasItemMaterial.BLEND_MODE_ADD,"multiply":CanvasItemMaterial.BLEND_MODE_MUL}.get(str(_options.get("blend","mix")),CanvasItemMaterial.BLEND_MODE_MIX)
	for layer_index: int in range(_layers.size()):
		var sprite: Sprite2D = _layers[layer_index]
		sprite.visible = layer_index < pending.size()
		if not sprite.visible:
			sprite.texture = null
			continue
		var item: Dictionary = pending[layer_index]
		sprite.texture = item.texture
		sprite.position = Vector2(item.offset) * zoom
		sprite.scale = Vector2.ONE * zoom
		sprite.modulate.a = float(_options.get("opacity",1.0))
		sprite.material = material_value
		sprite.z_index = -1 if bool(item.shadow) else 0
	frame_index = index
	return true

func _manual_override_active() -> bool:
	var host: Node = get_parent()
	var sample: Node = host.get_node_or_null("Current523EstimatedWorldPreview") if host != null else null
	return sample != null and sample.is_player_override_active()

func _existing_source_active() -> bool:
	var host: Node = get_parent()
	if host == null or not bool(host.get("transform_active")): return false
	var original: Variant = host.get("original_source_preview")
	return is_instance_valid(original) and original.has_method("installed") and original.installed()

func _suspend() -> void:
	var was_overriding: bool = _overriding_host
	_overriding_host = false
	hide()
	if was_overriding: _refresh_host()

func _refresh_host() -> void:
	var host: Node = get_parent()
	if host != null and host.is_inside_tree() and not host.is_queued_for_deletion() and host.has_method("_refresh_visual_visibility"):
		host._refresh_visual_visibility()

func _exit_tree() -> void:
	_suspend()
