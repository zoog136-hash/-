extends SceneTree
## Actual Main entry, close/reopen and save-byte preservation with no fake stock.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func run() -> void:
	root.size = Vector2i(960,540)
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	check(QA.enter_game(world),"actual Main class selection")
	world.player.set_physics_process(false)
	check(world._save_game(true) == OK,"isolated actual Main save")
	var path: String = world.save_path()
	var bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var inventory: Dictionary = world.inventory.duplicate(true)
	var instances: Dictionary = world.item_instances.duplicate(true)
	var gold: int = int(world.gold)
	world.hud.toggle_menu()
	check(world.hud.menu_page != null,"actual menu remains available")
	world.hud.open_frozen_exchange()
	await process_frame
	var panel: Node = world.hud.workspace.find_child("FrozenExchangePanel",true,false)
	check(panel != null and panel.is_visible_in_tree(),"actual Main exchange panel opens")
	if panel != null:
		check(panel.status.text.contains("수집 대기"),"incomplete live capture disclosed")
		check(panel.listing.item_count == 0 and panel.review.disabled and not panel.confirm.visible,"no synthetic listing or enabled payment")
		panel.search.text = "없는 상품";panel._filter()
		check(panel.listing.item_count == 0,"empty search cannot generate stock")
	world.hud._close_workspace()
	await process_frame
	check(not world.hud.workspace.visible,"close actually dismisses workspace")
	world.hud.open_frozen_exchange()
	await process_frame
	panel = world.hud.workspace.find_child("FrozenExchangePanel",true,false)
	check(panel != null and panel.listing.item_count == 0,"reopen has no stale confirmation or stock")
	check(world.inventory == inventory and world.item_instances == instances and int(world.gold) == gold,"browsing preserves wallet and physical items")
	check(FileAccess.get_file_as_bytes(path) == bytes_before,"browse close and reopen preserve save bytes")
	world.queue_free()
	await process_frame
	print("FROZEN_EXCHANGE_MAIN_RESULT checks=%d failures=%d absent_capture_path_only" % [checks,failures])
	quit(1 if failures else 0)
