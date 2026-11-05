extends SceneTree
## Actual Main consumers with explicit ownership and source-slot fixtures.
## Missing catalog registrations are supplied ONLY inside this test. This proves
## neither normal acquisition nor production catalog coverage/original artwork.
const QA = preload("res://tests/qa_class_selection.gd")
const C = preload("res://scripts/equipment523/common.gd")
const Sets = preload("res://scripts/equipment523/set_effects.gd")
const PROOF: String = "user://equipment523-set-host-proof.json"
const SLOT: Dictionary = {1:"helmet",2:"body",4:"cloak",6:"boots",7:"gloves",9:"ring",10:"necklace",11:"belt",152:"bracelet"}
var checks: int = 0
var failures: Array = []
var source_sets: Array = []
var blocked_sets: Array = []
var active_effect_rows: int = 0
var fixture_items: Dictionary = {}
var fixture_serial: int = 0
var durable_guard: Dictionary = {}
var cancel_catalog_cache: RefCounted

func _initialize() -> void:
	call_deferred("_reload_proof" if "--equipment523-set-reload-proof" in OS.get_cmdline_user_args() else "_run")

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_SET_HOST_FAIL ",label)

func _freeze(world: Node) -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -100000.0
	# Headless ordinarily writes immediately on unequip. Freeze that unrelated
	# background path so only this test's explicit atomic save defines the proof.
	world.deferred_save_enabled = true
	world.deferred_save.cancel()
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED
	for population: Variant in [world.field_population,world.legacy_population,world.original_population]:
		if is_instance_valid(population):
			population.set_process(false)
			population.set_physics_process(false)

