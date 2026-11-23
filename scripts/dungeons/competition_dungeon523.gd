extends RefCounted
## Original 523 competition menu and a bounded TWILIGHT local entrance visit.
## This never creates a server, admission state, battle, season or time credit.
const SRC = preload("res://scripts/resources/current523_definition_rows.gd")
const PAYMENT = preload("res://scripts/maps/current523_map_travel_payment.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const ITEM_WALLETS = preload("res://scripts/loot/patch523_item_inventory.gd")
const WORLD: int = 274
const MASTER: int = 284
const GLOBAL_MASTER: int = 322
const FAMILY := {"world": WORLD, "master": MASTER}
const POLICY := "TWILIGHT_LOCAL_COMPETITION_LOBBY_LEVEL_ONLY_V2"
const FISHING := 501
const GOLD := 1
const CLAN_COIN := 21
const MASTER_TICKET := 952
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
		var currency_id: int = int(tariff.get("CurrencyID",0))
		var row: Dictionary = {"id": id, "category_id": category_id,
			"name": name if not name.is_empty() else "원본 던전 #%d" % id,
			"original": original, "view": view, "category": categories[category_id],
			"arrival": move, "tariff": tariff, "levels": levels,
			"asset_id": asset_id, "asset_type": asset_type, "asset_path": image_path,
			"currency_name": _currency_name(currency_id), "wallet_key": _currency_wallet(currency_id), "local_block": ""}
		row.local_block = _local_block(row)
		rows[id] = row
	var lobbies: Dictionary = {}
	for row: Dictionary in rows.values():
		if not str(row.local_block).is_empty(): continue
		var land_id: int = int(row.arrival.land_id)
		if not lobbies.has(land_id): lobbies[land_id] = {"ids": [], "asset_path": str(row.arrival.asset_path), "links": []}
		lobbies[land_id].ids.append(int(row.id))
	# Variants may share a physical lobby and the same Land can belong to
	# several World/Master rows. This removes their entry checks only on an
	# authorized entrance Land, never on a linked combat field.
	for land_id: int in lobbies:
		for link: Dictionary in SRC.related("CompetitionDungeonLand", "LandID", land_id):
			var other: Dictionary = rows.get(int(link.CompetitionDungeonID), {})
			if not other.is_empty() and other.category_id in [WORLD,MASTER]:
				lobbies[land_id].links.append(int(link.ID))
	_data = {"rows": rows, "categories": categories, "lobbies": lobbies}
	return _data

static func _levels(teleport_id: int, land_id: int) -> Dictionary:
	var result: Dictionary = {"min": 1, "max": 0, "invalid": false}
	for link: Dictionary in SRC.related("LandTeleportPrerequisite", "LandTeleportID", teleport_id):
		var condition: Dictionary = SRC.row("Prerequisite", int(link.get("PrerequisiteID", -1)))
		if condition.is_empty():result.invalid=true;continue
		var type_id: int = int(condition.get("PrerequisiteTypeID", 0))
		if type_id not in [1, 2]: continue # Original non-level prerequisites are not entry gates here.
		if not _whole(condition.get("Value"), 1, 2147483647): result.invalid = true; continue
		_limit(result, type_id == 1, int(condition.Value))
	for row: Dictionary in SRC.related("LandAttribute", "LandID", land_id):
		# Region-scoped levels are checked by the actual landing provider, not
		# applied indiscriminately to the entire Land.
		if int(row.get("TerritoryID", -1)) != 0: continue
		var kind: String = str(SRC.row("LandAttributeType", int(row.LandAttributeTypeID)).get("Name",""))
		if kind not in ["MinLevel", "MaxLevel"]: continue
		if not _whole(row.get("Value"), 1, 2147483647): result.invalid = true; continue
		_limit(result, kind == "MinLevel", int(row.Value))
	return result

static func _limit(result: Dictionary, minimum: bool, value: int) -> void:
	if minimum: result.min = maxi(int(result.min), value)
	else: result.max = mini(int(result.max), value) if result.max > 0 else value

static func _local_block(row: Dictionary) -> String:
	var src: Dictionary = row.original
	var category: Dictionary = row.category.row
	if category.get("Release") != true: return "원본 분류 미공개"
	if row.category_id not in [WORLD,MASTER] or int(row.id)==FISHING: return "이 콘텐츠는 TWILIGHT 이동 대상에서 제외됩니다."
	if row.arrival.is_empty() or row.tariff.is_empty() or row.view.is_empty(): return "원본 도착 관계 확인 불가"
	if not _whole(row.tariff.get("TeleportCost"), 1, PAYMENT.MAX_AMOUNT): return "원본 이동 비용 확인 불가"
	if row.levels.invalid: return "원본 입장 레벨 확인 불가"
	if row.view.get("LandTeleportId") != src.LandTeleportId or row.view.get("TeleportCost") != row.tariff.get("TeleportCost") or row.view.get("TeleportCostCurrencyId") != row.tariff.get("CurrencyID"):
		return "원본 입장 비용 선언 불일치"
	if int(row.tariff.CurrencyID)==MASTER_TICKET: return "이동 비용: 원본 마스터 오만의 탑 입장권 결제 미연결"
	if int(row.tariff.CurrencyID)!=GOLD and str(row.wallet_key).is_empty(): return "원본 이동 재화 결제 미연결"
	return ""

static func _currency_name(id: int) -> String:
	if id==GOLD: return "아데나"
	var currency: Dictionary=SRC.row("Currency",id)
	var text: String=_desc(int(currency.get("DescID",0)))
	return text if not text.is_empty() else str(currency.get("Name","원본 재화"))

static func _currency_wallet(id: int) -> String:
	if id!=CLAN_COIN: return ""
	var row: Dictionary=_single("CurrencyUnitClass","CurrencyID",id)
	if row.get("UnitID")!=4 or row.get("ClassID")!=3631: return ""
	return ITEM_WALLETS.coin_wallet(3631)

static func _payment(world: Node,row: Dictionary) -> Dictionary:
	var amount: int=int(row.tariff.TeleportCost)
	if int(row.tariff.CurrencyID)==GOLD: return PAYMENT.quote(world,amount)
	var permitted: Dictionary=PAYMENT.quote(world,0)
	if not permitted.ok: return permitted
	var bag: Variant=world.get("inventory")
	var key: String=str(row.wallet_key)
	if key.is_empty() or not bag is Dictionary: return {"ok":false,"reason":"원본 이동 재화 결제 미연결"}
	var have: Variant=bag.get(key,0)
	if not _whole(have,0,9007199254740991) or have<amount: return {"ok":false,"reason":"이동 비용 %s 부족 (%d 필요)" % [key,amount]}
	var next: Dictionary=bag.duplicate(true)
	next[key]=int(have)-amount
	if int(next[key])==0:next.erase(key)
	return {"ok":true,"changes":{"inventory":next}}

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
	var row: Dictionary = _projection().get("lobbies", {}).get(land_id, {})
	if asset_path != "" and row.get("asset_path") != asset_path: return {}
	return row.duplicate(true)

static func nonlevel_lobby_hold(hold: Dictionary,land_id: int,lobby_row: Dictionary) -> bool:
	var row: Variant=hold.get("row")
	if not row is Dictionary or row.get("LandID")!=land_id: return false
	if hold.get("reason")=="native_land_condition_requires_policy" and hold.get("table")=="CompetitionDungeonLand":
		return int(row.get("ID",-1)) in lobby_row.links
	if hold.get("reason")!="native_attribute_requires_policy": return false
	var attribute: Variant=hold.get("type")
	if not attribute is Dictionary or not _whole(attribute.get("ID"),1,2147483647) or attribute.get("ID")!=row.get("LandAttributeTypeID"): return false
	# Level failures (including unresolved forms) are never treated as waived.
	return attribute.ID not in [91,101] and not str(attribute.get("Name","")).is_empty() and attribute.Name not in ["MinLevel","MaxLevel"]

static func picture(row: Dictionary) -> Dictionary:
	if int(row.get("asset_id", 0)) <= 0 or int(row.get("asset_type", -1)) != 11 or str(row.get("asset_path", "")).is_empty():
		return {"ok": false, "status": "source_competition_entrance_asset_missing", "texture": null}
	return IMAGES.resolve_asset_value(row.asset_id, row.asset_type, row.asset_path)

static func level_problem(level: int,levels: Dictionary) -> String:
	if level<int(levels.min):return "%d레벨부터 입구 이동 가능" % int(levels.min)
	if int(levels.max)>0 and level>int(levels.max):return "%d레벨까지만 입구 이동 가능" % int(levels.max)
	return ""

static func quote(world: Node, id: int) -> Dictionary:
	var row: Dictionary = entry(id)
	if row.is_empty(): return {"ok": false, "reason": "원본 월드·마스터 던전 정의 없음"}
	if not str(row.local_block).is_empty(): return {"ok": false, "reason": str(row.local_block), "row": row}
	var level_gate: String=level_problem(int(world.get("level")),row.levels)
	if not level_gate.is_empty():return {"ok":false,"reason":level_gate,"row":row}
	var land_id: int = int(row.arrival.land_id)
	if not world.has_method("dungeon523_land_ready"): return {"ok": false, "reason": "원본 지도 이동 연결 없음", "row": row}
	var reason: String = world.call("dungeon523_land_ready", land_id)
	if not reason.is_empty(): return {"ok": false, "reason": reason, "row": row}
	if world.has_method("orim_current_land") and int(world.call("orim_current_land").get("land_id", -1)) == land_id:
		return {"ok": false, "reason": "이미 이 입구 지도에 있습니다", "row": row}
	var paid: Dictionary = _payment(world,row)
	if not paid.ok: return paid.merged({"row": row})
	var ticket: Dictionary = {"id": id, "arrival": row.arrival.duplicate(true),
		"tariff": row.tariff.duplicate(true), "generation": SRC.cache_generation()}
	return {"ok": true, "row": row, "changes": paid.changes, "ticket": ticket}
