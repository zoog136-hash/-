extends SceneTree

const CAP = preload("res://scripts/loot/source_bonus_stat_cap523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")

var checks := 0
var failures: Array[String] = []
var refused_payload: Dictionary = {}
var completed := false
var original_bag := false


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("NATIVE_BONUS_CAP_FAIL ", message)
	return ok


func run() -> void:
	check(CAP.valid_extension(0.0) and CAP.valid_extension(CAP.MAX_EXTENSION), "valid legacy/default and largest exact JSON offsets")
	for invalid: Variant in [null, true, "1", -1, 0.5, INF, NAN, CAP.MAX_EXTENSION + 1]:
		check(not CAP.valid_extension(invalid), "reject malformed or overflowing offset " + str(invalid))
	check(CAP.profile(CAP.HEART, {}).is_empty() and CAP.profile(CAP.FRUIT, {}).is_empty(), "no source means no grant")
	check(not STACK.authorizes_bonus_stat_cap(null, {CAP.SAVE_KEY: 1}), "no unsealed growth override")
	if not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty():
		if check(SOURCE.identity().get("source_sha256") == SOURCE.SOURCE_SHA, "pinned definitions installed") \
				and check(not FileAccess.file_exists(ACCOUNT.DEFAULT_PATH), "fresh isolated user data only"):
			await exercise()
		check(completed, "all Main use/reload exercises completed")
	print("NATIVE_BONUS_CAP_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "original_bag": original_bag}))
	quit(0 if failures.is_empty() else 1)


func start_main() -> Node:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.save_timer = -100000
	await process_frame
	check(QA.enter_game(world), "actual Main character enters")
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	await process_frame
	return world


func read_save(world: Node) -> Dictionary:
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	ACCOUNT.expand(result)
	return result


func references(world: Node, item_id: int) -> Array[String]:
	var result: Array[String] = []
	for uid: String in world.item_instances:
		var entry: Dictionary = world.item_instances[uid]
		if entry.get("record", {}).get("source_item_class_id") == item_id:
			result.append(str(entry.name) + "@@@" + uid)
	return result


func remaining(world: Node, ref: String) -> int:
	return int(STACK.proof(world, ref.get_slice("@@@", 1)).get("remaining", 0))


func tap(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 6
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)


func use_bag(hud: Node, ref: String) -> void:
	var bag: Control = hud.lineage_inventory_ui
	var slot: Control
	if hud.original_inventory_is_open():
		slot = hud.original_main_ui_controller._inventory_view._hits.get(ref, {}).get("control")
	else:
		slot = bag.slot_buttons.get(ref)
	if not check(is_instance_valid(slot) and slot.is_visible_in_tree(), "actual visible inventory slot " + ref):
		return
	bag.disarm_item_action()
	var point: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5)
	tap(point)
	if check(bag.item_action_label(ref) == "사용", "first touch arms the use marker " + ref):
		tap(point)


func reject_write(_path: String, payload: Dictionary) -> Error:
	refused_payload = payload
	return ERR_CANT_CREATE


