extends SceneTree
## 비법서 제작 (original GachaCraft, TWILIGHT 근사 — scripts/crafting/patch523_gacha_craft.gd).
## Synthetic: the pure draw (group → item → bound) over a fixed table, the
## distribution over many rolls, amount/enchant/bless carried to the grant spec.
## With the original definition ZIP: every original weight set sums to
## 10,000,000, every usable book has a draw table for every class, the
## distribution of many draws matches the original group weights, and the
## real Main quotes, executes (book + material + 아데나 consumed, the drawn
## item granted with its ItemAmount/ItemEnchant/bless), saves and reloads.
const GACHA = preload("res://scripts/crafting/patch523_gacha_craft.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SUPPLY = preload("res://scripts/loot/patch523_item_inventory.gd")
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []
var evidence: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition: failures.append(label); printerr("CRAFT523_GACHA_FAIL: ",label)
	return condition

func _initialize() -> void: call_deferred("run")

func synthetic() -> void:
	var rows: Array = [
		{"ID":1,"ItemClassID":11,"ItemAmount":1,"ItemEnchant":0,"ItemBlessCodeID":1,"Probability":7,"BoundItemProbability":0},
		{"ID":2,"ItemClassID":12,"ItemAmount":300,"ItemEnchant":0,"ItemBlessCodeID":2,"Probability":3,"BoundItemProbability":0},
		{"ID":3,"ItemClassID":13,"ItemAmount":1,"ItemEnchant":5,"ItemBlessCodeID":0,"Probability":1,"BoundItemProbability":0}]
	var drawn: Dictionary = {"ok":true,"entries":[{"group_id":1,"row":rows[0],"weight":700},{"group_id":1,"row":rows[1],"weight":200},{"group_id":2,"row":rows[2],"weight":100}],"total":1000}
	check(GACHA.pick(drawn,0,0).item_class_id == 11 and GACHA.pick(drawn,699,0).item_class_id == 11, "roll below the first weight picks the first row")
	var second: Dictionary = GACHA.pick(drawn,700,0)
	check(second.item_class_id == 12 and second.amount == 300 and second.bless_raw == 2, "ItemAmount / bless carried to the grant")
	var third: Dictionary = GACHA.pick(drawn,999,0)
	check(third.item_class_id == 13 and third.enchant == 5 and third.bless_raw == 1, "ItemEnchant carried; bless 0 given as normal (근사)")
	var counts: Dictionary = {}
	var rng := RandomNumberGenerator.new(); rng.seed = 523
	for i: int in 100000:
		var id: int = int(GACHA.pick(drawn,rng.randi_range(0,999),0).item_class_id)
		counts[id] = int(counts.get(id,0))+1
	check(absf(float(counts[11])/100000.0-0.7) < 0.01 and absf(float(counts[12])/100000.0-0.2) < 0.01 and absf(float(counts[13])/100000.0-0.1) < 0.01, "synthetic distribution follows the weights "+str(counts))

func original_tables() -> void:
	var callers: Array = GACHA.callers()
	evidence["callers"] = callers.size()
	check(callers.size() >= 10, "usable original 비법서 (%d)" % callers.size())
	var classes: Array = [1,2,3,4,5,7,8,34,52,81,94,111,142]
	var problems: Array = []; var fallback: Dictionary = {}
	for id: int in callers:
		var item: Dictionary = GACHA.spec(id)
		var total: int = 0
		for group: Dictionary in SOURCE.related("GachaCraftGroupProbability","GachaCraftID",int(item.gacha_id)): total += int(group.GroupSelectProbability)
		if total != GACHA.SCALE: problems.append("%d group sum %d" % [id,total])
		for class_id: int in classes:
			var drawn: Dictionary = GACHA.table(int(item.gacha_id),class_id)
			if not drawn.get("ok",false): problems.append("%d class %d: %s" % [id,class_id,str(drawn.get("reason",""))]); continue
			if drawn.notes.get("class_fallback",false): fallback[str(id)] = int(fallback.get(str(id),0))+1
	evidence["class_fallback"] = fallback
	check(problems.is_empty(), "every book has a full original draw table for every class: "+str(problems.slice(0,5)))
	# Distribution of many draws of the first book (knight) vs original group weights.
	var first: Dictionary = GACHA.spec(int(callers[0]))
	var drawn: Dictionary = GACHA.table(int(first.gacha_id),1)
	# Expected: the original group weights over the groups that keep a
	# drawable row for this class (a group of only test rows is left out, 근사).
	var expected: Dictionary = {}; var kept_total: float = 0.0
	for entry: Dictionary in drawn.entries:
		if not expected.has(int(entry.group_id)): expected[int(entry.group_id)] = float(entry.group_weight); kept_total += float(entry.group_weight)
	for group: int in expected: expected[group] = expected[group]/kept_total
	evidence["groups_without_drawable_rows"] = SOURCE.related("GachaCraftGroupProbability","GachaCraftID",int(first.gacha_id)).size()-expected.size()
	var seen: Dictionary = {}
	var rng := RandomNumberGenerator.new(); rng.seed = 20261116
	var draws: int = 200000
	for i: int in draws:
		var roll: int = (((rng.randi() & 0x3FFFFFFF) << 32) | rng.randi()) % int(drawn.total)
		var picked: Dictionary = GACHA.pick(drawn,roll,rng.randi_range(0,GACHA.SCALE-1))
		seen[int(picked.group_id)] = int(seen.get(int(picked.group_id),0))+1
	var report: Dictionary = {}; var ok: bool = true
	for group: int in expected:
		var observed: float = float(seen.get(group,0))/float(draws)
		var sigma: float = sqrt(maxf(expected[group]*(1.0-expected[group])/float(draws),1e-12))
		report[str(group)] = [expected[group],observed]
		if absf(observed-expected[group]) > 5.0*sigma + 0.0005: ok = false
	evidence["distribution"] = {"book":int(callers[0]),"draws":draws,"groups":report}
	check(ok, "group distribution over %d draws matches the original weights %s" % [draws,str(report)])

func owned_total(world: Node, id: int) -> int:
	return int(GACHA.stacks_of(world,id).total)

func actual_main() -> void:
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world); world.set_process(false); world.save_timer = -100000
	check(QA.enter_game(world), "actual Main map entry")
	for frame: int in 10: await process_frame
	# A book whose material is a physical stack and one paid in 아데나.
	var samples: Array = []
	for id: int in GACHA.callers():
		var item: Dictionary = GACHA.spec(id)
		if (int(item.material_id) == 26 and samples.filter(func(s: int) -> bool: return int(GACHA.spec(s).material_id) == 26).is_empty()) or (int(item.material_id) != 26 and SUPPLY.coin_wallet(int(item.material_id)).is_empty() and samples.filter(func(s: int) -> bool: return int(GACHA.spec(s).material_id) != 26).is_empty()):
			samples.append(id)
	evidence["main_samples"] = samples
	check(samples.size() == 2, "a stack-material book and an 아데나-material book exist")
	var runs: Array = []
	for id: int in samples:
		var item: Dictionary = GACHA.spec(id)
		var grants: Array = [{"item_class_id":id,"amount":6,"bless_raw":1,"enchant":0}]
		if int(item.material_id) != 26: grants.append({"item_class_id":int(item.material_id),"amount":int(item.material_amount)*6,"bless_raw":1,"enchant":0})
		var given: bool = SUPPLY.commit(world,grants,{"kind":"test_craft523_gacha"})
		if not check(given, "book %d and its material granted through the shared supplier" % id): continue
		world.gold = 100000000
		var quote: Dictionary = world.patch523_gacha_craft_quote(id)
		check(quote.get("ok",false), "quote %d: %s" % [id,str(quote.get("reason",""))])
		var owned: Array = world.patch523_gacha_craft_owned()
		check(owned.any(func(e: Dictionary) -> bool: return int(e.item_class_id) == id), "owned book listed for the window")
		var books_before: int = owned_total(world,id)
		var material_before: int = owned_total(world,int(item.material_id))
		var gold_before: int = int(world.gold)
		var results: Array = []
		for attempt: int in 5:
			var result: Dictionary = world.patch523_gacha_craft_execute(id)
			if not check(result.get("ok",false), "execute %d #%d: %s" % [id,attempt,str(result.get("reason",""))]): break
			results.append(result.output)
		check(owned_total(world,id) == books_before-results.size(), "one book consumed per craft")
		if int(item.material_id) != 26: check(owned_total(world,int(item.material_id)) == material_before-int(item.material_amount)*results.size(), "material consumed per craft")
		var per: int = int(item.cost) + (int(item.material_amount) if int(item.material_id) == 26 else 0)
		check(int(world.gold) == gold_before-per*results.size(), "아데나 consumed per craft (%d each)" % per)
		# The drawn items are owned (stack or physical) with their amount.
		for output: Dictionary in results:
			var found: int = owned_total(world,int(output.item_class_id))
			var physical: int = 0
			for entry: Variant in world.item_instances.values():
				if entry is Dictionary and entry.get("record",{}).get("source_item_class_id") == int(output.item_class_id) and not entry.has(STACK.RECEIPT): physical += 1
			var wallet: String = SUPPLY.coin_wallet(int(output.item_class_id))
			check(found >= int(output.amount) or physical >= int(output.amount) or (not wallet.is_empty() and int(world.inventory.get(wallet,0)) >= int(output.amount)) or int(output.item_class_id) == 26, "drawn %s ×%d is owned" % [str(output.name),int(output.amount)])
		# Save and reload keep the result.
		world._save_game(true)
		var inventory_before: Dictionary = {"__gold":int(world.gold)}; var instances_before: int = world.item_instances.size()
		world.inventory = {}; world.item_instances = {}
		world._load_game(true)
		check(int(world.gold) == int(inventory_before.get("__gold",world.gold)) and world.item_instances.size() == instances_before and owned_total(world,id) == books_before-results.size(), "%d: reload keeps book count and drawn items" % id)
		runs.append({"book":id,"name":item.name,"crafted":results.map(func(o: Dictionary) -> String: return "%s ×%d%s" % [o.name,int(o.amount)," 귀속" if o.bound else ""])})
	# Forced draw: an entry with ItemAmount > 1 gives that amount.
	var big: Dictionary = {}
	for id: int in GACHA.callers():
		var drawn: Dictionary = GACHA.table(int(GACHA.spec(id).gacha_id),GACHA.class_of(world))
		var threshold: int = 0
		for entry: Dictionary in drawn.entries:
			if int(entry.row.ItemAmount) > 1 and big.is_empty(): big = {"book":id,"roll":threshold,"amount":int(entry.row.ItemAmount),"item":int(entry.row.ItemClassID)}
			threshold += int(entry.weight)
	if check(not big.is_empty(), "an original row with ItemAmount > 1"):
		SUPPLY.commit(world,[{"item_class_id":int(big.book),"amount":1,"bless_raw":1,"enchant":0}] + ([] if int(GACHA.spec(int(big.book)).material_id) == 26 else [{"item_class_id":int(GACHA.spec(int(big.book)).material_id),"amount":int(GACHA.spec(int(big.book)).material_amount),"bless_raw":1,"enchant":0}]),{"kind":"test_craft523_gacha"})
		var forced: Dictionary = GACHA.execute(world,int(big.book),int(big.roll),GACHA.SCALE-1)
		check(forced.get("ok",false) and int(forced.output.amount) == int(big.amount) and int(forced.output.item_class_id) == int(big.item), "forced draw grants ItemAmount %d: %s" % [int(big.amount),str(forced.get("reason",forced.get("output","")))])
		evidence["forced_amount"] = forced.get("output",{})
	evidence["main_runs"] = runs
	world.queue_free()
	await process_frame

func run() -> void:
	synthetic()
	if not SOURCE.not_installed():
		original_tables()
		await actual_main()
	print("CRAFT523_GACHA_RESULT " + JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence}))
	quit(0 if failures.is_empty() and checks >= 4 else 1)
