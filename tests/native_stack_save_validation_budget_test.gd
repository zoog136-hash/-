extends SceneTree
## Production validator with synthetic rows and preseeded SP2-independent
## ownership proof. No user items, real native definitions or Android timings.
const STACK := preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE := preload("res://scripts/resources/current523_definition_rows.gd")
const CONSUMABLE := preload("res://scripts/consumable_service.gd")
const GROUND := preload("res://scripts/loot/ground_loot_manager.gd")
const WAREHOUSE := preload("res://scripts/warehouse/local_warehouse.gd")
const QA := preload("res://tests/qa_class_selection.gd")
var checks: int=0
var failures: Array[String]=[]

class WorldFixture extends Node:
	var inventory: Dictionary={}
	var item_instances: Dictionary={}
	var warehouse := WAREHOUSE.new()
	var patch523_owner_state_problem: String=""
	var ground_loot := GROUND.new()
	var consumable_service := CONSUMABLE.new()
	func _ground_drops_snapshot() -> Array: return ground_loot.snapshot()

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("NATIVE_STACK_VALIDATION_FAIL ",label)

func source_row(uid: String) -> Dictionary:
	var record: Dictionary={"name":"fixture","meta":{"nested":range(16)}}
	var receipt: Dictionary={"schema":1,"origin":{"kind":"fixture"},"granted_quantity":1}
	var entry: Dictionary={"name":"fixture","record":record,STACK.RECEIPT:receipt}
	STACK._proof_cache[uid]=[entry.duplicate(true),{"receipt":receipt,"remaining":1,"used":0,"transferred":0}]
	return {"id":uid,"map_id":"aden_world","item_name":"fixture","item_record":record,"quantity":1,"player_dropped":true,
		"physical_item":{"id":uid,"data":entry},"expires_at":4000000000.0}

func seed_fixture(owner: Node,native: int,legacy: int) -> void:
	owner.add_child(owner.consumable_service)
	owner.ground_loot.configure(owner)
	STACK.clear_proof_cache()
	STACK._proof_identity=SOURCE.identity()
	for i: int in range(legacy):
		var uid: String="legacy:%d"%i
		owner.ground_loot.records[uid]={"id":uid,"map_id":"aden_world","expires_at":4000000000.0,"item_record":{"meta":{"nested":range(20)}}}
	for i: int in range(native):
		var uid: String="native:%d"%i
		owner.ground_loot.records[uid]=source_row(uid)
	var enchants: Dictionary={}
	for i: int in range(native):
		enchants[str(i)]={"row":i,"meta":{"nested":range(20)}}
	owner.consumable_service.elemental_enchants=enchants
	owner.warehouse.stacks={"legal-legacy":1}
	owner.warehouse.instances={"legacy-uid":{"name":"legal-legacy","record":{"nested":range(12)}}}

