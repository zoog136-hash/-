extends RefCounted
## Supply/learning bridge only. Skill effects and learned IDs stay with the catalog.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const SPELLS = preload("res://scripts/resources/current523_spell_data.gd")
const PROFILES = preload("res://scripts/skills/player_skills523.gd")
const BINDINGS_PATH: String = "res://data/skills/player_skills523_bindings.json"
const ORIGIN: String = "TWILIGHT 기존 스킬 습득 연결 · 원본 각인 스택 보존 · 습득 후 재구매 차단"
static var source_problem: String = ""
static var source_identity: Dictionary = {}
static var _source_books: Dictionary = {}
static var _source_book_signature: String = ""

static func contract(item_id: int) -> Dictionary:
	return _contracts().get(str(item_id), {})

static func _contracts() -> Dictionary:
	# Port the existing build_source523_books.py joins to the held original.
	# Public bindings supply reviewed host identities, never native rule values.
	# The former generated book JSON is preserved on disk but is not a fallback.
	var identity: Dictionary = SOURCE.identity()
	if identity.is_empty():
		source_problem = SOURCE.problem()
		return {}
	var binding_text: String = FileAccess.get_file_as_string(BINDINGS_PATH)
	var signature: String = str(identity.source_sha256)+":"+binding_text.sha256_text()
	if signature == _source_book_signature:
		source_problem = ""
		return _source_books
	var reviewed: Variant = JSON.parse_string(binding_text)
	if not reviewed is Dictionary or reviewed.get("schema_version")!=1 or reviewed.get("patch")!=523 or reviewed.get("source_zip_sha256")!=SOURCE.SOURCE_SHA or not reviewed.get("skills") is Dictionary or not reviewed.get("class_ids") is Dictionary:
		source_problem = "원본 스킬북의 공개 기존 스킬·직업 ID 계약을 읽을 수 없습니다."
		return {}
	var reviewed_spells: Dictionary = {}
	for skill_id: String in reviewed.skills:
		var binding: Variant = reviewed.skills[skill_id]
		if not binding is Dictionary or not PROFILES._source_integer(binding.get("spell_id")) or not binding.get("row_sha256") is String:
			source_problem = "원본 스킬북의 기존 스킬 ID 계약이 잘못되었습니다: "+skill_id
			return {}
		var spell_id: int = int(binding.spell_id)
		var raw: Dictionary = SOURCE.row("SpellClass",spell_id)
		if raw.is_empty() or PROFILES._source_row_json(raw,str(binding.row_sha256)).is_empty() or reviewed_spells.has(spell_id):
			source_problem = "원본 스킬북의 기존 스킬 행·지문·단일 ID 계약이 다릅니다: "+skill_id
			return {}
		reviewed_spells[spell_id] = skill_id
	var books: Dictionary = {}
	for sale: Dictionary in SOURCE.related("MerchantGoods","MerchantsID",10):
		if int(sale.get("DialogActionTypeID",0))!=1 or not SOURCE.declared_exclusion("MerchantGoods",sale).is_empty():continue
		var item: Dictionary = SOURCE.row("ItemClass",int(sale.get("ItemClassID",-1)))
		var card: Dictionary = SOURCE.row("BuffCard",int(sale.get("LimitRepeatedBuyCardID",-1)))
		if item.is_empty() or item.get("TestItem")!=false or card.is_empty():continue
		if not SOURCE.declared_exclusion("ItemClass",item).is_empty() or not SOURCE.declared_exclusion("BuffCard",card).is_empty():continue
		var spell_id: int = int(card.get("SpellClassID",0))
		if not reviewed_spells.has(spell_id):continue
		var item_cards: Dictionary = {}
		var item_card_unavailable: bool = false
		for link: Dictionary in SOURCE.related("ItemBonus","ItemClassID",int(item.ID)):
			if link.get("IsPossession")!=false:continue
			var bonus: Dictionary = SOURCE.row("Bonus",int(link.get("BonusID",-1)))
			var type: Dictionary = SOURCE.row("BonusType",int(bonus.get("BonusTypeID",-1))) if not bonus.is_empty() else {}
			if bonus.is_empty() or type.is_empty():item_card_unavailable=true;break
			if type.get("Name")!="BuffCardID":continue
			var unit: Dictionary = SOURCE.row("Unit",int(type.get("UnitID",-1)))
			if unit.get("Name")!="BuffCardID" or not PROFILES._source_integer(bonus.get("Value")) or int(bonus.Value)<=0:item_card_unavailable=true;break
			if not SOURCE.declared_exclusion("ItemBonus",link).is_empty() or not SOURCE.declared_exclusion("Bonus",bonus).is_empty() or not SOURCE.declared_exclusion("BonusType",type).is_empty() or not SOURCE.declared_exclusion("Unit",unit).is_empty():item_card_unavailable=true;break
			item_cards[int(bonus.Value)] = true
		if item_card_unavailable or item_cards.size()!=1 or not item_cards.has(int(card.ID)):continue
		# This existing reader supplies current native learn-limit rows. Effects
		# remain reference-only; learning/debit stay with the existing catalog.
		var detail: Dictionary = SPELLS.describe(spell_id)
		if detail.get("excluded")==true or detail.get("spell_class",{}).get("TestSpell")!=false:continue
		var classes: Dictionary = {}
		for job: String in reviewed.class_ids:
			var limits: Array = []
			for entry: Dictionary in detail.get("learn_limits",[]):
				var limit: Dictionary = entry.get("link",{})
				if limit.get("ClassID")!=reviewed.class_ids[job] or limit.get("IsTutorialSpell")!=false or not SOURCE.declared_exclusion("SpellLearnLimit",limit).is_empty():continue
				limits.append({"minimum_level":limit.CharacterMinLevel,"required_card":limit.LimitBuffCardID,"polymorph_grade":limit.CharacterPolymorphGradeID})
			if not limits.is_empty():classes[job] = limits
		var label: Dictionary = SOURCE.row("DescData_Korean",int(item.get("DescID",0)))
		if not label.get("Description") is String or str(label.Description).is_empty():continue
		books[str(int(item.ID))] = {"name":str(label.Description),"card_id":int(card.ID),"spell_id":spell_id,"skill_id":str(reviewed_spells[spell_id]),"classes":classes,"source_definition_archive":identity.duplicate(true)}
	_source_books = books
	_source_book_signature = signature
	source_identity = identity.duplicate(true)
	source_problem = ""
	return _source_books

