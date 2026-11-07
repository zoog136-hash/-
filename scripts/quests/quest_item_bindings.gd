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

static func resolve(reward: Dictionary, records: Dictionary, consumer: Callable) -> Dictionary:
	var unavailable: Dictionary = {"record":{},"reason":"실제 아이템 소비자 미연결"}
	if bool(reward.get("UseImmediately",false)):
		return {"record":{},"reason":"원본 즉시 사용 보상 연결 대기"}
	if int(reward.get("ItemBlessCodeID",0)) != 1:
		return {"record":{},"reason":"원본 축복 상태 소비 연결 대기"}
	var id: int = item_id(reward.get("RewardClassID",0))
	var candidates: Variant = records.get(str(id),[])
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
