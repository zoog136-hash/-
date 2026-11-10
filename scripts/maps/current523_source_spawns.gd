extends RefCounted
## Monster regions for a current523 source field, built from the verified
## cumulative523 world-links Land shard (Territories / NpcSpawnPackTerritory /
## NpcSpawnPackNpcClassView). Kind and area come from the original definitions.
## Count is an explicit TWILIGHT density policy (the original tables have no
## instance counts or positions). Respawn follows the game's existing rules:
## normal lives use the host Aden 60-120 s window with no visible respawn
## (data/monsters/source3_map_spawns.json), bosses use the device wall-clock
## timer of data/monsters/renewed_map_spawn_rules.json (Aden 8 h, others 24 h).
## Each region requests one exact source key; the existing roster, admission
## gate and visual owner still decide whether an actor can be created.
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const PLACEMENT_POLICY: String = "TWILIGHT_CURRENT523_TERRITORY_DENSITY_V1"
## One actor per this many source cells of a territory, per spawn relation.
const CELLS_PER_ACTOR: int = 800
const MIN_PER_RELATION: int = 1
const MAX_PER_RELATION: int = 6
const MAX_PER_VIEW: int = 4
const MAX_TERRITORY_CELLS: int = 200000
## Same window as the host Aden source3 rows; release() picks [min, max-1].
const NORMAL_RESPAWN_WINDOW: Array = [60.0, 120.0]
const BOSS_RULES_PATH: String = "res://data/monsters/renewed_map_spawn_rules.json"
const ADEN_LAND_ID: int = 4
## Territory labels whose packs belong to quests, PvP or scheduled content.
const EXCLUDED_TERRITORY_TAGS: Array[String] = ["[QUEST]", "[퀘스트]", "[메인]", "[깃발전]", "[스케줄]", "[이벤트]"]
## Attackable but not field-hunting targets: town people, guards, ambient slimes,
## siege, party-escort, gatekeeper and companion actors.
const NON_HUNT_CATEGORIES: Array[String] = ["Citizen", "Guard", "Slime", "SiegeNpc", "PartyNpc", "PartyImportantNpc", "LastavardGateKeeper", "Companion"]
const CONDITION_TABLES: Array[String] = ["NpcSpawnPackSchedulePeriod", "DaynightSpawnPack", "WorldBossRaidView"]


## Existing boss timer rule: "aden_world" for Aden, "other_maps" elsewhere.
static func boss_respawn_seconds(land_id: int) -> float:
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOSS_RULES_PATH)) if FileAccess.file_exists(BOSS_RULES_PATH) else null
	var table: Dictionary = rules.get("boss_respawn_seconds", {}) if rules is Dictionary else {}
	var value: float = float(table.get("aden_world" if land_id == ADEN_LAND_ID else "other_maps", 0))
	return value if value >= 1.0 else (28800.0 if land_id == ADEN_LAND_ID else 86400.0)

## Land identity of a current523 source field: native Land.ID + exact AssetPath.
static func land_identity(field: Object) -> Dictionary:
	if field == null or not bool(field.get_meta("current523_source_field", false)): return {}
	var land_id: int = int(field.data.get("source_land_id", -1))
	var asset: String = str(field.get("source_asset")) if field.get("source_asset") != null else ""
	if asset.is_empty() and land_id == 4: asset = "Aden/"
	if land_id < 0 or asset.is_empty(): return {}
	return {"land_id": land_id, "asset_path": asset}

## Verified Land shard from the installed definition pack, or null.
static func catalog_for(field: Object) -> RefCounted:
	var identity: Dictionary = land_identity(field)
	var options: Dictionary = POLICY.settings()
	if identity.is_empty() or str(options.get("root", "")).is_empty(): return null
	var candidate: RefCounted = LINKS.shared_land(str(options.root), int(identity.land_id), str(identity.asset_path), str(options.sha))
	if candidate == null:
		push_warning("current523 출현 정의를 읽지 못했습니다: " + LINKS.shared_problem)
		return null
	return candidate

static func _excluded_territory(territory: Dictionary) -> String:
	if territory.get("IsVillage") == true: return "village"
	var title: String = str(territory.get("Name", ""))
	for tag: String in EXCLUDED_TERRITORY_TAGS:
		if title.contains(tag): return "territory_tag"
	return ""

static func _conditioned(catalog: RefCounted, pack_id: int) -> bool:
	var conditions: Dictionary = catalog.pack_conditions(pack_id)
	for table: String in CONDITION_TABLES:
		if not conditions.get(table, []).is_empty(): return true
	return false

static func _enemy(catalog: RefCounted, npc: Dictionary) -> bool:
	# Exp 0 classes are ambient town creatures (for example slimes in villages).
	if npc.is_empty() or npc.get("TestNPC") != false or int(npc.get("Exp", 0)) <= 0: return false
	var category: Dictionary = POLICY.row_with_id(catalog.context_rows("NpcCategory"), int(npc.get("Category", -1)))
	return category.get("IsAttackable") == true and not NON_HUNT_CATEGORIES.has(str(category.get("Name", "")))

## Field bosses from the current original only: the NpcClass or Territory name
## carries the original "[필드보스" label. No old base508 catalog is consulted.
static func _boss(npc: Dictionary, territory: Dictionary) -> bool:
	for title: String in [str(npc.get("Name", "")), str(territory.get("Name", ""))]:
		if title.contains("[필드보스") or title.contains("[필드 보스"): return true
	return false

