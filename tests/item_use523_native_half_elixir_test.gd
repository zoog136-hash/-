extends SceneTree
## Uses the installed, SHA-pinned original archive; no synthetic source rows.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")

var checks: int = 0
var failures: Array[String] = []
var rejected_candidate: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func reject_save(_path: String, data: Dictionary) -> Error:
	rejected_candidate=data
	return ERR_CANT_CREATE

func run() -> void:
	check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA,"private pinned source")
	if failures.is_empty(): await exercise()
	print("NATIVE_HALF_ELIXIR523 ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exercise() -> void:
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer=-100000
	check(QA.enter_game(world),"Main and real class selection")
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	var owner=world.half_elixir
	world.level=50
	var refs: Dictionary={}
	var keys: Dictionary={}
	var ids: Dictionary={}
	var staged: Dictionary=INV.stage(world,[
		{"item_class_id":185094,"amount":2,"bless_raw":1,"enchant":0},
		{"item_class_id":199263,"amount":2,"bless_raw":1,"enchant":0}
	],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	check(staged.get("ok",false),"both chargers stage as native physical quantities: "+str(staged.get("error","")))
	if not staged.get("ok",false):world.queue_free();return
	world.inventory=staged.overrides.inventory
	world.item_instances=staged.overrides.item_instances
	for id: int in [185094,199263]:
		var record: Dictionary=world.source_item_record(id)
		check(STACK.profile(record).get("kind")=="half_elixir_charge","source physical rule "+str(id))
		for uid: String in world.item_instances:
			var instance: Dictionary=world.item_instances[uid]
			if int(instance.get("record",{}).get("source_item_class_id",0))!=id:continue
			keys[id]=str(instance.name); ids[id]=uid; refs[id]=str(instance.name)+"@@@"+uid
			break
	if refs.size()!=2:check(false,"physical references");world.queue_free();return
	var first: String=refs[185094]
	var first_key: String=keys[185094]
	var second_key: String=keys[199263]
	var first_id: String=ids[185094]
	var second_id: String=ids[199263]
	# Emit the precise inventory signal wired to the production Main owner.
	world.hud.inventory_item_activated.emit(first)
	check(world.inventory[first_key]==2 and owner.state.points==0,"unlinked original context preserves both sides")
	check(owner.link_bundled().get("ok",false),"link actual original growth owner")
	world.hud.inventory_item_activated.emit(first)
	check(world.inventory[first_key]==2 and owner.state.points==0,"unselected world context protects inventory")
	if owner.source==null:check(false,"half elixir source resolved");world.queue_free();return
	var context: String=str(owner.source.pairs[0])
	check(owner.execute(owner.request("context",context)).get("ok",false),"select a real original context")
	world.level=49
	world.hud.inventory_item_activated.emit(first)
	check(world.inventory[first_key]==2 and owner.state.points==0,"source minimum level blocks")
	world.level=50
	world.ui_preferences.item_locks={first:true}
	world.hud.inventory_item_activated.emit(first)
	check(world.inventory[first_key]==2 and owner.state.points==0,"locked receipt untouched")
	world.ui_preferences.item_locks={}
	world.hud.inventory_item_activated.emit(first_key+"@@@"+second_id)
	check(world.inventory[first_key]==2 and world.inventory[second_key]==2 and owner.state.points==0,"mismatched physical selection cannot spend either stack")
	check(world._save_game(true)==OK,"baseline read from durable save")
	var before: PackedByteArray=FileAccess.get_file_as_bytes(world.save_path())
	var old_state: Dictionary=owner.state.duplicate(true)
	var old_bag: Dictionary=world.inventory.duplicate(true)
	var old_instances: Dictionary=world.item_instances.duplicate(true)
	var old_rng: int=world.rng.state
	world.equipment_collections.test_save_writer=reject_save
	world.hud.inventory_item_activated.emit(first)
	check(rejected_candidate.get("half_elixir523",{}).get("points")==1 and rejected_candidate.get("inventory",{}).get(first_key)==1,"fault reaches writer with both new values in the same payload")
	check(old_state==owner.state and old_bag==world.inventory and old_instances==world.item_instances and before==FileAccess.get_file_as_bytes(world.save_path()) and old_rng==world.rng.state,"failed save rolls back points, ledger, quantities and RNG")
	world.equipment_collections.test_save_writer=Callable()
	var cap_state: Dictionary=owner.state.duplicate(true)
	cap_state.points=owner.capacity(cap_state,owner.source)
	owner.accept(cap_state)
	world.hud.inventory_item_activated.emit(first)
	check(owner.state==cap_state and world.inventory[first_key]==2,"existing source-context capacity blocks")
	owner.accept(old_state)
	world.hud.inventory_item_activated.emit(first)
	check(owner.state.points==1 and world.inventory[first_key]==1 and world.inventory[second_key]==2 and STACK.proof(world,first_id).get("remaining")==1,"first stock consumes precisely one, charges one")
	world.hud.inventory_item_activated.emit(refs[199263])
	check(owner.state.points==2 and world.inventory[second_key]==1 and STACK.proof(world,second_id).get("remaining")==1,"bound item uses only its own receipt")
	check(world.rng.state==old_rng,"deterministic original action does not consume RNG")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved.get("half_elixir523",{}).get("points")==2 and saved.get("inventory",{}).get(first_key)==1 and saved.get("inventory",{}).get(second_key)==1,"actual saved file contains points and exact remainders")
	owner.state.points=0 # Force the subsequent reload to prove restoration.
	world._load_game(true)
	check(owner.state.points==2 and world.inventory[first_key]==1 and world.inventory[second_key]==1 and STACK.proof(world,first_id).get("remaining")==1 and STACK.proof(world,second_id).get("remaining")==1,"saved points and both ledgers reload")
	world.hud.inventory_item_activated.emit(first)
	check(owner.state.points==3 and not world.item_instances.has(first_id),"last physical unit removes its live instance")
	world.hud.inventory_item_activated.emit(first)
	check(owner.state.points==3 and world.inventory[second_key]==1,"stale physical reference cannot spend twice")
	world.queue_free()
	await process_frame
