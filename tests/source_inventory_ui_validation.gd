extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var errors: Array[String] = []
var checks: int = 0
var folder: String = ""
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message); push_error(message)
func settle() -> void:
	for frame: int in range(8): await process_frame
func capture(name_value: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+name_value+".png")==OK,"capture "+name_value)
func run() -> void:
	var private_root: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): folder=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--private-ui-root="):private_root=arg.trim_prefix("--private-ui-root=")
	if folder.is_empty(): push_error("Explicit --capture-dir required"); quit(2); return
	if not private_root.is_empty() and ResourceLoader.exists("res://scripts/lineagem_pack_install.gd"):
		var installer: Script=load("res://scripts/lineagem_pack_install.gd");installer._session_root=private_root
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(1280,720); DisplayServer.window_set_size(root.size)
	var world: Node=load("res://Main.tscn").instantiate(); root.add_child(world)
	await settle(); check(QA.enter_game(world),"class selection")
	world.save_timer=-10000; world.set_process(false)
	world.field_population.set_process(false); world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	world._update_hud()
	var hud: Node=world.hud
	# Isolated UI test only: the private map installation is a separate fixture.
	hud.process_mode=Node.PROCESS_MODE_ALWAYS
	var state_before: int=hash([world.inventory,world.item_instances,world.equipped_items,world.gold])
	var bag: Node=hud.lineage_inventory_ui
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(854,480)]:
		root.size=extent; DisplayServer.window_set_size(extent)
		hud._close_workspace(); hud.toggle_inventory(); await settle()
		check(not bag.slot_buttons.is_empty(),"actual starting inventory")
		await capture("inventory-%dx%d" % [extent.x,extent.y])
		if bag.slot_buttons.is_empty(): continue
		var reference: String=bag.slot_buttons.keys()[0]
		var slot: Button=bag.slot_buttons[reference]
		if not private_root.is_empty():check(slot.has_meta("original_inventory_slot"),"original Common_Slot frame reaches inventory button")
		check(slot.custom_minimum_size==Vector2(76,76),"original background bounds")
		check(slot.get_node("Icon").size==Vector2(64,64),"original icon bounds")
		check(slot.get_meta("tooltip_reference","")==reference and not slot.tooltip_text.is_empty(),"tooltip physical reference")
		bag._select_item(reference); bag.open_detail(); await settle()
		check(bag.selected_item==reference and bag.detail_active,"detail exact selection")
		await capture("inventory-detail-%dx%d" % [extent.x,extent.y])
		var rebuilds: int=bag.inventory_list_rebuilds
		world._update_hud(); await settle()
		check(bag.inventory_list_rebuilds==rebuilds,"unchanged HUD avoids inventory rebuild")
		hud._close_workspace(); hud.toggle_inventory(); await settle()
		check(bag.selected_item==reference,"close/reopen preserves physical selection")
	check(hash([world.inventory,world.item_instances,world.equipped_items,world.gold])==state_before,"inventory equipment and currency unchanged")
	var result: Dictionary={"checks":checks,"errors":errors}
	var file: FileAccess=FileAccess.open(folder+"/checks.json",FileAccess.WRITE); file.store_string(JSON.stringify(result)); file.close()
	print("SOURCE_INVENTORY_UI ",JSON.stringify(result))
	world.queue_free(); await process_frame; quit(0 if errors.is_empty() else 1)
