extends Control

# Persistent option-awakening status, not a combat proc. Colors, badge design
# and shimmer timing are authored TWILIGHT presentation, not measured NC art.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var grade: String = "영웅"
var awakened: bool = false
var reduced_motion: bool = false
var low_detail: bool = false
var intensity: float = 0.85
var clock: float = 0.0
var redraw_elapsed: float = 0.0

func _ready() -> void:
	name = "OptionAwakeningBorder"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	_refresh_activity()

func configure(grade_name: String, active: bool, settings: Dictionary = {}) -> void:
	grade = grade_name
	awakened = active
	apply_settings(settings)

func apply_settings(settings: Dictionary) -> void:
	reduced_motion = bool(settings.get("reduced_motion", false))
	low_detail = str(settings.get("effect_detail", "full")) == "low"
	intensity = clampf(float(settings.get("impact_intensity", 0.85)), 0.0, 1.0)
	_refresh_activity()

func _refresh_activity() -> void:
	visible = awakened
	set_process(awakened and not reduced_motion and intensity > 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	clock = fposmod(clock + maxf(delta, 0.0), 12.0)
	redraw_elapsed += delta
	if redraw_elapsed >= (0.1 if low_detail else 1.0 / 30.0):
		redraw_elapsed = 0.0
		queue_redraw()

func _draw() -> void:
	if not awakened or minf(size.x, size.y) < 20.0:
		return
	var tint: Color = UI.grade(grade)
	var bounds := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	# The status stays legible even when the user disables animated intensity.
	draw_rect(bounds, Color(tint, 0.78), false, 1.6)
	draw_rect(bounds.grow(-3.0), Color(UI.GOLD, 0.42), false, 0.8)
	var span: float = minf(25.0, minf(size.x, size.y) * 0.15)
	for corner: Vector2 in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		var direction := Vector2(1.0 if corner.x < size.x * 0.5 else -1.0, 1.0 if corner.y < size.y * 0.5 else -1.0)
		draw_line(corner, corner + Vector2(span * direction.x, 0), UI.GOLD, 2.0, true)
		draw_line(corner, corner + Vector2(0, span * direction.y), UI.GOLD, 2.0, true)
	var badge: Vector2 = Vector2(size.x - 15, 15)
	var diamond := PackedVector2Array([badge + Vector2(0,-10), badge + Vector2(9,0), badge + Vector2(0,10), badge + Vector2(-9,0)])
	draw_colored_polygon(diamond, Color("13100c"))
	diamond.append(diamond[0])
	draw_polyline(diamond, UI.GOLD, 1.4, true)
	draw_line(badge + Vector2(-4,0), badge + Vector2(-1,4), Color("fff3d5"), 1.6, true)
	draw_line(badge + Vector2(-1,4), badge + Vector2(5,-4), Color("fff3d5"), 1.6, true)
	if not reduced_motion and intensity > 0.0:
		var phase: float = fposmod(clock / 4.0, 1.0)
		var line_y: float = bounds.position.y + phase * bounds.size.y
		var strength: float = sin(phase * PI) * 0.55 * intensity
		draw_line(Vector2(bounds.position.x, line_y), Vector2(bounds.position.x, minf(line_y + 16, bounds.end.y)), Color(Color.WHITE, strength), 2.2, true)
		draw_line(Vector2(bounds.end.x, bounds.end.y - phase * bounds.size.y), Vector2(bounds.end.x, maxf(bounds.position.y, bounds.end.y - phase * bounds.size.y - 16)), Color(Color.WHITE, strength), 2.2, true)
