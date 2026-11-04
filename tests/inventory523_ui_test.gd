extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const RULES = preload("res://scripts/warehouse/inventory_source523.gd")
const SOURCE_TEST = preload("res://tests/inventory_source523_test.gd")
var world: Node
var hud: Node
var checks: int = 0
var failures: Array[String] = []
var folder: String = "/tmp/inventory523-evidence"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("INVENTORY523_UI_FAIL: "+label)
func frames(count: int = 5) -> void:
	for _i: int in range(count): await process_frame
func freeze() -> void:
	world.set_process(false)
	world.field_population.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
func reveal(control: Control) -> void:
	await frames()
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await frames()
func click(control: Control, touch: bool = false) -> void:
	await reveal(control)
	var position: Vector2 = control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 7
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
func swipe(control: Control) -> void:
	await reveal(control)
	var position: Vector2 = control.get_global_transform_with_canvas()*(control.size*.5)
	var press := InputEventScreenTouch.new()
	press.index = 8
	press.pressed = true
	press.position = position
	root.push_input(press,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 8
	drag.relative = Vector2(0,-80)
	drag.position = position+drag.relative
	root.push_input(drag,true)
	press.pressed = false
	press.position = drag.position
	root.push_input(press,true)
	await frames()
func capture(label: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png") == OK,"capture "+label)
func choose_sale(screen: Control, name: String) -> bool:
	for index: int in range(screen.entries.size()):
		if str(screen.entries[index].name) == name:
			screen.listing.select(index)
			screen._select(index)
			return true
	return false
func choose_source(screen: Control, id: int) -> bool:
	for index: int in range(screen.source_rows.size()):
		if int(screen.source_rows[index].ItemClassID) == id:
			screen.list.select(index)
			screen._select(index)
			return true
	return false
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	await frames(12)
	check(QA.enter_game(world),"enter actual Main")
	freeze()
	hud = world.hud
	var auto = world.inventory_automation
	check(auto.source_rules.document.is_empty(),"new profile starts without private rules")
	hud.open_inventory_automation_settings("sell")
	await frames()
	var settings: Control = hud.transaction_view
	await click(settings.find_child("Inventory523Install",true,false))
	check(settings.file_dialog != null and settings.file_dialog.visible,"actual UI opens rule ZIP picker")
	# Exercise the picker's actual selected-file consumer. OS picker gestures are
	# not claimed by this harness.
	settings.file_dialog.file_selected.emit(OS.get_environment("TWILIGHT_AUTO_INVENTORY523_ZIP"))
	await frames()
	check(auto.source_rules.document.items.size() == 80 and settings.source_rows.size() == 25,"actual file consumer installs complete native sell list")
	var consumer = RULES.new()
	check(consumer.load_file("user://inventory523/inventory_rules523.json"),"fresh consumer reads durable installed rules")
	var scroll: ScrollContainer = settings.get_child(0)
	await swipe(settings.source_only)
	check(scroll.scroll_vertical > 0 and not auto.state.get("source_only",false),"actual finger swipe scrolls from a checkbox without toggling scope")
	scroll.scroll_vertical = 0
	var record: Dictionary = auto.source_rules.definition("767").binding
	var name: String = str(record.name)
	var catalog_record: Dictionary = world._find_catalog_item_record(name)
	var identity_matches: bool = true
	for key: String in RULES.FIELDS:
		if catalog_record.get(key,"") != record.get(key,""): identity_matches = false
	check(identity_matches,"actual catalog identity equals pinned Inven fields")
	world.inventory[name] = 5
	world._update_hud()
	settings._refresh()
	check(choose_source(settings,767) and not settings.fallback.editable and settings.details.text.contains("확인값"),"confirmed native price is visible and read only")
	check(not auto.set_native_price("767",1).ok,"cannot overwrite confirmed native price")
	settings.keep.value = 1
	await click(settings.register,true)
	check(auto.contains("sell",name,""),"touch registers exact held native candidate")
	await click(settings.source_only,true)
	check(auto.state.source_only,"touch enables native ID/bless selection")
	check(choose_source(settings,45011) and settings.register.disabled and settings.details.text.contains("범주 선택자"),"virtual selector has no grant or sell action")
	check(choose_source(settings,767) and int(settings.keep.value) == 1,"native candidate reentry restores saved reserve quantity")
	# A declared native test fixture exercises a currently absent item contract;
	# this is not a production item grant or a merged PR238 item catalog.
	var custom: Dictionary = SOURCE_TEST.native(auto.source_rules.definition("117163"))
	world.loot_catalog.by_name[custom.name] = custom
	world.inventory[custom.name] = 2
	check(choose_source(settings,117163) and settings.fallback.editable and settings.details.text.contains("자체"),"unknown price is explicitly editable custom value")
	settings.fallback.value = 123
	await click(settings.price_action,true)
	check(auto.state.native_prices.get("117163") == 123,"touch saves only unknown native price")
	choose_source(settings,767)
	await reveal(settings.details)
	await capture("native-prices-1280x720")
	hud.open_item_sell()
	await frames()
	var screen: Control = hud.transaction_view
	check(choose_sale(screen,name),"real native material appears in sale UI")
	check(screen.details.text.replace(",","").contains("20000") and screen.details.text.contains("원본"),"sale UI displays verified unit price provenance")
	var wallet: int = world.gold
	var disk: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	world._sell_shop_item(name,1,"")
	check(world.inventory[name] == 5 and world.gold == wallet and FileAccess.get_sha256(world.save_path()) == disk,"actual manual native sale writer failure preserves inventory wallet and disk")
	world.equipment_collections.test_save_writer = Callable()
	await click(screen.auto_controls.get_node("AutoActions/AutoFill"))
	check(dialog() != null and auto.preview("sell").payment == 80000,"real cart prices four native stacks exactly")
	await capture("native-sale-cart-1280x720")
	await click(dialog().confirm_button,true)
	check(world.inventory[name] == 1 and world.gold == wallet+80000,"real touch cart settles original verified price")
	world._load_game(true)
	freeze()
	check(world.inventory[name] == 1 and world.gold == wallet+80000 and auto.state.native_prices.get("117163") == 123,"native sale and custom settings survive actual restart")
	world._sell_shop_item(name,1,"")
	check(world.inventory.get(name,0) == 0 and world.gold == wallet+100000,"manual source quote and actual settlement agree")
	world._load_game(true)
	freeze()
	check(world.inventory.get(name,0) == 0 and world.gold == wallet+100000,"manual sale is durable before publication")
	# Existing generic items remain manually sellable in native-only auto mode.
	world.inventory["HP 물약"] = 250
	check(auto.sale_quote("HP 물약",1,"",world.inventory,world.item_instances,world.gold,false).ok,"native-only auto scope preserves unrelated manual sale")
	check(auto.set_source_only(false).ok and auto.clear("sell").ok and auto.set_target("deposit","HP 물약","",true,7).ok and auto.set_target("sell","HP 물약","",true,2).ok,"explicit custom maintenance scope and reserve counts")
	var m = auto.maintenance
	var portals: Array[Dictionary] = m.portals()
	var chosen: Dictionary = {}
	var distance: float = INF
	for portal: Dictionary in portals:
		var position := Vector2(portal.position[0],portal.position[1])
		var path: PackedVector2Array = world.find_world_path(world.player.global_position,position)
		var candidate: float = world.player.global_position.distance_to(position)
		if not path.is_empty() and m.safe_walk(path,str(portal.id)) and candidate < distance and candidate > float(portal.radius): chosen = portal; distance = candidate
	check(not chosen.is_empty(),"actual current map provides reachable verified local portal")
	if not chosen.is_empty():
		print("MAINTENANCE_ACTUAL_PORTAL: ",chosen.id," start=",world.player.global_position," target=",chosen.position," distance=",distance)
		hud.open_inventory_automation_settings("deposit")
		await frames()
		settings = hud.transaction_view
		check(settings.source_rows.size() == 84,"complete native storage candidate rows shown")
		for index: int in range(settings.local_portals.size()):
			if settings.local_portals[index].id == chosen.id: settings.portal_choice.select(index)
		root.size = Vector2i(854,480)
		DisplayServer.window_set_size(root.size)
		hud._fit_hud()
		var start: Button = settings.find_child("MaintenanceStart",true,false)
		await reveal(start)
		await capture("maintenance-small-854x480")
		await click(start)
		check(dialog() != null,"small-screen actual pointer opens one-shot standing-order confirmation")
		await click(dialog().cancel_button,true)
		check(not m.settings().armed and world.inventory["HP 물약"] == 250,"actual touch cancel preserves state")
		await click(start)
		await click(dialog().confirm_button,true)
		check(m.settings().armed and not world.player.click_path.is_empty(),"actual touch confirmation saves order and starts existing click path")
		world._load_game(true)
		freeze()
		check(m.settings().armed and m.paused and world.inventory["HP 물약"] == 250,"actual pending save reload requires explicit rearm and consumes nothing")
		check(m.arm(str(chosen.id),true,true,120).ok,"explicit actual route resume")
		wallet = world.gold
		world.portal_cooldown = 0
		world.player.set_physics_process(true)
		for _tick: int in range(2400):
			await physics_frame
			m.tick()
			world._update_field_triggers()
			if not m.settings().armed: break
		world.player.set_physics_process(false)
		await frames()
		check(not m.settings().armed and world.inventory.get("HP 물약") == 2 and world.warehouse.stacks.get("HP 물약") == 243 and world.gold == wallet+200,"actual physics walk and portal trigger atomically store then sell once")
		check(world.player.global_position.distance_to(Vector2(chosen.target_position[0],chosen.target_position[1])) < 6,"existing portal lands at its authoritative local destination")
		var token: int = m.settings().completed_run_id
		world._load_game(true)
		freeze()
		check(not m.settings().armed and m.settings().completed_run_id == token and world.inventory.get("HP 물약") == 2 and world.gold == wallet+200,"actual completed token and both phases survive restart without replay")
		root.size = Vector2i(1280,720)
		DisplayServer.window_set_size(root.size)
		hud._fit_hud()
		hud.open_warehouse()
		await capture("maintenance-result-1280x720")
	print("INVENTORY523_UI: %d checks, %d failures" % [checks,failures.size()])
	world.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
