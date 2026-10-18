extends Node2D
class_name TwilightCombatVFX
signal source_frame_marker(sprite_id: String, source_frame: int)

## One drawing node, bounded reusable records. No per-hit nodes, tweens or RNG.
const CAPACITY: int = 160
const VISUALS = preload("res://scripts/animation/impact_visuals.gd")
const SOURCE_SPX = preload("res://scripts/animation/source_spx_player.gd")
var source_effects: Array[TwilightSourceSPXPlayer] = []
var source_csb_effects: Array[Node2D] = []
@export_range(0.0, 1.0, 0.05) var impact_intensity: float = 0.85
var active: Array[Dictionary] = []
var available: Array[Dictionary] = []
var high_water: int = 0
var emitted: int = 0
var detailed_draws: int = 0
var font: Font
var visuals = VISUALS.new()
var reduced_motion: bool = false
var detail_limit: int = VISUALS.DETAIL_LIMIT

func _init() -> void:
	for i: int in range(CAPACITY): available.append({})

func _ready() -> void:
	font = preload("res://assets/fonts/NotoSansKR.ttf")
	visuals.prepare()
	set_process(false)

func _record(kind: String, point: Vector2, duration: float) -> Dictionary:
	var entry: Dictionary = available.pop_back() if not available.is_empty() else active.pop_front()
	entry.clear()
	entry.merge({"kind":kind, "point":point, "age":0.0, "duration":duration, "serial":emitted})
	active.append(entry)
	emitted += 1
	high_water = maxi(high_water, active.size())
	set_process(true)
	queue_redraw()
	return entry

func impact(point: Vector2, direction: Vector2, style: String, critical: bool = false) -> void:
	var entry: Dictionary = _record("impact", point, 0.22 if not critical else 0.30)
	entry.merge({"direction":direction.normalized(), "style":style, "family":VISUALS.family(style), "critical":critical})

