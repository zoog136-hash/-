extends CharacterBody2D
class_name TwilightMonster

const BASE508 = preload("res://scripts/lineagem_base508.gd")
const EQUIPMENT523_INVOKE_DEBUFF = preload("res://scripts/equipment523/invoke_debuff.gd")
var source_m_original: Dictionary = {}
var _original_attribute_values: Dictionary = {}
var source_targeting: Dictionary = {}
var collection_combat_context: Dictionary={}
var source_m_npc_id: int = -1
const SOURCE_M_VIEW = preload("res://scripts/monsters/base508_monster_view.gd")
const CURRENT523_SOURCE_M_VIEW = preload("res://scripts/monsters/current523_source_bank_view.gd")
const SOURCE_M_BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
var source_m_view: SOURCE_M_VIEW = null
const SOURCE_BOSS_COMBAT = preload("res://scripts/monsters/base508_boss_combat.gd")
var source_boss_combat = SOURCE_BOSS_COMBAT.new()
var source_action_contract_required: bool = false
var source_host_stationary: bool = false
var _source_only_native_visuals: bool = false
var mp: int = 0
var max_mp: int = 0
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const ANIMATION_CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MONSTER_ART = preload("res://scripts/monsters/monster_art.gd")
const VISUAL = preload("res://scripts/monsters/monster_visual.gd")
const AI_POLICY = preload("res://scripts/monsters/monster_ai_policy.gd")
const BOSS_GEOMETRY = preload("res://scripts/monsters/boss_geometry.gd")
var source_option_debuffs: Dictionary={}
var source_option_sequence := 0
var ai: Dictionary = {}
var aggro_remaining: float = 0.0
var life_id: int = 0
var concealed523: bool = false
var reveal_lock523: float = 0.0

func set_concealed523(value: bool) -> bool:
	if value and reveal_lock523 > 0: return false
	concealed523 = value
	modulate.a = .15 if value else 1.0
	return true

func reveal523(seconds: float) -> void:
	set_concealed523(false)
	reveal_lock523 = maxf(reveal_lock523, seconds)

func tick_reveal523(delta: float) -> void:
	reveal_lock523 = maxf(0, reveal_lock523 - delta)
var species_visual: TwilightMonsterVisual
var special_sequence: int = -1
var special_attack: Dictionary = {} # authoritative warning geometry for this action
var symbol_hit_context: Dictionary = {} # Scoped to one emitted impact, never actor-global history.
var released_sequence: int = -1
var committed_attack_type: String = "melee"
var special_cooldown: float = 3.0
var blink_cooldown: float = 0.0
var returning_home: bool = false
var enraged: bool = false
var social_alert_cooldown: float = 0.0
var decision_elapsed: float = 0.0
var sight_clock: float = 0.0
var sight_cached: bool = false
var motion: TwilightActorMotion = MOTION.new()
var animation_base_scale: Vector2 = Vector2.ONE
var attack_interval: float = 1.25
var configured_attack_range: float = 0.0
var animation_state: String = "idle"
var visual_height: float = 72.0
var motion_connected: bool = false

const LOOT_DROP = preload("res://scripts/loot_drop.gd")

signal died(monster: TwilightMonster)
signal player_hit(attacker: TwilightMonster, damage: int, attack_type: String)
signal selected(monster: TwilightMonster)

@onready var sprite: Sprite2D = $Sprite2D
@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var name_label: Label = $NameLabel
@onready var hp_bar: ProgressBar = $HPBar

var monster_name: String = "몬스터"
var monster_type: String = ""
var undead: bool = false
var element_resistance: Dictionary = {}
var attack_element: String = "physical"
var damage_hit_count: int = 0
var monster_level: int = 1
var defense_value: int = 0
var _guardian_base_armor_class: int = -10
var armor_class: int:
	get:
		if is_instance_valid(world_controller) and world_controller.get("growth")!=null:return _guardian_base_armor_class+world_controller.growth.guardian_combat.npc_ac_delta(self)
		return _guardian_base_armor_class
	set(value):_guardian_base_armor_class=value
var hp: int = 100
var _guardian_base_max_hp: int = 100
var source_523_base_max_hp: int:
	get: return _guardian_base_max_hp
	set(value): _guardian_base_max_hp = value
var max_hp: int:
	get:
		var base: int = _guardian_base_max_hp
		if is_instance_valid(world_controller) and world_controller.get("growth") != null:
			base = maxi(1,base+world_controller.growth.guardian_combat.npc_max_hp_delta(self))
		var source523 = _patch523_service()
		return source523.extensions.remaining.maximum_hp(self,base) if source523 != null else base
	set(value): _guardian_base_max_hp = value
var attack_power: int = 8
var melee_accuracy: int = 12
var ranged_accuracy: int = 12
var magic_accuracy: int = 12
var _guardian_base_magic_resistance: int = 10
var magic_resistance: int:
	get:
		if is_instance_valid(world_controller) and world_controller.get("growth")!=null:return _guardian_base_magic_resistance+world_controller.growth.guardian_combat.npc_mr_delta(self)
		return _guardian_base_magic_resistance
	set(value):_guardian_base_magic_resistance=value
var melee_critical_rate: int = 5
var ranged_critical_rate: int = 5
var magic_critical_rate: int = 5
var critical_resistance: int = 0
var stun_accuracy: int = 0
var dark_resistance: int=0
var ice_resistance: int=0
var dark_accuracy: int=0
var ice_accuracy: int=0
var dark_duration: float=0.0
var ice_duration: float=0.0
var stun_resistance: int = 0
var stun_duration: float = 0.0
var stun_remaining: float = 0.0
var silence_accuracy: int = 0
var silence_resistance: int = 0
var silence_duration: float = 0.0
var silence_remaining: float = 0.0
var hold_accuracy: int = 0
var hold_resistance: int = 0
var hold_duration: float = 0.0
var hold_remaining: float = 0.0
var fear_accuracy: int = 0
var fear_resistance: int = 0
var fear_duration: float = 0.0
var fear_remaining: float = 0.0
var fear_source_position: Vector2 = Vector2.ZERO
var fear_move_multiplier: float = 0.82
var poison_accuracy: int = 0
var poison_resistance: int = 0
var poison_duration: float = 0.0
var poison_tick_damage: int = 0
var poison_tick_interval: float = 1.0
var poison_remaining: float = 0.0
var poison_tick_clock: float = 0.0
var bleed_accuracy: int = 0
var bleed_resistance: int = 0
var bleed_duration: float = 0.0
var bleed_tick_damage: int = 0
var bleed_tick_interval: float = 0.75
var bleed_remaining: float = 0.0
var bleed_tick_clock: float = 0.0
var patch523_weapon_bleed: Dictionary = {}
var attack_type: String = "melee"
var move_speed: float = 90.0
var base_move_speed: float = 90.0
var slow_remaining: float = 0.0
var slow_multiplier: float = 1.0
var exp_reward: int = 25
var gold_reward: int = 40
var grade: String = "일반"
var is_boss: bool = false
var status_immunities: Array = []
var drop_items: Array[String] = []
var loot_source_identity: Dictionary = {}
var target_player: TwilightPlayer = null
var world_controller: Node = null
var attack_cooldown: float = 0.0
var repath_cooldown: float = 0.0
var path_stuck_elapsed: float = 0.0
var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var dead: bool = false
# Sleeping-actor visual residency: while the field population keeps a
# ordinary monster asleep (far outside the screen), it holds only its first
# frame instead of every pose texture. Waking restores the same SpriteFrames
# before the actor can reach the screen, so presentation is unchanged.
var visual_parked: bool = false
const VISUAL_PARK_AFTER_MSEC := 4000
var _asleep_since_msec: int = -1
var _awake_since_setup: bool = false
var home_position: Vector2 = Vector2.ZERO
var spawn_region_id: String = ""
var roaming_radius: float = 180.0
var roam_clock: float = 0.0

func retire_for_pool() -> void:
	var source523 = _patch523_service()
	if source523 != null: source523.forget(self)
	source_targeting.clear()
	source_boss_combat.clear()
	source_action_contract_required = false
	source_host_stationary = false
	loot_source_identity.clear()
	# Death presentation is complete before this is called. Release all visual
	# owners while keeping the lightweight body for the next life/region.
	set_physics_process(false)
	_clear_source_m_view()
	_source_only_native_visuals = false
	if has_meta("current523_source_only_visual"): remove_meta("current523_source_only_visual")
	loot_source_identity = {}
	input_pickable = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	damage_hit_count = 0
	special_attack.clear()
	source_option_debuffs.clear()
	patch523_weapon_bleed.clear()
	if is_instance_valid(world_controller):
		var died_callback:=Callable(world_controller,"_on_monster_died")
		var hit_callback:=Callable(world_controller,"_on_player_hit")
		var selected_callback:=Callable(world_controller,"_select_monster")
		if died.is_connected(died_callback): died.disconnect(died_callback)
		if player_hit.is_connected(hit_callback): player_hit.disconnect(hit_callback)
		if selected.is_connected(selected_callback): selected.disconnect(selected_callback)
	target_player = null
	world_controller = null
	motion = MOTION.new()
	motion_connected = false
	sprite.texture = null
	sprite.material = null
	if is_instance_valid(species_visual):
		species_visual.effect_texture = null
		# These dictionaries may alias catalog records; replace the references.
		species_visual.visual = {}
		species_visual.special = {}
		species_visual.warning_active = false
		species_visual.original_source = false
		species_visual.hide()
	ai.clear()
	status_immunities.clear()
	element_resistance.clear()
	drop_items.clear()

