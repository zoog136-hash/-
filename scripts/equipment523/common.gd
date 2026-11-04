extends RefCounted

const SCHEMA: String = "patch523-five-systems-v1"
const SOURCE_SHA: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"

static func rows(pack: Dictionary, table_name: String) -> Array:
	var value: Variant = pack.get("tables", {}).get(table_name, [])
	return value if value is Array else []

static func find(pack: Dictionary, table_name: String, identity: int) -> Dictionary:
	if not pack.has("_indexes"):
		pack["_indexes"] = {}
	if not pack["_indexes"].has(table_name):
		var index: Dictionary = {}
		for row: Dictionary in rows(pack, table_name):
			if row.has("ID"):
				index[str(int(row["ID"]))] = row
		pack["_indexes"][table_name] = index
	return pack["_indexes"][table_name].get(str(identity), {})

static func bonus(pack: Dictionary, identity: int) -> Dictionary:
	return pack.get("bonuses", {}).get(str(identity), {})

static func item(pack: Dictionary, identity: int) -> Dictionary:
	return pack.get("items", {}).get(str(identity), {})

static func weighted(candidates: Array, field: String, rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for row: Dictionary in candidates:
		var weight: int = int(row.get(field, 0))
		if weight < 0:
			return {}
		total += weight
	if total <= 0 or total > 2147483647:
		return {}
	var selected: int = rng.randi_range(0, total - 1)
	for row: Dictionary in candidates:
		selected -= int(row.get(field, 0))
		if selected < 0:
			return row.duplicate(true)
	return {}

static func effect_records(pack: Dictionary, identities: Array) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for identity: Variant in identities:
		var effect: Dictionary = bonus(pack, int(identity))
		if not bool(effect.get("supported", false)):
			continue
		var record: Dictionary = effect.get("record", {}).duplicate(true)
		if not record.is_empty():
			record["equipment523_bonus_id"] = int(identity)
			record["name"] = "가공 효과 · " + str(effect.get("name", identity))
			record["equipment523_synthetic"] = true
			records.append(record)
	return records

static func source_id(record: Dictionary) -> int:
	if record.has("source_item_class_id"):
		return int(record["source_item_class_id"])
	var source: String = str(record.get("sourceId", ""))
	if source.begins_with("m523:item:"):
		return int(source.trim_prefix("m523:item:"))
	return 0

static func fail(message: String) -> Dictionary:
	return {"ok":false, "error":message}
