extends Node2D
class_name TwilightOriginalSkillVFX

## Presentation observes motion/contact events. It never schedules damage.
signal phase_started(id: String, phase: String, point: Vector2)
const SPX_BRIDGE = preload("res://scripts/skills/skill_spx_bridge.gd")
const SPX_SHADER = preload("res://assets/effects/source_spx_additive.gdshader")
const ENERGY_SHADER = preload("res://assets/effects/skill_energy.gdshader")
const ELECTRIC = preload("res://scripts/skills/lightning_vfx_art.gd")
const ELECTRIC_SHADER = preload("res://assets/effects/skills/lightning_filament.gdshader")
const LIBRARY = preload("res://scripts/skills/skill_vfx_library.gd")
const MAX_EFFECTS := 160
const MAX_POOL := 160
const MAX_LAYERS := 3
var presets: Dictionary = {}
var live: Array[Dictionary] = []
var available: Array[Dictionary] = []
var persistent: Dictionary = {}
var emitted: int = 0
var retired: int = 0
var dropped: int = 0
var epoch: int = 0
var detail_limit: int = MAX_EFFECTS
var low_detail: bool = false
var use_private_sources: bool = true
var audio_pool: TwilightOriginalSkillAudio
var spx_bridge: TwilightSkillSPXBridge = SPX_BRIDGE.new()
var library: TwilightSkillVFXLibrary = LIBRARY.new()
var spx_pool: Array[AnimatedSprite2D] = []
var layer_pool: Array[Node2D] = []
var spx_material: ShaderMaterial

func _ready() -> void:
	presets = preload("res://scripts/skills/skill_catalog.gd").read_json("vfx.json")
	audio_pool = preload("res://scripts/skills/skill_audio.gd").new()
	add_child(audio_pool)
	spx_material = ShaderMaterial.new()
	spx_material.shader = SPX_SHADER
	set_process(false)

func set_detail(value: String) -> void:
	low_detail = value == "low"
	detail_limit = 64 if low_detail else MAX_EFFECTS

func color_for(id: String) -> Color:
	return Color(str(library.profile_for(id).get("color", "#86c6ec")))

func _source_sprite(id: String, phase: String, point: Vector2) -> Dictionary:
	if not use_private_sources: return {}
	var frames: SpriteFrames = spx_bridge.frames_for(id, phase)
	if frames == null: return {}
	var clip := spx_bridge.clip_for(id, phase)
	var sprite: AnimatedSprite2D = spx_pool.pop_back() if not spx_pool.is_empty() else AnimatedSprite2D.new()
	if sprite.get_parent() == null: add_child(sprite)
	sprite.stop()
	sprite.sprite_frames = frames
	sprite.animation = clip
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	var layout := spx_bridge.layout_for(id, phase)
	var source_offset: Array = layout.get("sprite_offset", [])
	if source_offset.size() == 2:
		sprite.centered = false
		sprite.offset = Vector2(float(source_offset[0]), float(source_offset[1]))
	sprite.material = spx_material
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var texture: Texture2D = frames.get_frame_texture(clip, 0)
	var edge := maxf(float(texture.get_width()), float(texture.get_height()))
	sprite.scale = Vector2.ONE * minf(1.0, 260.0 / maxf(1.0, edge))
	sprite.rotation = 0
	sprite.modulate = Color.WHITE
	sprite.global_position = point
	sprite.show()
	sprite.play(clip)
	var ticks := 0.0
	for index: int in range(frames.get_frame_count(clip)): ticks += frames.get_frame_duration(clip, index)
	return {"sprite":sprite, "duration":ticks / maxf(.001, frames.get_animation_speed(clip))}

func _new_layers() -> Node2D:
	var container := Node2D.new()
	for index: int in range(MAX_LAYERS):
		var sprite := AnimatedSprite2D.new()
		sprite.name = ["Body", "Ground", "Flare"][index]
		if index == 1:
			sprite.z_as_relative = false
			sprite.z_index = -1
		elif index == 2: sprite.z_index = 1
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if index == 2:
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			sprite.material = additive
		else:
			var material := ShaderMaterial.new()
			material.shader = ENERGY_SHADER
			sprite.material = material
		container.add_child(sprite)
	add_child(container)
	return container

