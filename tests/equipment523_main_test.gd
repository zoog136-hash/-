extends SceneTree
## Actual Main integration with explicitly supplied ownership fixtures.
## This does not prove production acquisition, original art, or all source effects.
const QA = preload("res://tests/qa_class_selection.gd")
const Smith = preload("res://scripts/equipment523/smith_smelt.gd")
const Common = preload("res://scripts/equipment523/common.gd")
const PackStore = preload("res://scripts/equipment523/pack_store.gd")
var checks: int = 0
var failures: Array[String] = []
var chosen_source: int = 0
var chosen_seed: int = 0
const TARGET: String = "equipment523-main-processed"
const OTHER: String = "equipment523-main-same-item-preserved"
const MATERIAL: String = "equipment523-main-material"
const PROOF: String = "user://equipment523-main-proof.json"

func _initialize() -> void:
	call_deferred("reload_proof" if "--equipment523-reload-proof" in OS.get_cmdline_user_args() else "run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_MAIN_FAIL: ",label)

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func freeze(world: Node) -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -100000.0
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED

func run() -> void:
	check(not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(),"explicit verified source-map pack")
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
	var service = world.equipment523
	check(not service.store.pack.is_empty(),"actual verified private mechanics pack loads")
	if service.store.pack.is_empty():
		world.queue_free()
		await process_frame
		finish()
		return
	var source_path: String = ""
	var source_sha: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--equipment523-rules="): source_path = arg.trim_prefix("--equipment523-rules=")
		if arg.begins_with("--equipment523-sha256="): source_sha = arg.trim_prefix("--equipment523-sha256=")
	var install_ownership: Variant = normalized([world.inventory,world.item_instances,world.gold])
	world._equipment523_open()
	await process_frame
	var installer: Control = world.hud.equipment523_view
	installer._path.text = source_path
	installer._sha.text = source_sha
	installer._path.text_changed.emit(source_path)
	installer._sha.text_changed.emit(source_sha)
	check(not installer._install.disabled,"actual UI enables installation for the supplied file and SHA")
	installer._install.pressed.emit()
	check(FileAccess.file_exists(PackStore.POINTER) and FileAccess.get_sha256(PackStore.ROOT+"/"+source_sha+"/rules.json") == source_sha,"actual install UI copies a verified private pack and persists its active pointer")
	check(normalized([world.inventory,world.item_instances,world.gold]) == install_ownership,"pack installation preserves inventory and wallet")
	var fixture: Dictionary = choose_fixture(world)
	check(not fixture.is_empty(),"at least one registered equipment family has a complete executable source pool")
	if fixture.is_empty():
		world.queue_free()
		await process_frame
		finish()
		return
	var record: Dictionary = fixture.record
	var material: Dictionary = fixture.material
	chosen_source = int(fixture.source_id)
	chosen_seed = int(fixture.seed)
	var name: String = str(record.name)
	var material_name: String = str(material.name)
	world.inventory[name] = int(world.inventory.get(name,0)) + 2
	world.inventory[material_name] = int(world.inventory.get(material_name,0)) + 5
	for id: String in [TARGET,OTHER]:
		world.item_instances[id] = {"name":name,"level":0,"element":"","element_level":0,"source_bless_code":2,"bless_state":"blessed","record":record.duplicate(true),"equipment523":{"unrelated_fixture":{"preserve":id}},"unrelated_fixture_option":17}
		world.item_instances[id].record.bless_state = "blessed"
		world.item_instances[id].record.blessed = true
		if world.item_instances[id].record.has("source_bless_raw"): world.item_instances[id].record.source_bless_raw = 2
	if material.has("source_reward_quantity"): material.source_reward_quantity = 5
	world.item_instances[MATERIAL] = {"name":material_name,"level":0,"record":material,"source_reward_quantity":5,"source_bless_code":1}
	world.gold = maxi(int(world.gold),10000000)
	world._equip_or_acquire_item(record,false,TARGET)
	check(world._is_instance_equipped(TARGET),"explicitly supplied target equips through production Main")
	world._update_hud()
	world.rng.seed = chosen_seed
	check(world._save_game(true) == OK,"real atomic baseline save with explicit ownership fixtures")
	var before_disk: String = FileAccess.get_sha256(world.save_path())
	var before: Variant = normalized([world.inventory,world.item_instances,world.gold,world.next_item_instance_id])
	var before_rng: int = world.rng.state
	var other_before: Variant = normalized(world.item_instances[OTHER])
	var before_stats: Dictionary = stats(world)
	world._equipment523_open()
	await process_frame
	var view: Control = world.hud.equipment523_view
	check(is_instance_valid(view),"production equipment523 menu mounts its actual UI")
	view._kind.select(1)
	view._kind.item_selected.emit(1)
	check(select(view._target,TARGET) and select(view._material,MATERIAL),"actual UI selects the exact target and material physical IDs")
	view._preview.pressed.emit()
	check(not view._confirm.disabled and view._commit.disabled,"preview exposes costs and requires consumption confirmation")
	view.get_node("ContentScroll").find_child("CancelOperation",true,false).pressed.emit()
	check(normalized([world.inventory,world.item_instances,world.gold,world.next_item_instance_id]) == before and world.rng.state == before_rng and FileAccess.get_sha256(world.save_path()) == before_disk,"actual UI cancel preserves ownership, wallet, RNG and save bytes")
	view._preview.pressed.emit()
	view._confirm.button_pressed = true
	check(not view._commit.disabled,"actual confirmation enables one execution")
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	view._commit.pressed.emit()
	check(normalized([world.inventory,world.item_instances,world.gold,world.next_item_instance_id]) == before and world.rng.state == before_rng and FileAccess.get_sha256(world.save_path()) == before_disk,"production atomic writer failure preserves live state, RNG and exact durable bytes")
	world.equipment_collections.test_save_writer = Callable()
	view._preview.pressed.emit()
	view._confirm.button_pressed = true
	view._commit.pressed.emit()
	check(world.item_instances[TARGET].equipment523.has("bless_reinforcement"),"actual UI commit stores the new namespace on one physical item")
	check(normalized(world.item_instances[OTHER]) == other_before,"another physical instance of the same item retains every option")
	check(world.item_instances[TARGET].equipment523.unrelated_fixture.preserve == TARGET and world.item_instances[TARGET].unrelated_fixture_option == 17,"unrelated target namespaces and options survive")
	check(int(world.inventory.get(material_name,0)) == int(before[0].get(material_name,0))-1 and int(world.item_instances[MATERIAL].source_reward_quantity) == 4,"exact selected material stack loses one unit")
	check(world.rng.state != before_rng,"successful transaction alone advances live RNG")
	world._invalidate_equipment_static()
	var applied: Array = service.records(world)
	check(not applied.is_empty(),"processed physical item contributes actual equipment records")
	var numeric_path: bool = false
	for effect: Dictionary in applied:
		for key: Variant in effect:
			if key in ["equipment523_bonus_id","name","equipment523_synthetic"] or not effect[key] is float and not effect[key] is int: continue
			if float(effect[key]) != 0 and float(world._equipped_numeric_sum(str(key))) != 0: numeric_path = true
	check(numeric_path,"production equipped numeric consumers read processed effects")
	check(stats(world) != before_stats,"actual Main character or combat statistics change")
	var saved_namespace: Variant = normalized(world.item_instances[TARGET].equipment523)
	var saved_stats: Dictionary = stats(world)
	var final_path: String = world.save_path()
	var final_sha: String = FileAccess.get_sha256(final_path)
	check(final_sha != before_disk,"successful transaction persists different save bytes")
	world.queue_free()
	await process_frame
	world = scene.instantiate()
	root.add_child(world)
	await process_frame
	check(QA.enter_game(world),"fresh Main starts with the committed save")
	freeze(world)
	check(normalized(world.item_instances.get(TARGET,{}).get("equipment523",{})) == saved_namespace,"fresh Main restores physical processing state")
	check(normalized(world.item_instances.get(OTHER,{})) == other_before,"fresh Main preserves the untouched same-item instance")
	check(stats(world) == saved_stats,"fresh Main restores actual processed statistics")
	check(FileAccess.get_sha256(final_path) == final_sha,"fresh load does not rewrite the durable save")
	var proof: Dictionary = {"pack_sha256":world.equipment523.store.sha256,"save_path":final_path,"save_sha256":final_sha,"namespace":saved_namespace,
		"other":other_before,"stats":saved_stats,"source_item_id":chosen_source,"fixture_rng_seed":chosen_seed}
	var proof_file: FileAccess = FileAccess.open(PROOF,FileAccess.WRITE)
	check(proof_file != null,"isolated reload proof file opens")
	if proof_file != null:
		proof_file.store_string(JSON.stringify(proof,"",true,true))
		proof_file.flush()
		check(proof_file.get_error() == OK,"isolated proof persists for a separate process")
		proof_file.close()
	world.queue_free()
	await process_frame
	finish()

