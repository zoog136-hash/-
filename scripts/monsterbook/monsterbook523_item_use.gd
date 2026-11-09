extends RefCounted
## Original item -> bonus -> reward/product -> exact output joins.
## Only missing mystery odds use the separately labelled local configuration.
const Cards = preload("res://scripts/card_draw_fusion.gd")
var _runtime: WeakRef
var runtime: RefCounted:
	get: return _runtime.get_ref() if _runtime != null else null
var world: Node
var rng := RandomNumberGenerator.new()
var spec_cache: Dictionary = {}

func configure(owner_runtime: RefCounted, owner_world: Node) -> void:
	_runtime = weakref(owner_runtime)
	world = owner_world
	rng.randomize()

func effects(item_id: int) -> Dictionary:
	var result: Dictionary = {}
	for link: Dictionary in runtime.catalog.table_rows("ItemBonus"):
		if int(link.ItemClassID) != item_id: continue
		var bonus: Dictionary = runtime.catalog.row("Bonus",int(link.BonusID))
		var type: Dictionary = runtime.catalog.row("BonusType",int(bonus.BonusTypeID))
		if int(bonus.BonusApplicationTypeID) != 0 or int(bonus.BonusApplicationTargetID) != 0: continue
		if result.has(str(type.Name)): return {}
		result[str(type.Name)] = int(bonus.Value)
	return result

func spec(record: Dictionary) -> Dictionary:
	var pool_size: int = 0
	for category: String in Cards.CATEGORIES: pool_size += world.card_draw_fusion.known_ids.get(category,{}).size()
	var stamp: String = runtime.catalog.pack_sha+":"+str(record.get("source_item_class_id",0))+":"+str(world.level)+":"+str(hash(runtime.economy.settings))+":"+str(pool_size)
	var key: String = str(record.get("source_item_class_id",0))
	if spec_cache.get(key,{}).get("stamp","") == stamp: return spec_cache[key].value.duplicate(true)
	var result := _build_spec(record)
	if not result.has("error"): spec_cache[key] = {"stamp":stamp,"value":result.duplicate(true)}
	return result

