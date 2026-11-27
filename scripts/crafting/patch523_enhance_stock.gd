extends RefCounted
## Keep the original scroll identity and physical selection through the quote
## and debit. Old saves can also carry a verified single physical unit.
const STACK = preload("res://scripts/loot/current523_native_stack.gd")
const ITEM_USE = preload("res://scripts/loot/patch523_item_use.gd")
const ENHANCE = preload("res://scripts/crafting/patch523_enhancement.gd")
const SOURCE = preload("res://scripts/crafting/patch523_enhance_source_book.gd")
const CATALOG_STACK = preload("res://scripts/loot/current523_catalog_stack.gd")
const DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")
const QUEST_OWN = preload("res://scripts/quests/quest_reward_ownership.gd")
const QUEST_CONSUME = preload("res://scripts/quests/quest_reward_consumption.gd")
const SEAL_BOX_SCROLL_ID := "320802"

static func select_owned(world: Node, name: String, selected: String, count: int, require_physical: bool=false) -> Dictionary:
	var ids: Array = world.item_instances.keys()
	ids.sort()
	var has_receipts: bool = false
	var refused: String = ""
	for uid: String in ids:
		var entry: Variant = world.item_instances[uid]
		if not entry is Dictionary or entry.get("name") != name: continue
		var receipted: bool = entry.has(STACK.RECEIPT)
		var quest_reward: bool = entry.has("quest_reward_receipt")
		has_receipts = has_receipts or receipted or quest_reward
		if not selected.is_empty() and uid != selected: continue
		if not receipted and selected.is_empty(): continue
		if world._item_locked(name,uid) or world._item_locked(name):
			refused="선택한 원본 강화 주문서의 잠금을 해제하세요"
			continue
		var proof: Dictionary
		if receipted:proof=STACK.proof(world,uid)
		elif quest_reward:proof=quest_scroll(world,uid)
		else:proof=legacy_unit(world,entry,name)
		if proof.is_empty():return {"native":true,"reason":"원본 강화 주문서의 물리 소유를 확인할 수 없습니다"}
		var reason: String=ITEM_USE.eligibility(world,proof.record)
		if not reason.is_empty():refused=reason;continue
		if ENHANCE.item_id(proof.record).is_empty():return {"native":true,"reason":"원본 강화 주문서의 ItemClass를 확인할 수 없습니다"}
		if int(proof.remaining)<count:
			refused="선택한 원본 강화 주문서 묶음의 수량이 부족합니다"
			continue
		return {"native":true,"ok":true,"uid":uid,"proof":proof}
	if has_receipts or require_physical:
		return {"native":true,"reason":refused if not refused.is_empty() else "가방에서 사용할 원본 강화 주문서 묶음을 다시 선택하세요"}
	return {}

static func quest_scroll(world: Node, uid: String) -> Dictionary:
	var receipt: Variant=world.item_instances.get(uid,{}).get("quest_reward_receipt")
	if not receipt is Dictionary:return {}
	var record: Dictionary=world.source_item_record(QUEST_OWN.positive(receipt.get("item_class_id")),QUEST_OWN.positive(receipt.get("bless_code_id")))
	if not SOURCE.declares_scroll(record) or world.item_life523.has_life_row(record):return {}
	var owned: Dictionary=QUEST_OWN.proof(world,uid)
	if not owned.get("ok",false) or owned.source_use_immediately:return {}
	return {"record":record,"remaining":int(owned.quantity),"quest_reward_receipt":receipt.duplicate(true)}

## The standalone seal box issued this scroll as a plain original-key balance.
## The bare bag row is usable only while it still represents that plain stock.
static func owns_seal_box_balance(world: Node, name: String, record: Dictionary) -> bool:
	if ENHANCE.item_id(record)!=SEAL_BOX_SCROLL_ID or record.get("name")!=name or record.get("source_bless_raw")!=1:
		return false
	if world._catalog_item_from_source_id(str(record.sourceId))!=record or not SOURCE.declares_scroll(record):
		return false
	return not world._item_locked(name) and CATALOG_STACK.holds_plain(world,name)

