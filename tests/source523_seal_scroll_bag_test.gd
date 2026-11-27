extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STOCK = preload("res://scripts/loot/current523_native_stack.gd")
const INV = preload("res://scripts/loot/patch523_item_inventory.gd")
const CRAFT = preload("res://scripts/ui/renewal_crafting.gd")
const SCROLL_ID := 320802
const BAG_SEAL := "수호의 인장"

var failures: Array[String] = []
var checks: int = 0

func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition: failures.append(message)
	return condition

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var installed: bool = not SOURCE.not_installed()
	if installed:
		await _exercise()
	print("SOURCE523_SEAL_SCROLL_BAG_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_definitions":installed}))
	quit(0 if failures.is_empty() else 1)

func _exercise() -> void:
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000
	if not check(QA.enter_game(world),"actual Main entry"):
		world.queue_free()
		return
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	await process_frame
	world._clear_monsters()
	world._clear_drops()
	world.gold = 100000
	var equipment: Dictionary = world.patch523_equipment.record("30671")
	var receipt_record: Dictionary = world.source_item_record(SCROLL_ID)
	var receipt: Dictionary = STOCK.stage_grant(receipt_record,9,world.item_instances,{"kind":"twilight_debug_catalog"})
	if not check(not equipment.is_empty() and receipt.get("ok",false),"exact original seal rules and 320802 receipt can be loaded"):
		world.queue_free()
		return
	world.item_instances=receipt.item_instances
	var scroll_name: String = str(receipt_record.name)
	var uid: String = str(receipt.id)
	world.inventory[scroll_name] = 9
	var seal_id: String = str(world.next_item_instance_id)
	world.next_item_instance_id += 1
	world.inventory[BAG_SEAL] = int(world.inventory.get(BAG_SEAL,0))+1
	world.item_instances[seal_id]={"name":BAG_SEAL,"level":0,"element":"","element_level":0,"record":equipment,"sourceId":"30671","bless_state":"normal"}
	check(world.patch523_equipment.identity(world.item_instances[seal_id])=="30671","the previously saved bare-ID seal box reward remains selectable")
	var before: Dictionary=world.item_instances[uid].duplicate(true)
	world.hud.refresh_inventory(world.inventory)
	world.hud.lineage_inventory_ui._select_item(scroll_name+"@@@"+uid)
	world.hud.lineage_inventory_ui._activate_selected()
	await process_frame
	var picker: Node=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
	if OS.get_environment("TWILIGHT_SOURCE_UI_SHA256").is_empty():
		check(picker!=null and picker.bag_scroll_uid==uid and picker.bag_scroll_id==str(SCROLL_ID),"without the original UI the existing seal screen keeps the exact physical scroll reference")
	else:
		var window: RefCounted=world.hud._original_enchant_window()
		check(window!=null and window._scroll_row.get("instance_id")==uid and picker==null,"only-seal inventory opens the original enhancement window with the exact scroll")
	check(world.item_instances[uid]==before and int(world.inventory[scroll_name])==9,"opening the screen preserves the receipt and stack")
	check(not world.patch523_seal_quote(seal_id,str(SCROLL_ID)).get("ok",true),"plain execution cannot debit a physical balance by name")
	var quote: Dictionary=world.patch523_seal_quote(seal_id,str(SCROLL_ID),uid)
	if not check(quote.get("ok",false) and quote.scroll_request.physical_id==uid,"exact scroll gets the source enhancement quote: "+str(quote)):
		world.queue_free()
		return
	var probe:=RandomNumberGenerator.new()
	for seed_value: int in range(1,100):
		probe.seed=seed_value
		if probe.randf_range(0.0,100.0)<float(quote.success):
			world.rng.seed=seed_value
			break
	var saved_gold: int=world.gold
	var saved_rng: int=world.rng.state
	world.source_save_blocked=true
	world._patch523_attempt_seal(seal_id,str(SCROLL_ID),uid)
	check(world.item_instances[uid]==before and world.item_instances[seal_id].level==0 and world.gold==saved_gold and world.rng.state==saved_rng,"refused save restores scroll, seal, wallet and RNG")
	world.source_save_blocked=false
	world._patch523_attempt_seal(seal_id,str(SCROLL_ID),uid)
	var left: Dictionary=STOCK.proof(world,uid)
	check(left.get("remaining")==8 and left.get("used")==1 and int(world.inventory[scroll_name])==8 and world.item_instances[seal_id].level==1 and world.gold==saved_gold-int(quote.cost),"successful reinforcement consumes one physical scroll and persists the original seal level")
	world._load_game(true)
	check(STOCK.proof(world,uid).get("remaining")==8 and world.item_instances.get(seal_id,{}).get("level")==1,"receipt and seal reload together")
	var legacy_uid: String=str(world.next_item_instance_id)
	world.next_item_instance_id+=1
	world.item_instances[legacy_uid]={"name":scroll_name,"level":0,"record":world.patch523_equipment.record(str(SCROLL_ID)),"bless_state":"normal"}
	world.inventory[scroll_name]+=1
	var legacy_quote: Dictionary=world.patch523_seal_quote(seal_id,str(SCROLL_ID),legacy_uid)
	if not legacy_quote.get("ok",false):
		var fields=preload("res://scripts/loot/current523_native_fields.gd")
		var saved_seal: Dictionary=fields.full(world.item_instances[seal_id].record)
		var definition: Dictionary=fields.full(world.patch523_equipment.record("30671"))
		print("SEAL_RECORD_FIELDS ",definition.keys().filter(func(key: Variant)->bool:return definition[key]!=saved_seal.get(key)), " · saved only ",saved_seal.keys().filter(func(key: Variant)->bool:return not definition.has(key)))
	check(legacy_quote.get("legacy_scroll_uid","")==legacy_uid,"legacy pinned scrolls without receipts get a single-unit quote: "+str(legacy_quote))
	var seal_record: Dictionary=world.item_instances[seal_id].record
	check(not world.patch523_equipment._source_ids_match([12.0,11.0],[11,12],false,true),"the persisted order of multiple enchant groups still matters")
	for bad_group: float in [431.5,99999.0]:
		var bad: Dictionary=seal_record.duplicate()
		bad.source_enchant_group_ids=[bad_group]
		world.item_instances[seal_id].record=bad
		check(not world.patch523_seal_quote(seal_id,str(SCROLL_ID),legacy_uid).get("ok",false),"a different or fractional enchant group cannot authorize the saved seal")
	var changed: Dictionary=seal_record.duplicate(true)
	changed["enhancement_options"]={"0":{"xp_pct":9999}}
	world.item_instances[seal_id].record=changed
	check(not world.patch523_seal_quote(seal_id,str(SCROLL_ID),legacy_uid).get("ok",false),"tooltip differences can pass, but altered enhancement options cannot")
	world.item_instances[seal_id].record=seal_record
	world.item_instances[legacy_uid][STOCK.RECEIPT]={"schema":1}
	check(not world.patch523_seal_quote(seal_id,str(SCROLL_ID),legacy_uid).get("ok",false),"an invalid receipt never falls back to legacy use")
	world.item_instances[legacy_uid].erase(STOCK.RECEIPT)
	if legacy_quote.get("ok",false):
		if is_instance_valid(world.hud.enhancement_reveal):world.hud.enhancement_reveal.queue_free()
		for seed_value: int in range(1,100):
			probe.seed=seed_value
			if probe.randf_range(0.0,100.0)<float(legacy_quote.success):
				world.rng.seed=seed_value
				break
		world._patch523_attempt_seal(seal_id,str(SCROLL_ID),legacy_uid)
		check(not world.item_instances.has(legacy_uid) and STOCK.proof(world,uid).get("remaining")==8 and int(world.inventory[scroll_name])==8 and world.item_instances[seal_id].level==2,"using the legacy unit leaves the other scroll receipt unchanged")
	if check(INV.commit(world,[{"item_class_id":629,"amount":1,"bless_raw":1,"enchant":0}],{"kind":"seal_and_accessory_regression"}),"supply an accessory accepted by the same shining scroll"):
		if is_instance_valid(world.hud.enhancement_reveal):
			world.hud.enhancement_reveal.skip_to_result()
			world.hud.enhancement_reveal.close_reveal()
		world.hud._close_workspace()
		await process_frame
		world._on_inventory_item_activated(scroll_name+"@@@"+uid)
		await process_frame
		var candidates: Array=world.hud.enhancement_candidates
		var seal_entries: Array=candidates.filter(func(entry: Dictionary) -> bool: return entry.instance_id==seal_id and entry.seal)
		var non_seals: Array=candidates.filter(func(entry: Dictionary) -> bool: return not entry.seal and world.item_instances[entry.instance_id].record.get("source_item_class_id")==629)
		check(world.hud.active_section=="enhance" and seal_entries.size()==1 and non_seals.size()==1,"mixed inventory offers both the original seal and the other authored target")
		if not seal_entries.is_empty():
			var established: Dictionary=world.patch523_seal_quote(seal_id,str(SCROLL_ID),uid)
			check(established.get("ok",false) and seal_entries[0].success_chance==established.success and seal_entries[0].cost==established.cost,"shared chooser quotes the dedicated seal owner")
			var balance: int=int(world.inventory[scroll_name])
			var adena: int=world.gold
			world._attempt_enhancement(scroll_name,seal_entries[0].target_id)
			check(STOCK.proof(world,uid).get("remaining")==balance-1 and world.gold==adena-int(established.cost),"shared chooser spends the selected unit with the established seal transaction")
	await _accessories(world,receipt_record,uid)
	world.queue_free()
	await process_frame

