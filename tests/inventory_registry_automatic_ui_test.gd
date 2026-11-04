extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var world: Node
var hud: Node
var checks: int = 0
var failures: Array[String] = []
var folder: String = "/tmp/registry-automatic523-evidence"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("REGISTRY_AUTO_UI_FAIL: "+label)
func frames(count: int = 5) -> void:
	for _i: int in range(count): await process_frame
func freeze() -> void:
	world.set_process(false);world.field_population.set_process(false);world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
func click(control: Control, touch: bool = true) -> void:
	await frames()
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await frames()
	var position: Vector2 = control.get_global_transform_with_canvas()*(control.size*.5)
	for down: bool in [true,false]:
		var event: InputEvent
		if touch: event = InputEventScreenTouch.new();event.index = 15
		else: event = InputEventMouseButton.new();event.button_index = MOUSE_BUTTON_LEFT
		event.position = position;event.pressed = down;root.push_input(event,true)
	await frames()
func dialog() -> Control:
	for child: Node in hud.get_node("Root").get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return child
	return null
func capture(label: String) -> void:
	await frames(8);await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png") == OK,"capture "+label)
func select_source(screen: Control, id: int, bless: int = 1) -> bool:
	for index: int in range(screen.source_rows.size()):
		if int(screen.source_rows[index].ItemClassID) == id and int(screen.source_rows[index].get("ItemBlessCodeID",1)) == bless:
			screen.list.select(index);screen._select(index);return true
	return false
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280,720);DisplayServer.window_set_size(root.size)
	world = load("res://Main.tscn").instantiate();root.add_child(world);await frames(12)
	check(QA.enter_game(world),"actual Main startup and class selection")
	freeze();hud = world.hud
	var auto = world.inventory_automation
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var instances_before: Dictionary = world.item_instances.duplicate(true)
	var rng_before: int = world.rng.state
	var loot_before: Dictionary = world.loot_catalog.duplicate(true)
	var registration: Dictionary = auto.refresh_catalog()
	check(registration.deposit == 80 and registration.sell == 19 and registration.deposit_allowed == 79,"actual Main registered target coverage and TestItem protection")
	check(world.inventory == inventory_before and world.item_instances == instances_before and world.rng.state == rng_before and world.loot_catalog == loot_before,"catalog application grants no ownership and leaves RNG and legacy loot pool unchanged")
	var normal: String = "무기 마법 주문서 · 원본#137"
	var blessed: String = normal+" · 축복"
	var cursed: String = normal+" · 저주"
	var sale_name: String = "다크엘프 병사의 배지 · 원본#118692"
	for name_: String in [normal,blessed,cursed,sale_name]: check(not world._find_catalog_item_record(name_).is_empty(),"actual registered key "+name_)
	check(world._catalog_item_from_source_id("m523:item:137:bless:2").name == blessed,"existing source-ID index receives exact native blessing key")
	# Explicit isolated ownership fixtures only; production registration grants nothing.
	world.inventory[normal] = 3;world.inventory[blessed] = 5;world.inventory[cursed] = 7;world.inventory[sale_name] = 4
	world._update_hud()
	var saved_inventory: Dictionary = world.inventory.duplicate(true)
	world._on_inventory_item_activated(blessed)
	check(world.inventory == saved_inventory and not world._quickslot_item_supported(blessed),"unlinked use effects cannot fall through into name-based enhancement/quickslot consumption")
	check(auto.set_source_only(true).ok,"native-only selection enabled")
	hud.open_inventory_automation_settings("deposit");await frames()
	var screen: Control = hud.transaction_view
	check(select_source(screen,137,2) and screen.held_options.size() == 1 and screen._chosen_held().name == blessed,"actual source row selects exact registered blessed stack")
	screen.keep.value = 2;await click(screen.register)
	check(auto.contains("deposit",blessed,"") and not auto.contains("deposit",normal,"") and not auto.contains("deposit",cursed,""),"touch selects only explicit blessing identity")
	check(auto.preview("deposit").cart.size() == 1 and auto.preview("deposit").cart[0].quantity == 3,"source JSON numeric blessing membership actually deposits intended quantity")
	await capture("registered-blessing-1280x720")
	hud.open_inventory_automation_settings("sell");await frames();screen = hud.transaction_view
	check(select_source(screen,118692) and not screen.register.disabled,"actual newly registered merchant target appears")
	screen.keep.value = 1;await click(screen.register)
	check(auto.preview("sell").payment == 3000,"confirmed original1000-unit NPC price used by actual registered source ID")
	var m = auto.maintenance
	var chosen: Dictionary = {}
	var closest: float = INF
	for portal: Dictionary in m.portals():
		var position := Vector2(portal.position[0],portal.position[1])
		var path: PackedVector2Array = world.find_world_path(world.player.global_position,position)
		var distance: float = world.player.global_position.distance_to(position)
		if distance > float(portal.radius) and not path.is_empty() and m.safe_walk(path,str(portal.id)) and distance < closest: closest = distance;chosen = portal
	check(not chosen.is_empty(),"verified existing local portal and safe current walk path")
	if chosen.is_empty(): world.queue_free();await frames();quit(1);return
	for index: int in range(screen.local_portals.size()):
		if screen.local_portals[index].id == chosen.id: screen.portal_choice.select(index)
	await click(screen.resume_auto)
	var before: String = JSON.stringify([world.inventory,world.gold,auto.state])
	await click(screen.find_child("MaintenanceAutomaticEnable",true,false))
	check(dialog() != null,"actual automatic policy opens target/cost/mode confirmation")
	await capture("automatic-target-cost-1280x720")
	await click(dialog().cancel_button)
	check(JSON.stringify([world.inventory,world.gold,auto.state]) == before and not m.automatic_enabled(),"cancel automatic activation leaves all state unchanged")
	await click(screen.find_child("MaintenanceAutomaticEnable",true,false));await click(dialog().confirm_button)
	check(m.automatic_enabled() and not m.settings().armed and not world.player.auto_enabled,"automatic policy stores without immediate execution")
	world._load_game(true);freeze()
	check(m.reconnect_wait and m.automatic_enabled() and not m.settings().armed,"actual reconnect keeps policy and requires explicit AUTO mode")
	hud.open_macro_info();await frames()
	check(hud.workspace.find_child("AutoMaintenanceSettings",true,false) != null,"existing AUTO settings links the execution consumer")
	await click(hud.workspace.find_child("AutoSettingToggle",true,false),false)
	hud._close_workspace();await frames()
	check(world.player.auto_enabled and not m.reconnect_wait,"actual existing AUTO toggle authorizes saved policy after reconnect")
	world._run_auto_hunt()
	check(m.settings().armed and not world.player.auto_enabled and not world.player.click_path.is_empty(),"actual hunting consumer starts existing walk path from saved automatic policy")
	var day: int = int(m.settings().automatic.last_started_day)
	var run_id: int = int(m.settings().run_id)
	var gold_before: int = world.gold
	world.portal_cooldown = 0;world.player.set_physics_process(true)
	for _i: int in range(2400):
		await physics_frame;m.tick();world._update_field_triggers()
		if not m.settings().armed: break
	world.player.set_physics_process(false);await frames()
	check(not m.settings().armed and world.inventory[blessed] == 2 and world.warehouse.stacks[blessed] == 3 and world.inventory[normal] == 3 and world.inventory[cursed] == 7,"automatic arrival stores exact blessed key and preserves other blessing stacks")
	check(world.inventory[sale_name] == 1 and world.gold == gold_before+3000,"automatic arrival sells exact approved NPC target with zero extra travel deduction")
	check(world.player.auto_enabled and int(m.settings().automatic.last_completed_day) == day and int(m.settings().completed_run_id) == run_id,"atomic saved day/run token and selected resume mode complete")
	m.next_automatic_check_ms = 0;world._run_auto_hunt()
	check(not m.settings().armed and int(m.settings().run_id) == run_id and world.gold == gold_before+3000,"same game-date repeated hunting frames cannot duplicate transaction")
	world._load_game(true);freeze()
	check(not m.settings().armed and world.gold == gold_before+3000 and int(m.settings().automatic.last_started_day) == day,"actual completed token/rewards survive reload")
	hud.open_inventory_automation_settings("sell");await frames();screen = hud.transaction_view
	root.size = Vector2i(854,480);DisplayServer.window_set_size(root.size);hud._fit_hud()
	await click(screen.find_child("MaintenanceAutomaticDisable",true,false))
	check(not m.automatic_enabled() and not m.settings().armed,"small-screen touch disables automatic execution durably")
	await capture("automatic-disabled-854x480")
	world._load_game(true);freeze()
	check(not m.automatic_enabled() and world.inventory[normal] == 3 and world.inventory[cursed] == 7 and world.warehouse.stacks[blessed] == 3,"disable and distinct identity quantities survive another reconnect")
	print("REGISTRY_AUTOMATIC_UI: %d checks, %d failures" % [checks,failures.size()])
	world.queue_free();await frames();quit(0 if failures.is_empty() else 1)
