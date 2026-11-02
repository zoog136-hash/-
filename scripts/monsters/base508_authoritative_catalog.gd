extends RefCounted
## Complete source-ID registry. Classification/registration never auto-spawns NPCs.
const PATH = "res://data/lineagem_base508/monster_full/authoritative_catalog.bin"
const BASE = preload("res://scripts/lineagem_base508.gd")
const CONTEXT = preload("res://scripts/monsters/base508_monster_context.gd")
static var _data: Dictionary = {}
static var _npcs: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var packed: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
		var raw: PackedByteArray = packed.decompress_dynamic(128 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
		var value: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if value is Dictionary and value.get("source_snapshot", "") == "base508":
			_data = value
			for row: Dictionary in value.get("rows", []): _npcs[int(row.npc_id)] = row
	return _data
static func npc(npc_id: int) -> Dictionary:
	data()
	var row: Dictionary = _npcs.get(npc_id, {}).duplicate(true)
	if row.is_empty(): return {}
	row["source_original"] = BASE.npc(npc_id).duplicate(true)
	row["source_model"] = _data.get("models", {}).get(str(int(row.sprite_id)), {}).duplicate(true)
	return row
static func context_key(npc_id: int, view_id: int, territory_link_id: int) -> String:
	return "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [npc_id, view_id, territory_link_id]
static func context_keys(npc_id: int) -> Array:
	data()
	var result: Array = []
	for pair: Array in _data.get("world_context_index", {}).get(str(npc_id), []):
		result.append(context_key(npc_id, int(pair[0]), int(pair[1])))
	return result
static func enemy_eligible(npc_id: int, allow_contextual: bool = false) -> bool:
	data()
	var row: Dictionary = _npcs.get(npc_id, {})
	if row.is_empty() or bool(row.get("source_TestNPC", false)): return false
	if not bool(row.get("source_category", {}).get("IsAttackable", false)): return false
	if row.get("source_kind", "") not in ["source_ui_boss_npc", "source_attackable_monster_actor"]: return false
	if not allow_contextual and not row.get("literal_context_evidence", []).is_empty(): return false
	return true
static func parse_key(source_key: String) -> Dictionary:
	var parts: PackedStringArray = source_key.split(":")
	if parts.size() != 7 or parts[0] != "lineagem_base508" or parts[1] != "npc" or parts[3] != "spawn" or parts[5] != "territory": return {}
	for index: int in [2,4,6]:
		if not parts[index].is_valid_int() or int(parts[index]) <= 0: return {}
	return {"npc_id":int(parts[2]),"view_id":int(parts[4]),"link_id":int(parts[6])}
static func source_record(source_key: String, compatibility: Dictionary = {}) -> Dictionary:
	var id: Dictionary = parse_key(source_key)
	if id.is_empty(): return {}
	data()
	if not _npcs.has(int(id.npc_id)): return {}
	var permitted: bool = false
	for pair: Array in _data.get("world_context_index", {}).get(str(int(id.npc_id)), []):
		if int(pair[0]) == int(id.view_id) and int(pair[1]) == int(id.link_id): permitted = true
	if not permitted: return {}
	var record: Dictionary = CONTEXT.record(int(id.npc_id), int(id.view_id), int(id.link_id), compatibility)
	if record.is_empty(): return {}
	record["sourceId"] = source_key
	record["source_m_catalog_key"] = source_key
	record["source_m_classification"] = _npcs[int(id.npc_id)].duplicate(true)
	return record
static func counts() -> Dictionary:
	return data().get("counts", {}).duplicate(true)
