extends SceneTree
## Actual Main/Monster consumers with explicit source-identity ownership fixtures.
## Requires the verified base pack and effects supplement. No acquisition/art claim.
const QA = preload("res://tests/qa_class_selection.gd")
const C = preload("res://scripts/equipment523/common.gd")
const Invoke = preload("res://scripts/equipment523/set_invoke.gd")
const Debuff = preload("res://scripts/equipment523/invoke_debuff.gd")
const Store = preload("res://scripts/equipment523/pack_store.gd")
const OWNER: String = "equipment523-invoke-host-fixture"
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_INVOKE_HOST_FAIL: ",label)

func freeze(world: Node) -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -100000.0
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED
	for population: Variant in [world.field_population,world.legacy_population,world.original_population]:
		if is_instance_valid(population):
			population.set_process(false)
			population.set_physics_process(false)

func run() -> void:
	check(not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(),"verified current source-map pack explicitly supplied")
	var scene: PackedScene = load("res://Main.tscn")
	check(scene != null,"actual Main loads")
	if scene == null:
		finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	check(QA.enter_game(world),"actual Main class confirmation")
	freeze(world)
	var base_path: String = ""
	var base_sha: String = ""
	var supplement: String = ""
	var supplement_sha: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-rules="): base_path = arg.trim_prefix("--equipment523-rules=")
		if arg.begins_with("--equipment523-sha256="): base_sha = arg.trim_prefix("--equipment523-sha256=")
		if arg.begins_with("--equipment523-effects="): supplement = arg.trim_prefix("--equipment523-effects=")
		if arg.begins_with("--equipment523-effects-sha256="): supplement_sha = arg.trim_prefix("--equipment523-effects-sha256=")
	var ownership: String = JSON.stringify([world.inventory,world.item_instances,world.gold])
	await install_ui(world,base_path,base_sha)
	check(FileAccess.file_exists(Store.POINTER) and FileAccess.get_sha256(Store.ROOT+"/"+base_sha+"/rules.json") == base_sha,"actual Main UI durably installs the verified base before its supplement")
	await install_ui(world,supplement,supplement_sha)
	check(world.equipment523.store.effects_sha256 == supplement_sha and FileAccess.file_exists(Store.ROOT+"/"+base_sha+"/effects-active.json") and FileAccess.get_sha256(Store.ROOT+"/"+base_sha+"/effects/"+supplement_sha+".json") == supplement_sha,"same actual Main UI installs the verified supplement and active pointer")
	check(JSON.stringify([world.inventory,world.item_instances,world.gold]) == ownership,"both private pack installations preserve inventory and wallet")
	var pack: Dictionary = world.equipment523.store.pack
	check(not pack.is_empty(),"verified mechanics pack is available")
	var cases: Array[Dictionary] = source_cases(pack,world.equipment523.policy)
	check(cases.size() == 7,"all seven variable debuff spells have an executable original selection path")
	if cases.size() != 7:
		world.queue_free()
		await process_frame
		finish()
		return
	var actor: TwilightMonster = world.MONSTER_SCENE.instantiate()
	world.monsters_root.add_child(actor)
	actor.setup({"name":"equipment523-host-fixture","hp":100000,"atk":100,"xp":0,"gold":0,"speed":0,"grade":"일반"},world.player,world,null)
	actor.melee_accuracy = 1000
	actor.ranged_accuracy = 1000
	actor.stun_resistance = 0
	actor.hold_resistance = 0
	actor.status_immunities.clear()
	actor.global_position = world.player.global_position
	for sample: Dictionary in cases:
		Debuff.clear(world)
		world.skill_cooldowns.clear()
		install_owner(world,pack,sample)
		var origin: Dictionary = sample.origin
		var spell_id: int = int(sample.parsed.spell.ID)
		check(world._equipment523_invoke_owner(origin,spell_id),"exact current equipped physical owner validates spell %d" % spell_id)
		var wrong: Dictionary = origin.duplicate(true)
		wrong.instance_id = "another-physical-item"
		check(not world._equipment523_invoke_owner(wrong,spell_id) and not world._equipment523_invoke_owner(origin,spell_id+1),"another physical ID or spell cannot reuse a valid owner proof")
		actor.set_meta("source_invisible",true)
		var hidden_seed: int = proc_seed(int(sample.probability))
		world.rng.seed = hidden_seed
		var hidden_fired: Array = world.equipment523.on_hit(world,actor,"melee",true,false)
		var hidden_hit: bool = false
		for event: Dictionary in hidden_fired:
			if int(event.get("spell_id",0)) == spell_id: hidden_hit = true
		check(sample.parsed.spell.get("CanCastOnInvisible") == false and not hidden_hit,"actual selected source spell rejects invisible target %d" % spell_id)
		check(not Debuff.apply(pack,world,actor,sample.option,world.equipment523.policy,origin).get("ok",false),"direct source debuff API preserves invisible restriction %d" % spell_id)
		actor.remove_meta("source_invisible")
		world.original_skills.status.set_modifiers(actor,"host-unrelated",100,{"ac":3})
		var baseline_accuracy: int = world._monster_accuracy_for_attack_type(actor,"melee")
		var baseline_damage: int = npc_damage(world,actor,179)
		var builtin_controls: Vector2 = Vector2(actor.stun_remaining,actor.hold_remaining)
		var seed: int = proc_seed(int(sample.probability))
		check(seed >= 0,"an unchanged source probability has a deterministic successful seed")
		world.rng.seed = seed
		var fired: Array = world.equipment523.on_hit(world,actor,"melee",true,false)
		var hit: bool = false
		for event: Dictionary in fired:
			if int(event.get("spell_id",0)) == spell_id: hit = true
		check(hit,"production on_hit routes the selected original debuff spell %d" % spell_id)
		var parsed: Dictionary = sample.parsed
		for field: String in ["CasterEffectSpriteID","EffectSpriteID","EffectExplosionSpriteID","SuccessEffectSpriteID"]:
			var sprite: int = int(parsed.spell.get(field,0))
			if sprite <= 0: continue
			var requested: bool = false
			for visual: Dictionary in world.equipment523.set_visual_results:
				if int(visual.get("spell_id",0)) == spell_id and visual.get("field") == field and int(visual.get("sprite_id",0)) == sprite: requested = true
			check(requested,"actual source visual field reaches the 523 renderer %d:%s" % [spell_id,field])
		for key: Variant in parsed.status:
			check(is_equal_approx(world.original_skills.status.modifier(actor,str(key)),float(parsed.status[key])),"actual source modifier consumer receives %s" % key)
		if parsed.status.has("status_resistance_6"):
			# Exercise the actual legacy impact after the source debuff. A
			# physical hit must still land while explicit stun immunity holds.
			var probe := RandomNumberGenerator.new()
			var impact_seed: int = -1
			for value: int in range(1000):
				probe.seed = value
				if probe.randf() < world._melee_hit_chance(actor):
					impact_seed = value
					break
			check(impact_seed >= 0,"actual legacy hit has an unchanged successful first-draw seed")
			var old_health: int = actor.hp
			var old_mana: int = world.mp
			var old_resolving: bool = world.resolving_combat_action
			actor.status_immunities = ["stun"]
			world.resolving_combat_action = true
			world.rng.seed = impact_seed
			var stunned: bool = world._cast_stun_skill(actor,1,0,1.0,"equipment523 immunity probe")
			check(not stunned and actor.hp < old_health and actor.stun_remaining == 0,"actual Main legacy impact preserves physical damage while source-six weakening cannot bypass explicit stun immunity")
			actor.status_immunities.clear()
			actor.hp = old_health
			world.mp = old_mana
			world.resolving_combat_action = old_resolving
		check(world._monster_accuracy_for_attack_type(actor,"melee") == baseline_accuracy+int(parsed.numeric.get("melee_accuracy",0)),"actual World melee accuracy consumes the live source delta")
		if float(parsed.numeric.get("melee_damage",0)) < 0:
			check(npc_damage(world,actor,179) < baseline_damage,"actual World NPC hit damage consumes the live melee decrease")
		var expected_heal: int = int(100.0*(1.0-float(parsed.healing.get("magic",0))/1000000.0))
		var expected_potion: int = int(100.0*(1.0-float(parsed.healing.get("potion",0))/1000000.0))
		check(actor.source_option_healing(100,false) == expected_heal and actor.source_option_healing(100,true) == expected_potion,"actual Monster healing consumes raw source recovery weights")
		if not str(parsed.control).is_empty():
			check(actor.is_stunned() if parsed.control == "stun" else actor.is_held(),"actual Monster consumes the independent source control timer")
			check(Vector2(actor.stun_remaining,actor.hold_remaining) == builtin_controls,"source controls preserve unrelated builtin timers")
		var before_generation: Array = [Debuff.outgoing(actor,100,"melee"),Debuff.outgoing(actor,100,"ranged"),Debuff.accuracy_delta(actor,"melee"),Debuff.healing_weight(actor,false),Debuff.healing_weight(actor,true),Debuff.control_active(actor,"stun"),Debuff.control_active(actor,"hold")]
		world.combat_generation += 1
		check(before_generation == [Debuff.outgoing(actor,100,"melee"),Debuff.outgoing(actor,100,"ranged"),Debuff.accuracy_delta(actor,"melee"),Debuff.healing_weight(actor,false),Debuff.healing_weight(actor,true),Debuff.control_active(actor,"stun"),Debuff.control_active(actor,"hold")],"same-map action generation preserves an applied debuff")
		Debuff.tick(world,33)
		check(world._monster_accuracy_for_attack_type(actor,"melee") == baseline_accuracy and actor.source_option_healing(100) == 100 and not Debuff.control_active(actor,"stun") and not Debuff.control_active(actor,"hold"),"expiry restores actual host consumers without destructive stat changes")
		check(world.original_skills.status.modifier(actor,"ac") == 3,"expiry preserves another status source")
		var applied: Dictionary = Debuff.apply(pack,world,actor,sample.option,world.equipment523.policy,origin)
		check(applied.get("ok",false),"verified direct cast is available for lifecycle checks")
		world._clear_combat_actions()
		check(Debuff.outgoing(actor,100,"melee") == 100 and actor.source_option_healing(100) == 100 and not Debuff.control_active(actor,"stun") and not Debuff.control_active(actor,"hold"),"actual combat clear removes only the equipment control and numeric lifetime")
	actor.queue_free()
	world.queue_free()
	await process_frame
	finish()

