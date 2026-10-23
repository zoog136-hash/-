extends Node2D

## Authoring stage only: no skill unlocks, damage, saves or private source images.
const VFX = preload("res://scripts/skills/skill_vfx.gd")
const FLIGHTS = preload("res://scripts/animation/combat_flights.gd")
const PLAYER = preload("res://scenes/Player.tscn")
const NAMES := ["쇼크 스턴", "카운터 배리어", "트리플 애로우", "썬더 볼트", "체인 라이트닝", "이럽션", "미티어 스트라이크", "세인트 이뮨", "다크 핸드", "포우 슬레이어", "하울", "힐"]
var vfx: TwilightOriginalSkillVFX
var flights: TwilightCombatFlights
var caster: TwilightPlayer
var target: TwilightPlayer
var title: Label
var detail: Label
var picker: OptionButton
var selected: int = 0
var direction_index: int = 0
var elapsed: float = 0
var autoplay: bool = true
var ids: Dictionary = {}
var records: Dictionary = {}
var skill_names: Array[String] = []
var hits: int = 0
var current: Dictionary = {}
var current_id: String = ""
var release_sequence: int = -1

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#131a19"))
	var catalog := preload("res://scripts/skills/skill_catalog.gd").new()
	catalog.configure(null)
	for row: Dictionary in catalog.records:
		ids[str(row.name)] = str(row.id)
		records[str(row.name)] = _preview_record(row, catalog)
	for name_value: String in NAMES: skill_names.append(name_value)
	var art := preload("res://scripts/skills/skill_vfx_library.gd").new()
	for row: Dictionary in catalog.records:
		if art.profile_for(str(row.id)).has("atlas") and not skill_names.has(str(row.name)): skill_names.append(str(row.name))
	caster = PLAYER.instantiate()
	target = PLAYER.instantiate()
	add_child(caster)
	add_child(target)
	for actor: TwilightPlayer in [caster, target]:
		actor.camera.enabled = false
		actor.set_physics_process(false)
		actor.set_process_input(false)
		actor.get_node("PlayerActionFX").hide()
	target.set_class_index(0)
	caster.position = Vector2(570, 400)
	caster.motion.strike.connect(_release)
	flights = FLIGHTS.new()
	add_child(flights)
	vfx = VFX.new()
	add_child(vfx)
	vfx.use_private_sources = false
	var camera := Camera2D.new()
	camera.position = Vector2(662, 370)
	camera.zoom = Vector2.ONE * 1.75
	add_child(camera)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	title = Label.new()
	title.position = Vector2(34, 25)
	title.add_theme_font_size_override("font_size", 27)
	overlay.add_child(title)
	detail = Label.new()
	detail.position = Vector2(36, 68)
	detail.add_theme_font_size_override("font_size", 16)
	overlay.add_child(detail)
	picker = OptionButton.new()
	picker.position = Vector2(895, 26)
	picker.custom_minimum_size.x = 350
	for name_value: String in skill_names:
		picker.add_item("%s · %s" % [records[name_value].get("class", ""), name_value])
	picker.item_selected.connect(func(index: int) -> void: selected = index; play_selected())
	overlay.add_child(picker)
	var help := Label.new()
	help.text = "←/→ 전체 연결 효과    ↑/↓ 8방향    Space 재생    L 상세도    A 자동 재생\n자체 제작 2차 시안 · 원작 고증 승인 대기 · 피해 판정 없는 제작실"
	help.position = Vector2(34, 640)
	help.add_theme_font_size_override("font_size", 17)
	overlay.add_child(help)
	play_selected()

func _preview_record(row: Dictionary, catalog: TwilightOriginalSkillCatalog, depth: int = 0) -> Dictionary:
	if str(row.get("mode", "")) != "upgrade" or depth >= 12: return row.duplicate(true)
	var relation: Dictionary = catalog.relations.get(str(row.id), {})
	var base := catalog.record_for(str(relation.get("upgrades_from", "")))
	if base.is_empty(): return row.duplicate(true)
	var preview := _preview_record(base, catalog, depth + 1)
	preview.merge(relation.get("patch", {}), true)
	preview["name"] = row.name
	preview["class"] = row.get("class", "공용")
	return preview

