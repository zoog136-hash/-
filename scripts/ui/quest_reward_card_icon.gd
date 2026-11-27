extends RefCounted
## Presentation-only recovery for compact, receipt-backed transformation card
## items from older quest saves. Never rewrite the saved item or authorize use.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")

static func resolve(physical: Dictionary, record: Dictionary) -> Dictionary:
	var receipt: Variant = physical.get("quest_reward_receipt")
	if not receipt is Dictionary or receipt.get("schema") != 1 or receipt.get("source_sha256") != SOURCE.SOURCE_SHA: return {}
	if record.get("source_pending_use")!=true or record.get("slot")!="quest_reward" or record.get("type")!="원본 보상 보관": return {}
	var id: int = OWN.positive(receipt.get("item_class_id"))
	var remaining: int = OWN.positive(physical.get("source_reward_quantity"))
	if id==0 or remaining==0 or remaining>OWN.positive(receipt.get("quantity")) or physical.get("level",0)!=0 or SOURCE.not_installed(): return {}
	var key := "m523:item:" + str(id)
	if record.get("source_item_class_id",id)!=id or record.get("sourceId",key)!=key: return {}
	if record.get("source","lineagem_patch523")!="lineagem_patch523" or record.get("source_snapshot","patch523")!="patch523": return {}
	var item: Dictionary = SOURCE.row("ItemClass",id)
	if item.get("CategoryID")!=83 or item.get("IconID",0)<=0: return {}
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
	if reward.get("RewardTypeID")!=2 or reward.get("RewardClassID")!=id or reward.get("RewardEnhancementTypeID")!=1 or reward.get("ClanOnly")!=false: return {}
	if reward.get("ItemBlessCodeID")!=receipt.get("bless_code_id") or reward.get("Amount")!=receipt.get("quantity"): return {}
	# The raw ItemBonus link must target one transformation card. The image
	# pack provides the unmodified row even for items whose game view is adjusted.
	var card_ids: Array[int] = []
	for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",id):
		var bonus: Dictionary = SOURCE.row("Bonus",int(link.BonusID))
		if bonus.get("BonusTypeID")==139: card_ids.append(OWN.positive(bonus.get("Value")))
	if card_ids.size()!=1 or card_ids[0]<=0 or SOURCE.row("BuffCard",card_ids[0]).get("BuffCardDeckID")!=1: return {}
	var images: RefCounted = IMAGES.active()
	if images==null: return {}
	var original: Dictionary = images.source_consumer_row("ItemClass",id).get("row",{})
	if original.is_empty() or SOURCE.approximated_item(original)!=item: return {}
	# The held reward's key comes from the exact source row, not a translated
	# or approximate label. A contradictory row is not repaired for display.
	var expected_name: String = "[원본 보상] " + str(item.get("Name",""))
	if physical.get("name") != expected_name or record.get("name",expected_name) != expected_name: return {}
	if record.has("source_original_item") and record.source_original_item != original: return {}
	return {"name":expected_name,"source":"lineagem_patch523","source_snapshot":"patch523",
		"sourceId":key,"source_item_class_id":id,"source_original_item":original,
		"source_pending_use":true,"quest_item":true}