func _run() -> void:
	_check(not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(),"explicit verified source map pack")
	var scene: PackedScene = load("res://Main.tscn")
	_check(scene != null,"actual Main loads")
	if scene == null:
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	_check(QA.enter_game(world),"actual Main class confirmation")
	_freeze(world)
	var service = world.equipment523
	var args: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		for key: String in ["rules","sha256","effects","effects-sha256"]:
			var prefix: String = "--equipment523-"+key+"="
			if arg.begins_with(prefix): args[key] = arg.trim_prefix(prefix)
	_check(args.size() == 4,"explicit base and effect installation inputs")
	if args.size() == 4:
		_check(bool(service.install(world,str(args.rules),str(args.sha256)).get("ok",false)),"base cache installs through production service")
		_check(bool(service.install(world,str(args.effects),str(args["effects-sha256"])).get("ok",false)),"typed addon installs through production service")
	var pack: Dictionary = service.store.pack
	_check(not pack.is_empty() and not pack.get("equipment523_effect_audit",{}).is_empty(),"verified base and typed effect extension load")
	if pack.is_empty() or pack.get("equipment523_effect_audit",{}).is_empty():
		world.queue_free()
		await process_frame
		_finish()
		return
	var contracts: Array = Sets.contracts(pack)
	_synthetic_all_element_consumer(world)
	_check(contracts.size() == 22,"all original twenty-two special rows have typed contracts")
	var ids: Dictionary = {}
	for effect: Dictionary in contracts:
		_check(bool(effect.get("ok",false)),"typed original contract " + str(effect.get("bonus_id",effect.get("error","unknown"))))
		ids[int(effect.get("set_id",0))] = true
	_check(ids.size() == 12,"all twelve source special sets accounted for")
	for set_id: int in ids:
		var definition: Dictionary = C.find(pack,"ItemSet",set_id)
		var members: Array = _members(pack,set_id)
		var eligibility: Dictionary = _eligibility(pack,set_id,members,contracts)
		if bool(eligibility.enabled): _check(not members.is_empty(),"source-compatible physical members " + str(set_id))
		_clear_equipped(world)
		var worn: Array = _equip(world,members)
		var resolved: Dictionary = Sets.resolve(pack,service._equipped(world),service.policy)
		print("EQUIPMENT523_SET_HOST_ELIGIBILITY ",JSON.stringify({"set_id":set_id,"eligibility":eligibility,"equipment":_equipment_diagnostic(world)}))
		if not bool(eligibility.enabled):
			blocked_sets.append({"set_id":set_id,"eligibility":eligibility})
			_check(not resolved.set_ids.has(set_id),"source-gated set remains inactive " + str(set_id))
			if int(eligibility.compatible_non_test_members) == 0:
				_check(service._equipped(world).is_empty(),"source test members cannot become authoritative equipped targets " + str(set_id))
			continue
		_check(worn.size() == members.size() and resolved.set_ids.has(set_id),"actual equip path activates distinct source members " + str(set_id))
		source_sets.append(set_id)
		for effect: Dictionary in contracts:
			if int(effect.get("set_id",0)) != set_id: continue
			active_effect_rows += 1
			if effect.get("kind","") == "stat":
				for key: String in effect.record:
					_check(float(world._equipped_numeric_sum(key)) >= float(effect.record[key]),"actual record consumer " + str(effect.bonus_id) + ":" + key)
		if set_id == 61:
			_check(world._player_element_resistance("fire") >= 10,"all-element resistance reaches actual incoming channel")
		elif set_id in [10132,10142,10202,10232,10281,10344]:
			var factor: float = world._skill_cooldown_factor()
			var last: String = str(worn.back())
			world._unequip_item_reference(str(world.item_instances[last].name)+"@@@"+last)
			_check(world._skill_cooldown_factor() > factor,"actual cast cooldown loses set bonus on unequip " + str(set_id))
			if set_id == 10142:
				_clear_equipped(world)
				_equip(world,[members[0],members[0]])
				_check(not Sets.resolve(pack,service._equipped(world),service.policy).set_ids.has(set_id),"two physical copies of one source ring do not complete a set")
		elif set_id == 10373: _reveal(world)
		elif set_id == 10401:
			service.tick(world,0)
			_check(service.set_effects.markers.is_empty(),"no source siege evidence means no shell aura in ordinary map")
		elif set_id == 10363: _yahi(world)
		_clear_equipped(world)
		_check(Sets.resolve(pack,service._equipped(world),service.policy).set_ids.is_empty(),"all effects release after actual unequip " + str(set_id))
	_guard(world)
	_check(source_sets.size() == 9 and blocked_sets.size() == 3,"nine reachable source sets exercised and three source-gated sets remain inactive")
	_check(active_effect_rows == 19 and contracts.size()-active_effect_rows == 3,"nineteen reachable special rows and three source-gated contracts remain distinct")
	world.queue_free()
	await process_frame
	world = scene.instantiate()
	root.add_child(world)
	await process_frame
	_check(QA.enter_game(world),"fresh actual Main confirms restored character")
	_freeze(world)
	var restored: Dictionary = world.equipment523.export_state(world)
	_check(not durable_guard.is_empty() and int(restored.get("guard",{}).get("hits",0)) == int(durable_guard.get("guard",{}).get("hits",-1)),"fresh actual Main restores spent source guard count")
	_check(_same_clocks(restored.get("cooldowns",{}),durable_guard.get("cooldowns",{})),"fresh actual Main restores reuse clock without a new grant")
	var proof: Dictionary = {"base_sha256":world.equipment523.store.sha256,"effects_sha256":world.equipment523.store.effects_sha256,"state":durable_guard,"save_path":world.save_path(),"save_sha256":FileAccess.get_sha256(world.save_path()),"fixture_items":fixture_items,"source_sets":source_sets,"blocked_sets":blocked_sets,"active_effect_rows":active_effect_rows}
	var file: FileAccess = FileAccess.open(PROOF,FileAccess.WRITE)
	_check(file != null,"separate-process guard proof opens")
	if file != null:
		file.store_string(JSON.stringify(proof))
		file.flush()
		_check(file.get_error() == OK,"separate-process guard proof persists")
		file.close()
	world.queue_free()
	await process_frame
	_finish()

func _same_clocks(actual: Dictionary, expected: Dictionary) -> bool:
	if actual.size() != expected.size(): return false
	for key: String in expected:
		if not actual.has(key) or float(actual[key]) > float(expected[key]) or float(expected[key])-float(actual[key]) > 0.25: return false
	return true

