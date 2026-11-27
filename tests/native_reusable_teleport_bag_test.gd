extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const EFFECTS = preload("res://scripts/loot/source523_item_effects.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const NATIVE_SCROLL := 203402
const LEGACY_SCROLL := 295494
const ORDINARY_SCROLL := 313

var checks: int = 0
var failures: Array[String] = []
var fixture: PlayableField

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("NATIVE_REUSABLE_TELEPORT_FAIL ",label)
	return ok

func _run() -> void:
	if check(SOURCE.identity().get("source_sha256")==SOURCE.SOURCE_SHA and not OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty(),"installed original definitions and bag"):
		await _exercise()
	print("NATIVE_REUSABLE_TELEPORT_BAG_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"navigation_fixture":fixture!=null}))
	quit(0 if failures.is_empty() else 1)

func _exercise() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	world.save_timer = -100000
	if check(QA.enter_game(world,"기사"),"entered actual Main with a selected class"):
		await process_frame
		await _test_scrolls(world)
	world.queue_free()
	await process_frame

func _use(world: TwilightWorld, reference: String) -> void:
	var hud: Node = world.hud
	hud._close_workspace()
	hud.toggle_inventory()
	if not check(hud.original_inventory_is_open() and hud.original_inventory_select(reference).get("ok",false),"original bag selects "+reference):
		return
	check(hud.lineage_inventory_ui.item_action_label(reference)=="사용","selected scroll shows use")
	check(hud.original_inventory_activate_selected(reference).get("emitted",false),"selected scroll emits the original bag action")
	for frame: int in range(900):
		if not world.MAP_LOADING.busy(world): return
		await process_frame
	check(false,"map movement completes")

func _test_scrolls(world: TwilightWorld) -> void:
	var records: Dictionary = {}
	for id: int in [NATIVE_SCROLL, LEGACY_SCROLL, ORDINARY_SCROLL]:
		var record: Dictionary = world._catalog_item_from_source_id("m523:item:"+str(id))
		records[id] = record
		var contract: Dictionary = EFFECTS.teleport(record)
		if not check(contract.get("teleport_type_id")==1 and contract.get("reusable",false)==(id!=ORDINARY_SCROLL),"typed random teleport profile #"+str(id)):
			return
		if id!=ORDINARY_SCROLL:
			var areas: Variant = EFFECTS.forbidden_areas(contract)
			if not check(contract.territory_class_ids==[10103,10504] and areas is Array and areas.size()==5,"all source no-teleport areas retained #"+str(id)): return
	var wrong: Dictionary = records[NATIVE_SCROLL].duplicate()
	wrong["sourceId"] = records[LEGACY_SCROLL].sourceId
	check(EFFECTS.teleport(wrong).is_empty(),"another scroll's identity is refused")
	_check_forbidden(world, records[NATIVE_SCROLL])
	if world.field_map==null:
		check(not EFFECTS.prepare(world,records[NATIVE_SCROLL],"teleport").get("ok",false),"a missing map admits no reusable travel")
		fixture = PlayableField.new()
		fixture.configure({"map_id":world.active_map_id,"layout_revision":1,"bounds":[0,0,1024,1024],
			"spawn_position":[512,512],"navigation":{"cell_size":32,"clearance":12,"use_baked_cache":false},
			"collision":[],"regions":[],"monster_spawn":[]})
		_attach_fixture(world,Vector2(512,512))
	if not check(SUPPLY.commit(world,[{"item_class_id":NATIVE_SCROLL,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"reusable_teleport_test"}),"original scroll is granted with an exact receipt"):
		return
	var uid: String = ""
	for id: String in world.item_instances:
		if world.item_instances[id].get("record",{}).get("source_item_class_id")==NATIVE_SCROLL:
			uid = id
	if not check(not uid.is_empty(),"original physical ID is available"):
		return
	var native: String = records[NATIVE_SCROLL].name
	var ref: String = native+"@@@"+uid
	var legacy: String = records[LEGACY_SCROLL].name
	world.inventory[legacy] = 2 # Old save with no physical receipt.
	world.rng.seed = 523203402
	var origin: Vector2 = world.player.global_position
	check(world._save_game(true)==OK,"save creates the old-style and physical stock")
	await _reload(world,origin)
	var before: Vector2 = world.player.global_position
	var before_rng: int = world.rng.state
	var before_bytes: String = FileAccess.get_sha256(world.save_path())
	var before_receipt: Dictionary = STACK.proof(world,uid)
	if not check(not before_receipt.is_empty(),"the exact receipt authenticates after reload"): return
	var ledger: Dictionary = world.consumable_service.export_state()
	var preview: Dictionary = EFFECTS.prepare(world,before_receipt.record,"teleport")
	if not check(preview.get("ok",false) and world.rng.state==before_rng,"landing is proposed without advancing live RNG: "+str(preview.get("reason",""))):
		return
	world.equipment_collections.test_save_writer = func(_path: String,_payload: Dictionary) -> Error: return ERR_FILE_CANT_WRITE
	await _use(world,ref)
	check(world.player.global_position==before and world.rng.state==before_rng and STACK.proof(world,uid)==before_receipt and FileAccess.get_sha256(world.save_path())==before_bytes,"failed write restores position and preserves RNG, receipt and disk")
	world.equipment_collections.test_save_writer = Callable()
	await _reload(world,before)
	world._set_item_locked(ref,true)
	var locked_bytes: String = FileAccess.get_sha256(world.save_path())
	await _use(world,ref)
	check(world.player.global_position==before and world.rng.state==before_rng and FileAccess.get_sha256(world.save_path())==locked_bytes,"locked physical scroll cannot change the landing or RNG")
	world._set_item_locked(ref,false)
	await _use(world,ref)
	check(world.player.global_position==preview.destination and world.rng.state==int(preview.patch523_transaction_rng.state),"successful bag use publishes the exact proposed landing and RNG")
	check(world.inventory.get(native,0)==2 and STACK.proof(world,uid)==before_receipt and world.consumable_service.export_state()==ledger,"physical reuse retains both units, receipt and consumption ledger")
	var land: int = world._regional_return_land()
	await _reload(world,preview.destination)
	check(world._regional_return_land()==land and world.player.global_position.is_equal_approx(preview.destination) and world.rng.state==int(preview.patch523_transaction_rng.state),"same land, destination and committed RNG survive reload")
	var legacy_preview: Dictionary = EFFECTS.prepare(world,records[LEGACY_SCROLL],"teleport")
	if not check(legacy_preview.get("ok",false),"the second scroll has a valid landing"):
		return
	await _use(world,legacy)
	check(world.player.global_position==legacy_preview.destination and world.inventory.get(legacy,0)==2,"old name-keyed stock of the second scroll moves without debit")
	await _reload(world,legacy_preview.destination)
	check(world.inventory.get(legacy,0)==2 and world.inventory.get(native,0)==2 and STACK.proof(world,uid)==before_receipt and world.player.global_position.is_equal_approx(legacy_preview.destination),"both unspent stocks, physical receipt and second landing survive a normal reload")
	if not check(SUPPLY.commit(world,[{"item_class_id":ORDINARY_SCROLL,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"teleport_control_test"}),"ordinary teleport scroll is granted"):
		return
	var ordinary: String = records[ORDINARY_SCROLL].name
	for id: String in world.item_instances:
		if world.item_instances[id].get("record",{}).get("source_item_class_id")==ORDINARY_SCROLL:
			# New characters already hold this scroll. Supply may coalesce with it.
			var owned: Dictionary = STACK.proof(world,id)
			var count_before: int = int(world.inventory.get(ordinary,0))
			await _use(world,ordinary+"@@@"+id)
			var remaining: Dictionary = STACK.proof(world,id)
			check(int(remaining.get("remaining",0))==int(owned.get("remaining",0))-1 and int(world.inventory.get(ordinary,0))==count_before-1,
				"ordinary scroll still pays one original unit: "+world.hud.message_label.text)
			return
	check(false,"ordinary scroll has an exact receipt")

func _attach_fixture(world: TwilightWorld, position: Vector2) -> void:
	world.field_map = fixture
	world.astar = fixture.astar
	world.player.global_position = position

func _reload(world: TwilightWorld, destination: Vector2) -> void:
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	var saved: Array = disk.get("position",[]) if disk is Dictionary else []
	check(saved.size()==2 and Vector2(float(saved[0]),float(saved[1])).is_equal_approx(destination),"save records the actual landing coordinates")
	world._load_game(true)
	await process_frame
	if fixture!=null:
		# The test-only navigation is not installed in the map registry. Restore
		# it for the next bag action; position was asserted on disk above.
		_attach_fixture(world,destination)

func _check_forbidden(world: TwilightWorld, record: Dictionary) -> void:
	var areas: Array = EFFECTS.forbidden_areas(EFFECTS.teleport(record))
	var trial: Array = areas.filter(func(area: Dictionary) -> bool: return area.consume_territory_class_id==10504 and area.rect.has_area())
	if not check(not trial.is_empty(),"trial-dungeon restriction has a usable rectangle"): return
	var forbidden: Dictionary = trial[0]
	var live_field: Variant = world.field_map
	var live_position: Vector2 = world.player.global_position
	var field := OriginalPlayableField.new()
	field.definition = {"source_land_id":forbidden.land,"rules":{"teleportable":1}}
	var origin: Vector2i = forbidden.rect.position
	field.coordinates.configure([origin.x,origin.y],[1,1])
	world.field_map = field
	world.player.global_position = field.coordinates.to_world(origin)
	var rng: int = world.rng.state
	var failed: Dictionary = EFFECTS.prepare(world,record,"teleport")
	check(not failed.get("ok",false) and str(failed.get("reason","")).contains("불가 지역") and world.rng.state==rng,"original trial-dungeon region refuses use before sampling")
	world.field_map = live_field
	world.player.global_position = live_position