func _build_spec(record: Dictionary) -> Dictionary:
	var source: Dictionary = record.get("source_original",{})
	if source.is_empty(): return {"error":"원본 아이템 정의 필요"}
	if world.level < int(source.LevelLimitMin) or (int(source.LevelLimitMax) > 0 and world.level > int(source.LevelLimitMax)): return {"error":"원본 아이템 사용 레벨 조건 미달"}
	var values := effects(int(source.ID))
	if values.has("SelectRewardClassID"):
		var root: Dictionary = runtime.catalog.row("Reward",int(values.SelectRewardClassID))
		var group: Dictionary = runtime.catalog.row("SelectReward",int(root.get("RewardClassID",0)))
		if int(root.get("RewardTypeID",0)) != 111 or int(group.get("SelectMaxCount",0)) != 1: return {"error":"원본 선택 보상 연결 필요"}
		var choices: Array = []
		for link: Dictionary in runtime.catalog.table_rows("SelectRewardEntity"):
			if int(link.SelectRewardID) == int(group.ID): choices.append(runtime.catalog.row("Reward",int(link.RewardID)))
		return {"kind":"select","choices":choices,"label":"원본 구성품 1종 선택"} if not choices.is_empty() else {"error":"원본 선택 구성품 필요"}
	if values.has("MarketPurchaseID"):
		if runtime.catalog.row("MarketPurchase_Korean",int(values.MarketPurchaseID)).is_empty(): return {"error":"원본 상품 참조 자료 필요"}
		var products: Array = []
		for extra: Dictionary in runtime.catalog.table_rows("MarketBonusForPurchase"):
			if int(extra.MarketPurchaseID) == int(values.MarketPurchaseID): return {"error":"원본 추가 상품 연결 필요"}
		for link: Dictionary in runtime.catalog.table_rows("MarketPurchaseProduct"):
			if int(link.MarketPurchaseID) != int(values.MarketPurchaseID): continue
			var product: Dictionary = runtime.catalog.row("MarketProduct",int(link.MarketProductID))
			if runtime.catalog.row("Unit",int(product.get("UnitID",0))).get("Name") != "GotChaClassID" or int(product.get("Amount",0)) <= 0: return {"error":"원본 카드 상품 유형 연결 필요"}
			for extra: Dictionary in runtime.catalog.table_rows("MarketProductAdditional"):
				if int(extra.MarketProductID) == int(product.ID): return {"error":"원본 부가 상품 연결 필요"}
			var pool: Array = []
			var weight: int = 0
			for entry: Dictionary in runtime.catalog.table_rows("GotChaEntityView"):
				if int(entry.GotChaClassID) != int(product.ClassID) or int(entry.Probability) <= 0: continue
				if runtime.catalog.row("Unit",int(entry.UnitID)).get("Name") != "BuffCardID" or runtime.catalog.row("BuffCard",int(entry.ClassID)).is_empty(): return {"error":"원본 카드 추첨 참조 필요"}
				pool.append(entry)
				weight += int(entry.Probability)
			if weight != 1000000: return {"error":"원본 카드 확률 합계 확인 필요"}
			products.append({"source":product,"pool":pool,"weight":weight})
		var draws: int = 0
		for product: Dictionary in products: draws += int(product.source.Amount)
		return {"kind":"pack","products":products,"label":"원본 %d장 · 카드별 원본 확률" % draws} if not products.is_empty() else {"error":"원본 카드 상품 연결 필요"}
	if values.has("IntangibleItemClassID"):
		if runtime.catalog.row("IntangibleItemClass",int(values.IntangibleItemClassID)).get("Name") != "BlessPoint" or int(values.get("IntangibleItemAmount",0)) <= 0: return {"error":"원본 무형 재화 연결 필요"}
		return {"kind":"points","amount":int(values.IntangibleItemAmount),"label":"원본 축복 포인트 +%d" % int(values.IntangibleItemAmount)}
	if values.has("GradeID") and values.has("BuffDeckID"):
		var category := category_for_deck(int(values.BuffDeckID))
		var grade: Dictionary = runtime.catalog.row("Grade",int(values.GradeID))
		var grade_label: Dictionary = runtime.catalog.row("DescData_Korean",int(grade.get("DescID",0)))
		if category.is_empty() or grade_label.get("Description") != "희귀": return {"error":"원본 미스터리 카드 덱·등급 연결 필요"}
		var hero: int = int(runtime.economy.settings.get("mystery_hero_weight_per_10000",-1))
		if hero < 0 or hero > 10000: return {"error":"미스터리 자체 확률 설정 확인 필요"}
		for title: String in ["희귀","영웅"]:
			if _mystery_pool(category,title).is_empty(): return {"error":"현재 카드 추첨 풀 필요"}
		var pool_label: String = "현재 원본의 제한 없는 카드" if runtime.economy.settings.get("mystery_pool_policy","current_unrestricted_pack_cards") == "current_unrestricted_pack_cards" else "기존 게임 카드"
		return {"kind":"mystery","category":category,"hero_weight":hero,"label":"자체 확률 · 영웅 %.2f%% / 희귀 %.2f%% · 선택 등급 내 동일 확률 · %s" % [float(hero)/100.0,float(10000-hero)/100.0,pool_label]}
	return {"error":"이 아이템의 사용은 해당 제작·상점·강화 화면에서 연결됩니다"}

func _mystery_pool(category: String, grade: String) -> Array:
	var policy: String = str(runtime.economy.settings.get("mystery_pool_policy","current_unrestricted_pack_cards"))
	var existing: Array = world.card_draw_fusion.pools.get(category,{}).get(grade,[])
	if policy == "existing_game_pool": return existing
	if policy != "current_unrestricted_pack_cards": return []
	var result: Array = []
	for entry: Dictionary in existing:
		var raw: Dictionary = runtime.catalog.row("BuffCard",int(entry.record.get("source_card_id",0)))
		if not raw.is_empty() and int(raw.ServerLimitSetID) == 0 and int(raw.StartDateTimeID) == 0 and int(raw.EndDateTimeID) == 0: result.append(entry)
	return result

func category_for_deck(deck_id: int) -> String:
	for category: String in Cards.CATEGORIES:
		for row: Dictionary in world.catalog_db.get(category,[]):
			if int(row.get("source_deck_id",-1)) == deck_id: return category
	return ""

