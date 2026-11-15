extends SceneTree
## Original 523 crafts with a ServerLimitSetID (ItemCraftView): admitted when
## the set's ServerLimit rows name the offline game profile (KR world 1), the
## same rule items, NPC spawns and the shop use (current523_server_profile),
## and checked again against the game's server profile on every craft.
## Synthetic checks always run; with the original definition ZIP every such
## recipe is executed in the real rules model and one is crafted in Main.
const CONDITIONS = preload("res://scripts/crafting/patch523_craft_conditions.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CRAFT523_SERVER_SETS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func condition(set_id: Variant) -> Dictionary:
	return {"schema":"patch523-craft-conditions-v1","min_level":0,"max_level":0,"source_level_fields":{"IsBelowLevelLimit":false,"LevelLimitValue":0},"server_limit_set_id":set_id}

func synthetic() -> void:
	check(CONDITIONS.valid(condition(772)), "a server set condition is valid")
	check(not CONDITIONS.valid(condition(0)) and not CONDITIONS.valid(condition(-3)) and not CONDITIONS.valid(condition("772")), "set 0 / negative / text is not a server condition")
	var recipe: Dictionary = {"id":"patch523:1","craft_conditions":condition(772)}
	check(not CONDITIONS.stage(recipe,1,{"level":1}).ok, "without a server profile the craft is refused")
	check(not CONDITIONS.stage(recipe,1,{"level":1,"server_profile":{"ServiceRegionCode":"KR"}}).ok, "a profile without WorldNo is refused")
	check(CONDITIONS.stage({"id":"patch523:2"},1,{}).ok, "a craft without conditions is unchanged")

func prepared(book: Object, recipe: Dictionary) -> Dictionary:
	var selected: Dictionary = {}
	for slot: Dictionary in recipe.get("material_slots",[]):
		selected[str(int(slot.slot_index))] = int(slot.candidates[0].row_id)
	var resolved: Dictionary = book.material_selection(recipe.id,selected).recipe
	var inventory: Dictionary = {}; var instances: Dictionary = {}; var next: int = 30001
	for material: Dictionary in resolved.materials:
		if material.get("wallet",false): continue
		var key: String = book.ownership_key(material)
		inventory[key] = int(inventory.get(key,0))+int(material.quantity)
		if not material.physical: continue
		for i: int in range(int(material.quantity)):
			var record: Dictionary = book.record(str(material.source_id))
			record["bless_state"] = "blessed" if int(material.bless_code)==2 else "normal"
			if record.get("source_m_native_item",false): record["source_bless_raw"] = int(material.bless_code)
			instances[str(next)] = {"name":material.item,"record":record,"sourceId":record.sourceId,"level":int(material.level),"element":"","element_level":0,"bless_state":record.bless_state,"source_bless_code":int(material.bless_code)}
			next += 1
	return {"inventory":inventory,"instances":instances,"next":next,"choices":selected,"gold":book.recipe_cost(resolved,1)}

func actual_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 10: await process_frame
	var book: Object = world.patch523_equipment
	var items: Dictionary = world._patch523_craft_item_index()
	var server_ids: Array = []
	for id: String in book.recipes:
		if book.recipes[id].get("craft_conditions",{}).has("server_limit_set_id"): server_ids.append(id)
	evidence["recipes"] = book.recipes.size(); evidence["server_recipes"] = server_ids.size()
	check(server_ids.size() >= 200, "original server-set crafts admitted (%d of %d)" % [server_ids.size(),book.recipes.size()])
	var home: Dictionary = {"ServiceRegionCode":"KR","WorldNo":1}
	var other: Dictionary = {"ServiceRegionCode":"ZZ","WorldNo":1} # a region no set names
	var executed: int = 0; var refused_elsewhere: int = 0; var failed: Array = []
	for id: String in server_ids:
		var recipe: Dictionary = book.recipes[id]
		var rows: Array = SOURCE.related("ServerLimit","ServerLimitSetID",int(recipe.craft_conditions.server_limit_set_id))
		var named: bool = false
		for row: Dictionary in rows:
			if str(row.ServiceRegionCode)=="KR" and int(row.WorldNo)==1: named = true
		if not named: failed.append(id+":set_not_kr1"); continue
		var state: Dictionary = prepared(book,recipe)
		var roll: int = 0 if recipe.has("outcomes") else -1
		var level: int = maxi(100,int(recipe.craft_conditions.min_level))
		var context: Dictionary = {"level":level,"usage":{},"now":int(Time.get_unix_time_from_system()),"server_profile":home}
		var done: Dictionary = book.execute(id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,roll,context)
		if done.get("ok",false): executed += 1
		elif not str(done.get("reason","")).contains("기간"): failed.append(id+":"+str(done.get("reason","")))
		context.server_profile = other
		var elsewhere: Dictionary = book.execute(id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,roll,context)
		if not elsewhere.get("ok",false) and str(elsewhere.get("reason","")).contains("서버"): refused_elsewhere += 1
	evidence["executed"] = executed; evidence["refused_elsewhere"] = refused_elsewhere; evidence["failed"] = failed.slice(0,20)
	check(failed.is_empty(), "every admitted server-set craft executes for KR 1 (or is outside its original period): %s" % str(failed.slice(0,5)))
	check(refused_elsewhere == server_ids.size(), "every one is refused for a server its set does not name (%d/%d)" % [refused_elsewhere,server_ids.size()])
	# One real craft through the game's own path, saved and reloaded.
	var crafted: String = ""
	for id: String in server_ids:
		var recipe: Dictionary = book.recipes[id]
		if recipe.has("outcomes") or recipe.craft_conditions.has("active_window") or recipe.craft_conditions.has("quota") or int(recipe.craft_conditions.min_level) > 0: continue
		var state: Dictionary = prepared(book,recipe)
		var physical: bool = false
		for material: Dictionary in book.material_selection(id,state.choices).recipe.materials:
			if material.get("physical",false): physical = true
		if physical or recipe.result.get("physical",false): continue
		world.inventory = state.inventory.duplicate(true); world.item_instances = {}; world.gold = int(state.gold)
		var before: int = world.crafting_log.size()
		world._patch523_craft_requested(id,1)
		if world.crafting_log.size() == before + 1:
			crafted = id
			var name: String = str(recipe.result.get("inventory_key",recipe.result.item))
			evidence["crafted"] = {"id":id,"result":name,"count":int(world.inventory.get(name,0))}
			check(int(world.inventory.get(name,0)) >= int(recipe.result.quantity), "crafted %s through the game's craft path" % id)
			var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
			check(saved is Dictionary and int((saved as Dictionary).get("inventory",{}).get(name,0)) == int(world.inventory.get(name,0)), "the craft result is saved")
			var expected: int = int(world.inventory.get(name,0))
			world.inventory.erase(name)
			world._load_game(true)
			check(int(world.inventory.get(name,0)) == expected, "reload keeps the crafted result")
			break
	check(not crafted.is_empty(), "one non-physical server-set craft was performed in Main")
	world.queue_free()
	await process_frame

func run() -> void:
	synthetic()
	if not SOURCE.not_installed(): await actual_main()
	print("CRAFT523_SERVER_SETS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
