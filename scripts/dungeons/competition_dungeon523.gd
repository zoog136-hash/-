extends RefCounted
## Original 523 competition menu and a bounded TWILIGHT local entrance visit.
## This never creates a server, admission state, battle, season or time credit.
const SRC = preload("res://scripts/resources/current523_definition_rows.gd")
const PAYMENT = preload("res://scripts/maps/current523_map_travel_payment.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const WORLD: int = 274
const MASTER: int = 284
const GLOBAL_MASTER: int = 322
const FAMILY := {"world": WORLD, "master": MASTER}
const POLICY := "TWILIGHT_VERIFIED_COMPETITION_LOBBY_V1"
## User-approved single-player geographic visits only. These retain a unique
## source tariff and entrance on their HomeTerritories Land, without a normal
## event/server/window dependency or a time-pool link on that entrance Land.
const LOCAL_LOBBIES := [134, 182, 253, 314, 483]
const LOCAL_LOBBY_LANDS := [44624, 46952, 47323, 47954, 49373]
## These facts apply inside a lobby or describe client/session machinery;
## other held attributes, level, time, and connection guards remain in force.
const IN_LOBBY := ["NoTeleport", "TurnOffAutoForTeleport", "NoBookmark",
	"LandPlayerSocketTimeoutSecond", "ObjectLazyLoad", "IdleTime", "Underground"]
static var _generation := -1
static var _data: Dictionary = {}

static func _whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floorf(float(value)) and value >= low and value <= high

static func _desc(id: int) -> String:
	return str(SRC.row("DescData_Korean", id).get("Description", "")).strip_edges()

static func _single(table: String, foreign_key: String, id: int) -> Dictionary:
	var found: Array[Dictionary] = SRC.related(table, foreign_key, id)
	return found[0] if found.size() == 1 else {}

static func _arrival(teleport_id: int) -> Dictionary:
	var link: Dictionary = _single("LandTeleportTerritories", "LandTeleportID", teleport_id)
	var territory: Dictionary = SRC.row("Territories", int(link.get("TerritoryID", -1)))
	var land: Dictionary = SRC.row("Land", int(territory.get("LandID", -1)))
	if link.is_empty() or territory.is_empty() or land.is_empty() or str(land.get("AssetPath", "")).is_empty(): return {}
	var bounds: Array[int] = []
	for key: String in ["StartX", "StartY", "EndX", "EndY"]:
		if not _whole(territory.get(key), 0, 65535): return {}
		bounds.append(int(territory[key]))
	if bounds[0] > bounds[2] or bounds[1] > bounds[3]: return {}
	return {"land_id": int(land.ID), "asset_path": str(land.AssetPath),
		"territory_id": int(territory.ID), "relation_id": int(link.ID),
		"bounds": bounds, "territory_name": str(territory.Name)}

static func _projection() -> Dictionary:
	var identity: Dictionary = SRC.identity()
	if _generation == SRC.cache_generation() and not _data.is_empty(): return _data
	_generation = SRC.cache_generation()
	_data = {}
	if identity.is_empty(): return _data
	for table: String in ["CompetitionDungeon", "CompetitionDungeonView", "CompetitionDungeonAsset", "CompetitionDungeonLand", "DungeonCategory", "UIDungeonCategory", "LandTeleport", "LandTeleportTerritories", "LandTeleportPrerequisite", "Prerequisite", "LandAttribute", "LandTimeLimit", "LandWeeklyOpenTime"]:
		if SRC.row_count(table) <= 0: return _data
	var categories: Dictionary = {}
	for id: int in [WORLD, MASTER, GLOBAL_MASTER]:
		var category: Dictionary = SRC.row("DungeonCategory", id)
		var ui: Dictionary = _single("UIDungeonCategory", "DungeonCategoryID", id)
		if not category.is_empty() and not ui.is_empty():
			categories[id] = {"row": category, "ui": ui, "title": _desc(int(ui.TitleDescId))}
	var rows: Dictionary = {}
	for original: Dictionary in SRC.rows("CompetitionDungeon"):
		var category_id: int = int(original.DungeonCategoryID)
		if not categories.has(category_id): continue
		var id: int = int(original.ID)
		var view: Dictionary = SRC.row("CompetitionDungeonView", id)
		var teleport_id: int = int(original.LandTeleportId)
		var tariff: Dictionary = SRC.row("LandTeleport", teleport_id)
		var move: Dictionary = _arrival(teleport_id)
		var visual: Dictionary = _single("CompetitionDungeonAsset", "CompetitionDungeonId", id)
		var asset_id: int = int(visual.get("EntranceAssetId", 0))
		var asset: Dictionary = _single("AssetView", "AssetId", asset_id) if asset_id > 0 else {}
		var asset_type: int = int(asset.get("AssetTypeId", -1))
		var file_name: String = str(asset.get("FilePath", ""))
		var asset_base: String = str(SRC.row("AssetType", asset_type).get("Path", "")) if asset_type > 0 else ""
		var image_path: String = asset_base.path_join(file_name) if not file_name.is_empty() and not asset_base.is_empty() else ""
		var name: String = _desc(int(view.get("TitleDescId", 0)))
		var levels: Dictionary = _levels(teleport_id, int(move.get("land_id", -1)))
		var row: Dictionary = {"id": id, "category_id": category_id,
			"name": name if not name.is_empty() else "원본 던전 #%d" % id,
			"original": original, "view": view, "category": categories[category_id],
			"arrival": move, "tariff": tariff, "levels": levels,
			"asset_id": asset_id, "asset_type": asset_type, "asset_path": image_path, "local_block": ""}
		row.local_block = _local_block(row)
		rows[id] = row
	# Installed world-links can expose the same lobby under an inactive source
	# variant. Only allow matching non-boss membership rows of the very same
	# original entrance; no unrelated Land relation or server rule is removed.
	var lobbies: Dictionary = {}
	for id: int in LOCAL_LOBBIES:
		var row: Dictionary = rows.get(id, {})
		if row.is_empty() or not str(row.local_block).is_empty(): continue
		var land_id: int = int(row.arrival.land_id)
		if lobbies.has(land_id):
			lobbies[land_id] = {}
			continue
		var allowed_links: Array[int] = []
		for link: Dictionary in SRC.related("CompetitionDungeonLand", "LandID", land_id):
			var other: Dictionary = rows.get(int(link.CompetitionDungeonID), {})
			if link.get("IsBossLand") == false and not other.is_empty() and other.arrival.get("territory_id") == row.arrival.territory_id and other.arrival.get("bounds") == row.arrival.bounds:
				allowed_links.append(int(link.ID))
		lobbies[land_id] = {"id": id, "asset_path": str(row.arrival.asset_path), "links": allowed_links}
	_data = {"rows": rows, "categories": categories, "lobbies": lobbies}
	return _data

static func _levels(teleport_id: int, land_id: int) -> Dictionary:
	var result: Dictionary = {"min": 1, "max": 0, "unknown": false}
	for link: Dictionary in SRC.related("LandTeleportPrerequisite", "LandTeleportID", teleport_id):
		var condition: Dictionary = SRC.row("Prerequisite", int(link.get("PrerequisiteID", -1)))
		var type_id: int = int(condition.get("PrerequisiteTypeID", 0))
		if type_id not in [1, 2] or not _whole(condition.get("Value"), 1, 2147483647):
			result.unknown = true
			continue
		_limit(result, type_id == 1, int(condition.Value))
	for row: Dictionary in SRC.related("LandAttribute", "LandID", land_id):
		# Region-scoped levels are checked by the actual landing provider, not
		# applied indiscriminately to the entire Land.
		if int(row.get("TerritoryID", -1)) != 0: continue
		var kind: String = str(SRC.row("LandAttributeType", int(row.LandAttributeTypeID)).get("Name",""))
		if kind in ["MinLevel", "MaxLevel"] and _whole(row.get("Value"), 1, 2147483647):
			_limit(result, kind == "MinLevel", int(row.Value))
	return result

static func _limit(result: Dictionary, minimum: bool, value: int) -> void:
	if minimum: result.min = maxi(int(result.min), value)
	else: result.max = mini(int(result.max), value) if result.max > 0 else value

static func _local_block(row: Dictionary) -> String:
	var src: Dictionary = row.original
	var category: Dictionary = row.category.row
	if category.get("Release") != true: return "원본 분류 미공개"
	if int(category.get("ServerLimitSetId", 0)) > 0 or int(src.get("ServerLimitSetID", 0)) > 0 or int(src.get("EventServerLimitSetID", 0)) > 0:
		return "원본 서버 조건 미확인 · 입장 보류"
	if row.arrival.is_empty() or row.tariff.is_empty() or row.view.is_empty(): return "원본 도착 관계 확인 불가"
	if int(row.tariff.get("CurrencyID", 0)) != 1: return "원본 이동 재화 처리 미지원"
	if not _whole(row.tariff.get("TeleportCost"), 1, PAYMENT.MAX_AMOUNT): return "원본 이동 비용 확인 불가"
	if int(src.get("WeeklyOpenTimeGroupId", 0)) > 0: return "원본 주간 입장 조건 미확인"
	for key: String in ["IsEvent", "SeasonDurationMinute", "RequiredWorldBossRaidID", "WinnerWeeklyOpenTimeGroupId", "WarZoneHotTimeID"]:
		if src.get(key) != 0: return "원본 이벤트·시즌·전투 조건 미확인"
	if int(src.get("DungeonState", -1)) != 4: return "원본 던전 상태 확인 불가"
	if int(row.id) not in LOCAL_LOBBIES: return "오프라인 입구 이동 미검증 · 원본 서버 입장 불가"
	var home: Dictionary = SRC.row("Territories", int(src.get("HomeTerritoriesID", -1)))
	if int(home.get("LandID", -1)) != int(row.arrival.land_id): return "원본 입구 지도 불일치"
	if row.levels.unknown: return "원본 이동 전제조건 미지원"
	if row.view.get("LandTeleportId") != src.LandTeleportId or row.view.get("TeleportCost") != row.tariff.get("TeleportCost") or row.view.get("TeleportCostCurrencyId") != row.tariff.get("CurrencyID"):
		return "원본 입장 비용 선언 불일치"
	if not SRC.related("LandTimeLimit", "LandID", int(row.arrival.land_id)).is_empty() or not SRC.related("LandWeeklyOpenTime", "LandId", int(row.arrival.land_id)).is_empty():
		return "원본 도착 지역 시간 조건 미확인"
	return ""

static func title(family: String) -> String:
	var id: int = FAMILY.get(family, 0)
	var ui: Dictionary = _single("UIDungeonCategory", "DungeonCategoryID", id)
	var label: String = _desc(int(ui.get("TitleDescId", 0))) if not ui.is_empty() else ""
	return label if not label.is_empty() else ("월드 던전" if id == WORLD else "마스터 던전")

static func entries(category_id: int) -> Array:
	var out: Array = []
	for row: Dictionary in _projection().get("rows", {}).values():
		if row.category_id == category_id: out.append(row.duplicate(true))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.original.ViewOrder != b.original.ViewOrder: return a.original.ViewOrder < b.original.ViewOrder
		return a.id < b.id)
	return out