func _reload_proof() -> void:
	for arg: String in OS.get_cmdline_user_args():
		_check(not arg.begins_with("--equipment523-rules=") and not arg.begins_with("--equipment523-sha256=") and not arg.begins_with("--equipment523-effects=") and not arg.begins_with("--equipment523-effects-sha256="),"fresh process has no mechanics CLI override")
	_check(FileAccess.file_exists(PROOF),"first-process source guard proof exists")
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROOF)) if FileAccess.file_exists(PROOF) else null
	if not proof is Dictionary:
		_check(false,"first-process proof parses")
		_finish()
		return
	var scene: PackedScene = load("res://Main.tscn")
	_check(scene != null,"fresh process loads actual Main")
	if scene == null:
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	_check(QA.enter_game(world),"fresh process confirms saved character")
	_freeze(world)
	_check(world.equipment523.store.sha256 == proof.get("base_sha256") and world.equipment523.store.effects_sha256 == proof.get("effects_sha256"),"fresh process restores installed base and addon pointers")
	_check(not world.equipment523.store.pack.get("equipment523_effect_audit",{}).is_empty(),"fresh process restores merged typed source graph")
	var state: Dictionary = world.equipment523.export_state(world)
	_check(int(state.get("guard",{}).get("hits",0)) == int(proof.get("state",{}).get("guard",{}).get("hits",-1)),"fresh process preserves spent source guard hit count")
	_check(_same_clocks(state.get("cooldowns",{}),proof.get("state",{}).get("cooldowns",{})),"fresh process preserves guard reuse clock")
	_check(FileAccess.get_sha256(str(proof.get("save_path",""))) == proof.get("save_sha256"),"fresh process preserves exact durable save bytes")
	fixture_items = proof.get("fixture_items",{})
	source_sets = proof.get("source_sets",[])
	blocked_sets = proof.get("blocked_sets",[])
	active_effect_rows = int(proof.get("active_effect_rows",0))
	world.queue_free()
	await process_frame
	_finish("FRESH_PROCESS_INSTALLED_SOURCE_SET_CACHE_AND_GUARD_SAVE")

func _members(pack: Dictionary, set_id: int) -> Array:
	var members: Array = []
	var used: Dictionary = {}
	for link: Dictionary in C.rows(pack,"ItemForItemSet"):
		if int(link.get("ItemSetID",0)) != set_id: continue
		var source: int = int(link.get("ItemClassID",0))
		for row: Dictionary in C.rows(pack,"ItemEquipSlot"):
			if int(row.get("ItemClassID",0)) != source or not SLOT.has(int(row.get("EquipSlotID",0))): continue
			var slot: String = str(SLOT[int(row.EquipSlotID)])
			var limit: int = 2 if slot == "ring" else 1
			if int(used.get(slot,0)) >= limit: continue
			used[slot] = int(used.get(slot,0))+1
			members.append({"source_id":source,"slot":slot})
			break
	return members

func _eligibility(pack: Dictionary, set_id: int, members: Array, contracts: Array) -> Dictionary:
	var definition: Dictionary = C.find(pack,"ItemSet",set_id)
	var original: Array = []
	var test_items: Array = []
	for row: Dictionary in C.rows(pack,"ItemForItemSet"):
		if int(row.get("ItemSetID",0)) != set_id: continue
		var id: int = int(row.get("ItemClassID",0))
		original.append(id)
		if bool(C.item(pack,id).get("raw",{}).get("TestItem",false)): test_items.append(id)
	var compatible: int = 0
	for member: Dictionary in members:
		if not bool(C.item(pack,int(member.source_id)).get("raw",{}).get("TestItem",false)): compatible += 1
	var required: int = 0
	for effect: Dictionary in contracts:
		if int(effect.get("set_id",0)) == set_id: required = maxi(required,int(effect.get("link",{}).get("CompletionDegree",0)))
	var definition_test: bool = bool(definition.get("IsTest",false)) or str(definition.get("Name","")).contains("[테스트]")
	return {"enabled":not definition_test and compatible >= required and required > 0,"definition_test":definition_test,"source_members":original,"source_test_members":test_items,"compatible_members":members.size(),"compatible_non_test_members":compatible,"required_completion":required}

