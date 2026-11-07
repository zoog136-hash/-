extends RefCounted
## Configurable TWILIGHT execution where the source lacks a final server contract.
var _owner: WeakRef
var service: RefCounted:
	get: return _owner.get_ref() if _owner != null else null
var enabled: bool = false
var reverse_healing: bool = false
var poison_interval: float = 1.0
var heal_target: int = 0 # player (original Enemy axis), caster, explicitly selected NPC
var environment_enabled: bool = false
var native_regions: bool = true
var own_attribute: int = 0
var own_map: String = ""
var own_center: Vector2 = Vector2.ZERO
var own_radius: float = 320
var reaction_enabled: bool = false
var reaction_scale: float = 1.0
var settings_path: String = "user://patch523_npc_extensions.cfg"
var active: Dictionary = {}
var last_event: Dictionary = {}
var incoming: Dictionary = {}
var reaction_depth: int = 0
var suppressed: Dictionary = {}
var actor_buffs: Dictionary = {}
var environment_clock: float = 0
var remaining = preload("res://scripts/monsters/patch523_npc_remaining.gd").new()

func configure(owner: RefCounted) -> void:
	_owner = weakref(owner)
	var cfg := ConfigFile.new()
	var loaded: bool = cfg.load(settings_path) == OK and int(cfg.get_value("rules","schema",0)) == 1
	remaining.configure(self,cfg)
	if not loaded: return
	for key: String in ["enabled","reverse_healing","environment_enabled","native_regions","reaction_enabled"]: set(key,bool(cfg.get_value("rules",key,get(key))))
	poison_interval = service.compatibility.bounded(cfg.get_value("rules","poison_interval",1),.1,10,1)
	heal_target = int(service.compatibility.bounded(cfg.get_value("rules","heal_target",0),0,2,0))
	own_attribute = int(cfg.get_value("rules","own_attribute",0)); own_map = str(cfg.get_value("rules","own_map",""))
	var center: Variant = cfg.get_value("rules","own_center",Vector2.ZERO)
	own_center = center if center is Vector2 and center.is_finite() else Vector2.ZERO
	own_radius = service.compatibility.bounded(cfg.get_value("rules","own_radius",320),16,2048,320)
	reaction_scale = service.compatibility.bounded(cfg.get_value("rules","reaction_scale",1),0,10,1)

func save_settings() -> Error:
	var cfg := ConfigFile.new(); cfg.set_value("rules","schema",1)
	for key: String in ["enabled","reverse_healing","poison_interval","heal_target","environment_enabled","native_regions","own_attribute","own_map","own_center","own_radius","reaction_enabled","reaction_scale"]: cfg.set_value("rules",key,get(key))
	remaining.save_into(cfg)
	var temporary: String = settings_path+".tmp"
	var result: Error = cfg.save(temporary)
	if result != OK: return result
	result = DirAccess.rename_absolute(temporary,settings_path)
	if result != OK: DirAccess.remove_absolute(temporary)
	return result

func clear() -> void:
	remaining.clear()
	active.clear(); incoming.clear(); last_event.clear(); suppressed.clear(); actor_buffs.clear(); environment_clock = 0

func heal_spec(spell: Dictionary) -> Dictionary:
	var id: int = int(spell.get("ID",0))
	var base: int = int(service.catalog.scalar("SpellBonus",id,"HPRestoration","Value"))
	var count: int = int(service.catalog.scalar("SpellBonus",id,"HPRestorationDiceNumber","Value"))
	var spots: int = int(service.catalog.scalar("SpellBonus",id,"HPRestorationDiceSpotCount","Value"))
	return {"base":base,"count":count,"spots":spots} if base >= 0 and count >= 0 and count <= 1000 and spots >= 0 and spots <= 1000000 and (count == 0 or spots > 0) and (base > 0 or count > 0) else {}

func handles(spell: Dictionary) -> bool:
	if not enabled or bool(spell.get("TestSpell",false)): return false
	if not flat_cost_supported(spell): return false
	if int(spell.get("SpellCategoryID",0)) == 2 and int(spell.get("TargettingTypeID",0)) == 1 and int(spell.get("TargetKindID",0)) == 2:
		return service.catalog.duration(int(spell.ID)).x > 0 and not service.catalog.values("SpellBonus",int(spell.ID),"BuffClassID","BuffClassID").is_empty()
	if int(spell.get("TargettingTypeID",0)) not in [1,2] or int(spell.get("TargetKindID",0)) != 3: return false
	return int(spell.get("SpellCategoryID",0)) == 3 or (int(spell.get("SpellCategoryID",0)) == 4 and not heal_spec(spell).is_empty())