func _award(card_id: int, state: Dictionary, results: Array) -> bool:
	var raw: Dictionary = runtime.catalog.row("BuffCard",card_id)
	# A server-limited card is awarded when its original set names the current
	# server profile (declared context, else offline Korean world 1).
	if raw.is_empty() or not preload("res://scripts/loot/current523_server_profile.gd").allows(world,raw.ServerLimitSetID).ok or int(raw.StartDateTimeID) != 0 or int(raw.EndDateTimeID) != 0: return false
	var category := category_for_deck(int(raw.BuffCardDeckID))
	if category.is_empty(): return false
	var identity: String = ""
	var title: String = str(raw.Name)
	var grade_row: Dictionary = runtime.catalog.row("Grade",int(raw.GradeID))
	var grade: String = str(runtime.catalog.row("DescData_Korean",int(grade_row.get("DescID",0))).get("Description",grade_row.get("Name","")))
	for record: Dictionary in world.catalog_db.get(category,[]):
		if int(record.get("source_card_id",-1)) != card_id: continue
		identity = Cards.card_id(record)
		title = str(record.name)
		grade = str(record.grade)
		break
	var deferred: bool = identity.is_empty()
	if deferred: identity = "source:m523:%d:%d" % [int(raw.BuffCardDeckID),card_id]
	var owned: Dictionary = state.owned[category]
	var spare: Dictionary = state.spare[category]
	if deferred:
		var preserved: Dictionary = state.get("preserved_unmapped_collection",{}).duplicate(true)
		var pending: Dictionary = preserved.get(category,{"owned":{},"spare":{}})
		owned = pending.owned
		spare = pending.spare
		preserved[category] = pending
		state["preserved_unmapped_collection"] = preserved
	var fresh: bool = not owned.get(identity,false)
	if not fresh and int(spare.get(identity,0)) >= 1000000: return false
	if fresh: owned[identity] = true
	else: spare[identity] = int(spare.get(identity,0))+1
	results.append({"kind":"card","card_id":card_id,"category":category,"identity":identity,"name":title,"grade":grade,"new":fresh,"deferred":deferred})
	return true

func reconcile_owned() -> bool:
	if runtime.transaction_busy: return false
	runtime.transaction_busy = true
	var result := _reconcile_owned()
	runtime.transaction_busy = false
	return result

func _reconcile_owned() -> bool:
	if runtime.save_blocked or runtime.catalog._busy: return false
	var ready: bool = false
	for category: String in Cards.CATEGORIES:
		for identity: String in world.card_draw_fusion.preserved_unmapped_collection.get(category,{}).get("owned",{}):
			if identity.begins_with("source:m523:") and world.card_draw_fusion.known_ids.get(category,{}).has(identity): ready = true
	if not ready: return true
	var cards: Dictionary = world.card_draw_fusion.export_state()
	var changed: bool = false
	for category: String in Cards.CATEGORIES:
		var pending: Dictionary = cards.get("preserved_unmapped_collection",{}).get(category,{})
		for identity: String in pending.get("owned",{}).keys():
			if not identity.begins_with("source:m523:") or pending.owned[identity] != true or not world.card_draw_fusion.known_ids.get(category,{}).has(identity): continue
			var additional: int = int(pending.get("spare",{}).get(identity,0)) + (1 if cards.owned[category].get(identity,false) else 0)
			if int(cards.spare[category].get(identity,0))+additional > 1000000: continue
			cards.owned[category][identity] = true
			if additional > 0: cards.spare[category][identity] = int(cards.spare[category].get(identity,0))+additional
			pending.owned.erase(identity)
			pending.get("spare",{}).erase(identity)
			changed = true
	if not changed: return true
	var proposed: Dictionary = runtime.catalog.export_state()
	for result: Dictionary in proposed.get("item_actions",{}).get("last_results",[]):
		if result.get("deferred",false) and cards.get("owned",{}).get(str(result.get("category","")),{}).get(str(result.get("identity","")),false): result.deferred = false
	if not runtime.persist(proposed,{"card_draw_fusion":cards}): return false
	world.card_draw_fusion.import_state(cards)
	runtime.catalog.import_state(proposed)
	world._update_hud()
	return true

func use(name: String, choice: int = 0) -> Dictionary:
	if runtime.transaction_busy: return {"ok":false,"message":"도감 거래 처리 중"}
	runtime.transaction_busy = true
	var result := _use(name,choice)
	runtime.transaction_busy = false
	return result

