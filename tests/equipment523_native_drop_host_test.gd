extends SceneTree
## Opt-in actual Main QA with unchanged published native acquisition owners.
## Target equipment ownership is an explicit fixture. Materials are never granted
## by this harness: exact original NPC membership -> host loot roll -> floor -> pickup.
const QA = preload("res://tests/qa_class_selection.gd")
const Adapter = preload("res://tests/helpers/equipment523_native_drop_adapter.gd")
const BaseNpc = preload("res://scripts/lineagem_base508.gd")
const C = preload("res://scripts/equipment523/common.gd")
const Smith = preload("res://scripts/equipment523/smith_smelt.gd")
const Native = preload("res://scripts/equipment523/native_catalog.gd")
const OWNER_PATH: String = "res://scripts/loot/patch523_monster_drops.gd"
const OWNER_SHA: String = "38ee3ec74d12adaa9847c507f6fb093c41a4f7a8c5c1cefcd08c3a9629920d27"
const LOOT_FILE_SHA: String = "88ecfa6665c771891e89adf1c8ff6877a15b8f59f376e507fbaf21d39b2b421e"
const RULE_SHA: String = "e2a51dce910799ee31c7943b84a6b44d3c84dfb964b25fe8962f39522cafd700"
const NPC_ID: int = 93032
const MATERIAL: int = 289162
const TARGET: String = "equipment523-native-drop-target-fixture"
const OTHER: String = "equipment523-native-drop-other-fixture"
const PROOF: String = "user://equipment523-native-drop-proof.json"
var checks: int = 0
var failures: Array[String] = []
var acquisition: Array[Dictionary] = []
var chosen_seed: int = -1
var target_source: int = 0

func _initialize() -> void:
	call_deferred("reload_proof" if "--equipment523-native-drop-reload" in OS.get_cmdline_user_args() else "run")

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("EQUIPMENT523_NATIVE_DROP_FAIL: "+label)
	return ok

func norm(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value,"",true,true))

func argument(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix): return arg.trim_prefix(prefix)
	return ""

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

func owner() -> Variant:
	if not ResourceLoader.exists(OWNER_PATH): return null
	return load(OWNER_PATH)

func make_world() -> Node:
	var scene: PackedScene = load("res://Main.tscn")
	if scene == null: return null
	var world: Node = scene.instantiate()
	# Only the optional drop/catalog bridge is replaced. Main nodes, startup,
	# actual NPC death, floor/pickup, processing and durable save stay inherited.
	world.set_script(Adapter)
	root.add_child(world)
	return world

func verify_installed(native: Variant) -> bool:
	var installed: String = native.installed_path(OWNER_SHA)
	var catalog_owner: Variant = load("res://scripts/loot/patch523_item_catalog.gd")
	return check(FileAccess.file_exists(installed) and FileAccess.get_sha256(installed) == OWNER_SHA,"durable native membership bytes retain the public pin") and check(catalog_owner.validate_files(native.data(),installed.get_base_dir()),"durable native installation validates every original item sidecar")

func stats(world: Node) -> Dictionary:
	var result: Dictionary = world._character_stats_snapshot()
	for key: String in ["inventory_weight","current_weight","encumbrance_multiplier","consumable_state","base_attributes"]: result.erase(key)
	result.max_hp = world._effective_max_hp()
	result.max_mp = world._effective_max_mp()
	return norm(result)

func has_stat(effects: Array) -> bool:
	for row: Dictionary in effects:
		for key: String in ["strFlat","dexFlat","conFlat","intFlat","wisFlat","chaFlat","def","hpFlat","hpPct","mpFlat","mpPct","meleeDamage","rangedDamage","meleeHit","rangedHit","magicDamage","magicHit","sp","mr","attackSpeed","damage_reduction","stun_resistance","stun_accuracy","xp"]:
			if float(row.get(key,0)) != 0: return true
	return false

