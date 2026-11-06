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
	# Pending population must not consume test RNG while awaiting UI frames.
	world.field_population.set_process(false)
	var record: Dictionary = world._catalog_item_from_source_id("30671").duplicate(true)
	check(not record.is_empty(), "exact seal catalog ID exists")
	var recipe_id: String = "patch523:77552"
	var actual_source: bool = not OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES").is_empty()
	if not actual_source:
		# Explicit synthetic transaction fixture on real Main, not source evidence.
		# Synthetic cached ItemCraft* join rows keep the source recipe contract active.
		var view: Dictionary = {"ItemCraftID":77552,"ItemClassID":30671,"Amount":1,"Enchant":3,"ItemBlessCodeID":2,"ServerLimitSetID":0,"IsCoalitionItem":false,"NoRepeat":false,"IsBelowLevelLimit":false,"LevelLimitValue":0,"CraftTimeTypeID":1,"EffectiveFrom":1,"EffectiveTo":3,"PopupText":0,"AlwaysSuccess":1}
		world.patch523_equipment.data = {"items":{"30671":{"catalog_record":record,"item_class":{"ID":30671,"TestItem":false},"item_bonuses":[],"enchant_effects":[]}},"bonuses":{},"enchantment":{},
			"raw_recipes":{"inputs":{"77552":[{"ID":1,"ItemCraftID":77552,"SlotIndex":0,"ItemClassID":30671,"Amount":2,"Enchant":3,"ItemBlessCodeID":1}]},
				"outputs":{"77552":[{"ItemCraftID":77552,"ItemCraftOutputTypeID":1,"ItemClassID":30671,"Amount":1,"Enchant":3,"ItemBlessCodeID":2,"Probability":1000000}]},
				"views":{"77552":[view]},"restrictions":{"77552":[]}}}
		world.patch523_equipment.recipes = {recipe_id:{"id":recipe_id,"source_craft_id":77552,"name":"Synthetic seal conversion fixture","source_snapshot":"patch523","category":"장신구","adena":0,"popup_text_id":0,
			"materials":[{"item":"수호의 인장","quantity":2,"source_id":"30671","level":3,"bless_code":1,"physical":true,"row_id":1,"slot_index":0}],
			"result":{"item":"수호의 인장","quantity":1,"source_id":"30671","level":3,"bless_code":2,"physical":true}}}
		world.crafting.recipes.merge(world.patch523_equipment.recipes)
	else:
		check(world.patch523_equipment.recipes.size()==347, "private current523 rules installed during Main startup")
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
	if actual_source: await continuation(world)
	world.queue_free()
	await process_frame
	print("PATCH523_MAIN_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_source":actual_source,"captures":capture_dir}))
	quit(0 if failures.is_empty() else 1)