func setup(record: Dictionary, player_ref: TwilightPlayer, world_ref: Node, texture: Texture2D) -> bool:
	var source523 = _patch523_service()
	if source523 != null: source523.forget(self)
	_original_attribute_values.clear()
	if has_meta("original_orim_numeric_input"): remove_meta("original_orim_numeric_input")
	if has_meta("original_orim_attack_range_input"): remove_meta("original_orim_attack_range_input")
	var original_numeric: Dictionary = {}
	# A numeric local-adapter input does not assert a native spawn/Sprite ID.
	if record.get("source")=="twilight_dungeon_visual_adapter" and record.get("original_attribute_input") is Dictionary:
		_original_attribute_values = preload("res://scripts/resources/current523_actor_attribute_input.gd").values(record.original_attribute_input)
		original_numeric = preload("res://scripts/resources/current523_actor_attribute_input.gd").numeric(record.original_attribute_input)
	source_targeting.clear()
	source_option_debuffs.clear()
	source_boss_combat.clear()
	_clear_source_m_view()
	_source_only_native_visuals = false
	if has_meta("current523_source_only_visual"): remove_meta("current523_source_only_visual")
	var incoming: Dictionary = preload("res://scripts/monsters/patch523_spawn_policy.gd").admit(record, str(world_ref.get("active_map_id")) if world_ref != null else "")
	if not incoming.ok: return _reject_patch523_spawn(str(incoming.reason))
	var source_record: Dictionary = SOURCE_M_BINDINGS.apply(record, str(world_ref.get("active_map_id")) if world_ref != null else "")
	var admission: Dictionary = preload("res://scripts/monsters/patch523_spawn_policy.gd").admit(source_record, str(world_ref.get("active_map_id")) if world_ref != null else "")
	if not admission.ok:
		return _reject_patch523_spawn(str(admission.reason))
	source_record = admission.record
	remove_meta("patch523_spawn_hold")
	if has_meta("current523_source_bank_selection"): remove_meta("current523_source_bank_selection")
	# Canonical definition/projection precedes the visual request. Keep this as
	# the single project_actor_record call when adopting the data-owner checkpoint.
	# world_controller is not assigned for this pooled life yet.
	var current_service: Variant = world_ref.get("patch523_npc_spells") if world_ref != null else null
	var current_catalog: Variant = current_service.get("catalog") if current_service != null else null
	var candidate_npc_id: int = int(source_record.get("source_m_npc_id",-1))
	if candidate_npc_id >= 0:
		source_record = BASE508.npc_record(candidate_npc_id,source_record)
		if current_catalog != null and current_catalog.has_method("project_actor_record"):
			var projected: Variant = current_catalog.project_actor_record(source_record)
			if projected is Dictionary: source_record = projected
	# A saved native NPC identity never authorizes an old final media input.
	_source_only_native_visuals = candidate_npc_id >= 0
	admission.erase("current523_npc_source_identity")
	if _source_only_native_visuals:
		source_record["current523_source_only"] = true
		# Retained inactive registry data is preservation only, never admission.
		if current_catalog != null and current_catalog.get("source_available") == true:
			var registry: Variant = current_catalog.get("admitted_source_identities")
			if registry is Dictionary:
				var identity: Variant = registry.get(str(candidate_npc_id),{})
				if identity is Dictionary: admission["current523_npc_source_identity"] = identity.duplicate(true)
		# A missing new visual does not reject or replace an already admitted actor.
		record = source_record
	elif int(record.get("source_m_npc_id",-1)) >= 0:
		record = source_record
	admission.record = source_record
	if not _source_only_native_visuals and source_record.has("source_m_asset_manifest_path"):
		var native_view := SOURCE_M_VIEW.new()
		if native_view.configure(source_record, str(source_record.source_m_asset_manifest_path)):
			record = source_record
			source_m_view = native_view
			add_child(source_m_view)
		else:
			native_view.free() # Retain the prior actor/stats if any original pixel fails verification.
	# The current bank supplies visuals only for the same already-admitted source
	# encounter. It cannot create a binding, placement, stat update or spawn context.
	if not is_instance_valid(source_m_view) and (admission.applied or _source_only_native_visuals):
		var current_view := CURRENT523_SOURCE_M_VIEW.new()
		if current_view.configure_admitted(source_record,admission):
			record = source_record
			source_m_view = current_view
			add_child(source_m_view)
			set_meta("current523_source_bank_selection",current_view.selection_status.duplicate(true))
		else:
			set_meta("current523_source_bank_selection",current_view.selection_status.duplicate(true))
			current_view.free()
			if not _source_only_native_visuals: return _reject_patch523_spawn("patch523_original_pixels_not_ready")
	if _source_only_native_visuals:
		var selected_visual: bool = is_instance_valid(source_m_view)
		set_meta("current523_source_only_visual",{"required":true,"state":"current_source_view_selected" if selected_visual else "source_only_pending","legacy_media_fallback_allowed":false,"selection":get_meta("current523_source_bank_selection",{}).duplicate(true)})
	set_meta("patch523_spawn_admission", record.get("source_m_patch523_admission", {}).duplicate(true))
	# Only an exact namespaced source ID opts into native stats. No name/Sprite/legacy-ID guessing.
	source_m_npc_id = int(record.get("source_m_npc_id", -1))
	# Main projects once before visual selection; reuse that service for the
	# original drop identity input without applying the projection a second time.
	var definition_service: Variant = current_service
	source_m_original = record.get("source_m_original", {}).duplicate(true)
	if source_m_npc_id >= 0:
		source_targeting = record.get("source_m_targeting", {}).duplicate(true)
		if source_targeting.is_empty():
			var category: Dictionary = record.get("source_m_context", {}).get("category", {})
			source_targeting = {"snapshot":"base508", "category_id":category.get("ID", -1)}
			for flag: String in ["IsAutoSelectable", "IsSelectable"]:
				if category.get(flag) is bool: source_targeting[flag] = category[flag]
	var context: Variant=record.get("collection_combat_context",{})
	collection_combat_context=context.duplicate(true) if context is Dictionary else {}
	source_action_contract_required = not record.get("source_m_host_action_contract", {}).is_empty()
	source_host_stationary = source_action_contract_required and bool(record.get("source_m_host_stationary",false)) and bool(record.get("source_m_host_action_contract",{}).get("host_stationary",false))
	# Reset with every pooled life. Keep only the small reviewed identity tuple.
	loot_source_identity = LOOT_DROP.SOURCE3_REVIEWED.identity(record)
	var patch523_identity: Dictionary = LOOT_DROP.PATCH523_DROPS.identity(record,definition_service.catalog if definition_service != null else null)
	if not patch523_identity.is_empty(): loot_source_identity = patch523_identity
	# Full reset is required when a corpse is reused by the bounded field pool.
	life_id += 1
	reveal_lock523 = 0
	set_concealed523(bool(record.get("estimated_concealed", false)))
	motion = MOTION.new()
	motion_connected = false
	dead = false
	damage_hit_count = 0
	attack_cooldown = 0.
	repath_cooldown = float(get_instance_id()%11)*.025
	path_stuck_elapsed = 0.0
	path = PackedVector2Array()
	path_index = 0
	velocity = Vector2.ZERO
	stun_remaining = 0.; silence_remaining = 0.; hold_remaining = 0.; fear_remaining = 0.
	for kind: String in ["dark","ice"]:
		set(kind+"_resistance",clampi(int(record.get(kind+"_resistance",0)),0,100))
		set(kind+"_accuracy",clampi(int(record.get(kind+"_accuracy",0)),0,100))
		set(kind+"_duration",clampf(float(record.get(kind+"_duration",0)),0,30))
	poison_remaining = 0.; poison_tick_clock = 0.; bleed_remaining = 0.; bleed_tick_clock = 0.
	patch523_weapon_bleed.clear()
	aggro_remaining = 0.; returning_home = false
	enraged = false; social_alert_cooldown = 0.0
	decision_elapsed = 0.; sight_clock = 0.; sight_cached = false
	special_attack.clear(); released_sequence = -1; committed_attack_type = "melee"
	special_sequence = -1; special_cooldown = 3.; blink_cooldown = 0.; roam_clock = 0.
	ai = (record.get("ai",{}) as Dictionary).duplicate(true)
	status_immunities = (record.get("status_immunities", []) as Array).duplicate()
	show()
	input_pickable = true
	collision_layer = 2
	collision_mask = 3
	set_physics_process(true)
	home_position = global_position
	# Overhead name/HP visibility is decided by distance at the end of setup.
	if has_node("GroundShadow") and not _source_only_native_visuals: $GroundShadow.show()
	monster_name = str(record.get("name", "몬스터"))
	monster_type = str(record.get("type", record.get("race", "")))
	undead = bool(record.get("undead", monster_type == "언데드"))
	var raw_resistance: Variant = record.get("element_resistance", {})
	element_resistance = (raw_resistance as Dictionary).duplicate(true) if raw_resistance is Dictionary else {}
	if not original_numeric.is_empty():
		element_resistance.merge(original_numeric.element_resistance,true)
		set_meta("original_orim_numeric_input",original_numeric)
	attack_element = str(record.get("attack_element", "physical"))
	monster_level = maxi(1, int(record.get("lv", record.get("level", 1))))
	defense_value = maxi(0, int(record.get("def", record.get("defense", record.get("방어력", 0)))))
	var default_ac: int = -(10 + monster_level + defense_value * 2)
	armor_class = int(record.get("ac", record.get("AC", default_ac)))
	if armor_class > 0 and source_m_original.is_empty():
		armor_class = -armor_class
	max_hp = int(record.hp) if not source_m_original.is_empty() else maxi(30, int(record.get("hp", record.get("HP", 100))))
	max_mp = int(record.get("mp", 0)) if not source_m_original.is_empty() else 0
	mp = max_mp
	hp = max_hp
	attack_power = maxi(3, int(record.get("atk", record.get("attack", record.get("공격력", 8)))))
	var default_accuracy: int = monster_level + 10 + int(round(float(attack_power) * 0.25))
	melee_accuracy = maxi(1, int(record.get("melee_accuracy", record.get("accuracy", record.get("hit", record.get("명중", default_accuracy))))))
	ranged_accuracy = maxi(1, int(record.get("ranged_accuracy", record.get("원거리 명중", melee_accuracy))))
	var default_magic_accuracy: int = monster_level + 10 + int(round(float(attack_power) * 0.20))
	magic_accuracy = maxi(1, int(record.get("magic_accuracy", record.get("마법 명중", default_magic_accuracy))))
	var default_mr: int = 10 + monster_level + defense_value
	magic_resistance = maxi(0, int(record.get("mr", record.get("MR", record.get("마법 방어력", default_mr)))))
	var generic_critical: int = maxi(0, int(record.get("crit", record.get("critical_rate", record.get("치명타", 5)))))
	melee_critical_rate = clampi(int(record.get("melee_crit", record.get("근거리 치명타", generic_critical))), 0, 50)
	ranged_critical_rate = clampi(int(record.get("ranged_crit", record.get("원거리 치명타", generic_critical))), 0, 50)
	magic_critical_rate = clampi(int(record.get("magic_crit", record.get("마법 치명타", generic_critical))), 0, 50)
	critical_resistance = clampi(int(record.get("critical_resistance", record.get("crit_resist", record.get("치명타 저항", 0)))), 0, 50)
	var default_stun_accuracy: int = 5 + int(floor(float(monster_level) / 5.0))
	var default_stun_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	stun_accuracy = clampi(int(record.get("stun_accuracy", record.get("스턴 적중", default_stun_accuracy))), 0, 100)
	stun_resistance = clampi(int(record.get("stun_resistance", record.get("stun_resist", record.get("스턴 내성", default_stun_resistance)))), 0, 100)
	stun_duration = maxf(0.0, float(record.get("stun_duration", record.get("스턴 지속시간", 0.0))))
	var default_silence_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	silence_accuracy = clampi(int(record.get("silence_accuracy", record.get("침묵 적중", 0))), 0, 100)
	silence_resistance = clampi(int(record.get("silence_resistance", record.get("silence_resist", record.get("침묵 내성", default_silence_resistance)))), 0, 100)
	silence_duration = maxf(0.0, float(record.get("silence_duration", record.get("침묵 지속시간", 0.0))))
	var default_hold_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	hold_accuracy = clampi(int(record.get("hold_accuracy", record.get("홀드 적중", 0))), 0, 100)
	hold_resistance = clampi(int(record.get("hold_resistance", record.get("hold_resist", record.get("홀드 내성", default_hold_resistance)))), 0, 100)
	hold_duration = maxf(0.0, float(record.get("hold_duration", record.get("홀드 지속시간", 0.0))))
	var default_fear_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	fear_accuracy = clampi(int(record.get("fear_accuracy", record.get("공포 적중", 0))), 0, 100)
	fear_resistance = clampi(int(record.get("fear_resistance", record.get("fear_resist", record.get("공포 내성", default_fear_resistance)))), 0, 100)
	fear_duration = maxf(0.0, float(record.get("fear_duration", record.get("공포 지속시간", 0.0))))
	var default_poison_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	poison_accuracy = clampi(int(record.get("poison_accuracy", record.get("독 적중", 0))), 0, 100)
	poison_resistance = clampi(int(record.get("poison_resistance", record.get("poison_resist", record.get("독 내성", default_poison_resistance)))), 0, 100)
	poison_duration = maxf(0.0, float(record.get("poison_duration", record.get("독 지속시간", 0.0))))
	poison_tick_damage = maxi(0, int(record.get("poison_tick_damage", record.get("독 피해", 0))))
	poison_tick_interval = maxf(0.1, float(record.get("poison_tick_interval", record.get("독 주기", 1.0))))
	var default_bleed_resistance: int = 5 + int(floor(float(monster_level) / 10.0))
	bleed_accuracy = clampi(int(record.get("bleed_accuracy", record.get("출혈 적중", 0))), 0, 100)
	bleed_resistance = clampi(int(record.get("bleed_resistance", record.get("bleed_resist", record.get("출혈 내성", default_bleed_resistance)))), 0, 100)
	bleed_duration = maxf(0.0, float(record.get("bleed_duration", record.get("출혈 지속시간", 0.0))))
	bleed_tick_damage = maxi(0, int(record.get("bleed_tick_damage", record.get("출혈 피해", 0))))
	bleed_tick_interval = maxf(0.1, float(record.get("bleed_tick_interval", record.get("출혈 주기", 0.75))))
	if not original_numeric.is_empty():
		var original_status: Dictionary = original_numeric.get("status_resistance",{})
		stun_resistance=int(original_status.get("stun_resistance",stun_resistance))
		hold_resistance=int(original_status.get("hold_resistance",hold_resistance))
		fear_resistance=int(original_status.get("fear_resistance",fear_resistance))
	attack_type = str(record.get("attack_type", record.get("attackType", record.get("공격타입", "melee")))).to_lower()
	if attack_type != "ranged" and attack_type != "magic":
		attack_type = "melee"
	exp_reward = int(record.xp) if not source_m_original.is_empty() else maxi(10, int(record.get("xp", record.get("exp", record.get("경험치", int(float(source_523_base_max_hp) / 4.0))))))
	gold_reward = int(record.get("gold", 0)) if not source_m_original.is_empty() else maxi(10, int(record.get("gold", record.get("아데나", int(float(source_523_base_max_hp) / 3.0)))))
	grade = str(record.get("grade", record.get("등급", "일반")))
	is_boss = LOOT_DROP.is_boss_record(record)
	drop_items.clear()
	var drop_value: Variant = record.get("drop", [])
	if drop_value is Array:
		for item_value: Variant in drop_value as Array:
			var item_name: String = str(item_value)
			if not item_name.is_empty():
				drop_items.append(item_name)
	move_speed = float(record.get("speed", 70.0 + float(mini(70, int(float(source_523_base_max_hp) / 10.0)))))
	base_move_speed = move_speed
	slow_remaining = 0.0
	slow_multiplier = 1.0
	target_player = player_ref
	world_controller = world_ref
	hp = max_hp # Initial life starts at its effective cap; boundary entry never heals.
	set_meta("patch523_hp_was_enabled",max_hp != source_523_base_max_hp)
	source_boss_combat.configure(self,world_controller,record)
	if world_controller is TwilightWorld:
		motion.reduced_motion = bool(world_controller.presentation_settings.get("reduced_motion", false))
	if _source_only_native_visuals:
		sprite.texture = null
		sprite.hide()
	else:
		sprite.show()
		sprite.texture = texture
	sprite.material = null
	if texture != null and not _source_only_native_visuals:
		var size: Vector2 = texture.get_size()
		var largest: float = maxf(size.x, size.y)
		if largest > 1.0:
			var desired: float = 72.0 if largest > 100.0 else 56.0
			var scale_value: float = desired / largest
			sprite.scale = Vector2(scale_value, scale_value)
	name_label.text = monster_name if not source_m_original.is_empty() and str(record.get("source_m_level_origin", "")).begins_with("local_") else "Lv.%d %s" % [monster_level, monster_name]
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	# Start with the same distance rule the AI applies every decision tick.
	# Showing every new actor's label until its first AI tick made the first
	# frame on a crowded field (Aden: ~360 actors) stall for tens of seconds
	# while hundreds of offscreen labels were laid out and drawn at once.
	_refresh_overhead_ui()
	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 42.0
	_setup_animation(record)
	if not _source_only_native_visuals and (record.has("visual") or is_boss):
		if record.has("visual") and motion.frame_source == null:
			sprite.material = MONSTER_ART.material_for(record.visual,sprite.texture)
		if not is_instance_valid(species_visual):
			species_visual = VISUAL.new()
			species_visual.actor = self
			add_child(species_visual)
		species_visual.visual = record.get("visual", {})
		species_visual.original_source = not preload("res://scripts/animation/visual_manifest.gd").monster_binding(record).is_empty()
		species_visual.special = ai.get("special",{})
		species_visual.warning_active = false
		species_visual.reset_presentation()
		species_visual.show()
		species_visual.update_pose()
	elif is_instance_valid(species_visual): species_visual.hide()
	if is_instance_valid(source_m_view):
		sprite.hide()
		$GroundShadow.hide()
		if is_instance_valid(species_visual): species_visual.hide()
		motion.profile.death_duration = maxf(motion.profile.death_duration, source_m_view.duration("death"))
	_hide_source_only_native_media()
	return true

