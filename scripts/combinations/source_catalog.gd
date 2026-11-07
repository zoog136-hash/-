extends RefCounted
## Imports a user-selected private Content archive. Original rows stay outside Git.
const COUNTS: Dictionary={"Combination":62,"CombinationRequirement":272,"CombinationBonus":91,"CombinationConstants":2}
static func fail(message: String) -> Dictionary:return {"ok":false,"error":message}
static func digest(raw: PackedByteArray) -> String:
	var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(raw);return h.finish().hex_encode()
static func parse_bytes(raw: PackedByteArray) -> Variant:
	return JSON.parse_string(raw.get_string_from_utf8().trim_prefix("\ufeff"))
static func index_rows(rows: Array) -> Dictionary:
	var out: Dictionary={}
	for row: Dictionary in rows:out[int(row.ID)]=row
	return out
static func read_table(zip: ZIPReader,name_value: String,index: Dictionary) -> Dictionary:
	var path: String="content/"+name_value+".json"
	if not index.has(path):return fail("원본 표 누락: "+name_value)
	var raw: PackedByteArray=zip.read_file(path)
	if raw.size()!=int(index[path].bytes) or digest(raw)!=str(index[path].sha256):return fail("원본 표 무결성 오류: "+name_value)
	var value: Variant=parse_bytes(raw)
	if not value is Dictionary or not value.get("rows") is Array:return fail("원본 표 형식 오류: "+name_value)
	return {"ok":true,"rows":value.rows,"sha256":digest(raw)}
const SHARED=preload("res://scripts/resources/current523_definition_rows.gd")
const SHARED_TABLES: Array[String]=["Bonus","ItemClass","DescData_Korean","BuffClass"]
## index_rows()/description lookups (last row per ID wins) over the shared reader.
class SharedIndex extends RefCounted:
	var table: String
	var field: String
	func _init(name_value: String,value_field: String="") -> void:
		table=name_value;field=value_field
	func lookup(id: Variant,fallback: Variant={}) -> Variant:
		if not (id is int or id is float):return fallback
		var matches: Array[Dictionary]=SHARED.related(table,"ID",int(id))
		if matches.is_empty():return fallback
		return str(matches[-1].get(field)) if not field.is_empty() else matches[-1]
static func _at(index: Variant,id: Variant,fallback: Variant={}) -> Variant:
	return index.get(id,fallback) if index is Dictionary else index.lookup(id,fallback)
static func _rows_with_ids(tables: Dictionary,shared: Dictionary,table_name: String,ids: Array) -> Array:
	var result: Array=[]
	if not shared.has(table_name):
		for row: Dictionary in tables[table_name]:
			if int(row.ID) in ids:result.append(row)
		return result
	var found: Array=[]
	for id: Variant in ids:
		found.append_array(SHARED.related(table_name,"ID",int(id)))
	return found
