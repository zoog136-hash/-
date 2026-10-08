extends Node2D
class_name TwilightCombatVFX

## One drawing node, bounded reusable records. No per-hit nodes, tweens or RNG.
const CAPACITY: int = 160
var active: Array[Dictionary] = []
var available: Array[Dictionary] = []
var high_water: int = 0
var emitted: int = 0
var font: Font

func _init() -> void:
	for i: int in range(CAPACITY): available.append({})

func _ready() -> void:
	font = ThemeDB.fallback_font
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
	entry.merge({"direction":direction.normalized(), "style":style, "critical":critical})

func number(point: Vector2, value: String, color: Color, critical: bool = false) -> void:
	var entry: Dictionary = _record("number", point, 0.65 if not critical else 0.8)
	entry.merge({"text":value, "color":color, "critical":critical})

func ring(point: Vector2, radius: float, color: Color) -> void:
	var entry: Dictionary = _record("ring", point, 0.3)
	entry.merge({"radius":clampf(radius, 16, 150), "color":color})

func clear() -> void:
	for entry: Dictionary in active:
		entry.clear()
		available.append(entry)
	active.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	for i: int in range(active.size() - 1, -1, -1):
		var entry: Dictionary = active[i]
		entry.age += delta
		if float(entry.age) >= float(entry.duration):
			active.remove_at(i)
			entry.clear()
			available.append(entry)
	queue_redraw()
	if active.is_empty(): set_process(false)

func _draw() -> void:
	if font == null: return
	var view: Rect2 = get_viewport_rect().grow(100)
	var canvas: Transform2D = get_canvas_transform()
	for entry: Dictionary in active:
		if not view.has_point(canvas * (entry.point as Vector2)): continue
		var point: Vector2 = to_local(entry.point)
		var p: float = float(entry.age) / float(entry.duration)
		var alpha: float = 1.0 - p
		match str(entry.kind):
			"number":
				var critical: bool = entry.critical
				var size: int = 23 if critical else 18
				var text_value: String = entry.text
				var width: float = font.get_string_size(text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				point += Vector2(-width * 0.5 + (int(entry.serial) % 3 - 1) * 7.0, -p * 35.0)
				var color: Color = entry.color
				color.a *= minf(1.0, alpha * 2.0)
				draw_string_outline(font, point, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.025, 0.025, 0.03, color.a))
				draw_string(font, point, text_value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
			"ring":
				var color: Color = entry.color
				color.a = alpha * 0.65
				draw_arc(point, float(entry.radius) * (0.6 + p * 0.4), 0, TAU, 32, color, 1.8, true)
			"impact":
				_draw_impact(point, entry, p, alpha)

func _draw_impact(point: Vector2, entry: Dictionary, p: float, alpha: float) -> void:
	var style: String = entry.style
	var critical: bool = entry.critical
	var direction: Vector2 = entry.direction
	if direction.length_squared() < 0.01: direction = Vector2.RIGHT
	var color: Color = Color(1.0, 0.82, 0.47, alpha)
	if style == "magic": color = Color(0.52, 0.78, 1.0, alpha)
	elif style == "poison": color = Color(0.45, 0.9, 0.36, alpha)
	elif style == "bleed": color = Color(1.0, 0.38, 0.3, alpha)
	var radius: float = (21.0 if critical else 13.0) * (0.45 + p * 1.2)
	var rays: int = 7 if critical else 4
	for i: int in range(rays):
		var ray: Vector2 = direction.rotated(TAU * float(i) / float(rays) + 0.35)
		draw_line(point + ray * radius * 0.25, point + ray * radius, color, 2.0 if critical else 1.4, true)
	if style in ["slash", "thrust", "melee"]:
		var normal: Vector2 = direction.orthogonal()
		draw_line(point - normal * radius, point + normal * radius, Color(1.0, 0.97, 0.83, alpha), 2.2, true)
	elif style in ["heavy", "magic"]:
		draw_arc(point, radius * 0.7, 0, TAU, 18, color, 2.0, true)
	if p < 0.3: draw_circle(point, (4.0 if critical else 2.5) * (1.0 - p), Color(1, 1, 0.91, alpha))
