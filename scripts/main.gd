extends Node2D

const SAVE_PATH := "user://twilight_v17_save.json"
const VIEW := Vector2(1280, 720)
const JOY_CENTER := Vector2(105, 585)
const ATTACK_CENTER := Vector2(1195, 605)
const AUTO_CENTER := Vector2(1083, 626)

var player_pos := Vector2(640, 380)
var player_speed := 235.0
var player_hp := 640
var player_max_hp := 640
var player_mp := 185
var player_max_mp := 185
var player_level := 55
var player_exp := 37
var player_gold := 125430
var attack_power := 37
var defense := 22
var stats := {"STR":18,"DEX":15,"CON":17,"INT":11,"WIS":13,"CHA":10}

var auto_hunt := false
var attack_cooldown := 0.0
var damage_tick := 0.0
var message := ""
var message_time := 0.0
var current_target = null

var monsters: Array = []
var drops: Array = []
var inventory := {
	"빨간 물약": 126,
	"초록 물약": 42,
	"귀환 주문서": 18,
	"철검": 1,
	"가죽 갑옷": 1
}

var joystick_touch := -1
var joystick_vector := Vector2.ZERO
var joystick_knob := JOY_CENTER
var status_open := false
var menu_open := false
var inventory_open := false

func _ready():
	randomize()
	_spawn_monsters(18)
	_show_message("V17 Godot 모바일 프로젝트")
	queue_redraw()

func _process(delta):
	attack_cooldown = max(0.0, attack_cooldown - delta)
	damage_tick = max(0.0, damage_tick - delta)
	message_time = max(0.0, message_time - delta)
	if message_time <= 0.0:
		message = ""

	_handle_keyboard(delta)
	_update_auto_hunt(delta)
	_update_monsters(delta)
	_collect_nearby_drops()
	queue_redraw()

func _handle_keyboard(delta):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if joystick_vector.length() > 0.05:
		dir = joystick_vector

	if dir.length() > 0.0:
		player_pos += dir.normalized() * player_speed * delta
		_clamp_player()

	if Input.is_action_just_pressed("attack"):
		_attack_nearest()
	if Input.is_action_just_pressed("toggle_auto"):
		_toggle_auto()
	if Input.is_action_just_pressed("open_inventory"):
		inventory_open = !inventory_open
	if Input.is_action_just_pressed("open_menu"):
		menu_open = !menu_open
	if Input.is_action_just_pressed("quick_potion"):
		_use_potion()
	if Input.is_action_just_pressed("save_game"):
		save_game()
	if Input.is_action_just_pressed("load_game"):
		load_game()

