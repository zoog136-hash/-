extends RefCounted
## Supply/learning bridge only. Skill effects and learned IDs stay with the catalog.
const DATA = preload("res://data/shop/source523_skill_books.json")
const ORIGIN: String = "TWILIGHT 기존 스킬 습득 연결 · 원본 각인 스택 보존 · 습득 후 재구매 차단"

static func contract(item_id: int) -> Dictionary:
	return DATA.data.books.get(str(item_id), {})

static func install(world, source) -> Dictionary:
	var bindings: Dictionary = {}
	if world.get("original_skills") == null:return bindings
	var catalog = world.original_skills.catalog
	var changed: bool = false
	for id: String in DATA.data.books:
		var spec: Dictionary = DATA.data.books[id]
		var item: Dictionary = source.record("ItemClass",int(id))
		var card: Dictionary = source.record("BuffCard",int(spec.card_id))
		var skill: Dictionary = catalog.record_for(str(spec.skill_id))
		if item.is_empty() or item.get("TestItem",true) or source.label(int(item.get("DescID",0))) != spec.name or int(card.get("SpellClassID",0)) != int(spec.spell_id):continue
		if skill.is_empty() or skill.get("runtime_blocked",false):continue
		if int(card.get("ServerLimitSetID",0))!=0 or int(card.get("StartDateTimeID",0))!=0 or int(card.get("EndDateTimeID",0))!=0:continue
		var name: String = str(spec.name)
		var record: Dictionary = world._find_catalog_item_record(name)
		var fresh: bool=record.is_empty()
		if not record.is_empty() and (record.get("source") != "twilight-shop523-book" or int(record.get("source_item_class_id",0)) != int(id) or record.get("source_bless_raw") != 1):continue
		if record.is_empty():
			record = {"name":name,"grade":"일반","slot":"consumable","type":"스킬북","source":"twilight-shop523-book","source_item_class_id":int(id),"source523_shop_item_id":int(id),"source_bless_raw":1,"source_skill_id":str(spec.skill_id),"source_spell_id":int(spec.spell_id),"source523_shop_use_origin":ORIGIN,"desc":str(skill.name)+" 습득 · "+ORIGIN,"weight":3}
		record.merge({"source_weight_raw":item.get("Weight",0),"source_max_stack":int(item.get("MaxStackAmount",0)),"droppable":item.get("IsDroppable",false),"storable":item.get("IsStorable",false),"source_is_tradable":item.get("IsTradable",false)},true)
		if fresh:
			world.item_db.append(record.duplicate(true));world.catalog_db["아이템"].append(record);changed=true
		bindings["4:"+id] = {"name":name,"record":record.duplicate(true)}
	if changed:world._index_item_weights()
	return bindings

static func registered(world, name: String, skill_id: String) -> bool:
	var record: Dictionary = world._find_catalog_item_record(name)
	var spec: Dictionary = contract(int(record.get("source_item_class_id",0)))
	return not spec.is_empty() and spec.skill_id == skill_id and spec.name == name and record.get("source") == "twilight-shop523-book" and record.get("source_skill_id") == skill_id and int(record.get("source_spell_id",0)) == int(spec.spell_id) and record.get("source_bless_raw") == 1 and record.get("slot") == "consumable"

static func learn_reason(world, spec: Dictionary) -> String:
	if spec.is_empty():return "스킬북 연결 없음"
	var limits: Array = spec.classes.get(str(world.job_class),[])
	if limits.is_empty():return "원본 스킬북 직업 조건 미충족"
	for limit: Dictionary in limits:
		if int(world.level)>=int(limit.minimum_level) and int(limit.required_card)==0 and int(limit.polymorph_grade)==0:return ""
	return "원본 스킬북 레벨·선행 카드·변신 등급 조건 미충족 또는 미연결"

static func qualification(world, sale: Dictionary) -> Dictionary:
	var spec: Dictionary = contract(int(sale.get("ItemClassID",0)))
	if spec.is_empty() or int(sale.get("LimitRepeatedBuyCardID",0)) != int(spec.card_id):return {"ok":false,"reason":"반복 구매 카드와 기존 스킬의 정확한 연결 필요"}
	if not registered(world,str(spec.name),str(spec.skill_id)):return {"ok":false,"reason":"스킬북 소비자 등록·정체 확인 필요"}
	var native_reason: String = learn_reason(world,spec)
	if not native_reason.is_empty():return {"ok":false,"reason":native_reason}
	var catalog = world.original_skills.catalog
	var skill: Dictionary = catalog.record_for(str(spec.skill_id))
	var reason: String = catalog.reason(skill,true)
	return {"ok":reason.is_empty(),"reason":reason,"origin":ORIGIN}

static func try_use(world, name: String) -> bool:
	var record: Dictionary = world._find_catalog_item_record(name)
	if record.get("source") != "twilight-shop523-book":return false
	var id: String = str(record.get("source_skill_id",""))
	if not registered(world,name,id):world.hud.show_message("스킬북 원본 정체 불일치 · 보존");return true
	var reason: String = learn_reason(world,contract(int(record.source_item_class_id)))
	if not reason.is_empty():world.hud.show_message(reason);return true
	world.original_skills.catalog.learn(id,name)
	return true
