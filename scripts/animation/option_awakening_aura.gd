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
	var contour: PackedVector2Array = _ellipse(radii, 0)
	if not low_detail:
		draw_polyline(contour, Color(tint, 0.025 * strength), 10.0, true)
	draw_polyline(contour, Color(tint, 0.10 * strength), 3.2, true)
	draw_polyline(_ellipse(radii, motion * 0.65, PI * 1.1), Color(tint, 0.48 * strength), 1.1, true)
	if category == "성물":
		draw_polyline(_ellipse(radii * Vector2(1.1, 0.40), -motion * 0.55), Color(tint, 0.30 * strength), 1.0, true)
	else:
		# A small second arc wraps the body; it is never a launched projectile.
		draw_polyline(_ellipse(radii * Vector2(0.84, 0.96), PI - motion * 0.42, PI * 0.72), Color(tint, 0.29 * strength), 0.9, true)
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
