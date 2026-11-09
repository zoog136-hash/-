extends RefCounted
## New source-qualified stacks only. Never reinterpret legacy name-only inventory.
const NATIVE=preload("res://scripts/monsterbook/monsterbook523_native_rewards.gd")
var _runtime: WeakRef
var runtime: RefCounted:
	get: return _runtime.get_ref() if _runtime != null else null
var world: Node

func configure(owner_runtime: RefCounted, owner_world: Node) -> void:
	_runtime = weakref(owner_runtime)
	world = owner_world

func reward_problem(reward: Dictionary) -> String:
	var kind: String=str(runtime.catalog.row("RewardType",int(reward.get("RewardTypeID",0))).get("Name",""))
	if int(reward.get("RewardTypeID",0)) == 1 and kind=="Exp": return "" if runtime.economy.experience_amount(reward) > 0 else "경험치 자체 환산 설정 확인 필요"
	if int(reward.get("RewardTypeID",0)) != 2 or kind!="Item": return "원본 보상 유형 확인 필요"
	if int(reward.get("CharacterClassID",-1)) != 0 or reward.get("ClanOnly") != false or reward.get("UseImmediately") != false: return "원본 직업·혈맹·즉시 사용 조건 확인 필요"
	if int(reward.get("ItemBlessCodeID",0)) != 1 or int(reward.get("RewardEnhancementTypeID",0)) != 1: return "원본 축복·강화 조건 확인 필요"
	var item: Dictionary = runtime.catalog.row("ItemClass",int(reward.RewardClassID))
	var category: Dictionary = runtime.catalog.row("ItemCategory",int(item.get("CategoryID",-1)))
	if item.is_empty() or category.is_empty(): return "보상 분류 자료 업데이트 필요"
	if item.get("TestItem")!=false or not preload("res://scripts/quests/source_dummy523.gd").item_evidence(item).is_empty():return "원본 시험·더미 보상 연결 제외 · 기존 보상 보존"
	if category.get("IsStackable") != true or int(item.get("Weight",-1)) != 0: return "원본 장비·무게 조건 연결 필요"
	var expiry := expiry_definition(int(item.ID))
	if expiry.has("error"): return str(expiry.error)
	if expiry.has("source_delete_clock") and runtime.local.source_clock() >= delete_clock(expiry): return "원본 아이템 삭제 시각이 지났습니다"
	if category.get("Name") not in ["Currency","StackableItem","ScrollBless","LinMarketProduct","IntangibleItemRecharger","ScrollBuffCardRetry","SelectReward"]: return "원본 아이템 분류 연결 필요"
	return ""

## Deletion clock that applies now: the source clock, or for a reward of a
## locally rotated monster book season, the source clock moved by the same
## number of season lengths (local_delete_clock).
static func delete_clock(item: Dictionary) -> String:
	return str(item.get("local_delete_clock", item.get("source_delete_clock", "")))

func _rotation_shift_seconds(item_id: int) -> int:
	var clock: String = runtime.local.source_clock()
	for book: Dictionary in runtime.catalog.books(false):
		var book_id := int(book.ID)
		var turn: int = runtime.catalog.rotation(book_id, clock)
		if turn <= 0: continue
		for stage: Dictionary in runtime.catalog.levels(book_id):
			for reward: Dictionary in stage.get("rewards", []):
				if int(reward.get("RewardTypeID", 0)) == 2 and int(reward.get("RewardClassID", 0)) == item_id:
					var period: Dictionary = runtime.catalog.raw_period(book_id)
					return turn * (runtime.catalog._clock_unix(runtime.catalog._clock(period.EndDateTimeID)) - runtime.catalog._clock_unix(runtime.catalog._clock(period.StartDateTimeID)))
	return 0

