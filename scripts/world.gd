extends Node2D
class_name TwilightWorld
const RETIRED_ITEMS = preload("res://scripts/loot/retired_enhancement_items523.gd")
const CHARACTER_ACCOUNT = preload("res://scripts/characters/account_store.gd")
const CHARACTER_PROFILE = preload("res://scripts/characters/save_profile.gd")
var character_source_cursor: Dictionary = {}
## Where an old-map save was moved from when it was brought to 523 Aden (kept in the save).
var old_map_relocation523: Dictionary = {}
## 사용자 결정 2026-11-16 tutorial removal record (scripts/content523/tutorial523.gd).
var tutorial523: Dictionary = {}
var character_display_name: String = "황혼의 기사"
var character_dormant_physical: Dictionary = {}
var returning_to_character_lobby: bool = false
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")

var card_selection_saves = preload("res://scripts/cards/card_selection_save.gd").new()

const EQUIPMENT523_SERVICE = preload("res://scripts/equipment523/service.gd")
const EQUIPMENT523_COMBAT = preload("res://scripts/equipment523/combat.gd")
const EQUIPMENT523_INVOKE_DEBUFF = preload("res://scripts/equipment523/invoke_debuff.gd")
const EQUIPMENT523_SET_INVOKE = preload("res://scripts/equipment523/set_invoke.gd")
var equipment523 = EQUIPMENT523_SERVICE.new()
var alchemy_held_items = preload("res://scripts/equipment523/alchemy_held_use.gd").new()
var source_ground_acquisitions = preload("res://scripts/loot/source523_ground_acquisition.gd").new()

var patch523_npc_spells = preload("res://scripts/monsters/patch523_npc_combat.gd").new()
const MONSTERBOOK523_RUNTIME = preload("res://scripts/monsterbook/monsterbook523_runtime.gd")
var monsterbook523_runtime = MONSTERBOOK523_RUNTIME.new()
var monsterbook523 = monsterbook523_runtime.catalog

const PROTECTION523 = preload("res://scripts/protection/protection523_runtime.gd")
var protection523 = PROTECTION523.new()

signal regional_return_settings_updated
const SOURCE_AMMO = preload("res://scripts/shop/source523_ammo.gd")
const REGIONAL_RETURN = preload("res://scripts/quickslots/regional_return.gd")

const QUICK_LAYOUT = preload("res://scripts/ui/reference_layout.gd")
const SOURCE_DUNGEONS = preload("res://scripts/dungeons/source_dungeon_runtime.gd")
var source_dungeons = SOURCE_DUNGEONS.new()
const DUNGEON_RUNS = preload("res://scripts/dungeons/dungeon_run_service.gd")
const DUNGEON_ECONOMY = preload("res://scripts/dungeons/dungeon_economy.gd")
const LOCAL_TOWER = preload("res://scripts/dungeons/local_tower_host.gd")
var source_dungeon_runs = DUNGEON_RUNS.new()
var pending_dungeon_events: Dictionary = {}
var local_dungeon_failure_pending: bool = false
var local_dungeon_session_id: String = Crypto.new().generate_random_bytes(16).hex_encode()
const DUNGEON_PLAY = preload("res://scripts/dungeons/dungeon_play_service.gd")
var dungeon_play = DUNGEON_PLAY.new()
const TOTEM_RUNTIME = preload("res://scripts/progression/totem_runtime.gd")
var totems = TOTEM_RUNTIME.new()
var totem_actions = preload("res://scripts/progression/totem_actions.gd").new()
var totem_combat = preload("res://scripts/progression/totem_combat.gd").new()


const SAVE_PATH: String = "user://twilight_v20_save.json"
const SAVE_TRIM = preload("res://scripts/loot/save_provenance_trim.gd")
const SAVE_SNAPSHOT = preload("res://scripts/save/owned_snapshot.gd")
const MAPS_PATH: String = "res://data/maps_v18.json"
const DB_PATH: String = "res://data/game_db_v17.json"
const CATALOG_PATH: String = "res://data/catalog_v19.json"
const BASE508 = preload("res://scripts/lineagem_base508.gd")
const CATALOG_IMAGE_INDEX_PATH: String = "res://data/catalog_image_index_v19.json"
const DIRECTIONAL_PATH: String = "res://data/directional_art_v19.json"
const MONSTER_SCENE: PackedScene = preload("res://scenes/Monster.tscn")
const FIELD_INDEX_PATH: String = "res://data/maps/field_index.json"
const COORD = preload("res://scripts/maps/world_coordinates.gd")
const FIELD_SCRIPT = preload("res://scripts/maps/playable_field.gd")
const FIELD_RENDERER = preload("res://scripts/maps/field_renderer.gd")
const SOURCE_FIELD = preload("res://scripts/maps/source_field.gd")
const SOURCE_RENDERER = preload("res://scripts/maps/source_renderer.gd")
const REMAKE_REGISTRY = preload("res://scripts/maps/remake_registry.gd")
const REMAKE_RENDERER = preload("res://scripts/maps/remake_renderer.gd")
const SOURCE_PNG_GAME = preload("res://scripts/maps/source_png_game_registry.gd")
const SOURCE_MAP84 = preload("res://scripts/maps/source_map_runtime.gd")
const SOURCE_MAP84_RENDERER = preload("res://scripts/maps/source_map_runtime_renderer.gd")
const LEGACY_LAYOUT=preload("res://scripts/maps/legacy_layout_policy.gd")
const MAP_SAVE_MIGRATION = preload("res://scripts/maps/source_map_save_migration.gd")
var migrated_save_path: String=""
var migration_path_checked: bool=false
var migration_pointer_error: String=""
var pending_map_save_record: Dictionary={}
var map_bootstrap_blocked: bool=false
var loading_source_door_state: bool=false
var map_prior_process_mode: int=Node.PROCESS_MODE_INHERIT
const BASE508_TEST = preload("res://scripts/maps/base508_game_mode.gd")
const CURRENT523_ADEN_PACK = preload("res://scripts/maps/current523_aden_pack.gd")
const CURRENT523_HOST = preload("res://scripts/maps/current523_host.gd")
const MAP_LOADING = preload("res://scripts/boot/dungeon_loading.gd")
const CURRENT523_MAP_TELEPORT = preload("res://scripts/maps/current523_map_teleport.gd")
const WALK_PATH_PROGRESS = preload("res://scripts/maps/walk_path_progress.gd")
const OLD_MAP_RELOCATION523 = preload("res://scripts/maps/old_map_save_relocation523.gd")
const TUTORIAL523 = preload("res://scripts/content523/tutorial523.gd")
const CURRENT523_ADEN_REVIEW = preload("res://scripts/maps/current523_aden_review.gd")
const CURRENT523_ADEN_PLAY = preload("res://scripts/maps/current523_aden_play_controller.gd")
const FRAME_HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const CURRENT523_ADEN_PLAY_OPTIONS = preload("res://scripts/maps/current523_aden_play_options.gd")
const CURRENT523_DEFINITION_PREFERENCES=preload("res://scripts/maps/current523_source_definition_preferences.gd")
const NATIVE_PNG = preload("res://scripts/maps/native_png_registry.gd")
const NATIVE_PNG_RENDERER_PATH: String = "res://scripts/maps/native_png_renderer.gd"
# Do not preload this heavy optional renderer while parsing the main game class.
# Android editor import may otherwise resolve the PNG class graph recursively.
# PR #137's shipped entry-only PNG plan (594438d). Only this reviewed layout
# upgrade may cross a plan hash; unknown plans still fail before state changes.
const NATIVE_PNG_SAVE_MIGRATIONS: Dictionary = {
	"6dddc9772b9b1605a0aeaaa1b3a52e6ae88aa99ecb7d3e9b4ddd9946fdb83da4": {
		"from_revision":2026102001,"to_revision":2026102002,
		"map_ids":["aden_world","faith_01","faith_02","faith_03","faith_04"]
	}
}
const SOURCE_POPULATION = preload("res://scripts/maps/source_population.gd")
const SOURCE_TRAVEL = preload("res://scripts/maps/source_travel.gd")
const FIELD_POPULATION = preload("res://scripts/maps/field_population.gd")
const FIELD_CAMERA = preload("res://scripts/maps/field_camera_scale.gd")
const MONSTER_CATALOG = preload("res://scripts/monsters/monster_catalog.gd")
const MONSTER_ART = preload("res://scripts/monsters/monster_art.gd")
const FIELD_MINIMAP = preload("res://scripts/maps/field_minimap.gd")
const SKILL_RULES = preload("res://scripts/skill_rules.gd")
const ORIGINAL_SKILLS = preload("res://scripts/skills/skill_service.gd")
var original_skills: TwilightOriginalSkillService = null
var legacy_skills_db: Array = []
const ITEM_OPTIONS = preload("res://scripts/item_options.gd")
const ITEM_CATALOG_LOOKUP = preload("res://scripts/catalog_item_lookup.gd")
const PHYSICAL_RESOLUTION = preload("res://scripts/combat/physical_resolution.gd")
const INVEN_OPTIONS = preload("res://scripts/inven_option_adapter.gd")
const ENCHANT = preload("res://scripts/original_enhancement.gd")
const CATALOG_EFFECTS = preload("res://scripts/catalog_effects.gd")
const TRANSFORM_SKILL = preload("res://scripts/transform_skill_options.gd")
const CATALOG_GRADES = preload("res://scripts/catalog_grade_policy.gd")
const EQUIPMENT_COLLECTION_RUNTIME = preload("res://scripts/collections/equipment_collection_runtime.gd")
var equipment_collections = EQUIPMENT_COLLECTION_RUNTIME.new()
const MASTERY523_RUNTIME = preload("res://scripts/mastery/mastery_runtime.gd")
var weapon_mastery = MASTERY523_RUNTIME.new()
const CARD_COLLECTION_RUNTIME = preload("res://scripts/cards/collection_runtime.gd")
var card_collections = CARD_COLLECTION_RUNTIME.new()
const GROWTH = preload("res://scripts/growth/growth_runtime.gd")
var growth = GROWTH.new()
const UNCONFIRMED523 = preload("res://scripts/unconfirmed523/runtime.gd")
var unconfirmed523 = UNCONFIRMED523.new()
const GROWTH96 = preload("res://scripts/progression/growth96_runtime.gd")
var growth96 = GROWTH96.new()
const HALF_ELIXIR = preload("res://scripts/growth/half_elixir_runtime.gd")
var half_elixir = HALF_ELIXIR.new()
const DOMINATION_STONES = preload("res://scripts/domination/domination_stone_runtime.gd")
var domination_stones = DOMINATION_STONES.new()
const ROUTINE523 = preload("res://scripts/routine523/routine523_runtime.gd")
var routines = ROUTINE523.new()
const EMBLEM523 = preload("res://scripts/emblem523/emblem523.gd")
var emblem523 = EMBLEM523.new()
const CLAN523 = preload("res://scripts/clan523/clan523.gd")
var clan523 = CLAN523.new()
const CONTENT523 = preload("res://scripts/content523/content523.gd")
var content523 = CONTENT523.new()
## 보유 칭호 ItemPossessionAppellationID (TWILIGHT 근사, scripts/titles/item_appellation523.gd).
const ITEM_APPELLATION523 = preload("res://scripts/titles/item_appellation523.gd")
var item_appellation523 = ITEM_APPELLATION523.new()
## 523 카드 다시 뽑기 / 스킬 카드 합성·강화 (사용자 결정 2026-11-16).
const CARD_SWAP523 = preload("res://scripts/cards/card_swap523.gd")
## TWILIGHT 근사: 획득 후 수명(Life) 장부, 지배 부적 소지 효과.
const ITEM_LIFE523 = preload("res://scripts/loot/item_life523.gd")
var item_life523 = ITEM_LIFE523.new()
## Original 523 아이템 컬렉션 (ItemBook tables, source_main_item_book_window).
const ITEM_BOOK523 = preload("res://scripts/collections/item_book523_runtime.gd")
var item_book523 = ITEM_BOOK523.new()
## TWILIGHT 근사: 신화 무기 발동 교체 (ItemInvokeReplacementID) 한 번 추첨 장부.
const ITEM_INVOKE523 = preload("res://scripts/loot/item_invoke_replacement523.gd")
var item_invoke523 = ITEM_INVOKE523.new()
## TWILIGHT 근사: 장비 상시 버프 (착용 장비의 BuffClassID 행).
var equipment_buff523 = preload("res://scripts/loot/equipment_buff523.gd").new()
## 던전 창 세부 데이터 (TWILIGHT 근사, scripts/dungeons/dungeon_extras523.gd).
const DUNGEON_EXTRAS523 = preload("res://scripts/dungeons/dungeon_extras523.gd")
var dungeon_extras523 = DUNGEON_EXTRAS523.new()
var item_possession523 = preload("res://scripts/loot/item_possession523.gd").new()
var card_swap523 = CARD_SWAP523.new()
const SKILL_CARD523 = preload("res://scripts/cards/skill_card523.gd")
var skill_cards523 = SKILL_CARD523.new()
const TITLE523 = preload("res://scripts/titles/title_runtime523.gd")
var titles = TITLE523.new()
var title_badge: Label
const CARD_DRAW_FUSION = preload("res://scripts/card_draw_fusion.gd")
const OPTION_AWAKENING = preload("res://scripts/cards/option_awakening_runtime.gd")
const OPTION_AWAKENING_AURA = preload("res://scripts/animation/option_awakening_aura.gd")
var option_awakening = OPTION_AWAKENING.new()
const SKILL_AWAKENING=preload("res://scripts/cards/skill_awakening_runtime.gd")
const CURRENT523_DEFINITION_ROWS=preload("res://scripts/resources/current523_definition_rows.gd")
var skill_awakening=SKILL_AWAKENING.new()
const CARD_DECK_BONUS=preload("res://scripts/cards/card_deck_bonus523.gd")
var card_deck_bonus=CARD_DECK_BONUS.new()
const HALPHAS_STAR = preload("res://scripts/cards/halphas_star_enchant_runtime.gd")
var halphas_star = HALPHAS_STAR.new()
const EXPEDITION_CATALOG = preload("res://scripts/expedition/source_catalog.gd")
var expedition_catalog = EXPEDITION_CATALOG.new()
var expedition_pack_checked: bool = false
const EXPEDITION_LOCAL = preload("res://scripts/expedition/local_runtime.gd")
var expedition_local = EXPEDITION_LOCAL.new()
var option_awakening_auras: Dictionary = {}
var source_awakening_auras: Dictionary = {}
const SOURCE_AWAKENING_AURA = preload("res://scripts/animation/source_awakening_aura.gd")
var option_awakening_transaction_busy: bool = false
const CARD_PACK_ITEMS = preload("res://scripts/card_pack_items.gd")
const LOOT_DROP = preload("res://scripts/loot_drop.gd")
const CURRENCY_DROP = preload("res://scripts/loot/currency_drops.gd")
const PROMO_CODES = preload("res://scripts/promo/promo_codes.gd")
const QUEST_SERVICE = preload("res://scripts/quests/quest_service.gd")
var quest_service = QUEST_SERVICE.new()
const TJ_RUNTIME = preload("res://scripts/tj/runtime.gd")
var tj_coupons = TJ_RUNTIME.new()
var quest_auto = preload("res://scripts/quests/quest_auto_runner.gd").new()
var quest_item_provider = preload("res://scripts/quests/quest_item_provider238.gd").new()
const GROUND_LOOT_MANAGER = preload("res://scripts/loot/ground_loot_manager.gd")
const LOOT_PICKUP_CONTROLLER = preload("res://scripts/loot/loot_pickup_controller.gd")
var ground_loot: TwilightGroundLootManager = GROUND_LOOT_MANAGER.new()
var loot_pickup: TwilightLootPickupController = LOOT_PICKUP_CONTROLLER.new()
const PRESENTATION_AUDIO = preload("res://scripts/audio/presentation_audio.gd")
var presentation_audio: Node
const RELIC_MOTION = preload("res://scripts/animation/relic_motion.gd")
var relic_motion: TwilightRelicMotion = RELIC_MOTION.new()
const FOLLOWER_MOTION = preload("res://scripts/animation/follower_motion.gd")
var doll_motion: TwilightFollowerMotion = FOLLOWER_MOTION.new()
var secondary_doll_visual: Node2D
var secondary_relic_visual: Node2D
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
var stat_hud_refresh_pending: bool = false
## HUD publish domains. A transaction names what it changed; only HP/MP/
## EXP/gold bars (HUD_VITALS) and bag counts/weight/quick items (HUD_ITEMS)
## have their own light publish. Anything else (equipment, buffs, cards,
## transform, combination, level, load) is the full _update_hud.
const HUD_VITALS: int = 1
const HUD_ITEMS: int = 2
const HUD_FULL: int = 1 << 30
## Publish counters: full HUD rebuilds (each recalculates every derived stat),
## light vitals/items publishes, and derived-stat snapshots.
var hud_publish_counts: Dictionary = {"full":0,"vitals":0,"items":0,"stat_snapshots":0,"speed_refreshes":0}
const PRESENTATION = preload("res://scripts/animation/presentation_preferences.gd")
const SOURCE_OPTIMIZATION = preload("res://scripts/animation/source_optimization.gd")
const LOCAL_PRESENTATION = preload("res://scripts/animation/local_presentation_region.gd")
const PRESENTATION_EFFECT_PACK = preload("res://scripts/animation/presentation_effect_pack.gd")
var presentation_effect_pack = PRESENTATION_EFFECT_PACK.new()
var presentation_effect_action: int = 0
var presentation_effect_enabled: bool = false
var source_optimization = SOURCE_OPTIMIZATION.new()
var source_optimization_result: Dictionary = {"status":"source_not_loaded","settings":{}}
var source_region_settings: Dictionary = {}
var source_optimization_signature: String = ""
var presentation_global_settings: Dictionary = PRESENTATION.DEFAULTS.duplicate(true)
var presentation_region_settings: Dictionary = {}
var presentation_settings: Dictionary = PRESENTATION.DEFAULTS.duplicate(true)
var local_presentation_regions: Dictionary = {}
var local_presentation_result: Dictionary = {"status":"off","settings":{}}
var local_presentation_signature: String = ""

const ANIMATION_CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const ELEMENT_RULES = preload("res://scripts/elemental_rules.gd")
const CONSUMABLE_AUTO = preload("res://scripts/consumable_auto_policy.gd")
const HP_POTION_COOLDOWN_SECONDS: float = 1.0
const HP_POTION_COOLDOWN_KEY: String = "__hp_potion_shared__"
const CONSUMABLE_RULES = preload("res://scripts/consumable_rules.gd")
const EQUIPMENT_BLESSING = preload("res://scripts/equipment_blessing.gd")
const PATCH523_ENHANCE = preload("res://scripts/crafting/patch523_enhancement.gd")
const PATCH523_TOKEN_STOCK = preload("res://scripts/loot/current523_native_stack.gd")
const PATCH523_ENHANCE_STOCK = preload("res://scripts/crafting/patch523_enhance_stock.gd")
const PATCH523_ENHANCE_SOURCE = preload("res://scripts/crafting/patch523_enhance_source_book.gd")
const PATCH523_EQUIPMENT_COMBAT = preload("res://scripts/crafting/patch523_equipment_combat.gd")
const CONSUMABLE_SERVICE = preload("res://scripts/consumable_service.gd")
const AIN_SERVICE = preload("res://scripts/ainhasad_service.gd")
const AIN_OPTION_RULES = preload("res://scripts/ainhasad_option_rules.gd")
const EXP_PROGRESSION = preload("res://scripts/experience_progression.gd")
const SHOP_CATALOG = preload("res://scripts/shop/shop_catalog.gd")
const SOURCE_SHOP = preload("res://scripts/shop/source523_shop_runtime.gd")
var source_shop = SOURCE_SHOP.new()
const LOCAL_WAREHOUSE = preload("res://scripts/warehouse/local_warehouse.gd")
const NPC_TELEPORT_POLICY = preload("res://scripts/npc/teleport_policy.gd")
const AUTO_HUNTING_SCHEDULE = preload("res://scripts/auto_hunting/source_schedule.gd")
const AUTO_HUNTING_LOCAL = preload("res://scripts/auto_hunting/local_movement.gd")
var auto_hunting_schedule: RefCounted = AUTO_HUNTING_SCHEDULE.new()
var auto_hunting_schedule_checked: bool = false
var auto_hunting_local: RefCounted = AUTO_HUNTING_LOCAL.new()
var auto_hunting_move_in_progress: bool = false
## Original 523 town NPCs and their original talk (no TWILIGHT dialogue data).
const TOWN_NPCS = preload("res://scripts/npc/source523_town_npcs.gd")
const LOCAL_CRAFTING = preload("res://scripts/crafting/local_crafting.gd")
const EXPANDED_CRAFTING = preload("res://scripts/crafting/expanded_crafting.gd")
var crafting = EXPANDED_CRAFTING.new()
const PATCH523_EQUIPMENT = preload("res://scripts/crafting/patch523_rules.gd")
var patch523_equipment = PATCH523_EQUIPMENT.new()
const PATCH523_ITEM_USE = preload("res://scripts/crafting/patch523_item_use.gd")
const POLYMORPH_WEAPON_LIMIT = preload("res://scripts/cards/polymorph_weapon_limit523.gd")
const PATCH523_SEAL_ACTIONS = preload("res://scripts/crafting/patch523_seal_actions.gd")
const PATCH523_STORE = preload("res://scripts/crafting/patch523_pack_store.gd")
var patch523_material_choices: Dictionary = {}
const PATCH523_QUEST_MATERIALS=preload("res://scripts/crafting/quest_material_inputs.gd")
# Session-only physical selections. SlotIndex -> source row choices above
# remain independent; neither mapping is a new ownership grant or save.
var patch523_owned_material_choices: Dictionary={}
const LOCAL_BUYBACK = preload("res://scripts/shop/local_buyback.gd")
var crafting_log: Array[Dictionary] = []
var patch523_crafting_usage: Dictionary = {}
const PATCH523_CRAFT_CATALOG=preload("res://scripts/crafting/patch523_craft_catalog.gd")
## Boot progress record (user://boot_progress.log); one line per startup step.
const BOOT_LOG=preload("res://scripts/boot/boot_progress_log.gd")
var patch523_craft_catalog_status: Dictionary={}
var patch523_craft_item_cache: Dictionary={}
## The craft item index built in small slices on idle frames after entering
## the game (same items, same order, same records as the one-shot build), so
## the first 제작 quote does not stall ~8 s building it (2026-11-19 measure:
## 8,016 ms for ~30,000 original items on desktop). A cache reset drops it.
var _craft_index_warm: Dictionary={}
var craft_index_warm_seconds: float=12.0
const CRAFT_INDEX_WARM_BUDGET_USEC := 3000
# Installed/configured only by the protection feature owner (PR256).
var patch523_owner_state_problem: String=""
var patch523_final_blow_fired: bool=false
var warehouse = LOCAL_WAREHOUSE.new()
const INVENTORY_AUTOMATION = preload("res://scripts/warehouse/inventory_automation.gd")
var inventory_automation = INVENTORY_AUTOMATION.new()
var ain_service: TwilightAinhasadService = AIN_SERVICE.new()
var ain_refresh_clock: float = 0.0

var field_map: PlayableField = null
## Zoom from the field data and whether it is an original-art (1:1) field.
var field_camera_base_zoom: float = 1.0
var field_camera_original_art: bool = false
var field_renderer: FieldRenderer = null
var field_physics: StaticBody2D = null
var field_population: FieldPopulation = null
var field_minimap: FieldMinimap = null
var original_maps: Array = []
var legacy_population: FieldPopulation
var original_population: OriginalSourcePopulation
var source_save_blocked: bool = false
var portal_cooldown: float = 2.0
var auto_repath_timer: float = 0.0
var _stable_auto_route: Dictionary = {}
var auto_last_position: Vector2 = Vector2.ZERO
var pending_ground_pickup: Button = null
const GROUND_PICKUP_RADIUS: float = 60.0
const AUTO_GROUND_PICKUP_SCAN: float = 460.0
var auto_stuck_time: float = 0.0
# Bound repeated unreachable-target pathfinding during AUTO, not manual selection.
const AUTO_TARGET_FAILED_PATH_RETRY_MS: int = 900
const AUTO_TARGET_EMPTY_RETRY_MS: int = 250
var auto_target_failed_paths: Dictionary = {}
var auto_target_next_search_ms: int = 0
var auto_target_failed_search_actor_count: int = -1
var auto_target_path_checks: int = 0
var auto_search_candidates: Array[Dictionary] = []
var auto_search_index: int = 0
var auto_search_cell: Vector2i
var auto_search_actor_count: int = -1
var auto_search_generation: int = -1
var manual_route_pending_target: Vector2 = Vector2.INF
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
var monster_size_index: Dictionary = {}
var item_db: Array = []
var item_weight_index: Dictionary = {}
var skills_db: Array = []
var skill_record_index: Dictionary = {}
var indexed_skills_db: Array = []
var indexed_skills_count: int = -1
var non_original_skill_rows: Array[Dictionary] = []
var job_classes: Array = []
var job_class: String = "기사"
var source_gender_id: int = 0 # Unknown until an explicit source gender is selected.
var source_card_visual_options: Dictionary = {}
var active_skill_buffs: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var skill_global_cooldown: float = 0.0
var active_item_buffs: Dictionary = {}
var item_use_cooldowns: Dictionary = {}
var _growth_catalyst_retry_usec:int=0
var consumable_service: Node = null
var quickslots: Array = []
var ui_preferences: Dictionary = {"quickslot_pages":{}, "edited_quickslots":{}, "item_locks":{}}
## Save marker of the legacy -> original 523 item migration (legacy_item_migration523.gd).
var legacy_item_marker: Dictionary = {}
## Save marker of the one-time load correction of EquipGroupID duplicates.
var equip_group_marker: Dictionary = {}
var auto_item_clock: float = 0.0
## M81: the auto heal sweep runs on the original 0.5 s main timer (strict >, single subtraction).
var auto_heal_sweep_elapsed: float = 0.0
var auto_quickslot_order_cache: Array[int] = []
var self_mode_enabled: bool = false
var auto_buff_check_timer: float = 0.0
var catalog_db: Dictionary = {}
var inven_record_index: Dictionary = {}
var catalog_item_by_source_id: Dictionary = {} # stable Inven ID -> full record
var catalog_item_variant_count: Dictionary = {} # name -> count; never dedupe rows
var verified_catalog_options: Dictionary = {}
var catalog_image_index: Dictionary = {}
var directional_art: Dictionary = {}
var combinations=preload("res://scripts/combinations/runtime.gd").new()
var card_draw_fusion: TwilightCardDrawFusion = CARD_DRAW_FUSION.new()
var equipped_catalog: Dictionary = {"변신": {}, "마법인형": {}, "성물": {}}
var equipped_items: Dictionary = {
	"weapon": {}, "offhand": {}, "helmet": {}, "tshirt": {}, "body": {}, "pants": {}, "cloak": {},
	"belt": {}, "earring1": {}, "earring2": {}, "ring1": {}, "ring2": {}, "seal1": {}, "seal2": {},
	"gaiters": {}, "boots": {}, "gloves": {}, "bracelet": {}, "necklace": {}, "badge": {},
	"crystal": {}, "catalyst": {}, "rune": {}, "domination_stone": {}, "relic_item": {}, "fishing_rod": {}
}
var enhancement_levels: Dictionary = {} # legacy name-level lookup; migration only
var item_instances: Dictionary = {} # physical ID -> {name, level}
var next_item_instance_id: int = 1
var spell_group_conversion=preload("res://scripts/skills/spell_group_conversion.gd").new()
var class_index: int = 0
var companion_velocity: Vector2 = Vector2.ZERO
var active_map: Dictionary = {}
var active_map_id: String = "aden_world"
var astar: AStarGrid2D = null
var world_size: Vector2 = Vector2(8192, 4224)
var tile_size: int = 32
const WORLD_INTERACTIONS = preload("res://scripts/input/world_interactions.gd")
const FOCUS_INPUT_RELEASE = preload("res://scripts/input/focus_input_release.gd")
const ORIGINAL_AUTOSLOT = preload("res://scripts/original_client/oc_m81_autoslot.gd")
const INVENTORY_GROUND_TRANSFER = preload("res://scripts/loot/inventory_ground_transfer.gd")
var world_interactions: Node
var ammo_notice_at: int = -10000
# Arrows/bullets are worn in their own ammo slot (LineageM style). "" means none.
# ammo_unequipped is true only after the player explicitly takes ammo off, so
# older saves and new characters still auto-equip the ammo their weapon needs.
var equipped_ammo: String = ""
var ammo_unequipped: bool = false
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
var general_save_pending: bool = false
# Non-transactional changes (quickslots, locks, shops, equipment swaps, NPC travel,
# warehouse) save after a quiet window rather than one synchronous disk write per
# action. Transactions and the pause/quit notifications still save immediately.
const DEFERRED_SAVE_GATE = preload("res://scripts/deferred_save_gate.gd")
# General autosave interval. A save costs ~25 ms since the source-map
# verification cache; pause/quit and transactions still save immediately.
const AUTOSAVE_SECONDS: float = 60.0
const DEFERRED_SAVE_SECONDS: float = 10.0
## SHA-256 of the save file this session last wrote with the shop state in it.
var _shop_key_saved_sha: String = ""
## Full re-reads of the previous save file for the shop migration (diagnostics/tests).
var previous_save_parses: int = 0
const PERF_LOG_THRESHOLD_USEC: int = 30000
var deferred_save: DEFERRED_SAVE_GATE = DEFERRED_SAVE_GATE.new(DEFERRED_SAVE_SECONDS)
# Automated suites run headless and assert durable state right after each action.
var deferred_save_enabled: bool = DisplayServer.get_name() != "headless"
var hp_recovery_elapsed: float = 0.0
var mp_recovery_elapsed: float = 0.0
var source_item_regen_elapsed: float = 0.0
var source_item_backup_checked_path: String = ""
var source_deadline_check_elapsed: float = 0.0
var source_item_save_blocked: bool = false
var source_item_catalog_history: Array=[]
var equipment_effects_dirty: bool = true
var equipment_effects: Dictionary = {}
var equipment_effect_rebuilds: int = 0
var equipment_records_dirty: bool = true
var equipment_records_cache: Array[Dictionary] = []
var equipment523_records_cache: Array[Dictionary] = []
var equipment_record_rebuilds: int = 0
const UNIQUE_RECOVERY_INTERVAL: float = 30.0
const UNIQUE_RECOVERY_AMOUNT: int = 5
var collision_debug: bool = false
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
	"boots", "gloves", "bracelet", "necklace", "badge", "crystal", "catalyst", "rune", "domination_stone", "relic_item", "fishing_rod"
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
	"crystal":"수정", "catalyst":"카탈리스트", "rune":"룬", "domination_stone":"지배석", "relic_item":"유물", "fishing_rod":"낚싯대"
}

var level: int = 35
var death_recovery = preload("res://scripts/death/runtime.gd").new()
var experience: int = 100
var exp_need: int = maxi(1, EXP_PROGRESSION.table_requirement(35))
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

var gold: int = 100000000 # Playtest-only starting funds; existing saved funds still load unchanged.
## A new character starts with original 523 items (current523_starter_kit.gd);
## pre-November item names are not used.
var inventory: Dictionary = {}

## Explicit loading-overlay contract. Deferred source/character restoration
## must finish before the overlay may report 100%.
var _boot_loading_finished: bool = false
var _boot_loading_problem: String = ""

func loading_readiness() -> Dictionary:
	var reason: String = ""
	if not _boot_loading_problem.is_empty(): reason = _boot_loading_problem
	elif map_bootstrap_blocked: reason = "원본 지도 팩을 확인해 주세요."
	elif source_save_blocked: reason = "저장 파일을 보존했습니다. 오류 내용을 확인해 주세요."
	elif _boot_loading_finished and field_map == null and not current523_aden_review_active: reason = "원본 지도 팩이 설치되지 않았습니다."
	elif _boot_loading_finished and _current523_source_restore_requested() and not current523_aden_play_active:
		reason = current523_aden_play_problem if not current523_aden_play_problem.is_empty() else "선택 캐릭터의 원본 지도 복원 실패"
	return {"ready": _boot_loading_finished and reason.is_empty(), "failed": not reason.is_empty(), "reason": reason}

func _finish_boot_loading() -> void:
	_boot_loading_finished = true
	BOOT_LOG.mark("world_deferred_ready", {"ok": not loading_readiness().failed})

func _ready() -> void:
	var boot_started: int = BOOT_LOG.begin("world_ready")
	preload("res://scripts/ui/dialog_korean_texts.gd").install(get_tree())
	add_child(preload("res://scripts/boot/frame_hitch_probe.gd").new())
	# Android: world canvas at 90% resolution, CanvasLayer UI stays native.
	add_child(preload("res://scripts/boot/world_render_scale.gd").new())
	BOOT_LOG.step("world_npc_spells")
	if patch523_npc_spells.configure(self):
		var source_panel = preload("res://scripts/ui/patch523_npc_panel.gd").new()
		source_panel.service = patch523_npc_spells
		add_child(source_panel)
	# Apply after resource import. A project-level custom_font is loaded before
	# first import on clean checkouts and would report a missing font loader.
	var korean_font := FontVariation.new()
	korean_font.base_font = load("res://assets/fonts/NotoSansKR.ttf") as Font
	korean_font.variation_opentype = {"wght":500.0}
	ThemeDB.get_default_theme().default_font = korean_font
	ThemeDB.fallback_font = korean_font
	BOOT_LOG.step("world_aden_review_check")
	if _boot_current523_aden_review():
		BOOT_LOG.step("")
		BOOT_LOG.end("world_ready", boot_started, {"path": "aden_review"})
		BOOT_LOG.mark("boot_done", {"path": "aden_review"})
		_finish_boot_loading.call_deferred()
		return
	BOOT_LOG.step("world_source_dungeon_pack")
	_load_source_dungeon_pack()
	_weight_index_deferred = true
	BOOT_LOG.step("world_services")
	rng.randomize()
	ain_service.import_state({})
	# Own TWILIGHT recipes (data/crafting/twilight_recipes.json) are not used in
	# the game; crafting is the original 523 ItemCraft tables only.
	inventory_automation.configure(self)
	BOOT_LOG.step("world_load_data")
	_load_data()
	BOOT_LOG.step("world_equipment523")
	equipment523.startup(self)
	BOOT_LOG.step("world_dungeons")
	source_dungeon_runs.configure(self,source_dungeons)
	source_dungeon_runs.changed.connect(_refresh_source_dungeon_panel)
	DUNGEON_ECONOMY.install_definitions(self,source_dungeons)
	LOCAL_TOWER.install_definition(self)
	dungeon_play.configure(self,source_dungeons)
	dungeon_play.install_items()
	dungeon_play.changed.connect(_refresh_source_dungeon_panel)
	var orim_hud: PanelContainer = preload("res://scripts/orim523/orim523_hud.gd").new()
	hud.add_child(orim_hud)
	orim_hud.configure(self)
	BOOT_LOG.step("world_catalog_titles")
	inventory_automation.refresh_catalog()
	titles.configure(self)
	title_badge=Label.new()
	title_badge.name="AchievedTitle523"
	title_badge.position=Vector2(-100,-104)
	title_badge.size=Vector2(200,24)
	title_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title_badge.add_theme_font_size_override("font_size",16)
	title_badge.add_theme_color_override("font_color",Color("efd792"))
	title_badge.add_theme_color_override("font_outline_color",Color.BLACK)
	title_badge.add_theme_constant_override("outline_size",5)
	player.add_child(title_badge)
	BOOT_LOG.step("world_monsterbook")
	monsterbook523_runtime.configure(self)
	BOOT_LOG.step("world_coupons")
	tj_coupons.configure(self)
	BOOT_LOG.step("world_protection")
	protection523.setup(self)
	BOOT_LOG.step("world_shop")
	source_shop.configure(self)
	BOOT_LOG.step("world_patch523_equipment")
	_load_patch523_equipment()
	BOOT_LOG.step("world_quests")
	if not quest_service.configure(item_db, monster_db):
		push_warning("퀘스트 데이터 검증 실패: " + quest_service.problem)
	if BASE508_TEST.enabled():
		var test_map:String=BASE508_TEST.register_test_map(maps,maps_by_id)
		if test_map.is_empty():
			_boot_loading_problem = "검사용 지도 팩이 거부되었습니다: " + BASE508_TEST.problem
			push_error("base508 test pack rejected: "+BASE508_TEST.problem)
			process_mode=Node.PROCESS_MODE_DISABLED
			BOOT_LOG.step("")
			BOOT_LOG.end("world_ready", boot_started, {"path": "base508_rejected"})
			return
		active_map_id=test_map
	BOOT_LOG.step("world_expedition")
	preload("res://scripts/expedition/reward_cards.gd").supplement(catalog_db,get_expedition_catalog())
	BOOT_LOG.step("world_cards")
	card_draw_fusion.configure(catalog_db)
	combinations.configure(self)
	# An absent owned original-definition ZIP is an expected install state, not
	# an engine error: those features stay off and say so. Damage still errors.
	if not card_collections.configure(self):
		if CURRENT523_DEFINITION_ROWS.not_installed():print("CURRENT523_DEFINITIONS_NOT_INSTALLED card_collections: "+card_collections.problem)
		else:push_error(card_collections.problem)
	BOOT_LOG.step("world_awakening")
	option_awakening.configure(self)
	halphas_star.configure(self)
	if not skill_awakening.configure(self):
		if skill_awakening.definitions_not_installed():print("CURRENT523_DEFINITIONS_NOT_INSTALLED skill_awakening: "+skill_awakening.problem)
		else:push_error(skill_awakening.problem)
	if not card_deck_bonus.configure(self):print("CARD_DECK_BONUS523_HELD "+card_deck_bonus.problem)
	preload("res://scripts/expedition/reward_cards.gd").register_profiles(self,get_expedition_catalog())
	BOOT_LOG.step("world_field_services")
	expedition_local.world = self
	consumable_service = CONSUMABLE_SERVICE.new()
	add_child(consumable_service)
	consumable_service.call("setup", self)
	quest_item_provider.configure(self)
	ground_loot.configure(self)
	loot_pickup.configure(self, ground_loot)
	death_recovery.configure(self)
	presentation_audio = PRESENTATION_AUDIO.new()
	add_child(presentation_audio)
	# Observe the existing released attack event; never drive its frame or timing.
	player.attack_strike.connect(func(cycle: int) -> void:
		if int(pending_attack.get("id", -1)) == cycle and bool(pending_attack.get("normal", false)):
			presentation_audio.play_world("attack", player.global_position))
	_flush_item_weight_index()
	_connect_signals()
	if hud.has_signal("consumable_auto_settings_changed"):
		hud.connect("consumable_auto_settings_changed", set_consumable_auto_settings)
	_setup_collision_tileset()
	_setup_field_services()
	# With the 523 pack, travel is the 523 world map and portals; the old
	# picture-pack destinations are not offered beside 523 Aden.
	hud.refresh_maps(maps.filter(func(record: Dictionary) -> bool: return str(record.get("id","")) == CURRENT523_HOST.MAP_ID) if CURRENT523_HOST.requested() else NATIVE_PNG.menu_entries(maps))
	hud.set_catalog_data(catalog_db, catalog_image_index)
	hud.set_job_data(job_classes, skills_db)
	var requested_png_map: String = ""
	if "--png-review" in OS.get_cmdline_user_args():
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--png-map="):
				var candidate_png_map: String = argument.trim_prefix("--png-map=")
				if maps_by_id.has(candidate_png_map) and REMAKE_REGISTRY.installed(candidate_png_map): requested_png_map = candidate_png_map;active_map_id = candidate_png_map
	BOOT_LOG.step("world_set_map")
	_set_map(active_map_id, false)
	BOOT_LOG.step("world_load_game")
	var creating_character: bool = not FileAccess.file_exists(save_path()) or (not CHARACTER_ACCOUNT.session.is_empty() and CHARACTER_ACCOUNT.session.get("path")==save_path() and not bool(CHARACTER_ACCOUNT.session.get("initialized",true)))
	_load_game(true)
	if creating_character:
		var starter: Dictionary = preload("res://scripts/loot/current523_starter_kit.gd").stage(self)
		if starter.get("ok", false):
			inventory = starter.overrides.inventory
			item_instances = starter.overrides.item_instances
	BOOT_LOG.step("world_finish")
	if _full_cards_playtest_active():
		var playtest_totals: Dictionary = card_draw_fusion.grant_full_collection_for_playtest(10)
		card_collections.restore_from_owned()
		_invalidate_equipment_static()
		hud.append_log("카드 테스트 · 변신 %d / 마법인형 %d / 성물 %d 전종 보유 · 중복 각 10장" % [
			int(playtest_totals.get("변신", 0)),
			int(playtest_totals.get("마법인형", 0)),
			int(playtest_totals.get("성물", 0))])
	if creating_character and growth.development: growth.seed_lab()
	if growth.development:
		var lab_badge := Label.new()
		lab_badge.text = "개발용 성장 실험 · 근사 수치 / 일반 저장과 분리"
		lab_badge.position = Vector2(440,80)
		lab_badge.z_index = 200
		lab_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lab_badge.add_theme_color_override("font_color",Color("ffcf76"))
		hud.get_node("Root").add_child(lab_badge)
		lab_badge.visible = not hud.workspace.visible
		hud.workspace.visibility_changed.connect(func() -> void: lab_badge.visible = not hud.workspace.visible)
	if NATIVE_PNG.enabled():
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--native-png-map="): _set_map(argument.trim_prefix("--native-png-map="),false)
	# Restore character progress first; an explicit review destination wins over
	# a different map in the isolated legacy save without reusing its pixels.
	if not requested_png_map.is_empty() and requested_png_map != active_map_id: _set_map(requested_png_map, false)
	_normalize_equipment_slots()
	_ensure_job_class_visual()
	_ensure_quickslots_seeded()
	_update_job_skillbar()
	_update_hud()
	# The original renewal replaced the old class-button panel without
	# replacing character creation. Show it only on a fresh playable launch.
	# Headless automated suites explicitly open the picker to test it; the
	# existing movement/input regressions must not inherit an opaque modal.
	world_interactions = WORLD_INTERACTIONS.new()
	world_interactions.name = "WorldInteractions"
	add_child(world_interactions)
	world_interactions.configure(self)
	if creating_character and CHARACTER_ACCOUNT.session.is_empty() and DisplayServer.get_name() != "headless":
		hud.call("open_class_selection",true)
	elif CHARACTER_ACCOUNT.session.is_empty() and _source_gender_needed() and DisplayServer.get_name() != "headless":
		# An existing character has no gender yet; the 523 picture needs one.
		hud.call("open_class_selection",false)
		hud.show_message("523 캐릭터 그림을 쓰려면 성별을 선택하세요.")
	_restore_current523_aden_play.call_deferred()
	_bind_current523_world_map_from_settings.call_deferred()
	_release_idle_original_models.call_deferred()
	# Card slot / option record bakes (only when they failed on this start).
	_note_store_result("card_slots", preload("res://scripts/cards/patch523_slot_data.gd").store_result())
	_note_store_result("card_options", preload("res://scripts/cards/current523_option_combat_input.gd").store_result())
	_show_store_failures()
	BOOT_LOG.step("")
	BOOT_LOG.end("world_ready", boot_started)
	BOOT_LOG.mark("boot_done")
	_finish_boot_loading.call_deferred()

## Device-bake store failures of this start (owner -> {stage, message}).
## A failed owner keeps its previous state and is not activated from a
## partial result; the player is told the cause and that the next start
## retries. Owned items, quantities and enhancement are never changed here.
var store_failures: Dictionary = {}

func _note_store_result(owner: String, result: Variant) -> void:
	if not result is Dictionary or (result as Dictionary).get("ok", true) != false: return
	var reason: String = str(result.get("reason", ""))
	if not reason.ends_with("_store_failed"): return
	store_failures[owner] = {"stage": str(result.get("stage", "")), "message": str(result.get("message", ""))}
	BOOT_LOG.mark("store_failed", {"owner": owner, "stage": str(result.get("stage", ""))})

func _show_store_failures() -> void:
	if store_failures.is_empty() or not is_instance_valid(hud): return
	var lines: PackedStringArray = []
	for owner: String in store_failures:
		var message: String = str(store_failures[owner].get("message", ""))
		lines.append(message if not message.is_empty() else owner)
	hud.append_log("원본 데이터 정리 실패 · " + " / ".join(lines))
	hud.show_message("기기 저장 공간이 부족해 원본 데이터를 정리하지 못했습니다. 공간을 확보한 뒤 다시 시작하면 다시 시도합니다.")

func _process(delta: float) -> void:
	if FRAME_HITCH._trail_until_msec != 0: FRAME_HITCH.trail("world.begin")
	var hitch_started: int = FRAME_HITCH.now()
	var hitch_nested: int = FRAME_HITCH.nested()
	_process_frame(delta)
	FRAME_HITCH.add_self("world", hitch_started, hitch_nested)

## Non-visual systems (quests, monster book, dungeons, content, timed items,
## combinations, inventory upkeep, save timers) run once per SLOW_TICK_SECONDS
## with the accumulated time; only what the player sees move or fight every
## frame stays per frame (2026-11-14: phone heat after one minute).
const SLOW_TICK_SECONDS: float = 1.0
const HUD_REFRESH_SECONDS: float = 0.5
const TARGET_HUD_SECONDS: float = 0.1
const FIELD_TRIGGER_SECONDS: float = 0.2
var _field_trigger_clock: float = 0.0
var _slow_tick_clock: float = 0.0
var _slow_tick_delta: float = 0.0
var _hud_refresh_clock: float = 0.0
var _target_hud_clock: float = 0.0

func _process_frame(delta: float) -> void:
	EQUIPMENT523_INVOKE_DEBUFF.tick(self,delta)
	equipment523.tick(self,delta)
	if death_recovery.blocked(): return
	patch523_npc_spells.tick(delta)
	_update_source_optimization()
	# No auto-save, auto-hunt or keyboard commands until the new class is
	# chosen. Otherwise a default-class save can silently bypass creation.
	if bool(hud.get("class_picker_initial")):
		return
	# The full craft index is no longer needed by play (see
	# _patch523_craft_items_for_ids): no background warm build.
	_slow_tick_delta += delta
	_slow_tick_clock -= delta
	if _slow_tick_clock <= 0.0:
		_slow_tick_clock = SLOW_TICK_SECONDS
		var slow_delta: float = _slow_tick_delta
		_slow_tick_delta = 0.0
		_process_slow(slow_delta)
	_hud_refresh_clock -= delta
	if stat_hud_refresh_pending and _hud_refresh_clock <= 0.0:
		_hud_refresh_clock = HUD_REFRESH_SECONDS
		var hitch_2: int = FRAME_HITCH.now()
		_update_hud()
		FRAME_HITCH.add("hud", hitch_2)
	_advance_native_route_preparation()
	portal_cooldown = maxf(0.0, portal_cooldown - delta)
	auto_repath_timer = maxf(0.0, auto_repath_timer - delta)
	# Stuck = a route walk that is not progressing, per expected step (the
	# original vertical walk is under 1 px per frame when slowed); standing on
	# purpose (attacking, healing, waiting) is not stuck (walk_path_progress.gd).
	if player.auto_enabled and WALK_PATH_PROGRESS.stalled(player.global_position - auto_last_position, player.intended_walk_speed(), delta):
		auto_stuck_time += delta
	else:
		auto_stuck_time = 0.0
	auto_last_position = player.global_position
	# Portals are checked often enough that walking through one is not missed.
	_field_trigger_clock -= delta
	if _field_trigger_clock <= 0.0:
		_field_trigger_clock = FIELD_TRIGGER_SECONDS
		var hitch_3: int = FRAME_HITCH.now()
		_update_field_triggers()
		FRAME_HITCH.add("field_triggers", hitch_3)
	var hitch_4: int = FRAME_HITCH.now()
	ground_loot.tick(delta)
	FRAME_HITCH.add("loot", hitch_4)
	var hitch_6: int = FRAME_HITCH.now()
	loot_pickup.tick(delta)
	FRAME_HITCH.add("loot", hitch_6)
	auto_attack_timer = maxf(0.0, auto_attack_timer - delta)
	_tick_skill_buffs(delta)
	_tick_skill_cooldowns(delta)
	item_life523.tick(delta)
	item_invoke523.tick(delta)
	dungeon_extras523.tick()
	var hitch_7: int = FRAME_HITCH.now()
	if original_skills != null: original_skills.tick(delta)
	FRAME_HITCH.add("skills", hitch_7)
	option_awakening.combat.tick(delta)
	halphas_star.combat.tick(delta)
	totem_combat.tick(delta)
	_advance_skill_charge(delta)
	_tick_automatic_save(delta)
	# M81: the timer advances every frame; a fire runs the manager callback (enable gate, then
	# the heal spell pass). Auto hunt itself keeps its per-frame cadence.
	var heal_tick: Dictionary = ORIGINAL_AUTOSLOT.timer_step(auto_heal_sweep_elapsed, delta)
	auto_heal_sweep_elapsed = float(heal_tick.elapsed)
	var auto_active: bool = player.auto_enabled and not player.is_stunned() and charge_skill.is_empty()
	if bool(heal_tick.fired):
		ORIGINAL_AUTOSLOT.manager_callback(auto_active, true, _auto_quickslot_queued_pass, _auto_quickslot_spell_pass, _auto_quickslot_aux_pass)
	if auto_active:
		var hitch_11: int = FRAME_HITCH.now()
		_run_auto_hunt()
		FRAME_HITCH.add("auto_hunt", hitch_11)
	var hitch_12: int = FRAME_HITCH.now()
	_update_companion(delta)
	FRAME_HITCH.add("companion", hitch_12)
	_target_hud_clock -= delta
	if hud.blocks_keyboard_input():
		if _target_hud_clock <= 0.0:
			_target_hud_clock = TARGET_HUD_SECONDS
			_update_target_hud()
		return
	if Input.is_action_just_pressed("open_inventory"):
		_open_inventory()
	if Input.is_action_just_pressed("open_menu"):
		var menu_started_usec: int = Time.get_ticks_usec()
		hud.toggle_menu()
		_perf_log("메뉴 열기", menu_started_usec)
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
	if _target_hud_clock <= 0.0:
		_target_hud_clock = TARGET_HUD_SECONDS
		_update_target_hud()

## Once per SLOW_TICK_SECONDS; `delta` is the time since the previous call.
var _tutorial523_grant_retry_at: float = 0.0
## TWILIGHT 근사 (사용자 결정 2026-11-16, tutorial523.gd): class skill books only
## the deleted tutorial quests gave are granted once per character.
func _tutorial523_start_grant() -> void:
	if source_save_blocked or equipment_collections.save_blocked or not pending_map_save_record.is_empty(): return
	if tutorial523.get("start_grant") is Dictionary and not tutorial523.get("removed_items") is Dictionary:return
	var now: float = Time.get_unix_time_from_system()
	if now < _tutorial523_grant_retry_at: return
	_tutorial523_grant_retry_at = now + 5.0
	var returning: Dictionary=TUTORIAL523.restored_grants(tutorial523)
	if not returning.is_empty():
		var previous: Dictionary=tutorial523.duplicate(true)
		tutorial523["restored_items"]=returning.ledger
		# Supplier stages physical receipts; that same save publishes our ledger.
		# Neither balance nor the restoration marker moves on a refused save.
		if not preload("res://scripts/loot/patch523_item_inventory.gd").commit(self,returning.grants,{"kind":"tutorial523_exact_item_restore"}):
			tutorial523=previous
			return
		hud.append_log("이전 저장에 기록된 드래곤의 다이아몬드를 되돌렸습니다.")
	if tutorial523.get("start_grant") is Dictionary:return
	var class_id: int = 0
	for id: int in preload("res://scripts/characters/account_store.gd").JOBS:
		if str(preload("res://scripts/characters/account_store.gd").JOBS[id]) == str(job_class): class_id = id
	var grants: Array = TUTORIAL523.start_grants(class_id, tutorial523)
	var before: Dictionary = tutorial523.duplicate(true)
	tutorial523["decision"] = TUTORIAL523.DECISION
	tutorial523["start_grant"] = {"class_id":class_id,"items":grants.map(func(grant: Dictionary) -> int: return int(grant.item_class_id)),"origin":"TWILIGHT 근사 · 튜토리얼 보상 대체"}
	if grants.is_empty(): return
	if not preload("res://scripts/loot/patch523_item_inventory.gd").stage(self,grants,{"kind":"tutorial523_start_grant"}).get("ok",false):
		tutorial523 = before # catalog not ready yet: retry later
		return
	if not preload("res://scripts/loot/patch523_item_inventory.gd").commit(self,grants,{"kind":"tutorial523_start_grant"}):
		tutorial523 = before
		return
	hud.append_log("튜토리얼 삭제 대체 지급(TWILIGHT 근사): 직업 1단계 기술서 %d권" % grants.size())

func _process_slow(delta: float) -> void:
	option_awakening.refresh_timed_relic()
	inventory_automation.maintenance.tick()
	var hitch_0: int = FRAME_HITCH.now()
	monsterbook523_runtime.tick()
	FRAME_HITCH.add("monsterbook", hitch_0)
	var hitch_1: int = FRAME_HITCH.now()
	quest_auto.tick(self)
	_tutorial523_start_grant()
	FRAME_HITCH.add("quests", hitch_1)
	var hitch_5: int = FRAME_HITCH.now()
	dungeon_play.tick(delta)
	var dungeon_split: int = FRAME_HITCH.detail_next("dungeon.play", hitch_5)
	content523.tick(delta)
	FRAME_HITCH.detail("dungeon.content523", dungeon_split)
	FRAME_HITCH.add("dungeon", hitch_5)
	expedition_local.tick(delta)
	_tick_item_buffs(delta)
	ain_refresh_clock -= delta
	if ain_refresh_clock <= 0.0:
		ain_refresh_clock = 1.0
		ain_service.advance_time()
		var ain_extra: int = ain_service.daily_extra(level)
		if ain_extra > 0: hud.append_log("아인하사드 일일 추가 충전 +%d (TWILIGHT 근사: LevelEinasadBlessRecharge)" % ain_extra)
		unconfirmed523.advance_time()
		LOCAL_TOWER.tick(self)
		if not source_dungeon_runs.state.active.is_empty(): _refresh_source_dungeon_panel()
		_update_ain_hud()
	_tick_catalog_recovery(delta)
	combinations.tick(delta)
	var hitch_8: int = FRAME_HITCH.now()
	_run_auto_buff_quickslots(delta)
	FRAME_HITCH.add("items", hitch_8)
	var hitch_9: int = FRAME_HITCH.now()
	_run_auto_item_quickslots(delta)
	FRAME_HITCH.add("items", hitch_9)
	save_timer += delta
	if save_timer >= AUTOSAVE_SECONDS:
		save_timer = 0.0
		_request_general_save()

func _unhandled_input(event: InputEvent) -> void:
	if death_recovery.blocked(): return
	if bool(hud.get("class_picker_initial")): return
	if is_instance_valid(world_interactions): world_interactions.begin(event)

func _load_data() -> void:
	var maps_text: String = FileAccess.get_file_as_string(MAPS_PATH)
	var maps_value: Variant = JSON.parse_string(maps_text)
	if maps_value is Array:
		maps = maps_value as Array
	maps=maps.filter(func(record: Dictionary) -> bool:
		return str(record.get("id","")) not in ["albino_03","albino_04"])
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
	var remake_names: Dictionary = REMAKE_REGISTRY.display_names()
	for map_value: Variant in maps:
		if map_value is Dictionary:
			var map_data: Dictionary = map_value as Dictionary
			if remake_names.has(str(map_data.get("id", ""))): map_data["name"] = remake_names[str(map_data.id)]
			maps_by_id[str(map_data.get("id", ""))] = map_data
	for record: Dictionary in NATIVE_PNG.catalog_entries():
		maps.append(record)
		maps_by_id[str(record.id)] = record
	for record: Dictionary in SOURCE_TRAVEL.catalog_entries():
		original_maps.append(record)
		maps_by_id[str(record.id)] = record
	for record: Dictionary in SOURCE_MAP84.catalog_entries():
		# Verified independent source IDs only; never alias a preserved temple.
		if not maps_by_id.has(str(record.id)):
			maps.append(record)
			maps_by_id[str(record.id)] = record
	var db_text: String = FileAccess.get_file_as_string(DB_PATH)
	var db_value: Variant = JSON.parse_string(db_text)
	if db_value is Dictionary:
		game_db = db_value as Dictionary
	# Pre-November monster records (game_db_v17, the old world catalog and the
	# reviewed L1J monsters) are not used (user decision 2026-11-10): monsters
	# come from the installed 523 pack (SP2 bank and 523 spawn regions).
	monster_db = []
	item_db = game_db.get("아이템", []) as Array
	for item_index: int in range(item_db.size() - 1, -1, -1):
		var item_value: Variant = item_db[item_index]
		if item_value is Dictionary and CONSUMABLE_RULES.is_removed_item(str((item_value as Dictionary).get("name", ""))):
			item_db.remove_at(item_index)
	legacy_skills_db = (game_db.get("스킬", []) as Array).duplicate(true)
	if original_skills == null:
		original_skills = ORIGINAL_SKILLS.new()
		original_skills.configure(self)
	spell_group_conversion.configure(self)
	skills_db = original_skills.catalog.records.duplicate(true)
	_rebuild_skill_record_index()
	_ensure_ammo_items()
	_enrich_weapon_records(item_db)
	CURRENCY_DROP.ensure_items(item_db)
	loot_catalog = LOOT_DROP.build_catalog(item_db)
	var catalog_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if catalog_value is Dictionary:
		catalog_db = catalog_value as Dictionary
	var catalog_items_value: Variant = catalog_db.get("아이템", [])
	if catalog_items_value is Array:
		CURRENCY_DROP.ensure_items(catalog_items_value as Array)
		_enrich_weapon_records(catalog_items_value as Array)
	preload("res://scripts/cards/native_doll_unlock_item.gd").install(catalog_db)
	preload("res://scripts/cards/native_relic_unlock_item.gd").install(catalog_db)
	preload("res://scripts/cards/native_relic_reward_box.gd").install(catalog_db)
	preload("res://scripts/cards/native_card_acquisition.gd").install(catalog_db)
	preload("res://scripts/cards/skill_awakening_service.gd").install_book_definitions(catalog_db)
	preload("res://scripts/cards/source_awakening_items.gd").install_drop_definitions(catalog_db,loot_catalog)
	growth.source523.install(catalog_db,loot_catalog)
	_merge_local_consumables_into_catalog()
	_note_store_result("native_items", LOOT_DROP.PATCH523_DROPS.register_catalog(LOOT_DROP.PATCH523_DROPS.data(), catalog_db))
	CATALOG_GRADES.apply(catalog_db.get("아이템", []) as Array)
	patch523_craft_catalog_status=PATCH523_CRAFT_CATALOG.register(catalog_db,PATCH523_CRAFT_CATALOG.available())
	preload("res://scripts/cards/native_awakening_supply.gd").install_current_definitions(catalog_db)
	_index_catalog_item_sources()
	_load_verified_catalog_options()
	_stash_inven_raw_options()
	_normalize_option_policies()
	_enrich_inven_catalog()
	_index_item_weights()
	catalog_db = BASE508.apply_catalog(catalog_db)
	loot_catalog["patch523_by_name"] = LOOT_DROP.PATCH523_DROPS.catalog_index(catalog_db.get("아이템", []))
	var image_index_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_IMAGE_INDEX_PATH))
	if image_index_value is Dictionary:
		catalog_image_index = image_index_value as Dictionary
	var directional_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIRECTIONAL_PATH))
	if directional_value is Dictionary:
		directional_art = directional_value as Dictionary
	# Source card UI assets are separate from legacy artwork, including equal names.
	for source_category: String in ["변신", "마법인형", "성물"]:
		catalog_image_index[source_category] = {}
	_build_job_classes()
	equipment_collections.configure(self)
	totems.configure_input()
	totem_actions.configure(self)
	totem_combat.configure(self)
	growth.configure(self)
	weapon_mastery.configure(self)
	growth96.configure(self)
	half_elixir.configure(self)
	domination_stones.configure(self)
	routines.configure(self)
	content523.configure(self)
	item_appellation523.configure(self)
	card_swap523.configure(self)
	item_life523.configure(self)
	item_book523.configure(self)
	item_invoke523.configure(self)
	equipment_buff523.configure(self)
	dungeon_extras523.configure(self)
	item_possession523.configure(self)
	skill_cards523.configure(self)
	unconfirmed523.configure(self)

func _refresh_patch523_drop_catalog() -> void:
	_note_store_result("native_items", LOOT_DROP.PATCH523_DROPS.register_catalog(LOOT_DROP.PATCH523_DROPS.data(), catalog_db))
	preload("res://scripts/cards/native_awakening_supply.gd").install_current_definitions(catalog_db)
	_index_catalog_item_sources()
	loot_catalog["patch523_by_name"] = LOOT_DROP.PATCH523_DROPS.catalog_index(catalog_db.get("아이템", []))
	_index_item_weights()
	hud.set_catalog_data(catalog_db, catalog_image_index)
	_refresh_inventory_hud()

func _stash_inven_raw_options() -> void:
	# Preserve authoritative raw source clauses for audit while displaying
	# a local single-player normalized subset in the encyclopedia.
	for category: String in ["아이템", "변신", "마법인형", "성물"]:
		var entries: Variant = catalog_db.get(category, [])
		if not (entries is Array):
			continue
		for value: Variant in entries as Array:
			if not (value is Dictionary):
				continue
			var record: Dictionary = value as Dictionary
			if str(record.get("source", "")) != "inven":
				continue
			if not record.has("originalSourceOptions"):
				record["originalSourceOptions"] = (record.get("sourceOptions", []) as Array).duplicate(true)

func _enrich_inven_catalog() -> void:
	# Keep the entire Inven source catalog, including every original option;
	# attach typed passives only to exact source rows.
	inven_record_index.clear()
	for category: String in ["아이템", "변신", "마법인형", "성물"]:
		var category_index: Dictionary = {}
		var value: Variant = catalog_db.get(category, [])
		if value is Array:
			var entries: Array = value as Array
			for index: int in range(entries.size()):
				if not (entries[index] is Dictionary):
					continue
				var raw: Dictionary = entries[index] as Dictionary
				if str(raw.get("source", "")) != "inven":
					continue
				var annotated: Dictionary = INVEN_OPTIONS.annotate(raw)
				entries[index] = annotated
				var original_name: String = str(annotated.get("name", ""))
				var original_id: String = str(annotated.get("sourceId", ""))
				if not category_index.has(original_name):
					category_index[original_name] = annotated
				if not original_id.is_empty():
					category_index["id:" + original_id] = annotated
		inven_record_index[category] = category_index

func _source_catalog_record(category: String, saved: Dictionary) -> Dictionary:
	# Old physical receipts must not fall back to a same-name active variant.
	if category=="아이템" and RETIRED_ITEMS.record(saved):return saved
	if category == "아이템":
		var migrated: Dictionary = LOOT_DROP.PATCH523_DROPS.migrate_legacy_record(saved)
		if not migrated.is_empty():
			for key: String in ["instance_id","enhance_level","is_engraved","bless_state","source_m_drop_proof","source_m_reward_proof"]:
				if saved.has(key): migrated[key] = saved[key]
			return migrated
	if BASE508.native(saved): return BASE508.canonical(saved)
	if category == "아이템" and saved.get("source_m_native_item",false):
		var current: Dictionary = _catalog_item_from_source_id(str(saved.get("sourceId","")))
		if current.get("source_m_native_item",false) and int(current.get("source_item_class_id",-1)) == int(saved.get("source_item_class_id",-2)) and str(NATIVE_FIELDS.field(current,"source_display_name","")) == str(NATIVE_FIELDS.field(saved,"source_display_name","")) and current.get("source_snapshot") == saved.get("source_snapshot"):
			var updated: Dictionary = current.duplicate(true)
			for key: String in ["instance_id","enhance_level","is_engraved","bless_state","source_m_drop_proof","source_m_reward_proof","source_m_item_id"]:
				if saved.has(key): updated[key] = saved[key]
			return updated
	if str(saved.get("name", "")).is_empty():
		return saved
	# Exact source IDs are authoritative. Preserve explicitly typed, locally
	# equipped records without sourceId; never replace a test/save item's
	# attack/hit fields merely because an Inven entry has the same name.
	if category == "아이템" and str(saved.get("sourceId", "")).is_empty() and (saved.has("atk") or saved.has("hit")):
		return saved
	var catalog_index: Dictionary = inven_record_index.get(category, {}) as Dictionary
	var candidate: Variant = {}
	var item_id: String = str(saved.get("sourceId", ""))
	if not item_id.is_empty():
		candidate = catalog_index.get("id:" + item_id, {})
	if not (candidate is Dictionary) or (candidate as Dictionary).is_empty():
		candidate = catalog_index.get(str(saved.get("name", "")), {})
	if not (candidate is Dictionary) or (candidate as Dictionary).is_empty():
		return _source_enhancement_extra_record(saved,saved) if category=="아이템" else saved
	var original: Dictionary = (candidate as Dictionary).duplicate(true)
	for state_key: String in ["instance_id", "enhance_level", "is_engraved", "bless_state"]:
		if saved.has(state_key):
			original[state_key] = saved[state_key]
	return _source_enhancement_extra_record(original,saved) if category=="아이템" else original

func _source_enhancement_extra_record(base: Dictionary,saved: Dictionary) -> Dictionary:
	if base.get("_patch523_effective_extras",false): return base
	var enhanced: Dictionary=_physical_enhancement_record(saved)
	var instance_id: String=str(saved.get("instance_id",""))
	var rank: int=_item_instance_level(instance_id,str(saved.get("name","")))
	var extras: Dictionary=enhanced.get("enhancement_extra_options",{}).get(str(rank),{})
	if extras.is_empty() or enhanced.get("patch523_effect_basis",{}).get("selection","")!="source_exact_level": return base
	var output: Dictionary=base.duplicate(true)
	for key: String in extras: output[key]=float(output.get(key,0))+float(extras[key])
	output["_patch523_effective_extras"]=true
	return output

func _equipment_inven_sum(key: String) -> float:
	if _stat_memo_depth == 0: return _equipment_inven_sum_uncached(key)
	var memo_key: String = "inven_sum:"+key
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _equipment_inven_sum_uncached(key)
	return _stat_memo[memo_key]

func _equipment_inven_sum_uncached(key: String) -> float:
	var total: float = 0.0
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var raw: Variant = equipped_items.get(slot, {})
		if raw is Dictionary and not (raw as Dictionary).is_empty():
			var record: Dictionary = _source_catalog_record("아이템", raw as Dictionary)
			total += float(record.get(key, 0.0))
	for record: Dictionary in _equipment523_bonus_records():
		total += float(record.get(key, 0.0))
	return total

func _equipped_numeric_sum(key: String) -> float:
	var total: float = 0.0
	for record: Dictionary in _all_equipped_records():
		total += float(record.get(key, 0.0))
	return total


func _index_catalog_item_sources() -> void:
	if catalog_db.has("아이템"):catalog_db["아이템"]=RETIRED_ITEMS.catalog(catalog_db["아이템"])
	patch523_craft_item_cache={}
	_craft_index_warm={}
	catalog_item_by_source_id.clear()
	catalog_item_variant_count.clear()
	for value: Variant in catalog_db.get("아이템", []) as Array:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		var source_id: String = str(record.get("sourceId", ""))
		var item_name: String = str(record.get("name", ""))
		if source_id != "" and not catalog_item_by_source_id.has(source_id):
			catalog_item_by_source_id[source_id] = record
		if item_name != "":
			catalog_item_variant_count[item_name] = int(catalog_item_variant_count.get(item_name, 0)) + 1

func _catalog_item_from_source_id(source_id: String) -> Dictionary:
	var source: Variant = catalog_item_by_source_id.get(source_id, {})
	return source as Dictionary if source is Dictionary else {}

func _normalize_option_policies() -> void:
	# Single-player rule: original PvP numerical bonuses become PvE bonuses;
	# deprecated durability and curse labels must never reach UI/character data.
	for source: Dictionary in [game_db, catalog_db]:
		for category: String in ["아이템", "변신", "마법인형", "성물"]:
			var raw_entries: Variant = source.get(category, [])
			if not (raw_entries is Array):
				continue
			for raw_entry: Variant in raw_entries as Array:
				if not (raw_entry is Dictionary):
					continue
				var entry: Dictionary = raw_entry as Dictionary
				for key: Variant in entry.keys():
					var label: String = str(key)
					if label.begins_with("pvp_"):
						var dest: String = "pve_" + label.substr(4)
						entry[dest] = int(entry.get(dest, 0)) + int(entry.get(key, 0))
						entry.erase(key)
					elif label in ["cursed", "curse", "non_damageable", "damageable", "indestructible", "weapon_damage_prevention"]:
						entry.erase(key)
				if str(entry.get("bless_state", "")).to_lower() in ["cursed", "저주"]:
					entry.erase("bless_state")
				var description: String = str(entry.get("desc", ""))
				var kept: PackedStringArray = []
				for fragment: String in description.split("·"):
					var part: String = fragment.strip_edges()
					if part.contains("손상") or part.contains("저주"):
						continue
					kept.append(part.replace("PVP", "PVE").replace("PvP", "PvE"))
				entry["desc"] = " · ".join(kept)
				# Keep the encyclopedia detail lines aligned with the single-player
				# policies, not just the summary description.
				var options_value: Variant = entry.get("sourceOptions", null)
				if options_value is Array:
					var normalized_options: Array = []
					for raw_option: Variant in options_value as Array:
						var option_text: String = str(raw_option).strip_edges()
						if option_text.contains("손상") or option_text.contains("저주"):
							continue
						normalized_options.append(option_text.replace("PVP", "PVE").replace("PvP", "PvE"))
					entry["sourceOptions"] = normalized_options

func _verified_catalog_record(category: String, source_record: Dictionary) -> Dictionary:
	if category in ["변신","마법인형","성물"] and BASE508.native(source_record):
		var canonical: Dictionary=BASE508.canonical(source_record)
		if canonical.get("source_snapshot","")=="patch523" and not _patch523_card_available(category,canonical):return {}
		return canonical
	source_record = _source_catalog_record(category, source_record)
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
		runtime_description = runtime_description.replace("HP 흡수", "HP 흡수(공격 적중마다 1)")
	merged["desc"] = runtime_description.replace("PVP", "PVE").replace("PvP", "PvE")
	if not merged.has("damage_reduction_ignore"):
		for part: String in str(merged.get("desc", "")).split("·"):
			var segment: String = part.strip_edges()
			if segment.begins_with("대미지 리덕션 무시"):
				merged["damage_reduction_ignore"] = maxi(0, ITEM_OPTIONS._signed_integer(segment.substr("대미지 리덕션 무시".length())))
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
	_refresh_equipment_effects()
	return bool(equipment_effects.hp_absorption)

func _has_recovery_effect(key: String) -> bool:
	_refresh_equipment_effects()
	return bool(equipment_effects.get(key,false))

func _refresh_equipment_effects() -> void:
	if not equipment_effects_dirty:return
	equipment_effects_dirty=false
	equipment_effect_rebuilds+=1
	var quest_recovery_hp: int=0;var quest_recovery_mp: int=0
	var flags: Dictionary={"hpAbsoluteRecovery":false,"hpRecoveryTick":false,"mpRecoveryTick":false,"hp_absorption":false,"damage_amp_pct":0.0}
	var native_passives: Dictionary = {}
	var source_mp_regeneration: int=0
	for record: Dictionary in _all_equipped_records():
		var effects: Dictionary = preload("res://scripts/loot/patch523_passive_items.gd").effects(record)
		for key: String in effects: native_passives[key] = int(native_passives.get(key,0))+int(effects[key])
		var source_id: String=PATCH523_ENHANCE.item_id(record)
		var source_mp: bool=patch523_equipment.has_equipment_runtime(source_id) and patch523_equipment.catalog_identity_matches(record,source_id)
		var original: Dictionary=quest_item_provider.equipment_owner.recovery_for_worn(self,record)
		quest_recovery_hp+=int(original.get("hp",0));quest_recovery_mp+=int(original.get("mp",0))
		for key: String in ["hpAbsoluteRecovery","hpRecoveryTick","mpRecoveryTick"]:
			var base_value: int=int(record.get(key,0))
			if key=="mpRecoveryTick" and source_mp:
				source_mp_regeneration+=base_value
				continue
			if base_value>0:flags[key]=true
		if not record.has("source_card_attack_drain_hp") and (bool(record.get("hpAbsorption",record.get("hp_absorption",false))) or str(record.get("desc","")).contains("HP 흡수")):
			flags.hp_absorption=true
		flags.damage_amp_pct=float(flags.damage_amp_pct)+float(record.get("damage_amp_pct",0.0))
	flags.hp_tick_amount=quest_recovery_hp+(UNIQUE_RECOVERY_AMOUNT if bool(flags.hpAbsoluteRecovery) or bool(flags.hpRecoveryTick) else 0)+int(card_collections.bonus("hp_regeneration:flat"))+halphas_star.catalog_bonus("hp_regen")
	flags.mp_tick_amount=quest_recovery_mp+(UNIQUE_RECOVERY_AMOUNT if bool(flags.mpRecoveryTick) else 0)+source_mp_regeneration+_enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER,"mp_recovery")+int(growth.bonus("mp_regeneration:flat"))+int(card_collections.bonus("mp_regeneration:flat"))
	flags.mp_tick_amount+=int(card_collections.bonus("absolute_mp_regeneration:flat"))+halphas_star.catalog_bonus("mp_regen")
	flags.mp_tick_amount+=int(monsterbook523_runtime.extra_stats().get("mp_regeneration",0))
	flags.source_item_passives = native_passives
	flags.hp_tick_amount += EQUIPMENT523_COMBAT.regeneration(_all_equipped_records(),"hp")
	flags.mp_tick_amount += EQUIPMENT523_COMBAT.regeneration(_all_equipped_records(),"mp")
	equipment_effects=flags

func _invalidate_equipment_static() -> void:
	combinations.invalidate()
	card_collections.invalidate()
	equipment_effects_dirty=true
	equipment_records_dirty=true

func _deal_successful_player_hit(target: TwilightMonster, normal_damage: int, critical: bool = false, attack_kind: String="", main_target: bool=true, by_spell: bool=false, context: Dictionary={}, ordinary_attack: bool=false, relic_attack_context: Dictionary={}) -> void:
	if _source_combat_targets_hidden(): return
	if target == null or not is_instance_valid(target) or target.dead:
		return
	if main_target and not equipment523_can_detect(target): return
	var locked: TwilightMonster = _equipment523_locked_target()
	if main_target and locked != null and target != locked: return
	var deal_stage: int = FRAME_HITCH.now()
	normal_damage+=card_collections.death_damage_bonus()
	normal_damage+=preload("res://scripts/crafting/patch523_final_blow.gd").conditional_magic_damage(self,target,by_spell)
	normal_damage+=PATCH523_EQUIPMENT_COMBAT.fear_flat_ignore(self,target,by_spell)
	if original_skills != null: normal_damage = original_skills.outgoing_damage(normal_damage, original_skills.attack_context(attack_kind, by_spell, true, main_target) if ordinary_attack else relic_attack_context)
	# TWILIGHT 근사: 대장간 연마 수식어(태고의 PierceDamageReductionPercent 5% = NC "대미지 증가 +5%").
	var honing_percent: float = preload("res://scripts/honing/honing523_service.gd").damage_percent(self)
	if honing_percent > 0.0: normal_damage = int(normal_damage * (1.0 + honing_percent / 100.0))
	if target.get_meta("dungeon_play_role","")=="Boss":normal_damage=int(round(normal_damage*(1.0+dungeon_play.modifier("boss_damage")/100.0)))
	var stolen: int = 0
	var drain: int = (1 if _has_hp_absorption() else 0)+int(growth.bonus("hp_drain:flat"))
	if drain>0:
		# Extra damage and healing represent the exact same amount of
		# HP stolen from the target, capped by its remaining HP.
		stolen = mini(drain, maxi(0, target.hp))
	var settings: Dictionary=PATCH523_ENHANCE.policy()
	var source_attack: bool=not by_spell or settings.get("source_drain_scope","")=="all_successful_hits"
	if source_attack:
		stolen+=mini(maxi(0,target.hp-stolen),maxi(0,int(_equipment_inven_sum("source_attack_drain_hp")+_equipped_numeric_sum("source_card_attack_drain_hp"))))
		var drain_mp: int=maxi(0,int(_equipment_inven_sum("source_attack_drain_mp")))
		for worn: Dictionary in _all_equipped_records():
			if str(worn.get("slot","")).is_empty():continue
			drain_mp+=maxi(0,int(worn.get("mpAbsorption",0)))
		drain_mp=mini(drain_mp,mini(maxi(0,target.mp),maxi(0,_effective_max_mp()-mp)))
		if drain_mp>0:
			target.mp-=drain_mp;mp+=drain_mp
			hud.append_log("MP 흡수 · %s MP -%d / 내 MP +%d" % [target.monster_name,drain_mp,drain_mp])
	if stolen > 0:
		var previous_hp: int = hp
		hp = mini(_effective_max_hp(), hp + stolen)
		hud.append_log("HP 흡수 · %s HP -%d / 내 HP +%d" % [target.monster_name, stolen, hp - previous_hp])
	deal_stage = FRAME_HITCH.detail_next("deal.bonuses_drain", deal_stage)
	_refresh_equipment_effects()
	deal_stage = FRAME_HITCH.detail_next("deal.equipment_effects", deal_stage)
	if ordinary_attack: stolen += preload("res://scripts/loot/patch523_passive_items.gd").drain(self,target,stolen)
	if attack_kind not in ["melee","ranged","magic"]:attack_kind=feedback_kind if resolving_combat_action else _current_attack_kind()
	var kind: String = attack_kind
	var oracle:Script=preload("res://scripts/loot/native_manual_scrolls523.gd")
	var oracle_amp:int=oracle.oracle_damage_percent(active_item_buffs,bool(target.get_meta("is_player_combatant",false))) if active_item_buffs.has(oracle.ORACLE_KEY) else 0
	var amplification: float = clampf(float(equipment_effects.damage_amp_pct)+weapon_mastery.damage_amplification(kind,_mastery_actual_weapon_type())+card_collections.damage_amplification(kind)+monsterbook523_runtime.outgoing_percent(attack_kind)+oracle_amp, 0.0, 300.0)
	var adjusted_damage: int = maxi(1, int(round(float(normal_damage) * (1.0 + amplification / 100.0))))
	adjusted_damage=growth.combat.outgoing(adjusted_damage,attack_kind)
	adjusted_damage=preload("res://scripts/crafting/patch523_final_blow.gd").damage(self,adjusted_damage,by_spell,target)
	adjusted_damage+=_source_elemental_flat_damage(target,by_spell)
	if target.source_m_npc_id>0:
		for record: Dictionary in _all_equipped_records():
			var scoped: Variant = record.get("source_card_npc_group_damage")
			if scoped is Dictionary:adjusted_damage+=int(scoped.get(target.source_m_npc_id,0))
	if target.is_undead() and (not by_spell or settings.get("source_undead_scope","")=="all_successful_hits"):
		var maximum: int=maxi(0,int(_equipment_inven_sum("source_undead_damage_max")))
		if maximum>0:
			var minimum: int=clampi(int(settings.get("source_undead_damage_min",1)),0,maximum)
			adjusted_damage+=rng.randi_range(minimum,maximum)
	var before_reduction: int=adjusted_damage
	if original_skills != null: adjusted_damage = original_skills.target_damage(adjusted_damage,target,attack_kind)
	var hit_context: Dictionary=context.duplicate(true)
	hit_context.flat_reduction=maxi(0,before_reduction-adjusted_damage)
	if attack_kind == "magic" and target.has_meta("magic_shield_reduction_percent"):
		var shield: float = float(target.get_meta("magic_shield_reduction_percent"))
		var pierce: float = clampf(_equipped_numeric_sum("source_card_magic_penetration_pct"),0.0,100.0)
		adjusted_damage = half_elixir.shield_damage(adjusted_damage, shield*(1.0-pierce/100.0))
	hit_context.pvp=bool(target.get_meta("is_player_combatant",false))
	hit_context.undead=target.is_undead()
	if not hit_context.has("final_blow"):hit_context.final_blow=growth.guardian_combat.roll(growth.guardian_combat.final_blow_chance())
	if not hit_context.has("percent_reduction"):hit_context.percent_reduction=float(target.get_meta("source_received_reduction_percent",0))
	var source_combat: Dictionary=unconfirmed523.combat_context(kind,hit_context)
	if int(source_combat.undead_max_damage)>0:
		adjusted_damage+=rng.randi_range(1,int(source_combat.undead_max_damage))
	hit_context=unconfirmed523.outgoing_context(kind,hit_context)
	adjusted_damage=growth.guardian_combat.outgoing(target,adjusted_damage,critical,kind,hit_context)
	if titles.bonus("FinalBlowProbability")>0: adjusted_damage=titles.outgoing(adjusted_damage,rng.randf())
	var final: Dictionary=card_collections.final_blow(adjusted_damage,rng,_equipped_numeric_sum("source_card_final_blow_pct"),int(_equipped_numeric_sum("source_card_final_blow_damage")),_equipped_numeric_sum("source_card_final_blow_scale")) if ordinary_attack else {"damage":adjusted_damage,"triggered":false}
	if final.triggered:hud.append_log("결정타 · "+target.monster_name)
	var available_hp: int=maxi(0,target.hp-stolen)
	var available_mp: int=target.mp
	var prior_hp: int=hp;var prior_mp: int=mp
	# Source flat elemental amounts use separate channels; legacy element_bonus is percent.
	var source_records: Array[Dictionary] = _all_equipped_records()
	var source_resistance: Dictionary = {}
	for element_channel: String in EQUIPMENT523_COMBAT.CHANNELS:
		source_resistance[element_channel] = target.elemental_resistance_percent(element_channel)
	var equipment523_extra: int = EQUIPMENT523_COMBAT.elemental_extra(source_records,source_resistance,rng,float(equipment523.policy.get("elemental_critical_multiplier",2.0)),float(target.get_meta("equipment523_element_critical_resistance",0.0)))
	equipment523_extra += EQUIPMENT523_COMBAT.death_extra(source_records,float(equipment523.policy.get("death_damage_per_point",0.0)))
	patch523_npc_spells.extensions.begin_incoming(target,int(final.damage)+equipment523_extra+stolen,kind,by_spell)
	target.set_meta("title523_direct_life",target.life_id)
	deal_stage = FRAME_HITCH.detail_next("deal.damage_math", deal_stage)
	target.take_damage(int(final.damage) + equipment523_extra + stolen, critical or bool(final.triggered))
	deal_stage = FRAME_HITCH.detail_next("deal.take_damage", deal_stage)
	if not target.dead: target.set_meta("title523_direct_life",-1)
	patch523_npc_spells.extensions.incoming.erase(target.get_instance_id())
	growth.guardian_combat.after_hit(target,critical,kind,main_target,by_spell,available_hp,available_mp)
	equipment523.on_hit(self,target,kind,main_target,by_spell,available_hp,available_mp)
	if stolen > 0 or hp!=prior_hp or mp!=prior_mp:
		_refresh_combat_hud()
	FRAME_HITCH.detail("deal.after_hit", deal_stage)

func _tick_catalog_recovery(delta: float) -> void:
	source_deadline_check_elapsed += maxf(0.0,delta)
	if source_deadline_check_elapsed >= 1.0:
		source_deadline_check_elapsed = 0.0
		if _enforce_patch523_equipment_requirements():
			hp = mini(hp,_effective_max_hp());mp = mini(mp,_effective_max_mp())
			_refresh_speed_modifiers();_update_hud();_request_deferred_save()
	var elapsed: float = maxf(0.0, delta)
	_refresh_equipment_effects()
	preload("res://scripts/loot/patch523_passive_items.gd").tick(self,elapsed)
	var hp_tick_amount: int = int(equipment_effects.hp_tick_amount)
	var hp_enabled: bool = hp_tick_amount>0
	var mp_tick_amount: int = int(equipment_effects.mp_tick_amount)
	var mp_enabled: bool = mp_tick_amount>0
	var changed: bool = false
	if hp_enabled:
		hp_recovery_elapsed += elapsed
		if hp_recovery_elapsed >= UNIQUE_RECOVERY_INTERVAL:
			var cycles: int = int(floor(hp_recovery_elapsed / UNIQUE_RECOVERY_INTERVAL))
			hp_recovery_elapsed = fmod(hp_recovery_elapsed, UNIQUE_RECOVERY_INTERVAL)
			var old_hp: int = hp
			hp = mini(_effective_max_hp(), hp + cycles * hp_tick_amount)
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
			mp = mini(_effective_max_mp(), mp + cycles * mp_tick_amount)
			if mp > old_mp:
				hud.append_log("MP 자동회복 · +%d" % (mp - old_mp))
				changed = true
	else:
		mp_recovery_elapsed = 0.0
	if changed:
		_refresh_combat_hud()

func _catalog_stat_sum(key: String) -> int:
	if _stat_memo_depth == 0: return _catalog_stat_sum_uncached(key)
	var memo_key: String = "catalog_sum:"+key
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _catalog_stat_sum_uncached(key)
	return _stat_memo[memo_key]

func _catalog_stat_sum_uncached(key: String) -> int:
	var result: int = 0
	for category: String in ["변신", "마법인형", "성물"]:
		var record_value: Variant = equipped_catalog.get(category, {})
		if record_value is Dictionary and not (record_value as Dictionary).is_empty():
			var entry: Dictionary = _verified_catalog_record(category, record_value as Dictionary)
			result += int(entry.get(key, 0))
	return result + equipment_collections.catalog_bonus(key) + card_collections.catalog_bonus(key) + option_awakening.catalog_bonus(key) + growth.catalog_bonus(key) + halphas_star.catalog_bonus(key) + weapon_mastery.catalog_bonus(key, _mastery_actual_weapon_type()) + combinations.catalog_bonus(key) + int(half_elixir.stat_record().get(key, 0)) + (totems.bonus("PVEDamageReduction") if key == "pve_damage_reduction" else 0) + monsterbook523_runtime.catalog_bonus(key) + unconfirmed523.catalog_bonus(key) + card_deck_bonus.catalog_bonus(key)

func source_active_card_spell_bonus(spell_id: int, field: String) -> float:
	if spell_id<=0:return 0.0
	var sum_value: float = 0.0
	for record: Dictionary in _all_equipped_records():
		var spells: Variant = record.get("source_card_spell_options")
		if spells is Dictionary and spells.has(spell_id):sum_value+=float(spells[spell_id].get(field,0.0))
	return sum_value

func _transformation_skill_bonus(skill_name: String, kind: String) -> float:
	var record_value: Variant = equipped_catalog.get("변신", {})
	if not (record_value is Dictionary) or (record_value as Dictionary).is_empty():
		return 0.0
	var record: Dictionary = _verified_catalog_record("변신", record_value as Dictionary)
	return TRANSFORM_SKILL.amount(record, job_class, skill_name, kind)

func _skill_cooldown_factor() -> float:
	if _stat_memo_depth == 0: return _skill_cooldown_factor_uncached()
	var memo_key: String = "cooldown_factor"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _skill_cooldown_factor_uncached()
	return _stat_memo[memo_key]

func _skill_cooldown_factor_uncached() -> float:
	var cast_bonus: float = original_skills.stat("castSpeed") if original_skills != null else 0.0
	cast_bonus += unconfirmed523.bonus("cast_speed:percent")
	if PATCH523_ENHANCE.policy().get("cast_speed_consumer","")=="existing_skill_cooldown_factor":cast_bonus+=_equipment_inven_sum("castSpeed")+_equipped_numeric_sum("source_card_cast_speed_pct")+card_deck_bonus.catalog_bonus("castSpeed")+_active_item_buff_percent("cast_speed")

	if equipment523.policy.get("set_cast_speed_mode","") == "cooldown":
		cast_bonus += _equipped_numeric_sum("equipment523_set_cast_speed_pct")
	return clampf(1.0 - (float(_catalog_stat_sum("skillCooldownPct")) + cast_bonus) / 100.0, 0.1, 1.0)

func _effective_max_mp(item_buff_override: Variant = null) -> int:
	if _stat_memo_depth == 0 or not (item_buff_override == null): return _effective_max_mp_uncached(item_buff_override)
	var memo_key: String = "max_mp"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _effective_max_mp_uncached(item_buff_override)
	return _stat_memo[memo_key]

func _effective_max_mp_uncached(item_buff_override: Variant = null) -> int:
	var added: int = _catalog_stat_sum("mpFlat") + _active_item_buff_total("mp_flat",item_buff_override)
	for record: Dictionary in _all_equipped_records():
		if str(record.get("slot", "")) != "" or bool(record.get("equipment523_synthetic", false)):
			var typed_mp: int = int(record.get("mpFlat", record.get("max_mp_bonus", 0)))
			added += typed_mp
			var description: String = str(record.get("desc", ""))
			for fragment: String in description.split("·"):
				var segment: String = fragment.strip_edges()
				if typed_mp == 0 and (segment.begins_with("MP ") or segment.begins_with("Max MP ")):
					added += maxi(0, ITEM_OPTIONS._signed_integer(segment.substr(3 if segment.begins_with("MP ") else 7)))
	var flat: int = max_mp + added + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "mp") + int(original_skills.stat("mp") if original_skills != null else 0)
	var skill_percent: float=original_skills.stat("mpPct") if original_skills!=null else 0.0
	return maxi(1, int(round(float(flat) * (1.0 + _equipped_numeric_sum("mpPct") + skill_percent))))

## While the world starts, a dozen services register items and each asks for
## the weight index to be rebuilt (about 30,000 original records per pass).
## Nothing reads the index in between, so those requests are remembered and
## the index is built once, before the map and the save are loaded.
var _weight_index_deferred: bool = false
var _weight_index_pending: bool = false
func _flush_item_weight_index() -> void:
	_weight_index_deferred = false
	if _weight_index_pending:
		_weight_index_pending = false
		_index_item_weights()

## Full index passes so far (tests check the start builds it once).
var item_weight_index_builds: int = 0
func _index_item_weights() -> void:
	if _weight_index_deferred:
		_weight_index_pending = true
		return
	item_weight_index_builds += 1
	patch523_craft_item_cache={}
	_craft_index_warm={}
	var rules: Dictionary = _item_weight_rules()
	var next_weight_index: Dictionary = {}
	for source: Variant in [catalog_db.get("아이템", []), item_db]:
		if not (source is Array):
			continue
		for entry: Variant in source as Array:
			if not _weight_index_entry(entry, rules, next_weight_index):
				return
	# Keep existing dictionary aliases while publishing a complete input index.
	item_weight_index.clear()
	item_weight_index.merge(next_weight_index)

## The weight rules file (res://, read-only at run time): parsed once.
var _item_weight_rules_cache: Dictionary = {}
func _item_weight_rules() -> Dictionary:
	if not _item_weight_rules_cache.is_empty(): return _item_weight_rules_cache
	var rules: Dictionary = {"type_defaults":{}, "overrides":{}, "source_weight_policy":{}, "original_weight_names":{}}
	var path: String = "res://data/item_weight_rules.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			rules.type_defaults = (parsed as Dictionary).get("type_defaults", {}) as Dictionary
			rules.overrides = (parsed as Dictionary).get("overrides", {}) as Dictionary
			var declared_source_policy: Variant = parsed.get("current523_source_weight")
			if declared_source_policy is Dictionary: rules.source_weight_policy = declared_source_policy
			# User decision "원작대로": these keep the original estimate, including zero.
			var original_items: Variant = parsed.get("current523_original_weight_overrides",{}).get("items",{}) if parsed.get("current523_original_weight_overrides") is Dictionary else {}
			if original_items is Dictionary: rules.original_weight_names = original_items
	_item_weight_rules_cache = rules
	return rules

## One catalog entry's weight into `index`; false when an original weight
## input is unresolved (the caller keeps the existing index).
func _weight_index_entry(entry: Variant, rules: Dictionary, index: Dictionary) -> bool:
	if not (entry is Dictionary):
		return true
	var record: Dictionary = entry as Dictionary
	var name_value: String = str(record.get("name", ""))
	if name_value.is_empty():
		return true
	var type_defaults: Dictionary = rules.type_defaults
	var overrides: Dictionary = rules.overrides
	var source_weight: Dictionary = ITEM_OPTIONS._bulk_source_weight_input(record,rules.source_weight_policy)
	if source_weight.get("applicable",false):
		if not source_weight.get("ok",false):
			push_warning("원문 무게 입력 보류 · 기존 인덱스 보존: "+str(source_weight.get("problem","입력 미확정")))
			return false
		# Exact source zero remains zero; host positive-default bounds below
		# still belong only to the pre-existing legacy input path.
		index[name_value] = int(source_weight.weight)
		return true
	var raw_weight: int = int(overrides.get(name_value, ITEM_OPTIONS.item_weight(record, type_defaults)))
	if rules.original_weight_names.has(name_value) and overrides.has(name_value):
		index[name_value] = maxi(0, int(overrides[name_value]))
		return true
	if record.get("source_weight_origin") == "current523_original_estimate":
		index[name_value] = maxi(0, int(record.get("weight", 0)))
		return true
	if record.has("growth96_item_id"):
		index[name_value] = maxi(0,int(record.weight))
		return true
	if raw_weight <= 0 and str(record.get("slot", "")) != "currency" and str(record.get("type", "")) != "화폐" and not record.get("monsterbook_source_item",false):
		raw_weight = maxi(1, int(type_defaults.get(str(record.get("type", "")), 3)))
	index[name_value] = maxi(0, raw_weight)
	return true

## Records appended to catalog_db["아이템"] / item_db after the sizes given
## (e.g. a box's first-seen reward): their weights only, as the full pass
## would publish them (a later entry of the same name wins, catalog first).
## Anything else (shrunk lists, a name already indexed, a deferred start)
## falls back to the full pass.
func _index_item_weights_appended(catalog_size: int, item_db_size: int) -> void:
	var catalog: Variant = catalog_db.get("아이템", [])
	if not catalog is Array or not item_db is Array: _index_item_weights(); return
	if catalog.size() == catalog_size and item_db.size() == item_db_size: return
	if _weight_index_deferred or catalog.size() < catalog_size or item_db.size() < item_db_size: _index_item_weights(); return
	var rules: Dictionary = _item_weight_rules()
	var added: Dictionary = {}
	for pair: Array in [[catalog, catalog_size], [item_db, item_db_size]]:
		for position: int in range(int(pair[1]), (pair[0] as Array).size()):
			var entry: Variant = pair[0][position]
			if entry is Dictionary and item_weight_index.has(str(entry.get("name", ""))): _index_item_weights(); return
			if not _weight_index_entry(entry, rules, added): return
	patch523_craft_item_cache={}
	_craft_index_warm={}
	item_weight_index.merge(added, true)

func _inventory_total_weight() -> int:
	if _stat_memo_depth == 0: return _inventory_total_weight_uncached()
	var memo_key: String = "weight"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _inventory_total_weight_uncached()
	return _stat_memo[memo_key]

func _inventory_total_weight_uncached() -> int:
	var total: int = 0
	for name_value: Variant in inventory.keys():
		# Held source rewards are provenance stacks until their item adapter is
		# available; legacy default weight must not turn them into carried gear.
		if str(name_value).begins_with("[원본 보상] "): continue
		total += maxi(0, int(inventory.get(name_value, 0))) * maxi(0, int(item_weight_index.get(str(name_value), 0 if str(name_value) == "아데나" else 3)))
	return total

func _carrying_capacity() -> int:
	if _stat_memo_depth == 0: return _carrying_capacity_uncached()
	var memo_key: String = "carrying"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _carrying_capacity_uncached()
	return _stat_memo[memo_key]

func _carrying_capacity_uncached() -> int:
	var skill_capacity := int(original_skills.stat("weight")) if original_skills != null else 0
	return skill_capacity + ITEM_OPTIONS.carrying_capacity(_effective_attribute("CON")) + _catalog_stat_sum("weightBonus") + int(_equipment_inven_sum("weightBonus")) + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "capacity") + _equipped_bless_bonus("capacity") + _active_item_buff_total("carry")

func _inventory_encumbrance_multiplier() -> float:
	if _stat_memo_depth == 0: return _inventory_encumbrance_multiplier_uncached()
	var memo_key: String = "encumbrance"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _inventory_encumbrance_multiplier_uncached()
	return _stat_memo[memo_key]

func _inventory_encumbrance_multiplier_uncached() -> float:
	return ITEM_OPTIONS.encumbrance_multiplier(_inventory_total_weight(), _carrying_capacity())

# Blessing is attached to one item_instances ID, not to a shared item name.
# Only the exact equipped physical item contributes its blessing; never patch
# a source catalog record or stack of identically named equipment.
func _equipped_bless_bonus(stat: String) -> int:
	if _stat_memo_depth == 0: return _equipped_bless_bonus_uncached(stat)
	var memo_key: String = "bless:"+stat
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _equipped_bless_bonus_uncached(stat)
	return _stat_memo[memo_key]

func _equipped_bless_bonus_uncached(stat: String) -> int:
	var total: int = 0
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var worn: Variant = equipped_items.get(slot, {})
		if not (worn is Dictionary) or (worn as Dictionary).is_empty():
			continue
		var equipped: Dictionary = worn as Dictionary
		var item_id: String = str(equipped.get("instance_id", ""))
		if item_id.is_empty() or not item_instances.has(item_id):
			continue
		var physical: Dictionary = item_instances[item_id] as Dictionary
		if str(physical.get("name", "")) != str(equipped.get("name", "")):
			continue
		var record: Dictionary = equipped
		if physical.get("record", {}) is Dictionary and not (physical.get("record", {}) as Dictionary).is_empty():
			record = physical["record"] as Dictionary
		if not EQUIPMENT_BLESSING.is_blessed(physical, record):
			continue
		var kind: String = _enhancement_kind_for_record(record)
		record=PATCH523_ENHANCE.prepare(patch523_equipment,record,2)
		var bonus: Dictionary = EQUIPMENT_BLESSING.bonus_for(str(record.get("grade", "")), kind,record)
		total += int(bonus.get(stat, 0))
	return total

func _equipment_attribute_bonus(stat: String) -> int:
	if _stat_memo_depth == 0: return _equipment_attribute_bonus_uncached(stat)
	var memo_key: String = "equip_attr:"+stat
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _equipment_attribute_bonus_uncached(stat)
	return _stat_memo[memo_key]

func _equipment_attribute_bonus_uncached(stat: String) -> int:
	var result: int = 0
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var entry: Variant = equipped_items.get(slot, {})
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			result += ITEM_OPTIONS.attribute(_source_catalog_record("아이템", entry as Dictionary), stat)
	for record: Dictionary in _equipment523_bonus_records():
		result += ITEM_OPTIONS.attribute(record, stat)
	return result + _source_enchantment_extra([],stat.to_lower()) + int(equipment_collections.bonus(stat.to_lower()+":flat") + card_collections.bonus(stat.to_lower()+":flat") + growth.bonus(stat.to_lower()+":flat"))

func _effective_attribute(stat: String) -> int:
	if _stat_memo_depth == 0: return _effective_attribute_uncached(stat)
	var memo_key: String = "attr:"+stat
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _effective_attribute_uncached(stat)
	return _stat_memo[memo_key]

func _effective_attribute_uncached(stat: String) -> int:
	var base: int = 0
	match stat:
		"STR": base = str_stat
		"DEX": base = dex_stat
		"CON": base = con_stat
		"INT": base = int_stat
		"WIS": base = wis_stat
		"CHA": base = cha_stat
		"DTH": return combinations.catalog_bonus("dthFlat")
		_: return 0
	var key: String = stat.to_lower() + "Flat"
	var total: int=base + _equipment_attribute_bonus(stat) + _catalog_stat_sum(key) + _active_item_buff_total(key) + int(original_skills.stat(stat.to_lower()) if original_skills != null else 0)
	if stat not in ["STR","DEX","INT"]:return total
	var percent: float=maxf(0.0,_equipment_inven_sum(stat.to_lower()+"Percent"))
	var settings: Dictionary=PATCH523_ENHANCE.policy()
	var basis: int=base if settings.get("attribute_percent_basis","")=="base_only" else total
	var increase: float=float(basis)*percent/100.0
	return total+(int(round(increase)) if settings.get("attribute_percent_rounding","")=="nearest" else int(floor(increase)))

func _equipment_accuracy_bonus(kind: String) -> int:
	var result: int = (_equipped_bless_bonus("accuracy") if kind in ["melee", "ranged"] else 0) + _source_enchantment_extra(ACCESSORY_EQUIPMENT_SLOTS,kind+"_accuracy") + (_source_enchantment_extra(["weapon"],"accuracy") if kind in ["melee","ranged"] else 0)
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var entry: Variant = equipped_items.get(slot, {})
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			result += ITEM_OPTIONS.accuracy(_source_catalog_record("아이템", entry as Dictionary), kind)
	for record: Dictionary in _equipment523_bonus_records():
		result += ITEM_OPTIONS.accuracy(record, kind)
	return result + int(titles.bonus({"melee":"MeleeHit","ranged":"RangeHit","magic":"MagicHit"}.get(kind,""))) + int(growth.bonus(kind+"_hit:flat") + equipment_collections.bonus(kind+"_hit:flat") + equipment_collections.bonus("pve_"+kind+"_hit:flat") + card_collections.bonus(kind+"_hit:flat") + card_collections.bonus("pve_"+kind+"_hit:flat")) + int(unconfirmed523.bonus(kind+"_hit:flat"))

func _equipment_potion_heal_stat(label: String) -> int:
	var sum: int = 0
	var typed_key: String = "potionHealFlat" if label == "물약 회복량" else "potionHealPct"
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var entry: Variant = equipped_items.get(slot, {})
		if not (entry is Dictionary) or (entry as Dictionary).is_empty():
			continue
		var record: Dictionary = _source_catalog_record("아이템", entry as Dictionary)
		sum += int(record.get(typed_key, ITEM_OPTIONS._description_bonus(record, label)))
	for record: Dictionary in _equipment523_bonus_records():
		sum += int(record.get(typed_key, 0))
	return sum

func _equipment_additional_damage(kind: String) -> int:
	var projected: int=0
	if PATCH523_ENHANCE.policy().get("source_typed_flat_ignore_consumer")=="existing_typed_flat_damage_projection":projected=PATCH523_EQUIPMENT_COMBAT.typed_flat_ignore(self,kind)
	var result: int = projected + PATCH523_EQUIPMENT_COMBAT.pvp_flat_ignore(self,kind) + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, kind + "_damage") + int(_equipment_inven_sum("pve_" + kind + "_damage")) + int(_equipment_inven_sum(kind + "_reduction_ignore")) + int(growth.bonus(kind+"_reduction_ignore:flat"))
	if kind in ["melee", "ranged"]:
		result += _equipped_bless_bonus("damage")
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var entry: Variant = equipped_items.get(slot, {})
		if entry is Dictionary and not (entry as Dictionary).is_empty():
			var item: Dictionary = _source_catalog_record("아이템", entry as Dictionary)
			result += ITEM_OPTIONS.additional_damage(item, kind)
			var typed_ignore: int = int(item.get("damage_reduction_ignore", item.get("damageReductionIgnore", 0)))
			result += typed_ignore
			if typed_ignore == 0:
				for fragment: String in str(item.get("desc", "")).split("·"):
					var segment: String = fragment.strip_edges()
					if segment.begins_with("대미지 리덕션 무시"):
						result += maxi(0, ITEM_OPTIONS._signed_integer(segment.substr("대미지 리덕션 무시".length())))
	for record: Dictionary in _equipment523_bonus_records():
		result += ITEM_OPTIONS.additional_damage(record, kind)
		result += int(record.get("damage_reduction_ignore", record.get("damageReductionIgnore", 0)))
	return result + titles.pve_pierce() + int(titles.bonus({"melee":"MeleeDamage","ranged":"RangeDamage","magic":"MagicDamage"}.get(kind,""))) + int(growth.bonus(kind+"_damage:flat") + growth.bonus("pve_"+kind+"_damage:flat") + equipment_collections.bonus(kind+"_damage:flat") + equipment_collections.bonus("pve_"+kind+"_damage:flat") + card_collections.bonus(kind+"_damage:flat") + card_collections.bonus("pve_"+kind+"_damage:flat")) + int(unconfirmed523.bonus(kind+"_damage:flat"))

func _weapon_size_adjustment(target: TwilightMonster) -> int:
	# Kept for older source audit callers; not used in the live damage path.
	if target == null:
		return 0
	var label: String = str(target.get_meta("size_class", "small")).to_lower()
	return ITEM_OPTIONS.weapon_size_adjustment(_equipped_weapon_record(), label == "large")

func _roll_weapon_damage(target: TwilightMonster, source_invokes: bool = false, resolved_weapon: Variant = null) -> int:
	if target == null:
		return 0
	var is_large: bool = str(target.get_meta("size_class", "small")).to_lower() == "large"
	var weapon: Dictionary = resolved_weapon if resolved_weapon is Dictionary else _equipped_weapon_record()
	var maximum: int = ITEM_OPTIONS.weapon_size_damage(weapon, is_large)
	var rolled: int = rng.randi_range(1, maximum) if maximum > 0 else 0
	if not source_invokes or maximum <= 0: return rolled
	var extra: int = ITEM_OPTIONS.additional_damage(weapon, "melee") + _enhancement_weapon_stat("damage")
	var scope: String = str(ui_preferences.get("patch523_weapon_double_scope", "base_flat_enchant"))
	if scope not in ["base_flat_enchant","base_only","disabled"]: scope = "base_flat_enchant"
	var outcome: Dictionary = LOOT_DROP.PATCH523_DROPS.weapon_invoke_roll(weapon,rolled,maximum,extra,scope,rng)
	for message: String in outcome.fired: hud.append_log(message)
	return int(outcome.damage)

func _load_monster_sizes() -> void:
	monster_size_index.clear()
	var filename: String = "res://data/monster_sizes_v1.json"
	if not FileAccess.file_exists(filename):
		return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(filename))
	if value is Dictionary:
		var size_records: Variant = (value as Dictionary).get("monster_sizes", {})
		if size_records is Dictionary:
			monster_size_index = size_records as Dictionary

func _monster_size_class(record: Dictionary) -> String:
	for key: String in ["size_class", "size", "monster_size", "크기"]:
		if record.has(key):
			var raw: String = str(record.get(key, "")).to_lower()
			if raw in ["large", "대", "대형", "big"]:
				return "large"
			if raw in ["small", "소", "소형"]:
				return "small"
	var name_value: String = str(record.get("name", ""))
	var known_value: Variant = monster_size_index.get(name_value, {})
	if known_value is Dictionary:
		var known_size: String = str((known_value as Dictionary).get("size", ""))
		if known_size in ["small", "large"]:
			return known_size
	# Body-type classification, deliberately independent of 'is_boss'.
	var big_keywords: Array[String] = ["거대", "골렘", "오우거", "사이클롭스", "에틴", "웜", "드레이크", "드래곤", "드레곤", "피닉스", "마이노", "바실리스크", "크랩맨", "에르자베"]
	for keyword: String in big_keywords:
		if name_value.contains(keyword):
			return "large"
	if str(record.get("type", "")) == "거인":
		return "large"
	return "small"

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
		{"name":"축복 부여 주문서 (각인)", "grade":"희귀", "type":"강화주문서", "slot":"consumable", "desc":"무기·방어구 축복에 사용 · 실패해도 장비 유지 · TWILIGHT 조정 확률"},
		{"name":"축복받은 무기 마법 주문서 (각인)", "grade":"희귀", "type":"강화주문서", "slot":"consumable", "desc":"성공 시 강화 단계가 +1~+3 상승할 수 있는 무기 주문서"},
		{"name":"축복받은 갑옷 마법 주문서 (각인)", "grade":"희귀", "type":"강화주문서", "slot":"consumable", "desc":"성공 시 강화 단계가 +1~+3 상승할 수 있는 방어구 주문서"},
		{"name":"장인의 무기 마법 주문서 (각인)", "grade":"영웅", "type":"강화주문서", "slot":"consumable", "desc":"+9 무기 강화. 실패해도 장비가 소실되지 않음"},
		{"name":"장인의 갑옷 마법 주문서 (각인)", "grade":"영웅", "type":"강화주문서", "slot":"consumable", "desc":"+7~+8 방어구 강화. 실패해도 장비가 소실되지 않음"},
		{"name":"오림의 장신구 마법 주문서 (각인)", "grade":"영웅", "type":"강화주문서", "slot":"consumable", "desc":"실패 시 장신구가 유지되거나 강화 단계가 1 하락"},
		{"name":"축복받은 오림의 장신구 마법 주문서 (각인)", "grade":"전설", "type":"강화주문서", "slot":"consumable", "desc":"실패해도 장신구 강화 단계가 유지됨"}
	]
	for regional_record: Dictionary in REGIONAL_RETURN.catalog_items():
		if not seen_names.has(str(regional_record.name)):
			catalog_items.append(regional_record)
			seen_names[str(regional_record.name)] = true
	for scroll_record: Dictionary in enhancement_scrolls:
		var scroll_name: String = str(scroll_record.get("name", ""))
		if seen_names.has(scroll_name):
			continue
		catalog_items.append(scroll_record.duplicate(true))
		seen_names[scroll_name] = true
	for i: int in range(catalog_items.size() - 1, -1, -1):
		var entry: Variant = catalog_items[i]
		if entry is Dictionary and CONSUMABLE_RULES.is_removed_item(str((entry as Dictionary).get("name", ""))):
			catalog_items.remove_at(i)
	for spec: Dictionary in CONSUMABLE_RULES.records():
		var found: bool = false
		for i: int in range(catalog_items.size()):
			var entry: Variant = catalog_items[i]
			if entry is Dictionary and str((entry as Dictionary).get("name", "")) == str(spec["name"]):
				var merged: Dictionary = (entry as Dictionary).duplicate(true)
				merged.merge(spec, true)
				catalog_items[i] = merged
				found = true
				break
		if not found:
			catalog_items.append(spec.duplicate(true))
	# The six shop/draw items must also be present in the runtime catalog:
	# inventory, shop, details and quickslot all resolve the same real icon.
	for item_name: String in CARD_PACK_ITEMS.PACKS:
		var pack_record: Dictionary = CARD_PACK_ITEMS.inventory_record(item_name)
		var present: bool = false
		for index: int in range(catalog_items.size()):
			var raw: Variant = catalog_items[index]
			if not (raw is Dictionary) or str((raw as Dictionary).get("name", "")) != item_name:
				continue
			var existing: Dictionary = raw as Dictionary
			# Never reinterpret an existing verified source-ID item as a local pack.
			if str(existing.get("sourceId", "")).is_empty():
				var merged: Dictionary = existing.duplicate(true)
				merged.merge(pack_record, true)
				catalog_items[index] = merged
			present = true
			break
		if not present:
			catalog_items.append(pack_record)
	catalog_db["아이템"] = catalog_items
	ITEM_CATALOG_LOOKUP.forget_misses()
	preload("res://scripts/shop/source523_cash_packages.gd").forget_owner_index()

func _connect_signals() -> void:
	hud.connect("equipment523_open_requested", _equipment523_open)
	hud.connect("equipment523_preview_requested", _equipment523_preview)
	hud.connect("equipment523_commit_requested", _equipment523_commit)
	hud.connect("equipment523_install_requested", _equipment523_install)
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
	var saved_presentation := ConfigFile.new()
	if saved_presentation.load("user://twilight_ui_settings.cfg") == OK:
		for key: String in presentation_global_settings:
			presentation_global_settings[key] = saved_presentation.get_value("visual", key, presentation_global_settings[key])
		if saved_presentation.has_section("visual_regions"):
			for map_key: String in saved_presentation.get_section_keys("visual_regions"):
				var local: Variant = saved_presentation.get_value("visual_regions", map_key)
				if local is Dictionary: presentation_region_settings[map_key] = PRESENTATION.region(local)
		if saved_presentation.has_section("presentation_local_regions"):
			for map_key: String in saved_presentation.get_section_keys("presentation_local_regions"):
				var rule: Dictionary = LOCAL_PRESENTATION.normalized(saved_presentation.get_value("presentation_local_regions",map_key))
				if not rule.is_empty(): local_presentation_regions[map_key] = rule
		var source_directory: String = str(saved_presentation.get_value("source_optimization","path",saved_presentation.get_value("source_optimization","directory","")))
		if not source_directory.is_empty():
			if source_directory.get_extension().to_lower()=="zip": source_optimization.load_zip(source_directory)
			else: source_optimization.load_directory(source_directory)
		var effect_directory: String = str(saved_presentation.get_value("presentation_effect","path",""))
		if not effect_directory.is_empty(): presentation_effect_pack.load_directory(effect_directory)
		var effect_enabled: Variant = saved_presentation.get_value("presentation_effect","enabled",false)
		presentation_effect_enabled = effect_enabled if effect_enabled is bool else false
		var effect_action: Variant = saved_presentation.get_value("presentation_effect","action",0)
		presentation_effect_action = int(effect_action) if (effect_action is int or effect_action is float) and effect_action in [0,3] else 0
	apply_presentation_settings(PRESENTATION.normalized(presentation_global_settings))
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
	hud.return_pressed.connect(_return_to_spawn_input)
	hud.inventory_pressed.connect(_open_inventory)
	hud.menu_pressed.connect(hud.toggle_menu)
	hud.weapon_mastery_requested.connect(weapon_mastery.show_panel)
	hud.map_pressed.connect(hud.toggle_map)
	hud.map_selected.connect(_on_map_selected)
	hud.save_pressed.connect(func() -> void: _save_game(false))
	hud.load_pressed.connect(func() -> void: _load_game(false))
	hud.catalog_equip_requested.connect(_equip_catalog)
	if hud.has_signal("quest_complete_requested"):
		hud.connect("quest_complete_requested", _claim_quest)
	if hud.has_signal("card_pack_draw_requested"):
		hud.connect("card_pack_draw_requested", _on_card_pack_draw_requested)
	if hud.has_signal("card_fusion_requested"):
		hud.connect("card_fusion_requested", _on_card_fusion_requested)
	if hud.has_signal("secondary_doll_requested"):
		hud.connect("secondary_doll_requested",_on_secondary_doll_requested)
	if hud.has_signal("secondary_relic_requested"):
		hud.connect("secondary_relic_requested",_on_secondary_relic_requested)
	if hud.has_signal("option_awakening_open_requested"):
		hud.connect("option_awakening_open_requested", _on_option_awakening_open_requested)
		hud.connect("option_awakening_feed_requested", _on_option_awakening_feed_requested)
		hud.connect("option_awakening_attempt_requested", _on_option_awakening_attempt_requested)
	hud.class_selected.connect(_on_class_selected)
	hud.stat_increase_requested.connect(_on_stat_increase_requested)
	hud.job_class_selected.connect(_on_job_class_selected)
	if hud.has_signal("source_gender_selected"):
		hud.connect("source_gender_selected", func(gender_id: int) -> void: set_source_character_gender(gender_id))
	hud.job_skill_pressed.connect(_cast_job_skill_input)
	hud.quickslot_pressed.connect(_on_quickslot_pressed)
	hud.quickslot_assignment_requested.connect(_on_quickslot_assignment_requested)
	hud.quickslot_edit_requested.connect(_on_quickslot_edit_requested)
	hud.self_mode_changed.connect(_on_self_mode_changed)
	hud.shop_buy_requested.connect(_buy_shop_item)
	if hud.has_signal("shop_bulk_buy_requested"):
		hud.connect("shop_bulk_buy_requested", _buy_shop_bulk)
	if hud.has_signal("reviewed_shop_buy_requested"):
		hud.connect("reviewed_shop_buy_requested", _buy_reviewed_shop_item)
	if hud.has_signal("warehouse_transfer_requested"):
		hud.connect("warehouse_transfer_requested", _warehouse_transfer)
	if hud.has_signal("npc_teleport_requested"):
		hud.connect("npc_teleport_requested", _npc_teleport_requested)
	if hud.has_signal("craft_requested"):
		hud.connect("craft_requested", _craft_requested)
	hud.totem_conversion_requested.connect(_totem_convert_requested)
	hud.totem_action_requested.connect(_totem_action_requested)
	if hud.has_signal("shop_sell_requested"):
		hud.connect("shop_sell_requested", _sell_shop_item)
	if hud.has_signal("npc_dialogue_action_requested"):
		hud.connect("npc_dialogue_action_requested", _npc_dialogue_action)
	if hud.has_signal("ain_item_requested"):
		hud.connect("ain_item_requested", _on_ain_item_requested)
	if hud.has_signal("ain_shop_requested"):
		hud.connect("ain_shop_requested", _on_ain_shop_requested)
	if hud.has_signal("ain_auto_changed"):
		hud.connect("ain_auto_changed", _on_ain_auto_changed)
	hud.inventory_item_activated.connect(_activate_inventory_input)
	if hud.has_signal("blessing_target_requested"):
		hud.connect("blessing_target_requested", _on_blessing_target_requested)
	hud.enhancement_requested.connect(_attempt_enhancement)
	# Optional validation tools live only in the isolated playtest HUD branch.
	if hud.has_signal("playtest_catalog_grant_requested"):
		hud.connect("playtest_catalog_grant_requested",_grant_playtest_catalog_item)
	if hud.has_signal("playtest_catalog_variant_grant_requested"):
		hud.connect("playtest_catalog_variant_grant_requested",_grant_playtest_catalog_variant)
	if hud.has_signal("playtest_aden_grant_requested"):
		hud.connect("playtest_aden_grant_requested",_grant_playtest_aden)

func _set_map(map_id: String, keep_position: bool) -> void:
	var map_started_usec: int = Time.get_ticks_usec()
	map_id = NATIVE_PNG.canonical(map_id)
	if not maps_by_id.has(map_id):
		if SOURCE_MAP84.supports(map_id):_reject_map_pack("원본 지도 팩 누락: 현재 지역과 저장을 보존합니다")
		return
	if field_map!=null and not loading_source_door_state:SOURCE_MAP84.saved_doors(field_map)
	var requested_native: PlayableField = BASE508_TEST.field_for(map_id)
	# Pre-November maps (source84, PNG maps, remakes, the old map list) are
	# not used (user decision 2026-11-10): the world is the installed original
	# 523 pack's Aden; other Lands open through 523 travel.
	if requested_native == null and (map_id != CURRENT523_HOST.MAP_ID or not CURRENT523_HOST.requested()):
		_reject_map_pack("원본 523 리소스 팩의 지도만 사용합니다. 예전 지도는 열지 않습니다")
		return
	if requested_native == null and NATIVE_PNG.supports(map_id) and not SOURCE_MAP84.supports(map_id):
		requested_native = NATIVE_PNG.load_field(map_id)
		if requested_native == null:
			_reject_map_pack("PNG 원본 팩 누락·손상: 현재 지역과 저장을 보존합니다")
			return
	if map_id in SOURCE_PNG_GAME.IDS and not SOURCE_MAP84.supports(map_id) and SOURCE_PNG_GAME.requested(map_id) and not REMAKE_REGISTRY.installed(map_id):
		_reject_map_pack("오만 통행 팩 누락: 구형 배경으로 바꾸지 않고 현재 지역을 유지합니다")
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
	var requested_original: OriginalPlayableField = null
	if requested_native == null and map_id == CURRENT523_HOST.MAP_ID and CURRENT523_HOST.requested():
		# The installed 523 pack supplies Aden itself; the old picture pack is
		# neither read nor required. If the 523 selection cannot open, this
		# session uses the old pack (when present) instead of a blank world.
		requested_original = CURRENT523_HOST.load_field(_aden_play_controller())
		if requested_original == null:
			CURRENT523_HOST.fail_session()
			# No older map is substituted.
			_reject_map_pack("523 아덴 지도를 열 수 없습니다: " + CURRENT523_HOST.problem)
			return
	if requested_native != null or requested_original != null:
		pass
	elif SOURCE_MAP84.supports(map_id):
		requested_original = SOURCE_MAP84.load_field(map_id)
		if requested_original == null:
			_reject_map_pack("원본 지도 팩을 확인할 수 없어 현재 지역을 유지합니다")
			return
	elif REMAKE_REGISTRY.installed(map_id):
		requested_original = REMAKE_REGISTRY.load_field(map_id)
		if requested_original == null:
			hud.show_message("리메이크 지도 데이터가 손상되어 현재 맵을 유지합니다")
			return
	elif requested_map.has("source_definition"):
		requested_original = SOURCE_TRAVEL.load_field(requested_map)
		if requested_original == null:
			hud.show_message("원본 지도의 좌표·통행 데이터를 검증할 수 없습니다")
			return
	if requested_original is RemakePlayableField and not bool(requested_original.get_meta("source_map84",false)) and SOURCE_PNG_GAME.requested(map_id) and not SOURCE_PNG_GAME.attach(requested_original):
		requested_original.close()
		_reject_map_pack("오만 PNG 팩 누락·손상: 현재 지역과 저장을 유지합니다")
		return
	var dungeon_run: Dictionary = source_dungeon_runs.state.active
	if not dungeon_run.is_empty() and dungeon_run.status == "active" and map_id != str(dungeon_run.map_id):
		var failed_run: Dictionary = source_dungeon_runs.fail_run()
		if not failed_run.get("ok",false):
			hud.show_message(str(failed_run.get("reason","던전 이탈을 저장할 수 없습니다."))); return
	# Restore the retained renderer before the existing map lifecycle releases it.
	# Requested experimental presentation can reapply on a supported destination.
	if current523_aden_play_active:
		# The renderer restored here is freed right below; one released by 523
		# play mode is not rebuilt only to be discarded.
		current523_prior_rebuild_suppressed = true
		close_current523_aden_play(false)
		current523_prior_rebuild_suppressed = false
	_clear_combat_actions()
	manual_route_pending_target=Vector2.INF
	if is_instance_valid(world_interactions):
		world_interactions.cancel_gesture()
		world_interactions.clear_selection()
	field_population.configure(self, null)
	field_population = original_population if requested_original != null and not requested_original is RemakePlayableField else legacy_population
	if field_map is OriginalPlayableField: (field_map as OriginalPlayableField).close()
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
	if field_map is NativePngField:(field_map as NativePngField).park_precise_routes()
	field_map = null
	if requested_native is NativePngField:(requested_native as NativePngField).prepare_precise_routes_step(256,2000)
	loot_pickup.map_changed()
	ground_loot.hide_map()
	# Cached failed routes are map- and life-specific; never retain them on travel.
	auto_target_failed_paths.clear()
	_clear_auto_target_search()
	auto_target_next_search_ms = 0
	auto_target_failed_search_actor_count = -1
	if active_map_id != map_id:
		unconfirmed523.record_event("map_change",{"event_id":"map:%s:%s:%d"%[active_map_id,map_id,Time.get_ticks_usec()],"map_id":map_id})
	active_map_id = map_id
	source_region_settings.clear()
	source_optimization_signature = ""
	active_map = maps_by_id[map_id] as Dictionary
	if requested_native != null:
		active_map = active_map.duplicate()
		active_map["name"] = requested_native.data.map_name
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
	if requested_native != null or requested_original != null or not requested_field.is_empty():
		if requested_native != null or requested_original != null:
			field_map = requested_native if requested_native != null else requested_original
			world_size = field_map.bounds.size
			player.camera.limit_left = floori(field_map.bounds.position.x)
			player.camera.limit_top = floori(field_map.bounds.position.y)
			player.camera.limit_right = ceili(field_map.bounds.end.x)
			player.camera.limit_bottom = ceili(field_map.bounds.end.y)
		else:
			field_map = REMAKE_REGISTRY.authored_field(MONSTER_CATALOG.apply_map(requested_field))
		astar = field_map.astar
		field_physics = field_map.build_physics(self)
		map_background.texture = null
		map_background.visible = false
		collision_tiles.clear()
		if collision_debug:
			_build_collision_debug_tiles()
		player.collision_mask = 4
		var settings: Dictionary = field_map.data["camera"]
		field_camera_base_zoom = float(settings["zoom"])
		# Original-art fields only (1:1 source pixels); authored remake fields keep their own zoom.
		field_camera_original_art = requested_native != null or requested_original != null
		_apply_field_camera_zoom()
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
		field_camera_original_art = false
		FIELD_CAMERA.set_applied(1.0, get_tree())
		player.camera.zoom = Vector2.ONE * fit_zoom
		player.camera.position = Vector2(0,-32)
	if not keep_position or not _is_walkable_world(player.global_position):
		player.global_position = _spawn_position()
	player.velocity = Vector2.ZERO
	preload("res://scripts/maps/source_body_profile.gd").apply(player,field_map is RemakePlayableField or field_map is NativePngField)
	player.set_touch_vector(Vector2.ZERO)
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	player.clear_click_path()
	selected_monster = null
	auto_target = null
	hud.set_map_name(str(active_map.get("name", active_map_id)))
	hud.clear_target()
	if field_map != null:
		var made: Dictionary = _new_field_renderer(field_map)
		if made.abort: return
		field_renderer = made.renderer
		# Only the 523 host can be without a renderer (its own was rejected);
		# the field still exists for saving and the 523 play mode on top.
		if field_renderer != null:
			_mount_field_renderer(field_renderer, field_map)
			if field_renderer is RemakeSourceRenderer and field_renderer.png_review_active:
				hud.set_map_name(str(active_map.get("name",active_map_id))+" · PNG 검수")
				player.global_position = field_renderer.png_review_spawn
				player.camera.reset_smoothing();player.camera.force_update_scroll()
				field_renderer.refresh_visible()
			_apply_saved_visual_mode()
		# A saved source-field session must not create host encounters before its
		# own field is restored. Existing boss data is imported/exported unchanged.
		field_population.configure(self, null if _current523_source_restore_requested() or CURRENT523_HOST.is_host(field_map) else field_map)
	else:
		_spawn_monsters(9)
	field_minimap.configure(self, field_map)
	portal_cooldown = 2.0
	region_id = ""
	auto_repath_timer = 0.0
	ground_loot.activate(active_map_id)
	hud.show_message(str(active_map.get("name", active_map_id)))
	_update_source_optimization()
	_refresh_presentation_settings()
	_refresh_regional_return_slots()
	_perf_log("맵 이동", map_started_usec)
	if map_bootstrap_blocked:
		map_bootstrap_blocked=false
		process_mode=map_prior_process_mode
		if not FileAccess.file_exists(save_path()):source_save_blocked=false
	_restore_current523_aden_play.call_deferred()

## The renderer `_set_map` selects for `field` (also used to rebuild a renderer
## released while 523 play mode covered the field). Returns
## {"renderer": FieldRenderer or null, "abort": bool}; abort means the native
## PNG renderer script is missing and the caller must stop, as it always did.
func _new_field_renderer(field: PlayableField) -> Dictionary:
	var renderer: FieldRenderer = null
	if bool(field.get_meta("base508_source_test",false)):
		renderer=load(BASE508_TEST.RENDERER_PATH).new() as FieldRenderer
	elif field is NativePngField:
		# Instantiate only when an actual native-PNG field is active.
		var native_renderer_script: Variant = load(NATIVE_PNG_RENDERER_PATH)
		if native_renderer_script == null:
			push_error("Native PNG renderer script could not be loaded")
			return {"renderer":null,"abort":true}
		renderer = native_renderer_script.new() as FieldRenderer
	elif CURRENT523_HOST.is_host(field):
		renderer = CURRENT523_HOST.make_renderer(self, _aden_play_controller(), field)
		if renderer == null:
			hud.show_message("523 아덴 지형 표시를 준비하지 못했습니다: " + CURRENT523_HOST.problem)
	elif bool(field.get_meta("source_map84",false)): renderer = SOURCE_MAP84_RENDERER.new()
	elif field is RemakePlayableField: renderer = REMAKE_RENDERER.new()
	elif field is AuthoredRemakeField: renderer = preload("res://scripts/maps/authored_remake_renderer.gd").new()
	else: renderer = SOURCE_RENDERER.new() if field is OriginalPlayableField else FIELD_RENDERER.new()
	return {"renderer":renderer,"abort":false}

## Adds a new renderer under the world (the 523 host one already is) and
## configures it on `field`, exactly as `_set_map` does.
func _mount_field_renderer(renderer: FieldRenderer, field: PlayableField) -> void:
	if not renderer.is_inside_tree():
		renderer.name = "FieldRenderer"
		add_child(renderer)
	renderer.configure(field, player)

func _reject_map_pack(message: String) -> void:
	hud.show_message(message)
	# Hold the world and its saves only while an installed 523 pack cannot open
	# its map. With no pack configured at all there is no map state to protect:
	# the menus stay usable and nothing is drawn.
	if field_map==null and field_renderer==null and map_background.texture==null and FileAccess.file_exists(CURRENT523_HOST.OPTIONS.PATH):
		if not map_bootstrap_blocked:map_prior_process_mode=process_mode
		map_bootstrap_blocked=true
		source_save_blocked=true
		process_mode=Node.PROCESS_MODE_DISABLED

func _set_visual_mode(mode: String) -> void:
	if is_instance_valid(field_renderer):
		field_renderer.set_visual_mode(mode)

func _apply_saved_visual_mode() -> void:
	if not is_instance_valid(field_renderer):
		return
	_set_visual_mode(_saved_visual_mode())

## The map visual mode saved in the user's settings ("twilight" by default).
func _saved_visual_mode() -> String:
	var options := ConfigFile.new()
	var mode: String = "twilight"
	if options.load("user://twilight_ui_settings.cfg") == OK:
		mode = str(options.get_value("visual","map_mode","twilight"))
	return mode

func _apply_map_background() -> void:
	var path: String = str(active_map.get("image_path", ""))
	var texture: Texture2D = null
	if path != "" and preload("res://scripts/resources/retired_assets.gd").usable(path):
		texture = load(path) as Texture2D
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
	if field_map is OriginalPlayableField: return
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
	if field_map is NativePngField:
		var safe: Vector2=field_map.nearest_safe_click_destination(COORD.array_vector(field_map.data["spawn_position"]),6)
		if safe.is_finite(): return safe
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
	if not position_value.is_finite(): return false
	# A native PNG cell may be nominally open while the real 4px foot still
	# overlaps a hand-reviewed obstacle or an exact floor boundary.
	if field_map is NativePngField: return field_map.line_clear(position_value,position_value)
	if field_map != null: return field_map.walkable(position_value)
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

func _advance_native_route_preparation() -> void:
	if not field_map is NativePngField:return
	var native: NativePngField=field_map as NativePngField
	var was_ready: bool=native.precise_routes!=null and native.precise_routes.ready()
	if not native.prepare_precise_routes_step(512,2000):return
	if not was_ready:auto_target_next_search_ms=0
	if manual_route_pending_target.is_finite():
		var deferred_target: Vector2=manual_route_pending_target
		manual_route_pending_target=Vector2.INF
		if player.click_path.is_empty() and not player.has_manual_movement():
			var deferred_path: PackedVector2Array=find_world_path(player.global_position,deferred_target)
			if not deferred_path.is_empty():player.set_manual_click_path(deferred_path,deferred_target)

func _native_route_pending() -> bool:
	return field_map is NativePngField and (field_map as NativePngField).route_pending

func _nearest_walkable_cell(origin: Vector2i) -> Vector2i:
	if field_map is OriginalPlayableField: return field_map.nearest_cell(field_map.cell_to_world(origin))
	if astar != null and astar.is_in_boundsv(origin) and not astar.is_point_solid(origin):
		return origin
	for radius: int in range(1, 12):
		for y: int in range(origin.y - radius, origin.y + radius + 1):
			for x: int in range(origin.x - radius, origin.x + radius + 1):
				var cell: Vector2i = Vector2i(x, y)
				if astar != null and astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
					return cell
	return origin

func _npc_dialogue_action(npc_id: String,node_id: String,action: String) -> void:
	# The UI cannot authorize an NPC service. Revalidate player proximity and
	# the NPC's original function on that page against CURRENT world state.
	if field_map == null:
		return
	if not TOWN_NPCS.allowed_action(self,npc_id,node_id,action):
		hud.show_message("대화 조건 또는 NPC 접근 거리가 맞지 않습니다")
		return
	match action:
		"shop": hud.open_npc_shop(npc_id)
		"warehouse": hud.call("open_warehouse")
		"craft": hud.call("open_crafting")
		"buyback": hud.call("open_item_sell")
		"teleport": hud.call("open_npc_teleport")
		"quest": hud.call("open_quests")
		"restore": death_recovery.open_ui()
		_: hud.show_message("이 대화에서는 이용할 수 없는 기능입니다")

## Original 523 town NPC tap: its function window opens directly, without the
## NpcDialogue_All talk (user request 2026-11-19). Shop NPC -> original store
## window, 창고지기 -> storage, 텔레포터 -> 지역 이동, quest -> quest window,
## 사망 복구 -> recovery; an NPC with no function only shows its name.
func _open_town_npc_function(npc: Dictionary) -> void:
	var npc_id: String = str(npc.get("id",""))
	match TOWN_NPCS.primary_action(self,npc_id):
		"shop": hud.open_npc_shop(npc_id)
		"warehouse": hud.call("open_warehouse")
		"teleport": hud.call("open_npc_teleport")
		"craft": hud.call("open_crafting")
		"buyback": hud.call("open_item_sell")
		"quest": hud.call("open_quests")
		"restore": death_recovery.open_ui()
		_: hud.show_message(str(npc.get("name","")))

func _set_click_destination(target: Vector2) -> void:
	loot_pickup.cancel()
	manual_route_pending_target=Vector2.INF
	if field_map != null:
		for npc: Dictionary in field_map.data["npc_spawn"]:
			var npc_position: Vector2 = COORD.array_vector(npc["position"])
			if target.distance_to(npc_position) < 55 and player.global_position.distance_to(npc_position) < 190:
				if TOWN_NPCS.is_town_npc_id(str(npc.get("id",""))):
					_open_town_npc_function(npc)
					return
				if str(npc["role"]) == "shop":
					hud.open_npc_shop()
				elif str(npc["role"]) == "warehouse":
					hud.call("open_warehouse")
				elif str(npc["role"]) == "teleport":
					hud.call("open_npc_teleport")
				elif str(npc["role"]) == "craft":
					hud.call("open_crafting")
				elif str(npc["role"]) == "buyback":
					hud.call("open_item_sell")
				elif field_map is OriginalPlayableField and field_map.uses_original_gameplay_rules():
					hud.show_message(str(npc.name)+" · 원본 대화 기능 미매핑")
				else:
					hud.show_message("왕의 길을 따라 동쪽으로: 초원 → 돌다리 → 황혼의 폐허" if str(field_map.data.get("map_id",""))=="aden_world" else str(field_map.data["map_name"])+" · 청록 이동진: 이전/다음 지역 · 아덴 귀환")
				return
	var destination: Vector2=target
	if field_map is NativePngField:
		# Blocked or visually misleading tap locations must resolve to vetted, full-foot-safe floor.
		destination=field_map.nearest_safe_click_destination(target)
		if not destination.is_finite():
			player.clear_click_path()
			hud.show_message("통행 불가 %s (%d,%d)" % [active_map_id,roundi(target.x),roundi(target.y)])
			return
	var path: PackedVector2Array = find_world_path(player.global_position,destination)
	if not path.is_empty():
		player.set_manual_click_path(path,destination)
	elif _native_route_pending():
		player.clear_click_path()
		manual_route_pending_target=destination
	elif current523_aden_source_active():
		# A new direct destination supersedes the old source walk even when
		# no complete OWN route exists. Never snap to another cell or keep going.
		player.clear_click_path(); player.velocity=Vector2.ZERO
		hud.show_message("원문 지형에서 확인된 보행 경로가 없습니다.")
	elif field_map is NativePngField:
		player.clear_click_path()
		hud.show_message("우회 경로 없음 %s (%d,%d)" % [active_map_id,roundi(target.x),roundi(target.y)])

func _unconfirmed_monster_entered(node: Node) -> void:
	if node is TwilightMonster:
		# Population setup runs immediately after add/reparent. Observe its final
		# HP and source identity after that setup, including each pooled life.
		_watch_unconfirmed_monster.call_deferred(weakref(node))

func _watch_unconfirmed_monster(reference: WeakRef) -> void:
	var monster: TwilightMonster = reference.get_ref() as TwilightMonster
	if not is_instance_valid(monster) or monster.get_parent() != monsters_root or not is_instance_valid(monster.hp_bar): return
	var callback: Callable = monster.get_meta("unconfirmed523_hp_callback",Callable())
	if not callback.is_valid():
		callback = _unconfirmed_monster_hp_changed.bind(reference)
		monster.set_meta("unconfirmed523_hp_callback",callback)
	if not monster.hp_bar.value_changed.is_connected(callback):
		monster.hp_bar.value_changed.connect(callback)
	monster.set_meta("unconfirmed523_hp",{"life":monster.life_id,"npc":monster.source_m_npc_id,"maximum":monster.max_hp,"hp":monster.hp,"serial":0})

func _unconfirmed_monster_hp_changed(_value: float, reference: WeakRef) -> void:
	var monster: TwilightMonster = reference.get_ref() as TwilightMonster
	if not is_instance_valid(monster) or monster.get_parent() != monsters_root: return
	var before: Dictionary = monster.get_meta("unconfirmed523_hp",{})
	var observed: Dictionary = {"life":monster.life_id,"npc":monster.source_m_npc_id,"maximum":monster.max_hp,"hp":monster.hp,"serial":int(before.get("serial",0))+1}
	monster.set_meta("unconfirmed523_hp",observed)
	# Setup, healing and changes to maximum HP are not threshold damage.
	if before.is_empty() or before.life != observed.life or before.npc != observed.npc or before.maximum != observed.maximum or observed.npc <= 0 or observed.hp >= before.hp: return
	if not unconfirmed523.domains.has("challenge") or not unconfirmed523.state.domains.has("challenge"): return
	var domain = unconfirmed523.domains.challenge
	if not domain.has_hp_section_crossing(int(observed.npc),int(before.hp),int(observed.hp),int(observed.maximum),unconfirmed523.state.domains.challenge): return
	unconfirmed523.record_event("npc_hp",{"npc_id":observed.npc,"previous_hp":before.hp,"hp":observed.hp,"max_hp":observed.maximum,"event_id":"hp:%s:%d:%d:%d"%[active_map_id,monster.get_instance_id(),monster.life_id,observed.serial]})

func _spawn_monsters(count: int) -> void:
	var spawnable: Array = MONSTER_CATALOG.spawnable_records(monster_db)
	if spawnable.is_empty():
		return
	for index: int in range(count):
		var record_value: Variant = spawnable[rng.randi_range(0, spawnable.size() - 1)]
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value as Dictionary
		var monster: TwilightMonster = MONSTER_SCENE.instantiate()
		# Position before entering the physics space (see field_population._spawn_slot).
		monster.position = monsters_root.to_local(_random_walkable_position(player.global_position, 360.0, 1200.0))
		monsters_root.add_child(monster)
		var texture: Texture2D = _monster_texture(record)
		if not monster.setup(record, player, self, texture): continue
		monster.set_meta("size_class", _monster_size_class(record))
		monster.died.connect(_on_monster_died)
		monster.player_hit.connect(_on_player_hit)
		monster.selected.connect(_select_monster)

func _monster_texture(record: Dictionary) -> Texture2D:
	var original_art: Texture2D = MONSTER_ART.texture_for(record)
	if original_art != null: return original_art
	# The old TWILIGHT monster sheets were removed: no substitute picture.
	return null

func _random_walkable_position(near: Vector2, min_distance: float, max_distance: float) -> Vector2:
	if field_map is OriginalPlayableField: return (field_map as OriginalPlayableField).random_landing(rng,near,min_distance,max_distance)
	if field_map is NativePngField: return (field_map as NativePngField).random_landing(rng,near,min_distance,max_distance)
	# Display tiles and navigation cells can have different dimensions.
	if astar == null or not astar.region.has_area(): return _spawn_position_fallback()
	var region: Rect2i = astar.region
	var require_reachable: bool = near != Vector2.ZERO
	var origin_cell: Vector2i = Vector2i.ZERO
	if require_reachable:
		origin_cell = _nearest_walkable_cell(_world_to_cell(near))
		if not astar.is_in_boundsv(origin_cell) or astar.is_point_solid(origin_cell): return _spawn_position_fallback()
		if is_finite(max_distance):
			var first: Vector2i = _world_to_cell(near-Vector2.ONE*max_distance)
			var last: Vector2i = _world_to_cell(near+Vector2.ONE*max_distance)
			region = region.intersection(Rect2i(first,last-first+Vector2i.ONE))
			if not region.has_area(): return _cell_to_world(origin_cell)
	for _attempt: int in range(700):
		var cell := Vector2i(rng.randi_range(region.position.x,region.end.x-1),rng.randi_range(region.position.y,region.end.y-1))
		if not astar.is_point_solid(cell):
			var position_value: Vector2 = _cell_to_world(cell)
			if not require_reachable:
				return position_value
			var distance: float = position_value.distance_to(near)
			if distance < min_distance or distance > max_distance:
				continue
			if astar.get_id_path(origin_cell, cell).is_empty():
				continue
			return position_value
	return _cell_to_world(origin_cell) if require_reachable else _spawn_position_fallback()

func _spawn_position_fallback() -> Vector2:
	if astar != null:
		var region: Rect2i = astar.region
		for row: int in range(region.position.y,region.end.y):
			for column: int in range(region.position.x,region.end.x):
				var cell := Vector2i(column,row)
				if not astar.is_point_solid(cell): return _cell_to_world(cell)
	return Vector2(tile_size * 2, tile_size * 2)

func _clear_monsters() -> void:
	for child: Node in monsters_root.get_children():
		monsters_root.remove_child(child)
		child.queue_free()

func _clear_drops() -> void:
	loot_pickup.cancel()
	ground_loot.clear_map(active_map_id)

func _magic_hit_chance(attacker_magic_accuracy: int, target_mr: int) -> float:
	return PHYSICAL_RESOLUTION.magic_hit_chance(attacker_magic_accuracy,target_mr)

func _player_magic_hit_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _magic_hit_chance(_magic_accuracy_stat(), card_collections.magic_resistance_after_pierce(target.magic_resistance+int(original_skills.status.modifier(target,"mr") if original_skills!=null else 0)+int(patch523_npc_spells.extensions.actor_values(target).get("MagicResist",0))))*halphas_star.combat.hit_factor(player)

func _cast_bleed_skill(target: TwilightMonster, mp_cost: int = 6, power: int = 28, bleed_duration: float = 4.5, tick_damage: int = 9, tick_interval: float = 0.75, skill_name: String = "출혈 베기") -> bool:
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
	if not resolving_combat_action and not pending_attack.is_empty(): return false
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.silence_remaining > 0:
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
		# MP is paid only for a registered motion; a refused registration keeps it.
		if not _queue_player_attack(target, "melee", _cast_bleed_skill.bind(target, 0, power, bleed_duration, tick_damage, tick_interval, skill_name), _skill_motion_duration({}), false, 90.0): return false
		mp = maxi(0, mp - mp_cost)
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
		damage = _player_critical_damage(damage, "melee")
	_deal_successful_player_hit(target, damage, critical,"melee",true,true)
	if target.dead:
		_update_hud()
		_update_target_hud()
		return false
	var bleed_chance: float = clampf(_player_bleed_chance(target)+card_collections.spell_hit_bonus({"status":"bleed"})/100.0,0.0,0.95)
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
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
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
		# MP is paid only for a registered motion; a refused registration keeps it.
		if not _queue_player_attack(target, "magic", _cast_poison_skill.bind(target, 0, poison_duration, tick_damage, tick_interval, skill_name), _skill_motion_duration({}), false, 300.0): return false
		mp = maxi(0, mp - mp_cost)
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
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
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
		# MP is paid only for a registered motion; a refused registration keeps it.
		if not _queue_player_attack(target, "magic", _cast_fear_skill.bind(target, 0, fear_duration, skill_name), _skill_motion_duration({}), false, 300.0): return false
		mp = maxi(0, mp - mp_cost)
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
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
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
		# MP is paid only for a registered motion; a refused registration keeps it.
		if not _queue_player_attack(target, "magic", _cast_hold_skill.bind(target, 0, hold_duration, skill_name), _skill_motion_duration({}), false, 280.0): return false
		mp = maxi(0, mp - mp_cost)
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
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
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
		# MP is paid only for a registered motion; a refused registration keeps it.
		if not _queue_player_attack(target, "magic", _cast_silence_skill.bind(target, 0, silence_duration, skill_name), _skill_motion_duration({}), false, 320.0): return false
		mp = maxi(0, mp - mp_cost)
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
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
	if not resolving_combat_action and not pending_attack.is_empty(): return false
	if player.is_feared():
		hud.show_message("공포 상태에서는 행동할 수 없습니다")
		return false
	if player.is_stunned():
		hud.show_message("스턴 상태에서는 스킬을 사용할 수 없습니다")
		return false
	if player.silence_remaining > 0:
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
		# MP is paid only for a registered motion; a refused registration keeps it.
		if not _queue_player_attack(target, "melee", _cast_stun_skill.bind(target, power, 0, stun_duration, skill_name), _skill_motion_duration({}), false, 90.0): return false
		mp = maxi(0, mp - mp_cost)
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
		damage = _player_critical_damage(damage, "melee")
	_deal_successful_player_hit(target, damage, critical,"melee",true,true)
	if target.dead:
		_update_hud()
		_update_target_hud()
		return false
	# An explicit status immunity is separate from numeric resistance. Keep the
	# landed hit and its damage, but never restore an immune stun via the floor.
	var stun_chance: float = 0.0 if target.status_immunities.has("stun") else clampf(_player_stun_chance(target) + _transformation_skill_bonus(skill_name, "accuracy_pct") / 100.0, 0.05, 0.95)
	var stunned: bool = stun_chance > 0.0 and rng.randf() < stun_chance
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
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
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
		# MP is paid only for a registered motion; a refused registration keeps it.
		if not _queue_player_attack(target, "magic", _cast_magic_attack.bind(target, power, 0, skill_name), _skill_motion_duration({}), false, 360.0): return false
		mp = maxi(0, mp - mp_cost)
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
		damage = _player_critical_damage(damage, "magic")
	_deal_successful_player_hit(target, damage, critical,"magic",true,true)
	hud.append_log("%s 적중%s · %s에게 %d 마법 피해 · 명중 %.1f%% · 치명타 %.1f%%" % [
		skill_name, " CRITICAL" if critical else "", target.monster_name, damage,
		hit_chance * 100.0, critical_chance * 100.0
	])
	_update_hud()
	_update_target_hud()
	return true

func _melee_hit_chance(target: TwilightMonster) -> float:
	return _normal_attack_hit_chance(target,"melee")

func _ranged_hit_chance(target: TwilightMonster) -> float:
	return _normal_attack_hit_chance(target,"ranged")

func _roll_melee_hit(target: TwilightMonster) -> bool:
	return rng.randf() < _melee_hit_chance(target)

func _skill_target(max_distance: float) -> TwilightMonster:
	if _source_combat_targets_hidden(): return null
	var locked: TwilightMonster = _equipment523_locked_target()
	if locked != null:
		if player.global_position.distance_squared_to(locked.global_position) <= max_distance*max_distance and _has_line_of_sight_world(player.global_position,locked.global_position): return locked
		return null
	# Explicit target selection is authoritative. A spell may fail against a
	# distant/obstructed target, but may never silently strike a different mob.
	if is_instance_valid(selected_monster) and selected_monster.concealed523: return null
	if is_instance_valid(world_interactions) and not world_interactions.selections.is_empty():
		if not world_interactions.valid(world_interactions.selections[0]):
			world_interactions.prune()
	var target: TwilightMonster = selected_monster
	if is_instance_valid(target) and not target.dead:
		if not equipment523_can_detect(target): return null
		if player.global_position.distance_squared_to(target.global_position) <= max_distance * max_distance:
			if _has_line_of_sight_world(player.global_position, target.global_position):
				return target
		return null
	if is_instance_valid(world_interactions) and not world_interactions.selections.is_empty():
		return null
	return _nearest_visible_monster(max_distance)

func _cast_bleed_from_hud() -> void:
	if death_recovery.blocked(): return
	# Backward-compatible signal used by older HUD revisions.
	_cast_bleed_skill(_skill_target(90.0))

func _cast_combat_skill_from_hud(skill_id: String) -> void:
	if death_recovery.blocked(): return
	if skill_id != "attack" and patch523_npc_spells.blocks("CannotCastSkill"): return
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

func _attack(automatic_acquisition: bool = false) -> void:
	if death_recovery.blocked(): return
	if patch523_npc_spells.blocks("CannotAttack"): return
	if _source_combat_targets_hidden(): return
	if is_instance_valid(world_interactions) and world_interactions.primary_is_npc(): return
	if player.is_stunned() or player.is_feared() or not charge_skill.is_empty():
		return
	if auto_attack_timer > 0.0 or not pending_attack.is_empty():
		return
	var polymorph_weapon_reason: String = POLYMORPH_WEAPON_LIMIT.attack_reason(self)
	if not polymorph_weapon_reason.is_empty():
		hud.show_message(polymorph_weapon_reason)
		auto_attack_timer = 1.0
		return
	var attack_kind: String = _current_attack_kind()
	var target: TwilightMonster = selected_monster
	var target_usable: bool = is_instance_valid(target) and not target.dead
	if target_usable and automatic_acquisition: target_usable = target.permits_auto_selection()
	if target_usable:
		target_usable = _target_in_current_weapon_range(target)
	if target_usable:
		target_usable = _has_line_of_sight_world(player.global_position, target.global_position)
	if not target_usable:
		if is_instance_valid(world_interactions) and not world_interactions.selections.is_empty(): return
		target = _nearest_visible_monster_in_weapon_range(automatic_acquisition)
	if target == null:
		hud.show_message("무기 사거리 안에 보이는 대상이 없습니다")
		return
	if original_skills!=null and original_skills.progression.try_repeat(target):
		auto_attack_timer=_normal_attack_interval()
		selected_monster=target
		return
	var source_ammo: Dictionary=SOURCE_AMMO.selected(self,_weapon_ammo_family())
	# Ammo is paid only for an attack that registers: the refusals are
	# checked first and the paid shot is registered in this same frame.
	if _player_attack_refused(target, attack_kind, true):
		auto_attack_timer = _normal_attack_interval()
		return
	var native_ammo_bonus: int=-1
	var native_ammo: Dictionary=load("res://scripts/loot/current523_native_stack.gd").call("consume_ammo",self,_current_ammo_name(),1,0,target,true)
	if native_ammo.get("handled",false):
		if not native_ammo.get("ok",false) or not native_ammo.get("saved",false) or native_ammo.get("consumed")!=1:
			hud.show_message(str(native_ammo.get("reason","원본 탄약 발사 연결 대기")));auto_attack_timer=1.0;return
		native_ammo_bonus=int(native_ammo.damage_bonus);_refresh_ammo_counters()
	elif not _consume_weapon_ammo():
		auto_attack_timer = 1.0
		return
	selected_monster = target
	auto_attack_timer = _normal_attack_interval()
	_break_invisibility()
	_queue_player_attack(target, attack_kind, _resolve_normal_attack.bind(target, attack_kind, _mastery_actual_weapon_type(), source_ammo,native_ammo_bonus), auto_attack_timer, true)

func _resolve_normal_attack(target: TwilightMonster, attack_kind: String, attack_weapon_type: int = -1, source_ammo: Dictionary = {}, native_ammo_bonus: int=-1) -> void:
	if patch523_npc_spells.blocks("CannotAttack"): return
	if not is_instance_valid(target) or target.dead: return
	# Stage times inside one hit (523.800/804: one impact ~120-130 ms on the
	# phone with no inner row in the record).
	var hit_stage: int = FRAME_HITCH.now()
	var hit_chance: float = _normal_attack_hit_chance(target, attack_kind)
	if rng.randf() >= hit_chance:
		target.show_miss()
		if original_skills != null: original_skills.trigger_relic_miss(target, attack_kind)
		var accuracy: int = _ranged_accuracy_stat() if attack_kind == "ranged" else _melee_accuracy_stat()
		hud.append_log("%s %s 공격 MISS · 명중 %d / AC %d / %.1f%%" % [
			target.monster_name,
			"원거리" if attack_kind == "ranged" else "근거리",
			accuracy, target.armor_class, hit_chance * 100.0
		])
		_update_target_hud()
		return
	var actual_weapon: int = _mastery_actual_weapon_type()
	if attack_weapon_type == -1 or attack_weapon_type == actual_weapon: weapon_mastery.normal_hit(actual_weapon)
	var roll: Dictionary = _normal_hit_damage_roll(target, attack_kind, source_ammo, native_ammo_bonus)
	var damage: int = roll.damage
	var critical: bool = roll.critical
	var critical_chance: float = roll.chance
	hit_stage = FRAME_HITCH.detail_next("hit.roll", hit_stage)
	_deal_successful_player_hit(target, damage, critical,attack_kind,true,false,{},true)
	hit_stage = FRAME_HITCH.detail_next("hit.deal", hit_stage)
	preload("res://scripts/loot/patch523_weapon_bleed.gd").on_normal_hit(self,target)
	_try_trigger_passives("on_hit", target,attack_kind,true,false)
	hit_stage = FRAME_HITCH.detail_next("hit.passives", hit_stage)
	_try_extra_weapon_hit(target, damage, attack_kind)
	hit_stage = FRAME_HITCH.detail_next("hit.extra", hit_stage)
	hud.append_log("%s에게 %d %s 피해%s · 사거리 %d칸 · 치명타 %.1f%%" % [
		target.monster_name, damage,
		"원거리" if attack_kind == "ranged" else "근거리",
		" CRITICAL" if critical else "",
		_current_attack_range_cells(),
		critical_chance * 100.0
	])
	hit_stage = FRAME_HITCH.detail_next("hit.log", hit_stage)
	_update_target_hud()
	FRAME_HITCH.detail("hit.target_hud", hit_stage)

## Immutable part of one successful normal attack roll. Enter after mastery
## updates and exit before the impact can kill, change gear, buff or reenter.
## Same order of RNG draws, proc notes, mitigations and source element.
func _normal_hit_damage_roll(target: TwilightMonster, attack_kind: String, source_ammo: Dictionary, native_ammo_bonus: int) -> Dictionary:
	_stat_memo_begin()
	var weapon: Dictionary = _equipped_weapon_record()
	var damage_stat: int = _ranged_normal_damage_stat() if attack_kind == "ranged" else _melee_damage_stat()
	# Size-specific weapon base is rolled separately; no legacy -6..+9 spread.
	var weapon_roll: int=_roll_weapon_damage(target, true, weapon)
	weapon_roll=PATCH523_EQUIPMENT_COMBAT.weapon_scale(self,weapon_roll,attack_kind,target)
	var damage: int = maxi(1,damage_stat+weapon_roll+(native_ammo_bonus if native_ammo_bonus>=0 else _roll_source_ammo_damage(target))+SOURCE_AMMO.roll(source_ammo,target,rng))
	var critical_chance: float = _critical_chance(_player_critical_rate(attack_kind), target.critical_resistance)
	var critical: bool = rng.randf() < critical_chance
	if critical:
		damage = _player_critical_damage(damage, attack_kind)
	damage = _elemental_damage_to_monster(damage, _normal_attack_element(weapon), target)
	damage += int(consumable_service.call("weapon_element_bonus", weapon, target))
	_stat_memo_end()
	return {"damage":damage,"critical":critical,"chance":critical_chance}

func auto_hunting_destinations() -> Dictionary:
	if not auto_hunting_schedule_checked:
		auto_hunting_schedule_checked = true
		auto_hunting_schedule.load_configured()
	return {"entries": auto_hunting_schedule.list_destinations(), "reason": auto_hunting_schedule.problem}

func auto_hunting_movement_assessment(schedule_id: int, landing_link_id: int) -> Dictionary:
	auto_hunting_destinations()
	var entry: Dictionary = auto_hunting_schedule.destination(schedule_id)
	var gems: int = -1
	if not entry.is_empty() and int(entry.currency.ID) == 4 and str(entry.currency.Name) == "Gem":
		var wallet: Dictionary = auto_hunting_local.gem_wallet(self)
		if not bool(wallet.ok): return wallet
		gems = int(wallet.balance)
	return auto_hunting_local.assess(self, auto_hunting_schedule.request_definition(schedule_id, landing_link_id, level, gold, gems))

func auto_hunting_gem_wallet() -> Dictionary:
	return auto_hunting_local.gem_wallet(self)

func auto_hunting_destination_saveable(point: Vector2) -> bool:
	# Match the existing save/reentry contract, including its bounded route
	# search. Never weaken that contract to make a destination appear usable.
	return SOURCE_MAP84.valid_position(field_map, [point.x, point.y])

func auto_hunting_local_settings() -> Dictionary:
	return auto_hunting_local.get_settings()

func auto_hunting_set_local_settings(value: Dictionary) -> Dictionary:
	if auto_hunting_move_in_progress: return AUTO_HUNTING_LOCAL.fail("BUSY", "지역 이동 처리 중입니다")
	return auto_hunting_local.update_settings(value)

func auto_hunting_move(schedule_id: int, landing_link_id: int) -> Dictionary:
	if auto_hunting_move_in_progress: return AUTO_HUNTING_LOCAL.fail("BUSY", "지역 이동 처리 중입니다")
	auto_hunting_move_in_progress = true
	var quote: Dictionary = auto_hunting_movement_assessment(schedule_id, landing_link_id)
	if not bool(quote.ok):
		auto_hunting_move_in_progress = false
		return quote
	# Persist the validated destination and original fee before changing live
	# state. Save faults leave position, gold, AUTO, paths and items untouched.
	var staged_cost: Dictionary = AUTO_HUNTING_LOCAL.cost_override(self, quote)
	var error: Error = _save_game(true, staged_cost, quote)
	if error != OK:
		auto_hunting_move_in_progress = false
		return AUTO_HUNTING_LOCAL.fail("SAVE_FAILED", "이동 저장 실패 · 위치와 재화를 유지합니다")
	if int(quote.currency_id) == 1: gold = int(staged_cost.gold)
	else: inventory = staged_cost.inventory
	player.global_position = quote.destination
	player.velocity = Vector2.ZERO
	player.clear_click_path()
	player.set_touch_vector(Vector2.ZERO)
	# Only transient actions are cancelled: _clear_combat_actions also clears
	# persistent buffs/summons, which this same-map transaction must preserve.
	combat_generation += 1
	pending_attack.clear()
	player.cancel_attack()
	if is_instance_valid(combat_flights): combat_flights.clear()
	if is_instance_valid(world_interactions): world_interactions.clear_selection()
	loot_pickup.cancel()
	manual_route_pending_target = Vector2.INF
	selected_monster = null
	auto_target = null
	auto_target_failed_paths.clear()
	_clear_auto_target_search()
	auto_target_next_search_ms = 0
	auto_target_failed_search_actor_count = -1
	auto_repath_timer = 0.0
	auto_attack_timer = 0.0
	auto_stuck_time = 0.0
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	if is_instance_valid(field_renderer): field_renderer.refresh_visible()
	hud.clear_target()
	deferred_save.cancel()
	if int(quote.currency_id) == 4: hud.refresh_inventory(inventory)
	_update_hud()
	quote["code"] = "MOVED"
	quote["reason"] = "지역 이동 완료 · %d %s 소모 · TWILIGHT 자체 정책" % [int(quote.price), str(quote.currency_label)]
	hud.show_message(quote.reason)
	hud.append_log(quote.reason)
	auto_hunting_move_in_progress = false
	return quote

func _run_auto_hunt() -> void:
	if player.has_manual_movement():
		_stable_auto_route.clear()
		_clear_auto_target_search()
		auto_stuck_time = 0.0
		return
	var manual_priority: TwilightMonster = null
	var locked: TwilightMonster = _equipment523_locked_target()
	if locked != null:
		auto_target = locked
		selected_monster = locked
	elif is_instance_valid(world_interactions):
		if world_interactions.pointer != -2: return
		if world_interactions.primary_is_npc(): return
		var priority: TwilightMonster = world_interactions.primary_monster()
		if priority != null:
			manual_priority = priority
			auto_target = priority
			selected_monster = priority
	# The source flag restricts acquisition, not damage or an explicit selection.
	if is_instance_valid(auto_target) and auto_target != manual_priority and not auto_target.permits_auto_selection(): auto_target = null
	if not pending_attack.is_empty(): return
	if player.is_stunned() or player.is_feared():
		player.clear_click_path()
		return
	if not charge_skill.is_empty():
		player.clear_click_path()
		return
	# Stage times for the phone record (523.681: auto_hunt 196 ms/s, no split).
	var auto_stage: int = FRAME_HITCH.now()
	if inventory_automation.maintenance.try_automatic(): return
	auto_stage = FRAME_HITCH.detail_next("auto.maintenance", auto_stage)
	var picked: bool = _run_auto_ground_pickup()
	auto_stage = FRAME_HITCH.detail_next("auto.pickup", auto_stage)
	if picked:
		return
	var acquired_path := PackedVector2Array()
	if not is_instance_valid(auto_target) or auto_target.dead:
		if Time.get_ticks_msec() < auto_target_next_search_ms and monsters_root.get_child_count() == auto_target_failed_search_actor_count:
			selected_monster = null
			player.clear_click_path()
			return
		acquired_path = _acquire_auto_target()
		auto_target_failed_search_actor_count = monsters_root.get_child_count()
		if _native_route_pending():
			auto_target_next_search_ms = Time.get_ticks_msec() + 50
			auto_stuck_time = 0.0
		elif auto_target != null or not auto_search_candidates.is_empty():
			auto_target_next_search_ms = 0
		else:
			auto_target_next_search_ms = Time.get_ticks_msec() + AUTO_TARGET_EMPTY_RETRY_MS
		auto_stage = FRAME_HITCH.detail_next("auto.search", auto_stage)
	elif not auto_search_candidates.is_empty():
		_clear_auto_target_search()
	if auto_target == null:
		_stable_auto_route.clear()
		selected_monster = null
		player.clear_click_path()
		return
	selected_monster = auto_target
	var can_see: bool = _has_line_of_sight_world(player.global_position, auto_target.global_position)
	auto_stage = FRAME_HITCH.detail_next("auto.sight", auto_stage)
	# A registered, ready skill uses its own range even when the equipped weapon
	# cannot reach the monster. Offensive skills always precede normal attacks.
	var cast: bool = can_see and _run_auto_combat_quickslots()
	auto_stage = FRAME_HITCH.detail_next("auto.quickslots", auto_stage)
	if cast:
		player.clear_click_path()
		return
	if _target_in_current_weapon_range(auto_target) and can_see:
		player.clear_click_path()
		if auto_attack_timer <= 0.0:
			_attack(manual_priority == null)
		return
	if player.is_held():
		player.clear_click_path()
		return
	if not acquired_path.is_empty() or player.click_path.is_empty() or player.path_index >= player.click_path.size() or auto_repath_timer <= 0.0:
		auto_repath_timer = 0.65
		if auto_stuck_time > 2.0:
			auto_target = null
			player.clear_click_path()
			auto_stuck_time = 0.0
			_stable_auto_route.clear()
			return
		if acquired_path.is_empty() and not can_see and _can_keep_stable_auto_route(auto_target):
			FRAME_HITCH.count("auto.pursuit_path_kept")
			FRAME_HITCH.detail("auto.path_reuse",auto_stage)
			return
		_stable_auto_route.clear()
		# A moving target that is directly visible must not send AUTO around
		# a distant A* waypoint. A grid route may include an old first turn even
		# when the direct segment is already clear, causing a long pursuit stall.
		# Field line_clear checks the same walkability used for combat sight.
		# Keep A* for obstructed targets; do not bypass collision or map bounds.
		var path: PackedVector2Array = acquired_path
		if path.is_empty() or can_see:
			path = _auto_pursuit_path(auto_target, can_see)
		auto_stage = FRAME_HITCH.detail_next("auto.path", auto_stage)
		if path.is_empty():
			if locked != null:
				player.clear_click_path()
				return
			if _native_route_pending():
				auto_repath_timer=0.05
				auto_stuck_time=0.0
				return
			if is_instance_valid(world_interactions) and not world_interactions.selections.is_empty(): return
			_remember_auto_target_path_failure(auto_target)
			# An obstructed pursuit already spent this frame's route search.
			# Acquisition resumes next frame without starting a second route here.
			auto_target = null
			auto_target_next_search_ms = 0
			selected_monster = null
			player.clear_click_path()
			return
		player.set_click_path(path, auto_target.global_position)
		if not can_see:
			_remember_stable_auto_route(auto_target)

# Only admitted static 523 terrain opts in. Never infer stability from the
# map display name; legacy/native PNG fields keep their original cadence.
func _static_auto_route_epoch() -> int:
	if not is_instance_valid(field_map) or not field_map.has_method("static_pursuit_epoch"): return 0
	return int(field_map.call("static_pursuit_epoch"))

func _remember_stable_auto_route(target: TwilightMonster) -> void:
	_stable_auto_route.clear()
	var epoch: int = _static_auto_route_epoch()
	if epoch == 0 or not is_instance_valid(target) or target.dead or player.manual_navigation: return
	if player.path_index<0 or player.path_index>=player.click_path.size(): return
	if player.click_path[-1] != target.global_position: return
	_stable_auto_route = {"field":field_map.get_instance_id(),"epoch":epoch,"combat":combat_generation,
		"actor":target.get_instance_id(),"life":target.life_id,"goal":target.global_position,
		"points":player.click_path.duplicate(),"index":player.path_index}

## Called only on the ordinary repath deadline, after attack and manual
## priority. Confirm remaining path identity and the immediate walking leg.
## No failed search is cached; stale or blocked state follows existing A*.
func _can_keep_stable_auto_route(target: TwilightMonster) -> bool:
	if _stable_auto_route.is_empty() or not is_instance_valid(target) or target.dead or target.is_queued_for_deletion(): return false
	if player.manual_navigation or player.path_index<0 or player.path_index>=player.click_path.size() or auto_stuck_time>0.0: return false
	var epoch: int = _static_auto_route_epoch()
	if epoch==0 or field_map.get_instance_id()!=_stable_auto_route.field or epoch!=_stable_auto_route.epoch or combat_generation!=_stable_auto_route.combat: return false
	if target.get_instance_id()!=_stable_auto_route.actor or target.life_id!=_stable_auto_route.life or target.global_position!=_stable_auto_route.goal: return false
	if player.path_index<int(_stable_auto_route.index) or player.click_path!=_stable_auto_route.points: return false
	if not field_map.line_clear(player.global_position,player.click_path[player.path_index]): return false
	_stable_auto_route["index"]=player.path_index
	return true

func _auto_pursuit_path(target: TwilightMonster, directly_visible: bool) -> PackedVector2Array:
	if not is_instance_valid(target) or target.dead:
		return PackedVector2Array()
	if directly_visible:
		# A visible target needs no old A* corners; physics still collides.
		return PackedVector2Array([target.global_position])
	# Re-search while walking: continue from the point the player is already
	# walking to. A route searched from the player starts at the centre of its
	# own cell, usually already passed at the original walk (2.25 cells/s,
	# 1.46 cells per 0.65 s search), which turned it back and forth.
	# Searches are bounded like monster chases: a hunt target is near, and a
	# full-map search (8192 nodes) for an unreachable one cost the phone
	# ~120 ms per second of auto-hunt (523.704: auto.path 117 ms/s).
	var field: Object = field_map
	var bounded: bool = field != null and "path_search_limit_override" in field
	if bounded: field.set("path_search_limit_override", AUTO_PURSUIT_SEARCH_NODES)
	var result: PackedVector2Array = _auto_pursuit_search(target)
	if bounded: field.set("path_search_limit_override", -1)
	return result

const AUTO_PURSUIT_SEARCH_NODES: int = 2048

func _auto_pursuit_search(target: TwilightMonster) -> PackedVector2Array:
	if player.path_index < player.click_path.size() and not player.manual_navigation:
		var via: Vector2 = player.click_path[player.path_index]
		if via.is_finite() and via.distance_to(target.global_position) > 1.0 and _is_walkable_world(via):
			var rest: PackedVector2Array = find_world_path(via, target.global_position)
			if not rest.is_empty():
				if rest[0].distance_to(via) > 0.5: rest.insert(0, via)
				return rest
			# The player is walking to `via`: a target not reachable from it is
			# not reachable from the player either. One search, not two.
			return rest
	return find_world_path(player.global_position, target.global_position)

func _nearest_monster(max_distance: float) -> TwilightMonster:
	if _source_combat_targets_hidden(): return null
	var best: TwilightMonster = null
	var best_distance: float = max_distance
	for node: Node in monsters_root.get_children():
		if node is TwilightMonster:
			var monster: TwilightMonster = node
			if monster.dead or monster.concealed523:
				continue
			var distance: float = player.global_position.distance_to(monster.global_position)
			if distance < best_distance:
				best_distance = distance
				best = monster
	return best

func _has_line_of_sight_world(from_position: Vector2, to_position: Vector2) -> bool:
	if field_map is OriginalPlayableField:
		# Same or neighbouring source cell joined by a legal step: in sight, as
		# on the A* grid below. The straight foot line between two off-centre
		# points can graze a third (blocked) cell at a diagonal corner; the player
		# then never attacked and walked back and forth next to its target.
		var field: OriginalPlayableField = field_map as OriginalPlayableField
		var a: Vector2i = field.world_to_cell(from_position)
		var b: Vector2i = field.world_to_cell(to_position)
		if a == b and field.walkable(from_position): return true
		var heading: int = OriginalPlayableField.DIRECTIONS.find(b - a)
		if heading >= 0 and field.can_step(a, heading): return true
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
	if _source_combat_targets_hidden(): return null
	var best: TwilightMonster = null
	var best_distance: float = max_distance
	for node: Node in monsters_root.get_children():
		if not (node is TwilightMonster):
			continue
		var monster: TwilightMonster = node
		if monster.dead or monster.concealed523:
			continue
		if not equipment523_can_detect(monster): continue
		var distance: float = player.global_position.distance_to(monster.global_position)
		if distance >= best_distance:
			continue
		if not _has_line_of_sight_world(player.global_position, monster.global_position):
			continue
		best_distance = distance
		best = monster
	return best

func _auto_target_failure_key(monster: TwilightMonster) -> String:
	# Recheck when either actor enters a different nav cell or a pooled actor
	# begins a new life. Never cache a positive route as terrain can change.
	return "%s|%d|%d|%s|%s" % [
		active_map_id, monster.get_instance_id(), monster.life_id,
		str(_world_to_cell(player.global_position)), str(_world_to_cell(monster.global_position))]

func _remember_auto_target_path_failure(monster: TwilightMonster) -> void:
	if not is_instance_valid(monster): return
	if auto_target_failed_paths.size() >= 512: auto_target_failed_paths.clear()
	auto_target_failed_paths[_auto_target_failure_key(monster)] = Time.get_ticks_msec() + AUTO_TARGET_FAILED_PATH_RETRY_MS

func _clear_auto_target_search() -> void:
	auto_search_candidates.clear()
	auto_search_index = 0

func _acquire_auto_target() -> PackedVector2Array:
	auto_target = null
	if _source_combat_targets_hidden():
		_clear_auto_target_search()
		return PackedVector2Array()
	var origin: Vector2 = player.global_position
	var cell: Vector2i = _world_to_cell(origin)
	var actor_count: int = monsters_root.get_child_count()
	if auto_search_candidates.is_empty() or auto_search_cell != cell or auto_search_actor_count != actor_count or auto_search_generation != combat_generation:
		auto_search_candidates = _reachable_target_candidates(99999.0, true)
		auto_search_cell = cell
		auto_search_actor_count = actor_count
		auto_search_generation = combat_generation
		auto_search_index = 0
	var now: int = Time.get_ticks_msec()
	while auto_search_index < auto_search_candidates.size():
		var candidate: Dictionary = auto_search_candidates[auto_search_index]
		auto_search_index += 1
		if not is_instance_id_valid(int(candidate.actor_id)): continue
		var monster: TwilightMonster = instance_from_id(int(candidate.actor_id)) as TwilightMonster
		if monster == null or monster.get_parent() != monsters_root or monster.life_id != int(candidate.life_id): continue
		if monster.dead or monster.is_queued_for_deletion() or not monster.permits_auto_selection() or not equipment523_can_detect(monster): continue
		var key: String = _auto_target_failure_key(monster)
		if int(auto_target_failed_paths.get(key, 0)) > now: continue
		auto_target_path_checks += 1
		var started: int = FRAME_HITCH.now()
		var route: PackedVector2Array = find_world_path(origin, monster.global_position)
		FRAME_HITCH.detail("auto.search_route", started)
		if not route.is_empty():
			auto_target_failed_paths.erase(key)
			_clear_auto_target_search()
			auto_target = monster
			return route
		if _native_route_pending():
			auto_search_index -= 1
		else:
			_remember_auto_target_path_failure(monster)
		# Preserve the field's full route limit, but run only one route per frame.
		break
	if auto_search_index >= auto_search_candidates.size(): _clear_auto_target_search()
	return PackedVector2Array()

func _reachable_target_candidates(max_distance: float, automatic_acquisition: bool) -> Array[Dictionary]:
	# Distance-first preserves the previous nearest-reachable rule, while
	# avoiding an expensive A*/source route for every closer actor seen so far.
	var candidates: Array[Dictionary] = []
	var origin: Vector2 = player.global_position
	var max_distance_squared: float = max_distance * max_distance
	var order: int = 0
	for node: Node in monsters_root.get_children():
		if not node is TwilightMonster: continue
		var monster: TwilightMonster = node
		if monster.dead or monster.is_queued_for_deletion(): continue
		if automatic_acquisition and not monster.permits_auto_selection(): continue

		if not equipment523_can_detect(monster): continue
		var distance_squared: float = origin.distance_squared_to(monster.global_position)
		if distance_squared < max_distance_squared:
			candidates.append({"actor_id":monster.get_instance_id(), "life_id":monster.life_id, "distance_squared":distance_squared, "order":order})
		order += 1
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if float(a.distance_squared) == float(b.distance_squared):
			return int(a.order) < int(b.order)
		return float(a.distance_squared) < float(b.distance_squared))
	return candidates

func _nearest_reachable_monster(max_distance: float, force_refresh: bool = false, automatic_acquisition: bool = false) -> TwilightMonster:
	if _source_combat_targets_hidden(): return null
	var origin: Vector2 = player.global_position
	var candidates: Array[Dictionary] = _reachable_target_candidates(max_distance, automatic_acquisition)
	var now: int = Time.get_ticks_msec()
	for candidate: Dictionary in candidates:
		var monster: TwilightMonster = instance_from_id(int(candidate.actor_id)) as TwilightMonster
		if not is_instance_valid(monster): continue
		var key: String = _auto_target_failure_key(monster)
		if not force_refresh and int(auto_target_failed_paths.get(key, 0)) > now: continue
		auto_target_path_checks += 1
		if not find_world_path(origin, monster.global_position).is_empty():
			auto_target_failed_paths.erase(key)
			return monster
		if _native_route_pending():return null
		_remember_auto_target_path_failure(monster)
	return null

func _select_monster(monster: TwilightMonster) -> void:
	if not equipment523_can_detect(monster): return
	var locked: TwilightMonster = _equipment523_locked_target()
	if locked != null and monster != locked:
		hud.show_message("세트 효과가 유지되는 동안 공격 대상을 바꿀 수 없습니다")
		return
	if is_instance_valid(world_interactions): world_interactions.select_monster(monster)
	else: selected_monster = monster

func _update_target_hud() -> void:
	# The selection controller prunes every 0.2s already; in the frame loop
	# only perform a full scan when the primary entry has actually gone stale.
	if is_instance_valid(world_interactions) and not world_interactions.selections.is_empty():
		if not world_interactions.valid(world_interactions.selections[0]):
			world_interactions.prune()
	var locked: TwilightMonster = _equipment523_locked_target()
	if locked != null: selected_monster = locked
	if not is_instance_valid(selected_monster) or selected_monster.dead: selected_monster = null

func _on_monster_died(monster: TwilightMonster) -> void:
	var kill_started: int = FRAME_HITCH.now()
	_on_monster_died_timed(monster)
	FRAME_HITCH.detail("kill.total", kill_started)

func _on_monster_died_timed(monster: TwilightMonster) -> void:
	if not monster.loot_source_identity.is_empty():monster.loot_source_identity["source_clock_offset_minutes"]=int(ui_preferences.get("patch523_source_clock_offset_minutes",540))
	# Pooled actors can signal the same death more than once, but each life owns
	# one reward transaction. Claim before callbacks/passives can re-enter.
	if not is_instance_valid(monster) or not monster.dead: return
	if int(monster.get_meta("rewarded_life_id", -1)) == monster.life_id: return
	monster.set_meta("rewarded_life_id", monster.life_id)
	dungeon_play.monster_died(monster)
	if not bool(monster.get_meta("summoned",false)): content523.record_kill()
	if bool(monster.get_meta("summoned",false)):
		patch523_npc_spells.extensions.remaining.forget(monster)
		# Bounded boss helpers cannot become an unlimited XP/equipment farm.
		if monster==selected_monster: selected_monster = null
		if monster==auto_target: auto_target = null
		if is_instance_valid(combat_corpses): monster.reparent(combat_corpses,true)
		return
	var phase: int = FRAME_HITCH.now()
	var source_reward: Dictionary = patch523_npc_spells.extensions.remaining.take_reward(monster)
	_source_dungeon_kill(monster)
	var totem_changed: bool = totems.record_kill(int(monster.source_m_original.get("ID",0)))
	quest_service.record_kill(monster.monster_name, monster.is_boss)
	titles.record_last_hit(monster.source_m_npc_id,"%s:%d"%[str(monster.get_instance_id()),monster.life_id],int(monster.get_meta("title523_direct_life",-1))==monster.life_id,monster.source_m_original)
	phase = FRAME_HITCH.detail_next("kill.records", phase)
	if hud.has_method("refresh_quests"):
		hud.call("refresh_quests")
	phase = FRAME_HITCH.detail_next("kill.quest_hud", phase)
	_try_trigger_passives("on_kill", monster)
	phase = FRAME_HITCH.detail_next("kill.passives", phase)
	if field_map != null:
		field_population.release(monster)
	phase = FRAME_HITCH.detail_next("kill.population", phase)
	# Apply the pre-consumption blessing stage, with original equipped
	# Adena passive preserved; never replace one multiplier with the other.
	var can_drop_equipment: bool = ain_service.protected_drops()
	var exp_rate: float = ain_service.experience_rate()
	var adena_rate: float = ain_service.adena_rate()
	if ain_service.source_jade_level_override >= 0:
		var source_protection: Dictionary=unconfirmed523.jade_status()
		if not source_protection.has("error") and not source_protection.is_empty():
			can_drop_equipment=bool(source_protection.protected_drops)
			exp_rate=float(source_protection.exp_multiplier)
			adena_rate=float(source_protection.adena_multiplier)
	var item_adena_rate: float = 1.0 + clampf(_equipped_numeric_sum("adena_drop_pct"), 0.0, 500.0) / 100.0
	var map_rate: float = EXP_PROGRESSION.map_exp_multiplier(_kill_map_id())
	var source_experience: int = maxi(0,monster.exp_reward+int(source_reward.get("experience",0)))
	var gained_experience: int = maxi(0 if not monster.source_m_original.is_empty() else 1, int(round(source_experience * _experience_multiplier() * exp_rate * map_rate)))
	# Exact source growth potions affect the NPC Adena channel only. Compose
	# the temporary factor over existing blessing and equipment multipliers.
	var growth_drop_rate: float = 1.0
	if not active_item_buffs.is_empty():
		growth_drop_rate += clampf(_active_item_buff_total("source_npc_adena_drop_pct"), 0.0, 20.0) / 100.0
	var gained_adena: int = maxi(0, int(round(float(monster.gold_reward) * adena_rate * item_adena_rate * growth_drop_rate)))
	experience += gained_experience
	gold += gained_adena
	var clan_level_before: int = clan523.level()
	var clan_leveled: bool = clan523.on_hunt_experience(gained_experience) > 0 and clan523.level() != clan_level_before
	if clan_leveled:
		hud.show_message("혈맹 레벨 %d" % clan523.level())
		_request_deferred_save()
	var card_growth: Dictionary=skill_awakening.on_hunt_experience(gained_experience)
	var card_leveled: bool=card_growth.get("grants",[]).any(func(grant: Dictionary) -> bool:return int(grant.get("levels_gained",0))>0)
	if bool(card_growth.get("changed",false)):
		_request_deferred_save()
		if hud.has_method("refresh_card_skill_awakening_growth"):hud.call_deferred("refresh_card_skill_awakening_growth")
	phase = FRAME_HITCH.detail_next("kill.rewards", phase)
	hud.append_log("%s 처치 · EXP %d · 아데나 %d" % [monster.monster_name, gained_experience, gained_adena])
	phase = FRAME_HITCH.detail_next("kill.log", phase)
	_roll_drop(monster, can_drop_equipment,source_reward.get("weights",{}))
	phase = FRAME_HITCH.detail_next("kill.drop", phase)
	var blessing_spent: int=ain_service.consume_for_kill(int(monster.exp_reward), _blessing_consumption_reduction_percent())
	var level_before: int = level
	_check_level_up()
	phase = FRAME_HITCH.detail_next("kill.level", phase)
	if player.auto_enabled:
		_auto_recharge_ain()
	if monster == selected_monster:
		selected_monster = null
	if monster == auto_target:
		auto_target = null
	if monster.get_parent() == monsters_root and is_instance_valid(combat_corpses):
		monster.reparent(combat_corpses, true)
	monsterbook523_runtime.on_death(monster)
	phase = FRAME_HITCH.detail_next("kill.monsterbook", phase)
	# Ordinary kills only change rewards/vitals/blessing. Rebuilding every
	# equipment, skill, collection and inventory surface here stalls the very
	# frame in which loot appears. Level changes still publish all new stats.
	if level != level_before or card_leveled or clan_leveled:
		# A level-up with stat points already rebuilt every HUD surface this
		# frame (523.882: kill.level 615 ms + kill.hud 364 ms for one level).
		if _level_up_hud_frame != Engine.get_process_frames() or card_leveled or clan_leveled: _update_hud()
		else:
			_refresh_combat_hud()
			_update_ain_hud()
	else:
		_refresh_combat_hud()
		_update_ain_hud()
	phase = FRAME_HITCH.detail_next("kill.hud", phase)
	unconfirmed523.record_event("kill",{"source_id":int(monster.source_m_npc_id),"npc_id":int(monster.source_m_npc_id),"event_id":"%s:%d:%d"%[active_map_id,monster.get_instance_id(),monster.life_id],"player_credit":true,"amount":1})
	routines.record("kill",{"npc_id":int(monster.source_m_npc_id),"amount":1})
	if blessing_spent>0:unconfirmed523.record_event("blessing_use",{"amount":blessing_spent,"event_id":"blessing:%s:%d:%d"%[active_map_id,monster.get_instance_id(),monster.life_id]})
	if totem_changed:
		if hud.has_method("refresh_totems"): hud.call("refresh_totems")
		_request_deferred_save()
	FRAME_HITCH.detail("kill.events", phase)
	call_deferred("_ensure_monster_count")

func _kill_map_id() -> String:
	if field_map != null:
		var mid: String = str(field_map.data.get("map_id", ""))
		if not mid.is_empty():
			return mid
	return active_map_id

func recycle_monster(monster: TwilightMonster) -> bool:
	return field_population!=null and field_population.recycle(monster)

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

func _spawn_ground_drop(item_name: String, world_position: Vector2, quantity: int = 1, source_batch: String = "", metadata: Dictionary = {}) -> Button:
	var view: Button = ground_loot.spawn(item_name, world_position, quantity, source_batch, metadata)
	if is_instance_valid(view) and is_instance_valid(presentation_audio):
		presentation_audio.play_world("drop", world_position)
	return view

func _collect_ground_drop(drop: Button) -> bool:
	var pickup_started: int = FRAME_HITCH.now()
	var collected: bool = _collect_ground_drop_timed(drop)
	FRAME_HITCH.detail("loot.pickup", pickup_started)
	return collected

func _collect_ground_drop_timed(drop: Button) -> bool:
	if patch523_npc_spells.blocks("CannotLoot"): return false
	if player.is_stunned() or player.is_feared() or player.is_held(): return false
	if original_skills!=null and original_skills.stat("cannotLoot")>0:
		hud.show_message("번개화 유지 중에는 아이템을 주울 수 없습니다")
		return false
	if not ground_loot.valid_view(drop): return false
	var pending: Dictionary = ground_loot.records[str(drop.get_meta("id"))]
	if not pending.get("player_dropped",false) and RETIRED_ITEMS.record(pending.get("item_record",{})):hud.show_message(RETIRED_ITEMS.REASON);return false
	if not titles.can_pickup(pending):
		hud.show_message("상급 축복의 가루 원본 확인·최대 수량을 확인해 주세요.")
		return false
	if not INVENTORY_GROUND_TRANSFER.can_collect(self,pending):
		hud.show_message("장비 고유 ID 충돌: 바닥 아이템을 보존했습니다")
		return false
	var acquired: Dictionary=preload("res://scripts/loot/current523_native_stack.gd").collect_floor(self,drop,pending)
	if not acquired.get("handled",false):acquired=source_ground_acquisitions.collect(self,drop,pending)
	var record: Dictionary={}
	var wallet_item: String=""
	if acquired.get("handled",false):
		if not acquired.get("ok",false):hud.show_message(str(acquired.get("reason","원본 습득 저장 확인 필요")));return false
		record=acquired.record
		wallet_item=LOOT_DROP.PATCH523_DROPS.wallet_name(record.get("item_record",{}))
	else:
		record=ground_loot.take(drop, player.global_position, GROUND_PICKUP_RADIUS)
		if record.is_empty():return false
		wallet_item=LOOT_DROP.PATCH523_DROPS.wallet_name(record.get("item_record",{}))
		INVENTORY_GROUND_TRANSFER.restore_physical(self,record)
		var source_pickup: Dictionary=preload("res://scripts/cards/source_awakening_items.gd").prepare_pickup(record,item_instances,next_item_instance_id)
		item_instances=source_pickup.item_instances;next_item_instance_id=int(source_pickup.next_item_instance_id)
		var symbol_pickup: Dictionary=growth.source523.prepare_pickup(record,item_instances,next_item_instance_id)
		item_instances=symbol_pickup.item_instances;next_item_instance_id=int(symbol_pickup.next_item_instance_id)
		if wallet_item=="아데나":gold+=int(record.quantity)
		else:
			var inventory_key: String=wallet_item if not wallet_item.is_empty() else str(record.item_name)
			inventory[inventory_key]=int(inventory.get(inventory_key,0))+int(record.quantity)
	var item_name: String=str(record.item_name)
	var quantity: int=int(record.quantity)
	if item_name==titles.POWDER_KEY or item_name==titles.POWDER_SHOP_KEY:titles.reconcile_powder_stock()
	_source_dungeon_pickup(record)
	unconfirmed523.record_event("pickup",{"source_id":UNCONFIRMED523.native_id(record.get("item_record",{})),"event_id":str(record.get("id","")),"amount":quantity})
	content523.record_pickup(UNCONFIRMED523.native_id(record.get("item_record",{})),quantity)
	quest_service.record_pickup(item_name, quantity)
	if hud.has_method("refresh_quests"):
		hud.call("refresh_quests")
	if is_instance_valid(presentation_audio): presentation_audio.play_world("pickup", player.global_position)
	if pending_ground_pickup == drop: pending_ground_pickup = null
	# Original acquisition text (UITextData_Korean) with the original name.
	var shown_name: String = preload("res://scripts/ui/source523_item_identity.gd").display_name(record.get("item_record",{}) if record.get("item_record") is Dictionary else {}, item_name)
	var acquired_text: String = preload("res://scripts/ui/source523_item_identity.gd").acquire_text(shown_name, quantity)
	hud.append_log(acquired_text)
	hud.show_message(acquired_text)
	var pickup_hud_started_usec: int = Time.get_ticks_usec()
	# Stacks fold at once (bag state); the bag/quickslot/weight/speed redraw
	# runs in the next frame, coalesced for a burst of pickups, so the pickup
	# frame does not also pay for the HUD.
	var started: int=FRAME_HITCH.now()
	_merge_native_stacks()
	FRAME_HITCH.detail("loot.stack_fold_pickup",started)
	_queue_inventory_hud_refresh()
	# A wallet pickup changes only the Adena readout (coins reach the HUD with the
	# queued quickslot redraw above); no full character-sheet rebuild.
	if not wallet_item.is_empty(): _refresh_combat_hud()
	_perf_log("습득 HUD 갱신", pickup_hud_started_usec)
	if bool(record.get("player_dropped",false)): _request_deferred_save()
	return true

var _inventory_hud_queued: bool = false

func _queue_inventory_hud_refresh() -> void:
	if _inventory_hud_queued or not is_inside_tree(): 
		if not is_inside_tree(): _refresh_inventory_hud()
		return
	_inventory_hud_queued = true
	get_tree().process_frame.connect(_flush_inventory_hud, CONNECT_ONE_SHOT)

func _flush_inventory_hud() -> void:
	_inventory_hud_queued = false
	if is_inside_tree(): _refresh_inventory_hud()

## A pickup only changes item counts, physical IDs and carried weight. Rebuilding
## the whole character sheet (all derived stats, card/awakening state, portrait,
## a deep copy for the side panel) on every pickup stalled the frame; publish just
## what changed. Equipment, stats and buffs still go through _update_hud.
func _refresh_inventory_hud() -> void:
	hud_publish_counts.items += 1
	var started: int=FRAME_HITCH.now()
	_merge_native_stacks()
	FRAME_HITCH.detail("loot.stack_fold_hud",started)
	_sync_item_instances()
	combinations.invalidate();combinations.reconcile()
	var weight: int = _inventory_total_weight()
	var capacity: int = _carrying_capacity()
	var encumbrance: float = ITEM_OPTIONS.encumbrance_multiplier(weight, capacity)
	# Carried weight feeds the encumbrance movement multiplier; the bag changes
	# nothing else of the speeds (I09), so the same multiplier needs no refresh.
	if encumbrance != _speed_encumbrance: _refresh_speed_modifiers()
	var state: Variant = hud.get("character_state")
	if state is Dictionary:
		(state as Dictionary).merge({"inventory_weight":weight, "current_weight":weight, "carrying_capacity":capacity,
			"max_weight":capacity, "encumbrance_multiplier":encumbrance,
			"item_instances":item_instances}, true)
	if hud.has_method("set_quick_items"):
		hud.call("set_quick_items", inventory)
	if hud.has_method("set_quickslot_state"):
		# Re-renders quickslot counts and hands the bag its new inventory (the bag
		# rebuilds its slots only while open).
		hud.call("set_quickslot_state", effective_quickslots(), inventory, _combined_active_buffs(), self_mode_enabled)
	elif hud.has_method("set_quickslot_entries"):
		hud.call("set_quickslot_entries", effective_quickslots())
	if hud.inventory_panel.visible:
		hud.refresh_inventory(inventory)
	var bag: Variant = hud.get("lineage_inventory_ui")
	if bag is Object and is_instance_valid(bag) and (bag as Object).has_method("_refresh_weight"):
		(bag as Object).call("_refresh_weight")
	# An open character sheet shows weight-derived values; refresh it fully once.
	if str(hud.get("active_section")) == "character":
		stat_hud_refresh_pending = true
	regional_return_settings_updated.emit()

## Bag stacking (scripts/loot/native_stack_merge.gd): receipted original
## stacks of the same item/bless merge into one slot up to the original
## MaxStackAmount. Runs between transactions, never inside one; the result is
## fully validated (state_error) before it is adopted and is persisted by the
## next save. Returns how many bag slots were folded away.
func _merge_native_stacks() -> int:
	var stock: Script=preload("res://scripts/loot/current523_native_stack.gd")
	if stock.busy or source_ground_acquisitions.get("_busy")==true or not patch523_owner_state_problem.is_empty() or source_item_save_blocked: return 0
	if quest_service==null or quest_service.save_blocked or consumable_service==null or warehouse==null or ground_loot==null: return 0
	# Only repeated receipted names can reach the expensive proof/grouping pass.
	var merge: Script=preload("res://scripts/loot/native_stack_merge.gd")
	var repeated: Dictionary=merge.possible_names(item_instances)
	if repeated.is_empty():return 0
	# Keep floor expiry and its transactional save at the previous boundary.
	# An expiry save can change live owner state; take the attempt's inputs
	# afterwards and fail closed if it blocked ownership.
	var started: int=FRAME_HITCH.now()
	ground_loot.prune()
	FRAME_HITCH.detail("loot.fold_prune",started)
	if stock.busy or quest_service.save_blocked or not patch523_owner_state_problem.is_empty() or source_item_save_blocked: return 0
	var owner_inputs: Array=[]
	var snapshot := func() -> Dictionary:
		var snapshot_started: int=FRAME_HITCH.now()
		var floor: Array=ground_loot.records.values().duplicate(true)
		var dormant: Dictionary=dormant_character_items()
		owner_inputs.append_array([floor,dormant])
		var reserved: Dictionary={}
		for uid: Variant in warehouse.instances: reserved[str(uid)]=true
		for uid: Variant in dormant: reserved[str(uid)]=true
		for record: Variant in floor:
			if record is Dictionary and record.get("physical_item") is Dictionary: reserved[str(record.physical_item.get("id",""))]=true
		var state: Dictionary=consumable_service.export_state()
		FRAME_HITCH.detail("loot.fold_owner_snapshot",snapshot_started)
		return {"state":state,"reserved":reserved}
	started=FRAME_HITCH.now()
	var planned: Dictionary=merge.plan(item_instances,{},ui_preferences.get("item_locks",{}),{},repeated,snapshot)
	FRAME_HITCH.detail("loot.fold_plan",started)
	if not planned.get("changed",false): return 0
	started=FRAME_HITCH.now()
	var issue: String=stock.state_error(inventory,planned.item_instances,planned.consumable_state,warehouse.snapshot(),owner_inputs[0],owner_inputs[1])
	FRAME_HITCH.detail("loot.fold_validate",started)
	# A plan the full ownership check rejects is not adopted; the bag stays as
	# it is (still valid) and nothing is saved.
	if not issue.is_empty(): return 0
	item_instances=planned.item_instances
	consumable_service.import_state(planned.consumable_state)
	ui_preferences["item_locks"]=planned.item_locks
	_request_deferred_save()
	return int(planned.merged_slots)

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
	for returned: Dictionary in ground_loot.recovered_to_bag:
		hud.append_log("바닥 아이템 회수 · %s %d개를 가방으로 돌려놓았습니다" % [preload("res://scripts/ui/source523_item_identity.gd").plain_text(str(returned.item_name)),int(returned.quantity)])

## Quest window [모두 받기].
func claim_all_quests() -> Dictionary:
	if death_recovery.blocked(): return {"claimed":0,"failed":0}
	return quest_auto.claim_all(self)

func _claim_quest(quest_id: String) -> void:
	if death_recovery.blocked(): return
	if quest_id.begins_with("m523:quest:"):
		quest_auto.claim(self,quest_id)
		return
	hud.show_message("임시 퀘스트는 종료되었습니다 · 최신523 원본 팩을 설치하세요")
	return


func _roll_drop(monster: TwilightMonster, can_drop_tradeable_equipment: bool = true, source_weights: Dictionary = {}) -> void:
	if monster == null or not is_instance_valid(monster):
		return
	var quest_eligibility: Variant=get_meta("base508_drop_quest_eligibility",{})
	if not quest_eligibility is Dictionary: quest_eligibility={}
	var earned: Array[Dictionary] = LOOT_DROP.roll_detailed(monster.drop_items, monster.is_boss, loot_catalog, rng, monster.monster_name, monster.loot_source_identity, _kill_map_id(),source_weights,quest_eligibility)
	# Source membership is exact; chance and one-item quantity are host policy.
	# A provider already producing this exact key owns that reward instead.
	var already_powder:=false
	for entry: Dictionary in earned:
		if entry.get("item_name")==titles.source.powder_record.get("name",""): already_powder=true
	if not already_powder and titles.source.powder_npcs.has(monster.source_m_npc_id):
		var powder: Dictionary=titles.powder_drop(monster.source_m_npc_id,monster.source_m_original,rng.randf())
		if not powder.is_empty(): earned.append(powder)
	if earned.is_empty():
		return
	var batch_id: String = ground_loot.begin_hunt_batch()
	for entry: Dictionary in earned:
		var item_name: String = str(entry["item_name"])
		var quantity: int = maxi(1, int(entry.get("quantity", 1)))
		if not can_drop_tradeable_equipment and not item_name.contains("각인"):
			var drop_record: Dictionary = _find_catalog_item_record(item_name)
			if _equipment_slot_base(drop_record) != "":
				continue
		var metadata: Dictionary=LOOT_DROP.PATCH523_DROPS.ground_metadata(entry)
		if metadata.is_empty():metadata=LOOT_DROP.BASE508_DROPS.ground_metadata(entry,not _enhancement_kind_for_record(entry.get("item_record",{})).is_empty())
		_spawn_ground_drop(item_name, monster.global_position, quantity, batch_id, metadata)
	hud.show_message("아이템이 바닥에 떨어졌습니다")


func _physical_hit_chance(attacker_accuracy: int, target_ac: int, avoidance: int) -> float:
	return PHYSICAL_RESOLUTION.physical_hit_chance(attacker_accuracy,target_ac,avoidance)

func _avoidance_for_attack_type(attack_type: String) -> int:
	return _effective_er() if attack_type == "ranged" else _effective_dg()

func _monster_accuracy_for_attack_type(attacker: TwilightMonster, attack_type: String) -> int:
	if attacker == null:
		return 0
	match attack_type:
		"magic":
			return attacker.magic_accuracy+growth.guardian_combat.npc_accuracy_delta(attacker,"magic")
		"ranged":
			return attacker.ranged_accuracy+int(original_skills.status.modifier(attacker,"source_ranged_hit") if original_skills!=null else 0)+growth.guardian_combat.npc_accuracy_delta(attacker,"ranged")+patch523_npc_spells.extensions.remaining.accuracy(attacker,"ranged")
		_:
			return attacker.melee_accuracy+int(original_skills.status.modifier(attacker,"source_melee_hit") if original_skills!=null else 0)+growth.guardian_combat.npc_accuracy_delta(attacker,"melee")+patch523_npc_spells.extensions.remaining.accuracy(attacker,"melee")+EQUIPMENT523_INVOKE_DEBUFF.accuracy_delta(attacker,"melee")

func _monster_hit_chance(attacker: TwilightMonster, attack_type: String = "melee") -> float:
	if attacker == null:
		return 0.05
	var normalized_type: String = attack_type
	if normalized_type != "ranged" and normalized_type != "magic":
		normalized_type = "melee"
	var accuracy: int = _monster_accuracy_for_attack_type(attacker, normalized_type)
	if normalized_type == "magic":
		return _magic_hit_chance(accuracy, _effective_mr())*halphas_star.combat.hit_factor(attacker)
	return _physical_hit_chance(
		accuracy,
		_effective_ac(),
		_avoidance_for_attack_type(normalized_type)
	)*halphas_star.combat.hit_factor(attacker)

func _roll_monster_hit(attacker: TwilightMonster, attack_type: String = "melee") -> bool:
	return rng.randf() < _monster_hit_chance(attacker, attack_type)

func _respawn_player(message_text: String) -> void:
	unconfirmed523.record_event("player_death",{"event_id":"death:%d"%Time.get_ticks_usec()})
	preload("res://scripts/loot/patch523_item_use.gd").clear_on_death(self)

	equipment523.on_death(self)
	if not dungeon_play.state.active.is_empty() and dungeon_play.state.active.status=="active": dungeon_play.stop()
	if source_dungeon_runs.state.active.get("host_kind","") == "twilight_local" and source_dungeon_runs.state.active.get("status","") == "active":
		local_dungeon_failure_pending = true
		LOCAL_TOWER.tick(self)
	if death_recovery.blocked(): return
	preload("res://scripts/loot/patch523_item_use.gd").clear_on_death(self)
	preload("res://scripts/shop/source523_wisdom.gd").clear_on_death(self)
	var death_position: Vector2 = player.global_position
	var death_sprite: AnimatedSprite2D = player.transform_sprite if player.transform_active else player.class_sprite
	if not player.transform_active and player.spx_sprite != null and player.spx_sprite.visible:
		death_sprite = player.spx_sprite
	var death_texture: Texture2D = death_sprite.sprite_frames.get_frame_texture(death_sprite.animation, death_sprite.frame) if death_sprite.sprite_frames != null else null
	var death_scale: Vector2 = death_sprite.scale
	var death_offset: Vector2 = death_sprite.position
	death_recovery.begin_death(message_text)
	if player.original_source_preview.current523_source_only_presentation():
		player.original_source_preview.notify_current_source_death_pose(death_position,player.motion.facing8)
	elif combat_vfx != null and death_texture != null:
		var death_animation: String = ""
		# S-only refined sets author one death_2 that every facing reuses, the
		# same policy ActorMotion applies to monsters; without it the corpse
		# showed a single static frame.
		for candidate: String in ["death_" + str(player.facing8), "death" + ["_down", "_up", "_left", "_right"][player.facing], "death", "death_2"]:
			if death_sprite.sprite_frames.has_animation(candidate):
				death_animation = candidate
				break
		combat_vfx.death_pose(death_position, death_texture, death_scale, death_offset, death_sprite.sprite_frames, death_animation, death_sprite.get_meta("base_scale", Vector2.ONE))

func _on_player_poison_tick(damage_value: int) -> void:
	if damage_value <= 0 or hp <= 0:
		return
	var poison_damage: int = growth.guardian_combat.poison_damage(card_collections.incoming_damage(half_elixir.incoming(_source_dot_damage(damage_value,"poison"), "poison", false, false, true),"poison"))
	hp = maxi(0, hp - poison_damage)
	player.show_poison_damage(poison_damage)
	hud.append_log("독 피해 %d" % poison_damage)
	if hp <= 0:
		_respawn_player("독 피해로 사망 후 부활했습니다")
		_update_hud()
	else:
		_refresh_combat_hud()

func _on_player_bleed_tick(damage_value: int) -> void:
	if damage_value <= 0 or hp <= 0:
		return
	var bleed_damage: int = _source_dot_damage(damage_value,"bleed")
	hp = maxi(0, hp - bleed_damage)
	player.show_bleed_damage(bleed_damage)
	hud.append_log("출혈 피해 %d" % bleed_damage)
	if hp <= 0:
		_respawn_player("출혈 피해로 사망 후 부활했습니다")
		_update_hud()
	else:
		_refresh_combat_hud()

func _on_player_hit(attacker: TwilightMonster, damage_value: int, attack_type: String, by_spell: bool = false, guard_kind: String = "") -> void:
	if _source_combat_targets_hidden(): return
	if attacker == null or not is_instance_valid(attacker) or attacker.dead or hp <= 0:
		return
	if field_map != null and field_map.is_safe(player.global_position):
		return
	damage_value = patch523_npc_spells.extensions.outgoing(attacker,damage_value,attack_type)
	var normalized_type: String = attack_type
	if normalized_type != "ranged" and normalized_type != "magic":
		normalized_type = "melee"
	damage_value = EQUIPMENT523_INVOKE_DEBUFF.outgoing(attacker,damage_value,normalized_type)
	# A typed source physical spell affects only the guard selector. Keep the
	# established hit, damage, resistance and critical channel unchanged.
	var source_spell: bool = by_spell or attacker.symbol_hit_context.has("boss_kind")
	var guard_attack: String = guard_kind if guard_kind in ["melee","ranged","magic"] else normalized_type
	var attacker_is_pc: bool = bool(attacker.get_meta("is_player_combatant",false))
	var accuracy: int = _monster_accuracy_for_attack_type(attacker, normalized_type)
	var hit_chance: float = _monster_hit_chance(attacker, normalized_type)
	if not _roll_monster_hit(attacker, normalized_type):
		# A source defense option may observe a failed attack (Param4). The
		# service owns that trigger; this remains a MISS with no guard hit spent.
		equipment523.incoming(self,guard_attack,source_spell,attacker_is_pc,false)
		if original_skills != null: original_skills.on_evaded(attacker)
		PATCH523_EQUIPMENT_COMBAT.fixed_counter(self,attacker,normalized_type,0,true)
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
	if equipment523.incoming(self,guard_attack,source_spell,attacker_is_pc):
		player.show_status_text("GUARD")
		_refresh_combat_hud()
		return
	if card_collections.blocks_weapon_hit(normalized_type,rng):
		damage_value=maxi(0,int(round(damage_value*(1.0-float(card_collections.policy_values.weapon_block_reduction)/100.0))))
		hud.append_log("무기 막기 · "+attacker.monster_name)
		if damage_value<=0:player.show_miss();return
	var collection_context: Dictionary=card_collections.incoming_context(attacker,normalized_type)
	var final: Dictionary=card_collections.incoming_final_blow(damage_value,normalized_type,collection_context,rng)
	damage_value=int(final.damage)
	if final.triggered:hud.append_log("몬스터 결정타 · "+attacker.monster_name)
	var attack_element: String = ELEMENT_RULES.channel(attacker.attack_element)
	collection_context.physical_magic=normalized_type=="magic" and attack_element=="physical"
	var attacker_critical_rate: int = attacker.critical_rate_for_type(normalized_type)
	var elemental_critical_resistance: int = int(half_elixir.value("ElementalCriticalResistance")) if ELEMENT_RULES.channel(attacker.attack_element) != "physical" else 0
	var source_critical_resist: int = int(EQUIPMENT523_COMBAT.elemental_critical_resistance(_all_equipped_records())) if ELEMENT_RULES.channel(attacker.attack_element) != "physical" else 0
	var critical_chance: float = _critical_chance(attacker_critical_rate, _critical_resistance_stat(normalized_type,attack_element!="physical") + elemental_critical_resistance + source_critical_resist)
	var critical: bool = rng.randf() < critical_chance
	var contextual_damage: int=maxi(1,damage_value+int(original_skills.status.modifier(attacker,"source_"+normalized_type+"_damage") if original_skills!=null else 0)+growth.guardian_combat.npc_damage_delta(attacker,normalized_type))
	var incoming_damage: int = _critical_damage(contextual_damage) if critical else contextual_damage
	if titles.bonus("WeaponBlock")>0: incoming_damage=titles.incoming(incoming_damage,normalized_type,rng.randf())
	var reduced: int = maxi(1, incoming_damage - int(protection523.effects().title_flat)) if normalized_type == "magic" else _physical_damage_after_reduction(incoming_damage)
	reduced = quest_item_provider.equipment_owner.reduce_hit(self,reduced,normalized_type)
	if attack_element != "physical":
		reduced = ELEMENT_RULES.damage_after_resistance(reduced, _player_element_resistance(attack_element))
	var ignore_percent: float=card_collections.incoming_ignore(collection_context)
	collection_context.ignore_remaining=maxf(0.0,ignore_percent-_pve_reduction_percent(normalized_type,attacker_is_pc))
	reduced = _pve_damage_after_item_buffs(reduced,ignore_percent,normalized_type,attacker_is_pc)
	reduced = card_collections.incoming_damage(reduced,normalized_type,critical,collection_context)
	reduced = half_elixir.incoming(reduced, normalized_type, attack_element != "physical")
	var totem_reduction: int = totems.bonus({"melee":"MeleeDamageReductionPercent","ranged":"RangeDamageReductionPercent","magic":"MagicDamageReductionPercent"}.get(normalized_type,""))
	reduced = maxi(1,int(round(float(reduced)*(1.0-clampf(float(totem_reduction)/1000000.0,0,1)))))
	reduced = monsterbook523_runtime.incoming_damage(reduced,normalized_type)
	var growth_max_hp: int = _effective_max_hp() if growth.bonus("low_hp_reduction:percent")>0 else 0
	var symbol_context: Dictionary=attacker.symbol_hit_context.duplicate(true)
	symbol_context["channel"]="dark" if attacker.attack_element=="dark" else normalized_type
	reduced = growth.incoming_damage(reduced,critical,player.is_stunned(),hp,growth_max_hp,symbol_context)
	if growth.combat.veil_fired:hud.append_log("실렌의 장막 · 피격 리덕션 300")
	if original_skills != null:
		reduced = original_skills.incoming_damage(attacker, normalized_type, reduced)
		if original_skills.last_evaded:
			PATCH523_EQUIPMENT_COMBAT.fixed_counter(self,attacker,normalized_type,0,true)
			player.show_miss()
			_refresh_combat_hud()
			return
	var guardian_context: Dictionary={"pvp":bool(attacker.get_meta("is_player_combatant",false)),"spell_tags":attacker.get_meta("source_spell_tags",[])}
	reduced=unconfirmed523.incoming_damage(reduced,normalized_type,guardian_context)
	var guardian_result: Dictionary=growth.guardian_combat.incoming(attacker,normalized_type,reduced,critical,guardian_context)
	if guardian_result.blocked:
		player.show_miss();_refresh_combat_hud();return
	reduced=int(guardian_result.damage)
	var option_result: Dictionary=option_awakening.combat.incoming(attacker,normalized_type,reduced)
	reduced=totem_combat.incoming(attacker,normalized_type,int(option_result.damage))
	reduced=PATCH523_EQUIPMENT_COMBAT.incoming(self,attacker,normalized_type,reduced)
	if reduced > 0:
		reduced = maxi(1,reduced - EQUIPMENT523_COMBAT.critical_reduction(_all_equipped_records(),critical))
		if attack_element != "physical": reduced = maxi(1,reduced - EQUIPMENT523_COMBAT.elemental_reduction(_all_equipped_records()))
	hp = maxi(0, hp - reduced)
	patch523_npc_spells.extensions.on_player_event("attacked")
	if hp>0 and int(option_result.heal)+int(guardian_result.heal)>0:hp=mini(_effective_max_hp(),hp+int(option_result.heal)+int(guardian_result.heal))
	if reduced > 0 and is_instance_valid(presentation_audio): presentation_audio.play_world("hurt", player.global_position)
	if hp > 0:
		_try_active_counterattack(attacker, normalized_type, reduced)
	if attacker.dead:
		player.show_received_damage(reduced, critical, normalized_type, attacker.combat_hit_position())
		_refresh_combat_hud()
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
	if hp>0:halphas_star.combat.incoming(attacker)
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
	else:
		_refresh_combat_hud()

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
	_request_deferred_save()

## The original boss overhead mark for NPC class `npc_class_id` (null: none).
func original_boss_overhead(npc_class_id: int) -> Node2D:
	var controller: Variant = hud.get("original_main_ui_controller") if hud != null else null
	if not is_instance_valid(controller) or not controller.has_method("boss_overhead"): return null
	return controller.boss_overhead(npc_class_id)

func _check_level_up(quiet: bool=false) -> void:
	var gained_stat_points: bool = false
	var reached: Array = []
	while experience >= exp_need:
		experience -= exp_need
		level += 1
		reached.append(level)
		exp_need = EXP_PROGRESSION.required_for_level(level, exp_need)
		max_hp += 45
		max_mp += 9
		hp = _effective_max_hp()
		mp = max_mp
		attack_power += 2
		defense += 1
		var awarded_points: int = _stat_points_for_level_up(level)
		stat_points += awarded_points
		if quiet: continue
		if awarded_points > 0:
			gained_stat_points = true
			if not quiet:hud.show_message("레벨 업! Lv.%d · 스탯 포인트 +%d" % [level, awarded_points])
			if not quiet:hud.append_log("Lv.%d 달성 · 스탯 포인트 +%d" % [level, awarded_points])
		elif not quiet:
			hud.show_message("레벨 업! Lv.%d" % level)
	var level_stage: int = FRAME_HITCH.now()
	if gained_stat_points and not quiet:
		_update_hud()
		_level_up_hud_frame = Engine.get_process_frames()
		hud.call_deferred("open_character")
	level_stage = FRAME_HITCH.detail_next("level.hud", level_stage)
	if not quiet and not reached.is_empty(): _play_original_level_up(reached)
	FRAME_HITCH.detail("level.presentation", level_stage)

## Frame in which _check_level_up already rebuilt the whole HUD.
var _level_up_hud_frame: int = -1

## The original Hud_LevelUp presentation with this class's LevelUpEffectDesc
## guidance for every level reached (presentation only).
func _play_original_level_up(reached: Array) -> void:
	var controller: Variant = hud.get("original_main_ui_controller") if hud != null else null
	if not is_instance_valid(controller) or not controller.has_method("play_level_up"): return
	var guidance: Array[Dictionary] = preload("res://scripts/ui/original_ui/source_main_level_up.gd").rows_for(BASE508.source_class_id(job_class), reached)
	controller.play_level_up(int(reached[-1]), guidance)

func _select_nearest_target() -> void:
	# An explicit tap must retry even if AUTO recently cached a failed route.
	var target: TwilightMonster = _nearest_reachable_monster(600.0, true)
	if target == null:
		hud.show_message("경로 준비 중 · 잠시 후 다시 시도하세요" if _native_route_pending() else "선택할 수 있는 몬스터가 없습니다")
		return
	_select_monster(target)
	hud.show_message("대상 선택: %s" % target.monster_name)

func _scroll_kind(scroll_name: String, owned_record: Dictionary = {}) -> String:
	if scroll_name.begins_with("[원본 보상] "): return ""
	var lookup: Dictionary=owned_record if not owned_record.is_empty() else _find_catalog_item_record(scroll_name)
	if lookup.get("source_m_native_item",false):
		return "source" if PATCH523_ENHANCE_SOURCE.declares_scroll(lookup) else ""
	if scroll_name.find("무기 마법 주문서") >= 0:
		return "weapon"
	if scroll_name.find("갑옷 마법 주문서") >= 0:
		return "armor"
	if scroll_name.find("장신구 마법 주문서") >= 0:
		return "accessory"
	var source_id: String=PATCH523_ENHANCE.item_id(lookup)
	for link: Dictionary in patch523_equipment.item_entry(source_id).get("item_bonuses",[]):
		if int(patch523_equipment.bonus_row(str(int(link.BonusID))).get("BonusTypeID",0)) in [2022,8352]: return "source"
	return ""

func _scroll_mode(scroll_name: String) -> String:
	if scroll_name.begins_with("TWILIGHT · ") and scroll_name.contains("(축복)"):return "blessed_orim"
	var issued: Dictionary=_patch523_expedition_scroll(scroll_name)
	if issued.get("ok",false):return {1:"normal",2:"blessed",3:"cursed"}[int(issued.bless_code)]
	var source: Dictionary=_find_catalog_item_record(scroll_name)
	if PATCH523_ENHANCE.item_id(source) in ["137","138","6401","6411"] and source.get("source_bless_raw")==3:return "cursed"
	if scroll_name.find("저주받은")>=0:return "cursed"
	if scroll_name.find("축복받은 오림") >= 0:
		return "blessed_orim"
	if scroll_name.find("오림") >= 0:
		return "orim"
	if scroll_name.find("장인의") >= 0:
		return "craftsman"
	if scroll_name.find("축복받은") >= 0:
		return "blessed"
	return "normal"

# Temporary catalog test grants. Never available in the production/main HUD.
# Only catalog-backed names and the three known enhancement scrolls are accepted.
func source_item_record(item_class_id: int, bless_raw: int = 1) -> Dictionary:
	if RETIRED_ITEMS.item(item_class_id):return {}
	var record: Dictionary = LOOT_DROP.PATCH523_DROPS.cached_definition(str(item_class_id)).get("native_record",{})
	if record.is_empty() or record.get("source_test_item",true) or bless_raw not in [1,2,3]: return {}
	return LOOT_DROP.PATCH523_DROPS.variant_item(record,bless_raw)

func source_item_definition(item_class_id: int) -> Dictionary:
	return LOOT_DROP.PATCH523_DROPS.definition_id(str(item_class_id))

func source_symbol_reward_record(item_id: int, registered: Dictionary, authored: Dictionary) -> Dictionary:
	return growth.source523.reward_record(item_id, registered, authored)

func stage_source_item_grants(grants: Array, supplier: Dictionary) -> Dictionary:
	return preload("res://scripts/loot/patch523_item_inventory.gd").stage(self,grants,supplier)

func _grant_playtest_catalog_item(item_name: String, amount: int) -> void:
	if not preload("res://scripts/boot/build_flags.gd").playtest(): return
	var source_record: Dictionary = _find_catalog_item_record(item_name)
	if RETIRED_ITEMS.record(source_record):hud.show_message(RETIRED_ITEMS.REASON);return
	if source_record.get("source_m_native_item",false) and LOOT_DROP.PATCH523_DROPS.data().get("full_item_catalog",false):
		var grant: Dictionary = {"item_class_id":int(source_record.get("source_item_class_id",-1)),"amount":clampi(amount,1,10),"bless_raw":int(source_record.get("source_bless_raw",1)),"enchant":0}
		if preload("res://scripts/loot/patch523_item_inventory.gd").commit(self,[grant],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}): hud.show_message("원본 도감 테스트 지급 · "+str(source_record.get("source_display_name",item_name)))
		return
	if item_name.is_empty() or CONSUMABLE_RULES.is_removed_item(item_name):
		hud.show_message("테스트 지급 불가 아이템")
		return
	var permitted: bool = CARD_PACK_ITEMS.is_pack(item_name) or not _find_catalog_item_record(item_name).is_empty()
	if not permitted:
		permitted = item_name in ["무기 마법 주문서 (각인)", "갑옷 마법 주문서 (각인)", "장신구 마법 주문서 (각인)"]
	if not permitted:
		hud.show_message("도감에 없는 아이템은 지급할 수 없습니다")
		return
	var quantity: int = clampi(amount,1,10)
	inventory[item_name] = int(inventory.get(item_name,0)) + quantity
	_sync_item_instances()
	hud.refresh_inventory(inventory)
	_update_hud()
	hud.show_message("테스트 지급 · %s ×%d" % [item_name,quantity])
	hud.append_log("테스트 도감 지급 · %s ×%d" % [item_name,quantity])
	_save_game(true)

func _grant_playtest_catalog_variant(source_id: String, amount: int) -> void:
	if not preload("res://scripts/boot/build_flags.gd").playtest(): return
	var record: Dictionary = _catalog_item_from_source_id(source_id)
	if record.is_empty() or str(record.get("name", "")) == "":
		hud.show_message("유효하지 않은 도감 원본 ID")
		return
	var item_name: String = str(record.get("name", ""))
	# Non-equipment inventory is still name-keyed: do not merge distinct
	# source records into a counterfeit legacy item stack.
	if _enhancement_kind_for_record(record) == "" and int(catalog_item_variant_count.get(item_name, 0)) > 1:
		hud.show_message("동명이인 비장비 아이템은 ID별 지급 준비 중")
		return
	var old_ids: Dictionary = item_instances.duplicate()
	_grant_playtest_catalog_item(item_name, amount)
	if growth.source523.material({"name":item_name,"record":record}):
		var source_pickup: Dictionary = growth.source523.prepare_pickup({"item_name":item_name,"item_record":record,"quantity":clampi(amount,1,10)},item_instances,next_item_instance_id)
		item_instances = source_pickup.item_instances; next_item_instance_id = int(source_pickup.next_item_instance_id)
		_update_hud()
		_save_game(true)
	if _enhancement_kind_for_record(record) != "":
		for raw_id: Variant in item_instances.keys():
			if old_ids.has(raw_id):
				continue
			var entry: Dictionary = item_instances[raw_id] as Dictionary
			if str(entry.get("name", "")) != item_name:
				continue
			entry["record"] = record.duplicate(true)
			entry["sourceId"] = source_id
		# Publish and save the pinned source record after the legacy grant.
		_update_hud()
		_save_game(true)

func _grant_playtest_aden() -> void:
	if not preload("res://scripts/boot/build_flags.gd").playtest(): return
	gold = maxi(gold,100000000)
	_update_hud()
	hud.show_message("테스트 아데나 · 현재 %d" % gold)
	_save_game(true)

func _use_card_pack_item(item_name: String) -> void:
	if not _patch523_item_allowed(): return
	if _option_awakening_busy(): return
	if hud.has_method("is_card_reveal_busy") and bool(hud.call("is_card_reveal_busy")):
		return
	var spec: Dictionary = CARD_PACK_ITEMS.definition(item_name)
	if spec.is_empty() or int(inventory.get(item_name, 0)) < 1:
		hud.show_message("뽑기권이 없습니다")
		return
	var category: String = str(spec.get("category", ""))
	var count: int = int(spec.get("count", 0))
	if not card_draw_fusion.can_draw(category):
		hud.show_message("해당 종류의 뽑기 카드 목록이 부족합니다")
		return
	# Persist an atomic (card ownership + ticket debit) transaction. Never show
	# a new card or consume the ticket if the old save cannot be replaced.
	var phase: int = FRAME_HITCH.now()
	var cards_before: Dictionary = card_draw_fusion.draw_checkpoint(category)
	var ticket_before: int = int(inventory.get(item_name, 0))
	var outcome: Dictionary = card_draw_fusion.draw_cards(category, count)
	FRAME_HITCH.detail("card.normal_draw", phase)
	if not bool(outcome.get("ok", false)):
		card_draw_fusion.restore_draw_checkpoint(category, cards_before)
		hud.show_message(str(outcome.get("error", "뽑기 실패")))
		return
	var remaining: int = ticket_before - 1
	if remaining == 0:
		inventory.erase(item_name)
	else:
		inventory[item_name] = remaining
	var grades: Dictionary = {}
	for raw: Variant in outcome.get("results", []) as Array:
		if raw is Dictionary:
			var grade: String = str((raw as Dictionary).get("grade", ""))
			grades[grade] = int(grades.get(grade, 0)) + 1
	var message: String = "%s %d회 완료 · 고급 %d · 희귀 %d · 영웅 %d · 전설 %d" % [
		category, count, int(grades.get("고급", 0)), int(grades.get("희귀", 0)),
		int(grades.get("영웅", 0)), int(grades.get("전설", 0))]
	phase = FRAME_HITCH.now()
	var saved: Error = _save_game(true)
	FRAME_HITCH.detail("card.normal_save", phase)
	if saved != OK:
		card_draw_fusion.restore_draw_checkpoint(category, cards_before)
		_invalidate_equipment_static()
		inventory[item_name] = ticket_before
		hud.refresh_inventory(inventory)
		hud.show_message("뽑기 저장 실패 · 뽑기권과 카드 보유 상태를 복구했습니다")
		return
	routines.record("card_buy",{"deck":int(ROUTINE523.CARD_DECKS.get(category,0)),"amount":1})
	phase = FRAME_HITCH.now()
	# Reuse the original-ticket publication batch for this normal ticket.
	# Supplied counts, physical instances and cards reach the HUD before reveal.
	if hud.has_method("publish_committed_ticket_hud"):
		hud.publish_committed_ticket_hud(_publish_normal_card_pack_hud)
	else:
		_publish_normal_card_pack_hud()
	FRAME_HITCH.detail("card.normal_hud_publish", phase)
	hud.call("set_card_draw_fusion_result", category, message)
	hud.show_message(message)
	hud.append_log(message)
	phase = FRAME_HITCH.now()
	hud.call("present_card_reveal", category, outcome, false)
	FRAME_HITCH.detail("card.normal_reveal", phase)

func _publish_normal_card_pack_hud() -> void:
	hud.refresh_inventory(inventory)
	_update_hud()

func _on_blessing_target_requested(scroll_reference: String, target_reference: String) -> void:
	if consumable_service == null or scroll_reference.is_empty(): return
	if int(inventory.get(_parse_enhancement_target(scroll_reference).name, 0)) < 1:
		hud.show_message("축복 주문서가 없습니다")
		return
	consumable_service.call("apply_bless_scroll", scroll_reference, target_reference)
	_update_hud()

func _item_requests_map_loading(reference: String) -> bool:
	if not current523_aden_source_active(): return false
	var selection: Dictionary = _parse_enhancement_target(reference)
	var item_name: String = selection.name
	var record: Dictionary = item_instances.get(str(selection.get("id","")),{}).get("record",{})
	if record.is_empty(): record = _find_catalog_item_record(item_name)
	var effects: Script = preload("res://scripts/loot/source523_item_effects.gd")
	if not effects.teleport(record).is_empty() or not effects.location_teleport(record).is_empty():
		return true
	var kind: String = str(CONSUMABLE_RULES.definition(item_name).get("kind",""))
	return kind == "return" or (kind == "teleport" and not growth.travel.enabled()) or REGIONAL_RETURN.claims_identity(item_name,record)


func _activate_inventory_input(reference: String) -> void:
	if MAP_LOADING.busy(self): return
	if _item_requests_map_loading(reference):
		await run_map_loading(_activate_travel_item.bind(reference))
		return
	_on_inventory_item_activated(reference)


func _activate_travel_item(reference: String) -> Dictionary:
	await _activate_inventory_impl(reference,true)
	return {}


func _on_inventory_item_activated(item_name: String) -> void:
	call("_activate_inventory_impl",item_name,false)

func _activate_inventory_impl(item_name: String, loading: bool) -> void:
	if death_recovery.blocked(): return
	var source_reward: Dictionary = _find_catalog_item_record(_parse_enhancement_target(item_name).name)
	if source_reward.get("monsterbook_source_item",false):
		if hud.has_method("open_mystery_card523") and hud.open_mystery_card523(str(source_reward.name)): return
		if not MONSTERBOOK523_RUNTIME.progression_enabled():
			hud.show_message(MONSTERBOOK523_RUNTIME.PAUSED_MESSAGE)
			return
		hud.open_monsterbook523()
		var panel: Control = hud.find_child("MonsterBook523Panel",true,false)
		if panel != null: panel.focus_owned_item(str(source_reward.name))
		return
	var selected: Dictionary = _parse_enhancement_target(item_name)
	item_name = str(selected.get("name", item_name))
	var selected_source: Dictionary=item_instances.get(str(selected.get("id","")),{}).get("record",source_reward)
	if RETIRED_ITEMS.record(selected_source) or RETIRED_ITEMS.retired_reference(item_name) or RETIRED_ITEMS.QUEST_ONLY.matches_reference(selected_source,item_name):
		hud.show_message(RETIRED_ITEMS.REASON)
		return
	var dummy_reason: String=preload("res://scripts/quests/source_dummy523.gd").reason(selected_source)
	if not dummy_reason.is_empty():hud.show_message(dummy_reason);return
	if tj_coupons.try_open_owned_coupon(item_name,str(selected.get("id","")),selected_source):return
	if selected_source.get("source_m_native_item") == true and NATIVE_FIELDS.field(selected_source,"source_category_name") == "ScrollGachaCraft":
		var book_id := int(selected_source.get("source_item_class_id",0))
		var book_uid := str(selected.get("id",""))
		if book_uid.is_empty() or item_name != selected_source.get("name") or not _patch523_item_allowed() or hp <= 0 or _option_awakening_busy():
			hud.show_message("사용할 수 있는 가방의 비법서를 선택하세요")
		else:
			hud.open_gacha_craft523(book_id,book_uid)
		return
	if _open_owned_seal_scroll(item_name,str(selected.get("id","")),selected_source):return
	if preload("res://scripts/shop/source523_cash_packages.gd").try_use(self,item_name):return
	if alchemy_held_items.try_use(self,item_name,str(selected.get("id",""))):return
	if unconfirmed523.try_use(item_name):return
	if str(selected.get("id","")).is_empty() and quest_item_provider.equipment_owner.requires_selected(self,item_name):hud.show_message("실제 장비 개체를 선택하세요");return
	if quest_item_provider.equipment_owner.activate(self,str(selected.get("id",""))):return
	var doll_unlock: Dictionary=option_awakening.use_native_unlock_item(item_name,str(selected.get("id","")))
	if doll_unlock.get("handled",false):
		hud.show_message(str(doll_unlock.get("message",doll_unlock.get("error","원본 인형 해금 입력 확인 필요"))))
		if doll_unlock.get("ok",false):_update_hud();hud.refresh_inventory(inventory)
		return
	var awakening_item: Dictionary=option_awakening.use_source_awakening_item(item_name,str(selected.get("id","")))
	if awakening_item.get("handled",false):
		hud.show_message(str(awakening_item.get("message",awakening_item.get("error","원본 각성 물품 확인 필요"))))
		if awakening_item.get("ok",false):_update_hud();hud.refresh_inventory(inventory)
		return
	if item_name.begins_with("[원본 보상] "):
		if quest_item_provider.try_use_held(self,str(selected.get("id",""))): return
		hud.show_message("원본 보상 보관 중 · 사용 기능 연결 대기")
		return
	if _open_owned_native_enhancement(item_name,str(selected.get("id","")),selected_source):return
	if _open_owned_native_smelt(str(selected.get("id","")),selected_source):return
	var stack_owner: Script = preload("res://scripts/loot/current523_native_stack.gd")
	var selected_id: String = str(selected.get("id",""))
	var native_stack: Dictionary
	if loading: native_stack = await stack_owner.try_use_loading(self,item_name,selected_id,false)
	else: native_stack = stack_owner.try_use(self,item_name,selected_id,false)
	if native_stack.get("handled",false):
		if native_stack.get("silent",false):return # The owner shows its own chooser or message.
		# 선택 상자: the original selection window (patch523_reward_choice).
		if native_stack.get("requires_original_selection",false) and consumable_service.open_owned_original_selection(item_name,native_stack):return
		hud.show_message(str(native_stack.get("message",native_stack.get("reason","원본 물리 수량 확인 필요"))))
		if native_stack.get("ok",false):
			if native_stack.get("effect_kind")=="buff":_publish_timed_buff_hud()
			else:hud.refresh_inventory(inventory);_update_hud()
		return
	if quest_item_provider.try_use_inventory(self,item_name): return
	if _find_catalog_item_record(item_name).get("source_automation_catalog_only",false):
		hud.show_message("원본 사용 효과 미연결 · 보관/판매 가능 · 아이템 보존")
		return
	if not half_elixir.item_action(item_name).is_empty():
		hud.open_half_elixir(item_name)
		return
	if CONSUMABLE_RULES.is_removed_item(item_name):
		hud.show_message("삭제된 상태이상 해제 물약입니다")
		return
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("아이템이 없습니다")
		return
	if item_name.begins_with("m523-growth-item:"):
		if item_name == GROWTH96.Source.item_key(GROWTH96.Source.TOKEN): hud.open_growth96()
		else:
			var opened: Dictionary = _open_growth_reward_box(item_name)
			if not opened.get("ok", false): hud.show_message(str(opened.get("reason", "미개봉 성장 보상 상자입니다")))
		return
	var issued_scroll: Dictionary=patch523_open_expedition_enhancement(item_name)
	if issued_scroll.get("handled",false):
		if not issued_scroll.get("ok",false):hud.show_message(str(issued_scroll.error))
		return
	if not patch523_equipment.data.is_empty():
		for source_id: String in ["30701","130611"]:
			if patch523_equipment.record(source_id).get("name","")==item_name and patch523_equipment.data.get("guaranteed_boxes",{}).has(source_id):
				hud.confirm_action("인장 상자 개봉", "상자 1개를 소비하여 일반 +0 인장 1개와 빛나는 장비 강화 주문서 8개를 확정 지급합니다.", "개봉", func(_count: int) -> void: _patch523_open_box(source_id))
				return
	var source_use_record: Dictionary = _patch523_use_record(str(selected.get("name",item_name))+ ("@@@"+str(selected.id) if not str(selected.get("id","")).is_empty() else ""))
	var source_use_reason: String = PATCH523_ITEM_USE.reason(source_use_record,level,BASE508.source_class_id(job_class))
	if not source_use_reason.is_empty():
		hud.show_message(source_use_reason)
		return
	var symbol_instance_id: String = str(selected.get("id",""))
	var symbol_unit: Dictionary = item_instances.get(symbol_instance_id,{})
	if not symbol_instance_id.is_empty() and growth.source523.reset_material(symbol_unit):
		hud.open_growth("emblems")
		return
	if not symbol_instance_id.is_empty() and not growth.source523.recharge(symbol_unit).is_empty():
		var converted: Dictionary = growth.execute("recharge",symbol_instance_id,1,int(growth.state.revision))
		hud.show_message(str(converted.message))
		return
	if dungeon_play.try_use_item(item_name,str(selected.get("id",""))):return
	# Pass the exact physical native ticket selected in the bag. Legacy
	# expedition/catalog-only ticket lanes retain their name-based API.
	var ticket_id: String=str(selected.get("id","")) if selected_source.get("source_m_native_item",false) else ""
	if source_shop.try_use_inventory_ticket(item_name,ticket_id):return
	if preload("res://scripts/shop/source523_skill_books.gd").try_use(self,item_name): return
	if loading:
		if await consumable_service.try_use_regional_return_loading(item_name): return
	elif consumable_service.try_use_regional_return(item_name): return
	if protection523.managed(_find_catalog_item_record(item_name)):
		_request_protection523_use(item_name)
		return
	# Completion boxes stay local; other source items enter a shared consumer
	# only after an atomic, exact-ID native handoff. Missing consumers preserve them.
	var expedition_use:Dictionary=expedition_local.inventory_activation(item_name)
	if expedition_use.get("handled",false):
		if expedition_use.has("message") or expedition_use.has("error"):hud.show_message(str(expedition_use.get("message",expedition_use.get("error",""))))
		return
	if CARD_PACK_ITEMS.is_pack(item_name):
		_use_card_pack_item(item_name)
		return
	# Enchant scrolls open the enhancement window; the generic 523 use path
	# would refuse them first (their generic use spec is "effect pending").
	var kind: String = _scroll_kind(item_name)
	if kind != "":
		_enhancement_scroll_selection={}
		var candidates: Array = _enhancement_candidates(kind, _scroll_mode(item_name),item_name)
		hud.call("open_enhancement", item_name, candidates)
		return
	if loading:
		if await consumable_service.try_use_loading(item_name,selected_id): return
	elif consumable_service.try_use(item_name,selected_id): return
	var record: Dictionary = _find_catalog_item_record(item_name)
	var requested_id: String = str(selected.get("id", ""))
	if requested_id != "" and item_instances.has(requested_id):
		var pinned: Variant = (item_instances[requested_id] as Dictionary).get("record", {})
		if pinned is Dictionary and not (pinned as Dictionary).is_empty():
			record = pinned as Dictionary
	if record.is_empty():
		hud.show_message("아이템 DB에서 정보를 찾을 수 없습니다")
		return
	if _is_ammo_record(record):
		_toggle_ammo_equipped(item_name,requested_id)
		return
	var equip_slot: String = _equipment_slot_base(record)
	if equip_slot != "":
		_equip_or_acquire_item(record, false, str(selected.get("id", "")))
		return
	if _is_timed_buff_item(record):
		_use_timed_item_buff(record)
		return
	if str(record.get("slot", "")) == "consumable" and int(record.get("heal", 0)) > 0:
		_use_healing_item(item_name, int(record.get("heal", 0)))
		return
	hud.show_message("이 아이템은 직접 사용할 수 없습니다")

## 성장 보상 상자 (m523-growth-item:<ItemClassID>): one box of the stack
## becomes the original box item of that ItemClassID (a physical receipted
## stack, same save) and is opened by its original box rule from the bag.
func _open_growth_reward_box(item_name: String) -> Dictionary:
	var id_text: String = item_name.trim_prefix("m523-growth-item:")
	if not id_text.is_valid_int() or int(inventory.get(item_name, 0)) < 1: return {"ok":false,"reason":"성장 보상 상자를 확인할 수 없습니다"}
	var stack: Script = preload("res://scripts/loot/current523_native_stack.gd")
	var summary: Dictionary = LOOT_DROP.PATCH523_DROPS.definition_id(id_text)
	var record: Dictionary = LOOT_DROP.PATCH523_DROPS.variant_item(summary.get("native_record", {}), 1)
	if record.is_empty() or str(stack.profile(record).get("kind", "")) not in ["bag","selection"]:
		return {"ok":false,"reason":"이 성장 보상 상자는 원본 상자 규칙이 없어 열 수 없습니다 · 상자 보존"}
	var view = stack.SupplierView.new()
	view.host = self; view.inventory = inventory.duplicate(true); view.item_instances = item_instances.duplicate(true); view.gold = gold
	view.inventory[item_name] = int(view.inventory[item_name]) - 1
	if int(view.inventory[item_name]) <= 0: view.inventory.erase(item_name)
	var staged: Dictionary = preload("res://scripts/loot/patch523_item_inventory.gd").stage(view, [{"item_class_id":int(id_text),"amount":1,"bless_raw":1,"enchant":0}], {"kind":"growth96_reward_box","growth_item":item_name})
	view.free()
	if not staged.get("ok", false): return {"ok":false,"reason":str(staged.get("error","성장 보상 상자 변환 실패")) + " · 상자 보존"}
	if _save_game(true, staged.overrides) != OK: return {"ok":false,"reason":"성장 보상 상자 저장 실패 · 상자 보존"}
	inventory = staged.overrides.inventory; item_instances = staged.overrides.item_instances
	if staged.overrides.has("gold"): gold = int(staged.overrides.gold)
	_on_inventory_item_activated(str(record.name))
	return {"ok":true}

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
	var spec: Dictionary = CONSUMABLE_RULES.definition(str(record.get("name", "")))
	if str(spec.get("kind", "")) in ["regen", "food", "buff"]:
		var generated: Dictionary = (spec.get("buff", {}) as Dictionary).duplicate(true)
		generated["duration"] = float(spec["duration"])
		generated["remaining"] = float(spec["duration"])
		generated["desc"] = str(spec.get("desc", ""))
		generated["group"] = str(spec.get("group", ""))
		generated["tick_elapsed"] = 0.0
		return generated
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
			buff["pve_damage_reduction"] = value
		elif segment.begins_with("PVE 대미지 감소"):
			buff["pve_damage_reduction_pct"] = value
		elif segment.begins_with("PVP 대미지 감소"):
			buff["pve_damage_reduction_pct"] = value
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

# Raw ValidLand lists 100 regular Trial Tower lands; do not classify a
# local challenge on Aden, a hard-mode alias or a fake current map as one.
func _trial_tower_item_land_active() -> bool:
	if not current523_aden_source_active() or not field_map is OriginalPlayableField:return false
	var land:int=int(field_map.definition.get("source_land_id",0))
	return land>=45374 and land<=46364 and (land-45374)%10==0

func _active_item_buff_total(key: String, item_buff_override: Variant = null) -> int:
	var total: int = 0
	var selected: Dictionary = item_buff_override if item_buff_override is Dictionary else active_item_buffs
	for value: Variant in selected.values():
		if value is Dictionary and (not value.has("source_trial_tower_territory_id") or _trial_tower_item_land_active()):
			total += int((value as Dictionary).get(key, 0))
	# The local clan's level buff (ClanReward -> BuffClass) is held while the
	# clan exists, like an always-on buff, and is not part of the timed set.
	# Escaros artifact buff (BuffClass bonuses, user decision 2026-11-13: 15 minutes).
	return total + clan523.buff_value(key) + content523.buff_value(key) + item_possession523.buff_value(key) + item_appellation523.buff_value(key) + equipment_buff523.buff_value(key) + dungeon_extras523.buff_value(key)

## _active_item_buff_total for a percent that may hold a fraction of a point
## (original 엘븐 와퍼 MoveSpeedBonus 125000 = 12.5 %); the other sources
## stay the integer totals they always were.
func _active_item_buff_percent(key: String) -> float:
	var total: float = 0.0
	for value: Variant in active_item_buffs.values():
		if value is Dictionary:
			var amount: Variant = (value as Dictionary).get(key, 0)
			if amount is int or amount is float: total += float(amount)
	return total + float(_active_item_buff_total(key, {}))

func _format_seconds_short(seconds: float) -> String:
	var whole: int = maxi(0, int(ceil(seconds)))
	if whole >= 3600:
		return "%d시간 %d분" % [whole / 3600, (whole % 3600) / 60]
	if whole >= 60:
		return "%d분 %d초" % [whole / 60, whole % 60]
	return "%d초" % whole

func _use_timed_item_buff(record: Dictionary) -> bool:
	if not _patch523_item_allowed(): return false
	if protection523.legacy_group_blocked(record):
		hud.show_message("Group604 가호 버프가 활성화되어 있습니다 · 비중첩")
		return false
	if protection523.managed(record):
		hud.show_message("원본 가호는 명예 코인 확인 후 사용하세요")
		return false
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
	var spec: Dictionary = CONSUMABLE_RULES.definition(item_name)
	var allowed: Array = spec.get("classes", []) as Array
	if not allowed.is_empty() and not allowed.has(job_class):
		hud.show_message("%s 직업은 %s 사용 불가" % [job_class, item_name])
		return false
	var buff_group: String = str(buff.get("group", ""))
	if buff_group != "":
		for current_key: Variant in active_item_buffs.keys():
			var current: Variant = active_item_buffs.get(current_key, {})
			if current is Dictionary and str((current as Dictionary).get("group", "")) == buff_group:
				active_item_buffs.erase(current_key)
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
		var remaining_before: float = maxf(0.0, float(buff.get("remaining", 0.0)))
		var deadline_left := INF
		if buff.has("source_buff_delete_at"):
			deadline_left = float(buff.source_buff_delete_at) - Time.get_unix_time_from_system()
		var interval: float = float(buff.get("tick_interval", 0.0))
		if interval > 0.0 and remaining_before > 0.0:
			var elapsed: float = float(buff.get("tick_elapsed", 0.0)) + minf(delta, minf(remaining_before, maxf(0.0, deadline_left + delta)))
			var ticks: int = maxi(0, int(floor(elapsed / interval)))
			buff["tick_elapsed"] = fmod(elapsed, interval)
			if ticks > 0:
				mp = mini(_effective_max_mp(), mp + maxi(0, int(buff.get("mp_regen_tick", 0))) * ticks)
				hp = mini(_effective_max_hp(), hp + maxi(0, int(buff.get("hp_regen_tick", 0))) * ticks)
				changed = true
		buff["remaining"] = maxf(0.0, remaining_before - delta)
		# 원본 IsAbsoluteTimeBuff: real time, also while the game was closed.
		if buff.has("absolute_until"): buff["remaining"] = maxf(0.0, float(buff.absolute_until) - Time.get_unix_time_from_system())
		if buff.has("source_buff_delete_at"): buff["remaining"] = minf(buff.remaining, maxf(0.0, deadline_left))
		# 원본 EraseBuffOnExperience / EraseOnLevel: ends at that level.
		if int(buff.get("erase_at_level", 0)) > 0 and level >= int(buff.erase_at_level): buff["remaining"] = 0.0
		active_item_buffs[key] = buff
		if float(buff.get("remaining", 0.0)) <= 0.0:
			expired.append(key)
	for key: String in expired:
		var entry:Variant=active_item_buffs.get(key)
		if entry is Dictionary and entry.has("source_growth_catalyst523_expiry"):
			if entry.has("xp"):
				# Expired stats stop even if the writer/reward supplier is busy.
				# Keep only the receipt for a later exact claim, not a second buff.
				active_item_buffs[key]={"remaining":0.0,"source_growth_catalyst523_expiry":entry.source_growth_catalyst523_expiry}
				changed=true
			var now:int=Time.get_ticks_usec()
			if now>=_growth_catalyst_retry_usec:
				_growth_catalyst_retry_usec=now+2000000
				if preload("res://scripts/loot/current523_native_stack.gd").finish_growth_catalyst(self,key):
					changed=true
			continue
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
		var value:Variant=active_item_buffs[key]
		if value is Dictionary and value.has("source_trial_tower_territory_id") and not _trial_tower_item_land_active():continue
		if value is Dictionary and value.has("source_growth_catalyst523_expiry") and not value.has("xp"):continue
		result[key] = value
	if ain_service.orb_active():
		result["드래곤의 보호"] = {"remaining": maxi(0, ain_service.dragon_orb_expires_at - int(Time.get_unix_time_from_system()))}
	return result

func _is_instance_equipped(id: String) -> bool:
	if domination_stones.is_extra_equipped(id): return true
	for entry: Variant in equipped_items.values():
		if entry is Dictionary and str((entry as Dictionary).get("instance_id", "")) == id:
			return true
	return false

func _migrate_patch523_physical_records() -> void:
	if not LOOT_DROP.PATCH523_DROPS.data().get("full_item_catalog",false): return
	for container: Dictionary in [item_instances,warehouse.instances]:
		for uid: Variant in container:
			var entry: Dictionary = container[uid]
			var old: Dictionary = entry.get("record",{}) if entry.get("record",{}) is Dictionary else {}
			if old.is_empty(): continue
			var current: Dictionary = _source_catalog_record("아이템",old)
			if not current.get("source_m_native_item",false) or current == old: continue
			if not entry.has("source523_previous_record"): entry["source523_previous_record"] = old.duplicate(true)
			# Preserve every instance field and its existing inventory name/key.
			if str(current.get("name","")) == str(entry.get("name","")): entry["record"] = current
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var old: Dictionary = equipped_items.get(slot,{})
		if old.is_empty(): continue
		var current: Dictionary = _source_catalog_record("아이템",old)
		if current.get("source_m_native_item",false) and current != old:
			current["source523_previous_equipped_record"] = old.get("source523_previous_equipped_record",old).duplicate(true)
			equipped_items[slot] = current

func _sync_item_instances() -> void:
	# Group physical IDs by name once, in item_instances order. Rescanning every
	# instance for every bag entry cost ~22-29 ms per call for 120 enhanceable
	# names / 400 instances (measured); this runs on every HUD refresh and save.
	# Edits below only touch the current name's IDs, so the groups stay valid.
	var ids_by_name: Dictionary = {}
	for key: Variant in item_instances.keys():
		var owner_name: String = str((item_instances[key] as Dictionary).get("name", ""))
		if not ids_by_name.has(owner_name): ids_by_name[owner_name] = [] as Array[String]
		(ids_by_name[owner_name] as Array[String]).append(str(key))
	for raw_name: Variant in inventory.keys():
		var name_value: String = str(raw_name)
		var record: Dictionary = _find_catalog_item_record(name_value)
		var has_native_stack: bool=false
		for typed_id: String in ids_by_name.get(name_value,[]):
			if item_instances[typed_id].has("source_native_stack_receipt"):has_native_stack=true;break
		if has_native_stack:continue # No name-derived creation/pruning of quantity-managed ownership.
		if not _needs_physical_item(record):
			continue
		var desired: int = maxi(0, int(inventory.get(name_value, 0)))
		var ids: Array[String] = (ids_by_name.get(name_value, [] as Array[String]) as Array[String]).duplicate()
		var legacy_import: bool = ids.is_empty() and enhancement_levels.has(name_value)
		while ids.size() < desired:
			var unique_id: String = str(next_item_instance_id)
			while item_instances.has(unique_id) or death_recovery.reserved(unique_id):
				next_item_instance_id += 1
				unique_id = str(next_item_instance_id)
			next_item_instance_id += 1
			item_instances[unique_id] = {"name":name_value,"level":int(enhancement_levels.get(name_value, 0)) if legacy_import else 0, "element":"", "element_level":0}
			if record.get("source_m_native_item",false):
				item_instances[unique_id]["record"] = record.duplicate(true)
				item_instances[unique_id]["bless_state"] = str(record.get("bless_state","normal"))
			if not ids.is_empty():
				var previous: Dictionary = item_instances.get(ids[0], {}) as Dictionary
				# Only propagate custom/unique records; name-only loot cannot
				# safely inherit one variant of several different source IDs.
				if previous.has("record") and int(catalog_item_variant_count.get(name_value, 0)) <= 1:
					item_instances[unique_id]["record"] = (previous["record"] as Dictionary).duplicate(true)
			ids.append(unique_id)
		while ids.size() > desired:
			var found: bool = false
			for id: String in ids:
				if not _is_instance_equipped(id):
					item_instances.erase(id)
					ids.erase(id)
					found = true
					break
			if not found:
				break
	for raw_id: Variant in item_instances.keys():
		var instance_id: String = str(raw_id)
		var name_value: String = str((item_instances[raw_id] as Dictionary).get("name", ""))
		if item_instances[raw_id].has("source_native_stack_receipt"):
			if int(inventory.get(name_value,0))<=0:patch523_owner_state_problem="원본 물리 묶음과 소지 수량 불일치 · 개체 보존, 정상 저장 불러오기 필요"
			continue
		if int(inventory.get(name_value, 0)) <= 0 and not _is_instance_equipped(instance_id):
			item_instances.erase(raw_id)
			continue
		if patch523_equipment.has_any_equipment_runtime():
			var physical: Dictionary=item_instances[raw_id]
			var pinned: Dictionary=physical.get("record",_find_catalog_item_record(name_value))
			var prepared: Dictionary=PATCH523_ENHANCE.prepare(patch523_equipment,pinned,patch523_equipment.bless_code(physical))
			if prepared!=pinned: physical["record"]=prepared

func _chosen_instance(name_value: String, only_free: bool = false) -> String:
	_sync_item_instances()
	var chosen: String = ""
	var level_value: int = -1
	for raw_id: Variant in item_instances.keys():
		var instance_id: String = str(raw_id)
		var entry: Dictionary = item_instances[raw_id] as Dictionary
		if str(entry.get("name", "")) != name_value or (only_free and _is_instance_equipped(instance_id)):
			continue
		if chosen.is_empty() or int(entry.get("level", 0)) > level_value:
			chosen = instance_id
			level_value = int(entry.get("level", 0))
	return chosen

func _item_instance_level(instance_id: String, fallback_name: String = "") -> int:
	if item_instances.has(instance_id):
		return int((item_instances[instance_id] as Dictionary).get("level", 0))
	return int(enhancement_levels.get(fallback_name, 0)) if instance_id == "" else 0

func _parse_enhancement_target(raw_name: String) -> Dictionary:
	var pieces: PackedStringArray = raw_name.split("@@@", false, 1)
	return {"name": pieces[0], "id": pieces[1] if pieces.size() > 1 else ""}

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

func _needs_physical_item(record: Dictionary) -> bool:
	return _enhancement_kind_for_record(record) != "" or (record.get("source_m_native_item",false) and LOOT_DROP.PATCH523_DROPS.equipment(record))

## Inventory use only opens the enhancer. Keep the original physical receipt
## intact until a specific roll has both a valid source rule and a durable debit.
var _enhancement_scroll_selection: Dictionary = {}
var _enhancement_token_quotes: Dictionary = {}
func _open_owned_native_enhancement(name: String, selected: String, record: Dictionary) -> bool:
	var kind: String=_scroll_kind(name,record)
	if kind.is_empty():return false
	var held: Dictionary=PATCH523_ENHANCE_STOCK.select_owned(self,name,selected,1)
	if not held.get("native",false):return false
	if not held.get("ok",false):
		hud.show_message(str(held.reason))
		return true
	_enhancement_scroll_selection={"name":name,"uid":held.uid}
	hud.call("open_enhancement",name,_enhancement_candidates(kind,_scroll_mode(name),name))
	return true

func _enhancement_stock(scroll_name: String, count: int) -> Dictionary:
	var uid: String=str(_enhancement_scroll_selection.get("uid","")) if _enhancement_scroll_selection.get("name") == scroll_name else ""
	return PATCH523_ENHANCE_STOCK.select_owned(self,scroll_name,uid,count,not uid.is_empty())

func _enhancement_candidates(kind: String, mode: String = "normal", scroll_name: String = "") -> Array:
	_enhancement_token_quotes.clear()
	_sync_item_instances()
	var result: Array = []
	var stock: Dictionary=_enhancement_stock(scroll_name,1) if not scroll_name.is_empty() else {}
	if stock.get("native",false) and not stock.get("ok",false):return result
	var physical_scroll: Dictionary=stock.proof.record if stock.get("ok",false) else {}
	var names: Array = item_instances.keys()
	names.sort()
	for value: Variant in names:
		var instance_id: String = str(value)
		var item_name: String = str((item_instances[instance_id] as Dictionary).get("name", ""))
		if int(inventory.get(item_name, 0)) <= 0:
			continue
		var record: Dictionary = _find_catalog_item_record(item_name)
		var pinned: Variant = (item_instances[instance_id] as Dictionary).get("record", {})
		if pinned is Dictionary and not (pinned as Dictionary).is_empty():
			record = pinned as Dictionary
		if record.is_empty() or (kind!="source" and _enhancement_kind_for_record(record) != kind):
			continue
		var receipt: Dictionary=item_instances[instance_id]
		var token: bool=not physical_scroll.is_empty() and receipt.has(PATCH523_TOKEN_STOCK.RECEIPT) and PATCH523_TOKEN_STOCK.is_enhancement_token(record)
		var level_value: int=int(receipt.get(PATCH523_TOKEN_STOCK.TOKEN_RANK,0)) if token else _item_instance_level(instance_id,item_name)
		var source_rule: Dictionary=_source_enhancement_rule(record,level_value,mode,scroll_name,receipt,physical_scroll,token)
		if source_rule.is_empty() and not _enhancement_level_allowed(kind, mode, level_value, record):
			continue
		var chance: Dictionary = source_rule if not source_rule.is_empty() else _enhancement_chance(kind, level_value, mode, record)
		if float(chance.get("success",0.0))+float(chance.get("decrease",0.0))<=0.0:
			continue
		var max_gain: int = 3 if mode == "blessed" and level_value <= 2 else (2 if mode == "blessed" and level_value <= 5 else 1)
		if not source_rule.is_empty():
			max_gain=-int(source_rule.side_effect_level_loss) if source_rule.get("forced_decrease",false) else 1
			for leap: Dictionary in source_rule.get("leaps",[]): max_gain=maxi(max_gain,int(leap.gain))
		if token:
			_enhancement_token_quotes[instance_id]={"entry":receipt.duplicate(true),"scroll_uid":str(stock.uid),"scroll_remaining":int(stock.proof.remaining)}
		else:record=PATCH523_ENHANCE.prepare(patch523_equipment,record,patch523_equipment.bless_code(item_instances[instance_id]))
		result.append({
			"name": item_name,
			"instance_id":instance_id,
			"target_id":item_name + "@@@" + instance_id,
			"level": level_value,
			"safe_level": int(chance.get("safe_level",_safe_enhancement_level(kind))),
			"success_chance": float(chance.get("success", 0.0)),
			"no_change_chance": float(chance.get("no_change", 0.0)),
			"destroy_chance": float(chance.get("destroy", 0.0)),
			"decrease_chance": float(chance.get("decrease", 0.0)),
			"gain_text": str(chance.get("gain_text",_enhancement_gain_text(mode, level_value))),
			"bonus_text": ENCHANT.summary(_enhancement_kind_for_record(record), level_value + max_gain, record),
			# Numbers behind bonus_text for the original Enchant_Text_Set rows.
			"stats_now": ENCHANT.stat_values(_enhancement_kind_for_record(record), level_value, record),
			"stats_next": ENCHANT.stat_values(_enhancement_kind_for_record(record), level_value + max_gain, record),
			"cost":int(chance.get("cost",0)),"count":int(chance.get("count",1)),"basis":str(chance.get("basis","TWILIGHT 기존 강화 규칙")),
			"equipped": _is_instance_equipped(instance_id)
		})
	return result

func patch523_open_expedition_enhancement(key: String) -> Dictionary:
	# Other source suppliers call this before a generic targetless activation.
	# Opening selection never debits, grants, rolls or acknowledges a receipt.
	var proof: Dictionary=_patch523_expedition_scroll(key)
	if not proof.get("issued",false):return {"handled":false}
	if not proof.get("ok",false):return {"handled":true,"ok":false,"error":proof.get("error","탐험 주문서 증명 확인 필요"),"committed":false}
	var candidates: Array=_enhancement_candidates("source",_scroll_mode(key),key)
	hud.open_enhancement(key,candidates)
	return {"handled":true,"ok":true,"stage":"target_selection","candidate_count":candidates.size(),"committed":false}

func _patch523_expedition_scroll(key: String) -> Dictionary:
	var record: Dictionary=_find_catalog_item_record(key)
	var source: String=str(record.get("sourceId",""))
	var tuple: String=str(record.get("expedition_key",""))
	# A saved issued key can outlive its provider/catalog installation. The
	# tag is only a refusal marker, never evidence permitting consumption.
	var tagged: bool=key.contains(" (탐험 137:") or key.contains(" (탐험 138:")
	if not tagged and not source.begins_with("m523:expedition:137:") and not source.begins_with("m523:expedition:138:") and not tuple.begins_with("137:") and not tuple.begins_with("138:"):return {}
	var result: Dictionary=preload("res://scripts/crafting/patch523_expedition_materials.gd").scroll(patch523_equipment,key,inventory,item_instances,ui_preferences.get("item_locks",{}),_patch523_craft_context())
	return result if result.get("issued",false) else {"issued":true,"ok":false,"error":"탐험 주문서 소유자/정체 미설치 · 기존 소지 보존"}

func _source_enhancement_rule(record: Dictionary, current_level: int, mode: String, scroll_name: String = "", physical: Dictionary = {}, scroll_override: Dictionary = {}, token: bool=false) -> Dictionary:
	if RETIRED_ITEMS.record(record):return {"source_rule":true,"success":0.0,"reason":RETIRED_ITEMS.REASON}
	if not physical.is_empty() and physical.has("sourceId") and str(physical.sourceId)!=str(record.get("sourceId","")):
		return {"source_rule":true,"success":0.0,"reason":"물리 장비의 원본 정체가 일치하지 않습니다"}
	var kind: String=_enhancement_kind_for_record(record)
	var scroll: Dictionary=scroll_override if not scroll_override.is_empty() else (_find_catalog_item_record(scroll_name) if not scroll_name.is_empty() else {})
	if RETIRED_ITEMS.record(scroll):return {"source_rule":true,"success":0.0,"reason":RETIRED_ITEMS.REASON}
	var exact_required: bool=bool(record.get("source_m_native_item",false)) or bool(scroll.get("source_m_native_item",false))
	var issued: Dictionary=_patch523_expedition_scroll(scroll_name)
	if issued.get("issued",false) and not issued.get("ok",false):return {"source_rule":true,"success":0.0,"reason":issued.error}
	var source_id: String=str(issued.source_id) if issued.get("ok",false) else PATCH523_ENHANCE.item_id(scroll)
	# Exact host scroll aliases preserve existing inventory keys; these map only
	# the original permanent normal/engraved scroll families, never item names.
	if source_id.is_empty():
		var aliases: Dictionary={"저주받은 무기 마법 주문서":"137","저주받은 무기 마법 주문서 (각인)":"6401","저주받은 갑옷 마법 주문서":"138","저주받은 갑옷 마법 주문서 (각인)":"6411","무기 마법 주문서":"137","무기 마법 주문서 (각인)":"6401","갑옷 마법 주문서":"138","갑옷 마법 주문서 (각인)":"6411","장신구 마법 주문서":"139","장신구 마법 주문서 (각인)":"139",
			"장인의 무기 마법 주문서 (각인)":"1184","장인의 무기 마법 주문서":"134862","장인의 갑옷 마법 주문서":"270654","장인의 갑옷 마법 주문서 (각인)":"271248","오림의 장신구 마법 주문서":"227002","오림의 장신구 마법 주문서 (각인)":"227002","축복받은 오림의 장신구 마법 주문서":"227002","축복받은 오림의 장신구 마법 주문서 (각인)":"227002","축복받은 무기 마법 주문서":"137","축복받은 무기 마법 주문서 (각인)":"6401","축복받은 갑옷 마법 주문서":"138","축복받은 갑옷 마법 주문서 (각인)":"6411"}
		source_id=str(aliases.get(scroll_name,""))
	if source_id.is_empty() and scroll_name.is_empty() and mode in ["normal","blessed"]:
		source_id=str({"weapon":"137","armor":"138","accessory":"139"}.get(kind,""))
	if source_id.is_empty() and scroll_name.is_empty() and mode=="craftsman": source_id="1184" if kind=="weapon" else ("271248" if kind=="armor" else "")
	if source_id.is_empty() and scroll_name.is_empty() and mode in ["orim","blessed_orim"] and kind=="accessory": source_id="227002"
	if source_id.is_empty():return {"source_rule":true,"success":0.0,"reason":"원본 ItemClass 또는 강화 주문서 그룹 연결이 없어 아이템을 보존합니다"} if exact_required else {}
	var bless: int=patch523_equipment.bless_code(physical) if not physical.is_empty() else (2 if EQUIPMENT_BLESSING.is_blessed({},record) else 1)
	var scroll_bless: int=int(issued.bless_code) if issued.get("ok",false) else int(scroll.get("source_bless_raw",3 if mode=="cursed" else 2 if mode in ["blessed","blessed_orim"] else 1))
	var book: RefCounted=patch523_equipment
	if exact_required and not issued.get("issued",false):
		# Some original event targets have a numeric enchant family but no
		# declared equip slot. Their physical storage receipts are not
		# equipment instances and must not be mutated by the equipment owner.
		if not token and record.get("source_m_native_item",false) and not LOOT_DROP.PATCH523_DROPS.equipment(record):
			return {"source_rule":true,"success":0.0,"reason":"원본 착용 슬롯 없는 강화용 아이템 · 전용 수량/강화 소유자 필요 · 주문서 보존"}
		var native: RefCounted=PATCH523_ENHANCE_SOURCE.new()
		if not native.bind(record,PATCH523_ENHANCE.item_id(record),scroll,source_id,patch523_equipment):
			return {"source_rule":true,"success":0.0,"reason":"원본 장비·주문서 정체 또는 지역·조건을 검증하지 못했습니다 · 아이템 보존"}
		for original: Dictionary in [native.target,native.scroll]:
			var date_problem: String=LOOT_DROP.PATCH523_DROPS.deadline_problem(original.get("native_record",{}),int(ui_preferences.get("patch523_source_clock_offset_minutes",540)))
			if not date_problem.is_empty():return {"source_rule":true,"success":0.0,"reason":date_problem}
		book=native
	var rule: Dictionary=PATCH523_ENHANCE.cursed_rule(book,record,source_id,current_level,bless) if scroll_bless==3 else PATCH523_ENHANCE.rule(book,record,source_id,current_level,bless,scroll_bless)
	if rule.is_empty() and exact_required:return {"source_rule":true,"success":0.0,"reason":"원본 장비·주문서의 강화 규칙을 검증하지 못했습니다 · 아이템 보존"}
	return rule

func _enhancement_level_allowed(kind: String, mode: String, current_level: int, record: Dictionary = {}) -> bool:
	var source_rule: Dictionary=_source_enhancement_rule(record,current_level,mode)
	if not source_rule.is_empty(): return float(source_rule.get("success",0))>0
	if mode == "craftsman" and kind == "weapon":
		var original: Dictionary = patch523_equipment.craftsman_weapon_rule(record)
		if not original.is_empty(): return current_level in original.levels
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

func _find_catalog_item_record(item_name: String, source_id: String = "") -> Dictionary:
	return _find_catalog_item_record_cash_install(item_name,source_id,null)

func _find_catalog_item_record_cash_install(item_name: String, source_id: String, scope: ITEM_CATALOG_LOOKUP.CashInstallScope) -> Dictionary:
	if source_id != "":
		var identified: Dictionary = _catalog_item_from_source_id(source_id)
		return identified if str(identified.get("name", "")) == item_name else {}
	# The built-in quest owner accepts only the explicit held-reward prefix
	# below. A missing held reward invalidates its index for the NEXT call:
	# don't immediately scan the same bag twice. Custom owners retain their
	# earlier opportunity to override any ordinary display name.
	var built_in: bool=quest_auto!=null and quest_auto.get_script()==preload("res://scripts/quests/quest_auto_runner.gd")
	if not built_in and quest_auto!=null and quest_auto.has_method("held_record"):
		var held: Variant=quest_auto.call("held_record",item_name,item_instances)
		if held is Dictionary and not held.is_empty():return held
	# Indexed, self-validating equivalent of the previous one-name find_many scan.
	if item_name.begins_with("[원본 보상] "):
		if built_in:return quest_auto.current_held_record(item_name,item_instances)
		return quest_auto.held_record(item_name,item_instances) if quest_auto!=null and quest_auto.has_method("held_record") else {}
	if scope != null:
		var scoped: Variant = scope.find_one([catalog_db.get("아이템", []),item_db],item_instances,item_name)
		if scoped is Dictionary: return scoped
	return ITEM_CATALOG_LOOKUP.find_one([catalog_db.get("아이템", []), item_db], item_instances, item_name)

func _safe_enhancement_level(kind: String, record: Dictionary = {}) -> int:
	var source_rule: Dictionary=_source_enhancement_rule(record,0,"normal")
	if not source_rule.is_empty(): return int(source_rule.get("safe_level",0))
	match kind:
		"weapon":
			return 6
		"armor":
			return 4
		_:
			return 0

func _enhancement_chance(kind: String, current_level: int, mode: String = "normal", record: Dictionary = {}) -> Dictionary:
	var source_rule: Dictionary=_source_enhancement_rule(record,current_level,mode)
	if not source_rule.is_empty(): return source_rule
	if mode == "craftsman" and kind == "weapon":
		var original: Dictionary = patch523_equipment.craftsman_weapon_rule(record)
		if not original.is_empty():
			return original if current_level in original.levels else {"success":0.0,"no_change":0.0,"destroy":0.0,"decrease":0.0}
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
	return ENCHANT.summary(kind, target_level)

func _is_item_equipped(item_name: String) -> bool:
	if not equipped_ammo.is_empty() and item_name == equipped_ammo:
		return true
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var value: Variant = equipped_items.get(slot, {})
		if value is Dictionary and str((value as Dictionary).get("name", "")) == item_name:
			return true
	return false

func _attempt_enhancement(scroll_name: String, target_name: String) -> void:
	if not _patch523_item_allowed(): return
	if dungeon_play.try_enhancement(scroll_name,target_name):return
	if hud.has_method("is_enhancement_presenting") and bool(hud.call("is_enhancement_presenting")):
		return
	var selected: Dictionary = _parse_enhancement_target(target_name)
	var item_id: String = str(selected.get("id", ""))
	target_name = str(selected.get("name", target_name))
	_sync_item_instances()
	if item_id.is_empty():
		item_id = _chosen_instance(target_name)
	if _item_locked(target_name,item_id) or _item_locked(scroll_name):
		hud.show_message("강화하려면 아이템 잠금을 해제하세요")
		return
	if not item_instances.has(item_id) or str((item_instances[item_id] as Dictionary).get("name", "")) != target_name:
		hud.show_message("해당 장비 개체를 찾을 수 없습니다")
		return
	var owned_scroll: Dictionary=_enhancement_stock(scroll_name,1)
	if owned_scroll.get("native",false) and not owned_scroll.get("ok",false):
		hud.show_message(str(owned_scroll.reason))
		return
	var physical_scroll: Dictionary=owned_scroll.proof.record if owned_scroll.get("ok",false) else {}
	var kind: String = _scroll_kind(scroll_name,physical_scroll)
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

	var target_record: Dictionary = (item_instances[item_id] as Dictionary).get("record", {})
	if target_record.is_empty(): target_record = _find_catalog_item_record(target_name)
	if target_record.is_empty() or (kind!="source" and _enhancement_kind_for_record(target_record) != kind):
		hud.show_message("이 주문서로 강화할 수 없는 장비입니다")
		return

	var receipt: Dictionary=item_instances[item_id]
	var token: bool=not str(selected.get("id","")).is_empty() and not physical_scroll.is_empty() and receipt.has(PATCH523_TOKEN_STOCK.RECEIPT) and PATCH523_TOKEN_STOCK.is_enhancement_token(target_record)
	var current_level: int=int(receipt.get(PATCH523_TOKEN_STOCK.TOKEN_RANK,0)) if token else _item_instance_level(item_id,target_name)
	var source_rule: Dictionary=_source_enhancement_rule(target_record,current_level,mode,scroll_name,receipt,physical_scroll,token)
	if source_rule.is_empty() and not _enhancement_level_allowed(kind, mode, current_level, target_record):
		hud.show_message("현재 강화 단계에는 이 주문서를 사용할 수 없습니다")
		return
	var chance: Dictionary = source_rule if not source_rule.is_empty() else _enhancement_chance(kind, current_level, mode, target_record)
	var success_chance: float = float(chance.get("success", 0.0))
	var no_change_chance: float = float(chance.get("no_change", 0.0))
	var decrease_chance: float = float(chance.get("decrease", 0.0))
	if success_chance+decrease_chance<=0.0:
		hud.show_message(str(chance.get("reason","더 이상 강화할 수 없습니다")))
		return
	var scroll_count: int=int(chance.get("count",1))
	var cost: int=int(chance.get("cost",0))
	if int(inventory.get(scroll_name,0))<scroll_count or gold<cost:
		hud.show_message("강화 주문서 또는 아데나가 부족합니다")
		return

	if token:
		var scroll_proof: Dictionary=owned_scroll.proof
		var shown: Dictionary=_enhancement_token_quotes.get(item_id,{})
		if shown.get("entry")!=receipt or shown.get("scroll_uid")!=owned_scroll.uid or shown.get("scroll_remaining")!=scroll_proof.remaining:
			hud.show_message("강화 대상 또는 주문서 수량이 달라졌습니다 · 가방에서 다시 선택하세요")
			return
		var request: Dictionary={"physical_id":owned_scroll.uid,"quantity":scroll_count,"expected_quantity":scroll_proof.remaining,
			"expected_remaining":int(scroll_proof.remaining)-scroll_count,"source_native_stack_receipt":scroll_proof.receipt}
		var outcome: Dictionary=PATCH523_TOKEN_STOCK.commit_enhancement_token(self,item_id,[request],source_rule)
		if not outcome.get("ok",false):
			hud.show_message(str(outcome.get("reason",outcome.get("error","비착용 강화 저장 실패 · 아이템 보존"))))
			return
		_enhancement_token_quotes.clear() # old unit-selection no longer authorizes a second roll
		var result: String=str(outcome.result)
		_update_hud()
		if enhancement_series_quiet:
			enhancement_series_last={"result":result,"from":current_level,"to":int(outcome.level),"name":target_name}
			return
		if hud.has_method("show_enhancement_result"):hud.call("show_enhancement_result",result,target_name,current_level,int(outcome.level))
		else:hud.show_message("강화 결과 · +%d %s" % [int(outcome.level),target_name])
		hud.open_enhancement(scroll_name,_enhancement_candidates(kind,mode,scroll_name))
		return
	var staged: Dictionary={}
	if owned_scroll.get("ok",false):
		var debit: Dictionary=PATCH523_ENHANCE_STOCK.stage(self,owned_scroll,scroll_count)
		if not debit.get("ok",false):
			hud.show_message(str(debit.get("reason","원본 강화 주문서를 사용할 수 없습니다")))
			return
		staged=debit.overrides
	var before: Dictionary = {"inventory":inventory.duplicate(true), "instances":item_instances.duplicate(true),
		"equipped":equipped_items.duplicate(true), "rng":rng.state, "hp":hp, "mp":mp, "next_id":next_item_instance_id,"gold":gold}
	var result_log: String = ""
	if staged.is_empty():
		inventory[scroll_name] = int(inventory.get(scroll_name, 0)) - scroll_count
		if int(inventory.get(scroll_name, 0)) <= 0: inventory.erase(scroll_name)
	else:
		inventory=staged.inventory
		item_instances=staged.item_instances
	gold-=cost

	var result_type: String = "maintain"
	var result_level: int = current_level
	var result_message: String = "강화 실패 · 장비 변화 없음"
	# randf_range may include100; keep the same draw/state but never let a
	# confirmed100% success/decrease fall into item destruction at the endpoint.
	var roll: float = minf(rng.randf_range(0.0,100.0),99.999999)
	if roll < success_chance:
		var gain: int=1
		if source_rule.is_empty(): gain=_roll_enhancement_gain(mode,current_level)
		else:
			var leap_roll: int=rng.randi_range(0,999999)
			var threshold: int=0
			for leap: Dictionary in source_rule.leaps:
				threshold+=int(leap.probability)
				if leap_roll<threshold:
					gain=int(leap.gain); break
		result_level = mini(21, current_level + gain)
		item_instances[item_id]["level"] = result_level
		result_type = "success"
		result_message = "강화 성공! +%d %s" % [result_level, target_name]
		result_log = "강화 성공 · +%d %s" % [result_level, target_name]
	elif roll < success_chance + no_change_chance:
		result_log = "강화 실패(유지) · +%d %s" % [current_level, target_name]
	elif roll < success_chance + no_change_chance + decrease_chance:
		result_level = maxi(0, current_level - int(chance.get("side_effect_level_loss",1)))
		item_instances[item_id]["level"] = result_level
		result_type = "decrease"
		result_message = "강화 실패 · +%d → +%d 하락" % [current_level, result_level]
		result_log = "강화 실패(하락) · %s +%d → +%d" % [target_name, current_level, result_level]
	else:
		_destroy_enhancement_target(target_name, item_id)
		result_type = "destroy"
		result_level = 0
		result_message = "강화 실패 · %s 소실" % target_name
		result_log = "강화 실패(소실) · +%d %s" % [current_level, target_name]

	_invalidate_equipment_static()
	hp = mini(hp, _effective_max_hp())
	var before_content: Dictionary = unconfirmed523.state.duplicate(true)
	if result_type == "success":
		unconfirmed523.record_event("enchant_success",{"amount":1,"source_id":UNCONFIRMED523.native_id(item_instances[item_id].get("record",{})),"event_id":"enchant:%s:%d"%[item_id,Time.get_ticks_usec()]})
	if not staged.is_empty():
		# The owner must validate the old physical receipt against the staged
		# debit. Restore the old bag until the atomic writer confirms it.
		inventory=before.inventory
		item_instances=before.instances
	if _save_game(true,staged) != OK:
		inventory = before.inventory
		item_instances = before.instances
		equipped_items = before.equipped
		rng.state = int(before.rng)
		hp = int(before.hp)
		mp = int(before.mp)
		next_item_instance_id = int(before.next_id)
		gold=int(before.gold)
		unconfirmed523.state = before_content
		_invalidate_equipment_static()
		_update_hud()
		hud.show_message("강화 저장 실패 · 주문서·장비·난수 상태를 보존했습니다")
		return
	if not staged.is_empty():
		inventory=staged.inventory
		item_instances=staged.item_instances
		consumable_service.import_state(staged.consumable_state)
	if result_type == "success": routines.record("enchant_success",{"amount":1})
	hud.append_log(result_log)
	var phase_usec: int = Time.get_ticks_usec()
	# _update_hud already redraws an open bag; a second full redraw is wasted.
	if not hud.inventory_panel.visible:
		hud.refresh_inventory(inventory)
	_update_hud()
	_perf_log("강화 HUD 갱신", phase_usec)
	# Persist first. Presentation/skip/close must never commit or reroll a result.
	if enhancement_series_quiet:
		enhancement_series_last={"result":result_type,"from":current_level,"to":result_level,"name":target_name}
		return
	if hud.has_method("show_enhancement_result"):
		hud.call("show_enhancement_result", result_type, target_name, current_level, result_level)
	else:
		hud.show_message(result_message)

	phase_usec = Time.get_ticks_usec()
	if int(inventory.get(scroll_name, 0)) > 0:
		var remaining_candidates: Array = _enhancement_candidates(kind, mode,scroll_name)
		hud.call("open_enhancement", scroll_name, remaining_candidates)
	else:
		hud.call("open_enhancement", scroll_name, [])
	_perf_log("강화 목록 갱신", phase_usec)

## 다중 강화 (TWILIGHT 근사): the existing single roll (_attempt_enhancement,
## its rules, costs, save and rollback) run for each target in turn up to
## `goal`; stops at the first roll that is not a success (유지 / 하락 / 소실),
## a refused roll (rules, too few scrolls or Adena) or the scroll running out.
var enhancement_series_quiet: bool=false
var enhancement_series_last: Dictionary={}
func attempt_enhancement_series(scroll_name: String, targets: Array, goal: int) -> Dictionary:
	if enhancement_series_quiet:return {"ok":false,"reason":"다중 강화가 진행 중입니다"}
	var rolls: int=0
	var reached: int=0
	var stop: String=""
	var stop_name: String=""
	enhancement_series_quiet=true
	for raw: Variant in targets:
		var target: Dictionary=_parse_enhancement_target(str(raw))
		var id: String=str(target.get("id",""))
		var name: String=str(target.get("name",""))
		while stop.is_empty():
			if not item_instances.has(id):
				stop="missing"
				break
			var level: int=_item_instance_level(id,name)
			if level>=goal:
				reached+=1
				break
			if int(inventory.get(scroll_name,0))<=0:
				stop="scroll"
				break
			enhancement_series_last={}
			var scrolls_before: int=int(inventory.get(scroll_name,0))
			_attempt_enhancement(scroll_name,str(raw))
			if enhancement_series_last.is_empty() or int(inventory.get(scroll_name,0))>=scrolls_before:
				stop="refused"
				break
			rolls+=1
			match str(enhancement_series_last.get("result","")):
				"success":pass
				"destroy":stop="destroy"
				_:stop="fail"
			if not stop.is_empty():stop_name=name
		if not stop.is_empty():break
	enhancement_series_quiet=false
	var texts: Dictionary={"":"다중 강화 완료","fail":"강화 실패로 멈췄습니다","destroy":"장비가 소실되어 멈췄습니다","scroll":"주문서가 부족해 멈췄습니다","refused":"강화할 수 없는 단계라 멈췄습니다","missing":"장비를 찾을 수 없어 멈췄습니다"}
	var message: String="%s · %d회 · 목표 달성 %d/%d%s" % [str(texts.get(stop,"")),rolls,reached,targets.size()," · "+stop_name if not stop_name.is_empty() else ""]
	hud.show_message(message)
	hud.append_log(message)
	var kind: String=_scroll_kind(scroll_name)
	hud.call("open_enhancement",scroll_name,_enhancement_candidates(kind,_scroll_mode(scroll_name),scroll_name) if int(inventory.get(scroll_name,0))>0 else [])
	return {"ok":stop.is_empty(),"rolls":rolls,"reached":reached,"stop":stop,"message":message}

func _destroy_enhancement_target(item_name: String, item_id: String = "") -> void:
	if not item_id.is_empty():
		item_instances.erase(item_id)
	var remaining: int = int(inventory.get(item_name, 0)) - 1
	if remaining > 0:
		inventory[item_name] = remaining
	else:
		inventory.erase(item_name)
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var value: Variant = equipped_items.get(slot, {})
		if value is Dictionary and (str((value as Dictionary).get("instance_id", "")) == item_id or (item_id.is_empty() and str((value as Dictionary).get("name", "")) == item_name)):
			equipped_items[slot] = {}
			_invalidate_equipment_static()

func _equipment_enhancement_level(slot: String) -> int:
	var value: Variant = equipped_items.get(slot, {})
	if not (value is Dictionary):
		return 0
	var record: Dictionary = value as Dictionary
	if record.is_empty():
		return 0
	return _item_instance_level(str(record.get("instance_id", "")), str(record.get("name", "")))

func _equipped_items_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var value: Variant = equipped_items.get(slot, {})
		if value is Dictionary:
			var record: Dictionary = (value as Dictionary).duplicate(true)
			if not record.is_empty():
				record["enhance_level"] = _item_instance_level(str(record.get("instance_id", "")), str(record.get("name", "")))
			result[slot] = record
		else:
			result[slot] = {}
	return result

func _on_ain_item_requested(item_name: String) -> void:
	if int(inventory.get(item_name, 0)) <= 0 and int(inventory.get(item_name + " (각인)", 0)) > 0:
		item_name += " (각인)"
	_on_inventory_item_activated(item_name)

func _on_ain_shop_requested() -> void:
	_buy_shop_item("드래곤의 용옥", AIN_SERVICE.DRAGON_ORB_PRICE)

func _on_ain_auto_changed(enabled: bool) -> void:
	ain_service.auto_recharge = enabled
	hud.show_message("축복 자동충전 %s" % ("ON" if enabled else "OFF"))
	_update_ain_hud()
	_request_deferred_save()

func _update_ain_hud() -> void:
	if hud.has_method("set_ain_state"):
		var state: Dictionary = ain_service.snapshot()
		state["blessing_reduction_pct"] = _blessing_consumption_reduction_percent()
		hud.call("set_ain_state", state, inventory)

func _apply_ain_consumable(item_name: String, spec: Dictionary) -> bool:
	if not _patch523_item_allowed(): return false
	var kind: String = str(spec.get("kind", ""))
	var base_name: String = CONSUMABLE_RULES.normalize_name(item_name)
	if kind == "ain_orb":
		if not ain_service.start_dragon_orb():
			hud.show_message("드래곤의 보호가 이미 적용 중입니다")
			return false
		hud.show_message("드래곤의 보호 · 30일 활성화")
		_update_ain_hud()
		return true
	if kind != "ain_charge":
		return false
	if base_name == "드래곤의 성수" and level < 45:
		hud.show_message("드래곤의 성수는 45레벨부터 사용 가능합니다")
		return false
	var amount: int = AIN_SERVICE.charge_amount(base_name, level)
	amount = _amount_with_ainhasad_charge_bonuses(amount)
	var charged: int = ain_service.charge(amount)
	if charged <= 0:
		hud.show_message("아인하사드 축복이 최대치입니다")
		return false
	if base_name == "드래곤의 성수":
		experience += EXP_PROGRESSION.HOLY_WATER_EXP
		_check_level_up()
	hud.show_message("%s 사용 · 축복 +%d" % [item_name, charged])
	_update_ain_hud()
	return true

func _amount_with_ainhasad_charge_bonuses(amount:int)->int:
	var percent:float=growth.bonus("blessing_charge:percent")+card_collections.bonus("blessing_charge:percent")+_active_item_buff_total("source_manual_blessing_charge_pct")
	return int(round(float(amount)*(1.0+percent/100.0)))

func _auto_recharge_ain() -> void:
	if not ain_service.auto_recharge or ain_service.blessing > 200:
		return
	for item_name: String in ["드래곤의 루비", "드래곤의 사파이어", "드래곤의 다이아몬드", "드래곤의 고급 다이아몬드"]:
		for inventory_name: String in [item_name, item_name + " (각인)"]:
			if int(inventory.get(inventory_name, 0)) > 0:
				consumable_service.call("try_use", inventory_name)
				return

func _buy_shop_item(item_name: String, _ui_price: int) -> void:
	if death_recovery.blocked(): return
	# Legacy HUD signal remains compatible but the transmitted price has no
	# authority. Never debit a price supplied by a screen or external caller.
	_buy_shop_bulk(item_name, 1)

func _sell_shop_item(item_name: String, quantity: int, instance_id: String) -> void:
	if death_recovery.blocked(): return
	if item_instances.get(instance_id,{}).has(PATCH523_TOKEN_STOCK.TOKEN_RANK):
		hud.show_message("강화된 비착용 토큰은 매입 미연결 · 보유 보존")
		return
	if _find_catalog_item_record(item_name).get("monsterbook_source_item",false):
		hud.show_message("원본 도감 보상의 매입 가격이 정의되지 않았습니다")
		return
	if protection523.managed(_find_catalog_item_record(item_name)):
		hud.show_message("원본 가호는 일반 매입 대상이 아닙니다")
		return
	var source_restriction:String=expedition_local.transfer_restriction(item_name,"sell")
	if not source_restriction.is_empty():hud.show_message(source_restriction);return
	if item_name.begins_with("[원본 보상] "):
		hud.show_message("원본 보상 보관 중 · 사용/이동 기능 연결 대기")
		return
	if _item_locked(item_name,instance_id):
		hud.show_message("잠긴 아이템은 판매할 수 없습니다")
		return
	# Validate the current inventory, bound flags and exact instance ID at
	# commit time. The UI never submits the price or enhancement bonus.
	_sync_item_instances()
	var quote: Dictionary = inventory_automation.sale_quote(item_name,quantity,instance_id,inventory,item_instances,gold,false)
	if not bool(quote.get("ok",false)):
		hud.show_message(str(quote.get("reason","매입할 수 없습니다")))
		return
	var staged_inventory: Dictionary = inventory.duplicate(true)
	var staged_instances: Dictionary = item_instances.duplicate(true)
	var transaction: Dictionary = LOCAL_BUYBACK.apply(quote,staged_inventory,staged_instances,gold)
	if not bool(transaction.get("ok",false)):
		hud.show_message(str(transaction.get("reason","거래에 실패했습니다")))
		return
	if _save_game(true,{"inventory":staged_inventory,"item_instances":staged_instances,"gold":int(transaction.wallet)}) != OK:
		hud.show_message("판매 저장 실패 · 아이템·아데나 보존")
		return
	inventory = staged_inventory
	item_instances = staged_instances
	gold = int(transaction["wallet"])
	_update_hud()
	hud.refresh_inventory(inventory)
	hud.append_log("아이템 매입 · %s ×%d (+%d 아데나)" % [item_name,quantity,int(transaction["payment"])])
	hud.show_message("매입 완료 · %d 아데나" % int(transaction["payment"]))
	if hud.has_method("refresh_service"):
		hud.call("refresh_service")

func _buy_shop_bulk(item_name: String, quantity: int) -> void:
	if death_recovery.blocked(): return
	if CONSUMABLE_RULES.is_removed_item(item_name):
		hud.show_message("삭제된 소모품은 구매할 수 없습니다")
		return
	if SHOP_CATALOG.price_for(item_name) <= 0:
		hud.show_message("상점에 등록되지 않은 아이템입니다")
		return
	if item_name == "드래곤의 용옥":
		if quantity != 1:
			hud.show_message("드래곤의 용옥은 1개씩만 구매할 수 있습니다")
			return
		if not ain_service.may_purchase_orb():
			hud.show_message("드래곤의 용옥은 월 1회 구매 가능합니다")
			return
		if SHOP_CATALOG.price_for(item_name) != AIN_SERVICE.DRAGON_ORB_PRICE:
			hud.show_message("용옥 상점 가격 데이터가 일치하지 않습니다")
			return
	# Server-side item index is the source of truth for capacity and price;
	# never use a total, discount or item count from the UI.
	var unit_weight: int = maxi(0, int(item_weight_index.get(item_name, 3)))
	var quote: Dictionary = SHOP_CATALOG.quote(
		item_name, quantity, gold, _inventory_total_weight(), _carrying_capacity(), unit_weight
	)
	if not bool(quote.get("ok", false)):
		hud.show_message(str(quote.get("reason", "구매할 수 없습니다")))
		return
	var total: int = int(quote["total"])
	# No awaits/callbacks between final validation and atomic local mutation.
	gold -= total
	inventory[item_name] = int(inventory.get(item_name, 0)) + quantity
	if item_name == "드래곤의 용옥":
		ain_service.register_orb_purchase()
	hud.refresh_inventory(inventory)
	hud.show_message("%s ×%d 구매 · %d 아데나" % [item_name, quantity, total])
	hud.append_log("상점 구매 · %s ×%d (-%d)" % [item_name, quantity, total])
	_update_hud()
	_request_deferred_save()
	if hud.has_method("refresh_shop"):
		hud.call("refresh_shop")


# The original static crafting service remains available for saved-game and
# regression compatibility. The expanded 413-recipe service is a separate instance.
# Original NPC merchandise uses an independent audited seller/price path.
# No UI-submitted unit price, item record or enhancement is trusted.
func _buy_reviewed_shop_item(vendor_id: String, item_name: String, quantity: int) -> void:
	var quote: Dictionary = SHOP_CATALOG.quote_reviewed(
		vendor_id, item_name, quantity, catalog_db.get("아이템", []),
		gold, _inventory_total_weight(), _carrying_capacity(),
		maxi(0, int(item_weight_index.get(item_name, 3)))
	)
	if not bool(quote.get("ok", false)):
		hud.show_message(str(quote.get("reason", "구매할 수 없습니다")))
		return
	var record: Dictionary = (quote["offer"] as Dictionary).get("record", {})
	_sync_item_instances()
	var old_ids: Dictionary = item_instances.duplicate(true)
	var total: int = int(quote["total"])
	gold -= total
	inventory[item_name] = int(inventory.get(item_name, 0)) + quantity
	_sync_item_instances()
	for raw_id: Variant in item_instances.keys():
		if old_ids.has(raw_id):
			continue
		var physical: Dictionary = item_instances[raw_id] as Dictionary
		if str(physical.get("name", "")) != item_name:
			continue
		physical["level"] = 0
		physical["record"] = record.duplicate(true)
		physical["sourceId"] = str(record.get("sourceId", ""))
	hud.refresh_inventory(inventory)
	hud.show_message("%s ×%d 구매 · %d 아데나" % [item_name, quantity, total])
	hud.append_log("원본 NPC 상점 구매 · %s ×%d (-%d)" % [item_name, quantity, total])
	_update_hud()
	_request_deferred_save()
	if hud.has_method("refresh_shop"):
		hud.call("refresh_shop")


func _totem_action_requested(action: String, id: int, material_id: int, revision: int) -> void:
	var result: Dictionary = totem_actions.execute(action,id,material_id,revision)
	if not result.ok: hud.show_message(str(result.reason))

func totem_reduction_pierce() -> float:
	return float(totems.resonance().pierce_reduction_fraction)

func totem_map_context() -> Dictionary:
	# Native M Land identity only; never confuse a PC map number with Land.ID.
	if field_map != null and field_map.has_method("actor_contract"):
		var pack: Variant = field_map.get("source_pack")
		if pack != null and pack.has_method("geographic_contract"):
			var contract: Dictionary = pack.geographic_contract()
			if contract.get("edition") == "LineageM_base508": return contract
	return {}

func totem_map_experience() -> float:
	var context := totem_map_context()
	return totems.map_experience_fraction(int(context.get("land_id",-1)),str(context.get("asset_path","")))

func _craft_item_index() -> Dictionary:
	var result:Dictionary=(loot_catalog.get("by_name", {}) as Dictionary).duplicate()
	result.merge(expedition_local.received_material_records(),false)
	return result

## Craft/box lookups need only the items one recipe or box names, not the
## whole ~27,000-item index: building that on first use froze crafting for
## 6.5 s on a PC with the real pack (~26 s on the phone), and warming it in the
## background cost ~3 ms per frame for minutes. Same per-item binding
## (_patch523_craft_index_item) over the source IDs the definition references,
## on top of the same base index. The full index is reused when it exists.
##
## The bound items accumulate in one shared index (like the full one, but only
## for IDs some definition asked for): the crafting window quotes every recipe
## when it opens, and rebuilding per call was as slow as the full index.
## Dropped wherever the full index is dropped (patch523_craft_item_cache={}).
var _patch523_lazy_index: Dictionary={}
var _patch523_lazy_ids: Dictionary={}
var _patch523_lazy_owner: Variant=null

func _patch523_craft_items_for_ids(source_ids: Array) -> Dictionary:
	if not patch523_craft_item_cache.is_empty():return patch523_craft_item_cache
	# The full cache was reset (catalog/pack change): start over.
	if not is_same(_patch523_lazy_owner,patch523_craft_item_cache):
		_patch523_lazy_owner=patch523_craft_item_cache
		_patch523_lazy_index={}
		_patch523_lazy_ids={}
	if _patch523_lazy_index.is_empty():_patch523_lazy_index=_craft_item_index().duplicate()
	var items: Dictionary=patch523_equipment.data.get("items",{}) if patch523_equipment!=null and patch523_equipment.data is Dictionary else {}
	for value: Variant in source_ids:
		var source_id: String=str(value)
		if _patch523_lazy_ids.has(source_id) or not items.has(source_id):continue
		_patch523_lazy_ids[source_id]=true
		_patch523_craft_index_item(_patch523_lazy_index,source_id)
	return _patch523_lazy_index

## Every "source_id" a recipe (all material choices, outcomes and bonuses) names.
func _patch523_craft_items_for_recipe(recipe_id: String) -> Dictionary:
	if not patch523_craft_item_cache.is_empty():return patch523_craft_item_cache
	# A recipe's referenced IDs never change; walk each definition once
	# (the window asks for every recipe on open). Selections pick among the
	# same definition's materials, so the base walk already names them; the
	# selected recipe is walked once per distinct choice set.
	var recipe: Variant=patch523_equipment.recipes.get(recipe_id,{})
	if not is_same(_recipe_ids_owner,patch523_equipment.recipes):
		_recipe_ids_owner=patch523_equipment.recipes
		_recipe_source_ids={}
	var choices: Variant=patch523_material_choices.get(recipe_id,{})
	var memo_key: String=recipe_id+"|"+str(hash(choices))
	var ids: Variant=_recipe_source_ids.get(memo_key)
	if ids==null:
		var found: Array=[]
		_collect_source_ids(recipe,found)
		var selection: Dictionary=patch523_equipment.material_selection(recipe_id,choices)
		if selection.get("recipe") is Dictionary and not is_same(selection.recipe,recipe):_collect_source_ids(selection.recipe,found)
		ids=found
		_recipe_source_ids[memo_key]=found
	return _patch523_craft_items_for_ids(ids)

var _recipe_source_ids: Dictionary={}
var _recipe_ids_owner: Variant=null

static func _collect_source_ids(value: Variant, out: Array) -> void:
	if value is Dictionary:
		for key: Variant in value:
			var child: Variant=value[key]
			if str(key)=="source_id" and (child is String or child is int or child is float):out.append(str(int(child)) if child is float else str(child))
			else:_collect_source_ids(child,out)
	elif value is Array:
		for child: Variant in value:_collect_source_ids(child,out)

func _patch523_craft_item_index() -> Dictionary:
	if not patch523_craft_item_cache.is_empty():return patch523_craft_item_cache
	if not _craft_index_warm.is_empty():
		# Finish a started warm build here: the remaining items in their order.
		var ids: Array=_craft_index_warm.ids
		var partial: Dictionary=_craft_index_warm.result
		for index: int in range(int(_craft_index_warm.cursor),ids.size()):_patch523_craft_index_item(partial,str(ids[index]))
		_craft_index_warm={}
		patch523_craft_item_cache=partial
		return partial
	var result: Dictionary = _craft_item_index().duplicate()
	# The current non-equipment inventory is name-keyed. Bind only its unique
	# catalog identity to the compiler-verified ItemClass ID; never merge aliases.
	# The same item order, read in blocks: worker threads decode the next
	# block's item templates while this one is indexed (NATIVE_FIELDS prefetch).
	var source_ids: Array=(patch523_equipment.data.get("items", {}) as Dictionary).keys()
	var blocks: Array[PackedStringArray]=[]
	for block_start: int in range(0,source_ids.size(),PATCH523_CRAFT_INDEX_BLOCK):
		blocks.append(PackedStringArray(source_ids.slice(block_start,block_start+PATCH523_CRAFT_INDEX_BLOCK)))
	var ahead: Dictionary=NATIVE_FIELDS.prefetch_begin(blocks[0]) if not blocks.is_empty() else {}
	for index: int in blocks.size():
		NATIVE_FIELDS.prefetch_install(ahead)
		ahead=NATIVE_FIELDS.prefetch_begin(blocks[index+1]) if index+1<blocks.size() else {}
		for source_id: String in blocks[index]:
			_patch523_craft_index_item(result,source_id)
	NATIVE_FIELDS.prefetch_install(ahead)
	NATIVE_FIELDS.end_prefetch()
	patch523_craft_item_cache=result
	return result

const PATCH523_CRAFT_INDEX_BLOCK := 1024

## One idle-frame slice of the craft item index (CRAFT_INDEX_WARM_BUDGET_USEC);
## true while work remains. Starts craft_index_warm_seconds after it is first
## called with nothing built.
func _tick_craft_index_warm(delta: float) -> bool:
	if not patch523_craft_item_cache.is_empty():return false
	var items: Variant=patch523_equipment.data.get("items",{}) if patch523_equipment!=null and patch523_equipment.data is Dictionary else {}
	if not items is Dictionary or (items as Dictionary).is_empty():return false
	if _craft_index_warm.is_empty():
		craft_index_warm_seconds-=delta
		if craft_index_warm_seconds>0.0:return true
		_craft_index_warm={"ids":(items as Dictionary).keys(),"cursor":0,"result":_craft_item_index().duplicate()}
		return true
	var started: int=Time.get_ticks_usec()
	var ids: Array=_craft_index_warm.ids
	var cursor: int=int(_craft_index_warm.cursor)
	while cursor<ids.size() and Time.get_ticks_usec()-started<CRAFT_INDEX_WARM_BUDGET_USEC:
		_patch523_craft_index_item(_craft_index_warm.result,str(ids[cursor]))
		cursor+=1
	_craft_index_warm.cursor=cursor
	if cursor>=ids.size():
		patch523_craft_item_cache=_craft_index_warm.result
		_craft_index_warm={}
		return false
	return true

func _patch523_craft_index_item(result: Dictionary, source_id: String) -> void:
	# Read-only identity for the branch checks (no deep copy of ~30,000
	# records); the stored host binding below is still a full record().
	var binding: Dictionary=patch523_equipment.record_view(source_id)
	if binding.get("source","")=="twilight_host_binding":
		binding=patch523_equipment.record(source_id)
		var spec: Dictionary=CONSUMABLE_RULES.definition(str(binding.name))
		if spec.get("kind")==binding.get("host_kind") and int(spec.get("amount",0))==int(binding.get("host_amount",-1)):
			binding["weight"]=maxi(0,int(item_weight_index.get(str(binding.name),3)))
			result[str(binding.name)]=binding
		return
	if source_id=="26":
		result["아데나"]=patch523_equipment.record("26")
		return
	# TWILIGHT 근사 2026-11-16: 각성서 supply / other-owner records of the exact ID.
	if str(patch523_equipment.data.items[source_id].get("twilight_owner_binding","")) in ["supply","owner"]:
		var owned_record: Dictionary=_catalog_item_from_source_id(str(binding.get("sourceId","")))
		if int(catalog_item_variant_count.get(str(binding.get("name","")),0))==1 and patch523_equipment.catalog_identity_matches(owned_record,source_id):
			var weighted_owner: Dictionary=owned_record.duplicate(true)
			weighted_owner["weight"]=maxi(0,int(item_weight_index.get(str(binding.name),3)))
			result[str(binding.name)]=weighted_owner
		return
	if binding.get("source_m_native_item",false):
		for state: String in patch523_equipment.data.items[source_id].get("stack_variants",{}):
			var variant: Dictionary=patch523_equipment.record(source_id,int(state))
			var current_variant: Dictionary=_catalog_item_from_source_id(str(variant.get("sourceId","")))
			if int(catalog_item_variant_count.get(str(variant.get("name","")),0))==1 and patch523_equipment.catalog_identity_matches(current_variant,source_id,int(state)):
				var weighted_variant: Dictionary=current_variant.duplicate(true)
				weighted_variant["weight"]=maxi(0,int(item_weight_index.get(str(variant.name),3)))
				result[str(variant.name)]=weighted_variant
		var native_entry: Dictionary=_catalog_item_from_source_id(str(binding.sourceId))
		if int(catalog_item_variant_count.get(str(binding.name),0))==1 and patch523_equipment.catalog_identity_matches(native_entry,source_id):
			var weighted: Dictionary=native_entry.duplicate(true)
			weighted["weight"]=maxi(0,int(item_weight_index.get(str(binding.name),3)))
			result[str(binding.name)]=weighted
		return
	var entry: Dictionary = _catalog_item_from_source_id(source_id)
	var item_name: String = str(entry.get("name", ""))
	if entry.get("source", "") != "inven" or int(catalog_item_variant_count.get(item_name, 0)) != 1: return
	var bound: Dictionary = entry.duplicate(true)
	bound["weight"] = maxi(0, int(item_weight_index.get(item_name, 3)))
	result[item_name] = bound

func _load_patch523_equipment() -> void:
	var path: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES")
	var expected: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
	# UNVERIFIED: even a SHA-only or explicitly empty environment selection is
	# authoritative. Neither it nor a damaged install pointer is bypassed.
	var explicit: bool = OS.has_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES") or OS.has_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
	var installed: bool = FileAccess.file_exists(PATCH523_STORE.INDEX)
	if not explicit and installed:
		var saved: Dictionary = PATCH523_STORE.active()
		path = str(saved.get("path", ""))
		expected = str(saved.get("sha256", ""))
	if explicit or installed:
		if not _install_patch523_equipment(path, expected): push_warning(patch523_equipment.problem)
		return
	var catalog_bytes: PackedByteArray = FileAccess.get_file_as_bytes("res://data/catalog_v19.json")
	# Export exactly the already registered catalog inputs used by the public
	# compiler, never a world/UI object or newly fabricated native identity.
	# Identified as the JSON bytes of {"아이템","patch523_crafting_catalog_contract"}.
	patch523_equipment.live_record = _catalog_item_from_source_id
	if not patch523_equipment.load_original_bound(catalog_bytes,catalog_db.get("아이템",[]),catalog_db.get("patch523_crafting_catalog_contract",{})):
		push_warning(patch523_equipment.problem)
		var rules_failure: Dictionary = patch523_equipment.get("store_failure") if patch523_equipment.get("store_failure") is Dictionary else {}
		if not rules_failure.is_empty():
			_note_store_result("equipment_rules", {"ok":false,"reason":"equipment_rules_store_failed","stage":str(rules_failure.get("stage","")),"message":patch523_equipment.problem})
		return
	_apply_loaded_patch523_equipment()

func install_patch523_craft_catalog_zip(path: String) -> bool:
	var installed: Dictionary=PATCH523_CRAFT_CATALOG.install_zip(path)
	if installed.is_empty(): return false
	var result: Dictionary=PATCH523_CRAFT_CATALOG.register(catalog_db,installed.document)
	if not result.get("ok",false):
		PATCH523_CRAFT_CATALOG.problem=str(result.get("reason","공통 아이템 등록 실패")); return false
	patch523_craft_catalog_status=result
	_index_catalog_item_sources(); _index_item_weights()
	if is_instance_valid(hud):
		hud.set_catalog_data(catalog_db,catalog_image_index)
		hud.refresh_inventory(inventory)
	return true

func install_patch523_equipment_file(path: String, expected: String) -> bool:
	var installed: Dictionary = PATCH523_STORE.install(path, expected)
	if installed.is_empty():
		patch523_equipment.problem = PATCH523_STORE.problem
		return false
	return _install_patch523_equipment(str(installed.path), str(installed.sha256))

func _install_patch523_equipment(path: String, expected: String) -> bool:
	if not patch523_equipment.load_file(path, expected):
		return false
	_apply_loaded_patch523_equipment()
	return true

func _apply_loaded_patch523_equipment() -> void:
	patch523_material_choices.clear()
	patch523_owned_material_choices.clear()
	patch523_craft_item_cache={}
	_craft_index_warm={}
	# Keep existing recipes, IDs and economy unchanged.
	for key: Variant in crafting.recipes.keys():
		if str(key).begins_with("patch523:"):
			crafting.recipes.erase(key)
	# Same read-only recipe Dictionaries as patch523_equipment (no third copy).
	crafting.recipes.merge(patch523_equipment.recipes)
	_refresh_patch523_equipment_options()

func _refresh_patch523_equipment_options() -> void:
	if patch523_equipment.data.is_empty(): return
	for container: Dictionary in [item_instances, warehouse.instances]:
		for id: Variant in container:
			if not container[id] is Dictionary or not patch523_equipment.refresh_derived_options(container[id]): continue
			for slot: String in equipped_items:
				var equipped: Dictionary = equipped_items[slot]
				if str(equipped.get("instance_id", "")) == str(id) and is_same(container, item_instances):
					equipped["enhancement_options"] = container[id].record.enhancement_options.duplicate(true)
					equipped["patch523_effect_basis"] = container[id].record.patch523_effect_basis.duplicate(true)
	_invalidate_equipment_static()

func _patch523_protection_recipe_item(recipe_id: String) -> int:
	if not recipe_id.begins_with("patch523:"):return 0
	var key: String=recipe_id.trim_prefix("patch523:")
	if not key.is_valid_int() or int(key)<=0:return 0
	for row: Dictionary in patch523_equipment.recipe_evidence(int(key)).get("outputs",[]):
		if int(row.get("ItemCraftID",0))==int(key) and int(row.get("ItemCraftOutputTypeID",0))==1 and int(row.get("Amount",0))==1 and int(row.get("Enchant",-1))==0 and int(row.get("ItemBlessCodeID",0))==1 and int(row.get("Probability",0))==1000000 and int(row.get("ItemClassID",0)) in [200723,245718,297828,328254,346911,371108,75764,123373]:return int(row.ItemClassID)
	return 0

func open_patch523_protection_owner() -> void:
	var binding: Dictionary=preload("res://scripts/crafting/patch523_protection_bindings.gd").prepare(self)
	if not binding.get("ok",false):hud.show_message(str(binding.get("error","가호 제작 소유자 확인 필요")));return
	var path: String="res://scripts/protection/protection523_panel.gd"
	if not preload("res://scripts/resources/retired_assets.gd").usable(path):hud.show_message("가호 전용 화면이 설치되지 않았습니다");return
	hud.call("_open_window","protection523","불멸·파멸의 가호","보유 · 원본 재료 제작 · 영구 호칭")
	var scroll:=ScrollContainer.new()
	scroll.name="ProtectionFullScroll"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	hud.workspace.mount(scroll)
	var panel: Control=load(path).new()
	scroll.add_child(panel)
	panel.call("configure",hud)

func patch523_delegate_protection(recipe_id: int, batches: int=1) -> Dictionary:
	var item_id: int=_patch523_protection_recipe_item("patch523:"+str(recipe_id))
	if item_id==0 or batches!=1:return {"ok":false,"error":"원본 가호 제작식과 단일 소유자 거래를 확인하세요"}
	if protection523==null or not protection523.has_method("craft_recipe"):return {"ok":false,"error":"가호 제작 소유자 미설치 · 재료와 장부를 보존합니다"}
	if item_id not in [75764,123373]:
		if not patch523_equipment.CONDITIONS.valid_usage(patch523_crafting_usage):return {"ok":false,"error":"기존 제작 제한 장부 보존 · 중복 가호 확인 필요"}
		var usage: Dictionary=patch523_crafting_usage.get("recipes",{})
		if usage.has(str(recipe_id)) or usage.has("patch523:"+str(recipe_id)):return {"ok":false,"error":"기존 일반 제작 제한 이력 보존 · 중복 가호 거부"}
	var has_source: bool=false
	for property: Dictionary in protection523.get_property_list():
		if property.get("name")=="source":has_source=true;break
	var source: Variant=protection523.get("source") if has_source else null
	if not source is Dictionary:return {"ok":false,"error":"가호 원본 정의 미설치 · 재료 보존"}
	var definitions: Variant=source.get("supply_recipes",{}) if item_id in [75764,123373] else source.get("definitions",{})
	var definition: Variant=definitions.get(str(item_id)) if definitions is Dictionary else null
	var recipe: Variant=definition.get("recipe") if definition is Dictionary else null
	var original_id: Variant=recipe.get("ItemCraftID") if recipe is Dictionary else null
	if typeof(original_id) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(original_id)) or float(original_id)!=float(recipe_id):return {"ok":false,"error":"가호 소유자의 원본 제작식 불일치 · 재료 보존"}
	var binding: Dictionary=preload("res://scripts/crafting/patch523_protection_bindings.gd").prepare(self)
	if not binding.get("ok",false):return binding
	# This exact public owner alone commits input/body/Appellation/ledger/save.
	# No generic execute(), grant(), second debit, log or outer save follows.
	var result: Variant=protection523.call("craft_recipe",recipe_id)
	if not result is Dictionary or not result.get("ok") is bool:return {"ok":false,"error":"가호 소유자 결과 확인 필요 · 저장 확인 전 재시도하지 마세요","outcome_uncertain":true}
	return result

func _patch523_craft_requested(recipe_id: String, batches: int) -> void:
	if _patch523_protection_recipe_item(recipe_id)>0:
		var delegated: Dictionary=patch523_delegate_protection(int(recipe_id.trim_prefix("patch523:")),batches)
		if not delegated.get("ok",false):hud.show_message(str(delegated.get("error","가호 소유자 결과 확인 필요")))
		return
	_sync_item_instances()
	var context: Dictionary=_patch523_craft_context(recipe_id,batches)
	var previous_rng: int=rng.state
	var outcome_roll: int=-1
	if patch523_equipment.recipes.get(recipe_id,{}).has("outcomes"):
		var quote: Dictionary=_craft_quote(recipe_id,batches)
		if not bool(quote.get("ok",false)):
			hud.show_message(str(quote.get("reason","제작 조건을 확인하세요")))
			return
		outcome_roll=rng.randi_range(0,999999)
	var transaction: Dictionary = patch523_equipment.execute(recipe_id, batches, inventory, gold,
		_patch523_craft_items_for_recipe(recipe_id), item_instances, equipped_items, _inventory_total_weight(), _carrying_capacity(),
		next_item_instance_id, ui_preferences.get("item_locks", {}), patch523_material_choices.get(recipe_id, {}), outcome_roll, context)
	if transaction.get("ok",false):transaction=PATCH523_QUEST_MATERIALS.join(self,patch523_equipment,transaction,context)
	if transaction.get("ok",false):transaction=preload("res://scripts/loot/current523_native_stack.gd").join_craft_output(self,patch523_equipment,transaction,context)
	# TWILIGHT 근사 2026-11-16: 성공 페이백 / 혈맹 몫 stacks get the same owned-stack receipts.
	for bonus: Dictionary in (transaction.get("bonus_outputs",[]) if transaction.get("ok",false) else []):
		var part: Dictionary=transaction.duplicate(); part.selected_output=bonus; part.result_quantity=int(bonus.quantity); part.erase("source_native_retained_output_quantity")
		var joined: Dictionary=preload("res://scripts/loot/current523_native_stack.gd").join_craft_output(self,patch523_equipment,part,context)
		if not joined.get("ok",false):transaction=joined;break
		transaction.item_instances=joined.item_instances
	if not bool(transaction.get("ok", false)):
		rng.state=previous_rng
		hud.show_message(str(transaction.get("reason", "원본 제작에 실패했습니다")))
		return
	var staged_log: Array[Dictionary] = crafting_log.duplicate(true)
	staged_log.append({"recipe_id": recipe_id, "batch": batches, "output": str(transaction.result_name),
		"quantity": int(transaction.result_quantity), "gold": int(transaction.cost),
		"rules_sha256": patch523_equipment.digest, "at": Time.get_unix_time_from_system(),
		"source_quest_craft_receipt_id":str(transaction.get("source_craft_receipt_id",""))})
	if staged_log.size() > 200:
		staged_log.pop_front()
	var staged: Dictionary = {"inventory": transaction.inventory, "item_instances": transaction.item_instances,
		"gold": int(transaction.gold_after), "next_item_instance_id": int(transaction.next_instance_id), "crafting_log": staged_log,
		"patch523_crafting_usage":transaction.get("usage_after",patch523_crafting_usage).duplicate(true)}
	if transaction.has("quest_state"):staged["quest_state"]=transaction.quest_state
	if transaction.has("consumable_state"):staged["consumable_state"]=transaction.consumable_state
	if transaction.has("quest_step") and not PATCH523_QUEST_MATERIALS.Consume.matches_payload(self,transaction.quest_step,staged):
		rng.state=previous_rng
		hud.show_message("선택 재료와 최종 제작 저장 후보가 달라졌습니다 · 재료 보존")
		return
	var before_content: Dictionary = unconfirmed523.state.duplicate(true)
	if int(transaction.result_quantity) > 0:
		unconfirmed523.record_event("craft",{"amount":int(transaction.result_quantity),"source_id":UNCONFIRMED523.native_id(_find_catalog_item_record(str(transaction.result_name))),"event_id":"craft:%s:%d"%[recipe_id,Time.get_ticks_usec()]})
	# No state is consumed on disk-write failure, unavailable map or save guards.
	if _save_game(true, staged) != OK:
		rng.state=previous_rng
		unconfirmed523.state = before_content
		hud.show_message("저장 실패 · 재료·장비·아데나·난수 상태를 보존했습니다")
		return
	if staged.has("quest_state") and not quest_service.import_state(staged.quest_state):
		patch523_owner_state_problem="제작 저장 후 원본 소비 장부 복원 필요 · 정상 저장을 다시 불러오세요"
		hud.show_message(patch523_owner_state_problem)
		return
	if staged.has("consumable_state"):consumable_service.import_state(staged.consumable_state)
	inventory = staged.inventory
	item_instances = staged.item_instances
	gold = int(staged.gold)
	next_item_instance_id = int(staged.next_item_instance_id)
	crafting_log = staged_log
	patch523_crafting_usage=staged.patch523_crafting_usage
	routines.record("craft_try",{"amount":batches})
	patch523_owned_material_choices.erase(recipe_id)
	hud.refresh_inventory(inventory)
	_update_hud()
	hud.show_message(("원본 제작 %s · 지급 없음" % str(transaction.get("outcome_label","실패"))) if int(transaction.result_quantity)==0 else ("원본 제작 %s · %s ×%d" % [str(transaction.get("outcome_label","완료")), str(transaction.result_name), int(transaction.result_quantity)]))
	hud.append_log("원본523 제작 · " + recipe_id)
	if hud.has_method("open_crafting"):
		hud.call("open_crafting")

func _patch523_open_box(source_id: String) -> void:
	_sync_item_instances()
	var box_name: String = str(patch523_equipment.record(source_id).get("name",""))
	var box_ids: Array=[source_id]
	for reward: Variant in (patch523_equipment.data.get("guaranteed_boxes",{}).get(source_id,{}) as Dictionary).get("rewards",[]):
		if reward is Dictionary and reward.has("ItemClassID"):box_ids.append(str(int(reward.ItemClassID)))
	var transaction: Dictionary = PATCH523_SEAL_ACTIONS.open_box(patch523_equipment, source_id, inventory, item_instances,
		next_item_instance_id, _inventory_total_weight(), _carrying_capacity(), _patch523_craft_items_for_ids(box_ids), _item_locked(box_name))
	if not bool(transaction.get("ok",false)):
		hud.show_message(str(transaction.get("reason","상자를 열 수 없습니다")))
		return
	var staged: Dictionary = {"inventory":transaction.inventory,"item_instances":transaction.item_instances,"next_item_instance_id":transaction.next_item_instance_id}
	if _save_game(true,staged)!=OK:
		hud.show_message("저장 실패 · 상자와 보상을 보존했습니다")
		return
	inventory=staged.inventory
	item_instances=staged.item_instances
	next_item_instance_id=int(staged.next_item_instance_id)
	_update_hud()
	hud.show_message("상자 개봉 완료 · 일반 +0 인장과 강화 주문서 8개")

## Permanent seal scrolls use their own source group and never the generic
## item-use fallback. Keep the exact bag reference until an enhancement commits.
func _open_owned_seal_scroll(item_name: String, scroll_uid: String, record: Dictionary) -> bool:
	var raw_id: Variant=record.get("source_item_class_id")
	var scroll_id: String=PATCH523_ENHANCE.item_id(record)
	if (raw_id is int or raw_id is float) and is_finite(float(raw_id)) and raw_id==floorf(float(raw_id)):
		scroll_id=str(int(raw_id))
	if scroll_id.is_empty():
		for candidate: String in PATCH523_SEAL_ACTIONS.SCROLLS:
			if patch523_equipment.record_view(candidate).get("name","")==item_name:
				scroll_id=candidate
				break
	if scroll_id not in PATCH523_SEAL_ACTIONS.SCROLLS: return false
	if patch523_equipment.record_view(scroll_id).is_empty():
		hud.show_message("이 주문서의 인장 강화 규칙을 불러오지 못했습니다.")
		return true
	if not _patch523_item_allowed(): return true
	if int(inventory.get(item_name,0))<1 or _item_locked(item_name) or _item_locked(item_name,scroll_uid):
		hud.show_message("주문서 소지 수량과 잠금을 확인하세요")
		return true
	if scroll_uid.is_empty():
		var matches: Array[String]=[]
		for uid: String in item_instances:
			if item_instances[uid].get("name")==item_name:matches.append(uid)
		if matches.size()==1:scroll_uid=matches[0]
	hud.open_patch523_equipment_info(scroll_id,scroll_uid)
	return true

func patch523_seal_quote(item_id: String, scroll_id: String, scroll_uid: String = "") -> Dictionary:
	if not item_instances.has(item_id): return PATCH523_EQUIPMENT.denied("선택한 장비가 없습니다")
	var physical: Dictionary = item_instances[item_id]
	if int(inventory.get(str(physical.get("name","")),0))<1: return PATCH523_EQUIPMENT.denied("보유 장비가 없습니다")
	var scroll_name: String = str(patch523_equipment.record(scroll_id).get("name",""))
	var stock = preload("res://scripts/loot/current523_native_stack.gd")
	var owned: Dictionary={}
	var legacy: bool=false
	if not scroll_uid.is_empty():
		var scroll: Dictionary=item_instances.get(scroll_uid,{})
		owned=stock.proof(self,scroll_uid)
		if not owned.is_empty() and owned.record.get("source_item_class_id")==int(scroll_id) and int(owned.receipt.bless_raw)==1:
			scroll_name=str(owned.record.name)
		else:
			var record: Dictionary=scroll.get("record",{})
			var stored_name: String=str(scroll.get("name",""))
			var current_name: String=str(source_item_record(int(scroll_id)).get("name",""))
			# Old saves sometimes pin one ordinary scroll as a physical unit.
			# An invalid or foreign receipt must never fall back to legacy use.
			legacy=owned.is_empty() and not scroll.has(stock.RECEIPT) and not scroll.has(stock.QUANTITY) and not scroll.has("quest_reward_receipt") and not scroll.has("source_reward_quantity") \
				and (record.get("source_item_class_id")==int(scroll_id) or PATCH523_ENHANCE.item_id(record)==scroll_id) and int(scroll.get("level",-1))==0 \
				and patch523_equipment.bless_code(scroll)==1 and not stored_name.is_empty() and stored_name in [scroll_name,current_name]
			if not legacy:return PATCH523_EQUIPMENT.denied("가방에서 보유한 일반 인장 강화 주문서를 다시 선택하세요")
			scroll_name=stored_name
	var quote: Dictionary = PATCH523_SEAL_ACTIONS.quote(patch523_equipment,physical,scroll_id,inventory,gold,
		_item_locked(str(physical.name),item_id) or _item_locked(scroll_name) or _item_locked(scroll_name,scroll_uid),scroll_name)
	if not quote.get("ok",false):return quote
	if legacy:
		if int(quote.count)!=1:return PATCH523_EQUIPMENT.denied("선택한 주문서 개체의 수량이 부족합니다")
		quote["legacy_scroll_uid"]=scroll_uid
	elif not scroll_uid.is_empty():
		if int(owned.remaining)<int(quote.count): return PATCH523_EQUIPMENT.denied("선택한 주문서 묶음의 수량이 부족합니다")
		quote["scroll_request"]={"physical_id":scroll_uid,"quantity":int(quote.count),"expected_quantity":int(owned.remaining),
			"expected_remaining":int(owned.remaining)-int(quote.count),"source_native_stack_receipt":owned.receipt}
	else:
		var plain: int = int(inventory.get(scroll_name,0))
		for entry: Variant in item_instances.values():
			if entry is Dictionary and entry.get("name")==scroll_name:
				plain-=int(entry.get(stock.QUANTITY,entry.get("source_reward_quantity",1)))
		if plain<int(quote.count): return PATCH523_EQUIPMENT.denied("가방에서 사용할 주문서 묶음을 선택하세요")
	return quote

func _patch523_attempt_seal(item_id: String, scroll_id: String, scroll_uid: String = "") -> void:
	if hud.has_method("is_enhancement_presenting") and bool(hud.call("is_enhancement_presenting")): return
	if not _patch523_item_allowed(): return
	var quote: Dictionary = patch523_seal_quote(item_id,scroll_id,scroll_uid)
	if not bool(quote.get("ok",false)):
		hud.show_message(str(quote.get("reason","원본 강화를 실행할 수 없습니다")))
		return
	var staged: Dictionary = {}
	if quote.has("scroll_request"):
		var debit: Dictionary = preload("res://scripts/loot/current523_native_stack.gd").stage_debit(self,[quote.scroll_request])
		if not debit.get("ok",false):
			hud.show_message(str(debit.get("reason","선택한 주문서를 사용할 수 없습니다")))
			return
		staged = debit.overrides
	elif quote.has("legacy_scroll_uid"):
		staged={"inventory":inventory.duplicate(true),"item_instances":item_instances.duplicate(true)}
		staged.item_instances.erase(quote.legacy_scroll_uid)
		staged.inventory[quote.scroll_name]=int(staged.inventory[quote.scroll_name])-int(quote.count)
		if int(staged.inventory[quote.scroll_name])==0:staged.inventory.erase(quote.scroll_name)
	var before: Dictionary = {"inventory":inventory.duplicate(true),"instances":item_instances.duplicate(true),
		"equipped":equipped_items.duplicate(true),"gold":gold,"rng":rng.state,"hp":hp,"mp":mp,"next_id":next_item_instance_id}
	gold-=int(quote.cost)
	if staged.is_empty():
		inventory[str(quote.scroll_name)] = int(inventory[str(quote.scroll_name)])-int(quote.count)
		if int(inventory[str(quote.scroll_name)])==0: inventory.erase(str(quote.scroll_name))
	var result_type: String = "maintain" if bool(quote.protected) else "destroy"
	var result_level: int = int(quote.level)
	var target_name: String = str(quote.item)
	if rng.randf_range(0.0,100.0)<float(quote.success):
		result_type="success"
		result_level+=1
		item_instances[item_id]["level"]=result_level
		if not staged.is_empty(): staged.item_instances[item_id]["level"]=result_level
	elif result_type=="destroy":
		_destroy_enhancement_target(target_name,item_id)
		if not staged.is_empty():
			staged.item_instances.erase(item_id)
			if inventory.has(target_name): staged.inventory[target_name]=inventory[target_name]
			else: staged.inventory.erase(target_name)
		result_level=0
	_invalidate_equipment_static()
	hp=mini(hp,_effective_max_hp())
	if _save_game(true,staged)!=OK:
		inventory=before.inventory
		item_instances=before.instances
		equipped_items=before.equipped
		gold=int(before.gold)
		next_item_instance_id=int(before.next_id)
		rng.state=int(before.rng)
		hp=int(before.hp)
		mp=int(before.mp)
		_invalidate_equipment_static()
		_update_hud()
		hud.show_message("저장 실패 · 주문서·아데나·장비·난수 상태 보존")
		return
	if not staged.is_empty():
		inventory=staged.inventory
		item_instances=staged.item_instances
		if staged.has("consumable_state"):consumable_service.import_state(staged.consumable_state)
	_update_hud()
	hud.open_patch523_equipment_info(scroll_id,scroll_uid)
	hud.append_log("원본 인장 강화 · %s +%d · %s" % [target_name,int(quote.level),result_type])
	hud.show_enhancement_result(result_type,target_name,int(quote.level),result_level)

# Inspection API: exact original branches, not a replacement economy/rate table.
func patch523_enhancement_evidence(item_id: int, scroll_id: int, level_value: int, target_bless: int, scroll_bless: int) -> Dictionary:
	return patch523_equipment.enhancement_evidence(item_id, scroll_id, level_value, target_bless, scroll_bless)

func totem_conversion_quote(recipe_id: int) -> Dictionary:
	if totems.save_blocked: return {"ok":false,"reason":"토템 저장 보호 중"}
	for recipe: Dictionary in totems.recipes():
		if int(recipe.view.ItemCraftID) != recipe_id: continue
		if int(recipe.view.AlwaysSuccess) != 1 or recipe.inputs.size() != 1 or recipe.outputs.size() != 1: break
		var input: Dictionary = recipe.inputs[0]
		var output: Dictionary = recipe.outputs[0]
		if int(input.Amount) != 1 or int(output.Amount) != 1 or int(output.Probability) != 1000000: break
		var source: Dictionary = _catalog_item_from_source_id(str(int(input.ItemClassID)))
		var target: Dictionary = _catalog_item_from_source_id(str(int(output.ItemClassID)))
		if source.is_empty() or target.is_empty() or source.get("slot") != "material" or target.get("slot") != "material": break
		var from_name := str(source.name)
		var to_name := str(target.name)
		if from_name == to_name or _item_locked(from_name): return {"ok":false,"reason":"잠긴 재료는 전환할 수 없습니다"}
		if int(inventory.get(from_name,0)) < 1: return {"ok":false,"reason":"일반 강화석이 부족합니다"}
		var stack_limit := int(totems.row("ItemClass",int(output.ItemClassID)).get("MaxStackAmount",0))
		if stack_limit > 0 and int(inventory.get(to_name,0)) >= stack_limit: return {"ok":false,"reason":"각인 강화석 보유 한도 초과"}
		var weight := _inventory_total_weight() - int(item_weight_index.get(from_name,3)) + int(item_weight_index.get(to_name,3))
		if weight > _carrying_capacity(): return {"ok":false,"reason":"인벤토리 무게 한도 초과"}
		return {"ok":true,"input":from_name,"output":to_name}
	return {"ok":false,"reason":"원본 제작·아이템 연결 확인 대기"}

func _totem_convert_requested(recipe_id: int) -> bool:
	var quote := totem_conversion_quote(recipe_id)
	if not bool(quote.ok):
		hud.show_message(str(quote.reason))
		return false
	var staged := inventory.duplicate(true)
	staged[quote.input] = int(staged[quote.input])-1
	if staged[quote.input] == 0: staged.erase(quote.input)
	staged[quote.output] = int(staged.get(quote.output,0))+1
	if _save_game(true,{"inventory":staged}) != OK:
		hud.show_message("전환 저장 실패 · 재료 보존")
		return false
	inventory.clear()
	inventory.merge(staged,true)
	_update_hud()
	hud.refresh_totems()
	hud.show_message("전환 완료 · %s × 1" % quote.output)
	return true

func _craft_quote(recipe_id: String, batches: int) -> Dictionary:
	_sync_item_instances()
	if recipe_id.begins_with("patch523:"):
		return patch523_equipment.quote(recipe_id, batches, inventory, gold, _patch523_craft_items_for_recipe(recipe_id), item_instances,
			equipped_items, _inventory_total_weight(), _carrying_capacity(), ui_preferences.get("item_locks", {}), patch523_material_choices.get(recipe_id, {}), _patch523_craft_context(recipe_id,batches))
	return crafting.quote(
		recipe_id, batches, inventory, gold, _craft_item_index(), item_instances,
		equipped_items, _inventory_total_weight(), _carrying_capacity()
	)

func patch523_set_owned_materials(recipe_id: String,batches: int,selections: Array) -> Dictionary:
	if not recipe_id.begins_with("patch523:") or not patch523_equipment.recipes.has(recipe_id) or _patch523_protection_recipe_item(recipe_id)>0:return {"ok":false,"reason":"기존 일반 원본 제작식의 선택 재료만 이 계약을 사용합니다"}
	var reviewed: Dictionary=PATCH523_QUEST_MATERIALS.review(self,patch523_equipment,recipe_id,batches,patch523_material_choices.get(recipe_id,{}),selections)
	if not reviewed.get("ok",false):return reviewed
	if selections.is_empty():patch523_owned_material_choices.erase(recipe_id)
	else:patch523_owned_material_choices[recipe_id]={"batch":batches,"selections":selections.duplicate(true)}
	return {"ok":true,"recipe_id":recipe_id,"batch":batches,"selected":selections.size(),"saved":false,"use_authorized":false}

func patch523_clear_owned_materials(recipe_id: String) -> void:
	patch523_owned_material_choices.erase(recipe_id)

func _patch523_craft_context(recipe_id: String="",batches: int=1) -> Dictionary:
	var context: Dictionary={"level":level,"usage":patch523_crafting_usage,"now":int(Time.get_unix_time_from_system()),"expedition_owner":expedition_local,"awakening_world":self,"source_recipe_id":recipe_id,"server_profile":preload("res://scripts/loot/current523_server_profile.gd").profile(self)}
	if recipe_id.is_empty():return context
	var selected: Dictionary=patch523_owned_material_choices.get(recipe_id,{})
	if not selected.is_empty() and int(selected.batch)!=batches:
		context["quest_material_review"]={"ok":false,"reason":"제작 횟수가 변경됐습니다 · 원본 물리 재료와 잔량을 다시 선택하세요"}
	else:context["quest_material_review"]=PATCH523_QUEST_MATERIALS.review(self,patch523_equipment,recipe_id,batches,patch523_material_choices.get(recipe_id,{}),selected.get("selections",[]))
	return context

func patch523_craft_condition_summary(recipe: Dictionary) -> String:
	return patch523_equipment.CONDITIONS.summary(recipe,_patch523_craft_context())

## 비법서 제작 (original GachaCraft, TWILIGHT 근사 — scripts/crafting/patch523_gacha_craft.gd).
## UI API: owned books → quote (costs, ownership, per-item %) → execute (one
## atomic save; returns {ok, output:{item_class_id,name,amount,enchant,bless_raw,bound}, detail}).
func patch523_gacha_craft_owned() -> Array:
	_sync_item_instances()
	return preload("res://scripts/crafting/patch523_gacha_craft.gd").owned_callers(self)

func patch523_gacha_craft_quote(item_class_id: int, book_uid: String = "") -> Dictionary:
	_sync_item_instances()
	return preload("res://scripts/crafting/patch523_gacha_craft.gd").quote(self,item_class_id,book_uid)

func patch523_gacha_craft_execute(item_class_id: int, book_uid: String = "", quoted_quantity: int = -1) -> Dictionary:
	if death_recovery.blocked(): return {"ok":false,"reason":"사망 상태에서는 제작할 수 없습니다"}
	_sync_item_instances()
	if hp <= 0 or not _patch523_item_allowed() or _option_awakening_busy(): return {"ok":false,"reason":"현재 상태에서는 제작할 수 없습니다"}
	return preload("res://scripts/crafting/patch523_gacha_craft.gd").execute(self,item_class_id,-1,-1,book_uid,quoted_quantity)

func _craft_requested(recipe_id: String, batches: int) -> void:
	if death_recovery.blocked(): return
	if recipe_id.begins_with("patch523:"):
		_patch523_craft_requested(recipe_id, batches)
		return
	# Revalidate authoritative ingredients, wallet, weight and physical IDs.
	# The service stages mutations and commits only if every check succeeds.
	_sync_item_instances()
	var staged_inventory:Dictionary=inventory.duplicate(true)
	var staged_instances:Dictionary=item_instances.duplicate(true)
	var transaction: Dictionary = crafting.execute(
		recipe_id, batches, staged_inventory, gold, _craft_item_index(), staged_instances,
		equipped_items, _inventory_total_weight(), _carrying_capacity(), next_item_instance_id
	)
	if not bool(transaction.get("ok", false)):
		hud.show_message(str(transaction.get("reason", "제작에 실패했습니다")))
		return
	var staged_log:Array=crafting_log.duplicate(true)
	var output_name:String=str(transaction.result_name)
	var output_quantity:int=int(transaction.result_quantity)
	staged_log.append({"recipe_id":recipe_id,"batch":batches,"output":output_name,"quantity":output_quantity,"gold":int(transaction.cost),"at":Time.get_unix_time_from_system()})
	if staged_log.size()>200:staged_log.pop_front()
	var before_content: Dictionary = unconfirmed523.state.duplicate(true)
	unconfirmed523.record_event("craft",{"amount":output_quantity,"source_id":UNCONFIRMED523.native_id(_find_catalog_item_record(output_name)),"event_id":"craft:%s:%d"%[recipe_id,Time.get_ticks_usec()]})
	if _save_game(true,{"inventory":staged_inventory,"item_instances":staged_instances,"gold":int(transaction.gold_after),"next_item_instance_id":int(transaction.next_instance_id),"crafting_log":staged_log})!=OK:
		unconfirmed523.state = before_content
		hud.show_message("제작 저장 실패 · 재료·결과·재화 보존")
		return
	inventory=staged_inventory;item_instances=staged_instances;gold=int(transaction.gold_after);next_item_instance_id=int(transaction.next_instance_id)
	crafting_log.assign(staged_log)
	hud.refresh_inventory(inventory)
	hud.append_log("제작 완료 · %s ×%d" % [output_name,output_quantity])
	hud.show_message("제작 완료 · %s ×%d" % [output_name,output_quantity])
	_update_hud()
	if hud.has_method("open_crafting"):
		hud.call("open_crafting")

func _npc_teleport_requested(map_id: String) -> void:
	if death_recovery.blocked(): return
	if patch523_npc_spells.blocks("CannotTeleport"): return
	map_id = NATIVE_PNG.canonical(map_id)
	if player.is_stunned() or player.is_feared() or player.is_held():
		hud.show_message("이동 불가 상태에서는 텔레포트할 수 없습니다")
		return
	var quote: Dictionary = NPC_TELEPORT_POLICY.quote(map_id,maps_by_id,active_map_id,level,gold)
	if not bool(quote.get("ok",false)):
		hud.show_message(str(quote.get("reason","텔레포트할 수 없습니다")))
		return
	# Existing map loader validates its own field and destination before
	# changing active_map_id. Only debit after a confirmed transition.
	var cost: int = int(quote["price"])
	_set_map(map_id,false)
	if active_map_id != map_id:
		hud.show_message("목적지 맵을 불러올 수 없습니다")
		return
	gold -= cost
	_update_hud()
	_request_deferred_save()
	hud.show_message("텔레포트 완료 · %d 아데나" % cost)


func _warehouse_transfer(item_name: String, quantity: int, direction: String, instance_id: String) -> void:
	if death_recovery.blocked(): return
	# Do not build a candidate or join an autosave on a warehouse tap. This
	# request is NOT accepted/queued; a later explicit tap validates fresh state.
	# The normal save pump owns completion (including errors), not this UI call.
	if background_save_pending():
		hud.show_message("저장 처리 중 · 창고 이동은 실행하지 않았습니다. 완료 후 다시 눌러 주세요.")
		return
	if direction == "deposit" and not half_elixir.storable(item_name):
		hud.show_message("원본에서 보관할 수 없는 하프 엘릭서 품목입니다.")
		return
	if item_name==titles.source.powder_record.get("name",""):
		if direction=="deposit" and not bool(titles.source.powder_record.get("storable",false)):
			hud.show_message("상급 축복의 가루는 원본에서 창고 보관 불가입니다.")
			return
		if direction=="withdraw" and not titles.can_pickup({"item_name":item_name,"quantity":quantity}):
			hud.show_message("상급 축복의 가루 최대 소지 수량을 초과합니다.")
			return
	if direction == "deposit" and protection523.managed(_find_catalog_item_record(item_name)):
		hud.show_message("원본 가호는 창고 보관 불가 아이템입니다")
		return
	if item_name.begins_with("[원본 보상] "):
		hud.show_message("원본 보상 보관 중 · 사용/이동 기능 연결 대기")
		return
	if item_name == "아데나" or item_name.is_empty():
		hud.show_message("이 아이템은 창고에 보관할 수 없습니다")
		return
	var record: Dictionary = _find_catalog_item_record(item_name)
	if direction == "deposit" and record.has("growth96_item_id") and not bool(record.get("storable",false)):
		hud.show_message("원본 성장 보상은 창고 보관이 제한되어 있습니다")
		return
	if record.get("monsterbook_source_item",false) and not record.get("storable",false):
		hud.show_message("원본 보관 제한 아이템입니다")
		return
	if record.is_empty() or int(quantity) < 1 or int(quantity) > 99:
		hud.show_message("창고 아이템 또는 수량이 유효하지 않습니다")
		return
	var source_restriction:String=expedition_local.transfer_restriction(item_name,direction)
	if not source_restriction.is_empty() or _item_locked(item_name,instance_id):hud.show_message(source_restriction if not source_restriction.is_empty() else "잠긴 아이템은 이동할 수 없습니다");return
	var native_stack: Dictionary=preload("res://scripts/loot/current523_native_stack.gd").transfer_warehouse(self,item_name,quantity,direction,instance_id)
	if native_stack.get("handled",false):
		hud.show_message(str(native_stack.get("message",native_stack.get("reason","원본 창고 개체 확인 필요"))))
		if native_stack.get("ok",false):_update_hud();hud.refresh_inventory(inventory)
		return
	if direction=="deposit" and not preload("res://scripts/cards/source_awakening_items.gd").storage_allowed(item_name,record,item_instances):
		hud.show_message("창고 보관이 불가능한 원본 아이템입니다")
		return
	_sync_item_instances()
	var staged_inventory:Dictionary=inventory.duplicate(true)
	var staged_instances:Dictionary=item_instances.duplicate(true)
	var staged_warehouse=LOCAL_WAREHOUSE.new();staged_warehouse.stacks=warehouse.stacks.duplicate(true);staged_warehouse.instances=warehouse.instances.duplicate(true)
	var is_equipment: bool = _enhancement_kind_for_record(record) != ""
	var source_instances: Dictionary=item_instances if direction=="deposit" else warehouse.instances
	if preload("res://scripts/cards/source_awakening_items.gd").has_physical_item(item_name,source_instances):
		if instance_id.is_empty() or quantity!=1 or not source_instances.has(instance_id) or source_instances[instance_id].get("name","")!=item_name or not source_instances[instance_id].get("record") is Dictionary or not preload("res://scripts/cards/source_awakening_items.gd").recognized(source_instances[instance_id].record):
			hud.show_message("원본 각성 아이템은 개체를 선택해 한 개씩 이동하세요")
			return
		if direction=="deposit" and (_item_locked(item_name) or _item_locked(item_name,instance_id)):
			hud.show_message("잠긴 원본 아이템은 보관할 수 없습니다")
			return
		is_equipment=true # Reuse the physical-preserving warehouse path.
		if direction=="deposit" and int(staged_instances[instance_id].get("source_awakening_quantity",1))>1:
			var unit: Dictionary=staged_instances[instance_id].duplicate(true);unit.source_awakening_quantity=1
			staged_instances[instance_id].source_awakening_quantity=int(staged_instances[instance_id].source_awakening_quantity)-1
			var separated: String=Crypto.new().generate_random_bytes(16).hex_encode()
			while staged_instances.has(separated):separated=Crypto.new().generate_random_bytes(16).hex_encode()
			staged_instances[separated]=unit;instance_id=separated

	var result: Dictionary = {}
	if direction == "deposit":
		result = staged_warehouse.store(item_name,quantity,instance_id,staged_inventory,staged_instances,equipped_items,is_equipment)
	elif direction == "withdraw":
		result = staged_warehouse.retrieve(
			item_name,quantity,instance_id,staged_inventory,staged_instances,is_equipment,
			_inventory_total_weight(),_carrying_capacity(),maxi(0,int(item_weight_index.get(item_name,3)))
		)
	else:
		hud.show_message("잘못된 창고 요청입니다")
		return
	if not bool(result.get("ok",false)):
		hud.show_message(str(result.get("reason","창고 이용에 실패했습니다")))
		return
	if _save_game(true,{"inventory":staged_inventory,"item_instances":staged_instances,"warehouse":staged_warehouse.snapshot()})!=OK:
		hud.show_message("창고 저장 실패 · 소지품·창고 보존");return
	inventory=staged_inventory;item_instances=staged_instances;warehouse.stacks=staged_warehouse.stacks;warehouse.instances=staged_warehouse.instances
	_update_hud()
	hud.append_log("창고 %s · %s ×%d" % ["보관" if direction == "deposit" else "찾기",item_name,quantity])
	hud.show_message("창고 이용 완료")
	if hud.has_method("refresh_service"):
		hud.call("refresh_service")

func _use_potion() -> void:
	if death_recovery.blocked(): return
	# The HUD potion slot (왼쪽 위 캐릭터 정보 옆): the potion the player chose
	# there, else the original 523 HP potion (#233).
	var chosen: String = hud_potion_name()
	if chosen.is_empty():
		# The chooser lists the owned ones (a rule-refused potion greyed) or
		# says none is owned.
		if hud.has_method("open_hud_potion_choice"): hud.open_hud_potion_choice()
		else: hud.show_message("보유한 체력 회복 물약이 없습니다")
		return
	_use_quick_item(chosen)

const HUD_POTION_KEY := "hud_potion_item"
## Owned HP-restoring items for the HUD potion slot, each with the reason it
## cannot be drunk now (원본 레벨·직업 제한 등; empty when usable).
func hud_potion_candidates() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var stack: Script = preload("res://scripts/loot/current523_native_stack.gd")
	var native_use: Script = preload("res://scripts/loot/patch523_item_use.gd")
	for key: Variant in inventory:
		var name_value: String = str(key)
		if int(inventory.get(name_value, 0)) <= 0: continue
		var record: Dictionary = _find_catalog_item_record(name_value)
		if record.is_empty(): continue
		var native_hp: bool = str(stack.profile(record).get("kind", "")) == "hp"
		if not native_hp and not (str(record.get("slot", "")) == "consumable" and int(record.get("heal", 0)) > 0): continue
		var reason: String = PATCH523_ITEM_USE.reason(_patch523_use_record(name_value), level, BASE508.source_class_id(job_class))
		if reason.is_empty() and native_hp: reason = str(native_use.eligibility(self, record))
		rows.append({"name":name_value,"count":int(inventory[name_value]),"reason":reason,"item_class_id":int(record.get("source_item_class_id", 0)),"heal":int(record.get("heal", 0))})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.heal) < int(b.heal) if int(a.heal) != int(b.heal) else str(a.name) < str(b.name))
	return rows

## The potion the HUD slot drinks: the chosen one while owned and usable,
## else the first usable owned original HP potion (#233 first).
func hud_potion_name() -> String:
	var chosen: String = str(ui_preferences.get(HUD_POTION_KEY, ""))
	var candidates: Array[Dictionary] = hud_potion_candidates()
	for row: Dictionary in candidates:
		if row.name == chosen and str(row.reason).is_empty(): return chosen
	for name_value: String in preload("res://scripts/loot/current523_starter_kit.gd").quickslot_names(self):
		for row: Dictionary in candidates:
			if row.name == name_value and str(row.reason).is_empty(): return name_value
	for row: Dictionary in candidates:
		if str(row.reason).is_empty(): return str(row.name)
	return ""

func select_hud_potion(item_name: String) -> bool:
	for row: Dictionary in hud_potion_candidates():
		if row.name != item_name: continue
		if not str(row.reason).is_empty():
			hud.show_message(str(row.reason))
			return false
		ui_preferences[HUD_POTION_KEY] = item_name
		hud.set_quick_items(inventory)
		_request_deferred_save()
		return true
	return false

func _use_quick_item(item_name: String) -> void:
	if death_recovery.blocked(): return
	if _item_requests_map_loading(item_name):
		_activate_inventory_input(item_name)
		return
	if item_name.begins_with("[원본 보상] "):
		hud.show_message("원본 보상 보관 중 · 사용/이동 기능 연결 대기")
		return
	if not _patch523_item_allowed(): return
	if unconfirmed523.try_use(item_name):return
	if _find_catalog_item_record(item_name).get("source_automation_catalog_only",false):
		hud.show_message("원본 사용 효과 미연결 · 아이템 보존")
		return
	if bool(consumable_service.call("try_use", item_name)):
		return
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
	var buffs_before: int=player_npc_buff_signature()
	var native_stack: Dictionary=preload("res://scripts/loot/current523_native_stack.gd").try_use(self,item_name)
	if native_stack.get("handled",false):
		hud.show_message(str(native_stack.get("message",native_stack.get("reason","원본 물리 수량 확인 필요"))))
		if native_stack.get("ok",false):hud.refresh_inventory(inventory);publish_hud(native_use_hud_domains(native_stack,buffs_before))
		return
	var native: Dictionary=_find_catalog_item_record(item_name)
	if native.get("source_m_native_item",false) and int(native.get("source_item_class_id",0))==233:
		preload("res://scripts/loot/quest_hp233_use.gd").use(self,native)
		return
	if native.get("source_m_native_item",false) and int(native.get("source_item_class_id",0))==LOOT_DROP.PATCH523_DROPS.LARGE_HP_ELIXIR_ID:
		hud.show_message("원본 영약 실제 소지 개체를 선택하세요 · 아이템 보존")
		return
	if not _patch523_item_allowed(): return
	var record: Dictionary = _find_catalog_item_record(item_name)
	var is_source: bool = bool(record.get("source_m_native_item", false))
	if is_source:
		record = preload("res://scripts/loot/patch523_item_use.gd").canonical(record)
		var problem: String = preload("res://scripts/loot/patch523_item_use.gd").eligibility(self, record)
		if problem.is_empty(): problem = LOOT_DROP.PATCH523_DROPS.hp_use_problem(record,is_player_concealed(),int(ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not problem.is_empty() or record.get("heal_spec", {}).is_empty():
			hud.show_message(problem if not problem.is_empty() else "원본 회복 효과 미지원 · 아이템 보존")
			return
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("%s이(가) 없습니다" % item_name)
		return
	var effective_max_hp: int = _effective_max_hp()
	if hp >= effective_max_hp:
		hud.show_message("HP가 가득 찼습니다")
		return
	var cooldown_left: float = float(item_use_cooldowns.get(HP_POTION_COOLDOWN_KEY, 0.0))
	if cooldown_left > 0.0:
		hud.show_message("HP 물약 재사용 대기 %s" % _format_seconds_short(cooldown_left))
		return
	var rng_before: int = rng.state
	heal_amount = LOOT_DROP.PATCH523_DROPS.healing_amount(record, rng, heal_amount)
	var next_inventory: Dictionary = inventory.duplicate(true)
	next_inventory[item_name] = int(next_inventory.get(item_name, 0)) - 1
	if is_source and int(next_inventory[item_name]) == 0: next_inventory.erase(item_name)
	var next_cooldowns: Dictionary = item_use_cooldowns.duplicate(true)
	next_cooldowns[HP_POTION_COOLDOWN_KEY] = HP_POTION_COOLDOWN_SECONDS * (1.0-clampf(growth.bonus("potion_cooldown:percent") + _enhancement_float_for_slots(EQUIPMENT_SLOT_ORDER, "potion_cooldown_pct"),0.0,90.0)/100.0)
	var enhanced_heal: int = maxi(1, heal_amount + _catalog_stat_sum("potionHealFlat") + _equipment_potion_heal_stat("물약 회복량") + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "potion_heal_flat") + int(original_skills.stat("potionFlat") if original_skills != null else 0))
	enhanced_heal += int(round(float(heal_amount) * float(_catalog_stat_sum("potionHealPct") + _equipment_potion_heal_stat("물약 회복률") + _enhancement_float_for_slots(EQUIPMENT_SLOT_ORDER, "potion_heal_pct") + _equipped_bless_bonus("potion_heal_pct")) / 100.0))
	var adjusted_heal: int = patch523_npc_spells.extensions.healing(maxi(1, enhanced_heal),true)
	var next_hp: int = clampi(hp + adjusted_heal,0,effective_max_hp)
	# Consumables commit in memory and join the coalesced background save
	# (user decision 2026-11-21, option A): a full synchronous save per potion
	# was ~0.4 s on the phone (523.747: five saves in one 7.3 s frame). A
	# crash before that save can return the last few seconds of potions.
	inventory = next_inventory
	item_use_cooldowns = next_cooldowns
	apply_patch523_healing(maxi(1,enhanced_heal),true)
	if is_source: _request_general_save()
	hud.refresh_inventory(inventory)
	hud.show_message("%s 사용" % item_name)
	if is_source:
		var source_visual: int = int(LOOT_DROP.PATCH523_DROPS.hp_use_metadata(record).get("consume_effect_sprite_id",0))
		if source_visual > 0: option_awakening.combat.emit_sprite(source_visual,player,LOOT_DROP.PATCH523_DROPS.item_definition(record).get("original_item",{}))
	_update_hud()

func _source_hp_potion_parameters(heal_amount: int) -> Dictionary:
	# Existing host potion bonuses and shared cooldown, used by the verified
	# source dice consumer without replacing the NPC healing adjustment/event.
	var enhanced: int=maxi(1,heal_amount+_catalog_stat_sum("potionHealFlat")+_equipment_potion_heal_stat("물약 회복량")+_enhancement_stat_for_slots(ACCESSORY_EQUIPMENT_SLOTS,"potion_heal_flat")+int(original_skills.stat("potionFlat") if original_skills!=null else 0))
	enhanced+=int(round(float(heal_amount)*float(_catalog_stat_sum("potionHealPct")+_equipment_potion_heal_stat("물약 회복률")+_enhancement_stat_for_slots(ACCESSORY_EQUIPMENT_SLOTS,"potion_heal_pct")+_active_item_buff_total("potion_heal_pct"))/100.0))
	return {"heal_amount":maxi(1,enhanced),"cooldown_key":HP_POTION_COOLDOWN_KEY,"cooldown_seconds":HP_POTION_COOLDOWN_SECONDS*(1.0-clampf(growth.bonus("potion_cooldown:percent"),0.0,90.0)/100.0)}

func _source_hp_potion_committed(amount: int) -> void:
	if amount>0:patch523_npc_spells.extensions.on_player_event("healed")

func _return_to_spawn_input() -> void:
	if MAP_LOADING.busy(self) or death_recovery.blocked() or patch523_npc_spells.blocks("CannotTeleport"): return
	if current523_aden_source_active():
		var outcome: Dictionary = await run_map_loading(return_current523_source_to_aden_loading)
		hud.show_message(str(outcome.get("reason","아덴 귀환 결과 확인 필요")))
		return
	_return_to_spawn()


func _return_to_spawn() -> void:
	if death_recovery.blocked(): return
	if patch523_npc_spells.blocks("CannotTeleport"): return
	if current523_aden_source_active():
		var outcome: Dictionary=return_current523_source_to_aden()
		hud.show_message(str(outcome.get("reason","아덴 귀환 결과 확인 필요")))
		return
	if player.is_stunned() or player.is_feared():
		hud.show_message("현재 상태에서는 귀환할 수 없습니다")
		return
	player.clear_click_path()
	if is_instance_valid(world_interactions): world_interactions.clear_selection()
	player.global_position = _spawn_position()
	player.camera.reset_smoothing()
	selected_monster = null
	auto_target = null
	hud.clear_target()
	hud.show_message("현재 지역 시작 지점으로 귀환했습니다")

func _on_auto_toggled(enabled: bool) -> void:
	inventory_automation.maintenance.mode_changed(enabled)
	loot_pickup.cancel()
	hud.set_auto(enabled)
	if not enabled:
		_clear_auto_target_search()
		auto_target = null
		player.clear_click_path()

func _open_inventory() -> void:
	var started_usec: int = Time.get_ticks_usec()
	# A session can still receive an old catalog grant, or the player can
	# unlock one that was protected during load.
	if inventory.has(titles.POWDER_SHOP_KEY) and titles.reconcile_powder_stock(): _update_hud()
	hud.refresh_inventory(inventory)
	hud.toggle_inventory()
	_perf_log("가방 열기", started_usec)

func _on_map_selected(map_id: String) -> void:
	if death_recovery.blocked(): return
	hud.toggle_map()
	_set_map(map_id, false)

## Read-only stat memo for one HUD publish. The character snapshot asks for
## the same derived values many times (one _update_hud: 825 helper calls, the
## same attribute 37 times); nothing changes them while it is built, so inside
## _stat_memo_begin()/_stat_memo_end() each is computed once. Outside, every
## call computes as before.
var _stat_memo: Dictionary = {}
var _stat_memo_depth: int = 0

func _stat_memo_begin() -> void:
	_stat_memo_depth += 1

func _stat_memo_end() -> void:
	_stat_memo_depth = maxi(0, _stat_memo_depth - 1)
	if _stat_memo_depth == 0: _stat_memo.clear()

## After a local clan change (creation, donation, level): the clan buff is
## read on demand, so only the shown values and the bag are refreshed.
func _refresh_after_clan_change() -> void:
	if hud != null and hud.has_method("refresh_inventory"): hud.refresh_inventory(inventory)
	_update_hud()

## Publishes the HUD for `domains` (HUD_* bits). Vitals/items only take the
## light paths; any other bit rebuilds everything (_update_hud).
func publish_hud(domains: int) -> void:
	if domains & ~(HUD_VITALS | HUD_ITEMS) != 0 or domains == 0:
		_update_hud()
		return
	if domains & HUD_ITEMS: _refresh_inventory_hud()
	if domains & HUD_VITALS:
		_refresh_combat_hud()
		_update_ain_hud()

## Identity of the NPC-cast buffs/debuffs on the player: healing can erase
## some (IsEraseOnHealed), which changes stats and needs the full publish.
## What a committed native-stack use changed: an HP/MP potion only its
## vitals and the bag (unless healing erased a buff); anything else is full.
func native_use_hud_domains(result: Dictionary, buffs_before: int) -> int:
	if str(result.get("effect_kind","")) in ["hp","mp"] and player_npc_buff_signature()==buffs_before:return HUD_VITALS | HUD_ITEMS
	return HUD_FULL

func player_npc_buff_signature() -> int:
	return hash(patch523_npc_spells.player_buffs.keys())

func _update_hud() -> void:
	_publish_player_hud(true)

## All combat/character stats are still published immediately. Only group
## the bag's count and physical-record changes and omit unrelated card UI
## exports; the native timed-buff owner did not modify a card ledger.
func _publish_timed_buff_hud() -> void:
	var since:int=FRAME_HITCH.now()
	var bag:Variant=hud.get("lineage_inventory_ui")
	var batch:bool=is_instance_valid(bag) and bag.has_method("begin_state_publish") and bag.has_method("end_state_publish")
	if batch:bag.begin_state_publish()
	_publish_player_hud(true,true)
	if batch:
		var finish:int=FRAME_HITCH.now()
		bag.end_state_publish()
		FRAME_HITCH.detail("item.buff_bag_publish",finish)
	FRAME_HITCH.detail("item.buff_hud",since)

func _publish_player_hud(fold_native_stacks:bool, timed_item:bool=false) -> void:
	var phase:int=FRAME_HITCH.now() if timed_item else 0
	hud_publish_counts.full += 1
	if is_instance_valid(title_badge):
		title_badge.text=titles.display_name()
		title_badge.add_theme_color_override("font_color",titles.personal.display_color())
		# TWILIGHT 근사: with no 작위/개인 호칭 shown, the held possession title (보유 칭호).
		if title_badge.text.is_empty() and item_appellation523 != null: title_badge.text=item_appellation523.display_name()
		title_badge.visible=not title_badge.text.is_empty()
	if protection523!=null and not protection523.get("source").is_empty():preload("res://scripts/crafting/patch523_protection_bindings.gd").prepare(self)
	stat_hud_refresh_pending = false
	unconfirmed523.rebuild()
	# Every equipment, enhancement, card, collection, growth, awakening,
	# passive-learning and load transaction publishes through this entry point.
	_invalidate_equipment_static()
	if fold_native_stacks:_merge_native_stacks()
	_sync_item_instances()
	if timed_item:phase=FRAME_HITCH.detail_next("item.buff_hud_prepare",phase)
	_stat_memo_begin()
	_refresh_speed_modifiers()
	var display_max_hp: int = _effective_max_hp()
	var display_max_mp: int = _effective_max_mp()
	hud.update_player(level, hp, display_max_hp, mp, display_max_mp, experience, exp_need, gold)
	_update_ain_hud()
	if hud.has_method("set_quick_items"):
		hud.call("set_quick_items", inventory)
	var character_state: Dictionary = _character_stats_snapshot()
	character_state["class_index"] = class_index
	character_state["job_class"] = job_class
	character_state["character_name"] = character_display_name
	character_state["source_gender_id"] = source_gender_id
	var job_profile: Dictionary = _job_profile(job_class)
	character_state["job_image_path"] = str(job_profile.get("image_path", ""))
	character_state["job_transform_name"] = str(job_profile.get("transform_name", ""))
	character_state["level"] = level
	character_state["hp"] = hp
	character_state["max_hp"] = display_max_hp
	character_state["mp"] = mp
	character_state["max_mp"] = display_max_mp
	character_state["attack"] = _effective_attack()
	character_state["defense"] = _effective_defense()
	character_state["equipped"] = equipped_catalog
	character_state["equipped_items"] = _equipped_items_snapshot()
	character_state["equipped_ammo"] = equipped_ammo
	character_state["enhancement_levels"] = enhancement_levels
	character_state["item_instances"] = item_instances
	character_state["combination_death_stat"]=_effective_attribute("DTH")
	character_state["gold"] = gold
	character_state["equipment_collection_bonuses"] = equipment_collections.totals.duplicate(true)
	character_state["card_collection_bonuses"] = card_collections.totals.duplicate(true)
	character_state["item_locks"] = ui_preferences.get("item_locks",{})
	_stat_memo_end()
	if timed_item:phase=FRAME_HITCH.detail_next("item.buff_hud_stats",phase)
	hud.set_character_state(character_state)
	if timed_item:phase=FRAME_HITCH.detail_next("item.buff_hud_sheet",phase)
	if not timed_item:
		if hud.has_method("set_card_collection_state"):
			hud.call("set_card_collection_state", card_draw_fusion.export_state())
		if hud.has_method("set_option_awakening_state"):
			hud.call("set_option_awakening_state", option_awakening.export_state())
		var completed_cards: Array[String] = card_collections.reconcile()
		if not completed_cards.is_empty():
			hud.append_log("카드 컬렉션 자동 완성 · %d개" % completed_cards.size())
		if hud.has_method("refresh_normal_card_collections"):hud.call("refresh_normal_card_collections")
	# Use the loaded physical records and stack counts together. The final
	# quickslot feed sees the same inventory and cannot trigger another bag publish.
	if timed_item or hud.inventory_panel.visible:
		hud.refresh_inventory(inventory)
	if timed_item:phase=FRAME_HITCH.detail_next("item.buff_bag_feed",phase)
	if hud.has_method("set_quickslot_state"):
		hud.call("set_quickslot_state", effective_quickslots(), inventory, _combined_active_buffs(), self_mode_enabled)
	elif hud.has_method("set_quickslot_entries"):
		hud.call("set_quickslot_entries", effective_quickslots())
	regional_return_settings_updated.emit()
	if timed_item:FRAME_HITCH.detail("item.buff_hud_final",phase)

func _refresh_combat_hud() -> void:
	# Only presentation limits are reused. Equipment/stat/buff changes and loads
	# publish fresh limits through _update_hud; real damage still queries live stats.
	# HP-only changes must not queue an equipment/character/inventory rebuild.
	hud_publish_counts.vitals += 1
	var display_max_hp: int = int(hud.character_state.get("max_hp", max_hp))
	var display_max_mp: int = int(hud.character_state.get("max_mp", max_mp))
	hud.character_state["gold"] = gold
	hud.update_player(level, hp, display_max_hp, mp, display_max_mp, experience, exp_need, gold)

# Android debug APKs receive the full catalog automatically. Desktop developers
# can opt in using --playtest-full-cards; release builds never seed ownership.
func _full_cards_playtest_active() -> bool:
	return CHARACTER_PROFILE.full_cards_active()

func base_save_path() -> String:
	return CHARACTER_PROFILE.namespace_for(BASE508_TEST.enabled(), growth.development, _full_cards_playtest_active(), NATIVE_PNG.enabled())

func save_path() -> String:
	if not migration_path_checked:
		migration_path_checked=true
		var resolved: Dictionary=CHARACTER_PROFILE.resolve(base_save_path())
		if resolved.ok:
			migrated_save_path=str(resolved.path);migration_pointer_error=""
		else:migration_pointer_error=str(resolved.problem)
	return migrated_save_path if not migrated_save_path.is_empty() else base_save_path()

func _request_general_save() -> void:
	# Autosave requests in one frame share one commit. Transactions and explicit
	# saves still call _save_game directly and complete before returning.
	if general_save_pending:return
	general_save_pending=true
	if not background_save_pending(): _commit_general_save.call_deferred()

func _tick_automatic_save(delta: float) -> void:
	_finish_background_save(false)
	# A busy writer keeps a single reservation. Once it finishes, save the
	# latest state rather than preparing a second snapshot or blocking here.
	if general_save_pending and not background_save_pending(): _commit_general_save.call_deferred()
	if deferred_save.tick(delta): _request_general_save()

func _commit_general_save() -> void:
	if not general_save_pending or background_save_pending(): return
	general_save_pending = false
	var started: int = FRAME_HITCH.now()
	var nested: int = FRAME_HITCH.nested()
	_save_game(true,{},{},false,true)
	FRAME_HITCH.add_self("save", started, nested)

var background_save_enabled: bool = DisplayServer.get_name() != "headless"
var _background_from_outer: bool = false
var _background_save_task: int = -1
var _background_save_job: Dictionary = {}

func background_save_pending() -> bool:
	return _background_save_task >= 0

func _start_background_save(data: Dictionary, prior_hash: String, started_usec: int, owned_fields: Dictionary = {}) -> Error:
	var pre: Error = equipment_collections.precheck_write(save_path())
	if pre != OK:
		hud.append_log("저장 실패 · 이전 저장 파일 보존 · 오류 %d" % pre)
		return pre
	# Exporters below already detached some fields. Transfer only those exact
	# roots; copy every live/overridden/trimmed replacement as before.
	var freeze_started: int = FRAME_HITCH.now()
	var frozen: Dictionary = SAVE_SNAPSHOT.freeze(data, owned_fields)
	FRAME_HITCH.detail("save.freeze", freeze_started)
	var job: Dictionary = {"path":save_path(),"data":frozen,"prior_hash":prior_hash,"error":ERR_BUSY}
	# Everything changed so far is in this save; later changes queue a new one.
	deferred_save.cancel()
	_background_save_job = job
	_background_save_task = WorkerThreadPool.add_task(_run_background_save.bind(job), false, "TWILIGHT save")
	_perf_log("저장(준비)", started_usec)
	return OK

## Worker thread: no scene/HUD access, only the job's own data and files.
static func _run_background_save(job: Dictionary) -> void:
	var account: Script = preload("res://scripts/characters/account_store.gd")
	# Flat saves have no account graph to transfer. Retain the original
	# lifecycle there: changing which thread releases the large flat graph
	# regressed a matched legacy completion benchmark.
	var account_job: bool=not account.session.is_empty() and account.session.get("path")==job.path
	var stage: Dictionary = account.stage_compact_write(str(job.path),job.data) if account_job else account.stage_save(str(job.path),job.data)
	# This input belongs to the worker. Release the frozen snapshot here,
	# not when the main loop drops the completed job after publication.
	if account_job:job.erase("data")
	if not stage.get("ok",false):
		job["error"] = ERR_INVALID_DATA; job["problem"] = str(stage.get("problem",""))
		return
	var payload: Dictionary = stage.payload
	if account_job:
		job["envelope"] = stage.envelope
	else:
		job["envelope"] = payload.get(account.KEY)
		payload=account.compact(payload)
	account.forget_durable()
	var text: String = JSON.stringify(payload, "", true, true)
	job["payload_hash"] = text.sha256_text()
	# Only these fields must be published separately after disk verification.
	# Do not transfer the entire compact save back to the main thread merely
	# to free it there; the account cache has its own sealed read-only graph.
	if account_job:
		var extras: Dictionary={}
		for key: String in ["protection523","expedition523_local","patch523_transaction_rng"]:
			if payload.has(key): extras[key]=payload[key].duplicate(true)
		job["extras"] = extras
	else:job["payload"]=payload
	job["error"] = preload("res://scripts/skills/save_writer.gd").write_text_if_unchanged(str(job.path), text, str(job.prior_hash))

func _finish_background_save(wait: bool) -> void:
	if _background_save_task < 0: return
	if not wait and not WorkerThreadPool.is_task_completed(_background_save_task): return
	WorkerThreadPool.wait_for_task_completion(_background_save_task)
	_background_save_task = -1
	var job: Dictionary = _background_save_job
	_background_save_job = {}
	if int(job.get("error",ERR_BUG)) == OK:
		var completed: Error=equipment_collections.commit_written(str(job.path), job.get("payload",{}), str(job.payload_hash))
		if completed == OK:
			if job.get("envelope") is Dictionary:
				CHARACTER_ACCOUNT.adopt_verified_worker_envelope(str(job.path),job,equipment_collections.verified_payload_sha(str(job.path)))
			if not CHARACTER_ACCOUNT.session.is_empty() and CHARACTER_ACCOUNT.session.get("path")==str(job.path): CHARACTER_ACCOUNT.session["initialized"]=true
			if job.has("extras"):
				for key: String in job.extras: equipment_collections.extra_save_fields[key]=job.extras[key]
			else:
				for key: String in ["protection523","expedition523_local","patch523_transaction_rng"]:
					if job.payload.has(key):equipment_collections.extra_save_fields[key]=job.payload[key].duplicate(true)
			return
		job["error"]=completed
	CHARACTER_ACCOUNT.forget_durable()
	if not str(job.get("problem","")).is_empty(): hud.append_log(str(job.problem))
	hud.append_log("저장 실패 · 이전 저장 파일 보존 · 오류 %d" % int(job.get("error",ERR_BUG)))
	if FileAccess.file_exists(str(job.path)) and FileAccess.get_sha256(str(job.path)) != str(job.prior_hash):
		patch523_owner_state_problem="원본 거래 저장 결과 확인 필요 · 다시 불러오기 전 소모/지급 중지"
	else:
		deferred_save.request()

## Ask for a save after DEFERRED_SAVE_SECONDS of quiet. Use only for state that
## is consistent if the last few seconds are lost; RNG outcomes and item/skill
## transactions keep calling _save_game directly.
## Promotion code entry (UI: 메뉴 > 쿠폰 코드). Codes have no use limit.
func redeem_promo_code(raw_code: String) -> Dictionary:
	var result: Dictionary = PROMO_CODES.apply(raw_code, gold, inventory)
	if not bool(result.get("ok", false)):
		return result
	gold = int(result.gold)
	inventory[PROMO_CODES.DIAMOND_ITEM] = int(result.diamond)
	hud.refresh_inventory(inventory)
	hud.show_message("쿠폰 코드 보상 · 다이아 %d · 아데나 %d" % [int(result.diamond_gain), int(result.gold_gain)])
	hud.append_log("쿠폰 코드 %s · 다이아 +%d · 아데나 +%d" % [str(result.code), int(result.diamond_gain), int(result.gold_gain)])
	_update_hud()
	_request_deferred_save()
	return result

func _request_deferred_save() -> void:
	if not deferred_save_enabled:
		_save_game(true)
		return
	deferred_save.request()

## Debug builds log any step slower than 30 ms to the engine log (logcat on
## Android). It is no longer written into the in-game chat (user: the game
## screen should show the game, not performance notes).
func _perf_log(label: String, started_usec: int) -> void:
	if not OS.is_debug_build(): return
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	if elapsed_usec >= PERF_LOG_THRESHOLD_USEC:
		print("[성능] %s %d ms" % [label, int(elapsed_usec / 1000.0)])

func _prepare_patch523_item_save_backup() -> Error:
	if LOOT_DROP.PATCH523_DROPS.pack_identity().is_empty(): return OK
	var target: String = save_path()
	if source_item_backup_checked_path == target: return OK
	if FileAccess.file_exists(target):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(target)
		var existing: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		if not existing is Dictionary: return ERR_FILE_CORRUPT
		var marker: Variant = existing.get("source_item_catalog",{})
		var actual_input: Dictionary=LOOT_DROP.PATCH523_DROPS.pack_identity()
		if actual_input.get("schema")==4 and marker!=actual_input:
			var fingerprint: String=preload("res://scripts/lineagem_pack_install.gd").sha(bytes)
			var backup: String=target+".pre-current523-original-input-"+fingerprint
			if (not FileAccess.file_exists(backup) and DirAccess.copy_absolute(target,backup)!=OK) or FileAccess.get_sha256(backup)!=fingerprint:return ERR_CANT_CREATE
		if not marker is Dictionary or int(marker.get("schema",0)) not in [3,4]:
			var fingerprint: String = preload("res://scripts/lineagem_pack_install.gd").sha(bytes)
			var backup: String = target+".pre-itemclass523-"+fingerprint
			if (not FileAccess.file_exists(backup) and DirAccess.copy_absolute(target,backup) != OK) or FileAccess.get_sha256(backup) != fingerprint: return ERR_CANT_CREATE
	source_item_backup_checked_path = target
	return OK

func _save_card_selection(quiet: bool, staged: Dictionary) -> Error:
	return card_selection_saves.commit(self, quiet, staged)

## Field camera = field data zoom x the player's camera distance
## (FIELD_CAMERA, TWILIGHT 근사) on original-art fields. Touch, picking,
## minimap and culling read the camera transform, so they follow it.
func _apply_field_camera_zoom() -> void:
	var factor: float = FIELD_CAMERA.preference(ui_preferences) if field_camera_original_art else 1.0
	FIELD_CAMERA.set_applied(factor, get_tree())
	player.camera.zoom = Vector2.ONE * field_camera_base_zoom * factor

func field_camera_zoom() -> float:
	return FIELD_CAMERA.preference(ui_preferences)

## Live change from settings; `persist` writes the existing save once.
func set_field_camera_zoom(value: float, persist: bool = true) -> Error:
	var before: Variant = ui_preferences.get(FIELD_CAMERA.PREFERENCE_KEY)
	ui_preferences[FIELD_CAMERA.PREFERENCE_KEY] = FIELD_CAMERA.clamp_zoom(value)
	if field_map != null: _apply_field_camera_zoom()
	if not persist: return OK
	var result: Error = _save_game(true)
	if result != OK:
		if before == null: ui_preferences.erase(FIELD_CAMERA.PREFERENCE_KEY)
		else: ui_preferences[FIELD_CAMERA.PREFERENCE_KEY] = before
		if field_map != null: _apply_field_camera_zoom()
	return result

## validate_only: every ownership/namespace check of this payload, then OK
## without building or writing the file (a staged owner may adopt it and
## request the batched save; the next save writes it with everything else).
## background: a plain (no staged payload) save builds and checks its data in
## this frame, then a worker thread stages the account file, serialises and
## writes it atomically (temp file + rename); the next save, load, pause or
## quit waits for it. The file is always either the previous or the new
## complete save. Transactions (staged payloads) still write before returning.
func _save_game(quiet: bool, collection_override: Dictionary = {}, movement_override: Dictionary = {}, validate_only: bool = false, background: bool = false) -> Error:
	var want_background: bool = background or _background_from_outer
	_background_from_outer = false
	if background_save_pending():
		var wait_started: int = FRAME_HITCH.now()
		_finish_background_save(true)
		FRAME_HITCH.detail("save.wait", wait_started)
	# Stage times for the phone record (523.655: save 286 ms/s without a split).
	var save_stage_usec: int = FRAME_HITCH.now()
	if equipment523.save_blocked: return ERR_UNAVAILABLE
	if unconfirmed523.save_blocked or not unconfirmed523.validate(collection_override.get("unconfirmed523",unconfirmed523.state)).is_empty():return ERR_INVALID_DATA
	if CURRENT523_ADEN_REVIEW.requested() or current523_aden_review_active: return ERR_UNAVAILABLE
	if current523_aden_play_active and _current523_aden_play_controller != null and bool(_current523_aden_play_controller.get("source_owned")) and not bool(_current523_aden_play_controller.get("saving_prior_snapshot")):
		# Native source cursors cannot authorize the host auto-movement save override.
		if not movement_override.is_empty(): return ERR_UNAVAILABLE
		# A check-only call writes nothing, so it needs no source-map snapshot swap.
		if not validate_only:
			_background_from_outer = want_background
			var delegated: Error = _current523_aden_play_controller.call("save_source_progress",quiet,collection_override)
			_background_from_outer = false
			return delegated
	if death_recovery.save_blocked or (not death_recovery.pending.is_empty() and not collection_override.has(death_recovery.KEY)): return ERR_UNAVAILABLE
	var death_state: Dictionary = collection_override.get(death_recovery.KEY,death_recovery.export_state())
	if not death_recovery.validate(death_state,collection_override.get("item_instances",item_instances)).is_empty(): return ERR_INVALID_DATA
	save_stage_usec = FRAME_HITCH.detail_next("save.check_death", save_stage_usec)
	if dungeon_play.save_blocked or not dungeon_play.valid(collection_override.get("source_dungeon_play",dungeon_play.state)).is_empty():return ERR_INVALID_DATA
	if source_dungeon_runs.save_blocked or not source_dungeon_runs.validate(collection_override.get("source_dungeon523",source_dungeon_runs.state)).is_empty(): return ERR_INVALID_DATA
	if titles.blocked or not titles.validate(collection_override.get("title523",titles.state)).is_empty(): return ERR_INVALID_DATA
	save_stage_usec = FRAME_HITCH.detail_next("save.check_dungeon_titles", save_stage_usec)
	if totem_combat.settings_blocked or not totem_combat.check_settings_load({"ui_preferences":ui_preferences}).is_empty():return ERR_INVALID_DATA
	if collection_override.has("totem_combat_settings") and not totem_combat.valid_settings(collection_override.totem_combat_settings):return ERR_INVALID_DATA
	if collection_override.has("totem_state") and not totems.check_state(collection_override.totem_state).is_empty(): return ERR_INVALID_DATA
	if totems.save_blocked or not totems.check_state(totems.export_state()).is_empty():
		if not quiet: hud.show_message("토템 저장 보호 중 · 정상 저장을 다시 불러오세요")
		return ERR_UNAVAILABLE
	save_stage_usec = FRAME_HITCH.detail_next("save.check_totems", save_stage_usec)
	if monsterbook523_runtime.save_blocked: return ERR_FILE_CORRUPT
	if collection_override.has("monsterbook523") and not monsterbook523.valid_state(collection_override.monsterbook523): return ERR_INVALID_DATA
	if tj_coupons.core.blocked or not tj_coupons.core.validate(tj_coupons.core.export_state()).is_empty():return ERR_FILE_CORRUPT
	if collection_override.has("tj_coupons523") and not tj_coupons.core.validate(collection_override.tj_coupons523).is_empty():return ERR_INVALID_DATA
	if protection523.save_blocked:
		if not quiet: hud.show_message("가호 저장 보호 중 · 정상 저장을 다시 불러오세요")
		return ERR_UNAVAILABLE
	if not PROTECTION523.validate((collection_override["protection523"] if collection_override.has("protection523") else protection523.snapshot())).is_empty(): return ERR_INVALID_DATA
	save_stage_usec = FRAME_HITCH.detail_next("save.check_book_coupon_protection", save_stage_usec)
	if source_shop.save_blocked or not source_shop.check_load({SOURCE_SHOP.SAVE_KEY:(collection_override[SOURCE_SHOP.SAVE_KEY] if collection_override.has(SOURCE_SHOP.SAVE_KEY) else source_shop.export_state())}).is_empty(): return ERR_INVALID_DATA
	save_stage_usec = FRAME_HITCH.detail_next("save.check_shop", save_stage_usec)
	if not patch523_owner_state_problem.is_empty():return ERR_UNAVAILABLE
	var owner_boundary=preload("res://scripts/crafting/patch523_owner_transactions.gd")
	if protection523!=null and protection523.get("save_blocked")==true:return ERR_UNAVAILABLE
	if expedition_local!=null and expedition_local.get("save_blocked")==true:return ERR_UNAVAILABLE
	if quest_auto!=null and quest_service.get("save_blocked")==true:return ERR_UNAVAILABLE
	var owner_error: String=owner_boundary.override_error(self,collection_override)
	save_stage_usec = FRAME_HITCH.detail_next("save.check_owner", save_stage_usec)
	if owner_error.is_empty():owner_error=preload("res://scripts/loot/current523_native_stack.gd").override_error(self,collection_override)
	save_stage_usec = FRAME_HITCH.detail_next("save.check_native_stack", save_stage_usec)
	if not owner_error.is_empty():
		if not quiet:hud.show_message(owner_error)
		return ERR_INVALID_DATA
	if quest_service.save_blocked:return ERR_UNAVAILABLE
	if collection_override.has("quest_state") and not QUEST_SERVICE.validate_saved_state(collection_override.quest_state).is_empty():return ERR_INVALID_DATA
	if BASE508_TEST.enabled():return ERR_UNAVAILABLE
	if collection_override.has("inventory_automation") and not INVENTORY_AUTOMATION.valid(collection_override.inventory_automation): return ERR_INVALID_DATA
	if halphas_star.save_blocked:return ERR_UNAVAILABLE
	if collection_override.has(HALPHAS_STAR.SAVE_KEY) and not halphas_star.check_load(collection_override).is_empty():return ERR_INVALID_DATA
	if not movement_override.is_empty():
		if not auto_hunting_move_in_progress or not pending_map_save_record.is_empty(): return ERR_UNAVAILABLE
		var current: Dictionary = auto_hunting_movement_assessment(int(movement_override.get("schedule_id", -1)), int(movement_override.get("landing_link_id", -1)))
		if not bool(current.ok) or current != movement_override: return ERR_UNAVAILABLE
		if collection_override != AUTO_HUNTING_LOCAL.cost_override(self, current): return ERR_INVALID_PARAMETER
	if collection_override.has("weapon_mastery523") and (not weapon_mastery.enabled or not weapon_mastery.core.validate_state(collection_override.weapon_mastery523).is_empty()): return ERR_INVALID_DATA
	if growth96.save_blocked: return ERR_FILE_CORRUPT
	if collection_override.has("growth96") and not growth96.validate(collection_override.growth96).is_empty(): return ERR_INVALID_DATA
	if combinations.save_blocked:return ERR_UNAVAILABLE
	if collection_override.has("combination523") and not combinations.check_load(collection_override).is_empty():return ERR_INVALID_DATA
	if half_elixir.save_blocked or not half_elixir.validate(collection_override.get("half_elixir523", half_elixir.state)).is_empty(): return ERR_INVALID_DATA
	if spell_group_conversion.save_blocked:
		if not quiet:hud.show_message("계열 전환 저장 손상 · 기존 파일을 보존합니다. 정상 백업을 불러오세요.")
		return ERR_FILE_CORRUPT
	if collection_override.has("spell_group_conversion") and not spell_group_conversion.validate(collection_override.spell_group_conversion).is_empty():return ERR_INVALID_DATA
	if source_item_save_blocked:
		if not quiet: hud.show_message("전체 원본 아이템 팩 확인 필요 · 기존 저장 보존")
		return ERR_UNAVAILABLE
	FRAME_HITCH.detail("save.check", save_stage_usec)
	save_stage_usec = FRAME_HITCH.now()
	var source_backup_error: Error = _prepare_patch523_item_save_backup()
	if source_backup_error != OK:
		source_item_save_blocked = true
		hud.show_message("전체 원본 아이템 이전 백업 실패 · 기존 저장 보존")
		return source_backup_error
	if expedition_local.save_blocked or not expedition_local.validate((collection_override[EXPEDITION_LOCAL.KEY] if collection_override.has(EXPEDITION_LOCAL.KEY) else expedition_local.export_state())).is_empty():return ERR_INVALID_DATA
	if not expedition_local.before_save(): return ERR_CANT_CREATE
	if collection_override.has("card_skill_awakening") and not skill_awakening.check_load({"card_skill_awakening":collection_override.card_skill_awakening}).is_empty():return ERR_INVALID_DATA
	if collection_override.has("quest_state"):
		if not quest_service.has_method("validate_saved_state") or not str(quest_service.call("validate_saved_state",collection_override.quest_state)).is_empty(): return ERR_INVALID_DATA
	if not migration_pointer_error.is_empty():
		if not quiet:hud.show_message("이전된 저장 파일 확인 실패 · 원본 저장 보존 중")
		return ERR_FILE_CORRUPT
	if skill_awakening.blocks_save():
		if not quiet:hud.show_message("스킬 각성 저장 보호 중 · 원본 저장 보존")
		return ERR_UNAVAILABLE
	if option_awakening.save_blocked or not option_awakening.problem.is_empty():
		if not quiet: hud.show_message("각성 저장 보호 중 · 정상 저장을 다시 불러오세요")
		return ERR_UNAVAILABLE
	if equipment_collections.save_blocked:
		if not quiet: hud.show_message("컬렉션 저장 보호 중 · 정상 저장을 다시 불러오세요")
		return ERR_UNAVAILABLE
	if collection_override.has("equipped_ammo") and not collection_override.equipped_ammo is String: return ERR_INVALID_PARAMETER
	if collection_override.has(ITEM_BOOK523.SAVE_KEY) and (item_book523.preserved_raw != null or not ITEM_BOOK523.validate(collection_override[ITEM_BOOK523.SAVE_KEY]).is_empty()): return ERR_INVALID_DATA
	if collection_override.has(ROUTINE523.SAVE_KEY) and (routines.save_blocked or not ROUTINE523.validate(collection_override[ROUTINE523.SAVE_KEY]).is_empty()): return ERR_INVALID_DATA
	if collection_override.has("ammo_unequipped") and not collection_override.ammo_unequipped is bool: return ERR_INVALID_PARAMETER
	if collection_override.has("equipped_items") and not quest_item_provider.equipment_owner.authorizes_save(collection_override):return ERR_INVALID_PARAMETER
	for key: String in collection_override:
		if key=="patch523_transaction_rng":
			if not (alchemy_held_items.authorizes(collection_override) or quest_item_provider.authorizes_held_save(collection_override) or preload("res://scripts/loot/current523_native_stack.gd").authorizes(collection_override)) or not owner_boundary.rng_error(collection_override[key]).is_empty():return ERR_INVALID_PARAMETER
			continue
		if key not in ["inventory","item_instances","equipment_collections","gold","card_draw_fusion","card_option_awakening","card_skill_awakening","growth","source_dungeon523","ainhasad_state","experience","source_dungeon_play","hp","mp","warehouse","inventory_automation","halphas_star_enchant","source_visual_context","death_recovery523","level","exp_need","max_hp","max_mp","attack","defense","stat_points","weapon_mastery523","growth96","combination523","half_elixir523","spell_group_conversion","original_skill_state","title523","totem_state","totem_combat_settings","monsterbook523","ground_drops","tj_coupons523","next_item_instance_id","equipped_items","patch523_crafting_usage","protection523","unconfirmed523","quest_state",EXPEDITION_LOCAL.KEY,"crafting_log",SOURCE_SHOP.SAVE_KEY,"active_item_buffs","item_use_cooldowns","consumable_state","equipped_ammo","ammo_unequipped","equipped_catalog",ROUTINE523.SAVE_KEY,DUNGEON_EXTRAS523.SAVE_KEY,ITEM_BOOK523.SAVE_KEY]: return ERR_INVALID_PARAMETER
	if collection_override.has("source_visual_context"):
		var visual: Variant=collection_override.source_visual_context
		if not visual is Dictionary or visual.get("snapshot")!="base508" or visual.get("gender_id")!=source_gender_id or not visual.get("active_card_options") is Dictionary:return ERR_INVALID_DATA
		var expected: Dictionary=source_card_visual_options.duplicate(true)
		var desired: Variant=visual.active_card_options.get("m508:1:24504",0)
		var earned: int=int(collection_override.get(HALPHAS_STAR.SAVE_KEY,halphas_star.progress).get("level",0))
		var allowed: bool=false
		for option: Dictionary in preload("res://scripts/cards/native_halphas_star_enchant.gd").DATA.data.sprite_options:
			if desired==option.ID and int(option.StarEnchant)<=earned:allowed=true
		if not allowed:return ERR_INVALID_DATA
		expected["m508:1:24504"]=desired
		if expected!=visual.active_card_options:return ERR_INVALID_DATA
	var peer_shop:Variant=EXPEDITION_LOCAL.REWARD_BRIDGE.shop(self)
	if collection_override.has("source_shop") and peer_shop==null:return ERR_INVALID_PARAMETER
	if "--png-review" in OS.get_cmdline_user_args():
		if not quiet: hud.show_message("PNG 검수 중에는 기존 저장을 덮어쓰지 않습니다")
		return ERR_UNAVAILABLE
	if source_save_blocked:
		if not quiet: hud.show_message("원본 맵 팩이 없어 기존 저장을 보존합니다. 팩 설치 후 다시 불러오세요")
		return ERR_UNAVAILABLE
	if validate_only: return OK
	# Transactions supply validated staged state. Commit it before mutating live resources.
	if collection_override.is_empty(): _sync_item_instances()
	# Preserve exporter order. Capture only audited, independently owned roots.
	var owned_save_fields: Dictionary = {}
	var data: Dictionary = {
		"unconfirmed523":unconfirmed523.snapshot(),
		# The staged dungeon candidate already captured actors' HP/MP; it is
		# still detached by staged_overrides below. Do not rebuild the live copy.
		"source_dungeon_play":{} if collection_override.has("source_dungeon_play") else dungeon_play.snapshot(),
		"source_dungeon523": source_dungeon_runs.state.duplicate(true),
		"map_id": active_map_id,
		"map_layout_revision": int(field_map.data.get("layout_revision", 0)) if field_map != null else 0,
		"position": [player.global_position.x, player.global_position.y],
		"level": level,
		"experience": experience,
		"exp_need": exp_need,
		"experience_progression_version": EXP_PROGRESSION.CURVE_VERSION,
		"death_recovery523": death_state,
		"hp": hp,
		"max_hp": max_hp,
		"mp": mp,
		"max_mp": max_mp,
		"hp_recovery_elapsed": hp_recovery_elapsed,
		"mp_recovery_elapsed": mp_recovery_elapsed,
		"source_item_regen_elapsed": source_item_regen_elapsed,
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
		"source_item_catalog": LOOT_DROP.PATCH523_DROPS.pack_identity(),
		SOURCE_SHOP.SAVE_KEY: source_shop.export_state(),
		"quest_state": SAVE_SNAPSHOT.capture(owned_save_fields,"quest_state",quest_service.export_state()),
		"monsterbook523": SAVE_SNAPSHOT.capture(owned_save_fields,"monsterbook523",monsterbook523.export_state()),
		"tj_coupons523": tj_coupons.core.export_state(),
		"protection523": protection523.snapshot(),
		"equipment_collections": SAVE_SNAPSHOT.capture(owned_save_fields,"equipment_collections",equipment_collections.export_state()),
		"totem_state": totems.export_state(),
		"growth": growth.state.duplicate(true),
		"growth96": growth96.state.duplicate(true),
		"half_elixir523": half_elixir.state.duplicate(true),
		DOMINATION_STONES.SAVE_KEY: domination_stones.export_state(),
		ROUTINE523.SAVE_KEY: routines.export_state(),
		EMBLEM523.SAVE_KEY: emblem523.export_state(),
		CLAN523.SAVE_KEY: clan523.export_state(),
		CONTENT523.SAVE_KEY: content523.export_state(),
		CARD_SWAP523.SAVE_KEY: card_swap523.export_state(),
		ITEM_LIFE523.SAVE_KEY: item_life523.export_state(),
		ITEM_BOOK523.SAVE_KEY: item_book523.export_state(),
		ITEM_INVOKE523.SAVE_KEY: item_invoke523.export_state(),
		DUNGEON_EXTRAS523.SAVE_KEY: dungeon_extras523.export_state(),
		SKILL_CARD523.SAVE_KEY: skill_cards523.export_state(),
		"ground_drops": _ground_drops_snapshot(),
		"warehouse": SAVE_SNAPSHOT.capture(owned_save_fields,"warehouse",warehouse.snapshot()),
		"inventory_automation": inventory_automation.state.duplicate(true),
		"crafting_log": crafting_log,
		"patch523_crafting_usage":patch523_crafting_usage,
		"monster_world": legacy_population.export_state(),
		"original_monster_world": original_population.export_state(),
		"original_position": SOURCE_TRAVEL.snapshot(self),
		"character_source_cursor":character_source_cursor.duplicate(true),
		OLD_MAP_RELOCATION523.KEY:old_map_relocation523.duplicate(true),
		TUTORIAL523.KEY:tutorial523.duplicate(true),
		"class_index": class_index,
		"job_class": job_class,
		"source_visual_context": {"snapshot":"base508","gender_id":source_gender_id,"active_card_options":source_card_visual_options.duplicate(true)},
		"quickslots": quickslots,
		"ui_preferences": ui_preferences,
		"self_mode_enabled": self_mode_enabled,
		"active_skill_buffs": active_skill_buffs,
		"skill_cooldowns": skill_cooldowns,
		"skill_global_cooldown": skill_global_cooldown,
		"spell_group_conversion": spell_group_conversion.export_state(),
		"original_skill_state": original_skills.catalog.export_state() if original_skills != null else {},
		"original_combat_state": original_skills.export_state() if original_skills != null else {},
		"active_item_buffs": active_item_buffs,
		"item_use_cooldowns": item_use_cooldowns,
		# A staged transaction already supplied and validated its replacement
		# journal. The staged merge below detaches it; don't export the old
		# live ledger just to discard that copy.
		"consumable_state": {} if collection_override.has("consumable_state") else SAVE_SNAPSHOT.capture(owned_save_fields,"consumable_state",consumable_service.call("export_state")),
		"ainhasad_state": ain_service.export_state(),
		"equipped_catalog": equipped_catalog,
		"combination523":combinations.export_state(),
		"card_draw_fusion": card_draw_fusion.export_state(),
		"card_collection_policy":card_collections.export_policy(),
		"card_option_awakening": option_awakening.export_state(),
		"card_skill_awakening": skill_awakening.export_state(),
		"halphas_star_enchant": halphas_star.export_state(),
		"title523": titles.state.duplicate(true),

		"equipment523_set_effects": equipment523.export_state(self),
		"equipped_items": equipped_items,
		"equipped_ammo": equipped_ammo,
		"ammo_unequipped": ammo_unequipped,
		"enhancement_levels": enhancement_levels,
		"item_instances": item_instances,
		"next_item_instance_id":next_item_instance_id,
		"legacy_item_migration523": legacy_item_marker,
		"equip_group_limit523": equip_group_marker
	}
	if field_map is NativePngField:
		data["native_png_plan_sha256"] = NATIVE_PNG.plan_hash(active_map_id)
		data["native_png_review_sha256"] = NATIVE_PNG.review_hash(active_map_id)
	if field_map is RemakePlayableField and field_map.png_game_pack!=null and not bool(field_map.get_meta("source_map84",false)):
		data["oman_png_index_sha256"]=FileAccess.get_sha256(SOURCE_PNG_GAME.root_path()+"/index.json")
	if expedition_local.namespace_present:
		data[EXPEDITION_LOCAL.KEY] = expedition_local.export_state()
	if peer_shop!=null:
		var peer_state:Dictionary=collection_override.get("source_shop",peer_shop.export_state())
		if not peer_shop.validate(peer_state).is_empty():return ERR_UNAVAILABLE
		if FileAccess.file_exists(save_path()):
			# prepare_load only acts on a save that has no shop state yet. A file
			# whose SHA-256 is the one this session last wrote with that state
			# already has it: skip re-reading and parsing the whole previous
			# save on every write (the largest single part of a phone save).
			if preload("res://scripts/save/previous_save_check.gd").needs_reading(save_path(),_shop_key_saved_sha):
				previous_save_parses+=1
				var previous:Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path()))
				if not previous is Dictionary or not peer_shop.prepare_load(previous,save_path(),FileAccess.get_sha256(save_path())).is_empty():return ERR_UNAVAILABLE
		data["source_shop"]=peer_state.duplicate(true)
	data["source_map84_layouts"]=SOURCE_MAP84.saved_layouts()
	data["source_map84_doors"]=SOURCE_MAP84.saved_doors(field_map)
	if not movement_override.is_empty(): data.merge(AUTO_HUNTING_LOCAL.save_fields(self, movement_override), true)
	var source_map_error: String=SOURCE_MAP84.validate_save(data,field_map)
	if not source_map_error.is_empty():
		if not quiet:hud.show_message(source_map_error)
		return ERR_UNAVAILABLE
	data.merge(weapon_mastery.save_fields(),true)
	data["patch523_transaction_rng"]={"schema":1,"seed":str(rng.seed),"state":str(rng.state)}
	if expedition_local!=null:
		var expedition_state: Dictionary=expedition_local.call("export_state")
		if not owner_boundary.expedition_error(self,expedition_state).is_empty():return ERR_INVALID_DATA
		data["expedition523_local"]=expedition_state
	if protection523!=null and protection523.has_method("snapshot"):
		var protection_state: Variant=protection523.call("snapshot")
		if not owner_boundary.protection_error(self,protection_state).is_empty():return ERR_INVALID_DATA
		data["protection523"]=protection_state
	data.merge(equipment_collections.extra_save_fields, false)
	data.erase("source_item_catalog_history") # retired history, also not carried as an unknown field
	var staged_overrides := collection_override.duplicate(true)
	if staged_overrides.has("totem_combat_settings"):
		data.ui_preferences = ui_preferences.duplicate(true)
		data.ui_preferences["totem_combat_settings"] = staged_overrides.totem_combat_settings
		staged_overrides.erase("totem_combat_settings")
	data.merge(staged_overrides, true)
	var observed_content: Dictionary = unconfirmed523.observe_staged_owner(collection_override)
	if not bool(observed_content.get("ok",false)): return ERR_INVALID_DATA
	if observed_content.has("state"):
		data["unconfirmed523"] = observed_content.state
	# Live-event replay keys are session-only (unconfirmed523/runtime.gd).
	data["unconfirmed523"] = UNCONFIRMED523.saved_form(data.get("unconfirmed523"))
	FRAME_HITCH.detail("save.snapshot", save_stage_usec)
	save_stage_usec = FRAME_HITCH.now()
	var save_started_usec: int = Time.get_ticks_usec()
	data = SAVE_TRIM.for_file(data)
	# write_save() refuses any file whose SHA-256 is not the one it last wrote
	# (external change -> save_blocked), so when this path is that file its
	# recorded hash is the file's hash: no extra full read and hash per save.
	var prior_owner_hash: String=""
	if str(equipment_collections.get("_disk_path"))==save_path() and not str(equipment_collections.get("_disk_hash")).is_empty():
		prior_owner_hash=str(equipment_collections.get("_disk_hash"))
	elif FileAccess.file_exists(save_path()):
		prior_owner_hash=FileAccess.get_sha256(save_path())
	if want_background and background_save_enabled and collection_override.is_empty() and movement_override.is_empty() and pending_map_save_record.is_empty() and not observed_content.has("state") and not equipment_collections.test_save_writer.is_valid():
		return _start_background_save(data, prior_owner_hash, save_started_usec, owned_save_fields)
	var checkpoint_only: bool=collection_override.size()==1 and collection_override.has("source_dungeon_play")
	var account_stage: Dictionary = CHARACTER_ACCOUNT.stage_checkpoint_write(save_path(),data) if checkpoint_only else CHARACTER_ACCOUNT.stage_save(save_path(),data)
	if not account_stage.ok:
		if not quiet: hud.show_message(str(account_stage.problem))
		return ERR_INVALID_DATA
	data = account_stage.payload
	var written_envelope: Variant = account_stage.envelope if checkpoint_only else data.get(CHARACTER_ACCOUNT.KEY)
	# The synchronous checkpoint stage already returns its compact file view.
	if not checkpoint_only: data = CHARACTER_ACCOUNT.compact(data)
	FRAME_HITCH.detail("save.account", save_stage_usec)
	save_stage_usec = FRAME_HITCH.now()
	CHARACTER_ACCOUNT.forget_durable()
	# Dungeon-only writes (periodic checkpoint, time exhaustion or stop) stage
	# a new ledger revision. Don't hash and retain a second full typed save
	# just for the fast path used by repeated identical saves.
	var retain_typed_snapshot: bool=not checkpoint_only
	var result: Error = equipment_collections.write_save(save_path(), data, retain_typed_snapshot)
	if result==OK and written_envelope is Dictionary:
		CHARACTER_ACCOUNT.remember_verified_durable(save_path(),written_envelope,equipment_collections.verified_payload_sha(save_path()))
	FRAME_HITCH.detail("save.write", save_stage_usec)
	if result!=OK and not equipment_collections.save_blocked and equipment_collections.problem.is_empty():
		if owner_boundary.committed(self,save_path(),data):
			result=OK
			hud.append_log("원본 거래 · 저장 응답 오류 뒤 전체 영수증/상태 일치 확인")
		elif FileAccess.file_exists(save_path()) and FileAccess.get_sha256(save_path())!=prior_owner_hash:
			patch523_owner_state_problem="원본 거래 저장 결과 확인 필요 · 다시 불러오기 전 소모/지급 중지"
	_perf_log("저장", save_started_usec)
	if result == OK and data.has(SOURCE_SHOP.SAVE_KEY) and str(equipment_collections.get("_disk_path"))==save_path():
		_shop_key_saved_sha=str(equipment_collections.get("_disk_hash"))
	elif result != OK:
		_shop_key_saved_sha=""
	if result != OK:
		hud.append_log("저장 실패 · 이전 저장 파일 보존 · 오류 %d" % result)
		if not quiet: hud.show_message("저장 실패")
		return result
	if not CHARACTER_ACCOUNT.session.is_empty() and CHARACTER_ACCOUNT.session.get("path")==save_path(): CHARACTER_ACCOUNT.session["initialized"]=true
	for key: String in ["protection523","expedition523_local","patch523_transaction_rng"]:
		if data.has(key):equipment_collections.extra_save_fields[key]=data[key].duplicate(true)
	if not pending_map_save_record.is_empty():
		var pointer_result: Error=MAP_SAVE_MIGRATION.activate(base_save_path(),pending_map_save_record)
		if pointer_result!=OK:
			patch523_owner_state_problem="전체 저장 후 활성 경로 기록 미확정 · 정상 저장을 다시 불러오기 전 거래 중지"
			hud.append_log("이전 저장 선택 기록 실패 · 원본과 별도 저장 후보를 보존합니다")
			return pointer_result
		pending_map_save_record.clear()
	if observed_content.has("state"):
		unconfirmed523.state = observed_content.state.duplicate(true)
	# This save already holds every earlier change, so a queued one is redundant.
	# A failed deferred write is not re-queued here; the 60 s general autosave in
	# _process keeps retrying, and pause/quit still attempt a final save.
	if collection_override.is_empty(): deferred_save.cancel()
	if not quiet:
		hud.show_message("저장 완료")
	return OK

func _load_game(quiet: bool) -> void:
	_enhancement_token_quotes.clear()
	_finish_background_save(true)
	if CURRENT523_ADEN_REVIEW.requested() or current523_aden_review_active: return
	if BASE508_TEST.enabled():return
	if not migration_pointer_error.is_empty():migration_path_checked=false
	save_path()
	if not migration_pointer_error.is_empty():
		source_save_blocked=true;hud.show_message("이전된 저장 파일 누락·손상 · 원본 저장을 보존합니다");return
	if not FileAccess.file_exists(save_path()):
		if not quiet:
			hud.show_message("저장 데이터가 없습니다")
		return
	# JSON.parse_string() emits an engine ERROR on invalid saves even if handled.
	# The explicit parser returns an error code, so damaged local saves can be
	# rejected without corrupting the current session or failing a smoke test.
	var save_parser: JSON = JSON.new()
	var original_save_bytes: PackedByteArray=FileAccess.get_file_as_bytes(save_path())
	var loaded_save_file: String=save_path()
	var save_hash_context:=HashingContext.new()
	save_hash_context.start(HashingContext.HASH_SHA256);save_hash_context.update(original_save_bytes)
	var loaded_save_sha: String=save_hash_context.finish().hex_encode()
	var parse_error: Error = save_parser.parse(original_save_bytes.get_string_from_utf8())
	if parse_error != OK:
		equipment_collections.save_blocked = true
		if not quiet:
			hud.show_message("저장 데이터가 손상되었습니다")
			hud.append_log("저장 데이터 JSON 해석 실패")
		return
	var value: Variant = save_parser.data
	if not (value is Dictionary):
		equipment_collections.save_blocked = true
		if not quiet:
			hud.show_message("저장 데이터가 손상되었습니다")
		hud.append_log("저장 데이터 JSON 해석 실패")
		return
	CHARACTER_ACCOUNT.expand(value)
	var account_error: String = CHARACTER_ACCOUNT.validate(value)
	if not account_error.is_empty():
		source_save_blocked=true
		hud.show_message(account_error)
		return
	if value.has(CHARACTER_ACCOUNT.KEY):
		if value[CHARACTER_ACCOUNT.KEY].get("schema") == CHARACTER_ACCOUNT.LEGACY_SCHEMA:
			source_save_blocked=true; hud.show_message("기존 계정을 캐릭터 선택에서 백업 후 이전해 주세요."); return
		var selected: Dictionary=CHARACTER_ACCOUNT.selected_record(value)
		character_display_name = str(selected.get("name","황혼의 기사"))
		if CHARACTER_ACCOUNT.session.is_empty(): CHARACTER_ACCOUNT.session={"path":save_path(),"id":selected.id,"initialized":selected.initialized}
		if CHARACTER_ACCOUNT.session.get("path")!=save_path() or CHARACTER_ACCOUNT.session.get("id")!=selected.id:
			source_save_blocked=true; hud.show_message("선택 캐릭터가 변경되었습니다. 로비에서 다시 접속하세요."); return
	preload("res://scripts/resources/current523_definition_rows.gd").normalize_loaded_save(value)
	# Older saves: drop acquisition history no rule reads (drop proofs, receipt
	# row copies, per-floor pickup receipts). Owned state is unchanged.
	SAVE_TRIM.loaded_save(value)
	preload("res://scripts/loot/current523_native_stack.gd").clear_proof_cache()
	# The validated file just read: the next save needs no second parse of it.
	if value.has(CHARACTER_ACCOUNT.KEY) and loaded_save_sha==FileAccess.get_sha256(save_path()): CHARACTER_ACCOUNT.remember_durable(save_path(), value[CHARACTER_ACCOUNT.KEY])
	character_dormant_physical = CHARACTER_ACCOUNT.dormant_items(value)
	var data: Dictionary = value as Dictionary
	var extra_error: String=unconfirmed523.check_load(data)
	if not extra_error.is_empty():
		unconfirmed523.save_blocked=true;unconfirmed523.problem=extra_error;hud.show_message(extra_error);return
	var quest_owner_error: String = equipment523.check_quest_load(self,data.get("quest_state",{}))
	if not quest_owner_error.is_empty():
		source_save_blocked = true
		equipment523.save_blocked = true
		equipment523.problem = quest_owner_error
		hud.show_message(quest_owner_error)
		return
	var equipment523_error: String = equipment523.check_load(data.get("equipment523_set_effects",{}))
	if not equipment523_error.is_empty():
		source_save_blocked = true
		equipment523.save_blocked = true
		equipment523.problem = equipment523_error
		hud.show_message(equipment523_error)
		return
	var play_error: String=dungeon_play.valid(data.get("source_dungeon_play",DUNGEON_PLAY.empty_state()))
	if not play_error.is_empty():
		dungeon_play.save_blocked=true;dungeon_play.problem=play_error;source_save_blocked=true;hud.show_message(play_error);return
	var dungeon_error: String = source_dungeon_runs.validate(data.get("source_dungeon523",DUNGEON_RUNS.empty_state()))
	if not dungeon_error.is_empty():
		source_dungeon_runs.save_blocked=true; source_dungeon_runs.problem=dungeon_error
		source_save_blocked=true; hud.show_message(dungeon_error); return
	var death_problem: String = death_recovery.check_load(data)
	if not death_problem.is_empty():
		death_recovery.save_blocked = true; hud.show_message(death_problem); return
	var mastery_error: String = weapon_mastery.check_load(data)
	if not mastery_error.is_empty():
		equipment_collections.save_blocked = true
		hud.show_message(mastery_error)
		return
	var growth96_error: String = growth96.check_load(data)
	if not growth96_error.is_empty():
		hud.show_message(growth96_error)
		return
	var combination_error: String=combinations.check_load(data)
	if not combination_error.is_empty():
		combinations.save_blocked=true;hud.show_message(combination_error);return
	var half_error: String = half_elixir.validate(data.get("half_elixir523", HALF_ELIXIR.fresh()))
	if not half_error.is_empty():
		half_elixir.save_blocked = true
		hud.show_message(half_error)
		return
	var group_error:String=spell_group_conversion.validate(data.get("spell_group_conversion", {"schema":1,"source_snapshot":"patch523","classes":{}}))
	if not group_error.is_empty():
		spell_group_conversion.save_blocked=true;hud.show_message(group_error);return
	var title_error: String=titles.check_load(data)
	if not title_error.is_empty():
		titles.blocked=true
		hud.show_message(title_error)
		return
	var regional_error: String = REGIONAL_RETURN.validate_save(data)
	if not regional_error.is_empty():
		source_save_blocked = true
		hud.show_message(regional_error)
		return
	var totem_settings_error: String = totem_combat.check_settings_load(data)
	if not totem_settings_error.is_empty():
		totem_combat.settings_blocked = true
		hud.show_message(totem_settings_error)
		return
	var totem_error := totems.check_state(data.get("totem_state"))
	if not totem_error.is_empty():
		totems.save_blocked = true
		hud.show_message(totem_error)
		return
	if not monsterbook523.valid_state(data.get("monsterbook523", {"schema":1,"books":{}})):
		monsterbook523_runtime.save_blocked = true
		hud.show_message("몬스터 도감 기록 손상 · 원본 저장을 보존합니다")
		return
	var protection_error: String = PROTECTION523.validate(data.get("protection523",PROTECTION523.fresh()))
	if not protection_error.is_empty():
		protection523.save_blocked = true
		hud.show_message(protection_error)
		return
	if not data.has("protection523"):
		var protection_backup: String = save_path()+".pre-protection523-"+loaded_save_sha
		if (not FileAccess.file_exists(protection_backup) and DirAccess.copy_absolute(save_path(),protection_backup)!=OK) or FileAccess.get_sha256(protection_backup)!=loaded_save_sha:
			protection523.save_blocked = true
			hud.show_message("가호 이전 백업 실패 · 기존 저장 보존")
			return
	var saved_items: Dictionary = data.get("source_item_catalog",{}) if data.get("source_item_catalog",{}) is Dictionary else {}
	var current_items: Dictionary = LOOT_DROP.PATCH523_DROPS.pack_identity()
	var old_history: Variant=data.get("source_item_catalog_history",[])
	if not old_history is Array:
		source_item_save_blocked=true;hud.show_message("기존 원본 정의 출처 이력 형식 확인 필요 · 저장 보존");return
	# Earlier definition-pack identities were only kept as history; no rule
	# reads them, so they are no longer carried (save_journal_trim_test).
	source_item_catalog_history=[]
	if int(saved_items.get("schema",0)) in [3,4] and current_items.is_empty():
		source_item_save_blocked=true
		hud.show_message("새 원본523 아이템 입력이 없어 기존 저장을 보존합니다")
		return
	if int(saved_items.get("schema",0))==4 and (saved_items.get("kind")!="current523_original_definition_projection" or saved_items.get("source_definition_archive",{}).get("source_sha256")!=preload("res://scripts/resources/current523_definition_rows.gd").SOURCE_SHA):
		source_item_save_blocked=true;hud.show_message("기존 새 원문 아이템 출처 확인 필요 · 저장 보존");return
	if not current_items.is_empty() and _prepare_patch523_item_save_backup()!=OK:
		source_item_save_blocked=true
		hud.show_message("원본 아이템 입력 전환 백업 실패 · 기존 저장 보존")
		return
	source_item_save_blocked=false
	var source_shop_error: String = source_shop.check_load(data)
	if source_shop_error.is_empty(): source_shop_error = source_shop.prepare_load(data, save_path(), loaded_save_sha)
	if not source_shop_error.is_empty():
		source_shop.save_blocked = true
		hud.show_message(source_shop_error)
		return
	var expedition_error: String = expedition_local.check_load(data)
	if not expedition_error.is_empty():
		expedition_local.save_blocked = true
		hud.show_message(expedition_error)
		return
	var peer_shop:Variant=EXPEDITION_LOCAL.REWARD_BRIDGE.shop(self)
	if peer_shop!=null:
		var peer_error:String=peer_shop.check_load(data)
		if not peer_error.is_empty():peer_shop.save_blocked=true;hud.show_message(peer_error);return
	var owner_boundary=preload("res://scripts/crafting/patch523_owner_transactions.gd")
	var owner_error: String=owner_boundary.quest_error(self,data.get("quest_state",{}))
	if owner_error.is_empty() and data.has("patch523_transaction_rng"):owner_error=owner_boundary.rng_error(data.patch523_transaction_rng)
	if owner_error.is_empty():owner_error=preload("res://scripts/loot/current523_native_stack.gd").state_error(data.get("inventory",{}),data.get("item_instances",{}),data.get("consumable_state",{}),data.get("warehouse",{}),data.get("ground_drops",[]),character_dormant_physical)
	if owner_error.is_empty() and expedition_local!=null and data.has("expedition523_local"):owner_error=owner_boundary.expedition_error(self,data.expedition523_local)
	if owner_error.is_empty() and protection523!=null and data.has("protection523"):owner_error=owner_boundary.protection_error(self,data.protection523)
	if not owner_error.is_empty():
		patch523_owner_state_problem=owner_error
		hud.show_message(owner_error)
		return
	var quest_error: String = QUEST_SERVICE.validate_saved_state(data.get("quest_state",{}))
	if not quest_error.is_empty():
		quest_service.save_blocked = true
		hud.show_message(quest_error+" · 기존 저장 보존")
		return
	var map_migration: Dictionary=SOURCE_MAP84.prepare_migrations(data,loaded_save_sha)
	if not map_migration.ok:
		source_save_blocked=true;hud.show_message(str(map_migration.error));return
	data=map_migration.data
	if data.has(CHARACTER_ACCOUNT.KEY):
		# Spatial migrations transform the flat owner payload. Refresh its
		# selected snapshot and account allocator before staging another file.
		var sealed_account: Dictionary=CHARACTER_ACCOUNT.seal_payload(data)
		if not sealed_account.get("ok",false):
			source_save_blocked=true; hud.show_message(str(sealed_account.get("problem","계정 저장 이전 검증 실패"))); return
		data=sealed_account.payload
		character_dormant_physical=CHARACTER_ACCOUNT.dormant_items(data)
	# Validate every new-map player/drop coordinate before inventory, bosses or
	# outgoing actors are changed. Unknown layout revisions require migration.
	var map84_error: String=SOURCE_MAP84.validate_save(data)
	if not map84_error.is_empty():
		source_save_blocked=true
		hud.show_message(map84_error)
		return
	var tj_error: String = tj_coupons.core.validate(data.get("tj_coupons523",tj_coupons.core.empty_state()))
	if not tj_error.is_empty():
		tj_coupons.core.blocked=true
		tj_coupons.core.problem=tj_error
		hud.show_message(tj_error)
		return
	var growth_error: String = growth.validate(data.get("growth",growth.empty_state()))
	var halphas_error: String = halphas_star.check_load(data)
	if not halphas_error.is_empty():
		halphas_star.save_blocked=true;hud.show_message(halphas_error);return
	if not growth_error.is_empty():
		equipment_collections.save_blocked = true
		hud.show_message(growth_error)
		return
	if data.has("inventory_automation") and not INVENTORY_AUTOMATION.valid(data.inventory_automation):
		equipment_collections.save_blocked = true
		hud.show_message("자동 보관·판매 설정 손상 · 기존 저장 보존")
		return
	var collection_error: String = equipment_collections.check_load(data)
	if not collection_error.is_empty():
		equipment_collections.save_blocked = true
		hud.show_message(collection_error)
		return
	var skill_awakening_error: String=skill_awakening.check_load(data)
	if not skill_awakening_error.is_empty():
		skill_awakening.save_blocked=true
		hud.show_message(skill_awakening_error)
		return
	var awakening_error: String = option_awakening.check_load(data)
	if not awakening_error.is_empty():
		equipment_collections.save_blocked = true
		hud.show_message(awakening_error)
		return
	var saved_map_id: String = str(data.get("map_id", ""))
	if saved_map_id in ["albino_03","albino_04"]:
		var retirement_sha: String=FileAccess.get_sha256(save_path())
		var retirement_backup: String=save_path()+".pre-albino-retirement-"+retirement_sha
		if (not FileAccess.file_exists(retirement_backup) and DirAccess.copy_absolute(save_path(),retirement_backup)!=OK) or FileAccess.get_sha256(retirement_backup)!=retirement_sha:
			source_save_blocked=true
			hud.show_message("알비노 구역 이전 백업 실패: 기존 저장을 보존합니다")
			return
		data=data.duplicate(true)
		data["map_id"]="albino_02"
		data["position"]=[]
		data["map_layout_revision"]=-1
		data.erase("native_png_plan_sha256")
		data.erase("native_png_review_sha256")
		data.erase("original_position")
		saved_map_id="albino_02"
	if OLD_MAP_RELOCATION523.needed(data,CURRENT523_HOST.requested(),LEGACY_LAYOUT.active("--legacy-map-layouts")):
		# A save from before the 523 pack on an old map (only old base508
		# monsters there) is moved once to 523 Land 4 at the start village
		# (Giran town, 사용자 결정 2026-11-17); progression is kept
		# and the original file is kept byte for byte.
		var relocation_sha: String=FileAccess.get_sha256(save_path())
		var relocation_backup: String=save_path()+".pre-old-map-523-"+relocation_sha
		if (not FileAccess.file_exists(relocation_backup) and DirAccess.copy_absolute(save_path(),relocation_backup)!=OK) or FileAccess.get_sha256(relocation_backup)!=relocation_sha:
			source_save_blocked=true
			hud.show_message("523 아덴 이전 백업 실패: 기존 저장을 보존합니다")
			return
		data=OLD_MAP_RELOCATION523.relocated(data)
		saved_map_id=OLD_MAP_RELOCATION523.TARGET_MAP
		hud.append_log("옛 지도 저장을 523 기란 마을로 옮겼습니다 (원본 백업 보존)")
	if TUTORIAL523.needed(data):
		# 사용자 결정 2026-11-16: a character in a deleted tutorial Land moves to
		# the start village (Giran town) and tutorial items leave the save (amounts recorded); the
		# original file is backed up byte for byte first.
		var tutorial_sha: String=FileAccess.get_sha256(save_path())
		var tutorial_backup: String=save_path()+".pre-tutorial-523-"+tutorial_sha
		if (not FileAccess.file_exists(tutorial_backup) and DirAccess.copy_absolute(save_path(),tutorial_backup)!=OK) or FileAccess.get_sha256(tutorial_backup)!=tutorial_sha:
			source_save_blocked=true
			hud.show_message("튜토리얼 삭제 이전 백업 실패: 기존 저장을 보존합니다")
			return
		data=TUTORIAL523.migrate_save(data)
		hud.append_log("튜토리얼 삭제(사용자 결정 2026-11-16): 튜토리얼 위치·아이템을 정리했습니다 (원본 백업 보존)")
	var has_native_position: bool=data.has("native_png_plan_sha256")
	var requested_native: bool=NATIVE_PNG.supports(saved_map_id) and not SOURCE_MAP84.supports(saved_map_id)
	var explicit_legacy: bool=LEGACY_LAYOUT.active("--legacy-map-layouts") or (NATIVE_PNG.extra_map(saved_map_id) and LEGACY_LAYOUT.active("--legacy-aden-faith-layouts"))
	if has_native_position and explicit_legacy and not requested_native and maps_by_id.has(saved_map_id):
		# Explicitly returning to an existing layout retains progression while
		# discarding pixel coordinates that belong to the PNG canvas.
		data=data.duplicate(true)
		data.erase("native_png_plan_sha256");data.erase("native_png_review_sha256")
		data["position"]=[];data["map_layout_revision"]=-1
	elif has_native_position or requested_native:
		# Validate prospective PNG migrations too, before mutating character
		# state. A corrupt default pack must not overwrite an old ordinary save.
		var native_saved_field: PlayableField=NATIVE_PNG.load_field(NATIVE_PNG.canonical(saved_map_id)) if requested_native else null
		var saved_plan: String=str(data.get("native_png_plan_sha256",""))
		var plan_changed: bool=has_native_position and saved_plan!=NATIVE_PNG.plan_hash(NATIVE_PNG.canonical(saved_map_id))
		var migration: Dictionary=NATIVE_PNG_SAVE_MIGRATIONS.get(saved_plan,{})
		var known_native_upgrade: bool=(native_saved_field!=null and plan_changed and not migration.is_empty()
			and saved_map_id in migration.map_ids
			and int(data.get("map_layout_revision",-1))==int(migration.from_revision)
			and (int(native_saved_field.data.layout_revision)==int(migration.to_revision)
				or (saved_map_id in ["aden_world","faith_01","faith_02","faith_03","faith_04"] and int(migration.to_revision)==2026102002 and int(native_saved_field.data.layout_revision)==(preload("res://scripts/maps/png_world_scale.gd").ADEN_REVISION if saved_map_id=="aden_world" else preload("res://scripts/maps/png_world_scale.gd").FAITH_REVISION)))
			and str(data.get("native_png_review_sha256",""))==saved_plan)
		if native_saved_field==null or (plan_changed and not known_native_upgrade):
			source_save_blocked=true
			hud.show_message("PNG 팩 누락·변경: 저장 파일을 보존합니다")
			return
		if known_native_upgrade:
			# Keep every distinct original byte-for-byte, including later imports
			# of another old character. Loading alone never rewrites the save.
			var original_hash: String=FileAccess.get_sha256(save_path())
			var backup_path: String=save_path()+".pre-aden-faith-population-"+original_hash
			if (not FileAccess.file_exists(backup_path) and DirAccess.copy_absolute(save_path(),backup_path)!=OK) or FileAccess.get_sha256(backup_path)!=original_hash:
				source_save_blocked=true
				hud.show_message("이전 PNG 저장 백업 실패: 저장 파일을 보존합니다")
				return
			data=data.duplicate(true)
			data["position"]=[];data["map_layout_revision"]=-1
		elif has_native_position and saved_map_id in ["aden_world","faith_01","faith_02","faith_03","faith_04"] and not plan_changed and int(data.get("map_layout_revision",-1))!=int(native_saved_field.data.layout_revision):
			# Same authenticated PNG/plan, explicit old world units. Never guess
			# a ratio from arbitrary saved pixels or overwrite the original save.
			var old_scales: Dictionary={2026102002:1.0,2026102003:2.0} if saved_map_id=="aden_world" else {2026102002:1.0}
			var old_revision: int=int(data.get("map_layout_revision",-1))
			if not old_scales.has(old_revision):
				source_save_blocked=true;hud.show_message("지도 저장 좌표 버전을 확인할 수 없습니다");return
			var original_hash: String=FileAccess.get_sha256(save_path())
			var backup_path: String=save_path()+".pre-aden-scale-"+original_hash
			if (not FileAccess.file_exists(backup_path) and DirAccess.copy_absolute(save_path(),backup_path)!=OK) or FileAccess.get_sha256(backup_path)!=original_hash:
				source_save_blocked=true;hud.show_message("지도 좌표 이전 백업 실패: 저장 파일을 보존합니다");return
			data=data.duplicate(true)
			var raw: Variant=data.get("position",[])
			var position: Vector2=Vector2.INF
			if raw is Array and raw.size()==2 and (raw[0] is int or raw[0] is float) and (raw[1] is int or raw[1] is float):
				position=Vector2(raw[0],raw[1])*(native_saved_field as NativePngField).artwork_scale/float(old_scales[old_revision])
			if position.is_finite() and native_saved_field.point_clear(position) and native_saved_field.line_clear(position,position):
				data["position"]=[position.x,position.y];data["map_layout_revision"]=native_saved_field.data.layout_revision
				# The historical review was the authenticated immutable PNG plan.
				# Having checked the new exact foot, retain this valid location.
				if str(data.get("native_png_review_sha256",""))==saved_plan:data["native_png_review_sha256"]=NATIVE_PNG.review_hash(saved_map_id)
			else:data["position"]=[];data["map_layout_revision"]=-1
		if not has_native_position and not FileAccess.file_exists(save_path()+".pre-native-png"):
			if DirAccess.copy_absolute(save_path(),save_path()+".pre-native-png")!=OK:
				source_save_blocked=true
				hud.show_message("이전 지도 저장 백업 실패: 저장 파일을 보존합니다")
				return
	if saved_map_id == CURRENT523_HOST.MAP_ID and CURRENT523_HOST.requested() and not data.get("original_position",{}).is_empty():
		# The 523 host replaces the old Aden picture pack. A position saved on
		# the old pack does not match the host's grid and is not restored (the
		# character starts at Aden town); progression loads unchanged. The
		# first save loaded this way is kept once, byte for byte.
		var host_backup: String=save_path()+".pre-current523-host"
		if not FileAccess.file_exists(host_backup) and DirAccess.copy_absolute(save_path(),host_backup)!=OK:
			source_save_blocked=true
			hud.show_message("523 아덴 이전 백업 실패: 기존 저장을 보존합니다")
			return
	elif saved_map_id.begins_with("l1_") or not data.get("original_position",{}).is_empty():
		var saved_field: OriginalPlayableField = SOURCE_MAP84.load_field(saved_map_id) if SOURCE_MAP84.supports(saved_map_id) else (REMAKE_REGISTRY.load_field(saved_map_id) if not saved_map_id.begins_with("l1_") else SOURCE_TRAVEL.load_field(maps_by_id.get(saved_map_id,{})))
		if saved_field is RemakePlayableField and not bool(saved_field.get_meta("source_map84",false)) and (data.has("oman_png_index_sha256") or SOURCE_PNG_GAME.requested(saved_map_id)) and not LEGACY_LAYOUT.active("--legacy-map-layouts"):
			if not SOURCE_PNG_GAME.attach(saved_field) or (data.has("oman_png_index_sha256") and data.oman_png_index_sha256!=FileAccess.get_sha256(SOURCE_PNG_GAME.root_path()+"/index.json")):
				saved_field.close();source_save_blocked=true
				hud.show_message("오만 PNG 리소스를 확인할 수 없어 저장 데이터를 보존합니다")
				return
		if saved_field == null:
			source_save_blocked = true
			hud.show_message("원본 맵 팩 누락·손상: 기존 저장 보존 중")
			return
		saved_field.close()
	if original_skills != null and not data.has("original_skill_state") and not FileAccess.file_exists(save_path() + ".pre-original-skills"):
		var backup_error := DirAccess.copy_absolute(save_path(), save_path() + ".pre-original-skills")
		if backup_error != OK:
			hud.append_log("스킬 저장 이전 중단 · 원본 백업 실패 · 오류 %d" % backup_error)
			if not quiet: hud.show_message("저장 이전 백업 실패")
			return
	if not option_awakening.prepare_load(data):
		equipment_collections.save_blocked = true
		hud.show_message("각성 저장 이전 실패 · 기존 저장을 보존합니다")
		return
	if not halphas_star.prepare_load(data):
		hud.show_message("할파스 강화 저장 이전 백업 실패 · 기존 저장 보존");return
	if not death_recovery.prepare_load(data,save_path()):
		death_recovery.save_blocked = true; hud.show_message("사망 복구 이전 백업 실패 · 기존 저장 보존"); return
	var prior_save_path: String=migrated_save_path
	var staged_map_save: Dictionary={}
	if bool(map_migration.changed):
		staged_map_save=MAP_SAVE_MIGRATION.stage(save_path(),data,loaded_save_sha)
		if not staged_map_save.ok:
			source_save_blocked=true;hud.show_message(str(staged_map_save.error));return
		migrated_save_path=str(staged_map_save.target_path)
	if not equipment_collections.accept_load(data):
		migrated_save_path=prior_save_path
		return
	if not option_awakening.accept_load(data):
		equipment_collections.save_blocked = true
		migrated_save_path=prior_save_path
		return
	if not skill_awakening.accept_load(data):
		migrated_save_path=prior_save_path
		return
	if not halphas_star.accept_load(data):
		migrated_save_path=prior_save_path;return
	# Invalid saves and failed accept/migration steps must retain the live source field.
	# Close it only after every fallible accepted-load step has succeeded.
	if current523_aden_play_active: close_current523_aden_play(false)
	expedition_local.restore(data)
	if peer_shop!=null:peer_shop.accept_load(data)
	SOURCE_MAP84.accept_layouts(data)
	totems.accept_state(data.get("totem_state"))
	totem_combat.settings_blocked = false
	totem_combat.clear()
	spell_group_conversion.restore(data.get("spell_group_conversion", {"schema":1,"source_snapshot":"patch523","classes":{}}))
	growth.restore(data.get("growth",growth.empty_state()))
	unconfirmed523.restore(data)
	death_recovery.accept_load(data)
	weapon_mastery.accept_load(data)
	growth96.restore(data.get("growth96",GROWTH96.fresh()))
	half_elixir.accept(data.get("half_elixir523", HALF_ELIXIR.fresh()))
	titles.restore(data)
	quest_service.import_state(data.get("quest_state", {}))
	tj_coupons.core.import_state(data.get("tj_coupons523",tj_coupons.core.empty_state()))
	tj_coupons.restore_context()
	if protection523!=null and protection523.has_method("load_state") and not protection523.call("load_state",data):
		patch523_owner_state_problem="가호 소유자 저장 복원 실패 · 기존 상태 보존"
		migrated_save_path=prior_save_path
		return
	if not staged_map_save.is_empty():
		pending_map_save_record=staged_map_save
		if not CHARACTER_ACCOUNT.session.is_empty(): CHARACTER_ACCOUNT.session["path"]=save_path()
	patch523_owner_state_problem=""
	# Reject missing/corrupt saves and failed migration backups before retiring
	# any live combat, summons or shields. Only an accepted load may reset them.
	source_save_blocked = false
	_clear_combat_actions()
	warehouse.restore(data.get("warehouse", {}))
	inventory_automation.restore(data.get("inventory_automation", {}))
	crafting_log.clear()
	patch523_crafting_usage=patch523_equipment.CONDITIONS.restore(data.get("patch523_crafting_usage",{}))
	var old_log: Variant = data.get("crafting_log", [])
	if old_log is Array:
		for raw_log: Variant in old_log:
			if raw_log is Dictionary and crafting_log.size() < 200:
				crafting_log.append((raw_log as Dictionary).duplicate(true))
	ain_service.import_state(data.get("ainhasad_state", {}))
	source_dungeon_runs.restore(data.get("source_dungeon523",DUNGEON_RUNS.empty_state()))
	dungeon_play.restore(data.get("source_dungeon_play",DUNGEON_PLAY.empty_state()))
	pending_dungeon_events.clear()
	level = maxi(1, int(data.get("level", level)))
	experience = maxi(0, int(data.get("experience", data.get("exp", experience))))
	exp_need = maxi(1, int(data.get("exp_need", exp_need)))
	var migrated_exp: Dictionary = EXP_PROGRESSION.migrate_progress(
		level, experience, exp_need, int(data.get("experience_progression_version", 0))
	)
	experience = int(migrated_exp["experience"])
	exp_need = int(migrated_exp["exp_need"])
	hp = int(data.get("hp", hp))
	max_hp = maxi(1, int(data.get("max_hp", max_hp)))
	mp = int(data.get("mp", mp))
	max_mp = maxi(0, int(data.get("max_mp", max_mp)))
	hp_recovery_elapsed = clampf(float(data.get("hp_recovery_elapsed", 0.0)), 0.0, UNIQUE_RECOVERY_INTERVAL)
	mp_recovery_elapsed = clampf(float(data.get("mp_recovery_elapsed", 0.0)), 0.0, UNIQUE_RECOVERY_INTERVAL)
	source_item_regen_elapsed = clampf(float(data.get("source_item_regen_elapsed",0.0)),0.0,300.0)
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
	var inventory_value: Variant = data.get("inventory", inventory)
	if inventory_value is Dictionary:
		inventory = inventory_value as Dictionary
	_ensure_inventory_ammo_defaults()
	consumable_service.call("prune_removed")
	character_source_cursor = data.get("character_source_cursor",{}).duplicate(true) if data.get("character_source_cursor",{}) is Dictionary else {}
	if TUTORIAL523.land(character_source_cursor.get("native_land_id",-1)):
		# Any other copy of a deleted tutorial Land spot (사용자 결정 2026-11-16).
		tutorial523["relocated"] = {"from_native_land_id":int(character_source_cursor.native_land_id),"from_source_position":character_source_cursor.get("source_position",[]),"to_native_land_id":TUTORIAL523.ADEN_LAND_ID,"to_source_position":TUTORIAL523.START_VILLAGE.source_position(),"to_village":TUTORIAL523.START_VILLAGE.NAME}
		character_source_cursor = TUTORIAL523.START_VILLAGE.cursor()
	old_map_relocation523 = data.get(OLD_MAP_RELOCATION523.KEY,{}).duplicate(true) if data.get(OLD_MAP_RELOCATION523.KEY,{}) is Dictionary else {}
	tutorial523 = data.get(TUTORIAL523.KEY,{}).duplicate(true) if data.get(TUTORIAL523.KEY,{}) is Dictionary else {}
	class_index = clampi(int(data.get("class_index", class_index)), 0, 3)
	job_class = str(data.get("job_class", job_class))
	if not JOB_CLASS_ORDER.has(job_class):
		job_class = "기사"
	source_gender_id = 0
	source_card_visual_options.clear()
	var source_context: Variant = data.get("source_visual_context", {})
	if source_context is Dictionary and source_context.get("snapshot", "") == "base508":
		source_gender_id = int(source_context.get("gender_id", 0))
		if source_gender_id not in [0,1,2]: source_gender_id = 0
		var saved_options: Variant = source_context.get("active_card_options", {})
		source_card_visual_options = saved_options.duplicate(true) if saved_options is Dictionary else {}
	_sync_card_class_variant()
	var saved_ui: Variant = data.get("ui_preferences", {})
	ui_preferences = saved_ui.duplicate(true) if saved_ui is Dictionary else {}
	ui_preferences["consumable_auto"] = CONSUMABLE_AUTO.normalize(ui_preferences.get("consumable_auto", {}))
	for key: String in ["quickslot_pages","edited_quickslots","item_locks"]:
		if not ui_preferences.get(key) is Dictionary: ui_preferences[key] = {}
	if field_map != null and is_instance_valid(player): _apply_field_camera_zoom()
	var quickslots_value: Variant = data.get("quickslots", quickslots)
	if quickslots_value is Array:
		quickslots = quickslots_value as Array
	self_mode_enabled = bool(data.get("self_mode_enabled", self_mode_enabled))
	var skill_buffs_value: Variant = data.get("active_skill_buffs", {})
	active_skill_buffs = skill_buffs_value as Dictionary if skill_buffs_value is Dictionary else {}
	var skill_cooldowns_value: Variant = data.get("skill_cooldowns", {})
	skill_cooldowns = skill_cooldowns_value as Dictionary if skill_cooldowns_value is Dictionary else {}
	skill_global_cooldown = maxf(0.0, float(data.get("skill_global_cooldown", 0.0)))
	if original_skills != null:
		original_skills.catalog.import_state(data)
	var item_buffs_value: Variant = data.get("active_item_buffs", {})
	active_item_buffs = item_buffs_value as Dictionary if item_buffs_value is Dictionary else {}
	for key: Variant in active_item_buffs.keys():
		var entry: Variant = active_item_buffs[key]
		if entry is Dictionary and entry.has("source_buff_delete_at") and float(entry.source_buff_delete_at) <= Time.get_unix_time_from_system():
			active_item_buffs.erase(key)
	var item_cooldowns_value: Variant = data.get("item_use_cooldowns", {})
	item_use_cooldowns = item_cooldowns_value as Dictionary if item_cooldowns_value is Dictionary else {}
	consumable_service.call("import_state", data.get("consumable_state", {}))
	consumable_service.call("prune_removed")
	_prune_active_skill_buffs_for_current_job()
	player.set_class_index(class_index)
	player.clear_status_effects()
	combinations.accept_load(data)
	monsterbook523_runtime.reset_pending()
	monsterbook523.import_state(data.get("monsterbook523", {"schema":1,"books":{}}))
	monsterbook523_runtime.save_blocked = false
	card_collections.import_policy(data.get("card_collection_policy",{}))
	card_draw_fusion.import_state(data.get("card_draw_fusion", {}))
	if _full_cards_playtest_active(): card_draw_fusion.grant_full_collection_for_playtest(10)
	# Old version-1 ownership is already permanent. Derive silently before HP/MP
	# clamping, with no card consumption, grant, or new mutable save field.
	card_collections.restore_from_owned()
	var equipped_value: Variant = data.get("equipped_catalog", equipped_catalog)
	if equipped_value is Dictionary:
		equipped_catalog = equipped_value as Dictionary
	var equipped_items_value: Variant = data.get("equipped_items", equipped_items)
	if equipped_items_value is Dictionary:
		equipped_items = equipped_items_value as Dictionary
	equipped_ammo = str(data.get("equipped_ammo", ""))
	if equipped_ammo not in ["화살", "총알"] and not _is_ammo_record(_find_catalog_item_record(equipped_ammo)) and SOURCE_AMMO.definition(_find_catalog_item_record(equipped_ammo)).is_empty():
		equipped_ammo = ""
	ammo_unequipped = bool(data.get("ammo_unequipped", false))
	var enhancement_value: Variant = data.get("enhancement_levels", enhancement_levels)
	if enhancement_value is Dictionary:
		enhancement_levels = enhancement_value as Dictionary
	var stored_instances: Variant = data.get("item_instances", {})
	source_shop.accept_load(data)
	item_instances = stored_instances as Dictionary if stored_instances is Dictionary else {}
	# Before the instance sync below: slots 2/3 hold physical stones.
	domination_stones.import_state(data.get(DOMINATION_STONES.SAVE_KEY, {}))
	routines.import_state(data.get(ROUTINE523.SAVE_KEY, {}))
	emblem523.import_state(data.get(EMBLEM523.SAVE_KEY, {}))
	clan523.import_state(data.get(CLAN523.SAVE_KEY, {}))
	content523.import_state(data.get(CONTENT523.SAVE_KEY, {}))
	card_swap523.import_state(data.get(CARD_SWAP523.SAVE_KEY, {}))
	# An older save has no ledger: its Life items start at this load time.
	item_life523.import_state(data.get(ITEM_LIFE523.SAVE_KEY, {}))
	item_book523.import_state(data.get(ITEM_BOOK523.SAVE_KEY))
	# Original 아이템 컬렉션 effects join the collection stats (no double count).
	equipment_collections.refresh_item_book_totals()
	# An older save has no draws: its 신화 weapons draw once after this load.
	item_invoke523.import_state(data.get(ITEM_INVOKE523.SAVE_KEY, {}))
	dungeon_extras523.import_state(data.get(DUNGEON_EXTRAS523.SAVE_KEY, {}))
	skill_cards523.import_state(data.get(SKILL_CARD523.SAVE_KEY, {}))
	CATALOG_GRADES.synchronize_saved_grades(catalog_db.get("아이템", []), item_db,
		item_instances, equipped_items, warehouse.instances)
	next_item_instance_id = maxi(1, int(data.get("next_item_instance_id", 1)))
	for raw_id: Variant in item_instances.keys():
		if str(raw_id).is_valid_int() and str(raw_id).length() <= 18:
			next_item_instance_id = maxi(next_item_instance_id, int(str(raw_id)) + 1)
	next_item_instance_id = maxi(next_item_instance_id, equipment_collections.next_safe_id())
	for death_entry: Dictionary in death_recovery.state.records:
		if not death_entry.item.is_empty() and str(death_entry.item.id).is_valid_int(): next_item_instance_id = maxi(next_item_instance_id,int(death_entry.item.id)+1)
	# Pre-November items -> the original 523 item of exactly the same name
	# (smallest ID for a shared name); unmatched ones are deleted (user
	# decisions 2026-11-13), before the physical-record sync below.
	var legacy_items: Dictionary=preload("res://scripts/loot/legacy_item_migration523.gd").run(self,data.get("legacy_item_migration523",{}),loaded_save_file,original_save_bytes)
	legacy_item_marker=(legacy_items.get("marker",{}) as Dictionary).duplicate(true)
	if not legacy_items.get("ok",false):hud.append_log("이전 아이템 523 교체 보류 · %s · 기존 아이템 보존" % str(legacy_items.get("error","")))
	elif legacy_items.get("changed",false):hud.append_log("이전 아이템 %d종을 같은 이름의 523 원본으로 교체 · 같은 이름의 원본이 없는 %d종 삭제(백업 보존) · %d종 보류" % [int(legacy_item_marker.migrated_count),int(legacy_item_marker.get("deleted_count",0)),int(legacy_item_marker.unmatched_count)])
	_migrate_patch523_physical_records()
	_sync_item_instances()
	_normalize_equipment_slots()
	_attach_missing_equipment_instance_ids()
	_refresh_patch523_equipment_options()
	consumable_service.call("migrate_legacy_elemental")
	_enforce_patch523_equipment_use()
	_enforce_weapon_class_compatibility(true)
	_enforce_patch523_equipment_requirements()
	_enforce_shield_weapon_compatibility(true)
	# Worn duplicates over the source EquipSlotConfig limit (user decision
	# 2026-11-13): unequip the later slot once; the item stays in the bag.
	var saved_group_marker: Variant=data.get("equip_group_limit523",{})
	equip_group_marker=preload("res://scripts/loot/current523_equip_group_limit.gd").enforce_loaded(self,saved_group_marker)
	if equip_group_marker!=saved_group_marker:
		for released: Variant in equip_group_marker.get("released",[]):
			hud.append_log("불러오기 장착 정리 · %s · 가방으로 해제" % str(released.get("reason","")))
	# Source possession/pass bonuses must use the restored ownership and
	# character before the saved HP is clamped to its effective maximum.
	unconfirmed523.rebuild()

	equipment523.after_load(self,data.get("equipment523_set_effects",{}))
	alchemy_held_items.after_load()
	_invalidate_equipment_static()
	_restore_equipped_visuals()
	player.set_skill_speed_multiplier(_active_skill_speed_multiplier())
	_refresh_skill_stealth_visual()
	hp = clampi(hp, 0, _effective_max_hp())
	mp = clampi(mp, 0, _effective_max_mp())
	var map_id: String = str(data.get("map_id", active_map_id))
	if not maps_by_id.has(map_id):
		map_id = active_map_id
	# Capture outgoing actors before importing; otherwise map teardown could
	# overwrite the loaded boss snapshot with the pre-load HP/cooldown.
	field_population.configure(self,null)
	legacy_population.import_state(data.get("monster_world",{}))
	original_population.import_state(data.get("original_monster_world",{}))
	loading_source_door_state=true
	_set_map(map_id, false)
	loading_source_door_state=false
	_restore_ground_drops(data.get("ground_drops", []))
	var position_value: Variant = data.get("position", [])
	var compatible_layout: bool = field_map == null or int(data.get("map_layout_revision",0)) == int(field_map.data.get("layout_revision",1))
	if field_map is NativePngField and str(data.get("native_png_review_sha256",""))!=NATIVE_PNG.review_hash(active_map_id):
		# Keep character progress, inventory and boss state; a revised obstacle
		# must not restore the actor inside its old, now blocked pixel position.
		compatible_layout=false
	if field_map is OriginalPlayableField:
		position_value = SOURCE_TRAVEL.restore_position(self,data.get("original_position",{}))
	if position_value is Array and compatible_layout:
		var position_array: Array = position_value as Array
		if position_array.size() >= 2:
			var saved_position: Vector2 = Vector2(float(position_array[0]), float(position_array[1]))
			if field_map is NativePngField and not field_map.line_clear(saved_position,saved_position):
				# Old saves can refer to a cell that is open in AStar but blocked
				# at the actor's true foot. Snap nearby, never into an obstacle.
				saved_position=field_map.nearest_safe_click_destination(saved_position,4)
			if _is_walkable_world(saved_position):
				player.global_position = saved_position
				player.camera.reset_smoothing()
	_update_job_skillbar()
	if original_skills != null: original_skills.import_state(data.get("original_combat_state", {}))
	if (source_dungeon_runs.has_experience_award() or dungeon_play.has_experience_award()) and experience >= exp_need: _check_level_up()
	halphas_star.combat.restore_player()
	titles.reconcile_powder_stock()
	# _update_hud also folds an old save's separate receipted stacks of one
	# item into one slot (_merge_native_stacks).
	_update_hud()
	_refresh_source_dungeon_panel()
	_emit_consumable_auto_settings()
	_refresh_regional_return_slots()
	# Scene/map restoration may use random landing/actor cooldowns. Resume the
	# committed transaction stream after that setup, before normal play.
	if data.has("patch523_transaction_rng"):
		rng.seed=int(data.patch523_transaction_rng.seed)
		rng.state=int(data.patch523_transaction_rng.state)
	if not quiet:
		hud.show_message("불러오기 완료")


func _build_job_classes() -> void:
	job_classes.clear()
	# Character classes are independent source definitions, not invented mythic cards.
	if not BASE508.cards().is_empty():
		for definition: Dictionary in BASE508.cards().get("classes", []):
			var job_name: String = str(definition.name)
			job_classes.append({"name":job_name,"transform_name":"","image_path":"","source_id":"","source_class":definition,"weapon":_job_weapon_text(job_name),"role":_job_role_from_skills(job_name),"primary_stat":str(JOB_PRIMARY_STAT.get(job_name,""))})
		return
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
	_invalidate_equipment_static()
	_apply_transform_visual(record)
	_refresh_speed_modifiers()

func _on_job_class_selected(job_name: String) -> void:
	if not CHARACTER_ACCOUNT.session.is_empty():
		hud.show_message("캐릭터 직업은 생성 시 고정됩니다. 다른 직업은 캐릭터 선택에서 생성하세요.")
		return
	if not JOB_CLASS_ORDER.has(job_name):
		return
	_clear_skill_charge()
	_clear_combat_actions()
	if original_skills != null: original_skills.catalog.class_slots[job_class] = quickslots.duplicate(true)
	job_class = job_name
	if _sync_card_class_variant(): _invalidate_equipment_static()
	if original_skills != null and original_skills.catalog.class_slots.has(job_name):
		quickslots = original_skills.catalog.class_slots[job_name].duplicate(true)
	var record: Dictionary = _job_transform_record(job_class)
	if not record.is_empty():
		equipped_catalog["변신"] = record.duplicate(true)
		_invalidate_equipment_static()
		_apply_transform_visual(record)
	if BASE508.native(equipped_catalog.get("변신", {})):
		_apply_transform_visual(equipped_catalog["변신"])
	_enforce_patch523_equipment_use()
	_enforce_weapon_class_compatibility(false)
	_enforce_patch523_equipment_requirements()
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
		if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"] and not original_skills.catalog.owned(skill): continue
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
		hud.call("set_quickslot_state", effective_quickslots(), inventory, _combined_active_buffs(), self_mode_enabled)

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
		if entry.is_empty(): continue
		if str(entry.get("kind", "")) == "item":
			if not _quickslot_item_supported(str(entry.get("id",""))):
				if quest_item_provider.retains_issued_reference(self,str(entry.get("id",""))):continue
				quickslots[index] = {}
				changed = true
			continue
		if str(entry.get("kind", "")) != "skill":
			quickslots[index] = {}
			changed = true
			continue
		var skill_name: String = str(entry.get("skill_id", entry.get("id", "")))
		var skill: Dictionary = _skill_record(skill_name)
		if skill.is_empty() or _is_passive_skill(skill) or (skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"] and not original_skills.catalog.owned(skill)):
			quickslots[index] = {}
			changed = true
			continue
		var skill_class: String = str(skill.get("class", "공용"))
		if skill_class != "공용" and skill_class != job_class:
			quickslots[index] = {}
			changed = true
		elif skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"] and str(entry.get("id", "")) != str(skill.name):
			entry["id"] = str(skill.name)
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
	while quickslots.size() < QUICK_LAYOUT.QUICK_CAPACITY:
		quickslots.append({})
	while quickslots.size() > QUICK_LAYOUT.QUICK_CAPACITY:
		quickslots.pop_back()

func _ensure_quickslots_seeded() -> void:
	var sanitized_changed: bool = _sanitize_quickslots_for_current_job()
	if bool(ui_preferences.get("edited_quickslots",{}).get(job_class,false)): return
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
		for item_name: String in preload("res://scripts/loot/current523_starter_kit.gd").quickslot_names(self):
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
	if slot_index < 0 or slot_index >= QUICK_LAYOUT.QUICK_CAPACITY:
		return
	var registration_error: String = _quickslot_registration_error(entry_kind,entry_id)
	if not registration_error.is_empty():
		hud.show_message(registration_error)
		return
	_normalize_quickslots()
	var is_auto_skill: bool = entry_kind == "skill_auto"
	if entry_kind == "skill" or is_auto_skill:
		var skill: Dictionary = _skill_record(entry_id)
		if skill.is_empty():
			hud.show_message("등록할 스킬을 찾을 수 없습니다")
			return
		if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"] and not original_skills.catalog.owned(skill):
			hud.show_message("미습득 스킬은 등록할 수 없습니다")
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
	ui_preferences.edited_quickslots[job_class] = true
	quickslots[slot_index] = {"kind":"skill" if is_auto_skill else entry_kind, "id":entry_id, "auto":is_auto_skill}
	if str(quickslots[slot_index].kind) == "skill":
		var slotted := _skill_record(entry_id)
		if slotted.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]:
			quickslots[slot_index]["skill_id"] = str(slotted.id)
			quickslots[slot_index]["id"] = str(slotted.name)
	_update_hud()
	_request_deferred_save()

func _on_quickslot_pressed(slot_index: int) -> void:
	if death_recovery.blocked(): return
	if slot_index < 0 or slot_index >= quickslots.size():
		return
	var value: Variant = quickslots[slot_index]
	if not (value is Dictionary):
		return
	var entry: Dictionary = REGIONAL_RETURN.effective(value, _regional_return_land(), get_regional_return_enabled(), inventory, _find_catalog_item_record)
	if entry.is_empty():
		hud.show_message("빈 퀵슬롯입니다")
		return
	var kind: String = str(entry.get("kind", ""))
	var entry_id: String = str(entry.get("skill_id", entry.get("id", ""))) if kind == "skill" else str(entry.get("id", ""))
	if kind == "skill":
		_cast_job_skill_input(entry_id)
	elif kind == "item":
		_use_quickslot_item(entry_id)

func _use_quickslot_item(item_name: String) -> void:
	if int(inventory.get(item_name, 0)) <= 0:
		hud.show_message("%s이(가) 없습니다" % item_name)
		_update_hud()
		return
	if _quickslot_item_supported(item_name):
		_activate_inventory_input(item_name)
	else:
		hud.show_message("직접 사용할 수 없는 아이템입니다")

func _quickslot_item_supported(item_name: String) -> bool:
	if option_awakening.source_scroll_supported(item_name):return true
	if _find_catalog_item_record(item_name).get("source_automation_catalog_only",false): return false
	if CONSUMABLE_RULES.is_removed_item(item_name): return false
	var return_record: Dictionary = _find_catalog_item_record(item_name)
	if REGIONAL_RETURN.claims_identity(item_name, return_record): return REGIONAL_RETURN.supported(item_name, return_record)
	# Original 523 acceleration potions (초록 물약·용기의 물약·엘븐 와퍼 ...) are
	# drunk from the quick slot like in the original.
	var native_use: Dictionary = preload("res://scripts/loot/current523_native_stack.gd").profile(return_record)
	if native_use.get("kind") == "buff" and not native_use.get("runtime_presentation", false) and int(native_use.get("spec", {}).get("acceleration_stage", 0)) > 0: return true
	if not CONSUMABLE_RULES.definition(item_name).is_empty() or _scroll_kind(item_name) != "": return true
	var record: Dictionary = _find_catalog_item_record(item_name)
	return not record.is_empty() and (_is_timed_buff_item(record) or int(record.get("heal",0)) > 0)

func _quickslot_registration_error(kind: String, id: String) -> String:
	if kind == "item":
		if int(inventory.get(id,0)) <= 0: return "보유하지 않은 아이템입니다"
		if not _quickslot_item_supported(id): return "장비와 재료는 퀵슬롯에 등록할 수 없습니다"
		return ""
	if kind not in ["skill","skill_auto"]: return "등록할 수 없는 항목입니다"
	var skill: Dictionary = _skill_record(id)
	if skill.is_empty(): return "삭제되었거나 존재하지 않는 스킬입니다"
	if original_skills!=null and skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029"]:skill=original_skills.catalog.resolve(skill)
	var source_status: Dictionary=original_skills.catalog.source_learning_status(skill)
	if not source_status.is_empty():return str(source_status.message)
	if _is_passive_skill(skill) and not (original_skills!=null and original_skills.stackable.handles(skill)): return "패시브는 직접 사용할 수 없습니다"
	if kind=="skill_auto" and str(skill.get("mode",""))=="source_toggle":return "ON/OFF는 수동 전환하고 일반 공격에서 실행합니다"
	if kind == "skill_auto" and not SKILL_RULES.can_auto_cast(skill): return "자동사용을 지원하지 않는 스킬입니다"
	if str(skill.get("class","공용")) not in [job_class,"공용"]: return "현재 직업의 스킬이 아닙니다"
	if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"] and not original_skills.catalog.owned(skill): return "미습득 스킬입니다"
	return ""

func _set_item_locked(reference: String, locked: bool) -> void:
	var parsed: Dictionary = _parse_enhancement_target(reference)
	var item_name: String = str(parsed.get("name",reference))
	var id: String = str(parsed.get("id",""))
	if int(inventory.get(item_name,0)) <= 0: return
	if not id.is_empty() and (not item_instances.has(id) or item_instances[id].get("name","") != item_name): return
	if locked: ui_preferences.item_locks[reference] = true
	else: ui_preferences.item_locks.erase(reference)
	_update_hud()
	_request_deferred_save()

func _item_locked(item_name: String, instance_id: String = "") -> bool:
	return bool(ui_preferences.get("item_locks",{}).get(item_name+("@@@"+instance_id if not instance_id.is_empty() else ""),false))

func _unequip_item_reference(reference: String) -> void:
	var parsed: Dictionary = _parse_enhancement_target(reference)
	var id: String = str(parsed.get("id",""))
	if quest_item_provider.equipment_owner.activate(self,id,"",true):return
	if id.is_empty() and str(parsed.get("name", reference)) == equipped_ammo and not equipped_ammo.is_empty():
		_toggle_ammo_equipped(equipped_ammo)
		return
	if id.is_empty(): return
	if domination_stones.is_extra_equipped(id):
		domination_stones.unequip(domination_stones.state.slots.find(id)+1)
		return
	for slot: String in equipped_items.keys():
		if str(equipped_items[slot].get("instance_id","")) != id: continue
		equipped_items.erase(slot)
		_invalidate_equipment_static()
		hp = mini(hp,_effective_max_hp())
		mp = mini(mp,_effective_max_mp())
		_refresh_speed_modifiers()
		_update_hud()
		hud.refresh_inventory(inventory)
		_request_deferred_save()
		return

func _quickslot_pages() -> Array:
	var value: Variant = ui_preferences.get("quickslot_pages",{}).get(job_class,[0,0])
	if not value is Array or value.size() != 2: return [0,0]
	return [clampi(int(value[0]),0,4),clampi(int(value[1]),0,4)]

func _quickslot_auto_allowed(entry: Dictionary) -> bool:
	if entry.get("kind","") == "skill":
		var skill: Dictionary=_skill_record(str(entry.get("skill_id",entry.get("id",""))))
		if original_skills!=null and skill.get("origin","") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]:skill=original_skills.catalog.resolve(skill)
		if str(skill.get("mode",""))=="source_toggle":return false
		return SKILL_RULES.can_auto_cast(skill)
	if option_awakening.source_scroll_supported(str(entry.get("id",""))):return true
	var record: Dictionary = _find_catalog_item_record(str(entry.get("id","")))
	if record.get("source_m_native_item",false) and int(record.get("source_item_class_id",0))==LOOT_DROP.PATCH523_DROPS.LARGE_HP_ELIXIR_ID:return false
	var spec: Dictionary = CONSUMABLE_RULES.definition(str(entry.get("id","")))
	return int(record.get("heal",0)) > 0 or str(spec.get("kind","")) in ["regen","food","buff","instant_mp"]

func _on_quickslot_edit_requested(action: String, source_index: int, target: int) -> void:
	_normalize_quickslots()
	if action == "page":
		if source_index < 0 or source_index > 1: return
		var pages: Array = _quickslot_pages()
		pages[source_index] = posmod(target,5)
		ui_preferences.quickslot_pages[job_class] = pages
	else:
		if source_index < 0 or source_index >= quickslots.size(): return
		match action:
			"swap":
				if target < 0 or target >= quickslots.size() or target == source_index: return
				var source_entry: Dictionary = quickslots[source_index].duplicate(true)
				quickslots[source_index] = quickslots[target].duplicate(true)
				quickslots[target] = source_entry
			"clear": quickslots[source_index] = {}
			"auto_on", "auto_off":
				if quickslots[source_index].is_empty(): return
				if action == "auto_on" and not _quickslot_auto_allowed(quickslots[source_index]):
					hud.show_message("자동사용을 지원하지 않는 항목입니다")
					return
				quickslots[source_index]["auto"] = action == "auto_on"
			_: return
		ui_preferences.edited_quickslots[job_class] = true
	_update_hud()
	_request_deferred_save()

func get_consumable_auto_settings() -> Dictionary:
	return CONSUMABLE_AUTO.normalize(ui_preferences.get("consumable_auto", {}))

func set_consumable_auto_settings(settings: Dictionary) -> void:
	ui_preferences["consumable_auto"] = CONSUMABLE_AUTO.normalize(settings)
	auto_item_clock = 0.0
	_emit_consumable_auto_settings()
	_request_deferred_save()

func _emit_consumable_auto_settings() -> void:
	if is_instance_valid(hud) and hud.has_signal("consumable_auto_settings_updated"):
		hud.emit_signal("consumable_auto_settings_updated", get_consumable_auto_settings())

func _run_auto_item_quickslots(delta: float) -> void:
	auto_item_clock -= delta
	if auto_item_clock > 0 or hp <= 0 or player.is_stunned() or player.is_feared():
		return
	auto_item_clock = 0.2
	var settings: Dictionary = get_consumable_auto_settings()
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	var active_entries: Array[Dictionary] = []
	# Candidate collection does not consume items or change buffs. Reuse these
	# expensive derived stats for this poll; the next poll reads fresh values.
	var maximum_hp: int = -1
	var maximum_mp: int = -1
	for value: Variant in quickslots:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value as Dictionary
		if entry.get("kind", "") != "item" or not bool(entry.get("auto", false)):
			continue
		var item: String = str(entry.get("id", ""))
		if seen.has(item) or int(inventory.get(item, 0)) <= 0 or float(item_use_cooldowns.get(item, 0)) > 0:
			continue
		seen[item] = true
		active_entries.append(entry)
	# Runs every 0.2 s: use the indexed single-name lookup (same results as
	# find_many, verified by catalog_item_lookup_index_test) instead of a scan.
	var records: Dictionary = {}
	var sources: Array = [catalog_db.get("아이템", []), item_db]
	for raw_item: Variant in seen.keys():
		var found: Dictionary = ITEM_CATALOG_LOOKUP.find_one(sources, item_instances, str(raw_item))
		if not found.is_empty(): records[str(raw_item)] = found
	for entry: Dictionary in active_entries:
		var item: String = str(entry.get("id", ""))
		var record: Dictionary = records.get(item, {})
		if option_awakening.source_scroll_supported(item):
			if option_awakening.source_scroll_auto_ready(item) and _quickslot_auto_allowed(entry):candidates.append({"item":item,"priority":2,"source_relic_scroll":true})
			continue
		if int(record.get("heal", 0)) > 0 and float(item_use_cooldowns.get(HP_POTION_COOLDOWN_KEY, 0.0)) > 0.0:
			continue
		var spec: Dictionary = CONSUMABLE_RULES.definition(item)
		if maximum_hp < 0:
			maximum_hp = _effective_max_hp()
			maximum_mp = _effective_max_mp()
		if not CONSUMABLE_AUTO.wanted(item, record, spec, settings, hp, maximum_hp, mp, maximum_mp, job_class, active_item_buffs):
			continue
		if not _quickslot_auto_allowed(entry):
			continue
		candidates.append({"item":item, "priority":CONSUMABLE_AUTO.priority(record, spec)})
	# One successful consumption per interval. HP first; slot order within
	# each class is preserved. A refused item cannot starve later slots.
	for priority: int in range(3):
		for candidate: Dictionary in candidates:
			if int(candidate.priority) != priority:
				continue
			var item: String = str(candidate.item)
			var before: int = int(inventory.get(item, 0))
			var before_revision: int=int(option_awakening.progress.revision)
			_use_quickslot_item(item)
			if int(inventory.get(item, 0)) < before or (candidate.get("source_relic_scroll",false) and int(option_awakening.progress.revision)!=before_revision):
				return

func _on_self_mode_changed(enabled: bool) -> void:
	self_mode_enabled = enabled
	auto_buff_check_timer = 0.0
	_update_hud()
	_request_deferred_save()

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
	if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]: return original_skills.catalog.enabled(skill)
	var skill_class: String = str(skill.get("class", "공용"))
	return skill_class == "공용" or skill_class == job_class

func _non_original_skill_rows() -> Array[Dictionary]:
	# Keep legacy migration data in its own array. The active 125-row catalogue
	# normally contains only original IDs, so scanning it for extra passive
	# fields on every stat query does no useful work.
	_ensure_skill_record_index()
	return non_original_skill_rows

func _passive_skill_total(key: String) -> int:
	var total: int = int(original_skills.stat(key)) if original_skills != null else 0
	for skill: Dictionary in _non_original_skill_rows():
		if not _is_passive_skill(skill) or not _skill_owned_for_current_job(skill) or SKILL_RULES.passive_trigger(skill) != "always":
			continue
		total += int(skill.get(key, 0))
	return total

func _passive_skill_speed_multiplier() -> float:
	if _stat_memo_depth == 0: return _passive_skill_speed_multiplier_uncached()
	var memo_key: String = "passive_speed"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _passive_skill_speed_multiplier_uncached()
	return _stat_memo[memo_key]

func _passive_skill_speed_multiplier_uncached() -> float:
	var multiplier: float = original_skills.catalog.speed() if original_skills != null else 1.0
	for value: Variant in skills_db:
		if not (value is Dictionary):
			continue
		var skill: Dictionary = value as Dictionary
		if not _is_passive_skill(skill) or not _skill_owned_for_current_job(skill) or SKILL_RULES.passive_trigger(skill) != "always":
			continue
		multiplier = maxf(multiplier, float(skill.get("speed", 1.0)))
	return multiplier

func _passive_skill_names() -> PackedStringArray:
	if _stat_memo_depth == 0: return _passive_skill_names_uncached()
	var memo_key: String = "passive_names"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _passive_skill_names_uncached()
	return _stat_memo[memo_key]

func _passive_skill_names_uncached() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for value: Variant in skills_db:
		if value is Dictionary:
			var skill: Dictionary = value as Dictionary
			if _is_passive_skill(skill) and _skill_owned_for_current_job(skill):
				names.append(str(skill.get("name", "")))
	return names

func _is_buff_skill(skill: Dictionary) -> bool:
	if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]: return skill.get("mode", "") in ["buff", "counter", "stealth", "summon", "local_buff"]
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
		var skill_name: String = str(entry.get("skill_id", entry.get("id", "")))
		if skill_name == "":
			continue
		var skill: Dictionary = _skill_record(skill_name)
		if skill.is_empty() or not _is_buff_skill(skill) or not _skill_owned_for_current_job(skill):
			continue
		skill_name = str(skill.name)
		if active_skill_buffs.has(skill_name): continue
		if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"] and not bool(entry.get("auto", false)):
			continue
		if not _skill_ready(skill):
			continue
		if _cast_job_skill(skill_name, false):
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
	if patch523_npc_spells.blocks("CannotCastSkill"): return false
	if halphas_star.combat.frozen(player) or not halphas_star.combat.charge.is_empty():return false
	if skill.get("origin","")=="TWILIGHT_GUARDIAN523":return bool(growth.quote("guardian_cast",str(skill.id).trim_prefix("guardian:")).ok)
	if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]: return original_skills.ready(skill, announce)
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
	var skill_ammo: String = _skill_ammo_name()
	var ammo_record: Dictionary = _find_catalog_item_record(skill_ammo)
	var invalid_source: bool = ammo_record.get("source")=="twilight-shop523-ammo" and SOURCE_AMMO.definition(ammo_record).is_empty()
	if required_ammo > 0 and (invalid_source or not _ammo_worn(skill_ammo, true) or int(inventory.get(skill_ammo, 0)) < required_ammo):
		if announce:
			hud.show_message("%s · 화살 %d개 필요" % [skill_name, required_ammo] if _is_item_equipped("화살") else "%s · 화살을 착용하세요" % skill_name)
		return false
	if not charge_skill.is_empty() or player.is_stunned() or player.is_feared() or ((player.silence_remaining > 0 or (player.source_523_spell_blocked and _skill_attack_kind(skill) == "magic")) and int(skill.get("mp",0)) > 0):
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

## M81 priority order: absolute quickslot index i is the original pair (page i/5, button i%5),
## sorted by page*5+button. Built once per slot count; equal to the plain index order.
func _auto_quickslot_order() -> Array[int]:
	if auto_quickslot_order_cache.size() != quickslots.size():
		var pairs: Array = []
		for index: int in range(quickslots.size()):
			pairs.append({"page": index / 5, "button": index % 5})
		var order: Array = ORIGINAL_AUTOSLOT.build_local_order(pairs, true, [], Callable()).order
		auto_quickslot_order_cache.clear()
		for pair: Dictionary in order:
			auto_quickslot_order_cache.append(ORIGINAL_AUTOSLOT.priority_key(pair))
	return auto_quickslot_order_cache

## Manager passes. No queued single pair exists in this game (manual use is immediate) and
## items/buffs keep their own 0.2 s / 0.8 s polls, so queued and auxiliary passes are empty.
func _auto_quickslot_queued_pass() -> void:
	pass

func _auto_quickslot_spell_pass() -> bool:
	_run_auto_heal_quickslots()
	return false

func _auto_quickslot_aux_pass() -> bool:
	return false

func _run_auto_heal_quickslots() -> void:
	for index: int in _auto_quickslot_order():
		if index >= quickslots.size(): break
		var value: Variant = quickslots[index]
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		if not bool(entry.get("auto", false)) or str(entry.get("kind", "")) != "skill":
			continue
		var skill: Dictionary = _skill_record(str(entry.get("skill_id", entry.get("id", ""))))
		if skill.is_empty() or SKILL_RULES.effect_kind(skill) != "heal":
			continue
		if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]:
			if original_skills.auto_wants(skill): _cast_job_skill(str(skill.name), false)
			continue
		if float(hp) / float(maxi(1, _effective_max_hp())) > SKILL_RULES.heal_threshold(skill):
			continue
		if _skill_ready(skill):
			_cast_job_skill(str(skill.get("name", "")), false)
			return

func _run_auto_combat_quickslots() -> bool:
	if not is_instance_valid(selected_monster) or selected_monster.dead:
		return false
	for index: int in _auto_quickslot_order():
		if index >= quickslots.size(): break
		var value: Variant = quickslots[index]
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value as Dictionary
		if not bool(entry.get("auto", false)) or str(entry.get("kind", "")) != "skill":
			continue
		var skill_name: String = str(entry.get("skill_id", entry.get("id", "")))
		var skill: Dictionary = _skill_record(skill_name)
		if skill.is_empty() or not SKILL_RULES.can_auto_cast(skill) or SKILL_RULES.effect_kind(skill) == "heal":
			continue
		if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"] and not original_skills.auto_wants(skill, selected_monster): continue
		if not _skill_ready(skill):
			continue
		if player.global_position.distance_to(selected_monster.global_position) > SKILL_RULES.range_pixels(skill):
			continue
		if not _has_line_of_sight_world(player.global_position, selected_monster.global_position):
			continue
		if SKILL_RULES.effect_kind(skill) == "turnUndead" and not selected_monster.is_undead():
			continue
		if _cast_job_skill(skill_name, false):
			return true
	return false

func _cast_job_status_skill(skill: Dictionary) -> bool:
	var target: TwilightMonster = _skill_target(SKILL_RULES.range_pixels(skill))
	if target == null:
		hud.show_message("상태이상 대상이 없습니다")
		return false
	if not _register_then_spend_skill(skill, _queue_player_attack.bind(target, _skill_attack_kind(skill), _resolve_status_skill.bind(skill.duplicate(true), target), _skill_motion_duration(skill), false, SKILL_RULES.range_pixels(skill))): return false
	_break_invisibility()
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

func _try_trigger_passives(trigger_name: String, target: TwilightMonster, attack_kind: String="melee", main_target: bool=true, by_spell: bool=false) -> void:
	if trigger_name=="on_hit" and hp>0:
		option_awakening.combat.on_hit(target,attack_kind,main_target,by_spell)
		if main_target: totem_combat.on_hit(target,attack_kind,by_spell)
	if trigger_name=="on_hit" and hp>0:PATCH523_EQUIPMENT_COMBAT.on_hit(self,target,attack_kind,main_target,by_spell)
	if trigger_name=="on_hit":skill_awakening.on_successful_hit(target)
	if original_skills != null: original_skills.trigger(trigger_name, target, {}, original_skills.attack_context(attack_kind, by_spell, true, main_target))
	for skill: Dictionary in _non_original_skill_rows():
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
				_deal_successful_player_hit(target, maxi(1, int(skill.get("power", 1))), false,attack_kind,true,true)
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
				# Publish new HP/MP limits immediately, but coalesce the full sheet
				# in the UI process phase instead of blocking a monster physics hit.
				hud.update_player(level, hp, _effective_max_hp(), mp, _effective_max_mp(), experience, exp_need, gold)
				stat_hud_refresh_pending = true
			_:
				continue
		var cooldown: float = SKILL_RULES.cooldown_seconds(skill) * _skill_cooldown_factor()
		if cooldown > 0.0:
			skill_cooldowns[skill_name] = cooldown
		hud.append_log("%s 패시브 발동" % skill_name)

func _rebuild_skill_record_index() -> void:
	# Keep first-match name/ID precedence of the former linear scan. Tests and
	# migration adapters may replace skills_db with another Array at runtime.
	skill_record_index.clear()
	non_original_skill_rows.clear()
	for value: Variant in skills_db:
		if not value is Dictionary: continue
		var record: Dictionary = value
		if not record.get("origin","") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]:non_original_skill_rows.append(record)
		for key: String in [str(record.get("name", "")), str(record.get("id", ""))]:
			if not skill_record_index.has(key):
				skill_record_index[key] = record
	if original_skills != null:
		for alias: String in original_skills.catalog.by_name:
			var id: String = str(original_skills.catalog.by_name[alias])
			if not skill_record_index.has(alias) and skill_record_index.has(id): skill_record_index[alias] = skill_record_index[id]
	indexed_skills_db = skills_db
	indexed_skills_count = skills_db.size()

func _ensure_skill_record_index() -> void:
	if not is_same(indexed_skills_db, skills_db) or indexed_skills_count != skills_db.size():
		_rebuild_skill_record_index()

func _skill_record(skill_name: String) -> Dictionary:
	if skill_name.begins_with("guardian:"):return growth.guardian_skill_record(skill_name)
	_ensure_skill_record_index()
	return skill_record_index.get(skill_name, {})

func _cast_job_skill_input(skill_name: String) -> void:
	if MAP_LOADING.busy(self): return
	await _cast_job_skill_impl(skill_name,true,true)


func _cast_job_skill(skill_name: String, manual: bool = true) -> bool:
	return call("_cast_job_skill_impl",skill_name,manual,false)


func _cast_job_skill_impl(skill_name: String, manual: bool, loading: bool) -> bool:
	if death_recovery.blocked(): return false
	if skill_name.begins_with("guardian:"):
		var response: Dictionary=growth.execute("guardian_cast",skill_name.trim_prefix("guardian:"),1,int(growth.state.revision))
		hud.show_message(str(response.message));return bool(response.ok)
	var skill: Dictionary = _skill_record(skill_name)
	if skill.get("origin", "") in ["LINEAGEM_20250617","LINEAGEM_CURRENT_LOCAL_20261029","OFFICIAL_REFERENCE_20261029"]:
		if loading: return await original_skills.cast_loading(skill,manual)
		return original_skills.cast(skill,manual)
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
			if loading: success = await _cast_job_teleport_impl(skill,true)
			else: success = _cast_job_teleport_skill(skill)
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
		# Damage/status casts only spend MP/ammo and queue a motion marker.
		# Buffs, healing and teleport still publish the complete derived sheet.
		if effect in ["damage", "turnUndead", "charge", "stun", "silence", "poison", "bleed", "hold", "fear"]:
			_refresh_combat_hud()
			if int(skill.get("ammo_per_hit", 0)) > 0 and hud.has_method("set_quick_items"):
				hud.call("set_quick_items", inventory)
		else:
			_update_hud()
	return success

func _spend_skill_mp(skill: Dictionary) -> bool:
	if patch523_npc_spells.blocks("CannotCastSkill") or (patch523_npc_spells.blocks("CannotCastSpell") and _skill_attack_kind(skill) == "magic"): return false
	var mp_cost: int = maxi(0, int(skill.get("mp", 0)))
	if mp < mp_cost:
		hud.show_message("MP가 부족합니다")
		return false
	var required_ammo: int = maxi(0, int(skill.get("ammo_per_hit", 0))) * maxi(1, int(skill.get("hits", 1)))
	var ammo_key: String = _skill_ammo_name()
	var source_record: Dictionary = _find_catalog_item_record(ammo_key)
	var source_ammo: bool = source_record.get("source")=="twilight-shop523-ammo"
	if required_ammo>0:
		var native: Dictionary=load("res://scripts/loot/current523_native_stack.gd").call("consume_ammo",self,ammo_key,required_ammo,mp_cost)
		if native.get("handled",false):
			if not native.get("ok",false) or not native.get("saved",false) or native.get("consumed")!=required_ammo:
				hud.show_message(str(native.get("reason","원본 스킬 탄약·MP 연결 대기")));return false
			_refresh_ammo_counters();return true
	var old_mp: int = mp
	var old_ammo: int = int(inventory.get(ammo_key,0))
	if required_ammo>0 and source_ammo and (SOURCE_AMMO.definition(source_record).is_empty() or old_ammo<required_ammo or not _ammo_worn(ammo_key,true)):
		hud.show_message("원본 탄약 정체·수량·착용 조건 미충족")
		return false
	mp -= mp_cost
	if required_ammo > 0:
		inventory[ammo_key] = old_ammo - required_ammo
		# Coalesced background save, not one full save per skill (option A).
		if source_ammo: _request_general_save()
	return true

## M100 data for the original quickslot count: only a skill that consumes ammo has the
## equivalent of the original BulletID mapping. The count is the ammo the skill would spend.
func _quickslot_ammo_source(entry: Dictionary) -> Dictionary:
	if str(entry.get("kind", "")) != "skill": return {}
	var skill: Dictionary = _skill_record(str(entry.get("skill_id", entry.get("id", ""))))
	# 보고서2 R1: a stackable (충전형) spell shows its stored charges, not ammo.
	var charges: int = original_skills.stackable.count_for(skill) if original_skills != null and not skill.is_empty() else -1
	if charges >= 0: return {"ammo_count": charges, "stack_count": charges, "can_use_without_ammo": true}
	if skill.is_empty() or int(skill.get("ammo_per_hit", 0)) <= 0: return {}
	return {"ammo_count": int(inventory.get(_skill_ammo_name(), 0)), "can_use_without_ammo": false}

func _skill_ammo_name() -> String:
	return _current_ammo_name() if _weapon_ammo_family()=="화살" else _skill_arrow_ammo_name()


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
	attacker.set_meta("title523_direct_life",attacker.life_id)
	attacker.take_damage(reflected)
	if not attacker.dead: attacker.set_meta("title523_direct_life",-1)
	return true


func _player_element_resistance(element_name: String) -> float:
	if ELEMENT_RULES.channel(element_name) == "physical":
		return 0.0
	var key: String = "element_resist_" + element_name
	var total: float = float(_active_skill_buff_total(key) + _passive_skill_total(key)) + _active_item_buff_percent(key)
	for record: Dictionary in _all_equipped_records():
		total += float(record.get(key, 0.0))
		# Patch-523's whole-element axis contains the four source elements.
		# Legacy host records retain their established wider channel scope.
		if not bool(record.get("equipment523_synthetic",false)) or element_name in EQUIPMENT523_COMBAT.CHANNELS:
			total += float(record.get("element_resist_all",0.0))
	return clampf(total, -80.0, 85.0)

func _normal_attack_element(resolved_weapon: Variant = null) -> String:
	if _active_skill_buff_total("element_bonus_holy") > 0:
		return "holy"
	var weapon: Dictionary = resolved_weapon if resolved_weapon is Dictionary else _equipped_weapon_record()
	var enchanted: String = str(consumable_service.call("weapon_element", weapon))
	if enchanted != "":
		return ELEMENT_RULES.channel(enchanted)
	return ELEMENT_RULES.channel(str(weapon.get("element", "physical")))

func _source_elemental_flat_damage(target: TwilightMonster, by_spell: bool=false) -> int:
	if target==null:return 0
	var settings: Dictionary=PATCH523_ENHANCE.policy()
	if by_spell and settings.get("source_elemental_scope","")!="all_successful_hits":return 0
	var result: int=0
	for channel: String in ["fire","water","wind","earth"]:
		var amount: float=maxf(0.0,_equipment_inven_sum("source_elemental_flat_"+channel))
		if amount<=0:continue
		var resistance: float=clampf(target.elemental_resistance_percent(channel),float(settings.get("source_elemental_resistance_min",-80)),float(settings.get("source_elemental_resistance_max",85)))
		var adjusted: float=amount*(1.0-resistance/100.0)
		result+=maxi(0,int(floor(adjusted)) if settings.get("source_elemental_rounding","")=="floor" else int(round(adjusted)))
	return result

func _elemental_damage_to_monster(raw_damage: int, element_name: String, target: TwilightMonster) -> int:
	var channel: String = ELEMENT_RULES.channel(element_name)
	if channel == "physical" or target == null:
		return maxi(1, raw_damage)
	var bonus: float = float(_active_skill_buff_total("element_bonus_" + channel) + _passive_skill_total("element_bonus_" + channel))
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("element_bonus_" + channel, 0.0))
	var modified: int = ELEMENT_RULES.damage_with_bonus(raw_damage, bonus)
	var source_element: int=int({"fire":1,"water":2,"wind":3,"earth":4}.get(channel,0))
	if source_element>0:modified+=int(combinations.amount("ElementalDamage",source_element))
	if channel == "holy" and target.is_undead():
		modified = ELEMENT_RULES.damage_with_bonus(modified, float(_active_skill_buff_total("holy_vs_undead")))
	return ELEMENT_RULES.damage_after_resistance(modified, target.elemental_resistance_percent(channel) - _equipped_numeric_sum("equipment523_element_pierce_" + channel))

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
	_deal_successful_player_hit(target, damage, false, attack_kind, true, false, {}, false, original_skills.attack_context(attack_kind,false,true) if original_skills != null else {})
	_try_trigger_passives("on_hit", target,attack_kind,true,false)
	hud.append_log("%s 추가타 +%d 피해" % [target.monster_name, damage])

func _cast_job_turn_undead(skill: Dictionary) -> bool:
	var target: TwilightMonster = _skill_target(SKILL_RULES.range_pixels(skill))
	if target == null:
		hud.show_message("시야 내 언데드 대상이 없습니다")
		return false
	if not target.is_undead():
		hud.show_message("턴 언데드는 언데드에게만 사용할 수 있습니다")
		return false
	if not _register_then_spend_skill(skill, _queue_player_attack.bind(target, "magic", _resolve_turn_undead.bind(skill.duplicate(true), target), _skill_motion_duration(skill), false, SKILL_RULES.range_pixels(skill))):
		return false
	_break_invisibility()
	return true

func _resolve_turn_undead(skill: Dictionary, target: TwilightMonster) -> void:
	var chance: float = clampf(_player_magic_hit_chance(target) + float(skill.get("magic_hit_bonus", 0.0)), 0.05, 0.99)
	if rng.randf() >= chance:
		target.show_miss()
		hud.append_log("%s · %s 마법 명중 실패" % [str(skill.get("name", "")), target.monster_name])
	else:
		var target_name: String = target.monster_name
		hud.append_log("%s · %s 언데드 즉사!" % [str(skill.get("name", "")), target_name])
		_deal_successful_player_hit(target, target.hp, false,"magic",true,true)
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
		if not _register_then_spend_skill(skill, _queue_damage_skill.bind(skill, target, 100.0)):
			return false
		_break_invisibility()
		return true
	var path: PackedVector2Array = find_world_path(source, target.global_position)
	if path.is_empty():
		hud.show_message("돌진 경로 준비 중 · 잠시 후 다시 시도하세요" if _native_route_pending() else "돌진 경로를 찾을 수 없습니다")
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
	if not _register_then_spend_skill(skill, _queue_damage_skill.bind(skill, target, SKILL_RULES.range_pixels(skill))):
		return false
	_break_invisibility()
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
		hit_chance = _ranged_hit_chance(target)
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
	var skill_name: String = str(skill.get("name", ""))
	var source_spell: int = card_collections.native_spell_id(skill)
	var transform_flat: int = int(round(_transformation_skill_bonus(skill_name, "damage_flat")+source_active_card_spell_bonus(source_spell,"damage")))
	var transform_multiplier: float = 1.0 + clampf(_transformation_skill_bonus(skill_name, "damage_pct"), 0.0, 200.0) / 100.0
	var transform_accuracy: float = clampf(_transformation_skill_bonus(skill_name, "accuracy_pct") / 100.0, 0.0, 0.90)
	var volley: Dictionary = skill.get("_volley_runtime", {})
	var total_damage: int = int(volley.get("total_damage", 0))
	if total_damage <= 0:
		total_damage = maxi(1, int(round(float(power + stat_damage + transform_flat + rng.randi_range(-4, 6)) * transform_multiplier)))
		volley["total_damage"] = total_damage
	var element_name: String = ELEMENT_RULES.channel(str(skill.get("element", "physical")))
	var style: String = "magic" if magic_style else ("ranged" if ranged_style else "melee")
	var chain_index: int = 0
	for victim: TwilightMonster in targets:
		var victim_hit_chance: float = hit_chance
		if magic_style:
			victim_hit_chance = _player_magic_hit_chance(victim)
		elif ranged_style:
			victim_hit_chance = _ranged_hit_chance(victim)
		else:
			victim_hit_chance = _melee_hit_chance(victim)
		victim_hit_chance = clampf(victim_hit_chance + transform_accuracy, 0.05, 0.95)
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
			if style != "magic":
				# A fresh size roll per successful physical skill hit; never on spells.
				damage += _roll_weapon_damage(victim)
			var critical: bool = rng.randf() < _critical_chance(crit_rate, victim.critical_resistance)
			if critical:
				damage = _player_critical_damage(damage, style)
			damage = _elemental_damage_to_monster(damage, element_name, victim)
			_deal_successful_player_hit(victim, damage, critical,style,victim==target,true)
			_try_trigger_passives("on_hit", victim,style,victim==target,true)
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
	amount = growth.magic_healing(amount)
	amount=card_collections.magic_heal(amount)
	var before: int = hp
	apply_patch523_healing(amount,false)
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
	return call("_cast_job_teleport_impl",skill,false)


func _cast_job_teleport_impl(skill: Dictionary, loading: bool) -> bool:
	if patch523_npc_spells.blocks("CannotTeleport"): return false
	if growth.travel.enabled():
		growth.travel.open({"kind":"job","name":str(skill.name)})
		return false
	if field_map is OriginalPlayableField and field_map.uses_original_gameplay_rules() and not bool((field_map as OriginalPlayableField).definition.rules.get("teleportable",0)) and not item_possession523.ignores_no_teleport():
		hud.show_message("원본 규칙상 순간이동 제한 지역입니다")
		return false
	for _attempt: int in range(100):
		var candidate: Vector2 = player.global_position + Vector2(rng.randf_range(-700.0, 700.0), rng.randf_range(-500.0, 500.0))
		var safe_only: bool = bool(skill.get("safe_zone_only", false))
		if _teleport_landing_clear(candidate) if safe_only else _is_walkable_world(candidate):
			if loading:
				var task: Callable = func() -> Dictionary:
					return {"ok":_commit_job_teleport(skill,candidate)}
				var result: Dictionary = await travel_map_point(candidate,task)
				return result.get("ok",false)
			return _commit_job_teleport(skill,candidate)
	hud.show_message("안전하게 이동할 위치를 찾지 못했습니다")
	return false

func _commit_job_teleport(skill: Dictionary,destination: Vector2) -> bool:
	if not _spend_skill_mp(skill): return false
	player.global_position = destination
	player.clear_click_path()
	player.camera.reset_smoothing()
	refresh_map_after_jump()
	hud.show_message(str(skill.get("name","텔레포트")))
	return true


func _active_skill_buff_total(key: String) -> int:
	var total: int = int(original_skills.stat("hp")) if original_skills != null and key == "hp" else 0
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

# Card acquisition is the only debug-only action. Real pack ownership/cost is
# not modelled yet; fusion is available whenever saved duplicate cards exist.
func _on_card_pack_draw_requested(category: String) -> void:
	if not preload("res://scripts/boot/build_flags.gd").playtest():
		return
	if _option_awakening_busy(): return
	if hud.has_method("is_card_reveal_busy") and bool(hud.call("is_card_reveal_busy")):
		return
	var cards_before: Dictionary = card_draw_fusion.export_state()
	var roll_before: int = card_draw_fusion.rng.state
	var result: Dictionary = card_draw_fusion.draw_pack(category)
	if not bool(result.get("ok", false)):
		hud.show_message(str(result.get("error", "뽑기 실패")))
		return
	var grades: Dictionary = {"고급": 0, "희귀": 0, "영웅": 0, "전설": 0}
	for raw: Variant in result.get("results", []) as Array:
		if raw is Dictionary:
			var grade: String = str((raw as Dictionary).get("grade", ""))
			if grades.has(grade):
				grades[grade] = int(grades[grade]) + 1
	var message: String = "%s 최상급팩 11장 · 고급 %d / 희귀 %d / 영웅 %d / 전설 %d" % [
		category, int(grades["고급"]), int(grades["희귀"]),
		int(grades["영웅"]), int(grades["전설"])
	]
	if _save_game(true) != OK:
		card_draw_fusion.import_state(cards_before)
		card_draw_fusion.rng.state = roll_before
		_invalidate_equipment_static()
		hud.show_message("뽑기 저장 실패 · 카드 획득 내역을 복구했습니다")
		return
	_update_hud()
	hud.show_message(message)
	hud.append_log(message)
	hud.call("set_card_draw_fusion_result", category, message)
	hud.call("present_card_reveal", category, result, false)

const SOURCE_FUSION_POINTS=preload("res://scripts/cards/source_fusion_points523.gd")

## Display lookup is small and data-only; no card list or draw on a menu-open.
func source_fusion_progress(category:String,grade:String)->Dictionary:
	var count:int=int(card_draw_fusion.pity.get(category,{}).get(grade,0))
	var available:bool=SOURCE_FUSION_POINTS.supported_threshold(category,grade)
	var active:bool=card_draw_fusion.original_points_active(category,grade)
	return {"source":available,"known":available or active,"count":count,"max":SOURCE_FUSION_POINTS.LIMIT,"pending":active and count>=SOURCE_FUSION_POINTS.LIMIT}

func claim_source_fusion_reward(category:String,grade:String)->Dictionary:
	if _option_awakening_busy() or hud.is_card_reveal_busy():return SOURCE_FUSION_POINTS.result(false,"다른 카드 동작 완료 후 다시 시도하세요")
	if not card_draw_fusion.original_points_active(category,grade) or card_draw_fusion.pity.get(category,{}).get(grade,0)!=SOURCE_FUSION_POINTS.LIMIT:return SOURCE_FUSION_POINTS.result(false,"아직 합성 시도 보상 포인트가 부족합니다")
	var verified:Dictionary=SOURCE_FUSION_POINTS.reward(self,category,grade)
	if not verified.get("ok",false):return SOURCE_FUSION_POINTS.result(false,"원본 합성 포인트 지급 자료가 없습니다 · 포인트 보존")
	var before:Dictionary=card_draw_fusion.export_state()
	var old_rng:int=card_draw_fusion.rng.state
	var selected:Dictionary=SOURCE_FUSION_POINTS.choose(verified.draw,card_draw_fusion.rng.randi_range(0,SOURCE_FUSION_POINTS.WEIGHT-1))
	if selected.is_empty():card_draw_fusion.rng.state=old_rng;return SOURCE_FUSION_POINTS.result(false,"원본 보상 후보 없음 · 포인트 보존")
	var card:Dictionary=selected.record
	var receipt:Dictionary={"kind":"source523_fusion_point_reward","card_id":selected.source_id,"cannot_swap":bool(card.get("source_swap_out_disabled",false)),"purchase_id":verified.lane.offer,"pool_id":verified.lane.pool}
	var awarded:Dictionary=card_draw_fusion.receive_source_card(category,card,receipt)
	if not awarded.get("ok",false) or not card_draw_fusion.claim_original_points(category,grade):
		card_draw_fusion.import_state(before);card_draw_fusion.rng.state=old_rng
		return SOURCE_FUSION_POINTS.result(false,"원본 카드 지급 불가 · 포인트 보존")
	var saved:Error=_save_game(true,{"card_draw_fusion":card_draw_fusion.export_state()})
	if saved!=OK:
		card_draw_fusion.import_state(before);card_draw_fusion.rng.state=old_rng
		return SOURCE_FUSION_POINTS.result(false,"합성 시도 보상 저장 실패 · 포인트와 카드 상태 보존")
	deferred_save.cancel()
	var message:String="합성 시도 보상 · %s %s" % [category,str(card.get("name",""))]
	_update_hud()
	hud.show_message(message);hud.append_log(message)
	hud.set_card_draw_fusion_result(category,message)
	hud.present_card_reveal(category,awarded,false)
	return {"ok":true,"message":message,"reward":awarded.results[0],"purchase_id":verified.lane.offer,"pool_id":verified.lane.pool}

func _on_card_fusion_requested(category: String, grade: String, count: int = 1) -> void:
	if _option_awakening_busy(): return
	if hud.has_method("is_card_reveal_busy") and bool(hud.call("is_card_reveal_busy")):
		return
	if card_draw_fusion.original_points_active(category,grade) and card_draw_fusion.pity.get(category,{}).get(grade,0)>=SOURCE_FUSION_POINTS.LIMIT:
		hud.show_message("합성 시도 보상을 먼저 받으세요 · 재료 보존")
		return
	var tj_before: Dictionary = tj_coupons.core.export_state()
	var cards_before: Dictionary = card_draw_fusion.export_state()
	var roll_before: int = card_draw_fusion.rng.state
	var batch: bool = count > 1
	var original_points:bool=SOURCE_FUSION_POINTS.supported_threshold(category,grade) and SOURCE_FUSION_POINTS.reward(self,category,grade).get("ok",false)
	var result: Dictionary = card_draw_fusion.fuse_many(category, grade, count, original_points) if batch else card_draw_fusion.fuse(category, grade, original_points)
	if not bool(result.get("ok", false)):
		hud.show_message(str(result.get("error", "합성 실패")))
		return
	var message: String = ""
	if batch:
		message = "%s %s 합성 %d회 · 성공 %d / 실패 %d" % [
			category, grade, int(result.get("attempts", 0)), int(result.get("success_count", 0)),
			int(result.get("attempts", 0)) - int(result.get("success_count", 0))
		]
		var pity_count: int = (result.get("results", []) as Array).filter(func(entry: Variant) -> bool: return entry is Dictionary and bool((entry as Dictionary).get("pity_reward", false))).size()
		if pity_count > 0:
			message += " · 누적 실패 보상 %d장" % pity_count
	else:
		var card: Dictionary = result.get("result", {}) as Dictionary
		var outcome: String = "성공" if bool(result.get("success", false)) else "실패"
		message = "%s %s 합성 %s · %s(%s)" % [
			category, grade, outcome, str(card.get("name", "")), str(card.get("grade", ""))
		]
		var pity_card: Dictionary = result.get("pity_reward", {}) as Dictionary
		if not pity_card.is_empty():
			message += " · 누적 실패 보상: %s" % str(pity_card.get("name", ""))
	var before_content: Dictionary = unconfirmed523.state.duplicate(true)
	# Original BuffCardDeck IDs: Polymorph1, MagicDoll2, HolyStuff98.
	var source_deck: int = int({"변신":1,"마법인형":2,"성물":98}.get(category,0))
	var attempts: int = int(result.get("attempts",0)) if batch else 1
	if source_deck > 0 and attempts > 0:
		unconfirmed523.record_event("card_compose",{"source_id":source_deck,"amount":attempts,"event_id":"compose:%d:%d"%[source_deck,Time.get_ticks_usec()]})
	tj_coupons.capture_fusion(result)
	if _save_game(true) != OK:
		unconfirmed523.state = before_content
		tj_coupons.core.state=tj_before.duplicate(true)
		card_draw_fusion.import_state(cards_before)
		card_draw_fusion.rng.state = roll_before
		_invalidate_equipment_static()
		hud.show_message("합성 저장 실패 · 중복 카드 재료를 복구했습니다")
		return
	if source_deck > 0 and attempts > 0: routines.record("card_compose",{"deck":source_deck,"amount":attempts})
	_update_hud()
	hud.show_message(message)
	hud.append_log(message)
	hud.call("set_card_draw_fusion_result", category, message)
	hud.call("present_card_reveal", category, result, true)

func _option_awakening_busy() -> bool:
	return option_awakening_transaction_busy or (hud.has_method("is_option_awakening_busy") and bool(hud.call("is_option_awakening_busy")))

func _on_option_awakening_open_requested(category: String, target_id: String) -> void:
	if _option_awakening_busy(): return
	if hud.has_method("is_card_reveal_busy") and bool(hud.call("is_card_reveal_busy")): return
	hud.call("set_option_awakening_view", option_awakening.view(category, target_id))

func _on_option_awakening_feed_requested(category: String, target_id: String, materials: Dictionary) -> void:
	if _option_awakening_busy(): return
	option_awakening_transaction_busy = true
	var result: Dictionary = option_awakening.feed(category, target_id, materials)
	option_awakening_transaction_busy = false
	var snapshot: Dictionary = result.get("snapshot", option_awakening.view(category, target_id))
	hud.call("set_option_awakening_view", snapshot)
	if not bool(result.get("ok", false)):
		hud.show_message(str(result.get("error", "각성 재료를 적용하지 못했습니다")))
		return
	_update_hud()
	var message: String = "옵션 각성 경험치 %d / %d · 중복 카드 재료 적용 완료" % [int(snapshot.get("experience", 0)), int(snapshot.get("required_experience", 100))]
	if int(snapshot.get("source_exp_scale",1))==100:
		var formatter: Script=preload("res://scripts/cards/native_option_economy.gd")
		message="옵션 각성 경험치 %s / %s · 소모 %d 아데나" % [formatter.format_units(int(snapshot.experience)),formatter.format_units(int(snapshot.required_experience)),int(result.get("consumed_gold",0))]
	hud.show_message(message)
	hud.append_log(message)

func _on_option_awakening_attempt_requested(category: String, target_id: String) -> void:
	if _option_awakening_busy(): return
	option_awakening_transaction_busy = true
	var result: Dictionary = option_awakening.awaken(category, target_id)
	option_awakening_transaction_busy = false
	var snapshot: Dictionary = result.get("snapshot", option_awakening.view(category, target_id))
	hud.call("set_option_awakening_view", snapshot)
	if not bool(result.get("ok", false)):
		hud.show_message(str(result.get("error", "옵션 각성을 진행하지 못했습니다")))
		return
	_update_hud()
	# The runtime commits gold, experience, outcome and RNG together before this point.
	_sync_option_awakening_auras()
	var card: Dictionary = snapshot.get("target_record", {})
	var success: bool = bool(result.get("success", false))
	var message: String = "%s 옵션 각성 %s" % [str(card.get("name", "")), "성공" if success else "실패"]
	if not success:
		if int(result.get("source_exp_scale",1))==100:message+=" · 원본 경험치 "+preload("res://scripts/cards/native_option_economy.gd").format_units(int(result.source_refunded_experience))+" 유지"
		else:message += " · 경험치 %d 환급" % int(result.get("refunded_experience", 0))
	hud.append_log(message)
	var presentation: Dictionary = result.duplicate(true)
	presentation["category"] = category
	presentation["message"] = message
	presentation["bonus_lines"] = snapshot.get("applied_options", []) if success else []
	hud.call("present_option_awakening_result", card, presentation, presentation_settings)

func _equip_catalog(category: String, record: Dictionary) -> void:
	if death_recovery.blocked(): return
	if category == "아이템":
		_equip_or_acquire_item(record)
		return
	if not equipped_catalog.has(category):
		return
	if BASE508.native(record):
		record=BASE508.canonical(record)
		if record.get("source_snapshot","")=="patch523" and not _patch523_card_available(category,record):
			hud.show_message("카드 보유·원본 서버·기간 조건 확인이 필요합니다")
			return
	var source_transaction: bool=BASE508.native(record) or (record.is_empty() and BASE508.native(equipped_catalog[category]))
	if expedition_local.reserved(CARD_DRAW_FUSION.card_id(record)):
		hud.show_message("탐험·정산 대기 기록에 사용 중인 카드는 소환할 수 없습니다.")
		return
	var old_max_hp: int = _effective_max_hp()
	if source_transaction:
		# Evaluate both primary/secondary effects together, then persist caps and
		# the selection before publishing any UI, visuals or live-state changes.
		var previous: Dictionary=equipped_catalog
		var previous_vitals: Dictionary={"hp":hp,"mp":mp}
		var previous_buffs: Dictionary=active_skill_buffs.duplicate(true)
		var next: Dictionary=previous.duplicate(true);next[category]=record.duplicate(true)
		equipped_catalog=next;_invalidate_equipment_static()
		var next_max_hp: int=_effective_max_hp()
		var next_max_mp: int=_effective_max_mp()
		var staged_hp: int=mini(int(previous_vitals.hp)+maxi(0,next_max_hp-old_max_hp),next_max_hp)
		var staged_mp: int=mini(int(previous_vitals.mp),next_max_mp)
		equipped_catalog=previous;_invalidate_equipment_static()
		_restore_card_selection_preview(previous_vitals,previous_buffs)
		if _save_card_selection(true,{"equipped_catalog":next,"inventory":inventory.duplicate(true),"item_instances":item_instances.duplicate(true),"card_option_awakening":option_awakening.export_state(),"hp":staged_hp,"mp":staged_mp})!=OK:
			hud.show_message("저장 실패 · 기존 카드·추가 슬롯·HP/MP 보존")
			return
		equipped_catalog=next;hp=staged_hp;mp=staged_mp
	else:equipped_catalog[category] = record.duplicate(true)
	_invalidate_equipment_static()
	if category == "마법인형" or category == "성물":
		hp_recovery_elapsed = 0.0
		mp_recovery_elapsed = 0.0
	if category == "변신":
		var transform_usec: int = Time.get_ticks_usec()
		_apply_transform_visual(record)
		_perf_log("변신 교체", transform_usec)
		var held_weapon_reason: String = POLYMORPH_WEAPON_LIMIT.attack_reason(self)
		if not held_weapon_reason.is_empty(): hud.append_log(held_weapon_reason + " · 공격하려면 무기를 교체하세요")
	elif category == "마법인형":
		_apply_doll_visual(record)
	elif category == "성물":
		_apply_relic_visual(record)
	_refresh_speed_modifiers()
	var new_max_hp: int = _effective_max_hp()
	if not source_transaction and new_max_hp > old_max_hp:
		hp += new_max_hp - old_max_hp
	hp = mini(hp, new_max_hp)
	mp = mini(mp, _effective_max_mp())
	hud.show_message("%s 장착: %s" % [category, str(record.get("name", ""))])
	hud.append_log("%s 적용 · %s" % [category, str(record.get("name", ""))])
	_update_hud()

func _patch523_card_available(category: String,record: Dictionary) -> bool:
	if not card_draw_fusion.owned.get(category,{}).get(CARD_DRAW_FUSION.card_id(record),false):return false
	option_awakening._sync_native_context()
	return option_awakening.core.native_material_available(record)

func _equip_reference_in_slot(reference: String, target: String) -> void:
	var parts: PackedStringArray = reference.split("@@@")
	if parts.size() != 2 or not item_instances.has(parts[1]): return
	var physical: Dictionary = item_instances[parts[1]]
	if str(physical.get("name","")) != parts[0] or int(inventory.get(parts[0],0)) < 1: return
	var record: Dictionary = physical.get("record",_find_catalog_item_record(parts[0]))
	if RETIRED_ITEMS.record(record):hud.show_message(RETIRED_ITEMS.REASON);return
	if quest_item_provider.equipment_owner.activate(self,parts[1],target):return
	_equip_or_acquire_item(record,false,parts[1],target)
	_request_deferred_save()

func _equip_or_acquire_item(record: Dictionary, add_to_inventory: bool = true, requested_id: String = "", requested_slot: String = "") -> void:
	if RETIRED_ITEMS.record(record) or (not requested_id.is_empty() and RETIRED_ITEMS.record(item_instances.get(requested_id,{}).get("record",{}))):hud.show_message(RETIRED_ITEMS.REASON);return
	if not add_to_inventory and requested_id.is_empty() and quest_item_provider.equipment_owner.requires_selected(self,str(record.get("name",""))):hud.show_message("실제 장비 개체를 선택하세요");return
	if not add_to_inventory and quest_item_provider.equipment_owner.activate(self,requested_id,requested_slot):return
	if bool(record.get("source_pending_use",false)):
		hud.show_message("원본 보상 보관 중 · 장착 기능 연결 대기")
		return
	# A physical item with a source ID outranks the legacy name-only lookup.
	if requested_id != "" and item_instances.has(requested_id):
		var pinned: Variant = (item_instances[requested_id] as Dictionary).get("record", {})
		if pinned is Dictionary and not (pinned as Dictionary).is_empty():
			record = pinned as Dictionary
	var item_name: String = str(record.get("name", "아이템"))
	if add_to_inventory:
		inventory[item_name] = int(inventory.get(item_name, 0)) + 1
		if growth.source523.material({"name":item_name,"record":record}):
			var symbol_physical_id: String = str(next_item_instance_id)
			while item_instances.has(symbol_physical_id):
				next_item_instance_id += 1
				symbol_physical_id = str(next_item_instance_id)
			next_item_instance_id += 1
			item_instances[symbol_physical_id] = {"name":item_name,"level":0,"record":NATIVE_FIELDS.full(record).duplicate(true)}
		# Generated gear without static catalog rows must also acquire a physical
		# ID and retain its schema for reload, equip and all scroll types.
		if _enhancement_kind_for_record(record) != "" and _find_catalog_item_record(item_name).is_empty():
			var new_id: String = str(next_item_instance_id)
			while item_instances.has(new_id):
				next_item_instance_id += 1
				new_id = str(next_item_instance_id)
			next_item_instance_id += 1
			item_instances[new_id] = {"name":item_name, "level":0, "element":"", "element_level":0, "record":NATIVE_FIELDS.full(record).duplicate(true)}
	var effective_use: Dictionary = _patch523_use_record(item_name + ("@@@"+requested_id if not requested_id.is_empty() else ""))
	var source_use_reason: String = PATCH523_ITEM_USE.reason(effective_use if not effective_use.is_empty() else record,level,BASE508.source_class_id(job_class))
	if not source_use_reason.is_empty():
		hud.show_message(source_use_reason)
		return
	var source_slot: String = str(record.get("slot", ""))
	var native_rejection: String = LOOT_DROP.PATCH523_DROPS.equipment_error(record, job_class, level, int(ui_preferences.get("patch523_source_clock_offset_minutes",540)))
	if not native_rejection.is_empty():
		hud.show_message(native_rejection)
		return
	if source_slot == "weapon" and not _weapon_allowed_for_job(record, job_class):
		var weapon_type: String = _normalized_weapon_type(str(record.get("type", "")))
		hud.show_message("%s 클래스는 %s 무기를 착용할 수 없습니다" % [job_class, weapon_type])
		hud.append_log("착용 제한 · %s / %s · 아이템은 인벤토리에 보관" % [job_class, item_name])
		hud.refresh_inventory(inventory)
		_update_hud()
		return
	var polymorph_weapon_reason: String = POLYMORPH_WEAPON_LIMIT.equip_reason(self, record)
	if not polymorph_weapon_reason.is_empty():
		hud.show_message(polymorph_weapon_reason)
		hud.append_log("착용 제한 · %s · 아이템은 인벤토리에 보관" % polymorph_weapon_reason)
		hud.refresh_inventory(inventory)
		_update_hud()
		return
	var equip_slot: String = _equipment_slot_for_record(record)
	if not requested_slot.is_empty():
		var compatible: bool = equip_slot == requested_slot
		for pair: Array in [["ring1","ring2"],["earring1","earring2"],["seal1","seal2"]]:
			if equip_slot in pair and requested_slot in pair: compatible = true
		if not compatible:
			hud.show_message("해당 부위에 착용할 수 없는 장비입니다")
			return
		equip_slot = requested_slot
	if _is_offhand_record(record):
		equip_slot = "offhand"
		if not _can_equip_offhand(record):
			hud.show_message("%s 무기에는 방패를 착용할 수 없습니다" % _current_weapon_type())
			hud.append_log("방패 착용 불가 · %s + %s" % [_current_weapon_type(), item_name])
			hud.refresh_inventory(inventory)
			_update_hud()
			return
	var group_limit: String = preload("res://scripts/loot/current523_equip_group_limit.gd").reason(record, equip_slot, equipped_items)
	if not group_limit.is_empty():
		hud.show_message(group_limit)
		hud.append_log("착용 제한 · %s · 아이템은 인벤토리에 보관" % group_limit)
		hud.refresh_inventory(inventory)
		_update_hud()
		return
	if equip_slot != "" and EQUIPMENT_SLOT_ORDER.has(equip_slot):
		var old_max_hp: int = _effective_max_hp()
		var selected_id: String = requested_id if requested_id != "" else _chosen_instance(item_name, true)
		if not item_instances.has(selected_id) or str((item_instances[selected_id] as Dictionary).get("name", "")) != item_name:
			hud.show_message("착용 가능한 장비 개체가 없습니다")
			return
		if _is_instance_equipped(selected_id):
			hud.show_message("이미 착용한 장비 개체입니다")
			return
		if record.get("source_m_native_item",false) and not (item_instances[selected_id] as Dictionary).has("record"):
			item_instances[selected_id]["record"] = record.duplicate(true)
		equipped_items[equip_slot] = record.duplicate(true)
		equipped_items[equip_slot]["instance_id"] = selected_id
		if equip_slot == "weapon":
			_enforce_shield_weapon_compatibility(false)
		_invalidate_equipment_static()
		_refresh_speed_modifiers()
		var new_max_hp: int = _effective_max_hp()
		if new_max_hp > old_max_hp:
			hp += new_max_hp - old_max_hp
		hp = mini(hp, new_max_hp)
		mp = mini(mp, _effective_max_mp())
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
	# PR122: explicit presentation-only source sharing; combat/catalog IDs remain distinct.
	# Mythic male Dark Elf/Gunner use their female source; both colored
	# Lance Masters use the ordinary transform:44 source with independent tints.
	if kind == "transform":
		var visual_donors: Dictionary = {"138":"139", "140":"141", "179":"44", "182":"44"}
		if visual_donors.has(source_id):
			var donor_id: String = str(visual_donors[source_id])
			var donor_metadata: Dictionary = directional_art.get("transform:" + donor_id, {})
			var donor_directional: String = str(donor_metadata.get("path", ""))
			if not donor_directional.is_empty() and preload("res://scripts/resources/retired_assets.gd").usable(donor_directional):
				return donor_directional
			for donor_record: Dictionary in catalog_db.get("변신", []):
				if str(donor_record.get("sourceId", "")) == donor_id:
					var donor_path: String = str(donor_record.get("image_path", ""))
					if preload("res://scripts/resources/retired_assets.gd").usable(donor_path): return donor_path
					break
	var key: String = "%s:%s" % [kind, source_id]
	var value: Variant = directional_art.get(key, {})
	if value is Dictionary:
		var meta: Dictionary = value as Dictionary
		var directional_path: String = str(meta.get("path", ""))
		if directional_path != "" and preload("res://scripts/resources/retired_assets.gd").usable(directional_path):
			return directional_path
	var fallback: String = str(record.get("image_path", ""))
	return fallback

func _current_transform_visual_record(saved: Dictionary) -> Dictionary:
	# Equipment saves retain their gameplay snapshot. Only presentation follows
	# the current catalog, including when an old save has no animation_profile.
	var source_id: String = str(saved.get("sourceId", ""))
	var saved_name: String = str(saved.get("name", ""))
	var current: Dictionary = {}
	var matches: int = 0
	for value: Variant in catalog_db.get("변신", []):
		if not value is Dictionary: continue
		var candidate: Dictionary = value as Dictionary
		var matched: bool = str(candidate.get("sourceId", "")) == source_id if not source_id.is_empty() else (not saved_name.is_empty() and str(candidate.get("name", "")) == saved_name)
		if matched:
			current = candidate
			matches += 1
	if matches != 1: return saved
	var visual: Dictionary = saved.duplicate(true)
	var presentation: Dictionary = current.duplicate(true)
	# A legacy name-only save still needs the canonical presentation identity
	# for direction donors and the transform's RUN/WALK policy. Never migrate
	# the persisted equipment record or its gameplay identity here.
	if source_id.is_empty(): visual["sourceId"] = presentation.get("sourceId", "")
	for property: String in ["animation_profile", "image_path"]:
		if presentation.has(property): visual[property] = presentation[property]
		else: visual.erase(property)
	return visual

func _apply_transform_visual(record: Dictionary) -> void:
	player.source_visual_context = _source_visual_context()
	if record.is_empty():
		player.clear_transform_visual()
		_sync_option_awakening_aura("변신")
		return
	var visual_record: Dictionary = _current_transform_visual_record(record)
	var path: String = _directional_image_path("transform", visual_record)
	var speed_multiplier: float = float(record.get("speed", 1.0))
	player.set_transform_visual(path, speed_multiplier, ANIMATION_CATALOG.for_record("transform", visual_record, path))
	if BASE508.native(visual_record):
		var selected: Dictionary = player.original_source_preview.source_selection_status
		if selected.get("status", "") == "selection_pending":
			hud.show_message("원본 변신 외형 선택 대기 · 캐릭터 직업과 성별을 확인하세요")
			hud.append_log("원본 변신 외형 선택 대기 · 직업/성별 문맥 필요")
	_sync_option_awakening_aura("변신")

func _apply_doll_visual(record: Dictionary) -> void:
	player.source_visual_context = _source_visual_context()
	doll_motion.configure(record, _directional_image_path("doll", record), $Companion, companion_sprite, player)
	doll_motion.set_presentation_hidden(bool(presentation_settings.hide_doll), $Companion, companion_sprite, player)
	_sync_option_awakening_aura("마법인형")

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
	player.source_visual_context = _source_visual_context()
	relic_motion.configure(record, relic_sprite, player, _drop_grade_color(str(record.get("grade", "일반"))))
	_sync_option_awakening_aura("성물")

func _sync_option_awakening_auras() -> void:
	for category: String in ["변신", "마법인형", "성물"]:
		_sync_option_awakening_aura(category)

func _sync_option_awakening_aura(category: String) -> void:
	var raw: Variant = equipped_catalog.get(category, {})
	var record: Dictionary = raw if raw is Dictionary else {}
	if BASE508.native(record):
		var old: Node2D = option_awakening_auras.get(category) as Node2D
		if is_instance_valid(old): old.call("set_awakened", false)
		var native_target: Node2D
		match category:
			"변신": native_target = player.original_source_preview
			"마법인형": native_target = doll_motion.native_actor
			"성물": native_target = relic_motion.native_actor
		var source_aura: Node2D = source_awakening_auras.get(category) as Node2D
		if not is_instance_valid(source_aura):
			source_aura = SOURCE_AWAKENING_AURA.new()
			add_child(source_aura)
			source_awakening_auras[category] = source_aura
		source_aura.configure(category, record, option_awakening.source_visual_awakened(category, record), native_target, player.original_source_manifest, presentation_settings)
		return
	var previous_source: Node2D = source_awakening_auras.get(category) as Node2D
	if is_instance_valid(previous_source): previous_source.deactivate()
	var awakened: bool = not BASE508.native(record) and not record.is_empty() and option_awakening.is_awakened(category, record)
	var aura: Node2D = option_awakening_auras.get(category) as Node2D
	if not awakened:
		if is_instance_valid(aura): aura.call("set_awakened", false)
		return
	var target: Node2D
	var parent: Node2D
	match category:
		"변신":
			target = player.transform_sprite
			parent = player
		"마법인형":
			target = companion_sprite
			parent = $Companion
		"성물":
			target = relic_sprite
			parent = self
		_:
			return
	if not is_instance_valid(target): return
	if not is_instance_valid(aura):
		aura = OPTION_AWAKENING_AURA.new()
		aura.name = "OptionAwakeningAura"
		parent.add_child(aura)
		option_awakening_auras[category] = aura
	aura.call("configure", target, category, str(record.get("grade", "영웅")), awakened, presentation_settings)
	aura.z_index = target.z_index

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

## --- 523 카드 다시 뽑기 · 스킬 카드 합성/강화 (견적 → 확인 → 실행) -------------
## UI 창은 이 함수들만 부른다. 규칙·저장은 scripts/cards/card_swap523.gd,
## scripts/cards/skill_card523.gd (docs/cards523_reroll_skillcard.md).
func card523_swap_quote(category: String, identity: String, confirmation_only: bool = false) -> Dictionary:
	if _option_awakening_busy(): return {"ok":false,"reason":"각성 처리 중"}
	return card_swap523.quote(category, identity, confirmation_only)

func card523_swap_execute(token: String, pick: String = "") -> Dictionary:
	if _option_awakening_busy(): return {"ok":false,"reason":"각성 처리 중"}
	if hud != null and hud.has_method("is_card_reveal_busy") and bool(hud.call("is_card_reveal_busy")): return {"ok":false,"reason":"카드 결과 연출 중"}
	return card_swap523.execute(token, pick)

## Takes the pending reroll result (quote.confirm_token): the original card
## is replaced by it. Until then the pending result stays saved.
func card523_swap_confirm(confirm_token: String) -> Dictionary:
	if _option_awakening_busy(): return {"ok":false,"reason":"각성 처리 중"}
	if hud != null and hud.has_method("is_card_reveal_busy") and bool(hud.call("is_card_reveal_busy")): return {"ok":false,"reason":"카드 결과 연출 중"}
	return card_swap523.confirm(confirm_token)

func card523_swap_quote_all() -> Dictionary:
	if _option_awakening_busy(): return {"ok":false,"reason":"각성 처리 중"}
	return card_swap523.quote_all()

func card523_swap_confirm_all(token: String) -> Dictionary:
	if _option_awakening_busy(): return {"ok":false,"reason":"각성 처리 중"}
	if hud != null and hud.has_method("is_card_reveal_busy") and bool(hud.call("is_card_reveal_busy")): return {"ok":false,"reason":"카드 결과 연출 중"}
	return card_swap523.confirm_all(token)

## Every saved pending reroll result (e.g. to reopen the window after a reload).
func card523_swap_pending() -> Array:
	return card_swap523.pending_results()

func card523_swap_confirmed() -> Dictionary:
	return card_swap523.confirmed_cards()

func skill_card523_materials(grade_id: int = -1) -> Array:
	return skill_cards523.materials(grade_id)

func skill_card523_deck() -> Array:
	return skill_cards523.deck_cards()

func skill_card523_merge_quote(grade_id: int, selection: Dictionary = {}) -> Dictionary:
	return skill_cards523.merge_quote(grade_id, selection)

func skill_card523_merge_execute(token: String) -> Dictionary:
	return skill_cards523.merge_execute(token)

## TWILIGHT 근사: deck-41 skill card reroll (docs/cards523_reroll_skillcard.md 5).
func skill_card523_swap_quote(physical_id: String) -> Dictionary:
	return skill_cards523.swap_quote(physical_id)

func skill_card523_swap_execute(token: String) -> Dictionary:
	return skill_cards523.swap_execute(token)

func skill_card523_levelup_quote(card_id: int, feed: Dictionary = {}, attempt: bool = true) -> Dictionary:
	return skill_cards523.levelup_quote(card_id, feed, attempt)

func skill_card523_levelup_execute(token: String) -> Dictionary:
	return skill_cards523.levelup_execute(token)

func source_relic_spell_level(source_grade_id: int, base_level: int) -> Dictionary:
	# Source grades are explicit IDs. Do not reinterpret the current custom
	# skill database's names/ranks as native spell identities or level curves.
	return preload("res://scripts/cards/relic_spell_levels.gd").level_for(self, source_grade_id, base_level)

func _all_equipped_records() -> Array[Dictionary]:
	combinations.reconcile()
	if not equipment_records_dirty:return equipment_records_cache
	equipment_records_dirty=false
	equipment_record_rebuilds+=1
	var records: Array[Dictionary] = []
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			records.append(_verified_catalog_record(category, value as Dictionary))
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var item_value: Variant = equipped_items.get(slot, {})
		if item_value is Dictionary and not (item_value as Dictionary).is_empty():
			records.append(_source_catalog_record("아이템", item_value as Dictionary))
	var combination_record: Dictionary=combinations.stat_record()
	if not combination_record.is_empty():records.append(combination_record)
	var collection_record: Dictionary = equipment_collections.stat_record()
	if not collection_record.is_empty(): records.append(collection_record)
	var card_collection_record: Dictionary = card_collections.stat_record()
	if not card_collection_record.is_empty(): records.append(card_collection_record)
	var totem_record: Dictionary = totems.stat_record()
	if not totem_record.is_empty(): records.append(totem_record)
	var monsterbook_record: Dictionary = monsterbook523_runtime.stat_record()
	if not monsterbook_record.is_empty(): records.append(monsterbook_record)
	var growth_record: Dictionary = growth.stat_record()
	if not growth_record.is_empty(): records.append(growth_record)
	var extra_record: Dictionary = unconfirmed523.stat_record()
	if not extra_record.is_empty(): records.append(extra_record)
	var half_record: Dictionary = half_elixir.stat_record()
	if not half_record.is_empty(): records.append(half_record)
	for record: Dictionary in option_awakening.bonus_records(): records.append(record)
	for record: Dictionary in skill_awakening.bonus_records(): records.append(record)
	for record: Dictionary in card_deck_bonus.bonus_records(): records.append(record)
	for record: Dictionary in halphas_star.bonus_records(): records.append(record)
	# Domination stone slots 2 and 3 (slot 1 is equipped_items.domination_stone).
	for record: Dictionary in domination_stones.bonus_records(): records.append(record)

	equipment523_records_cache = equipment523.records(self)
	records.append_array(equipment523_records_cache)
	equipment_records_cache=records
	return equipment_records_cache

func _equipment523_bonus_records() -> Array[Dictionary]:
	_all_equipped_records()
	return equipment523_records_cache

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
		"domination_stone": return "domination_stone"
		"relic_item": return "relic_item"
		"fishing_rod": return "fishing_rod"
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

func _attach_missing_equipment_instance_ids() -> void:
	_sync_item_instances()
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var value: Variant = equipped_items.get(slot, {})
		if not (value is Dictionary) or (value as Dictionary).is_empty():
			continue
		var record: Dictionary = value as Dictionary
		if not str(record.get("instance_id", "")).is_empty():
			continue
		var unique_id: String = _chosen_instance(str(record.get("name", "")), true)
		if not unique_id.is_empty():
			record["instance_id"] = unique_id
			equipped_items[slot] = record

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

func _source_enchantment_extra(excluded_slots: Array, stat: String) -> int:
	var total: int = 0
	for slot: String in EQUIPMENT_SLOT_ORDER:
		if excluded_slots.has(slot): continue
		var record: Dictionary = equipped_items.get(slot,{})
		if not record.get("source_m_native_item",false): continue
		total += int(LOOT_DROP.PATCH523_DROPS.native_enchant_stats(record,_equipment_enhancement_level(slot)).get(stat,0))
	return total

func _enhancement_weapon_stat(stat: String) -> int:
	var record_value: Variant = equipped_items.get("weapon", {})
	if not (record_value is Dictionary) or (record_value as Dictionary).is_empty():
		return 0
	return int(ENCHANT.stats("weapon", _equipment_enhancement_level("weapon"), _physical_enhancement_record(record_value as Dictionary)).get(stat, 0))

func _physical_enhancement_record(worn: Dictionary) -> Dictionary:
	var physical: Dictionary=item_instances.get(str(worn.get("instance_id","")),{})
	var record: Dictionary=physical.get("record",worn)
	var blessing: int=patch523_equipment.bless_code(physical) if not physical.is_empty() else (2 if EQUIPMENT_BLESSING.is_blessed({},record) else 1)
	return PATCH523_ENHANCE.prepare(patch523_equipment,record,blessing)

func _enhancement_stat_for_slots(slots: Array[String], stat: String) -> int:
	return int(_enhancement_float_for_slots(slots,stat))

func _enhancement_float_for_slots(slots: Array[String], stat: String) -> float:
	var result: float = 0.0
	for slot: String in slots:
		var record_value: Variant = equipped_items.get(slot, {})
		if not (record_value is Dictionary) or (record_value as Dictionary).is_empty():
			continue
		var kind: String = "weapon" if slot == "weapon" else ("armor" if ARMOR_EQUIPMENT_SLOTS.has(slot) else "accessory")
		result += float(ENCHANT.stats(kind, _equipment_enhancement_level(slot), _physical_enhancement_record(record_value as Dictionary)).get(stat, 0))
	return result

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
	if record.get("source_m_native_item",false) and record.get("source_is_two_handed",false): return false
	return SHIELD_COMPATIBLE_WEAPONS.has(_normalized_weapon_type(str(record.get("type", ""))))

func _current_weapon_supports_shield() -> bool:
	return _weapon_supports_shield(_equipped_weapon_record())

func _enforce_patch523_equipment_requirements() -> bool:
	var changed: bool = false
	for slot: String in EQUIPMENT_SLOT_ORDER:
		var record: Dictionary = _source_catalog_record("아이템",equipped_items.get(slot,{}))
		if not record.get("source_m_native_item",false): continue
		var problem: String = LOOT_DROP.PATCH523_DROPS.equipment_error(record,job_class,level,int(ui_preferences.get("patch523_source_clock_offset_minutes",540)))
		if not problem.is_empty():
			changed = true
			equipped_items[slot] = {}
			_invalidate_equipment_static()
			hud.append_log("원본 장비 조건에 따라 해제 · 아이템 보존 · "+str(record.name))
	return changed

func _can_equip_offhand(record: Dictionary) -> bool:
	if record.get("source_m_native_item",false) and record.has("source_can_equip_with_two_handed"):
		if record.source_can_equip_with_two_handed: return true
		if not _current_weapon_supports_shield(): return false
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
	var explicit_source_rule: bool = offhand.get("source_m_native_item",false) and offhand.has("source_can_equip_with_two_handed")
	if offhand.is_empty() or (_offhand_kind(offhand) != "shield" and not explicit_source_rule) or _can_equip_offhand(offhand):
		return
	var offhand_name: String = str(offhand.get("name", "방패"))
	equipped_items["offhand"] = {}
	_invalidate_equipment_static()
	if not quiet:
		hud.show_message("현재 무기와 방패를 함께 착용할 수 없어 방패가 해제되었습니다")
	hud.append_log("방패 자동 해제 · %s / 무기 %s" % [offhand_name, _current_weapon_type()])

## One resolved weapon record per frame for the same worn weapon. A single
## normal hit resolved it 3-5 times (weapon size roll, invoke roll, element
## bonus, bleed, ammo), each a catalog lookup plus a deep copy of the native
## record (523.808: hit.roll 28 ms on the phone). Callers only read it.
var _weapon_memo_frame: int = -1
var _weapon_memo_source: Variant = null
var _weapon_memo: Dictionary = {}

func _equipped_weapon_record() -> Dictionary:
	var value: Variant = equipped_items.get("weapon", {})
	if not value is Dictionary: return {}
	var frame: int = Engine.get_process_frames()
	var fingerprint: int = hash(value)
	if frame == _weapon_memo_frame and is_same(value, _weapon_memo_source) and _weapon_memo_size == fingerprint:
		return _weapon_memo
	_weapon_memo = _source_catalog_record("아이템", value as Dictionary)
	_weapon_memo_frame = frame
	_weapon_memo_source = value
	_weapon_memo_size = fingerprint
	return _weapon_memo
## Content hash of the worn weapon entry the memo was built from.
var _weapon_memo_size: int = 0

func _weapon_allowed_for_job(record: Dictionary, target_job: String) -> bool:
	if record.is_empty():
		return true
	if record.get("source_m_native_item",false):
		var full: Dictionary = NATIVE_FIELDS.full(record)
		if not full.get("source_unresolved_class_ids",[]).is_empty(): return false
		var classes: Array = full.get("source_class_names",[])
		return classes.is_empty() or classes.has(target_job)
	var weapon_type: String = _normalized_weapon_type(str(record.get("type", "")))
	var allowed_value: Variant = JOB_ALLOWED_WEAPONS.get(target_job, [])
	if not (allowed_value is Array):
		return false
	return (allowed_value as Array).has(weapon_type)

func _patch523_use_record(reference: String) -> Dictionary:
	var selected: Dictionary = _parse_enhancement_target(reference)
	var record: Dictionary = _find_catalog_item_record(str(selected.name))
	var id: String = str(selected.get("id",""))
	if not id.is_empty() and item_instances.has(id): record=item_instances[id].get("record",record)
	if record.has("patch523_item_use"): return record
	var source_id: String=patch523_equipment.identity({"record":record})
	if source_id.is_empty(): return record
	var canonical: Dictionary = patch523_equipment.record(source_id)
	if canonical.get("name")!=record.get("name") or not canonical.has("patch523_item_use"): return record
	var result: Dictionary=record.duplicate(true)
	result["patch523_item_use"]=canonical.patch523_item_use.duplicate(true)
	return result

func _enforce_patch523_equipment_use() -> void:
	# Keep the physical item and its saved metadata; only disallowed equipment
	# slots are cleared on class change/load. No acquisition is lost.
	for slot: String in equipped_items:
		var worn: Dictionary = equipped_items[slot]
		if worn.is_empty() or not worn.has("patch523_item_use"): continue
		if not PATCH523_ITEM_USE.reason(worn,level,BASE508.source_class_id(job_class)).is_empty():
			equipped_items[slot]={}
			_invalidate_equipment_static()

func _enforce_weapon_class_compatibility(quiet: bool = false) -> void:
	var weapon: Dictionary = _equipped_weapon_record()
	if weapon.is_empty() or _weapon_allowed_for_job(weapon, job_class):
		return
	var item_name: String = str(weapon.get("name", "무기"))
	equipped_items["weapon"] = {}
	_invalidate_equipment_static()
	_refresh_speed_modifiers()
	if not quiet:
		hud.show_message("클래스 변경으로 %s 장착 해제" % item_name)
	hud.append_log("%s 착용 불가 · %s 장착 해제" % [job_class, item_name])

func _current_weapon_type() -> String:
	if _stat_memo_depth == 0: return _current_weapon_type_uncached()
	var memo_key: String = "weapon_type"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _current_weapon_type_uncached()
	return _stat_memo[memo_key]

func _current_weapon_type_uncached() -> String:
	return _normalized_weapon_type(str(_equipped_weapon_record().get("type", "")))

func _current_attack_kind() -> String:
	var weapon: Dictionary = _equipped_weapon_record()
	var native: Dictionary = preload("res://scripts/loot/patch523_ammo.gd").weapon_type(weapon)
	if not native.is_empty(): return "ranged" if int(native.get("AmmoItemCategoryID",0)) > 0 else "melee"
	if weapon.has("attackKind"):
		return str(weapon.get("attackKind", "melee"))
	return _weapon_attack_kind_from_type(_current_weapon_type())

func _current_attack_range_cells() -> int:
	var weapon: Dictionary = _equipped_weapon_record()
	var native: Dictionary = preload("res://scripts/loot/patch523_ammo.gd").weapon_type(weapon)
	if not native.is_empty(): return maxi(1,int(native.get("AttackRange",1))) + int(original_skills.local_runtime.attack_range_bonus() if original_skills != null else 0)
	if weapon.has("attackRangeCells"):
		return maxi(1, int(weapon.get("attackRangeCells", 1))) + int(original_skills.local_runtime.attack_range_bonus() if original_skills != null else 0)
	return _weapon_range_cells_from_type(_current_weapon_type()) + int(original_skills.local_runtime.attack_range_bonus() if original_skills != null else 0)

func _weapon_cell_distance(target: TwilightMonster) -> int:
	if target == null:
		return 999999
	var from_cell: Vector2i = _world_to_cell(player.global_position)
	var to_cell: Vector2i = _world_to_cell(target.global_position)
	var delta: Vector2i = to_cell - from_cell
	return maxi(absi(delta.x), absi(delta.y))

func _target_in_current_weapon_range(target: TwilightMonster) -> bool:
	return target != null and _weapon_cell_distance(target) <= _current_attack_range_cells()

func _nearest_visible_monster_in_weapon_range(automatic_acquisition: bool = false) -> TwilightMonster:
	if _source_combat_targets_hidden(): return null
	var best: TwilightMonster = null
	var best_distance: float = INF
	var range_cells: int = _current_attack_range_cells()
	for node: Node in monsters_root.get_children():
		if not (node is TwilightMonster):
			continue
		var monster: TwilightMonster = node
		if monster.dead or _weapon_cell_distance(monster) > range_cells:
			continue
		if automatic_acquisition and not monster.permits_auto_selection(): continue
		if not _has_line_of_sight_world(player.global_position, monster.global_position):
			continue
		var distance: float = player.global_position.distance_to(monster.global_position)
		if distance < best_distance:
			best_distance = distance
			best = monster
	return best

func _weapon_ammo_family() -> String:
	if _current_weapon_type()=="건틀렛":
		var chosen: Dictionary=SOURCE_AMMO.definition(load("res://scripts/loot/current523_native_stack.gd").call("ammo_record",self,equipped_ammo))
		if not chosen.is_empty() and chosen.family=="스팅":return "스팅"
	var weapon: Dictionary = _equipped_weapon_record()
	var category: int = preload("res://scripts/loot/patch523_ammo.gd").weapon_category(weapon)
	var fallback: String = _weapon_ammo_from_type(_current_weapon_type())
	if category < 0: category = 8 if fallback == "화살" else 10194 if fallback == "총알" else 0
	if category == 0: return ""
	var worn: Dictionary = load("res://scripts/loot/current523_native_stack.gd").call("ammo_record",self,equipped_ammo)
	if category > 0 and int(NATIVE_FIELDS.full(worn).get("source_category_id",-1)) == category and not preload("res://scripts/loot/patch523_ammo.gd").profile(worn).is_empty():
		if preload("res://scripts/loot/patch523_item_use.gd").eligibility(self,worn).is_empty(): return equipped_ammo
	if category == 223: return "스팅"
	if weapon.has("ammo"):
		return str(weapon.get("ammo", ""))
	return _weapon_ammo_from_type(_current_weapon_type())

func _skill_arrow_ammo_name() -> String:
	var current: String = _current_ammo_name()
	return current if NATIVE_FIELDS.field(load("res://scripts/loot/current523_native_stack.gd").call("ammo_record",self,current),"source_category_name") == "Arrow" else "화살"

func _current_ammo_name() -> String:
	var family: String=_weapon_ammo_family()
	var record: Dictionary=load("res://scripts/loot/current523_native_stack.gd").call("ammo_record",self,equipped_ammo)
	if record.get("source")=="twilight-shop523-ammo":
		var spec: Dictionary=SOURCE_AMMO.definition(record)
		if spec.is_empty() or str(spec.family)==family:return equipped_ammo
	return family

func _weapon_intrinsic_attack_speed_percent(record: Dictionary) -> float:
	if record.is_empty():
		return 0.0
	if record.has("weaponAttackSpeed"):
		return maxf(0.0, float(record.get("weaponAttackSpeed", 0.0)))
	var weapon_type: String = _normalized_weapon_type(str(record.get("type", "")))
	return maxf(0.0, float(WEAPON_BASE_ATTACK_SPEED.get(weapon_type, 15.0)))

func _ensure_inventory_ammo_defaults() -> void:
	# The pre-November free "화살"/"총알" stacks are no longer added; a new
	# character gets the original 523 arrows/bullets from current523_starter_kit.
	pass

func _consume_weapon_ammo() -> bool:
	var ammo_name: String = _current_ammo_name()
	var native: Dictionary=load("res://scripts/loot/current523_native_stack.gd").call("consume_ammo",self,ammo_name,1)
	if native.get("handled",false):
		if not native.get("ok",false) or not native.get("saved",false) or native.get("consumed")!=1:
			hud.show_message(str(native.get("reason","원본 탄약 소비 연결 대기")));return false
		_refresh_ammo_counters();return true
	if ammo_name == "": return true
	var source_record: Dictionary=_find_catalog_item_record(ammo_name)
	var is_source: bool=source_record.get("source")=="twilight-shop523-ammo"
	if is_source and SOURCE_AMMO.definition(source_record).is_empty():
		hud.show_message("탄약 원본 정체 불일치 · 소지 스택 보존")
		return false
	if not _ammo_worn(ammo_name, true):
		var now_worn: int = Time.get_ticks_msec()
		if now_worn-ammo_notice_at >= 3000:
			ammo_notice_at = now_worn
			hud.show_message("%s 미착용 · 가방에서 %s을(를) 착용하세요" % [ammo_name, ammo_name])
		return false
	var count: int = int(inventory.get(ammo_name,0))
	if count <= 0:
		var now: int = Time.get_ticks_msec()
		if now-ammo_notice_at >= 3000:
			ammo_notice_at = now
			hud.show_message("%s 부족 · 공격 대기 (AUTO 유지)" % ammo_name)
		return false
	inventory[ammo_name] = count-1
	# One full save per arrow was ~0.4 s on the phone: the shot commits in
	# memory and joins the coalesced background save (option A).
	if is_source: _request_general_save()
	# One arrow per shot used to rebuild the whole HUD (equipment, cards,
	# collections, inventory) on every bow attack, which stuttered combat.
	# Only the counters that show ammo need refreshing.
	_refresh_ammo_counters()
	return true

func _refresh_ammo_counters() -> void:
	if hud.has_method("set_quick_items"):
		hud.call("set_quick_items", inventory)
	if hud.inventory_panel.visible:
		hud.refresh_inventory(inventory)

func _is_ammo_record(record: Dictionary) -> bool:
	return str(record.get("name", "")) in ["화살", "총알"] or not SOURCE_AMMO.definition(record).is_empty() or not preload("res://scripts/loot/patch523_ammo.gd").profile(record).is_empty()

func _roll_source_ammo_damage(target: TwilightMonster) -> int:
	if target == null: return 0
	var record: Dictionary = _find_catalog_item_record(_current_ammo_name())
	var profile: Dictionary = preload("res://scripts/loot/patch523_ammo.gd").profile(record)
	if profile.is_empty(): return 0
	var maximum: int = int(profile.get("large_damage" if str(target.get_meta("size_class","small")).to_lower() == "large" else "small_damage",0))
	match str(ui_preferences.get("patch523_ammo_damage_rule","uniform")):
		"disabled": return 0
		"maximum": return maximum
		_: return rng.randi_range(1,maximum) if maximum > 0 else 0

## True when `ammo_name` is worn. Unless the player explicitly took ammo off,
## the ammo the current weapon needs is worn automatically (old saves, new
## characters, and bow <-> gun swaps; there is one arrow and one bullet type).
func _ammo_worn(ammo_name: String, allow_auto: bool = false) -> bool:
	var owner: Script=load("res://scripts/loot/current523_native_stack.gd")
	if owner.call("native_ammo",owner.call("ammo_record",self,ammo_name)):return owner.call("ammo_worn",self,ammo_name)
	if not consumable_service.export_state().get("source_native_ammo_equipped",{}).is_empty():return false
	if equipped_ammo == ammo_name:
		return true
	if allow_auto and not ammo_unequipped and int(inventory.get(ammo_name, 0)) > 0:
		equipped_ammo = ammo_name
		hud.append_log("%s 자동 착용" % ammo_name)
		stat_hud_refresh_pending = true
		_request_deferred_save()
		return true
	return false

func _toggle_ammo_equipped(ammo_name: String,physical_id: String="") -> void:
	var native: Dictionary=load("res://scripts/loot/current523_native_stack.gd").call("equip_ammo",self,ammo_name,physical_id)
	if native.get("handled",false):
		hud.show_message(str(native.get("message",native.get("reason","원본 탄약 착용 연결 대기"))))
		if native.get("ok",false) and native.get("saved",false):_update_hud();hud.refresh_inventory(inventory)
		return
	var next_ammo: String = "" if equipped_ammo == ammo_name else ammo_name
	if not next_ammo.is_empty() and int(inventory.get(next_ammo,0)) <= 0:
		hud.show_message("탄약이 없습니다");return
	if _save_game(true,{"equipped_ammo":next_ammo,"ammo_unequipped":next_ammo.is_empty()}) != OK:
		hud.show_message("탄약 착용 저장 실패 · 기존 장착 상태 보존");return
	if equipped_ammo == ammo_name:
		equipped_ammo = ""
		ammo_unequipped = true
		hud.show_message("%s 착용 해제" % ammo_name)
		hud.append_log("%s 착용 해제" % ammo_name)
	else:
		if int(inventory.get(ammo_name, 0)) <= 0:
			hud.show_message("%s이(가) 없습니다" % ammo_name)
			return
		equipped_ammo = ammo_name
		ammo_unequipped = false
		var needed: String = _current_ammo_name()
		var note: String = "" if needed.is_empty() or needed == ammo_name else " · 현재 무기는 %s 사용" % needed
		hud.show_message("%s 착용%s" % [ammo_name, note])
		hud.append_log("%s 착용" % ammo_name)
	_update_hud()
	hud.refresh_inventory(inventory)

func _normal_attack_hit_chance(target: TwilightMonster, attack_kind: String) -> float:
	if target == null:
		return 0.05
	var accuracy: int = _ranged_accuracy_stat() if attack_kind == "ranged" else _melee_accuracy_stat()
	if original_skills != null:
		return original_skills.physical_hit_chance(accuracy, target,attack_kind)
	return PHYSICAL_RESOLUTION.physical_hit_chance(accuracy,target.hit_armor_class(),0)*halphas_star.combat.hit_factor(player)

func _catalog_damage_bonus(kind: String) -> int:
	# Native secondary doll effects are counted once, separately from general attack.
	var source_damage: int=monsterbook523_runtime.flat_bonus({"melee":"MeleeDamage","ranged":"RangeDamage","magic":"MagicDamage"}.get(kind,"")) + option_awakening.catalog_bonus({"melee":"meleeDamage","ranged":"rangedDamage","magic":"magicDamage"}.get(kind,""))+halphas_star.catalog_bonus({"melee":"meleeDamage","ranged":"rangedDamage","magic":"magicDamage"}.get(kind,"")) + weapon_mastery.catalog_bonus({"melee":"meleeDamage","ranged":"rangedDamage","magic":"magicDamage"}.get(kind,""), _mastery_actual_weapon_type())+int(combinations.amount({"melee":"MeleeDamage","ranged":"RangeDamage"}.get(kind,"")))
	var half_kind: String = {"melee":"Melee", "ranged":"Range", "magic":"Magic"}.get(kind, "")
	var total: int = totems.bonus({"melee":"MeleeDamage","ranged":"RangeDamage","magic":"MagicDamage"}.get(kind,"")) + source_damage + int(half_elixir.value(half_kind + "Damage")) + (clan523.buff_value("magic_damage") if kind == "magic" else 0) + _catalog_stat_sum("damage_reduction_ignore") + _catalog_stat_sum("damageReductionIgnore") + _catalog_stat_sum(kind + "_reduction_ignore")
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			var original: Dictionary = _verified_catalog_record(category, value as Dictionary)
			total += CATALOG_EFFECTS.damage_by_style(original, kind)
			if (kind == "melee" or kind == "ranged") and _current_weapon_type() != "":
				total += int(original.get("weapon_bonus_" + _current_weapon_type(), 0))
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
	var half_kind: String = {"melee":"Melee", "ranged":"Range", "magic":"Magic"}.get(kind, "")
	var total: int = option_awakening.accuracy_bonus(kind) + weapon_mastery.catalog_bonus({"melee":"meleeHit","ranged":"rangedHit"}.get(kind,""), _mastery_actual_weapon_type())+int(combinations.amount({"melee":"MeleeHit","ranged":"RangeHit","magic":"MagicHit"}.get(kind,""))) + int(half_elixir.value(half_kind + "Hit") + half_elixir.value("PVE" + half_kind + "Hit")) + totems.bonus({"melee":"MeleeHit","ranged":"RangeHit","magic":"MagicHit"}.get(kind,"")) + monsterbook523_runtime.flat_bonus({"melee":"MeleeHit","ranged":"RangeHit","magic":"MagicHit"}.get(kind,""))
	if kind in ["melee","ranged","magic"]:total+=_catalog_stat_sum("pve_"+kind+"_hit")
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			total += CATALOG_EFFECTS.accuracy_by_style(_verified_catalog_record(category, value as Dictionary), kind)
	return total

func _catalog_critical_bonus(kind: String) -> int:
	var total: int = weapon_mastery.catalog_bonus({"melee":"meleeCritical","ranged":"rangedCritical","magic":"magicCritical"}.get(kind,""), _mastery_actual_weapon_type())
	for category: String in ["변신", "마법인형", "성물"]:
		var value: Variant = equipped_catalog.get(category, {})
		if value is Dictionary and not (value as Dictionary).is_empty():
			var normalized: Dictionary = _verified_catalog_record(category, value as Dictionary)
			if bool(normalized.get("inven_indexed", false)):
				continue # The source is already counted by _record_critical_bonus.
			var critical_field: String={"melee":"meleeCrit","ranged":"rangedCrit","magic":"magicCrit"}.get(kind,"")
			if BASE508.native(normalized) and normalized.has(critical_field):continue
			total += CATALOG_EFFECTS.critical_by_style(normalized, kind)
	return total

func _ranged_normal_damage_stat() -> int:
	return _ranged_damage_stat()

func _record_move_speed_multiplier(record: Dictionary) -> float:
	var value: float = float(record.get("speed", 1.0))
	if value <= 0.0:
		return 1.0
	return clampf(value, 0.5, 2.0)

func _record_attack_speed_percent(record: Dictionary) -> float:
	if bool(record.get("_combination_bonus",false)) or bool(record.get("_equipment_collection_bonus",false)) or bool(record.get("_card_collection_bonus",false)):
		return maxf(0.0,float(record.get("collection_attack_speed",0.0)))
	var value: float = CATALOG_EFFECTS.attack_speed_percent(record)
	if str(record.get("slot", "")) == "weapon":
		value += _weapon_intrinsic_attack_speed_percent(record)
	return maxf(0.0, value)

func _effective_move_speed_multiplier() -> float:
	if _stat_memo_depth == 0: return _effective_move_speed_multiplier_uncached()
	var memo_key: String = "move_speed"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _effective_move_speed_multiplier_uncached()
	return _stat_memo[memo_key]

func _effective_move_speed_multiplier_uncached() -> float:
	var multiplier: float = 1.0
	var awakening_percent: float = 0.0
	for record: Dictionary in _all_equipped_records():
		multiplier *= _record_move_speed_multiplier(record)
		awakening_percent += float(record.get("speedBonusPct", 0.0))
	# Awakening adds percentage points before the existing buff/encumbrance factors.
	multiplier += awakening_percent / 100.0
	multiplier *= _passive_skill_speed_multiplier()
	multiplier *= 1.0 + _active_item_buff_percent("move_speed") / 100.0
	multiplier *= 1.0+dungeon_play.modifier("move_speed")/100.0
	multiplier *= _inventory_encumbrance_multiplier()
	return clampf(multiplier, 0.5, 2.5)

func _effective_attack_speed_bonus_percent() -> float:
	var total: float = original_skills.stat("attackSpeed") if original_skills != null else 0.0
	total += weapon_mastery.catalog_bonus("attackSpeed", _mastery_actual_weapon_type())
	for record: Dictionary in _all_equipped_records():
		total += _record_attack_speed_percent(record)
	total += _active_item_buff_percent("attack_speed")
	total += dungeon_play.modifier("attack_speed")
	return maxf(0.0, total)

func _effective_attack_speed_multiplier() -> float:
	if _stat_memo_depth == 0: return _effective_attack_speed_multiplier_uncached()
	var memo_key: String = "attack_speed_mul"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _effective_attack_speed_multiplier_uncached()
	return _stat_memo[memo_key]

func _effective_attack_speed_multiplier_uncached() -> float:
	return clampf(1.0 + _effective_attack_speed_bonus_percent() / 100.0, 0.5, 4.0)

func _normal_attack_interval() -> float:
	return clampf(0.72 / _effective_attack_speed_multiplier(), 0.12, 1.50)

## The encumbrance multiplier the player's speeds were last set with (NAN:
## unknown); a bag-only publish with the same multiplier skips the refresh.
var _speed_encumbrance: float = NAN

func _refresh_speed_modifiers() -> void:
	if player == null:
		return
	hud_publish_counts.speed_refreshes += 1
	_stat_memo_begin()
	player.set_source_weapon_visual(_current_weapon_type())
	player.set_equipment_speed_multipliers(_effective_move_speed_multiplier(), _effective_attack_speed_multiplier())
	_speed_encumbrance = _inventory_encumbrance_multiplier()
	_stat_memo_end()

func _stat_step_bonus(value: int, baseline: int, divisor: float) -> int:
	var delta: int = value - baseline
	if delta <= 0:
		return 0
	return int(floor(float(delta) / divisor))

func _melee_damage_stat() -> int:
	return _effective_attack() + int(original_skills.stat("meleeDamage") if original_skills != null else 0) + _catalog_damage_adjustment("melee") + _catalog_stat_sum("pve_melee_damage") + _stat_step_bonus(_effective_attribute("STR") + _active_skill_buff_total("strFlat"), 10, 2.0) + _equipment_additional_damage("melee") + _active_item_buff_total("melee_damage") + int(consumable_service.call("permanent_damage_bonus", "melee_damage"))

func _melee_accuracy_stat() -> int:
	return int(patch523_npc_spells.modifier("MeleeHit")) + int(original_skills.stat("meleeHit") if original_skills != null else 0) + level + _effective_attribute("STR") + _active_skill_buff_total("strFlat") + int(_equipped_numeric_sum("melee_evasion_ignore")) + int(growth.bonus("melee_evasion_ignore:flat")) + _active_item_buff_total("melee_evasion_ignore") + 10 + _enhancement_weapon_stat("accuracy") + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "melee_accuracy") + _equipment_accuracy_bonus("melee") + _catalog_accuracy_bonus("melee") + _active_item_buff_total("melee_accuracy")

func _ranged_damage_stat() -> int:
	return _effective_attack() + int(original_skills.stat("rangedDamage") if original_skills != null else 0) + _catalog_damage_adjustment("ranged") + _catalog_stat_sum("pve_ranged_damage") + _stat_step_bonus(_effective_attribute("DEX") + _active_skill_buff_total("dexFlat"), 10, 2.0) + _active_skill_buff_total("ranged_bonus") + _equipment_additional_damage("ranged") + _active_item_buff_total("ranged_damage") + int(consumable_service.call("permanent_damage_bonus", "ranged_damage"))

func _ranged_accuracy_stat() -> int:
	return int(original_skills.stat("rangedHit") if original_skills != null else 0) + level + _effective_attribute("DEX") + _active_skill_buff_total("dexFlat") + int(_equipped_numeric_sum("ranged_evasion_ignore")) + int(growth.bonus("ranged_evasion_ignore:flat")) + _active_item_buff_total("ranged_evasion_ignore") + 5 + _enhancement_weapon_stat("accuracy") + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "ranged_accuracy") + _equipment_accuracy_bonus("ranged") + _catalog_accuracy_bonus("ranged") + _active_skill_buff_total("ranged_accuracy") + _active_item_buff_total("ranged_accuracy")

func _magic_damage_stat() -> int:
	return 5 + _stat_step_bonus(_effective_attribute("INT") + _active_skill_buff_total("intFlat"), 8, 2.0) + _catalog_damage_bonus("magic") + _catalog_stat_sum("pve_magic_damage") + _catalog_stat_sum("sp") + int(_equipment_inven_sum("sp")) + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "sp") + _equipment_additional_damage("magic") + _active_item_buff_total("sp") + int(consumable_service.call("permanent_damage_bonus", "magic_damage"))

func _magic_accuracy_stat() -> int:
	return totems.bonus("MagicHit") + int(original_skills.stat("magicHit") if original_skills != null else 0) + level + _effective_attribute("INT") + _active_skill_buff_total("intFlat") + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "magic_accuracy") + _equipment_accuracy_bonus("magic") + _catalog_accuracy_bonus("magic") + _active_item_buff_total("magic_accuracy")

func _spell_power_stat() -> int:
	var defaults: Dictionary = original_skills.runtime_defaults if original_skills != null else {}
	var base := int(defaults.get("sp_base",{}).get("value",1))
	var threshold := int(defaults.get("sp_int_baseline",{}).get("value",12))
	var divisor := maxf(1,float(defaults.get("sp_int_divisor",{}).get("value",3)))
	return maxi(0,base + _stat_step_bonus(_effective_attribute("INT"),threshold,divisor) + _catalog_stat_sum("sp") + int(_equipment_inven_sum("sp")) + _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER,"sp") + _active_item_buff_total("sp") + int(original_skills.stat("sp") if original_skills != null else 0))

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
	if original_skills != null: base += int(original_skills.stat("meleeCrit" if attack_type == "melee" else "rangedCrit" if attack_type == "ranged" else "magicCrit"))
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
	var total: int = 5 + _stat_step_bonus(_effective_attribute("STR"), 10, 3.0) + int(titles.bonus("HitSpecialResistance"))
	for record: Dictionary in _all_equipped_records():
		total += _record_stun_accuracy(record)
	total+=int(growth.guardian_combat.status_hit("stun"))
	return growth96.status_accuracy(clampi(total, 0, 100))

func _stun_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("CON"), 10, 3.0) + int(titles.bonus("SpecialResistance"))
	for record: Dictionary in _all_equipped_records():
		total += _record_stun_resistance(record)
	total += _active_item_buff_total("stun_resistance") + _enhancement_float_for_slots(EQUIPMENT_SLOT_ORDER, "stun_resistance")
	total+=int(growth.guardian_combat.status_resistance("stun"))
	total += int(card_collections.interval_bonus("stun_resistance:percent",hp,_effective_max_hp()))
	return int(original_skills.stat("stunResistance") if original_skills != null else 0) + clampi(total, 0, 100)

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
	return growth96.status_accuracy(clampi(total, 0, 100))

func _silence_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("WIS"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_silence_resistance(record)
	return int(original_skills.stat("silenceResistance") if original_skills != null else 0) + clampi(total, 0, 100)

func _player_silence_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_silence_accuracy_stat(),
		PATCH523_EQUIPMENT_COMBAT.status_caster_level(self,level),
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
	return growth96.status_accuracy(clampi(total, 0, 100))

func _hold_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("CON"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_hold_resistance(record)
	return int(original_skills.stat("holdResistance") if original_skills != null else 0) + clampi(total, 0, 100)

func _player_hold_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_hold_accuracy_stat(),
		PATCH523_EQUIPMENT_COMBAT.status_caster_level(self,level),
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
	total+=int(growth.guardian_combat.status_hit("fear"))
	return growth96.status_accuracy(clampi(total, 0, 100))

func _fear_resistance_stat() -> int:
	var total: int = 5 + _stat_step_bonus(_effective_attribute("WIS"), 10, 3.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_fear_resistance(record)
	total+=int(growth.guardian_combat.status_resistance("fear"))
	total += int(card_collections.interval_bonus("fear_resistance:percent",hp,_effective_max_hp()))
	return int(original_skills.stat("fearResistance") if original_skills != null else 0) + clampi(total, 0, 100)

func _player_fear_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_fear_accuracy_stat(),
		PATCH523_EQUIPMENT_COMBAT.status_caster_level(self,level),
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
	return int(original_skills.stat("poisonResistance") if original_skills != null else 0) + clampi(total, 0, 100)

func _player_poison_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_poison_accuracy_stat(),
		PATCH523_EQUIPMENT_COMBAT.status_caster_level(self,level),
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
	return int(original_skills.stat("bleedResistance") if original_skills != null else 0) + clampi(total, 0, 100)

func _player_bleed_chance(target: TwilightMonster) -> float:
	if target == null:
		return 0.05
	return _status_effect_chance(
		_bleed_accuracy_stat(),
		PATCH523_EQUIPMENT_COMBAT.status_caster_level(self,level),
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
	var resistance: int = target.stun_resistance
	if original_skills != null: resistance = int(original_skills.status.effective_resistance(target,"stun"))
	return _status_effect_chance(
		_stun_accuracy_stat(),
		PATCH523_EQUIPMENT_COMBAT.status_caster_level(self,level),
		resistance,
		target.monster_level
	)

func _critical_resistance_stat(kind: String="melee",elemental: bool=false) -> int:
	var total: int = 0
	for record: Dictionary in _all_equipped_records():
		total += _record_critical_resistance(record)
	total += int(EQUIPMENT523_COMBAT.critical_resistance(_all_equipped_records(),kind))
	if kind in ["melee","ranged"]:total+=int(_equipment_inven_sum(kind+"_critical_resistance"))
	return clampi(total+int(growth.guardian_combat.critical_resistance(kind))+int(card_collections.critical_resistance(kind,elemental)), 0, 50)

func _critical_chance(attacker_critical_rate: int, defender_critical_resistance: int) -> float:
	return clampf(float(attacker_critical_rate - defender_critical_resistance) / 100.0, 0.0, 0.50)

func _critical_damage(raw_damage: int) -> int:
	return maxi(1, int(round(float(raw_damage) * 1.5)))

# Crit damage bonuses are flat values added AFTER the base 1.5x critical hit.
# Keep monster critical hits on _critical_damage so player gear never buffs enemies.
func _player_critical_damage(raw_damage: int, attack_type: String) -> int:
	var final_damage: int = _critical_damage(raw_damage) + int(equipment_collections.bonus(attack_type+"_critical_damage:flat") + card_collections.bonus(attack_type+"_critical_damage:flat") + growth.bonus(attack_type+"_critical_damage:flat"))
	var option_key: String = ""
	match attack_type:
		"ranged":
			option_key = "ranged_critical_damage"
		"magic":
			option_key = "magic_critical_damage"
			final_damage += int(monsterbook523_runtime.extra_stats().get("magic_critical_damage",0))
		_:
			option_key = "melee_critical_damage"
	return maxi(1, final_damage + int(round(_equipped_numeric_sum(option_key))))

func _effective_ac() -> int:
	var dex_ac_bonus: int = _stat_step_bonus(_effective_attribute("DEX"), 10, 3.0)
	return -(_effective_defense() + dex_ac_bonus) + int(equipment_collections.bonus("ac:flat") + growth.bonus("ac:flat") + card_collections.bonus("ac:flat")) - int(patch523_npc_spells.modifier("ArmorClassBonus")) + int(titles.bonus("ArmorClass")) - totems.bonus("ArmorClass")

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
	return maxi(0, total + int(original_skills.stat("dg") if original_skills != null else 0))

func _effective_er() -> int:
	var total: int = _stat_step_bonus(_effective_attribute("DEX"), 10, 2.0)
	for record: Dictionary in _all_equipped_records():
		total += _record_er(record)
	# TWILIGHT 근사: clan RangeEvasion (and any other held "ranged_evasion" buff) adds to ER.
	return maxi(0, total + int(original_skills.stat("er") if original_skills != null else 0) + _active_item_buff_total("ranged_evasion"))

func _record_mr(record: Dictionary) -> int:
	if record.has("mr"):
		return maxi(0, int(record.get("mr", 0)))
	if record.has("MR"):
		return maxi(0, int(record.get("MR", 0)))
	if record.has("마법 방어력"):
		return maxi(0, int(record.get("마법 방어력", 0)))
	return maxi(0, int(CATALOG_EFFECTS.numeric_description_option(record, "마법 방어력(MR)")) + int(CATALOG_EFFECTS.numeric_description_option(record, "마법 방어력")) )

func _effective_mr() -> int:
	var total: int = 10 + level + _effective_attribute("WIS") * 2 + weapon_mastery.catalog_bonus("mr", _mastery_actual_weapon_type())
	for record: Dictionary in _all_equipped_records():
		total += _record_mr(record)
	total += monsterbook523_runtime.flat_bonus("MagicResist")
	total += _active_skill_buff_total("mrFlat")
	total += _active_item_buff_total("mr")
	total += _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "mr")
	total += _equipped_bless_bonus("mr")
	total += int(titles.bonus("MagicResist"))
	return maxi(0, total + int(original_skills.stat("mr") if original_skills != null else 0))

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

func _patch523_protection_effects() -> Dictionary:
	if protection523==null or not protection523.has_method("effects"):return {}
	var value: Variant=protection523.call("effects")
	return value if value is Dictionary else {}

func _damage_reduction_stat() -> int:
	var total: int = 0
	for record: Dictionary in _all_equipped_records():
		total += _record_damage_reduction(record)
	total += monsterbook523_runtime.flat_bonus("DamageReduction")
	total += _active_item_buff_total("damage_reduction")
	total += _enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "reduction")
	total += int(_patch523_protection_effects().get("title_flat",0))
	return maxi(0, total + totem_combat.barrier_flat())

func _source_dot_damage(raw_damage: int,kind: String) -> int:
	var percent: float=0.0
	if kind in PATCH523_ENHANCE.policy().get("source_dot_channels",[]):percent=clampf(_equipment_inven_sum("dot_damage_reduction_pct"),0,90)
	return maxi(1,int(round(float(raw_damage)*(1.0-percent/100.0))))

func _pve_damage_after_item_buffs(raw_damage: int,ignore_percent: float=0.0,attack_type: String="",attacker_is_pc:bool=false) -> int:
	var protection: Dictionary=_patch523_protection_effects()
	var projection: bool=protection523!=null and bool(protection523.get("state").get("policy",{}).get("project_pvp_to_pve",false))
	var protection_flat: int=int(protection.get("possession_flat",0))+int(protection.get("active_flat",0)) if projection else 0
	var protection_percent: float=float(protection.get("possession_percent_raw",0))/10000.0 if projection else 0.0
	var reduced: int = maxi(1, raw_damage - titles.pve_reduction() - protection_flat - _active_item_buff_total("pve_damage_reduction") - _active_item_buff_total("pvp_damage_reduction") - _catalog_stat_sum("pve_damage_reduction") - _catalog_stat_sum("pvp_damage_reduction") - int(_equipment_inven_sum("pve_damage_reduction")))
	var percent: float = maxf(0.0,_pve_reduction_percent(attack_type,attacker_is_pc)-ignore_percent)
	if percent > 0:
		reduced = maxi(1, int(round(float(reduced) * (1.0 - float(percent) / 100.0))))
	return reduced

func _physical_damage_after_reduction(raw_damage: int) -> int:
	return PHYSICAL_RESOLUTION.physical_after_flat_reduction(raw_damage,_damage_reduction_stat(),_active_skill_buff_total("damage_reduction"))

func _character_stats_snapshot() -> Dictionary:
	hud_publish_counts.stat_snapshots += 1
	return {
		"str": _effective_attribute("STR"),
		"dex": _effective_attribute("DEX"),
		"con": _effective_attribute("CON"),
		"int": _effective_attribute("INT"),
		"wis": _effective_attribute("WIS"),
		"cha": _effective_attribute("CHA"),
		"stat_points": stat_points,
		"base_attributes":{"str":str_stat,"dex":dex_stat,"con":con_stat,"int":int_stat,"wis":wis_stat,"cha":cha_stat},
		"skill_cooldown_reduction": (1.0-_skill_cooldown_factor())*100.0,
		"consumable_state": consumable_service.call("export_state"),
		"inventory_weight": _inventory_total_weight(),
		"carrying_capacity": _carrying_capacity(),
		"current_weight": _inventory_total_weight(),
		"max_weight": _carrying_capacity(),
		"encumbrance_multiplier": _inventory_encumbrance_multiplier(),
		"melee_damage": _melee_damage_stat(),
		"melee_accuracy": _melee_accuracy_stat(),
		"ranged_damage": _ranged_damage_stat(),
		"ranged_accuracy": _ranged_accuracy_stat(),
		"weapon_small_damage": ITEM_OPTIONS.weapon_size_damage(_equipped_weapon_record(), false),
		"weapon_large_damage": ITEM_OPTIONS.weapon_size_damage(_equipped_weapon_record(), true),
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
	if _stat_memo_depth == 0: return _effective_attack_uncached()
	var memo_key: String = "attack"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _effective_attack_uncached()
	return _stat_memo[memo_key]

func _effective_attack_uncached() -> int:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("atk", 0.0))
	# Weapon 'atk' is a legacy aggregate (often size base + extra damage).
	# Remove it from both displayed melee/ranged stats and their common base;
	# the weapon's explicit flat options are counted once by additional_damage(),
	# and its size base is separately rolled on each successful physical hit.
	bonus -= float(_equipped_weapon_record().get("atk", 0.0))
	return attack_power + int(round(bonus)) + _enhancement_weapon_stat("damage") + _active_skill_buff_total("atk") + _passive_skill_total("atk")

func _effective_defense() -> int:
	if _stat_memo_depth == 0: return _effective_defense_uncached()
	var memo_key: String = "defense"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _effective_defense_uncached()
	return _stat_memo[memo_key]

func _effective_defense_uncached() -> int:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("def", 0.0))
	var armor_enhance: int = _enhancement_stat_for_slots(ARMOR_EQUIPMENT_SLOTS, "defense")
	var accessory_enhance: int = _enhancement_stat_for_slots(ACCESSORY_EQUIPMENT_SLOTS, "defense") + _source_enchantment_extra(ARMOR_EQUIPMENT_SLOTS+ACCESSORY_EQUIPMENT_SLOTS,"defense")
	return defense + int(round(bonus)) + armor_enhance + accessory_enhance + _active_skill_buff_total("def") + _active_item_buff_total("def") + _passive_skill_total("def") + _equipped_bless_bonus("defense")

func _effective_max_hp(base_override: int = -1, item_buff_override: Variant = null) -> int:
	if _stat_memo_depth == 0 or not (base_override < 0 and item_buff_override == null): return _effective_max_hp_uncached(base_override, item_buff_override)
	var memo_key: String = "max_hp"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _effective_max_hp_uncached(base_override, item_buff_override)
	return _stat_memo[memo_key]

func _effective_max_hp_uncached(base_override: int = -1, item_buff_override: Variant = null) -> int:
	var flat_bonus: float = float(weapon_mastery.catalog_bonus("hpFlat", _mastery_actual_weapon_type()))
	var percent_bonus: float = original_skills.stat("hpPct") if original_skills!=null else 0.0
	for record: Dictionary in _all_equipped_records():
		flat_bonus += float(record.get("hpFlat", 0.0))
		percent_bonus += float(record.get("hpPct", 0.0))
	flat_bonus += float(_enhancement_stat_for_slots(EQUIPMENT_SLOT_ORDER, "hp"))
	flat_bonus += float(_equipment_attribute_bonus("CON") * 10)
	flat_bonus += float(_active_skill_buff_total("hp"))
	flat_bonus += float(_passive_skill_total("hpFlat"))
	flat_bonus += float(_active_item_buff_total("hp_flat",item_buff_override))
	flat_bonus += float(_equipped_bless_bonus("hp"))
	return maxi(1, int(round(((max_hp if base_override < 0 else base_override) + flat_bonus) * (1.0 + percent_bonus))))

func _blessing_consumption_reduction_percent() -> float:
	var reduction: float = 0.0
	for record: Dictionary in _all_equipped_records():
		reduction += AIN_OPTION_RULES.reduction_percent(record)
	reduction += _enhancement_float_for_slots(EQUIPMENT_SLOT_ORDER, "ain_saving_pct")
	reduction += TwilightAinhasadService.level_reduction_percent(level)
	reduction += float(_active_item_buff_total("ain_saving_pct"))
	return clampf(reduction, 0.0, 100.0)

func _experience_multiplier() -> float:
	var bonus: float = 0.0
	for record: Dictionary in _all_equipped_records():
		bonus += float(record.get("xp", 0.0))
	bonus += float(_enhancement_float_for_slots(EQUIPMENT_SLOT_ORDER, "xp_pct")) / 100.0
	return maxf(1.0, 1.0 + bonus + totem_map_experience() + float(_active_item_buff_total("xp")) / 100.0)

func _update_companion(delta: float) -> void:
	doll_motion.update(delta, $Companion, companion_sprite, player)
	relic_motion.update(delta, relic_sprite, player)
	_update_secondary_doll(delta)
	_update_secondary_relic(delta)

func _update_secondary_doll(delta: float) -> void:
	if bool(presentation_settings.hide_doll):
		if is_instance_valid(secondary_doll_visual): secondary_doll_visual.hide()
		return
	var identity: String=option_awakening.active_subslot_identity()
	if identity.is_empty():
		if is_instance_valid(secondary_doll_visual):secondary_doll_visual.clear()
		return
	if not is_instance_valid(secondary_doll_visual):
		secondary_doll_visual=preload("res://scripts/cards/native_doll_subslot_visual.gd").new()
		secondary_doll_visual.name="SecondarySourceDoll";add_child(secondary_doll_visual)
	var record: Dictionary=option_awakening.core.catalog["마법인형"].get(identity,{})
	secondary_doll_visual.update_source(delta,self,record)

func _update_secondary_relic(delta: float) -> void:
	var identity: String=option_awakening.active_subslot_identity(true)
	if identity.is_empty():
		if is_instance_valid(secondary_relic_visual):secondary_relic_visual.clear()
		return
	if not is_instance_valid(secondary_relic_visual):
		secondary_relic_visual=preload("res://scripts/cards/native_doll_subslot_visual.gd").new()
		secondary_relic_visual.category="성물"
		secondary_relic_visual.name="SecondarySourceRelic";add_child(secondary_relic_visual)
	var record: Dictionary=option_awakening.core.catalog["성물"].get(identity,{})
	secondary_relic_visual.update_source(delta,self,record)

# Playable-field services: renderer, physics, population and HUD remain separate.
func _setup_field_services() -> void:
	y_sort_enabled = true
	monsters_root.y_sort_enabled = true
	monsters_root.z_index = 0
	monsters_root.child_entered_tree.connect(_unconfirmed_monster_entered)
	player.z_index = 0
	$Companion.z_index = 0
	field_population = FIELD_POPULATION.new()
	field_population.name = "FieldPopulation"
	add_child(field_population)
	field_population.set_process(false)
	legacy_population = field_population
	original_population = SOURCE_POPULATION.new()
	original_population.name = "OriginalSourcePopulation"
	add_child(original_population)
	original_population.set_process(false)
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
	# Original 523 walk-in portals (Portal table) on a 523 Land field.
	if current523_aden_source_active():
		var walked: Dictionary = await _aden_play_controller().call("step_source_portal_loading")
		if not walked.is_empty():
			current523_aden_play_active = bool(_aden_play_controller().get("active"))
			if not bool(walked.get("ok",false)): hud.show_message("포탈 이동 보류: "+str(walked.get("reason","")))
			return
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
		var maintenance_result: Dictionary = inventory_automation.maintenance.before_portal(portal_id)
		if not maintenance_result.get("ok",false):
			hud.show_message(str(maintenance_result.get("reason","정비를 확인해 주세요")))
			return false
		if portal.has("target_source"):
			if level < int(portal.get("min_level",0)) or (int(portal.get("max_level",0)) > 0 and level > int(portal.max_level)): return false
			return SOURCE_TRAVEL.enter(self,str(portal.target_map),COORD.array_vector(portal.target_source))
		var target_map: String = NATIVE_PNG.canonical(str(portal["target_map"]))
		if not maps_by_id.has(target_map):
			return false
		player.clear_click_path()
		player.velocity = Vector2.ZERO
		player.set_touch_vector(Vector2.ZERO)
		selected_monster = null
		auto_target = null
		if target_map != active_map_id:
			_set_map(target_map,false)
			if active_map_id != target_map: return false
			if field_map == null:
				_place_return_gate()
			elif portal.has("target_position") and (not (field_map is RemakePlayableField or field_map is NativePngField) or int(portal.get("target_layout_revision",-1))==int(field_map.data.layout_revision)):
				# Old pixel destinations belong to the old layout. A source remake
				# uses its validated entry unless a calibrated target revision matches.
				var landing: Vector2i = field_map.nearest_cell(COORD.array_vector(portal["target_position"]))
				if landing.x >= 0:
					player.global_position = field_map.cell_to_world(landing)
		elif portal.has("target_position"):
			if bool(field_map.get_meta("source_map84",false)):
				var destination: Vector2=COORD.array_vector(portal["target_position"])
				if int(portal.get("target_layout_revision",-1))!=int(field_map.data.layout_revision) or not field_map.point_clear(destination,4):destination=_spawn_position()
				player.global_position=destination
			elif field_map is NativePngField:
				# Reviewed PNG pockets can share one map through explicit travel
				# gates. Never project stale coordinates onto a different floor.
				if int(portal.get("target_layout_revision", -1)) != int(field_map.data.layout_revision): return false
				var destination: Vector2 = COORD.array_vector(portal["target_position"])
				if not field_map.walkable(destination) or not field_map.point_clear(destination, 4.0): return false
				var cell: Vector2i = field_map.world_to_cell(destination)
				if field_map.reachable[cell.y * field_map.width + cell.x] == 0: return false
				for offset: Vector2 in NativePngField.LANDING_BODY_OFFSETS:
					if not field_map.walkable(destination + offset): return false
				player.global_position = destination
			else:
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
		inventory_automation.maintenance.after_portal(maintenance_result)
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
	if skill.has("combination_charge_step_seconds"):
		return combinations.charge_step_duration(float(skill.combination_charge_step_seconds))*(1.0-clampf(_equipped_numeric_sum("source_card_charge_reduction_pct"),0.0,100.0)/100.0)
	return clampf(maxf(0.42, SKILL_RULES.global_cooldown_seconds(skill)) / _effective_attack_speed_multiplier(), 0.14, 0.85)

func _queue_damage_skill(skill: Dictionary, target: TwilightMonster, max_range: float) -> bool:
	if not _queue_player_attack(target, _skill_attack_kind(skill), _apply_job_skill_damage.bind(skill.duplicate(true), target), _skill_motion_duration(skill), false, max_range): return false
	pending_attack["skill"] = skill.duplicate(true)
	pending_attack["duration"] = _skill_motion_duration(skill)
	return true

## _queue_player_attack()'s refusals, without its side effects. A caller
## whose cost cannot be handed back (a saved ammo shot) asks this first and
## registers in the same frame, so a refused motion never consumes anything.
func _player_attack_refused(target: TwilightMonster, kind: String, normal: bool = false) -> bool:
	if _player_attack_gate_refused(target, kind, normal): return true
	return player.motion.dead or player.is_stunned() or player.is_feared() # start_combat_attack() refusals

func _player_attack_gate_refused(target: TwilightMonster, kind: String, normal: bool) -> bool:
	if patch523_npc_spells.blocks("CannotAttack" if normal else "CannotCastSkill") or (kind == "magic" and patch523_npc_spells.blocks("CannotCastSpell")): return true
	if halphas_star.combat.frozen(player) or not halphas_star.combat.charge.is_empty():return true
	return not is_instance_valid(target) or target.dead or hp <= 0

## Cost after registration: the motion is registered first (cancellable),
## then the cost is paid (MP/ammo, saved by its owner). A refused
## registration pays nothing; a refused payment withdraws only that
## registration. After a paid release, MISS and target death keep the
## normal rules (the cost stays spent).
func _register_then_spend_skill(skill: Dictionary, register: Callable) -> bool:
	var kept: Dictionary = _break_on_attack_buffs()
	if not bool(register.call()): return false
	var id: int = int(pending_attack.get("id", -1))
	if _spend_skill_mp(skill): return true
	_withdraw_player_attack(id, kept)
	return false

## The active buffs a registered attack removes (break_attack_buffs()).
func _break_on_attack_buffs() -> Dictionary:
	var kept: Dictionary = {}
	for name: String in active_skill_buffs:
		var buff: Variant = active_skill_buffs[name]
		if buff is Dictionary and bool((buff as Dictionary).get("break_on_attack", false)): kept[name] = buff
	return kept

## Undoes one just-registered player attack whose cost was then refused:
## only that motion, its pending entry and the buffs its registration broke.
## Never _clear_combat_actions() (flights, VFX, corpses, NPC effects stay).
func _withdraw_player_attack(id: int, kept_buffs: Dictionary = {}) -> void:
	if id < 0 or int(pending_attack.get("id", -1)) != id: return
	player.cancel_attack() # emits attack_cancelled -> _cancel_player_attack(id)
	if int(pending_attack.get("id", -1)) == id: pending_attack.clear()
	for name: String in kept_buffs:
		if not active_skill_buffs.has(name): active_skill_buffs[name] = kept_buffs[name]

func _queue_player_attack(target: TwilightMonster, kind: String, callback: Callable, duration: float, normal: bool = false, max_range: float = 0.0) -> bool:
	if _player_attack_gate_refused(target, kind, normal): return false
	player.cancel_attack()
	player.clear_click_path()
	var style: String = TwilightAnimationProfile.weapon_style(_current_weapon_type(), kind)
	var marker: float = player.motion.profile.marker_for(style)
	var id: int = player.start_combat_attack(target.global_position, duration, style, marker)
	if id < 0: return false
	if original_skills!=null:original_skills.break_attack_buffs()
	player.motion.weapon_variant = _current_weapon_type()
	pending_attack = {"id":id, "target":weakref(target), "callback":callback, "kind":kind,
		"style":style, "normal":normal, "range":max_range, "start":player.global_position, "generation":combat_generation,
		"target_life_id":target.life_id, "impact_resolved":false}
	return true

func _queue_player_area_attack(skill: Dictionary) -> bool:
	if halphas_star.combat.frozen(player) or not halphas_star.combat.charge.is_empty():return false
	# Self-centred attacks use the same cancellable motion marker as targeted
	# attacks, never a second SceneTree timer that survives movement/transform.
	player.cancel_attack()
	player.clear_click_path()
	var kind: String = str(skill.get("attack_type", "magic"))
	var style: String = TwilightAnimationProfile.weapon_style(_current_weapon_type(), kind)
	var id: int = player.start_combat_attack(player.global_position + player.motion.direction,
		float(skill.get("cast_time", 0.42)), style, player.motion.profile.marker_for(style))
	if id < 0: return false
	if original_skills!=null:original_skills.break_attack_buffs()
	pending_attack = {"id":id, "kind":kind, "style":style, "area_skill":skill.duplicate(true),
		"start":player.global_position, "generation":combat_generation}
	return true

func _cancel_player_attack(id: int) -> void:
	if int(pending_attack.get("id", -1)) == id:
		var original: Dictionary = pending_attack.get("original_skill", pending_attack.get("area_skill", {}))
		if original_skills != null and not original.is_empty():
			original_skills.vfx.cancel_cast(TwilightOriginalSkillService.presentation_id(original))
		pending_attack.clear()

func _release_player_attack(id: int) -> void:
	var strike_started: int = FRAME_HITCH.now()
	_release_player_attack_timed(id)
	FRAME_HITCH.detail("player.strike", strike_started)

func _release_player_attack_timed(id: int) -> void:
	if patch523_npc_spells.blocks("CannotAttack" if bool(pending_attack.get("normal",false)) else "CannotCastSkill"):
		_cancel_player_attack(id); return
	if int(pending_attack.get("id", -1)) != id: return
	var action: Dictionary = pending_attack
	pending_attack = {}
	if int(action.generation) != combat_generation or hp <= 0: return
	if player.is_stunned() or player.is_feared(): return
	if action.kind == "magic" and player.is_silenced(): return
	if player.global_position.distance_to(action.start) > 12.0: return
	if action.has("area_skill"):
		original_skills.area_marker(action.area_skill, int(action.generation))
		return
	var target: TwilightMonster = action.target.get_ref() as TwilightMonster
	if not is_instance_valid(target) or target.dead or target.life_id != int(action.get("target_life_id", target.life_id)): return
	var in_range: bool = _target_in_current_weapon_range(target) if action.normal else player.global_position.distance_to(target.global_position) <= float(action.range)
	if not in_range or not _has_line_of_sight_world(player.global_position, target.global_position): return
	player.face_target(target.global_position)
	if action.kind == "magic" and combat_vfx != null:
		combat_vfx.ring(player.combat_projectile_origin(), 18.0, Color(0.45, 0.7, 1.0))
	if action.has("original_skill"):
		original_skills.launch_at_marker(action, target)
		return
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
		# Normal bow/sting/gun shots follow the original 523 ammo sprite when the
		# pack has it; the flight itself (speed, hit, cancel) is unchanged.
		var flight_options: Dictionary = preload("res://scripts/animation/current523_ammo_flight.gd").options(self, player.combat_projectile_origin(), target) if action.kind == "ranged" and bool(action.get("normal", false)) else {}
		combat_flights.launch(player.combat_projectile_origin(), target, action.kind, _impact_player_attack.bind(action), 900.0 if action.kind == "magic" else 1300.0, 0.0, flight_options)
	else:
		_impact_player_attack(action)

func _impact_player_attack(action: Dictionary) -> void:
	var impact_started: int = FRAME_HITCH.now()
	_impact_player_attack_timed(action)
	FRAME_HITCH.detail("player.impact", impact_started)

func _impact_player_attack_timed(action: Dictionary) -> void:
	if bool(action.get("impact_resolved", false)): return
	action["impact_resolved"] = true # one event, even if its callback re-enters
	if int(action.generation) != combat_generation or hp <= 0: return
	var target: TwilightMonster = action.target.get_ref() as TwilightMonster
	if not is_instance_valid(target) or target.dead or target.life_id != int(action.get("target_life_id", target.life_id)): return
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
	_stable_auto_route.clear()
	EQUIPMENT523_INVOKE_DEBUFF.clear(self)
	patch523_npc_spells.clear()
	halphas_star.combat.reset()
	if is_instance_valid(presentation_audio): presentation_audio.clear()
	if original_skills != null: original_skills.clear()
	combat_generation += 1
	pending_attack.clear()
	if is_instance_valid(player): player.cancel_attack()
	if is_instance_valid(combat_flights): combat_flights.clear()
	if is_instance_valid(combat_vfx): combat_vfx.clear()
	if is_instance_valid(combat_corpses):
		for corpse: Node in combat_corpses.get_children(): corpse.queue_free()

func show_combat_number(point: Vector2, value: String, color: Color, critical: bool = false) -> void:
	if is_instance_valid(combat_vfx): combat_vfx.number(point, value, color, critical)

var _source_damage_effect_absent: Dictionary = {}
## Original hit effect of a 523 source monster (SkipDamageMotionSprite), on
## the existing successful-hit feedback. Monsters whose original body has no
## such row show none.
func _source_damage_effect(target: TwilightMonster) -> void:
	if not is_instance_valid(target) or not is_instance_valid(target.source_m_view) or target.source_m_view.get("_preview") == null: return
	var selection: Variant = target.get_meta("current523_source_bank_selection", {})
	var body_sprite: int = int(selection.get("sprite_id", -1)) if selection is Dictionary and selection.get("ok", false) else -1
	if body_sprite <= 0 or _source_damage_effect_absent.has(body_sprite): return
	var facing: int = int(target.motion.facing8) if target.motion != null else 0
	var preview: Node = target.source_m_view._preview
	if not preview.notify_current_source_damage_effect(body_sprite, target.global_position, player.global_position, facing):
		# Most bodies declare none: do not look the table up again on every hit.
		if str(preview.source_effect_status.get("reason", "")) == "current523_damage_effect_not_declared": _source_damage_effect_absent[body_sprite] = true

func monster_combat_feedback(target: TwilightMonster, critical: bool, damage_kind: String = "") -> void:
	# Named skill hits retain their existing skill audio path.
	if damage_kind.is_empty() and is_instance_valid(presentation_audio):
		presentation_audio.play_world("impact", target.combat_hit_position(), critical)
	_source_damage_effect(target)
	if not is_instance_valid(combat_vfx): return
	var style: String = feedback_style if damage_kind.is_empty() else damage_kind
	combat_vfx.impact(target.combat_hit_position(), player.global_position.direction_to(target.global_position), style, critical)
	if critical and not bool(presentation_settings.reduced_motion): player.motion.visual_hold = 0.028

func apply_presentation_settings(settings: Dictionary) -> void:
	presentation_global_settings = PRESENTATION.normalized(settings, presentation_global_settings)
	_refresh_presentation_settings()
	_update_source_optimization()

func set_region_presentation_settings(map_id: String, settings: Dictionary, enabled: bool = true) -> void:
	if map_id.is_empty(): return
	if enabled: presentation_region_settings[map_id] = PRESENTATION.region(settings)
	else: presentation_region_settings.erase(map_id)
	_refresh_presentation_settings()

func load_source_optimization(path: String, before_install: Callable = Callable()) -> Dictionary:
	var candidate = SOURCE_OPTIMIZATION.new()
	var result: Dictionary = candidate.load_zip(path) if path.get_extension().to_lower()=="zip" else candidate.load_directory(path)
	if bool(result.ok):
		if before_install.is_valid():
			var saved: Variant = before_install.call(path)
			if not saved is int or int(saved)!=OK:
				return {"ok":false,"error":"원본 선택을 저장하지 못했습니다. 기존 원본과 설정을 유지합니다."}
		source_optimization = candidate
		source_optimization_result = {"status":"manual_source_ready","settings":{}}
		source_optimization_signature = ""
		_update_source_optimization()
	return result

func select_source_presentation_effect(sprite_id: int, records: Dictionary) -> int:
	return source_optimization.simplified_sprite(sprite_id, str(presentation_settings.effect_detail)=="low", records)

func load_presentation_effect_pack(path: String, before_install: Callable = Callable()) -> Dictionary:
	var candidate = PRESENTATION_EFFECT_PACK.new()
	var result: Dictionary = candidate.load_directory(path)
	if not bool(result.ok): return result
	if before_install.is_valid():
		var saved: Variant = before_install.call(path)
		if not saved is int or int(saved)!=OK: return {"ok":false,"error":"효과 후보를 저장하지 못했습니다. 기존 선택을 유지합니다."}
	presentation_effect_pack = candidate
	return result

func presentation_effect_manifest(sprite_id: int) -> String:
	if not presentation_effect_enabled or sprite_id not in [24941,29044]: return ""
	var path: String = str(presentation_effect_pack.manifests.get(presentation_effect_action,""))
	return path if FileAccess.file_exists(path) else ""

func _update_source_optimization() -> void:
	_update_local_presentation()
	if not bool(presentation_global_settings.get("source_region_optimization",false)):
		if not source_region_settings.is_empty():
			source_region_settings.clear()
			_refresh_presentation_settings()
		return
	var context: Dictionary = {}
	if field_map != null and field_map.has_method("lineagem_m_presentation_context") and is_instance_valid(player):
		var value: Variant = field_map.call("lineagem_m_presentation_context",player.global_position)
		if value is Dictionary: context = value
	var result: Dictionary = source_optimization.at_source_point(context)
	var signature: String = JSON.stringify(result)
	if signature == source_optimization_signature: return
	source_optimization_signature = signature
	source_optimization_result = result
	source_region_settings = result.settings
	_refresh_presentation_settings()

func set_local_presentation_region(map_id: String, value: Dictionary, erase: bool = false) -> void:
	if erase: local_presentation_regions.erase(map_id)
	else:
		var rule: Dictionary = LOCAL_PRESENTATION.normalized(value)
		if rule.is_empty(): return
		local_presentation_regions[map_id] = rule
	_update_local_presentation()

func _update_local_presentation() -> void:
	if not is_instance_valid(player): return
	if not local_presentation_regions.has(active_map_id) and local_presentation_result.status=="off": return
	var rule: Dictionary = local_presentation_regions.get(active_map_id,{})
	var result: Dictionary = LOCAL_PRESENTATION.at_point(rule,player.global_position,source_optimization)
	var signature: String = JSON.stringify(result)
	if signature==local_presentation_signature: return
	local_presentation_signature = signature
	local_presentation_result = result
	_refresh_presentation_settings()

func _refresh_presentation_settings() -> void:
	var source_defaults: Dictionary = presentation_global_settings.duplicate(true)
	if bool(source_defaults.get("source_region_optimization",false)): source_defaults.merge(source_region_settings,true)
	presentation_settings = PRESENTATION.effective(source_defaults, presentation_region_settings, active_map_id)
	presentation_settings.merge(local_presentation_result.settings,true)
	if is_instance_valid(companion_sprite) and is_instance_valid(player):
		doll_motion.set_presentation_hidden(bool(presentation_settings.hide_doll), $Companion, companion_sprite, player)
	if is_instance_valid(secondary_doll_visual):
		secondary_doll_visual.visible = not bool(presentation_settings.hide_doll) and secondary_doll_visual.status == "source_native"
		if secondary_doll_visual.visible and is_instance_valid(player):
			secondary_doll_visual.global_position = player.global_position + Vector2(54,24)
	if is_instance_valid(combat_vfx):
		combat_vfx.impact_intensity = presentation_settings.impact_intensity
		combat_vfx.reduced_motion = presentation_settings.reduced_motion
		combat_vfx.impact_visual_limit = 24 if presentation_settings.limit_effect_count else COMBAT_VFX.CAPACITY
		combat_vfx.detail_limit = 6 if presentation_settings.effect_detail == "low" else COMBAT_VFX.VISUALS.DETAIL_LIMIT
	if is_instance_valid(combat_flights):
		combat_flights.visual_limit = 24 if presentation_settings.effect_detail == "low" or presentation_settings.limit_effect_count else 64
	for raw: Variant in source_awakening_auras.values():
		if is_instance_valid(raw): raw.call("apply_settings", presentation_settings)
	for raw: Variant in option_awakening_auras.values():
		if is_instance_valid(raw): raw.call("apply_settings", presentation_settings)
	if is_instance_valid(hud) and hud.has_method("apply_option_awakening_settings"):
		hud.call("apply_option_awakening_settings", presentation_settings)
	if is_instance_valid(player):
		player.motion.reduced_motion = presentation_settings.reduced_motion
		if bool(presentation_settings.reduced_motion): player.motion.visual_hold = 0.0
	if is_instance_valid(monsters_root):
		for monster: Node in monsters_root.get_children():
			if monster is TwilightMonster:
				monster.motion.reduced_motion = presentation_settings.reduced_motion
				if bool(presentation_settings.reduced_motion): monster.motion.visual_hold = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and _background_save_task >= 0:
		# Never leave a save half-owned: the worker finishes its atomic write.
		_finish_background_save(true)
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		# M87: after focus loss release held keys whose live state is exactly pressed, so
		# movement/attack does not stay stuck (Android background, alt-tab). Keys the
		# engine already released, or a second focus notification, release nothing.
		FOCUS_INPUT_RELEASE.release_game_input()
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(player):
		# Leaving the app flushes anything still waiting out its quiet window.
		_save_game(true)

func constrain_original_motion(actor: CharacterBody2D) -> void:
	if field_map is NativePngField and actor.velocity!=Vector2.ZERO:
		var delta: float=actor.get_physics_process_delta_time()
		if delta<=0.0: return
		var motion: Vector2=actor.velocity*delta
		var origin: Vector2=actor.global_position
		if not field_map.line_clear(origin,origin+motion):
			# Never push through a genuine obstacle. Preserve a legal tangent or
			# one safe axis when a diagonal foot sweep grazes coarse PNG cells.
			var contact:=KinematicCollision2D.new()
			var options: Array[Vector2]=[]
			if actor.test_move(actor.global_transform,motion,contact):
				options.append(motion.slide(contact.get_normal()))
			if actor is TwilightPlayer:
				var horizontal:=Vector2(motion.x,0.0)
				var vertical:=Vector2(0.0,motion.y)
				if absf(motion.x)>=absf(motion.y):
					options.append(horizontal);options.append(vertical)
				else:
					options.append(vertical);options.append(horizontal)
			actor.velocity=Vector2.ZERO
			for candidate: Vector2 in options:
				if candidate.length_squared()<0.000001: continue
				if not field_map.line_clear(origin,origin+candidate): continue
				if actor.test_move(actor.global_transform,candidate): continue
				actor.velocity=candidate/delta
				break
	if field_map is OriginalPlayableField and actor.velocity != Vector2.ZERO:
		var delta: float=actor.get_physics_process_delta_time()
		if delta<=0.0: return
		var origin: Vector2=actor.global_position
		var motion: Vector2=actor.velocity*delta
		var target: Vector2=origin+motion
		var source_clear: bool = field_map.source_line_clear(origin,target) if field_map is RemakePlayableField else field_map.line_clear(origin,target)
		if not source_clear:
			actor.velocity=Vector2.ZERO
			# Source-grid diagonal checks can reject a step that has a clear
			# cardinal component. Try only physically and navigationally legal
			# axes; never turn source walls into traversable terrain.
			if actor is TwilightPlayer:
				var horizontal:=Vector2(motion.x,0.0)
				var vertical:=Vector2(0.0,motion.y)
				var options: Array[Vector2]=[]
				if absf(motion.x)>=absf(motion.y):
					options.append(horizontal);options.append(vertical)
				else:
					options.append(vertical);options.append(horizontal)
				for candidate: Vector2 in options:
					if candidate.length_squared()<0.000001: continue
					if not field_map.line_clear(origin,origin+candidate): continue
					if actor.test_move(actor.global_transform,candidate): continue
					actor.velocity=candidate/delta
					break
		elif field_map is RemakePlayableField and not field_map.point_clear(target):
			# A streamed wall lets move_and_slide resolve the real circular foot
			# and keep its tangent motion. Zeroing first deadlocks glancing paths.
			# Off-screen actors still stop at source edges absent from physics.
			if not actor.test_move(actor.global_transform,target-actor.global_position): actor.velocity = Vector2.ZERO

func return_from_original_map() -> bool:
	if current523_aden_source_active():
		close_current523_aden_play()
		return true
	return SOURCE_TRAVEL.return_home(self)

## Bag item dragged onto the field: confirmation (quantity for stacks) first.
func request_inventory_delete(reference: String) -> Dictionary:
	return preload("res://scripts/loot/inventory_item_delete.gd").request(self,reference)

func request_inventory_ground_drop(reference: String, target: Vector2) -> Dictionary:
	return INVENTORY_GROUND_TRANSFER.request(self,reference,target)

func _drop_inventory_reference(reference: String, target: Vector2, count: int = 1) -> bool:
	# Source (original 523) fields keep their floor under their own map ID
	# (ground_loot_manager restores m523_land_* records like other maps).
	return INVENTORY_GROUND_TRANSFER.drop(self,reference,target,count)

func _on_secondary_doll_requested(identity: String) -> void:
	if _option_awakening_busy():return
	if expedition_local.reserved(identity):
		hud.show_message("탐험·정산 대기 기록에 사용 중인 카드는 추가 소환할 수 없습니다.")
		return
	var result: Dictionary=option_awakening.select_subslot(identity)
	if not result.ok:hud.show_message(str(result.error));return
	_update_companion(0)
	_update_hud()
	hud.show_message("추가 인형 소환 해제" if identity.is_empty() else "추가 인형 선택 완료"+(" · 인형 원본 리소스 설치 필요" if not is_instance_valid(secondary_doll_visual) or secondary_doll_visual.status!="source_native" else ""))

func _skill_awakening_vitals_for_state(next: Dictionary) -> Dictionary:
	var previous: Dictionary=skill_awakening.progress
	skill_awakening.progress=next;skill_awakening._has_cache=false;_invalidate_equipment_static()
	var result: Dictionary={"hp":mini(hp,_effective_max_hp()),"mp":mini(mp,_effective_max_mp())}
	skill_awakening.progress=previous;skill_awakening._has_cache=false;_invalidate_equipment_static()
	return result

func _option_awakening_vitals_for_state(next: Dictionary) -> Dictionary:
	var previous: Dictionary=option_awakening.progress
	var previous_vitals: Dictionary={"hp":hp,"mp":mp}
	var previous_buffs: Dictionary=active_skill_buffs.duplicate(true)
	option_awakening.progress=next;_invalidate_equipment_static()
	var result: Dictionary={"hp":mini(int(previous_vitals.hp),_effective_max_hp()),"mp":mini(int(previous_vitals.mp),_effective_max_mp())}
	option_awakening.progress=previous;_invalidate_equipment_static()
	_restore_card_selection_preview(previous_vitals,previous_buffs)
	return result

func _restore_card_selection_preview(vitals: Dictionary, buffs: Dictionary) -> void:
	# Resolving temporary source levels may refresh derived buffs and clamp
	# live vitals. A quote must restore those before the atomic writer runs.
	active_skill_buffs=buffs
	hp=int(vitals.hp);mp=int(vitals.mp)
	if original_skills != null:
		original_skills.relic_buff_signature=""
		original_skills.refresh_relic_buffs()

func _on_secondary_relic_requested(identity: String) -> void:
	if _option_awakening_busy():return
	var result: Dictionary=option_awakening.select_relic_subslot(identity)
	if not result.ok:hud.show_message(str(result.error));return
	_invalidate_equipment_static()
	_update_companion(0);_update_hud()
	if is_instance_valid(hud.relic_reference_view):hud.relic_reference_view.refresh_state()
	hud.show_message("추가 성물 소환 해제" if identity.is_empty() else "추가 성물 선택 완료"+(" · 성물 원본 리소스 설치 필요" if not is_instance_valid(secondary_relic_visual) or secondary_relic_visual.status!="source_native" else ""))

## 보고서2 R2: class/gender cards (BuffCardByClass) follow the playing character.
func _sync_card_class_variant() -> bool:
	return BASE508.set_character_context(BASE508.source_class_id(job_class),source_gender_id)

func _source_visual_context() -> Dictionary:
	var options: Dictionary = source_card_visual_options.duplicate(true)
	for record: Dictionary in equipped_catalog.values():
		if BASE508.native(record) and record.has("source_active_custom_option_id") and not options.has(str(record.sourceId)):
			options[str(record.sourceId)] = int(record.source_active_custom_option_id)
	return {"class_id":BASE508.source_class_id(job_class),"gender_id":source_gender_id,"active_card_options":options,"local_weapon_type":_current_weapon_type(),"source_weapon_type":preload("res://scripts/animation/source_weapon_banks.gd").local_type(_current_weapon_type())}

## Genders the original Class table gives a picture for this class (1 Male,
## 2 Female). Without the installed 523 tables both stay selectable.
func source_class_genders(job_name: String) -> Array:
	var bank: GDScript = preload("res://scripts/resources/current523_source_bank.gd")
	if not bool(bank.options(_source_visual_context()).get("enabled", false)): return [1, 2]
	var tables: Array[String] = ["Class", "Gender"]
	if not bool(bank.source_tables(_source_visual_context(), tables).get("ok", false)): return [1, 2]
	var row: Dictionary = bank.table_row("Class", BASE508.source_class_id(job_name))
	if row.is_empty(): return [1, 2]
	var genders: Array = []
	if int(row.get("MaleSpriteID", 0)) > 0: genders.append(1)
	if int(row.get("FemaleSpriteID", 0)) > 0: genders.append(2)
	return genders if not genders.is_empty() else [1, 2]

## True when the installed 523 bank draws the character (by class and gender).
func source_gender_required() -> bool:
	return bool(preload("res://scripts/resources/current523_source_bank.gd").options(_source_visual_context()).get("enabled", false))

## True when the installed 523 bank draws the character but no gender is known.
func _source_gender_needed() -> bool:
	return source_gender_id not in [1, 2] and source_gender_required()

func set_source_character_gender(gender_id: int) -> bool:
	if gender_id not in [0,1,2]: return false
	if not CHARACTER_ACCOUNT.session.is_empty() and source_gender_id!=gender_id: return false
	source_gender_id = gender_id
	if _sync_card_class_variant(): _invalidate_equipment_static()
	_restore_equipped_visuals()
	_update_hud()
	_save_game(true)
	return true

func get_expedition_catalog() -> RefCounted:
	if not expedition_pack_checked:
		expedition_pack_checked = true
		expedition_catalog.configure_arguments()
	return expedition_catalog

func expedition_owned_cards() -> Array:
	# Match canonical source identity and deck, never names or legacy integer IDs.
	var result: Array = []
	for category: String in CARD_DRAW_FUSION.CATEGORIES:
		var deck: int = {"변신": 1, "마법인형": 2, "성물": 98}.get(category, 0)
		for card: Dictionary in catalog_db.get(category, []):
			var identity := CARD_DRAW_FUSION.card_id(card)
			var source_id := int(card.get("source_card_id", 0))
			var card_namespace:String="m523" if card.get("source")=="lineagem_patch523" else "m508"
			if card.get("source") not in ["lineagem_base508","lineagem_patch523"] or str(card.get("sourceId",""))!="%s:%d:%d"%[card_namespace,deck,source_id] or int(card.get("source_deck_id",0))!=deck:
				continue
			if card_draw_fusion.owned.get(category, {}).get(identity, false) != true:
				continue
			var entry: Dictionary = skill_awakening.progress.cards.get(identity, {})
			# Corrupt/blocked skill saves cannot supply an eligible level.
			var level := 0 if skill_awakening.save_blocked or not skill_awakening.problem.is_empty() else int(entry.get("level", 0))
			if not skill_awakening.core.spell_allowed(identity, int(entry.get("spell_id", 0))) or skill_awakening.core.profile(identity, level).is_empty():
				level = 0
			result.append({"source_id": source_id, "owned": true, "skill_awaken_level": level, "identity": identity,"visual_pending":bool(card.get("source_expedition_definition_only",false))})
	return result

func inspect_expedition(spot_id: int, identities: Array) -> Dictionary:
	var selected: Array = []
	for identity in identities:
		for card: Dictionary in expedition_owned_cards():
			if card.identity == identity:
				selected.append(card)
	return get_expedition_catalog().inspect(spot_id, selected)

func request_expedition_start(spot_id: int, identities: Array, buff_ids: Array = []) -> Dictionary:
	return expedition_local.start(spot_id, identities, buff_ids)

func set_source_card_visual_option(source_id: String, active_option_id: int) -> bool:
	if active_option_id < 0: return false
	var record: Dictionary = BASE508.canonical({"source":"lineagem_base508","sourceId":source_id})
	if not record.has("source_card_id"): return false
	var rule: Dictionary = BASE508.identity_rules().get(int(record.source_card_id), {})
	if str(rule.get("selection_kind", "")) != "base_polymorph_or_declared_custom_sprite_option": return false
	if active_option_id > 0:
		var declared: bool = false
		for option: Dictionary in rule.get("custom_options", []):
			if int(option.native_option.ID) == active_option_id: declared = true
		if not declared: return false
		source_card_visual_options[source_id] = active_option_id
	else:
		source_card_visual_options[source_id] = 0 # Explicit source base, including over a saved active option.
	_restore_equipped_visuals()
	_update_hud()
	_save_game(true)
	return true


## Original models needed only while their window is open are released once
## boot is done (Lineage M style); each reloads on its next use.
func _release_idle_original_models() -> void:
	# Original definition reader caches kept from start-up (rows stay on
	# storage; a later query reads them again with the same values).
	BOOT_LOG.mark("definition_caches_released", preload("res://scripts/resources/current523_definition_rows.gd").release_caches())
	source_shop.release_catalog()
	# A dungeon in progress keeps its model.
	for service: Variant in [source_dungeon_runs, dungeon_play]:
		var running: Variant = service.get("state")
		if running is Dictionary and running.get("active") is Dictionary and not (running.active as Dictionary).is_empty(): return
	source_dungeons.release()

func _load_source_dungeon_pack() -> void:
	source_dungeons.load_configured()

func install_source_dungeon_pack(path: String) -> Dictionary:
	var result: Dictionary = source_dungeons.install_pack(path)
	if bool(result.get("ok",false)): DUNGEON_ECONOMY.install_definitions(self,source_dungeons)
	if bool(result.get("ok",false)): dungeon_play.install_items()
	return result

func source_dungeon_entries(kind: String, hard: bool = false) -> Array:
	var competition: Script=load("res://scripts/dungeons/competition_dungeon523.gd")
	if competition.FAMILY.has(kind): return competition.entries(int(competition.FAMILY[kind]))
	return source_dungeons.entries(kind,hard)

## Entry UIs share one overlay/duplicate-input gate; transactional owners
## retain level, tariff, ticket, save and current-game access policy checks.
func run_dungeon_loading(operation: Callable) -> Dictionary:
	return await preload("res://scripts/boot/dungeon_loading.gd").run(self,operation)

func run_map_loading(operation: Callable) -> Dictionary:
	return await MAP_LOADING.run(self,operation,"지도 이동 준비")


# Prepared spell destinations commit in the same input call. A cold point
# enters the same loading/rollback flow as a scroll, with payment still owned
# by the spell or bookmark.
func travel_map_point(destination: Vector2, commit: Callable, always_load: bool = false) -> Dictionary:
	if MAP_LOADING.busy(self): return {"ok":false}
	if not current523_aden_source_active(): return commit.call()
	var controller: RefCounted = _aden_play_controller()
	if not always_load and controller.call("same_land_prepared",destination): return commit.call()
	return await run_map_loading(_commit_prepared_map_point.bind(destination,commit))


func _commit_prepared_map_point(destination: Vector2, commit: Callable) -> Dictionary:
	if not commit.is_valid() or not await prepare_map_point(destination): return {"ok":false}
	return commit.call()


# Called inside the travel transaction before any item debit or MP spend.
func prepare_map_point(destination: Vector2) -> bool:
	if not current523_aden_source_active(): return true
	var controller: RefCounted = _aden_play_controller()
	if await controller.call("prepare_same_land",destination): return true
	hud.show_message(str(controller.get("problem")))
	return false


func refresh_map_after_jump() -> void:
	player.camera.force_update_scroll()
	if current523_aden_source_active() and is_instance_valid(field_renderer):
		field_renderer.refresh_visible()


func competition523_quote(id: int) -> Dictionary:
	return preload("res://scripts/dungeons/competition_dungeon523.gd").quote(self,id)

func competition523_enter(id: int, ticket: Dictionary) -> Dictionary:
	return call("_competition523_enter_impl",id,ticket,false)

func competition523_enter_loading(id: int, ticket: Dictionary) -> Dictionary:
	return await _competition523_enter_impl(id,ticket,true)

func _competition523_enter_impl(id: int, ticket: Dictionary, loading: bool) -> Dictionary:
	if death_recovery.blocked() or int(hp)<=0 or player.movement_locked or player.is_stunned() or player.is_held() or player.is_feared() or not charge_skill.is_empty() or patch523_npc_spells.blocks("CannotTeleport"):
		return {"ok":false,"reason":"현재 이동 상태에서는 던전 입구에 갈 수 없습니다."}
	var fresh: Dictionary=competition523_quote(id)
	if not fresh.get("ok",false):return fresh
	if ticket!=fresh.ticket:return {"ok":false,"reason":"목적지 또는 비용이 바뀌었습니다. 다시 선택하세요."}
	if (fresh.changes as Dictionary).is_empty():return {"ok":false,"reason":"원본 비용 저장을 확인할 수 없습니다."}
	var row: Dictionary=fresh.row
	var controller: RefCounted=_aden_play_controller()
	var policy: String=preload("res://scripts/dungeons/competition_dungeon523.gd").POLICY
	var moved: bool
	if loading: moved = await controller.call("enter_source_land_loading",int(row.arrival.land_id),row.arrival.bounds,[policy],fresh.changes)
	else: moved = controller.call("enter_source_land",int(row.arrival.land_id),row.arrival.bounds,[policy],fresh.changes)
	var state: Dictionary=controller.call("last_source_transition")
	current523_aden_play_active=bool(controller.get("active"))
	if not moved or not state.get("saved",false):
		var detail: String=str(controller.get("problem"))
		return {"ok":false,"reason":"입구 이동 보류 · "+(detail if not detail.is_empty() else "지도 또는 저장 확인 필요"),"uncertain":bool(state.get("uncertain",false))}
	if fresh.changes.has("inventory"):
		inventory=fresh.changes.inventory
		hud.refresh_inventory(inventory)
		_update_hud()
	if player.auto_enabled:player.set_auto_enabled(false)
	return {"ok":true,"saved":true,"land_id":row.arrival.land_id,"cost":row.tariff.TeleportCost,
		"reason":str(row.name)+" 원본 입구로 이동했습니다 · 오프라인 탐방"}

func competition523_return() -> Dictionary:
	var model: Script=preload("res://scripts/dungeons/competition_dungeon523.gd")
	if model.lobby(int(orim_current_land().get("land_id",-1))).is_empty():return {"ok":false,"reason":"현재 월드 던전 입구에 있지 않습니다."}
	# Preserve the wallet, but require the same atomic cursor save as a paid entry.
	var permitted: Dictionary=preload("res://scripts/maps/current523_map_travel_payment.gd").quote(self,0)
	if not permitted.get("ok",false):return permitted
	return return_current523_source_to_aden({"gold":gold})

func source_dungeon_entry_check(kind: String, identifier: int) -> Dictionary:
	return source_dungeon_runs.check(identifier) if kind == "tower" else source_dungeons.entry_check(kind,identifier,level)

func source_dungeon_tower_cost(hard: bool) -> Dictionary:
	return source_dungeons.tower_entry_cost(hard)

func source_dungeon_recharge_preview(item_id: int) -> Dictionary:
	return source_dungeons.recharge_preview(item_id)

func source_dungeon_context(land_id: int) -> Dictionary:
	return source_dungeons.context_for_land(land_id)


func source_dungeon_host_context(stage_id: int) -> Dictionary:
	var local: Dictionary = LOCAL_TOWER.context(self,stage_id)
	if not local.is_empty(): return local
	# Source map owners provide this from their verified geometry/instance host.
	# Existing PC/source84 fields have no such method and cannot be relabelled.
	if field_map == null or not field_map.has_method("dungeon523_context"): return {}
	var value: Variant = field_map.call("dungeon523_context",stage_id)
	return value if value is Dictionary else {}

func source_dungeon_local_cycle() -> int:
	return LOCAL_TOWER.cycle(source_dungeon_runs.state,int(Time.get_unix_time_from_system()))

func configure_source_dungeon_local(enabled: bool, time_scale: int) -> Dictionary:
	return source_dungeon_runs.configure_local(enabled,time_scale)

func source_dungeon_additional_busy() -> bool:
	return not dungeon_play.state.active.is_empty()

func source_dungeon_payment_plan(currency_id: int, amount: int) -> Dictionary:
	return DUNGEON_ECONOMY.payment(self,currency_id,amount)

func commit_dungeon_play(candidate: Dictionary, changes: Dictionary) -> Error:
	var staged: Dictionary={"source_dungeon_play":candidate}
	for key: String in ["inventory","item_instances","gold","experience","ainhasad_state","hp","mp"]:
		if changes.has(key):staged[key]=changes[key]
	var error: Error=_save_game(true,staged)
	if error!=OK:
		var saved: Variant=JSON.parse_string(FileAccess.get_file_as_string(save_path())) if FileAccess.file_exists(save_path()) else {}
		if saved is Dictionary and saved.get("source_dungeon_play",{})==JSON.parse_string(JSON.stringify(candidate,"",true,true)):
			dungeon_play.save_blocked=true;dungeon_play.problem="던전 저장 후보의 활성화가 불확실합니다. 저장을 다시 불러오세요."
		return error
	if staged.has("inventory"):inventory=staged.inventory
	if staged.has("item_instances"):item_instances=staged.item_instances
	if staged.has("item_instances"):_invalidate_equipment_static()
	if staged.has("gold"):gold=int(staged.gold)
	if staged.has("experience"):experience=int(staged.experience)
	if staged.has("ainhasad_state"):ain_service.blessing=int(staged.ainhasad_state.blessing)
	if staged.has("hp"):hp=int(staged.hp)
	if staged.has("mp"):mp=int(staged.mp)
	return OK

func source_dungeon_reward_plan(rows: Array, payment: Dictionary) -> Dictionary:
	return DUNGEON_ECONOMY.rewards(self,rows,payment)

func commit_source_dungeon(candidate: Dictionary, changes: Dictionary) -> Error:
	var staged: Dictionary = {"source_dungeon523":candidate}
	for key: String in ["inventory","item_instances","gold","experience","ainhasad_state"]:
		if changes.has(key): staged[key] = changes[key]
	var result: Error = _save_game(true,staged)
	if result != OK:
		# The save writer can commit a migration candidate before activation fails.
		# Do not report rollback or retry a monetary delta against an uncertain file.
		if FileAccess.file_exists(save_path()):
			var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path()))
			var expected: Variant = JSON.parse_string(JSON.stringify(candidate,"",true,true))
			if persisted is Dictionary and persisted.get("source_dungeon523",{}) == expected:
				source_dungeon_runs.save_blocked = true
				source_dungeon_runs.problem = "던전 저장 후보는 기록되었지만 활성화가 확정되지 않았습니다. 저장을 다시 불러와 주세요."
		return result
	if staged.has("inventory"): inventory = staged.inventory
	if staged.has("item_instances"): item_instances = staged.item_instances
	if staged.has("gold"): gold = int(staged.gold)
	if staged.has("experience"): experience = int(staged.experience)
	if staged.has("ainhasad_state"): ain_service.blessing = int(staged.ainhasad_state.blessing)
	return OK

func source_dungeon_action(action: String, stage_id: int = 0) -> Dictionary:
	var result: Dictionary
	match action:
		"begin": result = source_dungeon_runs.begin(stage_id)
		"claim": result = source_dungeon_runs.claim()
		"purchase": result = source_dungeon_runs.buy_attempt(stage_id)
		"immediate": result = source_dungeon_runs.immediate(stage_id)
		"leave": result = source_dungeon_runs.fail_run()
		"retry": result = _retry_dungeon_events()
		_: return {"ok":false,"reason":"알 수 없는 던전 작업입니다."}
	if result.get("ok",false):
		var level_before: int = level
		_check_level_up()
		if level != level_before: _request_deferred_save()
		_update_hud()
		hud.show_message("던전 기록을 저장했습니다.")
	else: hud.show_message(str(result.get("reason"," ".join(result.get("reasons",[])))))
	return result

func _source_dungeon_kill(monster: TwilightMonster) -> void:
	if not is_instance_valid(monster) or not monster.dead or monster.get_parent() != monsters_root: return
	var run: Dictionary = source_dungeon_runs.state.active
	if not run.is_empty() and run.get("host_kind","") == "twilight_local":
		LOCAL_TOWER.kill(self,monster,run)
		return
	if run.is_empty() or run.status != "active" or monster.get_meta("dungeon523_run_id","") != run.id: return
	var actor: String = str(monster.get_meta("dungeon523_actor_id",""))
	if actor.is_empty(): return
	_queue_dungeon_event("kill",actor+":"+str(monster.life_id),0)

func _source_dungeon_pickup(drop: Dictionary) -> void:
	var run: Dictionary = source_dungeon_runs.state.active
	var record: Variant = drop.get("item_record",{})
	if not run.is_empty() and run.get("host_kind","") == "twilight_local" and run.status == "active" and record is Dictionary and record.get("source","") == "twilight_local_dungeon" and record.get("dungeon_run_id","") == run.id:
		_queue_dungeon_event("pickup",str(drop.get("id","")),int(record.get("declared_goal_id",0)))
		return
	if run.is_empty() or run.status != "active" or drop.get("dungeon523_run_id","") != run.id or not record is Dictionary: return
	if record.get("source_snapshot","") != "current523" or record.get("source","") != "lineagem_current523": return
	_queue_dungeon_event("pickup",str(drop.get("id","")),int(record.get("source_item_class_id",0)))

func _queue_dungeon_event(kind: String, token: String, item_id: int) -> void:
	if token.is_empty(): return
	var result: Dictionary = source_dungeon_runs.record_event(kind,token,item_id)
	if not bool(result.get("ok",false)):
		pending_dungeon_events[kind+":"+token] = {"kind":kind,"token":token,"item_id":item_id,"run_id":str(source_dungeon_runs.state.active.get("id",""))}
		hud.show_message(str(result.get("reason","던전 진행 저장 재시도가 필요합니다.")))

func _retry_dungeon_events() -> Dictionary:
	for key: String in pending_dungeon_events.keys():
		var event: Dictionary = pending_dungeon_events[key]
		var run: Dictionary = source_dungeon_runs.state.active
		if run.is_empty() or run.status != "active" or event.get("run_id","") != run.id:
			pending_dungeon_events.erase(key); continue
		var result: Dictionary = source_dungeon_runs.record_event(event.kind,event.token,int(event.item_id))
		if not bool(result.get("ok",false)): return result
		pending_dungeon_events.erase(key)
	return {"ok":true}


func _refresh_source_dungeon_panel() -> void:
	if is_instance_valid(hud) and hud.has_method("refresh_source_dungeon_progress"):
		hud.call("refresh_source_dungeon_progress")




func _patch523_item_allowed() -> bool:
	if not patch523_npc_spells.blocks("CannotUseItem"): return true
	if is_instance_valid(hud): hud.show_message("현재 상태에서는 아이템을 사용할 수 없습니다")
	return false

func apply_patch523_healing(amount: int, potion: bool = false) -> void:
	if not potion and amount > 0: amount = EQUIPMENT523_COMBAT.magical_heal(_all_equipped_records(),amount)
	var adjusted: int = patch523_npc_spells.extensions.healing(amount,potion)
	if adjusted < 0: apply_patch523_secondary_damage(-adjusted,"역치유")
	else: hp = mini(_effective_max_hp(),hp+adjusted)
	if adjusted > 0: patch523_npc_spells.extensions.on_player_event("healed")

func apply_patch523_secondary_damage(amount: int, label: String) -> void:
	if amount <= 0 or hp <= 0: return
	hp = maxi(0,hp-amount)
	player.show_status_text(label+" "+str(amount))
	hud.append_log("%s 피해 %d · TWILIGHT 자체 결합식" % [label,amount])
	if hp <= 0:
		_respawn_player(label+" 피해로 사망 후 부활했습니다"); _update_hud()
	else: _refresh_combat_hud()

func resolve_patch523_npc_hit(actor: TwilightMonster, raw: int, spell: Dictionary, channel: String = "magic") -> bool:
	# Keep one authoritative hit/crit/counter/resistance/death call. Suppress
	# unrelated legacy status fields for this exact source spell only.
	if not is_instance_valid(actor): return false
	var life: int = actor.life_id
	var before_hp: int = hp
	var old: Dictionary = {}
	for kind: String in ["stun","silence","hold","fear","poison","bleed"]:
		for suffix: String in ["_duration","_accuracy"]:
			var property: String = kind + suffix
			old[property] = actor.get(property)
			actor.set(property,0)
	var old_element: String = actor.attack_element
	var element: Dictionary = patch523_npc_spells.catalog.row("ElementalType",int(spell.get("ElementalTypeID",0)))
	var channels: Dictionary = {"None":"physical","Fire":"fire","Water":"water","Air":"wind","Earth":"earth","Light":"holy","Dark":"dark"}
	if not spell.is_empty() and channels.has(element.get("Name","")): actor.attack_element = channels[element.Name]
	var guard_kind: String = patch523_npc_spells.guard_attack_kind(spell,channel)
	_on_player_hit(actor,raw,channel,not spell.is_empty(),guard_kind)
	if is_instance_valid(actor) and actor.life_id == life:
		for property: String in old: actor.set(property,old[property])
		actor.attack_element = old_element
	return hp < before_hp # Final host HP outcome, not a fabricated native success.



func _resume_death523() -> void:
	death_recovery.resume()

func _mastery_actual_weapon_type() -> int:
	if _stat_memo_depth == 0: return _mastery_actual_weapon_type_uncached()
	var memo_key: String = "mastery_weapon_type"
	if not _stat_memo.has(memo_key): _stat_memo[memo_key] = _mastery_actual_weapon_type_uncached()
	return _stat_memo[memo_key]

func _mastery_actual_weapon_type_uncached() -> int:
	return preload("res://scripts/animation/source_weapon_banks.gd").local_type(_current_weapon_type())


func _pve_reduction_percent(attack_type: String="",attacker_is_pc:bool=false) -> float:
	var protection: Dictionary=_patch523_protection_effects()
	var projection: bool=protection523!=null and bool(protection523.get("state").get("policy",{}).get("project_pvp_to_pve",false))
	var protection_percent: float=float(protection.get("possession_percent_raw",0))/10000.0 if projection else 0.0
	var oracle:Script=preload("res://scripts/loot/native_manual_scrolls523.gd")
	var oracle_guard:int=oracle.oracle_damage_percent(active_item_buffs,attacker_is_pc,"source_manual_pve_guard_pct") if active_item_buffs.has(oracle.ORACLE_KEY) else 0
	var percent: float=clampf(protection_percent+oracle_guard+_active_item_buff_total("pve_damage_reduction_pct")+_active_item_buff_total("pvp_damage_reduction_pct")+_catalog_stat_sum("pvp_damage_reduction_pct")+_catalog_stat_sum("pve_damage_reduction_pct")+_equipment_inven_sum("pve_damage_reduction_pct"),0.0,90.0)
	if attack_type in ["melee","ranged","magic"]:
		var growth:int=0
		if attack_type!="melee":
			var catalyst:Variant=active_item_buffs.get("아우라키아의 성장 물약")
			if catalyst is Dictionary: growth=int(catalyst.get("source_371558_magic_reduction" if attack_type=="magic" else "source_371558_ranged_reduction",0))
		percent=clampf(percent+int(_equipment_inven_sum(attack_type+"_damage_reduction_pct"))+growth,0,90)
	return percent

func get_regional_return_enabled() -> bool:
	return ui_preferences.get(REGIONAL_RETURN.SETTING, false) == true

func set_regional_return_enabled(enabled: bool) -> void:
	if get_regional_return_enabled() == enabled: return
	ui_preferences[REGIONAL_RETURN.SETTING] = enabled
	_refresh_regional_return_slots()
	_request_deferred_save()

func _regional_return_land() -> int:
	var context: Dictionary = field_map.data if field_map != null else {}
	if field_map is OriginalPlayableField and field_map.definition.has("source_land_id"):
		context = context.duplicate()
		context["source_land_id"] = field_map.definition.source_land_id
	# Current source geometry needs explicit M Land identity, never a PC host alias.
	if field_map is OriginalPlayableField and bool(field_map.get_meta("source_map84",false)) and not context.has("source_land_id"):
		return 0
	return REGIONAL_RETURN.land_for(active_map_id, active_map, context)

func effective_quickslots() -> Array:
	var result: Array = []
	var land: int = _regional_return_land()
	for value: Variant in quickslots:
		result.append(REGIONAL_RETURN.effective(value, land, get_regional_return_enabled(), inventory, _find_catalog_item_record) if value is Dictionary else {})
	return result

func _refresh_regional_return_slots() -> void:
	if is_instance_valid(hud) and hud.has_method("set_quickslot_state"):
		hud.set_quickslot_state(effective_quickslots(), inventory, _combined_active_buffs(), self_mode_enabled)
	regional_return_settings_updated.emit()

func regional_return_status() -> String:
	if not get_regional_return_enabled(): return "자동 변경 꺼짐 · 원래 귀환 슬롯 사용"
	var land: int = _regional_return_land()
	if not REGIONAL_RETURN.DATA.data.lands.has(str(land)): return "현재 지역: 변경 대상 아님"
	var original_m_field: bool=field_map!=null and bool(field_map.get_meta("current523_source_field",false))
	var suffix: String = " · TWILIGHT 대응 지도" if not original_m_field and REGIONAL_RETURN.DATA.data.host_bindings.has(active_map_id) else ""
	var key: String = REGIONAL_RETURN.target_key(126424, inventory, _find_catalog_item_record)
	return "잊혀진 귀환 주문서 적용 · 보유 %d개%s" % [int(inventory.get(key, 0)), suffix]

func regional_return_stack(item_name: String) -> Dictionary:
	return REGIONAL_RETURN.stack_identity(item_name, _find_catalog_item_record(item_name))
# Dedicated MonsterBook API; never changes population/spawn definitions.
func monsterbook_action_status(action: String, book_id: int, level_id: int) -> String:
	return monsterbook523_runtime.action_status(action, book_id, level_id)

func request_monsterbook_action(action: String, book_id: int, level_id: int) -> Dictionary:
	return monsterbook523_runtime.request_action(action, book_id, level_id)
func _tj_capture_awakening(category: String, identity: String, result: Dictionary) -> Dictionary:
	var before: Dictionary=tj_coupons.core.export_state()
	tj_coupons.capture_awakening(category,identity,result)
	return before
## Register exact current523 M originals separately from the live map field.
## Rendering and walking need independently validated M spatial semantics.
var _current523_aden_sources: RefCounted = null
var current523_aden_problem: String = ""
var current523_aden_review: Control = null
var current523_aden_review_active: bool = false
var _current523_aden_resume: Dictionary = {}
var _current523_aden_review_from_boot: bool = false
signal current523_aden_review_closed
var current523_aden_play_active: bool = false
var current523_aden_play_problem: String = ""
## True only while a caller that discards the field renderer closes 523 play.
var current523_prior_rebuild_suppressed: bool = false
var _current523_aden_play_controller: RefCounted
var _current523_source_definition_provider: RefCounted
var _current523_world_map_input: Node
var current523_world_map_status: Dictionary={}
signal current523_aden_play_changed(active: bool, detail: String)

func _world_map_input() -> Node:
	if not is_instance_valid(_current523_world_map_input):
		_current523_world_map_input=preload("res://scripts/maps/current523_world_map_input.gd").new()
		_current523_world_map_input.name="Current523WorldMapInput"
		add_child(_current523_world_map_input)
	return _current523_world_map_input

func bind_current523_world_map(image_adapter: RefCounted,offered_worlds: Dictionary,options: Dictionary) -> Dictionary:
	current523_world_map_status=_world_map_input().call("configure",self,image_adapter,offered_worlds,options)
	return current523_world_map_status.duplicate(true)

func _bind_current523_world_map_from_settings() -> void:
	current523_world_map_status=_world_map_input().call("configure_from_settings",self)

## 오림의 흔적: move to a stage's original Land / back to the starting point.
func orim_enter_land(land_id: int, bounds: Array) -> Dictionary:
	return call("_orim_enter_land_impl",land_id,bounds,false)

func orim_enter_land_loading(land_id: int, bounds: Array) -> Dictionary:
	return await _orim_enter_land_impl(land_id,bounds,true)

func _orim_enter_land_impl(land_id: int, bounds: Array, loading: bool) -> Dictionary:
	var controller: RefCounted = _aden_play_controller()
	var moved: bool
	if loading: moved = await controller.call("enter_source_land_loading", land_id, bounds)
	else: moved = controller.call("enter_source_land", land_id, bounds)
	return {"ok": moved, "reason": str(controller.get("problem"))}

func orim_current_land() -> Dictionary:
	return _aden_play_controller().call("current_source_land")

## 특수 던전 (시간 던전): "" when the original Land can be entered (523 field
## active, its map bundle in the installed pack), else the reason.
func dungeon523_land_ready(land_id: int) -> String:
	return str(_aden_play_controller().call("source_land_ready", land_id))

## 특수 던전 entry waive (TWILIGHT 근사, 2026-11-22): the dungeon's own
## SpecialDungeon LandTeleport is the way in, so besides the map-teleport list
## the in-Land rules its Lands declare do not gate that entry: NoDropItem,
## NoLoseExperience (death penalties inside), NoBookmark, Underground,
## TakeDeathPenaltyFromNPC, BlockLoginEnter (logging in there, not teleporting
## in), NoSpell, NoHellVirtuePoint, KillStreakClassID. MinLevel / MaxLevel and
## every other declaration still hold.
const DUNGEON523_ENTRY_WAIVE: Array[String] = ["NoTeleport","TurnOffAutoForTeleport","LandPlayerSocketTimeoutSecond","ObjectLazyLoad","IdleTime","UsableCallClan","LandCondition","CompetitionDungeonLand","NoDropItem","NoLoseExperience","NoBookmark","Underground","TakeDeathPenaltyFromNPC","BlockLoginEnter","NoSpell","NoHellVirtuePoint","KillStreakClassID"]

## 특수 던전 나가기 / time over: back to the start village (기란 마을); the
## dungeon Land's own rules (NoTeleport, ...) do not keep the player inside.
func dungeon523_return_to_village() -> Dictionary:
	if player.auto_enabled: player.set_auto_enabled(false)
	portal_cooldown = 0.0
	return return_current523_source_to_aden({}, DUNGEON523_ENTRY_WAIVE.duplicate())

## 특수 던전 entry: moves into the dungeon's original Land (LandTeleport
## Territories box) under DUNGEON523_ENTRY_WAIVE (MinLevel judged) and saves `save_changes` (the entry cost and the dungeon
## session) with the arrival. Not moved = nothing saved, nothing charged.
func dungeon523_enter_land(land_id: int, bounds: Array, save_changes: Dictionary) -> Dictionary:
	return call("_dungeon523_enter_land_impl",land_id,bounds,save_changes,false)

func dungeon523_enter_land_loading(land_id: int, bounds: Array, save_changes: Dictionary) -> Dictionary:
	return await _dungeon523_enter_land_impl(land_id,bounds,save_changes,true)

func _dungeon523_enter_land_impl(land_id: int, bounds: Array, save_changes: Dictionary, loading: bool) -> Dictionary:
	if death_recovery.blocked(): return {"ok":false,"reason":"사망 처리 중에는 입장할 수 없습니다."}
	if save_changes.is_empty(): return {"ok":false,"reason":"이동 저장 변경 없음"}
	var controller: RefCounted = _aden_play_controller()
	var moved: bool
	if loading: moved = await controller.call("enter_source_land_loading", land_id, bounds, DUNGEON523_ENTRY_WAIVE.duplicate(), save_changes)
	else: moved = controller.call("enter_source_land", land_id, bounds, DUNGEON523_ENTRY_WAIVE.duplicate(), save_changes)
	var transition: Dictionary = controller.call("last_source_transition")
	current523_aden_play_active = bool(controller.get("active"))
	if moved and player.auto_enabled: player.set_auto_enabled(false)
	return {"ok": moved, "reason": str(controller.get("problem")), "saved": bool(transition.get("saved",false)), "uncertain": bool(transition.get("uncertain",false))}

func content523_spawn_metrics() -> Dictionary:
	return _aden_play_controller().call("source_spawn_metrics")

func content523_cell_point(cell: Vector2i) -> Vector2:
	return _aden_play_controller().call("source_cell_point", cell)

## Content teleport (에스카로스 · 요정 숲 · 영지 퀘스트) into an original Land
## with the in-Land rules `waive` names (scripts/content523/content523.gd).
func content523_enter_land(land_id: int, bounds: Array, waive: Array) -> Dictionary:
	var controller: RefCounted = _aden_play_controller()
	var moved: bool = controller.call("enter_source_land", land_id, bounds, waive)
	return {"ok": moved, "reason": str(controller.get("problem"))}

## In-Land rules a teleport item's arrival waives (user decisions 2026-11-15):
## NoTeleport, and the declarations that do not gate an entry (server/socket/
## loading/clan-call attributes, LandCondition, CompetitionDungeonLand) — they
## are passed, no clan or server feature is added. TurnOffAutoForTeleport is
## passed by turning auto hunting off on arrival. MinLevel is still judged
## (actor_level_requirement_not_met is never waived); any other declaration
## (NoTeleportCome, BlockLoginEnter, CloseTime, GivenSpellClassID, ...) still
## holds. Only this item path uses the list; map travel is unchanged.
const ITEM523_TELEPORT_WAIVE: Array[String] = ["NoTeleport","TurnOffAutoForTeleport","LandPlayerSocketTimeoutSecond","ObjectLazyLoad","IdleTime","UsableCallClan","LandCondition","CompetitionDungeonLand"]

## Original 523 fixed-destination teleport item (source523_item_effects
## location_teleport): enters the destination Land under its own entry rules
## except ITEM523_TELEPORT_WAIVE and saves `save_changes` (the item debit)
## with the arrival checkpoint. Not moved = nothing saved, item kept.
func item523_teleport_land(land_id: int, bounds: Array, save_changes: Dictionary) -> Dictionary:
	return call("_item523_teleport_land_impl",land_id,bounds,save_changes,false)

func item523_teleport_land_loading(land_id: int, bounds: Array, save_changes: Dictionary) -> Dictionary:
	return await _item523_teleport_land_impl(land_id,bounds,save_changes,true)

func _item523_teleport_land_impl(land_id: int, bounds: Array, save_changes: Dictionary, loading: bool) -> Dictionary:
	if save_changes.is_empty(): return {"ok":false,"reason":"이동 저장 변경 없음"}
	var controller: RefCounted = _aden_play_controller()
	var moved: bool
	if loading: moved = await controller.call("enter_source_land_loading",land_id,bounds,ITEM523_TELEPORT_WAIVE.duplicate(),save_changes)
	else: moved = controller.call("enter_source_land",land_id,bounds,ITEM523_TELEPORT_WAIVE.duplicate(),save_changes)
	var transition: Dictionary = controller.call("last_source_transition")
	current523_aden_play_active = bool(controller.get("active"))
	var auto_off: bool = false
	if moved:
		var entry: Variant = controller.get("_active_entry_context")
		for hold: Variant in (entry.get("content_entry_waived",[]) if entry is Dictionary else []):
			if hold is Dictionary and str(hold.get("type",{}).get("Name",""))=="TurnOffAutoForTeleport": auto_off = true
		if auto_off and player.auto_enabled: player.set_auto_enabled(false)
	return {"ok": moved, "reason": str(controller.get("problem")), "saved": bool(transition.get("saved",false)), "uncertain": bool(transition.get("uncertain",false)), "auto_turned_off": auto_off}

## Original 523 map teleport (텔레포터 NPC / 지역 이동 창): UIMapArea row `id`
## (current523_map_teleport.gd). Same entry rules as a teleport item
## (ITEM523_TELEPORT_WAIVE; MinLevel judged), the LandTeleport Adena price is
## saved with the arrival, auto hunting is turned off on arrival.
func current523_map_teleport(id: String) -> Dictionary:
	return call("_current523_map_teleport_impl",id,false)

func current523_map_teleport_loading(id: String) -> Dictionary:
	return await run_map_loading(_current523_map_teleport_impl.bind(id,true))

func _current523_map_teleport_impl(id: String, loading: bool) -> Dictionary:
	if death_recovery.blocked(): return {"ok":false,"reason":"사망 처리 중에는 이동할 수 없습니다"}
	if patch523_npc_spells.blocks("CannotTeleport") or player.is_stunned() or player.is_feared() or player.is_held() or int(hp)<=0 or not charge_skill.is_empty():
		return {"ok":false,"reason":"이동 불가 상태에서는 텔레포트할 수 없습니다"}
	if not current523_aden_source_active(): return {"ok":false,"reason":"원본 523 지도에서만 사용할 수 있습니다"}
	var quote: Dictionary = CURRENT523_MAP_TELEPORT.quote(self, id)
	if not quote.get("ok",false): return {"ok":false,"reason":str(quote.get("reason","텔레포트할 수 없습니다"))}
	var row: Dictionary = quote.row
	var controller: RefCounted = _aden_play_controller()
	var moved: bool
	if loading: moved = await controller.call("enter_source_land_loading",int(row.land_id),row.bounds,ITEM523_TELEPORT_WAIVE.duplicate(),quote.changes)
	else: moved = controller.call("enter_source_land",int(row.land_id),row.bounds,ITEM523_TELEPORT_WAIVE.duplicate(),quote.changes)
	var transition: Dictionary = controller.call("last_source_transition")
	current523_aden_play_active = bool(controller.get("active"))
	if not moved: return {"ok":false,"reason":"이동 보류: "+str(controller.get("problem")),"uncertain":bool(transition.get("uncertain",false))}
	# A 하딘 (다이아) price was saved with the arrival as the bag after the
	# debit; the live bag takes it now (the controller adopts only gold).
	if (quote.changes as Dictionary).has("inventory") and bool(transition.get("saved",false)):
		inventory = (quote.changes.inventory as Dictionary).duplicate(true)
		if is_instance_valid(hud): hud.refresh_inventory(inventory)
	if player.auto_enabled: player.set_auto_enabled(false)
	_update_hud()
	return {"ok":true,"reason":"텔레포트 완료 · %s · %d %s" % [str(row.name), int(row.price), str(row.get("currency_name","아데나"))],"land_id":int(row.land_id),"price":int(row.price),"currency_id":int(row.get("currency_id",1)),"saved":bool(transition.get("saved",false))}

func _aden_play_controller() -> RefCounted:
	if _current523_aden_play_controller == null:
		_current523_aden_play_controller = CURRENT523_ADEN_PLAY.new()
		_current523_aden_play_controller.call("configure", self)
	return _current523_aden_play_controller

func open_current523_aden_play(raw_root: String, tile_root: String, options: Dictionary) -> bool:
	var requested: Dictionary = options.duplicate(true)
	requested.enabled = true
	requested.raw_root = raw_root
	requested.tile_root = tile_root
	var controller: RefCounted = _aden_play_controller()
	if options.get("navigation_profile")==CURRENT523_ADEN_PLAY_OPTIONS.GENERIC and not bool(controller.get("active")) and not _prepare_current523_source_definitions_from_launch():
		current523_aden_play_changed.emit(current523_aden_play_active,current523_aden_play_problem)
		return false
	var opened: bool = bool(controller.call("open", requested))
	current523_aden_play_active = bool(controller.get("active"))
	current523_aden_play_problem = str(controller.get("problem"))
	if not opened: print("CURRENT523_SESSION_OPEN_FAILED ", JSON.stringify({"reason":current523_aden_play_problem}))
	var description: String = "S32 원문 지형·속성의 자체 해석으로 이동합니다. M 원작 판정은 미확정입니다." if options.get("navigation_profile") in [CURRENT523_ADEN_PLAY_OPTIONS.SOURCE,CURRENT523_ADEN_PLAY_OPTIONS.GENERIC] else "기존 TWILIGHT 통행을 사용하는 아덴 실험 플레이입니다."
	if opened and not current523_aden_play_problem.is_empty(): description += " · 포탈 보류: "+current523_aden_play_problem
	current523_aden_play_changed.emit(current523_aden_play_active, description if opened else current523_aden_play_problem)
	return opened

func close_current523_aden_play(remember_disabled: bool = true, reason: String = "") -> void:
	var controller: RefCounted = _aden_play_controller()
	var saved: bool = bool(controller.call("close", remember_disabled))
	current523_aden_play_active = false
	current523_aden_play_problem = reason
	var detail: String = "기존 지도로 복귀했습니다." if reason.is_empty() else "실험 플레이 종료: " + reason
	if not reason.is_empty(): print("CURRENT523_SESSION_CLOSED ", JSON.stringify({"reason":reason,"saved":saved}))
	if not saved:
		var close_problem: String = str(controller.get("problem"))
		if close_problem.is_empty(): close_problem = "종료 상태를 저장하지 못했습니다."
		current523_aden_play_problem = close_problem if reason.is_empty() else reason + " · " + close_problem
		detail += " " + close_problem
	current523_aden_play_changed.emit(false, detail)
	if is_instance_valid(hud) and (not reason.is_empty() or not saved): hud.show_message(detail)

func apply_current523_aden_play_options(options: Dictionary) -> bool:
	var controller: RefCounted = _aden_play_controller()
	var value: Dictionary = (controller.get("settings") as Dictionary).duplicate(true)
	value.merge(options, true)
	var applied: bool = bool(controller.call("apply_options", value))
	current523_aden_play_problem = str(controller.get("problem"))
	current523_aden_play_changed.emit(current523_aden_play_active, "자체 표시 보정을 적용했습니다." if applied else current523_aden_play_problem)
	return applied

func apply_current523_static_spr_options(value: Dictionary) -> bool:
	var controller: RefCounted = _aden_play_controller()
	var applied: bool = bool(controller.call("apply_static_spr_options", value))
	current523_aden_play_active = bool(controller.get("active"))
	current523_aden_play_problem = str(controller.get("problem"))
	current523_aden_play_changed.emit(current523_aden_play_active, "정적 SPR 설정을 적용했습니다." if applied else current523_aden_play_problem)
	return applied

func current523_aden_play_metrics() -> Dictionary:
	return _aden_play_controller().call("metrics")

## Source play hides the legacy actor root. Combat stays closed only while
## that hidden root is still the target set (no 523 source population
## attached); with the source population, monsters_root is the visible 523
## actor root and ordinary combat applies to it (user report 2026-11-14:
## auto and the attack button did nothing after saves moved into 523 Aden).
func _source_combat_targets_hidden() -> bool:
	if not current523_aden_source_active(): return false
	return not is_instance_valid(monsters_root) or not monsters_root.visible or monsters_root.process_mode == Node.PROCESS_MODE_DISABLED

func current523_aden_source_active() -> bool:
	return current523_aden_play_active and _current523_aden_play_controller != null and bool(_current523_aden_play_controller.get("source_owned"))

func prepare_current523_source_landing(raw_root: String, source_manifest_sha256: String, native_land_id: int, declared_bounds: Array, selection_policy: String = "EXACT_POINT_ONLY", allowed_raw_words: Array = CURRENT523_ADEN_PLAY_OPTIONS.SOURCE_WORDS) -> Dictionary:
	# Pure geographic preflight. It grants no admission, fee, prerequisite or
	# LandTeleport permission; the calling feature owns those native rules.
	var script: Script=load("res://scripts/maps/current523_source_field.gd")
	var candidate=script.new()
	if not candidate.configure_catalog(raw_root,source_manifest_sha256,native_land_id,{"allowed_raw_words":allowed_raw_words}):
		var failure: Dictionary={"ok":false,"reason":str(candidate.problem),"native_landing_rule_verified":false}
		candidate.close(); return failure
	var result: Dictionary=candidate.choose_source_landing(declared_bounds,selection_policy)
	candidate.close()
	return result

func current523_source_geographic_contract() -> Dictionary:
	return _aden_play_controller().call("source_geographic_contract")

func bind_current523_source_portal_provider(provider: RefCounted, verified_manifest_sha256: String) -> bool:
	var bound: bool=_aden_play_controller().call("bind_source_portal_provider",provider,verified_manifest_sha256)
	if bound:
		# A caller-owned replacement must not inherit the previous verified-pack
		# status or make the launch path skip its genuine production binding.
		if provider!=_current523_source_definition_provider: _current523_source_definition_provider=null
		current523_aden_play_changed.emit(current523_aden_play_active,"원문 포탈 정의 연결을 갱신했습니다.")
	return bound

func bind_current523_source_definition_pack(directory: String, expected_manifest_sha256: String, remember: bool=false) -> bool:
	var script: Script=load("res://scripts/maps/current523_source_portal_provider.gd")
	var candidate: RefCounted=script.new()
	if not candidate.load_pack(directory,expected_manifest_sha256):
		current523_aden_play_problem=str(candidate.problem); return false
	# This trusted candidate already implements the fixed provider contract.
	# All fallible persistence precedes the in-memory binding/generation change.
	if remember and CURRENT523_DEFINITION_PREFERENCES.write(directory,expected_manifest_sha256)!=OK:
		current523_aden_play_problem="원문 정의 폴더를 저장하지 못해 이전 연결을 유지합니다."; return false
	if not bind_current523_source_portal_provider(candidate,expected_manifest_sha256):
		current523_aden_play_problem="원문 정의 소비자를 연결하지 못했습니다."; return false
	_current523_source_definition_provider=candidate
	current523_aden_play_problem=""
	return true

func current523_source_definition_selection() -> Dictionary:
	return CURRENT523_DEFINITION_PREFERENCES.read()

func clear_current523_source_definition_selection() -> bool:
	if CURRENT523_DEFINITION_PREFERENCES.disable()!=OK:
		current523_aden_play_problem="원문 정의 연결 해제를 저장하지 못했습니다."; return false
	var cleared: bool=bind_current523_source_portal_provider(null,"")
	if cleared: current523_aden_play_problem=""
	return cleared

func _prepare_current523_source_definitions_from_launch() -> bool:
	var directory: String=""
	var pin: String=""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--patch523-world-links="): directory=argument.trim_prefix("--patch523-world-links=")
		if argument.begins_with("--patch523-world-links-sha256="): pin=argument.trim_prefix("--patch523-world-links-sha256=")
	if directory.is_empty() and pin.is_empty():
		var stored: Dictionary=CURRENT523_DEFINITION_PREFERENCES.read()
		if not stored.ok: current523_aden_play_problem=stored.problem; return false
		if not stored.configured:return true
		directory=stored.directory;pin=stored.manifest_sha256
	# Explicit launch arguments override saved selection, including invalid ones.
	if _current523_source_definition_provider!=null and _current523_source_definition_provider.matches_manifest(directory,pin): return true
	return bind_current523_source_definition_pack(directory,pin)

func current523_source_definition_status() -> Dictionary:
	if _current523_source_definition_provider==null or not _current523_source_definition_provider.matches_manifest(_current523_source_definition_provider.root,CURRENT523_DEFINITION_PREFERENCES.PIN):return {}
	var result: Dictionary=_current523_source_definition_provider.cache_metrics()
	result["directory"]=_current523_source_definition_provider.root
	return result

func current523_aden_source_portals() -> Array:
	return _aden_play_controller().call("portal_evidence")

func current523_aden_source_portal_context(id: int) -> Dictionary:
	return _aden_play_controller().call("portal_context",id)

func current523_source_portal_navigation_ticket(id: int) -> Dictionary:
	return _aden_play_controller().call("portal_navigation_ticket",id)

func walk_to_current523_source_portal(id: int, ticket: Dictionary) -> bool:
	var result: bool=_aden_play_controller().call("walk_to_source_portal",id,ticket)
	current523_aden_play_problem=str(_aden_play_controller().get("problem"))
	current523_aden_play_changed.emit(current523_aden_play_active,"원문 출발점까지 걷습니다. 도착해도 자동 포탈은 활성화하지 않습니다." if result else current523_aden_play_problem)
	return result

func use_current523_aden_source_portal(id: int) -> bool:
	var result: bool = _aden_play_controller().call("use_source_portal",id)
	current523_aden_play_problem = str(_aden_play_controller().get("problem"))
	current523_aden_play_changed.emit(current523_aden_play_active,"원문 포탈로 이동했습니다." if result else current523_aden_play_problem)
	return result

func return_current523_source_to_aden(save_changes: Dictionary={}, departure_waive: Array=[]) -> Dictionary:
	return call("_return_current523_source_to_aden_impl",save_changes,departure_waive,false)

func return_current523_source_to_aden_loading(save_changes: Dictionary={}, departure_waive: Array=[]) -> Dictionary:
	return await _return_current523_source_to_aden_impl(save_changes,departure_waive,true)

func _return_current523_source_to_aden_impl(save_changes: Dictionary, departure_waive: Array, loading: bool) -> Dictionary:
	var controller: RefCounted=_aden_play_controller()
	var result: Dictionary
	if loading: result=await controller.call("return_to_aden_loading",save_changes,departure_waive)
	else: result=controller.call("return_to_aden",save_changes,departure_waive)
	current523_aden_play_active=bool(controller.get("active"))
	current523_aden_play_problem=str(result.get("reason","")) if not result.get("ok",false) else ""
	current523_aden_play_changed.emit(current523_aden_play_active,str(result.get("reason","아덴 귀환 보류")))
	return result

func _restore_current523_aden_play() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or current523_aden_play_active or current523_aden_review_active or CURRENT523_ADEN_REVIEW.requested(): return
	var options: Dictionary = CURRENT523_ADEN_PLAY_OPTIONS.read()
	if not CHARACTER_ACCOUNT.session.is_empty():
		# Device pack paths/preferences remain device-wide; spatial state is
		# restored from the selected character, not the previous player.
		var cursor: Dictionary=character_source_cursor if not character_source_cursor.is_empty() else {"native_land_id":4,"source_position":[]}
		options.merge(cursor,true)
	# A deleted tutorial Land (사용자 결정 2026-11-16) is never resumed.
	if TUTORIAL523.land(options.get("native_land_id",-1)): options.merge(TUTORIAL523.START_VILLAGE.cursor(),true)
	# Over the 523 host Aden, play mode is how the world is played: it always
	# resumes (the old picture-pack world no longer exists to fall back to).
	var host: bool = CURRENT523_HOST.is_host(field_map)
	if not options.enabled and not host: return
	# Other maps keep their normal presentation; this never redirects travel.
	if active_map_id != "aden_world": return
	var controller: RefCounted = _aden_play_controller()
	var saved_spot: bool = options.get("source_position",[]) is Array and not (options.get("source_position",[]) as Array).is_empty()
	controller.call("resume_saved_spot", int(options.get("native_land_id",-1)) if saved_spot else -1)
	var opened: bool = open_current523_aden_play(options.raw_root, options.tile_root, options)
	controller.call("resume_saved_spot", -1)
	if not opened and host and saved_spot and str(controller.get("problem")).contains("조건 보류"):
		# The saved spot cannot reopen under its Land's rules: rather than a
		# world with no 523 play mode (and no monsters), start at the start
		# village (Giran town, 사용자 결정 2026-11-17).
		var held: String = str(controller.get("problem"))
		options.merge({"native_land_id":4,"source_position":CURRENT523_ADEN_PLAY.village_source_position()},true)
		opened = open_current523_aden_play(options.raw_root, options.tile_root, options)
		if opened: hud.append_log("저장 위치를 다시 열 수 없어 기란 마을에서 시작합니다 (" + held + ")")
	if not opened and field_population.get("field")==null and not host:
		field_population.configure(self,field_map)

func _current523_source_restore_requested() -> bool:
	if active_map_id!="aden_world" or CURRENT523_ADEN_REVIEW.requested(): return false
	var options: Dictionary = CURRENT523_ADEN_PLAY_OPTIONS.read()
	if CURRENT523_HOST.requested(): return true
	return bool(options.enabled) and options.navigation_profile in [CURRENT523_ADEN_PLAY_OPTIONS.SOURCE,CURRENT523_ADEN_PLAY_OPTIONS.GENERIC]

func _exit_tree() -> void:
	if _current523_aden_play_controller != null:
		current523_prior_rebuild_suppressed = true
		_current523_aden_play_controller.call("close", false)
		current523_prior_rebuild_suppressed = false
	current523_aden_play_active = false
	EQUIPMENT523_INVOKE_DEBUFF.clear(self)
	equipment523.shutdown(self)

func _boot_current523_aden_review() -> bool:
	if not CURRENT523_ADEN_REVIEW.requested(): return false
	# Enter before old map/data bootstrap. The explicitly requested inspection
	# camera is separate from player navigation and the user's saved game.
	_mount_current523_aden_review(true)
	if not open_current523_aden_sources(CURRENT523_ADEN_REVIEW.argument("--aden523-pack=")):
		current523_aden_review.call("show_problem", current523_aden_problem)
		return true
	current523_aden_review.call("configure", self, CURRENT523_ADEN_REVIEW.argument("--aden523-tiles="), CURRENT523_ADEN_REVIEW.argument("--aden523-member="))
	return true

func _mount_current523_aden_review(from_boot: bool) -> void:
	_current523_aden_review_from_boot = from_boot
	_current523_aden_resume = {"process_mode":process_mode, "children":[], "source_registry":_current523_aden_sources}
	current523_aden_review_active = true
	process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in get_children():
		var record: Dictionary = {"node":child, "process_mode":child.process_mode}
		if child is CanvasItem or child is CanvasLayer: record.visible = child.visible
		_current523_aden_resume.children.append(record)
		child.process_mode = Node.PROCESS_MODE_DISABLED
		if child is CanvasItem: child.hide()
		elif child is CanvasLayer: child.hide()
	var layer := CanvasLayer.new()
	layer.name = "Current523AdenReview"
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	current523_aden_review = CURRENT523_ADEN_REVIEW.new()
	layer.add_child(current523_aden_review)
	current523_aden_review.get("close_button").text = "검토 종료" if from_boot else "게임으로 복귀"
	current523_aden_review.connect("close_requested", close_current523_aden_review)

func open_current523_aden_review_ui(raw_root: String, tile_root: String) -> bool:
	if current523_aden_play_active:
		current523_aden_problem = "실험 플레이를 종료한 뒤 원문 검토를 열어 주세요."
		return false
	if current523_aden_review_active:
		current523_aden_problem = "아덴 원문 검토가 이미 열려 있습니다"
		return false
	var candidate = CURRENT523_ADEN_PACK.new()
	if not candidate.load_pack(raw_root):
		current523_aden_problem = candidate.problem
		return false
	_mount_current523_aden_review(false)
	_current523_aden_sources = candidate
	if not bool(current523_aden_review.call("configure", self, tile_root, "Map/Aden/800a8000.s32")):
		var failed_problem: String = str(current523_aden_review.get("problem"))
		close_current523_aden_review()
		current523_aden_problem = failed_problem
		return false
	current523_aden_problem = ""
	return true

func close_current523_aden_review() -> void:
	if not current523_aden_review_active: return
	if _current523_aden_review_from_boot:
		get_tree().quit()
		return
	if is_instance_valid(current523_aden_review):
		var layer: CanvasLayer = current523_aden_review.get_parent() as CanvasLayer
		layer.hide()
		layer.process_mode = Node.PROCESS_MODE_DISABLED
		layer.queue_free()
	current523_aden_review = null
	current523_aden_review_active = false
	_current523_aden_sources = _current523_aden_resume.get("source_registry")
	process_mode = int(_current523_aden_resume.get("process_mode", Node.PROCESS_MODE_INHERIT))
	for record: Dictionary in _current523_aden_resume.get("children", []):
		var child: Node = record.node
		if not is_instance_valid(child): continue
		child.process_mode = int(record.process_mode)
		if record.has("visible"): child.visible = bool(record.visible)
	_current523_aden_resume.clear()
	current523_aden_problem = ""
	current523_aden_review_closed.emit()

func open_current523_aden_sources(pack_root: String) -> bool:
	var candidate = CURRENT523_ADEN_PACK.new()
	if not candidate.load_pack(pack_root):
		current523_aden_problem = candidate.problem
		return false
	_current523_aden_sources = candidate
	current523_aden_problem = ""
	return true

func current523_aden_source_members() -> Array:
	return [] if _current523_aden_sources == null else _current523_aden_sources.call("source_members")

func read_current523_aden_source(member: String) -> Dictionary:
	if _current523_aden_sources == null:
		current523_aden_problem = "No current523 Aden source pack registered"
		return {}
	var result: Dictionary = _current523_aden_sources.call("read_member", member)
	current523_aden_problem = str(_current523_aden_sources.get("problem"))
	return result

func close_current523_aden_sources() -> void:
	_current523_aden_sources = null
	current523_aden_problem = ""


func _request_protection523_use(item_name: String) -> void:
	var quote: Dictionary = protection523.quote_use(item_name)
	if not bool(quote.get("ok",false)):
		hud.show_message(str(quote.get("error","가호 사용 조건을 확인하세요")))
		return
	var definition: Dictionary = quote.definition
	hud.confirm_action(str(definition.name),"명예 코인 10개 소모 · %d분 · 해당 가호 재사용 1시간\n가호 본체는 보존하며 다른 Group604 가호 버프를 교체합니다." % (int(definition.duration)/60),"가호 사용",func(_count: int = 1) -> void:
		var result: Dictionary = protection523.use(item_name)
		if not bool(result.get("ok",false)): hud.show_message(str(result.get("error","가호 사용 실패"))))

func equipment523_can_reveal(flag: String) -> bool:
	return equipment523.capability(self,flag)

func equipment523_emit_spell(spell: Dictionary, target: Node) -> Array:
	return equipment523.emit_spell_visuals(self,spell,target)

func equipment523_actor_invisible(actor: Node) -> bool:
	if not is_instance_valid(actor) or (actor is TwilightMonster and (actor as TwilightMonster).dead): return false
	# Read active source buffs; this never creates an NPC concealment state or
	# infers the unresolved NpcAttribute activation enum from a numeric value.
	return bool(actor.get_meta("source_invisible",false)) or patch523_npc_spells.extensions.actor_invisible(actor)

func equipment523_can_detect(actor: TwilightMonster) -> bool:
	if not is_instance_valid(actor) or actor.dead: return false
	if equipment523_actor_invisible(actor) and not equipment523_can_reveal("invisibility"): return false
	if bool(actor.get_meta("source_camouflaged",false)) and not equipment523_can_reveal("camouflage"): return false
	return true

func equipment523_target_name(actor: TwilightMonster) -> String:
	if not is_instance_valid(actor): return ""
	if actor.has_meta("source_doppel_name"):
		if equipment523_can_reveal("doppel"): return str(actor.get_meta("source_original_name",actor.monster_name))
		return str(actor.get_meta("source_doppel_name"))
	return actor.monster_name

func _equipment523_locked_target() -> TwilightMonster:
	return equipment523.locked_target(self) as TwilightMonster

func _equipment523_invoke_owner(origin: Dictionary, spell_id: int) -> bool:
	# Recheck the exact equipped physical item and selected source effect. A
	# rolled debuff outlives unequipping, but unequipping prevents another cast.
	if equipment523.store.pack.is_empty() or equipment523.save_blocked: return false
	if not origin.get("instance_id") is String or str(origin.instance_id).is_empty() or spell_id <= 0: return false
	for key: String in ["source_id","slot","bonus_id"]:
		if not origin.get(key) is int or int(origin[key]) <= 0: return false
	for target: Dictionary in equipment523._equipped(self):
		if str(target.get("instance_id","")) != str(origin.get("instance_id","")) or int(target.get("source_id",0)) != int(origin.get("source_id",0)): continue
		for effect: Dictionary in EQUIPMENT523_SET_INVOKE.effects(equipment523.store.pack,target,equipment523.policy):
			if int(effect.get("slot",0)) == int(origin.get("slot",0)) and int(effect.get("bonus_id",0)) == int(origin.get("bonus_id",0)) and int(effect.get("option",{}).get("Param1",0)) == spell_id: return true
	return false

func _open_owned_native_smelt(uid:String,record:Dictionary)->bool:
	var smelt:Script=EQUIPMENT523_SERVICE.NATIVE_SMELT
	if not smelt.known(int(record.get("source_item_class_id",0))) or smelt.kind(record).is_empty():return false
	var offer:Dictionary=equipment523.native_smelt_offer(self,uid)
	if not offer.get("ok",false):
		hud.show_message(str(offer.get("error","선택한 제련 재료를 확인하세요.")))
		return true
	if not hud.open_native_smelt523(offer):
		hud.show_message("원본 제련 창을 불러올 수 없습니다 · 재료 보존")
	return true

func native_smelt523_quote(action:Dictionary)->Dictionary:
	return equipment523.quote(self,action)

func native_smelt523_commit(action:Dictionary)->Dictionary:
	var result:Dictionary=equipment523.commit(self,action)
	if result.get("ok",false):
		# The original window still shows this selected physical receipt. Do
		# not immediately fold it with a different same-name provenance stack.
		_publish_player_hud(false)
		hud.append_log(str(result.get("detail","제련 완료")))
	return result

func _equipment523_open() -> void:
	hud.call("open_equipment523",equipment523.snapshot(self))

func _equipment523_preview(action: Dictionary) -> void:
	hud.call("equipment523_quote_result",equipment523.quote(self,action))

func _equipment523_commit(action: Dictionary) -> void:
	var result: Dictionary = equipment523.commit(self,action)
	if result.get("ok",false):
		_update_hud()
		hud.append_log(str(result.get("detail","가공 완료")))
	hud.call("equipment523_refresh",equipment523.snapshot(self))
	hud.call("equipment523_action_result",result)

func _equipment523_install(path: String, sha: String) -> void:
	var result: Dictionary = equipment523.install(self,path,sha)
	if result.get("ok",false): _update_hud()
	hud.call("equipment523_refresh",equipment523.snapshot(self))
	hud.call("equipment523_action_result",result)


## Save before discarding the entire World, so no timer, combat target, input,
## deferred transaction or owner cache can leak into another character.
func return_to_character_lobby() -> bool:
	if returning_to_character_lobby: return false
	if current523_aden_review_active or not CHARACTER_PROFILE.allows_roster():
		hud.show_message("검수·개발 저장에서는 일반 캐릭터 목록으로 이동할 수 없습니다.")
		return false
	if _save_game(true)!=OK:
		hud.show_message("저장에 실패해 현재 캐릭터를 유지합니다. 저장 문제를 해결한 뒤 다시 시도하세요.")
		return false
	returning_to_character_lobby=true
	general_save_pending=false
	deferred_save.cancel()
	_clear_skill_charge()
	_clear_combat_actions()
	player.set_physics_process(false)
	set_process(false)
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot/Characters.tscn")
	return true

func dormant_character_items() -> Dictionary:
	return character_dormant_physical

func character_cursor_snapshot() -> Dictionary:
	return character_source_cursor.duplicate(true)

func set_character_cursor_snapshot(value: Dictionary) -> void:
	character_source_cursor=value.duplicate(true)