func _input(event):
	if event is InputEventScreenTouch:
		var p: Vector2 = _to_view(event.position)
		if event.pressed:
			if p.x < 235.0 and p.y > 445.0:
				joystick_touch = event.index
				_set_joystick(p)
				return
			_handle_tap(p)
		else:
			if event.index == joystick_touch:
				joystick_touch = -1
				joystick_vector = Vector2.ZERO
				joystick_knob = JOY_CENTER
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch:
			_set_joystick(_to_view(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_tap(_to_view(event.position))

func _to_view(screen_pos: Vector2) -> Vector2:
	# Convert real screen/touch coordinates through Godot's stretch/letterbox transform.
	# This keeps mobile touch hitboxes aligned on wide or tall Android displays.
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _set_joystick(p: Vector2):
	var delta := p - JOY_CENTER
	var radius := 58.0
	if delta.length() > radius:
		delta = delta.normalized() * radius
	joystick_knob = JOY_CENTER + delta
	joystick_vector = delta / radius
	if joystick_vector.length() > 1.0:
		joystick_vector = joystick_vector.normalized()

func _handle_tap(p: Vector2):
	if p.distance_to(ATTACK_CENTER) < 62.0:
		_attack_nearest()
		return
	if p.distance_to(AUTO_CENTER) < 48.0:
		_toggle_auto()
		return
	if Rect2(16, 14, 332, 92).has_point(p):
		status_open = !status_open
		menu_open = false
		inventory_open = false
		return
	if Rect2(1188, 10, 75, 64).has_point(p):
		menu_open = !menu_open
		status_open = false
		return
	if Rect2(1085, 10, 95, 64).has_point(p):
		inventory_open = !inventory_open
		menu_open = false
		status_open = false
		return
	if Rect2(1180, 515, 82, 58).has_point(p):
		_use_potion()
		return
	if menu_open:
		if Rect2(975, 86, 280, 46).has_point(p):
			inventory_open = true
			menu_open = false
			return
		if Rect2(975, 138, 280, 46).has_point(p):
			status_open = true
			menu_open = false
			return
		if Rect2(975, 190, 280, 46).has_point(p):
			save_game()
			return
		if Rect2(975, 242, 280, 46).has_point(p):
			load_game()
			return

func _spawn_monsters(count: int):
	monsters.clear()
	var names := ["오크 전사","해골 병사","늑대인간","다크 엘프","가고일"]
	for i in range(count):
		var max_hp := randi_range(70, 140)
		monsters.append({
			"name": names[randi() % names.size()],
			"level": randi_range(48, 58),
			"pos": Vector2(randf_range(330, 1180), randf_range(150, 570)),
			"hp": max_hp,
			"max_hp": max_hp,
			"speed": randf_range(28.0, 52.0),
			"damage": randi_range(2, 7),
			"exp": randi_range(2, 5),
			"gold": randi_range(12, 42),
			"respawn": 0.0
		})

func _update_monsters(delta):
	for m in monsters:
		if int(m["hp"]) <= 0:
			m["respawn"] = float(m["respawn"]) - delta
			if float(m["respawn"]) <= 0.0:
				_respawn_monster(m)
			continue

		var dist: float = m["pos"].distance_to(player_pos)
		if dist < 220.0 and dist > 42.0:
			var dir: Vector2 = (player_pos - m["pos"]).normalized()
			m["pos"] += dir * float(m["speed"]) * delta
		elif dist <= 42.0 and damage_tick <= 0.0:
			player_hp = max(0, player_hp - int(m["damage"]))
			damage_tick = 0.35
			if player_hp <= 0:
				_respawn_player()

func _update_auto_hunt(delta):
	if not auto_hunt:
		return

	var target = _nearest_alive_monster()
	current_target = target
	if target == null:
		return

	var dist: float = target["pos"].distance_to(player_pos)
	if dist > 56.0:
		var dir: Vector2 = (target["pos"] - player_pos).normalized()
		player_pos += dir * player_speed * 0.78 * delta
		_clamp_player()
	elif attack_cooldown <= 0.0:
		_attack_target(target)

func _nearest_alive_monster():
	var best = null
	var best_dist := INF
	for m in monsters:
		if int(m["hp"]) <= 0:
			continue
		var d: float = m["pos"].distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best = m
	return best

func _attack_nearest():
	var target = _nearest_alive_monster()
	if target == null:
		_show_message("주변에 대상이 없습니다.")
		return
	current_target = target
	if target["pos"].distance_to(player_pos) > 95.0:
		_show_message("대상이 너무 멉니다.")
		return
	_attack_target(target)

func _attack_target(target):
	if attack_cooldown > 0.0 or int(target["hp"]) <= 0:
		return
	var dmg := attack_power + randi_range(-5, 8)
	target["hp"] = max(0, int(target["hp"]) - max(1, dmg))
	attack_cooldown = 0.52
	if int(target["hp"]) <= 0:
		_on_monster_killed(target)

func _on_monster_killed(monster):
	player_exp += int(monster["exp"])
	player_gold += int(monster["gold"])
	var item_names := ["빨간 물약","초록 물약","철 화살","가죽 장갑","아데나 주머니"]
	var item := item_names[randi() % item_names.size()]
	drops.append({"pos": monster["pos"], "name": item})
	monster["respawn"] = 2.8
	_show_message("%s 처치  +%d 아데나" % [monster["name"], int(monster["gold"])])
	_check_level_up()

func _respawn_monster(m):
	var max_hp := randi_range(75, 145)
	m["pos"] = Vector2(randf_range(330, 1180), randf_range(150, 570))
	m["max_hp"] = max_hp
	m["hp"] = max_hp
	m["respawn"] = 0.0

func _respawn_player():
	player_hp = player_max_hp
	player_mp = player_max_mp
	player_pos = Vector2(640, 380)
	auto_hunt = false
	_show_message("마을에서 부활했습니다.")

func _check_level_up():
	var need := _exp_need()
	while player_exp >= need:
		player_exp -= need
		player_level += 1
		player_max_hp += 14
		player_max_mp += 4
		player_hp = player_max_hp
		player_mp = player_max_mp
		attack_power += 2
		defense += 1
		stats["STR"] = int(stats["STR"]) + 1
		_show_message("LEVEL UP! Lv.%d" % player_level)
		need = _exp_need()

func _exp_need() -> int:
	return 100 + max(0, player_level - 1) * 12

func _collect_nearby_drops():
	for d in drops.duplicate():
		if d["pos"].distance_to(player_pos) < 34.0:
			var item_name: String = str(d["name"])
			inventory[item_name] = int(inventory.get(item_name, 0)) + 1
			drops.erase(d)
			_show_message("%s 획득" % item_name)

func _use_potion():
	var count := int(inventory.get("빨간 물약", 0))
	if count <= 0:
		_show_message("빨간 물약이 없습니다.")
		return
	if player_hp >= player_max_hp:
		_show_message("HP가 가득 차 있습니다.")
		return
	inventory["빨간 물약"] = count - 1
	player_hp = min(player_max_hp, player_hp + 180)
	_show_message("빨간 물약 사용")

func _toggle_auto():
	auto_hunt = !auto_hunt
	_show_message("자동사냥 %s" % ("ON" if auto_hunt else "OFF"))

func _clamp_player():
	player_pos.x = clamp(player_pos.x, 285.0, 1240.0)
	player_pos.y = clamp(player_pos.y, 125.0, 650.0)

func _show_message(text: String):
	message = text
	message_time = 2.0

func save_game():
	var data = {
		"player_pos":[player_pos.x, player_pos.y],
		"hp":player_hp,
		"max_hp":player_max_hp,
		"mp":player_mp,
		"max_mp":player_max_mp,
		"level":player_level,
		"exp":player_exp,
		"gold":player_gold,
		"attack":attack_power,
		"defense":defense,
		"stats":stats,
		"inventory":inventory
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		_show_message("저장 완료")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		_show_message("저장 데이터가 없습니다.")
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		_show_message("저장 데이터 오류")
		return
	var p = data.get("player_pos", [640,380])
	player_pos = Vector2(float(p[0]), float(p[1]))
	player_hp = int(data.get("hp",640))
	player_max_hp = int(data.get("max_hp",640))
	player_mp = int(data.get("mp",185))
	player_max_mp = int(data.get("max_mp",185))
	player_level = int(data.get("level",55))
	player_exp = int(data.get("exp",37))
	player_gold = int(data.get("gold",125430))
	attack_power = int(data.get("attack",37))
	defense = int(data.get("defense",22))
	stats = data.get("stats",stats)
	inventory = data.get("inventory",inventory)
	_show_message("불러오기 완료")

func _draw():
	_draw_world()
	_draw_drops()
	_draw_monsters()
	_draw_player()
	_draw_hud()
	_draw_quest()
	_draw_touch_controls()
	_draw_bottom_ui()
	_draw_panels()
	_draw_message()

func _draw_world():
	draw_rect(Rect2(Vector2.ZERO, VIEW), Color("#172217"))
	for x in range(0, 1280, 64):
		draw_line(Vector2(x, 0), Vector2(x, 720), Color(0.16,0.23,0.16,0.30), 1)
	for y in range(0, 720, 64):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.16,0.23,0.16,0.30), 1)
	draw_rect(Rect2(300,120,950,540), Color(0.13,0.20,0.12,0.48))
	draw_rect(Rect2(520,120,115,540), Color(0.24,0.22,0.15,0.32))
	draw_rect(Rect2(300,350,950,92), Color(0.24,0.22,0.15,0.24))
	draw_circle(Vector2(780,260), 70, Color(0.10,0.18,0.24,0.65))
	draw_circle(Vector2(930,510), 84, Color(0.09,0.17,0.11,0.70))
	for i in range(12):
		var px := 350.0 + float((i * 79) % 820)
		var py := 155.0 + float((i * 131) % 430)
		draw_circle(Vector2(px,py), 18, Color(0.08,0.14,0.07,0.9))

func _draw_drops():
	for d in drops:
		var p: Vector2 = d["pos"]
		draw_circle(p, 7, Color("#f2ce47"))
		draw_string(ThemeDB.fallback_font, p + Vector2(-28,-12), str(d["name"]), HORIZONTAL_ALIGNMENT_CENTER, 56, 10, Color("#ffe897"))

func _draw_monsters():
	for m in monsters:
		if int(m["hp"]) <= 0:
			continue
		var p: Vector2 = m["pos"]
		var selected := m == current_target
		draw_circle(p, 17, Color("#7b2c22"))
		draw_circle(p, 22, Color("#d5b46a") if selected else Color("#4c3428"), false, 2)
		var ratio := float(m["hp"]) / float(m["max_hp"])
		draw_rect(Rect2(p + Vector2(-25,-34), Vector2(50,6)), Color("#180a09"))
		draw_rect(Rect2(p + Vector2(-25,-34), Vector2(50.0*ratio,6)), Color("#d52d28"))
		draw_string(ThemeDB.fallback_font, p + Vector2(-38,-42), "%s Lv.%d" % [m["name"], int(m["level"])], HORIZONTAL_ALIGNMENT_CENTER, 76, 10, Color("#eee1c3"))

func _draw_player():
	draw_circle(player_pos, 18, Color("#3e7fc7"))
	draw_circle(player_pos, 23, Color("#d5c38f"), false, 2)
	draw_line(player_pos + Vector2(0,-18), player_pos + Vector2(12,-30), Color("#e7d8b1"), 3)

func _draw_hud():
	draw_rect(Rect2(12,10,345,95), Color(0.03,0.03,0.025,0.88))
	draw_rect(Rect2(12,10,345,95), Color("#7b6039"), false, 1)
	draw_circle(Vector2(56,56), 38, Color("#201b14"))
	draw_circle(Vector2(56,56), 35, Color("#4b6880"))
	draw_string(ThemeDB.fallback_font, Vector2(32,61), "기사", HORIZONTAL_ALIGNMENT_CENTER, 48, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(91,33), "황혼의 기사   Lv.%d" % player_level, HORIZONTAL_ALIGNMENT_LEFT, 220, 16, Color("#f2e7cc"))
	_draw_bar(Rect2(92,43,245,17), float(player_hp)/float(player_max_hp), Color("#c52d29"), "%d / %d" % [player_hp,player_max_hp])
	_draw_bar(Rect2(92,64,245,16), float(player_mp)/float(player_max_mp), Color("#2c63b8"), "%d / %d" % [player_mp,player_max_mp])
	draw_string(ThemeDB.fallback_font, Vector2(94,97), "AC %d   ATK %d   GOLD %d" % [defense,attack_power,player_gold], HORIZONTAL_ALIGNMENT_LEFT, 240, 12, Color("#e0ca96"))

	draw_rect(Rect2(985,10,95,64), Color(0.04,0.04,0.03,0.90))
	draw_rect(Rect2(1085,10,95,64), Color(0.04,0.04,0.03,0.90))
	draw_rect(Rect2(1185,10,78,64), Color(0.04,0.04,0.03,0.90))
	draw_string(ThemeDB.fallback_font, Vector2(992,36), "변신", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color("#dcc796"))
	draw_string(ThemeDB.fallback_font, Vector2(1092,36), "인벤", HORIZONTAL_ALIGNMENT_CENTER, 80, 13, Color("#dcc796"))
	draw_string(ThemeDB.fallback_font, Vector2(1191,36), "≡", HORIZONTAL_ALIGNMENT_CENTER, 62, 24, Color("#f0dcae"))
	draw_string(ThemeDB.fallback_font, Vector2(1193,60), "메뉴", HORIZONTAL_ALIGNMENT_CENTER, 58, 10, Color("#bca981"))

	draw_string(ThemeDB.fallback_font, Vector2(18,130), "버프  ⚔ 공격  🛡 방어  EXP", HORIZONTAL_ALIGNMENT_LEFT, 300, 12, Color("#d8c79f"))

func _draw_bar(rect: Rect2, ratio: float, color: Color, text: String):
	draw_rect(rect, Color("#171717"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamp(ratio,0.0,1.0), rect.size.y)), color)
	draw_rect(rect, Color("#050505"), false, 1)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7,13), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x-8, 10, Color.WHITE)