func expiry_definition(item_id: int) -> Dictionary:
	var result: Dictionary = {}
	for link: Dictionary in runtime.catalog.table_rows("ItemBonus"):
		if int(link.ItemClassID) != item_id: continue
		var bonus: Dictionary = runtime.catalog.row("Bonus",int(link.BonusID))
		var type: Dictionary = runtime.catalog.row("BonusType",int(bonus.get("BonusTypeID",-1)))
		if type.get("Name") != "DeleteTime": continue
		var application: Dictionary = runtime.catalog.row("BonusApplicationType",int(bonus.BonusApplicationTypeID))
		var date: Dictionary = runtime.catalog.row("DateTimes_Korean",int(bonus.BonusApplicationTargetID))
		if not result.is_empty() or application.get("Name") != "DateTime" or int(bonus.Value) != 0 or date.is_empty(): return {"error":"원본 절대 삭제 조건 자료 확인 필요"}
		var clock: String = runtime.catalog._clock(date)
		if not runtime.catalog.valid_clock(clock): return {"error":"원본 삭제 시각 형식 확인 필요"}
		result = {"source_delete_clock":clock,"source_expiry_bonus":bonus,"source_expiry_type":type,"source_expiry_application":application,"source_expiry_datetime":date}
	if result.has("source_delete_clock"):
		var shift := _rotation_shift_seconds(item_id)
		if shift > 0: result["local_delete_clock"] = runtime.catalog._unix_clock(runtime.catalog._clock_unix(str(result.source_delete_clock)) + shift)
	return result

func definition(reward: Dictionary) -> Dictionary:
	var item: Dictionary = runtime.catalog.row("ItemClass",int(reward.RewardClassID))
	var name: String = str(item.Name) + " [" + str(int(item.ID)) + "]"
	var grade: Dictionary = runtime.catalog.row("Grade",int(item.GradeID))
	var desc: Dictionary = runtime.catalog.row("DescData_Korean",int(grade.get("DescID",0)))
	var category: Dictionary = runtime.catalog.row("ItemCategory",int(item.CategoryID))
	var record: Dictionary = {"name":name,"source":"lineagem_patch523","source_snapshot":"cumulative523","sourceId":"m523:item:"+str(int(item.ID))+":normal","source_item_class_id":int(item.ID),"monsterbook_source_item":true,"source_original":item.duplicate(true),"source_reward":reward.duplicate(true),"slot":"currency" if category.get("Name") == "Currency" else "material","type":str(category.get("Name","")),"grade":str(desc.get("Description","원본")),"desc":"몬스터 도감 보상 · 원본 아이템 ID와 소유 상태 보존","weight":0,"tradeable":bool(item.IsTradable),"storable":bool(item.IsStorable),"droppable":bool(item.IsDroppable),"price":0,"source_use_pending":true}
	var expiry := expiry_definition(int(item.ID))
	if not expiry.has("error"): record.merge(expiry)
	if record.has("local_delete_clock"): record.desc += " · 삭제 " + str(record.local_delete_clock) + " (로컬 순환)"
	elif record.has("source_delete_clock"): record.desc += " · 원본 삭제 " + str(record.source_delete_clock)
	return record

func native_target(reward: Dictionary) -> Dictionary:
	return NATIVE.target(runtime,world,reward)