func continuation(world: TwilightWorld) -> void:
	var source_path: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES")
	var expected: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
	world.hud.open_patch523_equipment_info()
	await process_frame
	var info: Node = world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
	check(info!=null and info.find_child("Patch523InstallPack",true,false)!=null,"pack installer is reachable from ordinary game UI")
	if info!=null:
		info.pack_sha.text = expected
		info.find_child("Patch523InstallPack",true,false).pressed.emit()
		check(info.pack_dialog.visible,"native rules file chooser opens")
		info.pack_dialog.file_selected.emit(source_path)
		await process_frame
		check(world.patch523_equipment.recipes.size()==347,"GUI pack installation activates all admitted recipes")
		var saved: Dictionary = world.PATCH523_STORE.active()
		check(saved.get("sha256","")==expected and FileAccess.get_sha256(str(saved.get("path","")))==expected,"GUI installation persists verified private bytes")
		OS.set_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES","")
		world.patch523_equipment = world.PATCH523_EQUIPMENT.new()
		world.crafting.load_recipes()
		world._load_patch523_equipment()
		check(world.patch523_equipment.recipes.size()==347,"normal startup restores installed pack without environment path")
		OS.set_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES",source_path)
	# Current host probability is unchanged; only exact physical record lookup
	# and durable commit semantics are extended to source-crafted equipment.
	var scroll: String = "장신구 마법 주문서 (각인)"
	world.inventory[scroll] = 2
	var probe := RandomNumberGenerator.new()
	var seed_value: int = 1
	while true:
		probe.seed = seed_value
		if probe.randf_range(0.0,100.0) < float(world._enhancement_chance("accessory",3,"normal").success): break
		seed_value += 1
	world.rng.seed = seed_value
	var rng_state: int = world.rng.state
	var before: String = JSON.stringify([world.inventory,world.item_instances,world.equipped_items])
	check(world._save_game(true)==OK,"source equipment pre-enhancement save")
	var save_sha: String = FileAccess.get_sha256(world.save_path())
	world.source_save_blocked = true
	world.hud.enhancement_requested.emit(scroll,"수호의 인장@@@7004")
	check(JSON.stringify([world.inventory,world.item_instances,world.equipped_items])==before and world.rng.state==rng_state,"failed enhancement save restores scroll, physical state, equipment and RNG")
	check(FileAccess.get_sha256(world.save_path())==save_sha,"failed enhancement save preserves durable bytes")
	world.source_save_blocked = false
	world.hud.enhancement_requested.emit(scroll,"수호의 인장@@@7004")
	check(int(world.item_instances["7004"].level)==4 and int(world.inventory.get(scroll,0))==1,"existing enhancement UI signal upgrades crafted physical item with existing price/rate")
	check(world._enhancement_stat_for_slots(["seal1"],"melee_accuracy")==5,"enhancing crafted seal selects exact next supported source row")
	check(world._experience_multiplier()>=1.06 and world._blessing_consumption_reduction_percent()>=3.0,"source XP and Einasad saving reach existing host consumers")
	if world.hud.is_enhancement_presenting():
		world.hud.enhancement_reveal.skip_to_result()
		world.hud.enhancement_reveal.close_reveal()
	await process_frame
	world._load_game(true)
	check(int(world.item_instances["7004"].level)==4,"enhanced source level survives actual save/load")
	# Real rune conversion has two alternative original SlotIndex1 rows.
	for pair: Array in [["884","8001"],["886","8002"]]:
		var rec: Dictionary = world.patch523_equipment.record(pair[0])
		world.inventory[str(rec.name)] = 1
		world.item_instances[pair[1]] = {"name":rec.name,"record":rec,"sourceId":pair[0],"level":0,"element":"","element_level":0,"bless_state":"normal"}
	world.next_item_instance_id = 8003
	world.hud.open_crafting()
	await process_frame
	var listing: ItemList = world.hud.workspace.find_child("CraftRecipes",true,false)
	var selected: int = -1
	for i: int in range(listing.item_count):
		if listing.get_item_metadata(i)=="patch523:54083": selected=i
	check(selected>=0,"real candidate recipe appears in existing crafting UI")
	if selected>=0:
		listing.select(selected)
		listing.item_selected.emit(selected)
		var chooser: OptionButton = world.hud.workspace.find_child("Patch523Candidate_1",true,false)
		check(chooser!=null and chooser.item_count==3,"candidate selector exposes both original rune rows")
		check(not bool(world._craft_quote("patch523:54083",1).get("ok",false)),"candidate recipe cannot execute before deliberate choice")
		if chooser!=null:
			chooser.select(2)
			chooser.item_selected.emit(2)
			check(bool(world._craft_quote("patch523:54083",1).get("ok",false)),"explicit candidate selection enables authoritative quote")
			await capture("source-candidates")
			var execute: Button = world.hud.workspace.find_child("CraftExecute",true,false)
			execute.pressed.emit()
			await process_frame
			var confirm: Button = world.hud.find_child("ConfirmTransaction",true,false)
			check(confirm!=null,"candidate craft has normal transaction confirmation")
			if confirm!=null: confirm.pressed.emit()
			await process_frame
	check(world.item_instances.has("8001") and not world.item_instances.has("8002"),"only chosen wisdom rune physical ID is consumed")
	check(int(world.inventory.get("룬 변환석",0))==1,"chosen original recipe output reaches actual inventory")
	# Source recovery seal: inventory equip + shared quick/inventory HP potion.
	var recovery: Dictionary = world.patch523_equipment.record("130551")
	world.inventory["회복의 인장"] = 2
	for id: String in ["8101","8102"]:
		world.item_instances[id] = {"name":"회복의 인장","record":recovery.duplicate(true),"sourceId":"130551","level":8,"element":"","element_level":0,"bless_state":"normal"}
	world.next_item_instance_id = 8103
	world._craft_requested("patch523:77712",1)
	check(world.item_instances.has("8103"),"recovery source recipe produces Blessed +8 physical item")
	world._equip_reference_in_slot("회복의 인장@@@8103","seal2")
	check(world._enhancement_stat_for_slots(["seal2"],"potion_cooldown_pct")==6,"recovery cooldown effect reaches shared item consumer")
	world.inventory["HP 물약"] = 3
	world.hp = 1
	world.item_use_cooldowns.clear()
	world._use_quick_item("HP 물약")
	check(int(world.inventory.get("HP 물약",0))==2 and world.hp>=87,"source potion flat/rate actually affect inventory/quick item healing")
	check(float(world.item_use_cooldowns.get(world.HP_POTION_COOLDOWN_KEY,100.0)) < world.HP_POTION_COOLDOWN_SECONDS,"source potion cooldown reduces actual shared cooldown")
	check(world._stun_resistance_stat()>=13,"source targeted stun resistance reaches existing combat consumer")
	check(world._save_game(true)==OK,"continuation state saves normally")
	check(world._enhancement_chance("weapon",9,"craftsman",world.patch523_equipment.record("322")).success==5.0,"source-identified Hero weapon uses official craftsman 5%, not old host 0.6%")
	check(world._enhancement_level_allowed("weapon","craftsman",10,world.patch523_equipment.record("176582")) and not world._enhancement_level_allowed("weapon","craftsman",10,world.patch523_equipment.record("322")),"actual Main enforces official craftsman grade/level qualification")
	check(world._enhancement_chance("weapon",9,"craftsman").success==0.6,"unidentified host probability remains unchanged")
	var wallet_before: int=world.gold
	world.inventory["오크족 토템 (각인)"]=100
	world.source_save_blocked=true
	world._craft_requested("patch523:1572",1)
	check(world.gold==wallet_before and int(world.inventory["오크족 토템 (각인)"])==100,"currency-output save failure preserves wallet and materials")
	world.source_save_blocked=false
	world._craft_requested("patch523:1572",1)
	check(world.gold==wallet_before+20000 and not world.inventory.has("오크족 토템 (각인)") and not world.inventory.has("아데나"),"original 100 totems produce exactly 20000 wallet Adena, never inventory currency")
	world._load_game(true)
	check(world.gold==wallet_before+20000,"source currency-output transaction persists")
	await native_seal_actions(world)

