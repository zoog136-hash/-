extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
var failures: Array[String]=[]
var checks: int=0
var captures: String=""
var archive: String=""

func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label);printerr("PATCH523_REGISTERED_CRAFT_FAIL: ",label)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):captures=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--source-catalog-zip="):archive=arg.trim_prefix("--source-catalog-zip=")
	call_deferred("run")

func capture(label: String) -> void:
	if captures.is_empty(): return
	await process_frame;await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(captures)
	check(root.get_texture().get_image().save_png(captures.path_join(label+".png"))==OK,"actual source UI capture "+label)

func prepared(book: Object, recipe: Dictionary, choices: Dictionary={}) -> Dictionary:
	var selected: Dictionary=choices.duplicate(true)
	for slot: Dictionary in recipe.get("material_slots",[]):
		if not selected.has(str(int(slot.slot_index))): selected[str(int(slot.slot_index))]=int(slot.candidates[0].row_id)
	var resolved: Dictionary=book.material_selection(recipe.id,selected).recipe
	var inventory: Dictionary={}
	var instances: Dictionary={}
	var next: int=30001
	for material: Dictionary in resolved.materials:
		if material.get("wallet",false):continue
		var key: String=book.ownership_key(material)
		inventory[key]=int(inventory.get(key,0))+int(material.quantity)
		if not material.physical: continue
		for i: int in range(int(material.quantity)):
			var record: Dictionary=book.record(str(material.source_id))
			record["bless_state"]="blessed" if int(material.bless_code)==2 else "normal"
			if record.get("source_m_native_item",false):record["source_bless_raw"]=int(material.bless_code)
			instances[str(next)]={"name":material.item,"record":record,"sourceId":record.sourceId,"level":int(material.level),"element":"","element_level":0,"bless_state":record.bless_state,"source_bless_code":int(material.bless_code)}
			next+=1
	return {"inventory":inventory,"instances":instances,"next":next,"choices":selected,"gold":book.recipe_cost(resolved,1)}

func table_checks(world: TwilightWorld) -> void:
	var book: Object=world.patch523_equipment
	var items: Dictionary=world._patch523_craft_item_index()
	var branches: int=0
	for id: String in book.recipes:
		var recipe: Dictionary=book.recipes[id]
		var state: Dictionary=prepared(book,recipe)
		var before: String=JSON.stringify(state)
		var rolls: Array[int]=[-1]
		if recipe.has("outcomes"):
			rolls.clear();var threshold: int=0
			for outcome: Dictionary in recipe.outcomes:rolls.append(threshold);threshold+=int(outcome.probability)
		for roll: int in rolls:
			var transaction: Dictionary=book.execute(id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,roll,{"level":100,"usage":{},"now":int(Time.get_unix_time_from_system())})
			check(transaction.get("ok",false),"registered real recipe branch executes "+id+" / "+str(roll)+" / "+str(transaction.get("reason","")))
			if not transaction.get("ok",false):continue
			check(transaction.cost==state.gold and JSON.stringify(state)==before,"real recipe costs exact original fee without mutating input snapshot "+id)
			var output: Dictionary=recipe.result
			if roll>=0:
				var threshold: int=0
				for outcome: Dictionary in recipe.outcomes:
					threshold+=int(outcome.probability)
					if roll<threshold: output=outcome;break
			var quantity: int=int(output.quantity)
			if output.get("empty_result",false):check(transaction.inventory.is_empty() and transaction.item_instances.is_empty() and int(transaction.next_instance_id)==int(state.next),"explicit original zero-item branch grants no phantom item or ID "+id)
			if output.get("wallet_currency",false):check(int(transaction.gold_after)==quantity,"source wallet result quantity "+id)
			else: check(int(transaction.inventory.get(book.ownership_key(output),0))==quantity,"source result goes to exact ownership key and quantity "+id)
			if output.physical:
				check(transaction.item_instances.size()==quantity,"source physical result count is independent of consumed instances "+id)
			branches+=1
	print("PATCH523_REGISTERED_MATRIX ",JSON.stringify({"recipes":book.recipes.size(),"branches":branches,"failures":failures.size()}))

func setup(world: TwilightWorld,id: String,choices: Dictionary={}) -> void:
	var state: Dictionary=prepared(world.patch523_equipment,world.patch523_equipment.recipes[id],choices)
	world.inventory=state.inventory;world.item_instances=state.instances;world.next_item_instance_id=state.next
	world.equipped_items.clear();world.gold=int(state.gold)+500
	world.patch523_material_choices[id]=state.choices
	world._update_hud()

func select(world: TwilightWorld,id: String) -> Button:
	world.hud.open_crafting();await process_frame
	var listing: ItemList=world.hud.workspace.find_child("CraftRecipes",true,false)
	for i: int in range(listing.item_count):
		if listing.get_item_metadata(i)==id:
			listing.select(i);listing.item_selected.emit(i)
			return world.hud.workspace.find_child("CraftExecute",true,false)
	return null

