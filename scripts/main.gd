extends Node2D

const SAVE_PATH = "user://twilight_v17_final_save.json"
const VIEW = Vector2(1280.0, 720.0)
const JOY_CENTER = Vector2(96.0, 585.0)
const ATTACK_CENTER = Vector2(1190.0, 600.0)
const AUTO_CENTER = Vector2(1080.0, 620.0)
const BASE36 = "0123456789abcdefghijklmnopqrstuvwxyz"

var map_catalog = []
var map_lookup = {}
var current_map_index = 0
var current_map = {}
var collision = PackedByteArray()
var map_width = 1
var map_height = 1
var tile_size = 32.0
var world_size = Vector2(1280.0, 720.0)
var camera_origin = Vector2.ZERO
var map_page = 0

var player_pos = Vector2(640.0, 380.0)
var player_speed = 235.0
var player_hp = 640
var player_max_hp = 640
var player_mp = 185
var player_max_mp = 185
var player_level = 55
var player_exp = 37
var player_gold = 125430
var attack_power = 37
var defense = 22
var stats = {"STR":18,"DEX":15,"CON":17,"INT":11,"WIS":13,"CHA":10}
var equipment = {
	"무기":"+6 황혼의 검",
	"갑옷":"+4 기사단 갑옷",
	"투구":"+3 강철 투구",
	"장갑":"가죽 장갑",
	"신발":"강철 부츠",
	"망토":"보호 망토"
}

var auto_hunt = false
var attack_cooldown = 0.0
var player_hit_cooldown = 0.0
var message = ""
var message_time = 0.0
var current_target = -1
var monsters = []
var drops = []
var inventory = {
	"빨간 물약":126,
	"초록 물약":42,
	"귀환 주문서":18,
	"철검":1,
	"가죽 갑옷":1
}
var item_names = ["철검","가죽 갑옷","강철 투구","보호 망토","빨간 물약","초록 물약"]

var joystick_touch = -1
var joystick_vector = Vector2.ZERO
var joystick_knob = JOY_CENTER

var status_open = false
var inventory_open = false
var menu_open = false
var map_open = false
var system_panel = ""
var inventory_page = 0

var transformations = [
	{"name":"기사","bonus":"근거리 명중 +1"},
	{"name":"검은 기사","bonus":"공격 속도 +3%"},
	{"name":"은빛 수호자","bonus":"AC -1"},
	{"name":"황혼의 검사","bonus":"근거리 대미지 +2"}
]
var dolls = [
	{"name":"작은 골렘","bonus":"리덕션 +1"},
	{"name":"요정 인형","bonus":"MP 회복 +2"},
	{"name":"기사 인형","bonus":"경험치 +3%"}
]
var relics = [
	{"name":"태양의 성물","bonus":"HP +50"},
	{"name":"달의 성물","bonus":"MP +30"},
	{"name":"고대의 성물","bonus":"모든 능력치 +1"}
]

func _ready():
	randomize()
	_load_map_database()
	_load_item_database()
	if map_catalog.size() > 0:
		_load_map_by_index(0)
	_show_message("V17 FINAL · 전체 맵 데이터 로드")
	queue_redraw()

func _process(delta):
	attack_cooldown = max(0.0, attack_cooldown - delta)
	player_hit_cooldown = max(0.0, player_hit_cooldown - delta)
	message_time = max(0.0, message_time - delta)
	if message_time <= 0.0:
		message = ""

	_handle_keyboard(delta)
	_update_auto_hunt(delta)
	_update_monsters(delta)
	_collect_nearby_drops()
	_update_camera()
	queue_redraw()

func _load_map_database():
	var f = FileAccess.open("res://data/maps_compact.json", FileAccess.READ)
	if f == null:
		_show_message("맵 DB를 찾을 수 없습니다")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_show_message("맵 DB 형식 오류")
		return
	map_catalog = parsed.get("maps", [])
	map_lookup.clear()
	for i in range(map_catalog.size()):
		var entry = map_catalog[i]
		map_lookup[str(entry.get("id", ""))] = i

