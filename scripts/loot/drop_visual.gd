extends Node2D
class_name TwilightDropVisual

# Original, procedural canvas art. No externally copied beam assets.
const GRADES = ["일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]
const COLORS = [Color("eeeeee"), Color("a8e080"), Color("3b99ff"), Color("ff5360"), Color("bd79ff"), Color("ffd450"), Color("4cf9cf")]
var rank: int = 0
var texture: Texture2D
var slot: String = ""
var selected: bool = false
var clock: float = 0.0
var redraw_time: float = 0.0

static func grade_color(grade: String) -> Color:
	return COLORS[maxi(0, GRADES.find(grade))]

func configure(grade: String, icon: Texture2D, kind: String) -> void:
	rank = maxi(0, GRADES.find(grade))
	texture = icon
	slot = kind
	set_process(rank >= 2)
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	redraw_time += delta
	if rank >= 2 and redraw_time >= 0.05:
		redraw_time = 0.0
		queue_redraw()

func _draw() -> void:
	var color: Color = COLORS[rank]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, 18, Color(0, 0, 0, 0.5))
	if rank >= 2:
		var pulse: float = 0.8 + 0.2 * sin(clock * 3.0)
		for radius: int in range(32, 5, -4):
			draw_circle(Vector2.ZERO, radius, Color(color, 0.025 * pulse))
	if selected:
		draw_arc(Vector2.ZERO, 27, 0, TAU, 48, Color("ffe6a1"), 2.5, true)
	draw_set_transform(Vector2.ZERO)
	if rank >= 2:
		var height: float = 104.0 + float(rank) * 13.0
		var width: float = 12.0 + float(rank)
		for layer: int in range(5):
			var w: float = width - float(layer) * 1.8
			var c: Color = Color(color, (0.04 + float(layer) * 0.025) * (0.85 + 0.15 * sin(clock * 3.0)))
			draw_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(-w * 0.55, -height), Vector2(w * 0.55, -height), Vector2(w, 0)]), PackedColorArray([c, Color(c, 0), Color(c, 0), c]))
		draw_line(Vector2.ZERO, Vector2(0, -height), Color(color.lightened(0.5), 0.48), 2.0, true)
		if rank >= 4:
			for side: int in [-1, 1]:
				draw_line(Vector2(side * 7, 0), Vector2(side * 3, -height * 0.9), Color(color, 0.38), 2.0, true)
		if rank == 6:
			draw_line(Vector2.ZERO, Vector2(0, -height), Color(0.86, 1, 0.96, 0.9), 2.0, true)
			draw_arc(Vector2(0, -10), 25 + sin(clock * 2) * 3, 0, TAU, 48, Color(0.1, 0.9, 0.78, 0.22), 2, true)
		for particle: int in range(4 + rank):
			var phase: float = fposmod(clock * (0.16 + float(particle % 3) * 0.025) + float(particle) * 0.173, 1.0)
			var point: Vector2 = Vector2(sin(float(particle) * 2.4 + clock) * 18, -phase * height)
			var alpha: float = sin(phase * PI) * 0.7
			draw_circle(point, 1.2, Color(color.lightened(0.4), alpha))
			if rank >= 4 and particle % 2 == 0:
				draw_line(point - Vector2(3, 0), point + Vector2(3, 0), Color(color.lightened(0.6), alpha), 1, true)
				draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color(color.lightened(0.6), alpha), 1, true)
	if texture != null:
		draw_texture_rect(texture, Rect2(-16, -28, 32, 32), false)
	elif slot == "consumable":
		draw_rect(Rect2(-7, -21, 14, 20), Color("bb334e"))
		draw_rect(Rect2(-4, -26, 8, 6), Color("d2bd91"))
	elif slot in ["weapon", "mainhand"]:
		draw_line(Vector2(-11, 2), Vector2(10, -27), Color("d8e4eb"), 5, true)
		draw_line(Vector2(-12, -8), Vector2(2, 2), Color("c9a35f"), 4, true)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0,-26), Vector2(13,-16), Vector2(10,-2), Vector2(0,4), Vector2(-10,-2), Vector2(-13,-16)]), Color("abb8c9"))
		draw_arc(Vector2(0,-10), 10, 0, TAU, 6, color, 2, true)
