extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const NavigationMemory = preload("res://scripts/ui/navigation_memory.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("UI_NAVIGATION FAIL: " + message)

func frames(n: int = 3) -> void:
	for i: int in range(n):
		await process_frame

func _run() -> void:
	# Validate the ported state machine independently of the scene.
	var nav = NavigationMemory.new()
	nav.enter("menu", "inventory")
	check(nav.has_history() and nav.back() == "menu", "navigation stack pop")
	check(not nav.has_history(), "pop consumes one entry")
	nav.enter("menu", "skills")
	nav.enter("skills", "inventory")
	nav.returning = true
	nav.enter("inventory", "skills")
	nav.returning = false
	check(nav.back() == "skills" and nav.back() == "menu", "return does not create loops")
	nav.enter("menu", "inventory")
	nav.clear_history()
	check(not nav.has_history(), "closing a window clears history")

	var controls := Control.new()
	root.add_child(controls)
	var field := LineEdit.new()
	field.name = "Filter"
	controls.add_child(field)
	var category := OptionButton.new()
	category.name = "Category"
	category.add_item("All")
	category.add_item("Skill")
	controls.add_child(category)
	var selection := ItemList.new()
	selection.name = "Items"
	selection.add_item("one")
	selection.add_item("two")
	controls.add_child(selection)
	field.text = "heal"
	category.select(1)
	selection.select(1)
	nav.capture("skills",controls)
	field.text = "changed"
	category.select(0)
	selection.deselect_all()
	nav.restore("skills",controls)
	check(field.text == "heal", "search query restored")
	check(category.selected == 1, "filter category restored")
	check(selection.get_selected_items() == PackedInt32Array([1]), "selected item restored")
	controls.queue_free()
	await process_frame

	root.size = Vector2i(1280,720)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	check(QA.enter_game(world), "class selection completes")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	var hud: Node = world.hud
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var quickslots_before: Array = world.quickslots.duplicate(true)

	hud.toggle_menu()
	await frames()
	check(hud.active_section == "menu" and hud.workspace.visible, "PR91 menu remains accessible")
	hud.open_settings_info()
	await frames()
	check(hud.active_section == "settings", "settings opens from menu")
	check(hud.workspace.back_button.visible, "contextual back control displayed")
	hud._go_back()
	await frames()
	check(hud.active_section == "menu" and hud.workspace.visible, "back returns to menu")

	hud.toggle_inventory()
	await frames()
	hud.lineage_inventory_ui.search_line.text = "HP"
	hud.lineage_inventory_ui.search_line.text_changed.emit("HP")
	hud.open_skills()
	await frames()
	hud._go_back()
	await frames()
	check(hud.active_section == "inventory", "back returns to inventory")
	check(hud.lineage_inventory_ui.search_line.text == "HP", "inventory search preserved")
	hud._close_workspace()
	check(not hud.navigation_memory.has_history(), "explicit close resets navigation stack")

	hud.open_combat_log()
	await frames()
	hud.append_log("UI_NAVIGATION_LIVE_LOG_MARKER")
	await frames(2)
	check(hud.combat_log_view != null and hud.combat_log_view.text.contains("UI_NAVIGATION_LIVE_LOG_MARKER"), "open combat log updates live")
	hud._close_workspace()
	check(hud.combat_log_view == null, "closed log clears stale reference")
	check(world.inventory == inventory_before and world.quickslots == quickslots_before, "navigation does not mutate inventory or quickslots")

	world.queue_free()
	await frames(2)
	if failures.is_empty():
		print("UI_NAVIGATION_OK: %d checks" % checks)
		quit(0)
	else:
		print("UI_NAVIGATION_FAILED: " + JSON.stringify(failures))
		quit(1)