func choose_target(world: Node, material: Dictionary) -> Dictionary:
	var service: Variant = world.equipment523
	var source_ids: Dictionary = {}
	for entity: Dictionary in C.rows(service.store.pack,"ItemSmeltEntity"): source_ids[int(entity.ItemClassID)] = true
	var native: Variant = owner()
	for source_id: int in source_ids:
		var definition: Dictionary = native.definition_id(str(source_id))
		var record: Dictionary = native.variant_item(definition.get("native_record",{}),1)
		if record.is_empty() or not native.equipment(record) or str(world._equipment_slot_base(record)).is_empty() or not native.equipment_error(record,world.job_class,world.level).is_empty(): continue
		var registered: Dictionary = world._catalog_item_from_source_id(str(record.sourceId))
		if not native.matches(registered,record) or service._native_identity(registered).is_empty(): continue
		record = registered
		var physical: Dictionary = {"name":record.name,"record":record.duplicate(true),"level":0,"element":"","element_level":0,"equipment523":{"unrelated_fixture":{"preserve":true}}}
		# This is read-only fixture planning, before any gear ownership is supplied.
		# The real service's ownership gate is exercised after the chosen fixture
		# is placed below; do not ask _info to authorize an as-yet-unowned item.
		var target: Dictionary = {"source_id":source_id,"instance_id":TARGET,"name":record.name,"level":0,"bless_code":1,"record":record,"state":physical.equipment523,"locked":false,"equipped":false}
		var q: Dictionary = Smith.quote(service.store.pack,{"kind":"smelt"},{"target":target,"materials":[material],"policy":service.policy,"now_unix":int(Time.get_unix_time_from_system())})
		if not q.get("ok",false) or int(world.gold) < int(q.get("gold_cost",0)): continue
		for seed: int in range(1,101):
			var rng = RandomNumberGenerator.new();rng.seed = seed
			var outcome: Dictionary = Smith.roll(service.store.pack,q,rng)
			if outcome.get("ok",false) and has_stat(outcome.get("effects",[])):
				return {"source_id":source_id,"physical":physical,"record":record,"seed":seed}
	return {}

func find_drop_seed(groups: Dictionary, is_boss: bool) -> int:
	var public_loot: Variant = load("res://scripts/loot_drop.gd")
	var rng = RandomNumberGenerator.new()
	for seed: int in range(2000000):
		rng.seed = seed
		var entries: Array = public_loot.roll_patch523(groups,is_boss,rng)
		for row: Dictionary in entries:
			if int(row.get("source_m_drop_proof",{}).get("source_item_class_id",0)) == MATERIAL: return seed
	return -1