func _reject_patch523_spawn(reason: String) -> bool:
	_original_attribute_values.clear()
	source_targeting.clear()
	retire_for_pool()
	dead = true
	hp = 0
	source_m_npc_id = -1
	source_m_original = {}
	loot_source_identity = {}
	set_meta("patch523_spawn_hold", reason)
	set_meta("patch523_spawn_admission", {})
	hide()
	queue_free()
	return false

func _clear_source_m_view() -> void:
	if is_instance_valid(source_m_view):
		source_m_view.hide()
		source_m_view.queue_free()
	source_m_view = null

func permits_auto_selection() -> bool:
	return source_targeting.is_empty() or (source_targeting.get("IsAutoSelectable") is bool and source_targeting.IsAutoSelectable)

func _advance_source_m_view(delta: float) -> void:
	if is_instance_valid(source_m_view):
		source_m_view.advance(delta, animation_state, motion.facing8, motion.sequence, motion.active, dead)
	_hide_source_only_native_media()

func _hide_source_only_native_media() -> void:
	if not _source_only_native_visuals: return
	# These are the historical Sprite/species owners, not the current source view.
	motion.frame_source = null
	sprite.texture = null
	sprite.material = null
	sprite.hide()
	if is_instance_valid(species_visual): species_visual.hide()
	if has_node("GroundShadow"): $GroundShadow.hide()

