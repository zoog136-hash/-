extends RefCounted
## Explicit TWILIGHT policy for missing contracts. Raw source rows stay intact.
const AREA = preload("res://scripts/monsters/patch523_boss_area.gd")
var _service_ref: WeakRef
var service: RefCounted:
	get: return _service_ref.get_ref() if _service_ref != null else null
	set(value): _service_ref = weakref(value) if value != null else null
var enabled: bool = false
var allow_test_definitions: bool = false
var trigger_on_hit: bool = false
var ground_radius: float = 96
var ground_seconds: float = 3
var ground_box: bool = true
var ground_repeat: bool = true
var ground_stack: bool = false
var cancel_on_interrupt: bool = true
var summon_count: int = 2
var summon_seconds: float = 20
var settings_path: String = "user://patch523_boss_rules.cfg"
var waiting: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var summons: Array[Dictionary] = []
var markers: Array[Node2D] = []
var last_event: Dictionary = {}

func configure(owner: RefCounted) -> void:
	service = owner
	var config := ConfigFile.new()
	if config.load(settings_path) != OK or int(config.get_value("boss","schema",0)) != 1: return
	for key: String in ["enabled","allow_test_definitions","trigger_on_hit","ground_box","ground_repeat","ground_stack","cancel_on_interrupt"]:
		set(key,bool(config.get_value("boss",key,get(key))))
	ground_radius = bounded(config.get_value("boss","ground_radius",96),16,320,96)
	ground_seconds = bounded(config.get_value("boss","ground_seconds",3),.1,30,3)
	summon_count = int(bounded(config.get_value("boss","summon_count",2),1,4,2))
	summon_seconds = bounded(config.get_value("boss","summon_seconds",20),1,120,20)

func bounded(value: Variant, low: float, high: float, fallback: float) -> float:
	if not value is int and not value is float: return fallback
	return clampf(float(value),low,high) if is_finite(float(value)) else fallback

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("boss","schema",1)
	for key: String in ["enabled","allow_test_definitions","trigger_on_hit","ground_box","ground_repeat","ground_stack","cancel_on_interrupt","ground_radius","ground_seconds","summon_count","summon_seconds"]:
		config.set_value("boss",key,get(key))
	return config.save(settings_path)

func handles(spell: Dictionary) -> bool:
	if not enabled: return false
	if bool(spell.get("TestSpell",false)) and not allow_test_definitions: return false
	for key: String in ["MPCost","HPCost","VPCost","SpellMaterialItemAmount"]:
		if int(spell.get(key,0)) != 0: return false
	var id: int = int(spell.get("ID",0))
	if id in [88822,88832]: return allow_test_definitions
	return int(spell.get("SpellCategoryID",0)) == 19 and int(service.catalog.scalar("SpellBonus",id,"NpcSummonSetID","NpcSummonSetID")) in [2053,2063]

func clear() -> void:
	waiting.clear(); zones.clear(); last_event.clear()
	for marker: Node2D in markers:
		if is_instance_valid(marker): marker.queue_free()
	markers.clear()
	for entry: Dictionary in summons:
		retire_summon(entry)
	summons.clear()

func retire_summon(entry: Dictionary) -> void:
	var monster: Node = entry.monster.get_ref()
	if not is_instance_valid(monster): return
	var population: Variant = service.world.get("field_population")
	if is_instance_valid(population): population.retire_summoned(monster)
	else: monster.queue_free()

func forget(actor: Node) -> void:
	var id: int = actor.get_instance_id()
	for queue: Array in [waiting,zones]:
		for entry: Dictionary in queue.duplicate():
			if int(entry.owner_id) == id:
				remove_marker(entry.get("marker")); queue.erase(entry)
	for entry: Dictionary in summons.duplicate():
		if int(entry.owner_id) == id: retire_summon(entry); summons.erase(entry)
	for marker: Node2D in markers.duplicate():
		if is_instance_valid(marker) and int(marker.get_meta("owner_id",0)) == id: remove_marker(marker)

func cancel(actor: Node, sequence: int) -> void:
	if not cancel_on_interrupt: return
	for queue: Array in [waiting,zones]:
		for entry: Dictionary in queue.duplicate():
			if int(entry.owner_id) == actor.get_instance_id() and int(entry.action.sequence) == sequence:
				remove_marker(entry.get("marker")); queue.erase(entry)

func remove_marker(value: Variant) -> void:
	if is_instance_valid(value): value.queue_free(); markers.erase(value)

func valid(entry: Dictionary) -> bool:
	var actor: Node = entry.action.actor.get_ref()
	return service.valid_action(actor,entry.action) and actor._target_attackable() and not bool(actor.get("returning_home"))

func marker_for(actor: Node, point: Vector2, is_warning: bool) -> Node2D:
	var marker = AREA.new()
	marker.radius = ground_radius; marker.box = ground_box; marker.warning = is_warning
	marker.set_meta("owner_id",actor.get_instance_id())
	service.world.add_child(marker); marker.global_position = point; markers.append(marker)
	return marker

