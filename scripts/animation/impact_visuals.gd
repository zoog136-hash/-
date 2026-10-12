extends RefCounted

## Original, presentation-only artwork. Reference screenshots are documented in
## docs/HIT_FEEDBACK_20261012.md. No source-game textures, RNG or gameplay calls.
const DETAIL_LIMIT: int = 32
var glow: ImageTexture
static var shared_glow: ImageTexture

func prepare() -> void:
	if glow != null: return
	if shared_glow != null:
		glow = shared_glow
		return
	var image: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	for y: int in range(48):
		for x: int in range(48):
			var distance: float = Vector2(x - 23.5, y - 23.5).length() / 23.5
			var opacity: float = pow(maxf(0.0, 1.0 - distance), 2.4)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, opacity))
	glow = ImageTexture.create_from_image(image)
	shared_glow = glow

static func family(style: String) -> String:
	match style:
		"thrust", "spear", "dagger": return "thrust"
		"heavy", "axe", "blunt": return "heavy"
		"bow", "arrow", "ranged": return "arrow"
		"gun", "bullet", "shot": return "bullet"
		"magic", "staff": return "magic"
		"poison", "bleed": return style
	return "slash"

static func tint(kind: String) -> Color:
	match kind:
		"magic": return Color(0.52, 0.67, 1.0)
		"poison": return Color(0.42, 0.87, 0.32)
		"bleed": return Color(0.93, 0.23, 0.18)
		"heavy": return Color(1.0, 0.60, 0.23)
		"arrow": return Color(0.81, 0.90, 1.0)
	return Color(1.0, 0.76, 0.36)

static func core_envelope(age: float) -> float:
	# A local tuning value, not a claimed measurement of Lineage M video frames.
	return pow(maxf(0.0, 1.0 - age / 0.065), 2.0)

static func number_scale(age: float, critical: bool) -> float:
	if not critical: return 1.0
	if age < 0.035: return lerpf(0.88, 1.22, clampf(age / 0.035, 0.0, 1.0))
	return lerpf(1.22, 1.0, clampf((age - 0.035) / 0.085, 0.0, 1.0))

static func swing_envelope(phase: float, marker: float) -> float:
	# Read the existing visual marker; never create a second strike clock.
	var before: float = smoothstep(marker - 0.16, marker, phase)
	var after: float = 1.0 - smoothstep(marker, marker + 0.22, phase)
	return before * after

func halo(canvas: Node2D, point: Vector2, size: Vector2, color: Color) -> void:
	if glow != null and color.a > 0.005:
		canvas.draw_texture_rect(glow, Rect2(point - size * 0.5, size), false, color)

func beam(canvas: Node2D, point: Vector2, direction: Vector2, length: float, width: float, color: Color) -> void:
	canvas.draw_set_transform(point, direction.angle())
	halo(canvas, Vector2.ZERO, Vector2(length * 2.25, width * 5.0), Color(color, color.a * 0.45))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-length, 0), Vector2(0, -width), Vector2(length, 0), Vector2(0, width)
	]), color)
	canvas.draw_set_transform(Vector2.ZERO)

