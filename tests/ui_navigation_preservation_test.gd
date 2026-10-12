extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const NavigationMemory = preload("res://scripts/ui/navigation_memory.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")
var failures: Array[String] = []
var checks: int = 0
var option_writes: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("UI_NAVIGATION FAIL: " + message)

func frames(n: int = 5) -> void:
	for i: int in range(n):
		await process_frame

func click(control: Control) -> void:
	var p: Vector2 = control.get_global_transform_with_canvas() * (control.size * .5)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = p
		event.pressed = down
		root.push_input(event, true)
	await frames()

func _run() -> void:
	var nav = NavigationMemory.new()
	nav.enter("menu", "inventory")
	check(nav.has_history() and nav.back() == "menu", "navigation stack pop")
	check(not nav.has_history(), "pop consumes one entry")
	nav.enter("menu", "skills")
	nav.enter("skills", "inventory")
	nav.returning = true
	nav.enter("inventory", "skills")
	nav.returning = false
	check(nav.back() == "skills" and nav.back() == "menu", "return never creates a loop")
	nav.enter("quickbind", "skills")
	nav.enter("dialogue", "inventory")
	check(not nav.has_history(), "transient screens without replay context are excluded")
	nav.enter("menu", "inventory")
	nav.clear_history()
	check(not nav.has_history(), "explicit close clears history")

	var controls := Control.new()
	root.add_child(controls)
	var option := OptionButton.new()
	option.name = "GameplaySetting"
	option.add_item("A")
	option.add_item("B")
	option.item_selected.connect(func(_index: int) -> void: option_writes += 1)
	controls.add_child(option)
	option.select(1)
	nav.capture("settings", controls)
	option.select(0)
	nav.restore("settings", controls)
	check(option_writes == 0 and option.selected == 0, "navigation must not replay gameplay option signals")
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
	for monster: Node in world.monsters_root.get_children():
		monster.set_physics_process(false)
	# Fixture only; snapshots below are authoritative for every navigation check.
	world.inventory["HP 물약"] = 30
	world._update_hud()
	var hud: Node = world.hud
	hud.refresh_inventory(world.inventory)
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var quickslots_before: Array = world.quickslots.duplicate(true)
	var schools_before: Dictionary = world.original_skills.catalog.schools.duplicate(true)

	hud._close_workspace()
	hud.toggle_menu()
	await frames()
	check(hud.active_section == "menu" and hud.workspace.visible, "PR91 menu remains accessible")
	check(hud.workspace.teleport_button.is_visible_in_tree(), "menu exposes existing teleport service")
	var position_before: Vector2 = world.player.global_position
	var gold_before: int = world.gold
	await click(hud.workspace.teleport_button)
	check(hud.active_section == "teleport", "native menu click opens teleport screen")
	check(world.gold == gold_before and world.player.global_position == position_before, "opening teleport never travels or spends currency")
	check(hud.workspace.back_button.visible, "contextual back button displayed")
	await click(hud.workspace.back_button)
	check(hud.active_section == "menu", "native Back returns to menu")
	hud.open_settings_info()
	await frames()
	await click(hud.workspace.compact_menu_button)
	check(hud.active_section == "menu", "compact menu shortcut returns to existing menu")

	hud.toggle_inventory()
	await frames()
	var bag: Node = hud.lineage_inventory_ui
	bag.search_line.text = "HP"
	bag.search_row.show()
	bag._refresh_inventory_grid()
	bag._select_item("HP 물약")
	bag.detail_active = true
	bag._reflow()
	hud.open_settings_info()
	await frames()
	hud._go_back()
	await frames()
	check(hud.active_section == "inventory", "Back returns to inventory")
	check(bag.search_line.text == "HP" and bag.search_row.visible, "inventory query and visible search row restored")
	check(bag.selected_item == "HP 물약" and bag.detail_active, "inventory identity and detail restored")
	hud._close_workspace()
	hud.open_skills()
	await frames()
	var skills: Node = hud.skills_view
	var old_view_id: int = skills.get_instance_id()
	check(not skills.filtered.is_empty(), "real skill records available")
	var selected_id: String = ""
	if not skills.filtered.is_empty():
		var index: int = mini(2, skills.filtered.size() - 1)
		skills.cards.select(index)
		skills.select(index)
		selected_id = str(skills.selected.get("id", skills.selected.get("name", "")))
		(skills.cards.get_parent().get_parent()).detail_active = true
		# These controls have gameplay callbacks, but programmatic selection is silent.
		skills.school_filter.select(3)
		skills.summon_order.select(3)
	hud.open_settings_info()
	await frames()
	hud._go_back()
	await frames()
	check(hud.active_section == "skills" and hud.skills_view.get_instance_id() != old_view_id, "skill screen is recreated, not reused")
	check(str(hud.skills_view.selected.get("id", hud.skills_view.selected.get("name", ""))) == selected_id, "stable skill identity restores matching details")
	check(bool(hud.skills_view.cards.get_parent().get_parent().detail_active), "skill detail/list mode restored")
	check(world.original_skills.catalog.schools == schools_before, "restoration never changes elemental school")
	hud._close_workspace()
	check(not hud.navigation_memory.has_history(), "explicit close resets navigation stack")

	var full: Rect2 = root.get_visible_rect()
	check(SafeArea._usable(full, Rect2(-20,-20,full.size.x+40,full.size.y+40)) == full, "safe area clips to viewport")
	check(SafeArea._usable(full, Rect2(99999,99999,10,10)) == full, "invalid safe area falls back to full viewport")
	var inset := Rect2(full.position + Vector2(48,24), full.size - Vector2(96,56))
	root.set_meta("twilight_test_safe_rect", inset)
	hud.toggle_menu()
	await frames()
	var panel := Rect2(hud.workspace.position, hud.workspace.size * hud.workspace.scale)
	check(inset.grow(.5).encloses(panel), "menu fits injected notch and bottom safe area")
	hud.workspace.position = Vector2(-1000,-1000)
	hud.workspace._keep_title_visible()
	panel = Rect2(hud.workspace.position, hud.workspace.size * hud.workspace.scale)
	check(inset.grow(.5).encloses(panel), "dragged inset window remains usable")
	root.remove_meta("twilight_test_safe_rect")
	hud._close_workspace()

	hud.open_combat_log()
	await frames()
	for i: int in range(130):
		hud.append_log("NAV_LOG_%d" % i)
	check(hud.combat_log_view != null and hud.combat_log_view.text.contains("NAV_LOG_129"), "open combat log updates live")
	check(hud.log_history.size() == 120 and hud.combat_log_view.text.begins_with("NAV_LOG_10"), "live log keeps existing 120-entry cap")
	hud._close_workspace()
	check(hud.combat_log_view == null, "closed log clears stale reference")
	check(world.inventory == inventory_before and world.quickslots == quickslots_before, "navigation preserves inventory and quickslots")
	check(world.quickslots.size() == 50, "PR91 fifty-slot model is retained")
	world.queue_free()
	await frames(2)
	if failures.is_empty():
		print("UI_NAVIGATION_OK: %d checks" % checks)
		quit(0)
	else:
		print("UI_NAVIGATION_FAILED: " + JSON.stringify(failures))
		quit(1)
