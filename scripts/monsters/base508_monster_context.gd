extends RefCounted
## Exact base508 identity/context joins. This file never guesses a legacy name,
## legacy NPC ID, MonsterBookLevel, LandID/AssetPath equality, loot rate or map transform.
const BASE = preload("res://scripts/lineagem_base508.gd")
const PATH = "res://data/lineagem_base508/monster_contexts.bin"
static var _data: Dictionary = {}
static var _indexes: Dictionary = {}
static var _attacks_by_npc: Dictionary = {}
static var _attributes_by_npc: Dictionary = {}
static var _schedules_by_pack: Dictionary = {}

static func ensure_loaded() -> void:
	if not _data.is_empty(): return
	var packed: PackedByteArray = FileAccess.get_file_as_bytes(PATH)
	var payload: PackedByteArray = packed.decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
	if payload.is_empty(): return
	var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("source_snapshot", "") != "base508": return
	_data = parsed
	for table_name: String in ["NpcSpawnPackNpcClassView", "NpcSpawnPackTerritory", "Territories", "Land", "NpcCategory"]:
		var index: Dictionary = {}
		for row: Dictionary in _data.get("tables", {}).get(table_name, []):
			index[int(row.ID)] = row
		_indexes[table_name] = index

	for row: Dictionary in _data.get("tables", {}).get("NpcAttack", []):
		var npc_id: int = int(row.NpcClassID)
		if not _attacks_by_npc.has(npc_id): _attacks_by_npc[npc_id] = []
		_attacks_by_npc[npc_id].append(row)
	for row: Dictionary in _data.get("tables", {}).get("NpcAttribute", []):
		var npc_id: int = int(row.NpcClassID)
		if not _attributes_by_npc.has(npc_id): _attributes_by_npc[npc_id] = []
		_attributes_by_npc[npc_id].append(row)
	for row: Dictionary in _data.get("tables", {}).get("NpcSpawnPackSchedulePeriod", []):
		var pack_id: int = int(row.NpcSpawnPackID)
		if not _schedules_by_pack.has(pack_id): _schedules_by_pack[pack_id] = []
		_schedules_by_pack[pack_id].append(row)

static func _row(table_name: String, id: int) -> Dictionary:
	ensure_loaded()
	return _indexes.get(table_name, {}).get(id, {})

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
static func activation_flag(value: Variant) -> String:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)): return "unsupported"
	if float(value)==0.0: return "inactive"
	if float(value)==1.0: return "active"
	return "unsupported"

static func explicitly_inactive(npc_id: int, spawn_view_id: int, territory_link_id: int) -> bool:
	var spawn: Dictionary=_row("NpcSpawnPackNpcClassView",spawn_view_id)
	var link: Dictionary=_row("NpcSpawnPackTerritory",territory_link_id)
	var flag: Variant=spawn.get("IsSpawn")
	return not spawn.is_empty() and not link.is_empty() and int(spawn.get("NpcClassID",-1))==npc_id and activation_flag(flag)=="inactive" and int(link.get("NpcSpawnPackID",-1))==int(spawn.get("NpcSpawnPackID",-2))