func custom_frozen() -> bool:
	return is_instance_valid(world_controller) and world_controller.get("halphas_star")!=null and world_controller.halphas_star.combat.frozen(self)

func _physics_process(delta: float) -> void:
	var source523 = _patch523_service()
	if source523 != null and not dead: source523.extensions.remaining.sync_actor(self)
	if not dead:
		var effective_hp: int=max_hp
		if hp_bar.max_value!=effective_hp:
			hp=mini(hp,effective_hp)
			hp_bar.max_value=effective_hp;hp_bar.value=hp
	tick_reveal523(delta)
	advance_source_option_debuffs(delta)
	preload("res://scripts/loot/patch523_weapon_bleed.gd").tick(self,delta)
	source_boss_combat.tick(delta)
	# Only bosses own warning/release lifetimes; normal actors have no such clock.
	if is_boss and is_instance_valid(species_visual): species_visual.tick(delta)
	if dead:
		if visual_parked: restore_visual()
		velocity = Vector2.ZERO
		motion.advance(delta, Vector2.ZERO)
		motion.apply(sprite, animation_base_scale)
		animation_state = motion.state
		_advance_source_m_view(delta)
		if is_instance_valid(species_visual):
			species_visual.warning_active = false
			if not _source_only_native_visuals: species_visual.update_pose()
		if motion.death_clock >= maxf(1.0, motion.profile.death_duration + .45):
			if world_controller.has_method("recycle_monster") and world_controller.recycle_monster(self): return
			queue_free()
		return
	var previous: Vector2 = global_position
	decision_elapsed += delta
	var on_screen: bool = get_viewport_rect().grow(160).has_point(get_global_transform_with_canvas().origin)
	# Off-screen actors that are only roaming re-decide at 5 Hz; anything
	# engaged, returning, casting, status-affected or a boss keeps 30 Hz.
	var decision_interval: float = .032
	if not on_screen and not is_boss and not motion.active and aggro_remaining <= 0.0 and not returning_home \
			and not is_stunned() and not is_held() and not is_feared() and poison_remaining <= 0.0 and bleed_remaining <= 0.0:
		decision_interval = .2
	if ai.is_empty() or decision_elapsed>=decision_interval:
		_tick_ai(decision_elapsed)
		decision_elapsed = 0.
	elif not motion.active and not is_stunned() and not is_held() and not custom_frozen():
		# Decisions/status clocks run at 30 Hz. Movement, facing, animation and
		# strike markers still advance every physics frame at the engine cadence.
		_move_on_map()
	if is_stunned() or is_feared() or custom_frozen(): motion.cancel_attack()
	motion.advance(delta, (global_position - previous) / maxf(delta, 0.001))
	if is_instance_valid(species_visual) and species_visual.warning_active:
		species_visual.warning_progress = clampf(motion.attack_elapsed / maxf(.01, motion.attack_duration * motion.attack_hit_ratio), 0.0, 1.0)
	# Boss warning geometry keeps ticking even at the camera fringe.
	# Resolve its authored eight-direction pose too, or a previously sampled
	# frame can persist across a live telegraph (notably NW). Ordinary remote
	# mobs retain their previous offscreen animation budget.
	var boss_telegraph: bool = is_boss and is_instance_valid(species_visual) and species_visual.warning_active
	if boss_telegraph or on_screen or get_viewport_rect().grow(160).has_point(get_global_transform_with_canvas().origin):
		motion.apply(sprite, animation_base_scale)
		if is_instance_valid(species_visual): species_visual.update_pose()
	animation_state = motion.state
	if not motion.active and velocity.length_squared() > 1.0:
		animation_state = "patrol" if velocity.length() < move_speed * 0.7 else "chase"
	_advance_source_m_view(delta)

func _tick_ai(delta: float) -> void:
	if dead or not is_instance_valid(target_player):
		velocity = Vector2.ZERO
		return
	_tick_stun(delta); _tick_silence(delta); _tick_hold(delta); _tick_fear(delta)
	_tick_poison(delta); _tick_bleed(delta); _tick_slow(delta)
	if dead: velocity = Vector2.ZERO; return
	if source_action_contract_required and (not source_boss_combat.active() or not is_instance_valid(source_m_view)):
		# An explicit native action actor must never fall back to a host basic
		# attack if its private combat table/view is absent or rejected.
		velocity = Vector2.ZERO
		motion.cancel_attack()
		return
	attack_cooldown = maxf(0.,attack_cooldown-delta)
	repath_cooldown = maxf(0.,repath_cooldown-delta)
	aggro_remaining = maxf(0.,aggro_remaining-delta)
	social_alert_cooldown = maxf(0.0, social_alert_cooldown-delta)
	special_cooldown = maxf(0.,special_cooldown-delta)
	blink_cooldown = maxf(0.,blink_cooldown-delta)
	sight_clock = maxf(0.,sight_clock-delta)
	var distance: float = global_position.distance_to(target_player.global_position)
	var enrage_value: Variant = ai.get("enrage", {})
	var enrage_settings: Dictionary = enrage_value as Dictionary if enrage_value is Dictionary else {}
	var next_enraged: bool = AI_POLICY.should_enrage(is_boss, hp, max_hp, enrage_settings)
	if next_enraged and not enraged:
		show_status_text("ENRAGE")
	enraged = next_enraged
	_refresh_overhead_ui(distance)
	if is_stunned() or is_feared() or custom_frozen():
		motion.cancel_attack()
		if is_instance_valid(species_visual): species_visual.warning_active = false
		velocity = _fear_velocity() if is_feared() and not is_held() and not custom_frozen() else Vector2.ZERO
		path = PackedVector2Array(); path_index = 0
		_move_on_map()
		return
	var field_active: bool = world_controller.field_map!=null
	# CannotSee is an observer-local visibility flag. Reuse the host's existing
	# concealed-target policy; no invented source sight radius or stun duration.
	var concealed: bool = source_option_cannot_see() or (world_controller.has_method("is_player_concealed") and world_controller.is_player_concealed())
	var safe: bool = field_active and world_controller.field_map.is_safe(target_player.global_position)
	var leash: float = float(ai.get("leash_distance",1050.))
	var home_distance: float = global_position.distance_to(home_position)
	# Once a monster disengages, finish walking home before re-acquiring its
	# target. This prevents infinite pursuit/re-aggro loops at the leash edge.
	if field_active and AI_POLICY.should_keep_returning(returning_home,home_distance):
		motion.cancel_attack()
		if is_instance_valid(species_visual): species_visual.warning_active = false
		_move_toward(home_position,delta,.8)
		return
	if returning_home:
		returning_home = false
		aggro_remaining = 0.0
	var disengage: bool = AI_POLICY.should_disengage(field_active,safe,concealed,
		home_distance,target_player.global_position.distance_to(home_position),
		distance,aggro_remaining,float(ai.get("aggro_radius",550.)),leash)
	if disengage:
		motion.cancel_attack()
		if is_instance_valid(species_visual): species_visual.warning_active = false
		aggro_remaining = 0.
		if not returning_home: repath_cooldown = 0.
		returning_home = true
		if home_distance > AI_POLICY.RETURN_RADIUS:
			_move_toward(home_position,delta,.8)
		else:
			returning_home = false
			velocity = Vector2.ZERO
		return
	if concealed:
		_stop_chasing_concealed_player()
		return
	var provoked: bool = aggro_remaining>0. or (bool(ai.get("aggressive",true)) and distance<=float(ai.get("aggro_radius",550.)))
	if field_active and not provoked:
		motion.cancel_attack()
		_roam_field(delta)
		return
	if provoked: aggro_remaining = maxf(aggro_remaining,2.)
	var kind: String = current_attack_type()
	var attack_range: float = current_attack_range()
	if motion.active:
		# A moving melee target can invalidate the windup and trigger pursuit;
		# an already released projectile remains independent of this pose.
		if kind=="melee" and not motion.released and special_sequence!=motion.sequence and distance>attack_range*1.35:
			motion.cancel_attack()
			repath_cooldown = 0.
		else:
			velocity = Vector2.ZERO
			return
	if sight_clock<=0.:
		sight_clock = .12+float(get_instance_id()%5)*.008
		sight_cached = world_controller._has_line_of_sight_world(global_position,target_player.global_position) if distance<=maxf(attack_range,620. if is_boss else attack_range) else false
	var sight: bool = sight_cached and distance<=maxf(attack_range,620. if is_boss else attack_range)
	var source523 = _patch523_service()
	if source523 != null and source523.owns_actor(self):
		if source523.try_begin(self,sight): return
		# Never turn an unhandled heal/summon/plate into the generic damage or
		# authored special attack. Existing movement/safe/leash logic remains.
		if distance > attack_range and not is_held(): _move_toward(target_player.global_position,delta)
		else: velocity = Vector2.ZERO
		return
	if source_boss_combat.try_begin(sight): return
	if source_action_contract_required:
		# All strikes for this adoption belong to the native action controller.
		# Preserve the existing host pursuit/hold range, without a second
		# legacy special/basic-attack path during its cooldown or rejection.
		velocity = Vector2.ZERO
		if not source_host_stationary and not is_held() and distance > attack_range and distance <= float(ai.get("aggro_radius",760.))*1.7:
			_move_toward(target_player.global_position,delta)
		return
	if is_boss and ai.has("special") and special_cooldown<=0. and distance<=620. and sight and not is_silenced():
		_begin_special()
		return
	if bool(ai.get("blink",false)) and distance<105. and blink_cooldown<=0. and not is_held():
		blink_cooldown = 8.
		var goal: Vector2 = target_player.global_position+target_player.global_position.direction_to(global_position)*190.
		if field_active and _patrol_allows(goal) and world_controller.field_map.walkable(goal) and world_controller.field_map.point_clear(goal) and not world_controller.field_map.is_safe(goal):
			global_position = goal
			repath_cooldown = 0.
			if world_controller.combat_vfx!=null: world_controller.combat_vfx.ring(global_position,40.,Color(.7,.4,1.))
	var retreat: float = float(ai.get("retreat_distance",0))
	if kind in ["ranged","magic"] and distance<retreat and not is_held() and field_active:
		var goal: Vector2 = global_position+target_player.global_position.direction_to(global_position)*72.
		if world_controller.field_map.walkable(goal) and world_controller.field_map.point_clear(goal):
			_move_toward(goal,delta,.85)
			return
	if distance<=attack_range and sight:
		velocity = Vector2.ZERO
		if attack_cooldown<=0.:
			var source_settings: Dictionary=world_controller.PATCH523_ENHANCE.policy()
			var source_speed: float=clampf(1.0+source_equipment_modifier("source_attack_speed_pct")/100.0,float(source_settings.get("source_buff_attack_speed_factor_min",.05)),float(source_settings.get("source_buff_attack_speed_factor_max",5)))
			attack_cooldown = AI_POLICY.attack_interval(attack_interval, enraged)/source_speed
			var style: String = motion.profile.motion_style if kind=="melee" else ("magic" if kind=="magic" else "bow")
			motion.begin_attack(minf(.68,attack_interval*.75)/source_speed,target_player.global_position-global_position,style,motion.profile.marker_for(style))
			committed_attack_type = kind
		return
	if is_held():
		velocity = Vector2.ZERO
		path = PackedVector2Array(); path_index = 0
		return
	if distance>float(ai.get("aggro_radius",760.))*1.7:
		velocity = Vector2.ZERO
		return
	_move_toward(target_player.global_position,delta)