func release(actor: Node, spell: Dictionary, already_paid: bool = false) -> bool:
	var id: int = int(spell.ID)
	if not already_paid and not can_pay(actor,spell): return false
	var cost: int = int(spell.get("MPCost",0))
	if cost > 0 and not already_paid: actor.mp -= cost # Explicit host policy: once at validated release.
	if int(spell.SpellCategoryID) == 2:
		var key: int = actor.get_instance_id(); var entries: Array = actor_buffs.get(key,[]).filter(func(old: Dictionary) -> bool: return int(old.life) == int(actor.life_id) and int(old.generation) == int(service.world.combat_generation))
		var changed: bool = false
		for value: Variant in service.catalog.values("SpellBonus",id,"BuffClassID","BuffClassID"):
			var source: Dictionary = service.catalog.row("BuffClass",int(value)); var blocked: bool = false
			for old: Dictionary in entries:
				if int(old.id) != int(value) and int(old.source.BuffGroupID) == int(source.BuffGroupID) and not bool(service.catalog.row("BuffGroup",int(source.BuffGroupID)).get("IsAllowOverlap",false)): blocked = true
			if blocked: continue
			entries = entries.filter(func(old: Dictionary) -> bool: return int(old.id) != int(value))
			entries.append({"actor":weakref(actor),"life":actor.life_id,"generation":service.world.combat_generation,"source":source,"id":int(value),"remaining":service.catalog.duration(id).x}); changed = true
		actor_buffs[key] = entries
		last_event = {"kind":"npc_self_buff","spell":id,"applied":changed,"group_policy":"nonoverlap; no invented priority winner"}
		return changed
	if int(spell.SpellCategoryID) == 4:
		var target: Node = service.world.player if heal_target == 0 else actor if heal_target == 1 else service.world.get("selected_monster")
		if not is_instance_valid(target) or (target != service.world.player and (bool(target.get("dead")) or not service.world._has_line_of_sight_world(actor.global_position,target.global_position) or actor.global_position.distance_to(target.global_position) > float(actor.current_attack_range()))): return false
		var dice: Dictionary = heal_spec(spell); var amount: int = int(dice.base)
		for n: int in int(dice.count): amount += service.world.rng.randi_range(1,int(dice.spots))
		var generation: int = int(service.world.combat_generation)
		if target == service.world.player: service.world.apply_patch523_healing(amount,false)
		else:
			amount = target.source_option_healing(amount)
			target.hp = mini(target.max_hp,target.hp+amount); target.hp_bar.value = target.hp
		if generation != int(service.world.combat_generation): return true
		last_event = {"kind":"heal","spell":id,"source_dice":dice,"host_target_mode":heal_target,"amount":amount}
		return true
	if not service.world._roll_monster_hit(actor,"magic"): return false
	var groups: Array = service.catalog.values("SpellBonus",id,"SpellBuffGroup")
	var removed: int = 0
	for buff_id: int in service.player_buffs.keys():
		var source: Dictionary = service.catalog.row("BuffClass",buff_id)
		if bool(source.get("IsImmuneToCancellation",false)): continue
		if (not groups.is_empty() and groups.has(source.get("BuffGroupID"))) or (groups.is_empty() and bool(source.get("IsGood",false))): service.player_buffs.erase(buff_id); removed += 1
	# Equipment source buffs retain their own exact group/immunity checks.
	removed += service.world.equipment523.cancel(service.world,groups)
	removed += remaining.cancel_host(groups)
	removed += cancel_quest_regen(groups)
	var duration: Vector2 = service.catalog.duration(id)
	if duration.x > 0:
		for value: Variant in service.catalog.values("SpellBonus",id,"BuffClassID","BuffClassID"):
			service.apply_player_buff(int(value),duration.x,service.buff_values(int(value)))
	service.sync_restrictions()
	last_event = {"kind":"cancel","spell":id,"removed":removed,"scope":"source-managed buffs only; source group/immunity respected"}
	return true

func cancel_quest_regen(groups: Array)->int:
	return preload("res://scripts/quests/quest_regen523.gd").cancel(service.world,groups)

func can_pay(actor: Node, spell: Dictionary) -> bool:
	var cost: int = int(spell.get("MPCost",0))
	return cost >= 0 and (cost == 0 or (actor.get("mp") is int and int(actor.get("mp")) >= cost))