func install_ui(world: Node, path: String, sha: String) -> void:
	world._equipment523_open()
	await process_frame
	var view: Control = world.hud.equipment523_view
	view._path.text = path
	view._sha.text = sha
	view._path.text_changed.emit(path)
	view._sha.text_changed.emit(sha)
	check(not view._install.disabled,"actual equipment UI enables the supplied verified pack path")
	view._install.pressed.emit()

func npc_damage(world: Node, actor: TwilightMonster, seed: int) -> int:
	# Explicit synthetic non-safe combat context; retain the actual host resolver.
	var field: Variant = world.field_map
	var hp: int = world.hp
	world.field_map = null
	world.hp = world._effective_max_hp()
	var before: int = world.hp
	world.rng.seed = seed
	world._on_player_hit(actor,100,"melee")
	var amount: int = before-world.hp
	world.hp = hp
	world.field_map = field
	return amount

func install_owner(world: Node, pack: Dictionary, sample: Dictionary) -> void:
	var source_id: int = int(sample.origin.source_id)
	var source_item: Dictionary = C.item(pack,source_id)
	var name: String = str(source_item.name)
	# Test-only host registration supplies no source item stats or acquisition.
	var record: Dictionary = {"name":name,"sourceId":"m523:item:"+str(source_id),"source_item_class_id":source_id,"slot":"weapon","weaponType":"단검"}
	world.inventory[name] = 1
	world.item_instances[OWNER] = {"name":name,"level":int(sample.level),"source_bless_code":int(sample.bless),"record":record,
		"equipment523":{"invoke_replacement":{"schema":"equipment523-invoke-v1","replacement_id":int(sample.replacement),"source_id":source_id,"target_id":OWNER,"source_sha256":str(pack.source_sha256),"slots":{str(int(sample.origin.slot)):{"group_id":int(sample.group),"entity_id":int(sample.entity)}}}}}
	world.equipped_items.weapon = record.duplicate(true)
	world.equipped_items.weapon.instance_id = OWNER
	world.equipped_items.weapon.enhance_level = int(sample.level)
	world._invalidate_equipment_static()