func crescent(canvas: Node2D, point: Vector2, aim: Vector2, radius: float, progress: float, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = point - aim * radius * 0.65
	var start: float = aim.angle() - 1.12 + progress * 0.32
	for i: int in range(13):
		var t: float = float(i) / 12.0
		points.append(center + Vector2.from_angle(start + t * 2.05) * radius)
	for i: int in range(11, 0, -1):
		var t: float = float(i) / 12.0
		var thickness: float = sin(t * PI) * radius * 0.22
		points.append(center + Vector2.from_angle(start + t * 2.05) * (radius - thickness))
	canvas.draw_colored_polygon(points, color)

func draw_impact(canvas: Node2D, point: Vector2, entry: Dictionary, detailed: bool, strength: float) -> void:
	if strength <= 0.0: return
	var age: float = float(entry.age)
	var p: float = clampf(age / float(entry.duration), 0.0, 1.0)
	var tail: float = (1.0 - p) * (1.0 - p) * strength
	var pulse: float = core_envelope(age) * strength
	var kind: String = str(entry.get("family", family(str(entry.style))))
	var critical: bool = bool(entry.critical)
	var aim: Vector2 = entry.direction
	if aim.length_squared() < 0.01: aim = Vector2.RIGHT
	var color: Color = tint(kind)
	var radius: float = (29.0 if critical else 20.0) * (0.72 + p * 0.7)
	if kind in ["poison", "bleed"]:
		halo(canvas, point, Vector2(24, 28), Color(color, tail * 0.50))
		for i: int in range(3):
			var drop: Vector2 = Vector2(float(i - 1) * (4.0 + p * 6.0), p * 12.0 - float(i % 2) * 5.0)
			canvas.draw_circle(point + drop, 2.2 * (1.0 - p), Color(color, tail))
		return
	if not detailed:
		canvas.draw_line(point - aim * 5.0, point + aim * 5.0, Color(color, tail), 1.8, true)
		return
	halo(canvas, point, Vector2.ONE * radius * 3.6, Color(color, tail * 0.45))
	match kind:
		"slash":
			crescent(canvas, point, aim, radius * 1.25, p, Color(color, tail * 0.48))
			crescent(canvas, point, aim, radius, p, Color(1.0, 0.96, 0.78, tail))
		"thrust":
			beam(canvas, point + aim * p * 9.0, aim, radius * 1.4, 2.3 * (1.0 - p), Color(1.0, 0.95, 0.78, tail))
		"arrow", "bullet":
			beam(canvas, point, aim, radius * (1.1 if kind == "arrow" else 0.7), 1.8, Color(1.0, 0.98, 0.90, tail))
		"heavy":
			canvas.draw_set_transform(point, 0.0, Vector2(1.0, 0.52))
			canvas.draw_arc(Vector2.ZERO, radius * (0.55 + p), 0.0, TAU, 24, Color(color, tail), 2.2, true)
			canvas.draw_set_transform(Vector2.ZERO)
			beam(canvas, point, aim.orthogonal(), radius * 0.65, 2.8, Color(1.0, 0.94, 0.76, pulse))
		"magic":
			canvas.draw_arc(point, radius * (0.45 + p), -p, TAU - p, 24, Color(color, tail * 0.8), 1.8, true)
			beam(canvas, point, Vector2.UP, radius * 0.9, 2.3, Color(0.86, 0.84, 1.0, pulse))
	var sparks: int = 7 if critical else 4
	for i: int in range(sparks):
		var variation: float = float((int(entry.serial) * 7 + i * 11) % 13) / 13.0
		var ray: Vector2 = aim.rotated(TAU * float(i) / float(sparks) + variation * 0.45)
		var travel: float = radius * (0.30 + sqrt(p) * (0.7 + variation * 0.5))
		var tip: Vector2 = point + ray * travel + Vector2(0.0, p * p * 8.0)
		canvas.draw_line(tip - ray * radius * 0.25, tip, Color(color, tail), 2.2 if critical else 1.4, true)
		canvas.draw_circle(tip, 1.2, Color(1.0, 0.96, 0.82, tail * 0.85))
	if critical:
		# Compact horizontal gold flare, not a full-screen flash or camera shake.
		beam(canvas, point, Vector2.RIGHT, 54.0 * (0.65 + p), 3.0, Color(1.0, 0.76, 0.30, pulse * 0.85))
		beam(canvas, point, Vector2.UP, 22.0, 1.7, Color(1.0, 0.95, 0.77, pulse))
	halo(canvas, point, Vector2.ONE * (31.0 if critical else 19.0), Color(1.0, 0.99, 0.90, pulse))
	canvas.draw_circle(point, (3.7 if critical else 2.2) * pulse, Color(1.0, 1.0, 0.95, pulse))
