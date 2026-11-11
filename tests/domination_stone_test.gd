extends SceneTree
## Domination stone rules on synthetic rows (no original table values are
## embedded): contract checks, set grade, slot gates, merge odds and
## consumption, weekly quest board, reroll costs and save round trip.
const SRC = preload("res://scripts/domination/domination_stone_source.gd")
const RUNTIME = preload("res://scripts/domination/domination_stone_runtime.gd")
var failures: Array[String] = []

class Drops:
	static func equipment_error(_record: Dictionary, _job: String, _level: int, _offset: int) -> String:
		return ""

class Loot:
	const PATCH523_DROPS = Drops

class FakeWorld:
	const LOOT_DROP = Loot
	var level: int = 100
	var hp: int = 10
	var mp: int = 10
	var gold: int = 0
	var job_class: String = "기사"
	var ui_preferences: Dictionary = {}
	var inventory: Dictionary = {}
	var item_instances: Dictionary = {}
	var equipped_items: Dictionary = {"domination_stone":{}}
	var hud = null
	var catalog: Dictionary = {}
	var runtime
	var next_id: int = 1
	func record(class_id: int) -> Dictionary:
		return {"name":"stone#%d" % class_id,"slot":"domination_stone","source_m_native_item":true,"source_item_class_id":class_id,"mr":class_id % 10}
	func grant(class_id: int) -> String:
		var rec: Dictionary = record(class_id)
		var id: String = str(next_id); next_id += 1
		item_instances[id] = {"name":rec.name,"record":rec}
		inventory[rec.name] = int(inventory.get(rec.name,0)) + 1
		return id
	func _is_instance_equipped(id: String) -> bool:
		return runtime.is_extra_equipped(id) or str(equipped_items.domination_stone.get("instance_id","")) == id
	func _find_catalog_item_record(_name: String) -> Dictionary: return {}
	func _item_locked(_name: String, _id: String = "") -> bool: return false
	func _catalog_item_from_source_id(source_id: String) -> Dictionary: return record(int(source_id.get_slice(":",2)))
	func _source_catalog_record(_kind: String, value: Dictionary) -> Dictionary: return value
	func _sync_item_instances() -> void:
		for name: Variant in inventory:
			var have: int = 0
			for id: Variant in item_instances:
				if item_instances[id].name == name: have += 1
			while have < int(inventory[name]):
				item_instances[str(next_id)] = {"name":name}; next_id += 1; have += 1
	func _equip_or_acquire_item(rec: Dictionary, _add: bool, id: String, _slot: String) -> void:
		equipped_items.domination_stone = rec.duplicate(); equipped_items.domination_stone["instance_id"] = id
	func _invalidate_equipment_static() -> void: pass
	func _refresh_speed_modifiers() -> void: pass
	func _effective_max_hp() -> int: return 10
	func _effective_max_mp() -> int: return 10
	func _update_hud() -> void: pass
	func _request_deferred_save() -> void: pass

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

