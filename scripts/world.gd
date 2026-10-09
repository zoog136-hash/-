extends Node2D
class_name TwilightWorld

const SAVE_PATH: String = "user://twilight_v20_save.json"
const MAPS_PATH: String = "res://data/maps_v18.json"
const DB_PATH: String = "res://data/game_db_v17.json"
const CATALOG_PATH: String = "res://data/catalog_v19.json"
const CATALOG_IMAGE_INDEX_PATH: String = "res://data/catalog_image_index_v19.json"
const DIRECTIONAL_PATH: String = "res://data/directional_art_v19.json"
const MONSTER_SCENE: PackedScene = preload("res://scenes/Monster.tscn")
const FIELD_PATH: String = "res://data/maps/aden_field.json"
const FIELD_INDEX_PATH: String = "res://data/maps/field_index.json"
const COORD = preload("res://scripts/maps/world_coordinates.gd")
const FIELD_SCRIPT = preload("res://scripts/maps/playable_field.gd")
const FIELD_RENDERER = preload("res://scripts/maps/field_renderer.gd")
const FIELD_POPULATION = preload("res://scripts/maps/field_population.gd")
const FIELD_MINIMAP = preload("res://scripts/maps/field_minimap.gd")
const SKILL_RULES = preload("res://scripts/skill_rules.gd")
const ITEM_OPTIONS = preload("res://scripts/item_options.gd")
const CATALOG_EFFECTS = preload("res://scripts/catalog_effects.gd")
const LOOT_DROP = preload("res://scripts/loot_drop.gd")
const GROUND_LOOT_MANAGER = preload("res://scripts/loot/ground_loot_manager.gd")
const LOOT_PICKUP_CONTROLLER = preload("res://scripts/loot/loot_pickup_controller.gd")
var ground_loot: TwilightGroundLootManager = GROUND_LOOT_MANAGER.new()
var loot_pickup: TwilightLootPickupController = LOOT_PICKUP_CONTROLLER.new()
const RELIC_MOTION = preload("res://scripts/animation/relic_motion.gd")
var relic_motion: TwilightRelicMotion = RELIC_MOTION.new()
const FOLLOWER_MOTION = preload("res://scripts/animation/follower_motion.gd")
var doll_motion: TwilightFollowerMotion = FOLLOWER_MOTION.new()
const COMBAT_VFX = preload("res://scripts/animation/combat_vfx.gd")
var combat_vfx: TwilightCombatVFX = null
var feedback_kind: String = "melee"
var feedback_style: String = "slash"
const COMBAT_FLIGHTS = preload("res://scripts/animation/combat_flights.gd")
var combat_flights: TwilightCombatFlights = null
var combat_corpses: Node2D = null
var pending_attack: Dictionary = {}
var combat_generation: int = 0
var resolving_combat_action: bool = false

const ANIMATION_CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const ELEMENT_RULES = preload("res://scripts/elemental_rules.gd")

var field_map: PlayableField = null
var field_renderer: FieldRenderer = null
var field_physics: StaticBody2D = null
var field_population: FieldPopulation = null
var field_minimap: FieldMinimap = null
var portal_cooldown: float = 2.0
var auto_repath_timer: float = 0.0
var auto_last_position: Vector2 = Vector2.ZERO
var pending_ground_pickup: Button = null
const GROUND_PICKUP_RADIUS: float = 60.0
const AUTO_GROUND_PICKUP_SCAN: float = 460.0
var auto_stuck_time: float = 0.0
var region_id: String = ""
var return_gate: Node2D = null
var return_gate_position: Vector2 = Vector2.INF

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
var loot_catalog: Dictionary = {}
var monster_db: Array = []
var item_db: Array = []
var item_weight_index: Dictionary = {}
var skills_db: Array = []
var job_classes: Array = []
var job_class: String = "기사"
var active_skill_buffs: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var skill_global_cooldown: float = 0.0
var active_item_buffs: Dictionary = {}
var item_use_cooldowns: Dictionary = {}
var quickslots: Array = []
var self_mode_enabled: bool = false
var auto_buff_check_timer: float = 0.0
var catalog_db: Dictionary = {}
var verified_catalog_options: Dictionary = {}
var catalog_image_index: Dictionary = {}
var directional_art: Dictionary = {}
var equipped_catalog: Dictionary = {"변신": {}, "마법인형": {}, "성물": {}}
var equipped_items: Dictionary = {
	"weapon": {}, "offhand": {}, "helmet": {}, "tshirt": {}, "body": {}, "pants": {}, "cloak": {},
	"belt": {}, "earring1": {}, "earring2": {}, "ring1": {}, "ring2": {}, "seal1": {}, "seal2": {},
	"gaiters": {}, "boots": {}, "gloves": {}, "bracelet": {}, "necklace": {}, "badge": {},
	"crystal": {}, "catalyst": {}, "rune": {}
}
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
# Charge movement is advanced locally; field map/path scripts are never mutated.
var charge_route: PackedVector2Array = PackedVector2Array()
var charge_route_index: int = 0
var charge_target: TwilightMonster = null
var charge_skill: Dictionary = {}
var charge_speed: float = 1150.0
var save_timer: float = 0.0
var hp_recovery_elapsed: float = 0.0
var mp_recovery_elapsed: float = 0.0
const UNIQUE_RECOVERY_INTERVAL: float = 30.0
const UNIQUE_RECOVERY_AMOUNT: int = 5
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
const JOB_ALLOWED_WEAPONS: Dictionary = {
	"기사": ["단검", "한손검", "양손검", "창", "그레이트소드"],
	"군주": ["단검", "한손검", "양손검", "창"],
	"요정": ["단검", "한손검", "활"],
	"마법사": ["단검", "지팡이"],
	"다크엘프": ["단검", "이도류", "크로우"],
	"총사": ["라이플", "핸드캐넌"],
	"투사": ["체인소드", "창"],
	"암흑기사": ["한손검", "양손검", "그레이트소드"],
	"신성검사": ["한손검", "마검"],
	"광전사": ["도끼", "창", "양손검", "그레이트소드"],
	"사신": ["사이드"],
	"뇌신": ["창", "건틀렛"],
	"마검사": ["마검", "그레이트소드"]
}
const WEAPON_TYPE_ALIASES: Dictionary = {
	"체인 소드":"체인소드", "체인소드":"체인소드",
	"핸드 캐넌":"핸드캐넌", "핸드캐넌":"핸드캐넌",
	"룬소드":"마검", "마검":"마검",
	"그레이트 소드":"그레이트소드", "그레이트소드":"그레이트소드"
}
const WEAPON_BASE_ATTACK_SPEED: Dictionary = {
	"단검":32.0, "한손검":22.0, "양손검":12.0, "그레이트소드":8.0,
	"창":17.0, "도끼":14.0, "지팡이":18.0, "이도류":26.0, "크로우":28.0,
	"사이드":20.0, "체인소드":18.0, "마검":21.0, "건틀렛":24.0,
	"활":24.0, "라이플":18.0, "핸드캐넌":10.0
}

const SHIELD_COMPATIBLE_WEAPONS: Array[String] = ["단검", "한손검", "지팡이", "마검"]
const EQUIPMENT_SLOT_ORDER: Array[String] = [
	"weapon", "offhand", "helmet", "tshirt", "body", "pants", "cloak", "shoulder", "belt",
	"earring1", "earring2", "ring1", "ring2", "seal1", "seal2", "gaiters",
	"boots", "gloves", "bracelet", "necklace", "badge", "crystal", "catalyst", "rune"
]
const ARMOR_EQUIPMENT_SLOTS: Array[String] = [
	"offhand", "helmet", "tshirt", "body", "pants", "cloak", "shoulder", "gaiters", "boots", "gloves"
]
const ACCESSORY_EQUIPMENT_SLOTS: Array[String] = [
	"belt", "earring1", "earring2", "ring1", "ring2", "seal1", "seal2",
	"bracelet", "necklace", "badge", "crystal", "catalyst", "rune"
]
const EQUIPMENT_SLOT_LABELS: Dictionary = {
	"weapon":"무기", "offhand":"보조무기", "helmet":"투구", "tshirt":"티셔츠", "body":"갑옷",
	"pants":"하의", "cloak":"망토", "shoulder":"견갑", "belt":"벨트", "earring1":"귀걸이1", "earring2":"귀걸이2",
	"ring1":"반지1", "ring2":"반지2", "seal1":"인장1", "seal2":"인장2", "gaiters":"각반",
	"boots":"신발", "gloves":"장갑", "bracelet":"팔찌", "necklace":"목걸이", "badge":"휘장",
	"crystal":"수정", "catalyst":"카탈리스트", "rune":"룬"
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
	"화살":500,
	"총알":300,
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
	# Apply after resource import. A project-level custom_font is loaded before
	# first import on clean checkouts and would report a missing font loader.
	var korean_font := FontVariation.new()
	korean_font.base_font = load("res://assets/fonts/NotoSansKR.ttf") as Font
	korean_font.variation_opentype = {"wght":500.0}
	ThemeDB.get_default_theme().default_font = korean_font
	ThemeDB.fallback_font = korean_font
	rng.randomize()
	_load_data()
	ground_loot.configure(self)
	loot_pickup.configure(self, ground_loot)
	_connect_signals()
	_setup_collision_tileset()
	_setup_field_services()
	hud.refresh_maps(maps)
	hud.set_catalog_data(catalog_db, catalog_image_index)
	hud.set_job_data(job_classes, skills_db)
	_set_map(active_map_id, false)
	_load_game(true)
	_normalize_equipment_slots()
	_ensure_job_class_visual()
	_ensure_quickslots_seeded()
	_update_job_skillbar()
	_update_hud()
	hud.append_log("V20 · 모바일 MMORPG HUD / 전투 화면 개선")

func _process(delta: float) -> void:
	portal_cooldown = maxf(0.0, portal_cooldown - delta)
	auto_repath_timer = maxf(0.0, auto_repath_timer - delta)
	if player.auto_enabled and player.global_position.distance_squared_to(auto_last_position) < 1.0:
		auto_stuck_time += delta
	else:
		auto_stuck_time = 0.0
	auto_last_position = player.global_position
	_update_field_triggers()
	ground_loot.tick(delta)
	loot_pickup.tick(delta)
	auto_attack_timer = maxf(0.0, auto_attack_timer - delta)
	_tick_skill_buffs(delta)
	_tick_skill_cooldowns(delta)
	_advance_skill_charge(delta)
	_tick_item_buffs(delta)
	_tick_catalog_recovery(delta)
	_run_auto_buff_quickslots(delta)
	save_timer += delta
	if save_timer >= 30.0:
		save_timer = 0.0
		_save_game(true)
	if player.auto_enabled and not player.is_stunned() and charge_skill.is_empty():
		_run_auto_heal_quickslots()
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
		if field_map != null:
			_build_collision_debug_tiles()
		collision_tiles.visible = collision_debug
		hud.show_message("충돌 타일 표시 %s" % ("ON" if collision_debug else "OFF"))
	_update_target_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_set_click_destination(COORD.screen_to_world(get_viewport(), mouse_event.position))
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			# Android touch events carry real viewport coordinates. Mouse emulation is
			# disabled in project.godot, so get_global_mouse_position() may be stale.
			var world_touch_position: Vector2 = COORD.screen_to_world(get_viewport(), touch_event.position)
			_set_click_destination(world_touch_position)

func _load_data() -> void:
	var maps_text: String = FileAccess.get_file_as_string(MAPS_PATH)
	var maps_value: Variant = JSON.parse_string(maps_text)
	if maps_value is Array:
		maps = maps_value as Array
	# Replace only the Aden entry; preserve every existing map ID and data path.
	var field_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIELD_PATH))
	if field_value is Dictionary:
		var definition: Dictionary = field_value as Dictionary
		for index: int in range(maps.size()):
			if str(maps[index].get("id", "")) == str(definition["map_id"]):
				maps[index] = {"id":definition["map_id"],"name":definition["map_name"],"field_definition":definition,
					"width":int(definition["bounds"][2])/32,"height":int(definition["bounds"][3])/32,"tile_size_world":32}
	# Only lightweight metadata is resident for other regions. Load their geometry
	# when entering; do not retain 24 full worlds or their textures in the map menu.
	if FileAccess.file_exists(FIELD_INDEX_PATH):
		var field_index: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIELD_INDEX_PATH))
		if field_index is Array:
			for entry: Dictionary in field_index:
				for index: int in range(maps.size()):
					if str(maps[index].get("id", "")) == str(entry["map_id"]):
						maps[index] = {"id":entry["map_id"],"name":entry["map_name"],"field_path":entry["path"],
							"width":int(entry["bounds"][2])/32,"height":int(entry["bounds"][3])/32,"tile_size_world":32}
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
	_ensure_ammo_items()
	_enrich_weapon_records(item_db)
	loot_catalog = LOOT_DROP.build_catalog(item_db)
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if catalog_value is Dictionary:
		catalog_db = catalog_value as Dictionary
	var catalog_items_value: Variant = catalog_db.get("아이템", [])
	if catalog_items_value is Array:
		_enrich_weapon_records(catalog_items_value as Array)
	_merge_local_consumables_into_catalog()
	_load_verified_catalog_options()
	_index_item_weights()
	var image_index_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_IMAGE_INDEX_PATH))
	if image_index_value is Dictionary:
		catalog_image_index = image_index_value as Dictionary
	var directional_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTIONAL_PATH))
	if directional_value is Dictionary:
		directional_art = directional_value as Dictionary
	_build_job_classes()

func _verified_catalog_record(category: String, source_record: Dictionary) -> Dictionary:
	var category_values: Dictionary = verified_catalog_options.get(category, {}) as Dictionary
	var name_value: String = str(source_record.get("name", ""))
	var override_value: Variant = category_values.get(name_value, {})
	if not (override_value is Dictionary) or (override_value as Dictionary).is_empty():
		return source_record
	var override_entry: Dictionary = override_value as Dictionary
	var stats: Dictionary = override_entry.get("stats", {}) as Dictionary
	var merged: Dictionary = source_record.duplicate(true)
	for option: Variant in stats.keys():
		merged[str(option)] = stats[option]
	var runtime_description: String = str(override_entry.get("desc", source_record.get("desc", "")))
	if int(stats.get("mpRecoveryTick", 0)) > 0:
		runtime_description = runtime_description.replace(
			"MP 회복(틱) +%d" % int(stats.get("mpRecoveryTick", 0)), "MP 자동회복(30초) +5"
		)
	if int(stats.get("hpAbsoluteRecovery", 0)) > 0:
		runtime_description = runtime_description.replace(
			"HP 절대회복 +%d" % int(stats.get("hpAbsoluteRecovery", 0)), "HP 자동회복(30초) +5"
		)
	if bool(stats.get("hpAbsorption", false)):
		runtime_description = runtime_description.replace("HP 흡수", "HP 흡수(공격 적중마다 1~3)")
	merged["desc"] = runtime_description
	merged["reference_verified"] = true
	merged["reference_source"] = str(override_entry.get("source", ""))
	return merged

func _load_verified_catalog_options() -> void:
	var path: String = "res://data/lineagem_verified_base_options.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return
	verified_catalog_options = parsed as Dictionary
	# Modify only verified named base cards, not custom/generated content.
	# The old save-format card is independently corrected on read too.
	for category: String in ["마법인형", "성물"]:
		for source: Dictionary in [game_db, catalog_db]:
			var entries_value: Variant = source.get(category, [])
			if not (entries_value is Array):
				continue
			var entries: Array = entries_value as Array
			for index: int in range(entries.size()):
				if entries[index] is Dictionary:
					entries[index] = _verified_catalog_record(category, entries[index] as Dictionary)

func _has_hp_absorption() -> bool:
	for record: Dictionary in _all_equipped_records():
		if bool(record.get("hpAbsorption", record.get("hp_absorption", false))) or str(record.get("desc", "")).contains("HP 흡수"):
			return true
	return false

func _has_recovery_effect(key: String) -> bool:
	for record: Dictionary in _all_equipped_records():
		if int(record.get(key, 0)) > 0:
			return true
	return false

func _deal_successful_player_hit(target: TwilightMonster, normal_damage: int, critical: bool = false) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		return
	var stolen: int = 0
	if _has_hp_absorption():
		# Extra damage and healing represent the exact same amount of
		# HP stolen from the target, capped by its remaining HP.
		stolen = mini(rng.randi_range(1, 3), maxi(0, target.hp))
	if stolen > 0:
		var previous_hp: int = hp
		hp = mini(_effective_max_hp(), hp + stolen)
		hud.append_log("HP 흡수 · %s HP -%d / 내 HP +%d" % [target.monster_name, stolen, hp - previous_hp])
	target.take_damage(maxi(1, normal_damage) + stolen, critical)
	if stolen > 0:
		_update_hud()