const OVERHEAD_UI_DISTANCE: float = 520.0

## Name and HP bar are only shown for actors near the player.
func _refresh_overhead_ui(distance: float = -1.0) -> void:
	if distance < 0.0:
		distance = global_position.distance_to(target_player.global_position) if is_instance_valid(target_player) else INF
	var near: bool = distance <= OVERHEAD_UI_DISTANCE
	if is_instance_valid(world_controller):
		var source_hidden: bool = has_meta("source_invisible") or has_meta("source_camouflaged")
		if world_controller.has_method("equipment523_actor_invisible"): source_hidden = source_hidden or world_controller.equipment523_actor_invisible(self)
		if source_hidden and world_controller.has_method("equipment523_can_detect"):
			near = near and world_controller.equipment523_can_detect(self)
		if has_meta("source_doppel_name") and world_controller.has_method("equipment523_target_name"):
			var caption: String = world_controller.equipment523_target_name(self)
			if name_label.text.begins_with("Lv."): caption = "Lv.%d %s" % [monster_level,caption]
			if name_label.text != caption: name_label.text = caption
	if name_label.visible != near: name_label.visible = near
	if hp_bar.visible != near: hp_bar.visible = near

func _move_toward(goal: Vector2, delta: float, speed_ratio: float = 1.) -> void:
	if source_host_stationary:
		velocity = Vector2.ZERO
		path = PackedVector2Array(); path_index = 0
		return
	if is_held(): velocity = Vector2.ZERO; return
	if repath_cooldown<=0.:
		repath_cooldown = .65+float(get_instance_id()%7)*.015
		# Most crowded fights are in one open hunting room. Avoid one expensive
		# AStar search per creature when its straight movement corridor is clear.
		if world_controller.field_map!=null and world_controller.field_map.line_clear(global_position,goal):
			path = PackedVector2Array([goal])
		else:
			path = world_controller.find_world_path(global_position,goal)
		path_index = 0
	while path_index<path.size() and global_position.distance_to(path[path_index])<8.: path_index += 1
	if path_index>=path.size():
		velocity = Vector2.ZERO
		path_stuck_elapsed = 0.0
		return
	var point: Vector2 = path[path_index]
	var before_move: Vector2 = global_position
	var tactical_speed: float = move_speed * source_523_speed_factor() * speed_ratio * AI_POLICY.chase_speed_factor(enraged and not returning_home)
	velocity = global_position.direction_to(point)*minf(tactical_speed,global_position.distance_to(point)/maxf(.001,delta))
	_move_on_map()
	path_stuck_elapsed = AI_POLICY.next_stuck_elapsed(path_stuck_elapsed,
		global_position.distance_to(before_move),velocity.length(),delta)
	if AI_POLICY.should_repath(path_stuck_elapsed):
		# Only clear the path and try AStar again; never teleport through walls.
		repath_cooldown = 0.0
		path_stuck_elapsed = 0.0
		path = PackedVector2Array()
		path_index = 0

func _begin_special() -> void:
	if dead or is_stunned() or is_feared() or is_silenced() or not _target_attackable() or not ai.has("special"): return
	var skill: Dictionary = (ai.special as Dictionary).duplicate(true)
	var aim: Vector2 = BOSS_GEOMETRY.direction(target_player.global_position-global_position, motion.direction)
	special_cooldown = float(skill.get("cooldown",12.))*(.7 if hp*2<max_hp else 1.)
	velocity = Vector2.ZERO
	special_sequence = motion.begin_attack(float(skill.get("windup",1.15)),aim,str(motion.profile.presentation.get("special_motion", "magic")),.85)
	if special_sequence < 0: return
	special_attack = {"skill":skill, "center":global_position, "aim":aim}
	motion.action_role = "special"
	motion.invalidate_pose()
	if is_instance_valid(species_visual):
		species_visual.warning_active = true
		species_visual.special = skill.duplicate(true)
		species_visual.warning_center = special_attack.center
		species_visual.warning_aim = aim
		species_visual.warning_progress = 0.
		species_visual.prepare_warning()
	if world_controller.has_method("show_combat_number"):
		world_controller.show_combat_number(global_position+Vector2(0,-visual_height-30),str(skill.get("label","특수 공격")),Color(1,.55,.2),true)

func _resolve_special() -> void:
	if special_attack.is_empty() or not motion.released or released_sequence != special_sequence: return
	# Consume before callbacks (damage/death/map changes can re-enter combat).
	var action: Dictionary = special_attack
	special_attack = {}
	if is_instance_valid(species_visual): species_visual.warning_active = false; species_visual.queue_redraw()
	if dead or is_stunned() or is_feared() or is_silenced() or not _target_attackable(): return
	var skill: Dictionary = action.skill
	var kind: String = str(skill.get("kind","nova"))
	var center: Vector2 = action.center
	var aim: Vector2 = action.aim
	var relative: Vector2 = target_player.global_position-center
	var radius: float = float(skill.get("radius",200))
	var hit: bool = BOSS_GEOMETRY.contains(kind, radius, relative, aim)
	if kind=="charge" and not is_held():
		var goal: Vector2 = center+aim*minf(radius*2.,relative.length())
		if world_controller.field_map!=null and _patrol_allows(goal) and world_controller.field_map.walkable(goal) and world_controller.field_map.point_clear(goal) and world_controller.field_map.line_clear(center,goal):
			global_position = goal
	if kind=="summon":
		if world_controller.field_population!=null: world_controller.field_population.summon_for(self)
		hit = false
	if kind=="volley" and world_controller.combat_flights!=null:
		for i: int in range(3):
			_launch_projectile(special_sequence,"ranged",float(i)*.14,.55,{"boss_kind":"volley"})
		hit = false
	if is_instance_valid(species_visual):
		# Both the warning and release renderer consume the same combat snapshot.
		species_visual.special = skill.duplicate(true)
		species_visual.warning_center = center
		species_visual.warning_aim = aim
		species_visual.prepare_warning()
		species_visual.release_special()
	elif world_controller.combat_vfx!=null:
		world_controller.combat_vfx.ring(center,minf(radius,150.),Color(1,.34,.15))
	if hit and world_controller._has_line_of_sight_world(center,target_player.global_position):
		var resolving_life: int = life_id
		_emit_symbol_hit(int(attack_power*float(skill.get("multiplier",1.6))),"magic" if kind not in ["charge","cone"] else "melee",{"boss_kind":kind})
		if kind=="drain" and not dead and life_id == resolving_life: hp = mini(max_hp,hp+source_option_healing(attack_power*2)); hp_bar.value = hp