func release(actor: Node, spell: Dictionary, action: Dictionary) -> Dictionary:
	var id: int = int(spell.ID)
	var point: Vector2 = action.get("compat_point",service.world.player.global_position)
	var hit: bool = not trigger_on_hit or service.world._roll_monster_hit(actor,"magic")
	if id == 88822:
		if hit and waiting.size() < 8:
			var chain: Dictionary = service.catalog.spell_chain(id)
			for edge: Dictionary in chain.get("next",[]):
				var child: Dictionary = edge.spell.get("source",{})
				if int(child.get("ID",0)) != 88832: continue
				var delay: float = service.catalog.scalar("SpellBonus",id,"NextSpellDelay","MilliSeconds",-1)/1000.0
				if delay < 0 or delay > 60: continue
				waiting.append({"owner_id":actor.get_instance_id(),"action":action.duplicate(),"spell_id":int(child.ID),"remaining":delay,"age":0.0,"point":point,"marker":marker_for(actor,point,true),"source_edge":edge.edge.duplicate(true)})
				last_event = {"phase":"waiting","source_parent_spell":id,"source_next_spell":int(child.ID),"source_delay_seconds":delay,"application_namespace":"SpellClass","application_target_raw":edge.edge.bonus.BonusApplicationTargetID,"host_trigger":"host_hit_roll" if trigger_on_hit else "after_release","native_trigger_verified":false}
	elif id == 88832:
		remove_marker(action.get("compat_warning"))
		if not ground_stack:
			for old: Dictionary in zones.duplicate():
				if int(old.owner_id) == actor.get_instance_id() and int(old.spell.ID) == id:
					remove_marker(old.marker); zones.erase(old)
		if zones.size() < 8:
			var interval: float = service.catalog.scalar("SpellBonus",id,"SpellPlateInterval","MilliSeconds",-1)/1000.0
			var dice: Dictionary = service.damage_spec({"IsSpell":true},spell)
			if interval > 0 and interval <= 60 and not dice.is_empty():
				zones.append({"owner_id":actor.get_instance_id(),"action":action.duplicate(),"spell":spell,"remaining":ground_seconds,"clock":0.0,"interval":interval,"dice":dice,"repeat":ground_repeat,"marker":marker_for(actor,point,false)})
				last_event = {"phase":"ground","source_spell":id,"source_interval":interval,"source_damage":dice,"host_radius_pixels":ground_radius,"host_duration_seconds":ground_seconds,"host_shape":"box" if ground_box else "circle","native_geometry_verified":false}
	elif int(spell.get("SpellCategoryID",0)) == 19:
		spawn_helpers(actor,spell,action)
	return {"hit":hit,"host_compat":true}

func spawn_helpers(actor: Node, spell: Dictionary, action: Dictionary) -> void:
	var population: Variant = service.world.get("field_population")
	if not is_instance_valid(population): return
	var space: int = maxi(0,8-summons.size())
	if space == 0: return
	# Existing field API selects ordinary local actors and marks them no-reward.
	# These are explicit TWILIGHT helpers, never claims about native pearl bodies.
	var spawned: Array = population.summon_for(actor,mini(summon_count,space))
	for monster: Node in spawned:
		monster.set_meta("patch523_source_set_raw",int(service.catalog.scalar("SpellBonus",int(spell.ID),"NpcSummonSetID","NpcSummonSetID")))
		monster.name_label.text = "TWILIGHT 자체 소환 · "+str(monster.monster_name)
		summons.append({"owner_id":actor.get_instance_id(),"action":action.duplicate(),"monster":weakref(monster),"remaining":summon_seconds})
	last_event = {"phase":"summon","source_spell":spell.ID,"source_set_raw":service.catalog.scalar("SpellBonus",int(spell.ID),"NpcSummonSetID","NpcSummonSetID"),"host_count":spawned.size(),"host_lifetime":summon_seconds,"native_membership_verified":false,"rewards":false}

func take_ready(actor: Node) -> Dictionary:
	for entry: Dictionary in waiting:
		if int(entry.owner_id) == actor.get_instance_id() and float(entry.remaining) <= 0 and valid(entry): return entry
	return {}

func tick(delta: float) -> void:
	if not enabled or not service.host_enabled: clear(); return
	delta = maxf(0,delta)
	for entry: Dictionary in waiting.duplicate():
		var actor: Node = entry.action.actor.get_ref()
		entry.age += delta; entry.remaining -= delta
		if not valid(entry) or float(entry.age) > 30 or (cancel_on_interrupt and (actor.is_stunned() or actor.is_feared())):
			remove_marker(entry.marker); waiting.erase(entry)
	for entry: Dictionary in zones.duplicate():
		if not valid(entry): remove_marker(entry.marker); zones.erase(entry); continue
		var active_delta: float = minf(delta,float(entry.remaining))
		entry.remaining -= active_delta; entry.clock += active_delta
		var handled: int = 0
		while float(entry.clock)+.000001 >= float(entry.interval) and handled < 32:
			entry.clock -= entry.interval; handled += 1
			if not zones.has(entry) or not valid(entry): return
			if entry.marker.contains_world(service.world.player.global_position):
				var raw: int = int(entry.dice.base)
				for i: int in int(entry.dice.count): raw += service.world.rng.randi_range(1,int(entry.dice.spots))
				var actor: Node = entry.action.actor.get_ref()
				service.world.resolve_patch523_npc_hit(actor,raw,entry.spell,"magic")
				if not zones.has(entry) or not valid(entry): return
				last_event["last_raw_damage"] = raw
			if not entry.repeat: entry.remaining = 0; break
		if float(entry.remaining) <= 0 and zones.has(entry): remove_marker(entry.marker); zones.erase(entry)
	for entry: Dictionary in summons.duplicate():
		entry.remaining -= delta
		var monster: Node = entry.monster.get_ref()
		if not valid(entry) or float(entry.remaining) <= 0 or not is_instance_valid(monster) or bool(monster.get("dead")):
			retire_summon(entry); summons.erase(entry)
	markers = markers.filter(func(node: Node2D) -> bool: return is_instance_valid(node) and not node.is_queued_for_deletion())