func source_cases(pack: Dictionary, policy: Dictionary) -> Array[Dictionary]:
	var found: Dictionary = {}
	for item: Dictionary in C.rows(pack,"ItemBonus"):
		var selector: Dictionary = C.bonus(pack,int(item.get("BonusID",0)))
		if selector.get("type",{}).get("Name","") != "ItemInvokeReplacementID": continue
		var source_id: int = int(item.ItemClassID)
		var replacement: int = Invoke.replacement_id(pack,str(source_id))
		if replacement <= 0: continue
		var slots: Dictionary = Invoke.slots(pack,replacement)
		for key: Variant in slots:
			if slots[key].size() <= 1: continue
			for entity: Dictionary in slots[key]:
				for link: Dictionary in C.rows(pack,"ItemInvokeReplacementBonus"):
					if int(link.get("ItemInvokeReplacementBonusGroupID",0)) != int(entity.ItemInvokeReplacementBonusGroupID): continue
					var bonus: Dictionary = C.bonus(pack,int(link.BonusID))
					if bonus.get("type",{}).get("Name","") != "InvokeOption" or int(bonus.get("raw",{}).get("Value",0)) <= 0: continue
					var option: Dictionary = C.find(pack,"InvokeOption",int(bonus.get("raw",{}).get("BonusApplicationTargetID",0)))
					var parsed: Dictionary = Debuff.contract(pack,option,policy)
					if not parsed.get("ok",false) or found.has(str(int(parsed.spell.ID))): continue
					var level: int = int(link.get("EnchantLevel",0))
					var bless: int = maxi(1,int(link.get("BlessCode",0)))
					found[str(int(parsed.spell.ID))] = {"option":option,"parsed":parsed,"level":level,"bless":bless,"replacement":replacement,"group":int(entity.ItemInvokeReplacementBonusGroupID),"entity":int(entity.ID),"probability":int(bonus.raw.Value),"origin":{"instance_id":OWNER,"source_id":source_id,"slot":int(key),"bonus_id":int(link.BonusID)}}
		if found.size() == 7: break
	var result: Array[Dictionary] = []
	for value: Dictionary in found.values(): result.append(value)
	return result

func proc_seed(probability: int) -> int:
	var rng := RandomNumberGenerator.new()
	for seed: int in range(100000):
		rng.seed = seed
		if rng.randi_range(0,999999) < probability: return seed
	return -1

func finish() -> void:
	print("EQUIPMENT523_INVOKE_HOST_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_AND_MONSTER_WITH_EXPLICIT_OWNERSHIP_AND_COMBAT_FIXTURES"}))
	quit(0 if failures.is_empty() else 1)
