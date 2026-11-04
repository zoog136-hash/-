extends SceneTree
const QA=preload("res://tests/qa_class_selection.gd")
const LIMITS=preload("res://scripts/crafting/patch523_craft_conditions.gd")
var checks: int=0
var failures: Array[String]=[]
var capture_dir: String=""

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		printerr("PATCH523_LIMIT_FAIL: ",label)

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
	call_deferred("run")

func capture(label: String) -> void:
	if capture_dir.is_empty(): return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_dir)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(label+".png"))==OK,"actual UI capture "+label)

func select_recipe(world: TwilightWorld, id: String) -> Button:
	world.hud.open_crafting()
	await process_frame
	var listing: ItemList=world.hud.workspace.find_child("CraftRecipes",true,false)
	for i: int in range(listing.item_count):
		if listing.get_item_metadata(i)==id:
			listing.select(i); listing.item_selected.emit(i)
			return world.hud.workspace.find_child("CraftExecute",true,false)
	return null

func snapshot(world: TwilightWorld) -> String:
	return JSON.stringify([world.inventory,world.gold,world.item_instances,world.next_item_instance_id,world.crafting_log,world.patch523_crafting_usage])

func clock_checks(recipe: Dictionary) -> void:
	var anchor: int=int(recipe.craft_conditions.quota.anchor_unix)
	var now: int=anchor+604800*2900
	var original: Dictionary={}
	var initial: Dictionary=LIMITS.stage(recipe,10,{"usage":original,"now":now,"level":68})
	check(initial.get("ok",false) and original.is_empty(),"full source weekly quota stages without mutating current ledger")
	var exhausted: Dictionary=initial.get("usage_after",{})
	check(not LIMITS.stage(recipe,1,{"usage":exhausted,"now":now+604799,"level":68}).get("ok",false),"weekly quota remains exhausted immediately before configured boundary")
	var renewed: Dictionary=LIMITS.stage(recipe,1,{"usage":exhausted,"now":now+604800,"level":68})
	check(renewed.get("ok",false) and int(renewed.usage_after.recipes[recipe.id].used)==1,"exact configured next-week boundary stages one new attempt")
	check(not LIMITS.stage(recipe,1,{"usage":renewed.usage_after,"now":now,"level":68}).get("ok",false),"clock rollback cannot reopen a consumed prior period")
	var changed: Dictionary=recipe.duplicate(true)
	changed.craft_conditions.quota.period_seconds=3600
	check(not LIMITS.valid(changed.craft_conditions),"host reset schedule cannot shorten the confirmed original weekly period")
	changed=recipe.duplicate(true)
	changed.craft_conditions.quota.anchor_unix+=3600
	check(not LIMITS.stage(changed,1,{"usage":exhausted,"now":now+604800,"level":68}).get("ok",false),"changing reset policy cannot silently erase a saved quota")
	for damaged: Variant in [[],{"schema":1,"recipes":[]},{"schema":1,"recipes":{recipe.id:{"used":-1,"bucket":2900,"schedule":"604800:504000"}}}]:
		check(not LIMITS.stage(recipe,1,{"usage":LIMITS.restore(damaged),"now":now,"level":68}).get("ok",false),"damaged quota save fails closed rather than granting free attempts")