func settle(_before: Dictionary, proposed: Dictionary, quote: Dictionary, persist: Callable) -> bool:
	if quote.action not in ["claim_rewards", "claim"]: return false
	var records: Dictionary = proposed.get("source_items", {}).duplicate(true)
	var exp_gain: int = 0
	var raw_deltas: Dictionary={}
	var native_rewards: Array=[]
	for reward: Dictionary in quote.get("rewards", []):
		if not reward_problem(reward).is_empty(): return false
		if int(reward.RewardTypeID) == 1:
			var amount: int=runtime.economy.experience_amount(reward)
			if amount<1 or exp_gain>9007199254740991-amount:return false
			exp_gain += amount
			continue
		if not native_target(reward).is_empty():
			native_rewards.append(reward)
			continue
		var item := definition(reward)
		var name: String = item.name
		var existing: Dictionary = world._find_catalog_item_record(name)
		if not existing.is_empty() and existing.get("sourceId") != item.sourceId: return false
		# A legacy quantity without our source-qualified ownership proof is not merged.
		if int(world.inventory.get(name,0)) > 0 and not records.has(name): return false
		var count: int = int(world.inventory.get(name,0))+int(raw_deltas.get(name,0)) + int(reward.Amount)
		if int(reward.Amount) <= 0 or count > int(item.source_original.MaxStackAmount): return false
		raw_deltas[name]=int(raw_deltas.get(name,0))+int(reward.Amount)
		if not records.has(name) or records[name].get("sourceId") != item.sourceId: return false
	var native: Dictionary=NATIVE.stage(runtime,world,proposed,quote,native_rewards)
	if not native.get("ok",false):return false
	var overrides: Dictionary=native.overrides
	if not overrides.has("inventory"):overrides["inventory"]=world.inventory.duplicate(true)
	var inventory: Dictionary=overrides.inventory
	for name: String in raw_deltas:
		# Join raw-only deltas onto the supplier's full candidate. Never merge a
		# second baseline inventory over the native output or old raw ownership.
		if int(inventory.get(name,0))!=int(world.inventory.get(name,0)):return false
		inventory[name]=int(inventory.get(name,0))+int(raw_deltas[name])
	var projected: Dictionary = runtime.economy.experience_state(exp_gain) if exp_gain > 0 else {}
	overrides.merge(runtime.progression_overrides(exp_gain),false)
	if persist.call(proposed,overrides) != true: return false
	world.inventory = inventory
	if overrides.has("item_instances"):world.item_instances=overrides.item_instances
	if overrides.has("gold"):world.gold=int(overrides.gold)
	if overrides.has("consumable_state"):world.consumable_service.import_state(overrides.consumable_state)
	for key: String in projected: world.set(key,projected[key])
	world.deferred_save.cancel()
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
		world.item_weight_index[name] = 0
		var existing: Dictionary = world._find_catalog_item_record(name)
		if not existing.is_empty(): continue
		world.catalog_db["아이템"].append(item.duplicate(true))
		world.item_db.append(item.duplicate(true))
		world.catalog_item_by_source_id[item.sourceId] = item.duplicate(true)
		world.item_weight_index[name] = 0
		world.loot_catalog.get("by_name",{})[name] = item.duplicate(true)

func expire_owned() -> bool:
	if runtime.transaction_busy: return false
	runtime.transaction_busy = true
	var result := _expire_owned()
	runtime.transaction_busy = false
	return result

func _expire_owned() -> bool:
	if runtime.save_blocked or runtime.catalog._busy or not runtime.clock_authority.is_valid(): return false
	var clock: Variant = runtime.clock_authority.call()
	if not clock is String or not runtime.catalog.valid_clock(clock): return false
	var tracked: Dictionary = runtime.catalog.source_items()
	var due: Dictionary = {}
	for name: String in tracked:
		if tracked[name].has("source_delete_clock") and clock >= delete_clock(tracked[name]): due[name] = true
	if due.is_empty(): return true
	var present: bool = false
	for name: String in due:
		if int(world.inventory.get(name,0)) > 0: present = true
	if not present:
		for drop: Dictionary in world.ground_loot.records.values():
			if due.has(str(drop.get("item_name",""))): present = true
	if not present: return true
	var proposed: Dictionary = runtime.catalog.export_state()
	var inventory: Dictionary = world.inventory.duplicate(true)
	var archived: Dictionary = proposed.get("expired_items",{}).duplicate(true)
	var changed: bool = false
	var ground_remove: Array[String] = []
	var ground_keep: Array = []
	for name: String in proposed.get("source_items",{}):
		var record: Dictionary = proposed.source_items[name]
		var count: int = int(inventory.get(name,0))
		if count <= 0 or not record.has("source_delete_clock") or clock < str(record.source_delete_clock): continue
		var previous: Dictionary = archived.get(name,{"quantity":0,"sourceId":record.sourceId,"delete_clock":record.source_delete_clock})
		previous.quantity = int(previous.quantity)+count
		archived[name] = previous
		inventory.erase(name)
		changed = true
	for drop: Dictionary in world.ground_loot.records.values():
		var name: String = str(drop.get("item_name",""))
		var record: Dictionary = proposed.get("source_items",{}).get(name,{})
		if record.is_empty() or not record.has("source_delete_clock") or clock < str(record.source_delete_clock):
			ground_keep.append(drop.duplicate(true))
			continue
		var previous: Dictionary = archived.get(name,{"quantity":0,"sourceId":record.sourceId,"delete_clock":record.source_delete_clock})
		previous.quantity = int(previous.quantity)+int(drop.quantity)
		archived[name] = previous
		ground_remove.append(str(drop.id))
		changed = true
	if not changed: return true
	proposed["expired_items"] = archived
	var overrides: Dictionary = {"inventory":inventory}
	if not ground_remove.is_empty(): overrides["ground_drops"] = ground_keep
	if not runtime.catalog.valid_state(proposed) or not runtime.persist(proposed,overrides): return false
	world.inventory = inventory
	for id: String in ground_remove: world.ground_loot._remove(id)
	runtime.catalog.import_state(proposed)
	world._refresh_inventory_hud()
	return true

