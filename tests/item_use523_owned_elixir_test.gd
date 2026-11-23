extends SceneTree

const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func reject_save(_path: String, _data: Dictionary) -> Error:
	return ERR_CANT_CREATE

func elixir_dialog(world: Node) -> ConfirmationDialog:
	for child: Node in world.get_children():
		if child is ConfirmationDialog and child.title == "엘릭서 선택" and child.visible:
			return child
	return null

func run() -> void:
	check(not SOURCE.not_installed(), "the caller-pinned private definitions are installed")
	if failures.is_empty():
		await exercise_game()
	print("OWNED_ELIXIR523_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func exercise_game() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000
	check(QA.enter_game(world),"actual Main and character entry")
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	var record: Dictionary = world.source_item_record(4151)
	check(STACK.profile(record).get("kind") == "elixir","private ItemClass 4151 resolves the exact stat rule")
	for unrelated: int in [146342,146402,146412,147152,175712]:
		check(STACK.profile(world.source_item_record(unrelated)).get("kind") != "elixir","different stat family row cannot use this owner " + str(unrelated))
	var staged: Dictionary = INV.stage(world,[{"item_class_id":4151,"amount":2,"bless_raw":1,"enchant":0}],{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	check(staged.get("ok",false),"two source elixirs enter as an ordinary physical stack")
	if not staged.get("ok",false): world.queue_free();return
	world.inventory = staged.overrides.inventory
	world.item_instances = staged.overrides.item_instances
	var name_value: String = str(record.name)
	var uid: String = ""
	for candidate: String in world.item_instances:
		if world.item_instances[candidate].get("name") == name_value:
			uid = candidate
			break
	var owned: Dictionary = STACK.proof(world,uid)
	check(int(owned.get("remaining",0)) == 2,"physical receipt proves exact quantity")
	if owned.is_empty(): world.queue_free();return
	world.level = 49
	var start_stat: int = world.str_stat
	var used: int = world.consumable_service.elixirs_used
	world._on_inventory_item_activated(name_value + "@@@" + uid)
	check(elixir_dialog(world) == null and world.inventory[name_value] == 2,"below source level gate, no UI or debit")
	world.level = 50
	world._on_inventory_item_activated(name_value + "@@@" + uid)
	var dialog := elixir_dialog(world)
	check(dialog != null and world.inventory[name_value] == 2,"real inventory activation opens a chooser without consuming")
	if dialog != null:
		dialog.canceled.emit()
		await process_frame
	check(world.str_stat == start_stat and world.inventory[name_value] == 2,"cancel preserves effect and quantity")
	check(world._save_game(true) == OK,"save baseline")
	var before: PackedByteArray = FileAccess.get_file_as_bytes(world.save_path())
	world.equipment_collections.test_save_writer = reject_save
	check(not world.consumable_service.apply_owned_elixir("STR",uid,owned.receipt,2),"failed save refuses to commit")
	check(world.inventory[name_value] == 2 and world.str_stat == start_stat and world.consumable_service.elixirs_used == used and before == FileAccess.get_file_as_bytes(world.save_path()),"save failure preserves bytes, stats, cap and quantity")
	world.equipment_collections.test_save_writer = Callable()
	world.ui_preferences.item_locks = {name_value + "@@@" + uid:true}
	check(not world.consumable_service.apply_owned_elixir("STR",uid,owned.receipt,2) and world.inventory[name_value] == 2,"lock after opening still prevents use")
	world.ui_preferences.item_locks = {}
	world.consumable_service.elixirs_used = world.consumable_service.ELIXIR_LIMIT
	check(not world.consumable_service.apply_owned_elixir("STR",uid,owned.receipt,2) and world.inventory[name_value] == 2,"shared character cap rejects without a debit")
	world.consumable_service.elixirs_used = used
	world.str_stat = world.consumable_service.STAT_CAP
	check(not world.consumable_service.apply_owned_elixir("STR",uid,owned.receipt,2) and world.inventory[name_value] == 2,"individual stat cap rejects without a debit")
	world.str_stat = start_stat
	world._on_inventory_item_activated(name_value + "@@@" + uid)
	dialog = elixir_dialog(world)
	if dialog != null: dialog.confirmed.emit()
	await process_frame
	check(world.str_stat == start_stat + 1 and world.inventory[name_value] == 1 and world.consumable_service.elixirs_used == used + 1,"confirmation commits one stat and one physical debit together")
	check(not world.consumable_service.apply_owned_elixir("STR",uid,owned.receipt,2) and world.str_stat == start_stat + 1 and world.inventory[name_value] == 1,"a stale confirmation cannot debit or grant twice")
	world._load_game(true)
	check(world.str_stat == start_stat + 1 and world.inventory.get(name_value,0) == 1 and int(STACK.proof(world,uid).get("remaining",0)) == 1,"reload keeps the stat and exact physical remainder")
	world.queue_free()
	await process_frame