func finish_reveal(world: TwilightWorld) -> void:
	if world.hud.is_enhancement_presenting():
		world.hud.enhancement_reveal.skip_to_result()
		world.hud.enhancement_reveal.close_reveal()
	await process_frame

func native_seal_actions(world: TwilightWorld) -> void:
	# Actual inventory activation opens the permanent, guaranteed source box.
	world.inventory["수호의 인장 상자"] = 2
	world.next_item_instance_id=9001
	var initial_scrolls: int = int(world.inventory.get("빛나는 장비 강화 주문서",0))
	var initial_seals: int = int(world.inventory.get("수호의 인장",0))
	world.source_save_blocked=true
	world._patch523_open_box("30701")
	check(int(world.inventory["수호의 인장 상자"])==2 and not world.item_instances.has("9001"),"failed source box save consumes nothing and grants nothing")
	world.source_save_blocked=false
	world.hud.inventory_item_activated.emit("수호의 인장 상자")
	await process_frame
	var confirm: Button = world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"inventory source box has actual confirmation UI")
	if confirm!=null: confirm.pressed.emit()
	await process_frame
	check(int(world.inventory["수호의 인장 상자"])==1 and int(world.inventory.get("수호의 인장",0))==initial_seals+1 and int(world.inventory.get("빛나는 장비 강화 주문서",0))==initial_scrolls+8,"source box gives both exact guaranteed rewards")
	check(world.item_instances.has("9001") and int(world.item_instances["9001"].level)==0 and world.patch523_equipment.bless_code(world.item_instances["9001"])==1,"box creates distinct original Normal +0 physical seal")
	var quote: Dictionary = world.patch523_seal_quote("9001","320802")
	check(bool(quote.get("ok",false)) and quote.success==62 and int(quote.count)==1 and int(quote.cost)==1000 and quote.economy_label.contains("자체 설정"),"ordinary source quote uses official rate and labels unresolved economic fallback")
	check(not bool(world.patch523_seal_quote("7004","320802").get("ok",false)),"ordinary source branch never assumes blessed target0 eligibility")
	check(not bool(world.patch523_seal_quote("9001","336978").get("ok",false)),"expired event scroll excluded from permanent source action")
	# Protected Blessed +4, exactly 3 scrolls and source Cost=11000.
	world.inventory["빛나는 장비 보호 주문서"]=6
	quote=world.patch523_seal_quote("7004","166044")
	check(bool(quote.get("ok",false)) and quote.success==7.5 and int(quote.count)==3 and int(quote.cost)==11000 and quote.protected,"protected Blessed branch matches exact official chance and source consumption")
	var probe := RandomNumberGenerator.new()
	var seed_value: int=1
	while true:
		probe.seed=seed_value
		if probe.randf_range(0.0,100.0)<7.5: break
		seed_value+=1
	world.rng.seed=seed_value
	var before: String=JSON.stringify([world.inventory,world.item_instances,world.equipped_items,world.gold])
	var state: int=world.rng.state
	world.source_save_blocked=true
	world._patch523_attempt_seal("7004","166044")
	check(JSON.stringify([world.inventory,world.item_instances,world.equipped_items,world.gold])==before and world.rng.state==state,"native source save failure rolls back money, scrolls, physical IDs and RNG")
	world.source_save_blocked=false
	var before_gold: int=world.gold
	world.hud.open_patch523_equipment_info()
	await process_frame
	var info: Node=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
	info.equipment.select(info.ids.find("7004"))
	info.scroll.select(info.scroll_ids.find("166044"))
	info._refresh()
	check(not info.source_action.disabled and info.detail.text.contains("7.5000%"),"source execution UI shows exact chance and is enabled only after authoritative quote")
	await capture("source-protected-enhancement")
	info.source_action.pressed.emit()
	await process_frame
	confirm=world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"native source enhancement uses normal irreversible-action confirmation")
	world.rng.seed=seed_value
	if confirm!=null: confirm.pressed.emit()
	await process_frame
	check(int(world.item_instances["7004"].level)==5 and int(world.inventory["빛나는 장비 보호 주문서"])==3 and world.gold==before_gold-11000,"actual UI native attempt applies source +1, three scrolls and fee once")
	await finish_reveal(world)
	world._load_game(true)
	check(int(world.item_instances["7004"].level)==5 and world.gold==before_gold-11000,"native enhancement durable state reloads")
	# Failure retains protected equipment. Select deterministic failure, no reroll.
	world.inventory["빛나는 장비 보호 주문서"]=10
	seed_value=1
	while true:
		probe.seed=seed_value
		if probe.randf_range(0.0,100.0)>=5.0: break
		seed_value+=1
	world.rng.seed=seed_value
	world._patch523_attempt_seal("7004","166044")
	check(int(world.item_instances["7004"].level)==5 and not world.inventory.has("빛나는 장비 보호 주문서"),"failed +5 protected attempt consumes ten scrolls and preserves equipment")
	await finish_reveal(world)
	# Ordinary failure destroys only the exact chosen physical ID.
	seed_value=1
	while true:
		probe.seed=seed_value
		if probe.randf_range(0.0,100.0)>=62.0: break
		seed_value+=1
	world.rng.seed=seed_value
	world._patch523_attempt_seal("9001","320802")
	check(not world.item_instances.has("9001") and world.item_instances.has("7004"),"ordinary source failure destroys selected seal only")
	await finish_reveal(world)