func _tick_catalog_recovery(delta: float) -> void:
	var elapsed: float = maxf(0.0, delta)
	var hp_enabled: bool = _has_recovery_effect("hpAbsoluteRecovery") or _has_recovery_effect("hpRecoveryTick")
	var mp_enabled: bool = _has_recovery_effect("mpRecoveryTick")
	var changed: bool = false
	if hp_enabled:
		hp_recovery_elapsed += elapsed
		if hp_recovery_elapsed >= UNIQUE_RECOVERY_INTERVAL:
			var cycles: int = int(floor(hp_recovery_elapsed / UNIQUE_RECOVERY_INTERVAL))
			hp_recovery_elapsed = fmod(hp_recovery_elapsed, UNIQUE_RECOVERY_INTERVAL)
			var old_hp: int = hp
			hp = mini(_effective_max_hp(), hp + cycles * UNIQUE_RECOVERY_AMOUNT)
			if hp > old_hp:
				hud.append_log("HP 자동회복 · +%d" % (hp - old_hp))
				changed = true
	else:
		hp_recovery_elapsed = 0.0
	if mp_enabled:
		mp_recovery_elapsed += elapsed
		if mp_recovery_elapsed >= UNIQUE_RECOVERY_INTERVAL:
			var cycles: int = int(floor(mp_recovery_elapsed / UNIQUE_RECOVERY_INTERVAL))
			mp_recovery_elapsed = fmod(mp_recovery_elapsed, UNIQUE_RECOVERY_INTERVAL)
			var old_mp: int = mp
			mp = mini(_effective_max_mp(), mp + cycles * UNIQUE_RECOVERY_AMOUNT)
			if mp > old_mp:
				hud.append_log("MP 자동회복 · +%d" % (mp - old_mp))
				changed = true
	else:
		mp_recovery_elapsed = 0.0
	if changed:
		_update_hud()

func _catalog_stat_sum(key: String) -> int:
	var result: int = 0
	for category: String in ["변신", "마법인형", "성물"]:
		var record_value: Variant = equipped_catalog.get(category, {})
		if record_value is Dictionary and not (record_value as Dictionary).is_empty():
			var entry: Dictionary = _verified_catalog_record(category, record_value as Dictionary)
			result += int(entry.get(key, 0))
	return result

func _skill_cooldown_factor() -> float:
	return clampf(1.0 - float(_catalog_stat_sum("skillCooldownPct")) / 100.0, 0.1, 1.0)

func _effective_max_mp() -> int:
	return maxi(1, max_mp + _catalog_stat_sum("mpFlat"))

func _index_item_weights() -> void:
	item_weight_index.clear()
	var type_defaults: Dictionary = {}
	var overrides: Dictionary = {}
	var path: String = "res://data/item_weight_rules.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			type_defaults = (parsed as Dictionary).get("type_defaults", {}) as Dictionary
			overrides = (parsed as Dictionary).get("overrides", {}) as Dictionary
	for source: Variant in [catalog_db.get("아이템", []), item_db]:
		if not (source is Array):
			continue
		for entry: Variant in source as Array:
			if not (entry is Dictionary):
				continue
			var record: Dictionary = entry as Dictionary
			var name_value: String = str(record.get("name", ""))
			if name_value.is_empty():
				continue
			item_weight_index[name_value] = maxi(0, int(overrides.get(name_value, ITEM_OPTIONS.item_weight(record, type_defaults))))

func _inventory_total_weight() -> int:
	var total: int = 0
	for name_value: Variant in inventory.keys():
		total += maxi(0, int(inventory.get(name_value, 0))) * maxi(0, int(item_weight_index.get(str(name_value), 0)))
	return total

func _carrying_capacity() -> int:
	return ITEM_OPTIONS.carrying_capacity(_effective_attribute("CON")) + _catalog_stat_sum("weightBonus")

func _inventory_encumbrance_multiplier() -> float:
	return ITEM_OPTIONS.encumbrance_multiplier(_inventory_total_weight(), _carrying_capacity())

func _equipment_attribute_bonus(stat: String) -> int:
	var result: int = 0
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var entry: Variant = equipped_items.get(slot, {})
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			result += ITEM_OPTIONS.attribute(entry as Dictionary, stat)
	return result

func _effective_attribute(stat: String) -> int:
	var base: int = 0
	match stat:
		"STR": base = str_stat
		"DEX": base = dex_stat
		"CON": base = con_stat
		"INT": base = int_stat
		"WIS": base = wis_stat
		"CHA": base = cha_stat
		_: return 0
	return base + _equipment_attribute_bonus(stat)

func _equipment_accuracy_bonus(kind: String) -> int:
	var result: int = 0
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var entry: Variant = equipped_items.get(slot, {})
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			result += ITEM_OPTIONS.accuracy(entry as Dictionary, kind)
	return result

func _equipment_additional_damage(kind: String) -> int:
	var result: int = 0
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var entry: Variant = equipped_items.get(slot, {})
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			result += ITEM_OPTIONS.additional_damage(entry as Dictionary, kind)
	return result

func _weapon_size_adjustment(target: TwilightMonster) -> int:
	if target == null:
		return 0
	var label: String = str(target.get_meta("size_class", "")).to_lower()
	# Explicit size_class wins; old DB has no size and uses boss fallback.
	var large: bool = label == "large" or (label.is_empty() and target.is_boss)
	return ITEM_OPTIONS.weapon_size_adjustment(_equipped_weapon_record(), large)

func _ensure_ammo_items() -> void:
	var names: Dictionary = {}
	for value: Variant in item_db:
		if value is Dictionary:
			names[str((value as Dictionary).get("name", ""))] = true
	var ammo_records: Array[Dictionary] = [
		{"name":"화살", "grade":"일반", "type":"탄약", "slot":"consumable", "desc":"활 일반 공격 시 1개 소모"},
		{"name":"총알", "grade":"일반", "type":"탄약", "slot":"consumable", "desc":"라이플/핸드 캐넌 일반 공격 시 1개 소모"}
	]
	for record: Dictionary in ammo_records:
		var item_name: String = str(record.get("name", ""))
		if names.has(item_name):
			continue
		item_db.append(record.duplicate(true))
		names[item_name] = true
	game_db["아이템"] = item_db

func _weapon_grade_speed_bonus(grade: String) -> float:
	match grade:
		"유일": return 6.0
		"신화": return 5.0
		"전설": return 4.0
		"영웅": return 3.0
		"희귀": return 2.0
		"고급": return 1.0
		_: return 0.0

func _weapon_name_speed_variation(item_name: String) -> float:
	var signature: int = 0
	for index: int in range(item_name.length()):
		signature = (signature + item_name.unicode_at(index) * (index + 1)) % 10007
	return float(signature % 401) / 100.0

func _enrich_weapon_records(records: Array) -> void:
	for index: int in range(records.size()):
		var value: Variant = records[index]
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		if str(record.get("slot", "")).strip_edges().to_lower() != "weapon":
			continue
		var weapon_type: String = _normalized_weapon_type(str(record.get("type", "")))
		var intrinsic_speed: float = float(WEAPON_BASE_ATTACK_SPEED.get(weapon_type, 15.0))
		intrinsic_speed += _weapon_grade_speed_bonus(str(record.get("grade", "")))
		intrinsic_speed += _weapon_name_speed_variation(str(record.get("name", "")))
		record["weaponTypeKey"] = weapon_type
		record["attackKind"] = _weapon_attack_kind_from_type(weapon_type)
		record["attackRangeCells"] = _weapon_range_cells_from_type(weapon_type)
		record["ammo"] = _weapon_ammo_from_type(weapon_type)
		record["weaponAttackSpeed"] = intrinsic_speed
		var meta: String = "무기 공속 +%.2f%% · %s · 사거리 %d칸" % [
			intrinsic_speed,
			"원거리" if str(record["attackKind"]) == "ranged" else "근거리",
			int(record["attackRangeCells"])
		]
		if str(record["ammo"]) != "":
			meta += " · 탄약 %s" % str(record["ammo"])
		var desc: String = str(record.get("desc", ""))
		if desc.find("무기 공속 +") < 0:
			record["desc"] = meta if desc == "" else desc + " · " + meta
		records[index] = record

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
	combat_vfx = COMBAT_VFX.new()
	combat_vfx.name = "CombatVFX"
	combat_vfx.z_index = 12
	add_child(combat_vfx)
	combat_corpses = Node2D.new()
	combat_corpses.name = "CombatCorpses"
	combat_corpses.y_sort_enabled = true
	add_child(combat_corpses)
	combat_flights = COMBAT_FLIGHTS.new()
	combat_flights.name = "CombatFlights"
	combat_flights.z_index = 12
	add_child(combat_flights)
	player.attack_strike.connect(_release_player_attack)
	player.attack_cancelled.connect(_cancel_player_attack)
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
	hud.quickslot_pressed.connect(_on_quickslot_pressed)
	hud.quickslot_assignment_requested.connect(_on_quickslot_assignment_requested)
	hud.self_mode_changed.connect(_on_self_mode_changed)
	hud.shop_buy_requested.connect(_buy_shop_item)
	hud.inventory_item_activated.connect(_on_inventory_item_activated)
	hud.enhancement_requested.connect(_attempt_enhancement)

func _set_map(map_id: String, keep_position: bool) -> void:
	_clear_combat_actions()
	if not maps_by_id.has(map_id):
		return
	# Validate before releasing the current playable world.
	var requested_map: Dictionary = maps_by_id[map_id] as Dictionary
	var requested_field: Dictionary = requested_map.get("field_definition", {})
	if requested_map.has("field_path"):
		var loaded_field: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(requested_map["field_path"])))
		if not (loaded_field is Dictionary) or str(loaded_field.get("map_id", "")) != map_id:
			push_error("Invalid playable field: " + map_id)
			return
		requested_field = loaded_field as Dictionary
	field_population.configure(self, null)
	if is_instance_valid(return_gate):
		remove_child(return_gate)
		return_gate.queue_free()
	return_gate = null
	return_gate_position = Vector2.INF
	for old_node: Node in [field_renderer, field_physics]:
		if is_instance_valid(old_node):
			remove_child(old_node)
			old_node.queue_free()
	field_renderer = null
	field_physics = null
	field_map = null
	loot_pickup.map_changed()
	ground_loot.hide_map()
	active_map_id = map_id
	active_map = maps_by_id[map_id] as Dictionary
	tile_size = int(active_map.get("tile_size_world", 32))
	world_size = Vector2(float(int(active_map.get("width", 1)) * tile_size), float(int(active_map.get("height", 1)) * tile_size))
	player.camera.limit_left = 0
	player.camera.limit_top = 0
	player.camera.limit_right = maxi(1, int(world_size.x))
	player.camera.limit_bottom = maxi(1, int(world_size.y))
	_clear_monsters()
	pending_ground_pickup = null
	for shape: Node in map_collision.get_children():
		map_collision.remove_child(shape)
		shape.queue_free()
	if not requested_field.is_empty():
		field_map = FIELD_SCRIPT.new()
		field_map.configure(requested_field)
		astar = field_map.astar
		field_physics = field_map.build_physics(self)
		map_background.texture = null
		map_background.visible = false
		collision_tiles.clear()
		if collision_debug:
			_build_collision_debug_tiles()
		player.collision_mask = 4
		var settings: Dictionary = field_map.data["camera"]
		player.camera.zoom = Vector2.ONE * float(settings["zoom"])
		player.camera.position = COORD.array_vector(settings["offset"])
		player.camera.position_smoothing_speed = float(settings["follow_speed"])
	else:
		_build_astar()
		_build_static_collisions()
		_build_collision_debug_tiles()
		_apply_map_background()
		map_background.visible = true
		player.collision_mask = 3
		# Small legacy maps still fill the viewport at their existing dimensions.
		var fit_zoom: float = maxf(1.0,maxf(get_viewport_rect().size.x/world_size.x,get_viewport_rect().size.y/world_size.y))
		player.camera.zoom = Vector2.ONE * fit_zoom
		player.camera.position = Vector2(0,-32)
	if not keep_position or not _is_walkable_world(player.global_position):
		player.global_position = _spawn_position()
	player.velocity = Vector2.ZERO
	player.set_touch_vector(Vector2.ZERO)
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	player.clear_click_path()
	selected_monster = null
	auto_target = null
	hud.set_map_name(str(active_map.get("name", active_map_id)))
	hud.clear_target()
	if field_map != null:
		field_renderer = FIELD_RENDERER.new()
		field_renderer.name = "FieldRenderer"
		add_child(field_renderer)
		field_renderer.configure(field_map, player)
		field_population.configure(self, field_map)
	else:
		_spawn_monsters(9)
	field_minimap.configure(self, field_map)
	portal_cooldown = 2.0
	region_id = ""
	auto_repath_timer = 0.0
	ground_loot.activate(active_map_id)
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
	if field_map != null:
		if collision_debug:
			for y: int in range(field_map.height):
				for x: int in range(field_map.width):
					if astar.is_point_solid(Vector2i(x,y)):
						collision_tiles.set_cell(Vector2i(x,y),0,Vector2i.ZERO,0)
		return
	var width: int = int(active_map.get("width", 1))
	var height: int = int(active_map.get("height", 1))
	var collision: Array = active_map.get("collision", []) as Array
	for row: int in range(height):
		for column: int in range(width):
			var index: int = row * width + column
			if index < collision.size() and int(collision[index]) != 0:
				collision_tiles.set_cell(Vector2i(column, row), 0, Vector2i.ZERO, 0)

func _spawn_position() -> Vector2:
	if field_map != null:
		return field_map.cell_to_world(field_map.nearest_cell(COORD.array_vector(field_map.data["spawn_position"])))
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
	if field_map != null:
		return field_map.cell_to_world(cell)
	return Vector2((cell.x + 0.5) * tile_size, (cell.y + 0.5) * tile_size)

func _world_to_cell(position_value: Vector2) -> Vector2i:
	if field_map != null:
		return field_map.world_to_cell(position_value)
	return Vector2i(int(floor(position_value.x / tile_size)), int(floor(position_value.y / tile_size)))

func _is_walkable_world(position_value: Vector2) -> bool:
	if astar == null:
		return false
	var cell: Vector2i = _world_to_cell(position_value)
	if not astar.is_in_boundsv(cell):
		return false
	return not astar.is_point_solid(cell)

