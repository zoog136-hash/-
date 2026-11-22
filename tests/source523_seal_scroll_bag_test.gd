extends SceneTree

const QA = preload("res://tests/qa_class_selection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const STOCK = preload("res://scripts/loot/current523_native_stack.gd")
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
	world.hud.inventory_item_activated.emit(scroll_name+"@@@"+uid)
	await process_frame
	var picker: Node=world.hud.workspace.find_child("Patch523EquipmentInfo",true,false)
	check(picker!=null and picker.bag_scroll_uid==uid and picker.bag_scroll_id==str(SCROLL_ID),"bag activation opens the seal screen with the exact physical scroll reference")
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
	world.queue_free()
	await process_frame