func _stop_chasing_concealed_player() -> void:
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0

func _roam_field(delta: float) -> void:
	if is_held():
		velocity = Vector2.ZERO
		return
	roam_clock -= delta
	if roam_clock <= 0.0:
		roam_clock = world_controller.rng.randf_range(3.5,7.0)
		var angle: float = world_controller.rng.randf_range(0.0,TAU)
		var goal: Vector2 = home_position + Vector2.from_angle(angle)*world_controller.rng.randf_range(30.0,roaming_radius)
		if not _patrol_allows(goal) or world_controller.field_map.is_safe(goal) or not world_controller.field_map.walkable(goal) or not world_controller.field_map.point_clear(goal):
			goal = home_position
		path = world_controller.find_world_path(global_position,goal)
		path_index = 0
	while path_index < path.size() and global_position.distance_to(path[path_index]) < 8:
		path_index += 1
	if path_index >= path.size():
		velocity = Vector2.ZERO
		return
	var direction: Vector2 = global_position.direction_to(path[path_index])
	velocity = direction * minf(move_speed*source_523_speed_factor()*.48,global_position.distance_to(path[path_index])/maxf(delta,.001))
	_move_on_map()
	if absf(velocity.x)>1:
		sprite.flip_h = velocity.x<0

func _tick_poison(delta: float) -> void:
	if dead or poison_remaining <= 0.0 or poison_tick_damage <= 0:
		return
	var active_delta: float = minf(delta, poison_remaining)
	poison_remaining = maxf(0.0, poison_remaining - delta)
	poison_tick_clock -= active_delta
	while poison_tick_clock <= 0.0 and poison_tick_damage > 0 and not dead:
		take_damage(poison_tick_damage, false, "poison")
		poison_tick_clock += poison_tick_interval
	if poison_remaining <= 0.0 or dead:
		poison_tick_clock = 0.0
		if not dead:
			poison_tick_damage = 0

func is_poisoned() -> bool:
	if dead:return false
	if poison_remaining > 0.0 and poison_tick_damage > 0:return true
	for entry: Dictionary in source_option_debuffs.values():
		if float(entry.remaining) > 0 and entry.has("venom"):return true
	return false

func apply_poison(duration: float, damage: int, interval: float = 1.0) -> void:
	if dead:
		return
	var safe_duration: float = maxf(0.0, duration)
	var safe_interval: float = maxf(0.1, interval)
	var was_poisoned: bool = is_poisoned()
	poison_remaining = maxf(poison_remaining, safe_duration)
	poison_tick_damage = maxi(poison_tick_damage, maxi(1, damage))
	poison_tick_interval = safe_interval
	if not was_poisoned or poison_tick_clock <= 0.0:
		poison_tick_clock = safe_interval
	else:
		poison_tick_clock = minf(poison_tick_clock, safe_interval)
	show_status_text("POISON")

func clear_poison() -> void:
	poison_remaining = 0.0
	poison_tick_clock = 0.0
	poison_tick_damage = 0
	for entry: Dictionary in source_option_debuffs.values():entry.erase("venom")

func _tick_bleed(delta: float) -> void:
	if dead or bleed_remaining <= 0.0 or bleed_tick_damage <= 0:
		return
	var active_delta: float = minf(delta, bleed_remaining)
	bleed_remaining = maxf(0.0, bleed_remaining - delta)
	bleed_tick_clock -= active_delta
	while bleed_tick_clock <= 0.0 and bleed_tick_damage > 0 and not dead:
		take_damage(bleed_tick_damage, false, "bleed")
		bleed_tick_clock += bleed_tick_interval
	if bleed_remaining <= 0.0 or dead:
		bleed_tick_clock = 0.0
		if not dead:
			bleed_tick_damage = 0

func is_bleeding() -> bool:
	return (bleed_remaining > 0.0 and bleed_tick_damage > 0 or not patch523_weapon_bleed.is_empty()) and not dead

func apply_patch523_weapon_bleed(effect: Dictionary, interval: float, rule: String) -> void:
	preload("res://scripts/loot/patch523_weapon_bleed.gd").apply(self,effect,interval,rule)

func apply_bleed(duration: float, damage: int, interval: float = 0.75) -> void:
	if dead:
		return
	var safe_duration: float = maxf(0.0, duration)
	var safe_interval: float = maxf(0.1, interval)
	var was_bleeding: bool = is_bleeding()
	bleed_remaining = maxf(bleed_remaining, safe_duration)
	bleed_tick_damage = maxi(bleed_tick_damage, maxi(1, damage))
	bleed_tick_interval = safe_interval
	if not was_bleeding or bleed_tick_clock <= 0.0:
		bleed_tick_clock = safe_interval
	else:
		bleed_tick_clock = minf(bleed_tick_clock, safe_interval)
	show_status_text("BLEED")

func clear_bleed() -> void:
	bleed_remaining = 0.0
	bleed_tick_clock = 0.0
	bleed_tick_damage = 0

func _tick_fear(delta: float) -> void:
	fear_remaining = maxf(0.0, fear_remaining - delta)

func is_feared() -> bool:
	return fear_remaining > 0.0

func apply_fear(duration: float, source_position: Vector2) -> void:
	if dead:
		return
	fear_remaining = maxf(fear_remaining, maxf(0.0, duration))
	fear_source_position = source_position
	if is_feared(): motion.cancel_attack()
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	show_status_text("FEAR")

func _fear_velocity() -> Vector2:
	var away: Vector2 = global_position - fear_source_position
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	return away.normalized() * move_speed * source_523_speed_factor() * fear_move_multiplier

func _tick_hold(delta: float) -> void:
	hold_remaining = maxf(0.0, hold_remaining - delta)

func is_held() -> bool:
	return hold_remaining > 0.0 or EQUIPMENT523_INVOKE_DEBUFF.control_active(self,"hold")

func apply_hold(duration: float) -> void:
	if dead:
		return
	hold_remaining = maxf(hold_remaining, maxf(0.0, duration))
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	show_status_text("HOLD")

func current_attack_type() -> String:
	if attack_type == "magic" and is_silenced():
		return "melee"
	return attack_type

func _tick_silence(delta: float) -> void:
	silence_remaining = maxf(0.0, silence_remaining - delta)

func is_silenced() -> bool:
	return silence_remaining > 0.0

func apply_silence(duration: float) -> void:
	if dead:
		return
	silence_remaining = maxf(silence_remaining, maxf(0.0, duration))
	if is_silenced() and motion.active and (motion.attack_style == "magic" or special_sequence == motion.sequence):
		motion.cancel_attack()
	show_status_text("SILENCE")

func _tick_stun(delta: float) -> void:
	stun_remaining = maxf(0.0, stun_remaining - delta)

func is_stunned() -> bool:
	return stun_remaining > 0.0 or EQUIPMENT523_INVOKE_DEBUFF.control_active(self,"stun")

func on_equipment523_control(kind: String) -> void:
	# The equipment layer owns its timer. Preserve timers from every other
	# skill so its expiry or clear cannot erase an unrelated stun or hold.
	if dead or kind not in ["stun","hold"]: return
	if kind == "stun": motion.cancel_attack()
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	show_status_text("STUN" if kind == "stun" else "HOLD")

func apply_stun(duration: float) -> void:
	if dead or status_immunities.has("stun"):
		return
	stun_remaining = maxf(stun_remaining, maxf(0.0, duration))
	if is_stunned(): motion.cancel_attack()
	velocity = Vector2.ZERO
	path = PackedVector2Array()
	path_index = 0
	show_status_text("STUN")

func show_status_text(text_value: String) -> void:
	if dead:
		return
	var label: Label = Label.new()
	label.text = text_value
	label.position = Vector2(-48.0, -112.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.93, 0.78, 0.30, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 34
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -28.0), 0.60)
	tween.tween_property(label, "modulate:a", 0.0, 0.60)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func critical_rate_for_type(kind: String) -> int:
	match kind:
		"ranged":
			return ranged_critical_rate
		"magic":
			return magic_critical_rate
		_:
			return melee_critical_rate

func apply_slow(duration: float, multiplier: float = 0.65) -> void:
	if dead:
		return
	slow_remaining = maxf(slow_remaining, maxf(0.0, duration))
	slow_multiplier = minf(slow_multiplier, clampf(multiplier, 0.2, 1.0))
	move_speed = base_move_speed * slow_multiplier
	show_status_text("SLOW")