static func install(world, source) -> Dictionary:
	var bindings: Dictionary = {}
	if world.get("original_skills") == null:return bindings
	var catalog = world.original_skills.catalog
	var changed: bool = false
	var books: Dictionary = _contracts()
	for id: String in books:
		var spec: Dictionary = books[id]
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

## MerchantGoods.LimitRepeatedBuyCardID for an original 523 skill book that
## has no merchant-10 contract (e.g. 기란 혈맹 상인 린, merchant 91): the sold
## item must be a native skill book whose own BuffCard is that card; it is
## refused once the spell is learned (the existing "습득 후 재구매 차단"
## reading), and while its original learn limits (class, level) or the local
## skill identity do not hold - the same checks the book's use runs.
static func native_repeat_qualification(world, sale: Dictionary, record: Dictionary) -> Dictionary:
	var card_id: int = int(sale.get("LimitRepeatedBuyCardID",0))
	var profile: Dictionary = preload("res://scripts/loot/current523_native_stack.gd").profile(record)
	var spec: Dictionary = profile.get("spec",{})
	if profile.get("kind")!="skill_book" or int(spec.get("card_id",-1))!=card_id:return {"ok":false,"reason":"반복 구매 카드와 원본 스킬서의 카드가 다릅니다"}
	if world.get("original_skills")==null:return {"ok":false,"reason":"스킬 소유자 없음"}
	var BOOK: Script = preload("res://scripts/loot/patch523_skill_book.gd")
	var limit: String = BOOK.source_limit_problem(world,spec)
	if not limit.is_empty():return {"ok":false,"reason":limit}
	var catalog = world.original_skills.catalog
	var identity: Dictionary = BOOK.resolve(BOOK._adapter(catalog),spec)
	if identity.is_empty():return {"ok":false,"reason":"원본 주문의 기존 스킬 연결 없음"}
	var reason: String = catalog.reason(catalog.record_for(str(identity.local_skill_id)),true)
	return {"ok":reason.is_empty(),"reason":reason,"origin":ORIGIN}
