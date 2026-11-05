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
	check(service.source.item_exemption_level() == 30 and service.source.item_exemption_origin() == "SOURCE_CONSTANT_APPLIED_TO_LOCAL_ITEM_POLICY","original NoDeathPenaltyLevel feeds existing local item policy only")
	check(service.source.exp_loss(30,50000,100000) == 4999,"native level30 XP loss is independent of item exemption")
	check(service.source.row(159).CumulativeExperience == "20556137784927015" and service.source.row(160).CumulativeExperience == "20556137784927016","native cumulative integers above2pow53 stay exact decimal strings")
	check(service.source.exp_loss(97,50000,100000) == 5000,"placeholder high-level native curve uses configurable custom projection without overflow")
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
	var prior_ledger: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	prior_ledger[service.KEY].erase("slot_expansions")
	check(Writer.write(path,prior_ledger) == OK,"original PR253 ledger fixture without slot fields")
	var prior_sha: String = FileAccess.get_sha256(path)
	world._load_game(true)
	await process_frame
	check(service.slot_capacity("exp") == 5 and service.slot_capacity("item") == 5 and FileAccess.get_sha256(path) == prior_sha,"old ledger defaults slots without rewriting save bytes")
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
	await test_item_exemption_boundaries(world,service,name_value,danger)
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
	id2 = await test_consumers(world,service,id2)
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

