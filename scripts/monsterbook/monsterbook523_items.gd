extends RefCounted
## New source-qualified stacks only. Never reinterpret legacy name-only inventory.
var _runtime: WeakRef
var runtime: RefCounted:
	get: return _runtime.get_ref() if _runtime != null else null
var world: Node

func configure(owner_runtime: RefCounted, owner_world: Node) -> void:
	_runtime = weakref(owner_runtime)
	world = owner_world

func reward_problem(reward: Dictionary) -> String:
	if int(reward.get("RewardTypeID",0)) == 1: return "" if runtime.economy.experience_amount(reward) > 0 else "경험치 자체 환산 설정 확인 필요"
	if int(reward.get("RewardTypeID",0)) != 2: return "원본 보상 유형 확인 필요"
	if int(reward.get("CharacterClassID",-1)) != 0 or reward.get("ClanOnly") != false or reward.get("UseImmediately") != false: return "원본 직업·혈맹·즉시 사용 조건 확인 필요"
	if int(reward.get("ItemBlessCodeID",0)) != 1 or int(reward.get("RewardEnhancementTypeID",0)) != 1: return "원본 축복·강화 조건 확인 필요"
	var item: Dictionary = runtime.catalog.row("ItemClass",int(reward.RewardClassID))
	var category: Dictionary = runtime.catalog.row("ItemCategory",int(item.get("CategoryID",-1)))
	if item.is_empty() or category.is_empty(): return "보상 분류 자료 업데이트 필요"
	if category.get("IsStackable") != true or int(item.get("Weight",-1)) != 0: return "원본 장비·무게 조건 연결 필요"
	# Existing source expiry handling also fails closed on native DeleteTime.
	# Preserve ownership; never turn a dated event pack into a permanent item.
	for link: Dictionary in runtime.catalog.table_rows("ItemBonus"):
		if int(link.ItemClassID) != int(item.ID): continue
		var bonus: Dictionary = runtime.catalog.row("Bonus",int(link.BonusID))
		var type: Dictionary = runtime.catalog.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if type.get("Name") == "DeleteTime": return "이벤트 아이템 삭제 시각 처리 확인 필요"
	if category.get("Name") not in ["Currency","StackableItem","ScrollBless"]: return "원본 아이템 사용·보관 조건 확인 필요"
	return ""

func definition(reward: Dictionary) -> Dictionary:
	var item: Dictionary = runtime.catalog.row("ItemClass",int(reward.RewardClassID))
	var name: String = str(item.Name) + " [" + str(int(item.ID)) + "]"
	var grade: Dictionary = runtime.catalog.row("Grade",int(item.GradeID))
	var desc: Dictionary = runtime.catalog.row("DescData_Korean",int(grade.get("DescID",0)))
	var category: Dictionary = runtime.catalog.row("ItemCategory",int(item.CategoryID))
	return {"name":name,"source":"lineagem_patch523","source_snapshot":"cumulative523","sourceId":"m523:item:"+str(int(item.ID))+":normal","source_item_class_id":int(item.ID),"monsterbook_source_item":true,"source_original":item.duplicate(true),"source_reward":reward.duplicate(true),"slot":"currency" if category.get("Name") == "Currency" else "material","type":str(category.get("Name","")),"grade":str(desc.get("Description","원본")),"desc":"몬스터 도감 보상 · 원본 아이템 ID와 소유 상태 보존","weight":0,"tradeable":bool(item.IsTradable),"storable":bool(item.IsStorable),"droppable":bool(item.IsDroppable),"price":0,"source_use_pending":true}

func settle(_before: Dictionary, proposed: Dictionary, quote: Dictionary, persist: Callable) -> bool:
	if quote.action not in ["claim_rewards", "claim"]: return false
	var inventory: Dictionary = world.inventory.duplicate(true)
	var records: Dictionary = proposed.get("source_items", {}).duplicate(true)
	var exp_gain: int = 0
	for reward: Dictionary in quote.get("rewards", []):
		if not reward_problem(reward).is_empty(): return false
		if int(reward.RewardTypeID) == 1:
			exp_gain += runtime.economy.experience_amount(reward)
			continue
		var item := definition(reward)
		var name: String = item.name
		var existing: Dictionary = world._find_catalog_item_record(name)
		if not existing.is_empty() and existing.get("sourceId") != item.sourceId: return false
		# A legacy quantity without our source-qualified ownership proof is not merged.
		if int(inventory.get(name,0)) > 0 and not records.has(name): return false
		var count: int = int(inventory.get(name,0)) + int(reward.Amount)
		if int(reward.Amount) <= 0 or count > int(item.source_original.MaxStackAmount): return false
		inventory[name] = count
		if not records.has(name) or records[name].get("sourceId") != item.sourceId: return false
	var overrides: Dictionary = {"inventory":inventory}
	var projected: Dictionary = runtime.economy.experience_state(exp_gain) if exp_gain > 0 else {}
	var saved_progress := projected.duplicate()
	if saved_progress.has("attack_power"):
		saved_progress["attack"] = saved_progress.attack_power
		saved_progress.erase("attack_power")
	overrides.merge(saved_progress)
	if persist.call(proposed,overrides) != true: return false
	world.inventory = inventory
	for key: String in projected: world.set(key,projected[key])
	install(records)
	if exp_gain > 0:
		world.hud.append_log("몬스터 도감 경험치 +%d · TWILIGHT 자체 환산" % exp_gain)
		world._update_hud()
	return true

func install(records: Dictionary) -> void:
	if not is_instance_valid(world): return
	for name: String in records:
		var item: Dictionary = records[name]
		if not valid_record(name,item): continue
		var existing: Dictionary = world._find_catalog_item_record(name)
		if not existing.is_empty(): continue
		world.catalog_db["아이템"].append(item.duplicate(true))
		world.item_db.append(item.duplicate(true))
		world.catalog_item_by_source_id[item.sourceId] = item.duplicate(true)
		world.item_weight_index[name] = 0
		world.loot_catalog.get("by_name",{})[name] = item.duplicate(true)

static func valid_record(name: String, item: Variant) -> bool:
	if not item is Dictionary or item.get("name") != name or item.get("source") != "lineagem_patch523" or item.get("source_snapshot") != "cumulative523" or item.get("monsterbook_source_item") != true or not item.get("source_original") is Dictionary or not item.get("source_reward") is Dictionary: return false
	var id: Variant = item.get("source_item_class_id")
	if not (id is int or id is float) or not is_finite(float(id)) or float(id) != floorf(float(id)) or int(id) <= 0: return false
	if item.get("sourceId") != "m523:item:"+str(int(id))+":normal" or int(item.source_original.get("ID",0)) != int(id) or int(item.source_reward.get("RewardClassID",0)) != int(id) or int(item.source_reward.get("RewardTypeID",0)) != 2: return false
	if name != str(item.source_original.get("Name",""))+" ["+str(int(id))+"]" or item.get("slot") not in ["currency","material"] or item.get("source_use_pending") != true: return false
	if item.get("weight") != 0 or item.get("price") != 0: return false
	return item.get("tradeable") == item.source_original.get("IsTradable") and item.get("storable") == item.source_original.get("IsStorable") and item.get("droppable") == item.source_original.get("IsDroppable")