func _play_layer(container: Node2D, index: int, frames: SpriteFrames, clip: String, opacity: float) -> void:
	var sprite := container.get_child(index) as AnimatedSprite2D
	sprite.stop()
	sprite.sprite_frames = frames
	sprite.animation = clip
	sprite.modulate = Color(1, 1, 1, opacity)
	sprite.position = Vector2.ZERO
	sprite.rotation = 0
	sprite.scale = Vector2.ONE
	sprite.offset = Vector2.ZERO
	if sprite.material is ShaderMaterial:
		sprite.material.shader = ENERGY_SHADER
		sprite.material.set_shader_parameter("dissolve", 0.0)
		sprite.material.set_shader_parameter("flow", 0.0)
		sprite.material.set_shader_parameter("energy", 1.0)
	sprite.show()
	sprite.play(clip)

func _authored(id: String, phase: String, point: Vector2, end: Vector2, context: Dictionary) -> Dictionary:
	var entry := library.acquire(id)
	if entry.is_empty(): return {}
	var frames: SpriteFrames = entry.frames
	if not frames.has_animation(phase):
		library.release(str(entry.key))
		return {}
	var container: Node2D = layer_pool.pop_back() if not layer_pool.is_empty() else _new_layers()
	for child: Node in container.get_children(): child.hide()
	container.global_position = point
	container.rotation = 0
	container.scale = Vector2.ONE * float(entry.profile.get("scale", 1.0))
	container.show()
	var body := container.get_child(0) as AnimatedSprite2D
	var electric_frames: SpriteFrames = entry.get("electric_frames")
	var electric: bool = phase == "impact" and electric_frames != null
	_play_layer(container, 0, electric_frames if electric else frames, phase, .74 if phase == "persistent" else 1.0)
	var frame_callback: Callable = _electric_frame_changed.bind(container)
	if electric:
		body.material.shader = ELECTRIC_SHADER
		if not body.frame_changed.is_connected(frame_callback): body.frame_changed.connect(frame_callback)
	elif body.frame_changed.is_connected(frame_callback):
		body.frame_changed.disconnect(frame_callback)
	var offset: Array = entry.profile.get("impact_offset", [0, 0]) if phase in ["impact", "aftermath"] else entry.profile.get("persistent_offset", [0, -38]) if phase in ["persistent", "end"] else entry.profile.get("cast_body_offset", [0, -38]) if phase == "cast" else entry.profile.get("status_offset", [0, 0]) if phase == "status" else [0, 0]
	body.position = Vector2(float(offset[0]), float(offset[1]))
	var contact: Variant = entry.profile.get("ground_contact_y")
	var ground_point: Vector2 = context.get("ground_point", Vector2.INF)
	if phase in ["impact", "aftermath"] and contact != null and ground_point.is_finite():
		body.position = container.to_local(ground_point) - Vector2(0, float(contact))
	# These atlas tails are ground dust, not a continuation of the directional
	# blade/bolt. Use their painted origin (128px cells), never rotate or stretch
	# the dust with the impact. Coordinates come from vfx_raster_painter.py.
	if phase == "aftermath" and ground_point.is_finite():
		var program: String = str(entry.profile.program)
		var dust_y: float = 26.0 if program in ["firestorm", "meteor", "eruption"] else 27.0 if program in ["lightning", "chain_lightning", "storm_field", "storm_ward", "thunder_stun", "plasma"] else 21.0
		body.position = container.to_local(ground_point) - Vector2(0, dust_y)
	var direction: Vector2 = context.get("direction", Vector2.ZERO)
	if phase in ["travel", "release"] or (phase == "impact" and bool(entry.profile.get("directional", false))):
		if direction.length_squared() > .0001: body.rotation = direction.angle()
	if phase == "travel": body.position = Vector2(-48, 0).rotated(body.rotation)
	if str(entry.profile.program) == "chain_lightning" and phase == "impact" and end.is_finite():
		body.position = container.to_local(point.lerp(end, .5))
		body.rotation = (container.to_local(point) - container.to_local(end)).angle()
		body.scale.x = container.to_local(point).distance_to(container.to_local(end)) / 112.0
	if phase == "cast" and not low_detail:
		_play_layer(container, 1, frames, "ground", .8)
		var ground_offset: Array = entry.profile.get("ground_offset", [0, -40])
		(container.get_child(1) as AnimatedSprite2D).position = Vector2(float(ground_offset[0]), float(ground_offset[1]))
	if phase == "impact" and not low_detail and not electric:
		_play_layer(container, 2, frames, "flare", .8)
		var flare := container.get_child(2) as AnimatedSprite2D
		flare.position = body.position
		flare.rotation = body.rotation
		flare.scale = body.scale
		if str(entry.profile.program) == "chain_lightning":
			flare.position = Vector2.ZERO
			flare.rotation = 0
			flare.scale = Vector2.ONE
	if electric: ELECTRIC.pose(body, container, point, end, ground_point)
	var durations: Array[float] = [_clip_duration(electric_frames if electric else frames, phase), 0.0, 0.0]
	if phase == "cast" and not low_detail: durations[1] = _clip_duration(frames, "ground")
	if phase == "impact" and not low_detail and not electric: durations[2] = _clip_duration(frames, "flare")
	return {"layers":container, "cache_key":entry.key, "duration":durations.max(), "layer_durations":durations}