func test_consumers(world, service, id: String) -> String:
	check(service.source.certificates.get("895") == "구호 증서" and service.source.certificates.get("198494") == "구호 증서 (각인)","permanent certificates use exact native Currency identities")
	check(service.source.slot_offers.exp.purchase_id == 57324 and service.source.slot_offers.item.purchase_id == 57334 and service.source.slot_offers.exp.behavior_id == 34 and service.source.slot_offers.item.behavior_id == 74,"typed purchase graphs keep behavior IDs separate from currencies")
	check(service.source.slot_offers.exp.cost == 50 and service.source.slot_offers.item.cost == 50,"both native currency namespaces resolve to50Gem")
	var certificate: String = "구호 증서 (각인)"
	world.inventory[certificate] = 2
	world.inventory["구호 증서 (이벤트)"] = 99
	service.state.free_used = 1
	check(not service.quote(id,"exp","certificate").ok,"certificate cannot precede remaining user free quota")
	service.state.free_used = 2
	world.ui_preferences.item_locks[certificate] = true
	check(not service.quote(id,"exp","certificate").ok,"locked certificate never consumed; event stack not substituted")
	world.ui_preferences.item_locks.erase(certificate)
	world.item_instances["900010"] = {"name":certificate,"level":0}
	check(not service.quote(id,"exp","certificate").ok,"physical object conflict rejects ambiguous certificate wallet")
	world.item_instances.erase("900010")
	check(not service.quote(str(service.state.records[0].id),"item","certificate").ok,"certificate is experience recovery currency only")
	var q: Dictionary = service.quote(id,"exp","certificate")
	check(q.ok and q.certificate.source_id == "198494" and q.cost == 1,"certificate quote pins exact engraved ID and configurable quantity")
	var xp: int = world.experience
	var gold: int = world.gold
	var gems: int = int(world.inventory["다이아"])
	var lost: int = int(service._entry(id).exp)
	check(world._save_game(true) == OK,"production save before certificate transaction")
	var sha: String = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not service.recover(q).ok and int(world.inventory[certificate]) == 2 and world.experience == xp and service.free_remaining() == 0 and FileAccess.get_sha256(world.save_path()) == sha,"certificate writer failure preserves stack EXP quota and save")
	world.equipment_collections.test_save_writer = Callable()
	service.open_ui()
	await process_frame
	await tap(service.view.find_child("Death523_%s_exp_certificate" % id,true,false))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/death523-certificate-confirm-1280.png")
	await tap(world.hud.get_node("Root").find_child("CancelTransaction",true,false))
	check(int(world.inventory[certificate]) == 2 and world.experience == xp,"actual certificate confirmation cancel preserves stack and EXP")
	await tap(service.view.find_child("Death523_%s_exp_certificate" % id,true,false))
	await tap(world.hud.get_node("Root").find_child("ConfirmTransaction",true,false))
	check(int(world.inventory[certificate]) == 1 and world.experience == xp+lost and world.gold == gold and int(world.inventory["다이아"]) == gems and service.free_remaining() == 0,"actual certificate UI consumes one exact stack and restores100percent once")
	check(not service.recover(q).ok and service._entry(id).exp_receipt.certificate.source_id == "198494","certificate duplicate rejected and typed receipt retained")
	world._load_game(true)
	await process_frame
	check(int(world.inventory[certificate]) == 1 and service._entry(id).exp_claimed and service.free_remaining() == 0,"certificate receipt stack and fixed quota survive actual reconnect")
	await test_equipped_death_stat(world,service)
	var slot: Dictionary = service.quote_slot("exp")
	check(slot.ok and slot.cost == 50 and slot.amount == 1,"slot expansion quote is native50Gem for one slot")
	sha = FileAccess.get_sha256(world.save_path())
	world.equipment_collections.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not service.expand_slot(slot).ok and service.slot_capacity("exp") == 5 and int(world.inventory["다이아"]) == gems and FileAccess.get_sha256(world.save_path()) == sha,"slot writer failure preserves wallet capacity and bytes")
	world.equipment_collections.test_save_writer = Callable()
	service.open_ui()
	await process_frame
	await tap(service.view.find_child("Death523Slot_exp",true,false))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/workspace/death523-slot-confirm-1280.png")
	await tap(world.hud.get_node("Root").find_child("CancelTransaction",true,false))
	check(service.slot_capacity("exp") == 5 and int(world.inventory["다이아"]) == gems,"actual slot expansion cancel preserves wallet")
	await tap(service.view.find_child("Death523Slot_exp",true,false))
	await tap(world.hud.get_node("Root").find_child("ConfirmTransaction",true,false))
	check(service.slot_capacity("exp") == 6 and service.slot_capacity("item") == 5 and int(world.inventory["다이아"]) == gems-50,"actual expansion UI commits only chosen kind and50Gem")
	check(not service.expand_slot(slot).ok and int(world.inventory["다이아"]) == gems-50,"stale duplicate expansion cannot charge again")
	check(service.expand_slot(service.quote_slot("item")).ok and service.slot_capacity("item") == 6 and int(world.inventory["다이아"]) == gems-100,"item expansion resolves its different native currency namespace")
	world._load_game(true)
	await process_frame
	check(service.slot_capacity("exp") == 6 and service.slot_capacity("item") == 6 and int(world.inventory["다이아"]) == gems-100,"both paid slot kinds and wallet survive reconnect")
	service.policy.maximum_slot_expansions = 1
	check(not service.quote_slot("exp").ok,"configurable expansion cap prevents further charges")
	service.policy.maximum_slot_expansions = 45
	var malformed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	malformed[service.KEY].slot_expansions.exp = -1
	check(not service.check_load(malformed).is_empty(),"corrupt slot state rejected before load")
	# Three real deaths with a deliberately small local QA capacity. Overflow
	# remains escrowed; it unlocks as an older loss is recovered, without deletion.
	service.policy.base_recovery_slots = 1
	var prior_count: int = service.state.records.size()
	var physical: Dictionary = world.item_instances.duplicate(true)
	var latest: String = ""
	for index: int in range(3):
		world.field_map._build_entry_reach()
		for flat: int in world.field_map.entry_cells:
			var point: Vector2 = world.field_map.cell_to_world(Vector2i(flat%world.field_map.width,flat/world.field_map.width))
			if not world.field_map.is_safe(point) and world.field_map.point_clear(point,4): world.player.global_position = point; break
		world.hp = 1
		world._on_player_poison_tick(2)
		check(service.resurrect().ok,"overflow fixture actual death and restart")
		latest = str(service.state.records[-1].id)
	check(service.state.records.size() == prior_count+3 and not service.quote(latest,"exp","adena").ok and equal(world.item_instances,physical),"overflow preserves every record and physical item while waiting")
	var earliest: String = str(service.active_losses("exp")[0])
	check(service.recover(service.quote(earliest,"exp","adena")).ok and service.quote(latest,"exp","adena").ok,"recovering earlier record unlocks overflow without deletion or payment")
	world.inventory.erase(certificate)
	check(not service.quote(latest,"exp","certificate").ok,"event certificates never replace missing permanent currency")
	service.policy.base_recovery_slots = 5
	return latest