func acquire(world: Node, setup_record: Dictionary, seed: int) -> bool:
	var native: Variant = owner()
	var actor: TwilightMonster = load("res://scenes/Monster.tscn").instantiate()
	world.monsters_root.add_child(actor)
	actor.global_position = world.player.global_position
	actor.setup(setup_record.duplicate(true),world.player,world,null)
	actor.set_meta("source_m_snapshot",setup_record.get("source_m_snapshot"))
	actor.set_physics_process(false)
	var raw_npc_sha: String = JSON.stringify(actor.source_m_original,"",true,true).sha256_text()
	if not check(actor.source_m_npc_id == NPC_ID and actor.source_m_original.get("TestNPC") == false and int(actor.source_m_original.get("Sprite",0)) == 22263,"production original NPC factory/setup retains exact non-test source identity"):
		actor.queue_free();return false
	actor.died.connect(world._on_monster_died)
	world.rng.seed = seed
	actor.take_damage(actor.hp+1,false)
	if not check(actor.dead and int(actor.get_meta("rewarded_life_id",-1)) == actor.life_id and int(world.native_drop_context.get("life_id",-1)) == actor.life_id,"actual NPC death dispatches the production reward path once"):
		return false
	if not check(world.native_drop_diagnostics.is_empty(),"native drop bridge refuses no unresolved source fields: "+JSON.stringify(world.native_drop_diagnostics)):
		return false
	var matching: Array[Dictionary] = []
	for row: Dictionary in world.native_drop_entries:
		if int(row.get("source_m_drop_proof",{}).get("source_item_class_id",0)) == MATERIAL: matching.append(row)
	if not check(matching.size() == 1,"unchanged full-pool host rarity roll produces one source life stone at its recorded seed"):
		return false
	var earned: Dictionary = matching[0]
	var proof: Dictionary = earned.source_m_drop_proof
	if not check(int(proof.source_npc_id) == NPC_ID and int(proof.required_quest_id) == 0 and proof.source_rows.any(func(row: Dictionary) -> bool: return int(row.ID) == 2243772 and int(row.source_row_1based) == 35373),"rolled material proves its original unconditional drop row"):
		return false
	var name: String = str(earned.item_name)
	var before: int = int(world.inventory.get(name,0))
	var selected: Button = null
	for id: String in world.native_drop_spawned_ids:
		var floor: Dictionary = world.ground_loot.records.get(id,{})
		if floor.get("item_name") == name and Native.same(floor.get("item_record",{}).get("source_m_drop_proof",{}),proof):
			selected = world.ground_loot.views.get(id)
			break
	if not check(is_instance_valid(selected) and before == acquisition.size(),"real ground record carries the proof before any inventory increment"):
		return false
	var floor_id: String = str(selected.get_meta("id"))
	var floor: Dictionary = world.ground_loot.records[floor_id].duplicate(true)
	# Respect the existing minimum visible lifetime; do not edit its clock.
	while is_instance_valid(selected) and Time.get_ticks_msec()-selected.visible_since < world.ground_loot.MIN_VISIBLE_MS:
		await create_timer(0.05).timeout
	world.player.global_position = Vector2(float(floor.position[0]),float(floor.position[1]))
	selected.pressed.emit()
	world.loot_pickup.pickup_button.pressed.emit()
	if int(world.inventory.get(name,0)) != before+1:
		print("EQUIPMENT523_NATIVE_PICKUP_DIAGNOSTIC "+JSON.stringify({"floor_id":floor_id,"still_on_floor":world.ground_loot.records.has(floor_id),"inventory_before":before,"inventory_after":world.inventory.get(name,0),"player_position":[world.player.global_position.x,world.player.global_position.y],"floor_position":floor.position,"line_clear":world._has_line_of_sight_world(world.player.global_position,world.player.global_position),"stunned":world.player.is_stunned(),"feared":world.player.is_feared(),"held":world.player.is_held(),"movement_locked":world.player.movement_locked,"visible_ms":Time.get_ticks_msec()-selected.visible_since if is_instance_valid(selected) else -1,"pickup_mode":world.loot_pickup.mode,"selected_id":world.loot_pickup.selected_id,"target_id":world.loot_pickup.target_id,"can_loot":not world.patch523_npc_spells.blocks("CannotLoot")}))
	if not check(int(world.inventory.get(name,0)) == before+1 and not world.ground_loot.records.has(floor_id),"actual Main floor button and pickup action transfer exactly one earned material"):
		return false
	check(not floor.has("physical_item"),"source stack material uses the published inventory-count contract without a fabricated physical receipt")
	acquisition.append({"seed":seed,"identity":world.native_drop_identity.duplicate(true),"factory_snapshot":setup_record.get("source_m_snapshot"),"factory":"BASE508.npc_record -> Monster.setup","raw_npc_sha256":raw_npc_sha,"source_drop_proof":proof.duplicate(true),"floor_id":floor_id,"full_candidate_count":world.native_drop_groups.size(),"host_rng_before":world.native_drop_rng_before,"host_rng_after":world.native_drop_rng_after,"material_inventory_after":before+1})
	return true