static func from_zip(path: String) -> Dictionary:
	var zip:=ZIPReader.new()
	if zip.open(path)!=OK:return fail("최신523 원본 ZIP을 열 수 없습니다")
	if not zip.file_exists("index.json"):zip.close();return fail("최신523 원본 index.json 누락")
	var index_value: Variant=parse_bytes(zip.read_file("index.json"))
	if not index_value is Array or index_value.size()!=1065:zip.close();return fail("1065표인 최신523 원본이 필요합니다")
	var index: Dictionary={}
	for entry: Variant in index_value:
		if not entry is Dictionary or int(entry.get("version",0))!=523:zip.close();return fail("원본 버전이 523이 아닙니다")
		if not entry.get("path") is String or not str(entry.path).begins_with("content/") or not str(entry.path).ends_with(".json") or not (entry.get("bytes") is int or entry.get("bytes") is float) or float(entry.bytes)<0 or not entry.get("sha256") is String or str(entry.sha256).length()!=64 or index.has(entry.path):zip.close();return fail("중복 또는 잘못된 원본 표 경로")
		index[str(entry.path)]=entry
	var data: Dictionary={"schema":1,"source_version":523,"source_archive_sha256":FileAccess.get_sha256(path),"tables":{},"table_sha256":{},"combinations":[]}
	for name_value: String in COUNTS:
		var loaded: Dictionary=read_table(zip,name_value,index)
		if not loaded.ok:zip.close();return loaded
		if loaded.rows.size()!=int(COUNTS[name_value]):zip.close();return fail("조합 원본 행 수 불일치: "+name_value)
		data.tables[name_value]=loaded.rows;data.table_sha256[name_value]=loaded.sha256
	# Large tables are read through the shared packed reader when it holds this
	# same verified archive, instead of parsing another full copy here.
	var shared: Dictionary={}
	if path==SHARED.archive_path() and SHARED.identity().get("source_sha256")==data.source_archive_sha256:
		for name_value: String in SHARED_TABLES:
			var entry: Dictionary=index.get("content/"+name_value+".json",{})
			if entry.is_empty():zip.close();return fail("원본 표 누락: "+name_value)
			if SHARED.row_count(name_value)!=int(SHARED.table_metadata(name_value).get("row_count",-1)):zip.close();return fail("원본 표 무결성 오류: "+name_value)
			shared[name_value]=true;data.table_sha256[name_value]=str(entry.sha256)
	var tables: Dictionary={}
	for name_value: String in ["Bonus","BonusType","Unit","UIUnit","UIBonusTypeView","BuffCard","ItemClass","EquipSlotConfig","ContentsControl","ServerLimit","DescData_Korean","EquipSlot","BuffClass","BuffGroup","ClientOnlyBuffGroup","SpecialResistanceType","ElementalType"]:
		if shared.has(name_value):continue
		var loaded: Dictionary=read_table(zip,name_value,index)
		if not loaded.ok:zip.close();return loaded
		tables[name_value]=loaded.rows;data.table_sha256[name_value]=loaded.sha256
	zip.close()
	data.contracts={}
	var contract_ids: Dictionary={"EquipSlot":[174],"BuffClass":[65694],"BuffGroup":[2064],"ClientOnlyBuffGroup":[74],"SpecialResistanceType":[6,7,8],"ElementalType":[1,2,3,4]}
	for table_name: String in contract_ids:
		data.contracts[table_name]=[]
		for row: Dictionary in _rows_with_ids(tables,shared,table_name,contract_ids[table_name]):
			data.contracts[table_name].append(row)
		if data.contracts[table_name].size()!=contract_ids[table_name].size():return fail("조합 원본 계약 행 누락")
	var marker: Dictionary=data.contracts.BuffClass[0]
	if int(marker.BuffGroupID)!=2064 or not bool(marker.IsImmuneToDead) or not bool(marker.IsImmuneToCancellation) or bool(marker.IsEraseOnTimeEnd) or bool(data.contracts.BuffGroup[0].IsAllowOverlap):return fail("조합 원본 버프 수명 또는 중첩 계약 불일치")
	if int(data.contracts.ClientOnlyBuffGroup[0].BuffGroupID)!=2064 or int(data.contracts.ClientOnlyBuffGroup[0].ContentControlID)!=564:return fail("조합 원본 콘텐츠 연결 불일치")
	for row: Dictionary in data.contracts.SpecialResistanceType:
		if str(row.Name)!={6:"Stun",7:"Hold",8:"Fear"}[int(row.ID)]:return fail("조합 상태 대상 계약 불일치")
	for row: Dictionary in data.contracts.ElementalType:
		if str(row.Name)!={1:"Fire",2:"Water",3:"Air",4:"Earth"}[int(row.ID)]:return fail("조합 속성 대상 계약 불일치")
	var bonuses: Variant=SharedIndex.new("Bonus") if shared.has("Bonus") else index_rows(tables.Bonus);var types: Dictionary=index_rows(tables.BonusType)
	var units: Dictionary=index_rows(tables.Unit);var ui_units: Dictionary={};var views: Dictionary=index_rows(tables.UIBonusTypeView)
	for row: Dictionary in tables.UIUnit:ui_units[int(row.UnitID)]=row
	var cards: Dictionary=index_rows(tables.BuffCard);var items: Variant=SharedIndex.new("ItemClass") if shared.has("ItemClass") else index_rows(tables.ItemClass)
	var descriptions: Variant=SharedIndex.new("DescData_Korean","Description") if shared.has("DescData_Korean") else {}
	if not shared.has("DescData_Korean"):
		for row: Dictionary in tables.DescData_Korean:descriptions[int(row.ID)]=str(row.Description)
	var single: bool=false;var enabled: bool=false
	for row: Dictionary in tables.EquipSlotConfig:
		if int(row.EquipSlotID)==174 and int(row.MaxEquipCount)==1:single=true
	for row: Dictionary in tables.ContentsControl:
		if row.Name=="Combination" and bool(row.Enable) and int(row.ServerLimitSetID)==0:enabled=true
	if not single or not enabled:return fail("원본 단일 조합 슬롯 또는 콘텐츠 조건 확인 실패")
	var needed_limits: Dictionary={}
	for original: Dictionary in data.tables.Combination:
		var combo: Dictionary={"id":int(original.ID),"name":_at(descriptions,int(original.DescID),str(original.Name)),"source":original,"slots":[],"effects":[]}
		needed_limits[int(original.ServerLimitSetID)]=true
		var slots: Dictionary={}
		for req: Dictionary in data.tables.CombinationRequirement:
			if int(req.CombinationID)!=int(original.ID):continue
			var kind: int=int(req.RequirementType);var target: Dictionary
			if kind in [14,4]:
				target=cards.get(int(req.ClassID),{})
				if target.is_empty() or int(target.BuffCardDeckID)!=(1 if kind==14 else 2):return fail("조합 카드 원본 연결 오류")
				if int(target.get("StartDateTimeID",0))!=0 or int(target.get("EndDateTimeID",0))!=0:return fail("미지원 조합 카드 기간 조건 · 원문 보존")
				needed_limits[int(target.ServerLimitSetID)]=true
			elif kind==24:target=_at(items,int(req.ClassID),{})
			else:return fail("미확인 조합 요구 타입")
			if target.is_empty():return fail("조합 대상 원본 누락")
			var candidate: Dictionary={"source":req,"target":target,"name":_at(descriptions,int(target.DescID),str(target.Name)),"kind":kind,"class_id":int(req.ClassID),"min_enchant":int(req.ItemEnchantValue)}
			var slot: int=int(req.RequirementIndex)
			if not slots.has(slot):slots[slot]=[]
			slots[slot].append(candidate)
		var keys: Array=slots.keys();keys.sort()
		for key: int in keys:combo.slots.append({"index":key,"candidates":slots[key]})
		for link: Dictionary in data.tables.CombinationBonus:
			if int(link.CombinationID)!=int(original.ID):continue
			var bonus: Dictionary=_at(bonuses,int(link.BonusID),{});var typ: Dictionary=types.get(int(bonus.get("BonusTypeID",-1)),{})
			if typ.is_empty():return fail("조합 효과 원본 연결 오류")
			var unit: Dictionary=units.get(int(typ.UnitID),{});var ui: Dictionary=views.get(int(typ.ID),ui_units.get(int(typ.UnitID),{}))
			var denominator: float=1.0 if unit.get("Name","")=="Value" else float(ui.get("Denominator",0))
			if denominator<=0:denominator=float(ui_units.get(int(typ.UnitID),{}).get("Denominator",0))
			if denominator<=0:return fail("조합 효과 단위 분모 누락")
			combo.effects.append({"source_link":link,"source_bonus":bonus,"source_type":typ,"source_unit":unit,"source_ui_unit":ui,"type":str(typ.Name),"unit":str(unit.Name),"value":float(bonus.Value)/denominator,"raw_value":bonus.Value,"denominator":denominator,"application_type":int(bonus.BonusApplicationTypeID),"target":int(bonus.BonusApplicationTargetID),"label":_at(descriptions,int(typ.DescID),str(typ.Name))})
		data.combinations.append(combo)
	data.server_limits=[]
	for row: Dictionary in tables.ServerLimit:
		if needed_limits.has(int(row.ServerLimitSetID)):data.server_limits.append(row)
	return {"ok":true,"catalog":data}
