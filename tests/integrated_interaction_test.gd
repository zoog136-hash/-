extends "res://tests/integrated_ui_test.gd"

var confirmations: int = 0

func finger(position: Vector2, pressed: bool, id: int = 71) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = position
	event.pressed = pressed
	root.push_input(event,true)

func swipe(control: Control, distance: Vector2) -> void:
	var start := point(control)
	finger(start,true)
	var event := InputEventScreenDrag.new()
	event.index = 71
	event.position = start+distance
	event.relative = distance
	root.push_input(event,true)
	finger(start+distance,false)
	await frames()

func _run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	hud = world.hud
	# Production skips its first-run picker in headless harnesses only.
	if not hud.class_picker_initial: hud.open_class_selection(true)
	await frames()
	check(named("Class_기사") != null and named("ClassConfirm") != null,"startup picker exposes class and confirmation controls")
	if named("Class_기사") == null or named("ClassConfirm") == null:
		quit(1)
		return
	await click(named("Class_기사"))
	await click(named("ClassConfirm"))
	check(not hud.class_picker_initial and not hud.workspace.visible,"startup class selection uses real mouse input")
	world.set_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	hud._navigate("inventory")
	await frames()
	var inv: Control = hud.lineage_inventory_ui
	var potion: Button = inv.slot_buttons["HP 물약"]
	inv.grid_scroll.ensure_control_visible(potion)
	await frames()
	await drag_between(potion,hud.v20_quickslot_buttons[0])
	check(world.quickslots[0].get("id","") == "HP 물약","native inventory drag registers a consumable without using it")
	hud.open_skills()
	await frames()
	var view: Node = hud.skills_view
	view.type_filter.select(1)
	view.type_filter.item_selected.emit(1)
	await frames()
	var skill_index: int = -1
	for index: int in view.filtered.size():
		if world._skill_owned_for_current_job(view.filtered[index]): skill_index = index; break
	check(skill_index >= 0,"starter has an owned active skill for drag registration")
	if skill_index < 0: quit(1); return
	view.select(skill_index)
	view.cards.ensure_current_is_visible()
	await frames()
	var skill_name: String = str(view.filtered[skill_index].get("name",""))
	var source: Vector2 = view.cards.get_global_transform_with_canvas() * view.cards.get_item_rect(skill_index).get_center()
	var destination := point(hud.v20_quickslot_buttons[1])
	mouse(source,true)
	for step: int in range(1,5):
		var motion := InputEventMouseMotion.new()
		motion.position = source.lerp(destination,float(step)/4)
		motion.relative = (destination-source)/4
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		await frames(1)
	mouse(destination,false)
	await frames()
	check(world.quickslots[1].get("id","") == skill_name,"native skill card drag registers authoritative skill")
	hud._close_workspace()
	await swipe(hud.v20_quickslot_buttons[0],Vector2(0,32))
	check(bool(world.quickslots[0].get("auto",false)),"finger swipe down enables item auto use")
	await swipe(hud.v20_quickslot_buttons[0],Vector2(0,32))
	check(not bool(world.quickslots[0].get("auto",true)),"second swipe down disables item auto use")
	await swipe(hud.v20_quickslot_buttons[0],Vector2(-42,0))
	check(hud.quick_controller.pages[0] == 1,"finger horizontal swipe changes slot group")
	hud._change_quick_page(0,-1)
	var slot_point := point(hud.v20_quickslot_buttons[0])
	finger(slot_point,true)
	await create_timer(.65).timeout
	finger(slot_point,false)
	await frames()
	check(hud.workspace.visible and named("ClearQuickslot") != null,"finger long press opens slot editor")
	hud._close_workspace()
	world.hp = 1
	world._toggle_item_lock("HP 물약")
	var count_before: int = world.inventory.get("HP 물약",0)
	world._use_potion()
	check(world.hp == 1 and world.inventory.get("HP 물약",0) == count_before,"locked healing item cannot bypass lock through HUD potion button")
	world._toggle_item_lock("HP 물약")
	world._edit_quickslot(0,"auto")
	world.player.set_auto_enabled(true)
	world._run_auto_item_quickslots(1)
	check(world.hp > 1 and world.inventory.get("HP 물약",0) == count_before-1,"AUTO consumes owned potion and heals real HP")
	world.player.set_auto_enabled(false)
	world.hp = 1
	count_before = world.inventory.get("HP 물약",0)
	world._run_auto_item_quickslots(1)
	check(world.inventory.get("HP 물약",0) == count_before,"manual stop suppresses auto consumables")
	hud.open_settings_info()
	await frames()
	hud.confirm_action("검사","취소 검증",func() -> void: confirmations += 1)
	await frames()
	check(hud.blocks_world_input(),"confirmation blocks world input")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE,false)
	await frames()
	check(confirmations == 0 and not is_instance_valid(hud.modal) and hud.workspace.visible,"ESC cancels only the top confirmation")
	hud.confirm_action("검사","확인 검증",func() -> void: confirmations += 1)
	await frames()
	await click(hud.modal.find_child("ConfirmAction",true,false))
	check(confirmations == 1 and not is_instance_valid(hud.modal),"confirmation executes once and releases input capture")
	# Synthetic cutout bounds exercise layout, not physical-device support.
	var full := root.get_visible_rect()
	var safe := Rect2(full.position+Vector2(48,24),full.size-Vector2(96,48))
	root.set_meta("twilight_test_safe_rect",safe)
	hud._fit_hud()
	await frames()
	var within := safe.encloses(hud.workspace.get_global_rect())
	for control: Control in [hud.v20_layer.get_node("StatusPanel"),hud.v20_quickslot_buttons[7],hud.joystick]:
		within = within and safe.encloses(control.get_global_rect())
	check(within,"injected mobile safe area contains menu HUD and joystick")
	hud.confirm_action("안전 영역","화면 경계 검증",func() -> void: confirmations += 1)
	await frames()
	check(safe.encloses(hud.modal.card.get_global_rect()),"confirmation fits safe area")
	await click(hud.modal.find_child("CancelAction",true,false))
	root.remove_meta("twilight_test_safe_rect")
	hud._fit_hud()
	hud._close_workspace()
	hud.toggle_menu()
	hud._navigate("skills")
	await frames()
	hud._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames()
	check(hud.active_section == "menu","mobile back notification follows menu history")
	mouse(Vector2(15,350),true)
	mouse(Vector2(15,350),false)
	await frames()
	check(not hud.workspace.visible,"outside mouse click closes workspace")
	var before: int = hud.quickslot_assignment_requested.get_connections().size()
	for cycle: int in 12:
		hud._navigate("inventory")
		hud.open_skills()
		hud._close_workspace()
		await frames(1)
	check(hud.quickslot_assignment_requested.get_connections().size() == before,"reopening windows does not multiply command connections")
	for index: int in 24: world.quickslots[index] = {}
	world.quickslots_customized = true
	check(world._save_game(true),"save command reports write success")
	world._load_game(true)
	world._ensure_quickslots_seeded()
	check(world.quickslots.all(func(entry: Dictionary) -> bool: return entry.is_empty()),"intentionally empty 24-slot configuration survives save and load")
	var file := FileAccess.open("user://integrated-interaction-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"))
	file.close()
	world.queue_free()
	await process_frame
	print("INTEGRATED_INTERACTION_OK" if failures.is_empty() else "INTEGRATED_INTERACTION_FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
