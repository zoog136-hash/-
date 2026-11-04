extends SceneTree
const RULES = preload("res://scripts/crafting/patch523_rules.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("PATCH523_EQUIPMENT_FAIL: ", label)

func _initialize() -> void:
	var rules = RULES.new()
	# Explicit synthetic transaction fixture, not a source-game rule or price.
	var old: Dictionary = {"name":"fixture_old", "source":"inven", "sourceId":"101", "slot":"earring", "weight":3}
	var fresh: Dictionary = {"name":"fixture_new", "source":"inven", "sourceId":"102", "slot":"earring", "weight":3}
	var material: Dictionary = {"item":"fixture_old", "quantity":1, "source_id":"101", "level":8, "bless_code":2, "physical":true}
	rules.data = {"items":{"101":{"catalog_record":old},"102":{"catalog_record":fresh}}}
	rules.recipes = {"patch523:17":{"id":"patch523:17", "adena":5, "popup_text_id":0, "materials":[material],
		"result":{"item":"fixture_new", "quantity":1, "source_id":"102", "level":7, "bless_code":1, "physical":true}}}
	var physical: Dictionary = {"7":{"name":"fixture_old", "record":old, "sourceId":"101", "level":8, "bless_state":"blessed", "element":"", "element_level":0}}
	var inventory: Dictionary = {"fixture_old":1}
	var items: Dictionary = {"fixture_old":old, "fixture_new":fresh}
	var before: String = JSON.stringify([inventory, physical])
	var staged: Dictionary = rules.execute("patch523:17",1,inventory,100,items,physical,{},3,100,8)
	check(bool(staged.get("ok",false)),"explicit source +8 Blessed -> +7 Normal transaction accepted")
	check(JSON.stringify([inventory, physical]) == before,"service does not mutate live state before durable save")
	if bool(staged.get("ok",false)):
		check(not staged.item_instances.has("7") and staged.item_instances.has("8"),"new physical ID, input consumed only in staged state")
		check(int(staged.item_instances["8"].level)==7 and RULES.bless_code(staged.item_instances["8"])==1,"output uses declared level and bless, not input state")
		check(int(staged.gold_after)==95 and int(staged.next_instance_id)==9,"exact wallet and monotonic counter")
	for changed: Dictionary in [{"level":7}, {"bless_state":"normal"}, {"sourceId":"999"}, {"record":{"source":"local","sourceId":"101"}}, {"element":"fire"}, {"custom_option":1}, {"source_smelt":{"unknown":1}}, {"record":{"name":"fixture_old","source":"inven","sourceId":"101","slot":"earring","custom":1}}, {"record":{"name":"fixture_old","source":"inven","sourceId":"101","slot":"earring","atk":999}}]:
		var invalid: Dictionary = physical.duplicate(true)
		invalid["7"].merge(changed,true)
		var rejected: Dictionary = rules.execute("patch523:17",1,inventory,100,items,invalid,{},3,100,8)
		check(not bool(rejected.get("ok",false)),"reject inexact/unknown physical state "+str(changed))
	for locks: Dictionary in [{"fixture_old":true}, {"fixture_old@@@7":true}]:
		check(not bool(rules.quote("patch523:17",1,inventory,100,items,physical,{},3,100,locks).get("ok",false)),"locked source materials protected")
	check(not bool(rules.quote("patch523:17",1,inventory,100,items,physical,{"earring":{"instance_id":"7"}},3,100).get("ok",false)),"worn source material protected")
	check(not bool(rules.quote("patch523:17",1,inventory,4,items,physical,{},3,100).get("ok",false)),"insufficient wallet rejected")
	check(not bool(rules.quote("patch523:17",1,inventory,100,items,physical,{},3,2).get("ok",false)),"overweight output rejected")
	for count: int in [0,21]:
		check(not bool(rules.quote("patch523:17",count,inventory,100,items,physical,{},3,100).get("ok",false)),"invalid batch rejected")
	check(rules.available_material(material,inventory,items,physical,{}, {},false)==1,"UI count agrees for exact source state")
	check(rules.available_material(material,inventory,items,physical,{}, {"fixture_old@@@7":true},false)==0,"UI excludes locked physical ID")
	var indexed: Dictionary = physical.duplicate(true)
	indexed["7"].record["originalSourceOptions"] = []
	check(bool(rules.quote("patch523:17",1,inventory,100,items,indexed,{},3,100).get("ok",false)),"Main's immutable original-option metadata remains eligible")
	var old_data: Dictionary = rules.data.duplicate(true)
	check(not rules.load_file("user://not-present-equipment.json", "0".repeat(64)) and rules.data==old_data,"missing replacement retains active registry")
	var pack: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES")
	if not pack.is_empty():
		var expected: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
		check(rules.load_file(pack, expected),"actual Library-materialized 523 rules load")
		check(rules.recipes.size()==159,"159 conservative source recipes mapped into current catalog")
		check(not rules.load_file(pack, "0".repeat(64)) and rules.recipes.size()==159,"wrong SHA replacement retains real registry")
		var chain: Dictionary = rules.recipe_evidence(258618)
		check(chain.inputs.size()==8 and chain.outputs.size()==1,"all elemental earring candidates preserved")
		check(not rules.recipes.has("patch523:258618"),"candidate-slot selection is not silently inferred")
		check(not rules.recipes.has("patch523:261764"),"viewless limited seal recipe not exposed as guaranteed upgrade")
		check(rules.recipes.has("patch523:77552") and int(rules.recipes["patch523:77552"].result.bless_code)==2,"same-level seal blessing conversion linked")
		var effects: int = 0
		for item_id: int in [30671,130551]:
			for level_value: int in range(9):
				for blessing: int in [0,2]:
					effects += rules.effect_evidence(item_id,level_value,blessing).size()
		check(effects==161,"161 exact-level/bless seal effects accessible without cumulative summing")
		var normal: Dictionary = rules.enhancement_evidence(30671,320802,0,1,1)
		check(normal.groups==[81] and normal.probabilities.size()==1 and int(normal.probabilities[0].Success)==620000,"ordinary seal probability path and raw0 kept")
		var protection: Dictionary = rules.enhancement_evidence(30671,166044,4,1,1)
		check(protection.groups==[781] and not protection.probabilities.is_empty() and not protection.costs.is_empty() and int(protection.probabilities[0].Success)==150000 and int(protection.costs[0].ConsumeAmount)==3,"protected seal exact Normal branch and quantity")
		var blessed: Dictionary = rules.enhancement_evidence(30671,166044,4,2,1)
		check(not blessed.probabilities.is_empty() and int(blessed.probabilities[0].Success)==75000,"protected seal Blessed branch remains distinct")
		check(rules.effect_evidence(130551,0,2).is_empty(),"no invented Blessed recovery seal +0 effects")
		var seal: Dictionary = rules.supported_seal_options("30671",2)
		check(int(seal["8"].melee_accuracy)==12 and int(seal["8"].melee_damage)==7,"exact Blessed guard +8 uses its own row minus catalog base")
		var recovery: Dictionary = rules.supported_seal_options("130551",2)
		check(not recovery.has("0") and int(recovery["8"].potion_heal_pct)==18 and int(recovery["8"].potion_heal_flat)==18 and int(recovery["8"].reduction)==7,"exact recovery +8 adapters preserve ratio, flat and reduction")
		check(rules.supported_seal_options("30671",1).is_empty(),"unresolved raw0 matching never changes Normal1 stats")
	print("PATCH523_EQUIPMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_source":not pack.is_empty()}))
	quit(0 if failures.is_empty() else 1)