func can_start(actor: Node, attack: Dictionary) -> bool:
	if service == null or not enabled: return true
	var spell: Dictionary = service.catalog.row("SpellClass",int(attack.get("SpellID",0)))
	return not bool(attack.get("IsSpell",false)) or int(spell.get("MPCost",0)) == 0 or (flat_cost_supported(spell) and can_pay(actor,spell))

func flat_cost_supported(spell: Dictionary) -> bool:
	for key: String in ["HPCost","VPCost","SpellMaterialItemAmount"]:
		if int(spell.get(key,0)) != 0: return false
	var cost: int = int(spell.get("MPCost",0))
	return cost >= 0 and (cost == 0 or (service != null and service.catalog.row("Unit",int(spell.get("MPCostUnit",0))).get("Name") == "Value"))

func healing(amount: int, potion: bool) -> int:
	var raw: float = 0
	for buff: Dictionary in service.player_buffs.values(): raw = maxf(raw,float(buff.values.get("HPPotionDecreasePercent" if potion else "HPHealDecreasePercent",0)))
	var result: int = (maxi(0,amount)*(1000000-int(raw)))/1000000
	return result if enabled and reverse_healing and not potion else maxi(0,result)

func on_player_event(event: String) -> void:
	var fields: Dictionary = {"attacked":"IsEraseOnAttacked","spell_attacked":"IsEraseOnSpellAttacked","attack":"IsEraseOnAttack","cast":"IsEraseOnCast","healed":"IsEraseOnHealed","move":"IsEraseOnMove"}
	if not fields.has(event): return
	for id: int in service.player_buffs.keys():
		if bool(service.catalog.row("BuffClass",id).get(fields[event],false)): service.player_buffs.erase(id)
	service.sync_restrictions()

func tick_player(delta: float) -> void:
	if not enabled: return
	for id: int in service.player_buffs.keys():
		if not service.player_buffs.has(id): continue
		var entry: Dictionary = service.player_buffs[id]
		var count: int = int(entry.values.get("PoisonDamageDiceNumber",0)); var spots: int = int(entry.values.get("PoisonDamageDiceSpotCount",0))
		if count <= 0 or count > 10000 or spots <= 0 or spots > 1000000: continue
		entry["poison_clock"] = float(entry.get("poison_clock",0))+minf(maxf(0,delta),float(entry.remaining))
		var generation: int = int(service.world.combat_generation); var steps: int = 0
		while float(entry.poison_clock)+.0000001 >= poison_interval and steps < 32:
			entry.poison_clock -= poison_interval; steps += 1
			var damage: int = 0
			for n: int in count: damage += service.world.rng.randi_range(1,spots)
			service.world._on_player_poison_tick(damage)
			if int(service.world.combat_generation) != generation or not service.player_buffs.has(id): return

func bind_current(attribute_id: int) -> bool:
	if not is_instance_valid(service.world.get("field_map")): return false
	var found: bool = false
	for entry: Dictionary in service.catalog.content.tables.get("LandAttribute",{}).values():
		if int(entry.row.ID) == attribute_id: found = true
	if not found: return false
	own_attribute = attribute_id; own_map = str(service.world.active_map_id); own_center = service.world.player.global_position
	return true

func actor_invisible(actor: Node) -> bool:
	if service == null or not enabled or not service.host_enabled or not is_instance_valid(actor): return false
	# Only an already applied, live self-spell buff is authoritative here.
	# Environment/NpcAttribute activation and other invisibility variants keep
	# their separate unresolved contracts; no state is produced by this query.
	for value: Variant in actor_buffs.get(actor.get_instance_id(),[]):
		if not value is Dictionary: continue
		var entry: Dictionary = value
		if not entry.get("actor") is WeakRef or entry.actor.get_ref() != actor: continue
		if bool(actor.get("dead")) or int(entry.get("life",-1)) != int(actor.get("life_id")) or int(entry.get("generation",-1)) != int(service.world.combat_generation): continue
		var duration: Variant = entry.get("remaining",0)
		if typeof(duration) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(duration)) or float(duration) <= 0: continue
		var id: int = int(entry.get("id",0))
		var source: Dictionary = service.catalog.row("BuffClass",id)
		if source.is_empty() or entry.get("source") != source: continue
		for detail: Dictionary in service.catalog.bonuses("BuffBonus",id):
			if detail.type.get("Name","") != "Invisible": continue
			if int(detail.type.get("UnitID",-1)) != 20 or int(detail.unit.get("ID",-1)) != 20 or detail.unit.get("Name","") != "TrueFalse": continue
			if int(detail.bonus.get("BonusApplicationTypeID",-1)) != 0 or int(detail.bonus.get("BonusApplicationTargetID",-1)) != 0: continue
			if int(detail.link.get("CharacterLevel",0)) != 0 or int(detail.link.get("CharacterClass",0)) != 0 or int(detail.link.get("MinSpellLevel",0)) != 0: continue
			var flag: Variant = detail.bonus.get("Value")
			if typeof(flag) in [TYPE_INT,TYPE_FLOAT] and float(flag) == 1.0: return true
	return false