func _equipment_diagnostic(world: Node) -> Array:
	var result: Array = []
	for slot: String in world.equipped_items:
		var worn: Dictionary = world.equipped_items[slot]
		var id: String = str(worn.get("instance_id",""))
		var physical: Dictionary = world.item_instances.get(id,{})
		var record: Dictionary = physical.get("record",{})
		var source: int = int(record.get("source_item_class_id",0))
		result.append({"slot":slot,"instance_id":id,"name":physical.get("name",""),"source_id":source,"worn_source_id":worn.get("source_item_class_id",0),"source_identity":world.equipment523._source(record),"source_test_item":C.item(world.equipment523.store.pack,source).get("raw",{}).get("TestItem",false),"quantity":world.equipment523._quantity(physical),"inventory_quantity":world.inventory.get(str(physical.get("name","")),0),"host_slot":record.get("slot",""),"class_restriction":record.get("AbleClass",record.get("class",""))})
	return result

func _equip(world: Node, members: Array) -> Array:
	var worn: Array = []
	for member: Dictionary in members:
		var source: int = int(member.source_id)
		var item: Dictionary = C.item(world.equipment523.store.pack,source)
		var source_test: bool = bool(item.get("raw",{}).get("TestItem",false))
		var fixture_scope: String = "TestSourceCondition" if source_test else "ExplicitSourceOwnership"
		var record: Dictionary = {"name":str(item.get("name",item.get("raw",{}).get("Name",""))),"sourceId":"m523:item:"+str(source),"source_item_class_id":source,"slot":str(member.slot),"weight":0,"equipment523_test_ownership_fixture":true,"equipment523_fixture_scope":fixture_scope}
		fixture_serial += 1
		var id: String = "set-host-fixture-" + str(fixture_serial)
		fixture_items[source] = {"unregistered_catalog_fixture":true,"source_slot":str(member.slot),"source_test_item":source_test,"scope":fixture_scope}
		world.inventory[record.name] = int(world.inventory.get(record.name,0))+1
		world.item_instances[id] = {"name":record.name,"record":record.duplicate(true),"level":0,"element":"","element_level":0,"source_bless_code":1}
		# Source identity and source slot are exact; fixture has no invented stats.
		world._equip_or_acquire_item(record,false,id)
		if world._is_instance_equipped(id): worn.append(id)
	world._invalidate_equipment_static()
	return worn

func _clear_equipped(world: Node) -> void:
	var references: Array = []
	for worn: Dictionary in world.equipped_items.values():
		var id: String = str(worn.get("instance_id",""))
		if not id.is_empty(): references.append(str(worn.get("name",""))+"@@@"+id)
	for reference: String in references: world._unequip_item_reference(reference)
	world._invalidate_equipment_static()
	world.equipment523.tick(world,0)

func _victim(world: Node) -> Node:
	for target: Node in world.monsters_root.get_children():
		if target is TwilightMonster and not target.dead:
			target.hp = 100000
			target.max_hp = 100000
			target.mp = 100
			target.global_position = world.player.global_position + Vector2(20,0)
			return target
	return null

func _reveal(world: Node) -> void:
	_check(world.equipment523_can_reveal("invisibility") and world.equipment523_can_reveal("camouflage") and world.equipment523_can_reveal("doppel"),"actual Main reveals all three source flags")
	var target: Node = _victim(world)
	_check(target != null,"actual monster available for reveal checks")
	if target == null: return
	target.set_meta("source_invisible",true)
	target.set_meta("source_camouflaged",true)
	_check(world.equipment523_can_detect(target),"actual target query detects equipped source invisibility and camouflage")
	target.remove_meta("source_invisible")
	target.remove_meta("source_camouflaged")

