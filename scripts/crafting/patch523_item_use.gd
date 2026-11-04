extends RefCounted
## ItemClass level bounds and ItemClassLimit are item-use constraints.
## ItemCraftRestriction remains the independent manufacturing contract.

static func definition(record: Dictionary) -> Dictionary:
	var value: Variant = record.get("patch523_item_use",{})
	return value if value is Dictionary else {}

static func valid(record: Dictionary) -> bool:
	if not record.has("patch523_item_use"): return true
	var value: Dictionary = definition(record)
	var source_id: String=str(record.get("sourceId",""))
	if record.get("source")=="lineagem_patch523" and record.get("source_snapshot")=="patch523" and record.get("source_m_native_item",false) and source_id=="m523:item:"+str(int(record.get("source_item_class_id",0))): source_id=str(int(record.source_item_class_id))
	elif record.get("source")!="inven": return false
	if value.get("schema","")!="patch523-item-use-v1" or str(value.get("source_id",""))!=source_id: return false
	for key: String in ["min_level","max_level"]:
		if typeof(value.get(key)) not in [TYPE_INT,TYPE_FLOAT] or float(value[key])!=float(int(value[key])) or int(value[key])<0 or int(value[key])>1000: return false
	if int(value.max_level)>0 and int(value.max_level)<int(value.min_level): return false
	if not value.get("class_ids") is Array or not value.get("class_names") is Array or value.class_ids.size()!=value.class_names.size(): return false
	for id: Variant in value.class_ids:
		if typeof(id) not in [TYPE_INT,TYPE_FLOAT] or float(id)!=float(int(id)) or int(id)<1: return false
	for label: Variant in value.class_names:
		if not label is String or str(label).is_empty(): return false
	return true

static func reason(record: Dictionary, level: int, class_id: int) -> String:
	if not valid(record): return "원본 아이템 사용 조건이 손상되어 사용할 수 없습니다"
	var value: Dictionary = definition(record)
	if value.is_empty(): return ""
	if level<int(value.min_level): return "원본 사용 조건 · 레벨 %d 이상 필요" % int(value.min_level)
	if int(value.max_level)>0 and level>int(value.max_level): return "원본 사용 조건 · 레벨 %d 이하 필요" % int(value.max_level)
	if not value.class_ids.is_empty():
		var allowed: bool=false
		for id: Variant in value.class_ids:
			if int(id)==class_id: allowed=true
		if not allowed: return "원본 사용 가능 직업 · " + ", ".join(value.class_names)
	return ""

static func summary(record: Dictionary) -> String:
	if not valid(record): return "원본 사용 조건 미확인"
	var value: Dictionary = definition(record)
	if value.is_empty(): return ""
	var result: PackedStringArray = []
	if int(value.min_level)>0: result.append("레벨 %d 이상" % int(value.min_level))
	if int(value.max_level)>0: result.append("레벨 %d 이하" % int(value.max_level))
	if not value.class_ids.is_empty(): result.append("직업: " + ", ".join(value.class_names))
	return "원본 사용 조건 · " + " / ".join(result)
