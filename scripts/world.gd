extends Node2D
class_name TwilightWorld

const SAVE_PATH: String = "user://twilight_v20_save.json"
const MAPS_PATH: String = "res://data/maps_v18.json"
const DB_PATH: String = "res://data/game_db_v17.json"
const CATALOG_PATH: String = "res://data/catalog_v19.json"
const CATALOG_IMAGE_INDEX_PATH: String = "res://data/catalog_image_index_v19.json"
const DIRECTIONAL_PATH: String = "res://data/directional_art_v19.json"
const MONSTER_SCENE: PackedScene = preload("res://scenes/Monster.tscn")

@onready var map_background: Sprite2D = $MapRoot/Background
@onready var collision_tiles: TileMapLayer = $MapRoot/CollisionTiles
@onready var map_collision: StaticBody2D = $MapCollision
@onready var monsters_root: Node2D = $Monsters
@onready var drops_root: Node2D = $Drops
@onready var player: TwilightPlayer = $Player
@onready var hud: TwilightHUD = $HUD
@onready var companion_sprite: AnimatedSprite2D = $Companion/Sprite2D
@onready var relic_sprite: Sprite2D = $RelicSprite

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var maps: Array = []
var maps_by_id: Dictionary = {}
var game_db: Dictionary = {}
var monster_db: Array = []
var item_db: Array = []
var catalog_db: Dictionary = {}
var catalog_image_index: Dictionary = {}
var directional_art: Dictionary = {}
var equipped_catalog: Dictionary = {"변신": {}, "마법인형": {}, "성물": {}}
var equipped_items: Dictionary = {"weapon": {}, "armor": {}, "accessory": {}}
var class_index: int = 0
var companion_velocity: Vector2 = Vector2.ZERO
var active_map: Dictionary = {}
var active_map_id: String = "aden_world"
var astar: AStarGrid2D = null
var world_size: Vector2 = Vector2(8192, 4224)
var tile_size: int = 32
var selected_monster: TwilightMonster = null
var auto_target: TwilightMonster = null
var auto_attack_timer: float = 0.0
var save_timer: float = 0.0
var collision_debug: bool = false
var quest_kills: int = 0
const QUEST_GOAL: int = 9

var level: int = 35
var experience: int = 100
var exp_need: int = 1400
var hp: int = 1832
var max_hp: int = 1832
var mp: int = 315
var max_mp: int = 375
var attack_power: int = 42
var defense: int = 19

# V20.2 Step 1: Lineage-style core attributes.
# These are persisted and displayed now; hit/miss combat logic is added in the next step.
var str_stat: int = 18
var dex_stat: int = 12
var con_stat: int = 16
var int_stat: int = 8
var wis_stat: int = 10
var cha_stat: int = 9
var stat_points: int = 0

var gold: int = 12000
var inventory: Dictionary = {"HP 물약":100, "강력 HP 물약":14, "축복받은 HP 물약":10, "낡은 장검":1, "초록 잎":200}

func _ready() -> void:
	rng.randomize()
	_load_data()
	_connect_signals()
	_setup_collision_tileset()
	hud.refresh_maps(maps)
	hud.set_catalog_data(catalog_db, catalog_image_index)
	_set_map(active_map_id, false)
	_load_game(true)
	_update_hud()
	hud.append_log("V20 · 모바일 MMORPG HUD / 전투 화면 개선")

func _process(delta: float) -> void:
	auto_attack_timer = maxf(0.0, auto_attack_timer - delta)
	save_timer += delta
	if save_timer >= 30.0:
		save_timer = 0.0
		_save_game(true)
	if player.auto_enabled:
		_run_auto_hunt()
	_update_companion(delta)
	if Input.is_action_just_pressed("open_inventory"):
		_open_inventory()
	if Input.is_action_just_pressed("open_menu"):
		hud.toggle_menu()
	if Input.is_action_just_pressed("open_map"):
		hud.toggle_map()
	if Input.is_action_just_pressed("quick_potion"):
		_use_potion()
	if Input.is_action_just_pressed("save_game"):
		_save_game(false)
	if Input.is_action_just_pressed("load_game"):
		_load_game(false)
	if Input.is_action_just_pressed("toggle_collision_debug"):
		collision_debug = not collision_debug
		collision_tiles.visible = collision_debug
		hud.show_message("충돌 타일 표시 %s" % ("ON" if collision_debug else "OFF"))
	_update_target_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_click_destination(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			# Android touch events carry real viewport coordinates. Mouse emulation is
			# disabled in project.godot, so get_global_mouse_position() may be stale.
			var world_touch_position: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * touch_event.position
			_set_click_destination(world_touch_position)

func _load_data() -> void:
	var maps_text: String = FileAccess.get_file_as_string(MAPS_PATH)
	var maps_value: Variant = JSON.parse_string(maps_text)
	if maps_value is Array:
		maps = maps_value as Array
	for map_value: Variant in maps:
		if map_value is Dictionary:
			var map_data: Dictionary = map_value as Dictionary
			maps_by_id[str(map_data.get("id", ""))] = map_data
	var db_text: String = FileAccess.get_file_as_string(DB_PATH)
	var db_value: Variant = JSON.parse_string(db_text)
	if db_value is Dictionary:
		game_db = db_value as Dictionary
	monster_db = game_db.get("몬스터", []) as Array
	item_db = game_db.get("아이템", []) as Array
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if catalog_value is Dictionary:
		catalog_db = catalog_value as Dictionary
	var image_index_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_IMAGE_INDEX_PATH))
	if image_index_value is Dictionary:
		catalog_image_index = image_index_value as Dictionary
	var directional_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTIONAL_PATH))
	if directional_value is Dictionary:
		directional_art = directional_value as Dictionary