func _clip_duration(frames: SpriteFrames, phase: String) -> float:
	var seconds := 0.0
	for frame: int in range(frames.get_frame_count(phase)):
		seconds += frames.get_frame_duration(phase, frame) / frames.get_animation_speed(phase)
	return seconds

func emit_skill(id: String, phase: String, point: Vector2, end: Vector2 = Vector2.INF, context: Dictionary = {}) -> void:
	_emit(id, phase, point, end, context)

func _emit(id: String, phase: String, point: Vector2, end: Vector2 = Vector2.INF, context: Dictionary = {}) -> Dictionary:
	if not point.is_finite(): return {}
	# Audio remains at the authoritative event even when the visual pool is full.
	if phase in ["cast", "impact", "status", "resist"] and is_instance_valid(audio_pool): audio_pool.play_skill(id, point, phase)
	phase_started.emit(id, phase, point)
	if live.size() >= detail_limit:
		dropped += 1
		return {}
	var source := _source_sprite(id, phase, point)
	var art := _authored(id, phase, point, end, context) if source.is_empty() else {}
	if source.is_empty() and art.is_empty():
		dropped += 1
		return {}
	var item: Dictionary = available.pop_back() if not available.is_empty() else {}
	item.merge({"id":id, "phase":phase, "point":point, "end":end, "age":0.0,
		"ttl":float(source.get("duration", art.get("duration", .4))),
		"spx_sprite":source.get("sprite", null), "layers":art.get("layers", null),
		"cache_key":art.get("cache_key", ""), "layer_durations":art.get("layer_durations", []), "context":context.duplicate(false)}, true)
	live.append(item)
	var container: Node2D = item.get("layers")
	if is_instance_valid(container) and (container.get_child(0) as AnimatedSprite2D).sprite_frames.has_meta("electric_form"):
		container.set_meta("electric_item", item)
	emitted += 1
	set_process(true)
	return item

func begin_cast(id: String, caster: Node2D, target: Node2D = null) -> void:
	var direction: Vector2 = caster.global_position.direction_to(target.global_position) if is_instance_valid(target) else Vector2.ZERO
	# Prepare/cast use the existing cast anchor; neither delays its motion marker.
	phase_started.emit(id, "prepare", caster.global_position)
	_emit(id, "cast", caster.global_position, Vector2.INF, {"owner":weakref(caster), "direction":direction})

func cancel_cast(id: String) -> void:
	for index: int in range(live.size() - 1, -1, -1):
		if str(live[index].id) == id and str(live[index].phase) in ["prepare", "cast"]: _retire(index)

func flight_options(id: String) -> Dictionary:
	var token: Dictionary = {"epoch":epoch, "started":false}
	return {"visual_step":_flight_step.bind(id, token), "visual_end":_flight_end.bind(token)}

func _flight_step(flight: Dictionary, id: String, token: Dictionary) -> bool:
	if int(token.epoch) != epoch: return false
	var pose := _flight_visual_pose(flight, id, token)
	var direction: Vector2 = pose.direction
	var visual_point: Vector2 = pose.point
	if not bool(token.started):
		token.started = true
		emit_skill(id, "release", flight.origin, Vector2.INF, {"direction":direction})
		if str(flight.kind) != "timed":
			var visual := _emit(id, "travel", visual_point, Vector2.INF, {"direction":direction})
			if not visual.is_empty():
				visual.ttl = INF
				token["item"] = visual
	var item: Dictionary = token.get("item", {})
	if item.is_empty(): return false
	item.point = visual_point
	var layers: Node2D = item.get("layers")
	if is_instance_valid(layers):
		layers.global_position = visual_point
		if direction.length_squared() > .0001:
			var body := layers.get_child(0) as AnimatedSprite2D
			body.rotation = direction.angle()
			body.position = Vector2(-48, 0).rotated(body.rotation)
	return true

