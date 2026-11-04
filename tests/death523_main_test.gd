extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const Writer = preload("res://scripts/skills/save_writer.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label); printerr("DEATH523_FAIL ",label)

func equal(a: Variant, b: Variant) -> bool:
	# Production JSON loading represents integral numbers as floats. Compare
	# complete persisted values through the same normalization as the core gate.
	return JSON.stringify(JSON.parse_string(JSON.stringify(a)),"",true,true) == JSON.stringify(JSON.parse_string(JSON.stringify(b)),"",true,true)

func tap(button: Button) -> void:
	check(button != null and button.is_visible_in_tree() and not button.disabled,"actual actionable button")
	if button == null: return
	var parent: Node = button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await process_frame
	var point: Vector2 = button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion := InputEventMouseMotion.new(); motion.position = point
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point; event.global_position = point; event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	check(QA.enter_game(world),"real Main class confirmation")
	world.set_process(false)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.hud.process_mode = Node.PROCESS_MODE_ALWAYS
	world.player.set_physics_process(false)
	for actor: Node in get_nodes_in_group("monsters"): actor.set_physics_process(false)
	var service = world.death_recovery
	check(service.source.ready,"real pinned523 source archive")
	check(service.source.experience.size() == 160,"all original experience rows")
	var original_pack: String = service.source.PATH
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--death523-source="): original_pack = argument.trim_prefix("--death523-source=")
	check(service.source.install(original_pack).is_empty(),"actual private rule pack installs")
	var pack_hash: String = FileAccess.get_sha256(service.source.PATH)
	var wrong := FileAccess.open("user://wrong-death523.zip",FileAccess.WRITE)
	wrong.store_string("not an original archive"); wrong.close()
	check(not service.source.install("user://wrong-death523.zip").is_empty() and FileAccess.get_sha256(service.source.PATH) == pack_hash,"invalid replacement preserves installed bytes")
	var reader = service.Source.new()
	check(reader.load_pack() and reader.experience.size() == 160,"installed pack reloads through default game path")
	world.gold = 1000000; world.inventory["다이아"] = 1000
	world.level = 35; world.exp_need = world.EXP_PROGRESSION.table_requirement(35)
	world.experience = int(world.exp_need/2)
	check(world._save_game(true) == OK,"initial production save")
	var path: String = world.save_path()
	# A historical save is a real complete Main payload with only the new key
	# absent. The production writer and loader perform the migration.
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	old.erase(service.KEY)
	check(Writer.write(path,old) == OK,"historical save fixture writer")
	var old_sha: String = FileAccess.get_sha256(path)
	world._load_game(true)
	await process_frame
	check(FileAccess.get_sha256(path) == old_sha,"load leaves historical bytes unchanged")
	check(FileAccess.get_sha256(path+".pre-death523-"+old_sha) == old_sha,"exact pre-migration backup")
	check(service.free_remaining() == 2,"user base free recoveries is2")
	check(world._save_game(true) == OK,"migrated ledger saves with existing progression")
	var record: Dictionary = {}
	for candidate: Dictionary in world.catalog_db.get("아이템",[]):
		var sid: String = str(candidate.get("sourceId",""))
		var item_name: String = str(candidate.get("name",""))
		if service.source.matches_item(candidate,sid) and bool(service.source.items[sid].IsDroppable) and not bool(service.source.items[sid].TestItem) and not world._enhancement_kind_for_record(candidate).is_empty() and int(world.catalog_item_variant_count.get(item_name,0)) == 1 and not world.inventory.has(item_name): record = candidate; break
	check(not record.is_empty(),"source-eligible exact-ID and original localized name equipment exists")
	var wrong_identity: Dictionary = record.duplicate(true)
	wrong_identity["name"] = "unrelated item with the same numeric ID"
	check(not service.source.matches_item(wrong_identity,str(wrong_identity.get("sourceId",""))),"same numeric ID with wrong name is never source eligible")
	if record.is_empty(): quit(1); return
	for id: String in world.item_instances: world.item_instances[id].locked = true
	var name_value: String = str(record.name)
	var physical: Dictionary = {"name":name_value,"record":record.duplicate(true),"level":7,"element":"fire","element_level":3,"opaque":{"keep":"unchanged"}}
	world.inventory[name_value] = 1; world.item_instances["900001"] = physical.duplicate(true); world.next_item_instance_id = 900002
	service.policy.item_loss_percent = 100.0 # Explicit deterministic QA fixture.
	var danger: Vector2 = Vector2.INF
	world.field_map._build_entry_reach()
	for flat: int in world.field_map.entry_cells:
		var point: Vector2 = world.field_map.cell_to_world(Vector2i(flat%world.field_map.width,flat/world.field_map.width))
		if not world.field_map.is_safe(point) and world.field_map.point_clear(point,4): danger = point; break
	check(danger.is_finite(),"real current source-map unsafe clear foot")
	if not danger.is_finite(): world.queue_free(); quit(1); return
	world.player.global_position = danger
	world.hp = 1
	check(world._save_game(true) == OK,"pre-lethal fixture save")
	var experience_before: int = world.experience
	var gold_before: int = world.gold
	# Exercise the actual poison -> death -> ledger path, not a model-only death.
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	world._on_player_poison_tick(2)
	check(not service.pending.is_empty() and world.experience == experience_before and world.item_instances.has("900001"),"lethal save failure preserves EXP and original item")
	check(world._save_game(true) != OK,"pending death blocks unrelated autosaves")
	world.equipment_collections.test_save_writer = Callable()
	await process_frame
	await tap(world.hud.get_node("Root").find_child("Death523Restart",true,false))
	await process_frame
	check(service.blocked() and world.hp == 0,"actual lethal tick enters dead state")
	check(world.gold == gold_before,"removed legacy arbitrary500 adena charge")
	check(service.state.records.size() == 1,"one death receipt")
	if service.state.records.size() != 1:
		print("DEATH_RETRY_DIAGNOSTIC pending=",not service.pending.is_empty()," save_blocked=",service.save_blocked," result=",world.hud.get_node("Root").find_child("Death523Result",true,false).text)
		world.queue_free(); quit(1); return
	var entry: Dictionary = service.state.records[0]
	check(int(entry.exp) > 0 and world.experience+int(entry.exp) == experience_before,"exact removed EXP escrow")
	check(entry.item.id == "900001" and not world.item_instances.has("900001") and not world.inventory.has(name_value),"original physical item escrow, no duplicate")
	check(equal(entry.item.physical,physical),"enhancement element and opaque metadata preserved")
	check(not world.player.is_physics_processing() and not world.player.auto_enabled,"dead movement and AUTO stopped")
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	world._use_quick_item("다이아"); world._use_potion(); world._return_to_spawn()
	check(equal(world.inventory,inventory_before) and world.player.global_position == danger,"dead actions consume nothing and cannot teleport")
	world._respawn_player("duplicate callback")
	check(service.state.records.size() == 1,"duplicate death callback not charged")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/death523-dead-1280.png")
	var death_sha: String = FileAccess.get_sha256(path)
	world._load_game(true)
	await process_frame
	check(service.blocked() and world.hp == 0 and FileAccess.get_sha256(path) == death_sha,"dead reload, no replay or overwrite")
	# A genuine writer failure must leave the dead ledger and position unchanged.
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not service.resurrect().ok and service.blocked() and world.player.global_position == danger,"failed resurrection atomic rollback")
	world.equipment_collections.test_save_writer = Callable()
	var restart: Button = world.hud.get_node("Root").find_child("Death523Restart",true,false)
	await tap(restart)
	check(not service.blocked() and world.hp > 0 and world.player.global_position == world._spawn_position(),"actual restart button revives at current start")
	check(world.hud.active_section == "death523","revival opens real recovery screen")
	var q: Dictionary = service.quote(str(entry.id),"exp","free")
	check(q.ok,"free EXP quote")
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	var before_failed: String = FileAccess.get_sha256(path)
	check(not service.recover(q).ok and service.free_remaining() == 2 and world.experience == experience_before-int(entry.exp) and FileAccess.get_sha256(path) == before_failed,"failed free recovery keeps quota EXP and save")
	world.equipment_collections.test_save_writer = Callable()
	service.open_ui()
	await process_frame
	await tap(service.view.find_child("Death523_%s_exp_free" % str(entry.id),true,false))
	await process_frame
	check(world.hud.get_node("Root").get_node_or_null("TwilightConfirmation") != null,"real recovery confirmation opens")
	await tap(world.hud.get_node("Root").find_child("CancelTransaction",true,false))
	check(world.experience != experience_before and service.free_remaining() == 2,"confirmation cancel keeps EXP and quota")
	await tap(service.view.find_child("Death523_%s_exp_free" % str(entry.id),true,false))
	await process_frame
	await tap(world.hud.get_node("Root").find_child("ConfirmTransaction",true,false))
	check(world.experience == experience_before and service.free_remaining() == 1,"actual free recovery UI commits once")
	check(not service.recover(q).ok and service.free_remaining() == 1,"duplicate free request rejected")
	var item_quote: Dictionary = service.quote(str(entry.id),"item","adena")
	check(item_quote.ok,"physical equipment recovery quote")
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not service.recover(item_quote).ok and world.gold == gold_before and not world.item_instances.has("900001"),"failed paid item recovery preserves wallet escrow")
	world.equipment_collections.test_save_writer = Callable()
	check(service.recover(item_quote).ok,"actual item recovery transaction")
	check(world.gold == gold_before-int(item_quote.cost) and int(world.inventory.get(name_value,0)) == 1 and equal(world.item_instances["900001"],physical),"cost and exact physical ID commit together")
	check(not service.recover(item_quote).ok and int(world.inventory.get(name_value,0)) == 1,"duplicate item recovery rejected")
	world._load_game(true)
	await process_frame
	check(not service.blocked() and service.free_remaining() == 1 and int(world.inventory.get(name_value,0)) == 1,"reconnect preserves recovery and free counter")
	check(world.item_instances["900001"].opaque.keep == "unchanged" and int(world.item_instances["900001"].level) == 7,"reconnect preserves custom equipment state")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var corrupt: Dictionary = valid.duplicate(true)
	corrupt[service.KEY].free_used = 3
	check(Writer.write(path,corrupt) == OK,"corrupt new-state fixture through real writer")
	var corrupt_sha: String = FileAccess.get_sha256(path)
	var live_gold: int = world.gold
	world._load_game(true)
	check(service.save_blocked and world.gold == live_gold,"corrupt quota rejected before live mutation")
	check(world._save_game(true) != OK and FileAccess.get_sha256(path) == corrupt_sha,"corrupt source bytes cannot be overwritten")
	check(Writer.write(path,valid) == OK,"restore untouched valid fixture")
	world._load_game(true)
	await process_frame
	check(not service.save_blocked and world.gold == live_gold,"valid reload releases save protection")
	var collision: Dictionary = valid.duplicate(true)
	collision[service.KEY].records[0].item_claimed = false
	check(not service.check_load(collision).is_empty(),"duplicate escrow and owned physical ID rejected")
	# Actual ledger quotes at the source24/72hour boundaries and day rollback.
	service.policy.item_loss_percent = 0.0
	world.player.global_position = danger; world.hp = 1
	world._on_player_bleed_tick(2)
	check(service.resurrect().ok,"second actual bleed death restarts")
	var id2: String = str(service.state.records[-1].id)
	check(service.recover(service.quote(id2,"exp","free")).ok and service.free_remaining() == 0,"second free recovery consumes final user quota")
	world.player.global_position = danger; world.hp = 1
	world._on_player_poison_tick(2)
	check(service.resurrect().ok,"third death restart")
	id2 = str(service.state.records[-1].id)
	check(not service.quote(id2,"exp","free").ok and service.quote(id2,"exp","adena").ok,"third free blocked, paid recovery offered")
	var time2: int = int(service.state.records[-1].at)
	service.test_clock = func() -> int: return time2+86400
	check(not service.quote(id2,"exp","adena").ok and service.quote(id2,"exp","gem").ok,"24hour extension is gem only")
	service.test_clock = func() -> int: return time2+259200
	check(not service.quote(id2,"exp","gem").ok,"72hour expiry blocks payment")
	service.test_clock = func() -> int: return time2
	check(service.now() == time2+259200,"clock rollback cannot reopen expired record")
	check(world._save_game(true) == OK,"high-water clock persists")
	service.open_ui()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/death523-recovery-1280.png")
		root.size = Vector2i(854,480)
		world.hud._fit_hud()
		for frame: int in range(3): await process_frame
		service.open_ui()
		for frame: int in range(3): await process_frame
		check(service.view.get_h_scroll_bar().max_value <= service.view.get_h_scroll_bar().page+2,"small viewport recovery has no horizontal overflow")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/death523-recovery-854.png")
	print("DEATH523_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"scope":"ACTUAL_MAIN_CURRENT_MAP; original source plus controlled item-loss fixture; not server probability approval"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
