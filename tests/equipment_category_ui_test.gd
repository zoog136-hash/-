extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var world: Node
var hud: Node
var checks: int = 0
var failures: Array[String] = []
var folder: String = "/tmp/category523-evidence"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("CATEGORY_UI_FAIL: "+label)
func frames(count: int = 5) -> void:
	for _i: int in range(count): await process_frame
func freeze() -> void:
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
func click(control: Control, touch: bool = false) -> void:
	await frames()
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await frames()
	var position: Vector2 = control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 12
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = down
		root.push_input(event,true)
	await frames()
func dialog() -> Control:
	for child: Node in hud.get_node("Root").get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return child
	return null
func choose(option: OptionButton, index: int) -> void:
	option.select(index)
	option.item_selected.emit(index)
func capture(name_: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name_+".png") == OK,"capture "+name_)
func live_snapshot() -> String: return JSON.stringify([world.inventory,world.item_instances,world.gold,world.inventory_automation.state])
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(12)
	check(QA.enter_game(world),"actual Main class selection")
	freeze()
	hud = world.hud
	var auto = world.inventory_automation
	check(not auto.source_rules.document.is_empty(),"actual previously verified523 private rules loaded")
	var name_: String = ""
	for raw: Variant in world.loot_catalog.by_name:
		var record: Dictionary = world.loot_catalog.by_name[raw]
		if record.get("slot") == "weapon" and record.get("grade") == "고급" and not str(raw).contains("각인") and world._find_catalog_item_record(str(raw)).get("grade") == "고급" and world.inventory.get(raw,0) == 0:
			name_ = str(raw)
			break
	check(name_ != "","use a real current catalog high-grade weapon")
	if name_ == "": world.queue_free(); await frames(); quit(1); return
	world.inventory[name_] = 4
	world._sync_item_instances()
	var ids: Array[String] = []
	for id: String in world.item_instances:
		if world.item_instances[id].name == name_: ids.append(id)
	ids.sort()
	check(ids.size() == 4,"actual world creates four distinct physical equipment IDs")
	var a: String = ids[0]
	var b: String = ids[1]
	var c: String = ids[2]
	var d: String = ids[3]
	world.item_instances[b].level = 3
	world.ui_preferences.item_locks[name_+"@@@"+c] = true
	world._update_hud()
	check(auto.set_source_only(true).ok,"prepare explicit native-only guard")
	hud.open_inventory_automation_settings("sell")
	await frames()
	var source: Control = hud.transaction_view
	for index: int in range(source.source_rows.size()):
		if int(source.source_rows[index].ItemClassID) == 45031: source.list.select(index); source._select(index); break
	check(source.register.disabled and source.category_action.visible,"virtual selector opens custom equipment action without granting an item")
	await click(source.category_action,true)
	var screen: Control = hud.transaction_view
	check(screen.selector.item_count == 4 and not screen.enabled.button_pressed and screen.slot.selected == 0 and screen.selected_targets.is_empty(),"all four native labels are inert until explicit host conditions and IDs selected")
	choose(screen.grade,1)
	choose(screen.slot,screen.slot_keys.find("weapon")+1)
	await frames()
	check(screen.candidate_buttons.has(a) and screen.candidate_buttons.has(c) and screen.candidate_buttons[c].disabled and not screen.candidate_buttons.has(b),"actual grade slot enchant filtering and locked-ID protection")
	await click(screen.enabled,true)
	await click(screen.candidate_buttons[a],true)
	check(screen.selected_targets.keys() == [a],"touch selects only one exact physical ID")
	var before: String = live_snapshot()
	var disk: String = FileAccess.get_sha256(world.save_path())
	await click(screen.find_child("EquipmentCategoryCart",true,false))
	check(dialog() == null and live_snapshot() == before,"native-only scope rejects implicit broadening")
	await click(screen.permit_custom,true)
	await click(screen.find_child("EquipmentCategoryCart",true,false))
	check(dialog() != null and live_snapshot() == before,"explicit host-scope permission opens a read-only final cart")
	await capture("category-cart-1280x720")
	await click(dialog().cancel_button,true)
	check(live_snapshot() == before and FileAccess.get_sha256(world.save_path()) == disk,"real touch cancel changes no item setting currency or disk")
	await click(screen.find_child("EquipmentCategoryActivate",true,false))
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	await click(dialog().confirm_button,true)
	check(live_snapshot() == before and FileAccess.get_sha256(world.save_path()) == disk,"actual activation save failure preserves selected scope and previous disk bytes")
	world.equipment_collections.test_save_writer = Callable()
	await click(screen.find_child("EquipmentCategoryActivate",true,false))
	await click(dialog().confirm_button,true)
	check(world.inventory[name_] == 4 and auto.state.equipment_category.enabled and auto.contains("sell",name_,a) and not auto.state.source_only,"actual activation persists exact ID and explicit source mode change without selling")
	world._load_game(true)
	freeze()
	hud.open_equipment_category_settings(45031)
	await frames()
	screen = hud.transaction_view
	check(screen.enabled.button_pressed and screen.selected_targets.keys() == [a] and screen.candidate_buttons[a].button_pressed and screen.slot_keys[screen.slot.selected-1] == "weapon","actual save reload restores own conditions and exact checked ID")
	world.inventory[name_] += 1
	world._sync_item_instances()
	var new_id: String = ""
	for id: String in world.item_instances:
		if world.item_instances[id].name == name_ and id not in ids: new_id = id
	screen._refresh()
	check(new_id != "" and not screen.candidate_buttons[new_id].button_pressed and auto.preview("sell").cart.size() == 1,"new same-name equipment stays unchecked and outside auto cart")
	check(world._save_game(true) == OK,"save isolated fixture before negative transaction checks")
	disk = FileAccess.get_sha256(world.save_path())
	await click(screen.find_child("EquipmentCategoryCart",true,false))
	world.ui_preferences.item_locks[name_+"@@@"+a] = true
	await click(dialog().confirm_button,true)
	check(world.item_instances.has(a) and FileAccess.get_sha256(world.save_path()) == disk,"lock changed after real cart invalidates commit without item loss")
	world.ui_preferences.item_locks.erase(name_+"@@@"+a)
	screen._refresh()
	before = live_snapshot()
	await click(screen.find_child("EquipmentCategoryCart",true,false))
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	await click(dialog().confirm_button,true)
	check(live_snapshot() == before and FileAccess.get_sha256(world.save_path()) == disk,"actual final sale writer failure preserves live item IDs wallet category and disk")
	world.equipment_collections.test_save_writer = Callable()
	var wallet: int = world.gold
	var payment: int = int(auto.preview("sell").payment)
	await click(screen.find_child("EquipmentCategoryCart",true,false))
	await click(dialog().confirm_button,true)
	check(not world.item_instances.has(a) and world.item_instances.has(b) and world.item_instances.has(c) and world.item_instances.has(d) and world.item_instances.has(new_id) and world.inventory[name_] == 4 and world.gold == wallet+payment,"real cart sells one approved ID and pays current quote once")
	check(auto.state.equipment_category.targets.is_empty() and not auto.contains("sell",name_,a),"consumed exact target is cleared atomically")
	await capture("category-result-1280x720")
	world._load_game(true)
	freeze()
	check(world.inventory[name_] == 4 and world.gold == wallet+payment and auto.state.equipment_category.targets.is_empty() and auto.preview("sell").cart.is_empty(),"completed transaction survives actual reload without selecting replacements or replaying")
	check(auto.set_target("sell",name_,d,true,1).ok,"preserve an independent keep-one exact-ID rule")
	hud.open_equipment_category_settings(45031)
	await frames()
	screen = hud.transaction_view
	screen.max_enchant.value = 3
	await frames()
	check(screen.candidate_buttons.has(b) and screen.candidate_buttons[d].disabled,"configurable enchant scope and existing manual retention shown")
	await click(screen.candidate_buttons[b],true)
	root.size = Vector2i(854,480)
	DisplayServer.window_set_size(root.size)
	hud._fit_hud()
	await click(screen.find_child("EquipmentCategoryActivate",true,false))
	await capture("category-small-cart-854x480")
	await click(dialog().confirm_button,true)
	check(auto.contains("sell",name_,b),"small-screen touch confirms exact-ID activation")
	await click(screen.find_child("EquipmentCategoryDisable",true,false),true)
	check(not auto.state.equipment_category.enabled and not auto.contains("sell",name_,b) and auto.contains("sell",name_,d),"actual disable preserves separately registered manual target")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	saved.inventory_automation.equipment_category = {"version":2}
	var file := FileAccess.open(world.save_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(saved));file.close()
	disk = FileAccess.get_sha256(world.save_path())
	before = live_snapshot()
	world._load_game(true)
	freeze()
	check(world.equipment_collections.save_blocked and live_snapshot() == before and world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == disk,"actual malformed category save rejects before mutation and preserves disk")
	print("EQUIPMENT_CATEGORY_UI: %d checks, %d failures" % [checks,failures.size()])
	world.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