func _load_item_database():
	var f = FileAccess.open("res://data/item_db.json", FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var pool = parsed.get("items", [])
	if typeof(pool) == TYPE_ARRAY and pool.size() > 0:
		item_names = pool

func _load_map_by_index(index):
	if map_catalog.size() == 0:
		return
	current_map_index = posmod(int(index), map_catalog.size())
	current_map = map_catalog[current_map_index]
	map_width = int(current_map.get("width", 40))
	map_height = int(current_map.get("height", 24))
	tile_size = float(current_map.get("tile_size", 32))
	world_size = Vector2(float(map_width) * tile_size, float(map_height) * tile_size)
	collision = _decode_rle(str(current_map.get("collision_rle", "")))
	var spawn = current_map.get("spawn", [map_width / 2, map_height / 2])
	var sc = int(spawn[0])
	var sr = int(spawn[1])
	player_pos = _cell_center(sc, sr)
	if not _can_walk(player_pos):
		player_pos = _find_any_walkable_center()
	monsters.clear()
	drops.clear()
	current_target = -1
	_spawn_monsters(18)
	_update_camera()
	_show_message(str(current_map.get("name", "맵")))

func _decode_rle(text):
	var out = PackedByteArray()
	var i = 0
	while i < text.length():
		var marker = text.substr(i, 1)
		var value = 0
		if marker == "b":
			value = 1
		i += 1
		var digits = ""
		while i < text.length():
			var ch = text.substr(i, 1)
			if ch == "a" or ch == "b":
				break
			digits += ch
			i += 1
		var count = _base36_to_int(digits)
		for _j in range(count):
			out.append(value)
	return out

func _base36_to_int(text):
	var total = 0
	for i in range(text.length()):
		var idx = BASE36.find(text.substr(i, 1))
		if idx < 0:
			idx = 0
		total = total * 36 + idx
	return total

func _cell_center(c, r):
	return Vector2((float(c) + 0.5) * tile_size, (float(r) + 0.5) * tile_size)

func _world_to_cell(pos):
	return Vector2i(int(floor(pos.x / tile_size)), int(floor(pos.y / tile_size)))

func _cell_blocked(c, r):
	if c < 0 or r < 0 or c >= map_width or r >= map_height:
		return true
	var idx = r * map_width + c
	if idx < 0 or idx >= collision.size():
		return true
	return int(collision[idx]) != 0

func _can_walk(pos):
	var cell = _world_to_cell(pos)
	return not _cell_blocked(cell.x, cell.y)

func _find_any_walkable_center():
	for r in range(map_height):
		for c in range(map_width):
			if not _cell_blocked(c, r):
				return _cell_center(c, r)
	return Vector2(tile_size * 0.5, tile_size * 0.5)

func _random_walkable_center_near(origin, min_tiles, max_tiles):
	for _attempt in range(300):
		var angle = randf() * TAU
		var dist = randf_range(float(min_tiles), float(max_tiles)) * tile_size
		var p = origin + Vector2(cos(angle), sin(angle)) * dist
		p.x = clamp(p.x, tile_size * 0.5, max(tile_size * 0.5, world_size.x - tile_size * 0.5))
		p.y = clamp(p.y, tile_size * 0.5, max(tile_size * 0.5, world_size.y - tile_size * 0.5))
		if _can_walk(p):
			return p
	return _find_any_walkable_center()

func _handle_keyboard(delta):
	var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if joystick_vector.length() > 0.05:
		dir = joystick_vector
	if dir.length() > 0.0:
		_move_player(dir.normalized() * player_speed * delta)

	if Input.is_action_just_pressed("attack"):
		_attack_nearest()
	if Input.is_action_just_pressed("toggle_auto"):
		_toggle_auto()
	if Input.is_action_just_pressed("open_inventory"):
		_toggle_inventory()
	if Input.is_action_just_pressed("open_menu"):
		_toggle_menu()
	if Input.is_action_just_pressed("open_map"):
		_open_map_panel()
	if Input.is_action_just_pressed("quick_potion"):
		_use_potion()
	if Input.is_action_just_pressed("save_game"):
		save_game()
	if Input.is_action_just_pressed("load_game"):
		load_game()
	if Input.is_action_just_pressed("next_map"):
		_load_map_by_index(current_map_index + 1)
	if Input.is_action_just_pressed("prev_map"):
		_load_map_by_index(current_map_index - 1)

func _move_player(step):
	var next_x = Vector2(player_pos.x + step.x, player_pos.y)
	if _can_walk(next_x):
		player_pos.x = next_x.x
	var next_y = Vector2(player_pos.x, player_pos.y + step.y)
	if _can_walk(next_y):
		player_pos.y = next_y.y

func _input(event):
	if event is InputEventScreenTouch:
		var p = _to_view(event.position)
		if event.pressed:
			if p.x < 220.0 and p.y > 455.0:
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
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_tap(_to_view(event.position))

func _to_view(screen_pos):
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos

func _set_joystick(p):
	var delta = p - JOY_CENTER
	var radius = 58.0
	if delta.length() > radius:
		delta = delta.normalized() * radius
	joystick_knob = JOY_CENTER + delta
	joystick_vector = delta / radius
	if joystick_vector.length() > 1.0:
		joystick_vector = joystick_vector.normalized()

func _handle_tap(p):
	if map_open:
		_handle_map_panel_tap(p)
		return
	if inventory_open:
		if Rect2(930, 90, 320, 500).has_point(p):
			return
	if status_open or system_panel != "":
		if Rect2(350, 90, 580, 500).has_point(p):
			return

	if p.distance_to(ATTACK_CENTER) < 62.0:
		_attack_nearest()
		return
	if p.distance_to(AUTO_CENTER) < 48.0:
		_toggle_auto()
		return
	if Rect2(15, 10, 345, 96).has_point(p):
		status_open = not status_open
		inventory_open = false
		menu_open = false
		map_open = false
		system_panel = ""
		return
	if Rect2(815, 10, 68, 64).has_point(p):
		_handle_menu_option("transform")
		return
	if Rect2(888, 10, 68, 64).has_point(p):
		_handle_menu_option("doll")
		return
	if Rect2(961, 10, 68, 64).has_point(p):
		_handle_menu_option("relic")
		return
	if Rect2(1080, 10, 96, 64).has_point(p):
		_toggle_inventory()
		return
	if Rect2(1182, 10, 82, 64).has_point(p):
		_toggle_menu()
		return
	if Rect2(1172, 515, 92, 60).has_point(p):
		_use_potion()
		return

	if menu_open:
		var options = ["inventory","status","transform","doll","relic","map","save","load"]
		for i in range(options.size()):
			var rr = Rect2(965, 82 + i * 48, 295, 43)
			if rr.has_point(p):
				_handle_menu_option(options[i])
				return

func _handle_menu_option(option):
	menu_open = false
	status_open = false
	inventory_open = false
	map_open = false
	system_panel = ""
	if option == "inventory":
		inventory_open = true
	elif option == "status":
		status_open = true
	elif option == "transform" or option == "doll" or option == "relic":
		system_panel = option
	elif option == "map":
		_open_map_panel()
	elif option == "save":
		save_game()
	elif option == "load":
		load_game()

func _toggle_inventory():
	inventory_open = not inventory_open
	status_open = false
	menu_open = false
	map_open = false
	system_panel = ""

func _toggle_menu():
	menu_open = not menu_open
	inventory_open = false
	status_open = false
	map_open = false
	system_panel = ""

func _open_map_panel():
	map_open = true
	menu_open = false
	inventory_open = false
	status_open = false
	system_panel = ""
	map_page = int(current_map_index / 9)

func _handle_map_panel_tap(p):
	var panel = Rect2(265, 70, 750, 580)
	if not panel.has_point(p):
		map_open = false
		return
	var total_pages = int(ceil(float(map_catalog.size()) / 9.0))
	if Rect2(305, 590, 110, 42).has_point(p):
		map_page = max(0, map_page - 1)
		return
	if Rect2(865, 590, 110, 42).has_point(p):
		map_page = min(max(0, total_pages - 1), map_page + 1)
		return
	if Rect2(925, 83, 65, 38).has_point(p):
		map_open = false
		return
	var start = map_page * 9
	for i in range(9):
		var idx = start + i
		if idx >= map_catalog.size():
			break
		var col = i % 3
		var row = int(i / 3)
		var rr = Rect2(300 + col * 230, 155 + row * 120, 210, 96)
		if rr.has_point(p):
			map_open = false
			_load_map_by_index(idx)
			return

func _spawn_monsters(count):
	monsters.clear()
	var names = _monster_names_for_current_map()
	for i in range(count):
		var hp = randi_range(80, 165)
		var p = _random_walkable_center_near(player_pos, 4, 20)
		monsters.append({
			"name":names[randi() % names.size()],
			"level":randi_range(max(1, player_level - 5), player_level + 4),
			"pos":p,
			"hp":hp,
			"max_hp":hp,
			"speed":randf_range(34.0, 58.0),
			"damage":randi_range(3, 9),
			"exp":randi_range(3, 7),
			"gold":randi_range(18, 65),
			"attack_cd":randf_range(0.0, 0.7),
			"respawn":0.0
		})

func _monster_names_for_current_map():
	var id = str(current_map.get("id", ""))
	if id.begins_with("oman_"):
		return ["탑 수호병","망령 기사","고대 골렘","어둠의 감시자"]
	if id.begins_with("albino_"):
		return ["백색 야수","알비노 전사","서리 마물","분지 수호자"]
	if id.begins_with("escaros_"):
		return ["타락 기사","균열 사냥꾼","붉은 수호병","에스카로스 마물"]
	if id.begins_with("faith_"):
		return ["신념의 파수꾼","봉인된 망령","탑 사제","고대 수호자"]
	if id.begins_with("domination"):
		return ["지배의 기사","정상 수호자","고대 장군","탑의 망령"]
	return ["오크 전사","해골 병사","늑대인간","다크 엘프","숲의 수호자"]

func _update_monsters(delta):
	for i in range(monsters.size()):
		var m = monsters[i]
		if int(m.get("hp", 0)) <= 0:
			m["respawn"] = float(m.get("respawn", 0.0)) - delta
			if float(m["respawn"]) <= 0.0:
				_respawn_monster(i)
			continue
		m["attack_cd"] = max(0.0, float(m.get("attack_cd", 0.0)) - delta)
		var pos = m["pos"]
		var dist = pos.distance_to(player_pos)
		if dist < 260.0 and dist > 46.0:
			var dir = (player_pos - pos).normalized()
			var candidate = pos + dir * float(m["speed"]) * delta
			if _can_walk(candidate):
				m["pos"] = candidate
		elif dist <= 46.0 and float(m["attack_cd"]) <= 0.0:
			player_hp = max(0, player_hp - int(m["damage"]))
			m["attack_cd"] = 0.72
			if player_hp <= 0:
				_respawn_player()

func _update_auto_hunt(delta):
	if not auto_hunt:
		return
	var idx = _nearest_alive_monster_index()
	if idx < 0:
		return
	current_target = idx
	var target = monsters[idx]
	var dist = target["pos"].distance_to(player_pos)
	if dist > 66.0:
		var dir = (target["pos"] - player_pos).normalized()
		_move_player(dir * player_speed * 0.82 * delta)
	elif attack_cooldown <= 0.0:
		_attack_target(idx)

func _nearest_alive_monster_index():
	var best = -1
	var best_dist = INF
	for i in range(monsters.size()):
		var m = monsters[i]
		if int(m.get("hp", 0)) <= 0:
			continue
		var d = m["pos"].distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best = i
	return best

func _attack_nearest():
	var idx = _nearest_alive_monster_index()
	if idx < 0:
		_show_message("주변에 대상이 없습니다")
		return
	current_target = idx
	var dist = monsters[idx]["pos"].distance_to(player_pos)
	if dist > 105.0:
		_show_message("대상이 너무 멉니다")
		return
	_attack_target(idx)

func _attack_target(idx):
	if idx < 0 or idx >= monsters.size():
		return
	if attack_cooldown > 0.0:
		return
	var m = monsters[idx]
	if int(m.get("hp", 0)) <= 0:
		return
	var dmg = max(1, attack_power + randi_range(-5, 9))
	m["hp"] = max(0, int(m["hp"]) - dmg)
	attack_cooldown = 0.48
	if int(m["hp"]) <= 0:
		_on_monster_killed(idx)

func _on_monster_killed(idx):
	var m = monsters[idx]
	player_exp += int(m["exp"])
	player_gold += int(m["gold"])
	var drop_name = "빨간 물약"
	if item_names.size() > 0 and randf() < 0.45:
		drop_name = str(item_names[randi() % item_names.size()])
	drops.append({"pos":m["pos"],"name":drop_name})
	m["respawn"] = 3.0
	_show_message("%s 처치 · %d 아데나" % [str(m["name"]), int(m["gold"])])
	_check_level_up()

func _respawn_monster(idx):
	if idx < 0 or idx >= monsters.size():
		return
	var m = monsters[idx]
	var hp = randi_range(85, 175)
	m["pos"] = _random_walkable_center_near(player_pos, 6, 22)
	m["max_hp"] = hp
	m["hp"] = hp
	m["respawn"] = 0.0
	m["attack_cd"] = randf_range(0.0, 0.7)

func _respawn_player():
	player_hp = player_max_hp
	player_mp = player_max_mp
	var spawn = current_map.get("spawn", [map_width / 2, map_height / 2])
	player_pos = _cell_center(int(spawn[0]), int(spawn[1]))
	if not _can_walk(player_pos):
		player_pos = _find_any_walkable_center()
	auto_hunt = false
	_show_message("안전 지점에서 부활했습니다")

func _check_level_up():
	var need = _exp_need()
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
		_show_message("LEVEL UP · Lv.%d" % player_level)
		need = _exp_need()

func _exp_need():
	return 100 + max(0, player_level - 1) * 12

func _collect_nearby_drops():
	for d in drops.duplicate():
		if d["pos"].distance_to(player_pos) < 38.0:
			var n = str(d["name"])
			inventory[n] = int(inventory.get(n, 0)) + 1
			drops.erase(d)
			_show_message("%s 획득" % n)

func _use_potion():
	var count = int(inventory.get("빨간 물약", 0))
	if count <= 0:
		_show_message("빨간 물약이 없습니다")
		return
	if player_hp >= player_max_hp:
		_show_message("HP가 가득 차 있습니다")
		return
	inventory["빨간 물약"] = count - 1
	player_hp = min(player_max_hp, player_hp + 190)
	_show_message("빨간 물약 사용")

func _toggle_auto():
	auto_hunt = not auto_hunt
	_show_message("자동사냥 %s" % ("ON" if auto_hunt else "OFF"))

func _show_message(text):
	message = str(text)
	message_time = 2.2

func _update_camera():
	var desired = player_pos - VIEW * 0.5
	var max_x = max(0.0, world_size.x - VIEW.x)
	var max_y = max(0.0, world_size.y - VIEW.y)
	camera_origin = Vector2(clamp(desired.x, 0.0, max_x), clamp(desired.y, 0.0, max_y))

func _world_to_screen(pos):
	return pos - camera_origin

func save_game():
	var data = {
		"map_id":str(current_map.get("id", "aden_world")),
		"player_pos":[player_pos.x, player_pos.y],
		"hp":player_hp,"max_hp":player_max_hp,
		"mp":player_mp,"max_mp":player_max_mp,
		"level":player_level,"exp":player_exp,"gold":player_gold,
		"attack":attack_power,"defense":defense,
		"stats":stats,"equipment":equipment,"inventory":inventory
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		_show_message("저장 완료")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		_show_message("저장 데이터가 없습니다")
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		_show_message("저장 데이터 오류")
		return
	var map_id = str(data.get("map_id", "aden_world"))
	if map_lookup.has(map_id):
		_load_map_by_index(int(map_lookup[map_id]))
	var p = data.get("player_pos", [player_pos.x, player_pos.y])
	player_pos = Vector2(float(p[0]), float(p[1]))
	if not _can_walk(player_pos):
		player_pos = _find_any_walkable_center()
	player_hp = int(data.get("hp", player_hp))
	player_max_hp = int(data.get("max_hp", player_max_hp))
	player_mp = int(data.get("mp", player_mp))
	player_max_mp = int(data.get("max_mp", player_max_mp))
	player_level = int(data.get("level", player_level))
	player_exp = int(data.get("exp", player_exp))
	player_gold = int(data.get("gold", player_gold))
	attack_power = int(data.get("attack", attack_power))
	defense = int(data.get("defense", defense))
	stats = data.get("stats", stats)
	equipment = data.get("equipment", equipment)
	inventory = data.get("inventory", inventory)
	_show_message("불러오기 완료")

func _draw():
	_draw_map_world()
	_draw_drops()
	_draw_monsters()
	_draw_player()
	_draw_target_hud()
	_draw_top_hud()
	_draw_quest_panel()
	_draw_minimap()
	_draw_touch_controls()
	_draw_bottom_ui()
	_draw_panels()
	_draw_message()

func _map_colors():
	var id = str(current_map.get("id", ""))
	if id.begins_with("oman_"):
		return {"floor":Color("#51463f"),"alt":Color("#5e5147"),"block":Color("#171415"),"edge":Color("#9a8066"),"accent":Color("#a55c48")}
	if id.begins_with("albino_"):
		return {"floor":Color("#66706b"),"alt":Color("#727c76"),"block":Color("#1f2927"),"edge":Color("#b5c5bd"),"accent":Color("#6d9b92")}
	if id.begins_with("escaros_"):
		return {"floor":Color("#4c3c38"),"alt":Color("#594540"),"block":Color("#181315"),"edge":Color("#9c6554"),"accent":Color("#9b3d38")}
	if id.begins_with("faith_"):
		return {"floor":Color("#423c50"),"alt":Color("#4d465c"),"block":Color("#15131a"),"edge":Color("#8b7ca4"),"accent":Color("#6e5a91")}
	if id.begins_with("domination"):
		return {"floor":Color("#5d5541"),"alt":Color("#6a614a"),"block":Color("#18160f"),"edge":Color("#b7a36c"),"accent":Color("#a68438")}
	return {"floor":Color("#586342"),"alt":Color("#66714a"),"block":Color("#192219"),"edge":Color("#9a8b62"),"accent":Color("#6f874e")}

func _draw_map_world():
	var colors = _map_colors()
	draw_rect(Rect2(Vector2.ZERO, VIEW), colors["block"])
	var start_c = max(0, int(floor(camera_origin.x / tile_size)) - 1)
	var end_c = min(map_width - 1, int(ceil((camera_origin.x + VIEW.x) / tile_size)) + 1)
	var start_r = max(0, int(floor(camera_origin.y / tile_size)) - 1)
	var end_r = min(map_height - 1, int(ceil((camera_origin.y + VIEW.y) / tile_size)) + 1)
	for r in range(start_r, end_r + 1):
		for c in range(start_c, end_c + 1):
			var sp = Vector2(float(c) * tile_size, float(r) * tile_size) - camera_origin
			var rr = Rect2(sp, Vector2(tile_size + 1.0, tile_size + 1.0))
			if _cell_blocked(c, r):
				if ((c * 17 + r * 29) % 31) == 0:
					draw_circle(sp + Vector2(tile_size * 0.5, tile_size * 0.5), tile_size * 0.22, Color(colors["accent"].r, colors["accent"].g, colors["accent"].b, 0.22))
				continue
			var floor_color = colors["floor"] if ((c + r) % 2 == 0) else colors["alt"]
			draw_rect(rr, floor_color)
			if ((c * 11 + r * 7) % 19) == 0:
				draw_circle(sp + Vector2(tile_size * 0.55, tile_size * 0.48), 2.0, Color(1,1,1,0.10))
			if _cell_blocked(c, r - 1):
				draw_line(sp, sp + Vector2(tile_size, 0), colors["edge"], 1.3)
			if _cell_blocked(c - 1, r):
				draw_line(sp, sp + Vector2(0, tile_size), colors["edge"], 1.3)
			if _cell_blocked(c, r + 1):
				draw_line(sp + Vector2(0, tile_size), sp + Vector2(tile_size, tile_size), Color(colors["edge"].r, colors["edge"].g, colors["edge"].b, 0.65), 1.0)
			if _cell_blocked(c + 1, r):
				draw_line(sp + Vector2(tile_size, 0), sp + Vector2(tile_size, tile_size), Color(colors["edge"].r, colors["edge"].g, colors["edge"].b, 0.65), 1.0)

func _draw_drops():
	for d in drops:
		var p = _world_to_screen(d["pos"])
		if p.x < -50 or p.y < -50 or p.x > 1330 or p.y > 770:
			continue
		draw_circle(p, 7, Color("#f1ca45"))
		draw_circle(p, 11, Color(1.0,0.8,0.2,0.28), false, 2.0)
		draw_string(ThemeDB.fallback_font, p + Vector2(-45,-14), str(d["name"]), HORIZONTAL_ALIGNMENT_CENTER, 90, 10, Color("#ffe9a0"))

func _draw_monsters():
	for i in range(monsters.size()):
		var m = monsters[i]
		if int(m.get("hp", 0)) <= 0:
			continue
		var p = _world_to_screen(m["pos"])
		if p.x < -70 or p.y < -70 or p.x > 1350 or p.y > 790:
			continue
		var selected = i == current_target
		draw_circle(p + Vector2(0,8), 16, Color(0,0,0,0.32))
		draw_circle(p, 17, Color("#752e26"))
		draw_circle(p + Vector2(-5,-4), 3, Color("#e6bf7a"))
		draw_circle(p + Vector2(5,-4), 3, Color("#e6bf7a"))
		draw_circle(p, 23, Color("#e2c173") if selected else Color("#44312a"), false, 2.0)
		var ratio = float(m["hp"]) / max(1.0, float(m["max_hp"]))
		draw_rect(Rect2(p + Vector2(-25,-35), Vector2(50,6)), Color("#1c0908"))
		draw_rect(Rect2(p + Vector2(-25,-35), Vector2(50.0 * ratio,6)), Color("#d12c28"))
		draw_string(ThemeDB.fallback_font, p + Vector2(-45,-43), "%s Lv.%d" % [str(m["name"]), int(m["level"])], HORIZONTAL_ALIGNMENT_CENTER, 90, 10, Color("#f0e0c2"))

func _draw_player():
	var p = _world_to_screen(player_pos)
	draw_circle(p + Vector2(0,10), 18, Color(0,0,0,0.36))
	draw_circle(p, 18, Color("#375e8c"))
	draw_rect(Rect2(p + Vector2(-7,-21), Vector2(14,17)), Color("#c8c0ae"))
	draw_line(p + Vector2(5,-10), p + Vector2(21,-28), Color("#e6d3a5"), 4.0)
	draw_circle(p, 24, Color("#d8c28c"), false, 2.0)

func _draw_target_hud():
	if current_target < 0 or current_target >= monsters.size():
		return
	var m = monsters[current_target]
	if int(m.get("hp",0)) <= 0:
		return
	var ratio = float(m["hp"]) / max(1.0, float(m["max_hp"]))
	draw_rect(Rect2(545, 314, 190, 10), Color("#1f1720"))
	draw_rect(Rect2(545, 314, 190.0 * ratio, 10), Color("#c72c28"))
	draw_string(ThemeDB.fallback_font, Vector2(545,306), str(m["name"]), HORIZONTAL_ALIGNMENT_CENTER, 190, 11, Color("#f1e0c0"))

func _draw_top_hud():
	draw_rect(Rect2(12,10,348,96), Color(0.025,0.025,0.02,0.91))
	draw_rect(Rect2(12,10,348,96), Color("#8d6b3e"), false, 1.5)
	draw_circle(Vector2(56,56), 38, Color("#1f1a14"))
	draw_circle(Vector2(56,56), 34, Color("#425f7a"))
	draw_string(ThemeDB.fallback_font, Vector2(32,62), "기사", HORIZONTAL_ALIGNMENT_CENTER, 48, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(92,33), "황혼의 기사 · Lv.%d" % player_level, HORIZONTAL_ALIGNMENT_LEFT, 245, 16, Color("#f2e5c8"))
	_draw_bar(Rect2(92,43,246,17), float(player_hp) / max(1.0,float(player_max_hp)), Color("#c62d2a"), "%d / %d" % [player_hp,player_max_hp])
	_draw_bar(Rect2(92,65,246,15), float(player_mp) / max(1.0,float(player_max_mp)), Color("#285eae"), "%d / %d" % [player_mp,player_max_mp])
	draw_string(ThemeDB.fallback_font, Vector2(94,99), "AC %d   ATK %d   %d 아데나" % [defense,attack_power,player_gold], HORIZONTAL_ALIGNMENT_LEFT, 240, 11, Color("#e0c992"))

	var top_labels = ["변신","인형","성물","인벤","≡"]
	var top_x = [815,888,961,1080,1182]
	var top_w = [68,68,68,96,82]
	for i in range(top_labels.size()):
		var rr = Rect2(top_x[i],10,top_w[i],64)
		draw_rect(rr, Color(0.025,0.025,0.02,0.91))
		draw_rect(rr, Color("#705735"), false, 1.0)
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(0,38), top_labels[i], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 14 if i < 4 else 25, Color("#e5d0a2"))

	draw_rect(Rect2(12,116,300,34), Color(0.03,0.03,0.025,0.75))
	draw_string(ThemeDB.fallback_font, Vector2(22,138), "버프   공격↑   방어↑   경험치↑   속도↑", HORIZONTAL_ALIGNMENT_LEFT, 280, 11, Color("#d7c79e"))

func _draw_bar(rect, ratio, color, text):
	draw_rect(rect, Color("#151515"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamp(ratio,0.0,1.0), rect.size.y)), color)
	draw_rect(rect, Color("#050505"), false, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(7,12), text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 9, 9, Color.WHITE)