static func valid_record(name: String, item: Variant) -> bool:
	if not item is Dictionary or item.get("name") != name or item.get("source") != "lineagem_patch523" or item.get("source_snapshot") != "cumulative523" or item.get("monsterbook_source_item") != true or not item.get("source_original") is Dictionary or not item.get("source_reward") is Dictionary: return false
	var id: Variant = item.get("source_item_class_id")
	if not (id is int or id is float) or not is_finite(float(id)) or float(id) != floorf(float(id)) or int(id) <= 0: return false
	if item.get("sourceId") != "m523:item:"+str(int(id))+":normal" or int(item.source_original.get("ID",0)) != int(id) or int(item.source_reward.get("RewardClassID",0)) != int(id) or int(item.source_reward.get("RewardTypeID",0)) != 2: return false
	if name != str(item.source_original.get("Name",""))+" ["+str(int(id))+"]" or item.get("slot") not in ["currency","material"] or not item.get("source_use_pending") is bool: return false
	if item.get("weight") != 0 or item.get("price") != 0: return false
	if item.has("source_delete_clock"):
		if not item.source_delete_clock is String or not preload("res://scripts/monsterbook/monsterbook523_clock.gd").valid(item.source_delete_clock): return false
		for field: String in ["source_expiry_bonus","source_expiry_type","source_expiry_application","source_expiry_datetime"]:
			if not item.get(field) is Dictionary: return false
		if item.source_expiry_type.get("Name") != "DeleteTime" or item.source_expiry_application.get("Name") != "DateTime": return false
		if int(item.source_expiry_bonus.get("BonusTypeID",-1)) != int(item.source_expiry_type.get("ID",-2)) or int(item.source_expiry_bonus.get("BonusApplicationTypeID",-1)) != int(item.source_expiry_application.get("ID",-2)) or int(item.source_expiry_bonus.get("BonusApplicationTargetID",-1)) != int(item.source_expiry_datetime.get("ID",-2)) or item.source_expiry_bonus.get("Value") != 0: return false
		if item.has("local_delete_clock") and (not item.local_delete_clock is String or not preload("res://scripts/monsterbook/monsterbook523_clock.gd").valid(item.local_delete_clock) or item.local_delete_clock <= item.source_delete_clock): return false
		var date: Dictionary = item.source_expiry_datetime
		if item.source_delete_clock != "%04d%02d%02d%02d%02d" % [date.get("Year",0),date.get("Month",0),date.get("Day",0),date.get("Hour",0),date.get("Minute",0)]: return false
	return item.get("tradeable") == item.source_original.get("IsTradable") and item.get("storable") == item.source_original.get("IsStorable") and item.get("droppable") == item.source_original.get("IsDroppable")