## Two kinds (groups 1, 2) of three grades; set 10 needs kind 1.
func tables() -> Dictionary:
	var items: Array = []
	var classes: Array = []
	var inputs: Array = []
	for group: int in [1,2]:
		for grade: int in [3,4,5]:
			var id: int = group * 100 + grade
			items.append({"ID":id,"DominationStoneGroupID":group,"ItemClassID":id})
			classes.append({"ID":id,"GradeID":grade,"TestItem":false,"Name":"s%d" % id})
			inputs.append({"ItemClassID":id,"BasePrice":{3:1,4:10,5:100}[grade]})
	return {
		"DominationStoneGroup":[{"ID":1,"Name":"A","TowerID":7,"FloorRank":1},{"ID":2,"Name":"B","TowerID":7,"FloorRank":2}],
		"DominationStoneItemClass":items,"ItemClass":classes,"DominationStoneMergeInput":inputs,
		"DominationStoneMergeOutputGrade":[{"GradeID":3,"PriceLow":3,"PriceHigh":9,"Probability":700000},{"GradeID":4,"PriceLow":3,"PriceHigh":9,"Probability":300000},{"GradeID":5,"PriceLow":10,"PriceHigh":999,"Probability":1000000}],
		"DominationStoneMergeOutputGroup":[{"DominationStoneGroupID":1,"ProbabilityType":3,"Probability":600000},{"DominationStoneGroupID":2,"ProbabilityType":3,"Probability":400000},{"DominationStoneGroupID":1,"ProbabilityType":23,"Probability":500000}],
		"UIDominationStoneMergeDivinationProb":[{"ResultGrade":3,"MinInputGrade":3,"DivinationGrade":3,"Probability":1}],
		"DominationStoneSet":[{"ID":10,"Name":"SetA","NameID":1}],
		"DominationStoneSetGroup":[{"DominationStoneSetID":10,"DominationStoneGroupID":1},{"DominationStoneSetID":10,"DominationStoneGroupID":1},{"DominationStoneSetID":10,"DominationStoneGroupID":1}],
		"DominationStoneSetBonus":[{"DominationStoneSetID":10,"GradeID":4,"BonusID":50,"Order":1},{"DominationStoneSetID":10,"GradeID":5,"BonusID":51,"Order":1}],
		"Bonus":[{"ID":50,"BonusTypeID":9,"Value":900,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0},{"ID":51,"BonusTypeID":9,"Value":901,"BonusApplicationTypeID":0,"BonusApplicationTargetID":0}],
		"BonusType":[{"ID":9,"Name":"FixedDesc"}],
		"DescData_Korean":[{"ID":1,"Description":"권능"},{"ID":900,"Description":"four"},{"ID":901,"Description":"five"},{"ID":800,"Description":"quest"}],
		"UIDominationStoneSet":[],
		"DominationStoneTower":[{"ID":1,"ContentsControlID":7,"Priority":1,"NameID":0}],
		"DominationStoneFloor":[{"ID":20,"TowerID":1,"Floor":1}],
		"DominationStoneQuestGroup":[{"ID":30,"FloorID":20,"SlotIndex":1}],
		"DominationStoneQuest":[{"QuestID":40,"GroupID":30,"Probability":1,"IsDefault":true},{"QuestID":41,"GroupID":30,"Probability":1,"IsDefault":false}],
		"QuestView":[{"ID":40,"TitleDescID":800,"TypeID":143}],
		"DominationStoneQuestRerollCost":[{"Count":1,"CurrencyID":1,"Amount":5},{"Count":2,"CurrencyID":4,"Amount":2}],
		"DominationStoneConstant":[],
	}