func find_world_path(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	if field_map != null:
		return field_map.path(from_position, to_position)
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
	loot_pickup.cancel()
	if field_map != null:
		for npc: Dictionary in field_map.data["npc_spawn"]:
			var npc_position: Vector2 = COORD.array_vector(npc["position"])
			if target.distance_to(npc_position) < 55 and player.global_position.distance_to(npc_position) < 190:
				if str(npc["role"]) == "shop":
					hud.open_shop()
				else:
					hud.show_message("왕의 길을 따라 동쪽으로: 초원 → 돌다리 → 황혼의 폐허" if str(field_map.data.get("map_id",""))=="aden_world" else str(field_map.data["map_name"])+" · 청록 이동진: 이전/다음 지역 · 아덴 귀환")
				return
	var path: PackedVector2Array = find_world_path(player.global_position, target)
	if path.size() > 0:
		player.set_auto_enabled(false)
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
	loot_pickup.cancel()
	ground_loot.clear_map(active_map_id)

func _magic_hit_chance(attacker_magic_accuracy: int, target_mr: int) -> float:
	var chance_percent: float = 75.0 + float(attacker_magic_accuracy - maxi(0, target_mr)) * 0.7
	return clampf(chance_percent / 100.0, 0.05, 0.95)

func _player_magic_hit_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _magic_hit_chance(_magic_accuracy_stat(), target.magic_resistance)

func _cast_bleed_skill(target: TwilightMonster, mp_cost: int = 6, power: int = 28, bleed_duration: float = 4.5, tick_damage: int = 9, tick_interval: float = 0.75, skill_name: String = "출혈 베기") -> bool:
	if not resolving_combat_action and not pending_attack.is_empty(): return false
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
	if not resolving_combat_action:
		mp = maxi(0, mp - mp_cost)
		_queue_player_attack(target, "melee", _cast_bleed_skill.bind(target, 0, power, bleed_duration, tick_damage, tick_interval, skill_name), _skill_motion_duration({}), false, 90.0)
		return true
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	if not resolving_combat_action: player.pulse_attack()
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
	_deal_successful_player_hit(target, damage, critical)
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
	if not resolving_combat_action and not pending_attack.is_empty(): return false
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
	if not resolving_combat_action:
		mp = maxi(0, mp - mp_cost)
		_queue_player_attack(target, "magic", _cast_poison_skill.bind(target, 0, poison_duration, tick_damage, tick_interval, skill_name), _skill_motion_duration({}), false, 300.0)
		return true
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	if not resolving_combat_action: player.pulse_attack()
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
	if not resolving_combat_action and not pending_attack.is_empty(): return false
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
	if not resolving_combat_action:
		mp = maxi(0, mp - mp_cost)
		_queue_player_attack(target, "magic", _cast_fear_skill.bind(target, 0, fear_duration, skill_name), _skill_motion_duration({}), false, 300.0)
		return true
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	if not resolving_combat_action: player.pulse_attack()
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
	if not resolving_combat_action and not pending_attack.is_empty(): return false
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
	if not resolving_combat_action:
		mp = maxi(0, mp - mp_cost)
		_queue_player_attack(target, "magic", _cast_hold_skill.bind(target, 0, hold_duration, skill_name), _skill_motion_duration({}), false, 280.0)
		return true
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	if not resolving_combat_action: player.pulse_attack()
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
	if not resolving_combat_action and not pending_attack.is_empty(): return false
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
	if not resolving_combat_action:
		mp = maxi(0, mp - mp_cost)
		_queue_player_attack(target, "magic", _cast_silence_skill.bind(target, 0, silence_duration, skill_name), _skill_motion_duration({}), false, 320.0)
		return true
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	if not resolving_combat_action: player.pulse_attack()
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
	if not resolving_combat_action and not pending_attack.is_empty(): return false
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
	if not resolving_combat_action:
		mp = maxi(0, mp - mp_cost)
		_queue_player_attack(target, "melee", _cast_stun_skill.bind(target, power, 0, stun_duration, skill_name), _skill_motion_duration({}), false, 90.0)
		return true
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	if not resolving_combat_action: player.pulse_attack()
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
	_deal_successful_player_hit(target, damage, critical)
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
	if not resolving_combat_action and not pending_attack.is_empty(): return false
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
	if not resolving_combat_action:
		mp = maxi(0, mp - mp_cost)
		_queue_player_attack(target, "magic", _cast_magic_attack.bind(target, power, 0, skill_name), _skill_motion_duration({}), false, 360.0)
		return true
	mp = maxi(0, mp - mp_cost)
	selected_monster = target
	if not resolving_combat_action: player.pulse_attack()
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
	_deal_successful_player_hit(target, damage, critical)
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
	if player.is_stunned() or player.is_feared() or not charge_skill.is_empty():
		return
	if auto_attack_timer > 0.0 or not pending_attack.is_empty():
		return
	var attack_kind: String = _current_attack_kind()
	var target: TwilightMonster = selected_monster
	var target_usable: bool = is_instance_valid(target) and not target.dead
	if target_usable:
		target_usable = _target_in_current_weapon_range(target)
	if target_usable:
		target_usable = _has_line_of_sight_world(player.global_position, target.global_position)
	if not target_usable:
		target = _nearest_visible_monster_in_weapon_range()
	if target == null:
		hud.show_message("무기 사거리 안에 보이는 대상이 없습니다")
		return
	if not _consume_weapon_ammo():
		auto_attack_timer = 1.0
		return
	selected_monster = target
	auto_attack_timer = _normal_attack_interval()
	_break_invisibility()
	_queue_player_attack(target, attack_kind, _resolve_normal_attack.bind(target, attack_kind), auto_attack_timer, true)

func _resolve_normal_attack(target: TwilightMonster, attack_kind: String) -> void:
	if not is_instance_valid(target) or target.dead: return
	var hit_chance: float = _normal_attack_hit_chance(target, attack_kind)
	if rng.randf() >= hit_chance:
		target.show_miss()
		var accuracy: int = _ranged_accuracy_stat() if attack_kind == "ranged" else _melee_accuracy_stat()
		hud.append_log("%s %s 공격 MISS · 명중 %d / AC %d / %.1f%%" % [
			target.monster_name,
			"원거리" if attack_kind == "ranged" else "근거리",
			accuracy, target.armor_class, hit_chance * 100.0
		])
		_update_target_hud()
		return
	var damage_stat: int = _ranged_normal_damage_stat() if attack_kind == "ranged" else _melee_damage_stat()
	var damage: int = maxi(1, damage_stat + _weapon_size_adjustment(target) + rng.randi_range(-6, 9))
	var critical_chance: float = _critical_chance(_player_critical_rate(attack_kind), target.critical_resistance)
	var critical: bool = rng.randf() < critical_chance
	if critical:
		damage = _critical_damage(damage)
	damage = _elemental_damage_to_monster(damage, _normal_attack_element(), target)
	_deal_successful_player_hit(target, damage, critical)
	_try_trigger_passives("on_hit", target)
	_try_extra_weapon_hit(target, damage, attack_kind)
	hud.append_log("%s에게 %d %s 피해%s · 사거리 %d칸 · 치명타 %.1f%%" % [
		target.monster_name, damage,
		"원거리" if attack_kind == "ranged" else "근거리",
		" CRITICAL" if critical else "",
		_current_attack_range_cells(),
		critical_chance * 100.0
	])
	_update_target_hud()

func _run_auto_hunt() -> void:
	if not pending_attack.is_empty(): return
	if player.is_stunned() or player.is_feared():
		player.clear_click_path()
		return
	if not charge_skill.is_empty():
		player.clear_click_path()
		return
	if _run_auto_ground_pickup():
		return
	if not is_instance_valid(auto_target) or auto_target.dead:
		auto_target = _nearest_reachable_monster(99999.0)
	if auto_target == null:
		selected_monster = null
		player.clear_click_path()
		return
	selected_monster = auto_target
	var can_see: bool = _has_line_of_sight_world(player.global_position, auto_target.global_position)
	# A registered, ready skill uses its own range even when the equipped weapon
	# cannot reach the monster. Offensive skills always precede normal attacks.
	if can_see and _run_auto_combat_quickslots():
		player.clear_click_path()
		return
	if _target_in_current_weapon_range(auto_target) and can_see:
		player.clear_click_path()
		if auto_attack_timer <= 0.0:
			_attack()
		return
	if player.is_held():
		player.clear_click_path()
		return
	if player.click_path.is_empty() or player.path_index >= player.click_path.size() or auto_repath_timer <= 0.0:
		auto_repath_timer = 0.65
		if auto_stuck_time > 2.0:
			auto_target = null
			player.clear_click_path()
			auto_stuck_time = 0.0
			return
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
	if field_map != null:
		return field_map.line_clear(from_position, to_position)
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
	_try_trigger_passives("on_kill", monster)
	if field_map != null:
		field_population.release(monster)
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
	if monster.get_parent() == monsters_root and is_instance_valid(combat_corpses):
		monster.reparent(combat_corpses, true)
	_update_hud()
	call_deferred("_ensure_monster_count")

func _ensure_monster_count() -> void:
	if field_map != null:
		return
	var alive: int = 0
	for child: Node in monsters_root.get_children():
		if child is TwilightMonster and not (child as TwilightMonster).dead:
			alive += 1
	if alive < 9:
		_spawn_monsters(9 - alive)


func _drop_grade_color(grade: String) -> Color:
	match grade:
		"고급":
			return Color("a8e080")
		"희귀":
			return Color("3b99ff")
		"영웅":
			return Color("ff5360")
		"전설":
			return Color("bd79ff")
		"신화":
			return Color("ffd450")
		"유일":
			return Color("4cf9cf")
		_:
			return Color("eeeeee")

func _spawn_ground_drop(item_name: String, world_position: Vector2, quantity: int = 1, source_batch: String = "") -> Button:
	return ground_loot.spawn(item_name, world_position, quantity, source_batch)

func _collect_ground_drop(drop: Button) -> bool:
	if player.is_stunned() or player.is_feared() or player.is_held(): return false
	var record: Dictionary = ground_loot.take(drop, player.global_position, GROUND_PICKUP_RADIUS)
	if record.is_empty(): return false
	var item_name: String = str(record["item_name"])
	var quantity: int = int(record["quantity"])
	inventory[item_name] = int(inventory.get(item_name, 0)) + quantity
	if pending_ground_pickup == drop: pending_ground_pickup = null
	hud.refresh_inventory(inventory)
	hud.append_log("%s ×%d 습득" % [item_name, quantity])
	hud.show_message("%s 획득" % item_name)
	_update_hud()
	return true

func _on_ground_drop_clicked(drop: Button) -> void:
	loot_pickup.select(drop)

func _tick_manual_ground_pickup() -> void:
	loot_pickup.tick(0.0)

func _run_auto_ground_pickup() -> bool:
	return loot_pickup.run_auto()

func _ground_drops_snapshot() -> Array:
	return ground_loot.snapshot()

func _restore_ground_drops(saved: Variant) -> void:
	loot_pickup.map_changed()
	ground_loot.restore(saved)

func _roll_drop(monster: TwilightMonster) -> void:
	if monster == null or not is_instance_valid(monster):
		return
	var earned: Array[String] = LOOT_DROP.roll(monster.drop_items, monster.is_boss, loot_catalog, rng)
	if earned.is_empty():
		return
	var batch_id: String = ground_loot.begin_hunt_batch()
	for index: int in range(earned.size()):
		var item_name: String = earned[index]
		_spawn_ground_drop(item_name, monster.global_position, 1, batch_id)
	hud.show_message("아이템 %d개가 바닥에 떨어졌습니다" % earned.size())


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
	var death_position: Vector2 = player.global_position
	var death_sprite: AnimatedSprite2D = player.transform_sprite if player.transform_active else player.class_sprite
	var death_texture: Texture2D = death_sprite.sprite_frames.get_frame_texture(death_sprite.animation, death_sprite.frame) if death_sprite.sprite_frames != null else null
	var death_scale: Vector2 = death_sprite.scale
	var death_offset: Vector2 = death_sprite.position
	_clear_combat_actions()
	if combat_vfx != null and death_texture != null:
		combat_vfx.death_pose(death_position, death_texture, death_scale, death_offset)
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
	if field_map != null and field_map.is_safe(player.global_position):
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
	var attack_element: String = ELEMENT_RULES.channel(attacker.attack_element)
	if attack_element != "physical":
		reduced = ELEMENT_RULES.damage_after_resistance(reduced, _player_element_resistance(attack_element))
	reduced = _pve_damage_after_item_buffs(reduced)
	hp = maxi(0, hp - reduced)
	if hp > 0:
		_try_active_counterattack(attacker, normalized_type, reduced)
	if attacker.dead:
		player.show_received_damage(reduced, critical, normalized_type, attacker.combat_hit_position())
		_update_hud()
		return
	if hp > 0:
		_try_trigger_passives("on_damaged", attacker)
	player.show_received_damage(reduced, critical, normalized_type, attacker.combat_hit_position())
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
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("아이템이 없습니다")
		return
	var kind: String = _scroll_kind(item_name)
	if kind != "":
		var candidates: Array = _enhancement_candidates(kind, _scroll_mode(item_name))
		hud.call("open_enhancement", item_name, candidates)
		return
	var record: Dictionary = _find_catalog_item_record(item_name)
	if record.is_empty():
		hud.show_message("아이템 DB에서 정보를 찾을 수 없습니다")
		return
	var equip_slot: String = _equipment_slot_base(record)
	if equip_slot != "":
		_equip_or_acquire_item(record, false)
		return
	if _is_timed_buff_item(record):
		_use_timed_item_buff(record)
		return
	if str(record.get("slot", "")) == "consumable" and int(record.get("heal", 0)) > 0:
		_use_healing_item(item_name, int(record.get("heal", 0)))
		return
	hud.show_message("이 아이템은 직접 사용할 수 없습니다")

func _first_number(text: String) -> int:
	var digits: String = ""
	for index: int in range(text.length()):
		var ch: String = text.substr(index, 1)
		if ch >= "0" and ch <= "9":
			digits += ch
		elif digits != "":
			break
	return int(digits) if digits != "" else 0

func _description_time_seconds(desc: String, label: String) -> float:
	for raw_segment: String in desc.split("·"):
		var segment: String = raw_segment.strip_edges()
		if not segment.begins_with(label):
			continue
		var tail: String = segment.trim_prefix(label).strip_edges()
		var amount: int = _first_number(tail)
		if amount <= 0:
			return 0.0
		if tail.find("시간") >= 0:
			return float(amount * 3600)
		if tail.find("분") >= 0:
			return float(amount * 60)
		return float(amount)
	return 0.0

func _timed_item_buff_from_record(record: Dictionary) -> Dictionary:
	var desc: String = str(record.get("desc", "")).strip_edges()
	var duration: float = _description_time_seconds(desc, "지속 시간")
	if duration <= 0.0:
		return {}
	var buff: Dictionary = {"remaining":duration, "duration":duration, "desc":desc}
	var cooldown: float = _description_time_seconds(desc, "쿨타임")
	if cooldown > 0.0:
		buff["cooldown"] = cooldown
	for raw_segment: String in desc.split("·"):
		var segment: String = raw_segment.strip_edges()
		var value: int = _first_number(segment)
		if value <= 0:
			continue
		if segment.begins_with("Max HP"):
			buff["hp_flat"] = value
		elif segment.begins_with("스턴 내성"):
			buff["stun_resistance"] = value
		elif segment.begins_with("PVE 대미지 리덕션"):
			buff["pve_damage_reduction"] = value
		elif segment.begins_with("PVP 대미지 리덕션"):
			buff["pvp_damage_reduction"] = value
		elif segment.begins_with("PVE 대미지 감소"):
			buff["pve_damage_reduction_pct"] = value
		elif segment.begins_with("PVP 대미지 감소"):
			buff["pvp_damage_reduction_pct"] = value
		elif segment.begins_with("대미지 리덕션"):
			buff["damage_reduction"] = value
		elif segment.begins_with("근거리 대미지"):
			buff["melee_damage"] = value
		elif segment.begins_with("원거리 대미지"):
			buff["ranged_damage"] = value
		elif segment.begins_with("SP"):
			buff["sp"] = value
		elif segment.begins_with("근거리 명중"):
			buff["melee_accuracy"] = value
		elif segment.begins_with("원거리 명중"):
			buff["ranged_accuracy"] = value
		elif segment.begins_with("마법 명중"):
			buff["magic_accuracy"] = value
		elif segment.begins_with("공격 속도"):
			buff["attack_speed"] = value
		elif segment.begins_with("이동 속도"):
			buff["move_speed"] = value
	return buff

func _is_timed_buff_item(record: Dictionary) -> bool:
	return not _timed_item_buff_from_record(record).is_empty()

func _active_item_buff_total(key: String) -> int:
	var total: int = 0
	for value: Variant in active_item_buffs.values():
		if value is Dictionary:
			total += int((value as Dictionary).get(key, 0))
	return total

func _format_seconds_short(seconds: float) -> String:
	var whole: int = maxi(0, int(ceil(seconds)))
	if whole >= 3600:
		return "%d시간 %d분" % [whole / 3600, (whole % 3600) / 60]
	if whole >= 60:
		return "%d분 %d초" % [whole / 60, whole % 60]
	return "%d초" % whole

func _use_timed_item_buff(record: Dictionary) -> bool:
	var item_name: String = str(record.get("name", ""))
	var buff: Dictionary = _timed_item_buff_from_record(record)
	if item_name == "" or buff.is_empty():
		return false
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("%s이(가) 없습니다" % item_name)
		return false
	var cooldown_left: float = float(item_use_cooldowns.get(item_name, 0.0))
	if cooldown_left > 0.0:
		hud.show_message("%s 재사용 대기 %s" % [item_name, _format_seconds_short(cooldown_left)])
		return false
	inventory[item_name] = int(inventory.get(item_name, 0)) - 1
	active_item_buffs[item_name] = buff
	var cooldown: float = float(buff.get("cooldown", 0.0))
	if cooldown > 0.0:
		item_use_cooldowns[item_name] = cooldown
	hp = mini(hp, _effective_max_hp())
	hud.refresh_inventory(inventory)
	hud.show_message("%s 사용 · %s" % [item_name, _format_seconds_short(float(buff.get("duration", 0.0)))])
	hud.append_log("%s 버프 활성화 · %s" % [item_name, str(record.get("desc", ""))])
	_update_hud()
	return true

func _tick_item_buffs(delta: float) -> void:
	var changed: bool = false
	var expired: Array[String] = []
	for key_value: Variant in active_item_buffs.keys():
		var key: String = str(key_value)
		var value: Variant = active_item_buffs.get(key, {})
		if not (value is Dictionary):
			expired.append(key)
			continue
		var buff: Dictionary = value as Dictionary
		buff["remaining"] = maxf(0.0, float(buff.get("remaining", 0.0)) - delta)
		active_item_buffs[key] = buff
		if float(buff.get("remaining", 0.0)) <= 0.0:
			expired.append(key)
	for key: String in expired:
		active_item_buffs.erase(key)
		changed = true
		hud.append_log("%s 버프 종료" % key)
	var cooldown_finished: Array[String] = []
	for key_value: Variant in item_use_cooldowns.keys():
		var key: String = str(key_value)
		var left: float = maxf(0.0, float(item_use_cooldowns.get(key, 0.0)) - delta)
		if left <= 0.0:
			cooldown_finished.append(key)
		else:
			item_use_cooldowns[key] = left
	for key: String in cooldown_finished:
		item_use_cooldowns.erase(key)
	if changed:
		hp = mini(hp, _effective_max_hp())
		_refresh_speed_modifiers()
		_update_hud()

func _combined_active_buffs() -> Dictionary:
	var result: Dictionary = active_skill_buffs.duplicate(true)
	for key_value: Variant in active_item_buffs.keys():
		var key: String = str(key_value)
		result[key] = active_item_buffs[key]
	return result

func _enhancement_kind_for_record(record: Dictionary) -> String:
	if record.is_empty():
		return ""
	var base_slot: String = _equipment_slot_base(record)
	if base_slot == "weapon":
		return "weapon"
	if ARMOR_EQUIPMENT_SLOTS.has(base_slot):
		return "armor"
	if ACCESSORY_EQUIPMENT_SLOTS.has(base_slot) or base_slot in ["ring", "earring", "seal"]:
		return "accessory"
	return ""

func _enhancement_candidates(kind: String, mode: String = "normal") -> Array:
	var result: Array = []
	var names: Array = inventory.keys()
	names.sort()
	for value: Variant in names:
		var item_name: String = str(value)
		if int(inventory.get(item_name, 0)) <= 0:
			continue
		var record: Dictionary = _find_catalog_item_record(item_name)
		if record.is_empty() or _enhancement_kind_for_record(record) != kind:
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
	var sources: Array = [catalog_db.get("아이템", []), item_db]
	for source_value: Variant in sources:
		if not (source_value is Array):
			continue
		for value: Variant in source_value as Array:
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
	for slot: String in EQUIPMENT_SLOT_ORDER:
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
	if target_record.is_empty() or _enhancement_kind_for_record(target_record) != kind:
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
	for slot: String in EQUIPMENT_SLOT_ORDER:
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
	for slot: String in EQUIPMENT_SLOT_ORDER:
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
	var record: Dictionary = _find_catalog_item_record(item_name)
	if record.is_empty():
		hud.show_message("아이템 DB에서 정보를 찾을 수 없습니다")
		return
	if _is_timed_buff_item(record):
		_use_timed_item_buff(record)
		return
	if str(record.get("slot", "")) == "consumable" and int(record.get("heal", 0)) > 0:
		_use_healing_item(item_name, int(record.get("heal", 0)))
		return
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
	var enhanced_heal: int = maxi(1, heal_amount + _catalog_stat_sum("potionHealFlat"))
	enhanced_heal += int(round(float(heal_amount) * float(_catalog_stat_sum("potionHealPct")) / 100.0))
	hp = mini(effective_max_hp, hp + maxi(1, enhanced_heal))
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
	loot_pickup.cancel()
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
	_refresh_speed_modifiers()
	hud.update_player(level, hp, _effective_max_hp(), mp, _effective_max_mp(), experience, exp_need, gold)
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
	character_state["max_mp"] = _effective_max_mp()
	character_state["attack"] = _effective_attack()
	character_state["defense"] = _effective_defense()
	character_state["equipped"] = equipped_catalog
	character_state["equipped_items"] = _equipped_items_snapshot()
	character_state["enhancement_levels"] = enhancement_levels
	character_state["gold"] = gold
	character_state["quest_kills"] = quest_kills
	character_state["quest_goal"] = QUEST_GOAL
	hud.set_character_state(character_state)
	if hud.has_method("set_quickslot_state"):
		hud.call("set_quickslot_state", quickslots, inventory, _combined_active_buffs(), self_mode_enabled)
	elif hud.has_method("set_quickslot_entries"):
		hud.call("set_quickslot_entries", quickslots)

func _save_game(quiet: bool) -> void:
	var data: Dictionary = {
		"map_id": active_map_id,
		"map_layout_revision": int(field_map.data.get("layout_revision", 0)) if field_map != null else 0,
		"position": [player.global_position.x, player.global_position.y],
		"level": level,
		"experience": experience,
		"exp_need": exp_need,
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"hp_recovery_elapsed": hp_recovery_elapsed,
		"mp_recovery_elapsed": mp_recovery_elapsed,
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
		"ground_drops": _ground_drops_snapshot(),
		"class_index": class_index,
		"job_class": job_class,
		"quickslots": quickslots,
		"self_mode_enabled": self_mode_enabled,
		"active_skill_buffs": active_skill_buffs,
		"skill_cooldowns": skill_cooldowns,
		"skill_global_cooldown": skill_global_cooldown,
		"active_item_buffs": active_item_buffs,
		"item_use_cooldowns": item_use_cooldowns,
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
	_clear_combat_actions()
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
	hp_recovery_elapsed = clampf(float(data.get("hp_recovery_elapsed", 0.0)), 0.0, UNIQUE_RECOVERY_INTERVAL)
	mp_recovery_elapsed = clampf(float(data.get("mp_recovery_elapsed", 0.0)), 0.0, UNIQUE_RECOVERY_INTERVAL)
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
	_ensure_inventory_ammo_defaults()
	class_index = clampi(int(data.get("class_index", class_index)), 0, 3)
	job_class = str(data.get("job_class", job_class))
	if not JOB_CLASS_ORDER.has(job_class):
		job_class = "기사"
	var quickslots_value: Variant = data.get("quickslots", quickslots)
	if quickslots_value is Array:
		quickslots = quickslots_value as Array
	self_mode_enabled = bool(data.get("self_mode_enabled", self_mode_enabled))
	var skill_buffs_value: Variant = data.get("active_skill_buffs", {})
	active_skill_buffs = skill_buffs_value as Dictionary if skill_buffs_value is Dictionary else {}
	var skill_cooldowns_value: Variant = data.get("skill_cooldowns", {})
	skill_cooldowns = skill_cooldowns_value as Dictionary if skill_cooldowns_value is Dictionary else {}
	skill_global_cooldown = maxf(0.0, float(data.get("skill_global_cooldown", 0.0)))
	var item_buffs_value: Variant = data.get("active_item_buffs", {})
	active_item_buffs = item_buffs_value as Dictionary if item_buffs_value is Dictionary else {}
	var item_cooldowns_value: Variant = data.get("item_use_cooldowns", {})
	item_use_cooldowns = item_cooldowns_value as Dictionary if item_cooldowns_value is Dictionary else {}
	_prune_active_skill_buffs_for_current_job()
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
	_normalize_equipment_slots()
	_enforce_weapon_class_compatibility(true)
	_enforce_shield_weapon_compatibility(true)
	_restore_equipped_visuals()
	player.set_skill_speed_multiplier(_active_skill_speed_multiplier())
	_refresh_skill_stealth_visual()
	hp = clampi(hp, 0, _effective_max_hp())
	mp = clampi(mp, 0, _effective_max_mp())
	var map_id: String = str(data.get("map_id", active_map_id))
	if not maps_by_id.has(map_id):
		map_id = active_map_id
	_set_map(map_id, false)
	_restore_ground_drops(data.get("ground_drops", []))
	var position_value: Variant = data.get("position", [])
	var compatible_layout: bool = field_map == null or int(data.get("map_layout_revision",0)) == int(field_map.data.get("layout_revision",1))
	if position_value is Array and compatible_layout:
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
	for job_name: String in JOB_CLASS_ORDER:
		var transform_record: Dictionary = {}
		for value: Variant in transforms:
			if not (value is Dictionary):
				continue
			var record: Dictionary = value as Dictionary
			if str(record.get("grade", "")) != "신화":
				continue
			var transform_name: String = str(record.get("name", ""))
			if transform_name.begins_with("신화-" + job_name):
				transform_record = record
				break
		if transform_record.is_empty():
			continue
		job_classes.append({
			"name": job_name,
			"transform_name": str(transform_record.get("name", "")),
			"image_path": str(transform_record.get("image_path", "")),
			"source_id": str(transform_record.get("sourceId", "")),
			"weapon": _job_weapon_text(job_name),
			"role": _job_role_from_skills(job_name),
			"primary_stat": str(JOB_PRIMARY_STAT.get(job_name, ""))
		})

func _job_weapon_text(job_name: String) -> String:
	var allowed_value: Variant = JOB_ALLOWED_WEAPONS.get(job_name, [])
	if not (allowed_value is Array):
		return "공용"
	var allowed: Array = allowed_value as Array
	var labels: PackedStringArray = PackedStringArray()
	for value: Variant in allowed:
		var weapon_type: String = str(value)
		if not labels.has(weapon_type):
			labels.append(weapon_type)
	return ", ".join(labels) if not labels.is_empty() else "공용"

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

func _job_role_from_skills(job_name: String) -> String:
	var attack_count: int = 0
	var heal_count: int = 0
	var buff_count: int = 0
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if str(skill.get("class", "")) != job_name:
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

func _job_profile(job_name: String) -> Dictionary:
	for value: Variant in job_classes:
		if value is Dictionary:
			var profile: Dictionary = value as Dictionary
			if str(profile.get("name", "")) == job_name:
				return profile
	return {}

func _job_transform_record(job_name: String) -> Dictionary:
	var profile: Dictionary = _job_profile(job_name)
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
	_refresh_speed_modifiers()

func _on_job_class_selected(job_name: String) -> void:
	if not JOB_CLASS_ORDER.has(job_name):
		return
	_clear_skill_charge()
	job_class = job_name
	var record: Dictionary = _job_transform_record(job_class)
	if not record.is_empty():
		equipped_catalog["변신"] = record.duplicate(true)
		_apply_transform_visual(record)
	_enforce_weapon_class_compatibility(false)
	_enforce_shield_weapon_compatibility(false)
	_prune_active_skill_buffs_for_current_job()
	_refresh_skill_stealth_visual()
	_refresh_speed_modifiers()
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
		if _is_passive_skill(skill):
			continue
		var effect: String = str(skill.get("effect", ""))
		if effect not in ["damage", "turnUndead", "charge", "heal", "atkBuff", "defBuff", "hpBuff", "speedBuff", "teleport", "invisibility", "stun", "silence", "poison", "bleed", "hold", "fear"]:
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
	_ensure_quickslots_seeded()
	if hud.has_method("set_job_skillbar"):
		hud.call("set_job_skillbar", _quickbar_job_skills())
	if hud.has_method("set_quickslot_state"):
		hud.call("set_quickslot_state", quickslots, inventory, _combined_active_buffs(), self_mode_enabled)

func _sanitize_quickslots_for_current_job() -> bool:
	_normalize_quickslots()
	var changed: bool = false
	for index: int in range(quickslots.size()):
		var value: Variant = quickslots[index]
		if not (value is Dictionary):
			quickslots[index] = {}
			changed = true
			continue
		var entry: Dictionary = value as Dictionary
		if entry.is_empty() or str(entry.get("kind", "")) != "skill":
			continue
		var skill_name: String = str(entry.get("id", ""))
		var skill: Dictionary = _skill_record(skill_name)
		if skill.is_empty() or _is_passive_skill(skill):
			quickslots[index] = {}
			changed = true
			continue
		var skill_class: String = str(skill.get("class", "공용"))
		if skill_class != "공용" and skill_class != job_class:
			quickslots[index] = {}
			changed = true
	return changed

func _prune_active_skill_buffs_for_current_job() -> bool:
	var changed: bool = false
	var remove_names: Array[String] = []
	for key_value: Variant in active_skill_buffs.keys():
		var skill_name: String = str(key_value)
		var skill: Dictionary = _skill_record(skill_name)
		if skill.is_empty() or _is_passive_skill(skill):
			remove_names.append(skill_name)
			continue
		var skill_class: String = str(skill.get("class", "공용"))
		if skill_class != "공용" and skill_class != job_class:
			remove_names.append(skill_name)
	for skill_name: String in remove_names:
		active_skill_buffs.erase(skill_name)
		changed = true
	if changed:
		hp = mini(hp, _effective_max_hp())
		player.set_skill_speed_multiplier(_active_skill_speed_multiplier())
		_refresh_speed_modifiers()
	return changed

func _normalize_quickslots() -> void:
	while quickslots.size() < 8:
		quickslots.append({})
	while quickslots.size() > 8:
		quickslots.pop_back()

func _ensure_quickslots_seeded() -> void:
	var sanitized_changed: bool = _sanitize_quickslots_for_current_job()
	var has_any: bool = false
	var skill_count: int = 0
	var item_count: int = 0
	for value: Variant in quickslots:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		if entry.is_empty():
			continue
		has_any = true
		if str(entry.get("kind", "")) == "skill":
			skill_count += 1
		elif str(entry.get("kind", "")) == "item":
			item_count += 1
	if not has_any:
		var defaults: Array = _quickbar_job_skills()
		var slot_index: int = 0
		for value: Variant in defaults:
			if slot_index >= 5:
				break
			if value is Dictionary:
				var skill: Dictionary = value as Dictionary
				quickslots[slot_index] = {"kind":"skill", "id":str(skill.get("name", ""))}
				slot_index += 1
		for item_name: String in ["HP 물약", "강력 HP 물약", "축복받은 HP 물약"]:
			if slot_index >= 8:
				break
			quickslots[slot_index] = {"kind":"item", "id":item_name}
			slot_index += 1
		return
	if not sanitized_changed and skill_count > 0:
		return
	# A class/passive migration may clear only skill entries while leaving item slots.
	# Legacy item-only quickbars also need current-job active skills restored.
	# Refill empty positions with valid active skills without overwriting user items.
	var defaults: Array = _quickbar_job_skills()
	for value: Variant in defaults:
		if skill_count >= 5:
			break
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		var skill_name: String = str(skill.get("name", ""))
		var already_present: bool = false
		for current_value: Variant in quickslots:
			if current_value is Dictionary:
				var current: Dictionary = current_value as Dictionary
				if str(current.get("kind", "")) == "skill" and str(current.get("id", "")) == skill_name:
					already_present = true
					break
		if already_present:
			continue
		for index: int in range(quickslots.size()):
			var current_value: Variant = quickslots[index]
			if current_value is Dictionary and (current_value as Dictionary).is_empty():
				quickslots[index] = {"kind":"skill", "id":skill_name}
				skill_count += 1
				break

func _on_quickslot_assignment_requested(slot_index: int, entry_kind: String, entry_id: String) -> void:
	if slot_index < 0 or slot_index >= 8:
		return
	_normalize_quickslots()
	var is_auto_skill: bool = entry_kind == "skill_auto"
	if entry_kind == "skill" or is_auto_skill:
		var skill: Dictionary = _skill_record(entry_id)
		if skill.is_empty():
			hud.show_message("등록할 스킬을 찾을 수 없습니다")
			return
		if _is_passive_skill(skill):
			hud.show_message("%s은(는) 패시브 스킬이라 퀵슬롯 등록이 필요 없습니다" % entry_id)
			return
		if is_auto_skill and not SKILL_RULES.can_auto_cast(skill):
			hud.show_message("%s은(는) 자동 공격/회복용 스킬이 아닙니다" % entry_id)
			return
		var skill_class: String = str(skill.get("class", "공용"))
		if skill_class != "공용" and skill_class != job_class:
			hud.show_message("%s 직업에서는 사용할 수 없는 스킬입니다" % job_class)
			return
	elif entry_kind == "item":
		if int(inventory.get(entry_id, 0)) <= 0:
			hud.show_message("보유하지 않은 아이템입니다")
			return
	else:
		return
	quickslots[slot_index] = {"kind":"skill" if is_auto_skill else entry_kind, "id":entry_id, "auto":is_auto_skill}
	_update_hud()
	_save_game(true)

func _on_quickslot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= quickslots.size():
		return
	var value: Variant = quickslots[slot_index]
	if not (value is Dictionary):
		return
	var entry: Dictionary = value as Dictionary
	if entry.is_empty():
		hud.show_message("빈 퀵슬롯입니다")
		return
	var kind: String = str(entry.get("kind", ""))
	var entry_id: String = str(entry.get("id", ""))
	if kind == "skill":
		_cast_job_skill(entry_id)
	elif kind == "item":
		_use_quickslot_item(entry_id)

func _use_quickslot_item(item_name: String) -> void:
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("%s이(가) 없습니다" % item_name)
		_update_hud()
		return
	var record: Dictionary = _find_catalog_item_record(item_name)
	if _scroll_kind(item_name) != "":
		_on_inventory_item_activated(item_name)
	elif not record.is_empty() and (_is_timed_buff_item(record) or str(record.get("slot", "")) == "consumable"):
		_use_quick_item(item_name)
	else:
		hud.show_message("DB 설명에 직접 사용 효과가 없는 아이템입니다")

func _on_self_mode_changed(enabled: bool) -> void:
	self_mode_enabled = enabled
	auto_buff_check_timer = 0.0
	_update_hud()
	_save_game(true)

func _skill_activation(skill: Dictionary) -> String:
	var activation: String = str(skill.get("activation", "")).strip_edges().to_lower()
	if activation == "passive" or activation == "active":
		return activation
	var effect: String = str(skill.get("effect", ""))
	if str(skill.get("type", "")) == "버프" and int(skill.get("mp", 0)) == 0 and not skill.has("duration") and effect in ["atkBuff", "defBuff", "hpBuff", "speedBuff"]:
		return "passive"
	return "active"

func _is_passive_skill(skill: Dictionary) -> bool:
	return SKILL_RULES.is_passive(skill)

func _skill_owned_for_current_job(skill: Dictionary) -> bool:
	var skill_class: String = str(skill.get("class", "공용"))
	return skill_class == "공용" or skill_class == job_class

func _passive_skill_total(key: String) -> int:
	var total: int = 0
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if not _is_passive_skill(skill) or not _skill_owned_for_current_job(skill) or SKILL_RULES.passive_trigger(skill) != "always":
			continue
		total += int(skill.get(key, 0))
	return total

func _passive_skill_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if not _is_passive_skill(skill) or not _skill_owned_for_current_job(skill) or SKILL_RULES.passive_trigger(skill) != "always":
			continue
		multiplier = maxf(multiplier, float(skill.get("speed", 1.0)))
	return multiplier

func _passive_skill_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for value: Variant in skills_db:
		if value is Dictionary:
			var skill: Dictionary = value as Dictionary
			if _is_passive_skill(skill) and _skill_owned_for_current_job(skill):
				names.append(str(skill.get("name", "")))
	return names

func _is_buff_skill(skill: Dictionary) -> bool:
	return not _is_passive_skill(skill) and SKILL_RULES.is_buff(SKILL_RULES.effect_kind(skill))

func _run_auto_buff_quickslots(delta: float) -> void:
	if self_mode_enabled:
		return
	auto_buff_check_timer = maxf(0.0, auto_buff_check_timer - delta)
	if auto_buff_check_timer > 0.0:
		return
	auto_buff_check_timer = 0.8
	if player.is_stunned() or player.is_feared() or player.is_silenced():
		return
	for value: Variant in quickslots:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		if str(entry.get("kind", "")) != "skill":
			continue
		var skill_name: String = str(entry.get("id", ""))
		if skill_name == "" or active_skill_buffs.has(skill_name):
			continue
		var skill: Dictionary = _skill_record(skill_name)
		if skill.is_empty() or not _is_buff_skill(skill) or not _skill_owned_for_current_job(skill):
			continue
		if not _skill_ready(skill):
			continue
		if _cast_job_skill(skill_name):
			break


func _tick_skill_cooldowns(delta: float) -> void:
	skill_global_cooldown = maxf(0.0, skill_global_cooldown - delta)
	var expired: Array[String] = []
	for key_value: Variant in skill_cooldowns.keys():
		var key: String = str(key_value)
		var remaining: float = maxf(0.0, float(skill_cooldowns.get(key, 0.0)) - delta)
		if remaining <= 0.0:
			expired.append(key)
		else:
			skill_cooldowns[key] = remaining
	for key: String in expired:
		skill_cooldowns.erase(key)

func _skill_ready(skill: Dictionary, announce: bool = false) -> bool:
	if not pending_attack.is_empty(): return false
	var skill_name: String = str(skill.get("name", ""))
	if _is_passive_skill(skill):
		if announce:
			hud.show_message("%s은(는) 상시 패시브입니다" % skill_name)
		return false
	if not _skill_owned_for_current_job(skill):
		if announce:
			hud.show_message("%s 직업에서 사용할 수 없는 스킬입니다" % job_class)
		return false
	if not SKILL_RULES.is_supported(SKILL_RULES.effect_kind(skill)):
		if announce:
			hud.show_message("%s · 효과 구현 전입니다" % skill_name)
		return false
	var required_value: Variant = skill.get("required_weapons", [])
	if required_value is Array and not (required_value as Array).is_empty():
		if not (required_value as Array).has(_current_weapon_type()):
			if announce:
				hud.show_message("%s · 현재 무기로 사용할 수 없는 스킬입니다" % skill_name)
			return false
	var required_ammo: int = maxi(0, int(skill.get("ammo_per_hit", 0))) * maxi(1, int(skill.get("hits", 1)))
	if required_ammo > 0 and int(inventory.get("화살", 0)) < required_ammo:
		if announce:
			hud.show_message("%s · 화살 %d개 필요" % [skill_name, required_ammo])
		return false
	if not charge_skill.is_empty() or player.is_stunned() or player.is_feared() or (player.is_silenced() and int(skill.get("mp", 0)) > 0):
		if announce:
			hud.show_message("현재 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if skill_global_cooldown > 0.0 or float(skill_cooldowns.get(skill_name, 0.0)) > 0.0:
		if announce:
			hud.show_message("%s 재사용 대기 %s" % [skill_name, _format_seconds_short(maxf(skill_global_cooldown, float(skill_cooldowns.get(skill_name, 0.0))))])
		return false
	if mp < maxi(0, int(skill.get("mp", 0))):
		if announce:
			hud.show_message("MP가 부족합니다")
		return false
	return true

func _start_skill_cooldown(skill: Dictionary) -> void:
	var name_value: String = str(skill.get("name", ""))
	var cooldown: float = SKILL_RULES.cooldown_seconds(skill) * _skill_cooldown_factor()
	if cooldown > 0.0:
		skill_cooldowns[name_value] = cooldown
	skill_global_cooldown = maxf(skill_global_cooldown, SKILL_RULES.global_cooldown_seconds(skill))

func _run_auto_heal_quickslots() -> void:
	for value: Variant in quickslots:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		if not bool(entry.get("auto", false)) or str(entry.get("kind", "")) != "skill":
			continue
		var skill: Dictionary = _skill_record(str(entry.get("id", "")))
		if skill.is_empty() or SKILL_RULES.effect_kind(skill) != "heal":
			continue
		if float(hp) / float(maxi(1, _effective_max_hp())) > SKILL_RULES.heal_threshold(skill):
			continue
		if _skill_ready(skill):
			_cast_job_skill(str(skill.get("name", "")))
			return

func _run_auto_combat_quickslots() -> bool:
	if not is_instance_valid(selected_monster) or selected_monster.dead:
		return false
	for value: Variant in quickslots:
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		if not bool(entry.get("auto", false)) or str(entry.get("kind", "")) != "skill":
			continue
		var skill_name: String = str(entry.get("id", ""))
		var skill: Dictionary = _skill_record(skill_name)
		if skill.is_empty() or not SKILL_RULES.can_auto_cast(skill) or SKILL_RULES.effect_kind(skill) == "heal":
			continue
		if not _skill_ready(skill):
			continue
		if player.global_position.distance_to(selected_monster.global_position) > SKILL_RULES.range_pixels(skill):
			continue
		if not _has_line_of_sight_world(player.global_position, selected_monster.global_position):
			continue
		if SKILL_RULES.effect_kind(skill) == "turnUndead" and not selected_monster.is_undead():
			continue
		if _cast_job_skill(skill_name):
			return true
	return false

func _cast_job_status_skill(skill: Dictionary) -> bool:
	var target: TwilightMonster = _skill_target(SKILL_RULES.range_pixels(skill))
	if target == null:
		hud.show_message("상태이상 대상이 없습니다")
		return false
	if not _spend_skill_mp(skill): return false
	_break_invisibility()
	_queue_player_attack(target, _skill_attack_kind(skill), _resolve_status_skill.bind(skill.duplicate(true), target), _skill_motion_duration(skill), false, SKILL_RULES.range_pixels(skill))
	return true

func _resolve_status_skill(skill: Dictionary, target: TwilightMonster) -> void:
	var cost: int = 0
	var skill_name: String = str(skill.get("name", ""))
	var duration: float = float(skill.get("duration", 2.5))
	match SKILL_RULES.effect_kind(skill):
		"stun":
			_cast_stun_skill(target, int(skill.get("power", 55)), cost, duration, skill_name)
		"silence":
			_cast_silence_skill(target, cost, duration, skill_name)
		"poison":
			_cast_poison_skill(target, cost, duration, int(skill.get("tick_damage", 12)), float(skill.get("tick_interval", 1.0)), skill_name)
		"bleed":
			_cast_bleed_skill(target, cost, int(skill.get("power", 28)), duration, int(skill.get("tick_damage", 9)), float(skill.get("tick_interval", 0.75)), skill_name)
		"hold":
			_cast_hold_skill(target, cost, duration, skill_name)
		"fear":
			_cast_fear_skill(target, cost, duration, skill_name)
	# Status resisted / attack missed still counts as a completed cast.


func _cast_job_invisibility_skill(skill: Dictionary) -> bool:
	if not _spend_skill_mp(skill):
		return false
	active_skill_buffs[str(skill.get("name", "은신"))] = {
		"remaining": maxf(1.0, float(skill.get("duration", 20.0))),
		"stealth": true
	}
	_refresh_skill_stealth_visual()
	hud.show_message("%s · 은신 활성화" % str(skill.get("name", "")))
	return true

func is_player_concealed() -> bool:
	for value: Variant in active_skill_buffs.values():
		if value is Dictionary and bool((value as Dictionary).get("stealth", false)):
			return true
	return false

func _refresh_skill_stealth_visual() -> void:
	if player != null:
		player.modulate.a = 0.5 if is_player_concealed() else 1.0

func _break_invisibility() -> void:
	if not is_player_concealed():
		return
	for key_value: Variant in active_skill_buffs.keys():
		var name_value: String = str(key_value)
		var value: Variant = active_skill_buffs.get(name_value, {})
		if value is Dictionary and bool((value as Dictionary).get("stealth", false)):
			active_skill_buffs.erase(name_value)
	_refresh_skill_stealth_visual()
	hud.append_log("공격으로 은신 해제")

func _try_trigger_passives(trigger_name: String, target: TwilightMonster) -> void:
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if not _is_passive_skill(skill) or not _skill_owned_for_current_job(skill):
			continue
		if SKILL_RULES.passive_trigger(skill) != trigger_name:
			continue
		var skill_name: String = str(skill.get("name", ""))
		if float(skill_cooldowns.get(skill_name, 0.0)) > 0.0 or rng.randf() >= SKILL_RULES.passive_proc_chance(skill):
			continue
		var proc_effect: String = str(skill.get("proc_effect", ""))
		match proc_effect:
			"damage":
				if target == null or not is_instance_valid(target) or target.dead:
					continue
				_deal_successful_player_hit(target, maxi(1, int(skill.get("power", 1))), false)
			"heal":
				if hp >= _effective_max_hp():
					continue
				hp = mini(_effective_max_hp(), hp + maxi(1, int(skill.get("heal", 1))))
			"atkBuff", "defBuff", "hpBuff", "speedBuff":
				active_skill_buffs[skill_name] = {
					"remaining": maxf(1.0, float(skill.get("duration", 5.0))),
					"atk": int(skill.get("atk", 0)),
					"def": int(skill.get("def", 0)),
					"hp": int(skill.get("hpFlat", 0)),
					"speed": float(skill.get("speed", 1.0))
				}
				player.set_skill_speed_multiplier(_active_skill_speed_multiplier())
			_:
				continue
		var cooldown: float = SKILL_RULES.cooldown_seconds(skill) * _skill_cooldown_factor()
		if cooldown > 0.0:
			skill_cooldowns[skill_name] = cooldown
		hud.append_log("%s 패시브 발동" % skill_name)

func _skill_record(skill_name: String) -> Dictionary:
	for value: Variant in skills_db:
		if value is Dictionary:
			var skill: Dictionary = value as Dictionary
			if str(skill.get("name", "")) == skill_name:
				return skill
	return {}

func _cast_job_skill(skill_name: String) -> bool:
	var skill: Dictionary = _skill_record(skill_name)
	if skill.is_empty():
		hud.show_message("스킬 정보를 찾을 수 없습니다")
		return false
	if not _skill_ready(skill, true):
		return false
	var effect: String = SKILL_RULES.effect_kind(skill)
	var success: bool = false
	match effect:
		"damage":
			success = _cast_job_damage_skill(skill)
		"turnUndead":
			success = _cast_job_turn_undead(skill)
		"charge":
			success = _cast_job_charge_skill(skill)
		"heal":
			success = _cast_job_heal_skill(skill)
		"atkBuff", "defBuff", "hpBuff", "speedBuff":
			success = _cast_job_buff_skill(skill)
		"teleport":
			success = _cast_job_teleport_skill(skill)
		"invisibility":
			success = _cast_job_invisibility_skill(skill)
		"stun", "silence", "poison", "bleed", "hold", "fear":
			success = _cast_job_status_skill(skill)
		_:
			hud.show_message("%s · 구현되지 않은 효과입니다" % skill_name)
			return false
	if success:
		_start_skill_cooldown(skill)
		if SKILL_RULES.has_target(effect):
			auto_attack_timer = maxf(auto_attack_timer, SKILL_RULES.global_cooldown_seconds(skill))
		_update_hud()
	return success

func _spend_skill_mp(skill: Dictionary) -> bool:
	var mp_cost: int = maxi(0, int(skill.get("mp", 0)))
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	mp -= mp_cost
	var required_ammo: int = maxi(0, int(skill.get("ammo_per_hit", 0))) * maxi(1, int(skill.get("hits", 1)))
	if required_ammo > 0:
		inventory["화살"] = int(inventory.get("화살", 0)) - required_ammo
	return true


func _try_active_counterattack(attacker: TwilightMonster, attack_kind: String, received_damage: int) -> bool:
	if attacker == null or not is_instance_valid(attacker) or attacker.dead or attack_kind != "melee" or hp <= 0:
		return false
	var chance: float = 0.0
	var multiplier: float = 0.0
	var counter_name: String = ""
	for key_value: Variant in active_skill_buffs.keys():
		var buff_value: Variant = active_skill_buffs.get(key_value, {})
		if not (buff_value is Dictionary):
			continue
		var buff: Dictionary = buff_value as Dictionary
		var rate: float = clampf(float(buff.get("counter_chance", 0.0)), 0.0, 1.0)
		if rate > chance:
			chance = rate
			multiplier = maxf(0.0, float(buff.get("counter_multiplier", 0.0)))
			counter_name = str(key_value)
	if chance <= 0.0 or multiplier <= 0.0 or rng.randf() >= chance:
		return false
	var reflected: int = maxi(1, int(round(float(maxi(1, received_damage)) * multiplier)))
	hud.append_log("%s 반격 발동 · %s에게 %d 피해" % [counter_name, attacker.monster_name, reflected])
	attacker.take_damage(reflected)
	return true


func _player_element_resistance(element_name: String) -> float:
	if ELEMENT_RULES.channel(element_name) == "physical":
		return 0.0
	var key: String = "element_resist_" + element_name
	var total: float = float(_active_skill_buff_total(key) + _passive_skill_total(key))
	for record: Dictionary in _all_equipped_records():
		total += float(record.get(key, 0.0))
	return clampf(total, -80.0, 85.0)

func _normal_attack_element() -> String:
	if _active_skill_buff_total("element_bonus_holy") > 0:
		return "holy"
	return ELEMENT_RULES.channel(str(_equipped_weapon_record().get("element", "physical")))

func _elemental_damage_to_monster(raw_damage: int, element_name: String, target: TwilightMonster) -> int:
	var channel: String = ELEMENT_RULES.channel(element_name)
	if channel == "physical" or target == null:
		return maxi(1, raw_damage)
	var bonus: float = float(_active_skill_buff_total("element_bonus_" + channel) + _passive_skill_total("element_bonus_" + channel))
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("element_bonus_" + channel, 0.0))
	var modified: int = ELEMENT_RULES.damage_with_bonus(raw_damage, bonus)
	if channel == "holy" and target.is_undead():
		modified = ELEMENT_RULES.damage_with_bonus(modified, float(_active_skill_buff_total("holy_vs_undead")))
	return ELEMENT_RULES.damage_after_resistance(modified, target.elemental_resistance_percent(channel))

func _try_extra_weapon_hit(target: TwilightMonster, initial_damage: int, attack_kind: String) -> void:
	if attack_kind != "melee" or target == null or not is_instance_valid(target) or target.dead:
		return
	var chance: float = 0.0
	var multiplier: float = 0.0
	for buff_name: Variant in active_skill_buffs.keys():
		var record: Dictionary = _skill_record(str(buff_name))
		if record.is_empty():
			continue
		var weapon_value: Variant = record.get("required_weapons", [])
		if weapon_value is Array and not (weapon_value as Array).is_empty() and not (weapon_value as Array).has(_current_weapon_type()):
			continue
		var value: Variant = active_skill_buffs.get(buff_name, {})
		if not (value is Dictionary):
			continue
		var buff: Dictionary = value as Dictionary
		if float(buff.get("double_chance", 0.0)) > chance:
			chance = float(buff.get("double_chance", 0.0))
			multiplier = float(buff.get("double_multiplier", 0.0))
	if chance <= 0.0 or multiplier <= 0.0 or rng.randf() >= chance:
		return
	var damage: int = maxi(1, int(round(float(initial_damage) * multiplier)))
	damage = _elemental_damage_to_monster(damage, _normal_attack_element(), target)
	_deal_successful_player_hit(target, damage)
	_try_trigger_passives("on_hit", target)
	hud.append_log("%s 추가타 +%d 피해" % [target.monster_name, damage])

func _cast_job_turn_undead(skill: Dictionary) -> bool:
	var target: TwilightMonster = _skill_target(SKILL_RULES.range_pixels(skill))
	if target == null:
		hud.show_message("시야 내 언데드 대상이 없습니다")
		return false
	if not target.is_undead():
		hud.show_message("턴 언데드는 언데드에게만 사용할 수 있습니다")
		return false
	if not _spend_skill_mp(skill):
		return false
	_break_invisibility()
	_queue_player_attack(target, "magic", _resolve_turn_undead.bind(skill.duplicate(true), target), _skill_motion_duration(skill), false, SKILL_RULES.range_pixels(skill))
	return true

func _resolve_turn_undead(skill: Dictionary, target: TwilightMonster) -> void:
	var chance: float = clampf(_player_magic_hit_chance(target) + float(skill.get("magic_hit_bonus", 0.0)), 0.05, 0.99)
	if rng.randf() >= chance:
		target.show_miss()
		hud.append_log("%s · %s 마법 명중 실패" % [str(skill.get("name", "")), target.monster_name])
	else:
		var target_name: String = target.monster_name
		hud.append_log("%s · %s 언데드 즉사!" % [str(skill.get("name", "")), target_name])
		_deal_successful_player_hit(target, target.hp, false)
	_update_target_hud()

func _clear_skill_charge() -> void:
	charge_route = PackedVector2Array()
	charge_route_index = 0
	charge_target = null
	charge_skill = {}

func _cast_job_charge_skill(skill: Dictionary) -> bool:
	if player.is_held():
		hud.show_message("이동 불가 상태에서는 돌진할 수 없습니다")
		return false
	var target: TwilightMonster = _skill_target(SKILL_RULES.range_pixels(skill))
	if target == null:
		hud.show_message("돌진 대상이 사거리 밖에 있습니다")
		return false
	var stop_distance: float = maxf(40.0, float(skill.get("charge_stop_distance", 52.0)))
	var source: Vector2 = player.global_position
	var distance: float = source.distance_to(target.global_position)
	if distance <= stop_distance + 32.0:
		if not _spend_skill_mp(skill):
			return false
		_break_invisibility()
		_queue_damage_skill(skill, target, 100.0)
		return true
	var path: PackedVector2Array = find_world_path(source, target.global_position)
	if path.is_empty():
		hud.show_message("돌진 경로를 찾을 수 없습니다")
		return false
	var planned: PackedVector2Array = PackedVector2Array()
	var previous: Vector2 = source
	var total_distance: float = 0.0
	var stopped_near_target: bool = false
	for waypoint: Vector2 in path:
		if previous.distance_to(waypoint) <= 2.0:
			continue
		var endpoint: Vector2 = waypoint
		var close_to_target: bool = waypoint.distance_to(target.global_position) <= stop_distance
		if close_to_target:
			var direction: Vector2 = (previous - target.global_position).normalized()
			if direction.length_squared() > 0.01:
				var before_target: Vector2 = target.global_position + direction * stop_distance
				if _is_walkable_world(before_target) and _has_line_of_sight_world(previous, before_target):
					endpoint = before_target
				else:
					endpoint = previous
		total_distance += previous.distance_to(endpoint)
		if total_distance > SKILL_RULES.range_pixels(skill) + 2.0:
			break
		if endpoint.distance_to(previous) > 2.0 and _is_walkable_world(endpoint):
			planned.append(endpoint)
		previous = endpoint
		if close_to_target:
			stopped_near_target = true
			break
	if not stopped_near_target or planned.is_empty() or previous.distance_to(target.global_position) > 100.0 or not _has_line_of_sight_world(previous, target.global_position):
		hud.show_message("장애물 때문에 안전하게 돌진할 수 없습니다")
		return false
	if not _spend_skill_mp(skill):
		return false
	_break_invisibility()
	player.clear_click_path()
	charge_route = planned
	charge_route_index = 0
	charge_target = target
	charge_skill = skill.duplicate(true)
	charge_speed = maxf(250.0, float(skill.get("charge_speed", 1150.0)))
	hud.append_log("%s · %s에게 돌진 시작" % [str(skill.get("name", "")), target.monster_name])
	return true

func _advance_skill_charge(delta: float) -> void:
	if charge_skill.is_empty():
		return
	if not is_instance_valid(charge_target) or charge_target.dead or player.is_stunned() or player.is_feared() or player.is_held():
		_clear_skill_charge()
		return
	var remaining: float = maxf(0.0, charge_speed * delta)
	var blocked: bool = false
	while remaining > 0.0 and charge_route_index < charge_route.size():
		var waypoint: Vector2 = charge_route[charge_route_index]
		var distance: float = player.global_position.distance_to(waypoint)
		if distance <= 1.0:
			charge_route_index += 1
			continue
		var step: float = minf(remaining, minf(10.0, distance))
		var next_position: Vector2 = player.global_position.move_toward(waypoint, step)
		if not _is_walkable_world(next_position):
			blocked = true
			break
		player.face_target(next_position)
		player.global_position = next_position
		remaining -= step
		if player.global_position.distance_to(waypoint) <= 1.0:
			charge_route_index += 1
	if blocked:
		hud.show_message("돌진 경로에 장애물이 있습니다")
		_clear_skill_charge()
		return
	if charge_route_index < charge_route.size():
		return
	var finished_skill: Dictionary = charge_skill
	var finished_target: TwilightMonster = charge_target
	_clear_skill_charge()
	if is_instance_valid(finished_target) and not finished_target.dead and player.global_position.distance_to(finished_target.global_position) <= 100.0 and _has_line_of_sight_world(player.global_position, finished_target.global_position):
		_queue_damage_skill(finished_skill, finished_target, 100.0)
	else:
		hud.append_log("%s · 돌진 대상 이탈로 공격 실패" % str(finished_skill.get("name", "")))

func _cast_job_damage_skill(skill: Dictionary) -> bool:
	var target: TwilightMonster = _skill_target(SKILL_RULES.range_pixels(skill))
	if target == null:
		hud.show_message("공격 대상이 없습니다")
		return false
	if not _spend_skill_mp(skill):
		return false
	_break_invisibility()
	_queue_damage_skill(skill, target, SKILL_RULES.range_pixels(skill))
	return true

func _apply_job_skill_damage(skill: Dictionary, target: TwilightMonster) -> void:
	if target == null or not is_instance_valid(target) or target.dead:
		return
	selected_monster = target
	var max_range: float = SKILL_RULES.range_pixels(skill)
	var skill_class: String = str(skill.get("class", "공용"))
	var requested_style: String = str(skill.get("attack_style", ""))
	var ranged_style: bool = requested_style == "ranged" or (requested_style == "" and (job_class == "요정" or job_class == "총사"))
	var magic_style: bool = requested_style == "magic" or (requested_style == "" and (job_class == "마법사" or skill_class == "마법사" or (skill_class == "공용" and max_range >= 250.0)))
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
	var hits: int = clampi(int(skill.get("hits", 1)), 1, 8)
	var targets: Array[TwilightMonster] = [target]
	var area_radius: float = maxf(0.0, float(skill.get("area_radius", 0.0)))
	if area_radius > 0.0 and is_instance_valid(combat_vfx):
		combat_vfx.ring(target.combat_hit_position(), area_radius, Color(0.4, 0.65, 1.0))
	if area_radius > 0.0:
		for child: Node in monsters_root.get_children():
			if child is TwilightMonster:
				var other: TwilightMonster = child as TwilightMonster
				if other != target and not other.dead and target.global_position.distance_to(other.global_position) <= area_radius and _has_line_of_sight_world(player.global_position, other.global_position):
					targets.append(other)
	var chain_limit: int = clampi(int(skill.get("chain_targets", 1)), 1, 8)
	if chain_limit > 1:
		var chain_candidates: Array[TwilightMonster] = []
		var chain_radius: float = maxf(10.0, float(skill.get("chain_radius", 140.0)))
		for child: Node in monsters_root.get_children():
			if child is TwilightMonster:
				var other: TwilightMonster = child as TwilightMonster
				if other != target and not other.dead and target.global_position.distance_to(other.global_position) <= chain_radius and _has_line_of_sight_world(player.global_position, other.global_position):
					chain_candidates.append(other)
		chain_candidates.sort_custom(func(a: TwilightMonster, b: TwilightMonster) -> bool:
			return target.global_position.distance_squared_to(a.global_position) < target.global_position.distance_squared_to(b.global_position)
		)
		for candidate: TwilightMonster in chain_candidates:
			if targets.size() >= chain_limit:
				break
			if not targets.has(candidate):
				targets.append(candidate)
	var power: int = maxi(1, int(skill.get("power", 20)))
	var volley: Dictionary = skill.get("_volley_runtime", {})
	var total_damage: int = int(volley.get("total_damage", 0))
	if total_damage <= 0:
		total_damage = maxi(1, power + stat_damage + rng.randi_range(-4, 6))
		volley["total_damage"] = total_damage
	var element_name: String = ELEMENT_RULES.channel(str(skill.get("element", "physical")))
	var style: String = "magic" if magic_style else ("ranged" if ranged_style else "melee")
	var chain_index: int = 0
	for victim: TwilightMonster in targets:
		var victim_hit_chance: float = hit_chance
		if magic_style:
			victim_hit_chance = _player_magic_hit_chance(victim)
		elif ranged_style:
			victim_hit_chance = clampf(_melee_hit_chance(victim) + float(_ranged_accuracy_stat() - _melee_accuracy_stat()) * 0.01, 0.10, 0.95)
		else:
			victim_hit_chance = _melee_hit_chance(victim)
		var first_hit: int = int(skill.get("_single_hit_index", 0))
		var last_hit: int = first_hit + 1 if skill.has("_single_hit_index") else hits
		for hit_index: int in range(first_hit, last_hit):
			if victim.dead:
				break
			if rng.randf() >= victim_hit_chance:
				victim.show_miss()
				hud.append_log("%s · %d/%d타 MISS" % [str(skill.get("name", "")), hit_index + 1, hits])
				continue
			var chain_factor: float = pow(clampf(float(skill.get("chain_falloff", 1.0)), 0.2, 1.0), chain_index) if chain_limit > 1 else 1.0
			var execute_factor: float = maxf(1.0, float(skill.get("execute_multiplier", 1.0))) if float(victim.hp) / maxf(1.0, float(victim.max_hp)) <= float(skill.get("execute_threshold", 0.0)) else 1.0
			var damage: int = maxi(1, int(ceil(float(total_damage) / float(hits) * chain_factor * execute_factor)))
			var critical: bool = rng.randf() < _critical_chance(crit_rate, victim.critical_resistance)
			if critical:
				damage = _critical_damage(damage)
			damage = _elemental_damage_to_monster(damage, element_name, victim)
			_deal_successful_player_hit(victim, damage, critical)
			_try_trigger_passives("on_hit", victim)
			_try_extra_weapon_hit(victim, damage, style)
			if not victim.dead and rng.randf() < clampf(float(skill.get("status_chance", 0.0)), 0.0, 1.0):
				match str(skill.get("on_hit_status", "")):
					"slow":
						victim.apply_slow(float(skill.get("status_duration", 3.0)), float(skill.get("slow_multiplier", 0.65)))
					"hold":
						victim.apply_hold(float(skill.get("status_duration", 2.0)))
					"poison":
						victim.apply_poison(float(skill.get("status_duration", 4.0)), maxi(1, int(skill.get("poison_tick_damage", 10))), 1.0)
			hud.append_log("%s · %s %d/%d타 %d 피해%s" % [
				str(skill.get("name", "")), victim.monster_name, hit_index + 1, hits, damage, " CRITICAL" if critical else ""
			])
		chain_index += 1
	_update_target_hud()

func _cast_job_heal_skill(skill: Dictionary) -> bool:
	if hp >= _effective_max_hp():
		hud.show_message("HP가 가득 찼습니다")
		return false
	if not _spend_skill_mp(skill):
		return false
	var base_amount: int = int(skill.get("heal", 40)) + (int_stat + _active_skill_buff_total("intFlat")) * 2
	var amount: int = maxi(1, int(round(float(base_amount) * (1.0 + float(skill.get("heal_bonus_percent", 0.0)) / 100.0))))
	if bool(skill.get("heal_to_full", false)):
		amount = _effective_max_hp()
	var before: int = hp
	hp = mini(_effective_max_hp(), hp + amount)
	hud.show_message("%s · HP +%d" % [str(skill.get("name", "")), hp - before])
	hud.append_log("%s 회복 · HP +%d" % [str(skill.get("name", "")), hp - before])
	return true

func _cast_job_buff_skill(skill: Dictionary) -> bool:
	if not _spend_skill_mp(skill):
		return false
	var duration: float = maxf(5.0, float(skill.get("duration", 60.0)))
	var speed_value: float = float(skill.get("speed", 1.0))
	active_skill_buffs[str(skill.get("name", "버프"))] = {
		"remaining": duration,
		"atk": int(skill.get("atk", 0)),
		"def": int(skill.get("def", 0)),
		"hp": int(skill.get("hpFlat", 0)),
		"speed": speed_value,
		"ranged_bonus": int(skill.get("ranged_bonus", 0)),
		"ranged_accuracy": int(skill.get("ranged_accuracy", 0)),
		"strFlat": int(skill.get("strFlat", 0)),
		"dexFlat": int(skill.get("dexFlat", 0)),
		"intFlat": int(skill.get("intFlat", 0)),
		"mrFlat": int(skill.get("mrFlat", 0)),
		"element_bonus_holy": int(skill.get("element_bonus_holy", 0)),
		"element_bonus_wind": int(skill.get("element_bonus_wind", 0)),
		"element_resist_dark": int(skill.get("element_resist_dark", 0)),
		"element_resist_lightning": int(skill.get("element_resist_lightning", 0)),
		"holy_vs_undead": int(skill.get("holy_vs_undead", 0)),
		"double_chance": float(skill.get("double_chance", 0.0)),
		"double_multiplier": float(skill.get("double_multiplier", 0.0)),
		"damage_reduction": int(skill.get("damage_reduction", 0)),
		"counter_chance": clampf(float(skill.get("counter_chance", 0.0)), 0.0, 1.0),
		"counter_multiplier": maxf(0.0, float(skill.get("counter_multiplier", 0.0)))
	}
	player.set_skill_speed_multiplier(_active_skill_speed_multiplier())
	hp = mini(_effective_max_hp(), hp + maxi(0, int(skill.get("hpFlat", 0))))
	hud.show_message("%s 활성화" % str(skill.get("name", "")))
	hud.append_log("%s 버프 · %.0f초" % [str(skill.get("name", "")), duration])
	return true

func _teleport_landing_clear(candidate: Vector2) -> bool:
	if not _is_walkable_world(candidate):
		return false
	for child: Node in monsters_root.get_children():
		if child is TwilightMonster:
			var monster: TwilightMonster = child as TwilightMonster
			if not monster.dead and candidate.distance_to(monster.global_position) < 155.0:
				return false
	return true

func _cast_job_teleport_skill(skill: Dictionary) -> bool:
	for _attempt: int in range(100):
		var candidate: Vector2 = player.global_position + Vector2(rng.randf_range(-700.0, 700.0), rng.randf_range(-500.0, 500.0))
		var safe_only: bool = bool(skill.get("safe_zone_only", false))
		if _teleport_landing_clear(candidate) if safe_only else _is_walkable_world(candidate):
			if not _spend_skill_mp(skill):
				return false
			player.global_position = candidate
			player.clear_click_path()
			player.camera.reset_smoothing()
			hud.show_message("%s" % str(skill.get("name", "텔레포트")))
			return true
	hud.show_message("안전하게 이동할 위치를 찾지 못했습니다")
	return false

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
	_refresh_skill_stealth_visual()
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
	if category == "마법인형" or category == "성물":
		hp_recovery_elapsed = 0.0
		mp_recovery_elapsed = 0.0
	if category == "변신":
		_apply_transform_visual(record)
	elif category == "마법인형":
		_apply_doll_visual(record)
	elif category == "성물":
		_apply_relic_visual(record)
	_refresh_speed_modifiers()
	var new_max_hp: int = _effective_max_hp()
	if new_max_hp > old_max_hp:
		hp += new_max_hp - old_max_hp
	hp = mini(hp, new_max_hp)
	mp = mini(mp, _effective_max_mp())
	hud.show_message("%s 장착: %s" % [category, str(record.get("name", ""))])
	hud.append_log("%s 적용 · %s" % [category, str(record.get("name", ""))])
	_update_hud()

func _equip_or_acquire_item(record: Dictionary, add_to_inventory: bool = true) -> void:
	var item_name: String = str(record.get("name", "아이템"))
	if add_to_inventory:
		inventory[item_name] = int(inventory.get(item_name, 0)) + 1
	var source_slot: String = str(record.get("slot", ""))
	if source_slot == "weapon" and not _weapon_allowed_for_job(record, job_class):
		var weapon_type: String = _normalized_weapon_type(str(record.get("type", "")))
		hud.show_message("%s 클래스는 %s 무기를 착용할 수 없습니다" % [job_class, weapon_type])
		hud.append_log("착용 제한 · %s / %s · 아이템은 인벤토리에 보관" % [job_class, item_name])
		hud.refresh_inventory(inventory)
		_update_hud()
		return
	var equip_slot: String = _equipment_slot_for_record(record)
	if _is_offhand_record(record):
		equip_slot = "offhand"
		if not _can_equip_offhand(record):
			hud.show_message("%s 무기에는 방패를 착용할 수 없습니다" % _current_weapon_type())
			hud.append_log("방패 착용 불가 · %s + %s" % [_current_weapon_type(), item_name])
			hud.refresh_inventory(inventory)
		_update_hud()
		return
	if equip_slot != "" and EQUIPMENT_SLOT_ORDER.has(equip_slot):
		var old_max_hp: int = _effective_max_hp()
		equipped_items[equip_slot] = record.duplicate(true)
		if equip_slot == "weapon":
			_enforce_shield_weapon_compatibility(false)
		_refresh_speed_modifiers()
		var new_max_hp: int = _effective_max_hp()
		if new_max_hp > old_max_hp:
			hp += new_max_hp - old_max_hp
		hp = mini(hp, new_max_hp)
		var slot_label: String = str(EQUIPMENT_SLOT_LABELS.get(equip_slot, equip_slot))
		hud.show_message("%s 장착: %s" % [slot_label, item_name])
		hud.append_log("%s 슬롯 장착 · %s" % [slot_label, item_name])
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
	player.set_transform_visual(path, speed_multiplier, ANIMATION_CATALOG.for_record("transform", record, path))

func _apply_doll_visual(record: Dictionary) -> void:
	doll_motion.configure(record, _directional_image_path("doll", record), $Companion, companion_sprite, player)

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
	relic_motion.configure(record, relic_sprite, player, _drop_grade_color(str(record.get("grade", "일반"))))

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
	_refresh_speed_modifiers()

func _all_equipped_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			records.append(_verified_catalog_record(category, value as Dictionary))
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var item_value: Variant = equipped_items.get(slot, {})
		if item_value is Dictionary and not (item_value as Dictionary).is_empty():
			records.append(item_value as Dictionary)
	return records

func _normalized_weapon_type(raw_type: String) -> String:
	var value: String = raw_type.strip_edges()
	if WEAPON_TYPE_ALIASES.has(value):
		return str(WEAPON_TYPE_ALIASES[value])
	return value

func _weapon_attack_kind_from_type(weapon_type: String) -> String:
	return "ranged" if weapon_type in ["활", "라이플", "핸드캐넌"] else "melee"

func _weapon_range_cells_from_type(weapon_type: String) -> int:
	match weapon_type:
		"사이드", "창":
			return 3
		"체인소드":
			return 5
		"라이플", "핸드캐넌":
			return 8
		"활":
			return 10
		_:
			return 1

func _weapon_ammo_from_type(weapon_type: String) -> String:
	if weapon_type == "활":
		return "화살"
	if weapon_type in ["라이플", "핸드캐넌"]:
		return "총알"
	return ""

func _equipment_slot_base(record: Dictionary) -> String:
	if record.is_empty():
		return ""
	var item_type: String = str(record.get("type", "")).strip_edges()
	var source_slot: String = str(record.get("slot", "")).strip_edges().to_lower()
	if source_slot == "weapon":
		return "weapon"
	match item_type:
		"방패", "가더", "방패/가더":
			return "offhand"
		"투구":
			return "helmet"
		"티셔츠":
			return "tshirt"
		"갑옷":
			return "body"
		"하의":
			return "pants"
		"망토":
			return "cloak"
		"견갑":
			return "shoulder"
		"벨트":
			return "belt"
		"귀걸이":
			return "earring"
		"반지":
			return "ring"
		"인장":
			return "seal"
		"각반":
			return "gaiters"
		"신발":
			return "boots"
		"장갑":
			return "gloves"
		"팔찌":
			return "bracelet"
		"목걸이":
			return "necklace"
		"휘장":
			return "badge"
		"수정":
			return "crystal"
		"카탈리스트":
			return "catalyst"
		"룬":
			return "rune"
	match source_slot:
		"offhand": return "offhand"
		"helmet": return "helmet"
		"tshirt": return "tshirt"
		"body": return "body"
		"pants": return "pants"
		"cloak": return "cloak"
		"shoulder": return "shoulder"
		"gaiters": return "gaiters"
		"boots": return "boots"
		"gloves": return "gloves"
		"ring": return "ring"
		"earring": return "earring"
		"belt": return "belt"
		"bracelet": return "bracelet"
		"badge": return "badge"
		"seal": return "seal"
		"crystal": return "crystal"
		"catalyst": return "catalyst"
		"rune": return "rune"
		"necklace": return "necklace"
		"armor": return "body"
		"accessory": return "necklace"
	return ""

func _choose_multi_equipment_slot(base_slot: String, container: Dictionary = {}) -> String:
	var source: Dictionary = equipped_items if container.is_empty() else container
	var options: Array[String] = []
	match base_slot:
		"earring": options = ["earring1", "earring2"]
		"ring": options = ["ring1", "ring2"]
		"seal": options = ["seal1", "seal2"]
		_: return base_slot
	for slot_name: String in options:
		var value: Variant = source.get(slot_name, {})
		if not (value is Dictionary) or (value as Dictionary).is_empty():
			return slot_name
	return options[0]

func _equipment_slot_for_record(record: Dictionary) -> String:
	return _choose_multi_equipment_slot(_equipment_slot_base(record))

func _empty_equipment_slots() -> Dictionary:
	var result: Dictionary = {}
	for slot_name: String in EQUIPMENT_SLOT_ORDER:
		result[slot_name] = {}
	return result

func _place_migrated_equipment(container: Dictionary, record: Dictionary, preferred_slot: String = "") -> void:
	if record.is_empty():
		return
	var target_slot: String = preferred_slot if EQUIPMENT_SLOT_ORDER.has(preferred_slot) else ""
	if target_slot == "":
		var base_slot: String = _equipment_slot_base(record)
		target_slot = _choose_multi_equipment_slot(base_slot, container)
	if target_slot == "" or not EQUIPMENT_SLOT_ORDER.has(target_slot):
		return
	var current: Variant = container.get(target_slot, {})
	if current is Dictionary and not (current as Dictionary).is_empty():
		var base_slot: String = _equipment_slot_base(record)
		if base_slot in ["earring", "ring", "seal"]:
			target_slot = _choose_multi_equipment_slot(base_slot, container)
	container[target_slot] = record.duplicate(true)

func _normalize_equipment_slots() -> void:
	var old_items: Dictionary = equipped_items
	var normalized: Dictionary = _empty_equipment_slots()
	for slot_name: String in EQUIPMENT_SLOT_ORDER:
		var direct_value: Variant = old_items.get(slot_name, {})
		if direct_value is Dictionary and not (direct_value as Dictionary).is_empty():
			normalized[slot_name] = (direct_value as Dictionary).duplicate(true)
	for legacy_slot: String in ["shield", "armor", "accessory", "earring", "ring", "seal"]:
		var legacy_value: Variant = old_items.get(legacy_slot, {})
		if legacy_value is Dictionary and not (legacy_value as Dictionary).is_empty():
			_place_migrated_equipment(normalized, legacy_value as Dictionary)
	equipped_items = normalized

func _equipment_enhancement_total(slots: Array[String]) -> int:
	var total: int = 0
	for slot_name: String in slots:
		total += _equipment_enhancement_level(slot_name)
	return total

func _equipment_enhancement_max(slots: Array[String]) -> int:
	var highest: int = 0
	for slot_name: String in slots:
		highest = maxi(highest, _equipment_enhancement_level(slot_name))
	return highest

func _offhand_kind(record: Dictionary) -> String:
	if record.is_empty():
		return ""
	var item_type: String = str(record.get("type", "")).strip_edges()
	var item_name: String = str(record.get("name", "")).strip_edges()
	if item_type == "가더" or item_name.find("가더") >= 0:
		return "guarder"
	if item_type == "방패" or item_name.find("방패") >= 0 or item_name.find("실드") >= 0 or item_name.find("쉴드") >= 0:
		return "shield"
	if item_type == "방패/가더":
		# The catalog groups shields, guarders and class-specific offhands together.
		# Only items whose names are clearly shields should inherit shield restrictions.
		return "offhand"
	return ""

func _is_offhand_record(record: Dictionary) -> bool:
	return _offhand_kind(record) != ""

func _weapon_supports_shield(record: Dictionary) -> bool:
	if record.is_empty():
		return true
	return SHIELD_COMPATIBLE_WEAPONS.has(_normalized_weapon_type(str(record.get("type", ""))))

func _current_weapon_supports_shield() -> bool:
	return _weapon_supports_shield(_equipped_weapon_record())

func _can_equip_offhand(record: Dictionary) -> bool:
	var kind: String = _offhand_kind(record)
	if kind == "":
		return false
	if kind == "guarder" or kind == "offhand":
		return true
	return _current_weapon_supports_shield()

func _enforce_shield_weapon_compatibility(quiet: bool = false) -> void:
	var offhand_value: Variant = equipped_items.get("offhand", {})
	if not (offhand_value is Dictionary):
		return
	var offhand: Dictionary = offhand_value as Dictionary
	if offhand.is_empty() or _offhand_kind(offhand) != "shield" or _current_weapon_supports_shield():
		return
	var offhand_name: String = str(offhand.get("name", "방패"))
	equipped_items["offhand"] = {}
	if not quiet:
		hud.show_message("현재 무기와 방패를 함께 착용할 수 없어 방패가 해제되었습니다")
	hud.append_log("방패 자동 해제 · %s / 무기 %s" % [offhand_name, _current_weapon_type()])

func _equipped_weapon_record() -> Dictionary:
	var value: Variant = equipped_items.get("weapon", {})
	if value is Dictionary:
		return value as Dictionary
	return {}

func _weapon_allowed_for_job(record: Dictionary, target_job: String) -> bool:
	if record.is_empty():
		return true
	var weapon_type: String = _normalized_weapon_type(str(record.get("type", "")))
	var allowed_value: Variant = JOB_ALLOWED_WEAPONS.get(target_job, [])
	if not (allowed_value is Array):
		return false
	return (allowed_value as Array).has(weapon_type)

func _enforce_weapon_class_compatibility(quiet: bool = false) -> void:
	var weapon: Dictionary = _equipped_weapon_record()
	if weapon.is_empty() or _weapon_allowed_for_job(weapon, job_class):
		return
	var item_name: String = str(weapon.get("name", "무기"))
	equipped_items["weapon"] = {}
	_refresh_speed_modifiers()
	if not quiet:
		hud.show_message("클래스 변경으로 %s 장착 해제" % item_name)
	hud.append_log("%s 착용 불가 · %s 장착 해제" % [job_class, item_name])

func _current_weapon_type() -> String:
	return _normalized_weapon_type(str(_equipped_weapon_record().get("type", "")))

func _current_attack_kind() -> String:
	var weapon: Dictionary = _equipped_weapon_record()
	if weapon.has("attackKind"):
		return str(weapon.get("attackKind", "melee"))
	return _weapon_attack_kind_from_type(_current_weapon_type())

func _current_attack_range_cells() -> int:
	var weapon: Dictionary = _equipped_weapon_record()
	if weapon.has("attackRangeCells"):
		return maxi(1, int(weapon.get("attackRangeCells", 1)))
	return _weapon_range_cells_from_type(_current_weapon_type())

func _weapon_cell_distance(target: TwilightMonster) -> int:
	if target == null:
		return 999999
	var from_cell: Vector2i = _world_to_cell(player.global_position)
	var to_cell: Vector2i = _world_to_cell(target.global_position)
	var delta: Vector2i = to_cell - from_cell
	return maxi(absi(delta.x), absi(delta.y))

func _target_in_current_weapon_range(target: TwilightMonster) -> bool:
	return target != null and _weapon_cell_distance(target) <= _current_attack_range_cells()

func _nearest_visible_monster_in_weapon_range() -> TwilightMonster:
	var best: TwilightMonster = null
	var best_distance: float = INF
	var range_cells: int = _current_attack_range_cells()
	for node: Node in monsters_root.get_children():
		if not (node is TwilightMonster):
			continue
		var monster: TwilightMonster = node
		if monster.dead or _weapon_cell_distance(monster) > range_cells:
			continue
		if not _has_line_of_sight_world(player.global_position, monster.global_position):
			continue
		var distance: float = player.global_position.distance_to(monster.global_position)
		if distance < best_distance:
			best_distance = distance
			best = monster
	return best

func _current_ammo_name() -> String:
	var weapon: Dictionary = _equipped_weapon_record()
	if weapon.has("ammo"):
		return str(weapon.get("ammo", ""))
	return _weapon_ammo_from_type(_current_weapon_type())

func _weapon_intrinsic_attack_speed_percent(record: Dictionary) -> float:
	if record.is_empty():
		return 0.0
	if record.has("weaponAttackSpeed"):
		return maxf(0.0, float(record.get("weaponAttackSpeed", 0.0)))
	var weapon_type: String = _normalized_weapon_type(str(record.get("type", "")))
	return maxf(0.0, float(WEAPON_BASE_ATTACK_SPEED.get(weapon_type, 15.0)))

func _ensure_inventory_ammo_defaults() -> void:
	if not inventory.has("화살"):
		inventory["화살"] = 500
	if not inventory.has("총알"):
		inventory["총알"] = 300

func _consume_weapon_ammo() -> bool:
	var ammo_name: String = _current_ammo_name()
	if ammo_name == "":
		return true
	var count: int = int(inventory.get(ammo_name, 0))
	if count <= 0:
		hud.show_message("%s이(가) 없습니다 · AUTO OFF" % ammo_name)
		hud.append_log("탄약 부족 · %s" % ammo_name)
		if player.auto_enabled:
			player.set_auto_enabled(false)
		_update_hud()
		return false
	inventory[ammo_name] = count - 1
	_update_hud()
	return true

func _normal_attack_hit_chance(target: TwilightMonster, attack_kind: String) -> float:
	if target == null:
		return 0.05
	var accuracy: int = _ranged_accuracy_stat() if attack_kind == "ranged" else _melee_accuracy_stat()
	var target_ac_abs: int = absi(target.armor_class)
	var chance_percent: float = 75.0 + float(accuracy - target_ac_abs) * 0.7
	return clampf(chance_percent / 100.0, 0.05, 0.95)

func _catalog_damage_bonus(kind: String) -> int:
	var total: int = 0
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			total += CATALOG_EFFECTS.damage_by_style(_verified_catalog_record(category, value as Dictionary), kind)
	return total

func _catalog_damage_adjustment(kind: String) -> int:
	# _effective_attack includes catalog atk; compensate for wrong weapon
	# styles without disturbing the pre-existing attack-stat calculation.
	var original_bonus: int = 0
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			original_bonus += int(_verified_catalog_record(category, value as Dictionary).get("atk", 0))
	return _catalog_damage_bonus(kind) - original_bonus

func _catalog_accuracy_bonus(kind: String) -> int:
	var total: int = 0
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			total += CATALOG_EFFECTS.accuracy_by_style(_verified_catalog_record(category, value as Dictionary), kind)
	return total

func _catalog_critical_bonus(kind: String) -> int:
	var total: int = 0
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			total += CATALOG_EFFECTS.critical_by_style(_verified_catalog_record(category, value as Dictionary), kind)
	return total

func _ranged_normal_damage_stat() -> int:
	return _ranged_damage_stat()

func _record_move_speed_multiplier(record: Dictionary) -> float:
	var value: float = float(record.get("speed", 1.0))
	if value <= 0.0:
		return 1.0
	return clampf(value, 0.5, 2.0)

func _record_attack_speed_percent(record: Dictionary) -> float:
	var value: float = CATALOG_EFFECTS.attack_speed_percent(record)
	if str(record.get("slot", "")) == "weapon":
		value += _weapon_intrinsic_attack_speed_percent(record)
	return maxf(0.0, value)

func _effective_move_speed_multiplier() -> float:
	var multiplier: float = 1.0
	for record: Dictionary in _all_equipped_records():
		multiplier *= _record_move_speed_multiplier(record)
	multiplier *= _passive_skill_speed_multiplier()
	multiplier *= 1.0 + float(_active_item_buff_total("move_speed")) / 100.0
	multiplier *= _inventory_encumbrance_multiplier()
	return clampf(multiplier, 0.5, 2.5)

func _effective_attack_speed_bonus_percent() -> float:
	var total: float = 0.0
	for record: Dictionary in _all_equipped_records():
		total += _record_attack_speed_percent(record)
	total += float(_active_item_buff_total("attack_speed"))
	return maxf(0.0, total)

func _effective_attack_speed_multiplier() -> float:
	return clampf(1.0 + _effective_attack_speed_bonus_percent() / 100.0, 0.5, 4.0)

func _normal_attack_interval() -> float:
	return clampf(0.72 / _effective_attack_speed_multiplier(), 0.12, 1.50)

func _refresh_speed_modifiers() -> void:
	if player == null:
		return
	player.set_equipment_speed_multipliers(_effective_move_speed_multiplier(), _effective_attack_speed_multiplier())

func _stat_step_bonus(value: int, baseline: int, divisor: float) -> int:
	var delta: int = value - baseline
	if delta <= 0:
		return 0
	return int(floor(float(delta) / divisor))

func _melee_damage_stat() -> int:
	return _effective_attack() + _catalog_damage_adjustment("melee") + _stat_step_bonus(_effective_attribute("STR") + _active_skill_buff_total("strFlat"), 10, 2.0) + _equipment_additional_damage("melee") + _active_item_buff_total("melee_damage")

func _melee_accuracy_stat() -> int:
	return level + _effective_attribute("STR") + _active_skill_buff_total("strFlat") + 10 + _equipment_enhancement_level("weapon") + _equipment_accuracy_bonus("melee") + _catalog_accuracy_bonus("melee") + _active_item_buff_total("melee_accuracy")

func _ranged_damage_stat() -> int:
	return _effective_attack() + _catalog_damage_adjustment("ranged") + _stat_step_bonus(_effective_attribute("DEX") + _active_skill_buff_total("dexFlat"), 10, 2.0) + _active_skill_buff_total("ranged_bonus") + _equipment_additional_damage("ranged") + _active_item_buff_total("ranged_damage")

func _ranged_accuracy_stat() -> int:
	return level + _effective_attribute("DEX") + _active_skill_buff_total("dexFlat") + 5 + _equipment_enhancement_level("weapon") + _equipment_accuracy_bonus("ranged") + _catalog_accuracy_bonus("ranged") + _active_skill_buff_total("ranged_accuracy") + _active_item_buff_total("ranged_accuracy")

func _magic_damage_stat() -> int:
	return 5 + _stat_step_bonus(_effective_attribute("INT") + _active_skill_buff_total("intFlat"), 8, 2.0) + _catalog_damage_bonus("magic") + _catalog_stat_sum("sp") + _equipment_additional_damage("magic") + _active_item_buff_total("sp")

func _magic_accuracy_stat() -> int:
	return level + _effective_attribute("INT") + _active_skill_buff_total("intFlat") + _equipment_accuracy_bonus("magic") + _catalog_accuracy_bonus("magic") + _active_item_buff_total("magic_accuracy")

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
			base += _stat_step_bonus(_effective_attribute("DEX"), 16, 5.0)
		"magic":
			base += _stat_step_bonus(_effective_attribute("INT"), 16, 5.0)
		_:
			base += _stat_step_bonus(_effective_attribute("STR"), 16, 5.0)
	for record: Dictionary in _all_equipped_records():
		base += _record_critical_bonus(record, attack_type)
	base += _catalog_critical_bonus(attack_type)
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
	var total: int = 5 + _stat_step_bonus(_effective_attribute("STR"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_stun_accuracy(record)
	return clampi(total, 0, 100)

func _stun_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("CON"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_stun_resistance(record)
	total += _active_item_buff_total("stun_resistance")
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
	var total: int = 5 + _stat_step_bonus(_effective_attribute("INT"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_silence_accuracy(record)
	return clampi(total, 0, 100)

func _silence_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("WIS"), 10, 3.0)
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
	var total: int = 5 + _stat_step_bonus(_effective_attribute("DEX"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_hold_accuracy(record)
	return clampi(total, 0, 100)

func _hold_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("CON"), 10, 3.0)
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
	var total: int = 5 + _stat_step_bonus(_effective_attribute("INT"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_fear_accuracy(record)
	return clampi(total, 0, 100)

func _fear_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("WIS"), 10, 3.0)
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
	var total: int = 5 + _stat_step_bonus(_effective_attribute("INT"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_poison_accuracy(record)
	return clampi(total, 0, 100)

func _poison_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("CON"), 10, 3.0)
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
	var total: int = 5 + _stat_step_bonus(_effective_attribute("STR"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_bleed_accuracy(record)
	return clampi(total, 0, 100)

func _bleed_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("CON"), 10, 3.0)
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
	var dex_ac_bonus: int = _stat_step_bonus(_effective_attribute("DEX"), 10, 3.0)
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
	var total: int = _stat_step_bonus(_effective_attribute("DEX"), 10, 4.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_dg(record)
	return maxi(0, total)

func _effective_er() -> int:
	var total: int = _stat_step_bonus(_effective_attribute("DEX"), 10, 2.0)
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
	var total: int = 10 + level + _effective_attribute("WIS") * 2
	for record: Dictionary in _all_equipped_records():
		total += _record_mr(record)
	total += _active_skill_buff_total("mrFlat")
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
	return CATALOG_EFFECTS.flat_reduction(record)

func _damage_reduction_stat() -> int:
	var total: int = 0
	for record: Dictionary in _all_equipped_records():
		total += _record_damage_reduction(record)
	total += _active_item_buff_total("damage_reduction")
	return maxi(0, total)

func _pve_damage_after_item_buffs(raw_damage: int) -> int:
	var reduced: int = maxi(1, raw_damage - _active_item_buff_total("pve_damage_reduction") - _catalog_stat_sum("pve_damage_reduction"))
	var percent: int = clampi(_active_item_buff_total("pve_damage_reduction_pct"), 0, 90)
	if percent > 0:
		reduced = maxi(1, int(round(float(reduced) * (1.0 - float(percent) / 100.0))))
	return reduced

func _physical_damage_after_reduction(raw_damage: int) -> int:
	return maxi(1, raw_damage - _damage_reduction_stat() - _active_skill_buff_total("damage_reduction"))

func _character_stats_snapshot() -> Dictionary:
	return {
		"str": _effective_attribute("STR"),
		"dex": _effective_attribute("DEX"),
		"con": _effective_attribute("CON"),
		"int": _effective_attribute("INT"),
		"wis": _effective_attribute("WIS"),
		"cha": _effective_attribute("CHA"),
		"stat_points": stat_points,
		"inventory_weight": _inventory_total_weight(),
		"carrying_capacity": _carrying_capacity(),
		"encumbrance_multiplier": _inventory_encumbrance_multiplier(),
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
		"damage_reduction": _damage_reduction_stat(),
		"attack_speed_bonus": _effective_attack_speed_bonus_percent(),
		"move_speed_bonus": (_effective_move_speed_multiplier() - 1.0) * 100.0,
		"attack_interval": _normal_attack_interval(),
		"weapon_type": _current_weapon_type() if _current_weapon_type() != "" else "맨손",
		"weapon_attack_kind": _current_attack_kind(),
		"weapon_range_cells": _current_attack_range_cells(),
		"weapon_attack_speed": _weapon_intrinsic_attack_speed_percent(_equipped_weapon_record()),
		"weapon_ammo": _current_ammo_name(),
		"weapon_ammo_count": int(inventory.get(_current_ammo_name(), 0)) if _current_ammo_name() != "" else -1,
		"allowed_weapons": _job_weapon_text(job_class),
		"passive_skills": _passive_skill_names(),
		"shield_compatible": _current_weapon_supports_shield(),
		"offhand_kind": _offhand_kind(equipped_items.get("offhand", {}) as Dictionary) if equipped_items.get("offhand", {}) is Dictionary else ""
	}

func _effective_attack() -> int:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("atk", 0.0))
	return attack_power + int(round(bonus)) + _equipment_enhancement_level("weapon") + _active_skill_buff_total("atk") + _passive_skill_total("atk")

func _effective_defense() -> int:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("def", 0.0))
	var armor_enhance: int = _equipment_enhancement_total(ARMOR_EQUIPMENT_SLOTS)
	var accessory_enhance: int = int(floor(float(_equipment_enhancement_total(ACCESSORY_EQUIPMENT_SLOTS)) / 2.0))
	return defense + int(round(bonus)) + armor_enhance + accessory_enhance + _active_skill_buff_total("def") + _passive_skill_total("def")

func _effective_max_hp() -> int:
	var flat_bonus: float = 0.0
	var percent_bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		flat_bonus += float(record.get("hpFlat", 0.0))
		percent_bonus += float(record.get("hpPct", 0.0))
	flat_bonus += float(_equipment_enhancement_max(ACCESSORY_EQUIPMENT_SLOTS) * 20)
	flat_bonus += float(_equipment_attribute_bonus("CON") * 10)
	flat_bonus += float(_active_skill_buff_total("hp"))
	flat_bonus += float(_passive_skill_total("hpFlat"))
	flat_bonus += float(_active_item_buff_total("hp_flat"))
	return maxi(1, int(round((max_hp + flat_bonus) * (1.0 + percent_bonus))))

func _experience_multiplier() -> float:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("xp", 0.0))
	return maxf(1.0, 1.0 + bonus)

func _update_companion(delta: float) -> void:
	doll_motion.update(delta, $Companion, companion_sprite, player)
	relic_motion.update(delta, relic_sprite, player)

# Playable-field services: renderer, physics, population and HUD remain separate.
func _setup_field_services() -> void:
	y_sort_enabled = true
	monsters_root.y_sort_enabled = true
	monsters_root.z_index = 0
	player.z_index = 0
	$Companion.z_index = 0
	field_population = FIELD_POPULATION.new()
	field_population.name = "FieldPopulation"
	add_child(field_population)
	field_population.set_process(false)
	field_minimap = FIELD_MINIMAP.new()
	field_minimap.name = "FieldMinimap"
	hud.get_node("Root").add_child(field_minimap)
	field_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	field_minimap.offset_left = -238
	field_minimap.offset_right = -16
	field_minimap.offset_top = 100
	field_minimap.offset_bottom = 291
	field_minimap.z_index = 36

func _update_field_triggers() -> void:
	if field_map == null:
		if return_gate_position.is_finite() and portal_cooldown <= 0 and not player.auto_enabled and player.global_position.distance_to(return_gate_position) < 55:
			portal_cooldown = 2.0
			call_deferred("_return_from_field_gate")
		return
	var region: Dictionary = field_map.region_at(player.global_position)
	if str(region["id"]) != region_id:
		region_id = str(region["id"])
		hud.set_map_name(str(region["name"]) + (" · 안전 지역" if str(region["type"])=="safe" else " · " + str(field_map.data.get("short_name", "아덴"))))
	if portal_cooldown > 0.0 or player.auto_enabled:
		return
	for portal: Dictionary in field_map.data["portal"]:
		if player.global_position.distance_to(COORD.array_vector(portal["position"])) < float(portal["radius"]):
			portal_cooldown = 2.0
			call_deferred("use_field_portal",str(portal["id"]))
			break

func use_field_portal(portal_id: String) -> bool:
	if field_map == null:
		return false
	for portal: Dictionary in field_map.data["portal"]:
		if str(portal["id"]) != portal_id:
			continue
		var target_map: String = str(portal["target_map"])
		if not maps_by_id.has(target_map):
			return false
		player.set_auto_enabled(false)
		player.clear_click_path()
		player.velocity = Vector2.ZERO
		player.set_touch_vector(Vector2.ZERO)
		selected_monster = null
		auto_target = null
		if target_map != active_map_id:
			_set_map(target_map,false)
			if field_map == null:
				_place_return_gate()
			elif portal.has("target_position"):
				var landing: Vector2i = field_map.nearest_cell(COORD.array_vector(portal["target_position"]))
				if landing.x >= 0:
					player.global_position = field_map.cell_to_world(landing)
		elif portal.has("target_position"):
			var cell: Vector2i = field_map.nearest_cell(COORD.array_vector(portal["target_position"]))
			if cell.x < 0:
				return false
			player.global_position = field_map.cell_to_world(cell)
		player.camera.reset_smoothing()
		player.camera.force_update_scroll()
		if field_renderer != null:
			field_renderer.refresh_visible()
		portal_cooldown = 2.0
		hud.show_message(str(portal["name"]))
		return true
	return false

func _place_return_gate() -> void:
	var path: PackedVector2Array = find_world_path(player.global_position,player.global_position+Vector2(192,0))
	if path.is_empty():
		return
	return_gate_position = path[path.size()-1]
	if return_gate_position.distance_to(player.global_position) < 85:
		return_gate_position = Vector2.INF
		return
	return_gate = Node2D.new()
	return_gate.name = "AdenReturnPortal"
	return_gate.position = return_gate_position
	add_child(return_gate)
	var line := Line2D.new()
	line.width = 4
	line.default_color = Color("8bddd0")
	for i: int in range(49):
		line.add_point(Vector2(cos(TAU*i/48.0)*50,sin(TAU*i/48.0)*28))
	return_gate.add_child(line)
	var label := Label.new()
	label.text = "아덴으로 귀환"
	label.position = Vector2(-65,-72)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_gate.add_child(label)

func _return_from_field_gate() -> void:
	_set_map("aden_world",false)
	var cell: Vector2i = field_map.nearest_cell(Vector2(10640,5440))
	player.global_position = field_map.cell_to_world(cell)
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	field_renderer.refresh_visible()

# Attack commands retain their original target and resolve once at the motion marker.
func _skill_attack_kind(skill: Dictionary) -> String:
	var requested: String = str(skill.get("attack_style", ""))
	if requested in ["melee", "ranged", "magic"]: return requested
	if job_class in ["요정", "총사"]: return "ranged"
	if job_class == "마법사" or str(skill.get("class", "")) == "마법사" or (str(skill.get("class", "공용")) == "공용" and SKILL_RULES.range_pixels(skill) >= 250.0): return "magic"
	return "melee"

func _skill_motion_duration(skill: Dictionary) -> float:
	return clampf(maxf(0.42, SKILL_RULES.global_cooldown_seconds(skill)) / _effective_attack_speed_multiplier(), 0.14, 0.85)

func _queue_damage_skill(skill: Dictionary, target: TwilightMonster, max_range: float) -> void:
	_queue_player_attack(target, _skill_attack_kind(skill), _apply_job_skill_damage.bind(skill.duplicate(true), target), _skill_motion_duration(skill), false, max_range)
	pending_attack["skill"] = skill.duplicate(true)
	pending_attack["duration"] = _skill_motion_duration(skill)

func _queue_player_attack(target: TwilightMonster, kind: String, callback: Callable, duration: float, normal: bool = false, max_range: float = 0.0) -> void:
	player.cancel_attack()
	player.clear_click_path()
	var style: String = TwilightAnimationProfile.weapon_style(_current_weapon_type(), kind)
	var marker: float = player.motion.profile.marker_for(style)
	var id: int = player.start_combat_attack(target.global_position, duration, style, marker)
	pending_attack = {"id":id, "target":weakref(target), "callback":callback, "kind":kind,
		"style":style, "normal":normal, "range":max_range, "start":player.global_position, "generation":combat_generation}

func _cancel_player_attack(id: int) -> void:
	if int(pending_attack.get("id", -1)) == id: pending_attack.clear()

func _release_player_attack(id: int) -> void:
	if int(pending_attack.get("id", -1)) != id: return
	var action: Dictionary = pending_attack
	pending_attack = {}
	var target: TwilightMonster = action.target.get_ref() as TwilightMonster
	if not is_instance_valid(target) or target.dead or hp <= 0: return
	if player.is_stunned() or player.is_feared(): return
	if action.kind == "magic" and player.is_silenced(): return
	if player.global_position.distance_to(action.start) > 12.0: return
	var in_range: bool = _target_in_current_weapon_range(target) if action.normal else player.global_position.distance_to(target.global_position) <= float(action.range)
	if not in_range or not _has_line_of_sight_world(player.global_position, target.global_position): return
	player.face_target(target.global_position)
	if action.kind == "magic" and combat_vfx != null:
		combat_vfx.ring(player.combat_projectile_origin(), 18.0, Color(0.45, 0.7, 1.0))
	var skill: Dictionary = action.get("skill", {})
	var hits: int = clampi(int(skill.get("hits", 1)), 1, 8)
	if hits > 1:
		var volley_runtime: Dictionary = {}
		var spacing: float = clampf(float(action.get("duration", 0.42)) * 0.18, 0.035, 0.10)
		for shot: int in range(hits):
			var shot_skill: Dictionary = skill.duplicate(true)
			shot_skill["_single_hit_index"] = shot
			shot_skill["_volley_runtime"] = volley_runtime
			var shot_action: Dictionary = action.duplicate(false)
			shot_action["callback"] = _apply_job_skill_damage.bind(shot_skill, target)
			var flight_kind: String = action.kind if action.kind in ["ranged", "magic"] else "timed"
			combat_flights.launch(player.combat_projectile_origin(), target, flight_kind, _impact_player_attack.bind(shot_action), 1300.0, float(shot) * spacing)
		return
	if action.kind in ["ranged", "magic"]:
		combat_flights.launch(player.combat_projectile_origin(), target, action.kind, _impact_player_attack.bind(action), 900.0 if action.kind == "magic" else 1300.0)
	else:
		_impact_player_attack(action)

func _impact_player_attack(action: Dictionary) -> void:
	if int(action.generation) != combat_generation or hp <= 0: return
	var target: TwilightMonster = action.target.get_ref() as TwilightMonster
	if not is_instance_valid(target) or target.dead: return
	if not _has_line_of_sight_world(player.global_position, target.global_position): return
	var callback: Callable = action.callback
	if not callback.is_valid(): return
	resolving_combat_action = true
	feedback_kind = action.kind
	feedback_style = action.get("style", action.kind)
	callback.call()
	feedback_kind = "melee"
	feedback_style = "slash"
	resolving_combat_action = false

func _clear_combat_actions() -> void:
	combat_generation += 1
	pending_attack.clear()
	if is_instance_valid(player): player.cancel_attack()
	if is_instance_valid(combat_flights): combat_flights.clear()
	if is_instance_valid(combat_vfx): combat_vfx.clear()
	if is_instance_valid(combat_corpses):
		for corpse: Node in combat_corpses.get_children(): corpse.queue_free()

func show_combat_number(point: Vector2, value: String, color: Color, critical: bool = false) -> void:
	if is_instance_valid(combat_vfx): combat_vfx.number(point, value, color, critical)

func monster_combat_feedback(target: TwilightMonster, critical: bool, damage_kind: String = "") -> void:
	if not is_instance_valid(combat_vfx): return
	var style: String = feedback_style if damage_kind.is_empty() else damage_kind
	combat_vfx.impact(target.combat_hit_position(), player.global_position.direction_to(target.global_position), style, critical)
	if critical: player.motion.visual_hold = 0.028

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(player):
		_save_game(true)
