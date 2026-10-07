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
var skills_db: Array = []
var job_classes: Array = []
var job_class: String = "기사"
var active_skill_buffs: Dictionary = {}
var catalog_db: Dictionary = {}
var catalog_image_index: Dictionary = {}
var directional_art: Dictionary = {}
var equipped_catalog: Dictionary = {"변신": {}, "마법인형": {}, "성물": {}}
var equipped_items: Dictionary = {"weapon": {}, "armor": {}, "accessory": {}}
var enhancement_levels: Dictionary = {}
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
const JOB_CLASS_ORDER: Array[String] = [
	"기사", "군주", "요정", "마법사", "다크엘프", "총사", "투사",
	"암흑기사", "신성검사", "광전사", "사신", "뇌신", "마검사"
]
const JOB_PRIMARY_STAT: Dictionary = {
	"기사":"STR", "군주":"STR / CHA", "요정":"DEX", "마법사":"INT / WIS",
	"다크엘프":"STR / DEX", "총사":"DEX", "투사":"STR", "암흑기사":"STR",
	"신성검사":"STR / WIS", "광전사":"STR / CON", "사신":"STR",
	"뇌신":"STR", "마검사":"STR / INT"
}

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
var inventory: Dictionary = {
	"HP 물약":100,
	"강력 HP 물약":14,
	"축복받은 HP 물약":10,
	"낡은 장검":1,
	"초록 잎":200,
	"무기 마법 주문서 (각인)":5,
	"갑옷 마법 주문서 (각인)":5,
	"장신구 마법 주문서 (각인)":3,
	"축복받은 무기 마법 주문서 (각인)":2,
	"축복받은 갑옷 마법 주문서 (각인)":2,
	"장인의 무기 마법 주문서 (각인)":1,
	"장인의 갑옷 마법 주문서 (각인)":1,
	"오림의 장신구 마법 주문서 (각인)":2,
	"축복받은 오림의 장신구 마법 주문서 (각인)":1
}

func _ready() -> void:
	rng.randomize()
	_load_data()
	_connect_signals()
	_setup_collision_tileset()
	hud.refresh_maps(maps)
	hud.set_catalog_data(catalog_db, catalog_image_index)
	hud.set_job_data(job_classes, skills_db)
	_set_map(active_map_id, false)
	_load_game(true)
	_ensure_job_class_visual()
	_update_job_skillbar()
	_update_hud()
	hud.append_log("V20 · 모바일 MMORPG HUD / 전투 화면 개선")

func _process(delta: float) -> void:
	auto_attack_timer = maxf(0.0, auto_attack_timer - delta)
	_tick_skill_buffs(delta)
	save_timer += delta
	if save_timer >= 30.0:
		save_timer = 0.0
		_save_game(true)
	if player.auto_enabled and not player.is_stunned():
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
	skills_db = game_db.get("스킬", []) as Array
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if catalog_value is Dictionary:
		catalog_db = catalog_value as Dictionary
	_merge_local_consumables_into_catalog()
	var image_index_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_IMAGE_INDEX_PATH))
	if image_index_value is Dictionary:
		catalog_image_index = image_index_value as Dictionary
	var directional_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTIONAL_PATH))
	if directional_value is Dictionary:
		directional_art = directional_value as Dictionary
	_build_job_classes()

func _merge_local_consumables_into_catalog() -> void:
	var catalog_items_value: Variant = catalog_db.get("아이템", [])
	if not (catalog_items_value is Array):
		catalog_db["아이템"] = []
	var catalog_items: Array = catalog_db.get("아이템", []) as Array
	var seen_names: Dictionary = {}
	for value: Variant in catalog_items:
		if value is Dictionary:
			var record: Dictionary = value as Dictionary
			seen_names[str(record.get("name", ""))] = true

	for value: Variant in item_db:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		var slot: String = str(record.get("slot", "")).strip_edges().to_lower()
		if slot != "consumable" and slot != "currency":
			continue
		var item_name: String = str(record.get("name", "")).strip_edges()
		if item_name == "" or seen_names.has(item_name):
			continue
		catalog_items.append(record.duplicate(true))
		seen_names[item_name] = true

	var enhancement_scrolls: Array[Dictionary] = [
		{"name":"무기 마법 주문서 (각인)", "grade":"일반", "type":"강화주문서", "slot":"consumable", "desc":"무기 강화에 사용. 안전강화 이후 실패 시 장비 소실 가능"},
		{"name":"갑옷 마법 주문서 (각인)", "grade":"일반", "type":"강화주문서", "slot":"consumable", "desc":"방어구 강화에 사용. 안전강화 이후 실패 시 장비 소실 가능"},
		{"name":"장신구 마법 주문서 (각인)", "grade":"일반", "type":"강화주문서", "slot":"consumable", "desc":"장신구 강화에 사용. 실패 시 장비 소실 가능"},
		{"name":"축복받은 무기 마법 주문서 (각인)", "grade":"희귀", "type":"강화주문서", "slot":"consumable", "desc":"성공 시 강화 단계가 +1~+3 상승할 수 있는 무기 주문서"},
		{"name":"축복받은 갑옷 마법 주문서 (각인)", "grade":"희귀", "type":"강화주문서", "slot":"consumable", "desc":"성공 시 강화 단계가 +1~+3 상승할 수 있는 방어구 주문서"},
		{"name":"장인의 무기 마법 주문서 (각인)", "grade":"영웅", "type":"강화주문서", "slot":"consumable", "desc":"+9 무기 강화. 실패해도 장비가 소실되지 않음"},
		{"name":"장인의 갑옷 마법 주문서 (각인)", "grade":"영웅", "type":"강화주문서", "slot":"consumable", "desc":"+7~+8 방어구 강화. 실패해도 장비가 소실되지 않음"},
		{"name":"오림의 장신구 마법 주문서 (각인)", "grade":"영웅", "type":"강화주문서", "slot":"consumable", "desc":"실패 시 장신구가 유지되거나 강화 단계가 1 하락"},
		{"name":"축복받은 오림의 장신구 마법 주문서 (각인)", "grade":"전설", "type":"강화주문서", "slot":"consumable", "desc":"실패해도 장신구 강화 단계가 유지됨"}
	]
	for scroll_record: Dictionary in enhancement_scrolls:
		var scroll_name: String = str(scroll_record.get("name", ""))
		if seen_names.has(scroll_name):
			continue
		catalog_items.append(scroll_record.duplicate(true))
		seen_names[scroll_name] = true
	catalog_db["아이템"] = catalog_items

func _connect_signals() -> void:
	player.attack_requested.connect(_attack)
	player.auto_toggled.connect(_on_auto_toggled)
	player.poison_tick.connect(_on_player_poison_tick)
	player.bleed_tick.connect(_on_player_bleed_tick)
	hud.move_vector_changed.connect(player.set_touch_vector)
	hud.attack_pressed.connect(_attack)
	hud.bleed_skill_pressed.connect(_cast_bleed_from_hud)
	hud.combat_skill_pressed.connect(_cast_combat_skill_from_hud)
	hud.target_pressed.connect(_select_nearest_target)
	hud.auto_pressed.connect(func() -> void: player.set_auto_enabled(not player.auto_enabled))
	hud.potion_pressed.connect(_use_potion)
	hud.quick_item_pressed.connect(_use_quick_item)
	hud.return_pressed.connect(_return_to_spawn)
	hud.inventory_pressed.connect(_open_inventory)
	hud.menu_pressed.connect(hud.toggle_menu)
	hud.map_pressed.connect(hud.toggle_map)
	hud.map_selected.connect(_on_map_selected)
	hud.save_pressed.connect(func() -> void: _save_game(false))
	hud.load_pressed.connect(func() -> void: _load_game(false))
	hud.catalog_equip_requested.connect(_equip_catalog)
	hud.class_selected.connect(_on_class_selected)
	hud.stat_increase_requested.connect(_on_stat_increase_requested)
	hud.job_class_selected.connect(_on_job_class_selected)
	hud.job_skill_pressed.connect(_cast_job_skill)
	hud.shop_buy_requested.connect(_buy_shop_item)
	hud.inventory_item_activated.connect(_on_inventory_item_activated)
	hud.enhancement_requested.connect(_attempt_enhancement)

func _set_map(map_id: String, keep_position: bool) -> void:
	if not maps_by_id.has(map_id):
		return
	active_map_id = map_id
	active_map = maps_by_id[map_id] as Dictionary
	tile_size = int(active_map.get("tile_size_world", 32))
	world_size = Vector2(float(int(active_map.get("width", 1)) * tile_size), float(int(active_map.get("height", 1)) * tile_size))
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = maxi(1, int(world_size.x))
	player.camera.limit_bottom = maxi(1, int(world_size.y))
	_clear_monsters()
	_clear_drops()
	_build_astar()
	_build_static_collisions()
	_build_collision_debug_tiles()
	_apply_map_background()
	if not keep_position or not _is_walkable_world(player.global_position):
		player.global_position = _spawn_position()
	player.camera.reset_smoothing()
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
		map_collision.remove_child(child)
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
	var require_reachable: bool = near != Vector2.ZERO
	var origin_cell: Vector2i = Vector2i.ZERO
	if require_reachable:
		origin_cell = _nearest_walkable_cell(_world_to_cell(near))
	for _attempt: int in range(700):
		var cell: Vector2i = Vector2i(rng.randi_range(0, maxi(0, width - 1)), rng.randi_range(0, maxi(0, height - 1)))
		if astar != null and not astar.is_point_solid(cell):
			var position_value: Vector2 = _cell_to_world(cell)
			if not require_reachable:
				return position_value
			var distance: float = position_value.distance_to(near)
			if distance < min_distance or distance > max_distance:
				continue
			if astar.get_id_path(origin_cell, cell).is_empty():
				continue
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
		monsters_root.remove_child(child)
		child.queue_free()

func _clear_drops() -> void:
	for child: Node in drops_root.get_children():
		drops_root.remove_child(child)
		child.queue_free()

func _magic_hit_chance(attacker_magic_accuracy: int, target_mr: int) -> float:
	var chance_percent: float = 75.0 + float(attacker_magic_accuracy - maxi(0, target_mr)) * 0.7
	return clampf(chance_percent / 100.0, 0.05, 0.95)

func _player_magic_hit_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _magic_hit_chance(_magic_accuracy_stat(), target.magic_resistance)

