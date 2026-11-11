extends RefCounted
## Current original definitions only. Persisted m508/m523 keys are caller ABI,
## never evidence that these definition bytes came from the former card pack.
const Source = preload("res://scripts/resources/current523_definition_rows.gd")
# Existing reviewed typed namespace policy, not a match on equal numeric IDs.
const BOOK_DECKS := {
	"PolymorphAwakenSkillEnchantProbGroupID":1,
	"MagicDollAwakenSkillEnchantProbGroupID":2,
	"HolyStuffAwakenSkillEnchantProbGroupID":98,
}
const GROUP_UNIT := "BuffCardSkillAwakenSkillEnchantProbGroupID"
const POOL_TABLE := "BuffCardSkillAwakenSkillEnchantProb"
const GROUP_TABLE := "BuffCardSkillAwakenSkillEnchantProbGroup"
const LEVEL_TABLES := ["BuffCardSkillAwakenStat","BuffCardSkillAwakenStatPerLevel","BuffCardSkillAwakenSkillInvokeProb","BuffCardSkillAwakenExp"]

static func build(catalog: Dictionary) -> Dictionary:
	var data: Dictionary={"schema":1,"source_snapshot":"patch523","source_definition_archive":{},"cards":{},"tables":{},"books":[],"spells":{},"source_server_limits":[],"unknown_rules":["경험치 재료별 획득량·소모·강화 처리 규칙은 미확정입니다.","각성서 수량·비용·재각성 초기화는 기존 명시적 사용자 정책입니다.","새 원문 각성서의 물리 개체·거래·저장은 통합 소유자의 current523 출처 계약 채택이 필요합니다."],"problem":"","input_problems":[]}
	var archive: Dictionary=Source.identity()
	if archive.is_empty():
		_problem(data,Source.problem())
		return data
	data.source_definition_archive=archive
	_cards(data,catalog)
	for table: String in LEVEL_TABLES:
		var selected: Array[Dictionary]=[]
		for row: Dictionary in Source.rows(table):
			if _excluded(table,row):continue
			if table=="BuffCardSkillAwakenSkillInvokeProb" and (not _integer(row.get("CastSuccessProb")) or not _integer(row.get("CastTotalProb")) or int(row.CastTotalProb)!=10000 or int(row.CastSuccessProb)<0 or int(row.CastSuccessProb)>10000):
				_problem(data,"원본 발동 확률이 기존 10000 실행 계약과 다릅니다: BuffCardSkillAwakenSkillInvokeProb#"+str(row.get("ID","")))
				continue
			selected.append(row)
		data.tables[table]=selected
		if selected.is_empty():_problem(data,"원본 스킬 각성 레벨 입력 없음: "+table)
	_books(data)
	if data.cards.is_empty():_problem(data,"새 원문 카드 카탈로그의 정확한 ID·덱 입력이 없습니다. 기존 저장은 보존합니다.")
	return data

static func _cards(data: Dictionary,catalog: Dictionary) -> void:
	var limits: Dictionary={}
	for category: String in catalog:
		if not catalog[category] is Array:continue
		for record: Variant in catalog[category]:
			if not record is Dictionary:continue
			var supplied: Variant=record.get("source_original_card")
			if not supplied is Dictionary or record.get("source_snapshot")!="patch523" or record.get("source_content_snapshot")!="patch523":continue
			if record.get("source_definition_archive",{}).get("source_sha256")!=Source.SOURCE_SHA:continue
			if not _integer(supplied.get("ID")) or not _integer(supplied.get("BuffCardDeckID")):continue
			var raw: Dictionary=Source.row("BuffCard",int(supplied.ID))
			if raw.is_empty() or raw!=supplied or _excluded("BuffCard",raw):continue
			if int(record.get("source_card_id",-1))!=int(raw.ID) or int(record.get("source_deck_id",-1))!=int(raw.BuffCardDeckID):continue
			var source_id: String=str(record.get("sourceId",""))
			var parts: PackedStringArray=source_id.split(":")
			if parts.size()!=3 or parts[0] not in ["m508","m523"] or parts[1]!=str(int(raw.BuffCardDeckID)) or parts[2]!=str(int(raw.ID)):continue
			var identity: String="source:"+source_id
			if data.cards.has(identity):
				_problem(data,"새 원문 각성 카드 ID 중복: "+identity)
				continue
			data.cards[identity]={"id":identity,"category":category,"name":str(record.get("name","")),"grade":str(record.get("grade","")),"source_card":raw,"source_snapshot":"patch523","source_content_snapshot":"patch523","source_definition_archive":data.source_definition_archive.duplicate(true)}
			limits[int(raw.ServerLimitSetID)]=true
	for limit: int in limits:
		if limit==0:continue
		for row: Dictionary in Source.related("ServerLimit","ServerLimitSetID",limit):
			if not _excluded("ServerLimit",row):data.source_server_limits.append(row)

