extends RefCounted
## Group presentation only. The slot activates its first physical reward;
## quest consumers still validate and debit that exact grant and receipt.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
const OWN = preload("res://scripts/quests/quest_reward_ownership.gd")

static func grouped_row(entry: Dictionary, physical: Dictionary, locks: Dictionary, caps: Dictionary, bins: Dictionary) -> Dictionary:
	var receipt: Variant = physical.get("quest_reward_receipt")
	if not receipt is Dictionary or not physical.get("record") is Dictionary: return {}
	for key: String in physical:
		if key not in ["name","record","level","quest_reward_receipt","source_reward_quantity"]: return {}
	var record: Dictionary = physical.record
	if record.get("source_pending_use")!=true or record.get("slot")!="quest_reward" or record.get("source_use_immediately")!=false or physical.get("level",0)!=0: return {}
	if record.get("source")!="lineagem_patch523" or record.get("source_snapshot")!="patch523" or record.get("name")!=entry.name: return {}
	var id: int = OWN.positive(record.get("source_item_class_id"))
	var bless: int = OWN.positive(receipt.get("bless_code_id"))
	var remaining: int = OWN.positive(physical.get("source_reward_quantity"))
	if id==0 or bless not in [1,2,3] or remaining==0 or remaining>OWN.positive(receipt.get("quantity")): return {}
	if receipt.get("schema")!=1 or receipt.get("source_sha256")!=SOURCE.SOURCE_SHA or receipt.get("item_class_id")!=id or record.get("sourceId")!="m523:item:"+str(id): return {}
	if OWN.positive(receipt.get("reward_id"))==0 or receipt.get("reward_id")!=record.get("source_reward_id") or record.get("source_bless_code_id")!=bless: return {}
	if not caps.has(id):
		var row: Dictionary = SOURCE.row("ItemClass",id)
		var category: Dictionary = SOURCE.row("ItemCategory",int(row.get("CategoryID",0))) if not row.is_empty() else {}
		# Ammo tracks exactly which physical reward is equipped.
		var cap: int = OWN.positive(row.get("MaxStackAmount")) if row.get("TestItem") == false and category.get("IsStackable") == true and category.get("Name") not in ["Arrow","Bullet","Sting"] else 0
		caps[id] = {"row":row,"cap":cap}
	var canonical: Dictionary = caps[id]
	if canonical.cap<=1 or remaining>int(canonical.cap) or NATIVE_FIELDS.field(record,"source_original_item",{})!=canonical.row: return {}
	var key: Array = [id,bless,bool(locks.get(entry.reference,false))]
	var bin: Dictionary = bins.get(key,{})
	if not bin.is_empty() and int(bin.amount)+remaining<=int(canonical.cap):
		bin.amount = int(bin.amount)+remaining
		return bin
	# Keep the first exact reference as the existing action target. New
	# entries start a separate bin when the original stack cap is reached.
	bins[key] = entry
	return {}
