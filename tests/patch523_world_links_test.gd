extends SceneTree
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); printerr("PATCH523_FAIL: ", label)

func write_json(path: String, value: Dictionary) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value)); file.close()
	return {"file": path.get_file(), "sha256": FileAccess.get_sha256(path), "bytes": FileAccess.get_file_as_bytes(path).size()}

func fixture() -> Dictionary:
	var path: String = "user://patch523-fixture"
	DirAccess.make_dir_recursive_absolute(path.path_join("lands"))
	var territory: Dictionary = {"ID": 80, "LandID": 4, "StartX": 1, "StartY": 2, "EndX": 3, "EndY": 4}
	var target: Dictionary = {"ID": 81, "LandID": 4, "StartX": 10, "StartY": 20, "EndX": 10, "EndY": 20}
	var native_land: Dictionary = {"ID": 4, "AssetPath": "Aden/"}
	var shard: Dictionary = {"schema": 1, "source_snapshot": "patch523", "land": native_land,
		"territories": [territory, target], "portals": [{"portal": {"ID": 12, "SourceLandID": 4, "SourceX": 1, "SourceY": 2, "AssetID": 0, "TargetTerritoryID": 81}, "target_territory": target, "target_land": native_land}],
		"spawn_relations": [{"ID": 1, "NpcSpawnPackID": 11, "TerritoriesID": 80, "Probability": 0}, {"ID": 2, "NpcSpawnPackID": 12, "TerritoriesID": 80, "Probability": 1}],
		"spawn_views": [{"ID": 1, "NpcSpawnPackID": 11, "NpcClassID": 90, "NpcLevel": 7, "IsSpawn": 0, "ServerLimitSetID": 274}, {"ID": 2, "NpcSpawnPackID": 11, "NpcClassID": 90, "NpcLevel": 9, "IsSpawn": 1, "ServerLimitSetID": 0}, {"ID": 3, "NpcSpawnPackID": 11, "NpcClassID": 90, "NpcLevel": 10, "IsSpawn": 2, "ServerLimitSetID": 0}],
		"npc_classes": [{"ID": 90, "IsOccupyLandTile": false}], "unresolved_class_view_packs": [12],
		"pack_context": {"NpcSpawnPackSchedulePeriod": [{"ID": 1, "NpcSpawnPackID": 11, "WeeklyOpenTimeGroupID": 10, "NaturallyDisappear": false}], "DaynightSpawnPack": [{"ID": 1, "NpcSpawnPackID": 11}, {"ID": 1, "NpcSpawnPackID": 11}], "WorldBossRaidView": [], "NpcRepresentativeSpawnView": []}}
	var shard_spec: Dictionary = write_json(path.path_join("lands/4.json"), shard)
	shard_spec.file = "lands/4.json"; shard_spec.asset_path = "Aden/"
	var tables: Dictionary = {}
	for name: String in ["NpcCategory", "ServerLimit", "WeeklyOpenTimeGroup", "WeeklyOpenTimeGroupSet", "WeeklyOpenTime", "WeeklyOpenTimeEntity", "LandAttribute", "LandAttributeType", "LandTimeLimit", "LandTimeLimitGroup", "LandWeeklyOpenTime", "DateTimes", "DateTimes_Korean", "DateTimes_Taiwanese", "DateTimes_Japanese", "DateTimes_Chinese", "CompetitionDungeon", "CompetitionDungeonLand", "CompetitionDungeonView", "LandTeleport", "LandTeleportTerritories", "LandTeleportPrerequisite", "Prerequisite", "PrerequisiteType", "WorldBossRaidPrerequisite", "WorldBossRaidPrerequisiteView"]: tables[name] = []
	tables.WeeklyOpenTimeGroupSet = [{"ID": 1, "WeeklyOpenTimeGroupId": 10, "WeeklyOpenTimeId": 20}]
	tables.WeeklyOpenTimeEntity = [{"ID": 1, "WeeklyOpenTimeID": 20, "ServiceRegionCode": "KR", "Hours": 21}, {"ID": 2, "WeeklyOpenTimeID": 20, "ServiceRegionCode": "TW", "Hours": 19}]
	tables.LandTeleportTerritories = [{"ID": 1, "LandTeleportID": 31, "TerritoryID": 81}]
	tables.LandTeleport = [{"ID": 31, "TeleportCost": 10000, "AllowMapTeleport": false}]
	tables.LandTeleportPrerequisite = [{"LandTeleportID": 31, "PrerequisiteID": 32}]
	tables.Prerequisite = [{"ID": 32, "PrerequisiteTypeID": 1, "Value": 91}]
	var context_spec: Dictionary = write_json(path.path_join("conditions.json"), {"schema": 1, "source_snapshot": "patch523", "tables": tables})
	var manifest: Dictionary = {"schema": 1, "source_snapshot": "patch523", "source_zip_sha256": LINKS.SOURCE_SHA256, "lands": {"4": shard_spec}, "conditions": context_spec}
	var manifest_spec: Dictionary = write_json(path.path_join("manifest.json"), manifest)
	return {"root": path, "sha": manifest_spec.sha256}