func reload_proof() -> void:
	check(FileAccess.file_exists(PROOF),"separate-process proof from the first run exists")
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROOF)) if FileAccess.file_exists(PROOF) else null
	if not proof is Dictionary:
		check(false,"separate-process proof is valid JSON")
		finish("FRESH_PROCESS_ACTIVE_PACK_CACHE_AND_SAVE")
		return
	for arg: String in OS.get_cmdline_user_args():
		check(not arg.begins_with("--equipment523-rules=") and not arg.begins_with("--equipment523-sha256="),"fresh process uses the installed pointer rather than mechanics CLI flags")
	var scene: PackedScene = load("res://Main.tscn")
	check(scene != null,"fresh process loads actual Main")
	if scene == null:
		finish("FRESH_PROCESS_ACTIVE_PACK_CACHE_AND_SAVE")
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	check(QA.enter_game(world),"fresh process confirms the loaded character")
	freeze(world)
	chosen_source = int(proof.get("source_item_id",0))
	chosen_seed = int(proof.get("fixture_rng_seed",0))
	check(world.equipment523.store.sha256 == proof.get("pack_sha256") and not world.equipment523.store.pack.is_empty(),"fresh process loads the verified installed mechanics cache")
	check(normalized(world.item_instances.get(TARGET,{}).get("equipment523",{})) == proof.get("namespace"),"fresh process restores exact processing state")
	check(normalized(world.item_instances.get(OTHER,{})) == proof.get("other"),"fresh process preserves the other identical item")
	check(stats(world) == proof.get("stats"),"fresh process restores actual processed statistics")
	check(int(world.item_instances.get(MATERIAL,{}).get("source_reward_quantity",0)) == 4,"fresh process preserves the remaining selected material stack")
	check(FileAccess.get_sha256(str(proof.get("save_path",""))) == proof.get("save_sha256"),"fresh process load preserves exact durable save bytes")
	world.queue_free()
	await process_frame
	finish("FRESH_PROCESS_ACTIVE_PACK_CACHE_AND_SAVE")

