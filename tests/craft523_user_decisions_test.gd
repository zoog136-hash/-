extends SceneTree
## 사용자 결정 2026-11-16 (docs/PATCH523_CRAFTING_EQUIPMENT.md): original 523
## crafts that were held back only by conditions the tables cannot name are
## admitted with the condition lifted —
##   count_limit  ItemCraftRestriction rows without a verified policy: no limit
##   time_window  CraftTimeTypeID ≠ 1 / unreadable period: no period
##   no_repeat    NoRepeat: repeated crafting allowed
## — while crafts whose server set names only other servers are deleted
## (reason other_server_only_set: never admitted, never listed).
## Synthetic checks always run; with the original definition ZIP every admitted
## decision craft executes in the real rules model, one sample per class is
## quoted and crafted twice through Main's own craft path, saved and reloaded,
## and no other-server craft is in the book.
const CONDITIONS = preload("res://scripts/crafting/patch523_craft_conditions.gd")
const PROJECTION = preload("res://scripts/crafting/patch523_rules_projection.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SERVER_PROFILE = preload("res://scripts/loot/current523_server_profile.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CRAFT523_USER_DECISIONS_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func base_condition() -> Dictionary:
	return {"schema":"patch523-craft-conditions-v1","min_level":0,"max_level":0,"source_level_fields":{"IsBelowLevelLimit":false,"LevelLimitValue":0}}

func view(fields: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"ItemCraftID":7,"ServerLimitSetID":0,"IsCoalitionItem":false,"NoRepeat":false,"IsBelowLevelLimit":false,"LevelLimitValue":0,
		"CraftTimeTypeID":1,"EffectiveFrom":1,"EffectiveTo":3,"PopupText":0,"AlwaysSuccess":1}
	for key: String in fields: row[key] = fields[key]
	return row

func synthetic() -> void:
	# The waivers the projection derives.
	var restriction: Array = [{"ID":44,"ItemCraftID":7,"ServiceTypeID":52,"Value":1,"RefreshUnitID":111,"isMultiCount":false},{"ID":12,"ItemCraftID":7,"ServiceTypeID":62,"Value":3,"RefreshUnitID":71,"isMultiCount":false}]
	var waived: Dictionary = PROJECTION.decision_waivers(view(),restriction,{},false,{})
	check(waived == {"count_limit_restriction_ids":[12,44]}, "unnamed restriction rows → count limit lifted (sorted row IDs) "+str(waived))
	check(PROJECTION.decision_waivers(view(),restriction,{"quota":{}},false,{}).is_empty(), "a craft with a verified policy entry is never waived")
	check(PROJECTION.decision_waivers(view(),[restriction[0]],{},true,{}).is_empty(), "a verified quota stays a quota")
	check(PROJECTION.decision_waivers(view({"NoRepeat":true}),[],{},false,{}) == {"no_repeat":true}, "NoRepeat → repeat allowed")
	check(PROJECTION.decision_waivers(view({"CraftTimeTypeID":11,"EffectiveFrom":5,"EffectiveTo":9}),[],{},false,null) == {"time_window":{"CraftTimeTypeID":11,"EffectiveFrom":5,"EffectiveTo":9}}, "time type ≠ 1 → period lifted")
	check(PROJECTION.decision_waivers(view({"EffectiveFrom":5,"EffectiveTo":9}),[],{},false,null).has("time_window"), "unreadable period → period lifted")
	check(PROJECTION.decision_waivers(view({"EffectiveFrom":5,"EffectiveTo":9}),[],{},false,{"start_unix":1}).is_empty(), "a readable original period stays a period")
	# Condition structure.
	var condition: Dictionary = base_condition()
	condition.user_decision = {"date":"2026-11-16","count_limit_restriction_ids":[12,44],"no_repeat":true}
	check(CONDITIONS.valid(condition), "decision condition is valid")
	for broken: Dictionary in [{"date":"2026-11-15","no_repeat":true},{"date":"2026-11-16"},{"date":"2026-11-16","no_repeat":false},
			{"date":"2026-11-16","count_limit_restriction_ids":[]},{"date":"2026-11-16","no_repeat":true,"extra":1},
			{"date":"2026-11-16","time_window":{"CraftTimeTypeID":11}}]:
		var other: Dictionary = base_condition(); other.user_decision = broken
		check(not CONDITIONS.valid(other), "malformed decision refused "+str(broken))
	var with_quota: Dictionary = condition.duplicate(true); with_quota.quota = {"limit":1}
	check(not CONDITIONS.valid(with_quota), "a lifted count limit never carries a quota")
	# The runtime join against the original rows.
	var recipe: Dictionary = {"id":"patch523:7","popup_text_id":0,"craft_conditions":condition}
	check(CONDITIONS.source_recipe(recipe,[view({"NoRepeat":true})],restriction).ok, "source join: waived rows accepted")
	check(not CONDITIONS.source_recipe(recipe,[view({"NoRepeat":true})],[restriction[0]]).ok, "source join: different restriction rows refused")
	check(not CONDITIONS.source_recipe(recipe,[view()],restriction).ok, "source join: no_repeat decision without NoRepeat refused")
	var plain: Dictionary = {"id":"patch523:7","popup_text_id":0}
	check(not CONDITIONS.source_recipe(plain,[view({"NoRepeat":true})],[]).ok, "source join: NoRepeat without the decision still refused")
	check(not CONDITIONS.source_recipe(plain,[view()],restriction).ok, "source join: restriction rows without the decision still refused")
	var timed: Dictionary = base_condition(); timed.user_decision = {"date":"2026-11-16","time_window":{"CraftTimeTypeID":11,"EffectiveFrom":5,"EffectiveTo":9}}
	check(CONDITIONS.source_recipe({"id":"patch523:7","popup_text_id":0,"craft_conditions":timed},[view({"CraftTimeTypeID":11,"EffectiveFrom":5,"EffectiveTo":9})],[]).ok, "source join: waived period accepted")
	check(not CONDITIONS.source_recipe({"id":"patch523:7","popup_text_id":0,"craft_conditions":timed},[view({"CraftTimeTypeID":11,"EffectiveFrom":5,"EffectiveTo":10})],[]).ok, "source join: other period refused")
	# Crafting: no count, no period — the same craft passes again and again.
	var context: Dictionary = {"level":1,"usage":{},"now":4000000000}
	for attempt: int in 3: check(CONDITIONS.stage(recipe,1,context).ok and CONDITIONS.stage({"id":"patch523:7","craft_conditions":timed},1,context).ok, "stage passes again (%d)" % attempt)
	check(CONDITIONS.brief(recipe,context).contains("사용자 결정 2026-11-16") and CONDITIONS.summary(recipe,context).contains("반복 제작 허용"), "window shows the decision")

func waiver_class(recipe: Dictionary) -> String:
	var decision: Dictionary = recipe.get("craft_conditions",{}).get("user_decision",{})
	var parts: PackedStringArray = []
	for key: String in ["count_limit_restriction_ids","time_window","no_repeat"]:
		if decision.has(key): parts.append(key.get_slice("_",0) if key != "no_repeat" else "no_repeat")
	return "+".join(parts)

func prepared(book: Object, recipe: Dictionary, times: int) -> Dictionary:
	var selected: Dictionary = {}
	for slot: Dictionary in recipe.get("material_slots",[]):
		selected[str(int(slot.slot_index))] = int(slot.candidates[0].row_id)
	var resolved: Dictionary = book.material_selection(recipe.id,selected).recipe
	var inventory: Dictionary = {}; var instances: Dictionary = {}; var next: int = 30001
	for material: Dictionary in resolved.materials:
		if material.get("wallet",false): continue
		var key: String = book.ownership_key(material)
		inventory[key] = int(inventory.get(key,0))+int(material.quantity)*times
		if not material.physical: continue
		for i: int in range(int(material.quantity)*times):
			var record: Dictionary = book.record(str(material.source_id))
			record["bless_state"] = "blessed" if int(material.bless_code)==2 else "normal"
			if record.get("source_m_native_item",false): record["source_bless_raw"] = int(material.bless_code)
			instances[str(next)] = {"name":material.item,"record":record,"sourceId":record.sourceId,"level":int(material.level),"element":"","element_level":0,"bless_state":record.bless_state,"source_bless_code":int(material.bless_code)}
			next += 1
	return {"inventory":inventory,"instances":instances,"next":next,"choices":selected,"gold":book.recipe_cost(resolved,1)*times}

func actual_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 10: await process_frame
	var book: Object = world.patch523_equipment
	var items: Dictionary = world._patch523_craft_item_index()
	var classes: Dictionary = {}
	var decided: Array = []
	for id: String in book.recipes:
		if book.recipes[id].get("craft_conditions",{}).has("user_decision"):
			decided.append(id)
			var name: String = waiver_class(book.recipes[id])
			classes[name] = int(classes.get(name,0))+1
	var rejected: Dictionary = book.data.get("recipe_summary",{}).get("rejected",{})
	evidence["recipes"] = book.recipes.size(); evidence["decision_recipes"] = decided.size(); evidence["by_class"] = classes; evidence["rejected"] = rejected
	check(decided.size() >= 100, "decision crafts admitted (%d of %d)" % [decided.size(),book.recipes.size()])
	for key: String in ["count","time","no_repeat"]:
		var any: bool = false
		for name: String in classes:
			if key in name.split("+"): any = true
		check(any, "at least one admitted craft lifts "+key)
	# Every decision craft executes in the real rules model (KR 1), twice in a row.
	var home: Dictionary = {"ServiceRegionCode":"KR","WorldNo":1}
	var executed: int = 0; var failed: Array = []
	for id: String in decided:
		var recipe: Dictionary = book.recipes[id]
		var state: Dictionary = prepared(book,recipe,2)
		var roll: int = 0 if recipe.has("outcomes") else -1
		var context: Dictionary = {"level":maxi(100,int(recipe.craft_conditions.min_level)),"usage":{},"now":int(Time.get_unix_time_from_system()),"server_profile":home}
		var first: Dictionary = book.execute(id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,roll,context)
		if not first.get("ok",false): failed.append(id+":"+str(first.get("reason",""))); continue
		context.usage = first.get("usage_after",context.usage)
		var second: Dictionary = book.execute(id,1,first.inventory,int(first.gold_after),items,first.item_instances,{},1000000000,2000000000,int(first.next_instance_id),{},state.choices,roll,context)
		if second.get("ok",false): executed += 1
		else: failed.append(id+":second:"+str(second.get("reason","")))
	evidence["executed_twice"] = executed; evidence["failed"] = failed.slice(0,20)
	check(failed.is_empty(), "every decision craft executes twice for KR 1: %s" % str(failed.slice(0,5)))
	# Other-server crafts are deleted: none is in the book.
	var full: Dictionary = book.materialized_data()
	var admission: Dictionary = full.get("recipe_admission",{})
	var other: Array = []
	for craft: String in admission:
		if admission[craft].get("reason") == "other_server_only_set": other.append(craft)
	var listed: int = 0; var not_other: int = 0
	for craft: String in other:
		if book.recipes.has("patch523:"+craft): listed += 1
		var views: Array = book.recipe_evidence(int(craft)).get("views",[])
		var set_id: int = int(views[0].ServerLimitSetID) if not views.is_empty() else 0
		var rows: Array = SOURCE.related("ServerLimit","ServerLimitSetID",set_id)
		if set_id <= 0 or rows.is_empty() or SERVER_PROFILE.rows_allow(rows,"KR",1): not_other += 1
	var restricted_other: int = 0
	for craft: String in other:
		if not book.recipe_evidence(int(craft)).get("restrictions",[]).is_empty(): restricted_other += 1
	evidence["other_server_deleted"] = other.size(); evidence["other_server_with_restriction_rows"] = restricted_other
	check(other.size() > 0 and int(rejected.get("other_server_only_set",0)) == other.size(), "other-server crafts recorded as deleted (%d)" % other.size())
	check(listed == 0 and not_other == 0, "no other-server craft is listed and every one names only other servers (%d listed, %d not other)" % [listed,not_other])
	for id: String in book.recipes:
		var set_id: int = int(book.recipes[id].get("craft_conditions",{}).get("server_limit_set_id",0))
		if set_id > 0 and not SERVER_PROFILE.rows_allow(SOURCE.related("ServerLimit","ServerLimitSetID",set_id),"KR",1): listed += 1
	check(listed == 0, "every listed server-set craft names KR 1")
	# One sample per class: quote → craft twice through Main's path, save, reload.
	var samples: Dictionary = {}; var skipped: Dictionary = {}
	for physical_pass: bool in [false,true]:
		for id: String in decided:
			var name: String = waiver_class(book.recipes[id])
			if samples.has(name): continue
			var recipe: Dictionary = book.recipes[id]
			world.level = maxi(int(world.level),int(recipe.craft_conditions.min_level))
			# Room for heavy results (the weight rule itself is unchanged).
			world.con_stat = maxi(int(world.con_stat),200)
			var physical: bool = recipe.result.get("physical",false)
			for material: Dictionary in book.material_selection(id,prepared(book,recipe,1).choices).recipe.materials:
				if material.get("physical",false): physical = true
			if physical != physical_pass: continue
			var state: Dictionary = prepared(book,recipe,2)
			world.inventory = state.inventory.duplicate(true); world.item_instances = state.instances.duplicate(true); world.next_item_instance_id = int(state.next)
			world.gold = int(state.gold); world.patch523_material_choices[id] = state.choices
			var quote: Dictionary = world._craft_quote(id,1)
			if not quote.get("ok",false): skipped[name] = id+":quote:"+str(quote.get("reason","")); continue
			var before: int = world.crafting_log.size()
			world._patch523_craft_requested(id,1)
			world._patch523_craft_requested(id,1)
			if world.crafting_log.size() != before + 2: skipped[name] = id+":crafted %d" % (world.crafting_log.size()-before); continue
			var result: String = str(recipe.result.get("inventory_key",recipe.result.item))
			var count: int = int(world.inventory.get(result,0))
			var random: bool = recipe.has("outcomes")
			if recipe.result.get("physical",false):
				count = 0
				for instance: Variant in world.item_instances.values():
					if instance is Dictionary and (str(instance.get("name","")) == str(recipe.result.item) or str(instance.get("record",{}).get("name","")) == str(recipe.result.item)): count += 1
			samples[name] = {"id":id,"result":recipe.result.item,"count":count,"physical":physical,"random":random,"log":world.crafting_log.slice(-2).map(func(e: Dictionary) -> String: return "%s×%d" % [e.output,int(e.quantity)])}
			# A random craft records both attempts (its rolled result may be a failure branch).
			check(random or count >= 2*int(recipe.result.quantity), "%s crafted twice through Main (%s ×%d)" % [id,recipe.result.item,count])
			world._save_game(true)
			var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
			check(saved is Dictionary, "the craft results are saved")
			var inventory_before: Dictionary = world.inventory.duplicate(true); var instances_before: int = world.item_instances.size()
			world.inventory = {}; world.item_instances = {}
			world._load_game(true)
			check(world.inventory.get(result,0) == inventory_before.get(result,0) and world.item_instances.size() == instances_before, "%s: reload keeps the crafted results" % id)
	evidence["samples"] = samples; evidence["skipped"] = skipped
	for name: String in classes:
		check(samples.has(name), "class %s was crafted twice in Main" % name)
	world.queue_free()
	await process_frame

func run() -> void:
	synthetic()
	if not SOURCE.not_installed(): await actual_main()
	print("CRAFT523_USER_DECISIONS_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() else 1)
