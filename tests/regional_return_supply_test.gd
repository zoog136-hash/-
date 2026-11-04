extends SceneTree
const RULE = preload("res://scripts/quickslots/regional_return.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const SUPPLY_WORLD = preload("res://tests/regional_return_supply_world_fixture.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("REGIONAL_SUPPLY_FAIL ", label)

func run() -> void:
	if OS.get_environment("TWILIGHT_REGIONAL_RETURN_TEST") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		printerr("REGIONAL_RETURN_TEST_REQUIRES_ISOLATED_XDG_PROFILE")
		quit(2); return
	var world = load("res://Main.tscn").instantiate()
	world.set_script(SUPPLY_WORLD)
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(world.supply_problem.is_empty(), "exact verified PR238 input")
	if not world.supply_problem.is_empty(): world.queue_free(); quit(1); return
	check(QA.enter_game(world), "actual Main startup with supplier catalogue fixture")
	world.player.set_physics_process(false)
	var native: Dictionary = world.supply_record
	var key: String = str(native.name)
	check(key == "귀환 주문서 (각인) · 원본#239", "actual supplier stack spelling")
	check(world.regional_return_stack(key).item_class_id == 239 and not world.regional_return_stack(key).infinite, "native identity and finite bonus")
	var membership: bool = false
	for row: Dictionary in world.supply_document.drops["6001"]:
		if int(row.ID) == 529791 and int(row.ItemClassID) == 239 and int(row.Bless) == 1 and int(row.RequiredQuestID) == 0: membership = true
	check(membership, "exact non-test red-orc membership row")
	for missing: String in ["126424", "282783", "295514"]:
		check(not world.supply_document.item_definitions.has(missing), "no invented supply for "+missing)
	var wrong: Dictionary = native.duplicate(true)
	wrong.source_item_class_id = 126424
	check(RULE.stack_identity(key, wrong).is_empty(), "wrong typed ID rejected")
	wrong = native.duplicate(true); wrong.source_snapshot = "base508"
	check(RULE.stack_identity(key, wrong).is_empty(), "different snapshot rejected")
	wrong = native.duplicate(true); wrong.source_bless_raw = 2
	check(RULE.stack_identity(key, wrong).is_empty(), "Normal stack cannot claim blessing variant")
	check(RULE.stack_identity(key, {}).is_empty(), "name suffix without registered metadata rejected")
	check(RULE.stack_identity("유일한 귀환 주문서 (각인)").infinite and RULE.stack_identity("무한한 귀환 주문서 (각인)").infinite, "both pinned infinite identities preserved")
	# Controlled supply into the existing floor/pickup path, not an NPC kill or shop sale.
	world.inventory["귀환 주문서"] = 10
	var drop: Button = world.ground_loot.spawn(key, world.player.global_position, 2, "", {"item_record":native})
	check(is_instance_valid(drop) and int(world.inventory.get(key, 0)) == 0, "floor exists before inventory credit")
	if not is_instance_valid(drop): world.queue_free(); quit(1); return
	# The production gate uses monotonic wall time, not SceneTreeTimer delta.
	while Time.get_ticks_msec()-drop.visible_since < world.ground_loot.MIN_VISIBLE_MS:
		await process_frame
	check(world._collect_ground_drop(drop), "existing floor lifetime/range/visibility pickup consumer")
	check(int(world.inventory.get(key, 0)) == 2 and world.inventory["귀환 주문서"] == 10, "native and legacy keys remain separate")
	world._on_quickslot_assignment_requested(0, "item", key)
	check(world.quickslots[0].id == key, "inventory registration preserves supplied key")
	world._on_quickslot_pressed(0)
	check(int(world.inventory.get(key, 0)) == 1 and world.inventory["귀환 주문서"] == 10, "direct return consumes only supplied Normal key")
	world.inventory["잊혀진 귀환 주문서 (각인)"] = 3 # target supply fixture; absent from this provider
	world.set_regional_return_enabled(true)
	world._set_map("source_70", false)
	check(world.hud.quickslot_entries[0].id == "잊혀진 귀환 주문서 (각인)" and world.quickslots[0].id == key, "native base slot projects without rewriting source key")
	world._on_quickslot_pressed(0)
	check(world.inventory["잊혀진 귀환 주문서 (각인)"] == 2 and world.inventory.get(key,0) == 1, "regional consumer spends target only")
	check(world._save_game(true) == OK, "supplier-key state saved")
	world.inventory[key] = 99
	world._load_game(true)
	check(world.inventory.get(key,0) == 1 and world.quickslots[0].id == key and world.hud.quickslot_entries[0].id == "잊혀진 귀환 주문서 (각인)", "source key and UI survive load")
	world.set_regional_return_enabled(false)
	check(world.hud.quickslot_entries[0].id == key, "turning off restores native supplier name")
	world.set_regional_return_enabled(true)
	check(world._save_game(true) == OK, "restart fixture committed")
	world.queue_free()
	await process_frame
	print("REGIONAL_SUPPLY_RESULT ", JSON.stringify({"checks":checks,"failures":failures,"supplier_execution":"not run; exact supplier record through controlled floor input","ordinary_target_acquisition":"not implemented"}))
	quit(0 if failures.is_empty() else 1)
