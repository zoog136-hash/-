extends SceneTree
## TWILIGHT 근사 2026-11-16 — the remaining original 523 crafts opened with
## researched approximations (scripts/crafting/patch523_craft_approx.gd,
## docs/PATCH523_CRAFTING_EQUIPMENT.md "TWILIGHT 근사 2026-11-16 — 남은 제작식").
## Synthetic checks always run; with the original definition ZIP every
## approximated craft executes twice in the real rules model, one sample per
## kind is quoted and crafted twice through Main's own craft path, saved and
## reloaded, and the reason counts are recorded.
const APPROX = preload("res://scripts/crafting/patch523_craft_approx.gd")
const CONDITIONS = preload("res://scripts/crafting/patch523_craft_conditions.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CRAFT523_APPROX_REST_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func synthetic() -> void:
	# 성공 페이백
	var main: Dictionary = {"ID":1,"ItemCraftOutputTypeID":1,"ItemClassID":10,"Amount":1,"Enchant":0,"ItemBlessCodeID":1,"Probability":1000000,"ClanItemClassID":0,"ClanAmount":0}
	var payback: Dictionary = {"ID":2,"ItemCraftOutputTypeID":12,"ItemClassID":20,"Amount":45,"Enchant":0,"ItemBlessCodeID":1,"Probability":0,"ClanItemClassID":0,"ClanAmount":0}
	var split: Dictionary = APPROX.payback_split([main,payback])
	check(split.core == [main] and split.payback == [payback], "type 12 Probability 0 row is the success payback")
	var failure_payback: Dictionary = payback.duplicate(); failure_payback.ItemCraftOutputTypeID = 22
	check(APPROX.payback_split([main,failure_payback]).payback.is_empty(), "other payback types are not opened")
	var random: Dictionary = main.duplicate(); random.Probability = 500000
	check(APPROX.payback_split([random,payback]).payback.is_empty(), "payback only on a guaranteed craft")
	# 혈맹 몫
	var clan: Dictionary = main.duplicate(); clan.ClanItemClassID = 216053; clan.ClanAmount = 18; clan.ClanEnchant = 0; clan.ClanItemBlessCodeID = 0
	var rows: Array = APPROX.clan_rows([clan])
	check(rows.size() == 1 and int(rows[0].ItemClassID) == 216053 and int(rows[0].Amount) == 18 and int(rows[0].ItemBlessCodeID) == 1, "clan share row (bless 0 → normal)")
	# 서버 세트 행 없음
	check(APPROX.empty_server_set_allows({"ServiceRegionCode":"KR","WorldNo":1}) and not APPROX.empty_server_set_allows({"ServiceRegionCode":"TW","WorldNo":1}), "empty server set = KR 1 only")
	var condition: Dictionary = {"schema":"patch523-craft-conditions-v1","min_level":0,"max_level":0,"server_limit_set_id":274,"twilight_approx":{"date":"2026-11-16","server_set_without_rows":274}}
	check(CONDITIONS.valid(condition), "empty-set condition valid")
	var bad: Dictionary = condition.duplicate(true); bad.twilight_approx.server_set_without_rows = 275
	check(not CONDITIONS.valid(bad), "empty-set flag must name the condition's set")
	# 행 보정
	var items: Dictionary = {7:{"TestItem":true},8:{"TestItem":false},9:{"TestItem":false}}
	var row_of: Callable = func(id: int) -> Dictionary: return items.get(id,{})
	var ins: Array = [{"ID":11,"ItemClassID":7,"Amount":1,"Enchant":0,"ItemBlessCodeID":1},{"ID":12,"ItemClassID":8,"Amount":3,"Enchant":2,"ItemBlessCodeID":2,"ItemHoningEpithetID":8}]
	var outs: Array = [{"ID":13,"ItemClassID":9,"Amount":1,"Enchant":0,"ItemBlessCodeID":1}]
	var calls: Array = [0]
	var reasons: Callable = func(i: Array, _o: Array) -> Dictionary:
		calls[0] += 1
		for row: Dictionary in i:
			if int(row.ItemClassID) == 7: return {"reason":"unresolved_item_condition","item_id":7}
			if int(row.get("ItemHoningEpithetID",0)) != 0: return {"reason":"unresolved_item_state","item_id":8}
			if int(row.Enchant) != 0: return {"reason":"stack_state_cannot_be_represented","item_id":8}
		return {}
	var fixed: Dictionary = APPROX.fix_rows([],ins,outs,reasons,row_of)
	check(fixed.ins.size() == 1 and int(fixed.ins[0].ItemClassID) == 8 and int(fixed.ins[0].Enchant) == 0 and int(fixed.ins[0].ItemBlessCodeID) == 1, "test input dropped, honing + stack state normalized "+str(fixed))
	check(APPROX.apply_overrides([],ins,outs,fixed.overrides,row_of).ins == fixed.ins, "runtime re-applies the recorded overrides identically")
	check(APPROX.apply_overrides([],ins,outs,{"in:12":{"drop":true}},row_of).is_empty(), "a non-test input can never be dropped")
	check(APPROX.apply_overrides([],ins,outs,{"in:12":{"Enchant":5}},row_of).is_empty(), "overrides only normalize")
	var only_test: Dictionary = APPROX.fix_rows([],[ins[0]],outs,reasons,row_of)
	check(only_test.overrides.is_empty(), "a craft whose only input is a test item stays out")
	# TestItem 대체
	var subst: Dictionary = APPROX.substitutes_for([{"ItemClassID":113892}],func(id: int) -> Dictionary: return {113892:{"TestItem":true,"CategoryID":79},549:{"TestItem":false,"CategoryID":79}}.get(id,{}))
	check(subst == {113892:549}, "TestItem substitute table")
	check(APPROX.substitute_rows([{"ItemClassID":113892.0}],subst)[0].ItemClassID == 549.0, "substituted row keeps the number type")

func kinds(book: Object, id: String) -> PackedStringArray:
	var recipe: Dictionary = book.recipes[id]
	var approx: Dictionary = recipe.get("twilight_approx",{})
	var result: PackedStringArray = []
	if approx.has("server_set_without_rows"): result.append("server_set_without_rows")
	if approx.has("test_item_substitutes"): result.append("test_item_substitute")
	for kind: Variant in approx.get("row_kinds",[]): result.append(str(kind))
	if approx.get("fee_only",false): result.append("fee_only")
	for bonus: Dictionary in recipe.get("bonus_outputs",[]):
		if not result.has(str(bonus.kind)): result.append(str(bonus.kind))
	for material: Dictionary in [recipe.result] + recipe.materials:
		var owner: String = str(book.data.items.get(str(material.source_id),{}).get("twilight_owner_binding",""))
		if not owner.is_empty() and not result.has("owner_"+owner): result.append("owner_"+owner)
	return result

func prepared(book: Object, recipe: Dictionary, times: int) -> Dictionary:
	var selected: Dictionary = {}
	for slot: Dictionary in recipe.get("material_slots",[]):
		selected[str(int(slot.slot_index))] = int(slot.candidates[0].row_id)
	var resolved: Dictionary = book.material_selection(recipe.id,selected).get("recipe",recipe)
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
	var rejected: Dictionary = book.data.get("recipe_summary",{}).get("rejected",{})
	var approximated: Array = []; var by_kind: Dictionary = {}
	for id: String in book.recipes:
		var found: PackedStringArray = kinds(book,id)
		if found.is_empty(): continue
		approximated.append(id)
		for kind: String in found: by_kind[kind] = int(by_kind.get(kind,0))+1
	evidence["recipes"] = book.recipes.size(); evidence["approximated"] = approximated.size(); evidence["by_kind"] = by_kind; evidence["rejected"] = rejected
	check(book.recipes.size() >= 1450, "1,328 + approximations admitted (%d)" % book.recipes.size())
	for kind: String in ["server_set_without_rows","test_item_substitute","test_input_dropped","stack_state_normal","payback","clan","owner_wallet","owner_supply"]:
		check(by_kind.has(kind), "approximation kind admitted: "+kind)
	check(int(rejected.get("other_server_only_set",0)) >= 131, "other-server-only crafts stay deleted")
	# Every approximated craft executes twice in the real rules model (KR 1).
	var home: Dictionary = {"ServiceRegionCode":"KR","WorldNo":1}
	var executed: int = 0; var failed: Array = []
	for id: String in approximated:
		var recipe: Dictionary = book.recipes[id]
		var state: Dictionary = prepared(book,recipe,2)
		var roll: int = 0 if recipe.has("outcomes") else -1
		var context: Dictionary = {"level":maxi(100,int(recipe.get("craft_conditions",{}).get("min_level",0))),"usage":{},"now":int(Time.get_unix_time_from_system()),"server_profile":home}
		var first: Dictionary = book.execute(id,1,state.inventory,state.gold,items,state.instances,{},1000000000,2000000000,state.next,{},state.choices,roll,context)
		if not first.get("ok",false): failed.append(id+":"+str(first.get("reason",""))); continue
		for bonus: Dictionary in first.get("bonus_outputs",[]):
			if int(first.inventory.get(book.ownership_key(bonus),0)) < int(bonus.quantity): failed.append(id+":bonus")
		context.usage = first.get("usage_after",context.usage)
		var second: Dictionary = book.execute(id,1,first.inventory,int(first.gold_after),items,first.item_instances,{},1000000000,2000000000,int(first.next_instance_id),{},state.choices,roll,context)
		if second.get("ok",false): executed += 1
		else: failed.append(id+":second:"+str(second.get("reason","")))
	evidence["executed_twice"] = executed; evidence["failed"] = failed.slice(0,30)
	check(failed.is_empty(), "every approximated craft executes twice: %s" % str(failed.slice(0,6)))
	# A KR 2 profile refuses the empty-set crafts.
	for id: String in approximated:
		if not kinds(book,id).has("server_set_without_rows"): continue
		check(not CONDITIONS.server_allows(book.recipes[id].craft_conditions,{"server_profile":{"ServiceRegionCode":"KR","WorldNo":2}}).ok, "empty server set is KR 1 only (%s)" % id)
		break
	# One sample per kind: quote → craft twice through Main, save, reload.
	var samples: Dictionary = {}; var skipped: Dictionary = {}
	for id: String in approximated:
		var recipe: Dictionary = book.recipes[id]
		var wanted: String = ""
		for kind: String in kinds(book,id):
			if not samples.has(kind): wanted = kind; break
		if wanted.is_empty(): continue
		world.level = maxi(int(world.level),int(recipe.get("craft_conditions",{}).get("min_level",0)))
		world.con_stat = maxi(int(world.con_stat),200)
		var state: Dictionary = prepared(book,recipe,2)
		world.inventory = state.inventory.duplicate(true); world.item_instances = state.instances.duplicate(true); world.next_item_instance_id = int(state.next)
		world.gold = int(state.gold); world.patch523_material_choices[id] = state.choices
		var quote: Dictionary = world._craft_quote(id,1)
		if not quote.get("ok",false): skipped[wanted] = id+":quote:"+str(quote.get("reason","")); continue
		var before: int = world.crafting_log.size()
		var rng_state: int = world.rng.state
		world._patch523_craft_requested(id,1)
		world._patch523_craft_requested(id,1)
		if world.crafting_log.size() != before + 2: skipped[wanted] = id+":crafted %d" % (world.crafting_log.size()-before); continue
		var result_key: String = str(recipe.result.get("inventory_key",recipe.result.item))
		var bonus_ok: bool = true
		if not recipe.has("outcomes"):
			for bonus: Dictionary in recipe.get("bonus_outputs",[]):
				if int(world.inventory.get(book.ownership_key(bonus),0)) < 2*int(bonus.quantity): bonus_ok = false
		var count: int = int(world.inventory.get(result_key,0))
		if recipe.result.get("physical",false):
			count = 0
			for instance: Variant in world.item_instances.values():
				if instance is Dictionary and str(instance.get("name","")) == str(recipe.result.item): count += 1
		check(recipe.has("outcomes") or count >= 2*int(recipe.result.quantity), "%s (%s) crafted twice through Main: %s ×%d" % [id,wanted,recipe.result.item,count])
		check(bonus_ok, "%s: payback / clan share given with each craft" % id)
		world._save_game(true)
		var inventory_before: Dictionary = world.inventory.duplicate(true); var instances_before: int = world.item_instances.size()
		world.inventory = {}; world.item_instances = {}
		world._load_game(true)
		check(int(world.inventory.get(result_key,0)) == int(inventory_before.get(result_key,0)) and world.item_instances.size() == instances_before, "%s: reload keeps the crafted results" % id)
		for kind: String in kinds(book,id):
			if not samples.has(kind): samples[kind] = {"id":id,"result":recipe.result.item,"count":count,"log":world.crafting_log.slice(-2).map(func(e: Dictionary) -> String: return "%s×%d" % [e.output,int(e.quantity)])}
	evidence["samples"] = samples; evidence["skipped"] = skipped
	for kind: String in by_kind:
		check(samples.has(kind), "kind %s crafted twice through Main (%s)" % [kind,str(skipped.get(kind,""))])
	world.queue_free()
	await process_frame

func run() -> void:
	synthetic()
	if not SOURCE.not_installed(): await actual_main()
	print("CRAFT523_APPROX_REST_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() and checks >= 10 else 1)