func number(point: Vector2, value: String, color: Color, critical: bool = false) -> void:
	var caption: bool = critical
	# Rapid multi-hits keep every number, but do not stack identical headings.
	for previous: Dictionary in active:
		if caption and str(previous.kind) == "number" and bool(previous.get("caption", false)):
			if float(previous.age) < 0.11 and (previous.point as Vector2).distance_squared_to(point) < 576.0:
				caption = false
	var entry: Dictionary = _record("number", point, 0.65 if not critical else 0.8)
	var size: int = 25 if critical else 18
	var display: String = value.trim_prefix("CRIT ") if critical else value
	var width: float = font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if font != null else 0.0
	entry.merge({"text":value, "display":display, "color":color, "critical":critical, "caption":caption, "width":width, "critical_width":font.get_string_size("Critical", HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x if critical and font != null else 0.0})

func death_pose(point: Vector2, texture: Texture2D, scale_value: Vector2, offset: Vector2, frames: SpriteFrames = null, animation: String = "") -> void:
	var entry: Dictionary = _record("death", point, 0.8)
	entry.merge({"texture":texture, "scale":scale_value, "offset":offset})
	if frames != null and not animation.is_empty() and frames.has_animation(animation):
		entry["frames"] = frames
		entry["animation"] = animation
		var ticks: float = 0.0
		for index: int in range(frames.get_frame_count(animation)):
			ticks += frames.get_frame_duration(animation, index)
		# Play the source track at its declared speed. The old p*2 compressed
		# every death into .4s, dropping phases during ordinary slow rendering.
		var speed: float = frames.get_animation_speed(animation)
		entry["pose_duration"] = ticks / speed if speed > 0.0 and ticks > 0.0 else .4
		entry.duration = maxf(float(entry.duration), float(entry.pose_duration) + .15)
		if frames.has_meta("twilight_canvas_size"):
			# The live actor already normalizes sheets of different resolutions.
			# Preserve that displayed canvas when its death uses another sheet.
			entry["canvas_size"] = texture.get_size() * scale_value

static func _death_draw_scale(entry: Dictionary, texture: Texture2D) -> Vector2:
	if entry.has("canvas_size"):
		return (entry.canvas_size as Vector2) / texture.get_size()
	return entry.scale

func ring(point: Vector2, radius: float, color: Color) -> void:
	var entry: Dictionary = _record("ring", point, 0.3)
	entry.merge({"radius":clampf(radius, 16, 150), "color":color})

func clear() -> void:
	for effect in source_effects:
		if is_instance_valid(effect): effect.queue_free()
	source_effects.clear()
	for effect in source_csb_effects:
		if is_instance_valid(effect): effect.queue_free()
	source_csb_effects.clear()
	for entry: Dictionary in active:
		entry.clear()
		available.append(entry)
	active.clear()
	detailed_draws = 0
	set_process(false)
	queue_redraw()

func source_skill_event(skill_id: String, phase: String, point: Vector2) -> bool:
	# Only an explicit, reviewed DB ID binding can opt in. Similar names and
	# SPX file IDs confer no identity. The private candidate manifest has none.
	var manifest := SOURCE_SPX.read_manifest()
	var binding: Dictionary = manifest.get("skill_bindings", {}).get(skill_id, {})
	if not bool(binding.get("approved", false)): return false
	var event: Dictionary = binding.get("events", {}).get(phase, {})
	if event.is_empty(): return false
	return play_source_effect(str(event.get("group", "")), str(event.get("action", "0")), point)

func _prune_source_effects() -> void:
	for index in range(source_effects.size()-1,-1,-1):
		if not is_instance_valid(source_effects[index]): source_effects.remove_at(index)
	for index in range(source_csb_effects.size()-1,-1,-1):
		if not is_instance_valid(source_csb_effects[index]): source_csb_effects.remove_at(index)

func play_source_effect(group: String, action: String, point: Vector2, preview: bool = false) -> bool:
	_prune_source_effects()
	if source_effects.size() >= 16: return false
	var effect := SOURCE_SPX.new()
	if not effect.configure(group, action, 0, preview):
		effect.free()
		return false
	add_child(effect)
	effect.global_position = point
	effect.play_source_audio = true
	effect.source_marker.connect(func(id: String, frame: int): source_frame_marker.emit(id,frame))
	source_effects.append(effect)
	effect.play()
	return true

func play_source_csb(id: String, point: Vector2, preview: bool = false) -> bool:
	_prune_source_effects()
	var path := "res://data/external_spx/csb_effects.json"
	if not FileAccess.file_exists(path): return false
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not manifest is Dictionary: return false
	var entry: Dictionary = manifest.get(id, {})
	if entry.is_empty() or (not preview and not bool(entry.get("production_approved", false))): return false
	if source_csb_effects.size() >= 8: return false
	var resource := load(str(entry.scene)) as PackedScene
	if resource == null: return false
	var effect := resource.instantiate() as Node2D
	var animation := effect.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation == null: effect.free(); return false
	add_child(effect)
	effect.global_position = point
	animation.animation_finished.connect(func(_name: StringName): effect.queue_free(), CONNECT_ONE_SHOT)
	source_csb_effects.append(effect)
	animation.play("source")
	return true

func _process(delta: float) -> void:
	for i: int in range(active.size() - 1, -1, -1):
		var entry: Dictionary = active[i]
		entry.age += maxf(0.0, delta)
		if float(entry.age) >= float(entry.duration):
			active.remove_at(i)
			entry.clear()
			available.append(entry)
	queue_redraw()
	if active.is_empty(): set_process(false)

func _draw() -> void:
	if font == null: return
	detailed_draws = 0
	var view: Rect2 = get_viewport_rect().grow(160)
	var canvas: Transform2D = get_global_transform_with_canvas()
	# Corpse/rings below impacts, all text above them; pool insertion order must
	# not let a later impact obscure an earlier damage number.
	for entry: Dictionary in active:
		var point: Vector2 = to_local(entry.point)
		if not view.has_point(canvas * point): continue
		var p: float = float(entry.age) / float(entry.duration)
		var alpha: float = 1.0 - p
		match str(entry.kind):
			"death":
				var texture: Texture2D = entry.texture
				var lean: float = 0.0 if reduced_motion else minf(1.0, p * 2.0) * 1.3
				if entry.has("frames"):
					var frames: SpriteFrames = entry.frames
					var animation: String = entry.animation
					texture = frames.get_frame_texture(animation, _death_frame_at_age(entry))
					lean = 0.0
				draw_set_transform(point + (entry.offset as Vector2).rotated(lean), lean, _death_draw_scale(entry, texture))
				draw_texture(texture, -texture.get_size() * 0.5, Color(1.0, 0.7, 0.65, alpha))
				draw_set_transform(Vector2.ZERO)
			"ring":
				var color: Color = entry.color
				color.a = alpha * 0.65
				draw_arc(point, float(entry.radius) * (0.6 + p * 0.4), 0, TAU, 32, color, 1.8, true)
	# Reserve detailed geometry for recent criticals first. Overflow retains a
	# compact contact mark; damage, text, projectile arrival and RNG are untouched.
	for priority: bool in [true, false]:
		for i: int in range(active.size() - 1, -1, -1):
			var entry: Dictionary = active[i]
			if str(entry.kind) != "impact" or bool(entry.critical) != priority: continue
			var point: Vector2 = to_local(entry.point)
			if not view.has_point(canvas * point): continue
			var detailed: bool = detailed_draws < detail_limit
			if detailed: detailed_draws += 1
			visuals.draw_impact(self, point, entry, detailed, impact_intensity)
	for entry: Dictionary in active:
		if str(entry.kind) != "number": continue
		var point: Vector2 = to_local(entry.point)
		if view.has_point(canvas * point): _draw_number(point, entry)

func _draw_number(point: Vector2, entry: Dictionary) -> void:
	var critical: bool = entry.critical
	var age: float = float(entry.age)
	var p: float = age / float(entry.duration)
	var size: int = 25 if critical else 18
	var text_value: String = entry.get("display", entry.text)
	var width: float = entry.width
	var alpha: float = minf(1.0, (1.0 - p) * 2.0)
	var color: Color = entry.color
	color.a *= alpha
	point += Vector2((int(entry.serial) % 3 - 1) * 8.0, 0.0 if reduced_motion else -p * 35.0)
	var scale_value: float = 1.0 if reduced_motion else VISUALS.number_scale(age, critical)
	draw_set_transform(point, 0.0, Vector2.ONE * scale_value)
	var baseline: Vector2 = Vector2(-width * 0.5, 0.0)
	draw_string_outline(font, baseline, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.025, 0.025, 0.03, color.a))
	draw_string(font, baseline, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_set_transform(Vector2.ZERO)

	if not bool(entry.get("caption", false)): return
	var title_point: Vector2 = point + Vector2(0.0, -27.0)
	var title_width: float = float(entry.critical_width)
	visuals.halo(self, title_point + Vector2(0.0, -8.0), Vector2(title_width * 1.6, 34.0), Color(1.0, 0.42, 0.10, alpha * 0.30 * impact_intensity))
	# Shear just the heading; normal numbers, MISS and healing keep their color.
	draw_set_transform_matrix(Transform2D(Vector2(scale_value, 0.0), Vector2(-0.16 * scale_value, scale_value), title_point))
	var title_base: Vector2 = Vector2(-title_width * 0.5, 0.0)
	draw_string_outline(font, title_base, "Critical", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, 5, Color(0.18, 0.055, 0.01, alpha))
	draw_string_outline(font, title_base, "Critical", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, 2, Color(1.0, 0.48, 0.10, alpha))
	draw_string(font, title_base, "Critical", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(1.0, 0.91, 0.53, alpha))
	draw_set_transform(Vector2.ZERO)

static func _death_frame_at_age(entry: Dictionary) -> int:
	return _death_frame(entry.frames, str(entry.animation), float(entry.age) / maxf(.001, float(entry.pose_duration)))

static func _death_frame(frames: SpriteFrames, animation: String, progress: float) -> int:
	# Authored death tracks can contain unequal frame ticks just like attacks.
	var count: int = frames.get_frame_count(animation)
	var duration: float = 0.0
	for index: int in range(count): duration += frames.get_frame_duration(animation, index)
	var point: float = clampf(progress, 0.0, 1.0) * duration
	for index: int in range(count):
		point -= frames.get_frame_duration(animation, index)
		if point < 0.0: return index
	return maxi(0, count - 1)
