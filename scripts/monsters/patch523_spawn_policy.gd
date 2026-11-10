extends RefCounted
## Optional latest-definition gate for existing explicit source-M host encounters.
## This never creates a location, count, clock, host binding or native pixel claim.
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
const ORIGINAL = preload("res://scripts/monsters/base508_monster_context.gd")
const DEFINITION_PREFERENCES = preload("res://scripts/maps/current523_source_definition_preferences.gd")
static var catalogs: Dictionary = {}
static var catalog_errors: Dictionary = {}

## The deterministic build of the pinned cumulative523 source zip.
const PINNED_PACK_SHA256: String = "2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
## Installed locations checked when no launch argument is given (Android editor
## runs have no user arguments). Only the pinned manifest hash is accepted here.
const INSTALLED_ROOTS: Array[String] = ["user://patch523-world-links", "res://private_packs/patch523-world-links"]

static func settings() -> Dictionary:
	var result: Dictionary = {"enabled": false, "root": "", "sha": ""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-world-links="):
			result.enabled = true; result.root = arg.trim_prefix("--patch523-world-links=")
		if arg.begins_with("--patch523-world-links-sha256="):
			result.enabled = true; result.sha = arg.trim_prefix("--patch523-world-links-sha256=")
	if result.enabled: return result
	# The 523 resource pack installer records where it put the world links
	# (the same selection 523 play mode binds); without this the installed
	# definitions never reached monster spawning on 523 maps.
	var selected: Dictionary = DEFINITION_PREFERENCES.read()
	if selected.get("ok", false) and selected.get("configured", false):
		var selected_manifest: String = str(selected.directory).path_join("manifest.json")
		if FileAccess.file_exists(selected_manifest) and FileAccess.get_sha256(selected_manifest) == PINNED_PACK_SHA256:
			return {"enabled": true, "root": str(selected.directory), "sha": PINNED_PACK_SHA256, "installed": true}
	for candidate: String in INSTALLED_ROOTS:
		var manifest: String = candidate.path_join("manifest.json")
		if FileAccess.file_exists(manifest) and FileAccess.get_sha256(manifest) == PINNED_PACK_SHA256:
			return {"enabled": true, "root": candidate, "sha": PINNED_PACK_SHA256, "installed": true}
	return result

static func marked(record: Dictionary) -> bool:
	if record.get("source") == "lineagem_base508" or str(record.get("sourceId", "")).begins_with("lineagem_base508:npc:"): return true
	for key: Variant in record:
		if str(key).begins_with("source_m_"): return true
	return false

static func hold(reason: String) -> Dictionary:
	return {"ok": false, "applied": true, "reason": reason, "record": {}}

static func row_with_id(rows: Array, id: int) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		if row.get("ID") != id: continue
		if not result.is_empty(): return {} # Repeated IDs do not choose an arbitrary variant.
		result = row
	return result

static func admit(record: Dictionary, host_map_id: String, explicit_catalog: RefCounted = null) -> Dictionary:
	var options: Dictionary = settings()
	if not marked(record) or (not options.enabled and explicit_catalog == null):
		return {"ok": true, "applied": false, "reason": "existing_game_policy", "record": record}
	if record.get("source") != "lineagem_base508": return hold("partial_source_identity")
	for key: String in ["source_m_npc_id", "source_m_sprite_id", "source_m_spawn_view_id", "source_m_territory_link_id"]:
		if not LINKS._integer(record.get(key)) or int(record[key]) < (0 if key == "source_m_sprite_id" else 1): return hold("invalid_source_identity")
	var npc_id: int = int(record.source_m_npc_id)
	var view_id: int = int(record.source_m_spawn_view_id)
	var link_id: int = int(record.source_m_territory_link_id)
	var expected_key: String = "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [npc_id, view_id, link_id]
	if record.get("sourceId") != expected_key: return hold("source_key_mismatch")
	if bool(record.get("catalog_only", false)) or str(record.get("source_m_host_placement", "")).is_empty() or host_map_id.is_empty(): return hold("existing_host_placement_contract_required")
	if record.has("source_m_bound_legacy_slot"):
		var authorized: bool = false
		for binding: Dictionary in BINDINGS.data().get("bindings", []) + BINDINGS.extension_bindings():
			if binding.get("npc_id") == npc_id and binding.get("spawn_view_id") == view_id and binding.get("territory_link_id") == link_id and binding.get("legacy_game_db_index") == record.source_m_bound_legacy_slot and binding.get("host_map_id") == host_map_id: authorized = true
		if not authorized: return hold("existing_host_binding_mismatch")
	elif record.get("source_m_catalog_key") != expected_key or record.get("source_m_runtime_host_map") != host_map_id:
		return hold("existing_host_region_contract_required")
	var prior: Variant = record.get("source_m_context")
	if not prior is Dictionary: return hold("source_context_required")
	for key: String in ["land", "territory", "territory_link", "spawn_view", "npc"]:
		if not prior.get(key) is Dictionary: return hold("incomplete_source_context")
	if not LINKS._integer(prior.land.get("ID")) or not prior.land.get("AssetPath") is String: return hold("invalid_source_land")
	if prior.npc.get("ID") != npc_id or prior.spawn_view.get("ID") != view_id or prior.spawn_view.get("NpcClassID") != npc_id or prior.territory_link.get("ID") != link_id:
		return hold("record_context_identity_mismatch")
	if prior.npc.get("Sprite") != record.source_m_sprite_id or prior.spawn_view.get("NpcSpawnPackID") != prior.territory_link.get("NpcSpawnPackID") or prior.territory_link.get("TerritoriesID") != prior.territory.get("ID") or prior.territory.get("LandID") != prior.land.ID:
		return hold("record_context_identity_mismatch")
	var catalog: RefCounted = explicit_catalog
	if catalog == null:
		var cache_key: String = "%s|%s|%d|%s" % [options.root, options.sha, int(prior.land.ID), prior.land.AssetPath]
		if catalog_errors.has(cache_key): return hold(str(catalog_errors[cache_key]))
		if not catalogs.has(cache_key):
			var candidate: RefCounted = LINKS.shared_land(str(options.root), int(prior.land.ID), str(prior.land.AssetPath), str(options.sha))
			if candidate == null:
				catalog_errors[cache_key] = "patch523_pack_rejected: " + LINKS.shared_problem
				return hold(str(catalog_errors[cache_key]))
			catalogs[cache_key] = candidate
		catalog = catalogs[cache_key]
	if not catalog.loaded or catalog.land.get("ID") != prior.land.ID or catalog.land.get("AssetPath") != prior.land.AssetPath: return hold("patch523_land_context_mismatch")
	var view: Dictionary = row_with_id(catalog.shard.spawn_views, view_id)
	var relation: Dictionary = row_with_id(catalog.shard.spawn_relations, link_id)
	if view.is_empty() or relation.is_empty(): return hold("patch523_explicit_link_unresolved")
	if view.get("NpcClassID") != npc_id or view.get("NpcSpawnPackID") != relation.get("NpcSpawnPackID") or relation.get("NpcSpawnPackID") != prior.territory_link.get("NpcSpawnPackID") or relation.get("TerritoriesID") != prior.territory_link.get("TerritoriesID"):
		return hold("patch523_pack_identity_changed")
	var latest_npc: Dictionary = catalog.npcs.get(npc_id, {})
	var territory: Dictionary = catalog.territories.get(int(relation.TerritoriesID), {})
	if latest_npc.is_empty() or territory.is_empty(): return hold("patch523_class_or_territory_unresolved")
	var state: String = LINKS.definition_state(view)
	if state == "EXPLICIT_IS_SPAWN_0": return hold("patch523_is_spawn_0")
	if state != "DEFINED_IS_SPAWN_1_ACTIVATION_UNKNOWN": return hold("patch523_conditional_or_unknown_is_spawn")
	if not LINKS._integer(view.get("ServerLimitSetID")) or int(view.ServerLimitSetID) != 0: return hold("patch523_server_context_required")
	var conditions: Dictionary = catalog.pack_conditions(int(view.NpcSpawnPackID))
	for key: String in ["NpcSpawnPackSchedulePeriod", "DaynightSpawnPack", "WorldBossRaidView"]:
		if not conditions.get(key, []).is_empty(): return hold("patch523_schedule_context_required")
	var baseline: Dictionary = ORIGINAL.context(npc_id, view_id, link_id)
	if not baseline.get("ok", false): return hold("authoritative_base508_context_required")
	if baseline.land.ID != prior.land.ID or baseline.land.AssetPath != prior.land.AssetPath or baseline.territory_link.NpcSpawnPackID != relation.NpcSpawnPackID or baseline.territory_link.TerritoriesID != relation.TerritoriesID:
		return hold("authoritative_source_context_mismatch")
	if latest_npc.get("Sprite") != record.source_m_sprite_id: return hold("patch523_sprite_changed")
	if view.get("NpcLevel") != baseline.spawn_view.NpcLevel or view.get("NpcLevel") != prior.spawn_view.get("NpcLevel") or record.get("source_m_spawn_npc_level") != view.NpcLevel: return hold("patch523_spawn_level_changed")
	for key: String in ["ID", "LandID", "StartX", "StartY", "EndX", "EndY"]:
		if territory.get(key) != baseline.territory.get(key) or prior.territory.get(key) != baseline.territory.get(key): return hold("patch523_territory_changed")
	# The current renderer/combat contract is base508. Changes need their own
	# explicit adapter; do not silently label old stats or occupancy as latest.
	for key: String in ["Sprite", "HP", "MP", "AC", "MR", "Exp", "Category", "IsOccupyLandTile", "TestNPC"]:
		if latest_npc.get(key) != baseline.npc.get(key) or prior.npc.get(key) != baseline.npc.get(key): return hold("patch523_npc_contract_changed")
	if not catalog.has_method("context_rows"): return hold("patch523_target_category_required")
	var category: Dictionary = row_with_id(catalog.context_rows("NpcCategory"), int(latest_npc.Category))
	if not category.get("IsAutoSelectable") is bool or not category.get("IsSelectable") is bool:
		return hold("patch523_target_category_required")
	var result: Dictionary = record.duplicate(true)
	# Consume current selection flags separately; preserve the508 source context.
	result.source_m_targeting = {"snapshot":"patch523", "category_id":category.ID,
		"IsAutoSelectable":category.IsAutoSelectable, "IsSelectable":category.IsSelectable}
	result.source_m_patch523_admission = {"snapshot": "patch523", "manifest_sha256": catalog.manifest_sha256,
		"npc_id": npc_id, "spawn_view_id": view_id, "territory_link_id": link_id,
		"is_spawn": view.IsSpawn, "server_limit_set_id": view.ServerLimitSetID,
		"host_map_id": host_map_id, "placement_policy": "EXISTING_HOST_POSITION_COUNT_RESPAWN_RETAINED",
		"activation_scope": "LATEST_EXPLICIT_DEFINITION_GATE; NOT_NATIVE_SERVER_ACTIVATION_PROOF"}
	return {"ok": true, "applied": true, "reason": "existing_host_contract_passes_patch523", "record": result}
