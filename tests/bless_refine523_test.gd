extends SceneTree
## Original 523 용해 (BlessPowderAmount -> 축복의 가루) and 질서의 연금
## (RefineItem/RefineInput/RefineOutput/RefineConstants). Without the original
## definition ZIP only the refusal rules run. With it the table lookups are
## checked against the rows themselves and, in actual Main, granted equipment
## is dissolved and refined (forced success and failure rolls), then the save
## is reloaded.
const RULES = preload("res://scripts/refine523/bless_refine523_rules.gd")
const SERVICE = preload("res://scripts/refine523/bless_refine523_service.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label); printerr("BLESS_REFINE523_FAIL: ",label)

func _initialize() -> void: call_deferred("run")

func rules() -> void:
	check(RULES.percent_text(105300)=="10%" and RULES.percent_text(200000)=="20%" and RULES.percent_text(999999)=="99%", "success percent is shown with decimals cut off")
	check(RULES.registration({"input":{"MinAmount":1,"MaxAmount":2,"MinProbability":1,"MaxProbability":2}},"between").get("code")=="amount_between", "an amount between the table endpoints is refused")
	var low: Dictionary = RULES.registration({"input":{"MinAmount":10000,"MaxAmount":20000,"MinProbability":100000,"MaxProbability":200000}},"min")
	var high: Dictionary = RULES.registration({"input":{"MinAmount":10000,"MaxAmount":20000,"MinProbability":100000,"MaxProbability":200000}},"max")
	check(low.amount==10000 and low.probability==100000 and high.amount==20000 and high.probability==200000, "the endpoints register the table amount and probability")
	if SOURCE.not_installed():
		check(not RULES.installed() and RULES.dissolve_yield(1,0,0).get("code")=="source_not_installed" and RULES.refine_entry(1,0).get("code")=="source_not_installed", "without the original archive both features are held")

func soluble_weapon(grade: int) -> int:
	for row: Dictionary in SOURCE.rows_matching("ItemClass","GradeID",{grade:true}):
		if row.get("IsSoluble")==true and row.get("TestItem")==false and int(row.get("CategoryID",0))==1 and str(row.get("ServiceRegionCode",""))=="" : return int(row.ID)
	return 0

func expected_amount(grade: int, enchant: int) -> int:
	for row: Dictionary in SOURCE.rows("BlessPowderAmount"):
		if int(row.GradeID)==grade and int(row.Enchant)==enchant: return int(row.Amount)
	return -1

func table() -> void:
	var grades: Dictionary = {}
	for row: Dictionary in SOURCE.rows("BlessPowderAmount"): grades[int(row.GradeID)] = true
	var checked: int = 0
	for grade: int in grades:
		var item: int = soluble_weapon(grade)
		if item==0: continue
		for enchant: int in [0,5,20]:
			var yielded: Dictionary = RULES.dissolve_yield(item,enchant,0)
			check(yielded.get("ok",false) and int(yielded.amount)==expected_amount(grade,enchant) and int(yielded.item_class_id)==RULES.BLESS_POWDER_ITEM, "dissolve amount grade %d +%d" % [grade,enchant])
			checked += 1
		check(RULES.dissolve_yield(item,21,0).get("code")=="amount_row_missing", "no row past +20 for grade %d" % grade)
		check(RULES.dissolve_yield(item,0,1).get("code")=="amplify_rule_missing", "an elemental enchant is held for grade %d" % grade)
	evidence["dissolve_rows_checked"] = checked
	var target: Dictionary = SOURCE.row_at("RefineItem",0)
	var entry: Dictionary = RULES.refine_entry(int(target.ItemClassID),int(target.Enchant))
	check(entry.get("ok",false) and int(entry.group_id)==int(target.RefineItemGroupID), "a RefineItem row resolves its group")
	if entry.get("ok",false):
		check(int(entry.input.ItemClassID)==RULES.ADVANCED_BLESS_POWDER_ITEM and int(entry.cost)==int(RULES.constant("RefineConstants","RefineCost")), "the main input is 상급 축복의 가루 and the cost is RefineCost")
		evidence["refine_first"] = {"target":int(target.ItemClassID),"enchant":int(target.Enchant),"min":int(entry.input.MinAmount),"max":int(entry.input.MaxAmount),"min_probability":int(entry.input.MinProbability),"max_probability":int(entry.input.MaxProbability),"output":int(entry.outputs[0].ItemClassID),"output_enchant":int(entry.outputs[0].Enchant),"cost":int(entry.cost),"special_inputs":entry.special_inputs.size()}
	check(RULES.refine_entry(int(target.ItemClassID),99).get("code")=="not_refine_target", "an enchant without a RefineItem row is not a target")
	var resolved: int = 0
	for index: int in SOURCE.row_count("RefineItem"):
		var row: Dictionary = SOURCE.row_at("RefineItem",index)
		if RULES.refine_entry(int(row.ItemClassID),int(row.Enchant)).get("ok",false): resolved += 1
	check(resolved==SOURCE.row_count("RefineItem"), "every RefineItem row resolves to a complete recipe")
	evidence["refine_rows_resolved"] = resolved
	evidence["refine_contents_enabled"] = RULES.refine_contents_enabled()

func physical_of(world: Node, item_class_id: int) -> Array:
	var result: Array = []
	for uid: String in world.item_instances:
		var entry: Variant = world.item_instances[uid]
		if entry is Dictionary and entry.get("record") is Dictionary and int(entry.record.get("source_item_class_id",0))==item_class_id and not entry.has(STACK.RECEIPT): result.append(uid)
	result.sort()
	return result

func grant(world: Node, grants: Array) -> bool:
	var staged: Dictionary = SUPPLY.stage(world,grants,{"kind":"twilight_debug_catalog","initial_level_origin":"twilight_debug_default_zero"})
	if not staged.get("ok",false): printerr("grant: ",staged); return false
	if world._save_game(true,staged.overrides)!=OK: return false
	world.inventory = staged.overrides.inventory; world.item_instances = staged.overrides.item_instances; world.gold = int(staged.overrides.gold)
	return true

## A seed whose first transaction roll is (or is not) below `probability`.
func seed_for(probability: int, success: bool) -> int:
	var rng := RandomNumberGenerator.new()
	for value: int in range(1,100000):
		rng.seed = value
		if (rng.randi_range(0,RULES.SCALE-1)<probability)==success: return value
	return 0

func runtime() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	world.field_population.set_process(false); world.player.set_physics_process(false)
	world._clear_monsters(); world._clear_drops()
	world.inventory = {}; world.item_instances = {}; world.equipped_items = {}
	var weapon: int = soluble_weapon(3)
	var target: Dictionary = SOURCE.row_at("RefineItem",0)
	var target_id: int = int(target.ItemClassID)
	var entry: Dictionary = RULES.refine_entry(target_id,int(target.Enchant))
	check(grant(world,[{"item_class_id":weapon,"amount":1,"bless_raw":1,"enchant":0},{"item_class_id":weapon,"amount":1,"bless_raw":1,"enchant":5},{"item_class_id":target_id,"amount":2,"bless_raw":1,"enchant":int(target.Enchant)},{"item_class_id":RULES.ADVANCED_BLESS_POWDER_ITEM,"amount":int(entry.input.MinAmount)+int(entry.input.MaxAmount),"bless_raw":1,"enchant":0},{"item_class_id":26,"amount":int(entry.cost)*2,"bless_raw":1,"enchant":0}]), "original equipment, 상급 축복의 가루 and Adena granted")
	var weapons: Array = physical_of(world,weapon)
	check(weapons.size()==2, "two physical weapons to dissolve")
	# Dissolution.
	var powder_name: String = str(world.source_item_definition(RULES.BLESS_POWDER_ITEM).get("native_record",{}).get("name",""))
	var before_powder: int = int(world.inventory.get(powder_name,0))
	var expected: int = expected_amount(3,0)+expected_amount(3,5)
	var locked_name: String = str(world.item_instances[weapons[0]].name)
	world.ui_preferences.item_locks[locked_name+"@@@"+str(weapons[0])] = true
	check(SERVICE.dissolve(world,weapons).get("code")=="locked", "a locked item is not dissolved")
	world.ui_preferences.item_locks.erase(locked_name+"@@@"+str(weapons[0]))
	# Through the menu window: tick both weapons and press 용해.
	world.hud.call("_navigate","bless_refine523")
	var panel: Node = world.hud.workspace.find_child("BlessRefine523Panel",true,false)
	check(panel!=null, "the 용해·질서의 연금 window opens from the HUD")
	var dissolved: Dictionary = {}
	if panel!=null:
		for uid: String in weapons:
			var box: CheckBox = panel.find_child("Dissolve_"+uid,true,false) as CheckBox
			check(box!=null, "the window lists dissolvable weapon "+uid)
			if box!=null: box.button_pressed = true
		check(panel.find_child("RefineMin_"+str(physical_of(world,target_id)[0]),true,false)!=null, "the window lists the refine target with its min/max buttons")
		(panel.find_child("DissolveSelected",true,false) as Button).pressed.emit()
		var line: String = str((panel.find_child("BlessRefineStatus",true,false) as Label).text)
		evidence["panel_status"] = line
		dissolved = {"ok":physical_of(world,weapon).is_empty(),"amount":int(world.inventory.get(powder_name,0))-before_powder}
	check(dissolved.get("ok",false) and int(dissolved.amount)==expected, "dissolving +0 and +5 grade-3 weapons yields the table amounts " + str(dissolved))
	check(physical_of(world,weapon).is_empty() and int(world.inventory.get(powder_name,0))==before_powder+expected, "the weapons are gone and 축복의 가루 is in the bag")
	evidence["dissolve"] = {"weapon":weapon,"amount":int(dissolved.get("amount",0)),"powder_before":before_powder,"powder_after":int(world.inventory.get(powder_name,0))}
	# 질서의 연금: a failure, then a success.
	var targets: Array = physical_of(world,target_id)
	var gold0: int = int(world.gold)
	var powder0: int = int(SERVICE.powder_owned(world).total)
	check(SERVICE.refine_quote(world,str(targets[0]),"between").get("code")=="amount_between", "an amount between min and max is refused in the world")
	world.rng.seed = seed_for(int(entry.input.MinProbability),false)
	var failed: Dictionary = SERVICE.refine(world,str(targets[0]),"min")
	check(failed.get("ok",false) and failed.success==false, "a roll above the probability fails " + str(failed))
	check(world.item_instances.has(str(targets[0])) and int(world.gold)==gold0-int(entry.cost) and int(SERVICE.powder_owned(world).total)==powder0-int(entry.input.MinAmount), "a failure returns the target and spends the powder and Adena")
	world.rng.seed = seed_for(int(entry.input.MaxProbability),true)
	var won: Dictionary = SERVICE.refine(world,str(targets[0]),"max")
	var output_id: int = int(entry.outputs[0].ItemClassID)
	var outputs: Array = physical_of(world,output_id)
	check(won.get("ok",false) and won.success==true and int(won.output_item_class_id)==output_id, "a roll below the probability succeeds " + str(won))
	check(not world.item_instances.has(str(targets[0])) and outputs.size()==1 and int(world.item_instances[outputs[0]].level)==int(entry.outputs[0].Enchant), "the target becomes the RefineOutput item at its enchant")
	check(int(world.gold)==gold0-2*int(entry.cost) and int(SERVICE.powder_owned(world).total)==powder0-int(entry.input.MinAmount)-int(entry.input.MaxAmount), "success spends the max amount and Adena")
	check(SERVICE.refine(world,str(targets[1]),"min").get("code")=="powder", "without powder the next refine is refused and nothing changes")
	evidence["refine"] = {"target":target_id,"gold_before":gold0,"gold_after":int(world.gold),"powder_before":powder0,"powder_after":int(SERVICE.powder_owned(world).total),"fail_roll":int(failed.get("roll",-1)),"success_roll":int(won.get("roll",-1)),"output":output_id}
	# Save and reload.
	var bag: Dictionary = world.inventory.duplicate(true); var physical: Dictionary = world.item_instances.duplicate(true); var gold: int = int(world.gold)
	check(world._save_game(true)==OK, "the state saves")
	world.inventory = {}; world.item_instances = {}; world.gold = 0
	world._load_game(true)
	var bag_diff: Dictionary = {}
	for key: Variant in bag: if world.inventory.get(key)!=bag[key]: bag_diff[key] = [bag[key],world.inventory.get(key)]
	for key: Variant in world.inventory: if not bag.has(key): bag_diff[key] = [null,world.inventory[key]]
	var lost: Array = []
	for uid: Variant in physical: if not world.item_instances.has(uid): lost.append(uid)
	evidence["reload"] = {"bag_diff":bag_diff,"lost_physical":lost,"physical_before":physical.size(),"physical_after":world.item_instances.size(),"gold":[gold,int(world.gold)]}
	check(bag_diff.is_empty() and lost.is_empty() and int(world.gold)==gold, "inventory, physical items and Adena reload unchanged")
	check(int(world.inventory.get(powder_name,0))==before_powder+expected and physical_of(world,output_id).size()==1 and int(SERVICE.powder_owned(world).total)==0, "축복의 가루 and the refined item survive the reload")
	check(world.patch523_owner_state_problem.is_empty(), "no owner problem after reload")
	world.queue_free()
	await process_frame

func run() -> void:
	rules()
	if not SOURCE.not_installed():
		table()
		await runtime()
	print("BLESS_REFINE523_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