func _cast_bleed_skill(target: TwilightMonster, mp_cost: int = 6, power: int = 28, bleed_duration: float = 4.5, tick_damage: int = 9, tick_interval: float = 0.75, skill_name: String = "출혈 베기") -> bool:
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.is_silenced():
		hud.show_message("침묵 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if target == null or not is_instance_valid(target) or target.dead:
		hud.show_message("출혈 대상이 없습니다")
		return false
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	if player.global_position.distance_to(target.global_position) > 90.0:
		hud.show_message("출혈 베기 사거리 밖입니다")
		return false
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	player.pulse_attack()
	var hit_chance: float = _melee_hit_chance(target)
	if not _roll_melee_hit(target):
		target.show_miss()
		hud.append_log("%s MISS · 근거리 명중 %d / AC %d / %.1f%%" % [
			skill_name, _melee_accuracy_stat(), target.armor_class, hit_chance * 100.0
		])
		_update_hud()
		_update_target_hud()
		return false
	var damage: int = maxi(1, power + _stat_step_bonus(str_stat, 10, 2.0) + rng.randi_range(-4, 6))
	var critical_chance: float = _critical_chance(_player_critical_rate("melee"), target.critical_resistance)
	var critical: bool = rng.randf() < critical_chance
	if critical:
		damage = _critical_damage(damage)
	target.take_damage(damage, critical)
	if target.dead:
		_update_hud()
		_update_target_hud()
		return false
	var bleed_chance: float = _player_bleed_chance(target)
	var bleeding: bool = rng.randf() < bleed_chance
	if bleeding:
		target.apply_bleed(bleed_duration, tick_damage, tick_interval)
		hud.append_log("%s 성공 · %s %.1f초 출혈 · %d 피해/%.2f초 · 적중률 %.1f%%" % [
			skill_name, target.monster_name, bleed_duration, tick_damage, tick_interval, bleed_chance * 100.0
		])
	else:
		target.show_status_text("BLEED RESIST")
		hud.append_log("%s 출혈 실패 · 적중 %d / 내성 %d / %.1f%%" % [
			skill_name, _bleed_accuracy_stat(), target.bleed_resistance, bleed_chance * 100.0
		])
	_update_hud()
	_update_target_hud()
	return bleeding

func _cast_poison_skill(target: TwilightMonster, mp_cost: int = 6, poison_duration: float = 6.0, tick_damage: int = 12, tick_interval: float = 1.0, skill_name: String = "포이즌") -> bool:
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.is_silenced():
		hud.show_message("침묵 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if target == null or not is_instance_valid(target) or target.dead:
		hud.show_message("독 대상이 없습니다")
		return false
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	if player.global_position.distance_to(target.global_position) > 300.0:
		hud.show_message("포이즌 사거리 밖입니다")
		return false
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	player.pulse_attack()
	var magic_hit_chance: float = _player_magic_hit_chance(target)
	if rng.randf() >= magic_hit_chance:
		target.show_miss()
		hud.append_log("%s MISS · 마법 명중 %d / MR %d / %.1f%%" % [
			skill_name, _magic_accuracy_stat(), target.magic_resistance, magic_hit_chance * 100.0
		])
		_update_hud()
		_update_target_hud()
		return false
	var poison_chance: float = _player_poison_chance(target)
	var poisoned: bool = rng.randf() < poison_chance
	if poisoned:
		target.apply_poison(poison_duration, tick_damage, tick_interval)
		hud.append_log("%s 성공 · %s %.1f초 중독 · %d 피해/%.1f초 · 적중률 %.1f%%" % [
			skill_name, target.monster_name, poison_duration, tick_damage, tick_interval, poison_chance * 100.0
		])
	else:
		target.show_status_text("POISON RESIST")
		hud.append_log("%s 실패 · 독 적중 %d / 내성 %d / %.1f%%" % [
			skill_name, _poison_accuracy_stat(), target.poison_resistance, poison_chance * 100.0
		])
	_update_hud()
	_update_target_hud()
	return poisoned

func _cast_fear_skill(target: TwilightMonster, mp_cost: int = 10, fear_duration: float = 2.5, skill_name: String = "피어") -> bool:
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.is_silenced():
		hud.show_message("침묵 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if target == null or not is_instance_valid(target) or target.dead:
		hud.show_message("공포 대상이 없습니다")
		return false
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	if player.global_position.distance_to(target.global_position) > 300.0:
		hud.show_message("피어 사거리 밖입니다")
		return false
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	player.pulse_attack()
	var magic_hit_chance: float = _player_magic_hit_chance(target)
	if rng.randf() >= magic_hit_chance:
		target.show_miss()
		hud.append_log("%s MISS · 마법 명중 %d / MR %d / %.1f%%" % [
			skill_name, _magic_accuracy_stat(), target.magic_resistance, magic_hit_chance * 100.0
		])
		_update_hud()
		_update_target_hud()
		return false
	var fear_chance: float = _player_fear_chance(target)
	var feared: bool = rng.randf() < fear_chance
	if feared:
		target.apply_fear(fear_duration, player.global_position)
		hud.append_log("%s 성공 · %s %.1f초 공포 · 적중률 %.1f%%" % [
			skill_name, target.monster_name, fear_duration, fear_chance * 100.0
		])
	else:
		target.show_status_text("FEAR RESIST")
		hud.append_log("%s 실패 · 공포 적중 %d / 내성 %d / %.1f%%" % [
			skill_name, _fear_accuracy_stat(), target.fear_resistance, fear_chance * 100.0
		])
	_update_hud()
	_update_target_hud()
	return feared

func _cast_hold_skill(target: TwilightMonster, mp_cost: int = 8, hold_duration: float = 2.5, skill_name: String = "홀드") -> bool:
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.is_silenced():
		hud.show_message("침묵 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if target == null or not is_instance_valid(target) or target.dead:
		hud.show_message("홀드 대상이 없습니다")
		return false
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	if player.global_position.distance_to(target.global_position) > 280.0:
		hud.show_message("홀드 사거리 밖입니다")
		return false
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	player.pulse_attack()
	var magic_hit_chance: float = _player_magic_hit_chance(target)
	if rng.randf() >= magic_hit_chance:
		target.show_miss()
		hud.append_log("%s MISS · 마법 명중 %d / MR %d / %.1f%%" % [
			skill_name, _magic_accuracy_stat(), target.magic_resistance, magic_hit_chance * 100.0
		])
		_update_hud()
		_update_target_hud()
		return false
	var hold_chance: float = _player_hold_chance(target)
	var held: bool = rng.randf() < hold_chance
	if held:
		target.apply_hold(hold_duration)
		hud.append_log("%s 성공 · %s %.1f초 홀드 · 적중률 %.1f%%" % [
			skill_name, target.monster_name, hold_duration, hold_chance * 100.0
		])
	else:
		target.show_status_text("HOLD RESIST")
		hud.append_log("%s 실패 · 홀드 적중 %d / 내성 %d / %.1f%%" % [
			skill_name, _hold_accuracy_stat(), target.hold_resistance, hold_chance * 100.0
		])
	_update_hud()
	_update_target_hud()
	return held

func _cast_silence_skill(target: TwilightMonster, mp_cost: int = 8, silence_duration: float = 3.0, skill_name: String = "사일런스") -> bool:
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.is_silenced():
		hud.show_message("침묵 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if target == null or not is_instance_valid(target) or target.dead:
		hud.show_message("침묵 대상이 없습니다")
		return false
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	if player.global_position.distance_to(target.global_position) > 320.0:
		hud.show_message("사일런스 사거리 밖입니다")
		return false
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	player.pulse_attack()
	var magic_hit_chance: float = _player_magic_hit_chance(target)
	if rng.randf() >= magic_hit_chance:
		target.show_miss()
		hud.append_log("%s MISS · 마법 명중 %d / MR %d / %.1f%%" % [
			skill_name, _magic_accuracy_stat(), target.magic_resistance, magic_hit_chance * 100.0
		])
		_update_hud()
		_update_target_hud()
		return false
	var silence_chance: float = _player_silence_chance(target)
	var silenced: bool = rng.randf() < silence_chance
	if silenced:
		target.apply_silence(silence_duration)
		hud.append_log("%s 성공 · %s %.1f초 침묵 · 적중률 %.1f%%" % [
			skill_name, target.monster_name, silence_duration, silence_chance * 100.0
		])
	else:
		target.show_status_text("SILENCE RESIST")
		hud.append_log("%s 실패 · 침묵 적중 %d / 내성 %d / %.1f%%" % [
			skill_name, _silence_accuracy_stat(), target.silence_resistance, silence_chance * 100.0
		])
	_update_hud()
	_update_target_hud()
	return silenced

func _cast_stun_skill(target: TwilightMonster, power: int = 55, mp_cost: int = 10, stun_duration: float = 2.0, skill_name: String = "쇼크 스턴") -> bool:
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.is_silenced():
		hud.show_message("침묵 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if target == null or not is_instance_valid(target) or target.dead:
		hud.show_message("스턴 대상이 없습니다")
		return false
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	if player.global_position.distance_to(target.global_position) > 90.0:
		hud.show_message("쇼크 스턴 사거리 밖입니다")
		return false
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	player.pulse_attack()
	var hit_chance: float = _melee_hit_chance(target)
	if not _roll_melee_hit(target):
		target.show_miss()
		hud.append_log("%s MISS · 근거리 명중 %d / AC %d / %.1f%%" % [
			skill_name, _melee_accuracy_stat(), target.armor_class, hit_chance * 100.0
		])
		_update_hud()
		_update_target_hud()
		return false
	var damage: int = maxi(1, power + _stat_step_bonus(str_stat, 10, 2.0) + rng.randi_range(-4, 6))
	var critical_chance: float = _critical_chance(_player_critical_rate("melee"), target.critical_resistance)
	var critical: bool = rng.randf() < critical_chance
	if critical:
		damage = _critical_damage(damage)
	target.take_damage(damage, critical)
	if target.dead:
		_update_hud()
		_update_target_hud()
		return false
	var stun_chance: float = _player_stun_chance(target)
	var stunned: bool = rng.randf() < stun_chance
	if stunned:
		target.apply_stun(stun_duration)
		hud.append_log("%s 성공 · %s %.1f초 스턴 · 적중률 %.1f%%" % [
			skill_name, target.monster_name, stun_duration, stun_chance * 100.0
		])
	else:
		target.show_status_text("STUN RESIST")
		hud.append_log("%s 스턴 실패 · 적중 %d / 내성 %d / %.1f%%" % [
			skill_name, _stun_accuracy_stat(), target.stun_resistance, stun_chance * 100.0
		])
	_update_hud()
	_update_target_hud()
	return stunned

func _cast_magic_attack(target: TwilightMonster, power: int, mp_cost: int, skill_name: String = "마법") -> bool:
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 마법을 사용할 수 없습니다")
		return false
	if player.is_silenced():
		hud.show_message("침묵 상태에서는 마법을 사용할 수 없습니다")
		return false
	if target == null or not is_instance_valid(target) or target.dead:
		hud.show_message("마법 대상이 없습니다")
		return false
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	var max_range: float = 360.0
	if player.global_position.distance_to(target.global_position) > max_range:
		hud.show_message("마법 사거리 밖입니다")
		return false
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	player.pulse_attack()
	var hit_chance: float = _player_magic_hit_chance(target)
	if rng.randf() >= hit_chance:
		target.show_miss()
		hud.append_log("%s MISS · 마법 명중 %d / MR %d / %.1f%%" % [
			skill_name, _magic_accuracy_stat(), target.magic_resistance, hit_chance * 100.0
		])
		_update_hud()
		_update_target_hud()
		return false
	var damage: int = maxi(1, power + _magic_damage_stat() + rng.randi_range(-4, 6))
	var critical_chance: float = _critical_chance(_player_critical_rate("magic"), target.critical_resistance)
	var critical: bool = rng.randf() < critical_chance
	if critical:
		damage = _critical_damage(damage)
	target.take_damage(damage, critical)
	hud.append_log("%s 적중%s · %s에게 %d 마법 피해 · 명중 %.1f%% · 치명타 %.1f%%" % [
		skill_name, " CRITICAL" if critical else "", target.monster_name, damage,
		hit_chance * 100.0, critical_chance * 100.0
	])
	_update_hud()
	_update_target_hud()
	return true

func _melee_hit_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	var accuracy: int = _melee_accuracy_stat()
	var target_ac_abs: int = absi(target.armor_class)
	var chance_percent: float = 75.0 + float(accuracy - target_ac_abs) * 0.7
	return clampf(chance_percent / 100.0, 0.05, 0.95)

func _roll_melee_hit(target: TwilightMonster) -> bool:
	return rng.randf() < _melee_hit_chance(target)

func _skill_target(max_distance: float) -> TwilightMonster:
	var target: TwilightMonster = selected_monster
	if is_instance_valid(target) and not target.dead:
		if player.global_position.distance_to(target.global_position) <= max_distance:
			if _has_line_of_sight_world(player.global_position, target.global_position):
				return target
	return _nearest_visible_monster(max_distance)

func _cast_bleed_from_hud() -> void:
	# Backward-compatible signal used by older HUD revisions.
	_cast_bleed_skill(_skill_target(90.0))

func _cast_combat_skill_from_hud(skill_id: String) -> void:
	match skill_id:
		"attack":
			_attack()
		"bleed":
			_cast_bleed_skill(_skill_target(90.0))
		"stun":
			_cast_stun_skill(_skill_target(90.0))
		"poison":
			_cast_poison_skill(_skill_target(300.0))
		"silence":
			_cast_silence_skill(_skill_target(320.0))
		"hold":
			_cast_hold_skill(_skill_target(280.0))
		"fear":
			_cast_fear_skill(_skill_target(300.0))
		"magic":
			_cast_magic_attack(_skill_target(360.0), 26, 3, "에너지 볼트")
		_:
			hud.show_message("알 수 없는 스킬입니다")

func _attack() -> void:
	if player.is_stunned() or player.is_feared():
		return
	var target: TwilightMonster = selected_monster
	var target_usable: bool = is_instance_valid(target) and not target.dead
	if target_usable:
		target_usable = player.global_position.distance_to(target.global_position) <= 105.0
	if target_usable:
		target_usable = _has_line_of_sight_world(player.global_position, target.global_position)
	if not target_usable:
		target = _nearest_visible_monster(105.0)
	if target == null:
		hud.show_message("공격 범위에 보이는 대상이 없습니다")
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
	var critical_chance: float = _critical_chance(_player_critical_rate("melee"), target.critical_resistance)
	var critical: bool = rng.randf() < critical_chance
	if critical:
		damage = _critical_damage(damage)
	target.take_damage(damage, critical)
	hud.append_log("%s에게 %d 피해%s · 명중 %.1f%% · 치명타 %.1f%%" % [
		target.monster_name, damage, " CRITICAL" if critical else "",
		hit_chance * 100.0, critical_chance * 100.0
	])
	_update_target_hud()

func _run_auto_hunt() -> void:
	if player.is_stunned() or player.is_feared():
		player.clear_click_path()
		return
	if not is_instance_valid(auto_target) or auto_target.dead:
		auto_target = _nearest_reachable_monster(99999.0)
	if auto_target == null:
		selected_monster = null
		player.clear_click_path()
		return
	selected_monster = auto_target
	var distance: float = player.global_position.distance_to(auto_target.global_position)
	if distance <= 95.0 and _has_line_of_sight_world(player.global_position, auto_target.global_position):
		player.clear_click_path()
		if auto_attack_timer <= 0.0:
			auto_attack_timer = 0.72
			_attack()
	else:
		if player.is_held():
			player.clear_click_path()
			return
		if player.click_path.is_empty() or player.path_index >= player.click_path.size():
			var path: PackedVector2Array = find_world_path(player.global_position, auto_target.global_position)
			if path.is_empty():
				auto_target = _nearest_reachable_monster(99999.0)
				if auto_target == null:
					selected_monster = null
					player.clear_click_path()
					return
				selected_monster = auto_target
				path = find_world_path(player.global_position, auto_target.global_position)
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

func _has_line_of_sight_world(from_position: Vector2, to_position: Vector2) -> bool:
	if astar == null:
		return false
	var start: Vector2i = _world_to_cell(from_position)
	var goal: Vector2i = _world_to_cell(to_position)
	if not astar.is_in_boundsv(start) or not astar.is_in_boundsv(goal):
		return false
	var delta: Vector2i = goal - start
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	if steps <= 1:
		return true
	for step: int in range(1, steps):
		var t: float = float(step) / float(steps)
		var cell: Vector2i = Vector2i(
			roundi(lerpf(float(start.x), float(goal.x), t)),
			roundi(lerpf(float(start.y), float(goal.y), t))
		)
		if astar.is_in_boundsv(cell) and astar.is_point_solid(cell):
			return false
	return true

func _nearest_visible_monster(max_distance: float) -> TwilightMonster:
	var best: TwilightMonster = null
	var best_distance: float = max_distance
	for node: Node in monsters_root.get_children():
		if not (node is TwilightMonster):
			continue
		var monster: TwilightMonster = node
		if monster.dead:
			continue
		var distance: float = player.global_position.distance_to(monster.global_position)
		if distance >= best_distance:
			continue
		if not _has_line_of_sight_world(player.global_position, monster.global_position):
			continue
		best_distance = distance
		best = monster
	return best

func _nearest_reachable_monster(max_distance: float) -> TwilightMonster:
	var best: TwilightMonster = null
	var best_distance: float = max_distance
	for node: Node in monsters_root.get_children():
		if not (node is TwilightMonster):
			continue
		var monster: TwilightMonster = node
		if monster.dead:
			continue
		var distance: float = player.global_position.distance_to(monster.global_position)
		if distance >= best_distance:
			continue
		if find_world_path(player.global_position, monster.global_position).is_empty():
			continue
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
	_roll_drop(monster)
	_check_level_up()
	if monster == selected_monster:
		selected_monster = null
	if monster == auto_target:
		auto_target = null
	if monster.get_parent() == monsters_root:
		monsters_root.remove_child(monster)
	monster.queue_free()
	_update_hud()
	call_deferred("_ensure_monster_count")

func _ensure_monster_count() -> void:
	var alive: int = 0
	for child: Node in monsters_root.get_children():
		if child is TwilightMonster and not (child as TwilightMonster).dead:
			alive += 1
	if alive < 9:
		_spawn_monsters(9 - alive)

func _roll_drop(monster: TwilightMonster) -> void:
	if monster == null or not is_instance_valid(monster):
		return
	if rng.randf() > 0.72:
		return
	var item_name: String = ""
	if not monster.drop_items.is_empty():
		item_name = monster.drop_items[rng.randi_range(0, monster.drop_items.size() - 1)]
	elif not item_db.is_empty():
		var record_value: Variant = item_db[rng.randi_range(0, item_db.size() - 1)]
		if record_value is Dictionary:
			item_name = str(record_value.get("name", ""))
	if item_name.is_empty():
		return
	inventory[item_name] = int(inventory.get(item_name, 0)) + 1
	hud.refresh_inventory(inventory)
	var label: Label = Label.new()
	label.text = "◆ " + item_name
	label.position = monster.global_position + Vector2(-45, -28)
	label.add_theme_color_override("font_color", Color("f5d66f"))
	drops_root.add_child(label)
	var timer: SceneTreeTimer = get_tree().create_timer(4.0)
	timer.timeout.connect(label.queue_free)
	hud.show_message("획득: " + item_name)

func _physical_hit_chance(attacker_accuracy: int, target_ac: int, avoidance: int) -> float:
	var base_percent: float = 75.0 + float(attacker_accuracy - absi(target_ac)) * 0.7
	var final_percent: float = base_percent - float(maxi(0, avoidance))
	return clampf(final_percent / 100.0, 0.05, 0.95)

func _avoidance_for_attack_type(attack_type: String) -> int:
	return _effective_er() if attack_type == "ranged" else _effective_dg()

func _monster_accuracy_for_attack_type(attacker: TwilightMonster, attack_type: String) -> int:
	if attacker == null:
		return 0
	match attack_type:
		"magic":
			return attacker.magic_accuracy
		"ranged":
			return attacker.ranged_accuracy
		_:
			return attacker.melee_accuracy

func _monster_hit_chance(attacker: TwilightMonster, attack_type: String = "melee") -> float:
	if attacker == null:
		return 0.05
	var normalized_type: String = attack_type
	if normalized_type != "ranged" and normalized_type != "magic":
		normalized_type = "melee"
	var accuracy: int = _monster_accuracy_for_attack_type(attacker, normalized_type)
	if normalized_type == "magic":
		return _magic_hit_chance(accuracy, _effective_mr())
	return _physical_hit_chance(
		accuracy,
		_effective_ac(),
		_avoidance_for_attack_type(normalized_type)
	)

func _roll_monster_hit(attacker: TwilightMonster, attack_type: String = "melee") -> bool:
	return rng.randf() < _monster_hit_chance(attacker, attack_type)

func _respawn_player(message_text: String) -> void:
	hp = _effective_max_hp()
	mp = max_mp
	gold = maxi(0, gold - 500)
	player.clear_status_effects()
	player.global_position = _spawn_position()
	player.camera.reset_smoothing()
	selected_monster = null
	auto_target = null
	hud.clear_target()
	hud.show_message(message_text)

func _on_player_poison_tick(damage_value: int) -> void:
	if damage_value <= 0 or hp <= 0:
		return
	var poison_damage: int = maxi(1, damage_value)
	hp = maxi(0, hp - poison_damage)
	player.show_poison_damage(poison_damage)
	hud.append_log("독 피해 %d" % poison_damage)
	if hp <= 0:
		_respawn_player("독 피해로 사망 후 부활했습니다")
	_update_hud()

func _on_player_bleed_tick(damage_value: int) -> void:
	if damage_value <= 0 or hp <= 0:
		return
	var bleed_damage: int = maxi(1, damage_value)
	hp = maxi(0, hp - bleed_damage)
	player.show_bleed_damage(bleed_damage)
	hud.append_log("출혈 피해 %d" % bleed_damage)
	if hp <= 0:
		_respawn_player("출혈 피해로 사망 후 부활했습니다")
	_update_hud()

func _on_player_hit(attacker: TwilightMonster, damage_value: int, attack_type: String) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	var normalized_type: String = attack_type
	if normalized_type != "ranged" and normalized_type != "magic":
		normalized_type = "melee"
	var accuracy: int = _monster_accuracy_for_attack_type(attacker, normalized_type)
	var hit_chance: float = _monster_hit_chance(attacker, normalized_type)
	if not _roll_monster_hit(attacker, normalized_type):
		player.show_miss()
		if normalized_type == "magic":
			hud.append_log("%s 마법 MISS · 마법 명중 %d / 내 MR %d / %.1f%%" % [
				attacker.monster_name, accuracy, _effective_mr(), hit_chance * 100.0
			])
		else:
			var avoidance: int = _avoidance_for_attack_type(normalized_type)
			var evasion_name: String = "ER" if normalized_type == "ranged" else "DG"
			hud.append_log("%s 공격 MISS · %s 명중 %d / 내 AC %d / %s %d / %.1f%%" % [
				attacker.monster_name,
				"원거리" if normalized_type == "ranged" else "근거리",
				accuracy,
				_effective_ac(),
				evasion_name,
				avoidance,
				hit_chance * 100.0
			])
		return
	var attacker_critical_rate: int = attacker.critical_rate_for_type(normalized_type)
	var critical_chance: float = _critical_chance(attacker_critical_rate, _critical_resistance_stat())
	var critical: bool = rng.randf() < critical_chance
	var incoming_damage: int = _critical_damage(damage_value) if critical else damage_value
	var reduced: int = maxi(1, incoming_damage) if normalized_type == "magic" else _physical_damage_after_reduction(incoming_damage)
	hp = maxi(0, hp - reduced)
	player.show_received_damage(reduced, critical)
	if normalized_type == "magic":
		hud.append_log("%s에게 %d 마법 피해%s · 피격률 %.1f%% · 치명타 %.1f%% · MR %d" % [
			attacker.monster_name, reduced, " CRITICAL" if critical else "",
			hit_chance * 100.0, critical_chance * 100.0, _effective_mr()
		])
	else:
		hud.append_log("%s에게 %d 피해%s · %s 피격률 %.1f%% · 치명타 %.1f%% · 리덕션 %d" % [
			attacker.monster_name,
			reduced,
			" CRITICAL" if critical else "",
			"원거리" if normalized_type == "ranged" else "근거리",
			hit_chance * 100.0,
			critical_chance * 100.0,
			_damage_reduction_stat()
		])
	if hp > 0 and attacker.stun_duration > 0.0 and attacker.stun_accuracy > 0:
		var stun_chance: float = _status_effect_chance(
			attacker.stun_accuracy,
			attacker.monster_level,
			_stun_resistance_stat(),
			level
		)
		if rng.randf() < stun_chance:
			player.apply_stun(attacker.stun_duration)
			hud.append_log("%s 스턴 적중 · %.1f초 · 내 스턴 내성 %d · %.1f%%" % [
				attacker.monster_name, attacker.stun_duration, _stun_resistance_stat(), stun_chance * 100.0
			])
		else:
			player.show_status_text("STUN RESIST")
			hud.append_log("%s 스턴 저항 성공 · 내성 %d · %.1f%%" % [
				attacker.monster_name, _stun_resistance_stat(), stun_chance * 100.0
			])
	if hp > 0 and attacker.silence_duration > 0.0 and attacker.silence_accuracy > 0:
		var silence_chance: float = _status_effect_chance(
			attacker.silence_accuracy,
			attacker.monster_level,
			_silence_resistance_stat(),
			level
		)
		if rng.randf() < silence_chance:
			player.apply_silence(attacker.silence_duration)
			hud.append_log("%s 침묵 적중 · %.1f초 · 내 침묵 내성 %d · %.1f%%" % [
				attacker.monster_name, attacker.silence_duration, _silence_resistance_stat(), silence_chance * 100.0
			])
		else:
			player.show_status_text("SILENCE RESIST")
			hud.append_log("%s 침묵 저항 성공 · 내성 %d · %.1f%%" % [
				attacker.monster_name, _silence_resistance_stat(), silence_chance * 100.0
			])
	if hp > 0 and attacker.hold_duration > 0.0 and attacker.hold_accuracy > 0:
		var hold_chance: float = _status_effect_chance(
			attacker.hold_accuracy,
			attacker.monster_level,
			_hold_resistance_stat(),
			level
		)
		if rng.randf() < hold_chance:
			player.apply_hold(attacker.hold_duration)
			hud.append_log("%s 홀드 적중 · %.1f초 · 내 홀드 내성 %d · %.1f%%" % [
				attacker.monster_name, attacker.hold_duration, _hold_resistance_stat(), hold_chance * 100.0
			])
		else:
			player.show_status_text("HOLD RESIST")
			hud.append_log("%s 홀드 저항 성공 · 내성 %d · %.1f%%" % [
				attacker.monster_name, _hold_resistance_stat(), hold_chance * 100.0
			])
	if hp > 0 and attacker.fear_duration > 0.0 and attacker.fear_accuracy > 0:
		var fear_chance: float = _status_effect_chance(
			attacker.fear_accuracy,
			attacker.monster_level,
			_fear_resistance_stat(),
			level
		)
		if rng.randf() < fear_chance:
			player.apply_fear(attacker.fear_duration, attacker.global_position)
			hud.append_log("%s 공포 적중 · %.1f초 · 내 공포 내성 %d · %.1f%%" % [
				attacker.monster_name, attacker.fear_duration, _fear_resistance_stat(), fear_chance * 100.0
			])
		else:
			player.show_status_text("FEAR RESIST")
			hud.append_log("%s 공포 저항 성공 · 내성 %d · %.1f%%" % [
				attacker.monster_name, _fear_resistance_stat(), fear_chance * 100.0
			])
	if hp > 0 and attacker.poison_duration > 0.0 and attacker.poison_accuracy > 0 and attacker.poison_tick_damage > 0:
		var poison_chance: float = _status_effect_chance(
			attacker.poison_accuracy,
			attacker.monster_level,
			_poison_resistance_stat(),
			level
		)
		if rng.randf() < poison_chance:
			player.apply_poison(attacker.poison_duration, attacker.poison_tick_damage, attacker.poison_tick_interval)
			hud.append_log("%s 독 적중 · %.1f초 · %d 피해/%.1f초 · 내 독 내성 %d · %.1f%%" % [
				attacker.monster_name, attacker.poison_duration, attacker.poison_tick_damage,
				attacker.poison_tick_interval, _poison_resistance_stat(), poison_chance * 100.0
			])
		else:
			player.show_status_text("POISON RESIST")
			hud.append_log("%s 독 저항 성공 · 내성 %d · %.1f%%" % [
				attacker.monster_name, _poison_resistance_stat(), poison_chance * 100.0
			])
	if hp > 0 and normalized_type == "melee" and attacker.bleed_duration > 0.0 and attacker.bleed_accuracy > 0 and attacker.bleed_tick_damage > 0:
		var bleed_chance: float = _status_effect_chance(
			attacker.bleed_accuracy,
			attacker.monster_level,
			_bleed_resistance_stat(),
			level
		)
		if rng.randf() < bleed_chance:
			player.apply_bleed(attacker.bleed_duration, attacker.bleed_tick_damage, attacker.bleed_tick_interval)
			hud.append_log("%s 출혈 적중 · %.1f초 · %d 피해/%.2f초 · 내 출혈 내성 %d · %.1f%%" % [
				attacker.monster_name, attacker.bleed_duration, attacker.bleed_tick_damage,
				attacker.bleed_tick_interval, _bleed_resistance_stat(), bleed_chance * 100.0
			])
		else:
			player.show_status_text("BLEED RESIST")
			hud.append_log("%s 출혈 저항 성공 · 내성 %d · %.1f%%" % [
				attacker.monster_name, _bleed_resistance_stat(), bleed_chance * 100.0
			])
	if hp <= 0:
		_respawn_player("사망 후 부활했습니다")
	_update_hud()

func _stat_points_for_level_up(new_level: int) -> int:
	# Every level-up grants one allocatable point so the stat-growth screen is
	# immediately useful and predictable in the offline RPG.
	return 1 if new_level >= 2 else 0

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
	var gained_stat_points: bool = false
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
			gained_stat_points = true
			hud.show_message("레벨 업! Lv.%d · 스탯 포인트 +%d" % [level, awarded_points])
			hud.append_log("Lv.%d 달성 · 스탯 포인트 +%d" % [level, awarded_points])
		else:
			hud.show_message("레벨 업! Lv.%d" % level)
	if gained_stat_points:
		_update_hud()
		hud.call_deferred("open_character")

func _select_nearest_target() -> void:
	var target: TwilightMonster = _nearest_reachable_monster(600.0)
	if target == null:
		hud.show_message("선택할 수 있는 몬스터가 없습니다")
		return
	_select_monster(target)
	hud.show_message("대상 선택: %s" % target.monster_name)

func _scroll_kind(scroll_name: String) -> String:
	if scroll_name.find("무기 마법 주문서") >= 0:
		return "weapon"
	if scroll_name.find("갑옷 마법 주문서") >= 0:
		return "armor"
	if scroll_name.find("장신구 마법 주문서") >= 0:
		return "accessory"
	return ""

func _scroll_mode(scroll_name: String) -> String:
	if scroll_name.find("축복받은 오림") >= 0:
		return "blessed_orim"
	if scroll_name.find("오림") >= 0:
		return "orim"
	if scroll_name.find("장인의") >= 0:
		return "craftsman"
	if scroll_name.find("축복받은") >= 0:
		return "blessed"
	return "normal"

func _on_inventory_item_activated(item_name: String) -> void:
	var kind: String = _scroll_kind(item_name)
	if kind == "":
		hud.show_message("이 아이템은 더블클릭 사용 대상이 아닙니다")
		return
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("주문서가 없습니다")
		return
	var candidates: Array = _enhancement_candidates(kind, _scroll_mode(item_name))
	hud.call("open_enhancement", item_name, candidates)

func _enhancement_candidates(kind: String, mode: String = "normal") -> Array:
	var result: Array = []
	var names: Array = inventory.keys()
	names.sort()
	for value: Variant in names:
		var item_name: String = str(value)
		if int(inventory.get(item_name, 0)) <= 0:
			continue
		var record: Dictionary = _find_catalog_item_record(item_name)
		if record.is_empty() or str(record.get("slot", "")) != kind:
			continue
		var level_value: int = int(enhancement_levels.get(item_name, 0))
		if not _enhancement_level_allowed(kind, mode, level_value):
			continue
		var chance: Dictionary = _enhancement_chance(kind, level_value, mode)
		if float(chance.get("success", 0.0)) <= 0.0:
			continue
		var max_gain: int = 3 if mode == "blessed" and level_value <= 2 else (2 if mode == "blessed" and level_value <= 5 else 1)
		result.append({
			"name": item_name,
			"level": level_value,
			"safe_level": _safe_enhancement_level(kind),
			"success_chance": float(chance.get("success", 0.0)),
			"no_change_chance": float(chance.get("no_change", 0.0)),
			"destroy_chance": float(chance.get("destroy", 0.0)),
			"decrease_chance": float(chance.get("decrease", 0.0)),
			"gain_text": _enhancement_gain_text(mode, level_value),
			"bonus_text": _enhancement_bonus_text(kind, level_value + max_gain),
			"equipped": _is_item_equipped(item_name)
		})
	return result

func _enhancement_level_allowed(kind: String, mode: String, current_level: int) -> bool:
	if mode == "craftsman":
		if kind == "weapon":
			return current_level == 9
		if kind == "armor":
			return current_level == 7 or current_level == 8
		return false
	if mode == "orim" or mode == "blessed_orim":
		return kind == "accessory" and current_level >= 0 and current_level <= 7
	return current_level >= 0 and current_level <= 20

func _enhancement_gain_text(mode: String, current_level: int) -> String:
	if mode != "blessed":
		return "+1"
	if current_level <= 2:
		return "+1 / +2 / +3"
	if current_level <= 5:
		return "+1 / +2"
	return "+1"

func _roll_enhancement_gain(mode: String, current_level: int) -> int:
	if mode != "blessed":
		return 1
	var roll: float = rng.randf_range(0.0, 100.0)
	if current_level <= 2:
		if roll < 33.3334:
			return 1
		if roll < 66.6667:
			return 2
		return 3
	if current_level <= 5:
		return 1 if roll < 50.0 else 2
	return 1

func _find_catalog_item_record(item_name: String) -> Dictionary:
	var source: Array = catalog_db.get("아이템", []) as Array
	for value: Variant in source:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		if str(record.get("name", "")) == item_name:
			return record
	return {}

func _safe_enhancement_level(kind: String) -> int:
	match kind:
		"weapon":
			return 6
		"armor":
			return 4
		_:
			return 0

func _enhancement_chance(kind: String, current_level: int, mode: String = "normal") -> Dictionary:
	if mode == "craftsman":
		if kind == "weapon" and current_level == 9:
			return {"success": 0.6, "no_change": 99.4, "destroy": 0.0, "decrease": 0.0}
		if kind == "armor" and (current_level == 7 or current_level == 8):
			return {"success": 2.5, "no_change": 97.5, "destroy": 0.0, "decrease": 0.0}
		return {"success": 0.0, "no_change": 0.0, "destroy": 0.0, "decrease": 0.0}

	if mode == "orim" or mode == "blessed_orim":
		var orim_success: Array[float] = [45.0, 35.0, 25.0, 20.0, 10.0, 5.0, 3.5, 2.0]
		var orim_no_change: Array[float] = [55.0, 60.0, 65.0, 65.0, 75.0, 75.0, 76.5, 78.0]
		var orim_decrease: Array[float] = [0.0, 5.0, 10.0, 15.0, 15.0, 20.0, 20.0, 20.0]
		if current_level < 0 or current_level >= orim_success.size():
			return {"success": 0.0, "no_change": 0.0, "destroy": 0.0, "decrease": 0.0}
		var success_value: float = orim_success[current_level]
		if mode == "blessed_orim":
			return {"success": success_value, "no_change": 100.0 - success_value, "destroy": 0.0, "decrease": 0.0}
		return {
			"success": success_value,
			"no_change": orim_no_change[current_level],
			"destroy": 0.0,
			"decrease": orim_decrease[current_level]
		}

	var success: float = 0.0
	var no_change: float = 0.0
	var destroy: float = 0.0
	if kind == "weapon":
		if current_level <= 5:
			success = 100.0
		elif current_level <= 8:
			success = 33.3
			destroy = 66.7
		elif current_level == 9:
			success = 0.6
			no_change = 32.4
			destroy = 67.0
		elif current_level == 10:
			success = 0.8
			no_change = 32.5
			destroy = 66.7
		elif current_level <= 20:
			success = 0.7
			no_change = 32.4
			destroy = 66.9
	elif kind == "armor":
		if current_level <= 3:
			success = 100.0
		elif current_level == 4:
			success = 25.0
			destroy = 75.0
		elif current_level == 5:
			success = 20.0
			destroy = 80.0
		elif current_level == 6:
			success = 16.7
			destroy = 83.3
		elif current_level == 7:
			success = 14.3
			destroy = 85.7
		elif current_level == 8:
			success = 12.5
			destroy = 87.5
		elif current_level == 9:
			success = 0.3
			no_change = 10.8
			destroy = 88.9
		elif current_level == 10:
			success = 0.3
			no_change = 9.8
			destroy = 89.9
		elif current_level <= 20:
			success = 0.2
			no_change = 8.9
			destroy = 90.9
	elif kind == "accessory":
		var accessory_success: Array[float] = [75.0, 65.0, 55.0, 45.0, 35.0, 25.0, 15.0, 5.0]
		if current_level >= 0 and current_level < accessory_success.size():
			success = accessory_success[current_level]
			destroy = 100.0 - success

	return {"success": success, "no_change": no_change, "destroy": destroy, "decrease": 0.0}

func _enhancement_bonus_text(kind: String, target_level: int) -> String:
	match kind:
		"weapon":
			return "추가 대미지 +%d · 명중 +%d" % [target_level, target_level]
		"armor":
			return "AC -%d" % target_level
		"accessory":
			return "Max HP +%d · 방어 +%d" % [target_level * 20, int(floor(float(target_level) / 2.0))]
	return "능력치 상승"

func _is_item_equipped(item_name: String) -> bool:
	for slot: String in ["weapon", "armor", "accessory"]:
		var value: Variant = equipped_items.get(slot, {})
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name:
			return true
	return false

func _attempt_enhancement(scroll_name: String, target_name: String) -> void:
	var kind: String = _scroll_kind(scroll_name)
	var mode: String = _scroll_mode(scroll_name)
	if kind == "":
		hud.show_message("강화 주문서가 올바르지 않습니다")
		return
	if int(inventory.get(scroll_name, 0)) <= 0:
		hud.show_message("강화 주문서가 부족합니다")
		return
	if int(inventory.get(target_name, 0)) <= 0:
		hud.show_message("강화할 장비가 없습니다")
		return

	var target_record: Dictionary = _find_catalog_item_record(target_name)
	if target_record.is_empty() or str(target_record.get("slot", "")) != kind:
		hud.show_message("이 주문서로 강화할 수 없는 장비입니다")
		return

	var current_level: int = int(enhancement_levels.get(target_name, 0))
	if not _enhancement_level_allowed(kind, mode, current_level):
		hud.show_message("현재 강화 단계에는 이 주문서를 사용할 수 없습니다")
		return
	var chance: Dictionary = _enhancement_chance(kind, current_level, mode)
	var success_chance: float = float(chance.get("success", 0.0))
	var no_change_chance: float = float(chance.get("no_change", 0.0))
	var decrease_chance: float = float(chance.get("decrease", 0.0))
	if success_chance <= 0.0:
		hud.show_message("더 이상 강화할 수 없습니다")
		return

	inventory[scroll_name] = int(inventory.get(scroll_name, 0)) - 1
	if int(inventory.get(scroll_name, 0)) <= 0:
		inventory.erase(scroll_name)

	var result_type: String = "maintain"
	var result_level: int = current_level
	var roll: float = rng.randf_range(0.0, 100.0)
	if roll < success_chance:
		var gain: int = _roll_enhancement_gain(mode, current_level)
		result_level = mini(21, current_level + gain)
		enhancement_levels[target_name] = result_level
		result_type = "success"
		hud.show_message("강화 성공! +%d %s" % [result_level, target_name])
		hud.append_log("강화 성공 · +%d %s" % [result_level, target_name])
	elif roll < success_chance + no_change_chance:
		hud.show_message("강화 실패 · 장비 변화 없음")
		hud.append_log("강화 실패(유지) · +%d %s" % [current_level, target_name])
	elif roll < success_chance + no_change_chance + decrease_chance:
		result_level = maxi(0, current_level - 1)
		enhancement_levels[target_name] = result_level
		result_type = "decrease"
		hud.show_message("강화 실패 · +%d → +%d 하락" % [current_level, result_level])
		hud.append_log("강화 실패(하락) · %s +%d → +%d" % [target_name, current_level, result_level])
	else:
		_destroy_enhancement_target(target_name)
		result_type = "destroy"
		result_level = 0
		hud.show_message("강화 실패 · %s 소실" % target_name)
		hud.append_log("강화 실패(소실) · +%d %s" % [current_level, target_name])

	if hud.has_method("show_enhancement_result"):
		hud.call("show_enhancement_result", result_type, target_name, current_level, result_level)
	hp = mini(hp, _effective_max_hp())
	hud.refresh_inventory(inventory)
	_update_hud()
	_save_game(true)

	if int(inventory.get(scroll_name, 0)) > 0:
		var remaining_candidates: Array = _enhancement_candidates(kind, mode)
		hud.call("open_enhancement", scroll_name, remaining_candidates)
	else:
		hud.call("open_enhancement", scroll_name, [])

func _destroy_enhancement_target(item_name: String) -> void:
	var remaining: int = int(inventory.get(item_name, 0)) - 1
	if remaining > 0:
		inventory[item_name] = remaining
	else:
		inventory.erase(item_name)
	enhancement_levels.erase(item_name)
	for slot: String in ["weapon", "armor", "accessory"]:
		var value: Variant = equipped_items.get(slot, {})
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name:
			equipped_items[slot] = {}

func _equipment_enhancement_level(slot: String) -> int:
	var value: Variant = equipped_items.get(slot, {})
	if not (value is Dictionary):
		return 0
	var record: Dictionary = value as Dictionary
	if record.is_empty():
		return 0
	return int(enhancement_levels.get(str(record.get("name", "")), 0))

func _equipped_items_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for slot: String in ["weapon", "armor", "accessory"]:
		var value: Variant = equipped_items.get(slot, {})
		if value is Dictionary:
			var record: Dictionary = (value as Dictionary).duplicate(true)
			if not record.is_empty():
				record["enhance_level"] = int(enhancement_levels.get(str(record.get("name", "")), 0))
			result[slot] = record
		else:
			result[slot] = {}
	return result

func _buy_shop_item(item_name: String, price: int) -> void:
	var safe_price: int = maxi(0, price)
	if safe_price <= 0:
		return
	if gold < safe_price:
		hud.show_message("아데나가 부족합니다")
		return
	gold -= safe_price
	inventory[item_name] = int(inventory.get(item_name, 0)) + 1
	hud.refresh_inventory(inventory)
	hud.show_message("%s 구매 · %d 아데나" % [item_name, safe_price])
	hud.append_log("상점 구매 · %s (-%d)" % [item_name, safe_price])
	_update_hud()
	_save_game(true)
	if hud.has_method("open_shop"):
		hud.call("open_shop")

func _use_potion() -> void:
	_use_healing_item("HP 물약", 320)

func _use_quick_item(item_name: String) -> void:
	match item_name:
		"HP 물약":
			_use_healing_item(item_name, 320)
		"강력 HP 물약":
			_use_healing_item(item_name, 650)
		"축복받은 HP 물약":
			_use_healing_item(item_name, 1100)
		_:
			hud.show_message("사용할 수 없는 퀵 아이템입니다")

func _use_healing_item(item_name: String, heal_amount: int) -> void:
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("%s이(가) 없습니다" % item_name)
		return
	var effective_max_hp: int = _effective_max_hp()
	if hp >= effective_max_hp:
		hud.show_message("HP가 가득 찼습니다")
		return
	inventory[item_name] = int(inventory.get(item_name, 0)) - 1
	hp = mini(effective_max_hp, hp + maxi(1, heal_amount))
	hud.refresh_inventory(inventory)
	hud.show_message("%s 사용" % item_name)
	_update_hud()

func _return_to_spawn() -> void:
	if player.is_stunned() or player.is_feared():
		hud.show_message("현재 상태에서는 귀환할 수 없습니다")
		return
	player.set_auto_enabled(false)
	player.clear_click_path()
	player.global_position = _spawn_position()
	player.camera.reset_smoothing()
	selected_monster = null
	auto_target = null
	hud.clear_target()
	hud.show_message("현재 지역 시작 지점으로 귀환했습니다")

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
	character_state["job_class"] = job_class
	var job_profile: Dictionary = _job_profile(job_class)
	character_state["job_image_path"] = str(job_profile.get("image_path", ""))
	character_state["job_transform_name"] = str(job_profile.get("transform_name", ""))
	character_state["level"] = level
	character_state["hp"] = hp
	character_state["max_hp"] = _effective_max_hp()
	character_state["mp"] = mp
	character_state["max_mp"] = max_mp
	character_state["attack"] = _effective_attack()
	character_state["defense"] = _effective_defense()
	character_state["equipped"] = equipped_catalog
	character_state["equipped_items"] = _equipped_items_snapshot()
	character_state["enhancement_levels"] = enhancement_levels
	character_state["gold"] = gold
	character_state["quest_kills"] = quest_kills
	character_state["quest_goal"] = QUEST_GOAL
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
		"job_class": job_class,
		"equipped_catalog": equipped_catalog,
		"equipped_items": equipped_items,
		"enhancement_levels": enhancement_levels,
		"quest_kills": quest_kills
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		if not quiet:
			hud.show_message("저장 실패")
		hud.append_log("저장 파일을 열 수 없습니다")
		return
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
		if not quiet:
			hud.show_message("저장 데이터가 손상되었습니다")
		hud.append_log("저장 데이터 JSON 해석 실패")
		return
	var data: Dictionary = value as Dictionary
	level = maxi(1, int(data.get("level", level)))
	experience = maxi(0, int(data.get("experience", data.get("exp", experience))))
	exp_need = maxi(1, int(data.get("exp_need", exp_need)))
	hp = int(data.get("hp", hp))
	max_hp = maxi(1, int(data.get("max_hp", max_hp)))
	mp = int(data.get("mp", mp))
	max_mp = maxi(0, int(data.get("max_mp", max_mp)))
	attack_power = maxi(1, int(data.get("attack", attack_power)))
	defense = maxi(0, int(data.get("defense", defense)))
	str_stat = int(data.get("str", str_stat))
	dex_stat = int(data.get("dex", dex_stat))
	con_stat = int(data.get("con", con_stat))
	int_stat = int(data.get("int", int_stat))
	wis_stat = int(data.get("wis", wis_stat))
	cha_stat = int(data.get("cha", cha_stat))
	stat_points = maxi(0, int(data.get("stat_points", stat_points)))
	gold = maxi(0, int(data.get("gold", gold)))
	quest_kills = clampi(int(data.get("quest_kills", quest_kills)), 0, QUEST_GOAL)
	var inventory_value: Variant = data.get("inventory", inventory)
	if inventory_value is Dictionary:
		inventory = inventory_value as Dictionary
	class_index = clampi(int(data.get("class_index", class_index)), 0, 3)
	job_class = str(data.get("job_class", job_class))
	if not JOB_CLASS_ORDER.has(job_class):
		job_class = "기사"
	player.set_class_index(class_index)
	player.clear_status_effects()
	var equipped_value: Variant = data.get("equipped_catalog", equipped_catalog)
	if equipped_value is Dictionary:
		equipped_catalog = equipped_value as Dictionary
	var equipped_items_value: Variant = data.get("equipped_items", equipped_items)
	if equipped_items_value is Dictionary:
		equipped_items = equipped_items_value as Dictionary
	var enhancement_value: Variant = data.get("enhancement_levels", enhancement_levels)
	if enhancement_value is Dictionary:
		enhancement_levels = enhancement_value as Dictionary
	_restore_equipped_visuals()
	hp = clampi(hp, 0, _effective_max_hp())
	mp = clampi(mp, 0, max_mp)
	var map_id: String = str(data.get("map_id", active_map_id))
	if not maps_by_id.has(map_id):
		map_id = active_map_id
	_set_map(map_id, false)
	var position_value: Variant = data.get("position", [])
	if position_value is Array:
		var position_array: Array = position_value as Array
		if position_array.size() >= 2:
			var saved_position: Vector2 = Vector2(float(position_array[0]), float(position_array[1]))
			if _is_walkable_world(saved_position):
				player.global_position = saved_position
				player.camera.reset_smoothing()
	_update_job_skillbar()
	_update_hud()
	if not quiet:
		hud.show_message("불러오기 완료")


func _build_job_classes() -> void:
	job_classes.clear()
	var transforms: Array = catalog_db.get("변신", []) as Array
	for class_name: String in JOB_CLASS_ORDER:
		var transform_record: Dictionary = {}
		for value: Variant in transforms:
			if not (value is Dictionary):
				continue
			var record: Dictionary = value as Dictionary
			if str(record.get("grade", "")) != "신화":
				continue
			var transform_name: String = str(record.get("name", ""))
			if transform_name.begins_with("신화-" + class_name):
				transform_record = record
				break
		if transform_record.is_empty():
			continue
		job_classes.append({
			"name": class_name,
			"transform_name": str(transform_record.get("name", "")),
			"image_path": str(transform_record.get("image_path", "")),
			"source_id": str(transform_record.get("sourceId", "")),
			"weapon": _job_weapon_hint(transform_record),
			"role": _job_role_from_skills(class_name),
			"primary_stat": str(JOB_PRIMARY_STAT.get(class_name, ""))
		})

func _job_weapon_hint(transform_record: Dictionary) -> String:
	var weapons: PackedStringArray = PackedStringArray()
	var options: Array = transform_record.get("sourceOptions", []) as Array
	for option_value: Variant in options:
		var option: String = str(option_value)
		var marker_index: int = option.find(" 추가 대미지")
		if marker_index <= 0:
			continue
		var weapon_name: String = option.substr(0, marker_index).strip_edges()
		if weapon_name != "" and not weapons.has(weapon_name):
			weapons.append(weapon_name)
	return ", ".join(weapons) if not weapons.is_empty() else "공용"

func _job_role_from_skills(class_name: String) -> String:
	var attack_count: int = 0
	var heal_count: int = 0
	var buff_count: int = 0
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if str(skill.get("class", "")) != class_name:
			continue
		var effect: String = str(skill.get("effect", ""))
		if effect == "damage":
			attack_count += 1
		elif effect == "heal":
			heal_count += 1
		elif effect.find("Buff") >= 0:
			buff_count += 1
	if heal_count >= 3:
		return "공격 / 회복"
	if buff_count > attack_count:
		return "전투 / 강화"
	return "공격 / 전투"

func _job_profile(class_name: String) -> Dictionary:
	for value: Variant in job_classes:
		if value is Dictionary:
			var profile: Dictionary = value as Dictionary
			if str(profile.get("name", "")) == class_name:
				return profile
	return {}

func _job_transform_record(class_name: String) -> Dictionary:
	var profile: Dictionary = _job_profile(class_name)
	var target_name: String = str(profile.get("transform_name", ""))
	if target_name == "":
		return {}
	var transforms: Array = catalog_db.get("변신", []) as Array
	for value: Variant in transforms:
		if value is Dictionary:
			var record: Dictionary = value as Dictionary
			if str(record.get("name", "")) == target_name:
				return record
	return {}

func _ensure_job_class_visual() -> void:
	var current_transform: Variant = equipped_catalog.get("변신", {})
	if current_transform is Dictionary and not (current_transform as Dictionary).is_empty():
		return
	var record: Dictionary = _job_transform_record(job_class)
	if record.is_empty():
		return
	equipped_catalog["변신"] = record.duplicate(true)
	_apply_transform_visual(record)

func _on_job_class_selected(class_name: String) -> void:
	if not JOB_CLASS_ORDER.has(class_name):
		return
	job_class = class_name
	var record: Dictionary = _job_transform_record(job_class)
	if not record.is_empty():
		equipped_catalog["변신"] = record.duplicate(true)
		_apply_transform_visual(record)
	_update_job_skillbar()
	hud.show_message("직업 변경: %s" % job_class)
	hud.append_log("%s 클래스 적용 · 대표 신화 변신 %s" % [job_class, str(record.get("name", ""))])
	_update_hud()
	_save_game(true)

func _job_skills(include_common: bool = true) -> Array:
	var result: Array = []
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		var skill_class: String = str(skill.get("class", "공용"))
		if skill_class == job_class or (include_common and skill_class == "공용"):
			result.append(skill)
	return result

func _skill_grade_weight(grade: String) -> int:
	match grade:
		"신화": return 5
		"전설": return 4
		"영웅": return 3
		"희귀": return 2
		"고급": return 1
		_: return 0

func _quickbar_job_skills() -> Array:
	var class_skills: Array = []
	var common_skills: Array = []
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		var effect: String = str(skill.get("effect", ""))
		if effect not in ["damage", "heal", "atkBuff", "defBuff", "hpBuff", "speedBuff", "teleport"]:
			continue
		var skill_class: String = str(skill.get("class", "공용"))
		if skill_class == job_class:
			class_skills.append(skill)
		elif skill_class == "공용":
			common_skills.append(skill)
	class_skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _skill_grade_weight(str(a.get("grade", "일반"))) > _skill_grade_weight(str(b.get("grade", "일반")))
	)
	common_skills.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _skill_grade_weight(str(a.get("grade", "일반"))) > _skill_grade_weight(str(b.get("grade", "일반")))
	)
	var result: Array = []
	for skill: Dictionary in class_skills:
		if result.size() >= 8:
			break
		result.append(skill)
	for skill: Dictionary in common_skills:
		if result.size() >= 8:
			break
		result.append(skill)
	return result

func _update_job_skillbar() -> void:
	if hud.has_method("set_job_skillbar"):
		hud.call("set_job_skillbar", _quickbar_job_skills())

func _skill_record(skill_name: String) -> Dictionary:
	for value: Variant in skills_db:
		if value is Dictionary:
			var skill: Dictionary = value as Dictionary
			if str(skill.get("name", "")) == skill_name:
				return skill
	return {}

func _cast_job_skill(skill_name: String) -> void:
	var skill: Dictionary = _skill_record(skill_name)
	if skill.is_empty():
		hud.show_message("스킬 정보를 찾을 수 없습니다")
		return
	var skill_class: String = str(skill.get("class", "공용"))
	if skill_class != "공용" and skill_class != job_class:
		hud.show_message("%s 전용 스킬입니다" % skill_class)
		return
	if player.is_stunned() or player.is_feared():
		hud.show_message("현재 상태에서는 스킬을 사용할 수 없습니다")
		return
	if player.is_silenced() and int(skill.get("mp", 0)) > 0:
		hud.show_message("침묵 상태에서는 스킬을 사용할 수 없습니다")
		return
	var effect: String = str(skill.get("effect", "utility"))
	match effect:
		"damage":
			_cast_job_damage_skill(skill)
		"heal":
			_cast_job_heal_skill(skill)
		"atkBuff", "defBuff", "hpBuff", "speedBuff":
			_cast_job_buff_skill(skill)
		"teleport":
			_cast_job_teleport_skill(skill)
		_:
			if not _spend_skill_mp(skill):
				return
			hud.show_message("%s 사용" % skill_name)
			hud.append_log("%s · %s 보조 스킬 사용" % [job_class, skill_name])
			_update_hud()

func _spend_skill_mp(skill: Dictionary) -> bool:
	var mp_cost: int = maxi(0, int(skill.get("mp", 0)))
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	mp -= mp_cost
	return true

func _cast_job_damage_skill(skill: Dictionary) -> void:
	var max_range: float = maxf(80.0, float(skill.get("range", 120)))
	var target: TwilightMonster = _skill_target(max_range)
	if target == null:
		hud.show_message("공격 대상이 없습니다")
		return
	if not _spend_skill_mp(skill):
		return
	selected_monster = target
	player.pulse_attack()
	var skill_class: String = str(skill.get("class", "공용"))
	var ranged_style: bool = job_class == "요정" or job_class == "총사"
	var magic_style: bool = job_class == "마법사" or skill_class == "마법사" or (skill_class == "공용" and max_range >= 250.0)
	var hit_chance: float = _melee_hit_chance(target)
	var stat_damage: int = _melee_damage_stat()
	var crit_rate: int = _player_critical_rate("melee")
	if magic_style:
		hit_chance = _player_magic_hit_chance(target)
		stat_damage = _magic_damage_stat()
		crit_rate = _player_critical_rate("magic")
	elif ranged_style:
		stat_damage = _ranged_damage_stat()
		crit_rate = _player_critical_rate("ranged")
		hit_chance = clampf(_melee_hit_chance(target) + float(_ranged_accuracy_stat() - _melee_accuracy_stat()) * 0.01, 0.10, 0.95)
	if rng.randf() >= hit_chance:
		target.show_miss()
		hud.append_log("%s MISS · %.1f%%" % [str(skill.get("name", "")), hit_chance * 100.0])
		_update_hud()
		return
	var power: int = maxi(1, int(skill.get("power", 20)))
	var damage: int = maxi(1, power + stat_damage + rng.randi_range(-4, 6))
	var critical_chance: float = _critical_chance(crit_rate, target.critical_resistance)
	var critical: bool = rng.randf() < critical_chance
	if critical:
		damage = _critical_damage(damage)
	target.take_damage(damage, critical)
	hud.append_log("%s · %s에게 %d 피해%s" % [
		str(skill.get("name", "")), target.monster_name, damage, " CRITICAL" if critical else ""
	])
	_update_hud()
	_update_target_hud()

func _cast_job_heal_skill(skill: Dictionary) -> void:
	if not _spend_skill_mp(skill):
		return
	var amount: int = maxi(1, int(skill.get("heal", 40)) + int_stat * 2)
	hp = mini(_effective_max_hp(), hp + amount)
	hud.show_message("%s · HP +%d" % [str(skill.get("name", "")), amount])
	hud.append_log("%s 회복 · HP +%d" % [str(skill.get("name", "")), amount])
	_update_hud()

func _cast_job_buff_skill(skill: Dictionary) -> void:
	if not _spend_skill_mp(skill):
		return
	var duration: float = maxf(5.0, float(skill.get("duration", 60.0)))
	var speed_value: float = float(skill.get("speed", 1.0))
	active_skill_buffs[str(skill.get("name", "버프"))] = {
		"remaining": duration,
		"atk": int(skill.get("atk", 0)),
		"def": int(skill.get("def", 0)),
		"hp": int(skill.get("hpFlat", 0)),
		"speed": speed_value
	}
	player.set_skill_speed_multiplier(_active_skill_speed_multiplier())
	hp = mini(_effective_max_hp(), hp + maxi(0, int(skill.get("hpFlat", 0))))
	hud.show_message("%s 활성화" % str(skill.get("name", "")))
	hud.append_log("%s 버프 · %.0f초" % [str(skill.get("name", "")), duration])
	_update_hud()

func _cast_job_teleport_skill(skill: Dictionary) -> void:
	if not _spend_skill_mp(skill):
		return
	for _attempt: int in range(60):
		var candidate: Vector2 = player.global_position + Vector2(rng.randf_range(-700.0, 700.0), rng.randf_range(-500.0, 500.0))
		if _is_walkable_world(candidate):
			player.global_position = candidate
			player.clear_click_path()
			player.camera.reset_smoothing()
			hud.show_message("%s" % str(skill.get("name", "텔레포트")))
			_update_hud()
			return
	hud.show_message("이동 가능한 위치를 찾지 못했습니다")

func _active_skill_buff_total(key: String) -> int:
	var total: int = 0
	for value: Variant in active_skill_buffs.values():
		if value is Dictionary:
			total += int((value as Dictionary).get(key, 0))
	return total

func _active_skill_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for value: Variant in active_skill_buffs.values():
		if value is Dictionary:
			multiplier = maxf(multiplier, float((value as Dictionary).get("speed", 1.0)))
	return multiplier

func _tick_skill_buffs(delta: float) -> void:
	if active_skill_buffs.is_empty():
		return
	var expired: Array[String] = []
	for key_value: Variant in active_skill_buffs.keys():
		var key: String = str(key_value)
		var value: Variant = active_skill_buffs.get(key, {})
		if not (value is Dictionary):
			expired.append(key)
			continue
		var buff: Dictionary = value as Dictionary
		buff["remaining"] = float(buff.get("remaining", 0.0)) - delta
		active_skill_buffs[key] = buff
		if float(buff.get("remaining", 0.0)) <= 0.0:
			expired.append(key)
	if expired.is_empty():
		return
	for key: String in expired:
		active_skill_buffs.erase(key)
	player.set_skill_speed_multiplier(_active_skill_speed_multiplier())
	hp = mini(hp, _effective_max_hp())
	_update_hud()

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
	return level + str_stat + 10 + _equipment_enhancement_level("weapon")

func _ranged_damage_stat() -> int:
	return attack_power + _stat_step_bonus(dex_stat, 10, 2.0) + _equipment_enhancement_level("weapon")

func _ranged_accuracy_stat() -> int:
	return level + dex_stat + 5 + _equipment_enhancement_level("weapon")

func _magic_damage_stat() -> int:
	return 5 + _stat_step_bonus(int_stat, 8, 2.0)

func _magic_accuracy_stat() -> int:
	return level + int_stat

func _record_critical_bonus(record: Dictionary, attack_type: String) -> int:
	var total: int = 0
	if record.has("crit"):
		total += int(record.get("crit", 0))
	if record.has("critical_rate"):
		total += int(record.get("critical_rate", 0))
	if record.has("치명타"):
		total += int(record.get("치명타", 0))
	match attack_type:
		"ranged":
			total += int(record.get("ranged_crit", record.get("rangedCrit", record.get("원거리 치명타", 0))))
		"magic":
			total += int(record.get("magic_crit", record.get("magicCrit", record.get("마법 치명타", 0))))
		_:
			total += int(record.get("melee_crit", record.get("meleeCrit", record.get("근거리 치명타", 0))))
	return total

func _record_critical_resistance(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"critical_resistance",
		record.get("criticalResistance", record.get("crit_resist", record.get("치명타 저항", record.get("치명타 내성", 0))))
	)))

func _player_critical_rate(attack_type: String) -> int:
	var base: int = 2
	match attack_type:
		"ranged":
			base += _stat_step_bonus(dex_stat, 16, 5.0)
		"magic":
			base += _stat_step_bonus(int_stat, 16, 5.0)
		_:
			base += _stat_step_bonus(str_stat, 16, 5.0)
	for record: Dictionary in _all_equipped_records():
		base += _record_critical_bonus(record, attack_type)
	return clampi(base, 0, 50)

func _record_stun_accuracy(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"stun_accuracy",
		record.get("stunAccuracy", record.get("스턴 적중", record.get("스턴 적중률", 0)))
	)))