func run() -> void:
	var world: TwilightWorld=(load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false); world.save_timer=-100000.0
	check(QA.enter_game(world),"actual Main entered through class selection")
	world.player.set_physics_process(false); world.field_population.set_process(false)
	check(world.patch523_equipment.recipes.size()==347,"347 exact source recipes installed")
	if world.patch523_equipment.recipes.size()!=347:
		world.queue_free(); await process_frame; quit(1); return
	world.inventory.clear(); world.item_instances.clear(); world.equipped_items.clear(); world.crafting_log.clear()
	world.next_item_instance_id=19001; world.gold=123456
	world.inventory["잊혀진 화룡의 표식"]=56
	world.level=67
	check(world._save_game(true)==OK,"baseline existing save accepted")
	var before: String=snapshot(world)
	var sha: String=FileAccess.get_sha256(world.save_path())
	var action: Button=await select_recipe(world,"patch523:235381")
	check(action!=null and action.disabled,"real crafting UI blocks source level67")
	var odds: Label=world.hud.workspace.find_child("Patch523CraftOdds",true,false)
	check(odds.visible and odds.text.contains("68"),"source craft level is visible above execution button")
	world._craft_requested("patch523:235381",1)
	check(snapshot(world)==before and FileAccess.get_sha256(world.save_path())==sha,"authoritative level guard preserves materials, wallet, IDs and save bytes")
	await capture("source-level-block")
	world.level=68
	action=await select_recipe(world,"patch523:235381")
	check(not action.disabled,"inclusive source craft level68 enables actual UI")
	world.source_save_blocked=true
	action.pressed.emit(); await process_frame
	var confirm: Button=world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"source craft uses normal confirmation UI")
	confirm.pressed.emit()
	check(snapshot(world)==before and FileAccess.get_sha256(world.save_path())==sha,"blocked save does not consume source28 marks or grant a box")
	world.source_save_blocked=false
	world._craft_requested("patch523:235381",1)
	check(int(world.inventory.get("잊혀진 화룡의 표식",0))==28 and int(world.inventory.get("잊혀진 발라카스의 전리품 상자",0))==1 and world.gold==123456 and world.next_item_instance_id==19001,"source28 marks become exactly one box without invented fee or physical ID")
	world._load_game(true)
	check(world.level==68 and int(world.inventory.get("잊혀진 발라카스의 전리품 상자",0))==1,"new level-limited source output survives actual save reload")
	world.inventory.clear(); world.inventory["풍룡의 파편 (각인)"]=110
	check(world._save_game(true)==OK,"weekly source baseline durable save")
	before=snapshot(world); sha=FileAccess.get_sha256(world.save_path())
	clock_checks(world.patch523_equipment.recipes["patch523:142364"])
	check(not world._craft_quote("patch523:142364",11).get("ok",false),"batch cannot exceed source weekly10")
	action=await select_recipe(world,"patch523:142364")
	var amount: SpinBox=world.hud.workspace.find_child("CraftQuantity",true,false)
	amount.value=9
	check(not action.disabled,"actual weekly UI supports nine of ten attempts")
	var detail: RichTextLabel=world.hud.workspace.find_child("CraftAvailability",true,false)
	check(detail.text.contains("이번 주 0/10") and detail.text.contains("TWILIGHT 일정 설정"),"weekly source limit and offline reset provenance are shown together")
	odds=world.hud.workspace.find_child("Patch523CraftOdds",true,false)
	check(odds.visible and odds.text.contains("0/10회") and odds.text.contains("수 05:00 KST") and odds.text.contains("게임 설정"),"actual visible action summary contains remaining quota and derived host reset schedule")
	await capture("source-weekly-craft")
	world.source_save_blocked=true
	action.pressed.emit(); await process_frame
	confirm=world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"weekly quota uses actual confirmation")
	confirm.pressed.emit()
	check(snapshot(world)==before and FileAccess.get_sha256(world.save_path())==sha,"failed write preserves quota, fragments, gold and original save")
	world.source_save_blocked=false
	world._craft_requested("patch523:142364",9)
	check(int(world.inventory.get("풍룡의 파편 (각인)",0))==20 and int(world.inventory.get("풍룡의 보물 상자 (각인)",0))==9,"nine original attempts consume exactly90 fragments and give9 boxes")
	check(int(world.patch523_crafting_usage.recipes["patch523:142364"].used)==9 and world.gold==123456,"quota commits with inventory and preserves source zero fee")
	world.crafting_log.clear()
	check(world._save_game(true)==OK,"history can be pruned without quota deletion")
	world.patch523_crafting_usage.clear(); world._load_game(true)
	check(int(world.patch523_crafting_usage.recipes["patch523:142364"].used)==9 and world.crafting_log.is_empty(),"independent durable ledger survives history clearing and actual reload")
	action=await select_recipe(world,"patch523:142364")
	amount=world.hud.workspace.find_child("CraftQuantity",true,false); amount.value=1
	detail=world.hud.workspace.find_child("CraftAvailability",true,false)
	check(not action.disabled and detail.text.contains("이번 주 9/10"),"real UI shows saved remaining weekly attempt")
	action.pressed.emit(); await process_frame
	confirm=world.hud.find_child("ConfirmTransaction",true,false)
	check(confirm!=null,"tenth attempt requires actual confirmation")
	confirm.pressed.emit()
	check(int(world.inventory.get("풍룡의 파편 (각인)",0))==10 and int(world.inventory.get("풍룡의 보물 상자 (각인)",0))==10 and int(world.patch523_crafting_usage.recipes["patch523:142364"].used)==10,"tenth confirmed attempt atomically consumes and records final quota")
	action=await select_recipe(world,"patch523:142364")
	check(action.disabled,"real UI disables exhausted source quota")
	odds=world.hud.workspace.find_child("Patch523CraftOdds",true,false)
	check(odds.visible and odds.text.contains("10/10회"),"exhausted count stays visible above disabled action")
	before=snapshot(world); sha=FileAccess.get_sha256(world.save_path())
	world._craft_requested("patch523:142364",1)
	check(snapshot(world)==before and FileAccess.get_sha256(world.save_path())==sha,"duplicate eleventh request cannot consume or grant beyond source quota")
	await capture("source-weekly-exhausted")
	world._load_game(true)
	check(not world._craft_quote("patch523:142364",1).get("ok",false) and int(world.inventory.get("풍룡의 보물 상자 (각인)",0))==10,"exhausted quota remains blocked across final actual reload")
	world.queue_free(); await process_frame
	print("PATCH523_LIMIT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