static func _books(data: Dictionary) -> void:
	var by_key: Dictionary={}
	var ambiguous: Dictionary={}
	for type: Dictionary in Source.rows("BonusType"):
		if not BOOK_DECKS.has(str(type.get("Name",""))) or _excluded("BonusType",type):continue
		var unit: Dictionary=Source.row("Unit",int(type.UnitID))
		if unit.get("Name")!=GROUP_UNIT or _excluded("Unit",unit):
			_problem(data,"원본 각성서 그룹 참조 Unit 계약 불일치: "+str(type.Name))
			continue
		var deck: int=int(BOOK_DECKS[type.Name])
		for bonus: Dictionary in Source.related("Bonus","BonusTypeID",int(type.ID)):
			if _excluded("Bonus",bonus) or not _integer(bonus.get("Value")) or int(bonus.Value)<=0:continue
			if int(bonus.BonusApplicationTypeID)!=0 or int(bonus.BonusApplicationTargetID)!=0:continue
			# A typed Bonus without an ItemBonus is not an available book.
			for item_link: Dictionary in Source.related("ItemBonus","BonusID",int(bonus.ID)):
				if _excluded("ItemBonus",item_link) or item_link.get("IsPossession")!=false:continue
				var item: Dictionary=Source.row("ItemClass",int(item_link.ItemClassID))
				if item.is_empty() or _excluded("ItemClass",item):continue
				var group: Dictionary=Source.row(GROUP_TABLE,int(bonus.Value))
				if group.is_empty() or _excluded(GROUP_TABLE,group):
					_problem(data,"원본 각성서의 그룹 참조 없음: Bonus#"+str(int(bonus.ID)))
					continue
				var pool: Dictionary=_pool(data,deck,group)
				if pool.is_empty():continue
				var key: String=str(deck)+":"+str(int(group.GradeID))
				if ambiguous.has(key):continue
				if by_key.has(key):
					# The existing service accepts one exact book per deck/grade.
					# Do not choose an ownership alias or silently discard a variant.
					by_key.erase(key)
					ambiguous[key]=true
					_problem(data,"각성서 덱·등급의 복수 원문 공급 계약 확인 필요: "+key)
					continue
				by_key[key]={"item_row":item,"item_bonus_row":item_link,"bonus_row":bonus,"bonus_type_row":type,"unit_row":unit,"target_deck_from_named_bonus_type":deck,"group_row":group,"pool_rows":pool.rows,"pool_weight_sum":100000,"spell_ids":pool.spell_ids,"name":_label(item),"source_snapshot":"patch523","source_definition_archive":data.source_definition_archive.duplicate(true),"saved_identity_namespace":"m508","saved_item_source_id":"m508:item:"+str(int(item.ID))}
	for key: String in by_key:data.books.append(by_key[key])

static func _pool(data: Dictionary,deck: int,group: Dictionary) -> Dictionary:
	var rows: Array[Dictionary]=Source.related(POOL_TABLE,"GroupID",int(group.ID))
	var total: int=0
	var spell_ids: Array[int]=[]
	if rows.is_empty():
		_problem(data,"원본 스킬 각성 후보 입력 없음: group#"+str(int(group.ID)))
		return {}
	for row: Dictionary in rows:
		if _excluded(POOL_TABLE,row) or not _integer(row.get("Prob")) or int(row.Prob)<0 or int(row.BuffCardDeckID)!=deck or int(row.SpellClassID)<=0:
			_problem(data,"원본 스킬 각성 후보의 덱·확률·제외 계약 불일치: group#"+str(int(group.ID)))
			return {}
		total+=int(row.Prob)
		var spell_id: int=int(row.SpellClassID)
		if not data.spells.has(str(spell_id)):
			var spell: Dictionary=_spell(spell_id)
			if spell.is_empty():
				_problem(data,"원본 스킬 각성 후보의 SpellClass→SpellBonus 계약 없음 또는 제외: "+str(spell_id))
				return {}
			data.spells[str(spell_id)]=spell
		spell_ids.append(spell_id)
	if total!=100000:
		_problem(data,"원본 스킬 각성 후보 확률 합계가 기존 100000 실행 계약과 다릅니다: group#"+str(int(group.ID)))
		return {}
	return {"rows":rows,"spell_ids":spell_ids}

static func _spell(id: int) -> Dictionary:
	var raw: Dictionary=Source.row("SpellClass",id)
	if raw.is_empty() or _excluded("SpellClass",raw):return {}
	var effects: Array[Dictionary]=[]
	for link: Dictionary in Source.related("SpellBonus","SpellClassID",id):
		if _excluded("SpellBonus",link):return {}
		var bonus: Dictionary=Source.row("Bonus",int(link.BonusID))
		if bonus.is_empty() or _excluded("Bonus",bonus):return {}
		var type: Dictionary=Source.row("BonusType",int(bonus.BonusTypeID))
		if type.is_empty() or _excluded("BonusType",type):return {}
		var unit: Dictionary=Source.row("Unit",int(type.UnitID))
		if unit.is_empty() or _excluded("Unit",unit):return {}
		effects.append({"link":link,"bonus":bonus,"type":type,"unit":unit})
	return {"source_spell":raw,"name":_label(raw),"effects":effects,"source_snapshot":"patch523","source_definition_archive":Source.identity()}

static func _label(row: Dictionary) -> String:
	var description: Dictionary=Source.row("DescData_Korean",int(row.get("DescID",0))) if int(row.get("DescID",0))>0 else {}
	return str(description.get("Description",row.get("Name","")))

static func _excluded(table: String,row: Dictionary) -> bool:
	if table=="ItemClass" and row.get("TestItem")==true:return true
	if table=="SpellClass" and row.get("TestSpell")==true:return true
	return not Source.declared_exclusion(table,row).is_empty()

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func _problem(data: Dictionary,message: String) -> void:
	if message.is_empty():message="새 원문 스킬 각성 입력을 읽을 수 없습니다. 기존 저장은 보존합니다."
	if data.problem.is_empty():data.problem=message
	if not message in data.input_problems:data.input_problems.append(message)

