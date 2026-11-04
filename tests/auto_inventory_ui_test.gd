extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var world: Node
var hud: Node
var checks: int = 0
var failures: Array[String] = []
var folder: String = "/tmp/auto-inventory-evidence"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); printerr("AUTO_UI_FAIL: "+message)
func frames(count: int = 4) -> void:
	for _i: int in range(count): await process_frame
func point(control: Control) -> Vector2: return control.get_global_transform_with_canvas()*(control.size*.5)
func click(control: Control) -> void:
	var position: Vector2 = point(control)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
	await frames()
func tap(control: Control) -> void:
	for down: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 9
		event.position = point(control)
		event.pressed = down
		root.push_input(event,true)
	await frames()
func dialog() -> Control:
	for child: Node in hud.get_node("Root").get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return child
	return null
func capture(label: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png(folder+"/"+label+".png") == OK,"screenshot "+label)
func choose(screen: Control, name: String, deposit: bool) -> void:
	for index: int in range(screen.entries.size()):
		if str(screen.entries[index].name) == name:
			screen.listing.select(index)
			if deposit: screen._selected(index)
			else: screen._select(index)
			return
	check(false,"item present "+name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(12)
	check(QA.enter_game(world),"class selection")
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	hud = world.hud
	world.inventory["HP 물약"] = 250
	world._update_hud()
	hud.open_warehouse()
	await frames(6)
	var screen: Control = hud.transaction_view
	choose(screen,"HP 물약",true)
	var controls: Control = screen.auto_controls
	controls.keep.value = 7
	await click(controls.select_button)
	check(world.inventory_automation.contains("deposit","HP 물약",""),"actual pointer registers target")
	check(FileAccess.file_exists(world.save_path()),"target is saved")
	await click(controls.get_node("AutoActions/AutoFill"))
	check(dialog() != null,"actual pointer opens cart")
	check(world.inventory["HP 물약"] == 250,"cart leaves inventory unchanged")
	await capture("warehouse-cart-1280x720")
	await click(dialog().cancel_button)
	check(world.inventory["HP 물약"] == 250,"cancel leaves all items")
	await click(controls.get_node("AutoActions/AutoFill"))
	await click(dialog().confirm_button)
	check(world.inventory["HP 물약"] == 7 and world.warehouse.stacks["HP 물약"] == 243,"pointer confirmation deposits complete stack less reserve")
	await capture("warehouse-result-1280x720")
	world._load_game(true)
	check(world.inventory["HP 물약"] == 7 and world.warehouse.stacks["HP 물약"] == 243 and world.inventory_automation.contains("deposit","HP 물약",""),"actual save reload restores inventory storage and selection")
	hud.open_item_sell()
	await frames(6)
	screen = hud.transaction_view
	choose(screen,"HP 물약",false)
	controls = screen.auto_controls
	controls.keep.value = 2
	await tap(controls.select_button)
	check(world.inventory_automation.contains("sell","HP 물약",""),"actual touch sale selection")
	var before: int = world.gold
	var quote: Dictionary = world.inventory_automation.preview("sell")
	await click(controls.get_node("AutoActions/AutoFill"))
	check(dialog() != null,"sale cart opens")
	await capture("sale-cart-1280x720")
	await tap(dialog().confirm_button)
	check(world.inventory["HP 물약"] == 2 and world.gold == before+int(quote.payment),"actual touch sale awards known price and removes selected quantity")
	world._load_game(true)
	check(world.inventory["HP 물약"] == 2 and world.gold == before+int(quote.payment),"sale survives actual reload")
	check(world.inventory_automation.set_target("deposit","HP 물약","",true,0).ok,"prepare actual failed-transfer check")
	var failed_plan: Dictionary = world.inventory_automation.preview("deposit")
	var saved_hash: String = FileAccess.get_sha256(world.save_path())
	var saved_inventory: Dictionary = world.inventory.duplicate(true)
	var saved_warehouse: Dictionary = world.warehouse.snapshot()
	var saved_gold: int = world.gold
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	var failed_transfer: Dictionary = world.inventory_automation.execute("deposit",failed_plan.stamp)
	check(not failed_transfer.ok and world.inventory == saved_inventory and world.warehouse.snapshot() == saved_warehouse and world.gold == saved_gold and FileAccess.get_sha256(world.save_path()) == saved_hash,"actual transfer write failure preserves live inventory warehouse wallet and disk")
	var failure: Dictionary = world.inventory_automation.set_target("sell","HP 물약","",true,0)
	check(not failure.ok and world.inventory == saved_inventory and FileAccess.get_sha256(world.save_path()) == saved_hash,"real writer failure preserves live and previous disk bytes")
	world.equipment_collections.test_save_writer = Callable()
	root.size = Vector2i(854,480)
	DisplayServer.window_set_size(root.size)
	hud._fit_hud()
	hud.open_item_sell()
	await frames(8)
	screen = hud.transaction_view
	choose(screen,"HP 물약",false)
	controls = screen.auto_controls
	check(int(controls.keep.value) == 2,"reopened UI restores saved retention value")
	await capture("sale-small-854x480")
	check(controls.get_node("AutoActions/AutoFill").is_visible_in_tree(),"cart action visible at small extent")
	var saved_hash_after: String = FileAccess.get_sha256(world.save_path())
	check(saved_hash_after == saved_hash,"screen changes do not rewrite failed save")
	var bad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	bad.inventory_automation = {"version":2}
	var file := FileAccess.open(world.save_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	var corrupt_hash: String = FileAccess.get_sha256(world.save_path())
	var live_settings: String = JSON.stringify(world.inventory_automation.state)
	world._load_game(true)
	check(world.equipment_collections.save_blocked and world.inventory == saved_inventory and JSON.stringify(world.inventory_automation.state) == live_settings,"actual malformed automation namespace rejects load before changing state")
	check(world._save_game(true) != OK and FileAccess.get_sha256(world.save_path()) == corrupt_hash,"unsupported save version cannot overwrite source bytes")
	print("AUTO_INVENTORY_UI: %d checks, %d failures" % [checks,failures.size()])
	world.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
