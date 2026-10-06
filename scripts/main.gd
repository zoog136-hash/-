extends Node2D

const SAVE_PATH := "user://savegame.json"

var player_pos := Vector2(640, 360)
var player_speed := 220.0
var player_hp := 100
var player_max_hp := 100
var player_level := 1
var player_exp := 0
var player_gold := 0
var attack_power := 12
var auto_hunt := false
var attack_cooldown := 0.0

var monsters := []
var drops := []
var inventory := {}

func _ready():
	randomize()
	_spawn_monsters(12)
	queue_redraw()

func _process(delta):
	_handle_input(delta)
	_update_monsters(delta)
	_update_combat(delta)
	_collect_nearby_drops()
	queue_redraw()

func _handle_input(delta):
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir.length() > 0.0:
		player_pos += dir.normalized() * player_speed * delta
		player_pos.x = clamp(player_pos.x, 30.0, 1250.0)
		player_pos.y = clamp(player_pos.y, 60.0, 690.0)

	if Input.is_action_just_pressed("toggle_auto"):
		auto_hunt = !auto_hunt

	if Input.is_key_pressed(KEY_F5):
		save_game()
	if Input.is_key_pressed(KEY_F9):
		load_game()

func _spawn_monsters(count:int):
	monsters.clear()
	for i in count:
		monsters.append({
			"pos": Vector2(randf_range(80, 1200), randf_range(100, 650)),
			"hp": 30 + randi_range(0, 20),
			"max_hp": 50,
			"speed": randf_range(35, 60),
			"exp": 15,
			"gold": randi_range(4, 12)
		})

func _update_monsters(delta):
	for m in monsters:
		if m["hp"] <= 0:
			continue
		var dist: float = m["pos"].distance_to(player_pos)
		if dist < 260.0 and dist > 38.0:
			var dir: Vector2 = (player_pos - m["pos"]).normalized()
			m["pos"] += dir * float(m["speed"]) * delta
		elif dist <= 38.0:
			player_hp = max(0, player_hp - 1)

func _update_combat(delta):
	attack_cooldown = max(0.0, attack_cooldown - delta)
	if player_hp <= 0:
		player_hp = player_max_hp
		player_pos = Vector2(640,360)
		return

	var target = _nearest_alive_monster()
	if target == null:
		if monsters.size() < 12:
			_spawn_monsters(12)
		return

	var dist: float = target["pos"].distance_to(player_pos)
	if auto_hunt and dist > 55.0:
		var dir := (target["pos"] - player_pos).normalized()
		player_pos += dir * player_speed * 0.55 * delta
	elif auto_hunt and dist <= 55.0 and attack_cooldown <= 0.0:
		target["hp"] -= attack_power
		attack_cooldown = 0.55
		if target["hp"] <= 0:
			_on_monster_killed(target)

func _nearest_alive_monster():
	var best = null
	var best_dist := INF
	for m in monsters:
		if m["hp"] <= 0:
			continue
		var d: float = m["pos"].distance_to(player_pos)
		if d < best_dist:
			best_dist = d
			best = m
	return best

func _on_monster_killed(monster):
	player_exp += int(monster["exp"])
	player_gold += int(monster["gold"])
	drops.append({
		"pos": monster["pos"],
		"name": ["Red Potion","Iron Sword","Leather Armor","Adena Pouch"][randi() % 4]
	})
	_check_level_up()
	await get_tree().create_timer(2.5).timeout
	monster["pos"] = Vector2(randf_range(80,1200), randf_range(100,650))
	monster["hp"] = monster["max_hp"]

func _check_level_up():
	var need := player_level * 100
	while player_exp >= need:
		player_exp -= need
		player_level += 1
		player_max_hp += 10
		player_hp = player_max_hp
		attack_power += 2
		need = player_level * 100

func _collect_nearby_drops():
	for d in drops.duplicate():
		if d["pos"].distance_to(player_pos) < 32.0:
			var item_name: String = d["name"]
			inventory[item_name] = int(inventory.get(item_name, 0)) + 1
			drops.erase(d)

func save_game():
	var data = {
		"player_pos": [player_pos.x, player_pos.y],
		"hp": player_hp,
		"max_hp": player_max_hp,
		"level": player_level,
		"exp": player_exp,
		"gold": player_gold,
		"attack": attack_power,
		"inventory": inventory
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	var p = data.get("player_pos", [640,360])
	player_pos = Vector2(float(p[0]), float(p[1]))
	player_hp = int(data.get("hp",100))
	player_max_hp = int(data.get("max_hp",100))
	player_level = int(data.get("level",1))
	player_exp = int(data.get("exp",0))
	player_gold = int(data.get("gold",0))
	attack_power = int(data.get("attack",12))
	inventory = data.get("inventory",{})

func _draw():
	# Background / field
	draw_rect(Rect2(0,0,1280,720), Color(0.08,0.11,0.08))
	for x in range(0,1280,64):
		draw_line(Vector2(x,0), Vector2(x,720), Color(0.12,0.16,0.12), 1)
	for y in range(0,720,64):
		draw_line(Vector2(0,y), Vector2(1280,y), Color(0.12,0.16,0.12), 1)

	# Drops
	for d in drops:
		draw_circle(d["pos"], 7, Color(0.95,0.78,0.18))

	# Monsters
	for m in monsters:
		if m["hp"] <= 0:
			continue
		var p: Vector2 = m["pos"]
		draw_circle(p, 16, Color(0.65,0.16,0.12))
		var ratio: float = float(m["hp"]) / float(m["max_hp"])
		draw_rect(Rect2(p + Vector2(-20,-28), Vector2(40,5)), Color(0.15,0.05,0.05))
		draw_rect(Rect2(p + Vector2(-20,-28), Vector2(40*ratio,5)), Color(0.8,0.08,0.08))

	# Player
	draw_circle(player_pos, 18, Color(0.22,0.55,0.95))
	draw_circle(player_pos, 22, Color(0.75,0.9,1.0), false, 2)

	# UI
	draw_rect(Rect2(18,16,410,92), Color(0.02,0.02,0.02,0.78))
	draw_string(ThemeDB.fallback_font, Vector2(32,42), "Lv.%d  HP %d/%d  ATK %d" % [player_level, player_hp, player_max_hp, attack_power], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(32,68), "EXP %d/%d   Gold %d" % [player_exp, player_level*100, player_gold], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95,0.85,0.35))
	draw_string(ThemeDB.fallback_font, Vector2(32,94), "AUTO: %s   [T] Toggle   [F5] Save   [F9] Load" % ("ON" if auto_hunt else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.7,1.0,0.7) if auto_hunt else Color(0.8,0.8,0.8))

	var inv_text := "Inventory: "
	for k in inventory.keys():
		inv_text += "%s x%s   " % [k, inventory[k]]
	draw_rect(Rect2(18,665,1244,38), Color(0.02,0.02,0.02,0.72))
	draw_string(ThemeDB.fallback_font, Vector2(30,691), inv_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
