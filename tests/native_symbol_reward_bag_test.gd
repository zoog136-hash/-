extends SceneTree
## Exact-pack test. Two taps on the installed original slot, first on a box
## and then on its selected physical holy water, exercise the player's path.
const QA = preload("res://tests/qa_class_selection.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const TOP = preload("res://scripts/ui/original_ui/source_main_menu_bindings.gd")
const BOX = 135012
const WATER = 117304
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(good: bool, label: String) -> bool:
	checks += 1
	if not good: failures.append(label)
	return good

func frames() -> void:
	await process_frame
	await process_frame

func tap(control: Control) -> void:
	if not check(is_instance_valid(control) and control.is_visible_in_tree(), "original slot accepts touch"): return
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 10
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func use_slot(world: Node, item_id: int) -> bool:
	var controller: Node = world.hud.original_main_ui_controller
	var view: RefCounted = controller._inventory_view
	var matches: Array[String] = []
	for ref: String in view._hits:
		var uid: String = ref.get_slice("@@@", 1)
		if world.item_instances.get(uid, {}).get("record", {}).get("source_item_class_id") == item_id:
			matches.append(ref)
	if not check(matches.size() == 1, "unique visible physical slot for original ID %d" % item_id): return false
	var control: Control = view._hits[matches[0]].control
	await tap(control)
	if not check(world.hud.lineage_inventory_ui.selected_item == matches[0], "real touch selected the physical UID"): return false
	check(world.hud.lineage_inventory_ui.item_action_label(matches[0]) == "사용", "the actual original slot arms use")
	await tap(view._hits[matches[0]].control)
	await frames()
	return true

func book_rewards(world: Node) -> void:
	var craft: Script = preload("res://scripts/crafting/patch523_gacha_craft.gd")
	for id: int in [138263, 145734, 155812, 160443]:
		var spec: Dictionary = craft.spec(id)
		var table: Dictionary = craft.table(int(spec.gacha_id), craft.class_of(world))
		var roll: int = 0
		var found: bool = false
		for outcome: Dictionary in table.entries:
			if int(outcome.row.ItemClassID) == 117284:
				found = true
				break
			roll += int(outcome.weight)
		if not check(found, "authored holy-water result in book "+str(id)): continue
		var items: Array = [{"item_class_id":id, "amount":1, "bless_raw":1, "enchant":0}]
		if int(spec.material_id) != 26:
			items.append({"item_class_id":spec.material_id, "amount":spec.material_amount, "bless_raw":1, "enchant":0})
		if not check(SUPPLY.commit(world, items, {"kind":"symbol_book_regression"}), "book and its real material supplied"): continue
		world.gold = 200000000
		var owned: Dictionary = craft.stacks_of(world, id).stacks[0]
		var fields: Script = preload("res://scripts/loot/current523_native_fields.gd")
		var minimum: int = 1
		var maximum: int = 200
		for prefix: String in ["source_level_limit_", "source_max_level_limit_"]:
			minimum = maxi(minimum, int(fields.field(owned.owned.record, prefix+"min", 0)))
			var upper: int = int(fields.field(owned.owned.record, prefix+"max", 0))
			if upper > 0: maximum = mini(maximum, upper)
		world.level = clampi(85, minimum, maximum)
		var name_value: String = world._catalog_item_from_source_id("m523:item:117284").name
		var before: int = world.inventory.get(name_value, 0)
		var paid: Dictionary = craft.execute(world, id, roll, craft.SCALE-1, owned.uid, int(owned.owned.remaining))
		check(paid.get("ok",false) and paid.output.item_class_id == 117284 and world.inventory.get(name_value,0) == before+int(paid.output.amount),
			"book pays its selected original holy-water result #"+str(id)+" "+str(paid.get("reason","")))

func actual() -> void:
	root.size = Vector2i(2048, 919)
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	if not check(QA.enter_game(world), "normal Main startup"): world.queue_free(); return
	await frames()
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	var water: Dictionary = world._catalog_item_from_source_id("m523:item:"+str(WATER))
	if not check(water.get("type") == "문양 재료", "registered specialist owner"): world.queue_free(); return
	var grant: Array = [{"item_class_id":BOX, "amount":1, "bless_raw":1, "enchant":0}]
	if not check(SUPPLY.commit(world, grant, {"kind":"symbol_reward_regression"}), "grant actual original box"): world.queue_free(); return
	var controller: Node = world.hud.original_main_ui_controller
	if not check(is_instance_valid(controller), "original HUD mounted"): world.queue_free(); return
	var hot: Node = controller._menu_scene.source_nodes[TOP.INVENTORY]
	await tap(hot.get_meta("source_button")._input_area)
	await frames()
	var points: int = int(world.growth.state.points)
	var next_id: int = world.next_item_instance_id
	var old_save: String = FileAccess.get_sha256(world.save_path())
	var stock: Dictionary = world.item_instances.duplicate(true)
	var roll: int = world.rng.state
	world.equipment_collections.test_save_writer = func(_path: String, _payload: Dictionary) -> Error: return ERR_CANT_CREATE
	await use_slot(world, BOX)
	check(world.item_instances == stock and world.rng.state == roll and FileAccess.get_sha256(world.save_path()) == old_save,
		"failed reward save keeps the box, original RNG and disk")
	world.equipment_collections.test_save_writer = Callable()
	world._load_game(true)
	await frames()
	check(world.patch523_owner_state_problem.is_empty(), "normal reload verifies the last saved stock after a writer failure")
	if world.hud.original_inventory_is_open(): controller.close_inventory()
	await tap(hot.get_meta("source_button")._input_area)
	await frames()
	await use_slot(world, BOX)
	check(world.inventory.get(water.name,0) == 1 and world.growth.state.points == points, "box delivers the selected holy water as an item")
	var uid: String = ""
	for ref: String in world.item_instances:
		if world.item_instances[ref].get("record",{}).get("source_item_class_id") == WATER: uid = ref
	if check(not uid.is_empty(), "physical reward exists"):
		check(world.next_item_instance_id == next_id and world.growth.source523.recharge(world.item_instances[uid]).get("amount") == 1000, "original point amount and independent physical ID")
		world._set_item_locked(str(water.name)+"@@@"+uid, true)
		var locked: Dictionary = world.growth.execute("recharge", uid, 1, world.growth.state.revision)
		check(not locked.ok and world.item_instances.has(uid) and world.growth.state.points == points, "locked holy water cannot be charged")
		world._set_item_locked(str(water.name)+"@@@"+uid, false)
		await use_slot(world, WATER)
		print("SYMBOL_BAG_USE ", world.hud.message_label.text, " points=", world.growth.state.points)
		check(not world.item_instances.has(uid) and world.inventory.get(water.name,0) == 0 and world.growth.state.points == points+1000, "selected unit is consumed once for 1,000 points")
		world._load_game(true)
		await frames()
		check(not world.item_instances.has(uid) and world.growth.state.points == points+1000, "atomic recharge survives reload")
	var raw: Dictionary = world.source_item_definition(WATER).get("original_item", {})
	var foreign: Dictionary = water.duplicate()
	foreign["sourceId"] = "m523:item:117284"
	check(world.source_symbol_reward_record(WATER, foreign, raw).is_empty(), "same-name foreign identity rejected")
	grant[0] = {"item_class_id":WATER, "amount":1, "bless_raw":2, "enchant":0}
	var disk: String = FileAccess.get_sha256(world.save_path())
	check(not SUPPLY.stage(world, grant, {"kind":"wrong_bless"}).ok and FileAccess.get_sha256(world.save_path()) == disk, "unsupported variant preserves disk bytes")
	book_rewards(world)
	var reset: Dictionary = world._catalog_item_from_source_id("m523:item:231772")
	grant[0] = {"item_class_id":231772,"amount":1,"bless_raw":1,"enchant":0}
	if check(SUPPLY.commit(world,grant,{"kind":"symbol_reset_regression"}), "normal reset material supply"):
		if not world.hud.original_inventory_is_open(): await tap(hot.get_meta("source_button")._input_area)
		await frames()
		var state: Dictionary = world.growth.state.duplicate(true)
		await use_slot(world,231772)
		check(controller.feature_window_is_open("emblems") and world.growth.state == state and world.inventory.get(reset.name) == 1,
			"reset scroll opens the original symbol target selection with no reset or debit")
		var scroll_id: String = ""
		for key: String in world.item_instances:
			if world.growth.source523.reset_material(world.item_instances[key]): scroll_id = key
		var progress: Dictionary = world.growth.progress("eva")
		progress.attempts = 1
		world.growth.state.emblems["eva"] = progress
		var offer: Dictionary = world.growth.quote("reset","eva")
		check(offer.get("ok",false) and offer.consume_instance == scroll_id, "symbol reset quotes the exact supplied scroll")
		world._set_item_locked(str(reset.name)+"@@@"+scroll_id,true)
		check(not world.growth.quote("reset","eva").ok and world.item_instances.has(scroll_id), "symbol reset preserves the locked scroll")
	world.queue_free()
	await frames()

func run() -> void:
	var source = preload("res://scripts/growth/symbol_source523.gd").new()
	var record: Dictionary = source.item_record(WATER)
	var original: Dictionary = source.data.items[str(WATER)]
	check(not source.reward_record(WATER, record, original).is_empty(), "existing non-event material is eligible")
	var altered: Dictionary = record.duplicate()
	altered["sourceId"] = "m523:item:117284"
	check(source.reward_record(WATER, altered, original).is_empty(), "matching name with a different source ID rejected")
	if OS.get_environment("TWILIGHT_SYMBOL_REWARD_BAG") == "1": await actual()
	print("NATIVE_SYMBOL_REWARD_BAG_RESULT ", JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
