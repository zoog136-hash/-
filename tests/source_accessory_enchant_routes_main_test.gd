extends "res://tests/source_catalog_stack_bag_test.gd"
## Installed-pack Main with a legacy save and the original bag's two-touch action.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const STOCK = preload("res://scripts/crafting/patch523_enhance_stock.gd")
const SHINING: int = 320802
const SHINING_GROUPS = {629:10, 2401:32, 30671:81, 882:253, 158761:371, 183681:511, 213611:548, 289062:792}

func run() -> void:
	if OS.get_environment("TWILIGHT_ACCESSORY_QA")!="1" or OS.get_environment("XDG_DATA_HOME").is_empty() or FileAccess.file_exists("user://twilight_v20_save.json"):
		quit(2)
		return
	root.size=Vector2i(1280,720)
	var world: Node=load("res://Main.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	world.set_process(false)
	world.save_timer=-100000
	if check(QA.enter_game(world,"기사"),"installed Main enters normal gameplay"):
		await frames()
		world.player.set_physics_process(false)
		world.field_population.set_process(false)
		world._clear_monsters()
		world._clear_drops()
		world.level=74
		world.gold=1000000
		await exercise_accessories(world)
	world.hud._close_workspace()
	await frames()
	world.queue_free()
	await frames()
	print("ACCESSORY_ENCHANT_ROUTES_RESULT ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)

func instance_id(world: Node, item_id: int, bless: int=1) -> String:
	for uid: String in world.item_instances:
		var owned: Dictionary=STACK.proof(world,uid)
		if int(owned.get("receipt",{}).get("item_class_id",0))==item_id and int(owned.receipt.bless_raw)==bless:
			return uid
	return ""

func candidates_by_id(world: Node) -> Dictionary:
	var rows: Dictionary={}
	for candidate: Dictionary in world.hud.enhancement_candidates:
		var record: Dictionary=world.item_instances.get(candidate.instance_id,{}).get("record",{})
		rows[int(record.get("source_item_class_id",int(record.get("sourceId",0))))]=candidate
	return rows

func exercise_accessories(world: Node) -> void:
	var grants: Array=[{"item_class_id":SHINING,"amount":2,"bless_raw":1,"enchant":0}]
	var routes: Array=[[226992,1,394,632],[227002,1,394,642],[227002,2,394,652],[2431,1,2401,32],
		[159291,1,158761,371],[183711,1,183681,511],[213471,1,213611,548],[166044,1,629,522]]
	for route: Array in routes: grants.append({"item_class_id":route[0],"amount":10,"bless_raw":route[1],"enchant":0})
	var source_scroll: Dictionary=world.source_item_record(SHINING)
	var equipment: Dictionary={}
	for id: int in SHINING_GROUPS.keys()+[394]:
		var record: Dictionary=world._catalog_item_from_source_id(str(id))
		if not check(record.get("source")=="inven","registered old catalog equipment #"+str(id)):return
		var uid: String=str(world.next_item_instance_id)
		world.next_item_instance_id+=1
		world.inventory[record.name]=int(world.inventory.get(record.name,0))+1
		world.item_instances[uid]={"name":record.name,"level":0,"record":record.duplicate(),"sourceId":str(id),"bless_state":"normal","element":"","element_level":0}
		equipment[id]=uid
	await exercise_seal_box_balance(world,source_scroll.name,equipment[2401])
	if not check(SUPPLY.commit(world,grants,{"kind":"qa_accessory_scroll_inventory"}),"exact original enhancement scroll receipts are supplied"):return
	var fresh_uid: String=instance_id(world,SHINING)
	var old_name: String=LABELS.original_name(SHINING)
	var old_uid: String=str(world.next_item_instance_id)
	world.next_item_instance_id+=1
	world.inventory[old_name]=1
	world.item_instances[old_uid]={"name":old_name,"level":0,"record":source_scroll,"sourceId":str(SHINING),"bless_state":"normal"}
	if not check(world._save_game(true)==OK,"an older physical key and equipment can be saved together"):return
	world._load_game(true)
	await frames()
	var before_inventory: Dictionary=world.inventory.duplicate()
	var old_reference: String=old_name+"@@@"+old_uid
	var invalid: Dictionary=world.item_instances[old_uid].duplicate(true)
	invalid[STACK.QUANTITY]=1
	check(STOCK.legacy_unit(world,invalid,old_name).is_empty(),"an incomplete receipt cannot be used as old stock")
	invalid.erase(STACK.QUANTITY)
	invalid.sourceId="166044"
	check(STOCK.legacy_unit(world,invalid,old_name).is_empty(),"a saved scroll pinned to another original ID is refused")
	if not await use(world,old_reference):return
	var forge: RefCounted=world.hud.original_main_ui_controller.enchant_window()
	if not check(is_instance_valid(forge) and forge.is_open() and forge._scroll_row.get("reference")==old_reference,"the original bag opens the original chooser with the selected old receipt-less unit"):return
	check(world.inventory==before_inventory and STACK.proof(world,fresh_uid).remaining==2,"entry does not consume either scroll stack")
	var shown: Dictionary=candidates_by_id(world)
	for id: int in SHINING_GROUPS:
		var physical: Dictionary=world.item_instances[equipment[id]]
		var quote: Dictionary=world._source_enhancement_rule(physical.record,0,"normal",old_name,physical,source_scroll)
		check(shown.get(id,{}).get("instance_id")==equipment[id] and int(quote.get("group",0))==SHINING_GROUPS[id],"the old physical target is eligible in its own 523 group #"+str(id)+" "+str(quote.get("reason","")))
	check(not shown.has(394),"shining scroll does not list an ordinary necklace")
	if not check(shown.has(629),"old red earring is selectable for a real transaction"):return
	var target: Dictionary=shown[629]
	var snapshot_file: String=FileAccess.get_sha256(world.save_path())
	var gold: int=world.gold
	var before_rng: int=world.rng.state
	world.source_save_blocked=true
	await tap_enchant(forge,target.target_id)
	world.source_save_blocked=false
	check(world.inventory==before_inventory and world.gold==gold and world.rng.state==before_rng and FileAccess.get_sha256(world.save_path())==snapshot_file,
		"refused save leaves the selected old scroll, gear, adena and RNG together")
	seed_success(world,float(target.success_chance))
	await tap_enchant(forge,target.target_id)
	check(not world.item_instances.has(old_uid) and STACK.proof(world,fresh_uid).remaining==2 and world.item_instances[equipment[629]].level==1
		and world.gold==gold-int(target.cost),"the real button spends only the selected old unit and enhances the same physical earring")
	world.hud._close_workspace()
	await frames()
	world._load_game(true)
	check(world.item_instances[equipment[629]].level==1 and not world.item_instances.has(old_uid) and STACK.proof(world,fresh_uid).remaining==2,"the result and both stock identities survive reload")
	var protector: String=instance_id(world,166044)
	if check(not protector.is_empty(),"authentic protection stock is available"):
		var protect: Dictionary=STACK.proof(world,protector).record
		var rejected: Dictionary=world._source_enhancement_rule(world.item_instances[equipment[629]].record,1,"normal",str(protect.name),world.item_instances[equipment[629]],protect)
		check(float(rejected.get("success",0.0))==0.0,"shining protection excludes a +1 accessory")
	world.item_instances[equipment[629]].level=4
	for route: Array in routes:
		var uid: String=instance_id(world,int(route[0]),int(route[1]))
		if not check(not uid.is_empty(),"authentic stock for "+str(route)):continue
		world.hud._close_workspace()
		await frames()
		var scroll: Dictionary=STACK.proof(world,uid).record
		world.hud.inventory_item_activated.emit(str(scroll.name)+"@@@"+uid)
		await frames()
		var origin: Dictionary=world.item_instances[equipment[route[2]]]
		var quote: Dictionary=world._source_enhancement_rule(origin.record,int(origin.level),"normal",str(scroll.name),origin,scroll)
		check(candidates_by_id(world).get(route[2],{}).get("instance_id")==equipment[route[2]] and quote.get("group")==route[3],
			"ordinary, Orim, protection or dedicated scroll routes to its authored group "+str(route)+" "+str(quote.get("reason","")))

func seed_success(world: Node, chance: float) -> void:
	var probe:=RandomNumberGenerator.new()
	for seed_value: int in range(1,1000):
		probe.seed=seed_value
		if probe.randf_range(0.0,100.0)<chance:
			world.rng.seed=seed_value
			return

func exercise_seal_box_balance(world: Node, name: String, ring: String) -> void:
	# The standalone seal reward stored 8 under the compiled original key
	# with no physical scroll row. Reproduce a save with one remaining.
	world.inventory[name]=1
	if not check(world._save_game(true)==OK,"persist the remaining plain seal-box stock"):return
	world._load_game(true)
	await frames()
	if not await use(world,name):return
	var forge: RefCounted=world.hud.original_main_ui_controller.enchant_window()
	var roll: Dictionary=candidates_by_id(world).get(2401,{})
	if not check(is_instance_valid(forge) and forge.is_open() and forge._scroll_row.get("reference")==name
			and roll.get("instance_id")==ring and world.inventory.get(name)==1,"an old box scroll also opens a non-seal target in the original chooser"):return
	seed_success(world,float(roll.success_chance))
	await tap_enchant(forge,roll.target_id)
	check(not world.inventory.has(name) and world.item_instances[ring].level==1,"the last plain box scroll applies to its exact old physical ring")
	world.hud._close_workspace()
	await frames()