func bindings(actor: Node) -> Array:
	var result: Array = []
	if service == null: return result
	if not service.host_enabled or not is_instance_valid(actor) or bool(actor.get("dead")): return result
	if enabled:
		for entry: Dictionary in actor_buffs.get(actor.get_instance_id(),[]):
			if int(entry.life) == int(actor.life_id) and int(entry.generation) == int(service.world.combat_generation): result.append({"attribute":{"ID":0,"Value":entry.id},"buff":service.catalog.buff_details(int(entry.id)),"self_spell":true})
	var field: Variant = service.world.get("field_map")
	if not environment_enabled or field == null: return result
	var definition: Variant = field.get("definition")
	var land_id: int = int(definition.get("source_map_id",-1)) if definition is Dictionary else -1
	var land: Dictionary = service.catalog.row("Land",land_id)
	# AssetPath confirms the Land namespace against the exact current source map.
	var source_field: bool=field.get_meta("current523_source_field",false)==true
	if native_regions and source_field:
		var context: Dictionary=_current_source_region(actor,field,land)
		if not context.is_empty():
			# Read only the catalog's admitted environment set. No SOURCE.rows
			# fallback and no NoBuffGroup/World/Territory-ID substitution.
			for binding: Dictionary in service.catalog.environment_buffs(land_id):
				if _source_environment_contains(binding,context):
					var located: Dictionary=binding.duplicate(true)
					located["source_region_context"]=context.duplicate(true)
					result.append(located)
	elif native_regions and str(land.get("AssetPath","")) == "%d/" % land_id and field.get("coordinates") != null:
		var xy: Array = field.coordinates.source_components(actor.global_position)
		xy = [floori(xy[0]),floori(xy[1])]
		for binding: Dictionary in service.catalog.environment_buffs(land_id):
			var t: Dictionary = binding.territory
			if int(binding.attribute.TerritoryID) == 0 or (int(t.get("LandID",-1)) == land_id and xy[0] >= t.StartX and xy[0] <= t.EndX and xy[1] >= t.StartY and xy[1] <= t.EndY): result.append(binding)
	if own_attribute > 0 and str(service.world.active_map_id) == own_map and actor.global_position.distance_to(own_center) <= own_radius:
		for entry: Dictionary in service.catalog.content.tables.get("LandAttribute",{}).values():
			if int(entry.row.ID) == own_attribute:
				var duplicate: bool = false
				for old: Dictionary in result:
					if int(old.attribute.ID) == own_attribute: duplicate = true
				if not duplicate: result.append({"attribute":entry.row,"buff":service.catalog.buff_details(int(entry.row.Value)),"host_context":true})
	var own_extra: Dictionary = remaining.own_binding(actor)
	if not own_extra.is_empty():
		var exists: bool = false
		for prior: Dictionary in result:
			if int(prior.attribute.Value) == int(own_extra.attribute.Value): exists = true
		if not exists: result.append(own_extra)
	var suppression: Dictionary = suppressed.get(actor.get_instance_id(),{})
	var excluded: Dictionary = suppression.get("ids",{}) if int(suppression.get("life",-1)) == int(actor.life_id) and int(suppression.get("generation",-1)) == int(service.world.combat_generation) else {}
	return result.filter(func(binding: Dictionary) -> bool: return not excluded.has(int(binding.attribute.ID)))

func dismiss(actor: Node) -> bool:
	if not is_instance_valid(actor): return false
	var ids: Dictionary = {}
	for binding: Dictionary in bindings(actor):
		if not bool(binding.buff.source.get("IsImmuneToCancellation",false)): ids[int(binding.attribute.ID)] = true
	if ids.is_empty(): return false
	suppressed[actor.get_instance_id()] = {"ids":ids,"life":actor.life_id,"generation":service.world.combat_generation}
	return true

