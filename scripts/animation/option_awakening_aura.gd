extends Node2D

# Option-awakening appearance only: no damage, proc, stat, RNG or save access.
# Palette, loop speed and geometry are TWILIGHT authored choices. Public
# references do not establish an exhaustive original-game grade color table.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const MAX_MOTES: int = 10
const LOW_MOTES: int = 3
var category: String = "변신"
var grade: String = "영웅"
var awakened: bool = false
var reduced_motion: bool = false
var low_detail: bool = false
var intensity: float = 0.85
var clock: float = 0.0
var center: Vector2 = Vector2.ZERO
var radii: Vector2 = Vector2(24, 42)
var target_ref: WeakRef
var redraw_elapsed: float = 0.0

func _ready() -> void:
	name = "OptionAwakeningAura"
	z_index = 0
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	set_process(awakened)
	sync_visual()

func configure(target_sprite: Node2D, card_category: String, grade_name: String, active: bool, settings: Dictionary = {}) -> void:
	target_ref = weakref(target_sprite) if is_instance_valid(target_sprite) else null
	category = card_category
	grade = grade_name
	awakened = active
	apply_settings(settings)
	set_process(awakened)
	sync_visual()

func set_awakened(active: bool) -> void:
	awakened = active
	set_process(active)
	sync_visual()

func apply_settings(settings: Dictionary) -> void:
	reduced_motion = bool(settings.get("reduced_motion", false))
	low_detail = str(settings.get("effect_detail", "full")) == "low"
	intensity = clampf(float(settings.get("impact_intensity", 0.85)), 0.0, 1.0)
	queue_redraw()

func _target() -> Node2D:
	return target_ref.get_ref() as Node2D if target_ref != null else null

func _sprite_rect(sprite: Node2D) -> Rect2:
	if sprite is Sprite2D:
		return (sprite as Sprite2D).get_rect() if (sprite as Sprite2D).texture != null else Rect2()
	if sprite is AnimatedSprite2D:
		var animated := sprite as AnimatedSprite2D
		var frames: SpriteFrames = animated.sprite_frames
		if frames == null or not frames.has_animation(animated.animation) or frames.get_frame_count(animated.animation) == 0:
			return Rect2()
		var texture: Texture2D = frames.get_frame_texture(animated.animation, animated.frame)
		if texture == null:
			return Rect2()
		var extent: Vector2 = texture.get_size()
		return Rect2(animated.offset - extent * 0.5 if animated.centered else animated.offset, extent)
	return Rect2()

func sync_visual() -> void:
	var sprite: Node2D = _target()
	if not awakened or not is_instance_valid(sprite) or not is_inside_tree() or not sprite.is_inside_tree() or not sprite.is_visible_in_tree() or intensity <= 0.0:
		visible = false
		return
	var bounds: Rect2 = _sprite_rect(sprite)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		visible = false
		return
	# Keep this node at the owner's foot for Y-sort, and offset only its drawing.
	# RelicSprite itself is foot-positioned: its elevated art lives in offset.
	var foot: Node2D = sprite if category == "성물" else sprite.get_parent() as Node2D
	global_position = foot.global_position if is_instance_valid(foot) else sprite.global_position
	global_rotation = 0.0
	global_scale = Vector2.ONE
	center = to_local(sprite.to_global(bounds.get_center()))
	var visual_size := Vector2(
		sprite.to_global(bounds.position).distance_to(sprite.to_global(bounds.position + Vector2(bounds.size.x, 0))),
		sprite.to_global(bounds.position).distance_to(sprite.to_global(bounds.position + Vector2(0, bounds.size.y))))
	match category:
		"마법인형": radii = Vector2(clampf(visual_size.x * 0.48, 14, 35), clampf(visual_size.y * 0.48, 18, 44))
		"성물": radii = Vector2(clampf(visual_size.x * 0.68, 13, 30), clampf(visual_size.y * 0.68, 15, 36))
		_: radii = Vector2(clampf(visual_size.x * 0.44, 18, 56), clampf(visual_size.y * 0.52, 30, 80))
	modulate = Color(1, 1, 1, clampf(sprite.modulate.a * sprite.self_modulate.a, 0.0, 1.0))
	visible = modulate.a > 0.005

func _process(delta: float) -> void:
	if not reduced_motion:
		clock = fposmod(clock + maxf(delta, 0.0), 120.0)
	sync_visual()
	redraw_elapsed += delta
	if redraw_elapsed >= (0.1 if low_detail else 1.0 / 30.0):
		redraw_elapsed = 0.0
		if visible:
			queue_redraw()

func _ellipse(radius: Vector2, rotation_phase: float, span: float = TAU) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments: int = 18 if low_detail else 36
	for index: int in range(segments + 1):
		var angle: float = rotation_phase + span * float(index) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw() -> void:
	if not awakened or not visible:
		return
	var tint: Color = UI.grade(grade)
	var motion: float = 0.0 if reduced_motion else clock
	var strength: float = intensity * (0.75 if reduced_motion else 0.82 + sin(motion * 1.7) * 0.12)
	# Broken edge ribbons leave the face and weapon readable. A closed body
	# ellipse reads as a selection/target marker at gameplay scale.
	if category == "성물":
		for side: int in range(2):
			var arc := _ellipse(radii * Vector2(1.05, 0.38), motion * 0.45 + side * PI, PI * 0.65)
			draw_polyline(arc, Color(tint, 0.38 * strength), 1.0, true)
	else:
		# Ground cue is local to this presentation node: never move actor feet.
		var ground := PackedVector2Array()
		for index: int in range(25):
			var angle: float = PI * float(index) / 24.0
			ground.append(Vector2(cos(angle) * radii.x * 0.78, sin(angle) * 5.0 - 2.0))
		draw_polyline(ground, Color(tint, 0.26 * strength), 1.0, true)
		for side: int in [-1, 1]:
			var edge := PackedVector2Array()
			for index: int in range(13):
				var rise: float = float(index) / 12.0
				var sway: float = sin(rise * PI * 1.4 + motion * 1.3 + side) * 0.10
				edge.append(center + Vector2(side * radii.x * (0.78 - rise * 0.22 + sway), radii.y * (0.8 - rise * 1.45)))
			if not low_detail:
				draw_polyline(edge, Color(tint, 0.045 * strength), 4.0, true)
			draw_polyline(edge, Color(tint, 0.27 * strength), 1.0, true)
	if reduced_motion:
		return
	var count: int = LOW_MOTES if low_detail else MAX_MOTES
	for index: int in range(count):
		var phase: float = fposmod(motion * 0.19 + float(index) * 0.6180339, 1.0)
		var angle: float = float(index) * 2.39996 + motion * 0.15
		var point: Vector2 = center + Vector2(cos(angle) * radii.x, radii.y * (0.9 - phase * 1.8))
		var alpha: float = sin(phase * PI) * 0.56 * strength
		if not low_detail:
			draw_circle(point, 3.4, Color(tint, alpha * 0.10))
		draw_circle(point, 0.75 if category == "성물" else 0.9, Color(tint, alpha))