func _initialize() -> void:
	var spec: Dictionary = fixture()
	var links = LINKS.new()
	check(links.load_land(spec.root, 4, "Aden/", spec.sha), "fixture loads through production loader")
	check(links.spawn_evidence().size() == 2, "separate Territory relations")
	var evidence: Array = links.spawn_evidence(11)
	check(evidence[0].classes.size() == 3, "levels and IsSpawn variants retained")
	check(evidence[0].classes[0].definition_state == "EXPLICIT_IS_SPAWN_0", "explicit zero exclusion")
	check(evidence[0].classes[1].definition_state == "DEFINED_IS_SPAWN_1_ACTIVATION_UNKNOWN", "one does not imply active")
	check(evidence[0].classes[2].definition_state == "CONDITIONAL_OR_UNKNOWN_IS_SPAWN", "conditional preserved")
	check(LINKS.definition_state({"IsSpawn": false}) == "UNKNOWN_IS_SPAWN" and LINKS.definition_state({}) == "UNKNOWN_IS_SPAWN", "unknown and bool are not numeric zero")
	check(links.spawn_evidence(12)[0].class_link_state == "UNRESOLVED_CLASS_VIEW", "missing pack not replaced")
	evidence[0].classes[0].view.IsSpawn = 1
	check(links.spawn_evidence(11)[0].classes[0].view.IsSpawn == 0, "query cannot mutate source")
	var conditions: Dictionary = links.pack_conditions(11)
	check(conditions.DaynightSpawnPack.size() == 2, "duplicate daynight rows retained")
	check(conditions.weekly.entities.size() == 2 and conditions.weekly.entities[0].ServiceRegionCode == "KR" and conditions.weekly.entities[1].ServiceRegionCode == "TW", "service region schedules remain separate")
	check(274 in conditions.unresolved_server_limit_sets and conditions.server_limits.is_empty(), "missing server Set274 is unresolved")
	var portals: Array = links.portal_evidence()
	check(portals.size() == 1 and not portals[0].runtime_enabled, "no inferred automatic activation")
	check(portals[0].arrival_selection == "EXACT_POINT", "exact point preserved")
	var context: Dictionary = links.portal_context(12)
	check(context.separate_land_teleport_routes[0].land_teleport[0].TeleportCost == 10000, "route cost retained")
	check(context.separate_land_teleport_routes[0].applies_to_portal == "UNVERIFIED_SEPARATE_TRAVEL_ROUTE", "same destination does not grant portal cost/level")
	check(not links.load_land(spec.root, 4, "4/", spec.sha) and not links.loaded and links.spawn_evidence().is_empty(), "wrong AssetPath rejects and clears active data")
	check(not links.load_land(spec.root, 30, "30/", spec.sha), "numeric Land cannot be substituted")
	check(not links.load_land(spec.root, 4, "Aden/", "0".repeat(64)), "wrong manifest digest rejects")
	# Shared read-only data: one parse of conditions.json and of each Land shard.
	LINKS.reset_shared()
	var first: RefCounted = LINKS.shared_land(spec.root, 4, "Aden/", spec.sha)
	var second: RefCounted = LINKS.shared_land(spec.root, 4, "Aden/", spec.sha)
	check(first != null and first.loaded and is_same(first, second), "a shared Land is loaded once")
	var separate = LINKS.new()
	check(separate.load_land(spec.root, 4, "Aden/", spec.sha) and is_same(separate.contexts, first.contexts), "conditions.json is parsed once and shared")
	check(separate.pack_conditions(11) == first.pack_conditions(11), "a shared load answers exactly like its own")
	check(LINKS.shared_land(spec.root, 4, "4/", spec.sha) == null and not LINKS.shared_problem.is_empty(), "a rejected shared load reports and is not cached")
	check(LINKS.shared_land(spec.root, 4, "Aden/", "0".repeat(64)) == null, "a shared load still checks the manifest digest")
	var conditions_path: String = spec.root.path_join("conditions.json")
	var kept: String = FileAccess.get_file_as_string(conditions_path)
	var rewrite := FileAccess.open(conditions_path, FileAccess.WRITE); rewrite.store_string(kept + " "); rewrite.close()
	check(not LINKS.new().load_land(spec.root, 4, "Aden/", spec.sha), "a changed conditions.json is rejected even when shared")
	rewrite = FileAccess.open(conditions_path, FileAccess.WRITE); rewrite.store_string(kept); rewrite.close()
	check(LINKS.new().load_land(spec.root, 4, "Aden/", spec.sha), "the restored file loads again")
	LINKS.reset_shared()
	if "--patch523-game-field" in OS.get_cmdline_user_args():
		var field_script = load("res://scripts/maps/base508_game_field.gd")
		var field = field_script.new()
		var pack_script = load("res://scripts/maps/base508_pack.gd")
		var pack = pack_script.new()
		# Host adapter harness only: no artwork/navigation is claimed by this fixture.
		pack.loaded = true; pack.manifest = {"land": {"ID": 4, "AssetPath": "Aden/"}}
		field.source_pack = pack
		field.data = {"portal": [{"id": "preserved"}], "monster_spawn": [{"id": "preserved"}]}
		check(field.configure_world_links(spec.root, spec.sha), "actual game field binds cumulative523 definitions")
		check(field.portal_evidence().size() == 1 and field.spawn_evidence().size() == 2, "actual field exposes portal and spawn links")
		var arrival: Dictionary = field.portal_contract(12)
		check(arrival.arrival_kind == "EXACT_POINT" and int(arrival.declared_arrival[0]) == 10 and int(arrival.declared_arrival[1]) == 20 and not arrival.travel_enabled, "actual field exposes immutable declared arrival without enabling travel")
		check(arrival.conditions.separate_land_teleport_routes[0].land_teleport[0].TeleportCost == 10000 and not arrival.portal_cost_known, "field contract retains separate route price without charging this portal")
		check(field.data.portal == [{"id": "preserved"}] and field.data.monster_spawn == [{"id": "preserved"}], "binding preserves gameplay placements")
		check(not field.configure_world_links(spec.root, "0".repeat(64)) and field.spawn_evidence().size() == 2, "rejected update preserves existing field binding")
	var file := FileAccess.open(spec.root.path_join("conditions.json"), FileAccess.WRITE)
	file.store_string("{}"); file.close()
	check(not links.load_land(spec.root, 4, "Aden/", spec.sha), "corrupt conditions reject")
	var private_root: String = ""; var private_sha: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-pack="): private_root = arg.trim_prefix("--patch523-pack=")
		if arg.begins_with("--patch523-sha="): private_sha = arg.trim_prefix("--patch523-sha=")
	if not private_root.is_empty():
		check(links.load_land(private_root, 4, "Aden/", private_sha), "actual cumulative523 Aden data loads")
		if links.loaded:
			check(links.portal_evidence().size() == 93, "actual Aden outgoing portals93")
			check(links.shard.spawn_relations.size() == 1343 and links.shard.spawn_views.size() == 3105, "actual Aden relations/views")
			check(links.shard.unresolved_class_view_packs.size() == 142, "actual Aden unresolved142")
			check(links.spawn_evidence(172312)[0].classes.is_empty(), "Hadin172312 remains unresolved")
			check(not links.spawn_evidence(172402)[0].classes.is_empty(), "Hadin172402 stays independent")
	print("PATCH523_WORLD_LINKS_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
