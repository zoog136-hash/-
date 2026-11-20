extends RefCounted
## Original 523 map areas of one map (UIMapArea rows of a UIMapWorld: the
## "맵 번호"), for the original 지도 Map_Tab_Area list and 지역 정보 popup.
##
## A row: UIMapArea (not IsHide, no test tag) with its Korean name (DescID),
## UIMapAreaType (3 마을, 4 던전, 5 필드, 8 장소 = 거점 tab), UIMapLevelType
## label, its Territories box (TerritoryID, else the LandTeleport's
## LandTeleportTerritories box) and, when it has one, the original map
## teleport destination (current523_map_teleport: LandTeleport cost,
## AllowMapTeleport, prerequisites). Nothing is invented.
##
## TWILIGHT 근사 (no original table links a tapped cell or a spawn territory to
## an area): the area of a tapped cell / of a spawn region is the area of the
## same Land whose box centre is nearest.
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const MAP_TELEPORT = preload("res://scripts/maps/current523_map_teleport.gd")
const TEST_TAGS: Array[String] = ["[테스트]", "테스트]", "[미사용]"]
## Map_Tab_Area filter tabs -> UIMapAreaType IDs.
const FILTERS: Dictionary = {"field": [5], "dungeon": [4], "village": [3], "base": [8]}
const FILTER_ORDER: Array[String] = ["field", "dungeon", "village", "base"]
const APPROXIMATION: String = "TWILIGHT 근사: 가장 가까운 원본 지역(같은 Land, 지역 상자 중심 거리)"
static var _cache: Dictionary = {}
static var _generation: int = -1

static func areas(world_id: int) -> Array:
	if _generation != DEF.cache_generation():
		_cache = {}
		_generation = DEF.cache_generation()
	if _cache.has(world_id): return _cache[world_id]
	var out: Array = []
	if DEF.not_installed() or DEF.row_count("UIMapArea") <= 0 or world_id <= 0: return out
	for area: Dictionary in DEF.rows("UIMapArea"):
		if int(area.get("WorldID", 0)) != world_id: continue
		var row: Dictionary = _area(area)
		if not row.is_empty(): out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.area_id) < int(b.area_id))
	_cache[world_id] = out
	return out

static func filter_of(type_id: int) -> String:
	for key: String in FILTERS:
		if (FILTERS[key] as Array).has(type_id): return key
	return ""

static func filtered(world_id: int, filter: String) -> Array:
	var out: Array = []
	for row: Dictionary in areas(world_id):
		if filter.is_empty() or row.filter == filter: out.append(row)
	return out

static func area(world_id: int, area_id: int) -> Dictionary:
	for row: Dictionary in areas(world_id):
		if int(row.area_id) == area_id: return row
	return {}

