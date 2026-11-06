extends SceneTree
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const CONTEXT = preload("res://scripts/monsters/base508_monster_context.gd")
const BINDINGS = preload("res://scripts/monsters/base508_monster_bindings.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

class CatalogFixture extends RefCounted:
	var loaded: bool = true
	var manifest_sha256: String = "f".repeat(64)
	var land: Dictionary = {}
	var shard: Dictionary = {}
	var npcs: Dictionary = {}
	var territories: Dictionary = {}
	var conditions: Dictionary = {}
	var categories: Array = []
	func _init() -> void:
		# Existing committed native context; mutations below are explicit fixtures.
		var joined: Dictionary = preload("res://scripts/monsters/base508_monster_context.gd").context(90, 762, 558)
		land = joined.land.duplicate(true)
		shard = {"spawn_views": [joined.spawn_view.duplicate(true)], "spawn_relations": [joined.territory_link.duplicate(true)]}
		npcs = {90: joined.npc.duplicate(true)}
		territories[int(joined.territory.ID)] = joined.territory.duplicate(true)
		categories = [joined.category.duplicate(true)]
	func pack_conditions(_id: int) -> Dictionary: return conditions
	func context_rows(table: String) -> Array: return categories.duplicate(true) if table == "NpcCategory" else []
	func record() -> Dictionary:
		var key: String = "lineagem_base508:npc:90:spawn:762:territory:558"
		return {"source": "lineagem_base508", "sourceId": key, "source_m_npc_id": 90, "source_m_sprite_id": npcs[90].Sprite, "source_m_spawn_view_id": 762, "source_m_territory_link_id": 558,
			"source_m_host_placement": "TEST_EXISTING_HOST_REGION; NOT_ORIGINAL_PLACEMENT", "source_m_catalog_key": key, "source_m_runtime_host_map": "aden_world", "catalog_only": false,
			"hp": npcs[90].HP, "lv": shard.spawn_views[0].NpcLevel, "source_m_spawn_npc_level": shard.spawn_views[0].NpcLevel, "atk": 7, "speed": 111.0,
			"source_m_context": {"land": land.duplicate(true), "spawn_view": shard.spawn_views[0].duplicate(true), "territory_link": shard.spawn_relations[0].duplicate(true), "territory": territories.values()[0].duplicate(true), "npc": npcs[90].duplicate(true)}}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_SPAWN_FAIL: ", label)

func _initialize() -> void:
	if DEFINITIONS.not_installed():
		# NPC rows come only from the user's owned current523 ZIP. Verify the
		# absent-install hold honestly; this is not counted as the full contract.
		print("VALIDATION_SCOPE current523 definitions not installed: spawn admission contract needs the owned ZIP")
		var joined: Dictionary = CONTEXT.context(90, 762, 558)
		check(not joined.ok and joined.reason == "npc_id_missing", "absent current523 install supplies no substitute NPC context")
		print("PATCH523_SPAWN_POLICY_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "scope": "CURRENT523_NOT_INSTALLED"}))
		quit(0 if failures.is_empty() else 1)
		return
	var catalog := CatalogFixture.new()
	var record: Dictionary = catalog.record()
	var original: String = JSON.stringify(record)
	var admitted: Dictionary = POLICY.admit(record, "aden_world", catalog)
	check(admitted.ok and admitted.applied, "existing explicit host record admitted")
	check(admitted.record.hp == record.hp and admitted.record.lv == record.lv and admitted.record.atk == 7 and admitted.record.speed == 111.0, "existing record parameters retained")
	check(admitted.record.sourceId == record.sourceId and JSON.stringify(record) == original, "identity and input immutable")
	check(admitted.record.source_m_patch523_admission.placement_policy == "EXISTING_HOST_POSITION_COUNT_RESPAWN_RETAINED", "host geometry/clock policy labelled")
	check(admitted.record.source_m_targeting.IsAutoSelectable == false and admitted.record.source_m_targeting.IsSelectable == true, "latest source category keeps automatic and manual selection separate")
	catalog.categories[0].IsAutoSelectable = true
	check(POLICY.admit(record, "aden_world", catalog).record.source_m_targeting.IsAutoSelectable == true and JSON.stringify(record) == original, "latest category overrides without rewriting original508 context")
	catalog.categories[0].IsAutoSelectable = 1
	check(POLICY.admit(record, "aden_world", catalog).reason == "patch523_target_category_required", "unknown category flag is held")
	catalog.categories[0].IsAutoSelectable = false
	for flag: Variant in [0, 2, null, false, "1"]:
		catalog.shard.spawn_views[0].IsSpawn = flag
		check(not POLICY.admit(record, "aden_world", catalog).ok, "reject inactive/conditional/unknown flag " + str(flag))
	catalog.shard.spawn_views[0].erase("IsSpawn")
	check(not POLICY.admit(record, "aden_world", catalog).ok, "missing flag held")
	catalog.shard.spawn_views[0].IsSpawn = 1
	for server: int in [274, 772]:
		catalog.shard.spawn_views[0].ServerLimitSetID = server
		check(POLICY.admit(record, "aden_world", catalog).reason == "patch523_server_context_required", "server condition not bypassed")
	catalog.shard.spawn_views[0].ServerLimitSetID = 0
	for table: String in ["NpcSpawnPackSchedulePeriod", "DaynightSpawnPack", "WorldBossRaidView"]:
		catalog.conditions[table] = [{"ID": 1}]
		check(POLICY.admit(record, "aden_world", catalog).reason == "patch523_schedule_context_required", "time context held " + table)
		catalog.conditions.clear()
	catalog.shard.spawn_views.append(catalog.shard.spawn_views[0].duplicate(true))
	check(not POLICY.admit(record, "aden_world", catalog).ok, "ambiguous view ID rejected")
	catalog.shard.spawn_views.pop_back()
	for field: String in ["source", "sourceId", "source_m_npc_id", "source_m_sprite_id", "source_m_spawn_view_id", "source_m_territory_link_id", "source_m_context", "source_m_host_placement", "source_m_runtime_host_map"]:
		var bad: Dictionary = record.duplicate(true); bad.erase(field)
		check(not POLICY.admit(bad, "aden_world", catalog).ok, "partial native identity rejected " + field)
	catalog.npcs[90].Sprite = 999
	check(not POLICY.admit(record, "aden_world", catalog).ok, "changed Sprite held")
	catalog.npcs[90].Sprite = 31
	catalog.npcs[90].HP = 999
	check(not POLICY.admit(record, "aden_world", catalog).ok, "changed native combat contract held")
	catalog.npcs[90].HP = record.source_m_context.npc.HP
	var territory_id: int = int(record.source_m_context.territory.ID)
	catalog.territories[territory_id].EndX += 99
	check(not POLICY.admit(record, "aden_world", catalog).ok, "changed Territory held")
	catalog.territories[territory_id].EndX = record.source_m_context.territory.EndX
	var wrong_level: Dictionary = record.duplicate(true); wrong_level.source_m_spawn_npc_level = 999
	check(not POLICY.admit(wrong_level, "aden_world", catalog).ok, "effective level cannot differ from source view")
	var forged: Dictionary = record.duplicate(true); forged.source_m_context.npc.HP = 999; catalog.npcs[90].HP = 999
	check(not POLICY.admit(forged, "aden_world", catalog).ok, "caller prior cannot replace authoritative base508 baseline")
	catalog.npcs[90].HP = record.source_m_context.npc.HP
	catalog.land.AssetPath = "4/"
	check(not POLICY.admit(record, "aden_world", catalog).ok, "AssetPath namespace held")
	catalog.land.AssetPath = "Aden/"
	check(not POLICY.admit(record, "source_0", catalog).ok, "host map contract retained separately")
	check(not POLICY.admit({"source_m_npc_id": 90}, "aden_world", catalog).ok, "stripped source marker cannot bypass gate")
	var stripped: Dictionary = record.duplicate(true)
	for marker: String in ["source", "source_m_npc_id", "sourceId"]: stripped.erase(marker)
	check(not POLICY.admit(stripped, "aden_world", catalog).ok, "retained native operational fields cannot bypass gate")
	check(not POLICY.admit({"sourceId": "lineagem_base508:npc:90:spawn:20:territory:30"}, "aden_world", catalog).ok, "stripped marker namespace cannot bypass gate")
	check(not POLICY.admit(record, "aden_world", CatalogFixture.new()).record.has("count"), "no spawn count supplied")
	var legacy: Dictionary = {"sourceId": "l1j_tw380_npc_45010", "name": "existing", "hp": 17}
	var unchanged: Dictionary = POLICY.admit(legacy, "aden_world", catalog)
	check(unchanged.ok and not unchanged.applied and unchanged.record == legacy, "PC source identity never matched by number")
	var private_root: String = ""; var private_sha: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-world-links="): private_root = arg.trim_prefix("--patch523-world-links=")
		if arg.begins_with("--patch523-world-links-sha256="): private_sha = arg.trim_prefix("--patch523-world-links-sha256=")
	if not private_root.is_empty():
		var by_land: Dictionary = {}
		for binding: Dictionary in BINDINGS.data().bindings + BINDINGS.extension_bindings():
			var existing: Dictionary = CONTEXT.record(int(binding.npc_id), int(binding.spawn_view_id), int(binding.territory_link_id))
			existing.catalog_only = false; existing.source_m_host_placement = binding.placement_contract; existing.source_m_bound_legacy_slot = binding.legacy_game_db_index
			var lid: int = int(existing.source_m_context.land.ID)
			if not by_land.has(lid):
				var links = LINKS.new()
				check(links.load_land(private_root, lid, str(existing.source_m_context.land.AssetPath), private_sha), "actual source Land loads")
				by_land[lid] = links
			var checked: Dictionary = POLICY.admit(existing, str(binding.host_map_id), by_land[lid])
			check(checked.ok and checked.applied, "actual existing host contract " + str(binding.npc_id))
			check(not POLICY.admit(existing, "source_0", by_land[lid]).ok, "existing binding does not leak to another host")
	print("PATCH523_SPAWN_POLICY_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
