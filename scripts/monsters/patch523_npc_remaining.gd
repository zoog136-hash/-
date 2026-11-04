extends RefCounted
## Local opt-in policies; never alter source rows, rarity rates or roll counts.
var _extension: WeakRef
var extension: RefCounted:
	get: return _extension.get_ref() if _extension != null else null
var stats_enabled: bool = false
var strength_damage: float = 1
var strength_accuracy: float = 1
var dexterity_damage: float = 1
var dexterity_accuracy: float = 1
var drops_enabled: bool = false
var drop_divisor: float = 1000
var item_bindings: Dictionary = {} # Explicit user choice: source ItemClassID -> current item name.
var own_buff: int = 0
var own_map: String = ""
var own_center: Vector2 = Vector2.ZERO
var special_type: int = 0 # 0 existing channel, 42 Dark, 72 MeleeMagic (reaction classification only)
var host_cancel_mode: int = 0 # 0 source only, 1 selected names, 2 all eligible host buffs
var selected_host_buffs: Array = []
var protected_host_buffs: Array = []
var rewards: Dictionary = {}
var last_event: Dictionary = {}
var environment_ids: Dictionary = {}
const KEYS = ["stats_enabled","strength_damage","strength_accuracy","dexterity_damage","dexterity_accuracy","drops_enabled","drop_divisor","item_bindings","own_buff","own_map","own_center","special_type","host_cancel_mode","selected_host_buffs","protected_host_buffs"]

func configure(owner: RefCounted, cfg: ConfigFile) -> void:
	_extension = weakref(owner)
	environment_ids.clear()
	for entry: Dictionary in owner.service.catalog.content.get("tables",{}).get("LandAttribute",{}).values(): environment_ids[int(entry.row.Value)] = true
	for key: String in ["stats_enabled","drops_enabled"]: set(key,bool(cfg.get_value("remaining",key,get(key))))
	for key: String in ["strength_damage","strength_accuracy","dexterity_damage","dexterity_accuracy"]: set(key,owner.service.compatibility.bounded(cfg.get_value("remaining",key,1),0,10,1))
	drop_divisor = owner.service.compatibility.bounded(cfg.get_value("remaining","drop_divisor",1000),1,1000000,1000)
	own_buff = int(cfg.get_value("remaining","own_buff",0)); own_map = str(cfg.get_value("remaining","own_map",""))
	var point: Variant = cfg.get_value("remaining","own_center",Vector2.ZERO)
	own_center = point if point is Vector2 and point.is_finite() else Vector2.ZERO
	special_type = int(cfg.get_value("remaining","special_type",0))
	if special_type not in [0,42,72]: special_type = 0
	host_cancel_mode = clampi(int(cfg.get_value("remaining","host_cancel_mode",0)),0,2)
	var bindings: Variant = cfg.get_value("remaining","item_bindings",{})
	item_bindings = bindings if bindings is Dictionary else {}
	for key: String in ["selected_host_buffs","protected_host_buffs"]:
		var value: Variant = cfg.get_value("remaining",key,[])
		set(key,value if value is Array else [])

func save_into(cfg: ConfigFile) -> void:
	for key: String in KEYS: cfg.set_value("remaining",key,get(key))

func clear() -> void:
	rewards.clear(); last_event.clear()

func bind_current(buff_id: int) -> bool:
	if extension.service.world.get("field_map") == null or extension.service.catalog.row("BuffClass",buff_id).is_empty(): return false
	own_buff = buff_id; own_map = str(extension.service.world.active_map_id); own_center = extension.service.world.player.global_position
	return true

func own_binding(actor: Node) -> Dictionary:
	if extension == null or not extension.environment_enabled or not extension.service.host_enabled or own_buff <= 0 or str(extension.service.world.active_map_id) != own_map or extension.service.world.get("field_map") == null: return {}
	if actor.global_position.distance_to(own_center) > extension.own_radius: return {}
	return {"attribute":{"ID":-own_buff,"Value":own_buff},"buff":extension.service.catalog.buff_details(own_buff),"host_context":true,"drop_profile":not environment_ids.has(own_buff)}

func maximum_hp(actor: Node, base: int) -> int:
	if not stats_enabled: return base
	var bonus: int = int(extension.actor_values(actor).get("HPPlus",0))
	return base if bonus == 0 else maxi(1,base+bonus)

func speed(actor: Node) -> float:
	return maxf(.1,1.0+float(extension.actor_values(actor).get("MoveSpeedBonus",0))/1000000.0) if stats_enabled else 1.0

func attribute_damage(actor: Node, channel: String) -> int:
	if not stats_enabled: return 0
	var values: Dictionary = extension.actor_values(actor)
	return int(float(values.get("Strength",0))*strength_damage) if channel == "melee" else int(float(values.get("Dexterity",0))*dexterity_damage) if channel == "ranged" else 0