static func context(npc_id: int, spawn_view_id: int, territory_link_id: int, allowed_limit_sets: Array = [0]) -> Dictionary:
	var npc: Dictionary = BASE.npc(npc_id)
	if npc.is_empty(): return _failure("npc_id_missing")
	var spawn: Dictionary = _row("NpcSpawnPackNpcClassView", spawn_view_id)
	if spawn.is_empty(): return _failure("spawn_view_id_missing")
	if int(spawn.NpcClassID) != npc_id: return _failure("spawn_view_npc_mismatch")
	var activation: String=activation_flag(spawn.get("IsSpawn"))
	if activation=="inactive": return _failure("source_spawn_inactive")
	if activation!="active": return _failure("source_spawn_flag_unsupported")
	if not allowed_limit_sets.has(int(spawn.ServerLimitSetID)): return _failure("server_limit_set_context_required")
	if int(spawn.NpcLevel) <= 0: return _failure("source_spawn_level_not_positive")
	if bool(npc.get("TestNPC", false)): return _failure("source_test_npc")
	var link: Dictionary = _row("NpcSpawnPackTerritory", territory_link_id)
	if link.is_empty(): return _failure("territory_link_id_missing")
	if int(link.NpcSpawnPackID) != int(spawn.NpcSpawnPackID): return _failure("territory_link_pack_mismatch")
	var territory: Dictionary = _row("Territories", int(link.TerritoriesID))
	if territory.is_empty(): return _failure("territory_id_missing")
	var land: Dictionary = _row("Land", int(territory.LandID))
	if land.is_empty(): return _failure("land_id_missing")
	return {"ok": true, "npc": npc.duplicate(true), "spawn_view": spawn.duplicate(true),
		"territory_link": link.duplicate(true), "territory": territory.duplicate(true), "land": land.duplicate(true),
		"sprite": _data.get("sprites", {}).get(str(int(npc.Sprite)), {}).duplicate(true),
		"category": _row("NpcCategory", int(npc.Category)).duplicate(true),
		"native_attacks": _attacks_by_npc.get(npc_id, []).duplicate(true),
		"native_attributes": _attributes_by_npc.get(npc_id, []).duplicate(true),
		"native_schedules": _schedules_by_pack.get(int(spawn.NpcSpawnPackID), []).duplicate(true),
		"world_activation": "not_authorized_by_join; schedule/limit/coordinate and pixel readiness still required"}

static func record(npc_id: int, spawn_view_id: int, territory_link_id: int, compatibility: Dictionary = {}, allowed_limit_sets: Array = [0]) -> Dictionary:
	var joined: Dictionary = context(npc_id, spawn_view_id, territory_link_id, allowed_limit_sets)
	if not bool(joined.ok): return {}
	var local: Dictionary = compatibility.duplicate(true)
	# Existing source3 identity/animation/loot fields must not accidentally address
	# a different game's NPC or reuse its generated silhouette for this source ID.
	for key: String in ["sourceId", "source_id", "source_npc_id", "source_m_original", "source_m_previous_application", "source_m_spawn_npc_level", "visual", "image_path", "animation_profile", "animation_id", "drop", "gold"]:
		local.erase(key)
	var compatibility_keys: Array = local.keys()
	local["source_m_spawn_npc_level"] = int(joined.spawn_view.NpcLevel)
	var result: Dictionary = BASE.npc_record(npc_id, local)
	result.erase("source_m_previous_application")
	result["source"] = "lineagem_base508"
	result["sourceId"] = "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [npc_id, spawn_view_id, territory_link_id]
	result["source_m_sprite_id"] = int(joined.npc.Sprite)
	result["source_m_spawn_view_id"] = spawn_view_id
	result["source_m_territory_link_id"] = territory_link_id
	result["source_m_context"] = joined
	result["source_m_motion_status"] = joined.sprite.get("status", "source_declaration_missing")
	result["source_m_pixel_status"] = "requires_verified_monster_pack"
	result["source_m_local_compatibility_keys"] = compatibility_keys
	result["source_m_combat_contract"] = "HP/MP/AC/MR/Exp and context level are native; other combat parameters remain explicit host compatibility."
	result["source_m_drop_contract"] = "No source drop probability or quantity supplied; no native loot schedule inferred."
	result["catalog_only"] = true
	result["drop"] = []
	result["gold"] = 0
	return result

static func motion(sprite_id: int) -> Dictionary:
	ensure_loaded()
	return _data.get("sprites", {}).get(str(sprite_id), {}).duplicate(true)

static func counts() -> Dictionary:
	ensure_loaded()
	return _data.get("counts", {}).duplicate(true)

static func map_bindings() -> Array:
	ensure_loaded()
	return _data.get("map_bindings", []).duplicate(true)
