extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## Explicit original declarations only. This excludes gameplay connections,
## never deletes source rows/assets, existing ownership or original denominators.
const SOURCE_SHA="d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const ITEM_DECLARATIONS={224743:{"name":"테스트용 더미3","line":712233},224753:{"name":"테스트용 더미2","line":712277},224763:{"name":"테스트용 더미1","line":712321}}
static var observed_exclusions: Dictionary={}

static func evidence(table: String,row: Dictionary,scope: String="record") -> Dictionary:
	var name_value: Variant=row.get("Name")
	if not name_value is String:return {}
	var marker: String=""
	var id: int=int(row.get("ID",0))
	var line: int=0
	if table=="ItemClass" and ITEM_DECLARATIONS.has(id) and name_value==ITEM_DECLARATIONS[id].name:
		marker=str(ITEM_DECLARATIONS[id].name);line=int(ITEM_DECLARATIONS[id].line)
	elif name_value.contains("[더미]"):
		marker="[더미]"
	elif scope=="motion" and name_value.contains("(더미모션)"):
		marker="(더미모션)"
	if marker.is_empty():return {}
	var result: Dictionary={"source_sha256":SOURCE_SHA,"source_path":"content/"+table+".json","source_row_id":id,"field":"Name","source_value":name_value,"declaration":marker,"scope":scope,"excluded_from_connection":true,"counted_as_consumption":false}
	if line>0:result["source_line"]=line
	observed_exclusions[table+":"+str(id)+":"+scope]=result.duplicate(true)
	return result

static func item_id_evidence(id: int) -> Dictionary:
	return evidence("ItemClass",{"ID":id,"Name":ITEM_DECLARATIONS[id].name}) if ITEM_DECLARATIONS.has(id) else {}

static func item_evidence(row: Dictionary) -> Dictionary:
	return evidence("ItemClass",row)

static func record_evidence(record: Dictionary) -> Dictionary:
	if record.get("source_snapshot") not in ["patch523","current523"] or record.get("source") not in ["lineagem_patch523","lineagem_current523"]:return {}
	var id: int=int(record.get("source_item_class_id",0))
	var raw: Variant=NATIVE_FIELDS.full(record).get("source_original_item")
	if raw is Dictionary and int(raw.get("ID",0))==id:
		return item_evidence(raw)
	# IDs below bind to reviewed declarations in this exact snapshot, never to
	# a legacy item's display name, IsTrash, TestItem, absent art or zero stats.
	return item_id_evidence(id)

static func reason(record: Dictionary) -> String:
	var excluded: Dictionary=record_evidence(record)
	return "원본 더미 선언으로 사용·지급 연결에서 제외 · 기존 소유와 원본 보존" if not excluded.is_empty() else ""