func run() -> void:
	print("EQUIPMENT523_NATIVE_DROP_PROGRESS install_begin")
	var native: Variant = owner()
	if not check(native != null and FileAccess.get_sha256("res://scripts/loot_drop.gd") == LOOT_FILE_SHA,"exact published native loot owner exists in the existing stage"):
		finish();return
	var installed: Dictionary = native.install_zip(argument("--equipment523-native-drop-zip="))
	if not check(installed.get("ok",false),"actual native installer durably verifies original cache and sidecars: "+JSON.stringify(installed)) or not verify_installed(native):
		finish();return
	var world: Node = make_world()
	print("EQUIPMENT523_NATIVE_DROP_PROGRESS main_created")
	await process_frame
	if not check(is_instance_valid(world) and QA.enter_game(world),"actual Main scene starts with its real class/load flow"):
		finish();return
	freeze(world)
	check(world.field_map != null and not OS.get_environment("TWILIGHT_SOURCE_MAP_PACK").is_empty(),"existing verified Main map remains active")
	var before_registration: Variant = norm([world.inventory,world.item_instances,world.gold])
	var registration: Dictionary = world.register_native_drop_catalog()
	if not check(registration.get("ok",false),"unchanged public native catalog API registers definitions without granting ownership"):
		world.queue_free();finish();return
	check(norm([world.inventory,world.item_instances,world.gold]) == before_registration,"native definition registration changes no owned items or wallet")
	var rules: String = argument("--equipment523-rules=")
	var install_rules: Dictionary = world.equipment523.install(world,rules,RULE_SHA)
	if not check(install_rules.get("ok",false) and world.equipment523.store.sha256 == RULE_SHA,"actual mechanics installer persists the original source rules"):
		world.queue_free();finish();return
	var record: Dictionary = BaseNpc.npc_record(NPC_ID,{})
	var native_identity: Dictionary = native.identity(record)
	var groups: Dictionary = native.candidates(native_identity,{"patch523_by_name":world.loot_catalog.patch523_by_name})
	if not check(not native_identity.is_empty() and groups.has(str(MATERIAL)) and groups[str(MATERIAL)].kind == "equipment","original source NPC full candidate pool contains the source high-grade consumable path"):
		world.queue_free();finish();return
	chosen_seed = find_drop_seed(groups,false)
	if not check(chosen_seed >= 0,"deterministic seed is found without reducing candidates or changing host rarity chances"):
		world.queue_free();finish();return
	for _count: int in range(2):
		var acquired: bool = await acquire(world,record,chosen_seed)
		if not acquired:
			world.queue_free();finish();return
	print("EQUIPMENT523_NATIVE_DROP_PROGRESS original_pickups_complete")
	var material: Dictionary = {}
	for entry: Dictionary in world.equipment523._entries(world):
		if entry.get("instance_id") == "stack:289162": material = entry
	if not check(int(material.get("quantity",0)) == 2 and material.get("virtual_stack",false),"two genuine pickups expose the existing native stack selection"):
		world.queue_free();finish();return
	var fixture: Dictionary = choose_target(world,material)
	if not check(not fixture.is_empty(),"source-compatible registered gear can be tested with explicitly supplied equipment ownership"):
		world.queue_free();finish();return
	target_source = int(fixture.source_id)
	print("EQUIPMENT523_NATIVE_DROP_PROGRESS target_fixture_selected ",target_source)
	for id: String in [TARGET,OTHER]:
		world.item_instances[id] = fixture.physical.duplicate(true)
		world.inventory[str(fixture.record.name)] = int(world.inventory.get(str(fixture.record.name),0))+1
	world._equip_or_acquire_item(fixture.record,false,TARGET)
	if not check(world._is_instance_equipped(TARGET),"fixture gear uses the actual equipment owner and source-compatible slot"):
		world.queue_free();finish();return
	world._update_hud()
	world.rng.seed = int(fixture.seed)
	if not check(world._save_game(true) == OK,"durable baseline includes genuine material ownership and explicitly marked gear fixtures"):
		world.queue_free();finish();return
	var action: Dictionary = {"kind":"smelt","target_id":TARGET,"material_ids":["stack:289162"]}
	var other: Variant = norm(world.item_instances[OTHER])
	var baseline: Variant = norm([world.inventory,world.item_instances,world.gold,world.next_item_instance_id])
	var baseline_rng: int = world.rng.state
	var baseline_sha: String = FileAccess.get_sha256(world.save_path())
	var before_stats: Dictionary = stats(world)
	var q: Dictionary = world.equipment523.quote(world,action)
	print("EQUIPMENT523_NATIVE_DROP_PROGRESS source_quote_complete")
	if not check(q.get("ok",false) and q.get("costs",[]).size() == 1 and int(q.costs[0].source_id) == MATERIAL and int(q.costs[0].amount) == 1,"production source smelt quote consumes one genuinely acquired life stone"):
		world.queue_free();finish();return
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	var failed: Dictionary = world.equipment523.commit(world,action)
	world.equipment_collections.test_save_writer = Callable()
	check(not failed.get("ok",false) and norm([world.inventory,world.item_instances,world.gold,world.next_item_instance_id]) == baseline and world.rng.state == baseline_rng and FileAccess.get_sha256(world.save_path()) == baseline_sha,"atomic writer failure preserves earned material, target, wallet, RNG and exact save bytes")
	q = world.equipment523.quote(world,action)
	var done: Dictionary = world.equipment523.commit(world,action) if q.get("ok",false) else q
	if not check(done.get("ok",false),"actual Main processing service commits native smelt through its one atomic save: "+JSON.stringify(done)):
		world.queue_free();finish();return
	world._invalidate_equipment_static()
	var after_stats: Dictionary = stats(world)
	check(int(world.inventory.get(str(material.name),0)) == 1 and int(world.gold) == int(baseline[2])-int(q.gold_cost),"successful commit debits exactly one earned material and the quoted wallet cost")
	check(norm(world.item_instances[OTHER]) == other and world.item_instances[TARGET].equipment523.unrelated_fixture.preserve,"another physical gear instance and unrelated target state remain unchanged")
	check(not world.equipment523.records(world).is_empty() and after_stats != before_stats,"processed native equipment reaches actual Main stat consumers")
	check(world.item_instances[TARGET].equipment523_last_processing.consumer_data_sha256 == RULE_SHA,"processed target records this consumer's exact mechanics digest")
	var proof: Dictionary = {"native_sha":OWNER_SHA,"rules_sha":RULE_SHA,"source_item_id":target_source,"drop_seed":chosen_seed,"acquisition":acquisition,"target_ownership":"EXPLICIT_EQUIPMENT_FIXTURE_NOT_NORMAL_ACQUISITION","material_ownership":"ORIGINAL_NON_TEST_NPC_FULL_POOL_PUBLIC_LOOT_FLOOR_AND_ACTUAL_MAIN_PICKUP","material_name":material.name,"material_quantity":1,"target":norm(world.item_instances[TARGET]),"other":other,"stats":after_stats,"gold":world.gold,"save_path":world.save_path(),"save_sha256":FileAccess.get_sha256(world.save_path()),"scene_sha256":FileAccess.get_sha256("res://Main.tscn"),"world_sha256":FileAccess.get_sha256("res://scripts/world.gd"),"loot_sha256":LOOT_FILE_SHA,"adapter_sha256":FileAccess.get_sha256("res://tests/helpers/equipment523_native_drop_adapter.gd")}
	var file := FileAccess.open(PROOF,FileAccess.WRITE)
	check(file != null,"separate-process proof file can be written in this isolated profile")
	if file != null:
		file.store_string(JSON.stringify(proof,"",true,true));file.flush()
		check(file.get_error() == OK,"separate-process source acquisition and save proof is durable")
		file.close()
	world.queue_free()
	await process_frame
	finish()

