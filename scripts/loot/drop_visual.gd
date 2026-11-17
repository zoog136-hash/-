extends Node2D
class_name TwilightDropVisual
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const FLOOR_ALPHA = preload("res://scripts/ui/ground_alpha.gd")

# Original, procedural canvas art. No externally copied beam assets.
const GRADES = ["일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]
const COLORS = [Color("eeeeee"), Color("a8e080"), Color("3b99ff"), Color("ff5360"), Color("bd79ff"), Color("ffd450"), Color("4cf9cf")]
var rank: int = 0
var texture: Texture2D
var slot: String = ""
var selected: bool = false
var source_missing: bool=false
## Off for a current 523 item: its floor beam is the original drop effect
## sprite (current523_ground_drop_effect.gd) or nothing, never this drawing.
## Always off: self-drawn beams/shapes are not shown (user rule 2026-11-17).
var procedural_beam: bool = false
var clock: float = 0.0
var redraw_time: float = 0.0
var source_icon: Sprite2D
var screen_notifier: VisibleOnScreenNotifier2D

func _ready() -> void:
	# The item and its hit target remain alive; only invisible beam animation
	# stops. A large farming field can otherwise redraw every rare drop at 20Hz.
	screen_notifier = VisibleOnScreenNotifier2D.new()
	screen_notifier.rect = Rect2(-40, -220, 80, 260)
	screen_notifier.screen_entered.connect(func() -> void: set_process(rank >= 2 and procedural_beam); queue_redraw())
	screen_notifier.screen_exited.connect(func() -> void: set_process(false))
	add_child(screen_notifier)
	set_process(false)

static func grade_color(grade: String) -> Color:
	return preload("res://scripts/loot/current523_item_grade.gd").color(grade, COLORS[maxi(0, GRADES.find(grade))])

func configure(grade: String, icon: Texture2D, kind: String) -> void:
	rank = maxi(0, GRADES.find(grade))
	texture = FLOOR_ALPHA.texture(icon)
	slot = kind
	if is_instance_valid(source_icon):
		remove_child(source_icon)
		source_icon.queue_free()
		source_icon = null
	if texture != null and texture.resource_path.begins_with("res://assets/l1j/verified/ground/"):
		source_icon = Sprite2D.new()
		source_icon.texture = texture
		source_icon.position = Vector2(0, -12)
		source_icon.scale = Vector2(32,32) / texture.get_size()
		var key_material := ShaderMaterial.new()
		key_material.shader = preload("res://addons/twilight_l1j/source_color_key.gdshader")
		key_material.set_shader_parameter("background_key", Vector3.ONE)
		source_icon.material = key_material
		add_child(source_icon)
	set_process(rank >= 2 and procedural_beam)
	queue_redraw()

func _process(delta: float) -> void:
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_process_step(delta)
	FRAME_HITCH.add_self("loot", hitch_started, hitch_nested)

func _process_step(delta: float) -> void:
	clock += delta
	redraw_time += delta
	if rank >= 2 and redraw_time >= 0.05:
		redraw_time = 0.0
		queue_redraw()

func _draw() -> void:
	var color: Color = COLORS[rank]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.38))
	if procedural_beam: draw_circle(Vector2.ZERO, 18, Color(0, 0, 0, 0.5))
	if rank >= 2 and procedural_beam:
		var pulse: float = 0.8 + 0.2 * sin(clock * 3.0)
		for radius: int in range(32, 5, -4):
			draw_circle(Vector2.ZERO, radius, Color(color, 0.030 * pulse))
	draw_set_transform(Vector2.ZERO)
	if rank >= 2 and procedural_beam:
		var height: float = 104.0 + float(rank) * 13.0
		var width: float = 15.0 + float(rank) * 1.15
		for layer: int in range(5):
			var w: float = width - float(layer) * 1.8
			var c: Color = Color(color, (0.05 + float(layer) * 0.031) * (0.85 + 0.15 * sin(clock * 3.0)))
			draw_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(-w * 0.55, -height), Vector2(w * 0.55, -height), Vector2(w, 0)]), PackedColorArray([c, Color(c, 0), Color(c, 0), c]))
		draw_line(Vector2.ZERO, Vector2(0, -height), Color(color.lightened(0.56), 0.60), 2.5, true)
		if rank >= 4:
			for side: int in [-1, 1]:
				draw_line(Vector2(side * 7, 0), Vector2(side * 3, -height * 0.9), Color(color, 0.48), 2.5, true)
		if rank == 6:
			draw_line(Vector2.ZERO, Vector2(0, -height), Color(0.86, 1, 0.96, 0.96), 2.5, true)
			draw_arc(Vector2(0, -10), 25 + sin(clock * 2) * 3, 0, TAU, 48, Color(0.1, 0.9, 0.78, 0.22), 2, true)
		for particle: int in range(4 + rank):
			var phase: float = fposmod(clock * (0.16 + float(particle % 3) * 0.025) + float(particle) * 0.173, 1.0)
			var point: Vector2 = Vector2(sin(float(particle) * 2.4 + clock) * 18, -phase * height)
			var alpha: float = sin(phase * PI) * 0.7
			draw_circle(point, 1.2, Color(color.lightened(0.4), alpha))
			if rank >= 4 and particle % 2 == 0:
				draw_line(point - Vector2(3, 0), point + Vector2(3, 0), Color(color.lightened(0.6), alpha), 1, true)
				draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color(color.lightened(0.6), alpha), 1, true)
	if source_missing:return
	if is_instance_valid(source_icon):
		pass
	elif texture != null:
		draw_texture_rect(texture, Rect2(-16, -28, 32, 32), false)
	# No self-drawn substitute shapes: without an original picture the spot stays empty.