func accuracy(actor: Node, channel: String) -> int:
	if not stats_enabled: return 0
	var values: Dictionary = extension.actor_values(actor)
	return int(float(values.get("Strength",0))*strength_accuracy) if channel == "melee" else int(float(values.get("Dexterity",0))*dexterity_accuracy) if channel == "ranged" else 0

func sync_actor(actor: Node) -> void:
	if not stats_enabled and not bool(actor.get_meta("patch523_hp_was_enabled",false)): return
	# Entry increases the cap only. Never grant healing by crossing a boundary.
	actor.hp = mini(actor.hp,actor.max_hp)
	if is_instance_valid(actor.hp_bar): actor.hp_bar.max_value = actor.max_hp; actor.hp_bar.value = actor.hp
	actor.set_meta("patch523_hp_was_enabled",stats_enabled)

func capture_rewards(actor: Node) -> void:
	if extension == null or not extension.service.host_enabled or (not stats_enabled and not drops_enabled): return
	var bonus: int = int(extension.actor_values(actor).get("AddtionalExperience",0)) if stats_enabled else 0
	rewards[actor.get_instance_id()] = {"actor":weakref(actor),"life":actor.life_id,"generation":extension.service.world.combat_generation,"experience":bonus,"weights":drop_weights(actor)}

func reward_for(actor: Node) -> Dictionary:
	var entry: Dictionary = rewards.get(actor.get_instance_id(),{})
	if entry.is_empty() or int(entry.life) != int(actor.life_id) or int(entry.generation) != int(extension.service.world.combat_generation): return {}
	return entry

func take_reward(actor: Node) -> Dictionary:
	var result: Dictionary = reward_for(actor)
	rewards.erase(actor.get_instance_id())
	return result

func forget(actor: Node) -> void:
	rewards.erase(actor.get_instance_id())
	actor.set_meta("patch523_hp_was_enabled",false)

func drop_weights(actor: Node) -> Dictionary:
	var result: Dictionary = {}
	if not drops_enabled: return result
	var catalog: Dictionary = extension.service.world.get("loot_catalog")
	var by_name: Dictionary = catalog.get("by_name",{})
	for binding: Dictionary in extension.bindings(actor):
		for detail: Dictionary in binding.buff.bonuses:
			if detail.type.get("Name") != "NpcSingleItemDropProbabilityMultiple" or int(detail.bonus.get("BonusApplicationTypeID",0)) != 5 or extension.service.catalog.row("BonusApplicationType",5).get("Name") != "ItemClass": continue
			var item_id: int = int(detail.bonus.BonusApplicationTargetID)
			var name: String = str(item_bindings.get(str(item_id),""))
			if name.is_empty():
				for candidate: String in by_name:
					if int(by_name[candidate].get("source_item_class_id",0)) == item_id:
						if not name.is_empty(): name = ""; break # Ambiguous source variant requires explicit UI choice.
						name = candidate
			if name.is_empty() or not by_name.has(name): continue
			result[name] = maxf(float(result.get(name,0)),float(detail.bonus.Value)/drop_divisor)
	return result

func classify(channel: String, by_spell: bool) -> int:
	# Explicit UI classification, never a damage-channel conversion.
	return special_type if special_type in [42,72] else {"melee":1,"ranged":2,"magic":3}.get(channel,0)

func cancel_host(groups: Array) -> int:
	if host_cancel_mode == 0: return 0
	var world: Node = extension.service.world
	var removed: int = 0
	for name: String in world.active_skill_buffs.keys():
		var buff: Dictionary = world.active_skill_buffs[name]
		if protected_host_buffs.has(name) or (host_cancel_mode == 1 and not selected_host_buffs.has(name)): continue
		if bool(buff.get("IsImmuneToCancellation",false)) or bool(buff.get("immune_to_cancellation",false)) or bool(buff.get("uncancellable",false)): continue
		var source_id: int = int(buff.get("source_buff_class_id",0))
		var source: Dictionary = extension.service.catalog.row("BuffClass",source_id)
		if not source.is_empty() and bool(source.get("IsImmuneToCancellation",false)): continue
		if not groups.is_empty() and (source.is_empty() or not groups.has(source.get("BuffGroupID"))): continue
		# Active summoned entities are not host stat buffs. Do not delete companions.
		if str(buff.get("summon_stage","")) not in ["","shield"]: continue
		var skill: Dictionary = world.original_skills.catalog.record_for(str(buff.get("skill_id","")))
		if str(skill.get("mode","")) == "summon" and str(buff.get("summon_stage","")) != "shield": continue
		if world.original_skills.dispel_active_buff(name): removed += 1
	if removed > 0:
		world.hp = mini(world.hp,world._effective_max_hp())
		world.mp = mini(world.mp,world._effective_max_mp())
		world._refresh_speed_modifiers(); world._refresh_combat_hud()
	last_event = {"kind":"own_host_cancel","removed":removed,"mode":host_cancel_mode,"native_immunity_unknown_for_unmapped":true}
	return removed