func run() -> void:
	var owner := WorldFixture.new()
	seed_fixture(owner,6,4)
	var before: Array=owner.ground_loot.snapshot()
	var detached: Dictionary=owner.consumable_service.export_state()
	var old_warehouse: Dictionary=owner.warehouse.snapshot()
	check(STACK.override_error(owner,{}).is_empty(),"live floor and warehouse save passes")
	check(STACK.override_error(owner,{"gold":777}).is_empty(),"unrelated staged save keeps native ownership")
	check(STACK.override_error(owner,{"ground_drops":before}).is_empty(),"detached identical candidate keeps all floor rows")
	check(owner.ground_loot.snapshot()==before and owner.consumable_service.export_state()==detached and owner.warehouse.snapshot()==old_warehouse,"validation never edits live/snapshot rows")
	detached.elemental_enchants["0"].meta.nested[0]=-1
	old_warehouse.instances["legacy-uid"].record.nested[0]=-1
	check(owner.consumable_service.elemental_enchants["0"].meta.nested[0]==0 and owner.warehouse.instances["legacy-uid"].record.nested[0]==0,"durable snapshots remain detached")
	var missing: Array=before.duplicate(true)
	missing.pop_back()
	check(not STACK.override_error(owner,{"ground_drops":missing}).is_empty(),"unowned removal still fails")
	# Same atomic ownership handoff through the real validator: only the
	# exact sealed floor-pickup candidate can move the receipt into the bag.
	var staged: Dictionary={"ground_drops":missing,"inventory":{"fixture":1},"item_instances":{"native:5":before[-1].physical_item.data}}
	check(not STACK.override_error(owner,staged).is_empty(),"unsealed exact floor-to-bag transition still fails")
	STACK.busy=true;STACK._candidate_kind="floor_pickup";STACK._candidate=staged.duplicate(true)
	check(STACK.override_error(owner,staged).is_empty(),"sealed exact floor-pickup still admits correct matching ownership")
	STACK._clear_floor_candidate()
	check(owner.ground_loot.snapshot()==before and owner.item_instances.is_empty(),"validation does not publish the pickup")
	var wrong_type: Array=before.duplicate(true)
	wrong_type[-1].physical_item.id=47
	check(not STACK.override_error(owner,{"ground_drops":wrong_type}).is_empty(),"numeric ID cannot match")
	var corrupted: Array=before.duplicate(true)
	corrupted[-1].physical_item.data.record.meta.nested[0]=-1
	check(not STACK.override_error(owner,{"ground_drops":corrupted}).is_empty(),"malformed/mutated physical receipt still fails")
	source_row("native:5") # restore the synthetic proof after the negative-path cache miss
	var repeated: Array=before.duplicate(true)
	repeated.append(before[-1])
	check(not STACK.override_error(owner,{"ground_drops":repeated}).is_empty(),"duplicate receipted principal rejected")
	var earlier_legacy: Array=before.duplicate(true)
	earlier_legacy.push_front({"physical_item":{"id":"native:5","data":{"name":"wrong-first"}}})
	check(not STACK.override_error(owner,{"ground_drops":earlier_legacy}).is_empty(),"earlier matching legacy ID still blocks shadowed native floor row")
	earlier_legacy.pop_front()
	earlier_legacy.append({"physical_item":{"id":"native:5","data":{"name":"wrong-later"}}})
	check(STACK.override_error(owner,{"ground_drops":earlier_legacy}).is_empty(),"later same legacy ID does not overwrite original first-match result")
	owner.ground_loot.records["legacy:0"].expires_at=0.0
	check(STACK.override_error(owner,{}).is_empty() and not owner.ground_loot.records.has("legacy:0"),"same live floor expiry boundary before validating")
	owner.patch523_owner_state_problem="fixture: blocked durable owner"
	owner.ground_loot.records["native:0"].expires_at=0.0
	check(STACK.override_error(owner,{}).is_empty() and owner.ground_loot.records.has("native:0"),"expired native floor row remains when its durable owner rejects removal")
	owner.ground_loot.records["native:1"].physical_item.data.record.meta.nested[0]=999
	check(not STACK.override_error(owner,{}).is_empty(),"in-place live floor mutation cannot reuse cached proof")
	owner.free()
	STACK.clear_proof_cache()
	var evidence: Dictionary={}
	if "--benchmark" in OS.get_cmdline_user_args(): evidence=benchmark()
	if "--main" in OS.get_cmdline_user_args(): await main_write()
	print("NATIVE_STACK_SAVE_VALIDATION_BUDGET_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)

func benchmark() -> Dictionary:
	return {"ordinary":benchmark_size(32,128),"stress":benchmark_size(450,900)}

func benchmark_size(native: int,legacy: int) -> Dictionary:
	var owner := WorldFixture.new()
	seed_fixture(owner,native,legacy)
	var snapshot: Array=owner.ground_loot.snapshot()
	var cases: Dictionary={"live":{},"staged_floor":{"ground_drops":snapshot}}
	var times: Dictionary={}
	for kind: String in cases:
		# Both revisions measure the same real validation entry point.
		var times_ms: Array=[]
		check(STACK.override_error(owner,cases[kind]).is_empty(),kind+" benchmark seeded")
		for _run: int in range(9):
			var started: int=Time.get_ticks_usec()
			var verdict: String=STACK.override_error(owner,cases[kind])
			times_ms.append(float(Time.get_ticks_usec()-started)/1000.0)
			check(verdict.is_empty(),kind+" measured validation accepted")
		times_ms.sort()
		times[kind]={"median_ms":times_ms[4],"samples_ms":times_ms}
	owner.free()
	STACK.clear_proof_cache()
	return times

func main_write() -> void:
	for name: String in DirAccess.get_files_at("user://"):
		if name.begins_with("twilight_v20_save"):
			check(false,"Main test requires isolated user directory")
			return
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000
	check(QA.enter_game(world),"Main enters through class selection")
	world.field_population.set_process(false);world.player.set_physics_process(false)
	world.player.auto_enabled=false
	world.inventory={"fixture":13}
	world.rng.seed=12345
	var path: String=world.save_path()
	check(world._save_game(true)==OK,"Main production atomic save")
	var original: String=FileAccess.get_file_as_string(path)
	var original_sha: String=FileAccess.get_sha256(path)
	var stored: Variant=JSON.parse_string(original) if not original.is_empty() else null
	check(stored is Dictionary and int(stored.inventory.get("fixture",-1))==13,"Main file owns fixture bag")
	world.equipment_collections.test_save_writer=func(_p: String,_d: Dictionary)->Error:return ERR_CANT_CREATE
	check(world._save_game(true,{"inventory":{"fixture":12}})!=OK and FileAccess.get_sha256(path)==original_sha and world.inventory=={"fixture":13},"failed staged write leaves disk and gameplay state alone")
	world.equipment_collections.test_save_writer=Callable()
	check(world._save_game(true,{"inventory":{"fixture":13}})==OK and FileAccess.get_file_as_string(path)==original,"unchanged staged write keeps exact bytes")
	print("NATIVE_STACK_BUDGET_MAIN_SHA ",original_sha)
	world.queue_free()
	await process_frame