func reload_proof() -> void:
	for arg: String in OS.get_cmdline_user_args():
		check(not arg.begins_with("--patch523-drop-root=") and not arg.begins_with("--equipment523-rules=") and not arg.begins_with("--equipment523-sha256="),"fresh process reads installed native and mechanics caches without input CLI paths")
	var proof: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROOF)) if FileAccess.file_exists(PROOF) else null
	if not check(proof is Dictionary,"first-process proof is available without inventing ownership"):
		finish("FRESH_PROCESS");return
	var native: Variant = owner()
	if not check(native != null and native.pack_identity().get("sha256") == OWNER_SHA,"fresh process public owner locates the installed native cache") or not verify_installed(native):
		finish("FRESH_PROCESS");return
	var world: Node = make_world()
	await process_frame
	if not check(is_instance_valid(world) and QA.enter_game(world),"fresh process loads actual Main and the committed character"):
		finish("FRESH_PROCESS");return
	freeze(world)
	var registered: Dictionary = world.register_native_drop_catalog()
	check(registered.get("ok",false) and world.equipment523.store.sha256 == RULE_SHA,"fresh process registers verified installed definitions and loads the mechanics active pointer")
	check(norm(world.item_instances.get(TARGET,{})) == proof.target and norm(world.item_instances.get(OTHER,{})) == proof.other,"fresh process preserves processed target provenance and untouched gear")
	check(int(world.inventory.get(str(proof.material_name),0)) == int(proof.material_quantity) and world.gold == proof.gold,"fresh process restores remaining genuinely earned material and wallet")
	check(stats(world) == proof.stats and not world.equipment523.records(world).is_empty(),"fresh process reapplies the exact saved native smelt effects to actual Main consumers")
	check(FileAccess.get_sha256(world.save_path()) == proof.save_sha256,"fresh process does not rewrite the durable save")
	check(FileAccess.get_sha256("res://Main.tscn") == proof.scene_sha256 and FileAccess.get_sha256("res://scripts/world.gd") == proof.world_sha256,"both processes use the same recorded Main scene and owner code")
	acquisition.assign(proof.acquisition)
	chosen_seed = int(proof.drop_seed);target_source = int(proof.source_item_id)
	world.queue_free()
	await process_frame
	finish("FRESH_PROCESS")

func finish(phase: String = "ACQUIRE_PROCESS_AND_SAVE") -> void:
	print("EQUIPMENT523_NATIVE_DROP_HOST_RESULT "+JSON.stringify({"checks":checks,"failures":failures,"phase":phase,"drop_seed":chosen_seed,"target_source_id":target_source,"genuine_material_acquisitions":acquisition.size(),"scope":"ACTUAL_MAIN_WITH_UNCHANGED_PUBLIC_LOOT_OWNERS_AND_EXPLICIT_TARGET_GEAR_OWNERSHIP_FIXTURE","npc_placement":"ISOLATED_ORIGINAL_FACTORY_ACTOR_NOT_MAP_HABITAT_SPAWN_PROOF","original_art_verified":false}))
	quit(0 if failures.is_empty() else 1)
