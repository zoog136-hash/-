extends SceneTree
const CRAFT = preload("res://scripts/crafting/local_crafting.gd")
const LOOT = preload("res://scripts/loot_drop.gd")
const MONSTERS = preload("res://scripts/monsters/monster_catalog.gd")
const GRADES: Array[String] = ["희귀","영웅","전설","신화","유일"]
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		printerr("CRAFT_SCROLL_FAIL: "+label)

func _run() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	_check(source is Dictionary,"item DB parses")
	if not (source is Dictionary):
		quit(1)
		return
	var db: Dictionary = source as Dictionary
	var items: Dictionary = {}
	for raw: Variant in db.get("아이템",[]):
		var item: Dictionary = raw as Dictionary
		items[str(item.get("name",""))] = item
	var service := CRAFT.new()
	service.load_recipes()
	_check(service.recipes.size() == 413,"413 original and new crafting recipes")
	var catalog: Dictionary = LOOT.build_catalog(db.get("아이템",[]))
	var pools: Dictionary = catalog.get("equipment_by_grade",{})
	var source_rows: Dictionary = catalog.get("crafting_drops",{})
	for grade: String in GRADES:
		var scroll: String = grade+" 제작 비법서"
		var item: Dictionary = items.get(scroll,{})
		_check(not item.is_empty() and bool(item.get("crafting_scroll",false)),"known crafting scroll "+grade)
		_check(str(item.get("grade","")) == grade and str(item.get("slot","")) == "consumable","matching grade and non-wearable slot "+grade)
		_check(not CRAFT._is_equipment(item) and LOOT._is_equipment(item) and not LOOT._is_potion(item),"stackable scroll shares only equipment drop chance "+grade)
		_check((pools.get(grade,[]) as Array).has(scroll),"scroll exists in equipment rarity pool "+grade)
		var source_count: int = 0
		for row: Variant in source_rows.values():
			if (row.get("equipment_ingredients",[]) as Array).has(scroll):
				source_count += 1
		_check(source_count >= 4,"scroll has four or more monster sources "+grade)

	var covered: Dictionary = {}
	for id: String in service.recipes:
		var recipe: Dictionary = service.recipes[id]
		var name: String = str((recipe.get("result",{}) as Dictionary).get("item",""))
		var item: Dictionary = items.get(name,{})
		if item.is_empty() or CRAFT._is_equipment(item) == false or not str(item.get("grade","")) in GRADES:
			continue
		var grade: String = str(item["grade"])
		var scroll_name: String = grade+" 제작 비법서"
		_check(str(recipe.get("required_scroll_grade","")) == grade,"declared grade gate "+id)
		var scroll_count: int = 0
		for raw: Variant in recipe.get("materials",[]):
			if str((raw as Dictionary).get("item","")) == scroll_name:
				scroll_count += int((raw as Dictionary).get("quantity",0))
		_check(scroll_count == 1,"requires exactly one scroll per craft "+id)
		covered[name] = true
	var covered_count: int = 0
	for raw: Variant in db.get("아이템",[]):
		var item: Dictionary = raw as Dictionary
		if CRAFT._is_equipment(item) and str(item.get("grade","")) in GRADES:
			covered_count += 1
			_check(covered.has(str(item["name"])),"all rare-plus equipment outputs craftable "+str(item["name"]))
	_check(covered.size() == covered_count and covered_count == 355,"all 355 rare+ equipment outputs covered")

	# Each registered scroll drop consumes an equipment-grade slot, not a
	# second material or potion roll. Source rows are exact grade fallbacks.
	var monsters: Array = MONSTERS.expand(db.get("몬스터",[]))
	for grade: String in GRADES:
		var scroll_name: String = grade+" 제작 비법서"
		var verified: bool = false
		for raw: Variant in monsters:
			var monster: Dictionary = raw as Dictionary
			var name: String = str(monster.get("name",""))
			var row: Dictionary = source_rows.get(name,{})
			if not (row.get("equipment_ingredients",[]) as Array).has(scroll_name):
				continue
			var drops: Array[String] = []
			for value: Variant in monster.get("drop",[]):
				drops.append(str(value))
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261010
			if LOOT._pick_equipment(grade,drops,catalog,rng,name) == scroll_name:
				verified = true
				break
		_check(verified,"real monster pool can yield scroll "+grade)

	var mithril: Dictionary = service.recipes["blade_mithril"]
	var bag: Dictionary = {}
	var physical: Dictionary = {}
	var counter: int = 500
	for raw: Variant in mithril.get("materials",[]):
		var row: Dictionary = raw as Dictionary
		var name: String = str(row["item"])
		var required: int = int(row["quantity"])
		bag[name] = required
		if CRAFT._is_equipment(items[name] as Dictionary):
			for _index: int in range(required):
				physical[str(counter)] = {"name":name,"level":0,"element":"","element_level":0}
				counter += 1
	var scroll_item_name: String = "희귀 제작 비법서"
	bag.erase(scroll_item_name)
	var rejected: Dictionary = service.execute("blade_mithril",1,bag,1000000,items,physical,{},1000,100000,600)
	_check(not bool(rejected.get("ok",false)) and not bag.has("미스릴 한손검"),"missing scroll cannot craft or mutate items")
	bag[scroll_item_name] = 1
	var completed: Dictionary = service.execute("blade_mithril",1,bag,1000000,items,physical,{},1001,100000,600)
	_check(bool(completed.get("ok",false)),"matching scroll + ingredients can craft rare equipment")
	_check(int(bag.get(scroll_item_name,0)) == 0 and int(bag.get("미스릴 한손검",0)) == 1,"scroll consumed and result delivered exactly once")
	_check(physical.size() == 1 and physical.has("600") and str((physical["600"] as Dictionary).get("name","")) == "미스릴 한손검","scroll does not create an equipped ID; only result does")

	var tamper: Dictionary = (service.recipes["blade_mithril"] as Dictionary).duplicate(true)
	tamper["required_scroll_grade"] = "영웅"
	service.recipes["blade_mithril"] = tamper
	bag[scroll_item_name] = 1
	var denied: Dictionary = service.quote("blade_mithril",1,bag,1000000,items,physical,{},1000,100000)
	_check(not bool(denied.get("ok",false)),"wrong grade gate invalid even when materials exist")
	if failures.is_empty():
		print("CRAFT_SCROLL_OK: five nonwearable scrolls, same-rarity gear drops, 355 rare-plus equipment recipes, atomic consumption")
		quit(0)
	else:
		print("CRAFT_SCROLL_FAILED: %d" % failures.size())
		quit(1)
