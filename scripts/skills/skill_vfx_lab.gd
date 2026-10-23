extends Node2D

## Standalone authoring stage. It grants no skills and writes no game save.
const VFX = preload("res://scripts/skills/skill_vfx.gd")
const FLIGHTS = preload("res://scripts/animation/combat_flights.gd")
const PLAYER = preload("res://scenes/Player.tscn")
const NAMES := ["쇼크 스턴", "카운터 배리어", "트리플 애로우", "썬더 볼트", "체인 라이트닝", "이럽션", "미티어 스트라이크", "세인트 이뮨", "다크 핸드", "포우 슬레이어", "하울", "힐"]
var vfx: TwilightOriginalSkillVFX
var flights: TwilightCombatFlights
var caster: TwilightPlayer
var target: TwilightPlayer
var title: Label
var selected: int = 0
var direction_index: int = 0
var elapsed: float = 0
var autoplay: bool = true
var ids: Dictionary = {}
var hits: int = 0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#121b22"))
	var rows: Array = preload("res://scripts/skills/skill_catalog.gd").read_json("master.json").get("records", [])
	for row: Dictionary in rows: ids[str(row.name)] = str(row.id)
	caster = PLAYER.instantiate()
	target = PLAYER.instantiate()
	add_child(caster)
	add_child(target)
	for actor: TwilightPlayer in [caster, target]:
		actor.camera.enabled = false
		actor.set_physics_process(false)
		actor.set_process_input(false)
	target.set_class_index(1)
	caster.position = Vector2(570, 400)
	flights = FLIGHTS.new()
	add_child(flights)
	vfx = VFX.new()
	add_child(vfx)
	vfx.use_private_sources = false
	title = Label.new()
	title.position = Vector2(34, 30)
	title.add_theme_font_size_override("font_size", 24)
	add_child(title)
	var help := Label.new()
	help.text = "←/→ skill   ↑/↓ direction   Space replay   L detail   A autoplay\nIndependent fallback study · source fidelity UNVERIFIED · no damage simulation"
	help.position = Vector2(34, 630)
	add_child(help)
	play_selected()

func play_selected() -> void:
	flights.clear()
	vfx.clear()
	hits = 0
	var angle := direction_index * TAU / 8.0
	target.position = caster.position + Vector2.from_angle(angle) * 210
	caster.motion.face(Vector2.from_angle(angle))
	caster.motion.advance(0, Vector2.ZERO)
	caster.motion.apply_frames(caster.class_sprite)
	var skill_name: String = NAMES[selected]
	var id := str(ids[skill_name])
	title.text = "%02d / 12 · %s · direction %d" % [selected + 1, skill_name, direction_index]
	vfx.begin_cast(id, caster, target)
	var contact := func() -> void:
		hits += 1
		if selected in [1, 7]: vfx.maintain(id, caster, 1.5)
		else: vfx.emit_skill(id, "impact", caster.global_position if selected == 11 else target.combat_hit_position(), caster.combat_projectile_origin() if selected == 4 else Vector2.INF, {"direction":Vector2.from_angle(angle)})
	for index: int in range(3 if selected in [2, 9] else 1):
		flights.launch(caster.combat_projectile_origin(), target, "ranged" if selected == 2 else "magic" if selected == 6 else "timed", contact, 1050, .16 + index * .08, vfx.flight_options(id))
	elapsed = 0

func _process(delta: float) -> void:
	elapsed += delta
	if autoplay and elapsed >= 2.2:
		selected = (selected + 1) % NAMES.size()
		play_selected()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	match event.keycode:
		KEY_RIGHT: selected = (selected + 1) % NAMES.size()
		KEY_LEFT: selected = posmod(selected - 1, NAMES.size())
		KEY_UP: direction_index = (direction_index + 1) % 8
		KEY_DOWN: direction_index = posmod(direction_index - 1, 8)
		KEY_L: vfx.set_detail("full" if vfx.low_detail else "low")
		KEY_A: autoplay = not autoplay
		KEY_SPACE: pass
		_: return
	play_selected()

func _draw() -> void:
	# Stage grid only. Skill shapes are AnimatedSprite2D resources.
	for x: int in range(0, 1280, 64): draw_line(Vector2(x, 110), Vector2(x, 600), Color(1, 1, 1, .025))
	for y: int in range(112, 600, 64): draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 1, 1, .025))