func _flight_visual_pose(flight: Dictionary, id: String, token: Dictionary) -> Dictionary:
	var point: Vector2 = flight.position
	var direction: Vector2 = point - (flight.previous as Vector2)
	if str(library.profile_for(id).get("program", "")) == "meteor":
		var target: Node2D = flight.target.get_ref()
		if is_instance_valid(target):
			var end: Vector2 = target.combat_hit_position() if target.has_method("combat_hit_position") else target.global_position + Vector2(0, -24)
			if not token.has("initial_distance"): token.initial_distance = maxf(1, (flight.origin as Vector2).distance_to(end))
			var progress := clampf(1.0 - point.distance_to(end) / float(token.initial_distance), 0, 1)
			# Authored visual drop. The existing flight still owns speed, obstruction,
			# cancellation and the sole impact callback; the final tip is the real target.
			point = end + Vector2(-28, -145) * pow(1.0 - progress, .85)
			direction = point - (token.get("last_visual_point", point - Vector2(28, 145)) as Vector2)
	token["last_visual_point"] = point
	return {"point":point, "direction":direction}

func _flight_end(token: Dictionary) -> void:
	# Flight cancellation is visual only. Successful damage owns the impact cue.
	if int(token.epoch) != epoch: return
	var item: Dictionary = token.get("item", {})
	if item.is_empty(): return
	for index: int in range(live.size() - 1, -1, -1):
		if is_same(live[index], item):
			_retire(index)
			break
	token.erase("item")

func maintain(id: String, node: Node2D, duration: float) -> void:
	if persistent.has(id): remove_persistent(id)
	persistent[id] = {"target":weakref(node), "remaining":duration, "visual":{}, "retry":0.0}
	set_process(true)

func maintain_status(id: String, target: Node2D, kind: String) -> void:
	var property := kind + "_remaining"
	if target.get(property) == null: return
	for existing: Dictionary in live:
		if existing.get("status_target", null) is WeakRef and existing.status_target.get_ref() == target and str(existing.id) == id: return
	var item := _emit(id, "status", target.combat_hit_position())
	if item.is_empty(): return
	item.merge({"ttl":INF, "status_target":weakref(target), "status_property":property, "life_id":target.life_id}, true)
	var layers: Node2D = item.get("layers")
	if is_instance_valid(layers):
		var sprite := layers.get_child(0) as AnimatedSprite2D
		sprite.sprite_frames.set_animation_loop("status", true)

func remove_persistent(id: String) -> void:
	var previous: Dictionary = persistent.get(id, {})
	persistent.erase(id)
	if previous.is_empty(): return
	var item: Dictionary = previous.get("visual", {})
	for index: int in range(live.size() - 1, -1, -1):
		if is_same(live[index], item): _retire(index)
	var target: Node2D = previous.target.get_ref()
	if is_instance_valid(target): emit_skill(id, "end", target.global_position)

func _recycle_source_sprite(item: Dictionary) -> void:
	var sprite: AnimatedSprite2D = item.get("spx_sprite") as AnimatedSprite2D
	if not is_instance_valid(sprite): return
	sprite.stop()
	sprite.hide()
	sprite.sprite_frames = null
	if spx_pool.size() < 32: spx_pool.append(sprite)
	else: sprite.queue_free()

func _retire(index: int) -> void:
	var item: Dictionary = live[index]
	live.remove_at(index)
	_recycle_source_sprite(item)
	var layers: Node2D = item.get("layers") as Node2D
	if is_instance_valid(layers):
		if layers.has_meta("electric_item"): layers.remove_meta("electric_item")
		for child: Node in layers.get_children():
			var sprite := child as AnimatedSprite2D
			sprite.stop()
			sprite.hide()
			sprite.sprite_frames = null
		layers.hide()
		if layer_pool.size() < MAX_POOL: layer_pool.append(layers)
		else: layers.queue_free()
	library.release(str(item.get("cache_key", "")))
	item.clear()
	if available.size() < MAX_POOL: available.append(item)
	retired += 1

func clear() -> void:
	epoch += 1
	if is_instance_valid(audio_pool): audio_pool.clear()
	persistent.clear()
	for index: int in range(live.size() - 1, -1, -1): _retire(index)
	library.trim()
	spx_bridge.cache.clear()
	set_process(false)