func exercise() -> void:
	root.size = Vector2i(1280, 720)
	var world: Node = await start_main()
	var hud: Node = world.hud
	world.level = 88
	world.str_stat = CAP.BASE_LIMIT
	world.dex_stat = CAP.BASE_LIMIT + 1
	world.stat_points = 2
	if not check(world._save_game(true) == OK, "seed baseline for old-save compatibility"):
		world.queue_free()
		return
	var old := read_save(world)
	old.erase(CAP.SAVE_KEY)
	ACCOUNT.selected_record(old).get("state", {}).erase(CAP.SAVE_KEY)
	check(WRITER.write(world.save_path(), old) == OK, "write fixture in legacy shape before cap field existed")
	world._load_game(true)
	check(world.bonus_stat_cap_extension == 0 and world.dex_stat == 51, "older base attributes and points are preserved")
	hud.stat_increase_requested.emit("STR")
	check(world.str_stat == 50 and world.stat_points == 2, "existing cap refuses allocation without spending")
	check(world._save_game(true, {CAP.SAVE_KEY: 1, "stat_points": 3}) != OK, "unsealed cap plus points cannot be saved")
	for id: int in [CAP.HEART, CAP.FRUIT]:
		var definition: Dictionary = world.source_item_definition(id)
		var rule: Dictionary = STACK.profile(world.source_item_record(id))
		check(rule.get("kind") == "bonus_stat_cap" and rule.get("spec", {}).get("stat_points") == int(id == CAP.FRUIT), "exact original bonus rows " + str(id))
		definition = definition.duplicate(true)
		if not definition.get("item_bonus", []).is_empty():
			definition.item_bonus[0].bonus.Value = 2
			check(CAP.profile(id, definition).is_empty(), "changed original effect refused " + str(id))
	var supplied := INV.commit(world, [
		{"item_class_id": CAP.HEART, "amount": 1, "bless_raw": 1, "enchant": 0},
		{"item_class_id": CAP.HEART, "amount": 1, "bless_raw": 1, "enchant": 0},
		{"item_class_id": CAP.FRUIT, "amount": 2, "bless_raw": 1, "enchant": 0},
	], {"kind": "twilight_debug_catalog", "initial_level_origin": "twilight_debug_default_zero"})
	var hearts := references(world, CAP.HEART)
	var fruits := references(world, CAP.FRUIT)
	if not check(supplied and hearts.size() == 2 and fruits.size() == 1, "standard supplier grants two heart objects and one two-unit fruit stack: %s (%d, %d)" % [hud.message_label.text, hearts.size(), fruits.size()]):
		world.queue_free()
		return
	world._set_item_locked(hearts[1], true)
	check(world._save_game(true) == OK, "locked sibling saved")
	var hash_before := FileAccess.get_sha256(world.save_path())
	hud.toggle_inventory()
	await process_frame
	original_bag = hud.original_inventory_is_open()
	check(OS.get_environment("TWILIGHT_SOURCE_UI").is_empty() or original_bag, "selected original inventory reached")
	use_bag(hud, hearts[0])
	check(hud.message_label.text.contains("레벨 조건") and remaining(world, hearts[0]) == 1 and FileAccess.get_sha256(world.save_path()) == hash_before, "level 88 refuses from bag and leaves disk identical")
	world.level = CAP.MIN_LEVEL
	use_bag(hud, hearts[1])
	check(remaining(world, hearts[1]) == 1 and world.bonus_stat_cap_extension == 0 and FileAccess.get_sha256(world.save_path()) == hash_before, "locked physical sibling preserved")
	use_bag(hud, hearts[0])
	await process_frame
	check(remaining(world, hearts[0]) == 0 and remaining(world, hearts[1]) == 1 and world.bonus_stat_cap_extension == 1 and world.stat_points == 2 and world.str_stat == 50, "one real heart debited, cap only +1")
	hud.inventory_item_activated.emit(hearts[0])
	check(world.bonus_stat_cap_extension == 1 and remaining(world, hearts[1]) == 1, "stale selection cannot spend another heart")

	hash_before = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = reject_write
	use_bag(hud, fruits[0])
	check(refused_payload.get(CAP.SAVE_KEY) == 2 and refused_payload.get("stat_points") == 3 \
		and refused_payload.get("item_instances", {}).get(fruits[0].get_slice("@@@", 1), {}).get(STACK.QUANTITY) == 1, "fruit debit and both bonuses reach one writer candidate")
	check(remaining(world, fruits[0]) == 2 and world.bonus_stat_cap_extension == 1 and world.stat_points == 2 and FileAccess.get_sha256(world.save_path()) == hash_before, "failed write keeps fruit, both bonuses and disk")
	world.equipment_collections.test_save_writer = Callable()
	use_bag(hud, fruits[0])
	await process_frame
	var durable := read_save(world)
	check(remaining(world, fruits[0]) == 1 and durable.get(CAP.SAVE_KEY) == 2 and durable.get("stat_points") == 3 and world.str_stat == 50, "one fruit removed and both bonuses saved")
	hash_before = FileAccess.get_sha256(world.save_path())
	world.bonus_stat_cap_extension = CAP.MAX_EXTENSION
	use_bag(hud, fruits[0])
	check(remaining(world, fruits[0]) == 1 and world.stat_points == 3 and FileAccess.get_sha256(world.save_path()) == hash_before, "unrepresentable extension leaves fruit and save intact")
	world.bonus_stat_cap_extension = 2

	hud.toggle_inventory()
	hud.lineage_side_ui._show_stats_page()
	hud.open_character()
	await process_frame
	var plus: Button = hud.lineage_side_ui.stats_page.find_child("STRPlus", true, false)
	check(plus.is_visible_in_tree() and not plus.disabled, "real stat distribution is open and accepts the raised cap")
	plus.pressed.emit()
	plus.pressed.emit()
	check(world.str_stat == 52 and world.stat_points == 1 and plus.disabled, "visible stat control spends two and then disables at the raised cap")
	hud.stat_increase_requested.emit("STR")
	check(world.str_stat == 52 and world.stat_points == 1 and world._save_game(true) == OK, "direct repeated allocation at cap keeps earned point")
	await exercise_growth_fruit(world)

	world.queue_free()
	await process_frame
	world = await start_main()
	check(world.bonus_stat_cap_extension == 3 and world.stat_points == 2 and world.str_stat == 52 and world.dex_stat == 51, "fresh Main load keeps the exact saved points, cap and bases")
	check(remaining(world, hearts[1]) == 1 and remaining(world, fruits[0]) == 1 and world._item_locked(hearts[1].get_slice("@@@", 0), hearts[1].get_slice("@@@", 1)), "restart keeps untouched receipt and lock")
	# Only this isolated fixture injects a corrupt offset.
	durable = read_save(world)
	durable[CAP.SAVE_KEY] = -1
	if durable.has(ACCOUNT.KEY):
		ACCOUNT.selected_record(durable).state[CAP.SAVE_KEY] = -1
	check(WRITER.write(world.save_path(), durable) == OK, "seed malformed owned field")
	hash_before = FileAccess.get_sha256(world.save_path())
	world._load_game(true)
	check(world.source_save_blocked and world.bonus_stat_cap_extension == 3 and world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == hash_before, "corrupt save is neither published to live state nor overwritten")
	world.queue_free()
	await process_frame
	completed = true


