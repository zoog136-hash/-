extends Node2D

# Option-awakening appearance only: no damage, proc, stat, RNG or save access.
# Palette, loop speed and geometry are TWILIGHT authored choices. Public
# references do not establish an exhaustive original-game grade color table.
const LIGHTNING = preload("res://scripts/cards/option_lightning_art.gd")
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
	material = LIGHTNING.make_material(grade)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(awakened)
	sync_visual()

func configure(target_sprite: Node2D, card_category: String, grade_name: String, active: bool, settings: Dictionary = {}) -> void:
	target_ref = weakref(target_sprite) if is_instance_valid(target_sprite) else null
	category = card_category
	grade = grade_name
	if material is ShaderMaterial: material.set_shader_parameter("grade_color", LIGHTNING.color_for(grade))
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

func _draw() -> void:
	if not awakened or not visible:
		return
	# Offset each attachment's discharge; never make all three flash in sync.
	var phase_offset: float = 0.17 if category == "마법인형" else 0.34 if category == "성물" else 0.0
	var frame: int = LIGHTNING.frame_at(clock + phase_offset, reduced_motion)
	if frame < 0: return
	var extent := radii * Vector2(2.05, 1.75)
	var opacity: float = intensity * (0.40 if reduced_motion else 0.85 if low_detail else 1.0)
	draw_texture_rect_region(LIGHTNING.ATLAS, Rect2(center - extent * 0.5, extent), LIGHTNING.source_rect(frame), Color(1,1,1,opacity))