func _initialize() -> void:
	var t: Dictionary = tables()
	var c: Dictionary = SRC.build(t)
	check(c.get("ok",false), "contract builds: "+str(c.get("problem","")))
	var broken: Dictionary = t.duplicate(true)
	broken.DominationStoneMergeOutputGrade[0].Probability = 1
	check(not SRC.build(broken).get("ok",true), "grade odds must sum to one million")
	broken = t.duplicate(true)
	broken.DominationStoneQuest[0].IsDefault = false
	check(not SRC.build(broken).get("ok",true), "one default quest per group")
	check(SRC.pick([[3,700000],[4,300000]],699999) == 3 and SRC.pick([[3,700000],[4,300000]],700000) == 4, "weighted pick boundaries")
	# Weeks start Wednesday 05:00 KST (= Tuesday 20:00 UTC).
	var tuesday_1959: int = 1762891140 # 2025-11-11 19:59 UTC (Tue)
	check(RUNTIME.week_key(tuesday_1959) != RUNTIME.week_key(tuesday_1959 + 120), "week turns at Wednesday 05:00 KST")
	check(RUNTIME.week_key(tuesday_1959 + 120) == RUNTIME.week_key(tuesday_1959 + 6 * 86400), "same week until next Wednesday")

	var world := FakeWorld.new()
	var runtime = RUNTIME.new()
	world.runtime = runtime
	runtime.contract_override = c
	runtime.configure(world)
	runtime.rng.seed = 11
	runtime.now_override = tuesday_1959 + 3600
	world.level = 70
	var a: String = world.grant(104)
	var b: String = world.grant(105)
	var d: String = world.grant(104)
	check(runtime.equip(a,0).get("ok",false), "slot 1 opens at 68")
	check(not runtime.equip(b,1).get("ok",false), "slot 2 locked below 80")
	world.level = 92
	check(runtime.equip(b,1).get("ok",false) and runtime.equip(d,2).get("ok",false), "slots 2 and 3")
	check(not runtime.equip(d,1).get("ok",false), "a stone is equipped once")
	var set_state: Dictionary = runtime.active_set()
	check(set_state.get("active",false) and int(set_state.grade) == 4 and str(set_state.entries[0].text) == "four", "set grade is the lowest stone grade")
	check(runtime.bonus_records().size() == 2, "slots 2/3 add their item records")
	# Merge.
	var inputs: Array = []
	for i: int in range(5): inputs.append(world.grant(103))
	check(not runtime.merge_quote(inputs.slice(0,2)).get("ok",true), "merge needs three")
	check(not runtime.merge_quote([a,inputs[0],inputs[1]]).get("ok",true), "equipped stones are not inputs")
	var quote: Dictionary = runtime.merge_quote(inputs)
	check(quote.get("ok",false) and int(quote.price) == 5 and int(quote.same_group) == 1 and int(quote.same_group_probability_raw) == 500000, "five same stones keep the kind at the table odds")
	check(int(runtime.merge_quote(inputs.slice(0,4)).same_group) == -1, "kind odds need every slot")
	var before: int = world.item_instances.size()
	var merged: Dictionary = runtime.merge(inputs)
	check(merged.get("ok",false) and int(merged.grade) in [3,4] and world.item_instances.size() == before - 4, "merge consumes five and grants one")
	check(int(world.inventory.get("stone#103",0)) == (1 if int(merged.item_class_id) == 103 else 0), "inputs leave the bag")
	# Grade odds over many rolls stay on the table values.
	var counts: Dictionary = {3:0,4:0}
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	for i: int in range(20000): counts[SRC.pick(c.bands[0].grades, rng.randi_range(0,999999))] += 1
	check(absf(float(counts[3]) / 20000.0 - 0.7) < 0.02, "grade odds follow the table")
	# Quests.
	var board: Array = runtime.board()
	check(board.size() == 1 and int(board[0].slots[0].quest.quest_id) == 40, "default quest first")
	check(not runtime.reroll(20).get("ok",true), "reroll needs adena")
	world.gold = 10
	check(runtime.reroll(20).get("ok",false) and world.gold == 5, "first reroll costs table adena")
	check(not runtime.reroll(20).get("ok",true), "second reroll needs gems")
	world.inventory["다이아"] = 3
	check(runtime.reroll(20).get("ok",false) and int(world.inventory["다이아"]) == 1, "second reroll costs table gems")
	check(not runtime.reroll(20).get("ok",true), "rerolls stop past the table")
	check(runtime.accept(20,1).get("ok",false) and not runtime.accept(20,1).get("ok",true), "one quest per week")
	# Save round trip and a broken save.
	var saved: Variant = runtime.export_state()
	var reloaded = RUNTIME.new()
	reloaded.contract_override = c
	reloaded.configure(world)
	reloaded.now_override = runtime.now_override
	world.runtime = reloaded
	reloaded.import_state(JSON.parse_string(JSON.stringify(saved)))
	check(reloaded.state.slots == runtime.state.slots and int(reloaded.state.accepted.quest_id) == int(runtime.state.accepted.quest_id) and int(reloaded.state.rerolls) == 2, "save round trip")
	check(reloaded.active_set().get("active",false), "set active after reload")
	var bad = RUNTIME.new()
	bad.configure(world)
	bad.import_state({"schema":"other"})
	check(bad.save_blocked and bad.export_state() == {"schema":"other"} and not bad.unequip(1).get("ok",true), "unreadable save is kept and blocks changes")
	world.runtime = runtime
	var removed: Dictionary = runtime.unequip(1)
	check(removed.get("ok",false) and not runtime.active_set().get("active",false), "unequip ends the set")
	print("DOMINATION_STONE_RESULT ", JSON.stringify({"failures":failures,"merged":merged.get("item_class_id",-1)}))
	quit(0 if failures.is_empty() else 1)
