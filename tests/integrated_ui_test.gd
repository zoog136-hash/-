extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const LAYOUT = preload("res://scripts/ui/quickslot_controller.gd")
const MENU = preload("res://scripts/ui/menu_registry.gd")
var world: Node
var hud: Node
var checks: Array = []
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func check(ok: bool, name: String) -> void:
	checks.append({"name":name,"status":"PASS" if ok else "FAIL"})
	if not ok: failures.append(name)
	print(("PASS " if ok else "FAIL: ")+name)
func frames(count: int = 3) -> void:
	for index: int in count: await process_frame
func point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * .5)
func mouse(position: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	root.push_input(event,true)
func click(control: Control) -> void:
	mouse(point(control),true)
	mouse(point(control),false)
	await frames()
func touch(control: Control, id: int = 61) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = id
		event.position = point(control)
		event.pressed = pressed
		root.push_input(event,true)
	await frames()
func key(code: Key, down: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event,true)
func named(name: String) -> Control:
	return hud.workspace.find_child(name,true,false) as Control
func drag_between(from: Control, to: Control) -> void:
	var origin := point(from)
	var destination := point(to)
	mouse(origin,true)
	for step: int in range(1,5):
		var event := InputEventMouseMotion.new()
		event.position = origin.lerp(destination,float(step)/4)
		event.relative = (destination-origin)/4
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(event,true)
		await frames(1)
	mouse(destination,false)
	await frames()

func _run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	hud = world.hud
	check(CLASS_QA.enter_game(world),"01 class selection to world")
	world.save_timer = -100000
	check(hud.v20_layer.visible and hud.v20_quickslot_buttons.size() == 8 and world.quickslots.size() == 24,"01 complete HUD and 24 slots")
	world.set_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world.self_mode_enabled = true
	var old_hp: int = world.hp
	world._on_player_poison_tick(7)
	check(world.hp < old_hp and int(hud.hp_bar.value) == world.hp,"02 real damage updates HUD")
	await click(hud.v20_layer.get_node("MainShortcuts").find_child("Shortcut_inventory",true,false))
	check(hud.active_section == "inventory" and hud.workspace.visible,"03 mouse opens inventory")
	await click(named("CloseWindow"))
	check(not hud.workspace.visible,"03 mouse closes inventory")
	# Known test-only equipment fixture through the existing acquisition command.
	var equip_record: Dictionary = {}
	for raw: Dictionary in world.catalog_db.get("아이템",[]):
		if world._equipment_slot_base(raw) == "helmet": equip_record = raw; break
	world._equip_or_acquire_item(equip_record,true)
	world._update_hud()
	var equipped: Dictionary = world._equipped_items_snapshot().get("helmet",{})
	var reference := str(equipped.get("name",""))+"@@@"+str(equipped.get("instance_id",""))
	hud._navigate("inventory")
	await frames()
	var inv: Control = hud.lineage_inventory_ui
	inv._select_item(reference)
	var attack_before: int = world._effective_attack()
	await click(inv.detail_action)
	check(not world.equipped_items.has("helmet") and int(hud.character_state.get("attack",0)) == world._effective_attack(),"04 exact equipment unequip and shared stats")
	await click(inv.detail_action)
	check(not world.equipped_items.get("helmet",{}).is_empty(),"04 re-equip owned instance")
	await click(inv.lock_button)
	check(world._item_is_locked(str(equipped.get("name","")),str(equipped.get("instance_id",""))),"04 item instance lock")
	var gold_before: int = world.gold
	world._sell_shop_item(str(equipped.get("name","")),1,str(equipped.get("instance_id","")))
	check(world.gold == gold_before,"04 locked equipment cannot be sold")
	await click(inv.lock_button)
	inv.gesture_dragged = false
	inv._select_item("HP 물약")
	await click(inv.quick_button)
	check(hud.active_section == "quickslots","05 inventory opens slot registration")
	# Scroll third page into view before interacting with its actual button.
	var assign := named("AssignQuickslot_23")
	if assign == null:
		world.queue_free()
		await process_frame
		quit(1)
		return
	var scroll: ScrollContainer = assign.get_parent().get_parent().get_parent().get_parent()
	scroll.ensure_control_visible(assign)
	await frames()
	await click(assign)
	check(world.quickslots[23].get("id","") == "HP 물약","05 inventory registers into group 3 right slot")
	hud.open_skills()
	await frames()
	var view: Node = hud.skills_view
	var skill_index: int = -1
	for index: int in view.filtered.size():
		var record: Dictionary = view.filtered[index]
		if world._is_buff_skill(record) and int(record.get("mp",0)) > 0: skill_index = index; break
	check(skill_index >= 0,"06 current job has implemented buff skill")
	if skill_index >= 0:
		view.select(skill_index)
		var skill_name := str(view.selected.get("name",""))
		await click(view.quick_button)
		await click(named("AssignQuickslot_0"))
		check(world.quickslots[0].get("id","") == skill_name,"06 skill registers through detail UI")
		hud._close_workspace()
		world.active_skill_buffs.clear()
		world.skill_cooldowns.clear()
		world.skill_global_cooldown = 0
		world.mp = world._effective_max_mp()
		world._update_hud()
		var before_mp: int = world.mp
		await click(hud.v20_quickslot_buttons[0])
		check(world.mp < before_mp and world.active_skill_buffs.has(skill_name),"08 quickslot executes real spell and consumes MP")
		check(float(world.skill_cooldowns.get(skill_name,0)) > 0 and int(hud.mp_bar.value) == world.mp,"09 cooldown and live MP")
		await frames(12)
		check(hud.cooldown_shades[0].visible,"09 cooldown shade visible")
		world.mp = 0
		world.skill_cooldowns.clear()
		hud._render_quickslots(world.inventory,{})
		world._update_hud()
		check(hud.quickslot_cooldown_labels[0].text == "MP 부족","09 MP shortage state")
		world.mp = world._effective_max_mp()
		world._update_hud()
	await click(hud.page_buttons[1])
	check(hud.quick_controller.pages == [0,1],"07 independent right page switching")
	await touch(hud.page_buttons[0])
	check(hud.quick_controller.pages == [1,1],"18 native touch changes left group")
	var persisted := LAYOUT.new()
	check(persisted.pages == [1,1],"15 pages persist across controller recreation")
	hud._change_quick_page(0,-1)
	hud._change_quick_page(1,-1)
	var prior_slots: Array = world.quickslots.duplicate(true)
	await drag_between(hud.v20_quickslot_buttons[0],hud.v20_quickslot_buttons[1])
	check(world.quickslots[1] == prior_slots[0] and world.quickslots[0] == prior_slots[1],"18 native mouse drag swaps slot entries")
	hud._open_slot_editor(23)
	await frames()
	await click(named("ToggleSlotAuto"))
	check(bool(world.quickslots[23].get("auto",false)),"05 consumable auto enable")
	await click(named("ToggleSlotAuto"))
	check(not bool(world.quickslots[23].get("auto",true)),"05 consumable auto disable")
	await click(named("ClearQuickslot"))
	check(world.quickslots[23].is_empty(),"05 clear slot")
	world._ensure_quickslots_seeded()
	check(world.quickslots[23].is_empty(),"15 clear is not reseeded")
	hud._close_workspace()
	await click(hud.v20_auto_button)
	check(world.player.auto_enabled and hud.v20_auto_button.text.contains("ON"),"10 AUTO enables existing hunting")
	world._run_auto_hunt()
	await click(hud.v20_auto_button)
	check(not world.player.auto_enabled,"10 AUTO manual stop")
	hud.open_quest_info()
	await frames()
	check(named("QuestProgress") != null,"11 quest details")
	var quest_before: int = world.quest_kills
	var victim: Node = world.monsters_root.get_child(0)
	world._on_monster_died(victim)
	check(world.quest_kills == mini(world.QUEST_GOAL,quest_before+1) and int(hud.quest_view.progress.value) == world.quest_kills,"11 kill event updates quest")
	check(int(hud.exp_bar.value) == world.experience,"02 kill experience updates HUD")
	hud._navigate("map")
	await frames()
	hud.region_selection.select(1)
	hud.region_selection.item_selected.emit(1)
	check(hud.region_selection.get_selected_items().has(1),"12 world map selects actual region")
	var destination := str(hud.map_records[1].get("id",""))
	await click(named("EnterRegion"))
	await frames(4)
	check(world.active_map_id == destination and hud.v20_layer.visible,"17 region transition retains HUD")
	hud._navigate("chat")
	await frames()
	var chat_input: LineEdit = named("ChatInput")
	chat_input.text = "ui test local record"
	await click(named("ChatSend"))
	check(hud.chat_messages.back().contains("ui test"),"13 local message records and displays")
	var channel: OptionButton = named("ChatChannel")
	channel.select(3)
	channel.item_selected.emit(3)
	check((named("ChatSend") as Button).disabled,"13 unconnected world chat never reports sent")
	# Keyboard commands must not run while entering messages in a window.
	chat_input.grab_focus()
	var position_before: Vector2 = world.player.global_position
	key(KEY_W)
	await physics_frame
	await physics_frame
	key(KEY_W,false)
	check(world.player.global_position.distance_to(position_before) < .1,"18 chat keyboard input cannot move player")
	hud._close_workspace()
	hud.toggle_menu()
	hud._navigate("skills")
	await frames()
	hud.skills_view.search.text = "카운터"
	hud.skills_view.search.text_changed.emit("카운터")
	hud._navigate("quest")
	hud.go_back()
	await frames()
	check(hud.active_section == "skills" and hud.skills_view.search.text == "카운터","14 back restores menu selection and search")
	for record: Array in MENU.ENTRIES:
		if record[0] == "exit" or record[0] == "class_select": continue
		hud._navigate(record[0])
		await frames(2)
		check(hud.workspace.visible and hud.active_section == record[0],"14 route "+str(record[0]))
		hud._close_workspace()
	hud.open_settings_info()
	await frames()
	var coord: CheckButton = named("CoordinateToggle")
	var old_coord: bool = coord.button_pressed
	await click(coord)
	hud._close_workspace()
	hud.open_settings_info()
	await frames()
	check((named("CoordinateToggle") as CheckButton).button_pressed != old_coord,"15 setting survives reopen")
	var saved_slots: Array = world.quickslots.duplicate(true)
	world._save_game(true)
	world.quickslots = []
	world._load_game(true)
	check(world.quickslots == saved_slots,"15 24 slot save and reload")
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2400,1080)]:
		root.size = extent
		await frames(5)
		hud._fit_hud()
		var logical: Rect2 = root.get_visible_rect()
		var ok := true
		for control: Control in [hud.v20_layer.get_node("StatusPanel"),hud.v20_quickslot_buttons[7],hud.v20_auto_button]:
			var rect := control.get_global_rect()
			ok = ok and logical.encloses(rect)
		check(ok,"16 HUD bounds "+str(extent))
		check(not hud.v20_target_panel.get_global_rect().intersects(hud.v20_map_name.get_parent().get_global_rect()),"16 target and region titles do not overlap "+str(extent))
		hud.open_settings_info()
		await frames(5)
		check(logical.encloses(hud.workspace.get_global_rect()),"16 menu bounds "+str(extent))
		hud._close_workspace()
	checks.append({"name":"Online chat/party and real mobile device","status":"BLOCKED","reason":"No server contract or physical mobile device"})
	var file := FileAccess.open("user://integrated-ui-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(checks,"\t"))
	print("RESULT_PATH "+ProjectSettings.globalize_path("user://integrated-ui-results.json"))
	world.queue_free()
	await process_frame
	if failures.is_empty(): print("INTEGRATED_UI_OK: %d checks" % checks.size())
	else: print("INTEGRATED_UI_FAILED: "+str(failures))
	quit(0 if failures.is_empty() else 1)
