extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const USE = preload("res://scripts/crafting/patch523_item_use.gd")
var failures: Array[String]=[]
var checks: int=0
var capture_dir: String=""

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("PATCH523_USE_FAIL: ",label)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))==OK,"render "+label)

func run() -> void:
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer=-100000.0
	check(QA.enter_game(world),"actual class-selection Main entered")
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	check(world.patch523_equipment.recipes.size()==347,"next original recipes installed")
	if world.patch523_equipment.recipes.size()!=347:
		world.queue_free(); await process_frame; quit(1); return
	world.inventory.clear()
	world.item_instances.clear()
	world.equipped_items.clear()
	world.next_item_instance_id=12001
	var recipe: Dictionary=world.patch523_equipment.recipes["patch523:41172"]
	for slot: Dictionary in recipe.material_slots:
		var material: Dictionary=slot.candidates[0]
		world.inventory[str(material.item)]=int(material.quantity)
	world.gold=100000000
	check(world._save_game(true)==OK,"pre-craft durable state")
	var before: String=JSON.stringify([world.inventory,world.gold,world.item_instances,world.next_item_instance_id])
	var save_sha: String=FileAccess.get_sha256(world.save_path())
	world.hud.open_crafting()
	await process_frame
	var listing: ItemList=world.hud.workspace.find_child("CraftRecipes",true,false)
	var index: int=-1
	for i: int in range(listing.item_count):
		if listing.get_item_metadata(i)=="patch523:41172": index=i
	check(index>=0,"new legendary helmet recipe in real crafting UI")
	listing.select(index); listing.item_selected.emit(index)
	var chooser: OptionButton=world.hud.workspace.find_child("Patch523Candidate_1",true,false)
	check(chooser!=null and chooser.item_count==4,"original three book alternatives exposed")
	chooser.select(1); chooser.item_selected.emit(1)
	var execute: Button=world.hud.workspace.find_child("CraftExecute",true,false)
	var detail: RichTextLabel=world.hud.workspace.find_child("CraftAvailability",true,false)
	check(not execute.disabled and detail.text.contains("원본 사용 조건") and detail.text.contains("기사"),"source use qualifications shown without pretending they are craft restrictions")
	await capture("legendary-source-craft")
	world.source_save_blocked=true
	execute.pressed.emit()
	await process_frame
	var confirm: Button=world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"new source recipe normal confirmation")
	confirm.pressed.emit()
	check(JSON.stringify([world.inventory,world.gold,world.item_instances,world.next_item_instance_id])==before and FileAccess.get_sha256(world.save_path())==save_sha,"blocked save preserves 50m fee, exact materials, physical IDs and durable bytes")
	world.source_save_blocked=false
	world._craft_requested("patch523:41172",1)
	check(world.gold==50000000 and int(world.inventory.get("진명황의 투구",0))==1 and world.item_instances.has("12001"),"source recipe consumes original 50m and creates physical legendary helmet")
	check(not world.inventory.has("전설 제작 비법서") and not world.inventory.has("다크엘프 영혼 결정체"),"selected book and exact 2000 source material consumed")
	var rec: Dictionary=world.item_instances["12001"].record
	check(USE.reason(rec,35,1).is_empty() and not USE.reason(rec,35,3).is_empty(),"exact ItemClassLimit is saved on produced physical record")
	world.hud.inventory_item_activated.emit("진명황의 투구@@@12001")
	check(world.equipped_items.get("helmet",{}).get("instance_id","")=="12001","actual inventory use equips original class-eligible helmet")
	world._open_inventory()
	await process_frame
	var bag: Node=world.hud.lineage_inventory_ui
	bag._select_item("진명황의 투구@@@12001")
	bag.find_child("InventoryDetail",true,false).pressed.emit()
	await process_frame
	check(bag.detail_panel.is_visible_in_tree(),"real inventory detail button opens source qualification panel")
	check(bag.detail_text.text.contains("원본 사용 조건") and bag.detail_text.text.contains("기사"),"inventory detail displays saved source equipment qualification")
	await capture("source-item-use")
	world.job_class="마법사"
	world._enforce_patch523_equipment_use()
	world._update_hud()
	await process_frame
	bag._refresh_detail("진명황의 투구@@@12001")
	check(bag.detail_action.disabled,"inventory disables source gear use for disallowed class")
	world.hud.inventory_item_activated.emit("진명황의 투구@@@12001")
	check(world.equipped_items.get("helmet",{}).is_empty() and world.item_instances.has("12001") and int(world.inventory.get("진명황의 투구",0))==1,"wrong-class real inventory use is rejected without losing item")
	world.inventory["오만의 탑 1층 이동 주문서"]=1
	var teleport: Dictionary=world._patch523_use_record("오만의 탑 1층 이동 주문서")
	check(not USE.reason(teleport,67,3).is_empty() and USE.reason(teleport,68,3).is_empty(),"actual source LevelLimitMin68 uses inclusive boundary")
	world.level=67
	world.hud.inventory_item_activated.emit("오만의 탑 1층 이동 주문서")
	check(int(world.inventory["오만의 탑 1층 이동 주문서"])==1,"below-level source item activation consumes nothing")
	world.level=68
	world.job_class="기사"
	world.hud.inventory_item_activated.emit("진명황의 투구@@@12001")
	check(world._save_game(true)==OK,"qualified helmet and source metadata save")
	world.patch523_equipment=world.PATCH523_EQUIPMENT.new()
	world._load_game(true)
	check(world.equipped_items.get("helmet",{}).get("instance_id","")=="12001" and not USE.reason(world.item_instances["12001"].record,68,3).is_empty(),"saved equipment use constraints survive loading without private pack")
	world._load_patch523_equipment()
	await probability_and_payment(world)
	world.queue_free()
	await process_frame
	print("PATCH523_USE_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func select_recipe(world: TwilightWorld, id: String) -> Node:
	world.hud.open_crafting()
	await process_frame
	var listing: ItemList=world.hud.workspace.find_child("CraftRecipes",true,false)
	for i: int in range(listing.item_count):
		if listing.get_item_metadata(i)==id:
			listing.select(i); listing.item_selected.emit(i)
			return world.hud.workspace.find_child("CraftExecute",true,false)
	return null

func seed_for(lower: int, upper: int) -> int:
	var probe:=RandomNumberGenerator.new()
	for value: int in range(10000):
		probe.seed=value
		var roll: int=probe.randi_range(0,999999)
		if roll>=lower and roll<upper: return value
	return -1

func probability_and_payment(world: TwilightWorld) -> void:
	var book: Object=world.patch523_equipment
	world.inventory.clear(); world.item_instances.clear(); world.equipped_items.clear()
	world.gold=5000
	var shirt: Dictionary=book.record("44932")
	world.inventory[str(shirt.name)]=1
	world.inventory["드래곤의 다이아몬드"]=200
	world.item_instances["15001"]={"name":shirt.name,"record":shirt,"sourceId":"44932","level":9,"element":"","element_level":0,"bless_state":"normal"}
	world.next_item_instance_id=15002
	var execute: Button=await select_recipe(world,"patch523:77742")
	check(execute!=null and not execute.disabled,"official random shirt craft is reachable and executable")
	var detail: RichTextLabel=world.hud.workspace.find_child("CraftAvailability",true,false)
	check(detail.text.contains("90.0000%") and detail.text.contains("10.0000%") and detail.text.contains("TWILIGHT 호환 설정"),"actual UI displays both official rates and host material binding")
	var odds: Label=world.hud.workspace.find_child("Patch523CraftOdds",true,false)
	check(odds.visible and odds.text.contains("10.00%") and odds.text.contains("90.00%"),"probability is always visible above action without scrolling")
	check(world.hud.workspace.find_child("CraftQuantity",true,false).max_value==1,"random UI limits one committed draw")
	await capture("official-random-craft")
	world.source_save_blocked=true
	var before: String=JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id])
	world.rng.seed=seed_for(0,900000)
	var rng_state: int=world.rng.state
	world._craft_requested("patch523:77742",1)
	check(JSON.stringify([world.inventory,world.item_instances,world.gold,world.next_item_instance_id])==before and world.rng.state==rng_state,"random save failure preserves material, physical identity and RNG")
	world.source_save_blocked=false
	execute.pressed.emit()
	await process_frame
	var confirm: Button=world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"probability craft has actual confirmation")
	world.rng.seed=seed_for(0,900000)
	confirm.pressed.emit()
	await process_frame
	check(world.item_instances.has("15001") and int(world.item_instances["15001"].level)==9 and world.next_item_instance_id==15002 and int(world.inventory["드래곤의 다이아몬드"])==100,"official failure returns same +9 shirt physical ID and consumes exactly 100 bound host material")
	world._load_game(true)
	check(world.item_instances.has("15001") and int(world.inventory["드래곤의 다이아몬드"])==100,"random failure return and consumption persist")
	world.rng.seed=seed_for(900000,1000000)
	world._craft_requested("patch523:77742",1)
	check(not world.item_instances.has("15001") and world.item_instances.has("15002") and int(world.item_instances["15002"].level)==0 and int(world.inventory.get("영웅의 빛나는 완력 티셔츠",0))==1 and not world.inventory.has("드래곤의 다이아몬드"),"official success creates the declared new Hero +0 physical shirt exactly once")
	world.hud.inventory_item_activated.emit("영웅의 빛나는 완력 티셔츠@@@15002")
	check(world.equipped_items.get("tshirt",{}).get("instance_id","")=="15002","random source equipment output is usable through actual inventory UI")
	world.inventory["지배석 파편 (각인)"]=10
	world.rng.seed=seed_for(900000,1000000)
	world._craft_requested("patch523:221973",1)
	check(int(world.inventory.get("일반 지배석 상자",0))==1 and not world.inventory.has("일반 지배석 상자 (각인)") and not world.inventory.has("지배석 파편 (각인)"),"official 10% critical branch grants unengraved box only")
	# Exact original alternative payments: 500m wallet OR 2000 diamonds.
	world.inventory.clear(); world.item_instances.clear(); world.equipped_items.clear()
	world.next_item_instance_id=18001
	world.gold=1000000000
	var recipe: Dictionary=book.recipes["patch523:120"]
	for slot: Dictionary in recipe.material_slots:
		if int(slot.slot_index)==5: continue
		var material: Dictionary=slot.candidates[0]
		world.inventory[str(material.item)]=int(material.quantity)
	execute=await select_recipe(world,"patch523:120")
	for slot: String in ["1","5"]:
		var choice: OptionButton=world.hud.workspace.find_child("Patch523Candidate_"+slot,true,false)
		choice.select(1); choice.item_selected.emit(1)
	var quote: Dictionary=world._craft_quote("patch523:120",1)
	check(bool(quote.get("ok",false)) and int(quote.cost)==500000000,"original 500m wallet candidate selected without material quantity truncation")
	await capture("original-payment-choice")
	world.source_save_blocked=true
	before=JSON.stringify([world.inventory,world.gold,world.next_item_instance_id])
	world._craft_requested("patch523:120",1)
	check(JSON.stringify([world.inventory,world.gold,world.next_item_instance_id])==before,"large wallet source transaction is preserved on save failure")
	world.source_save_blocked=false
	world._craft_requested("patch523:120",1)
	check(world.gold==500000000 and int(world.inventory.get("드래곤 슬레이어",0))==1 and world.item_instances.has("18001"),"original wallet payment crafts Mythic source weapon and charges exactly 500m")
	for slot: Dictionary in recipe.material_slots:
		if int(slot.slot_index)==5: continue
		var material: Dictionary=slot.candidates[0]
		world.inventory[str(material.item)]=int(material.quantity)
	world.inventory["드래곤의 다이아몬드"]=2000
	execute=await select_recipe(world,"patch523:120")
	var payment: OptionButton=world.hud.workspace.find_child("Patch523Candidate_5",true,false)
	payment.select(2); payment.item_selected.emit(2)
	quote=world._craft_quote("patch523:120",1)
	check(bool(quote.get("ok",false)) and int(quote.cost)==0,"alternative original diamond payment does not also charge wallet")
	world._craft_requested("patch523:120",1)
	check(world.gold==500000000 and int(world.inventory.get("드래곤 슬레이어",0))==2 and not world.inventory.has("드래곤의 다이아몬드") and world.item_instances.has("18002"),"explicit alternative consumes 2000 material and grants a distinct second Mythic physical ID")
	world._load_game(true)
	check(world.gold==500000000 and world.item_instances.has("18001") and world.item_instances.has("18002"),"both payment paths survive actual Main reload")
