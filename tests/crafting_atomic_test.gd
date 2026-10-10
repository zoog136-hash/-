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
	_check(service.recipes.size() == 413,"413 DB-backed crafting recipes loaded")
	for id: String in service.recipes:
		var recipe: Dictionary = service.recipes[id]
		_check(items.has(str((recipe["result"] as Dictionary).get("item",""))), "known output item for " + id)
		for raw: Variant in recipe.get("materials",[]):
			_check(items.has(str((raw as Dictionary).get("item",""))), "known material item for "+id)
	var resource_names: Array[String] = ["철 광석","동 광석","미스릴 원석","가죽 조각","정제된 목재","천 조각","마력 결정","연마석","약초","정령의 가루"]
	for name: String in resource_names:
		_check(items.has(name) and bool((items[name] as Dictionary).get("crafting_material",false)), "registered stackable material "+name)
		_check(str((items[name] as Dictionary).get("slot","")) == "consumable" and int((items[name] as Dictionary).get("heal",0)) == 0, "material not equipment or healing potion "+name)
	var resource_recipes: int = 0
	for id: String in service.recipes:
		var recipe: Dictionary = service.recipes[id]
		if (recipe.get("materials",[]) as Array).any(func(raw: Variant) -> bool: return str((raw as Dictionary).get("item","")) in resource_names):
			resource_recipes += 1
	_check(resource_recipes == 413, "all 413 recipes require obtainable harvested resources")
	var category_counts: Dictionary = {}
	for id: String in service.recipes:
		var record: Dictionary = service.recipes[id]
		var category: String = str(record.get("category",""))
		category_counts[category] = int(category_counts.get(category,0)) + 1
		var item_name: String = str((record.get("result",{}) as Dictionary).get("item",""))
		_check(str((items[item_name] as Dictionary).get("grade","")) in ["일반","고급","희귀","영웅","전설","신화","유일"], "known crafting grade: "+id)
	_check(int(category_counts.get("무기",0)) >= 55 and int(category_counts.get("방어구",0)) == 16, "weapons and armor expanded")
	var inv: Dictionary = {"HP 물약":3,"약초":2}
	var physical: Dictionary = {}
	var equipped: Dictionary = {}
	var denied: Dictionary = service.execute("healing_plus",1,inv,79,items,physical,equipped,11,200,10)
	_check(not bool(denied.get("ok")) and inv["HP 물약"] == 3 and inv["약초"] == 2, "insufficient Adena cannot consume materials")
	denied = service.execute("healing_plus",1,inv,1000,items,physical,equipped,11,3,10)
	_check(not bool(denied.get("ok")) and inv["HP 물약"] == 3 and inv["약초"] == 2, "result overweight cannot consume materials")
	var crafted: Dictionary = service.execute("healing_plus",1,inv,1000,items,physical,equipped,11,200,10)
	_check(bool(crafted.get("ok")), "valid potion crafting works")
	_check(int(crafted.get("gold_after",-1)) == 920, "authoritative Adena price")
	_check(int(inv.get("HP 물약",0)) == 0 and int(inv.get("약초",0)) == 0 and int(inv.get("강력 HP 물약",0)) == 1, "materials deducted and result produced")
	_check(physical.is_empty(), "potion result never creates equipment IDs")
	denied = service.execute("fake_recipe",1,inv,10000,items,physical,equipped,4,200,10)
	_check(not bool(denied.get("ok")), "forged recipe ID rejected")
	denied = service.execute("healing_plus",0,inv,10000,items,physical,equipped,4,200,10)
	_check(not bool(denied.get("ok")), "zero count rejected")
	denied = service.execute("healing_plus",21,inv,10000,items,physical,equipped,4,200,10)
	_check(not bool(denied.get("ok")), "excess batch count rejected")

	var swords: Dictionary = {"청동 한손검":3,"HP 물약":8,"철 광석":8,"연마석":1}
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
	_check(swords.get("청동 한손검",0) == 1 and swords.get("HP 물약",0) == 4 and swords.get("철 광석",0) == 0 and swords.get("연마석",0) == 0 and swords.get("강철 한손검",0) == 1, "material counts exactly reduced")
	_check(instances.has("21") and not instances.has("22") and not instances.has("23") and instances.has("24"), "keep equipped+enchanted ID, consume pristine IDs, create unique ID")
	_check(int(instances["21"]["level"]) == 4 and int(instances["24"]["level"]) == 0, "enchanted state kept and crafted gear begins at +0")
	_check(int(result["gold_after"]) == 1150 and int(result["next_instance_id"]) == 25, "pricing and monotonic physical ID counter")
	var save_blob: String = JSON.stringify({"inventory":swords, "item_instances":instances, "next_item_instance_id":result["next_instance_id"]})
	var loaded: Variant = JSON.parse_string(save_blob)
	_check(loaded is Dictionary and int((loaded as Dictionary).get("next_item_instance_id",0)) == 25, "JSON save shape preserved")
	if loaded is Dictionary:
		_check(int(((loaded as Dictionary)["item_instances"] as Dictionary)["21"]["level"]) == 4, "save/load preserves enhanced equipped item")

	var protected: Dictionary = {"청동 한손검":2,"HP 물약":4,"철 광석":8,"연마석":1}
	var protected_ids: Dictionary = {
		"41":{"name":"청동 한손검","level":8,"element":"fire","element_level":4},
		"42":{"name":"청동 한손검","level":0,"element":"","element_level":0}
	}
	var rejected: Dictionary = service.execute("blade_steel",1,protected,5000,items,protected_ids,{},100,250,43)
	_check(not bool(rejected.get("ok")), "enhanced/elemental equipment never consumed as recipe material")
	_check(protected["청동 한손검"] == 2 and protected_ids.size() == 2, "failed craft stays atomic")
	# Expanded recipe checks: equipment instance accounting, batches and wallet.
	var bow_inv: Dictionary = {"훈련용 활":4,"정제된 목재":8,"동 광석":6}
	var bow_instances: Dictionary = {
		"100":{"name":"훈련용 활","level":0,"element":"","element_level":0},
		"101":{"name":"훈련용 활","level":0,"element":"","element_level":0},
		"102":{"name":"훈련용 활","level":0,"element":"","element_level":0},
		"103":{"name":"훈련용 활","level":0,"element":"","element_level":0}
	}
	var bows: Dictionary = service.execute("local_weapon_03_01",2,bow_inv,1000,items,bow_instances,{},160,500,104)
	_check(bool(bows.get("ok")), "new local bow recipe supports batch 2")
	_check(int(bows.get("cost",-1)) == 600 and int(bows.get("gold_after",-1)) == 400, "batch cost is exact")
	_check(int(bow_inv.get("훈련용 활",0)) == 0 and int(bow_inv.get("청동 활",0)) == 2 and int(bow_inv.get("정제된 목재",0)) == 0 and int(bow_inv.get("동 광석",0)) == 0, "batch consumes all four inputs, creates two results")
	_check(bow_instances.size() == 2 and bow_instances.has("104") and bow_instances.has("105"), "batch assigns unique physical IDs")
	var armor_inv: Dictionary = {"가죽의 방패":2,"정제된 목재":6,"철 광석":6}
	var armor_instances: Dictionary = {
		"200":{"name":"가죽의 방패","level":0,"element":"","element_level":0},
		"201":{"name":"가죽의 방패","level":0,"element":"","element_level":0}
	}
	var armor: Dictionary = service.execute("local_armor_07_01",1,armor_inv,10000,items,armor_instances,{},60,300,202)
	_check(bool(armor.get("ok")), "new shield crafting uses real game equipment")
	_check(armor_instances.size() == 1 and armor_instances.has("202") and int(armor_inv.get("강철의 방패",0)) == 1, "crafted armor creates exactly one new physical item")
	var blocked_rare: Dictionary = {"흑철 활":4,"미스릴 원석":8,"정령의 가루":3,"희귀 제작 비법서":1}
	var blocked_instances: Dictionary = {"300":{"name":"흑철 활","level":7,"element":"","element_level":0}}
	var rare_denied: Dictionary = service.execute("local_weapon_03_04",1,blocked_rare,500000,items,blocked_instances,{},160,500,301)
	_check(not bool(rare_denied.get("ok")) and blocked_instances.size() == 1 and blocked_rare.get("흑철 활",0) == 4 and blocked_rare.get("미스릴 원석",0) == 8, "rare-grade crafting cannot bypass missing pristine copies")
	var map_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/aden_field.json"))
	var found: bool = false
	if map_data is Dictionary:
		for raw: Variant in (map_data as Dictionary).get("npc_spawn",[]):
			if raw is Dictionary and str((raw as Dictionary).get("id","")) == "craft_master":
				found = str((raw as Dictionary).get("role","")) == "craft"
	_check(found, "real craft master connected in Aden NPC data")
	if failures.is_empty():
		print("CRAFTING_OK: 413 DB-backed recipes, batches, weight, enchant safety, atomic inventory and save")
		quit(0)
	else:
		print("CRAFTING_FAILED: %d" % failures.size())
		quit(1)