func exercise_growth_fruit(world: Node) -> void:
	var owner: RefCounted = world.growth96
	var hud: Node = world.hud
	var key: String = owner.Source.item_key(CAP.FRUIT)
	hud._close_workspace()
	world.experience = world.exp_need
	var claim: Dictionary = owner.execute("claim", "143", int(owner.state.revision))
	if not check(claim.get("ok", false) and world.inventory.get(key) == 1, "actual original milestone grants the growth-key fruit: " + str(claim.get("message", ""))):
		return
	var claims: Dictionary = owner.state.claims.duplicate(true)
	hud.refresh_inventory(world.inventory)
	hud.toggle_inventory()
	await process_frame
	if hud.original_inventory_is_open():
		var scrolled: Dictionary = hud.original_inventory_scroll_by(-4096.0)
		check(scrolled.get("ok", false), "latest growth reward is reached by original bag scrolling")
		await process_frame
	var hash_before := FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = reject_write
	use_bag(hud, key)
	check(world.inventory.get(key) == 1 and world.bonus_stat_cap_extension == 2 and FileAccess.get_sha256(world.save_path()) == hash_before, "failed growth fruit save leaves the original claim and stock")
	world.equipment_collections.test_save_writer = Callable()
	use_bag(hud, key)
	check(not world.inventory.has(key) and world.bonus_stat_cap_extension == 3 and world.stat_points == 2 and owner.state.claims == claims, "real growth fruit used once without altering existing reward receipts")
