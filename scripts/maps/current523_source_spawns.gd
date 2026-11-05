extends RefCounted
## Monster regions for a current523 source field, built from the verified
## cumulative523 world-links Land shard (Territories / NpcSpawnPackTerritory /
## NpcSpawnPackNpcClassView). Kind and area come from the original definitions.
## Count, respawn period and the boss timer are an explicit TWILIGHT policy:
## the original tables do not contain instance counts, positions or periods.
## Each region requests one exact source key; the existing roster, admission
## gate and visual owner still decide whether an actor can be created.
const LINKS = preload("res://scripts/maps/patch523_world_links.gd")
const POLICY = preload("res://scripts/monsters/patch523_spawn_policy.gd")
const FULL = preload("res://scripts/monsters/base508_authoritative_catalog.gd")
const PLACEMENT_POLICY: String = "TWILIGHT_CURRENT523_TERRITORY_DENSITY_V1"
## One actor per this many source cells of a territory, per spawn relation.
const CELLS_PER_ACTOR: int = 800
const MIN_PER_RELATION: int = 1
const MAX_PER_RELATION: int = 6
const MAX_PER_VIEW: int = 4
const MAX_TERRITORY_CELLS: int = 200000
const NORMAL_RESPAWN_SECONDS: float = 30.0
const BOSS_RESPAWN_SECONDS: float = 1800.0
## Territory labels whose packs belong to quests, PvP or scheduled content.
const EXCLUDED_TERRITORY_TAGS: Array[String] = ["[QUEST]", "[퀘스트]", "[메인]", "[깃발전]", "[스케줄]", "[이벤트]"]
## Attackable but not field-hunting targets: town people, guards, ambient slimes,
## siege, party-escort, gatekeeper and companion actors.
const NON_HUNT_CATEGORIES: Array[String] = ["Citizen", "Guard", "Slime", "SiegeNpc", "PartyNpc", "PartyImportantNpc", "LastavardGateKeeper", "Companion"]
const CONDITION_TABLES: Array[String] = ["NpcSpawnPackSchedulePeriod", "DaynightSpawnPack", "WorldBossRaidView"]

static var _catalogs: Dictionary = {}

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
	var key: String = "%s|%s|%d|%s" % [options.root, options.sha, identity.land_id, identity.asset_path]
	if _catalogs.has(key): return _catalogs[key]
	var candidate = LINKS.new()
	if not candidate.load_land(str(options.root), int(identity.land_id), str(identity.asset_path), str(options.sha)):
		push_warning("current523 출현 정의를 읽지 못했습니다: " + candidate.problem)
		return null
	_catalogs[key] = candidate
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

static func _boss(npc_id: int, territory: Dictionary) -> bool:
	if bool(FULL.npc(npc_id).get("source_ui_boss", false)): return true
	var title: String = str(territory.get("Name", ""))
	return title.contains("[필드보스]") or title.contains("[필드 보스]")

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
			if _boss(int(view.NpcClassID), territory): counts[int(view.ID)] = 1
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
			var key: String = FULL.context_key(npc_id, int(view.ID), int(relation.ID))
			if seen.has(key): continue
			seen[key] = true
			var boss: bool = _boss(npc_id, territory)
			var region: Dictionary = {"id": "m523:" + key, "source_m_key": key, "monster_types": [key],
				"source_rect": box, "source_territory_id": int(territory.ID), "source_spawn_pack_id": pack_id,
				"source_npc_level": int(view.get("NpcLevel", 0)), "mode": "boss" if boss else "normal",
				"max_count": 1 if boss else mini(count, MAX_PER_VIEW),
				"respawn_time": BOSS_RESPAWN_SECONDS if boss else NORMAL_RESPAWN_SECONDS,
				"roaming_radius": 160.0 if boss else 120.0, "min_spacing": 24.0,
				"placement_policy": PLACEMENT_POLICY}
			# Candidate territories of one boss class share one life and timer.
			if boss: region.boss_id = "m523:boss:%d" % npc_id
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