func _record_stun_resistance(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"stun_resistance",
		record.get("stunResistance", record.get("stun_resist", record.get("스턴 내성", record.get("스턴 저항", 0))))
	)))

func _stun_accuracy_stat() -> int:
	var total: int = 5 + _stat_step_bonus(str_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_stun_accuracy(record)
	return clampi(total, 0, 100)

func _stun_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(con_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_stun_resistance(record)
	return clampi(total, 0, 100)

func _record_silence_accuracy(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"silence_accuracy",
		record.get("silenceAccuracy", record.get("침묵 적중", record.get("사일런스 적중", 0)))
	)))

func _record_silence_resistance(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"silence_resistance",
		record.get("silenceResistance", record.get("silence_resist", record.get("침묵 내성", record.get("사일런스 내성", 0))))
	)))

func _silence_accuracy_stat() -> int:
	var total: int = 5 + _stat_step_bonus(int_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_silence_accuracy(record)
	return clampi(total, 0, 100)

func _silence_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(wis_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_silence_resistance(record)
	return clampi(total, 0, 100)

func _player_silence_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_silence_accuracy_stat(),
		level,
		target.silence_resistance,
		target.monster_level
	)

func _record_hold_accuracy(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"hold_accuracy",
		record.get("holdAccuracy", record.get("홀드 적중", record.get("속박 적중", 0)))
	)))

