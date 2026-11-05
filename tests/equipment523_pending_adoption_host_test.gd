extends SceneTree
## Opt-in actual Main migration QA. All held outputs below are explicit ownership
## fixtures matching the old fallback schema, never normal material acquisition.
const QA = preload("res://tests/qa_class_selection.gd")
const Adapter = preload("res://tests/helpers/equipment523_native_drop_adapter.gd")
const C = preload("res://scripts/equipment523/common.gd")
const Native = preload("res://scripts/equipment523/native_catalog.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
const OWNER_PATH: String = "res://scripts/loot/patch523_monster_drops.gd"
const OWNER_SHA: String = "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const RULE_SHA: String = "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700"
const TARGET: String = "pending-adoption-existing-physical-fixture"
const CUSTOM: String = "pending-adoption-unknown-physical-fixture"
const RECORD: String = "pending-adoption-unknown-record-fixture"
const REFERENCE: String = "pending-adoption-referenced-fixture"
const UNCERTAIN: String = "pending-adoption-uncertain-physical-fixture"
const PROOF: String = "user://equipment523-pending-adoption-proof.json"
var checks: int = 0
var failures: Array[String] = []
var source_id: int = 0
var result_id: int = 0

func _initialize() -> void:
	call_deferred("reload_proof" if "--equipment523-pending-adoption-reload" in OS.get_cmdline_user_args() else "run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_PENDING_ADOPTION_FAIL: "+label)
	return ok

func norm(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value,"",true,true))

