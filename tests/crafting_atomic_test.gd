extends SceneTree
const CRAFTING = preload("res://scripts/crafting/local_crafting.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		printerr("CRAFTING_FAIL: "+label)

func _run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_db_v17.json"))
	_check(data is Dictionary,"TWILIGHT item DB parses")
	if not (data is Dictionary):
		quit(1)
		return
	var items: Dictionary = {}
	for raw: Variant in (data as Dictionary).get("아이템",[]):
		if raw is Dictionary:
			items[str((raw as Dictionary).get("name",""))] = raw
	var service = CRAFTING.new()
	service.load_recipes()
	_check(service.recipes.size() == 5,"five actual DB-backed recipes loaded")
	for id: String in service.recipes:
		var recipe: Dictionary = service.recipes[id]
		_check(items.has(str((recipe["result"] as Dictionary).get("item",""))), "known output item for " + id)
		for raw: Variant in recipe.get("materials",[]):
			_check(items.has(str((raw as Dictionary).get("item",""))), "known material item for "+id)
	var inv: Dictionary = {"HP 물약":3}
	var physical: Dictionary = {}
	var equipped: Dictionary = {}
	var denied: Dictionary = service.execute("healing_plus",1,inv,79,items,physical,equipped,9,200,10)
	_check(not bool(denied.get("ok")) and inv["HP 물약"] == 3, "insufficient Adena cannot consume materials")
	denied = service.execute("healing_plus",1,inv,1000,items,physical,equipped,9,3,10)
	_check(not bool(denied.get("ok")) and inv["HP 물약"] == 3, "result overweight cannot consume materials")
	var crafted: Dictionary = service.execute("healing_plus",1,inv,1000,items,physical,equipped,9,200,10)
	_check(bool(crafted.get("ok")), "valid potion crafting works")
	_check(int(crafted.get("gold_after",-1)) == 920, "authoritative Adena price")
	_check(int(inv.get("HP 물약",0)) == 0 and int(inv.get("강력 HP 물약",0)) == 1, "materials deducted and result produced")
	_check(physical.is_empty(), "potion result never creates equipment IDs")
	denied = service.execute("fake_recipe",1,inv,10000,items,physical,equipped,4,200,10)
	_check(not bool(denied.get("ok")), "forged recipe ID rejected")
	denied = service.execute("healing_plus",0,inv,10000,items,physical,equipped,4,200,10)
	_check(not bool(denied.get("ok")), "zero count rejected")
	denied = service.execute("healing_plus",21,inv,10000,items,physical,equipped,4,200,10)
	_check(not bool(denied.get("ok")), "excess batch count rejected")

	var swords: Dictionary = {"청동 한손검":3,"HP 물약":8}
	var instances: Dictionary = {
		"21":{"name":"청동 한손검","level":4,"element":"","element_level":0},
		"22":{"name":"청동 한손검","level":0,"element":"","element_level":0},
		"23":{"name":"청동 한손검","level":0,"element":"","element_level":0}
	}
	var wearing: Dictionary = {"weapon":{"name":"청동 한손검","instance_id":"21"}}
	var price: Dictionary = service.quote("blade_steel",1,swords,2000,items,instances,wearing,174,250)
	_check(bool(price.get("ok")), "two pristine spare swords support recipe")
	var result: Dictionary = service.execute("blade_steel",1,swords,2000,items,instances,wearing,174,250,24)
	_check(bool(result.get("ok")), "steel sword crafting from actual equipment works")
	_check(swords.get("청동 한손검",0) == 1 and swords.get("HP 물약",0) == 4 and swords.get("강철 한손검",0) == 1, "material counts exactly reduced")
	_check(instances.has("21") and not instances.has("22") and not instances.has("23") and instances.has("24"), "keep equipped+enchanted ID, consume pristine IDs, create unique ID")
	_check(int(instances["21"]["level"]) == 4 and int(instances["24"]["level"]) == 0, "enchanted state kept and crafted gear begins at +0")
	_check(int(result["gold_after"]) == 1150 and int(result["next_instance_id"]) == 25, "pricing and monotonic physical ID counter")
	var save_blob: String = JSON.stringify({"inventory":swords, "item_instances":instances, "next_item_instance_id":result["next_instance_id"]})
	var loaded: Variant = JSON.parse_string(save_blob)
	_check(loaded is Dictionary and int((loaded as Dictionary).get("next_item_instance_id",0)) == 25, "JSON save shape preserved")
	if loaded is Dictionary:
		_check(int(((loaded as Dictionary)["item_instances"] as Dictionary)["21"]["level"]) == 4, "save/load preserves enhanced equipped item")

	var protected: Dictionary = {"청동 한손검":2,"HP 물약":4}
	var protected_ids: Dictionary = {
		"41":{"name":"청동 한손검","level":8,"element":"fire","element_level":4},
		"42":{"name":"청동 한손검","level":0,"element":"","element_level":0}
	}
	var rejected: Dictionary = service.execute("blade_steel",1,protected,5000,items,protected_ids,{},100,250,43)
	_check(not bool(rejected.get("ok")), "enhanced/elemental equipment never consumed as recipe material")
	_check(protected["청동 한손검"] == 2 and protected_ids.size() == 2, "failed craft stays atomic")
	var map_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))
	var found: bool = false
	if map_data is Dictionary:
		for raw: Variant in (map_data as Dictionary).get("npc_spawn",[]):
			if raw is Dictionary and str((raw as Dictionary).get("id","")) == "craft_master":
				found = str((raw as Dictionary).get("role","")) == "craft"
	_check(found, "real craft master connected in Aden NPC data")
	if failures.is_empty():
		print("CRAFTING_OK: five catalog recipes, authoritative costs, weight, enchant safety, atomic inventory and save")
		quit(0)
	else:
		print("CRAFTING_FAILED: %d" % failures.size())
		quit(1)