func _tick_slow(delta: float) -> void:
	if slow_remaining <= 0.0:
		return
	slow_remaining = maxf(0.0, slow_remaining - delta)
	if slow_remaining <= 0.0:
		slow_multiplier = 1.0
	move_speed = base_move_speed * slow_multiplier

func is_undead() -> bool:
	return undead or monster_type == "언데드"

func elemental_resistance_percent(element_name: String) -> float:
	return float(element_resistance.get(element_name, 0.0))

func take_damage(amount: int, critical: bool = false, damage_kind: String = "") -> void:
	if dead:
		return
	var source523 = _patch523_service()
	if source523 != null: amount = source523.extensions.before_damage(self,amount,damage_kind)
	if amount <= 0: return
	if source523 != null and amount >= hp: source523.extensions.remaining.capture_rewards(self)
	damage_hit_count += 1
	aggro_remaining = 10.
	if social_alert_cooldown <= 0.0 and is_instance_valid(world_controller) and world_controller.get("field_population")!=null:
		social_alert_cooldown = AI_POLICY.SOCIAL_ALERT_DELAY
		world_controller.field_population.alert_social(self)
	hp = maxi(0, hp - amount)
	hp_bar.value = hp
	_show_damage_number(amount, critical)
	if is_instance_valid(world_controller) and world_controller.has_method("monster_combat_feedback"):
		world_controller.monster_combat_feedback(self, critical, damage_kind)
	motion.react(critical, target_player.global_position.direction_to(global_position) if is_instance_valid(target_player) else Vector2.ZERO)
	if hp <= 0:
		dead = true
		motion.die()
		if has_node("GroundShadow"): $GroundShadow.hide()
		name_label.hide()
		hp_bar.hide()
		input_pickable = false
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)
		set_physics_process(true)
		died.emit(self)

func show_miss() -> void:
	if dead:
		return
	if is_instance_valid(world_controller) and world_controller.has_method("show_combat_number"):
		world_controller.show_combat_number(global_position + Vector2(0, -visual_height - 8), "MISS", Color(0.78, 0.86, 1.0))
		return
	var label: Label = Label.new()
	label.text = "MISS"
	label.position = Vector2(-36.0, -88.0)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.78, 0.86, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.14, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 30
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -30.0), 0.50)
	tween.tween_property(label, "modulate:a", 0.0, 0.50)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _show_damage_number(amount: int, critical: bool = false) -> void:
	if is_instance_valid(world_controller) and world_controller.has_method("show_combat_number"):
		world_controller.show_combat_number(global_position + Vector2(0, -visual_height - 8), ("CRIT " if critical else "") + str(amount), Color(1.0, 0.45, 0.2) if critical else Color(1.0, 0.83, 0.4), critical)
		return
	var label: Label = Label.new()
	label.text = ("CRIT " + str(amount)) if critical else str(amount)
	label.position = Vector2(-28.0, -88.0)
	label.add_theme_font_size_override("font_size", 24 if critical else 20)
	label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.18, 1.0) if critical else Color(1.0, 0.77, 0.28, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.03, 0.01, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 30
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0.0, -34.0), 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			selected.emit(self)

func note_asleep() -> void:
	# Park only after the actor has stayed asleep for a while, so actors at the
	# sleep boundary never thrash their frames. An actor spawned asleep has
	# never been seen, so it parks at once and the spawn burst stays small.
	if not _awake_since_setup:
		park_visual()
	elif _asleep_since_msec < 0:
		_asleep_since_msec = Time.get_ticks_msec()
	elif Time.get_ticks_msec() - _asleep_since_msec >= VISUAL_PARK_AFTER_MSEC:
		park_visual()

func park_visual() -> void:
	# Bosses keep their frames: their save/respawn lifecycle and encounter
	# presentation are checked against the live frames.
	if visual_parked or motion.frame_source == null or is_boss or dead or motion.active or _source_only_native_visuals: return
	if motion.profile == null or motion.profile.frames_path.is_empty(): return
	var first: Texture2D = ANIMATION_CATALOG.first_texture(motion.frame_source)
	motion.frame_source = null
	motion._track_source = null
	motion._native_hit_source = null
	motion._native_hit_clock = 0.0
	motion._tracks = {}
	motion._resolved_profile = null
	motion._resolved_key = ""
	if first != null: sprite.texture = first
	visual_parked = true

func restore_visual() -> void:
	_asleep_since_msec = -1
	_awake_since_setup = true
	if not visual_parked: return
	visual_parked = false
	var frames: SpriteFrames = ANIMATION_CATALOG.frames_for_profile(motion.profile, "")
	var first: Texture2D = ANIMATION_CATALOG.first_texture(frames)
	if first == null: return
	motion.frame_source = frames
	sprite.texture = first
	motion.apply(sprite, animation_base_scale)

func _setup_animation(record: Dictionary) -> void:
	visual_parked = false
	_asleep_since_msec = -1
	_awake_since_setup = false
	motion.profile = ANIMATION_CATALOG.for_record("monster", record)
	# Sample optional native art onto the existing Sprite2D; no scene/AI/UI changes.
	motion.frame_source = null
	if not _source_only_native_visuals and not motion.profile.frames_path.is_empty():
		var frames: SpriteFrames = ANIMATION_CATALOG.frames_for_profile(motion.profile, "")
		var first: Texture2D = ANIMATION_CATALOG.first_texture(frames)
		if first != null:
			motion.frame_source = frames
			sprite.texture = first
			sprite.material = null # pooled portrait shaders must not warp native views
	motion.profile.reference_speed = maxf(1.0, base_move_speed)
	visual_height = float(record.get("visual_height", 92.0 if is_boss else (62.0 if motion.profile.motion_style == "crawl" else 72.0)))
	if sprite.texture != null:
		animation_base_scale = Vector2.ONE * (visual_height / maxf(1.0, maxf(sprite.texture.get_width(), sprite.texture.get_height())))
		if record.has("visual") and motion.frame_source==null:
			var scale_value: float = minf(visual_height/maxf(1.,sprite.texture.get_height()),visual_height*1.65/maxf(1.,sprite.texture.get_width()))
			animation_base_scale = Vector2.ONE*scale_value
			visual_height = sprite.texture.get_height()*scale_value
	else:
		animation_base_scale = Vector2.ONE
	if motion.profile.pixel_scale > 0.0:
		animation_base_scale = Vector2.ONE * motion.profile.pixel_scale
	if motion.frame_source != null:
		animation_base_scale.x *= motion.profile.native_width_ratio
	# Foot anchor and hit point depend on visible body size, not one fixed offset.
	motion.profile.sprite_offset = Vector2(0, -visual_height * 0.46)
	motion.profile.hit_position = Vector2(0, -visual_height * 0.42)
	motion.profile.projectile_origin = Vector2(visual_height * 0.15, -visual_height * 0.48)
	motion.profile.shadow_size = Vector2(visual_height * 0.25, visual_height * 0.08)
	var overrides: Dictionary = ANIMATION_CATALOG.records.get(motion.profile.profile_id, {}).duplicate(true)
	overrides.merge(record.get("animation_profile", {}), true)
	for property: String in ["sprite_offset", "hit_position", "projectile_origin", "shadow_size"]:
		var value: Variant = overrides.get(property)
		if value is Array and value.size() == 2: motion.profile.set(property, Vector2(value[0], value[1]))
	preload("res://scripts/monsters/reviewed_existing_visuals.gd").apply_anchor(motion.profile, record)
	attack_interval = maxf(0.12, float(record.get("attack_interval", 1.25)))
	configured_attack_range = maxf(0.0, float(record.get("attack_range", 0.0)))
	var shape: CircleShape2D = $CollisionShape2D.shape.duplicate() as CircleShape2D
	shape.radius = maxf(1.0,float(record.get("collision_radius",19.)))
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = motion.profile.collision_offset
	name_label.position.y = -visual_height - 20.0
	hp_bar.position.y = -visual_height - 4.0
	if not motion_connected:
		motion.strike.connect(_release_attack)
		motion.cancelled.connect(_cancel_attack)
		motion_connected = true
	if not has_node("GroundShadow"):
		var shadow: Node2D = preload("res://scripts/animation/actor_shadow.gd").new()
		shadow.name = "GroundShadow"
		shadow.radius = motion.profile.shadow_size
		add_child(shadow)
	$GroundShadow.visible = not _source_only_native_visuals and not motion.profile.embedded_shadow
	motion.apply(sprite, animation_base_scale)
	_hide_source_only_native_media()

func current_attack_range() -> float:
	if configured_attack_range > 0.0 and not is_silenced(): return configured_attack_range
	var kind: String = current_attack_type()
	return 280.0 if kind == "magic" else (220.0 if kind == "ranged" else 58.0)

func combat_hit_position() -> Vector2:
	return global_position + motion.profile.hit_position

func _cancel_attack(id: int) -> void:
	var source523 = _patch523_service()
	if source523 != null: source523.cancel(self,id)
	source_boss_combat.cancel(id)
	if id != special_sequence: return
	special_attack.clear()
	special_sequence = -1
	if is_instance_valid(species_visual):
		species_visual.warning_active = false
		species_visual.queue_redraw()