func _connect_signals() -> void:
	player.attack_requested.connect(_attack)
	player.auto_toggled.connect(_on_auto_toggled)
	hud.move_vector_changed.connect(player.set_touch_vector)
	hud.attack_pressed.connect(_attack)
	hud.auto_pressed.connect(func() -> void: player.set_auto_enabled(not player.auto_enabled))
	hud.potion_pressed.connect(_use_potion)
	hud.inventory_pressed.connect(_open_inventory)
	hud.menu_pressed.connect(hud.toggle_menu)
	hud.map_pressed.connect(hud.toggle_map)
	hud.map_selected.connect(_on_map_selected)
	hud.save_pressed.connect(func() -> void: _save_game(false))
	hud.load_pressed.connect(func() -> void: _load_game(false))
	hud.catalog_equip_requested.connect(_equip_catalog)
	hud.class_selected.connect(_on_class_selected)
	hud.stat_increase_requested.connect(_on_stat_increase_requested)

func _set_map(map_id: String, keep_position: bool) -> void:
	if not maps_by_id.has(map_id):
		return
	active_map_id = map_id
	active_map = maps_by_id[map_id] as Dictionary
	tile_size = int(active_map.get("tile_size_world", 32))
	world_size = Vector2(float(int(active_map.get("width", 1)) * tile_size), float(int(active_map.get("height", 1)) * tile_size))
	_clear_monsters()
	_clear_drops()
	_build_astar()
	_build_static_collisions()
	_build_collision_debug_tiles()
	_apply_map_background()
	if not keep_position or not _is_walkable_world(player.global_position):
		player.global_position = _spawn_position()
	player.clear_click_path()
	selected_monster = null
	auto_target = null
	hud.set_map_name(str(active_map.get("name", active_map_id)))
	hud.clear_target()
	_spawn_monsters(9)
	hud.show_message(str(active_map.get("name", active_map_id)))

func _apply_map_background() -> void:
	var path: String = str(active_map.get("image_path", ""))
	var texture: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	elif ResourceLoader.exists("res://assets/world.png"):
		texture = load("res://assets/world.png") as Texture2D
	else:
		texture = null
	map_background.texture = texture
	map_background.position = world_size * 0.5
	if texture != null:
		var texture_size: Vector2 = texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			map_background.scale = Vector2(world_size.x / texture_size.x, world_size.y / texture_size.y)
	map_background.modulate = Color(0.66, 0.66, 0.64, 1.0)

func _build_astar() -> void:
	astar = AStarGrid2D.new()
	var width: int = int(active_map.get("width", 1))
	var height: int = int(active_map.get("height", 1))
	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(tile_size, tile_size)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	var collision: Array = active_map.get("collision", []) as Array
	for row: int in range(height):
		for column: int in range(width):
			var index: int = row * width + column
			if index >= collision.size() or int(collision[index]) != 0:
				astar.set_point_solid(Vector2i(column, row), true)

func _build_static_collisions() -> void:
	for child: Node in map_collision.get_children():
		child.queue_free()
	var rects: Array = active_map.get("collision_rects", []) as Array
	for rect_value: Variant in rects:
		if not (rect_value is Array):
			continue
		var rect: Array = rect_value as Array
		if rect.size() < 4:
			continue
		var column: int = int(rect[0])
		var row: int = int(rect[1])
		var width_cells: int = int(rect[2])
		var height_cells: int = int(rect[3])
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(width_cells * tile_size, height_cells * tile_size)
		var node: CollisionShape2D = CollisionShape2D.new()
		node.shape = shape
		node.position = Vector2((column + width_cells * 0.5) * tile_size, (row + height_cells * 0.5) * tile_size)
		map_collision.add_child(node)