func actor_values(actor: Node) -> Dictionary:
	var values: Dictionary = {}
	for binding: Dictionary in bindings(actor):
		if bool(binding.get("drop_profile",false)): continue
		for name: String in ["MeleeDamage","RangeDamage","MagicDamage","ArmorClass","MagicResist","DamageReduction","HPPlus","Strength","Dexterity","AddtionalExperience"]:
			values[name] = float(values.get(name,0))+service.catalog.scalar("BuffBonus",int(binding.attribute.Value),name,"Value")
		values["MoveSpeedBonus"] = float(values.get("MoveSpeedBonus",0))+service.catalog.scalar("BuffBonus",int(binding.attribute.Value),"MoveSpeedBonus","Percentage")
	return values

func outgoing(actor: Node, amount: int, channel: String) -> int:
	return amount+int(actor_values(actor).get({"melee":"MeleeDamage","ranged":"RangeDamage","magic":"MagicDamage"}.get(channel,"MeleeDamage"),0))+remaining.attribute_damage(actor,channel)

func begin_incoming(actor: Node, amount: int, channel: String, by_spell: bool) -> Dictionary:
	var packet: Dictionary = {"actor":weakref(actor),"channel":channel,"by_spell":by_spell,"amount":amount,"source_attack_type":remaining.classify(channel,by_spell)}
	incoming[actor.get_instance_id()] = packet
	return packet

func before_damage(actor: Node, amount: int, kind: String) -> int:
	if service == null or not service.host_enabled: return amount
	var matching: Array = bindings(actor)
	active[actor.get_instance_id()] = {"actor":weakref(actor),"bindings":matching}
	var packet: Dictionary = incoming.get(actor.get_instance_id(),{})
	incoming.erase(actor.get_instance_id())
	var reduced: int = maxi(0,amount-int(actor_values(actor).get("DamageReduction",0)))
	if not reaction_enabled or packet.is_empty() or reaction_depth > 0 or amount <= 0: return reduced
	for binding: Dictionary in matching:
		if bool(binding.get("drop_profile",false)): continue
		for invoke: Dictionary in binding.buff.invokes:
			var r: Dictionary = invoke.source
			var attack_type: String = str(service.catalog.row("AttackType",int(r.get("AttackTypeID",0))).get("Name",""))
			if int(r.get("AttackTypeID",0)) != int(packet.get("source_attack_type",0)) or bool(r.get("BySpellAttack",false)) != bool(packet.by_spell) or int(r.get("InvokeOptionTypeID",0)) != 11: continue
			if int(r.get("MaterialAmount",0)) != 0 or int(r.get("SuccessedInvokeOptionID",0)) != 0: continue
			var chance: float = clampf(float(invoke.edge.bonus.Value)/1000000.0,0,1)
			if service.world.rng.randf() >= chance: continue
			# Formula order/rounding is explicitly host policy, raw parameters retained.
			reduced = maxi(0,int(float(reduced)*(1.0-clampf(float(r.Param2)/1000000.0,0,1))))
			var reflection: int = maxi(0,int(float(amount)*float(r.Param1)/1000000.0*reaction_scale))
			var generation: int = int(service.world.combat_generation)
			reaction_depth += 1
			if reflection > 0: service.world.apply_patch523_secondary_damage(reflection,"카운터 반사")
			reaction_depth -= 1
			if generation != int(service.world.combat_generation): return 0
			last_event = {"kind":"environment_counter","attribute":binding.attribute.ID,"invoke":r.ID,"by_spell":packet.by_spell,"channel":packet.channel,"reflected":reflection,"remaining_damage":reduced,"formula_origin":"TWILIGHT configurable interpretation"}
			return reduced # one exact branch, never sum the ten alternatives
	return reduced