func _record_hold_resistance(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"hold_resistance",
		record.get("holdResistance", record.get("hold_resist", record.get("홀드 내성", record.get("속박 내성", 0))))
	)))

func _hold_accuracy_stat() -> int:
	var total: int = 5 + _stat_step_bonus(dex_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_hold_accuracy(record)
	return clampi(total, 0, 100)

func _hold_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(con_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_hold_resistance(record)
	return clampi(total, 0, 100)

func _player_hold_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_hold_accuracy_stat(),
		level,
		target.hold_resistance,
		target.monster_level
	)

func _record_fear_accuracy(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"fear_accuracy",
		record.get("fearAccuracy", record.get("공포 적중", record.get("피어 적중", 0)))
	)))

func _record_fear_resistance(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"fear_resistance",
		record.get("fearResistance", record.get("fear_resist", record.get("공포 내성", record.get("피어 내성", 0))))
	)))

func _fear_accuracy_stat() -> int:
	var total: int = 5 + _stat_step_bonus(int_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_fear_accuracy(record)
	return clampi(total, 0, 100)

func _fear_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(wis_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_fear_resistance(record)
	return clampi(total, 0, 100)

func _player_fear_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_fear_accuracy_stat(),
		level,
		target.fear_resistance,
		target.monster_level
	)

func _record_poison_accuracy(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"poison_accuracy",
		record.get("poisonAccuracy", record.get("독 적중", record.get("중독 적중", 0)))
	)))