static func context_key(npc_id: int, view_id: int, link_id: int) -> String:
	# Stable encounter tuple format shared with the roster/admission gate.
	return "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [npc_id, view_id, link_id]

## Rebuilds the field's monster regions. Returns a summary for the HUD notice.
static func apply(field: Object, catalog: RefCounted = null) -> Dictionary:
	var summary: Dictionary = {"ok": false, "regions": 0, "bosses": 0, "slots": 0, "relations": 0, "skipped": {}, "placement_policy": PLACEMENT_POLICY}
	if field == null: summary.reason = "no_field"; return summary
	field.data.monster_spawn = []
	if catalog == null: catalog = catalog_for(field)
	if catalog == null or not catalog.loaded:
		summary.reason = "definition_pack_unavailable"
		field.set_meta("current523_spawn_summary", summary)
		return summary
	var boss_seconds: float = boss_respawn_seconds(int(catalog.land.get("ID", -1)))
	var bounds: Rect2i = field.get("source_bounds") if field.get("source_bounds") is Rect2i else Rect2i()
	var skipped: Dictionary = {}
	var regions: Array = []
	var seen: Dictionary = {}
	var boss_ids: Dictionary = {}
	for relation: Dictionary in catalog.shard.spawn_relations:
		var territory: Dictionary = catalog.territories.get(int(relation.TerritoriesID), {})
		var pack_id: int = int(relation.NpcSpawnPackID)
		var reason: String = _excluded_territory(territory)
		if reason.is_empty() and _conditioned(catalog, pack_id): reason = "scheduled_pack"
		var box := Rect2i()
		if reason.is_empty():
			box = Rect2i(int(territory.StartX), int(territory.StartY), int(territory.EndX) - int(territory.StartX) + 1, int(territory.EndY) - int(territory.StartY) + 1)
			if box.size.x < 1 or box.size.y < 1 or box.get_area() > MAX_TERRITORY_CELLS: reason = "invalid_territory_area"
			elif bounds.has_area():
				box = box.intersection(bounds)
				if not box.has_area(): reason = "outside_field"
		var views: Array = []
		if reason.is_empty():
			for view: Dictionary in catalog.views_by_pack.get(pack_id, []):
				if LINKS.definition_state(view) != "DEFINED_IS_SPAWN_1_ACTIVATION_UNKNOWN": continue
				if not LINKS._integer(view.get("ServerLimitSetID")) or int(view.ServerLimitSetID) != 0: continue
				if not _enemy(catalog, catalog.npcs.get(int(view.NpcClassID), {})): continue
				views.append(view)
			if views.is_empty(): reason = "no_enemy_view"
		if not reason.is_empty():
			skipped[reason] = int(skipped.get(reason, 0)) + 1
			continue
		summary.relations += 1
		var budget: int = clampi(ceili(float(box.get_area()) / float(CELLS_PER_ACTOR)), MIN_PER_RELATION, MAX_PER_RELATION)
		# Bosses are kept apart from the normal budget. A pack's normal views
		# share the relation budget round-robin; the start rotates by relation
		# so large mixed packs still show each kind somewhere in the field.
		var normal: Array = []
		var counts: Dictionary = {}
		for view: Dictionary in views:
			if _boss(catalog.npcs.get(int(view.NpcClassID), {}), territory): counts[int(view.ID)] = 1
			else: normal.append(view)
		normal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.ID) < int(b.ID))
		for index: int in range(mini(budget, normal.size() * MAX_PER_VIEW)):
			if normal.is_empty(): break
			var chosen: Dictionary = normal[(index + int(relation.ID)) % normal.size()]
			counts[int(chosen.ID)] = int(counts.get(int(chosen.ID), 0)) + 1
		for view: Dictionary in views:
			var count: int = int(counts.get(int(view.ID), 0))
			if count < 1: continue
			var npc_id: int = int(view.NpcClassID)
			var key: String = context_key(npc_id, int(view.ID), int(relation.ID))
			if seen.has(key): continue
			seen[key] = true
			var boss: bool = _boss(catalog.npcs.get(npc_id, {}), territory)
			var region: Dictionary = {"id": "m523:" + key, "source_m_key": key, "monster_types": [key],
				"source_rect": box, "source_territory_id": int(territory.ID), "source_spawn_pack_id": pack_id,
				"source_npc_level": int(view.get("NpcLevel", 0)), "mode": "boss" if boss else "normal",
				"max_count": 1 if boss else mini(count, MAX_PER_VIEW),
				"respawn_time": boss_seconds if boss else float(NORMAL_RESPAWN_WINDOW[0]),
				"roaming_radius": 160.0 if boss else 120.0, "min_spacing": 24.0,
				"placement_policy": PLACEMENT_POLICY}
			if boss:
				# Candidate territories of one boss class share one life and timer.
				region.boss_id = "m523:boss:%d" % npc_id
				region.respawn_policy = "wall_clock"
			else:
				region.source_respawn_seconds = NORMAL_RESPAWN_WINDOW.duplicate()
				region.respawn_on_screen = false
			regions.append(region)
			summary.regions += 1
			summary.slots += int(region.max_count)
			if boss: boss_ids[region.boss_id] = true
	field.data.monster_spawn = regions
	summary.bosses = boss_ids.size()
	summary.skipped = skipped
	summary.ok = true
	summary.manifest_sha256 = catalog.manifest_sha256
	field.set_meta("current523_spawn_summary", summary)
	return summary