func _setup_collision_tileset() -> void:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.85, 0.13, 0.12, 0.36))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(32, 32)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = Vector2i(32, 32)
	atlas.create_tile(Vector2i.ZERO)
	tile_set.add_source(atlas, 0)
	collision_tiles.tile_set = tile_set
	collision_tiles.visible = collision_debug

func _build_collision_debug_tiles() -> void:
	collision_tiles.clear()
	var width: int = int(active_map.get("width", 1))
	var height: int = int(active_map.get("height", 1))
	var collision: Array = active_map.get("collision", []) as Array
	for row: int in range(height):
		for column: int in range(width):
			var index: int = row * width + column
			if index < collision.size() and int(collision[index]) != 0:
				collision_tiles.set_cell(Vector2i(column, row), 0, Vector2i.ZERO, 0)

func _spawn_position() -> Vector2:
	var spawn_value: Variant = active_map.get("navigation_spawn", {})
	if spawn_value is Dictionary:
		var spawn: Dictionary = spawn_value as Dictionary
		var column: int = int(spawn.get("column", 1))
		var row: int = int(spawn.get("row", 1))
		var position_value: Vector2 = _cell_to_world(Vector2i(column, row))
		if _is_walkable_world(position_value):
			return position_value
	return _random_walkable_position(Vector2.ZERO, 0.0, 999999.0)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * tile_size, (cell.y + 0.5) * tile_size)

func _world_to_cell(position_value: Vector2) -> Vector2i:
	return Vector2i(int(floor(position_value.x / tile_size)), int(floor(position_value.y / tile_size)))

func _is_walkable_world(position_value: Vector2) -> bool:
	if astar == null:
		return false
	var cell: Vector2i = _world_to_cell(position_value)
	if not astar.is_in_boundsv(cell):
		return false
	return not astar.is_point_solid(cell)

