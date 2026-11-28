extends Node2D
## Small, procedural TWILIGHT spell effects drawn from resolved combat events.
## No assets, hit callbacks, physics or effects worker are involved.
const MAX_EFFECTS := 28
const MOBILE_LIMIT := 14
var live: Array[Dictionary] = []

func _ready() -> void:
	z_index = 4
	set_process(false)

func show_effect(id: String, style: Dictionary, phase: String, point: Vector2, low_detail: bool) -> bool:
	if not point.is_finite() or style.is_empty() or live.size() >= (MOBILE_LIMIT if low_detail else MAX_EFFECTS):
		return false
	var kind: String = "cast" if phase in ["cast", "learn"] else ("fail" if phase == "fail" else "contact")
	for item: Dictionary in live:
		if item.id == id and item.kind == kind and float(item.age) < 0.065 \
			and (item.point as Vector2).distance_squared_to(point) <= 64.0:
			return false
	var shape: String = str(style.get("shape", "burst"))
	live.append({"id":id, "point":point, "kind":kind, "style":shape,
		"color":Color.from_string(str(style.get("color", "")), Color("#81c7e8")), "age":0.0,
		"duration":0.68 if shape == "wraith" else (0.55 if kind == "cast" else 0.42), "sparks":4 if low_detail else 8})
	set_process(true)
	queue_redraw()
	return true

func clear() -> void:
	live.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	for index: int in range(live.size() - 1, -1, -1):
		var effect: Dictionary = live[index]
		effect.age += delta
		if effect.age >= effect.duration: live.remove_at(index)
	if live.is_empty(): set_process(false)
	queue_redraw()

func _draw() -> void:
	for effect: Dictionary in live:
		var t: float = float(effect.age) / float(effect.duration)
		var opacity: float = (1.0 - t) * minf(1.0, 0.35 + t * 7.0)
		var color: Color = effect.color
		color.a *= opacity
		var core: Color = color.lerp(Color(0.95, 0.97, 1.0, opacity), 0.65)
		var point: Vector2 = to_local(effect.point)
		var radius: float = lerpf(12.0, 32.0, t)
		if effect.kind == "fail":
			draw_arc(point, radius * 0.7, 0.0, TAU, 16, Color(0.62, 0.7, 0.78, opacity * 0.55), 1.3, true)
			continue
		match str(effect.style):
			"scythe":
				var center: Vector2 = point + Vector2(-8, 8)
				draw_arc(center, radius + 12.0, -2.85 + t, 0.60 + t, 22, color, 5.5, true)
				draw_arc(center, radius + 10.0, -2.60 + t, 0.43 + t, 22, core, 1.8, true)
				draw_arc(center, radius + 2.0, -2.35 + t, 0.30 + t, 18, color, 1.5, true)
			"wraith":
				var head: Vector2 = point + Vector2(2.0 + sin(t * TAU) * 7.0, -8.0 - t * 23.0)
				draw_circle(head, 7.0, color)
				draw_line(head + Vector2(-4,-2), head + Vector2(-2,-2), core, 2, true)
				draw_line(head + Vector2(2,-2), head + Vector2(4,-2), core, 2, true)
				draw_arc(head + Vector2(1,8), 12.0, 0.35, PI - 0.35, 12, color, 3.0, true)
			"bolt":
				var zigzag := PackedVector2Array([point + Vector2(-10,-34),point + Vector2(7,-21),
					point + Vector2(-5,-13),point + Vector2(4,-8),point,point + Vector2(-10,9)])
				draw_polyline(zigzag, color, 5.0, true)
				draw_polyline(zigzag, core, 1.6, true)
			"round":
				draw_arc(point, radius * 0.78, 0.0, TAU, 14, color, 2.0, true)
				for angle: float in [0.0,PI * .5,PI,PI * 1.5]:
					var ray := Vector2.from_angle(angle)
					draw_line(point + ray * radius * .72, point + ray * radius, core, 1.7, true)
			"rune":
				draw_arc(point, radius, 0.0, TAU, 20, color, 2.0, true)
				draw_arc(point, radius * 0.70, -PI * .5 + t, TAU - PI * .5 + t, 4, core, 1.7, true)
			"slash":
				draw_arc(point + Vector2(-5, 6), radius + 4.0, -2.7 + t, 0.65 + t, 16, color, 4.0, true)
				draw_arc(point + Vector2(-5, 6), radius + 1.0, -2.7 + t, 0.35 + t, 16, core, 1.4, true)
			"guard":
				draw_arc(point, radius, 0.0, TAU, 6, color, 3.0, true)
				draw_arc(point, radius * 0.82, -PI * 0.8, PI * 0.22, 12, core, 1.4, true)
			"heal":
				draw_line(point + Vector2(-9, -11), point + Vector2(9, -11), core, 2.3, true)
				draw_line(point + Vector2(0, -20), point + Vector2(0, -2), core, 2.3, true)
				draw_arc(point, radius, 0.0, TAU, 18, color, 1.5, true)
			"bind":
				draw_arc(point, radius, PI * 0.17, TAU + PI * 0.17, 8, color, 2.5, true)
				draw_arc(point + Vector2(0, -8), radius * 0.72, -PI, PI, 8, core, 1.4, true)
			"warp":
				draw_arc(point + Vector2(0, -18 * t), radius * (1.0 - 0.4 * t), -PI, PI, 18, color, 2.6, true)
				draw_arc(point, radius * 0.72, 0.0, TAU, 6, core, 1.2, true)
			_:
				draw_arc(point, radius, 0.0, TAU, 18, color, 2.2, true)
				draw_circle(point, maxf(1.0, 7.0 * (1.0 - t)), core)
		for spark: int in range(int(effect.sparks)):
			var ray: Vector2 = Vector2.from_angle(TAU * float(spark) / float(effect.sparks) + 0.25)
			var tail: Vector2 = point + ray * radius * 0.68 + Vector2(0, -6 * t)
			draw_line(tail, tail + ray * lerpf(6.0, 2.0, t), core, 1.2, true)
