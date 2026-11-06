extends SceneTree
const RULES = preload("res://scripts/crafting/patch523_rules.gd")
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("PATCH523_EQUIPMENT_FAIL: ", label)

func fixture_class(id: int) -> Dictionary:
	return {"ID":id,"TestItem":false}

func fixture_inputs(craft: int, rows: Array) -> Array:
	var result: Array = [{"ID":craft*100+1,"ItemCraftID":craft,"SlotIndex":0,"ItemClassID":26,"Amount":5,"Enchant":0,"ItemBlessCodeID":1}]
	for row: Array in rows:
		result.append({"ID":row[0],"ItemCraftID":craft,"SlotIndex":row[1],"ItemClassID":row[2],"Amount":row[3],"Enchant":row[4],"ItemBlessCodeID":row[5]})
	return result

func fixture_output(craft: int) -> Dictionary:
	return {"ItemCraftID":craft,"ItemCraftOutputTypeID":1,"ItemClassID":102,"Amount":1,"Enchant":7,"ItemBlessCodeID":1,"Probability":1000000}

func fixture_view(craft: int) -> Dictionary:
	return {"ItemCraftID":craft,"ItemClassID":102,"Amount":1,"Enchant":7,"ItemBlessCodeID":1,"ServerLimitSetID":0,"IsCoalitionItem":false,"NoRepeat":false,"IsBelowLevelLimit":false,"LevelLimitValue":0,"CraftTimeTypeID":1,"EffectiveFrom":1,"EffectiveTo":3,"PopupText":0,"AlwaysSuccess":1}