func _draw_quest_panel():
	draw_rect(Rect2(12,157,315,143), Color(0.025,0.03,0.025,0.80))
	draw_rect(Rect2(12,157,315,143), Color("#705835"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(26,180), "메인 퀘스트", HORIZONTAL_ALIGNMENT_LEFT, 280, 13, Color("#e7d3aa"))
	draw_string(ThemeDB.fallback_font, Vector2(26,205), str(current_map.get("name","아덴 월드")), HORIZONTAL_ALIGNMENT_LEFT, 280, 13, Color("#70df91"))
	draw_string(ThemeDB.fallback_font, Vector2(26,230), "지역 몬스터 처치 및 장비 성장", HORIZONTAL_ALIGNMENT_LEFT, 280, 11, Color("#dddddd"))
	draw_string(ThemeDB.fallback_font, Vector2(26,254), "AUTO로 자동 사냥 가능", HORIZONTAL_ALIGNMENT_LEFT, 280, 10, Color("#b2a891"))
	var cell = _world_to_cell(player_pos)
	draw_string(ThemeDB.fallback_font, Vector2(26,280), "좌표 %d, %d · 맵 %d/%d" % [cell.x,cell.y,current_map_index+1,map_catalog.size()], HORIZONTAL_ALIGNMENT_LEFT, 280, 10, Color("#868686"))

func _draw_minimap():
	var rr = Rect2(1030,90,230,150)
	draw_rect(rr, Color(0.02,0.02,0.02,0.82))
	draw_rect(rr, Color("#80643b"), false, 1.0)
	var sx = rr.size.x / max(1.0, world_size.x)
	var sy = rr.size.y / max(1.0, world_size.y)
	var pp = rr.position + Vector2(player_pos.x * sx, player_pos.y * sy)
	draw_circle(pp, 4, Color("#74b7ff"))
	for m in monsters:
		if int(m.get("hp",0)) <= 0:
			continue
		var mp = rr.position + Vector2(m["pos"].x * sx, m["pos"].y * sy)
		draw_circle(mp, 2, Color("#de5a50"))
	draw_string(ThemeDB.fallback_font, rr.position + Vector2(7,14), "MINI MAP", HORIZONTAL_ALIGNMENT_LEFT, 100, 9, Color("#d8c392"))

func _draw_touch_controls():
	draw_circle(JOY_CENTER, 75, Color(1,1,1,0.045))
	draw_circle(JOY_CENTER, 58, Color(1,1,1,0.03))
	draw_circle(JOY_CENTER, 75, Color(1,1,1,0.15), false, 1.0)
	draw_circle(joystick_knob, 25, Color(0.68,0.68,0.68,0.22))
	draw_circle(joystick_knob, 25, Color(1,1,1,0.22), false, 1.0)

	draw_circle(ATTACK_CENTER, 53, Color("#291815"))
	draw_circle(ATTACK_CENTER, 53, Color("#b99a61"), false, 2.0)
	draw_string(ThemeDB.fallback_font, ATTACK_CENTER + Vector2(-43,7), "공격", HORIZONTAL_ALIGNMENT_CENTER, 86, 18, Color("#f0deb9"))

	draw_circle(AUTO_CENTER, 39, Color("#42331a") if auto_hunt else Color("#15150f"))
	draw_circle(AUTO_CENTER, 39, Color("#e1b457") if auto_hunt else Color("#77705b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, AUTO_CENTER + Vector2(-34,4), "AUTO", HORIZONTAL_ALIGNMENT_CENTER, 68, 12, Color("#ffe5a1") if auto_hunt else Color("#c9c0ab"))

func _draw_bottom_ui():
	draw_rect(Rect2(0,660,1280,60), Color(0.02,0.02,0.018,0.94))
	var ratio = float(player_exp) / max(1.0,float(_exp_need()))
	draw_rect(Rect2(10,704,260,7), Color("#211d15"))
	draw_rect(Rect2(10,704,260.0 * ratio,7), Color("#e5a229"))
	draw_string(ThemeDB.fallback_font, Vector2(12,686), "EXP %d / %d" % [player_exp,_exp_need()], HORIZONTAL_ALIGNMENT_LEFT, 250, 11, Color("#e7d4a7"))
	var skills = ["베기","강타","방패","질주","집중","귀환"]
	for i in range(6):
		var rr = Rect2(430 + i * 63, 666, 56, 48)
		draw_rect(rr, Color("#0d141a"))
		draw_rect(rr, Color("#80643a"), false, 1.0)
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(0,19), str(i+1), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 11, Color("#d8c49a"))
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(0,39), skills[i], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 8, Color("#a8c8e7"))
	var potion = Rect2(1172,515,92,60)
	draw_rect(potion, Color("#1b1110"))
	draw_rect(potion, Color("#896740"), false, 1.0)
	draw_string(ThemeDB.fallback_font, potion.position + Vector2(0,24), "물약", HORIZONTAL_ALIGNMENT_CENTER, potion.size.x, 13, Color("#ff8c8c"))
	draw_string(ThemeDB.fallback_font, potion.position + Vector2(0,48), "x%d" % int(inventory.get("빨간 물약",0)), HORIZONTAL_ALIGNMENT_CENTER, potion.size.x, 11, Color.WHITE)

func _draw_panels():
	if menu_open:
		_draw_menu_panel()
	if status_open:
		_draw_status_panel()
	if inventory_open:
		_draw_inventory_panel()
	if map_open:
		_draw_map_panel()
	if system_panel != "":
		_draw_system_panel()

func _draw_menu_panel():
	var labels = ["인벤토리","캐릭터/장비","변신","마법인형","성물","월드맵","저장하기","불러오기"]
	draw_rect(Rect2(955,76,310,400), Color(0.02,0.02,0.018,0.97))
	draw_rect(Rect2(955,76,310,400), Color("#89683c"), false, 2.0)
	for i in range(labels.size()):
		var rr = Rect2(965,82 + i*48,295,43)
		draw_rect(rr, Color("#17130e"))
		draw_rect(rr, Color("#554329"), false, 1.0)
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(14,28), labels[i], HORIZONTAL_ALIGNMENT_LEFT, 265, 14, Color("#e5d0a1"))