func test_equipped_death_stat(world, service) -> void:
	var record: Dictionary = {}
	for candidate: Dictionary in world.catalog_db.get("아이템",[]):
		var sid: String = str(candidate.get("sourceId",""))
		if candidate.get("slot","") == "ring" and service.source.matches_item(candidate,sid) and int(service.source.item_death_stats.get(sid,0)) == 3: record = candidate; break
	check(not record.is_empty(),"existing catalog and native ItemBonus share exact Death-stat ring identity")
	if record.is_empty(): return
	var equipment: Dictionary = world.equipped_items.duplicate(true)
	world.equipped_items.clear()
	var item_name: String = str(record.name)
	var count: int = int(world.inventory.get(item_name,0))
	world.inventory[item_name] = count+1
	world.item_instances["900020"] = {"name":item_name,"record":record.duplicate(true),"level":0,"element":"","element_level":0}
	world.next_item_instance_id = maxi(world.next_item_instance_id,900021)
	world._equip_or_acquire_item(record,false,"900020","ring1")
	check(world._is_instance_equipped("900020") and service.death_stats().value == 3,"real existing equip action derives native KarmaDeath from owned physical ID")
	world.equipped_items["ring2"] = world.equipped_items.ring1.duplicate(true)
	check(service.death_stats().value == 3,"same physical ID in two slots never doubles Death-stat")
	world.equipped_items.erase("ring2")
	world.item_instances["900020"].record.name = "unrelated name"
	check(service.death_stats().value == 0,"wrong-name native ID cannot grant Death-stat")
	world.item_instances["900020"].record.name = item_name
	check(service.death_stats().exp_reduction == 3.0 and service.death_stats().item_reduction == 3.0,"explicit configurable custom coefficients affect only derived existing stat")
	var xp: int = world.experience
	var expected: int = int(floor(service.source.exp_loss(world.level,xp,world.exp_need)*0.97))
	world.field_map._build_entry_reach()
	for flat: int in world.field_map.entry_cells:
		var point: Vector2 = world.field_map.cell_to_world(Vector2i(flat%world.field_map.width,flat/world.field_map.width))
		if not world.field_map.is_safe(point) and world.field_map.point_clear(point,4): world.player.global_position = point; break
	world.hp = 1
	world._on_player_poison_tick(2)
	var entry: Dictionary = service.state.records[-1]
	check(int(entry.exp) == expected and world.experience == xp-expected and int(entry.death_stat_policy.value) == 3,"actual lethal transaction applies and persists snapshot of equipped Death-stat loss relief")
	check(service.resurrect().ok,"Death-stat death restarts through same resurrection service")
	check(service.recover(service.quote(str(entry.id),"exp","adena")).ok and world.experience == xp,"recovery returns exact reduced escrow rather than unreduced EXP")
	world._load_game(true)
	await process_frame
	check(service.death_stats().value == 3 and int(service._entry(str(entry.id)).death_stat_policy.value) == 3,"owned equipped stat and applied death snapshot survive reconnect")
	world.equipped_items = equipment
	world.item_instances.erase("900020")
	if count == 0: world.inventory.erase(item_name)
	else: world.inventory[item_name] = count
	world._invalidate_equipment_static()
	world._update_hud()


