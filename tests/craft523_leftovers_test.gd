extends SceneTree
## 제작 잔여 근사 (2026-11-17, docs/PATCH523_CRAFTING_EQUIPMENT.md "TWILIGHT 근사 2026-11-17"):
## 1) 일반 세공 주문서 2개 → 축복 세공 주문서 1개: the result is the blessed stack (no longer
##    normalized to a normal scroll);
## 2) a 각성서 held as an awakening supply entity is a craft input: quoted, crafted through
##    Main, its entity quantity debited;
## With the original ZIP, in actual Main.
const APPROX = preload("res://scripts/crafting/patch523_craft_approx.gd")
const SUPPLY = preload("res://scripts/cards/native_awakening_supply.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CRAFT523_LEFTOVERS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func prepared(book: Object, recipe: Dictionary, times: int, skip: Array = []) -> Dictionary:
	var selected: Dictionary = {}
	for slot: Dictionary in recipe.get("material_slots",[]):
		var pick: Dictionary = slot.candidates[0]
		for candidate: Dictionary in slot.candidates:
			if str(candidate.get("source_id","")) in skip: pick = candidate
		selected[str(int(slot.slot_index))] = int(pick.row_id)
	var resolved: Dictionary = book.material_selection(recipe.id,selected).get("recipe",recipe)
	var inventory: Dictionary = {}; var instances: Dictionary = {}; var next: int = 30001
	for material: Dictionary in resolved.materials:
		if material.get("wallet",false) or str(material.source_id) in skip: continue
		var key: String = book.ownership_key(material)
		inventory[key] = int(inventory.get(key,0))+int(material.quantity)*times
		if not material.physical: continue
		for i: int in range(int(material.quantity)*times):
			var record: Dictionary = book.record(str(material.source_id))
			record["bless_state"] = "blessed" if int(material.bless_code)==2 else "normal"
			if record.get("source_m_native_item",false): record["source_bless_raw"] = int(material.bless_code)
			instances[str(next)] = {"name":material.item,"record":record,"sourceId":record.sourceId,"level":int(material.level),"element":"","element_level":0,"bless_state":record.bless_state,"source_bless_code":int(material.bless_code)}
			next += 1
	return {"inventory":inventory,"instances":instances,"next":next,"choices":selected,"gold":book.recipe_cost(resolved,1)*times,"recipe":resolved}

func actual_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 10: await process_frame
	var book: Object = world.patch523_equipment
	var items: Dictionary = world._patch523_craft_item_index()
	var home: Dictionary = {"ServiceRegionCode":"KR","WorldNo":1}
	# 1) blessed 세공 주문서 results.
	var blessed: Array = []; var normalized: Array = []
	for id: String in book.recipes:
		var recipe: Dictionary = book.recipes[id]
		if int(str(recipe.result.source_id)) not in APPROX.BLESSED_STACK_OUTPUTS: continue
		if int(recipe.result.bless_code) == 2: blessed.append(id)
		else: normalized.append(id)
	evidence["blessed"] = {"blessed":blessed,"normal":normalized}
	# 142292..142322 give a normal scroll in the original rows; only the blessed rows are checked.
	var still_normalized: Array = []
	for id: String in normalized:
		if (book.recipes[id].get("twilight_approx",{}).get("row_overrides",{}) as Dictionary).keys().any(func(k: String) -> bool: return k.begins_with("out:")): still_normalized.append(id)
	check(blessed.size() >= 8 and still_normalized.is_empty(), "세공 주문서 crafts pay the blessed stack (no result normalized): "+str(evidence.blessed))
	if not blessed.is_empty():
		var id: String = str(blessed[0]); var recipe: Dictionary = book.recipes[id]
		var state: Dictionary = prepared(book,recipe,1)
		var context: Dictionary = {"level":100,"usage":{},"now":int(Time.get_unix_time_from_system()),"server_profile":home}
		var done: Dictionary = book.execute(id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,-1,context)
		var key: String = book.ownership_key(recipe.result)
		evidence["blessed_craft"] = {"id":id,"ok":done.get("ok"),"reason":done.get("reason",""),"key":key,"count":int(done.get("inventory",{}).get(key,0))}
		check(done.get("ok",false) and key.contains("축복") and int(done.inventory.get(key,0)) == 1, "the craft gives one blessed scroll "+str(evidence.blessed_craft))
	# 2) 각성서 inputs held as supply entities.
	# Original crafts 38344 / 38354 take 6 희귀 / 5 영웅 각성서 (75184 / 75194).
	var supply_recipes: Array = []
	for pair: Array in [["patch523:38344",75184],["patch523:38354",75194]]:
		if book.recipes.has(pair[0]): supply_recipes.append(pair)
	evidence["supply_recipes"] = supply_recipes
	if check(not supply_recipes.is_empty(), "recipes with a 각성서 input exist"):
		var id: String = str(supply_recipes[0][0]); var book_id: int = int(supply_recipes[0][1])
		var recipe: Dictionary = book.recipes[id]
		world.level = maxi(int(world.level),maxi(100,int(recipe.get("craft_conditions",{}).get("min_level",0))))
		world.con_stat = maxi(int(world.con_stat),200)
		var state: Dictionary = prepared(book,recipe,2,[str(book_id)])
		var need: int = 0
		for material: Dictionary in state.recipe.materials:
			if int(str(material.source_id)) == book_id: need = int(material.quantity)
		check(need > 0, "%s takes 각성서 #%d (%d)" % [id,book_id,need])
		var value: Dictionary = SUPPLY.record(book_id)
		var staged: Dictionary = SUPPLY.stage_grant(value,need*2+1,state.instances,{"kind":"twilight_test"})
		world.inventory = state.inventory.duplicate(true); world.item_instances = staged.item_instances.duplicate(true); world.next_item_instance_id = int(state.next)
		world.inventory[SUPPLY.key(value)] = need*2+1
		world.gold = int(state.gold); world.patch523_material_choices[id] = state.choices
		var quote: Dictionary = world._craft_quote(id,1)
		var before: int = world.crafting_log.size()
		world._patch523_craft_requested(id,1)
		var left: int = int(world.item_instances.get(staged.id,{}).get(SUPPLY.QUANTITY,0))
		evidence["supply_craft"] = {"id":id,"book":book_id,"need":need,"quote":quote.get("ok"),"reason":quote.get("reason",""),"crafted":world.crafting_log.size()-before,"left":left,"inventory":int(world.inventory.get(SUPPLY.key(value),0))}
		check(quote.get("ok",false) and world.crafting_log.size() == before+1 and left == need+1 and int(world.inventory.get(SUPPLY.key(value),0)) == need+1, "각성서 supply entity is quoted and debited "+str(evidence.supply_craft))
	world.queue_free()
	for frame: int in 5: await process_frame

func run() -> void:
	check(APPROX.BLESSED_STACK_OUTPUTS.size() == 36, "approximation tables")
	if not SOURCE.not_installed(): await actual_main()
	print("CRAFT523_LEFTOVERS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