func argument(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

func native_owner() -> Variant:
	return load(OWNER_PATH) if ResourceLoader.exists(OWNER_PATH) else null

func freeze(world: Node) -> void:
	world.set_process(false)
	world.set_physics_process(false)
	world.save_timer = -100000000.0
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	world.monsters_root.process_mode = Node.PROCESS_MODE_DISABLED
	for population: Variant in [world.field_population,world.legacy_population,world.original_population]:
		if is_instance_valid(population):
			population.set_process(false)
			population.set_physics_process(false)

func make_world() -> Node:
	var scene: PackedScene = load("res://Main.tscn")
	if scene == null: return null
	var world: Node = scene.instantiate()
	# Reuse the frozen adapter's public definition registration before load.
	world.set_script(Adapter)
	root.add_child(world)
	return world

func ownership(world: Node) -> Variant:
	return norm([world.inventory,world.item_instances,world.gold,world.next_item_instance_id,world.equipped_items,world.quickslots,world.ui_preferences])

func stats(world: Node) -> Dictionary:
	var data: Dictionary = world._character_stats_snapshot()
	for key: String in ["inventory_weight","current_weight","encumbrance_multiplier","consumable_state","base_attributes"]: data.erase(key)
	data.max_hp = world._effective_max_hp()
	data.max_mp = world._effective_max_mp()
	return norm(data)

func known_numeric(record: Dictionary) -> bool:
	for key: String in ["atk","def","strFlat","dexFlat","conFlat","intFlat","wisFlat","chaFlat","hpFlat","hpPct","mpFlat","mpPct","meleeDamage","rangedDamage","meleeHit","rangedHit","magicDamage","magicHit","sp","mr","attackSpeed","damage_reduction","stun_resistance","stun_accuracy"]:
		if float(record.get(key,0)) != 0: return true
	return false

func eligible_outputs(world: Node) -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	var seen: Dictionary = {}
	var native: Variant = native_owner()
	var pack: Dictionary = world.equipment523.store.pack
	for row: Dictionary in C.rows(pack,"AlchemyResult"):
		var recipe: Dictionary = C.find(pack,"AlchemyRecipeType",int(row.RecipeTypeID))
		if int(row.RecipeTypeID) not in [63,113] or recipe.get("IsEnabled") != true or int(row.Amount) != 1 or int(row.Enchant) != 0 or int(row.BlessCode) != 1 or int(row.ServerLimitSetID) != 0 or int(row.Probability) <= 0: continue
		var id: int = int(row.ItemClassID)
		if seen.has(id): continue
		seen[id] = true
		if C.item(pack,id).get("raw",{}).get("TestItem") != false: continue
		var definition: Dictionary = native.definition_id(str(id))
		var expected: Dictionary = native.expected_variant(definition.get("native_record",{}),{"source_bless_raw":1})
		if expected.is_empty() or not native.equipment(expected) or not known_numeric(expected) or str(world._equipment_slot_base(expected)).is_empty(): continue
		if not native.equipment_error(expected,world.job_class,world.level).is_empty(): continue
		var registered: Dictionary = world._catalog_item_from_source_id(str(expected.sourceId))
		if not native.matches(registered,expected) or world.equipment523._native_identity(registered).is_empty(): continue
		selected.append({"result":row.duplicate(true),"native":registered.duplicate(true)})
		if selected.size() == 2: break
	return selected

func old_output(pack: Dictionary, result: Dictionary) -> Dictionary:
	var id: int = int(result.ItemClassID)
	var name: String = "[원본보상]"+str(C.item(pack,id).name)
	var record: Dictionary = {"name":name,"source":"lineagem_current523","source_snapshot":"current523","sourceId":"m523:item:"+str(id),"source_item_class_id":id,"source_original_item":true,"source_bless_code_id":1,"source_reward_quantity":1,"source_reward_id":int(result.ID),"desc":"미등록 원본 아이템: 실제 장비 효과는 카탈로그 등록 후 적용합니다.","bless_state":"normal","blessed":false}
	return {"name":name,"level":0,"element":"","element_level":0,"source_bless_code":1,"bless_state":"normal","record":record,"source_reward_quantity":1,"equipment523":{},"source_smelt":{}}

func held_items(world: Node) -> Dictionary:
	var held: Dictionary = {}
	for id: String in [CUSTOM,RECORD,REFERENCE]: held[id] = norm(world.item_instances.get(id,{}))
	return held

func installed(native: Variant) -> bool:
	var path: String = native.installed_path(OWNER_SHA)
	var full: Variant = load("res://scripts/loot/patch523_item_catalog.gd")
	return check(FileAccess.file_exists(path) and FileAccess.get_sha256(path) == OWNER_SHA and full.validate_files(native.data(),path.get_base_dir()),"native catalog and every sidecar are durably installed at their public pin")

func run() -> void:
	var native: Variant = native_owner()
	if not check(native != null,"optional verified public native owner exists"):
		finish();return
	var install: Dictionary = native.install_zip(argument("--equipment523-pending-native-zip="))
	if not check(install.get("ok",false),"real public native installer succeeds: "+JSON.stringify(install)) or not installed(native):
		finish();return
	var world: Node = make_world()
	await process_frame
	if not check(is_instance_valid(world) and QA.enter_game(world),"actual Main confirms its real character/load flow"):
		finish();return
	freeze(world)
	if not check(world.field_map != null and world.native_drop_registration.get("ok",false),"actual source map and before-load native catalog bridge are available"):
		world.queue_free();finish();return
	var rules_install: Dictionary = world.equipment523.install(world,argument("--equipment523-rules="),RULE_SHA)
	if not check(rules_install.get("ok",false),"verified mechanics rules are durably installed"):
		world.queue_free();finish();return
	var outputs: Array[Dictionary] = eligible_outputs(world)
	if not check(outputs.size() == 2,"active exact Amount1 normal unenchanted equipment results have real registered consumers"):
		world.queue_free();finish();return
	var original: Dictionary = old_output(world.equipment523.store.pack,outputs[0].result)
	source_id = int(outputs[0].result.ItemClassID);result_id = int(outputs[0].result.ID)
	for id: String in [TARGET,CUSTOM,RECORD]:
		world.item_instances[id] = original.duplicate(true)
		world.inventory[str(original.name)] = int(world.inventory.get(str(original.name),0))+1
	world.item_instances[CUSTOM]["opaque_custom_state"] = {"preserve":[17,"custom fixture"]}
	world.item_instances[RECORD].record["unknown_original_record_field"] = {"preserve":true}
	var referenced: Dictionary = old_output(world.equipment523.store.pack,outputs[1].result)
	world.item_instances[REFERENCE] = referenced
	world.inventory[str(referenced.name)] = int(world.inventory.get(str(referenced.name),0))+1
	var lock_reference: String = str(referenced.name)+"@@@"+REFERENCE
	world.ui_preferences.item_locks[lock_reference] = true
	world.rng.seed = 5231842
	if not check(world._save_game(true) == OK,"real writer persists exact legacy pending output ownership fixtures before adoption"):
		world.queue_free();finish();return
	var before: Variant = ownership(world)
	var before_rng: int = world.rng.state
	var before_sha: String = FileAccess.get_sha256(world.save_path())
	var before_ids: Array = world.item_instances.keys().duplicate()
	var before_gold: int = world.gold
	var before_next: int = world.next_item_instance_id
	var held: Dictionary = held_items(world)
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	var failed: Dictionary = world.equipment523.adopt_pending_alchemy(world)
	world.equipment_collections.test_save_writer = Callable()
	check(not failed.get("ok",false) and ownership(world) == before and world.rng.state == before_rng and FileAccess.get_sha256(world.save_path()) == before_sha,"atomic adoption writer failure preserves all live ownership, IDs, RNG, wallet and exact save bytes")
	var done: Dictionary = world.equipment523.adopt_pending_alchemy(world)
	if not check(done.get("ok",false) and done.get("state") == "saved_and_adopted" and done.get("migrated_ids",[]) == [TARGET],"single atomic adoption rebinds only the proven original physical output: "+JSON.stringify(done)):
		world.queue_free();finish();return
	var adopted: Dictionary = world.item_instances[TARGET]
	var migration: Dictionary = adopted.get("equipment523_alchemy_catalog_migration",{})
	check(migration.get("basis") == "legacy_exact_result_contract" and migration.get("consumer_data_sha256") == RULE_SHA and migration.get("native_data_sha256") == OWNER_SHA and int(migration.get("result_id",0)) == result_id,"legacy migration records its exact source/result/consumer/native basis without claiming a new reward")
	check(Native.same(migration.get("original_record",{}),original.record) and Native.same(adopted.get("equipment523"),original.equipment523) and Native.same(adopted.get("source_smelt"),original.source_smelt),"original record provenance and known empty owner state survive on the existing physical ID")
	check(world.item_instances.keys() == before_ids and world.next_item_instance_id == before_next and world.gold == before_gold and world.rng.state == before_rng,"successful adoption mints no ID, wallet amount or RNG draw")
	check(held_items(world) == held and done.get("held",[]).size() == 3 and world.ui_preferences.item_locks.get(lock_reference) == true,"unknown physical custom state, unknown record and externally referenced output are held byte-for-value")
	check(int(world.inventory.get(str(original.name),0)) == 2 and int(world.inventory.get(str(adopted.name),0)) == 1 and native.matches(adopted.record,outputs[0].native),"existing quantity moves one-for-one to the verified native identity")
	var before_equip: Dictionary = stats(world)
	world._equip_or_acquire_item(adopted.record,false,TARGET)
	world._invalidate_equipment_static()
	if not check(world._is_instance_equipped(TARGET) and not world.equipment523._info(world,TARGET,world.item_instances[TARGET]).is_empty(),"actual Main equipment owner accepts the adopted physical item and exact native identity"):
		world.queue_free();finish();return
	var after_equip: Dictionary = stats(world)
	check(after_equip != before_equip,"actual Main equipment stat consumers apply the adopted original equipment")
	check(world._save_game(true) == OK,"actual writer persists the adopted equipped item for a separate process")
	var stable_sha: String = FileAccess.get_sha256(world.save_path())
	var stable_state: Variant = ownership(world)
	var again: Dictionary = world.equipment523.adopt_pending_alchemy(world)
	check(again.get("ok",false) and not again.get("changed",false) and ownership(world) == stable_state and FileAccess.get_sha256(world.save_path()) == stable_sha,"repeated adoption is idempotent and preserves every held output")
	# A separate exact ownership fixture exercises a write that succeeds on disk
	# but reports an error. Never retry that potentially committed adoption live.
	world.item_instances[UNCERTAIN] = original.duplicate(true)
	world.inventory[str(original.name)] = int(world.inventory.get(str(original.name),0))+1
	if not check(world._save_game(true) == OK,"real writer preserves a separate uncertain-result baseline fixture"):
		world.queue_free();finish();return
	var uncertain_before: Variant = ownership(world)
	var uncertain_rng: int = world.rng.state
	var uncertain_sha: String = FileAccess.get_sha256(world.save_path())
	var real_write_errors: Array[int] = []
	world.equipment_collections.test_save_writer = func(path: String,data: Dictionary) -> Error:
		var error: Error = Writer.write(path,data)
		real_write_errors.append(error)
		return ERR_CANT_CREATE if error == OK else error
	var uncertain: Dictionary = world.equipment523.adopt_pending_alchemy(world)
	world.equipment_collections.test_save_writer = Callable()
	check(real_write_errors == [OK] and not uncertain.get("ok",false) and world.equipment523.save_blocked and ownership(world) == uncertain_before and world.rng.state == uncertain_rng,"write-then-error preserves live ownership/RNG and blocks uncertain adoption")
	var written_sha: String = FileAccess.get_sha256(world.save_path())
	check(written_sha != uncertain_sha,"uncertain writer produced different durable bytes without adopting them live")
	var denied: Dictionary = world.equipment523.adopt_pending_alchemy(world)
	check(not denied.get("ok",false) and ownership(world) == uncertain_before and world.rng.state == uncertain_rng and FileAccess.get_sha256(world.save_path()) == written_sha,"uncertain adoption refuses another debit or save before reload")
	world._load_game(true)
	freeze(world)
	if not check(not world.equipment523.save_blocked and world.item_instances.get(UNCERTAIN,{}).get("record",{}).get("source_m_native_item") == true and world.item_instances[UNCERTAIN].equipment523_alchemy_catalog_migration.basis == "legacy_exact_result_contract","actual Main reload reconciles the durably adopted same physical ID"):
		world.queue_free();finish();return
	check(held_items(world) == held and world.gold == before_gold and world.next_item_instance_id == before_next and FileAccess.get_sha256(world.save_path()) == written_sha,"uncertain-result reload preserves held state, wallet, IDs and confirmed disk bytes")
	after_equip = stats(world)
	var proof: Dictionary = {"source_id":source_id,"result_id":result_id,"ownership":"EXPLICIT_LEGACY_PENDING_OUTPUT_SCHEMA_FIXTURE_NOT_NORMAL_ACQUISITION","rules_sha":RULE_SHA,"native_sha":OWNER_SHA,"target":norm(world.item_instances[TARGET]),"uncertain_target":norm(world.item_instances[UNCERTAIN]),"held":held_items(world),"inventory":norm(world.inventory),"gold":world.gold,"next_id":world.next_item_instance_id,"stats":after_equip,"lock_reference":lock_reference,"initial_baseline_sha256":before_sha,"successful_adoption_sha256":stable_sha,"uncertain_baseline_sha256":uncertain_sha,"save_sha256":written_sha,"scene_sha256":FileAccess.get_sha256("res://Main.tscn"),"world_sha256":FileAccess.get_sha256("res://scripts/world.gd"),"adapter_sha256":FileAccess.get_sha256("res://tests/helpers/equipment523_native_drop_adapter.gd")}
	var file := FileAccess.open(PROOF,FileAccess.WRITE)
	check(file != null,"isolated pending-adoption proof file opens")
	if file != null:
		file.store_string(JSON.stringify(proof,"",true,true));file.flush()
		check(file.get_error() == OK,"pending-adoption proof is durable for a separate process")
		file.close()
	world.queue_free()
	await process_frame
	finish()

func reload_proof() -> void:
	for arg: String in OS.get_cmdline_user_args():
		check(not arg.begins_with("--patch523-drop-root=") and not arg.begins_with("--equipment523-rules=") and not arg.begins_with("--equipment523-sha256="),"fresh process uses installed owners without rules/native input CLI paths")
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROOF)) if FileAccess.file_exists(PROOF) else null
	if not check(proof is Dictionary,"separate-process pending-adoption proof exists"):
		finish("FRESH_PROCESS");return
	var native: Variant = native_owner()
	if not check(native != null and native.pack_identity().get("sha256") == OWNER_SHA,"fresh process loads the durable native owner") or not installed(native):
		finish("FRESH_PROCESS");return
	var world: Node = make_world()
	await process_frame
	if not check(is_instance_valid(world) and QA.enter_game(world),"fresh actual Main loads the committed pending-adoption save"):
		finish("FRESH_PROCESS");return
	freeze(world)
	source_id = int(proof.source_id);result_id = int(proof.result_id)
	check(world.equipment523.store.sha256 == RULE_SHA and world.native_drop_registration.get("ok",false),"native registration precedes load and the installed mechanics pointer restores")
	check(norm(world.item_instances.get(TARGET,{})) == proof.target and norm(world.item_instances.get(UNCERTAIN,{})) == proof.uncertain_target and held_items(world) == proof.held,"fresh process preserves both physical IDs, migration proofs and every unknown/referenced held item")
	check(norm(world.inventory) == proof.inventory and world.gold == proof.gold and world.next_item_instance_id == proof.next_id,"fresh process preserves quantities, wallet and next physical ID")
	check(world._is_instance_equipped(TARGET) and stats(world) == proof.stats,"fresh actual Main restores equipped native effects through its real consumers")
	check(world.ui_preferences.item_locks.get(str(proof.lock_reference)) == true and FileAccess.get_sha256(world.save_path()) == proof.save_sha256,"fresh load preserves references and exact durable save bytes")
	check(FileAccess.get_sha256("res://Main.tscn") == proof.scene_sha256 and FileAccess.get_sha256("res://scripts/world.gd") == proof.world_sha256 and FileAccess.get_sha256("res://tests/helpers/equipment523_native_drop_adapter.gd") == proof.adapter_sha256,"both processes use the same recorded Main owner and frozen adapter")
	world.queue_free()
	await process_frame
	finish("FRESH_PROCESS")

func finish(phase: String = "EXACT_PENDING_FIXTURE_ATOMIC_ADOPTION") -> void:
	print("EQUIPMENT523_PENDING_ADOPTION_HOST_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"phase":phase,"source_item_id":source_id,"alchemy_result_id":result_id,"scope":"ACTUAL_MAIN_WITH_EXPLICIT_OLD_PENDING_OUTPUT_OWNERSHIP_FIXTURES","normal_acquisition_verified":false,"original_art_verified":false}))
	quit(0 if failures.is_empty() else 1)