func confirm(world: TwilightWorld,action: Button,seed: int=-1) -> void:
	check(action!=null and not action.disabled,"actual registered recipe action enabled")
	if action==null or action.disabled:return
	action.pressed.emit();await process_frame
	var button: Button=world.hud.find_child("ConfirmTransaction",true,false)
	check(button!=null,"actual registered recipe confirmation appears")
	if button!=null:
		if seed>=0:world.rng.seed=seed
		button.pressed.emit()

func seed_for(low: int,high: int) -> int:
	var rng:=RandomNumberGenerator.new()
	for seed: int in range(10000):
		rng.seed=seed;var roll: int=rng.randi_range(0,999999)
		if roll>=low and roll<high:return seed
	return -1

func run() -> void:
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world);world.set_process(false);world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main enters source crafting")
	world.player.set_physics_process(false);world.field_population.set_process(false)
	check(world.patch523_equipment.recipes.size()==732,"732 compiled recipes load with actual registered catalog")
	check(world._catalog_item_from_source_id("m523:item:379").get("name")=="철 · 원본#379","actual native iron registration precedes execution")
	if world.patch523_equipment.recipes.size()!=732:world.queue_free();await process_frame;quit(1);return
	if not archive.is_empty():
		world.hud.open_patch523_equipment_info();await process_frame
		var catalog_dialog: FileDialog=world.hud.workspace.find_child("Patch523CraftCatalogDialog",true,false)
		catalog_dialog.file_selected.emit(archive)
		var catalog_status: Label=world.hud.workspace.find_child("Patch523CraftCatalogStatus",true,false)
		check(catalog_status.text.contains("등록 완료"),"actual source catalog UI installs verified BIN for future sessions")
		var fingerprint: LineEdit=world.hud.workspace.find_child("Patch523PackSHA",true,false)
		var expected_sha: String=OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
		fingerprint.text=expected_sha
		var rules_dialog: FileDialog=world.hud.workspace.find_child("Patch523PackFileDialog",true,false)
		rules_dialog.file_selected.emit(OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES"))
		check(world.PATCH523_STORE.active().get("sha256")==expected_sha,"actual source rules UI installs managed active version")
		await capture("registered-source-installers")
	table_checks(world)
	setup(world,"patch523:13")
	world.inventory["철"]=50
	check(world._save_game(true)==OK,"native material baseline saves")
	var sha: String=FileAccess.get_sha256(world.save_path())
	var before: String=JSON.stringify([world.inventory,world.gold,world.item_instances,world.next_item_instance_id])
	var action: Button=await select(world,"patch523:13")
	await capture("registered-iron-recipe")
	world.source_save_blocked=true;await confirm(world,action)
	check(JSON.stringify([world.inventory,world.gold,world.item_instances,world.next_item_instance_id])==before and FileAccess.get_sha256(world.save_path())==sha,"source material transaction preserves legacy iron, IDs and fee on save failure")
	world.source_save_blocked=false;action=await select(world,"patch523:13");await confirm(world,action)
	check(not world.inventory.has("철 · 원본#379") and int(world.inventory.get("철",0))==50 and world.gold==500 and int(world.inventory.get("해골 투구 (각인)",0))==1,"actual UI consumes20 original iron and10000 Adena while preserving same-name legacy50")
	world.hud.inventory_item_activated.emit("해골 투구 (각인)@@@30001")
	check(world.equipped_items.get("helmet",{}).get("instance_id")=="30001","crafted source helmet uses actual inventory equip path")
	check(world._save_game(true)==OK,"crafted source equipment saves")
	world._load_game(true)
	check(world.item_instances.has("30001") and int(world.inventory.get("철",0))==50,"actual source material craft and physical output survive reload")
	setup(world,"patch523:2561",{"1":306612})
	world.inventory["봉인된 희귀 방어구 제작 비법서 (각인) · 원본#32332"]=1
	world.inventory["봉인된 희귀 방어구 제작 비법서 (각인)"]=1
	action=await select(world,"patch523:2561");await capture("registered-exact-candidates");await confirm(world,action)
	check(not world.inventory.has("봉인된 희귀 방어구 제작 비법서 (각인) · 원본#85282") and int(world.inventory.get("봉인된 희귀 방어구 제작 비법서 (각인) · 원본#32332",0))==1 and int(world.inventory.get("봉인된 희귀 방어구 제작 비법서 (각인)",0))==1,"selected85282 does not consume32332 or old ambiguous name stack")
	check(not world.inventory.has("드래곤의 다이아몬드 · 원본#549") and int(world.inventory.get("희귀 방어구 제작 비법서 (각인)",0))==1,"actual registered source549 is used before host fallback and produces exact book")
	setup(world,"patch523:61563")
	action=await select(world,"patch523:61563");await capture("registered-currency-settlement");await confirm(world,action)
	check(int(world.inventory.get("마법인형 제작 코인",0))==100 and not world.inventory.has("마법인형 코인 · 원본#3252"),"source coin output settles100 into existing game currency instead of dead namespace stack")
	setup(world,"patch523:194223")
	action=await select(world,"patch523:194223");await confirm(world,action)
	check(not world.inventory.has("성물 제작 코인") and int(world.inventory.get("[성물 카드] 타이탄 골렘의 돌주먹 · 원본#283133",0))==1,"source1.1m currency payment consumes existing wallet and gives exact native card inventory key")
	setup(world,"patch523:2001")
	action=await select(world,"patch523:2001");await confirm(world,action,seed_for(150000,1000000))
	check(int(world.inventory.get("퓨어 엘릭서",0))==30 and not world.inventory.has("엘릭서 · 원본#4151") and world.gold==500,"actual original85% failed branch returns30 of35 pure elixirs and consumes100k fee")
	setup(world,"patch523:2001")
	action=await select(world,"patch523:2001");await capture("registered-original-random");await confirm(world,action,seed_for(0,150000))
	check(int(world.inventory.get("엘릭서 · 원본#4151",0))==1 and not world.inventory.has("퓨어 엘릭서"),"actual original15% success gives exactly one original elixir")
	world._load_game(true)
	check(int(world.inventory.get("엘릭서 · 원본#4151",0))==1 and world.gold==500,"actual native result and fee survive final reload")

	setup(world,"patch523:150468")
	check(world._save_game(true)==OK,"explicit zero-item source branch baseline saves")
	sha=FileAccess.get_sha256(world.save_path())
	before=JSON.stringify([world.inventory,world.gold,world.item_instances,world.next_item_instance_id])
	action=await select(world,"patch523:150468")
	await capture("registered-explicit-empty-failure")
	world.source_save_blocked=true
	var failure_seed: int=seed_for(800000,1000000)
	var probe:=RandomNumberGenerator.new();probe.seed=failure_seed
	await confirm(world,action,failure_seed)
	check(JSON.stringify([world.inventory,world.gold,world.item_instances,world.next_item_instance_id])==before and world.rng.state==probe.state and FileAccess.get_sha256(world.save_path())==sha,"zero-result failure branch restores materials,3m fee,RNG and save bytes when save is blocked")
	world.source_save_blocked=false
	action=await select(world,"patch523:150468");await confirm(world,action,failure_seed)
	check(world.inventory.is_empty() and world.item_instances.is_empty() and world.next_item_instance_id==30001 and world.gold==500,"explicit source20% failure consumes3 source coins and3m fee with zero result and no physical ID")
	var empty_saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	check(empty_saved.inventory.is_empty() and empty_saved.item_instances.is_empty() and int(empty_saved.gold)==500,"durable source zero-result transaction contains no phantom item")
	world._load_game(true)
	var loaded_results: Dictionary=world.inventory.duplicate(true)
	loaded_results.erase("화살");loaded_results.erase("총알")
	check(loaded_results.is_empty() and world.gold==500,"source no-item result remains empty after reload while preserving existing ammunition defaults")
	setup(world,"patch523:2")
	action=await select(world,"patch523:2");await confirm(world,action,seed_for(0,990000))
	check(int(world.inventory.get("싸울아비 장검 (각인)",0))==1 and not world.inventory.has("싸울아비 장검"),"actual original99% branch gives engraved equipment only")
	setup(world,"patch523:2")
	action=await select(world,"patch523:2");await capture("registered-source-critical");await confirm(world,action,seed_for(990000,1000000))
	check(int(world.inventory.get("싸울아비 장검",0))==1 and not world.inventory.has("싸울아비 장검 (각인)"),"actual original1% critical branch gives unengraved equipment only")
	world._load_game(true)
	check(int(world.inventory.get("싸울아비 장검",0))==1 and world.item_instances.has("30001"),"critical equipment and distinct original identity survive actual reload")
	world.queue_free();await process_frame
	if not archive.is_empty():
		OS.unset_environment("TWILIGHT_PATCH523_CRAFT_CATALOG_BIN")
		OS.unset_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES")
		OS.unset_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
		var restored: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
		root.add_child(restored);restored.set_process(false);restored.save_timer=-100000.0
		check(QA.enter_game(restored),"fresh actual Main enters from managed data without source environment arguments")
		restored.player.set_physics_process(false);restored.field_population.set_process(false)
		check(restored.patch523_equipment.recipes.size()==732 and not restored._catalog_item_from_source_id("m523:item:379").is_empty(),"fresh Main restores both registered catalog and732 managed recipes")
		check(int(restored.inventory.get("싸울아비 장검",0))==1 and restored.item_instances.has("30001"),"fresh Main preserves original critical result and physical identity")
		restored.queue_free();await process_frame
	print("PATCH523_REGISTERED_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_registered_recipes":732,"actual_ui_recipe_ids":[13,2561,61563,194223,2001,150468,2]}))
	quit(0 if failures.is_empty() else 1)