static func entry(id: int) -> Dictionary:
	return _projection().get("rows", {}).get(id, {}).duplicate(true)

static func lobby(land_id: int, asset_path: String = "") -> Dictionary:
	if land_id not in LOCAL_LOBBY_LANDS: return {}
	var row: Dictionary = _projection().get("lobbies", {}).get(land_id, {})
	if asset_path != "" and row.get("asset_path") != asset_path: return {}
	return row.duplicate(true)

static func picture(row: Dictionary) -> Dictionary:
	if int(row.get("asset_id", 0)) <= 0 or int(row.get("asset_type", -1)) != 11 or str(row.get("asset_path", "")).is_empty():
		return {"ok": false, "status": "source_competition_entrance_asset_missing", "texture": null}
	return IMAGES.resolve_asset_value(row.asset_id, row.asset_type, row.asset_path)

static func quote(world: Node, id: int) -> Dictionary:
	var row: Dictionary = entry(id)
	if row.is_empty(): return {"ok": false, "reason": "원본 월드·마스터 던전 정의 없음"}
	if not str(row.local_block).is_empty(): return {"ok": false, "reason": str(row.local_block), "row": row}
	var level: int = int(world.get("level"))
	if level < int(row.levels.min): return {"ok": false, "reason": "%d레벨부터 입구 이동 가능" % int(row.levels.min), "row": row}
	if int(row.levels.max) > 0 and level > int(row.levels.max): return {"ok": false, "reason": "%d레벨까지만 입구 이동 가능" % int(row.levels.max), "row": row}
	var land_id: int = int(row.arrival.land_id)
	if not world.has_method("dungeon523_land_ready"): return {"ok": false, "reason": "원본 지도 이동 연결 없음", "row": row}
	var reason: String = world.call("dungeon523_land_ready", land_id)
	if not reason.is_empty(): return {"ok": false, "reason": reason, "row": row}
	if world.has_method("orim_current_land") and int(world.call("orim_current_land").get("land_id", -1)) == land_id:
		return {"ok": false, "reason": "이미 이 입구 지도에 있습니다", "row": row}
	var paid: Dictionary = PAYMENT.quote(world, int(row.tariff.TeleportCost))
	if not paid.ok: return paid.merged({"row": row})
	var ticket: Dictionary = {"id": id, "arrival": row.arrival.duplicate(true),
		"tariff": row.tariff.duplicate(true), "generation": SRC.cache_generation()}
	return {"ok": true, "row": row, "changes": paid.changes, "ticket": ticket}
