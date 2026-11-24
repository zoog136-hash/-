extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INVENTORY = preload("res://scripts/loot/patch523_item_inventory.gd")
const ENHANCE = preload("res://scripts/crafting/patch523_enhancement.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const TARGET: int=234774
const SCROLL: int=6411
var checks: int=0
var failures: Array[String]=[]

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures.append(label);printerr("PATCH523_EVENT_TOKEN_FAIL ",label)
	return ok
func check_save(world: TwilightWorld) -> Dictionary:
	var j:=JSON.new()
	if j.parse(FileAccess.get_file_as_string(world.save_path()))!=OK or not j.data is Dictionary:return {}
	ACCOUNT.expand(j.data)
	return j.data
## Compact fixture for the same transaction. Bootstrap Main without loading
## unrelated original tables, then bind just these rows from the pinned ZIP.
## Never substitute a fake item, probability or stock receipt.
func bind_targeted(world: TwilightWorld, path: String) -> bool:
	# The targeted harness attaches the archive after Main configured unrelated
	# systems. An untouched skill-awakening owner was legitimately saveable
	# before attaching; retain that test-only condition without loading its tables.
	if world.skill_awakening.blocks_save() or not world.skill_awakening.definitions_not_installed():return false
	world.skill_awakening.problem=""
	OS.set_environment("TWILIGHT_PATCH523_CONTENT",path)
	SOURCE.reset()
	if SOURCE.identity().is_empty():return false
	for id: int in [TARGET,SCROLL]:
		var k: String=str(id)
		var native: Dictionary=DROPS.definition_id(k).get("native_record",{})
		if native.is_empty():return false
		world.catalog_db["아이템"].append(native)
	world._index_catalog_item_sources()
	# The native enhancement action must not depend on these definitions
	# happening to be included in the separate legacy crafting compiler.
	world.patch523_equipment.data={}
	return true

func run() -> void:
	var targeted: String=OS.get_environment("TWILIGHT_TEST_ENHANCE_SOURCE")
	if targeted.is_empty() and SOURCE.not_installed():printerr("PATCH523_EVENT_TOKEN_REAL_PACK_REQUIRED");quit(2);return
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with("twilight_v20_save"):printerr("Isolated user data required");quit(2);return
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"actual Main character enters gameplay")
	world.field_population.set_process(false);world.player.set_physics_process(false);world.player.auto_enabled=false
	if not targeted.is_empty() and not check(bind_targeted(world,targeted),"original ZIP authenticated and exact targeted rows installed into fixture"):
		world.queue_free();await process_frame;quit(1);return
	var granted: Dictionary=INVENTORY.stage(world,[{"item_class_id":TARGET,"amount":2,"bless_raw":1,"enchant":0},{"item_class_id":SCROLL,"amount":5,"bless_raw":1,"enchant":0}], {"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not check(granted.get("ok",false),"original bulk token and scroll grant: "+str(granted.get("error",""))):
		world.queue_free();await process_frame;quit(1);return
	var initial_save: Error=world._save_game(false,granted.overrides)
	check(initial_save==OK,"actual inventory fixture saved: "+error_string(initial_save))
	world.inventory=granted.overrides.inventory;world.item_instances=granted.overrides.item_instances
	var uid: String="";var target_id: String=""
	for id: String in world.item_instances:
		var record: Dictionary=world.item_instances[id].get("record",{})
		match int(record.get("source_item_class_id",0)):
			TARGET:target_id=id
			SCROLL:uid=id
	if not check(not uid.is_empty() and not target_id.is_empty(),"both physical receipts"):
		world.queue_free();await process_frame;quit(1);return
	var name: String=world.item_instances[uid].name
	var target_name: String=world.item_instances[target_id].name
	var reference: String=target_name+"@@@"+target_id
	var selected: Dictionary=STACK.proof(world,target_id)
	check(STACK.is_enhancement_token(selected.record) and int(selected.remaining)==2 and int(world.item_instances[target_id].level)==0,"Kujak token is unwearable with a historical bulk receipt")
	var hash_before: String=FileAccess.get_sha256(world.save_path())
	var rng_before: int=world.rng.state
	var gold_before: int=world.gold
	world.hud.inventory_item_activated.emit(name+"@@@"+uid)
	var candidates: Array=world._enhancement_candidates("source","normal",name)
	check(candidates.any(func(row:Dictionary)->bool:return row.target_id==reference and row.success_chance==100.0),"actual chooser exposes exact Kuhjak +0 probability")
	check(FileAccess.get_sha256(world.save_path())==hash_before,"opening chooser writes nothing")
	world.enhancement_series_quiet=true
	var attempts: Array[Dictionary]=[]
	world.equipment_collections.test_save_writer=func(_path:String,data:Dictionary)->Error:
		attempts.append(data);return ERR_CANT_CREATE
	world.hud.enhancement_requested.emit(name,reference)
	check(attempts.size()==1,"one failed write after actual isolated-unit candidate validates")
	check(int(STACK.proof(world,target_id).get("remaining",0))==2 and int(STACK.proof(world,uid).get("remaining",0))==5 and world.rng.state==rng_before and world.gold==gold_before and FileAccess.get_sha256(world.save_path())==hash_before,"failed save preserves both receipts, rank, wallet and RNG")
	world.equipment_collections.test_save_writer=Callable()
	world.hud.enhancement_requested.emit(name,reference)
	var child: String=""
	for id: String in world.item_instances:
		if int(world.item_instances[id].get(STACK.TOKEN_RANK,0))==1:child=id
	if check(not child.is_empty(),"one ranked independent child after success"):
		var disk: Dictionary=check_save(world)
		check(int(world.inventory.get(target_name,0))==2 and int(STACK.proof(world,target_id).get("remaining",0))==1 and int(STACK.proof(world,child).get("remaining",0))==1 and int(world.item_instances[child].level)==0 and not world._is_instance_equipped(child),"parent and child conserve two units; ranked child is never equipped")
		check(int(STACK.proof(world,uid).get("remaining",0))==4 and int(disk.get("item_instances",{}).get(child,{}).get(STACK.TOKEN_RANK,0))==1,"one scroll and ranked child committed to disk")
		check(int(disk.get("consumable_state",{}).get(STACK.PARTITIONS,{}).size())==1,"one immutable partition journal entry")
		var after_split: String=FileAccess.get_sha256(world.save_path())
		world.hud.enhancement_requested.emit(name,reference)
		check(FileAccess.get_sha256(world.save_path())==after_split,"stale original target request cannot spend another scroll")
		var child_ref: String=target_name+"@@@"+child
		check(not STACK.transfer_warehouse(world,target_name,1,"deposit",child).get("ok",false),"ranked unit cannot be moved to warehouse")
		check(not STACK.drop(world,child_ref,world.player.global_position).get("ok",false),"ranked unit cannot be dropped")
		world._sell_shop_item(target_name,1,child)
		check(FileAccess.get_sha256(world.save_path())==after_split and world.patch523_owner_state_problem.is_empty(),"forbidden sale or transfers leave save and owner unchanged")
		world._load_game(true)
		check(int(world.item_instances.get(child,{}).get(STACK.TOKEN_RANK,0))==1 and int(STACK.proof(world,target_id).get("remaining",0))==1,"durable exact child rank and remainder survive reload")
		world.enhancement_series_quiet=true
		for expected: int in range(2,5):
			world.hud.inventory_item_activated.emit(name+"@@@"+uid)
			world.hud.enhancement_requested.emit(name,child_ref)
			check(int(world.item_instances.get(child,{}).get(STACK.TOKEN_RANK,0))==expected,"selected child raises without touching parent to +"+str(expected))
		var probe:=RandomNumberGenerator.new()
		for rng_seed: int in range(100):
			probe.seed=rng_seed
			if probe.randf_range(0.0,100.0)>25.0:
				world.rng.seed=rng_seed
				break
		world.hud.inventory_item_activated.emit(name+"@@@"+uid)
		world.hud.enhancement_requested.emit(name,child_ref)
		disk=check_save(world)
		var ledger: Dictionary=disk.get("consumable_state",{}).get(STACK.USES,{})
		check(not world.item_instances.has(child) and int(STACK.proof(world,target_id).get("remaining",0))==1 and int(world.inventory.get(target_name,0))==1,"original destruction closes only the selected child")
		check(not world.item_instances.has(uid) and int(ledger.get(child,{}).get("used_quantity",0))==1 and int(ledger.get(child,{}).get("remaining_quantity",-1))==0 and int(disk.get("consumable_state",{}).get(STACK.PARTITIONS,{}).size())==1,"last scroll and destroyed descendant preserve closed receipts and lineage")
		world._load_game(true)
		check(not world.item_instances.has(child) and int(STACK.proof(world,target_id).get("remaining",0))==1,"destruction and untouched parent survive reload")
	world.queue_free();await process_frame
	print("PATCH523_EVENT_TOKEN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"target":TARGET,"scroll":SCROLL}))
	quit(0 if failures.is_empty() else 1)