func _record_poison_resistance(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"poison_resistance",
		record.get("poisonResistance", record.get("poison_resist", record.get("독 내성", record.get("중독 내성", 0))))
	)))

func _poison_accuracy_stat() -> int:
	var total: int = 5 + _stat_step_bonus(int_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_poison_accuracy(record)
	return clampi(total, 0, 100)

func _poison_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(con_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_poison_resistance(record)
	return clampi(total, 0, 100)

func _player_poison_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_poison_accuracy_stat(),
		level,
		target.poison_resistance,
		target.monster_level
	)

func _record_bleed_accuracy(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"bleed_accuracy",
		record.get("bleedAccuracy", record.get("출혈 적중", record.get("출혈 적중률", 0)))
	)))

func _record_bleed_resistance(record: Dictionary) -> int:
	return maxi(0, int(record.get(
		"bleed_resistance",
		record.get("bleedResistance", record.get("bleed_resist", record.get("출혈 내성", record.get("출혈 저항", 0))))
	)))

func _bleed_accuracy_stat() -> int:
	var total: int = 5 + _stat_step_bonus(str_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_bleed_accuracy(record)
	return clampi(total, 0, 100)

func _bleed_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(con_stat, 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_bleed_resistance(record)
	return clampi(total, 0, 100)

func _player_bleed_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_bleed_accuracy_stat(),
		level,
		target.bleed_resistance,
		target.monster_level
	)

func _status_effect_chance(attacker_accuracy: int, attacker_level: int, defender_resistance: int, defender_level: int) -> float:
	var chance_percent: float = 50.0 + float(attacker_accuracy - defender_resistance)
	chance_percent += float(attacker_level - defender_level) * 0.5
	return clampf(chance_percent / 100.0, 0.05, 0.95)

func _player_stun_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_stun_accuracy_stat(),
		level,
		target.stun_resistance,
		target.monster_level
	)