## Old saves could pin a single ordinary scroll before receipts existed.
## A partial or foreign receipt must never be downgraded to this format.
static func legacy_unit(world: Node, entry: Dictionary, name: String) -> Dictionary:
	if not world.has_method("source_item_record"): return {}
	for field: String in [STACK.RECEIPT, STACK.QUANTITY, "quest_reward_receipt", "source_reward_quantity", "source_native_stack_used_quantity"]:
		if entry.has(field): return {}
	var pinned: Variant = entry.get("record")
	if not pinned is Dictionary or pinned.get("slot") not in ["consumable","material"]:
		return {}
	if entry.get("name")!=name or entry.get("level",-1)!=0 or world.patch523_equipment.bless_code(entry)!=1:
		return {}
	var record: Dictionary
	if pinned.get("source_m_native_item",false):
		var original_id: String = ENHANCE.item_id(pinned)
		if not original_id.is_valid_int(): return {}
		record = world._catalog_item_from_source_id("m523:item:"+original_id)
		if record.is_empty(): record=world.source_item_record(int(original_id))
		if record.is_empty(): return {}
		var original_name: String = str(record.name)
		if name!=original_name and not CATALOG_STACK.unique_stock_name(name,int(original_id)): return {}
		if pinned.get("name") not in [name,original_name]: return {}
		# Earlier saves stored the Korean key with or without the verified
		# ItemClass suffix. Compare the pinned metadata against that exact row.
		var identity: Dictionary = pinned.duplicate()
		identity["name"]=original_name
		if not DROPS.matches(identity,record): return {}
	else:
		if pinned.get("name")!=name: return {}
		record=CATALOG_STACK.action_record(world,pinned)
	var id: String=ENHANCE.item_id(record)
	if not id.is_valid_int() or record.get("source_bless_raw")!=1: return {}
	if str(entry.get("sourceId", pinned.get("sourceId", ""))) not in [id, str(pinned.get("sourceId", ""))]: return {}
	if not SOURCE.declares_scroll(record) or world.item_life523.has_life_row(record): return {}
	return {"record":record,"remaining":1,"legacy_unit":true,"inventory_key":name}

static func stage(world: Node, owned: Dictionary, quantity: int) -> Dictionary:
	if STACK.busy:return {"ok":false,"reason":"원본 아이템 저장 처리 중 · 주문서 보존"}
	var proof: Dictionary=owned.proof
	if quantity<=0 or int(proof.remaining)<quantity:return {"ok":false,"reason":"선택한 원본 강화 주문서 묶음의 수량이 부족합니다"}
	if proof.has("quest_reward_receipt"):
		var request: Dictionary={"physical_id":owned.uid,"quantity":quantity,"expected_quantity":proof.remaining,
			"expected_remaining":int(proof.remaining)-quantity,"quest_reward_receipt":proof.quest_reward_receipt}
		var digest: String=str(proof.record.get("source_definition_archive",{}).get("source_sha256",""))
		var result: Dictionary=QUEST_CONSUME.stage(world,[request],digest)
		if not result.get("ok",false):return result
		return {"ok":true,"overrides":result.overrides,"quest_step":result}
	if proof.get("legacy_unit", false):
		var name: String = str(proof.inventory_key)
		var current: Dictionary = select_owned(world, name, str(owned.uid), quantity, true)
		if not current.get("ok", false) or current.proof != proof or int(world.inventory.get(name, 0)) < quantity:
			return {"ok":false,"reason":"선택한 원본 강화 주문서가 변경되었습니다"}
		var bag: Dictionary = world.inventory.duplicate(true)
		var instances: Dictionary = world.item_instances.duplicate(true)
		bag[name] = int(bag[name]) - quantity
		if bag[name] == 0: bag.erase(name)
		instances.erase(owned.uid)
		return {"ok":true,"overrides":{"inventory":bag,"item_instances":instances,"consumable_state":world.consumable_service.export_state()}}
	var request: Dictionary={"physical_id":owned.uid,"quantity":quantity,"expected_quantity":proof.remaining,
		"expected_remaining":int(proof.remaining)-quantity,"source_native_stack_receipt":proof.receipt}
	return STACK.stage_debit(world,[request])
