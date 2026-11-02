extends RefCounted
## New source identities use class + exact view/territory, never a legacy ID/name.
const FULL = preload("res://scripts/monsters/base508_authoritative_catalog.gd")
const PATH = "res://data/lineagem_base508/monster_batch02/runtime_registry.json"
const CONTEXT = preload("res://scripts/monsters/base508_monster_context.gd")
const BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
const PACK = preload("res://scripts/monsters/base508_monster_pack_cache.gd")
static var _data: Dictionary = {}
static var _by_npc: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if value is Dictionary and value.get("source_snapshot", "") == "base508":
			_data = value
			for row: Dictionary in value.get("source_id_records", []): _by_npc[int(row.npc_id)] = row
	return _data
static func record(source_key: String, manifest_path: String = "", compatibility: Dictionary = {}) -> Dictionary:
	data()
	var context: Dictionary = _data.get("contexts", {}).get(source_key, {})
	if context.is_empty(): return _full_record(source_key, manifest_path, compatibility)
	var row: Dictionary = _by_npc.get(int(context.npc_id), {})
	if row.is_empty(): return {}
	var path: String = manifest_path if not manifest_path.is_empty() else BINDINGS.pack_manifest()
	var actor: Dictionary = PACK.actor(path, int(context.npc_id))
	if actor.is_empty() or int(actor.get("sprite_id", -1)) != int(context.sprite_id): return {}
	var available: bool = false
	for permitted: Dictionary in actor.get("source_contexts", [actor]):
		if int(permitted.get("spawn_view_id", -1)) == int(context.spawn_view_id) and int(permitted.get("territory_link_id", -1)) == int(context.territory_link_id): available = true
	if not available: return {}
	var host: Dictionary = {"atk":8,"speed":70.0,"attack_interval":1.25,"attack_range":58.0,"collision_radius":19.0,"grade":"일반","is_boss":bool(row.get("source_ui_boss",false))}
	host.merge(compatibility, true)
	var result: Dictionary = CONTEXT.record(int(context.npc_id), int(context.spawn_view_id), int(context.territory_link_id), host)
	if result.is_empty(): return {}
	result["sourceId"] = source_key
	result["source_m_catalog_key"] = source_key
	result["source_m_asset_manifest_path"] = path
	result["source_m_pixel_status"] = "private_source_model_registered; hash_checked_before_spawn"
	result["source_m_source_ui_boss"] = bool(row.get("source_ui_boss", false))
	result["source_m_host_placement"] = row.host_placement_contract
	return result
static func for_spawn(source_key: String, host_map_id: String, manifest_path: String = "") -> Dictionary:
	data()
	var context: Dictionary = _data.get("contexts", {}).get(source_key, {})
	if context.is_empty():
		var full_record: Dictionary = _full_record(source_key, manifest_path, {})
		if not full_record.is_empty(): full_record["catalog_only"] = false
		return full_record
	var row: Dictionary = _by_npc.get(int(context.npc_id), {})
	if not row.get("host_maps", []).has(host_map_id): return {}
	var result: Dictionary = record(source_key, manifest_path)
	if not result.is_empty(): result["catalog_only"] = false
	return result
static func primary_keys() -> Array:
	var result: Array = []
	for row: Dictionary in data().get("source_id_records", []): result.append(str(row.key))
	return result

static func _full_record(source_key: String, manifest_path: String, compatibility: Dictionary) -> Dictionary:
	var ids: Dictionary = FULL.parse_key(source_key)
	if ids.is_empty() or not FULL.enemy_eligible(int(ids.npc_id)): return {}
	var path: String = manifest_path if not manifest_path.is_empty() else BINDINGS.pack_manifest()
	var actor: Dictionary = PACK.actor(path, int(ids.npc_id))
	if actor.is_empty(): return {}
	var host: Dictionary = {"atk":8,"speed":70.0,"attack_interval":1.25,"attack_range":58.0,"collision_radius":19.0,"grade":"일반"}
	host["is_boss"] = bool(FULL.npc(int(ids.npc_id)).get("source_ui_boss", false))
	host.merge(compatibility, true)
	var result: Dictionary = FULL.source_record(source_key, host)
	if result.is_empty() or int(result.get("source_m_sprite_id", -1)) != int(actor.get("sprite_id", -2)): return {}
	result["source_m_asset_manifest_path"] = path
	result["source_m_host_placement"] = "Explicit host region source-key port; native geography unverified"
	return result