func _release_attack(id: int) -> void:
	if dead or id != motion.sequence or id == released_sequence or not motion.active or not motion.released: return
	released_sequence = id
	var source523 = _patch523_service()
	if source523 != null and source523.release(self,id): return
	if source_boss_combat.release(id): return
	if source_action_contract_required: return
	if not _target_attackable(): return
	if is_stunned() or is_feared() or custom_frozen(): return
	if id==special_sequence:
		_resolve_special()
		return
	if global_position.distance_to(target_player.global_position) > current_attack_range(): return
	if not world_controller._has_line_of_sight_world(global_position, target_player.global_position): return
	if world_controller.is_player_concealed(): return
	if world_controller.field_map != null and world_controller.field_map.is_safe(target_player.global_position): return
	var kind: String = committed_attack_type
	if kind == "magic" and is_silenced(): return
	if kind in ["ranged", "magic"] and world_controller.combat_flights != null:
		_launch_projectile(id,kind)
	else:
		_resolve_attack(id, kind)

func _target_attackable() -> bool:
	if source_option_cannot_see() or not is_instance_valid(target_player) or world_controller.hp<=0: return false
	if world_controller.is_player_concealed(): return false
	return world_controller.field_map==null or not world_controller.field_map.is_safe(target_player.global_position)

func _launch_projectile(id: int, kind: String, delay: float = 0., ratio: float = 1., context: Dictionary = {}) -> void:
	var aim: Vector2 = target_player.combat_hit_position()
	var origin: Vector2 = combat_hit_position()+motion.direction*visual_height*.18
	var color: Color = {"fire":Color(1,.35,.10),"water":Color(.2,.7,1),"wind":Color(.5,1,.75),"earth":Color(.8,.65,.35),"dark":Color(.75,.4,1)}.get(attack_element,Color(1,.87,.5))
	world_controller.combat_flights.launch(origin,target_player,kind,_resolve_attack.bind(id,kind,life_id,ratio,context.duplicate(true)),800. if kind=="magic" else 1100.,delay,
		{"aim":aim,"hit_radius":30.,"obstruction":_projectile_clear,"color":color})

func _projectile_clear(from: Vector2, to: Vector2) -> bool:
	if dead: return false
	# Projectiles draw at torso height; map obstruction checks use their ground
	# projection, the same navigational/physical geometry as walking actors.
	var offset: Vector2 = motion.profile.hit_position
	return world_controller._has_line_of_sight_world(from-offset,to-offset)

func _resolve_attack(id: int, kind: String, born: int = -1, ratio: float = 1., context: Dictionary = {}) -> void:
	if dead or (born!=-1 and born!=life_id) or not _target_attackable(): return
	if kind=="melee" and (id!=motion.sequence or global_position.distance_to(target_player.global_position)>current_attack_range()): return
	if not world_controller._has_line_of_sight_world(global_position,target_player.global_position): return
	_emit_symbol_hit(maxi(1,int(attack_power*ratio)),kind,context)

func _emit_symbol_hit(amount: int, kind: String, context: Dictionary) -> void:
	var previous: Dictionary=symbol_hit_context
	symbol_hit_context=context.duplicate(true)
	player_hit.emit(self,amount,kind)
	symbol_hit_context=previous

func _move_on_map() -> void:
	if source_host_stationary:
		velocity = Vector2.ZERO
		return
	var controller: Node = world_controller
	if not _patrol_allows(global_position+velocity*get_physics_process_delta_time()): velocity = Vector2.ZERO
	if is_instance_valid(controller) and controller.has_method("constrain_original_motion"):
		controller.constrain_original_motion(self)
	move_and_slide()

func _patrol_allows(point: Vector2) -> bool:
	if not is_instance_valid(world_controller): return true
	# New PNG encounters opt normals into their authored habitat/portal limits.
	# Older fields keep their existing free-roaming normal-monster behavior.
	var field: Variant = world_controller.field_map
	if not is_boss and (field==null or not bool(field.data.get("constrain_all_population_patrol",false))): return true
	var population: Node = world_controller.field_population
	return not is_instance_valid(population) or not population.has_method("destination_allowed") or population.destination_allowed(self,point)

func apply_source_option_debuff(origin: String,duration: float,effects: Array) -> bool:
	if dead or duration<=0:return false
	for effect: Dictionary in effects:
		if int(effect.bonus.BonusApplicationTypeID)!=0 or int(effect.bonus.BonusApplicationTargetID)!=0:return false
		if effect.type.Name == "CannotSee":
			if effect.unit.Name != "TrueFalse" or int(effect.bonus.Value) != 1:return false
		elif effect.type.Name not in ["HPHealDecreasePercent","HPPotionDecreasePercent"] or effect.unit.Name!="Percentage":return false
	source_option_sequence += 1
	source_option_debuffs[origin]={"remaining":duration,"effects":effects.duplicate(true),"sequence":source_option_sequence}
	if source_option_cannot_see():
		motion.cancel_attack()
		_stop_chasing_concealed_player()
		sight_cached = false
		sight_clock = 0
		if is_inside_tree():show_status_text("시야 차단")
	return true

func source_option_cannot_see() -> bool:
	if dead:return false
	for entry: Dictionary in source_option_debuffs.values():
		if float(entry.remaining) <= 0:continue
		for effect: Dictionary in entry.effects:
			if effect.type.Name == "CannotSee" and int(effect.bonus.Value) == 1:return true
	return false

func configure_totem_venom(origin: String, interval: float, raw_percent: int, minimum: int, maximum: int, policy_id: String) -> bool:
	# Explicit host adapter: source rate/min/max, local tick and clamp procedure.
	if dead or status_immunities.has("poison") or origin != "totem:17524" or not source_option_debuffs.has(origin):return false
	if not is_finite(interval) or interval < 0.25 or interval > 10 or raw_percent < 0 or raw_percent > 1000000 or minimum <= 0 or maximum < minimum:return false
	var damage := clampi(int(floor(float(max_hp)*float(raw_percent)/1000000.0)),minimum,maximum)
	source_option_debuffs[origin]["venom"] = {"clock":interval,"interval":interval,"damage":damage,"policy":policy_id}
	if is_inside_tree():show_status_text("중독 [자체 주기]")
	return true
func prune_source_option_debuffs(enabled: Dictionary, origin_prefix: String = "") -> void:
	for origin: String in source_option_debuffs.keys():
		if origin_prefix.is_empty() and origin.begins_with("totem:"): continue
		if not origin_prefix.is_empty() and not origin.begins_with(origin_prefix): continue
		if dead or not enabled.has(origin):source_option_debuffs.erase(origin)
func source_equipment_modifier(key: String) -> float:
	if not is_instance_valid(world_controller) or world_controller.original_skills==null:return 0
	return world_controller.original_skills.status.modifier(self,key)

func source_option_healing(amount: int,potion: bool=false) -> int:
	var maximum: int=maxi(EQUIPMENT523_INVOKE_DEBUFF.healing_weight(self,potion),maxi(0,int(source_equipment_modifier("source_potion_heal_decrease_raw" if potion else "source_hp_heal_decrease_raw"))))
	for entry: Dictionary in source_option_debuffs.values():
		for effect: Dictionary in entry.effects:
			if effect.type.Name==("HPPotionDecreasePercent" if potion else "HPHealDecreasePercent"):maximum=maxi(maximum,int(effect.bonus.Value))
	# Native Percentage uses 1,000,000 raw units for 100%. Keep raw values,
	# clamp the resulting recovery at zero; never turn healing into damage.
	return maxi(0,int(float(amount)*(1.0-clampf(float(maximum)/1000000.0,0,1))))

func advance_source_option_debuffs(delta: float) -> void:
	for origin: String in source_option_debuffs.keys():
		if not source_option_debuffs.has(origin):continue
		var entry: Dictionary = source_option_debuffs[origin]
		var active_delta := minf(maxf(0,delta),maxf(0,float(entry.remaining)))
		entry.remaining -= maxf(0,delta)
		var born := life_id
		var sequence := int(entry.get("sequence",-1))
		if entry.has("venom"):
			entry.venom.clock -= active_delta
			while float(entry.venom.clock) <= 0.000001 and not dead:
				if life_id != born or int(source_option_debuffs.get(origin,{}).get("sequence",-2)) != sequence:break
				entry.venom.clock += float(entry.venom.interval)
				take_damage(int(entry.venom.damage),false,"poison")
		if life_id == born and int(source_option_debuffs.get(origin,{}).get("sequence",-2)) == sequence and (dead or float(entry.remaining) <= 0):source_option_debuffs.erase(origin)

func hit_armor_class() -> int:
	# Existing local formula expects nonpositive armor; preserve raw native AC for display/audit.
	var base: int = mini(0, armor_class) if not source_m_original.is_empty() else armor_class
	var source523 = _patch523_service()
	return base-int(source523.extensions.actor_values(self).get("ArmorClass",0)) if source523 != null else base

func _patch523_service() -> RefCounted:
	return world_controller.get("patch523_npc_spells") if is_instance_valid(world_controller) else null

func source_523_speed_factor() -> float:
	var source523 = _patch523_service()
	return source523.extensions.remaining.speed(self) if source523 != null else 1.0

func effective_source_attribute(attribute: String) -> float:
	if is_instance_valid(world_controller) and world_controller.get("growth")!=null:return float(world_controller.growth.guardian_combat.attribute(self,attribute).after)
	var original: Dictionary = source_m_original if not source_m_original.is_empty() else _original_attribute_values
	return float(original.get(attribute.capitalize(),0))

func original_attribute_input() -> Dictionary:
	return _original_attribute_values.duplicate(true)


