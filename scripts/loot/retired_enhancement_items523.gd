extends RefCounted
## TWILIGHT gameplay decision, not a source dummy marker or save migration.
## Only ItemClass IDs listed by the missing-enchantment audit are retired.
const IDS := {133134:true,133144:true,133154:true,133324:true,151863:true,151873:true,153904:true,153914:true,153924:true,153934:true,163603:true,163613:true,163623:true,163633:true,244282:true,351964:true,358932:true}
const REASON := "강화 원본 자료가 없어 제외한 아이템입니다 · 기존 소유 기록은 보존합니다"

static func item(id: Variant) -> bool:
	if id is int:return IDS.has(id)
	if id is float and id >= 133134 and id <= 358932 and id == floorf(id):return IDS.has(int(id))
	return false

static func record(row: Dictionary) -> bool:
	if row.has("source_item_class_id"):return item(row.source_item_class_id)
	if row.get("source")=="twilight_dungeon_adaptation":return item(row.get("declared_source_item"))
	var key: Variant=row.get("sourceId")
	if not key is String or not key.begins_with("m523:item:"):return false
	var tokens: PackedStringArray=key.split(":")
	if tokens.size()!=3 and (tokens.size()!=5 or tokens[3]!="bless" or tokens[4] not in ["1","2","3"]):return false
	return tokens[2].is_valid_int() and tokens[2]==str(int(tokens[2])) and IDS.has(int(tokens[2]))

## Return the same array unless a row must actually disappear; preserve order
## and duplicates. Never edit the source document or an inventory collection.
static func catalog(rows: Array) -> Array:
	var result: Array=[]
	var changed:=false
	for i: int in rows.size():
		var row: Variant=rows[i]
		if row is Dictionary and record(row):
			if not changed:result=rows.slice(0,i);changed=true
		elif changed:result.append(row)
	return result if changed else rows