func _process(delta: float) -> void:
	for index: int in range(live.size() - 1, -1, -1):
		var item: Dictionary = live[index]
		item.age += delta
		if item.has("status_target"):
			var target: Node2D = item.status_target.get_ref()
			if not is_instance_valid(target) or target.dead or target.life_id != int(item.life_id) or float(target.get(str(item.status_property))) <= 0:
				_retire(index)
				continue
			item.point = target.combat_hit_position()
		var context: Dictionary = item.context
		if context.get("owner", null) is WeakRef:
			var owner: Node2D = context.owner.get_ref()
			if not is_instance_valid(owner):
				_retire(index)
				continue
			item.point = owner.global_position
		var source_sprite: AnimatedSprite2D = item.get("spx_sprite") as AnimatedSprite2D
		if is_instance_valid(source_sprite): source_sprite.global_position = item.point
		var layers: Node2D = item.get("layers") as Node2D
		if is_instance_valid(layers):
			layers.global_position = item.point
			_update_electric_pose(item)
			for layer: int in range(MAX_LAYERS):
				var sprite := layers.get_child(layer) as AnimatedSprite2D
				if not sprite.visible: continue
				var looping := sprite.sprite_frames.get_animation_loop(sprite.animation)
				var length := float(item.layer_durations[layer])
				if not looping and float(item.age) >= length:
					sprite.hide()
					continue
				if sprite.material is ShaderMaterial:
					var progress := 0.0 if looping else float(item.age) / maxf(.001, length)
					sprite.material.set_shader_parameter("dissolve", clampf((progress - .78) / .22, 0, 1) * .8)
					sprite.material.set_shader_parameter("flow", fmod(float(item.age), 1.0))
		if float(item.age) >= float(item.ttl):
			var id := str(item.id)
			var point: Vector2 = item.point
			var phase := str(item.phase)
			var tail_context: Dictionary = item.context.duplicate(false)
			var overflow := float(item.age) - float(item.ttl)
			_retire(index)
			if phase == "impact" and not low_detail:
				var times: Array = library.profile_for(id).get("clips", {}).get("aftermath", {}).get("durations_ms", [])
				var length := 0.0
				for milliseconds: Variant in times: length += float(milliseconds) / 1000.0
				if overflow < length:
					var tail := _emit(id, "aftermath", point, Vector2.INF, tail_context)
					if not tail.is_empty():
						tail.age = overflow
						_seek_layers(tail, overflow)
				else:
					phase_started.emit(id, "aftermath", point)
					phase_started.emit(id, "end", point)
			elif phase in ["impact", "aftermath"]: phase_started.emit(id, "end", point)
	for id: String in persistent.keys():
		var record: Dictionary = persistent[id]
		record.remaining -= delta
		var target: Node2D = record.target.get_ref()
		if float(record.remaining) <= 0 or not is_instance_valid(target):
			remove_persistent(id)
			continue
		var visual: Dictionary = record.visual
		record.retry -= delta
		if visual.is_empty() and float(record.retry) <= 0:
			visual = _emit(id, "persistent", target.global_position)
			record.visual = visual
			record.retry = .5
			if not visual.is_empty(): visual.ttl = INF
		if not visual.is_empty(): visual.point = target.global_position
	if live.is_empty() and persistent.is_empty():
		library.trim()
		spx_bridge.cache.clear()
		set_process(false)

func _electric_frame_changed(container: Node2D) -> void:
	# AnimatedSprite can advance after its parent's _process; anchor the newly
	# selected pixels in the same frame rather than lagging one frame behind.
	if container.has_meta("electric_item"):
		_update_electric_pose(container.get_meta("electric_item"))

func _update_electric_pose(item: Dictionary) -> void:
	var container: Node2D = item.get("layers")
	if not is_instance_valid(container): return
	var body := container.get_child(0) as AnimatedSprite2D
	if body.sprite_frames == null or not body.sprite_frames.has_meta("electric_form"): return
	ELECTRIC.pose(body, container, item.point, item.end, item.context.get("ground_point", Vector2.INF))

func _seek_layers(item: Dictionary, seconds: float) -> void:
	var container: Node2D = item.get("layers") as Node2D
	if not is_instance_valid(container): return
	for sprite: AnimatedSprite2D in container.get_children():
		if sprite.sprite_frames == null or not sprite.visible: continue
		var remaining := seconds
		var frames: SpriteFrames = sprite.sprite_frames
		for frame: int in range(frames.get_frame_count(sprite.animation)):
			var duration := frames.get_frame_duration(sprite.animation, frame) / frames.get_animation_speed(sprite.animation)
			if remaining < duration:
				sprite.set_frame_and_progress(frame, remaining / duration)
				break
			remaining -= duration

	_update_electric_pose(item)