func _critical_resistance_stat() -> int:
	var total: int = 0
	for record: Dictionary in _all_equipped_records():
		total += _record_critical_resistance(record)
	return clampi(total, 0, 50)

func _critical_chance(attacker_critical_rate: int, defender_critical_resistance: int) -> float:
	return clampf(float(attacker_critical_rate - defender_critical_resistance) / 100.0, 0.0, 0.50)

func _critical_damage(raw_damage: int) -> int:
	return maxi(1, int(round(float(raw_damage) * 1.5)))

func _effective_ac() -> int:
	var dex_ac_bonus: int = _stat_step_bonus(dex_stat, 10, 3.0)
	return -(_effective_defense() + dex_ac_bonus)

func _record_dg(record: Dictionary) -> int:
	if record.has("dg"):
		return maxi(0, int(record.get("dg", 0)))
	if record.has("DG"):
		return maxi(0, int(record.get("DG", 0)))
	if record.has("근거리 회피력"):
		return maxi(0, int(record.get("근거리 회피력", 0)))
	return 0

func _record_er(record: Dictionary) -> int:
	if record.has("er"):
		return maxi(0, int(record.get("er", 0)))
	if record.has("ER"):
		return maxi(0, int(record.get("ER", 0)))
	if record.has("원거리 회피력"):
		return maxi(0, int(record.get("원거리 회피력", 0)))
	return 0

