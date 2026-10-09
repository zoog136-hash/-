extends Node2D
class_name TwilightOriginalSkillVFX

## One bounded Compatibility canvas pool; it never controls combat callbacks.
## No publisher bitmaps, extracted sounds, or per-particle scene allocation.
var presets: Dictionary = {}
var live: Array[Dictionary] = []
var available: Array[Dictionary] = []
var persistent: Dictionary = {}
var emitted: int = 0
var retired: int = 0
var audio_pool: TwilightOriginalSkillAudio
const MAX_EFFECTS := 160
const MAX_POOL := 160

func _ready() -> void:
	presets = preload("res://scripts/skills/skill_catalog.gd").read_json("vfx.json")
	audio_pool = preload("res://scripts/skills/skill_audio.gd").new()
	add_child(audio_pool)
	set_process(false)

func color_for(id: String) -> Color:
	return Color.from_hsv(float(presets.get(id, {}).get("hue", .58)), .5, 1.0)

func emit_skill(id: String, phase: String, point: Vector2, end: Vector2 = Vector2.INF) -> void:
	if phase in ["impact", "status"] and is_instance_valid(audio_pool): audio_pool.play_skill(id, point)
	if live.size() >= MAX_EFFECTS: return
	var item: Dictionary = available.pop_back() if not available.is_empty() else {}
	item.merge({"id":id,"phase":phase,"point":point,"end":end,"age":0.0,"ttl":.65 if phase != "cast" else .4}, true)
	live.append(item)
	emitted += 1
	set_process(true)
	queue_redraw()

func maintain(id: String, node: Node2D, duration: float) -> void:
	persistent[id] = {"target":weakref(node),"remaining":duration}
	set_process(true)

func remove_persistent(id: String) -> void:
	var previous: Dictionary = persistent.get(id, {})
	if not previous.is_empty():
		var target: Node2D = previous.target.get_ref()
		if is_instance_valid(target): emit_skill(id, "end", target.global_position)
	persistent.erase(id)

func clear() -> void:
	if is_instance_valid(audio_pool): audio_pool.clear()
	for item: Dictionary in live:
		item.clear()
		if available.size() < MAX_POOL: available.append(item)
		retired += 1
	live.clear()
	persistent.clear()
	queue_redraw()
	set_process(false)

func _process(delta: float) -> void:
	for index: int in range(live.size() - 1, -1, -1):
		live[index].age += delta
		if float(live[index].age) >= float(live[index].ttl):
			var item: Dictionary = live[index]
			live.remove_at(index)
			item.clear()
			if available.size() < MAX_POOL: available.append(item)
			retired += 1
	for id: String in persistent.keys():
		persistent[id].remaining -= delta
		if float(persistent[id].remaining) <= 0 or not is_instance_valid(persistent[id].target.get_ref()): remove_persistent(id)
	queue_redraw()
	if live.is_empty() and persistent.is_empty(): set_process(false)

func _draw() -> void:
	for item: Dictionary in live:
		var preset: Dictionary = presets.get(str(item.id), {})
		var point := to_local(item.point)
		var t := float(item.age) / float(item.ttl)
		var color := color_for(str(item.id))
		color.a = 1.0 - t
		var motif := str(preset.get("motif", "rune"))
		var seed := int(preset.get("seed", 1))
		var radius := 12.0 + t * (25.0 + float(seed % 17))
		if item.phase == "cast":
			for ray: int in range(5 + seed % 4):
				var angle := TAU * float(ray) / float(5 + seed % 4) + t
				draw_line(point + Vector2.from_angle(angle) * radius, point + Vector2.from_angle(angle) * (radius + 9), color, 2)
		elif motif in ["lightning","chain_lightning","thunder_stun","thunder_armor","field"]:
			var begin := to_local(item.end) if item.end != Vector2.INF else point + Vector2(0, -160)
			var last := begin
			for step: int in range(1, 9):
				var next := begin.lerp(point, float(step) / 8.0) + Vector2(sin(float(step * 5 + seed)) * 13, 0)
				if step == 8: next = point
				draw_line(last, next, Color(color,.25 * color.a), 9, true)
				draw_line(last, next, color, 2, true)
				last = next
		elif motif in ["lance","sword","stun","dark_stun","holy_stun","rune_stun"]:
			draw_line(point + Vector2(0,-90 * (1-t)), point + Vector2(0,20), color, 5, true)
			draw_arc(point, radius, 0, TAU, 24, Color(color,.6*color.a), 2, true)
			for ray: int in range(8): draw_line(point, point + Vector2.from_angle(TAU*ray/8) * radius, color, 1)
		elif motif in ["meteor","flame","blood","howl"]:
			for ember: int in range(12):
				var v := Vector2.from_angle(float(ember) * TAU / 12 + float(seed%6))
				draw_circle(point + v * radius, (1-t) * (3 + ember%4), color)
			draw_circle(point, (1-t) * 14, Color(color,.4*color.a))
		elif motif in ["counter","illusion","holy_counter","shield","phalanx","barrier"]:
			draw_arc(point + Vector2(0,-20), radius, -PI*.8, PI*.6, 24, color, 3, true)
			for shard: int in range(3): draw_line(point + Vector2(-20+shard*20,-35),point+Vector2(-10+shard*20,-5),color,2,true)
		elif motif in ["arrows","bullets","claw","axe","scythe"]:
			for slash: int in range(3):
				draw_line(point + Vector2(-radius, -radius+slash*12), point+Vector2(radius,radius+slash*6), color, 2, true)
		elif motif in ["heal","life","nature","cleanse","nomad"]:
			for leaf: int in range(8):
				var offset := Vector2(sin(float(leaf)+t*3)*radius,-t*65+leaf*5)
				draw_line(point+offset+Vector2(-3,0),point+offset+Vector2(3,0),color,2)
				draw_line(point+offset+Vector2(0,-3),point+offset+Vector2(0,3),color,2)
		else:
			var vertices := PackedVector2Array()
			for vertex: int in range(7): vertices.append(point + Vector2.from_angle(TAU*vertex/6+t*2) * radius)
			draw_polyline(vertices, color, 2, true)
	for id: String in persistent:
		var target: Node2D = persistent[id].target.get_ref()
		if not is_instance_valid(target): continue
		var point := to_local(target.global_position) + Vector2(0,-22)
		var color := color_for(id)
		color.a = .45
		var motif := str(presets.get(id, {}).get("motif", ""))
		if motif == "light": draw_circle(point, 68, Color(color,.08))
		else: draw_arc(point, 28, -PI*.9, PI*.1, 20, color, 2, true)
