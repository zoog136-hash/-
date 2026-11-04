extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Source = preload("res://scripts/protection/protection523_source.gd")
const Runtime = preload("res://scripts/protection/protection523_runtime.gd")
var failures: Array[String] = []
var checks := 0
var world: Node
var capture_dir := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("PROTECTION523_FAIL ",message)

func norm(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func pointer_press(button: Button, panel: Node) -> void:
	panel.scroll_host.ensure_control_visible(button)
	await process_frame
	await process_frame
	var point := button.get_global_rect().get_center()
	check(button.is_visible_in_tree() and root.get_visible_rect().has_point(point),"rendered source button reachable by pointer")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		root.push_input(event,true)
	await process_frame

func accept() -> void:
	var dialog: Node = world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(dialog != null,"actual confirmation exists")
	if dialog != null:
		dialog.confirm_button.pressed.emit()
		dialog.confirm_button.pressed.emit()
	await process_frame

func reject() -> void:
	var dialog: Node = world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
	check(dialog != null,"actual cancel confirmation exists")
	if dialog != null: dialog.cancel_button.pressed.emit()
	await process_frame

func capture(name_value: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	check(image.save_png(capture_dir+"/"+name_value+".png") == OK,"actual rendered capture "+name_value)

func stop_actors() -> void:
	world.set_process(false)
	world.player.set_physics_process(false)
	for actor: Node in world.monsters_root.get_children():
		actor.set_process(false)
		actor.set_physics_process(false)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): capture_dir = argument.trim_prefix("--capture-dir=")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	var scene := load("res://Main.tscn") as PackedScene
	check(scene != null,"actual Main loads")
	if scene == null: quit(1); return
	world = scene.instantiate()
	root.add_child(world)
	stop_actors()
	check(QA.enter_game(world),"actual class selection")
	var service: RefCounted = world.protection523
	check(not service.source.is_empty(),"verified source installed in actual Main")
	if service.source.is_empty():
		print("PROTECTION523_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"problem":service.problem}))
		world.queue_free()
		await process_frame
		quit(1)
		return
	if "--reload-only" in OS.get_cmdline_user_args():
		check(service.state.crafted.size() == 6 and service.state.titles.size() == 6,"all craft/title receipts survive fresh process")
		check(int(service.effects().title_flat) == 7,"permanent title effect survives fresh process")
		check(service.state.cooldowns.size() == 6,"all cooldowns survive fresh process")
		var key: String = service.owned_key(371108,world.inventory)
		check(not key.is_empty() and int(world.inventory.get(key,0)) == 1,"non-consumed final item survives fresh process")
		check(not service.quote_use(key).ok,"fresh process cannot bypass cooldown")
		check(not service.quote_craft(371108).ok,"fresh process cannot craft twice")
		world.hud.open_protection523()
		await capture("reload")
		await finish()
		return
	check(service.source.definitions.size() == 6,"every normal source item supported; unused item excluded")
	check(service.source.group604_item_ids.size() == 23,"all related Group604 item identities audited")
	check(service.records_for(371108).size() == 1,"missing final tier has independent runtime catalog identity")
	var old_quests: Variant = norm(world.quest_service.export_state())
	var old_gear: Variant = norm(world.item_instances)
	var old_gold: int = world.gold
	world.inventory["정상의 가호(3단)"] = 1
	world.inventory["은총의 두루마리"] = 6
	world.inventory["명예 코인"] = 100
	service.state = Runtime.fresh()
	service.reset_clock()
	check(world._save_game(true) == OK,"isolated legitimate source-material fixture saved atomically")
	world.hud.toggle_menu()
	var entry: Button = world.hud.workspace.find_child("MenuTile_protection523",true,false)
	check(entry != null,"normal menu entry")
	if entry != null: entry.pressed.emit()
	var panel: Node = world.hud.workspace.find_child("Protection523Panel",true,false)
	check(panel != null,"normal menu opens full six-tier panel")
	if panel == null: await finish(); return
	await capture("before-craft")
	var starting_inventory: Variant = norm(world.inventory)
	panel.request_craft(200723)
	await reject()
	check(norm(world.inventory) == starting_inventory and service.state.crafted.is_empty(),"cancel preserves exact materials and receipts")
	var initial_disk := FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	panel.request_craft(200723)
	await accept()
	check(norm(world.inventory) == starting_inventory and service.state.crafted.is_empty() and FileAccess.get_sha256(world.save_path()) == initial_disk,"actual craft writer failure preserves disk, both materials and title")
	world.equipment_collections.test_save_writer = Callable()
	var pointer_hash := FileAccess.get_sha256(Source.POINTER)
	check(not service.install("/workspace/protection523-private/intentionally-absent-source.zip").ok and FileAccess.get_sha256(Source.POINTER) == pointer_hash and service.source.definitions.size() == 6,"failed source installation preserves active verified definitions")
	check(not service.quote_craft(327823).ok,"unused source item/recipe cannot be activated")
	for item_id: int in Source.IDS:
		var d: Dictionary = service.source.definitions[str(item_id)]
		var before_coin: int = int(world.inventory.get("명예 코인",0))
		var before_general: int = world._damage_reduction_stat()
		var craft_button: Button = panel.find_child("ProtectionCraft_%d" % item_id,true,false)
		check(craft_button != null and not craft_button.disabled,"normal source crafting button enabled %d" % item_id)
		if craft_button != null:
			if capture_dir.is_empty(): craft_button.pressed.emit()
			else: await pointer_press(craft_button,panel)
		await accept()
		var key: String = service.owned_key(item_id,world.inventory)
		check(not key.is_empty(),"actual UI crafts source item %d" % item_id)
		check(service.state.crafted.has(str(int(d.recipe.ItemCraftID))),"durable exact recipe receipt %d" % item_id)
		check(service.state.titles.has(int(d.title.ID)),"craft unlocks correct BuffClass title namespace %d" % item_id)
		check(int(service.effects().title_flat) == int(d.title_flat),"Group841 highest title once %d" % item_id)
		check(world._damage_reduction_stat() == before_general+1 if item_id != 200723 else world._damage_reduction_stat() == before_general+2,"actual general reduction changes at tier %d" % item_id)
		check(int(service.effects().possession_flat) == int(d.possession_flat),"actual possession effect %d" % item_id)
		check(int(service.effects().possession_percent_raw) == int(d.possession_percent_raw),"full-precision possession percent %d" % item_id)
		var body_count := int(world.inventory.get(key,0))
		var before_bytes := FileAccess.get_sha256(world.save_path())
		var state_before: Variant = norm(service.state)
		world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
		check(not service.use(key).ok,"actual writer failure denies use %d" % item_id)
		check(int(world.inventory.get("명예 코인",0)) == before_coin and int(world.inventory.get(key,0)) == body_count,"writer failure preserves coin/body %d" % item_id)
		check(FileAccess.get_sha256(world.save_path()) == before_bytes and norm(service.state) == state_before,"writer failure preserves disk/effect %d" % item_id)
		world.equipment_collections.test_save_writer = Callable()
		world.hud.inventory_item_activated.emit(key)
		await accept()
		check(int(world.inventory.get("명예 코인",0)) == before_coin-10,"inventory UI spends exactly source coin amount %d" % item_id)
		check(int(world.inventory.get(key,0)) == body_count,"source Category10204 body never consumed %d" % item_id)
		check(int(service.effects().active_flat) == int(d.buff_flat),"Group604 only current activated buff %d" % item_id)
		check(int(service.state.active.until)-service.now() <= int(d.duration) and int(service.state.active.until)-service.now() > int(d.duration)-3,"source duration %d" % item_id)
		check(int(service.state.cooldowns[str(item_id)])-service.now() <= 3600,"source cooldown %d" % item_id)
		check(not service.use(key).ok,"double use denied %d" % item_id)
		var source_only_damage: int = world._pve_damage_after_item_buffs(1000)
		check(service.set_policy(false,"keep_stronger").ok,"explicit source-only PvP projection setting %d" % item_id)
		check(world._pve_damage_after_item_buffs(1000) > source_only_damage,"actual solo combat consumes configured source stats %d" % item_id)
		check(service.set_policy(true,"keep_stronger").ok,"restore existing host projection %d" % item_id)
		var item_before: Variant = norm(world.inventory)
		world._warehouse_transfer(key,1,"deposit","")
		world._sell_shop_item(key,1,"")
		check(norm(world.inventory) == item_before,"source no-store/no-sale flags enforced %d" % item_id)
		check(not world._use_timed_item_buff(service.records_for(item_id)[0]),"legacy handler cannot consume body %d" % item_id)
		check(not service.legacy_group_blocked(world._find_catalog_item_record("드래곤의 성수")),"unrelated timed consumable stays separate")
		check(service.legacy_group_blocked(world._find_catalog_item_record("발록의 가호")),"other exact Group604 legacy item cannot stack")
		check(not service.quote_craft(item_id).ok,"one-per-character craft enforced %d" % item_id)
	check(world.inventory.get("은총의 두루마리",0) == 0,"all six source scroll inputs consumed exactly")
	check(world.inventory.get("명예 코인",0) == 40,"six UI activations consume sixty coins")
	check(norm(world.quest_service.export_state()) == old_quests,"existing instant-completion quest state preserved")
	check(norm(world.item_instances) == old_gear and world.gold == old_gold,"existing physical gear and gold preserved")
	check(service.state.crafted.size() == 6 and service.state.titles.size() == 6,"all six normal craft/title paths exercised")
	var saved: Variant = norm(service.state)
	var broken: Dictionary = service.state.duplicate(true)
	broken.titles.append(999999)
	check(not Runtime.validate(broken).is_empty(),"forged title rejected")
	broken = service.state.duplicate(true)
	broken.active.until = int(broken.cooldowns["371108"])+1
	check(not Runtime.validate(broken).is_empty(),"impossible buff/cooldown pair rejected")
	var invalid_record: Dictionary = service.records_for(371108)[0].duplicate(true)
	invalid_record.sourceId = "m523:item:327823"
	check(not service.managed(invalid_record),"wrong identity cannot alias valid final item")
	var key: String = service.owned_key(371108,world.inventory)
	var qty: int = int(world.inventory[key])
	var receipt_count: int = service.state.crafted.size()
	world.crafting_log.clear()
	check(not service.quote_craft(371108).ok and service.state.crafted.size() == receipt_count,"truncated generic craft log cannot reset lifetime quota")
	world.ui_preferences.item_locks[key] = true
	service.state.cooldowns["371108"] = 0
	check(not service.quote_use(key).ok,"locked body denied")
	world.ui_preferences.item_locks.erase(key)
	service.state = saved.duplicate(true)
	service.state.last_seen = int(Time.get_unix_time_from_system())+100
	check(not service.quote_use(key).ok,"clock rollback denies action")
	service.state = saved.duplicate(true)
	service.reset_clock()
	var until: int = int(service.state.active.until)
	service.clock_anchor = until+1
	service.clock_ticks = Time.get_ticks_msec()
	check(int(service.effects().active_flat) == 0,"absolute expiry removes activated effect")
	check(int(service.effects().title_flat) == 7 and int(service.effects().possession_flat) == 10,"expiry preserves independent possession/title layers")
	service.state = saved.duplicate(true)
	service.reset_clock()
	check(int(world.inventory[key]) == qty,"expiry/time checks preserve non-consumable item")
	check(world._save_game(true) == OK,"final runtime/ownership/source receipts saved")
	world._load_game(true)
	check(service.state.crafted.size() == 6 and int(service.effects().title_flat) == 7,"same-process reload preserves full state")
	check(world._save_game(true) == OK,"accepted reload remains writable")
	var original_field: Variant = world.field_map
	var original_hp: int = world.hp
	var attacker: TwilightMonster = null
	for child: Node in world.monsters_root.get_children():
		if child is TwilightMonster and not child.dead: attacker = child; break
	check(attacker != null,"actual current-map monster available for damage event")
	if attacker != null:
		world.field_map = null # Isolated event test bypasses only the town safe-area filter.
		var projected_loss := 0
		var source_only_loss := 0
		var old_stun: float = attacker.stun_duration
		var old_attacker_hp: int = attacker.hp
		attacker.hp = 100000
		attacker.stun_duration = 0.0
		for seed_value: int in range(10):
			world.hp = 100000
			service.state.policy.project_pvp_to_pve = false
			world.rng.seed = seed_value
			world._on_player_hit(attacker,1000,"magic")
			source_only_loss = 100000-world.hp
			world.hp = 100000
			service.state.policy.project_pvp_to_pve = true
			world.rng.seed = seed_value
			world._on_player_hit(attacker,1000,"magic")
			projected_loss = 100000-world.hp
			if source_only_loss > 0: break
		check(source_only_loss > projected_loss and projected_loss > 0,"actual monster hit event consumes independent possession and activated defense")
		attacker.stun_duration = old_stun
		attacker.hp = old_attacker_hp
		world.field_map = original_field
		world.hp = original_hp
		world.player.clear_status_effects()
	var floor_key: String = service.owned_key(371108,world.inventory)
	check(world._drop_inventory_reference(floor_key,world.player.global_position),"existing ground-drop path transfers owned non-consumable")
	check(int(service.effects().possession_flat) == 0 and int(service.effects().title_flat) == 7,"floor ownership removes possession effect while title remains")
	check(int(service.effects().active_flat) == 10,"source activated buff remains independent of body ownership")
	await create_timer(0.9).timeout
	var floor_view: Button = null
	for child: Node in world.drops_root.get_children():
		if child is Button and str(child.get_meta("item_name","")) == floor_key: floor_view = child; break
	if floor_view == null:
		for child: Node in world.drops_root.get_children():
			if child is Button: floor_view = child; break
	check(floor_view != null,"actual floor pickup button exists")
	if floor_view != null:
		floor_view.pressed.emit()
		world.loot_pickup.pickup_button.pressed.emit()
	check(int(world.inventory.get(floor_key,0)) == 1,"actual protected floor pickup restores ownership")
	check(int(service.effects().possession_flat) == 10 and int(world.inventory.get(floor_key,0)) == 1,"floor pickup restores original source possession effect once")
	var pre_death_coin: int = int(world.inventory.get("명예 코인",0))
	var pre_death_active: Variant = norm(service.state.active)
	var pre_death_gold: int = world.gold
	world._respawn_player("QA existing death/respawn")
	check(int(world.inventory.get(floor_key,0)) == 1 and int(world.inventory.get("명예 코인",0)) == pre_death_coin and norm(service.state.active) == pre_death_active,"death/respawn never consumes body or coin and preserves immune buff")
	world.gold = pre_death_gold
	check(world._save_game(true) == OK,"floor ownership and death-persistent layers durably saved")
	panel.refresh()
	await process_frame
	panel.scroll_host.ensure_control_visible(panel.find_child("ProtectionCard_371108",true,false))
	await capture("all-tiers")
	await finish()

func finish() -> void:
	print("PROTECTION523_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"actual Main, original523 six definitions, source-material QA fixture, real UI/atomic save; upstream quest suppliers separate"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