func _draw_quest():
	draw_rect(Rect2(12,154,310,140), Color(0.03,0.035,0.03,0.78))
	draw_rect(Rect2(12,154,310,140), Color("#725a35"), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(26,178), "퀘스트 · 메인", HORIZONTAL_ALIGNMENT_LEFT, 270, 14, Color("#eadab7"))
	draw_string(ThemeDB.fallback_font, Vector2(26,205), "아덴 월드의 위협", HORIZONTAL_ALIGNMENT_LEFT, 270, 14, Color("#6ce089"))
	draw_string(ThemeDB.fallback_font, Vector2(26,230), "몬스터를 처치하며 장비를 성장시키세요.", HORIZONTAL_ALIGNMENT_LEFT, 270, 11, Color("#d5d5d5"))
	draw_string(ThemeDB.fallback_font, Vector2(26,255), "현재 지역 : 아덴 월드 · 숲길", HORIZONTAL_ALIGNMENT_LEFT, 270, 11, Color("#a8a08f"))
	draw_string(ThemeDB.fallback_font, Vector2(26,278), "좌표 %d, %d" % [int(player_pos.x),int(player_pos.y)], HORIZONTAL_ALIGNMENT_LEFT, 270, 10, Color("#7d7d7d"))

func _draw_touch_controls():
	draw_circle(JOY_CENTER, 75, Color(1,1,1,0.045))
	draw_circle(JOY_CENTER, 57, Color(1,1,1,0.03))
	draw_circle(JOY_CENTER, 75, Color(1,1,1,0.16), false, 1)
	draw_circle(joystick_knob, 25, Color(0.65,0.65,0.65,0.22))
	draw_circle(joystick_knob, 25, Color(1,1,1,0.22), false, 1)

	draw_circle(ATTACK_CENTER, 52, Color("#2b1915"))
	draw_circle(ATTACK_CENTER, 52, Color("#b89c64"), false, 2)
	draw_string(ThemeDB.fallback_font, ATTACK_CENTER + Vector2(-40,7), "공격", HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Color("#f0dfbc"))

	draw_circle(AUTO_CENTER, 38, Color("#3e321b") if auto_hunt else Color("#151510"))
	draw_circle(AUTO_CENTER, 38, Color("#e4b85c") if auto_hunt else Color("#79705b"), false, 2)
	draw_string(ThemeDB.fallback_font, AUTO_CENTER + Vector2(-32,4), "AUTO", HORIZONTAL_ALIGNMENT_CENTER, 64, 12, Color("#ffe7a5") if auto_hunt else Color("#ccc3ae"))