func _yahi(world: Node) -> void:
	var service = world.equipment523
	var target: Node = _victim(world)
	_check(target != null,"actual monster available for Yahi chain")
	if target == null: return
	var hp_before: int = int(target.hp)
	var mp_before: int = int(target.mp)
	world.hp = maxi(1,world._effective_max_hp()-20)
	world.mp = maxi(0,world._effective_max_mp()-20)
	var player_hp: int = world.hp
	var player_mp: int = world.mp
	service.on_hit(world,target,"melee",true,false)
	_check(int(target.hp) == hp_before-1 and int(target.mp) == mp_before-1 and world.hp == player_hp+1 and world.mp == player_mp+1,"actual Main source drains transfer current resources")
	_check(service.locked_target(world) == null,"strict original PC-only Yahi ignores ordinary monster")
	target.set_meta("is_player_combatant",true)
	target.set_meta("source_invisible",true)
	service.on_hit(world,target,"melee",true,false)
	_check(service.locked_target(world) == null,"original Yahi CanCastOnInvisible false survives PC selection")
	target.remove_meta("source_invisible")
	service.on_hit(world,target,"melee",true,false)
	_check(service.locked_target(world) == target and world._equipment523_locked_target() == target,"Yahi chain reaches actual Main fixed target query")
	var explosion_requested: bool = false
	for visual: Dictionary in service.set_visual_results:
		if int(visual.get("spell_id",0)) == 78898 and visual.get("field") == "EffectExplosionSpriteID" and int(visual.get("sprite_id",0)) == 24726: explosion_requested = true
	_check(explosion_requested,"actual Yahi source explosion reaches the existing 523 renderer without an invented replacement")
	_check(world.original_skills.status.modifier(target,"reduction") == -10,"Yahi typed stack reaches actual status damage-reduction consumer")
	_cancel_yahi_source(world,target)
	var saved: Dictionary = service.export_state(world)
	_check(Sets.validate_state(JSON.parse_string(JSON.stringify(saved))).is_empty(),"actual service exports JSON-safe source state")
	service.tick(world,8)
	_check(service.locked_target(world) == null and world.original_skills.status.modifier(target,"reduction") == 0,"actual service tick removes expired Yahi lock and owned debuff")
	target.remove_meta("is_player_combatant")

func _guard(world: Node) -> void:
	var service = world.equipment523
	var members: Array = _members(service.store.pack,10604)
	_check(members.size() == 4,"four different source guard equipment slots")
	_clear_equipped(world)
	for stage: int in range(1,5):
		_clear_equipped(world)
		service.set_effects.clear()
		var base_fear: int = int(world._fear_accuracy_stat())
		_equip(world,members.slice(0,stage))
		var expected_fear: int = 15 if stage == 4 else 7 if stage >= 2 else 0
		_check(int(world._fear_accuracy_stat())-base_fear == expected_fear,"actual fear accuracy preserves source stage delta " + str(stage))
		world.hp = maxi(1,int(ceil(world._effective_max_hp()*0.21)))
		service.tick(world,0)
		service.incoming(world,"melee",false,true,false)
		_check(service.set_effects.guard.is_empty(),"HP above source interval cannot trigger stage " + str(stage))
		world.hp = maxi(1,int(floor(world._effective_max_hp()*0.2)))
		service.tick(world,0)
		_check(service.set_effects.guard.is_empty(),"HP tick cannot trigger a defensive spell without an attack stage " + str(stage))
		_check(not service.incoming(world,"melee",false,false) and service.set_effects.guard.is_empty(),"PC-only source trigger excludes NPC stage " + str(stage))
		_check(not service.incoming(world,"melee",true,true) and service.set_effects.guard.is_empty(),"BySpellAttack false does not trigger from a skill stage " + str(stage))
		_check(not service.incoming(world,"melee",false,true,false),"miss remains a miss when Param4 triggers stage " + str(stage))
		_check(int(service.set_effects.guard.get("hits",0)) == stage*15,"actual source guard stage " + str(stage))
		_check(not service.incoming(world,"melee",false,false),"source guard rejects NPC hit stage " + str(stage))
		_check(not service.incoming(world,"magic",true,true),"source guard rejects magical hit stage " + str(stage))
		_check(service.incoming(world,"melee",false,true),"source guard blocks actual PC physical context stage " + str(stage))
	_cancel_source_npc(world)
	var creation_seen: bool = false
	var removal_seen: bool = false
	for event: Dictionary in service.set_visual_results:
		if event.kind == "guard_created" and int(event.sprite_id) == 29085 and event.action == 1: creation_seen = true
		if event.kind == "guard_removed" and int(event.sprite_id) == 29090 and event.action == null: removal_seen = true
	_check(creation_seen and removal_seen,"actual service forwards exact source guard creation action and action-unspecified removal to existing renderer")
	var saved: Dictionary = service.export_state(world)
	var before: Dictionary = saved.duplicate(true)
	_check(world._save_game(true) == OK,"actual source guard clocks save through atomic production writer")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	_check(disk is Dictionary and disk.has("equipment523_set_effects"),"production durable save contains guard state")
	if disk is Dictionary: durable_guard = disk.get("equipment523_set_effects",{}).duplicate(true)
	service.after_load(world,JSON.parse_string(JSON.stringify(saved)))
	_check(service.export_state(world).guard.hits == before.guard.hits,"service reload preserves spent guard hit count")
	var clock: float = float(service.export_state(world).cooldowns.values()[0])
	_clear_equipped(world)

	_equip(world,members)
	world.hp = maxi(1,int(floor(world._effective_max_hp()*0.2)))
	service.tick(world,0)
	_check(service.set_effects.guard.is_empty() and float(service.export_state(world).cooldowns.values()[0]) == clock,"real unequip and reequip cannot reset guard cooldown")
	service.tick(world,clock)
	_check(service.set_effects.guard.is_empty(),"elapsed cooldown waits for another defensive invoke event")
	service.incoming(world,"melee",false,true,false)
	_check(not service.set_effects.guard.is_empty(),"guard reactivates after the remaining source-policy clock")
	service.on_death(world)
	_check(service.set_effects.guard.is_empty() and not service.export_state(world).cooldowns.is_empty(),"death clears active guard while preserving reuse state")
	_clear_equipped(world)

