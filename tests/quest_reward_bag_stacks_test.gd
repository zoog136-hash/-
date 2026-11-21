extends SceneTree

const BAG = preload("res://scripts/ui/lineage_inventory_ui.gd")
const GROUPS = preload("res://scripts/ui/quest_reward_bag_stacks.gd")
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QUEST_SOURCE = preload("res://scripts/quests/source_quest523.gd")

class QuestService extends RefCounted:
	var source = QUEST_SOURCE.new()
	var claimed: Dictionary = {}
	var index: Dictionary = {}
	var item_grants: Dictionary = {}
	var save_blocked: bool = false

class World extends Node:
	var quest_service := QuestService.new()
	var item_instances: Dictionary = {}
	var inventory: Dictionary = {}
	var locks: Dictionary = {}
	func _item_locked(name_value: String, id: String = "") -> bool:
		return locks.get(name_value if id.is_empty() else name_value+"@@@"+id,false)

var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func grant(row: Dictionary, quest: String, reward: int, quantity: int) -> Dictionary:
	var id: int = int(row.ID)
	var name_value: String = "[원본 보상] "+str(row.Name)
	return {"name":name_value,"level":0,"source_reward_quantity":quantity,
		"record":{"name":name_value,"slot":"quest_reward","source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:"+str(id),"source_pending_use":true,"source_original_item":row,"source_item_class_id":id,"source_reward_id":reward,"source_bless_code_id":1,"source_use_immediately":false},
		"quest_reward_receipt":{"schema":1,"quest_id":quest,"reward_id":reward,"item_class_id":id,"bless_code_id":1,"source_sha256":SOURCE.SOURCE_SHA,"quantity":quantity}}

func ui_row(physical: Dictionary, uid: String) -> Dictionary:
	return {"name":physical.name,"reference":str(physical.name)+"@@@"+uid,"amount":physical.source_reward_quantity}

func rules() -> void:
	var original: Dictionary = {"ID":335,"Name":"용기의 물약 (각인)"}
	var first: Dictionary = grant(original,"quest1",1,5)
	var second: Dictionary = grant(original,"quest2",2,5)
	var caps: Dictionary = {335:{"row":original,"cap":11}}
	var bins: Dictionary = {}
	var first_row: Dictionary = ui_row(first,"11")
	check(GROUPS.grouped_row(first_row,first,{},caps,bins).is_empty(), "the first grant creates a row with its exact reference")
	check(GROUPS.grouped_row(ui_row(second,"12"),second,{},caps,bins)==first_row and int(first_row.amount)==10, "different receipt origins share a row when the item and state match")
	check(GROUPS.grouped_row(ui_row(second,"13"),second,{},caps,bins).is_empty() and int(first_row.amount)==10, "the source cap starts a separate row")
	var locked: Dictionary = ui_row(second,"14")
	check(GROUPS.grouped_row(locked,second,{locked.reference:true},caps,bins).is_empty(), "a locked reward stays separate")
	var blessed: Dictionary = second.duplicate(true)
	blessed.quest_reward_receipt.bless_code_id=2
	blessed.record.source_bless_code_id=2
	check(GROUPS.grouped_row(ui_row(blessed,"15"),blessed,{},caps,bins).is_empty(), "a different blessing stays separate")
	var invalid: Dictionary=second.duplicate(true)
	invalid.quest_reward_receipt.source_sha256="other"
	check(GROUPS.grouped_row(ui_row(invalid,"16"),invalid,{},caps,bins).is_empty(), "an unknown receipt stamp is kept separate")
	var other: Dictionary = {"ID":19423,"Name":original.Name}
	caps[19423]={"row":other,"cap":11}
	var another_item: Dictionary = grant(other,"quest3",3,1)
	check(GROUPS.grouped_row(ui_row(another_item,"17"),another_item,{},caps,bins).is_empty(), "an equally named item with a different ItemClass stays separate")
	check(int(first.source_reward_quantity)==5 and int(second.source_reward_quantity)==5, "display grouping leaves the underlying grants untouched")

func original_rewards() -> void:
	var original: Dictionary = SOURCE.row("ItemClass",335)
	var world := World.new()
	for values: Array in [["11",401,22111],["12",451,22191]]:
		var reward: Dictionary = SOURCE.row("Reward",int(values[2])).duplicate()
		var link: Array[Dictionary] = SOURCE.related("QuestReward","QuestID",int(values[1]))
		check(int(reward.get("RewardClassID",0))==335 and int(reward.get("Amount",0))==5 and link.any(func(row: Dictionary) -> bool: return row.RewardID==values[2]), "original Reward and QuestReward join for "+str(values[2]))
		var quest: String = "m523:quest:"+str(values[1])
		reward["source_item"]=original
		reward["type_name"]="Item"
		world.quest_service.index[quest]={"blockers":[],"excluded_reasons":[],"enhancements":[],"source_rewards":[reward]}
		world.quest_service.claimed[quest]=true
		var plan: Dictionary=world.quest_service.source.reward_plan(world.quest_service.index[quest],{"class_id":int(reward.CharacterClassID)})
		if not plan.get("ok",false) or plan.items.size()!=1 or not plan.items[0].record.get("source_pending_use",false):
			check(false,"production reward planner offers an exact held item")
			world.free()
			return
		var physical: Dictionary=grant(original,quest,int(reward.ID),int(reward.Amount))
		physical.record=plan.items[0].record
		world.item_instances[values[0]]=physical
	var name_value: String = str(world.item_instances["11"].name)
	world.inventory[name_value]=10
	var before: Dictionary = world.item_instances.duplicate(true)
	var bag = BAG.new()
	bag.inventory=world.inventory
	bag.character_state={"item_instances":world.item_instances}
	var rows: Array[Dictionary]=bag._inventory_entries()
	check(rows.size()==1 and rows[0].amount==10 and rows[0].reference==name_value+"@@@11", "two original quest grants display as one x10 slot")
	check(world.item_instances==before and OWN.proof(world,"11").get("ok",false) and OWN.proof(world,"12").get("ok",false), "both exact quest receipts remain valid")
	var staged: Dictionary=OWN.prepare_debit(world,"11",1)
	check(staged.get("ok",false) and staged.get("override",{}).get("item_instances",{}).get("12")==before["12"], "the existing owner debits only the representative's receipt")
	if staged.get("ok",false):
		bag.inventory=staged.override.inventory
		bag.character_state.item_instances=staged.override.item_instances
		rows=bag._inventory_entries()
		check(rows.size()==1 and rows[0].amount==9 and bag._bag_display_amount(rows[0].reference)==9, "the grouped count follows an adopted exact debit")
		bag.character_state.item_instances=JSON.parse_string(JSON.stringify(staged.override.item_instances))
		rows=bag._inventory_entries()
		check(rows.size()==1 and rows[0].amount==9, "restored JSON receipts retain the same displayed stack")
	var exhausted: Dictionary = OWN.prepare_debit(world,"11",5)
	check(exhausted.get("ok",false), "the first grant can be exhausted independently")
	if exhausted.get("ok",false):
		bag.inventory=exhausted.override.inventory
		bag.character_state.item_instances=exhausted.override.item_instances
		rows=bag._inventory_entries()
		check(rows.size()==1 and rows[0].amount==5 and rows[0].reference==name_value+"@@@12", "depleting the first receipt exposes the second exact reference")
	bag.free()
	world.free()

func run() -> void:
	rules()
	var original: bool=not SOURCE.not_installed()
	if original: original_rewards()
	print("QUEST_REWARD_BAG_STACKS_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"original_definitions":original}))
	quit(0 if failures.is_empty() else 1)