func tick_environment(delta: float = .25) -> void:
	for key: int in actor_buffs.keys():
		var remaining: Array = []
		for entry: Dictionary in actor_buffs[key]:
			entry.remaining -= maxf(0,delta)
			var actor: Node = entry.actor.get_ref()
			if enabled and service.host_enabled and is_instance_valid(actor) and not bool(actor.dead) and actor.life_id == int(entry.life) and service.world.combat_generation == int(entry.generation) and float(entry.remaining) > 0: remaining.append(entry)
		if remaining.is_empty(): actor_buffs.erase(key)
		else: actor_buffs[key] = remaining
	environment_clock -= maxf(0,delta)
	if environment_clock > 0: return
	environment_clock = .25
	active.clear()
	if not environment_enabled or not service.host_enabled: return
	var root: Variant = service.world.get("monsters_root")
	if not is_instance_valid(root): return
	for actor: Node in root.get_children():
		if actor.get("dead") == null or bool(actor.get("dead")): continue
		if suppressed.has(actor.get_instance_id()):
			var state: Dictionary = suppressed[actor.get_instance_id()]
			var held: Dictionary = state.ids if int(state.life) == int(actor.life_id) and int(state.generation) == int(service.world.combat_generation) else {}
			suppressed.erase(actor.get_instance_id())
			var still_inside: Array = bindings(actor)
			var remaining: Dictionary = {}
			for binding: Dictionary in still_inside:
				if held.has(int(binding.attribute.ID)): remaining[int(binding.attribute.ID)] = true
			if not remaining.is_empty(): suppressed[actor.get_instance_id()] = {"ids":remaining,"life":actor.life_id,"generation":service.world.combat_generation}
		var found: Array = bindings(actor)
		if not found.is_empty(): active[actor.get_instance_id()] = {"actor":weakref(actor),"bindings":found}

func _current_source_region(actor: Node, field: Object, land: Dictionary) -> Dictionary:
	if field.get_meta("current523_generic_field",false)!=true or not field.has_method("source_region_context") or land.is_empty():return {}
	if service.catalog.source_mode!="current523_original" or not service.catalog.source_available or service.catalog.source_identity.get("source_sha256")!=service.catalog.SOURCE_SHA:return {}
	if service.catalog.content.get("input_kind")!="twilight.current523.npc-input.v1" or service.catalog.content.get("source_archive_sha256")!=service.catalog.SOURCE_SHA:return {}
	# Only the actual current population's living M actor supplies this point.
	# Never project the player, a paused previous root or target-map coordinates.
	if not actor is TwilightMonster or actor.source_m_original.is_empty() or actor.get_parent()!=service.world.monsters_root or not actor.is_inside_tree() or actor.is_queued_for_deletion():return {}
	var admitted: Dictionary=service.catalog.admitted_source_identities.get(str(actor.source_m_npc_id),{})
	if admitted.get("source_archive_sha256")!=service.catalog.SOURCE_SHA or admitted.get("npc_class_id")!=actor.source_m_original.get("ID"):return {}
	if admitted.get("sprite")!=actor.source_m_original.get("Sprite") or admitted.get("desc_id")!=actor.source_m_original.get("DescId"):return {}
	var population: Variant=service.world.get("field_population")
	if not population is Object or population.get("field")!=field:return {}
	var context: Variant=field.call("source_region_context",actor.global_position,land)
	if not context is Dictionary or context.get("schema")!=1 or context.get("source_snapshot")!=523 or context.get("land")!=land or context.get("land_id")!=land.get("ID") or context.get("asset_path")!=land.get("AssetPath") or context.get("field_instance")!=field.get_instance_id():return {}
	return context

static func _source_region_integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and float(value)>=0 and float(value)<=2147483647

func _source_environment_contains(binding: Dictionary, context: Dictionary) -> bool:
	var attribute: Variant=binding.get("attribute")
	var buff: Variant=binding.get("buff")
	if not attribute is Dictionary or not buff is Dictionary:return false
	var type: Dictionary=service.catalog.row("LandAttributeType",504)
	var unit: Dictionary=service.catalog.row("Unit",16)
	if type.get("Name")!="NpcBuff" or type.get("UnitID")!=16 or unit.get("Name")!="BuffClassID" or attribute.get("LandAttributeTypeID")!=504 or attribute.get("LandID")!=context.land_id:return false
	if not _source_region_integer(attribute.get("ID")) or not _source_region_integer(attribute.get("Value")) or attribute.Value==0 or not buff.get("source") is Dictionary or buff.source.get("ID")!=attribute.Value:return false
	for key: String in ["Param1","Param2","Param3"]:
		if not _source_region_integer(attribute.get(key)) or attribute[key]!=0:return false
	var id: Variant=attribute.get("TerritoryID")
	if not _source_region_integer(id):return false
	if id==0:return true
	var territory: Variant=binding.get("territory")
	if not territory is Dictionary or territory.get("ID")!=id or territory.get("LandID")!=context.land_id:return false
	for key: String in ["StartX","StartY","EndX","EndY"]:
		if not _source_region_integer(territory.get(key)):return false
	if territory.StartX>territory.EndX or territory.StartY>territory.EndY:return false
	var xy: Array=context.source_cell
	return xy[0]>=territory.StartX and xy[0]<=territory.EndX and xy[1]>=territory.StartY and xy[1]<=territory.EndY
