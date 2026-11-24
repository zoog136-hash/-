extends RefCounted
## Presentation-only recovery for compact, receipt-backed transformation card
## items from older quest saves. Never rewrite the saved item or authorize use.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
## Exact quest reward ItemClasses whose ItemBonus declares a deck-1 BuffCard.
## This list is only an admission bound; the actual reward and row are rechecked.
const ITEMS := [139781,289172,289182,289202,306611,306621,306631,306641]

static func resolve(physical: Dictionary, record: Dictionary) -> Dictionary:
	var receipt: Variant = physical.get("quest_reward_receipt")
	if not receipt is Dictionary or receipt.get("schema") != 1 or receipt.get("source_sha256") != SOURCE_SHA: return {}
	var id: Variant = receipt.get("item_class_id")
	if id not in ITEMS or SOURCE.not_installed(): return {}
	var key := "m523:item:" + str(int(id))
	if record.get("source_item_class_id",id) != id or record.get("sourceId",key) != key 			or record.get("source","lineagem_patch523") != "lineagem_patch523" or record.get("source_snapshot","patch523") != "patch523": return {}
	var quest: Variant = receipt.get("quest_id")
	var reward_id: Variant = receipt.get("reward_id")
	if not quest is String or not quest.begins_with("m523:quest:") or not (reward_id is int or reward_id is float): return {}
	var quest_id := int(quest.trim_prefix("m523:quest:"))
	if quest_id <= 0 or quest != "m523:quest:" + str(quest_id) or not is_finite(float(reward_id)) or int(reward_id) != reward_id or reward_id <= 0: return {}
	var matches := 0
	for link: Dictionary in SOURCE.related("QuestReward","QuestID",quest_id):
		if link.get("RewardID") == reward_id: matches += 1
	if matches != 1: return {}
	var reward: Dictionary = SOURCE.row("Reward",int(reward_id))
	if reward.get("RewardClassID") != id or reward.get("ItemBlessCodeID") != receipt.get("bless_code_id"): return {}
	var kind: Dictionary = SOURCE.row("RewardType",int(reward.get("RewardTypeID",-1)))
	if kind.get("Name") != "Item": return {}
	var item: Dictionary = SOURCE.row("ItemClass",int(id))
	if item.is_empty() or item.get("TestItem",true) != false or item.get("IconID",0) <= 0: return {}
	# The held reward's key comes from the exact source row, not a translated
	# or approximate label. A contradictory row is not repaired for display.
	var expected_name: String = "[원본 보상] " + str(item.get("Name",""))
	if physical.get("name") != expected_name or record.get("name",expected_name) != expected_name: return {}
	if record.has("source_original_item") and record.source_original_item != item: return {}
	return {"name":expected_name,"source":"lineagem_patch523","source_snapshot":"patch523",
		"sourceId":key,"source_item_class_id":int(id),"source_original_item":item,
		"source_pending_use":true,"quest_item":true}