func find_world_path(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if astar == null:
		return result
	var start: Vector2i = _nearest_walkable_cell(_world_to_cell(from_position))
	var goal: Vector2i = _nearest_walkable_cell(_world_to_cell(to_position))
	if not astar.is_in_boundsv(start) or not astar.is_in_boundsv(goal):
		return result
	var cell_path: Array[Vector2i] = astar.get_id_path(start, goal)
	for cell: Vector2i in cell_path:
		result.append(_cell_to_world(cell))
	return result

func _nearest_walkable_cell(origin: Vector2i) -> Vector2i:
	if astar != null and astar.is_in_boundsv(origin) and not astar.is_point_solid(origin):
		return origin
	for radius: int in range(1, 12):
		for y: int in range(origin.y - radius, origin.y + radius + 1):
			for x: int in range(origin.x - radius, origin.x + radius + 1):
				var cell: Vector2i = Vector2i(x, y)
				if astar != null and astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
					return cell
	return origin

func _set_click_destination(target: Vector2) -> void:
	var path: PackedVector2Array = find_world_path(player.global_position, target)
	if path.size() > 0:
		player.set_click_path(path, target)

func _spawn_monsters(count: int) -> void:
	if monster_db.is_empty():
		return
	for index: int in range(count):
		var record_value: Variant = monster_db[rng.randi_range(0, monster_db.size() - 1)]
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value as Dictionary
		var monster: TwilightMonster = MONSTER_SCENE.instantiate()
		monsters_root.add_child(monster)
		monster.global_position = _random_walkable_position(player.global_position, 360.0, 1200.0)
		var texture: Texture2D = _monster_texture(record)
		monster.setup(record, player, self, texture)
		monster.died.connect(_on_monster_died)
		monster.player_hit.connect(_on_player_hit)
		monster.selected.connect(_select_monster)

func _monster_texture(record: Dictionary) -> Texture2D:
	var monster_name: String = str(record.get("name", ""))
	var visual_index: int = 5
	if monster_name.contains("뱀") or monster_name.contains("드레이크") or monster_name.contains("용") or monster_name.contains("리자드"):
		visual_index = 0
	elif monster_name.contains("골렘") or monster_name.contains("오우거") or monster_name.contains("버그베어"):
		visual_index = 1
	elif monster_name.contains("거미") or monster_name.contains("스콜피온") or monster_name.contains("개미"):
		visual_index = 2
	elif monster_name.contains("악마") or monster_name.contains("서큐") or monster_name.contains("고스트") or monster_name.contains("데몬"):
		visual_index = 3
	elif monster_name.contains("늑대") or monster_name.contains("라이칸") or monster_name.contains("멧돼지"):
		visual_index = 4
	var path: String = "res://assets/sprites/monsters/monster_%d.png" % visual_index
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if ResourceLoader.exists("res://assets/ghost.png"):
		return load("res://assets/ghost.png") as Texture2D
	return null

func _random_walkable_position(near: Vector2, min_distance: float, max_distance: float) -> Vector2:
	var width: int = int(active_map.get("width", 1))
	var height: int = int(active_map.get("height", 1))
	for _attempt: int in range(700):
		var cell: Vector2i = Vector2i(rng.randi_range(0, maxi(0, width - 1)), rng.randi_range(0, maxi(0, height - 1)))
		if astar != null and not astar.is_point_solid(cell):
			var position_value: Vector2 = _cell_to_world(cell)
			if near == Vector2.ZERO:
				return position_value
			var distance: float = position_value.distance_to(near)
			if distance >= min_distance and distance <= max_distance:
				return position_value
	return _spawn_position_fallback()

func _spawn_position_fallback() -> Vector2:
	var width: int = int(active_map.get("width", 1))
	var height: int = int(active_map.get("height", 1))
	for row: int in range(height):
		for column: int in range(width):
			var cell: Vector2i = Vector2i(column, row)
			if astar != null and not astar.is_point_solid(cell):
				return _cell_to_world(cell)
	return Vector2(tile_size * 2, tile_size * 2)

func _clear_monsters() -> void:
	for child: Node in monsters_root.get_children():
		child.queue_free()

func _clear_drops() -> void:
	for child: Node in drops_root.get_children():
		child.queue_free()

func _melee_hit_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	var accuracy: int = _melee_accuracy_stat()
	var target_ac_abs: int = absi(target.armor_class)
	var chance_percent: float = 75.0 + float(accuracy - target_ac_abs) * 0.7
	return clampf(chance_percent / 100.0, 0.05, 0.95)

func _roll_melee_hit(target: TwilightMonster) -> bool:
	return rng.randf() < _melee_hit_chance(target)

func _attack() -> void:
	var target: TwilightMonster = selected_monster
	if not is_instance_valid(target) or target.dead or player.global_position.distance_to(target.global_position) > 105.0:
		target = _nearest_monster(105.0)
	if target == null:
		hud.show_message("공격 범위에 대상이 없습니다")
		return
	selected_monster = target
	player.pulse_attack()
	var hit_chance: float = _melee_hit_chance(target)
	if not _roll_melee_hit(target):
		target.show_miss()
		hud.append_log("%s 공격 MISS · 명중 %d / AC %d / %.1f%%" % [
			target.monster_name, _melee_accuracy_stat(), target.armor_class, hit_chance * 100.0
		])
		_update_target_hud()
		return
	var damage: int = maxi(1, _melee_damage_stat() + rng.randi_range(-6, 9))
	target.take_damage(damage)
	hud.append_log("%s에게 %d 피해 · 명중률 %.1f%%" % [target.monster_name, damage, hit_chance * 100.0])
	_update_target_hud()

func _run_auto_hunt() -> void:
	if not is_instance_valid(auto_target) or auto_target.dead:
		auto_target = _nearest_monster(99999.0)
	if auto_target == null:
		return
	selected_monster = auto_target
	var distance: float = player.global_position.distance_to(auto_target.global_position)
	if distance <= 95.0:
		player.clear_click_path()
		if auto_attack_timer <= 0.0:
			auto_attack_timer = 0.72
			_attack()
	else:
		if player.click_path.is_empty() or player.path_index >= player.click_path.size():
			var path: PackedVector2Array = find_world_path(player.global_position, auto_target.global_position)
			player.set_click_path(path, auto_target.global_position)

func _nearest_monster(max_distance: float) -> TwilightMonster:
	var best: TwilightMonster = null
	var best_distance: float = max_distance
	for node: Node in monsters_root.get_children():
		if node is TwilightMonster:
			var monster: TwilightMonster = node
			if monster.dead:
				continue
			var distance: float = player.global_position.distance_to(monster.global_position)
			if distance < best_distance:
				best_distance = distance
				best = monster
	return best

func _select_monster(monster: TwilightMonster) -> void:
	selected_monster = monster
	_update_target_hud()

func _update_target_hud() -> void:
	if is_instance_valid(selected_monster) and not selected_monster.dead:
		hud.show_target("Lv.%d %s · AC %d" % [selected_monster.monster_level, selected_monster.monster_name, selected_monster.armor_class], selected_monster.hp, selected_monster.max_hp)
	else:
		selected_monster = null
		hud.clear_target()

func _on_monster_died(monster: TwilightMonster) -> void:
	var gained_experience: int = maxi(1, int(round(monster.exp_reward * _experience_multiplier())))
	experience += gained_experience
	gold += monster.gold_reward
	hud.append_log("%s 처치 · EXP %d · 아데나 %d" % [monster.monster_name, gained_experience, monster.gold_reward])
	quest_kills = mini(QUEST_GOAL, quest_kills + 1)
	if hud.has_method("set_quest_progress"):
		hud.call("set_quest_progress", quest_kills, QUEST_GOAL)
	_roll_drop(monster.global_position)
	_check_level_up()
	if monster == selected_monster:
		selected_monster = null
	if monster == auto_target:
		auto_target = null
	monster.queue_free()
	_update_hud()
	call_deferred("_ensure_monster_count")

func _ensure_monster_count() -> void:
	var alive: int = monsters_root.get_child_count()
	if alive < 8:
		_spawn_monsters(9 - alive)

func _roll_drop(position_value: Vector2) -> void:
	if item_db.is_empty():
		return
	if rng.randf() > 0.72:
		return
	var record_value: Variant = item_db[rng.randi_range(0, item_db.size() - 1)]
	var item_name: String = "아이템"
	if record_value is Dictionary:
		item_name = str(record_value.get("name", item_name))
	inventory[item_name] = int(inventory.get(item_name, 0)) + 1
	var label: Label = Label.new()
	label.text = "◆ " + item_name
	label.position = position_value + Vector2(-45, -28)
	label.add_theme_color_override("font_color", Color("f5d66f"))
	drops_root.add_child(label)
	var timer: SceneTreeTimer = get_tree().create_timer(4.0)
	timer.timeout.connect(label.queue_free)
	hud.show_message("획득: " + item_name)

func _on_player_hit(damage_value: int) -> void:
	var reduced: int = maxi(1, damage_value - int(_effective_defense() * 0.28))
	hp = maxi(0, hp - reduced)
	if hp <= 0:
		hp = _effective_max_hp()
		mp = max_mp
		gold = maxi(0, gold - 500)
		player.global_position = _spawn_position()
		player.clear_click_path()
		hud.show_message("사망 후 부활했습니다")
	_update_hud()

func _stat_points_for_level_up(new_level: int) -> int:
	# Provisional Lineage-style growth rule, isolated for later balance changes.
	if new_level > 50:
		return 1
	if new_level >= 5 and new_level % 5 == 0:
		return 1
	return 0

func _on_stat_increase_requested(stat_name: String) -> void:
	if stat_points <= 0:
		hud.show_message("남은 스탯 포인트가 없습니다")
		return
	match stat_name:
		"STR":
			str_stat += 1
		"DEX":
			dex_stat += 1
		"CON":
			con_stat += 1
		"INT":
			int_stat += 1
		"WIS":
			wis_stat += 1
		"CHA":
			cha_stat += 1
		_:
			return
	stat_points -= 1
	hud.show_message("%s +1 · 남은 포인트 %d" % [stat_name, stat_points])
	hud.append_log("스탯 투자 · %s +1" % stat_name)
	_update_hud()
	_save_game(true)

func _check_level_up() -> void:
	while experience >= exp_need:
		experience -= exp_need
		level += 1
		exp_need = int(round(exp_need * 1.14 + 120.0))
		max_hp += 45
		max_mp += 9
		hp = _effective_max_hp()
		mp = max_mp
		attack_power += 2
		defense += 1
		var awarded_points: int = _stat_points_for_level_up(level)
		stat_points += awarded_points
		if awarded_points > 0:
			hud.show_message("레벨 업! Lv.%d · 스탯 포인트 +%d" % [level, awarded_points])
			hud.append_log("Lv.%d 달성 · 스탯 포인트 +%d" % [level, awarded_points])
		else:
			hud.show_message("레벨 업! Lv.%d" % level)

func _use_potion() -> void:
	var potion: String = "HP 물약"
	if int(inventory.get(potion, 0)) <= 0:
		hud.show_message("HP 물약이 없습니다")
		return
	var effective_max_hp: int = _effective_max_hp()
	if hp >= effective_max_hp:
		hud.show_message("HP가 가득 찼습니다")
		return
	inventory[potion] = int(inventory.get(potion, 0)) - 1
	hp = mini(effective_max_hp, hp + 320)
	hud.show_message("HP 물약 사용")
	_update_hud()

func _on_auto_toggled(enabled: bool) -> void:
	hud.set_auto(enabled)
	if not enabled:
		auto_target = null
		player.clear_click_path()

func _open_inventory() -> void:
	hud.refresh_inventory(inventory)
	hud.toggle_inventory()

func _on_map_selected(map_id: String) -> void:
	hud.toggle_map()
	_set_map(map_id, false)

func _update_hud() -> void:
	hud.update_player(level, hp, _effective_max_hp(), mp, max_mp, experience, exp_need, gold)
	if hud.has_method("set_quick_items"):
		hud.call("set_quick_items", inventory)
	if hud.has_method("set_quest_progress"):
		hud.call("set_quest_progress", quest_kills, QUEST_GOAL)
	var character_state: Dictionary = _character_stats_snapshot()
	character_state["class_index"] = class_index
	character_state["level"] = level
	character_state["hp"] = hp
	character_state["max_hp"] = _effective_max_hp()
	character_state["mp"] = mp
	character_state["max_mp"] = max_mp
	character_state["attack"] = _effective_attack()
	character_state["defense"] = _effective_defense()
	character_state["equipped"] = equipped_catalog
	character_state["equipped_items"] = equipped_items
	hud.set_character_state(character_state)

func _save_game(quiet: bool) -> void:
	var data: Dictionary = {
		"map_id": active_map_id,
		"position": [player.global_position.x, player.global_position.y],
		"level": level,
		"experience": experience,
		"exp_need": exp_need,
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"attack": attack_power,
		"defense": defense,
		"str": str_stat,
		"dex": dex_stat,
		"con": con_stat,
		"int": int_stat,
		"wis": wis_stat,
		"cha": cha_stat,
		"stat_points": stat_points,
		"gold": gold,
		"inventory": inventory,
		"class_index": class_index,
		"equipped_catalog": equipped_catalog,
		"equipped_items": equipped_items,
		"quest_kills": quest_kills
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
		if not quiet:
			hud.show_message("저장 완료")

func _load_game(quiet: bool) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		if not quiet:
			hud.show_message("저장 데이터가 없습니다")
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (value is Dictionary):
		return
	var data: Dictionary = value as Dictionary
	level = int(data.get("level", level))
	experience = int(data.get("experience", data.get("exp", experience)))
	exp_need = int(data.get("exp_need", exp_need))
	hp = int(data.get("hp", hp))
	max_hp = int(data.get("max_hp", max_hp))
	mp = int(data.get("mp", mp))
	max_mp = int(data.get("max_mp", max_mp))
	attack_power = int(data.get("attack", attack_power))
	defense = int(data.get("defense", defense))
	str_stat = int(data.get("str", str_stat))
	dex_stat = int(data.get("dex", dex_stat))
	con_stat = int(data.get("con", con_stat))
	int_stat = int(data.get("int", int_stat))
	wis_stat = int(data.get("wis", wis_stat))
	cha_stat = int(data.get("cha", cha_stat))
	stat_points = maxi(0, int(data.get("stat_points", stat_points)))
	gold = int(data.get("gold", gold))
	quest_kills = clampi(int(data.get("quest_kills", quest_kills)), 0, QUEST_GOAL)
	var inventory_value: Variant = data.get("inventory", inventory)
	if inventory_value is Dictionary:
		inventory = inventory_value as Dictionary
	class_index = clampi(int(data.get("class_index", class_index)), 0, 3)
	player.set_class_index(class_index)
	var equipped_value: Variant = data.get("equipped_catalog", equipped_catalog)
	if equipped_value is Dictionary:
		equipped_catalog = equipped_value as Dictionary
	var equipped_items_value: Variant = data.get("equipped_items", equipped_items)
	if equipped_items_value is Dictionary:
		equipped_items = equipped_items_value as Dictionary
	_restore_equipped_visuals()
	hp = mini(hp, _effective_max_hp())
	var map_id: String = str(data.get("map_id", active_map_id))
	_set_map(map_id, false)
	var position_value: Variant = data.get("position", [])
	if position_value is Array:
		var position_array: Array = position_value as Array
		if position_array.size() >= 2:
			var saved_position: Vector2 = Vector2(float(position_array[0]), float(position_array[1]))
			if _is_walkable_world(saved_position):
				player.global_position = saved_position
	_update_hud()
	if not quiet:
		hud.show_message("불러오기 완료")


func _on_class_selected(value: int) -> void:
	class_index = clampi(value, 0, 3)
	player.set_class_index(class_index)
	hud.show_message("캐릭터 외형: %s" % ["전사", "마법사", "궁수", "암살자"][class_index])
	_update_hud()

func _equip_catalog(category: String, record: Dictionary) -> void:
	if category == "아이템":
		_equip_or_acquire_item(record)
		return
	if not equipped_catalog.has(category):
		return
	var old_max_hp: int = _effective_max_hp()
	equipped_catalog[category] = record.duplicate(true)
	if category == "변신":
		_apply_transform_visual(record)
	elif category == "마법인형":
		_apply_doll_visual(record)
	elif category == "성물":
		_apply_relic_visual(record)
	var new_max_hp: int = _effective_max_hp()
	if new_max_hp > old_max_hp:
		hp += new_max_hp - old_max_hp
	hp = mini(hp, new_max_hp)
	hud.show_message("%s 장착: %s" % [category, str(record.get("name", ""))])
	hud.append_log("%s 적용 · %s" % [category, str(record.get("name", ""))])
	_update_hud()

func _equip_or_acquire_item(record: Dictionary) -> void:
	var item_name: String = str(record.get("name", "아이템"))
	inventory[item_name] = int(inventory.get(item_name, 0)) + 1
	var slot: String = str(record.get("slot", ""))
	if slot == "weapon" or slot == "armor" or slot == "accessory":
		var old_max_hp: int = _effective_max_hp()
		equipped_items[slot] = record.duplicate(true)
		var new_max_hp: int = _effective_max_hp()
		if new_max_hp > old_max_hp:
			hp += new_max_hp - old_max_hp
		hp = mini(hp, new_max_hp)
		hud.show_message("아이템 장착: %s" % item_name)
		hud.append_log("%s 슬롯 장착 · %s" % [slot, item_name])
	else:
		hud.show_message("아이템 획득: %s" % item_name)
		hud.append_log("인벤토리 획득 · %s" % item_name)
	hud.refresh_inventory(inventory)
	_update_hud()

func _directional_image_path(kind: String, record: Dictionary) -> String:
	var source_id: String = str(record.get("sourceId", ""))
	var key: String = "%s:%s" % [kind, source_id]
	var value: Variant = directional_art.get(key, {})
	if value is Dictionary:
		var meta: Dictionary = value as Dictionary
		var directional_path: String = str(meta.get("path", ""))
		if directional_path != "" and ResourceLoader.exists(directional_path):
			return directional_path
	var fallback: String = str(record.get("image_path", ""))
	return fallback

func _apply_transform_visual(record: Dictionary) -> void:
	if record.is_empty():
		player.clear_transform_visual()
		return
	var path: String = _directional_image_path("transform", record)
	var speed_multiplier: float = float(record.get("speed", 1.0))
	player.set_transform_visual(path, speed_multiplier)

func _apply_doll_visual(record: Dictionary) -> void:
	companion_sprite.stop()
	companion_sprite.sprite_frames = SpriteFrames.new()
	companion_sprite.visible = false
	if record.is_empty():
		return
	var path: String = _directional_image_path("doll", record)
	if path == "" or not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return
	_build_directional_frames(companion_sprite, texture)
	var size: Vector2 = texture.get_size()
	var cell_height: float = size.y / 4.0
	var scale_value: float = 72.0 / maxf(1.0, cell_height)
	companion_sprite.scale = Vector2(scale_value, scale_value)
	companion_sprite.animation = _direction_animation_name(player.facing)
	companion_sprite.frame = 0
	companion_sprite.play()
	companion_sprite.visible = true
	$Companion.global_position = player.global_position + Vector2(-50, 18)

func _build_directional_frames(sprite: AnimatedSprite2D, texture: Texture2D) -> void:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var names: Array[String] = ["dir_down", "dir_up", "dir_left", "dir_right"]
	var size: Vector2 = texture.get_size()
	var cell_width: float = size.x / 4.0
	var cell_height: float = size.y / 4.0
	for row: int in range(4):
		var animation_name: String = names[row]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 7.0)
		frames.set_animation_loop(animation_name, true)
		for column: int in range(4):
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * cell_width, row * cell_height, cell_width, cell_height)
			frames.add_frame(animation_name, atlas)
	sprite.sprite_frames = frames