func _source_cancel_catalog() -> RefCounted:
	if cancel_catalog_cache != null: return cancel_catalog_cache
	var directory: String = OS.get_environment("EQUIPMENT523_SOURCE_CONTENT")
	_check(not directory.is_empty(),"explicit private source directory for NPC cancellation fixture")
	if directory.is_empty(): return null
	var catalog = preload("res://scripts/monsters/patch523_npc_catalog.gd").new()
	catalog.content = {"tables":{}}
	var wanted: Dictionary = {"SpellClass":{1093:true,44223:true},"SpellBonus":{},"Bonus":{},"BonusType":{},"Unit":{}}
	var spell_index: Dictionary = {}
	for name: String in ["SpellClass","SpellBonus","Bonus","BonusType","Unit"]:
		var path: String = directory.path_join(name+".json")
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(path).trim_prefix("\ufeff"))
		_check(source is Dictionary and source.get("rows") is Array,"source cancellation table " + name)
		if not source is Dictionary or not source.get("rows") is Array: return null
		var selected: Dictionary = {}
		var number: int = 0
		for row: Dictionary in source.rows:
			number += 1
			var keep: bool = wanted.SpellClass.has(int(row.get("SpellClassID",0))) if name == "SpellBonus" else wanted[name].has(int(row.get("ID",0)))
			if not keep: continue
			selected[str(int(row.ID))] = {"row":row,"source_row_1based":number}
			if name == "SpellBonus":
				wanted.Bonus[int(row.BonusID)] = true
				var owner: String = str(int(row.SpellClassID))
				if not spell_index.has(owner): spell_index[owner] = []
				spell_index[owner].append(row)
			elif name == "Bonus": wanted.BonusType[int(row.BonusTypeID)] = true
			elif name == "BonusType": wanted.Unit[int(row.UnitID)] = true
		catalog.content.tables[name] = selected
	catalog.indexes = {"SpellBonus":spell_index}
	cancel_catalog_cache = catalog
	return catalog

func _cancel_yahi_source(world: Node, actor: Node) -> void:
	var catalog: RefCounted = _source_cancel_catalog()
	if catalog == null: return
	var npc = world.patch523_npc_spells
	var original_catalog: RefCounted = npc.catalog
	var old_mode: int = int(npc.extensions.remaining.host_cancel_mode)
	var original_buffs: Dictionary = npc.player_buffs.duplicate(true)
	npc.catalog = catalog
	npc.player_buffs.clear()
	npc.extensions.remaining.host_cancel_mode = 0
	_check(_release_cancel(world,catalog.row("SpellClass",1093),actor),"actual NPC mass cancellation executes against equipped Yahi owner")
	_check(world.equipment523.locked_target(world) == actor and world.original_skills.status.modifier(actor,"reduction") == -10,"source NPC cancellation preserves immune Yahi target and self buffs")
	npc.catalog = original_catalog
	npc.player_buffs = original_buffs
	npc.extensions.remaining.host_cancel_mode = old_mode

