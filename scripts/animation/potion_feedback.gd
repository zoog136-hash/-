extends Node2D
class_name TwilightPotionFeedback

## Newly authored light, not recovered SPR art. Presentation only; never heals.
const LIGHT = preload("res://scripts/animation/impact_visuals.gd")
const LIFETIME: float = 0.48
const CAPACITY: int = 3
const COLORS: Dictionary = {
	"health": Color(1.0, 0.22, 0.16),
	"health_high": Color(1.0, 0.57, 0.18),
	"health_strong": Color(1.0, 0.94, 0.76),
	"mana": Color(0.24, 0.61, 1.0),
	"haste": Color(0.30, 1.0, 0.48),
	"brave": Color(1.0, 0.77, 0.25),
	"buff": Color(0.76, 0.48, 1.0)
}
var active: Array[Dictionary] = []
var world: Node
var actor: Node2D
var generation: int = 0
var last_position: Vector2 = Vector2.ZERO
var emitted: int = 0
var light = LIGHT.new()

static func channel_for(item_name: String, kind: String) -> String:
	var title: String = item_name.replace("(각인)", "").strip_edges()
	if kind == "hp":
		if "강력" in title or "상급" in title or "흰" in title: return "health_strong"
		if "고급" in title or "주황" in title: return "health_high"
		return "health"
	if kind == "instant_mp": return "mana"
	if kind != "timed" or not title.contains("물약"): return ""
	if "마나" in title or "MP" in title or "파란" in title: return "mana"
	if "용기" in title: return "brave"
	if "초록" in title or "가속" in title: return "haste"
	return "buff"

func _ready() -> void:
	light.prepare()
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	z_index = 1
	set_process(false)

func setup(world_node: Node, actor_node: Node2D) -> void:
	world = world_node
	actor = actor_node
	generation = int(world.get("combat_generation"))
	last_position = actor.global_position

func _context_valid() -> bool:
	return is_instance_valid(world) and is_instance_valid(actor) and int(world.get("hp")) > 0

func _context_changed() -> bool:
	return generation != int(world.get("combat_generation")) or actor.global_position.distance_squared_to(last_position) > 65536.0

func play(channel: String) -> bool:
	if not COLORS.has(channel) or not _context_valid(): return false
	if _context_changed(): clear()
	generation = int(world.get("combat_generation"))
	last_position = actor.global_position
	# Repeated drinking refreshes the same light, never creates per-use nodes.
	for index: int in range(active.size() - 1, -1, -1):
		if str(active[index].channel) == channel: active.remove_at(index)
	if active.size() >= CAPACITY: active.pop_front()
	active.append({"channel":channel, "age":0.0})
	emitted += 1
	set_process(true)
	queue_redraw()
	return true

func clear() -> void:
	active.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	if not _context_valid() or _context_changed():
		clear()
		return
	last_position = actor.global_position
	for index: int in range(active.size() - 1, -1, -1):
		active[index].age += maxf(0.0, delta)
		if float(active[index].age) >= LIFETIME: active.remove_at(index)
	queue_redraw()
	if active.is_empty(): set_process(false)

func _draw() -> void:
	if not _context_valid() or _context_changed(): return
	var settings: Dictionary = world.get("presentation_settings") as Dictionary
	var strength: float = clampf(float(settings.get("impact_intensity", 0.85)), 0.0, 1.0)
	if strength <= 0.0: return
	var quiet: bool = bool(settings.get("reduced_motion", false)) or str(settings.get("effect_detail", "full")) != "full"
	for entry: Dictionary in active:
		var p: float = clampf(float(entry.age) / LIFETIME, 0.0, 1.0)
		var fade: float = minf(1.0, float(entry.age) / 0.04) * pow(1.0 - p, 1.4) * strength
		var tint: Color = COLORS[str(entry.channel)]
		light.halo(self, Vector2(0, -30), Vector2(48, 68), Color(tint, fade * 0.46))
		light.halo(self, Vector2(0, -30), Vector2(20, 34), Color(1.0, 0.97, 0.90, fade * 0.36))
		if quiet: continue
		draw_set_transform(Vector2(0, -6), 0.0, Vector2(1.0, 0.4))
		draw_arc(Vector2.ZERO, 18.0 + 7.0 * p, 0.0, TAU, 24, Color(tint, fade * 0.55), 1.4, true)
		draw_set_transform(Vector2.ZERO)
		for index: int in range(6):
			var angle: float = TAU * float(index) / 6.0
			var point: Vector2 = Vector2(cos(angle) * (12.0 + p * 6.0), -10.0 - p * 48.0 + sin(angle) * 8.0)
			light.halo(self, point, Vector2.ONE * 12.0, Color(tint, fade * 0.65))
			draw_line(point - Vector2(0, 3), point + Vector2(0, 3), Color(1.0, 0.98, 0.92, fade * 0.8), 1.2, true)
			draw_line(point - Vector2(2, 0), point + Vector2(2, 0), Color(tint, fade * 0.8), 1.2, true)
