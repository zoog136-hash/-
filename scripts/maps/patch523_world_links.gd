extends RefCounted
## Cumulative523 definitions in the original Land namespace. No inferred instances.
const SOURCE_SHA256: String = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const MAX_FILE_BYTES: int = 32 * 1024 * 1024
var problem: String = ""
var loaded: bool = false
var root: String = ""
var manifest: Dictionary = {}
var land: Dictionary = {}
var shard: Dictionary = {}
var contexts: Dictionary = {}
var territories: Dictionary = {}
var npcs: Dictionary = {}
var views_by_pack: Dictionary = {}

func _fail(message: String) -> bool:
	problem = message
	return false

func _object(path: String, spec: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES: return {}
	if not spec.is_empty() and (file.get_length() != int(spec.get("bytes", -1)) or FileAccess.get_sha256(path) != str(spec.get("sha256", ""))): return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}

func _rows(value: Variant) -> bool:
	if not value is Array: return false
	for row: Variant in value:
		if not row is Dictionary: return false
	return true

func _index(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var id: Variant = row.get("ID")
		if not _integer(id) or result.has(int(id)): return {}
		result[int(id)] = row
	return result

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func load_land(path: String, land_id: int, asset_path: String, expected_manifest_sha256: String) -> bool:
	loaded = false
	shard = {}; contexts = {}; land = {}; territories = {}; npcs = {}; views_by_pack = {}
	root = path
	var manifest_path: String = root.path_join("manifest.json")
	if expected_manifest_sha256.length() != 64 or not FileAccess.file_exists(manifest_path) or FileAccess.get_sha256(manifest_path) != expected_manifest_sha256:
		return _fail("Cumulative523 manifest is missing or SHA256 differs")
	manifest = _object(manifest_path)
	if manifest.get("schema") != 1 or manifest.get("source_snapshot") != "patch523" or manifest.get("source_zip_sha256") != SOURCE_SHA256:
		return _fail("Unsupported cumulative523 source identity")
	if not manifest.get("lands") is Dictionary or not manifest.lands.get(str(land_id)) is Dictionary:
		return _fail("Cumulative523 Land is unavailable")
	var spec: Dictionary = manifest.lands[str(land_id)]
	if spec.get("file") != "lands/%d.json" % land_id or spec.get("asset_path") != asset_path:
		return _fail("Land/AssetPath namespace mismatch")
	var candidate: Dictionary = _object(root.path_join(spec.file), spec)
	if candidate.get("schema") != 1 or candidate.get("source_snapshot") != "patch523" or not candidate.get("land") is Dictionary or candidate.land.get("ID") != land_id or candidate.land.get("AssetPath") != asset_path:
		return _fail("Cumulative523 Land shard is missing, corrupt or mismatched")
	for key: String in ["territories", "portals", "spawn_relations", "spawn_views", "npc_classes"]:
		if not _rows(candidate.get(key)): return _fail("Invalid cumulative523 row collection: " + key)
	if not candidate.get("pack_context") is Dictionary or not candidate.get("unresolved_class_view_packs") is Array:
		return _fail("Missing cumulative523 pack contexts")
	var selected_territories: Dictionary = _index(candidate.territories)
	var selected_npcs: Dictionary = _index(candidate.npc_classes)
	if selected_territories.size() != candidate.territories.size() or selected_npcs.size() != candidate.npc_classes.size(): return _fail("Duplicate cumulative523 source identities")
	for territory: Dictionary in candidate.territories:
		if territory.get("LandID") != land_id: return _fail("Foreign Territory in Land shard")
	for relation: Dictionary in candidate.spawn_relations:
		if not _integer(relation.get("TerritoriesID")) or not _integer(relation.get("NpcSpawnPackID")) or not selected_territories.has(int(relation.TerritoriesID)): return _fail("Unresolved spawn Territory")
	var selected_views: Dictionary = {}
	for view: Dictionary in candidate.spawn_views:
		if not _integer(view.get("NpcClassID")) or not selected_npcs.has(int(view.NpcClassID)) or not _integer(view.get("NpcSpawnPackID")): return _fail("Unresolved spawn NpcClass")
		var pack_id: int = int(view.NpcSpawnPackID)
		if not selected_views.has(pack_id): selected_views[pack_id] = []
		selected_views[pack_id].append(view)
	for link: Dictionary in candidate.portals:
		if not link.get("portal") is Dictionary or not link.get("target_territory") is Dictionary or not link.get("target_land") is Dictionary: return _fail("Invalid portal relation")
		if link.portal.get("SourceLandID") != land_id or link.portal.get("TargetTerritoryID") != link.target_territory.get("ID") or link.target_territory.get("LandID") != link.target_land.get("ID"): return _fail("Unresolved portal identity")
	for key: String in ["NpcSpawnPackSchedulePeriod", "DaynightSpawnPack", "WorldBossRaidView", "NpcRepresentativeSpawnView"]:
		if not _rows(candidate.pack_context.get(key)): return _fail("Invalid pack condition rows")
	if not manifest.get("conditions") is Dictionary or manifest.conditions.get("file") != "conditions.json": return _fail("Invalid cumulative523 conditions path")
	var condition_data: Dictionary = _object(root.path_join("conditions.json"), manifest.conditions)
	if condition_data.get("schema") != 1 or condition_data.get("source_snapshot") != "patch523" or not condition_data.get("tables") is Dictionary: return _fail("Cumulative523 condition table is missing or corrupt")
	for key: String in ["NpcCategory", "ServerLimit", "WeeklyOpenTimeGroup", "WeeklyOpenTimeGroupSet", "WeeklyOpenTime", "WeeklyOpenTimeEntity", "LandAttribute", "LandAttributeType", "LandTimeLimit", "LandTimeLimitGroup", "LandWeeklyOpenTime", "DateTimes", "DateTimes_Korean", "DateTimes_Taiwanese", "DateTimes_Japanese", "DateTimes_Chinese", "CompetitionDungeon", "CompetitionDungeonLand", "CompetitionDungeonView", "LandTeleport", "LandTeleportTerritories", "LandTeleportPrerequisite", "Prerequisite", "PrerequisiteType", "WorldBossRaidPrerequisite", "WorldBossRaidPrerequisiteView"]:
		if not _rows(condition_data.tables.get(key)): return _fail("Invalid condition table: " + key)
	shard = candidate
	land = candidate.land
	contexts = condition_data.tables
	territories = selected_territories
	npcs = selected_npcs
	views_by_pack = selected_views
	loaded = true
	problem = ""
	return true

static func definition_state(view: Dictionary) -> String:
	# Numeric 0 alone excludes a definition. 1 is not proof of current activation.
	var flag: Variant = view.get("IsSpawn")
	if not _integer(flag): return "UNKNOWN_IS_SPAWN"
	if int(flag) == 0: return "EXPLICIT_IS_SPAWN_0"
	return "DEFINED_IS_SPAWN_1_ACTIVATION_UNKNOWN" if int(flag) == 1 else "CONDITIONAL_OR_UNKNOWN_IS_SPAWN"

func _matching(table: String, field: String, value: Variant) -> Array:
	var result: Array = []
	for row: Dictionary in contexts.get(table, []):
		if row.get(field) == value: result.append(row.duplicate(true))
	return result

func _weekly(group_ids: Array) -> Dictionary:
	var sets: Array = []; var entities: Array = []
	var time_ids: Dictionary = {}
	for row: Dictionary in contexts.get("WeeklyOpenTimeGroupSet", []):
		if row.get("WeeklyOpenTimeGroupId") in group_ids:
			sets.append(row.duplicate(true)); time_ids[row.WeeklyOpenTimeId] = true
	for row: Dictionary in contexts.get("WeeklyOpenTimeEntity", []):
		if time_ids.has(row.get("WeeklyOpenTimeID")): entities.append(row.duplicate(true))
	return {"group_sets": sets, "entities": entities, "evaluation": "RAW_SERVICE_REGION_TIMES; NO_UTC_OR_WEEKDAY_INFERENCE"}

func pack_conditions(pack_id: int) -> Dictionary:
	if not loaded: return {}
	var result: Dictionary = {}; var group_ids: Array = []; var server_ids: Dictionary = {}
	for table: String in shard.pack_context:
		result[table] = []
		for row: Dictionary in shard.pack_context[table]:
			if int(row.NpcSpawnPackID) != pack_id: continue
			result[table].append(row.duplicate(true))
			if row.get("WeeklyOpenTimeGroupID", 0) != 0 and row.WeeklyOpenTimeGroupID not in group_ids: group_ids.append(row.WeeklyOpenTimeGroupID)
	for view: Dictionary in views_by_pack.get(pack_id, []):
		if view.get("ServerLimitSetID", 0) != 0: server_ids[int(view.ServerLimitSetID)] = true
	for row: Dictionary in result.get("NpcRepresentativeSpawnView", []):
		if row.get("ServerLimitSetID", 0) != 0: server_ids[int(row.ServerLimitSetID)] = true
	result.weekly = _weekly(group_ids)
	result.server_limits = []; result.unresolved_server_limit_sets = []
	for set_id: Variant in server_ids:
		var rows: Array = _matching("ServerLimit", "ServerLimitSetID", set_id)
		result.server_limits.append_array(rows)
		if rows.is_empty(): result.unresolved_server_limit_sets.append(set_id)
	result.world_boss_prerequisites = []
	for boss: Dictionary in result.get("WorldBossRaidView", []):
		result.world_boss_prerequisites.append_array(_matching("WorldBossRaidPrerequisite", "WorldBossRaidID", boss.ID))
		result.world_boss_prerequisites.append_array(_matching("WorldBossRaidPrerequisiteView", "BossRaidID", boss.ID))
	return result

func context_rows(table: String) -> Array:
	# Includes date/prerequisite/category definitions without assigning new semantics.
	return contexts.get(table, []).duplicate(true) if loaded else []

func spawn_evidence(pack_id: int = -1) -> Array:
	var result: Array = []
	if not loaded: return result
	for relation: Dictionary in shard.spawn_relations:
		var current: int = int(relation.NpcSpawnPackID)
		if pack_id >= 0 and current != pack_id: continue
		var classes: Array = []
		for view: Dictionary in views_by_pack.get(current, []):
			classes.append({"view": view.duplicate(true), "npc_class": npcs[int(view.NpcClassID)].duplicate(true), "definition_state": definition_state(view)})
		result.append({"relation": relation.duplicate(true), "territory": territories[int(relation.TerritoriesID)].duplicate(true),
			"classes": classes, "class_link_state": "UNRESOLVED_CLASS_VIEW" if classes.is_empty() else "EXPLICIT_CLASS_VIEW",
			"placement_state": "TERRITORY_DEFINITION_ONLY; INSTANCE_COUNT_POSITION_AND_RESPAWN_UNKNOWN"})
	return result

func portal_evidence() -> Array:
	var result: Array = []
	if not loaded: return result
	for link: Dictionary in shard.portals:
		var entry: Dictionary = link.duplicate(true)
		var target: Dictionary = entry.target_territory
		entry.source_snapshot = "patch523"
		entry.runtime_enabled = false
		entry.arrival_selection = "EXACT_POINT" if target.StartX == target.EndX and target.StartY == target.EndY else "REGION_REQUIRES_ARRIVAL_POLICY"
		entry.reason = "Portal trigger geometry and activation conditions are not supplied by Content"
		result.append(entry)
	return result

func portal_context(portal_id: int) -> Dictionary:
	if not loaded: return {}
	for link: Dictionary in shard.portals:
		if int(link.portal.ID) != portal_id: continue
		var target: Dictionary = link.target_territory
		var lid: int = int(target.LandID)
		var attributes: Array = _matching("LandAttribute", "LandID", lid)
		var time_limits: Array = _matching("LandTimeLimit", "LandID", lid)
		var time_groups: Array = []
		for row: Dictionary in time_limits: time_groups.append_array(_matching("LandTimeLimitGroup", "ID", row.LandTimeLimitGroupID))
		var weekly: Array = _matching("LandWeeklyOpenTime", "LandId", lid)
		var weekly_ids: Array = []
		for row: Dictionary in weekly: weekly_ids.append(row.WeeklyTypeGroupId)
		var separate_routes: Array = []
		for relation: Dictionary in _matching("LandTeleportTerritories", "TerritoryID", target.ID):
			var prerequisites: Array = _matching("LandTeleportPrerequisite", "LandTeleportID", relation.LandTeleportID)
			var definitions: Array = []
			for prerequisite: Dictionary in prerequisites: definitions.append_array(_matching("Prerequisite", "ID", prerequisite.PrerequisiteID))
			separate_routes.append({"relation": relation, "land_teleport": _matching("LandTeleport", "ID", relation.LandTeleportID),
				"prerequisite_links": prerequisites, "prerequisites": definitions,
				"applies_to_portal": "UNVERIFIED_SEPARATE_TRAVEL_ROUTE"})
		var dungeon_links: Array = _matching("CompetitionDungeonLand", "LandID", lid)
		var dungeons: Array = []; var dungeon_views: Array = []
		for row: Dictionary in dungeon_links:
			dungeons.append_array(_matching("CompetitionDungeon", "ID", row.CompetitionDungeonID))
			dungeon_views.append_array(_matching("CompetitionDungeonView", "ID", row.CompetitionDungeonID))
		return {"portal": link.duplicate(true), "target_land_attributes": attributes,
			"attribute_scope": "RAW_LAND_AND_TERRITORY_RULES; NOT_PORTAL_ACTIVATION_OR_COLLISION",
			"land_time_limits": time_limits, "land_time_limit_groups": time_groups,
			"land_weekly_links": weekly, "weekly": _weekly(weekly_ids),
			"competition_dungeon_land": dungeon_links, "competition_dungeons": dungeons,
			"competition_dungeon_views": dungeon_views, "separate_land_teleport_routes": separate_routes}
	return {}