func _draw_status_panel():
	var panel = Rect2(350,90,580,500)
	draw_rect(panel, Color(0.025,0.03,0.025,0.97))
	draw_rect(panel, Color("#a07d47"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(375,128), "캐릭터 정보 / 장비", HORIZONTAL_ALIGNMENT_LEFT, 520, 22, Color("#f0dfb5"))
	draw_string(ThemeDB.fallback_font, Vector2(375,163), "Lv.%d  황혼의 기사" % player_level, HORIZONTAL_ALIGNMENT_LEFT, 520, 17, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(375,193), "HP %d/%d   MP %d/%d" % [player_hp,player_max_hp,player_mp,player_max_mp], HORIZONTAL_ALIGNMENT_LEFT, 520, 14, Color("#dddddd"))
	draw_string(ThemeDB.fallback_font, Vector2(375,225), "ATK %d   AC %d   GOLD %d" % [attack_power,defense,player_gold], HORIZONTAL_ALIGNMENT_LEFT, 520, 14, Color("#e1ca95"))
	var y = 270
	for key in ["STR","DEX","CON","INT","WIS","CHA"]:
		draw_string(ThemeDB.fallback_font, Vector2(390,y), "%s   %d" % [key,int(stats[key])], HORIZONTAL_ALIGNMENT_LEFT, 160, 15, Color("#efdfb4"))
		y += 34
	draw_string(ThemeDB.fallback_font, Vector2(590,270), "장비", HORIZONTAL_ALIGNMENT_LEFT, 250, 17, Color("#f0d69c"))
	var ey = 305
	for slot in equipment.keys():
		draw_string(ThemeDB.fallback_font, Vector2(590,ey), "%s   %s" % [str(slot),str(equipment[slot])], HORIZONTAL_ALIGNMENT_LEFT, 300, 13, Color("#d8d8d8"))
		ey += 33

func _draw_inventory_panel():
	var panel = Rect2(900,82,365,525)
	draw_rect(panel, Color(0.022,0.026,0.022,0.98))
	draw_rect(panel, Color("#987542"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(920,118), "인벤토리", HORIZONTAL_ALIGNMENT_LEFT, 300, 20, Color("#ead7ad"))
	var keys = inventory.keys()
	keys.sort()
	var start = inventory_page * 10
	var y = 155
	for i in range(10):
		var idx = start + i
		if idx >= keys.size():
			break
		var key = keys[idx]
		draw_rect(Rect2(918,y-22,325,35), Color("#12130f"))
		draw_string(ThemeDB.fallback_font, Vector2(928,y), str(key), HORIZONTAL_ALIGNMENT_LEFT, 230, 12, Color("#e2e2e2"))
		draw_string(ThemeDB.fallback_font, Vector2(1160,y), "x%s" % inventory[key], HORIZONTAL_ALIGNMENT_RIGHT, 70, 12, Color("#f0cf79"))
		y += 40
	draw_string(ThemeDB.fallback_font, Vector2(920,585), "아이템 종류 %d" % keys.size(), HORIZONTAL_ALIGNMENT_LEFT, 300, 10, Color("#8f8f8f"))

func _draw_map_panel():
	var panel = Rect2(265,70,750,580)
	draw_rect(panel, Color(0.02,0.024,0.02,0.985))
	draw_rect(panel, Color("#a17b43"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(295,112), "월드 / 던전 이동", HORIZONTAL_ALIGNMENT_LEFT, 500, 23, Color("#f1dfb3"))
	draw_string(ThemeDB.fallback_font, Vector2(925,108), "닫기", HORIZONTAL_ALIGNMENT_CENTER, 65, 13, Color("#d9c393"))
	var total_pages = int(ceil(float(map_catalog.size()) / 9.0))
	var start = map_page * 9
	for i in range(9):
		var idx = start + i
		if idx >= map_catalog.size():
			break
		var col = i % 3
		var row = int(i / 3)
		var rr = Rect2(300 + col * 230, 155 + row * 120, 210, 96)
		var entry = map_catalog[idx]
		var active = idx == current_map_index
		draw_rect(rr, Color("#49381f") if active else Color("#151711"))
		draw_rect(rr, Color("#d0a85d") if active else Color("#6e5734"), false, 1.5)
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(9,25), str(entry.get("group","지역")), HORIZONTAL_ALIGNMENT_LEFT, 190, 10, Color("#a9a18f"))
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(9,52), str(entry.get("name","맵")), HORIZONTAL_ALIGNMENT_LEFT, 190, 12, Color("#f0ddb4"))
		draw_string(ThemeDB.fallback_font, rr.position + Vector2(9,78), "%dx%d 충돌맵" % [int(entry.get("width",0)),int(entry.get("height",0))], HORIZONTAL_ALIGNMENT_LEFT, 190, 9, Color("#8b8b8b"))
	draw_rect(Rect2(305,590,110,42), Color("#211a10"))
	draw_rect(Rect2(865,590,110,42), Color("#211a10"))
	draw_string(ThemeDB.fallback_font, Vector2(305,617), "◀ 이전", HORIZONTAL_ALIGNMENT_CENTER, 110, 13, Color("#dec99f"))
	draw_string(ThemeDB.fallback_font, Vector2(865,617), "다음 ▶", HORIZONTAL_ALIGNMENT_CENTER, 110, 13, Color("#dec99f"))
	draw_string(ThemeDB.fallback_font, Vector2(575,617), "%d / %d" % [map_page+1,max(1,total_pages)], HORIZONTAL_ALIGNMENT_CENTER, 130, 12, Color("#9e9177"))

func _draw_system_panel():
	var panel = Rect2(350,100,580,470)
	draw_rect(panel, Color(0.025,0.028,0.025,0.98))
	draw_rect(panel, Color("#987542"), false, 2.0)
	var title = "시스템"
	var entries = []
	if system_panel == "transform":
		title = "변신"
		entries = transformations
	elif system_panel == "doll":
		title = "마법인형"
		entries = dolls
	elif system_panel == "relic":
		title = "성물"
		entries = relics
	draw_string(ThemeDB.fallback_font, Vector2(380,140), title, HORIZONTAL_ALIGNMENT_LEFT, 500, 22, Color("#efddb2"))
	var y = 185
	for e in entries:
		draw_rect(Rect2(380,y-25,520,54), Color("#13150f"))
		draw_rect(Rect2(380,y-25,520,54), Color("#5f4a2c"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(395,y), str(e["name"]), HORIZONTAL_ALIGNMENT_LEFT, 230, 15, Color("#f0dfba"))
		draw_string(ThemeDB.fallback_font, Vector2(640,y), str(e["bonus"]), HORIZONTAL_ALIGNMENT_LEFT, 240, 12, Color("#9fd5a7"))
		y += 66

func _draw_message():
	if message == "":
		return
	draw_rect(Rect2(445,88,390,38), Color(0.02,0.02,0.02,0.88))
	draw_rect(Rect2(445,88,390,38), Color("#8c6c3e"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(455,113), message, HORIZONTAL_ALIGNMENT_CENTER, 370, 13, Color("#f1e3c6"))