func _bag_use(world: TwilightWorld, reference: String) -> void:
	world.hud._close_workspace()
	if is_instance_valid(world.hud.enhancement_reveal):
		world.hud.enhancement_reveal.skip_to_result()
		world.hud.enhancement_reveal.close_reveal()
	await process_frame
	world.hud.refresh_inventory(world.inventory)
	world.hud.lineage_inventory_ui._select_item(reference)
	check(world.hud.lineage_inventory_ui.item_action_kind(reference)=="사용","bag displays the real scroll's use action")
	world.hud.lineage_inventory_ui._activate_selected()
	await process_frame

func _accessories(world: TwilightWorld, scroll: Dictionary, receipt_uid: String) -> void:
	var name_value: String = str(scroll.name)
	var legacy: String = str(world.next_item_instance_id)
	world.next_item_instance_id+=1
	world.inventory[name_value]=int(world.inventory[name_value])+1
	world.item_instances[legacy]={"name":name_value,"level":0,"record":scroll,"sourceId":str(SCROLL_ID),"bless_state":"normal"}
	if not check(world._save_game(true)==OK,"persist a legacy one-unit scroll before opening the bag"):return
	world._load_game(true)
	var before: int=int(STOCK.proof(world,receipt_uid).remaining)
	await _bag_use(world,name_value+"@@@"+legacy)
	var targets: Array=world.hud.enhancement_candidates.filter(func(row: Dictionary) -> bool:
		return not row.seal and world.item_instances[row.instance_id].record.get("source_item_class_id")==629)
	if not check(world.hud.active_section=="enhance" and targets.size()==1,"old saved shining scroll offers the authored earring target"):return
	var target: Dictionary=targets[0]
	var hash_before: String=FileAccess.get_sha256(world.save_path())
	var rng_before: int=world.rng.state
	world.equipment_collections.test_save_writer=func(_path: String,_payload: Dictionary) -> Error:return ERR_CANT_CREATE
	world._attempt_enhancement(name_value,target.target_id)
	world.equipment_collections.test_save_writer=Callable()
	check(world.rng.state==rng_before and world.item_instances.has(legacy) and FileAccess.get_sha256(world.save_path())==hash_before,
		"failed enhancement write preserves legacy stock, target, RNG, and saved bytes")
	var probe:=RandomNumberGenerator.new()
	for seed_value: int in range(1,1000):
		probe.seed=seed_value
		if probe.randf_range(0.0,100.0)<float(target.success_chance):
			world.rng.seed=seed_value
			break
	world._attempt_enhancement(name_value,target.target_id)
	check(not world.item_instances.has(legacy) and STOCK.proof(world,receipt_uid).remaining==before and world.item_instances.get(target.instance_id,{}).get("level")==1,
		"one old unit pays for the exact accessory roll, with the other stack intact")
	world._load_game(true)
	check(not world.item_instances.has(legacy) and world.item_instances.get(target.instance_id,{}).get("level")==1,"accessory enhancement survives reload")
	var supplier: Dictionary={"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}
	if check(INV.commit(world,[{"item_class_id":227002,"amount":1,"bless_raw":1,"enchant":0},{"item_class_id":394,"amount":1,"bless_raw":1,"enchant":0}],supplier),"load actual Orim scroll and eligible necklace"):
		for id: String in world.item_instances:
			var physical: Dictionary=world.item_instances[id]
			if physical.record.get("source_item_class_id")!=227002:continue
			await _bag_use(world,str(physical.name)+"@@@"+id)
			check(world.hud.enhancement_candidates.any(func(row: Dictionary) -> bool:return world.item_instances[row.instance_id].record.get("source_item_class_id")==394),"authored Orim scroll opens ordinary necklace candidates through the bag")
			break
	await _bless_earrings(world)

func _bless_earrings(world: TwilightWorld) -> void:
	var supplier: Dictionary={"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"}
	var grants: Array=[{"item_class_id":629,"amount":2,"bless_raw":1,"enchant":3},{"item_class_id":629,"amount":1,"bless_raw":1,"enchant":4}]
	if not check(INV.commit(world,grants,supplier),"load both +3 and +4 original earrings"):return
	var same: Array[String]=[]
	var different: String=""
	for id: String in world.item_instances:
		var physical: Dictionary=world.item_instances[id]
		if physical.record.get("source_item_class_id")!=629:continue
		if physical.level==3:same.append(id)
		if physical.level==4:different=id
	if not check(same.size()==2 and not different.is_empty(),"original two same-level physical copies available"):return
	var name_value: String=str(world.item_instances[same[0]].name)
	var reference: String=name_value+"@@@"+same[0]
	var recipe_id: String="patch523:38084"
	check(world.accessory_blessing_recipe(reference)==recipe_id,"+3 from bag links the original same-level two-copy recipe")
	check(world.accessory_blessing_recipe(name_value+"@@@"+different)=="patch523:38094","a +4 links its own recipe")
	world.ui_preferences.item_locks[name_value+"@@@"+same[1]]=true
	check(not world._craft_quote(recipe_id,1).get("ok",false),"locked duplicate and wrong-level copy cannot pay")
	world.ui_preferences.item_locks.clear()
	world.hud._close_workspace()
	world.hud.lineage_inventory_ui._select_item(reference)
	world.hud.lineage_inventory_ui._open_acquisition()
	var controller: Node=world.hud.original_main_ui_controller
	if controller.acquisition_is_open():
		var popup: RefCounted=controller._acquisition_popup
		check(popup._craft_rows()[0].recipe_id==recipe_id,"bag acquisition presents the exact blessing conversion first")
		popup._open_craft(recipe_id)
	check(CRAFT.last_focus.get("recipe_id")==recipe_id and CRAFT.last_focus.get("focused",false),"player path focuses the original craft recipe")
	if not check(world._craft_quote(recipe_id,1).get("ok",false),"the existing owner accepts the two exact duplicates"):return
	world._craft_requested(recipe_id,1)
	world._load_game(true)
	var blessed: Array=world.item_instances.values().filter(func(row: Dictionary) -> bool:
		return row.record.get("source_item_class_id")==629 and row.level==3 and world.patch523_equipment.bless_code(row)==2)
	check(blessed.size()==1 and world.item_instances.has(different) and not world.item_instances.has(same[0]) and not world.item_instances.has(same[1]),
		"craft and reload leave one blessed +3 and preserve the unselected +4")