func _release_cancel(world: Node, spell: Dictionary, actor: Node) -> bool:
	# Keep the real host hit roll; choose a deterministic fixture seed which
	# reaches release. Source chances and source spell rows are never rewritten.
	for seed: int in range(1,64):
		world.rng.seed = seed
		if world.patch523_npc_spells.extensions.release(actor,spell,true): return true
	return false

func _cancel_source_npc(world: Node) -> void:
	var catalog: RefCounted = _source_cancel_catalog()
	if catalog == null: return
	var npc = world.patch523_npc_spells
	var extension = npc.extensions
	var actor: Node = _victim(world)
	_check(actor != null,"actual monster actor for source cancellation release")
	if actor == null: return
	# Exact source spell graph is a test-only registration, not normal NPC
	# spawning, production catalog installation or acquisition evidence.
	var original_catalog: RefCounted = npc.catalog
	var old_mode: int = int(extension.remaining.host_cancel_mode)
	var original_buffs: Dictionary = npc.player_buffs.duplicate(true)
	npc.catalog = catalog
	npc.player_buffs.clear()
	extension.remaining.host_cancel_mode = 0
	var service = world.equipment523
	var before: Dictionary = service.export_state(world)
	_check(_release_cancel(world,catalog.row("SpellClass",44223),actor),"actual source grouped cancel release reaches equipment owner")
	_check(not service.set_effects.guard.is_empty() and service.export_state(world).cooldowns == before.cooldowns,"mismatched source group preserves guard and reuse clock")
	_check(_release_cancel(world,catalog.row("SpellClass",1093),actor),"actual source mass cancel release reaches equipment owner")
	_check(service.set_effects.guard.is_empty() and service.export_state(world).cooldowns == before.cooldowns,"source mass cancel removes guard while host_cancel_mode is zero and preserves cooldown")
	service.tick(world,0)
	_check(service.set_effects.guard.is_empty(),"source cancellation cannot grant an immediate recast")
	service.tick(world,float(service.export_state(world).cooldowns.values()[0]))
	service.incoming(world,"melee",false,true,false)
	_check(not service.set_effects.guard.is_empty(),"source-cancelled guard recasts only after reuse clock")
	_check(service.incoming(world,"melee",false,true),"source-cancelled guard resumes normal physical count consumption")
	npc.catalog = original_catalog
	npc.player_buffs = original_buffs
	extension.remaining.host_cancel_mode = old_mode

func _finish(scope: String = "ACTUAL_MAIN_EXPLICIT_SOURCE_OWNERSHIP_FIXTURES_NO_ACQUISITION_OR_ART_CLAIM") -> void:
	print("EQUIPMENT523_SET_HOST_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"source_sets":source_sets,"blocked_sets":blocked_sets,"active_effect_rows":active_effect_rows,"typed_effect_rows":22,"fixture_items":fixture_items,"scope":scope}))
	quit(0 if failures.is_empty() else 1)

func _synthetic_all_element_consumer(world: Node) -> void:
	# Set61 is source-ineligible. Test only the consumer, without changing
	# TestItem, inventing a source owner, or saving this synthetic record.
	world._all_equipped_records()
	var records: Array = world.equipment_records_cache.duplicate(true)
	var baseline: Dictionary = {}
	for channel: String in ["fire","water","wind","earth","dark","holy"]: baseline[channel] = world._player_element_resistance(channel)
	world.equipment_records_cache.append({"element_resist_all":10,"equipment523_synthetic":true,"name":"explicit synthetic consumer fixture"})
	for channel: String in ["fire","water","wind","earth"]:
		_check(is_equal_approx(world._player_element_resistance(channel),clampf(float(baseline[channel])+10,-80,85)),"synthetic consumer only: source all-element axis reaches "+channel)
	for channel: String in ["dark","holy"]:
		_check(is_equal_approx(world._player_element_resistance(channel),float(baseline[channel])),"synthetic consumer only: source all-element axis excludes "+channel)
	world.equipment_records_cache.clear()
	world.equipment_records_cache.append_array(records)
