extends SceneTree

const SLOTS = preload("res://scripts/loot/source_slot_expanders523.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const ACCOUNT = preload("res://scripts/characters/account_store.gd")
const WRITER = preload("res://scripts/skills/save_writer.gd")
const QA = preload("res://tests/qa_class_selection.gd")
const STRENGTH := 882
const DEXTERITY := 883
const RUNE_PAGE_PATH := "UI/FloatingUi/CharacterInfo_EquipSlotSet_B.csb"

var world: Node
var hud: Node
var checks := 0
var failures: Array[String] = []
var candidate: Dictionary = {}
var reached_end := false


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("NATIVE_RUNE_SLOT_FAIL ", message)
	return ok


func run() -> void:
	check(SLOTS.save_problem(false, {}, {}).is_empty(), "old save has one existing rune slot")
	check(not SLOTS.save_problem(1, {}, {}).is_empty(), "malformed unlock rejected")
	check(not SLOTS.save_problem(false, {"rune2": {"instance_id":"7"}}, {}).is_empty(), "closed slot cannot wear gear")
	check(SLOTS.save_problem(true, {"rune2": {}}, {}).is_empty(), "open empty slot persists")
	check(not STACK.authorizes_rune_slot(null, {SLOTS.RUNE_KEY:true}), "unsealed gear unlock always rejected")
	if not OS.get_environment("TWILIGHT_PATCH523_CONTENT").is_empty():
		if check(SOURCE.identity().get("source_sha256") == SOURCE.SOURCE_SHA, "pinned current source") \
				and check(not FileAccess.file_exists(ACCOUNT.DEFAULT_PATH), "isolated save required"):
			await exercise()
		check(reached_end, "all controlled Main steps reached")
	print("NATIVE_RUNE_SLOT_RESULT ", JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)


func start_main() -> void:
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_process(false)
	world.save_timer = -100000
	await process_frame
	check(QA.enter_game(world), "actual Main entered")
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.auto_enabled = false
	hud = world.hud
	await process_frame


func references(item_id: int) -> Array[String]:
	var result: Array[String] = []
	for uid: String in world.item_instances:
		var entry: Dictionary = world.item_instances[uid]
		if entry.get("record", {}).get("source_item_class_id") == item_id:
			result.append(str(entry.name) + "@@@" + uid)
	return result


func worn(slot: String) -> String:
	return str(world.equipped_items.get(slot, {}).get("instance_id", ""))


func remaining(ref: String) -> int:
	return int(STACK.proof(world, ref.get_slice("@@@", 1)).get("remaining", 0))


func disk() -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	ACCOUNT.expand(data)
	return data


func tap(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 6
		event.pressed = pressed
		event.position = point
		root.push_input(event, true)


func bag_action(ref: String, marker: String) -> void:
	var bag: Control = hud.lineage_inventory_ui
	if not hud.original_inventory_is_open():
		hud.toggle_inventory()
		await process_frame
	if not check(hud.original_inventory_is_open(), "selected original bag open"):
		return
	var view: RefCounted = hud.original_main_ui_controller._inventory_view
	var slot: Control
	# The native bag materializes only visible rows.
	hud.original_inventory_scroll_by(4096.0)
	for attempt: int in range(4):
		slot = view._hits.get(ref, {}).get("control")
		if is_instance_valid(slot) and view.hit_at(slot.get_global_transform_with_canvas() * (slot.size * 0.5)).get("reference") == ref:
			break
		slot = null
		hud.original_inventory_scroll_by(-164.0)
		await process_frame
	if not check(is_instance_valid(slot), "visible original slot for " + ref):
		return
	bag.disarm_item_action()
	var point: Vector2 = slot.get_global_transform_with_canvas() * (slot.size * 0.5)
	tap(point)
	if check(bag.item_action_label(ref) == marker, "first touch arms " + marker):
		tap(point)
	await process_frame


func reject_write(_path: String, payload: Dictionary) -> Error:
	candidate = payload
	return ERR_CANT_CREATE


func exercise() -> void:
	root.size = Vector2i(1280, 720)
	await start_main()
	check(SLOTS.rune_pouch(world.source_item_definition(SLOTS.RUNE_POUCH)), "exact source pouch and second Rune lane")
	check(SLOTS.character_seal(world.source_item_definition(SLOTS.CHARACTER_SEAL)) and ACCOUNT.MAX_CHARACTERS == 13, "exact source seal and existing 13 slot cap")
	check(SLOTS.exact_rune(world.source_item_definition(STRENGTH).get("native_record", {})) \
		and SLOTS.exact_rune(world.source_item_definition(DEXTERITY).get("native_record", {})), "both exact original Rune slot IDs")
	# Clear unrelated starter stock only in this disposable Main fixture.
	world.inventory = {}
	world.item_instances = {}
	world.equipped_items = world._empty_equipment_slots()
	var grants: Array = []
	for id: int in [STRENGTH, STRENGTH, DEXTERITY, SLOTS.RUNE_POUCH, SLOTS.RUNE_POUCH, SLOTS.CHARACTER_SEAL]:
		grants.append({"item_class_id":id,"amount":1,"bless_raw":1,"enchant":0})
	if not check(INV.commit(world, grants, {"kind":"qa_original_slot_expanders"}), "production supplier stages native receipts and rune objects: " + hud.message_label.text):
		world.queue_free()
		return
	var strength_refs := references(STRENGTH)
	var strength := strength_refs[0]
	var dexterity := references(DEXTERITY)[0]
	var pouches := references(SLOTS.RUNE_POUCH)
	var seal := references(SLOTS.CHARACTER_SEAL)[0]
	world.level = 87
	await bag_action(strength, "장착")
	check(worn("rune") == strength.get_slice("@@@", 1) and worn("rune2").is_empty(), "primary original rune equipped through the bag")
	check(world._save_game(true) == OK and not disk().has(SLOTS.RUNE_KEY), "old-style save with a primary rune and no unlock field")
	var old := disk()
	world._load_game(true)
	check(not world.rune_slot2_unlocked and worn("rune") == strength.get_slice("@@@", 1), "old save loads exact original first rune")
	world._equip_reference_in_slot(dexterity, "rune2")
	check(worn("rune2").is_empty(), "closed rune slot rejects explicit equipment action")
	var hash_before := FileAccess.get_sha256(world.save_path())
	await bag_action(pouches[0], "사용")
	check(hud.message_label.text.contains("레벨 조건") and not world.rune_slot2_unlocked \
		and remaining(pouches[0]) == 1 and FileAccess.get_sha256(world.save_path()) == hash_before, "level 87 refuses with no debit")
	check(world._save_game(true, {SLOTS.RUNE_KEY:true}) != OK, "unsealed slot write rejected")

	world.level = SLOTS.RUNE_LEVEL
	world.equipment_collections.test_save_writer = reject_write
	await bag_action(pouches[0], "사용")
	check(candidate.get(SLOTS.RUNE_KEY) == true and not candidate.get("item_instances", {}).has(pouches[0].get_slice("@@@", 1)), "one physical pouch and the unlock reach the same save")
	check(not world.rune_slot2_unlocked and remaining(pouches[0]) == 1 and FileAccess.get_sha256(world.save_path()) == hash_before, "failed writer keeps closed slot, stock and disk")
	world.equipment_collections.test_save_writer = Callable()
	await bag_action(pouches[0], "사용")
	check(world.rune_slot2_unlocked and disk().get(SLOTS.RUNE_KEY) == true and remaining(pouches[0]) == 0 and remaining(pouches[1]) == 1, "successful unlock consumes only the selected pouch")
	hash_before = FileAccess.get_sha256(world.save_path())
	await bag_action(pouches[1], "사용")
	check(hud.message_label.text.contains("이미") and remaining(pouches[1]) == 1 and FileAccess.get_sha256(world.save_path()) == hash_before, "duplicate original pouch keeps stock and disk")
	await bag_action(seal, "사용")
	check(hud.message_label.text.contains("13개") and remaining(seal) == 1 and FileAccess.get_sha256(world.save_path()) == hash_before, "fixed thirteen-slot policy preserves the original seal")
	await bag_action(strength_refs[1], "장착")
	check(worn("rune") == strength.get_slice("@@@", 1) and worn("rune2").is_empty() \
		and hud.message_label.text.contains("장착 제한"), "source protects against equipping the same rune class in both slots")

	var before_dexterity: int = world._effective_attribute("DEX")
	await bag_action(dexterity, "장착")
	check(worn("rune") == strength.get_slice("@@@", 1) and worn("rune2") == dexterity.get_slice("@@@", 1), "bag equips the second rune without replacing the first")
	check(world._effective_attribute("DEX") == before_dexterity + 1, "the second rune publishes its exact DEX bonus")
	check(world._save_game(true) == OK, "save both worn physical IDs")
	var durable := disk()
	var restore_problem: String = SLOTS.save_problem(durable.get(SLOTS.RUNE_KEY, false), durable.equipped_items, durable.item_instances)
	check(restore_problem.is_empty(), "the real compact save can verify the physical rune before expansion: " + restore_problem)
	var template_store: Object = FIELDS._store
	var weight_script: Script = FIELDS._weight_script
	FIELDS.bind(null)
	restore_problem = SLOTS.save_problem(durable.get(SLOTS.RUNE_KEY, false), durable.equipped_items, durable.item_instances)
	FIELDS.bind(template_store, weight_script)
	check(restore_problem.is_empty(), "the roster can validate the compact rune save before Main attaches templates: " + restore_problem)
	world.queue_free()
	await process_frame
	await start_main()
	check(world.rune_slot2_unlocked and worn("rune") == strength.get_slice("@@@", 1) and worn("rune2") == dexterity.get_slice("@@@", 1), "fresh Main restores both exact worn IDs and unlock: " + hud.message_label.text)
	hud.open_character()
	await process_frame
	var character: RefCounted = hud.original_main_ui_controller._character_view
	var equipment_status: Dictionary = hud.original_main_ui_status.get("character_equipment", {})
	if check(character.is_open() and character._mode == "equipment", "actual original equipment page open: " + str(equipment_status.get("code", equipment_status.get("error", "")))):
		var contract: Dictionary = character._equipment.build(RUNE_PAGE_PATH)
		check(contract.get("ok", false) and contract.get("bindings", {}).get(5996, {}).get("visible") == true \
			and contract.get("owner_results", {}).has(5996), "original Slot_Loon_1 binds the second native rune icon")
		character._page_view.set_page_index(1)
		var renderer: Node = character._page_view._pages[1].renderer
		var original: Dictionary = renderer.project_player([5996])
		var icon: Node2D = original.player.source_nodes.get(15012) if original.get("ok", false) else null
		check(is_instance_valid(icon) and original.player.is_visible_in_tree() \
			and icon.is_visible_in_tree(), "the second rune and its icon render in the actual original equipment page")
	hud._close_workspace()
	await bag_action(dexterity, "해제")
	check(worn("rune2").is_empty() and worn("rune") == strength.get_slice("@@@", 1) \
		and world.item_instances.has(dexterity.get_slice("@@@", 1)) and world._effective_attribute("DEX") == before_dexterity, "bag unequips only the selected second rune and keeps ownership")
	check(world._save_game(true) == OK and disk().get(SLOTS.RUNE_KEY) == true, "unequip preserves the permanent unlock")

	hud._close_workspace()
	check(WRITER.write(world.save_path(), old) == OK, "restore isolated old fixture for independent earned reward")
	world._load_game(true)
	world.level = 88
	world.experience = world.exp_need
	var growth: RefCounted = world.growth96
	var claim: Dictionary = growth.execute("claim", "114", int(growth.state.revision))
	var growth_key: String = growth.Source.item_key(SLOTS.RUNE_POUCH)
	if check(claim.get("ok", false) and world.inventory.get(growth_key) == 1, "real growth milestone gives the exact pouch"):
		hud.refresh_inventory(world.inventory)
		var prior_claims: Dictionary = growth.state.claims.duplicate(true)
		await bag_action(growth_key, "사용")
		check(world.rune_slot2_unlocked and not world.inventory.has(growth_key) and remaining(pouches[0]) == 1 \
			and growth.state.claims == prior_claims and disk().get(SLOTS.RUNE_KEY) == true, "earned growth pouch unlocks once and preserves the original claim and other stock")
	world.queue_free()
	await process_frame
	reached_end = true