func _direction_animation_name(direction_value: int) -> String:
	match direction_value:
		1: return "dir_up"
		2: return "dir_left"
		3: return "dir_right"
		_: return "dir_down"

func _apply_relic_visual(record: Dictionary) -> void:
	relic_sprite.texture = null
	relic_sprite.visible = false
	if record.is_empty():
		return
	var path: String = str(record.get("image_path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return
	relic_sprite.texture = texture
	var size: Vector2 = texture.get_size()
	var scale_value: float = 34.0 / maxf(1.0, maxf(size.x, size.y))
	relic_sprite.scale = Vector2(scale_value, scale_value)
	relic_sprite.visible = true

func _restore_equipped_visuals() -> void:
	var transform_value: Variant = equipped_catalog.get("변신", {})
	if transform_value is Dictionary:
		_apply_transform_visual(transform_value as Dictionary)
	var doll_value: Variant = equipped_catalog.get("마법인형", {})
	if doll_value is Dictionary:
		_apply_doll_visual(doll_value as Dictionary)
	var relic_value: Variant = equipped_catalog.get("성물", {})
	if relic_value is Dictionary:
		_apply_relic_visual(relic_value as Dictionary)

func _all_equipped_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			records.append(value as Dictionary)
	for slot: String in ["weapon", "armor", "accessory"]:
		var item_value: Variant = equipped_items.get(slot, {})
		if item_value is Dictionary and not (item_value as Dictionary).is_empty():
			records.append(item_value as Dictionary)
	return records

func _stat_step_bonus(value: int, baseline: int, divisor: float) -> int:
	var delta: int = value - baseline
	if delta <= 0:
		return 0
	return int(floor(float(delta) / divisor))

func _melee_damage_stat() -> int:
	return _effective_attack() + _stat_step_bonus(str_stat, 10, 2.0)

func _melee_accuracy_stat() -> int:
	return level + str_stat + 10

func _ranged_damage_stat() -> int:
	return attack_power + _stat_step_bonus(dex_stat, 10, 2.0)

func _ranged_accuracy_stat() -> int:
	return level + dex_stat + 5

func _magic_damage_stat() -> int:
	return 5 + _stat_step_bonus(int_stat, 8, 2.0)

func _magic_accuracy_stat() -> int:
	return level + int_stat

func _effective_ac() -> int:
	var dex_ac_bonus: int = _stat_step_bonus(dex_stat, 10, 3.0)
	return -(_effective_defense() + dex_ac_bonus)

func _effective_dg() -> int:
	return _stat_step_bonus(dex_stat, 10, 4.0)

func _effective_er() -> int:
	return _stat_step_bonus(dex_stat, 10, 2.0)

func _effective_mr() -> int:
	return 10 + level + wis_stat * 2

func _damage_reduction_stat() -> int:
	return 0

func _character_stats_snapshot() -> Dictionary:
	return {
		"str": str_stat,
		"dex": dex_stat,
		"con": con_stat,
		"int": int_stat,
		"wis": wis_stat,
		"cha": cha_stat,
		"stat_points": stat_points,
		"melee_damage": _melee_damage_stat(),
		"melee_accuracy": _melee_accuracy_stat(),
		"ranged_damage": _ranged_damage_stat(),
		"ranged_accuracy": _ranged_accuracy_stat(),
		"magic_damage": _magic_damage_stat(),
		"magic_accuracy": _magic_accuracy_stat(),
		"ac": _effective_ac(),
		"dg": _effective_dg(),
		"er": _effective_er(),
		"mr": _effective_mr(),
		"damage_reduction": _damage_reduction_stat()
	}

func _effective_attack() -> int:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("atk", 0.0))
	return attack_power + int(round(bonus))

func _effective_defense() -> int:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("def", 0.0))
	return defense + int(round(bonus))

func _effective_max_hp() -> int:
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		flat_bonus += float(record.get("hpFlat", 0.0))
		percent_bonus += float(record.get("hpPct", 0.0))
	return maxi(1, int(round((max_hp + flat_bonus) * (1.0 + percent_bonus))))

func _experience_multiplier() -> float:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("xp", 0.0))
	return maxf(1.0, 1.0 + bonus)

func _update_companion(delta: float) -> void:
	if companion_sprite.visible:
		var side: float = -50.0 if player.facing != 2 else 50.0
		var target: Vector2 = player.global_position + Vector2(side, 20.0)
		$Companion.global_position = $Companion.global_position.lerp(target, clampf(delta * 6.5, 0.0, 1.0))
		var animation_name: String = _direction_animation_name(player.facing)
		if companion_sprite.animation != animation_name:
			companion_sprite.animation = animation_name
			companion_sprite.frame = 0
		if not companion_sprite.is_playing():
			companion_sprite.play()
		companion_sprite.position.y = -26.0 + sin(Time.get_ticks_msec() / 180.0) * 2.0
	if relic_sprite.visible:
		relic_sprite.global_position = player.global_position + Vector2(42.0, -64.0 + sin(Time.get_ticks_msec() / 420.0) * 4.0)