func test_item_exemption_boundaries(world, service, item_name: String, danger: Vector2) -> void:
	# Reuse this test's explicitly seeded owned physical equipment. These are
	# real Main poison/death/save/reentry paths, not normal acquisition evidence.
	check(world._save_game(true) == OK,"item boundary baseline production save")
	var path: String = world.save_path()
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for boundary: int in [30,31]:
		world.level = boundary
		# The reviewed local table starts at35. Exercise the production fallback
		# for these controlled lower-level fixtures; native death rates stay intact.
		world.exp_need = world.EXP_PROGRESSION.required_for_level(boundary,int(baseline.exp_need))
		world.experience = int(world.exp_need/2)
		check(world.exp_need > 1 and world.experience > 0,"boundary fixture has positive XP through reviewed local progression")
		world.player.global_position = danger
		world.hp = 1
		check(world._save_game(true) == OK,"item boundary pre-lethal production save")
		var confirmed_writes: Array[int] = [0]
		world.equipment_collections.test_save_writer = func(destination: String,data: Dictionary) -> Error:
			confirmed_writes[0] += 1
			return Writer.write(destination,data)
		world._on_player_poison_tick(2)
		check(confirmed_writes[0] == 1,"boundary death uses exactly one real production writer call")
		check(service.pending.is_empty() and service.state.records.size() == 1,"item boundary produces one confirmed death receipt")
		if service.state.records.size() == 1:
			var entry: Dictionary = service.state.records[0]
			check(int(entry.exp) > 0,"level30 and31 retain native XP loss")
			check(entry.item.is_empty() if boundary == 30 else str(entry.item.get("id","")) == "900001","only level31 enters owned item escrow")
		var duplicate_sha: String = FileAccess.get_sha256(path)
		world._respawn_player("item boundary duplicate callback")
		check(service.state.records.size() == 1 and FileAccess.get_sha256(path) == duplicate_sha,"duplicate boundary death neither saves nor consumes again")
		check(confirmed_writes[0] == 1,"duplicate boundary callback does not call the writer")
		world._load_game(true)
		await process_frame
		check(service.blocked() and world.hp == 0 and FileAccess.get_sha256(path) == duplicate_sha,"boundary death reentry preserves confirmed bytes without replay")
		check(confirmed_writes[0] == 1,"boundary reentry does not call the writer")
		check(world.item_instances.has("900001") == (boundary == 30) and int(world.inventory.get(item_name,0)) == (1 if boundary == 30 else 0),"boundary reentry keeps exactly one ownership location")
		world.equipment_collections.test_save_writer = Callable()
		await test_fresh_item_exemption_process(boundary,item_name,path,duplicate_sha)
		check(FileAccess.get_sha256(path) == duplicate_sha,"fresh process leaves the parent confirmed save unchanged")
		check(Writer.write(path,baseline) == OK,"restore isolated test baseline through production writer")
		world._load_game(true)
		await process_frame
		if is_instance_valid(service.death_overlay):
			service.death_overlay.queue_free()
			service.death_overlay = null
		check(not service.blocked() and world.item_instances.has("900001") and int(world.inventory.get(item_name,0)) == 1,"isolated boundary fixture restores original owned item")

func test_fresh_item_exemption_process(boundary: int, item_name: String, path: String, fingerprint: String) -> void:
	var result_path: String = ProjectSettings.globalize_path("user://death523-item-exemption-probe.json")
	if FileAccess.file_exists(result_path): DirAccess.remove_absolute(result_path)
	var arguments := PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/death523_item_exemption_reentry_probe.gd","--"])
	for argument: String in OS.get_cmdline_user_args():
		# The new process must discover the installed default source, independently
		# of the source archive provided to the parent test's installer.
		if not argument.begins_with("--death523-source=") and not argument.begins_with("--death523-probe-"):
			arguments.append(argument)
	arguments.append("--death523-probe-level="+str(boundary))
	arguments.append("--death523-probe-item="+item_name)
	arguments.append("--death523-probe-save="+ProjectSettings.globalize_path(path))
	arguments.append("--death523-probe-hash="+fingerprint)
	var process: int = OS.create_process(OS.get_executable_path(),arguments)
	check(process > 0,"fresh Main reentry process starts")
	if process <= 0: return
	var started: int = Time.get_ticks_msec()
	while OS.is_process_running(process) and Time.get_ticks_msec()-started < 180000:
		await process_frame
	if OS.is_process_running(process):
		OS.kill(process)
		check(false,"fresh Main reentry process exceeded180second bound")
		return
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_path)) if FileAccess.file_exists(result_path) else null
	check(result is Dictionary and result.get("ok",false) == true and result.get("level",-1) == boundary,"fresh Main process confirms default source and immutable death ownership")
