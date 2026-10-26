extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var hud: Node
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	assertions += 1
	if not value: failures.append(message); print("UI_POINTER FAIL: "+message)
func frames(count: int = 3) -> void:
	for i: int in range(count): await process_frame
func point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas()*(control.size*.5)
func mouse(p: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = down
	root.push_input(event,true)
func motion(p: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event,true)
func touch(p: Vector2, down: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 12
	event.position = p
	event.pressed = down
	event.canceled = canceled
	root.push_input(event,true)
func touch_motion(p: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 12
	event.position = p
	event.relative = relative
	root.push_input(event,true)
func drag(a: Vector2,b: Vector2) -> void:
	mouse(a,true)
	motion(b,b-a)
	mouse(b,false)
	await frames()
func dialog() -> Control:
	for child: Node in hud.get_node("Root").get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return child
	return null

func _run() -> void:
	root.size = Vector2i(1280,720)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(8)
	check(QA.enter_game(world),"class confirmation")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	world.player.clear_click_path()
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	hud = world.hud
	world.quickslots.clear()
	world._normalize_quickslots()
	world.ui_preferences.edited_quickslots[world.job_class] = true
	world.inventory["HP 물약"] = 30
	world._update_hud()
	hud.refresh_inventory(world.inventory)
	hud.toggle_inventory()
	await frames() # Wait for deferred navigation restoration before setting the fixture query.
	var bag: Control = hud.lineage_inventory_ui
	bag.search_line.text = "HP 물약"
	bag._refresh_inventory_grid()
	await frames(5)
	check(bag.item_grid.columns == 4,"four column default bag")
	check(bag.inventory_panel.size.x < 380,"bag minimum does not overflow shelf")
	var source: Vector2 = point(bag.slot_buttons["HP 물약"])
	var slot0: Vector2 = point(hud.v20_quickslot_buttons[0])
	var slot9: Vector2 = point(hud.v20_quickslot_buttons[9])
	var old_position: Vector2 = world.player.global_position
	# A fast inventory scroll can leave the short header on a mobile screen.
	# It must never become a world drop or consume the touched item on release.
	var above_bag: Vector2=Vector2(source.x,bag.get_global_transform_with_canvas().origin.y-32)
	touch(source,true)
	touch_motion(source-Vector2(0,35),Vector2(0,-35))
	touch_motion(above_bag,above_bag-(source-Vector2(0,35)))
	touch(above_bag,false)
	await frames()
	check(world.inventory["HP 물약"]==30 and world.player.click_path.is_empty(),"inventory flick past window edge neither drops nor uses an item")
	bag.grid_scroll.get_v_scroll_bar().value=0
	await frames()
	source=point(bag.slot_buttons["HP 물약"])
	await drag(source,slot0)
	check(world.quickslots[0].get("id","") == "HP 물약","mouse bag to real quickslot")
	check(int(world.inventory["HP 물약"]) == 30,"registration never consumes an item")
	check(world.player.global_position == old_position and world.player.click_path.is_empty(),"UI drag never issues world movement")
	touch(source,true)
	OS.delay_msec(340) # A busy render frame must not shorten a real long press.
	touch_motion(slot9,slot9-source)
	touch(slot9,false)
	await frames()
	check(world.quickslots[9].get("id","") == "HP 물약","native touch long hold registers item")
	var before_swipe: Array = world.quickslots.duplicate(true)
	touch(slot9,true)
	touch_motion(slot9-Vector2(80,0),Vector2(-80,0))
	touch(slot9-Vector2(80,0),false)
	await frames()
	check(world._quickslot_pages() == [0,1] and world.quickslots == before_swipe,"quick touch swipe changes only its page without moving a binding")
	world._on_quickslot_edit_requested("page",1,0)
	await frames()
	touch(slot9,true)
	await create_timer(.34).timeout
	var slot8: Vector2 = point(hud.v20_quickslot_buttons[8])
	touch_motion(slot8,slot8-slot9)
	touch(slot8,false)
	await frames()
	check(world._quickslot_pages() == [0,0] and world.quickslots[8].get("id","") == "HP 물약" and world.quickslots[9].is_empty(),"long hold moves a quickslot instead of changing page")
	await drag(slot8,slot9)
	await drag(slot0,slot0+Vector2(0,29))
	check(bool(world.quickslots[0].get("auto",false)),"downward gesture enables auto within same slot")
	await drag(slot0,slot0-Vector2(0,29))
	check(not bool(world.quickslots[0].get("auto",true)),"upward gesture disables auto")
	world.quickslots[0]["auto"] = true
	world._update_hud()
	await drag(slot0,point(hud.v20_quickslot_buttons[1]))
	check(world.quickslots[0].is_empty() and bool(world.quickslots[1].get("auto",false)),"move to empty keeps binding and auto together")
	await drag(point(hud.v20_quickslot_buttons[1]),Vector2(700,400))
	check(not world.quickslots[1].is_empty(),"world drop cancels rather than clearing")
	mouse(point(hud.v20_quickslot_buttons[1]),true)
	motion(Vector2(650,520),Vector2(100,-100))
	mouse(point(hud.pointer_transfer.remove_target),false)
	await frames()
	check(world.quickslots[1].is_empty() and world.inventory["HP 물약"] == 30,"explicit clear removes only binding")
	world._on_quickslot_edit_requested("page",1,4)
	await frames()
	await drag(source,slot9)
	check(world.quickslots[49].get("id","") == "HP 물약" and hud.quickslot_index(0) == 0,"right page five is independent from left")
	var previous: Dictionary = world.quickslots[49].duplicate(true)
	world._on_quickslot_assignment_requested(49,"item","화살")
	check(world.quickslots[49] == previous,"material cannot replace valid binding")
	world._on_quickslot_assignment_requested(49,"skill","removed-test-skill")
	check(world.quickslots[49] == previous,"deleted skill cannot replace valid binding")
	touch(source,true)
	await create_timer(.34).timeout
	touch(source,false,true)
	check(hud.pointer_transfer.pointer == -2 and not hud.pointer_transfer.preview.visible,"OS canceled touch clears preview")
	mouse(source,true)
	motion(slot0,slot0-source)
	root.focus_exited.emit()
	mouse(slot0,false)
	check(hud.pointer_transfer.pointer == -2 and world.quickslots[0].is_empty(),"focus loss cancels pending drop")
	mouse(source,true)
	motion(slot0,slot0-source)
	hud._close_workspace()
	mouse(slot0,false)
	check(world.quickslots[0].is_empty(),"closing source window cancels drop")
	hud.open_skills()
	var skills: Control = hud.skills_view
	skills.search.text = "라이트"
	skills.refresh()
	await frames(5)
	var item_rect: Rect2 = skills.cards.get_item_rect(0)
	var skill_point: Vector2 = skills.cards.get_global_transform_with_canvas()*item_rect.get_center()
	await drag(skill_point,slot0)
	check(world.quickslots[0].get("id","") == "라이트" and not str(world.quickslots[0].get("skill_id","")).is_empty(),"skill drag binds canonical stable ID")
	world._on_quickslot_assignment_requested(1,"skill","라이트")
	world.skill_cooldowns["라이트"] = 8.0
	hud.refresh_clock = 0
	hud._process(.2)
	check(hud.quickslot_cooldown_labels[0].text == hud.quickslot_cooldown_labels[1].text and not hud.quickslot_cooldown_labels[0].text.is_empty(),"duplicate skill bindings share real cooldown")
	var bindings: Array = world.quickslots.duplicate(true)
	world._save_game(true)
	world.quickslots.clear()
	world.ui_preferences.quickslot_pages.clear()
	world._load_game(true)
	check(world.quickslots == bindings and world._quickslot_pages() == [0,4],"binding and independent pages survive save/reload")
	world._on_job_class_selected("요정")
	world._on_quickslot_edit_requested("page",0,3)
	world._on_job_class_selected("기사")
	check(world.quickslots == bindings and world._quickslot_pages() == [0,4],"class changes restore own layout")
	for index: int in range(50): world.quickslots[index] = {}
	world.ui_preferences.edited_quickslots[world.job_class] = true
	world._save_game(true)
	world._load_game(true)
	world._ensure_quickslots_seeded()
	check(world.quickslots.all(func(entry: Dictionary) -> bool: return entry.is_empty()),"deliberately empty layout is not reseeded")
	hud.open_npc_shop()
	await frames()
	var shop: Control = hud.workspace.content.get_child(0)
	shop.search_field.text = "HP 물약"
	shop._refresh()
	shop.purchase_quantity.value = 2
	var count_before: int = int(world.inventory["HP 물약"])
	var wallet_before: int = world.gold
	shop._buy()
	check(dialog() != null and world.gold == wallet_before,"buy opens confirmation before debit")
	if dialog() != null: dialog().dismiss()
	await frames()
	check(world.gold == wallet_before and world.inventory["HP 물약"] == count_before,"cancel purchase preserves wallet and inventory")
	shop._buy()
	var confirmation: Control = dialog()
	if confirmation != null:
		confirmation._accept()
		confirmation._accept()
	await frames()
	check(world.inventory["HP 물약"] == count_before+2,"confirm commits once despite duplicate input")
	check(world.gold == wallet_before-2*world.SHOP_CATALOG.price_for("HP 물약"),"purchase uses authoritative exact total")
	hud.open_catalog("마법인형")
	await frames()
	var equipped_before: Dictionary = world.equipped_catalog["마법인형"].duplicate(true)
	hud._on_catalog_item_selected(0)
	check(world.equipped_catalog["마법인형"] == equipped_before,"card selection is separate from application")
	hud._equip_selected_catalog()
	check(dialog() != null and world.equipped_catalog["마법인형"] == equipped_before,"summon confirmation precedes application")
	if dialog() != null: dialog().dismiss()
	await frames()
	await equipment_and_services()
	hud._close_workspace()
	world.queue_free()
	await frames()
	print("UI_POINTER_RESULT ",JSON.stringify({"assertions":assertions,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func equipment_and_services() -> void:
	check(hud.lineage_side_ui.equipment_buttons.size() == world.EQUIPMENT_SLOT_ORDER.size(),"every live equipment slot has a UI target")
	world._grant_playtest_catalog_item("낡은 장검",2)
	var ids: Array[String] = []
	for id: String in world.item_instances:
		if world.item_instances[id].name == "낡은 장검": ids.append(id)
	ids.sort()
	check(ids.size() >= 2,"fixture creates distinct equipment instances")
	if ids.size() < 2: return
	var first: String = "낡은 장검@@@"+ids[0]
	var second: String = "낡은 장검@@@"+ids[1]
	world.item_instances[ids[0]]["level"] = 3
	world.item_instances[ids[1]]["level"] = 1
	world._update_hud()
	hud.toggle_inventory()
	await frames() # Opening restores the previous search on the next frame.
	var bag: Control = hud.lineage_inventory_ui
	bag.search_line.text = "낡은 장검"
	bag._refresh_inventory_grid()
	hud.show_companion_equipment()
	await frames(5)
	var source: Vector2 = point(bag.slot_buttons[first])
	var old_equipment: Dictionary = world.equipped_items.duplicate(true)
	await drag(source,point(hud.lineage_side_ui.equipment_buttons.helmet))
	check(world.equipped_items == old_equipment,"incompatible equipment target rejects without mutation")
	await drag(source,point(hud.lineage_side_ui.equipment_buttons.weapon))
	check(world.equipped_items.get("weapon",{}).get("instance_id","") == ids[0],"equipment drop equips exact physical ID")
	world._set_item_locked(first,true)
	var scrolls_before: int = int(world.inventory.get("무기 마법 주문서 (각인)",0))
	world._attempt_enhancement("무기 마법 주문서 (각인)",first)
	check(int(world.item_instances[ids[0]].level) == 3 and int(world.inventory.get("무기 마법 주문서 (각인)",0)) == scrolls_before,"locked gear cannot consume enhancement scroll")
	world._unequip_item_reference(first)
	check(not world._is_instance_equipped(ids[0]),"unequip retains the physical instance")
	world._set_item_locked(first,false)
	await frames()
	await drag(point(bag.slot_buttons[first]),point(bag.slot_buttons[second]))
	check(world.item_instances[ids[0]].level == 3 and world.item_instances[ids[1]].level == 1,"inventory reorder preserves individual enhancement values")
	check(world.ui_preferences.get("inventory_order",[]).has(first),"manual inventory order stores stable references")
	for record: Dictionary in world.catalog_db.get("아이템",[]):
		if world._equipment_slot_base(record) != "earring": continue
		var name: String = str(record.name)
		world._grant_playtest_catalog_item(name,1)
		var reference: String = ""
		for id: String in world.item_instances:
			if world.item_instances[id].name == name: reference = name+"@@@"+id; break
		if reference.is_empty(): continue
		bag.search_line.text = name
		bag._refresh_inventory_grid()
		hud.lineage_side_ui.equipment_page_index = 1
		hud.lineage_side_ui._layout_equipment()
		await frames(5)
		await drag(point(bag.slot_buttons[reference]),point(hud.lineage_side_ui.equipment_buttons.earring2))
		check(world.equipped_items.get("earring2",{}).get("instance_id","") == reference.get_slice("@@@",1),"second equipment page drops into chosen paired accessory slot")
		break
	hud.open_warehouse()
	bag.search_line.text = "HP 물약"
	bag._refresh_inventory_grid()
	await frames(5)
	var count_before: int = int(world.inventory["HP 물약"])
	await drag(point(bag.slot_buttons["HP 물약"]),point(hud.transaction_view.listing))
	check(dialog() != null and world.inventory["HP 물약"] == count_before,"warehouse drop requests quantity without moving immediately")
	if dialog() != null:
		dialog().quantity.value = 2
		dialog()._accept()
	await frames()
	check(world.inventory["HP 물약"] == count_before-2 and int(world.warehouse.stacks.get("HP 물약",0)) >= 2,"warehouse confirmed quantity uses existing storage service")
	hud.transaction_view.mode.select(1)
	hud.transaction_view._refresh()
	await frames()
	var warehouse_list: ItemList = hud.transaction_view.listing
	var warehouse_point: Vector2 = warehouse_list.get_global_transform_with_canvas()*warehouse_list.get_item_rect(0).get_center()
	await drag(warehouse_point,point(bag.grid_scroll))
	check(dialog() != null and world.inventory["HP 물약"] == count_before-2,"warehouse to bag drag requests confirmation before withdrawal")
	if dialog() != null:
		dialog().quantity.value = 2
		dialog()._accept()
	await frames()
	check(world.inventory["HP 물약"] == count_before,"warehouse withdrawal restores the exact selected quantity")
	world._set_item_locked("HP 물약",true)
	count_before = int(world.inventory["HP 물약"])
	world.hp = maxi(1,world._effective_max_hp()-500)
	world._use_quickslot_item("HP 물약")
	check(world.inventory["HP 물약"] == count_before-1,"lock does not prevent ordinary consumable use")
	var wallet_before: int = world.gold
	world._sell_shop_item("HP 물약",1,"")
	check(world.gold == wallet_before,"locked stack cannot be sold")
	world._set_item_locked("HP 물약",false)
	hud.toggle_inventory()
	await frames() # Apply this fixture query after the saved inventory view is restored.
	bag.search_line.text = "HP 물약"
	bag._refresh_inventory_grid()
	await frames(5)
	source = point(bag.slot_buttons["HP 물약"])
	mouse(source,true)
	motion(Vector2(600,400),Vector2(-300,200))
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	root.push_input(key,true)
	mouse(Vector2(600,400),false)
	check(hud.pointer_transfer.pointer == -2 and not hud.pointer_transfer.preview.visible,"Esc cancels gesture before window action")
	mouse(source,true)
	motion(Vector2(600,400),Vector2(-300,200))
	root.size = Vector2i(1920,1080)
	await frames()
	check(hud.pointer_transfer.pointer == -2,"viewport resize cancels gesture")
	mouse(Vector2(600,400),false)
	root.size = Vector2i(1280,720)

	await frames()
	hud._open_quickslot_picker("item","HP 물약","HP 물약")
	world._on_quickslot_edit_requested("page",1,4)
	await frames()
	count_before = int(world.inventory["HP 물약"])
	world.hp = 1
	world.item_use_cooldowns.clear()
	touch(point(hud.v20_quickslot_buttons[9]),true)
	touch(point(hud.v20_quickslot_buttons[9]),false)
	for down: bool in [true,false]:
		var synthetic := InputEventMouseButton.new()
		synthetic.device = InputEvent.DEVICE_ID_EMULATION
		synthetic.button_index = MOUSE_BUTTON_LEFT
		synthetic.position = point(hud.v20_quickslot_buttons[9])
		synthetic.pressed = down
		root.push_input(synthetic,true)
	check(world.quickslots[49].get("id","") == "HP 물약" and world.inventory["HP 물약"] == count_before,"button registration addresses current page without consuming its binding")
