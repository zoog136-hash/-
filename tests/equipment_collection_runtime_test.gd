extends SceneTree
## Actual Main scene + actual catalog IDs. All saves are isolated by the CI runner.
var failures: Array[String] = []
var checks: int = 0
var world
const Core = preload("res://scripts/collections/equipment_collection_service.gd")
const CID: String = "eqc_b10d34dbc266c4e869ca"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("COLLECTION_FAIL: "+message)

func _give(name_value: String, enchantment: int) -> String:
	var record: Dictionary = world.equipment_collections.icon_record(name_value)
	check(not record.is_empty(),"real catalog item exists: "+name_value)
	if record.is_empty(): return ""
	var id: String = str(world.next_item_instance_id)
	world.next_item_instance_id += 1
	var original: String = str(record.name)
	world.inventory[original] = int(world.inventory.get(original,0))+1
	world.item_instances[id] = {"name":original,"level":enchantment,"record":record.duplicate(true),"sourceId":str(record.sourceId)}
	return id

func _write_raw(text: String) -> void:
	var file := FileAccess.open(world.save_path(),FileAccess.WRITE)
	check(file != null,"test fixture save opens")
	if file != null: file.store_string(text); file.close()

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	check(scene != null,"actual Main scene loads")
	if scene == null: _finish(); return
	world = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.hud.complete_class_selection()
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_process(false); monster.set_physics_process(false)
	var rt = world.equipment_collections
	check(rt.problem.is_empty(),"runtime configured")
	check(rt.definitions().size()==447,"all 447 original canonical IDs retained")
	check(rt.core.resolve(CID).name=="MP를 위한 투자 I","known source collection resolves")
	check(bool(rt.availability(CID).get("ok",false)),"actual source catalog binds known MP collection")
	check(Core.normalize_name("마법 망토 (각인)")=="마법 망토","engraved identity")
	check(Core.normalize_name("축복받은 마법 망토 (각인)")=="축복받은 마법 망토","only engraving removed, blessing kept")
	check(Core.normalize_name("마법 망토 (이벤트)")=="마법 망토 (이벤트)","event identity preserved")
	if not rt.problem.is_empty() or not bool(rt.availability(CID).get("ok",false)):
		world.queue_free(); await process_frame; _finish(); return
	world.inventory = {}
	world.item_instances = {}
	world.equipped_items = {}
	world.equipped_catalog = {"변신":{},"마법인형":{},"성물":{}}
	world.enhancement_levels = {}
	world.next_item_instance_id = 1001
	var normal: String = _give("마법 망토",5)
	var engraved: String = _give("마법 망토 (각인)",5)
	var wrong_level: String = _give("마법 망토",6)
	var helmet: String = _give("마법 방어 투구",5)
	var before_mp: int = world._effective_max_mp()
	check(world._save_game(true)==OK,"whole-game initial save succeeds")
	var definitions: Dictionary = rt.core.resolve(CID)
	var slot1: String = str(definitions.requirements[0].slot_id)
	var slot2: String = str(definitions.requirements[1].slot_id)
	var eligible: Array = rt.candidates(CID,slot1)
	var eligible_ids: Array = []
	for item: Dictionary in eligible: eligible_ids.append(str(item.instance_id))
	check(eligible_ids.has(normal) and eligible_ids.has(engraved),"actual normal/engraved source IDs both accepted")
	check(not eligible_ids.has(wrong_level),"higher enhancement is not silently substituted")
	var state_before: Dictionary = rt.export_state()
	var inventory_before: Dictionary = world.inventory.duplicate(true)
	var instances_before: Dictionary = world.item_instances.duplicate(true)
	var file_before: String = FileAccess.get_file_as_string(world.save_path())
	var locked_key: String = str(world.item_instances[engraved].name)+"@@@"+engraved
	world.ui_preferences.item_locks[locked_key] = true
	check(not bool(rt.register(rt.request_for(CID,slot1,[engraved])).get("ok",false)),"locked exact instance rejected")
	world.ui_preferences.item_locks.erase(locked_key)
	var worn: Dictionary = world.item_instances[engraved].record.duplicate(true)
	worn["instance_id"] = engraved
	world.equipped_items["cloak"] = worn
	check(not bool(rt.register(rt.request_for(CID,slot1,[engraved])).get("ok",false)),"equipped exact instance rejected")
	world.equipped_items = {}
	check(not bool(rt.register(rt.request_for(CID,slot1,[wrong_level])).get("ok",false)),"wrong enhancement rejected")
	var pinned: String = str(world.item_instances[engraved].sourceId)
	world.item_instances[engraved].sourceId = "unknown-id"
	check(not bool(rt.register(rt.request_for(CID,slot1,[engraved])).get("ok",false)),"forged source ID rejected")
	world.item_instances[engraved].sourceId = pinned
	var wrong_count_name: String = str(world.item_instances[engraved].name)
	world.inventory[wrong_count_name] += 1
	check(not bool(rt.register(rt.request_for(CID,slot1,[engraved])).get("ok",false)),"inconsistent stack/physical count rejected")
	world.inventory[wrong_count_name] -= 1
	rt.test_save_writer = func(_path: String,_data: Dictionary) -> Error: return ERR_CANT_CREATE
	check(not bool(rt.register(rt.request_for(CID,slot1,[engraved])).get("ok",false)),"injected disk failure rejected")
	rt.test_save_writer = Callable()
	check(world.inventory==inventory_before,"failure preserves all inventory stacks")
	check(world.item_instances==instances_before,"failure preserves all physical gear")
	check(rt.export_state()==state_before,"failure preserves receipts/progress/revision")
	check(FileAccess.get_file_as_string(world.save_path())==file_before,"failure preserves entire durable save byte-for-byte")
	var request: Dictionary = rt.request_for(CID,slot1,[engraved])
	var first: Dictionary = rt.register(request)
	check(bool(first.get("ok",false)),"real engraved item registers")
	check(not bool(first.get("completed",false)),"partial collection grants no bonus")
	check(world._effective_max_mp()==before_mp,"partial collection does not alter MP")
	check(not world.item_instances.has(engraved),"chosen exact physical ID consumed")
	check(world.item_instances.has(normal) and world.item_instances.has(wrong_level),"other identical-name copies preserved")
	var after_first: Dictionary = rt.export_state()
	var duplicate: Dictionary = rt.register(request)
	check(bool(duplicate.get("ok",false)) and bool(duplicate.get("already_applied",false)),"identical request is idempotent")
	check(rt.export_state()==after_first,"retry never adds a receipt or consumes again")
	var stale: Dictionary = rt.request_for(CID,slot2,[helmet])
	stale.expected_revision = -1
	check(not bool(rt.register(stale).get("ok",false)),"stale revision rejected")
	var finish: Dictionary = rt.register(rt.request_for(CID,slot2,[helmet]))
	check(bool(finish.get("ok",false)) and bool(finish.get("completed",false)),"actual collection completes")
	check(world._effective_max_mp()==before_mp+10,"completed reward reaches actual max MP calculation")
	check(int(rt.bonus("max_mp:flat"))==10,"cached collection bonus computed once")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(saved.equipment_collections.gear.is_empty(),"no competing demo inventory serialized")
	check(saved.equipment_collections.receipts.has(engraved) and not saved.item_instances.has(engraved),"consumption and receipt committed in one save")
	check(saved.has("ground_drops") and saved.has("original_combat_state") and saved.has("warehouse") and saved.has("card_draw_fusion"),"existing world/skills/warehouse/card save fields retained")
	check(not bool(rt.register(rt.request_for(CID,slot1,[normal])).get("ok",false)),"completed slot cannot consume another copy")
	world._load_game(true)
	check(rt.completed(CID) and world._effective_max_mp()==before_mp+10,"save reload does not double bonuses")
	check(not world.item_instances.has(engraved) and not world.item_instances.has(helmet),"reload never resurrects consumed physical IDs")
	saved["future_extension_test"] = {"keep":true}
	saved["next_item_instance_id"] = 1
	_write_raw(JSON.stringify(saved))
	world._load_game(true)
	check(world.next_item_instance_id > int(helmet),"consumed numeric IDs remain reserved on migration")
	check(world._save_game(true)==OK,"resave after accepted external load")
	check(bool(JSON.parse_string(FileAccess.get_file_as_string(world.save_path())).future_extension_test.keep),"unknown save extension preserved")
	var valid_text: String = FileAccess.get_file_as_string(world.save_path())
	_write_raw("{broken")
	world._load_game(true)
	check(rt.save_blocked,"damaged JSON blocks subsequent autosave")
	check(world._save_game(true)!=OK,"corrupt save cannot be silently overwritten")
	check(rt.completed(CID),"rejected load preserves live progress")
	check(FileAccess.get_file_as_string(world.save_path())=="{broken","rejected load preserves disk bytes")
	_write_raw(valid_text)
	world._load_game(true)
	check(not rt.save_blocked,"valid reload releases save protection")
	var invalid_state: Dictionary = JSON.parse_string(valid_text)
	invalid_state.equipment_collections.schema_version = 999
	_write_raw(JSON.stringify(invalid_state))
	world._load_game(true)
	check(rt.save_blocked and rt.completed(CID),"unknown collection schema preserved, not reset")
	_write_raw(valid_text)
	world._load_game(true)
	var legacy: Dictionary = JSON.parse_string(valid_text)
	legacy.erase("equipment_collections")
	_write_raw(JSON.stringify(legacy))
	world._load_game(true)
	check(FileAccess.file_exists(world.save_path()+".pre-equipment-collections"),"legacy save backup created")
	check(rt.progress.receipts.is_empty() and not rt.completed(CID),"legacy save starts empty without invented progress")
	_write_raw(valid_text)
	world._load_game(true)
	# UI controls are actual existing HUD routes, not an independent demo.
	world.hud.toggle_menu()
	check(world.hud.workspace.find_child("MenuTile_equipment_collections",true,false)!=null,"real menu exposes equipment collections")
	world.hud.open_catalog("아이템")
	check(not world.hud.equipment_collection_button.disabled,"actual item encyclopedia shortcut enabled")
	world.hud.open_catalog("변신")
	check(not world.hud.equipment_collection_button.disabled and world.hud.equipment_collection_button.text=="장비 컬렉션","card window exposes clearly named equipment collection route")
	world.hud.open_equipment_collections()
	await process_frame
	var view: Node = world.hud.workspace.content.get_child(0)
	check(view.name=="EquipmentCollectionView","actual workspace mounts native collection screen")
	check(view.list.item_count==447,"native list shows every retained definition")
	view.query.text = "MP를 위한 투자 I"
	view._filter()
	check(view.list.item_count > 0 and view.list.item_count < 447,"native name search filters results")
	view.query.text = ""
	view._filter()
	# Drive the real confirmation callback with another actual catalog-backed slot.
	var second_id: String = "eqc_27cb6afdcc5f7bce2be6"
	var second_row: Dictionary = rt.core.resolve(second_id)
	var second_req: Dictionary = second_row.requirements[0]
	var ui_item: String = _give(str(second_req.name),int(second_req.enchant))
	check(bool(rt.availability(second_id).get("ok",false)),"UI registration target is actually bound")
	view.selected_id = second_id
	view._choose(second_id,str(second_req.slot_id))
	await process_frame
	check(view.candidates_list != null and view.candidates_list.item_count > 0,"native candidate picker populated from real inventory")
	if view.candidates_list != null and view.candidates_list.item_count > 0:
		view.candidates_list.select(0)
		view.find_child("RegisterCollectionItem",true,false).pressed.emit()
		await process_frame
		var dialog: Node = world.hud.get_node("Root").get_node_or_null("TwilightConfirmation")
		check(dialog!=null,"real destructive confirmation opens")
		if dialog != null: dialog.confirm_button.pressed.emit()
		await process_frame
		check(not world.item_instances.has(ui_item),"real confirmation consumes selected physical ID")
		check(rt.slot_count(second_id,str(second_req.slot_id))==1,"real confirmation persists slot progress")
	# Native responsive layouts; only the render variant writes actual PNG captures.
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = resolution
		await process_frame
		await process_frame
		world.hud.workspace.fit_viewport()
		await process_frame
		view._fit()
		check(view.size.x>0 and view.size.y>0,"workspace has visible area "+str(resolution))
		check(view.get_global_rect().size.x<=root.get_visible_rect().size.x+1,"collection fits viewport width "+str(resolution))
		if "--capture-collections" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var folder: String = OS.get_environment("TWILIGHT_COLLECTION_CAPTURE_DIR")
			if folder.is_empty(): folder="user://collection-evidence"
			DirAccess.make_dir_recursive_absolute(folder)
			var image: Image = root.get_texture().get_image()
			check(image.save_png(folder+"/collections_%dx%d.png" % [resolution.x,resolution.y])==OK,"native rendered capture "+str(resolution))
	print("COLLECTION_RUNTIME_SUMMARY "+JSON.stringify(rt.summary()))
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	print("COLLECTION_RUNTIME_RESULT "+JSON.stringify({"checks":checks,"failures":failures}))
	if failures.is_empty(): print("EQUIPMENT_COLLECTION_RUNTIME_OK")
	quit(0 if failures.is_empty() else 1)
