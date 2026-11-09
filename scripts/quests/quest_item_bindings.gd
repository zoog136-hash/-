extends RefCounted
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")
## A catalog ID is not proof that its original item or consumer is connected.
static func item_id(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<1 or value>1000000000: return 0
	return int(value)

static func index(catalogs: Array) -> Dictionary:
	var result: Dictionary = {}
	for rows: Array in catalogs:
		for record: Dictionary in rows:
			var id: int = item_id(record.get("source_item_class_id",0))
			if id <= 0 or record.get("source_snapshot") != "patch523" or record.get("sourceId") != "m523:item:"+str(id): continue
			var key: String = str(id)
			if not result.has(key): result[key] = []
			# Preserve different candidates instead of silently letting the last
			# item_db/catalog row decide the identity of an original reward.
			if not result[key].has(record): result[key].append(record)
	return result

## index() without holding a Dictionary entry and Array per original item
## (the quest context rebuilt that ~MB index every second). Entries are
## packed (id, catalog, position) in one sorted PackedInt64Array and the
## candidates are read from the same catalog Arrays on lookup, in the same
## order and with the same de-duplication as index().
class Lookup extends RefCounted:
	var catalogs: Array = []
	var entries := PackedInt64Array()
	func candidates(key: String) -> Array:
		var result: Array = []
		if not key.is_valid_int() or key != str(int(key)): return result
		var id: int = int(key)
		if id <= 0 or id > 1000000000: return result
		var low: int = entries.bsearch(id << 32)
		for at: int in range(low, entries.size()):
			var packed: int = entries[at]
			if (packed >> 32) != id: break
			var rows: Array = catalogs[(packed >> 28) & 0xF]
			var position: int = packed & 0xFFFFFFF
			var record: Variant = rows[position] if position < rows.size() else null
			if not record is Dictionary or not _indexed(record, id):
				return _scan(id) # A catalog changed in place: read it as index() would.
			if not result.has(record): result.append(record)
		return result
	func _scan(id: int) -> Array:
		var result: Array = []
		for rows: Array in catalogs:
			for record: Variant in rows:
				if record is Dictionary and _indexed(record, id) and not result.has(record): result.append(record)
		return result
	## The index() admission rule for `id`.
	static func _indexed(record: Dictionary, id: int) -> bool:
		var value: Variant = record.get("source_item_class_id",0)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<1 or value>1000000000: return false
		return int(value) == id and record.get("source_snapshot") == "patch523" and record.get("sourceId") == "m523:item:"+str(id)

static func lookup(catalogs: Array) -> Lookup:
	var result := Lookup.new()
	var entries := PackedInt64Array()
	for catalog: int in catalogs.size():
		var rows: Array = catalogs[catalog]
		result.catalogs.append(rows)
		for position: int in rows.size():
			var record: Dictionary = rows[position]
			var id: int = item_id(record.get("source_item_class_id",0))
			if id <= 0 or record.get("source_snapshot") != "patch523" or record.get("sourceId") != "m523:item:"+str(id): continue
			entries.append((id << 32) | (catalog << 28) | position)
	entries.sort()
	result.entries = entries
	return result

## `records` is an index() Dictionary or a lookup().
static func resolve(reward: Dictionary, records: Variant, consumer: Callable) -> Dictionary:
	var unavailable: Dictionary = {"record":{},"reason":"실제 아이템 소비자 미연결"}
	if bool(reward.get("UseImmediately",false)):
		return {"record":{},"reason":"원본 즉시 사용 보상 연결 대기"}
	if int(reward.get("ItemBlessCodeID",0)) != 1:
		return {"record":{},"reason":"원본 축복 상태 소비 연결 대기"}
	var id: int = item_id(reward.get("RewardClassID",0))
	var candidates: Variant = records.candidates(str(id)) if records is Lookup else (records.get(str(id),[]) if records is Dictionary else [])
	if not candidates is Array or candidates.is_empty() or not consumer.is_valid(): return unavailable
	var original: Dictionary = reward.get("source_item",{})
	if original.is_empty() or int(original.get("ID",0)) != id: return {"record":{},"reason":"원본 아이템 행 확인 실패"}
	var accepted: Dictionary = {}
	for record: Dictionary in candidates:
		if id<=0 or record.get("source") != "lineagem_patch523" or record.get("source_snapshot") != "patch523" or record.get("sourceId") != "m523:item:"+str(id) or item_id(record.get("source_item_class_id",0)) != id: return {"record":{},"reason":"원본 아이템 ID 충돌"}
		if record.get("source_bless_raw",1) != 1: return {"record":{},"reason":"소비자 축복 상태 불일치"}
		if NATIVE_FIELDS.full(record).get("source_original_item",{}) != original: return {"record":{},"reason":"원본 아이템 행 불일치"}
		if record.get("source_automation_catalog_only",false) or record.get("source_pending_use",false): return unavailable
		if not bool(consumer.call({"name":str(record.get("name","")),"record":record})): return unavailable
		if not accepted.is_empty() and accepted != record: return {"record":{},"reason":"중복 원본 아이템 정의 충돌"}
		accepted = record
	return {"record":accepted.duplicate(true),"reason":"" if not accepted.is_empty() else unavailable.reason}
