extends Control
## Host-drawn tracking meter; it contains no original game artwork.
var session: RefCounted

func _ready() -> void:
	custom_minimum_size = Vector2(200, 44)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("171510"))
	if session == null or session.difficulty.is_empty(): return
	var width: float = size.x
	var zone: float = float(session.difficulty.TargetZoneSize) * width / 1000.0
	var target: float = float(session.target) * width / 1000.0
	var cursor: float = float(session.cursor) * width / 1000.0
	draw_rect(Rect2(Vector2(maxf(0.0, target - zone / 2.0), 5), Vector2(zone, size.y - 10)), Color("796334"))
	draw_line(Vector2(target, 5), Vector2(target, size.y - 5), Color("dfc97c"), 2)
	draw_line(Vector2(cursor, 1), Vector2(cursor, size.y - 1), Color("79e0e3"), 4)