func _draw_bottom_ui():
	draw_rect(Rect2(0,662,1280,58), Color(0.025,0.025,0.02,0.92))
	var ratio := float(player_exp) / float(_exp_need())
	draw_rect(Rect2(10,704,260,7), Color("#201c15"))
	draw_rect(Rect2(10,704,260*ratio,7), Color("#e7a62d"))
	draw_string(ThemeDB.fallback_font, Vector2(12,687), "EXP %d / %d" % [player_exp,_exp_need()], HORIZONTAL_ALIGNMENT_LEFT, 250, 11, Color("#e7d6ab"))

	for i in range(6):
		var r := Rect2(430 + i*63, 667, 56, 48)
		draw_rect(r, Color("#0d141a"))
		draw_rect(r, Color("#80653b"), false, 1)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0,21), str(i+1), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color("#d7c59d"))
		draw_string(ThemeDB.fallback_font, r.position + Vector2(0,39), ["베기","강타","방패","질주","집중","귀환"][i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, Color("#a8c8e8"))

	var potion_rect := Rect2(1180,515,82,58)
	draw_rect(potion_rect, Color("#1a1110"))
	draw_rect(potion_rect, Color("#8a6842"), false, 1)
	draw_string(ThemeDB.fallback_font, potion_rect.position + Vector2(0,24), "물약", HORIZONTAL_ALIGNMENT_CENTER, 82, 13, Color("#ff8c8c"))
	draw_string(ThemeDB.fallback_font, potion_rect.position + Vector2(0,47), "x%d" % int(inventory.get("빨간 물약",0)), HORIZONTAL_ALIGNMENT_CENTER, 82, 11, Color.WHITE)

func _draw_panels():
	if status_open:
		draw_rect(Rect2(360,90,560,500), Color(0.03,0.035,0.03,0.96))
		draw_rect(Rect2(360,90,560,500), Color("#a17f48"), false, 2)
		draw_string(ThemeDB.fallback_font, Vector2(382,125), "캐릭터 정보 / 장비", HORIZONTAL_ALIGNMENT_LEFT, 500, 22, Color("#f0dfb6"))
		draw_string(ThemeDB.fallback_font, Vector2(382,160), "Lv.%d  황혼의 기사" % player_level, HORIZONTAL_ALIGNMENT_LEFT, 500, 17, Color.WHITE)
		draw_string(ThemeDB.fallback_font, Vector2(382,190), "HP %d/%d   MP %d/%d" % [player_hp,player_max_hp,player_mp,player_max_mp], HORIZONTAL_ALIGNMENT_LEFT, 500, 14, Color("#d7d7d7"))
		draw_string(ThemeDB.fallback_font, Vector2(382,222), "ATK %d    AC %d" % [attack_power,defense], HORIZONTAL_ALIGNMENT_LEFT, 500, 14, Color("#e2cc98"))
		var y := 265
		for key in ["STR","DEX","CON","INT","WIS","CHA"]:
			draw_string(ThemeDB.fallback_font, Vector2(395,y), "%s   %d" % [key,int(stats[key])], HORIZONTAL_ALIGNMENT_LEFT, 160, 15, Color("#efdfb4"))
			y += 34
		draw_string(ThemeDB.fallback_font, Vector2(590,265), "장비", HORIZONTAL_ALIGNMENT_LEFT, 240, 17, Color("#f0d69e"))
		draw_string(ThemeDB.fallback_font, Vector2(590,300), "무기   +6 황혼의 검", HORIZONTAL_ALIGNMENT_LEFT, 250, 14, Color("#cfaef5"))
		draw_string(ThemeDB.fallback_font, Vector2(590,334), "갑옷   +4 기사단 갑옷", HORIZONTAL_ALIGNMENT_LEFT, 250, 14, Color("#9fc5ff"))
		draw_string(ThemeDB.fallback_font, Vector2(590,368), "투구   +3 강철 투구", HORIZONTAL_ALIGNMENT_LEFT, 250, 14, Color("#d8d8d8"))
		draw_string(ThemeDB.fallback_font, Vector2(590,402), "장갑   가죽 장갑", HORIZONTAL_ALIGNMENT_LEFT, 250, 14, Color("#d8d8d8"))
		draw_string(ThemeDB.fallback_font, Vector2(590,436), "신발   강철 부츠", HORIZONTAL_ALIGNMENT_LEFT, 250, 14, Color("#d8d8d8"))
		draw_string(ThemeDB.fallback_font, Vector2(382,560), "캐릭터 HUD를 다시 누르면 닫힘", HORIZONTAL_ALIGNMENT_LEFT, 480, 11, Color("#888888"))

	if inventory_open:
		draw_rect(Rect2(895,84,365,520), Color(0.025,0.028,0.025,0.97))
		draw_rect(Rect2(895,84,365,520), Color("#9b7943"), false, 2)
		draw_string(ThemeDB.fallback_font, Vector2(915,118), "인벤토리", HORIZONTAL_ALIGNMENT_LEFT, 300, 20, Color("#ead7ae"))
		var y2 := 152
		for k in inventory.keys():
			draw_rect(Rect2(915,y2-22,320,34), Color(0.08,0.08,0.07,0.7))
			draw_string(ThemeDB.fallback_font, Vector2(925,y2), str(k), HORIZONTAL_ALIGNMENT_LEFT, 220, 13, Color("#e2e2e2"))
			draw_string(ThemeDB.fallback_font, Vector2(1150,y2), "x%s" % inventory[k], HORIZONTAL_ALIGNMENT_RIGHT, 70, 13, Color("#f0d07d"))
			y2 += 40

	if menu_open:
		draw_rect(Rect2(965,80,295,230), Color(0.025,0.025,0.02,0.97))
		draw_rect(Rect2(965,80,295,230), Color("#8e6d3d"), false, 2)
		var items := ["인벤토리","캐릭터/장비","저장하기","불러오기"]
		for i in range(items.size()):
			var rr := Rect2(975,86+i*52,280,46)
			draw_rect(rr, Color("#17130e"))
			draw_rect(rr, Color("#5e4a2d"), false, 1)
			draw_string(ThemeDB.fallback_font, rr.position + Vector2(14,29), items[i], HORIZONTAL_ALIGNMENT_LEFT, 250, 14, Color("#e5d1a4"))

	if current_target != null and int(current_target["hp"]) > 0:
		var r := float(current_target["hp"])/float(current_target["max_hp"])
		draw_rect(Rect2(550,315,180,10), Color("#202020"))
		draw_rect(Rect2(550,315,180*r,10), Color("#c92525"))
		draw_string(ThemeDB.fallback_font, Vector2(550,306), str(current_target["name"]), HORIZONTAL_ALIGNMENT_CENTER, 180, 11, Color("#f3e4c8"))

func _draw_message():
	if message == "":
		return
	draw_rect(Rect2(450,92,380,36), Color(0.02,0.02,0.02,0.86))
	draw_rect(Rect2(450,92,380,36), Color("#8f7141"), false, 1)
	draw_string(ThemeDB.fallback_font, Vector2(460,116), message, HORIZONTAL_ALIGNMENT_CENTER, 360, 13, Color("#f1e4c9"))