func _initialize() -> void:
	var rules = RULES.new()
	# Explicit synthetic transaction fixture, not a source-game rule or price.
	var old: Dictionary = {"name":"fixture_old", "source":"inven", "sourceId":"101", "slot":"earring", "weight":3}
	var fresh: Dictionary = {"name":"fixture_new", "source":"inven", "sourceId":"102", "slot":"earring", "weight":3}
	var material: Dictionary = {"item":"fixture_old", "quantity":1, "source_id":"101", "level":8, "bless_code":2, "physical":true, "row_id":10, "slot_index":1}
	# Synthetic cached source join rows (ItemCraftInput/OutputView/View/
	# Restriction) so the recipe contract is exercised without the private pack.
	rules.data = {"items":{"26":{"item_class":fixture_class(26)},"101":{"catalog_record":old,"item_class":fixture_class(101)},"102":{"catalog_record":fresh,"item_class":fixture_class(102)}},
		"raw_recipes":{"inputs":{"17":fixture_inputs(17,[[10,1,101,1,8,2]]),"18":fixture_inputs(18,[[10,1,101,1,8,2],[20,1,101,1,7,1]])},
			"outputs":{"17":[fixture_output(17)],"18":[fixture_output(18)]},"views":{"17":[fixture_view(17)],"18":[fixture_view(18)]},"restrictions":{"17":[],"18":[]}}}
	rules.recipes = {"patch523:17":{"id":"patch523:17", "source_craft_id":17, "adena":5, "popup_text_id":0, "materials":[material],
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
	var alternative: Dictionary = material.duplicate(true)
	alternative["row_id"] = 10
	var second: Dictionary = alternative.duplicate(true)
	second["row_id"] = 20
	second["level"] = 7
	second["bless_code"] = 1
	rules.recipes["patch523:18"] = rules.recipes["patch523:17"].duplicate(true)
	rules.recipes["patch523:18"]["id"] = "patch523:18"
	rules.recipes["patch523:18"]["source_craft_id"] = 18
	rules.recipes["patch523:18"]["material_slots"] = [{"slot_index":1,"candidates":[alternative,second]}]
	check(not bool(rules.quote("patch523:18",1,inventory,100,items,physical,{},3,100).get("ok",false)),"candidate material is never silently selected")
	check(not bool(rules.quote("patch523:18",1,inventory,100,items,physical,{},3,100,{}, {"1":999}).get("ok",false)),"forged candidate row is rejected")
	check(not bool(rules.quote("patch523:18",1,inventory,100,items,physical,{},3,100,{}, {"1":20}).get("ok",false)),"selected candidate still requires its exact physical state")
	check(bool(rules.execute("patch523:18",1,inventory,100,items,physical,{},3,100,8,{}, {"1":10}).get("ok",false)),"explicit valid candidate produces staged transaction")
	var indexed: Dictionary = physical.duplicate(true)
	indexed["7"].record["originalSourceOptions"] = []
	check(bool(rules.quote("patch523:17",1,inventory,100,items,indexed,{},3,100).get("ok",false)),"Main's immutable original-option metadata remains eligible")
	var old_data: Dictionary = rules.data.duplicate(true)
	check(not rules.load_file("user://not-present-equipment.json", "0".repeat(64)) and rules.data==old_data,"missing replacement retains active registry")
	var pack: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_RULES")
	if not pack.is_empty():
		var expected: String = OS.get_environment("TWILIGHT_PATCH523_EQUIPMENT_SHA256")
		check(rules.load_file(pack, expected),"actual Library-materialized 523 rules load")
		check(rules.recipes.size()==347,"347 conservative source recipes mapped into current catalog")
		check(not rules.load_file(pack, "0".repeat(64)) and rules.recipes.size()==347,"wrong SHA replacement retains real registry")
		var chain: Dictionary = rules.recipe_evidence(258618)
		check(chain.inputs.size()==8 and chain.outputs.size()==1,"all elemental earring candidates preserved")
		check(rules.recipes.has("patch523:258618") and not bool(rules.material_selection("patch523:258618").get("ok",false)),"elemental earring candidates require explicit row selection")
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
		check(int(seal["8"].xp_pct)==12 and int(seal["8"].ain_saving_pct)==11 and int(seal["8"].stun_resistance)==8,"guard source XP/saving/targeted stun values remain distinct")
		check(int(recovery["8"].potion_cooldown_pct)==6 and int(recovery["8"].stun_resistance)==8,"recovery source cooldown and targeted stun supported")
		var old_record: Dictionary = rules.record("30671")
		old_record["bless_state"] = "blessed"
		old_record["enhancement_options"] = {"8":{"melee_accuracy":12}}
		old_record["patch523_effect_basis"] = {"selection":"exact_level_only"}
		var old_physical: Dictionary = {"record":old_record,"bless_state":"blessed","level":8}
		check(rules.refresh_derived_options(old_physical) and int(old_physical.record.enhancement_options["8"].xp_pct)==12,"older matching derived cache safely gains newly connected source effects")
		old_physical.record.enhancement_options["8"].melee_accuracy = 999
		check(not rules.refresh_derived_options(old_physical) and int(old_physical.record.enhancement_options["8"].melee_accuracy)==999,"custom derived record is never overwritten by source cache refresh")
		check(rules.craftsman_weapon_rule(rules.record("322")).get("levels",[])==[9],"original Hero craftsman weapon is +9 only")
		check(rules.craftsman_weapon_rule(rules.record("176582")).get("levels",[])==[9,10],"original Legendary craftsman weapon is +9/+10")
		check(rules.craftsman_weapon_rule(rules.record("425")).get("levels",[])==[9,10,11],"original Mythic craftsman weapon is +9/+10/+11")
		check(rules.craftsman_weapon_rule(rules.record("362391")).get("levels",[9]).is_empty(),"Unique weapon does not borrow standard craftsman qualification")
		check(rules.craftsman_weapon_rule({"name":"fixture","source":"local","slot":"weapon","grade":"영웅"}).is_empty(),"unidentified/local custom weapon never inherits official source override")
		var actions = preload("res://scripts/crafting/patch523_seal_actions.gd")
		for source_id: String in ["30671","130551"]:
			for level_value: int in range(8):
				var target: Dictionary = {"name":rules.record(source_id).name,"record":rules.record(source_id),"level":level_value,"bless_state":"normal"}
				var quote: Dictionary = actions.quote(rules,target,"320802",{"빛나는 장비 강화 주문서":100},1000000,false)
				check(bool(quote.get("ok",false)) and int(quote.count)==1,"normal seal exact source/official current-level branch "+source_id+":"+str(level_value))
			for blessing: int in [1,2]:
				for level_value: int in range(4,8):
					var target: Dictionary = {"name":rules.record(source_id).name,"record":rules.record(source_id),"level":level_value,"bless_state":"blessed" if blessing==2 else "normal"}
					var quote: Dictionary = actions.quote(rules,target,"166044",{"빛나는 장비 보호 주문서":100},1000000,false)
					check(bool(quote.get("ok",false)) and quote.protected and int(quote.count)==[3,10,20,50][level_value-4],"protected seal exact state/consumption "+source_id+":"+str(blessing)+":"+str(level_value))
		var target: Dictionary = {"name":rules.record("30671").name,"record":rules.record("30671"),"level":4,"bless_state":"normal"}
		for inventory_case: Dictionary in [{},{"빛나는 장비 보호 주문서":2}]:
			check(not bool(actions.quote(rules,target,"166044",inventory_case,1000000,false).get("ok",false)),"insufficient protected scrolls rejected")
		check(not bool(actions.quote(rules,target,"166044",{"빛나는 장비 보호 주문서":100},10999,false).get("ok",false)),"insufficient native fee rejected")
		check(not bool(actions.quote(rules,target,"166044",{"빛나는 장비 보호 주문서":100},1000000,true).get("ok",false)),"locked native target/scroll rejected")
		var source_box: Dictionary = actions.open_box(rules,"30701",{"수호의 인장 상자":1},{},1,0,1000,{"수호의 인장 상자":rules.record("30701")},false)
		check(bool(source_box.get("ok",false)) and int(source_box.inventory["빛나는 장비 강화 주문서"])==8 and source_box.item_instances.size()==1,"box source rows are both guaranteed, not weighted alternatives")
		check(not bool(actions.open_box(rules,"30701",{"수호의 인장 상자":1},{},1,1000,1000,{"수호의 인장 상자":rules.record("30701")},false).get("ok",false)),"box weight guard preserves input")
		var use = preload("res://scripts/crafting/patch523_item_use.gd")
		var qualified: Dictionary=rules.record("111842")
		check(use.reason(qualified,35,1).is_empty() and not use.reason(qualified,35,3).is_empty(),"original class qualification tolerates JSON numeric representation")
		var teleport: Dictionary=rules.record("19232")
		check(not use.reason(teleport,67,1).is_empty() and use.reason(teleport,68,1).is_empty(),"actual source minimum use level is inclusive")
		qualified.patch523_item_use.min_level=-1
		check(not use.reason(qualified,35,1).is_empty(),"damaged use metadata denies activation")
		check(rules.valid_material({"item":"아데나","source_id":"26","quantity":500000000,"level":0,"bless_code":1,"physical":false,"wallet":true}),"original 500m wallet alternative is not blocked by the old material cap")
		var fragments: Dictionary={"지배석 파편 (각인)":10}
		var fragment_record: Dictionary=rules.record("323853")
		var mapped: Dictionary={str(fragment_record.name):fragment_record}
		for id: String in ["323843","327323"]: mapped[str(rules.record(id).name)]=rules.record(id)
		var normal_result: Dictionary=rules.execute("patch523:221973",1,fragments,0,mapped,{}, {},30,1000,1,{}, {},0)
		var critical_result: Dictionary=rules.execute("patch523:221973",1,fragments,0,mapped,{}, {},30,1000,1,{}, {},900000)
		check(bool(normal_result.get("ok",false)) and normal_result.inventory.get("일반 지배석 상자 (각인)",0)==1,"original normal outcome selects first interval")
		check(bool(critical_result.get("ok",false)) and critical_result.inventory.get("일반 지배석 상자",0)==1 and not critical_result.inventory.has("일반 지배석 상자 (각인)"),"original critical boundary grants exactly one distinct unengraved result")
		check(not bool(rules.execute("patch523:221973",1,fragments,0,mapped,{}, {},30,1000,1).get("ok",false)),"random craft cannot execute without authoritative roll")
		check(not bool(rules.quote("patch523:221973",2,fragments,0,mapped,{}, {},30,1000).get("ok",false)),"random craft batch bound enforces one attempt")
		var store = preload("res://scripts/crafting/patch523_pack_store.gd")
		var installed: Dictionary = store.install(pack,expected)
		check(not installed.is_empty() and FileAccess.get_sha256(str(installed.get("path","")))==expected,"private pack copied to durable user directory")
		var index_sha: String = FileAccess.get_sha256(store.INDEX)
		check(store.install(pack,"0".repeat(64)).is_empty() and FileAccess.get_sha256(store.INDEX)==index_sha,"rejected installation preserves active configuration")
		check(str(store.active().get("sha256",""))==expected,"installed pack selection can be restored without environment variables")
	print("PATCH523_EQUIPMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"actual_source":not pack.is_empty()}))
	quit(0 if failures.is_empty() else 1)