func play_selected() -> void:
	flights.clear()
	vfx.clear()
	hits = 0
	var angle := direction_index * TAU / 8.0
	var skill_name: String = skill_names[selected]
	current = records[skill_name]
	current_id = str(ids[skill_name])
	# These are the four existing public class actors; no character art is modified.
	caster.set_class_index(2 if current.get("attack_type") == "ranged" else 1 if current.get("attack_type") == "magic" else 3 if current.get("class") in ["다크엘프", "사신", "암흑기사"] else 0)
	target.position = caster.position + Vector2.from_angle(angle) * 174
	caster.motion.face(Vector2.from_angle(angle))
	target.motion.face(-Vector2.from_angle(angle))
	title.text = "%s · %s" % [current.get("class", "공용"), skill_name]
	detail.text = "%02d / %d 연결 연출  ·  방향 %d / 8  ·  %s" % [selected + 1, skill_names.size(), direction_index + 1, "낮은 상세" if vfx.low_detail else "전체 레이어"]
	picker.select(selected)
	vfx.begin_cast(current_id, caster, target)
	var kind := str(current.get("attack_type", "melee"))
	var style := "bow" if kind == "ranged" else "magic" if kind == "magic" else "heavy" if current.get("class") == "광전사" else "slash"
	var duration := maxf(.15, float(current.get("cast_time", .42)))
	release_sequence = caster.start_combat_attack(target.global_position, duration, style, caster.motion.profile.marker_for(style))
	elapsed = 0

func _release(sequence: int) -> void:
	if sequence != release_sequence: return
	var id := current_id
	var direction := caster.global_position.direction_to(target.global_position)
	var mode := str(current.get("mode", "attack"))
	if mode in ["buff", "counter", "stealth", "summon"]:
		vfx.maintain(id, caster, 1.4)
		return
	if mode in ["heal", "cleanse", "convert", "teleport", "taunt"]:
		vfx.emit_skill(id, "impact", caster.global_position, Vector2.INF, {"direction":direction, "ground_point":caster.global_position})
		return
	var contact := func() -> void:
		hits += 1
		target.motion.react(false, direction)
		vfx.emit_skill(id, "impact", target.combat_hit_position(), caster.combat_projectile_origin() if str(vfx.library.profile_for(id).get("program", "")) == "chain_lightning" else Vector2.INF, {"direction":direction, "ground_point":target.global_position})
		if mode == "status": vfx.emit_skill(id, "status", target.combat_hit_position())
	var kind := str(current.get("attack_type", "melee"))
	# Existing data owns the volley count and interval, including Foe Slayer and Rapid Shot.
	for index: int in range(int(current.get("hits", 1))):
		flights.launch(caster.combat_projectile_origin(), target, kind if kind in ["ranged", "magic"] else "timed", contact, 1050, index * .08, vfx.flight_options(id))

func _process(delta: float) -> void:
	if not is_instance_valid(caster): return
	caster._update_visual(delta)
	target._update_visual(delta)
	elapsed += delta
	if autoplay and elapsed >= 2.2:
		selected = (selected + 1) % skill_names.size()
		play_selected()

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	match event.keycode:
		KEY_RIGHT: selected = (selected + 1) % skill_names.size()
		KEY_LEFT: selected = posmod(selected - 1, skill_names.size())
		KEY_UP: direction_index = (direction_index + 1) % 8
		KEY_DOWN: direction_index = posmod(direction_index - 1, 8)
		KEY_L: vfx.set_detail("full" if vfx.low_detail else "low")
		KEY_A: autoplay = not autoplay
		KEY_SPACE: pass
		_: return
	play_selected()