func _use(name: String, choice: int = 0) -> Dictionary:
	if runtime.save_blocked or runtime.catalog._busy: return {"ok":false,"message":"저장 보호 중"}
	var proposed: Dictionary = runtime.catalog.export_state()
	var record: Dictionary = proposed.get("source_items",{}).get(name,{})
	if not runtime.items.valid_record(name,record) or int(world.inventory.get(name,0)) <= 0: return {"ok":false,"message":"보유 아이템이 없습니다"}
	var clock: String = runtime.local.source_clock()
	if record.has("source_delete_clock") and clock >= preload("res://scripts/monsterbook/monsterbook523_items.gd").delete_clock(record): return {"ok":false,"message":"원본 삭제 시각이 지났습니다"}
	var action := spec(record)
	if action.has("error"): return {"ok":false,"message":str(action.error)}
	var inventory: Dictionary = world.inventory.duplicate(true)
	var cards: Dictionary = world.card_draw_fusion.export_state()
	var growth: Dictionary = world.growth.state.duplicate(true)
	var ledger: Dictionary = proposed.get("item_actions",{"schema":1,"sequence":0,"last_results":[]}).duplicate(true)
	if ledger.has("rng_state"): rng.state = int(ledger.rng_state)
	var before_rng: int = rng.state
	var results: Array = []
	var error: String = ""
	match str(action.kind):
		"select":
			var selected: Dictionary = {}
			for reward: Dictionary in action.choices:
				if int(reward.ID) == choice: selected = reward
			if selected.is_empty() or int(selected.RewardTypeID) != 2: error = "원본 구성품을 선택하세요"
			elif not runtime.items.reward_problem(selected).is_empty(): error = runtime.items.reward_problem(selected)
			else:
				var output: Dictionary = runtime.items.definition(selected)
				var quantity: int = int(inventory.get(output.name,0))+int(selected.Amount)
				if quantity > int(output.source_original.MaxStackAmount): error = "원본 스택 상한 초과"
				elif int(inventory.get(output.name,0)) > 0 and not proposed.source_items.has(output.name): error = "기존 아이템 정체성 확인 필요"
				else:
					inventory[output.name] = quantity
					proposed.source_items[output.name] = output
					results.append({"kind":"item","name":output.name,"amount":int(selected.Amount)})
		"points":
			growth.points = int(growth.points)+int(action.amount)
			growth.revision = int(growth.revision)+1
			error = world.growth.validate(growth)
			results.append({"kind":"points","amount":int(action.amount)})
		"pack":
			for product: Dictionary in action.products:
				for draw: int in range(int(product.source.Amount)):
					var roll: int = rng.randi_range(0,int(product.weight)-1)
					var card_id: int = 0
					for entry: Dictionary in product.pool:
						roll -= int(entry.Probability)
						if roll < 0: card_id = int(entry.ClassID); break
					if card_id <= 0 or not _award(card_id,cards,results): error = "원본 카드 수령 참조 확인 필요"; break
		"mystery":
			var grade: String = "영웅" if rng.randi_range(0,9999) < int(action.hero_weight) else "희귀"
			var pool: Array = _mystery_pool(str(action.category),grade)
			var entry: Dictionary = pool[rng.randi_range(0,pool.size()-1)]
			var owned: Dictionary = cards.owned[action.category]
			var fresh: bool = not owned.get(entry.id,false)
			if fresh: owned[entry.id] = true
			elif int(cards.spare[action.category].get(entry.id,0)) >= 1000000: error = "중복 카드 보관 상한 초과"
			else: cards.spare[action.category][entry.id] = int(cards.spare[action.category].get(entry.id,0))+1
			results.append({"kind":"card","card_id":int(entry.record.get("source_card_id",0)),"category":action.category,"identity":entry.id,"name":entry.record.name,"grade":grade,"new":fresh,"deferred":false})
	if not error.is_empty(): rng.state = before_rng; return {"ok":false,"message":error}
	inventory[name] = int(inventory[name])-1
	if int(inventory[name]) <= 0: inventory.erase(name)
	ledger.sequence = int(ledger.sequence)+1
	var used: Dictionary = ledger.get("used",{}).duplicate(true)
	used[str(int(record.source_item_class_id))] = int(used.get(str(int(record.source_item_class_id)),0))+1
	ledger["used"] = used
	ledger["rng_state"] = str(rng.state)
	ledger.last_results = results
	ledger["last_source_item"] = int(record.source_item_class_id)
	ledger["last_policy"] = str(action.label)
	ledger["last_clock"] = clock
	proposed["item_actions"] = ledger
	var overrides: Dictionary = {"inventory":inventory}
	if action.kind in ["pack","mystery"]: overrides["card_draw_fusion"] = cards
	if action.kind == "points": overrides["growth"] = growth
	if not runtime.catalog.valid_state(proposed) or not runtime.persist(proposed,overrides): rng.state = before_rng; return {"ok":false,"message":"저장 실패 · 아이템·카드·재화 유지"}
	world.inventory = inventory
	if overrides.has("card_draw_fusion"): world.card_draw_fusion.import_state(cards)
	if overrides.has("growth"): world.growth.state = growth; world.growth._rebuild()
	runtime.catalog.import_state(proposed)
	world._invalidate_equipment_static()
	world._update_hud()
	world._refresh_inventory_hud()
	return {"ok":true,"message":"아이템 사용 완료 · " + str(action.label),"results":results}