## The area of `cell` on Land `land_id` (TWILIGHT 근사, see above), with the
## distance in cells; empty when the map has no area on that Land.
static func nearest(world_id: int, land_id: int, cell: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for row: Dictionary in areas(world_id):
		if int(row.land_id) != land_id: continue
		var box: Rect2 = row.box
		var distance: float = 0.0 if box.grow(0.5).has_point(cell) else cell.distance_to(box.get_center())
		if distance < best_distance:
			best_distance = distance
			best = row
	if best.is_empty(): return {}
	var result: Dictionary = best.duplicate()
	result["distance"] = best_distance
	result["approximation"] = APPROXIMATION
	return result

static func _area(area: Dictionary) -> Dictionary:
	var area_id: int = int(area.get("ID", 0))
	if area_id <= 0 or area.get("IsHide") == true: return {}
	var source_name: String = str(area.get("Name", ""))
	for tag: String in TEST_TAGS:
		if source_name.contains(tag): return {}
	var territory_id: int = int(area.get("TerritoryID", 0))
	var teleport_id: int = int(area.get("LandTeleportID", 0))
	if territory_id <= 0 and teleport_id > 0:
		for link: Dictionary in DEF.related("LandTeleportTerritories", "LandTeleportID", teleport_id):
			if int(link.get("TerritoryID", 0)) > 0: territory_id = int(link.TerritoryID); break
	var territory: Dictionary = DEF.row("Territories", territory_id) if territory_id > 0 else {}
	if territory.is_empty(): return {}
	var box := Rect2(float(territory.StartX), float(territory.StartY), float(int(territory.EndX) - int(territory.StartX)), float(int(territory.EndY) - int(territory.StartY)))
	if box.size.x < 0.0 or box.size.y < 0.0: return {}
	var name: String = _desc(int(area.get("DescID", 0)))
	if name.is_empty(): name = MAP_TELEPORT._strip_tags(source_name)
	var type_id: int = int(area.get("TypeID", 0))
	var level_type: Dictionary = DEF.row("UIMapLevelType", int(area.get("MapLevelTypeID", 0))) if int(area.get("MapLevelTypeID", 0)) > 0 else {}
	var destination: Dictionary = MAP_TELEPORT.destination(MAP_TELEPORT.ID_PREFIX + str(area_id))
	var level_label: String = _desc(int(level_type.get("DescID", 0))) if not level_type.is_empty() else ""
	if level_label.is_empty() and not destination.is_empty() and int(destination.min_level) > 1: level_label = "Lv.%d ~" % int(destination.min_level)
	return {"area_id": area_id, "world_id": int(area.get("WorldID", 0)), "name": name, "source_name": source_name,
		"type_id": type_id, "filter": filter_of(type_id), "level_label": level_label, "land_id": int(territory.LandID),
		"territory_id": territory_id, "box": box, "destination_id": str(destination.get("id", "")),
		"min_level": int(destination.get("min_level", 1)), "price": int(destination.get("price", 0)),
		"currency_id": int(destination.get("currency_id", MAP_TELEPORT.ADENA))}

static func _desc(desc_id: int) -> String:
	if desc_id <= 0: return ""
	return str(DEF.row("DescData_Korean", desc_id).get("Description", "")).strip_edges()

## 지역 정보: the monsters of the field's live source spawn regions
## (current523_source_spawns: original Territories / NpcSpawnPack rows) whose
## area is `area_id` (TWILIGHT 근사: nearest area of the same Land), with the
## original NpcClass name, level, 선공 (Tendency 2+), boss label, and the
## original NpcItemDropView items. Empty without the live field.
static func monsters(world_id: int, area_id: int, field: Object) -> Array:
	var target: Dictionary = area(world_id, area_id)
	if target.is_empty() or field == null or not field.get("data") is Dictionary: return []
	var by_npc: Dictionary = {}
	for raw: Variant in (field.data as Dictionary).get("monster_spawn", []):
		if not raw is Dictionary or not (raw as Dictionary).get("source_rect") is Rect2i: continue
		var region: Dictionary = raw
		var rect: Rect2i = region.source_rect
		var owner: Dictionary = nearest(world_id, int(target.land_id), Vector2(rect.get_center()))
		if owner.is_empty() or int(owner.area_id) != area_id: continue
		var npc_id: int = _npc_of(str(region.get("source_m_key", "")))
		if npc_id <= 0: continue
		var entry: Dictionary = by_npc.get(npc_id, {"npc_id": npc_id, "level": int(region.get("source_npc_level", 0)), "boss": str(region.get("mode", "")) == "boss"})
		entry.level = maxi(int(entry.level), int(region.get("source_npc_level", 0)))
		by_npc[npc_id] = entry
	var out: Array = []
	for npc_id: int in by_npc:
		var npc: Dictionary = DEF.row("NpcClass", npc_id)
		var entry: Dictionary = by_npc[npc_id]
		var name: String = _desc(int(npc.get("DescId", 0)))
		if name.is_empty(): name = MAP_TELEPORT._strip_tags(str(npc.get("Name", "")))
		entry["name"] = name
		entry["aggressive"] = int(npc.get("Tendency", 0)) >= 2
		out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.boss != b.boss: return a.boss
		if a.level != b.level: return a.level < b.level
		return a.npc_id < b.npc_id)
	return out

static func _npc_of(key: String) -> int:
	# current523_source_spawns.context_key: lineagem_base508:npc:<id>:spawn:...
	var parts: PackedStringArray = key.split(":")
	return int(parts[2]) if parts.size() > 2 and parts[1] == "npc" and parts[2].is_valid_int() else -1

## Original NpcItemDropView items of one monster (distinct, in table order).
static func drops(npc_id: int, limit: int = 30) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for row: Dictionary in DEF.related("NpcItemDropView", "NpcClassID", npc_id):
		if int(row.get("RequiredQuestID", 0)) != 0: continue
		var item_id: int = int(row.get("ItemClassID", 0))
		if item_id <= 0 or seen.has(item_id): continue
		seen[item_id] = true
		var item: Dictionary = DEF.row("ItemClass", item_id)
		var name: String = _desc(int(item.get("DescID", 0)))
		if name.is_empty(): name = MAP_TELEPORT._strip_tags(str(item.get("Name", "")))
		if name.is_empty(): continue
		out.append({"item_id": item_id, "name": name})
		if out.size() >= limit: break
	return out