func choose_fixture(world: Node) -> Dictionary:
	var service = world.equipment523
	var pack: Dictionary = service.store.pack
	var material: Dictionary = service._output_record(world,3581)
	if material.is_empty(): return {}
	var material_info: Dictionary = {"source_id":3581,"instance_id":MATERIAL,"name":str(material.name),"bless_code":1,"quantity":5,"amount":5,"equipped":false,"locked":false,"record":material}
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		var source_id: int = service._source(record)
		if source_id <= 0 or str(world._enhancement_kind_for_record(record)).is_empty(): continue
		if str(record.get("slot","")) == "weapon" and not world._weapon_allowed_for_job(record,world.job_class): continue
		var target: Dictionary = {"source_id":source_id,"instance_id":TARGET,"name":str(record.name),"level":0,"bless_code":2,"element_type":0,"element_level":0,"state":{},"record":record,"locked":false,"equipped":false}
		var action: Dictionary = {"kind":"bless_reinforcement","target_id":TARGET,"material_ids":[MATERIAL]}
		var q: Dictionary = Smith.quote(pack,action,{"target":target,"materials":[material_info],"policy":service.policy,"now_unix":int(Time.get_unix_time_from_system())})
		if not q.get("ok",false): continue
		for seed: int in range(11,40):
			var rng := RandomNumberGenerator.new()
			rng.seed = seed
			var rolled: Dictionary = Smith.roll(pack,q,rng)
			if rolled.get("ok",false) and changes_stats(rolled.get("effects",[])): return {"source_id":source_id,"record":record.duplicate(true),"material":material.duplicate(true),"seed":seed}
	return {}

func changes_stats(effects: Array) -> bool:
	for effect: Dictionary in effects:
		for key: String in ["strFlat","dexFlat","conFlat","intFlat","wisFlat","chaFlat","def","hpFlat","hpPct","mpFlat","mpPct","meleeDamage","rangedDamage","meleeHit","rangedHit","magicDamage","magicHit","sp","mr","attackSpeed","damage_reduction","stun_resistance","stun_accuracy","xp"]:
			if float(effect.get(key,0)) != 0: return true
	return false

func select(option: OptionButton, id: String) -> bool:
	for index: int in range(option.item_count):
		if str(option.get_item_metadata(index)) == id:
			option.select(index)
			option.item_selected.emit(index)
			return true
	return false

func stats(world: Node) -> Dictionary:
	var snapshot: Dictionary = world._character_stats_snapshot()
	for key: String in ["inventory_weight","current_weight","encumbrance_multiplier","consumable_state","base_attributes"]: snapshot.erase(key)
	snapshot["max_hp"] = world._effective_max_hp()
	snapshot["max_mp"] = world._effective_max_mp()
	snapshot["experience_multiplier"] = world._experience_multiplier()
	return snapshot

func finish(scope: String = "ACTUAL_MAIN_UI_SAVE_NODE_RELOAD_WITH_EXPLICIT_OWNERSHIP_FIXTURES") -> void:
	print("EQUIPMENT523_MAIN_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"source_item_id":chosen_source,"fixture_rng_seed":chosen_seed,"scope":scope}))
	quit(0 if failures.is_empty() else 1)
