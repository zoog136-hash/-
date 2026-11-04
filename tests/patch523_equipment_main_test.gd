extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var checks: int = 0
var capture_dir: String = ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("PATCH523_MAIN_FAIL: ", label)

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("run")

func capture(label: String) -> void:
	if capture_dir.is_empty():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	var path: String = capture_dir.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "OpenGL screenshot " + label)

func run() -> void:
	var packed: PackedScene = load("res://Main.tscn")
	check(packed != null, "actual Main loads")
	if packed == null:
		quit(1)
		return
	var world: TwilightWorld = packed.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "class selection enters actual Main")
	world.player.set_physics_process(false)
	var record: Dictionary = world._catalog_item_from_source_id("30671").duplicate(true)
	check(not record.is_empty(), "exact seal catalog ID exists")
	var recipe_id: String = "patch523:77552"
	var actual_source: bool = not OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES").is_empty()
	if not actual_source:
		# Explicit synthetic transaction fixture on real Main, not source evidence.
		world.patch523_equipment.data = {"items":{"30671":{"catalog_record":record,"item_bonuses":[],"enchant_effects":[]}},"bonuses":{},"enchantment":{}}
		world.patch523_equipment.recipes = {recipe_id:{"id":recipe_id,"name":"Synthetic seal conversion fixture","source_snapshot":"patch523","category":"장신구","adena":0,"popup_text_id":0,
			"materials":[{"item":"수호의 인장","quantity":2,"source_id":"30671","level":3,"bless_code":1,"physical":true}],
			"result":{"item":"수호의 인장","quantity":1,"source_id":"30671","level":3,"bless_code":2,"physical":true}}}
		world.crafting.recipes.merge(world.patch523_equipment.recipes)
	else:
		check(world.patch523_equipment.recipes.size()==159, "private current523 rules installed during Main startup")
	world.inventory["수호의 인장"] = 3
	world.gold = 7654321
	for id: Variant in world.item_instances.keys():
		if world.item_instances[id].get("name", "") == "수호의 인장":
			world.item_instances.erase(id)
	for id: String in ["7001", "7002", "7003"]:
		world.item_instances[id] = {"name":"수호의 인장","level":7 if id=="7003" else 3,"element":"","element_level":0,
			"record":record.duplicate(true),"sourceId":"30671","bless_state":"normal"}
	world.next_item_instance_id = 7004
	world._update_hud()
	check(bool(world._craft_quote(recipe_id,1).get("ok",false)), "actual Main source quote accepts exact two materials")
	check(world._save_game(true)==OK, "baseline durable save succeeds")
	var save_hash: String = FileAccess.get_sha256(world.save_path())
	var before: String = JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id,world.crafting_log])
	world.source_save_blocked = true
	world._craft_requested(recipe_id,1)
	check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id,world.crafting_log])==before,"save guard preserves live materials, IDs, wallet, log and counter")
	check(FileAccess.get_sha256(world.save_path())==save_hash,"failed source craft preserves save bytes")
	world.source_save_blocked = false
	world.hud.open_crafting()
	await process_frame
	var listing: ItemList = world.hud.workspace.find_child("CraftRecipes",true,false)
	check(listing!=null,"existing crafting screen opens")
	if actual_source:
		var search: LineEdit = world.hud.workspace.find_child("CraftNameFilter",true,false)
		check(search!=null,"existing crafting search is available")
		if search!=null:
			search.text = "원본523"
			search.text_changed.emit(search.text)
	var source_index: int = -1
	if listing!=null:
		for i: int in range(listing.item_count):
			if str(listing.get_item_metadata(i))==recipe_id:
				source_index = i
				break
	check(source_index>=0,"source conversion is selectable in existing recipe list")
	if source_index>=0:
		listing.select(source_index)
		listing.ensure_current_is_visible()
		listing.item_selected.emit(source_index)
		var screen: Node = listing.get_parent().get_parent()
		while screen!=null and not screen.has_method("_refresh_quote"):
				screen = screen.get_parent()
		check(screen!=null,"actual crafting controller found")
		if screen!=null:
			check(not screen.action.disabled,"source craft action enabled")
			check(screen.product_name.text.contains("축복") and screen.detail.text.contains("원본523"),"result state and source conditions displayed")
			check(screen.material_rows.size()==1 and screen.material_rows[0].count.text.begins_with("2 / 2"),"UI counts exact +3 materials, excludes +7 instance")
			await capture("source-recipe")
			screen.action.pressed.emit()
			await process_frame
			var confirm: Button = world.hud.find_child("ConfirmTransaction",true,false)
			check(confirm!=null,"source craft uses actual confirmation dialog")
			if confirm!=null:
				confirm.pressed.emit()
				await process_frame
	check(int(world.inventory.get("수호의 인장",0))==2,"UI transaction consumes two and creates one seal")
	check(world.item_instances.has("7003") and not world.item_instances.has("7001") and not world.item_instances.has("7002"),"source transaction preserves unrelated +7 instance")
	check(world.item_instances.has("7004") and int(world.item_instances["7004"].level)==3 and world.item_instances["7004"].bless_state=="blessed","UI result receives declared level, blessing and distinct ID")
	check(world.gold==7654321 and world.next_item_instance_id==7005,"original no-Adena conversion preserves wallet")
	world._load_game(true)
	check(world.item_instances.has("7004") and world.item_instances["7004"].bless_state=="blessed","saved source result reloads through Main")
	if actual_source and world.item_instances.has("7004"):
		world._equip_reference_in_slot("수호의 인장@@@7004", "seal1")
		check(world.equipped_items.get("seal1", {}).get("instance_id", "")=="7004", "source result equips through actual physical-ID path")
		check(world._enhancement_stat_for_slots(["seal1"], "melee_accuracy")==4 and world._enhancement_stat_for_slots(["seal1"], "melee_damage")==1, "crafted Blessed +3 seal affects actual Main stat consumers")
		check(world._save_game(true)==OK, "source enhancement increments persist after equip")
		world._load_game(true)
		check(world._enhancement_stat_for_slots(["seal1"], "melee_accuracy")==4, "source supported options survive Main save reload")
	world.hud.open_patch523_equipment_info()
	await process_frame
	var information: Control = world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
	check(information!=null,"source enhancement information opens from existing HUD")
	if information!=null:
		check(information.equipment.item_count>=2,"information screen uses owned physical IDs")
		if actual_source:
			var produced_choice: int = information.ids.find("7004")
			if produced_choice>=0:
				information.equipment.select(produced_choice)
				information.equipment.item_selected.emit(produced_choice)
			var chosen_scroll: int = information.scroll_ids.find("320802")
			check(chosen_scroll>=0,"actual shining scroll selectable in information UI")
			if chosen_scroll>=0:
				information.scroll.select(chosen_scroll)
				information.scroll.item_selected.emit(chosen_scroll)
				check(information.detail.text.contains("성공") and information.detail.text.contains("통화 미확정"),"actual source probability and unresolved cost rendered")
		await capture("source-enhancement-info")
	world.hud._open_enhance_chooser()
	await process_frame
	check(world.hud.workspace.find_child("Patch523ForgeInfoButton",true,false)!=null,"existing forge links source information")
	world.queue_free()
	await process_frame
	print("PATCH523_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_source":actual_source,"captures":capture_dir}))
	quit(0 if failures.is_empty() else 1)