func _effective_dg() -> int:
	var total: int = _stat_step_bonus(dex_stat, 10, 4.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_dg(record)
	return maxi(0, total)

func _effective_er() -> int:
	var total: int = _stat_step_bonus(dex_stat, 10, 2.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_er(record)
	return maxi(0, total)

func _record_mr(record: Dictionary) -> int:
	if record.has("mr"):
		return maxi(0, int(record.get("mr", 0)))
	if record.has("MR"):
		return maxi(0, int(record.get("MR", 0)))
	if record.has("마법 방어력"):
		return maxi(0, int(record.get("마법 방어력", 0)))
	return 0

func _effective_mr() -> int:
	var total: int = 10 + level + wis_stat * 2
	for record: Dictionary in _all_equipped_records():
		total += _record_mr(record)
	return maxi(0, total)

func _record_damage_reduction(record: Dictionary) -> int:
	if record.has("damage_reduction"):
		return maxi(0, int(record.get("damage_reduction", 0)))
	if record.has("damageReduction"):
		return maxi(0, int(record.get("damageReduction", 0)))
	if record.has("reduction"):
		return maxi(0, int(record.get("reduction", 0)))
	if record.has("리덕션"):
		return maxi(0, int(record.get("리덕션", 0)))
	return 0

func _damage_reduction_stat() -> int:
	var total: int = 0
	for record: Dictionary in _all_equipped_records():
		total += _record_damage_reduction(record)
	return maxi(0, total)

func _physical_damage_after_reduction(raw_damage: int) -> int:
	return maxi(1, raw_damage - _damage_reduction_stat())

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
		"melee_critical": _player_critical_rate("melee"),
		"ranged_critical": _player_critical_rate("ranged"),
		"magic_critical": _player_critical_rate("magic"),
		"critical_resistance": _critical_resistance_stat(),
		"stun_accuracy": _stun_accuracy_stat(),
		"stun_resistance": _stun_resistance_stat(),
		"silence_accuracy": _silence_accuracy_stat(),
		"silence_resistance": _silence_resistance_stat(),
		"hold_accuracy": _hold_accuracy_stat(),
		"hold_resistance": _hold_resistance_stat(),
		"fear_accuracy": _fear_accuracy_stat(),
		"fear_resistance": _fear_resistance_stat(),
		"poison_accuracy": _poison_accuracy_stat(),
		"poison_resistance": _poison_resistance_stat(),
		"bleed_accuracy": _bleed_accuracy_stat(),
		"bleed_resistance": _bleed_resistance_stat(),
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
	return attack_power + int(round(bonus)) + _equipment_enhancement_level("weapon") + _active_skill_buff_total("atk")

func _effective_defense() -> int:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("def", 0.0))
	var armor_enhance: int = _equipment_enhancement_level("armor")
	var accessory_enhance: int = int(floor(float(_equipment_enhancement_level("accessory")) / 2.0))
	return defense + int(round(bonus)) + armor_enhance + accessory_enhance + _active_skill_buff_total("def")

func _effective_max_hp() -> int:
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		flat_bonus += float(record.get("hpFlat", 0.0))
		percent_bonus += float(record.get("hpPct", 0.0))
	flat_bonus += float(_equipment_enhancement_level("accessory") * 20)
	flat_bonus += float(_active_skill_buff_total("hp"))
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
