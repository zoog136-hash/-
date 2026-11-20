extends RefCounted
## Original 523 map teleport destinations (텔레포터 NPC 지역 이동 / 지도 텔레포트).
##
## Rows: `UIMapArea` (the map's village/dungeon/field/spot areas). Each row
## names its landing box (`TerritoryID` -> `Territories` LandID/StartX..EndY)
## and its tariff (`LandTeleportID` -> `LandTeleport` TeleportCost /
## CurrencyID / AllowMapTeleport) and gate (`LandTeleportPrerequisite` ->
## `Prerequisite`). Only original rows are listed; nothing is invented.
##
## Listed: not IsHide, a Territories box, a LandTeleport row with
## AllowMapTeleport and CurrencyID 1 (Adena) or 4 (Gem = 다이아: the
## "[맵텔] [하딘]" rows of 하딘의 텔레포트, the Map_Tab_Teleport tab Hadin
## presents; user report 2026-11-20 "하딘의 텔레포트도 안되고"), no test tag.
## A Gem row is paid with the game's own 다이아 (no real payment); its
## TerritoryID 0 row (이계의 균열) lands in its LandTeleportTerritories box.
## Rows without a tariff (LandTeleportID 0) are not listed. Prerequisites: MinLevel (type 1) is
## judged; a row with any other prerequisite type is listed but locked
## ("원본 전제조건 미지원"), never waived.
## The move itself is world.current523_map_teleport (current Land rules except
## the item-teleport waive list, auto hunting off on arrival, the Adena debit
## saved with the arrival).
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const PAYMENT = preload("res://scripts/maps/current523_map_travel_payment.gd")
const ID_PREFIX: String = "m523area:"
const ADENA: int = 1
## Currency 4 "Gem" (DescData 729861 다이아), the game's diamond stack.
const GEM: int = 4
const DIAMOND: String = "다이아"
const CURRENCY_NAMES: Dictionary = {ADENA: "아데나", GEM: DIAMOND}
## Hadin (다이아) rows follow the Adena rows in the list (TWILIGHT 근사:
## the client shows them on the same tab; no order field).
const GEM_ORDER_OFFSET: int = 10
const MIN_LEVEL_TYPE: int = 1
## UIMapAreaType: 3 Village, 4 Dungeon, 5 Field (8: 장소, no type row).
const TYPE_ORDER: Dictionary = {3: 0, 5: 1, 8: 2, 4: 3}
const TEST_TAGS: Array[String] = ["[테스트]", "테스트]", "[미사용]"]
static var _rows: Array = []
static var _generation: int = -1

static func is_destination_id(id: String) -> bool:
	return id.begins_with(ID_PREFIX)

static func destinations() -> Array:
	if _generation == DEF.cache_generation() and not _rows.is_empty(): return _rows
	_rows = []
	_generation = DEF.cache_generation()
	if DEF.not_installed() or DEF.row_count("UIMapArea") <= 0: return _rows
	for area: Dictionary in DEF.rows("UIMapArea"):
		var row: Dictionary = _destination(area)
		if not row.is_empty(): _rows.append(row)
	_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.order != b.order: return a.order < b.order
		return a.area_id < b.area_id)
	return _rows

static func destination(id: String) -> Dictionary:
	for row: Dictionary in destinations():
		if row.id == id: return row
	return {}

static func _destination(area: Dictionary) -> Dictionary:
	var area_id: int = int(area.get("ID", 0))
	if area_id <= 0 or area.get("IsHide") == true: return {}
	var source_name: String = str(area.get("Name", ""))
	for tag: String in TEST_TAGS:
		if source_name.contains(tag): return {}
	var teleport_id: int = int(area.get("LandTeleportID", 0))
	var territory_id: int = int(area.get("TerritoryID", 0))
	if teleport_id <= 0: return {}
	var tariff: Dictionary = DEF.row("LandTeleport", teleport_id)
	var currency: int = int(tariff.get("CurrencyID", 0))
	if tariff.is_empty() or tariff.get("AllowMapTeleport") != true or not CURRENCY_NAMES.has(currency): return {}
	if territory_id <= 0:
		# The original landing set of the tariff (LandTeleportTerritories).
		for link: Dictionary in DEF.related("LandTeleportTerritories", "LandTeleportID", teleport_id):
			if int(link.get("TerritoryID", 0)) > 0: territory_id = int(link.TerritoryID); break
	if territory_id <= 0: return {}
	var territory: Dictionary = DEF.row("Territories", territory_id)
	if territory.is_empty(): return {}
	var bounds: Array = [int(territory.StartX), int(territory.StartY), int(territory.EndX), int(territory.EndY)]
	if bounds[2] < bounds[0] or bounds[3] < bounds[1]: return {}
	var min_level: int = 1
	var unsupported: Array = []
	for link: Dictionary in DEF.related("LandTeleportPrerequisite", "LandTeleportID", teleport_id):
		var prerequisite: Dictionary = DEF.row("Prerequisite", int(link.get("PrerequisiteID", 0)))
		if prerequisite.is_empty(): unsupported.append(int(link.get("PrerequisiteID", 0))); continue
		if int(prerequisite.get("PrerequisiteTypeID", 0)) == MIN_LEVEL_TYPE: min_level = maxi(min_level, int(prerequisite.get("Value", 1)))
		else: unsupported.append(int(prerequisite.ID))
	var name: String = ""
	if int(area.get("DescID", 0)) > 0: name = str(DEF.row("DescData_Korean", int(area.DescID)).get("Description", "")).strip_edges()
	if name.is_empty(): name = _strip_tags(source_name)
	var type_id: int = int(area.get("TypeID", 0))
	return {"id": ID_PREFIX + str(area_id), "area_id": area_id, "name": name, "source_name": source_name,
		"land_id": int(territory.LandID), "bounds": bounds, "territory_id": territory_id,
		"land_teleport_id": teleport_id, "price": int(tariff.get("TeleportCost", 0)), "currency_id": currency, "currency_name": str(CURRENCY_NAMES[currency]),
		"min_level": min_level, "unsupported_prerequisites": unsupported, "type_id": type_id,
		"world_id": int(area.get("WorldID", 0)), "order": int(TYPE_ORDER.get(type_id, 9)) + (GEM_ORDER_OFFSET if currency == GEM else 0)}

static func _strip_tags(text: String) -> String:
	var result: String = text
	while result.begins_with("["):
		var end: int = result.find("]")
		if end < 0: break
		result = result.substr(end + 1).strip_edges()
	return result if not result.is_empty() else text

## {"ok", "reason", "price", "changes"} for the move to `id` now.
static func quote(world: Node, id: String) -> Dictionary:
	var row: Dictionary = destination(id)
	if row.is_empty(): return {"ok": false, "reason": "존재하지 않는 이동 목적지입니다"}
	if not (row.unsupported_prerequisites as Array).is_empty(): return {"ok": false, "reason": "원본 전제조건 미지원 지역입니다", "row": row}
	if int(world.get("level")) < int(row.min_level): return {"ok": false, "reason": "이 지역은 %d레벨부터 이동 가능합니다" % int(row.min_level), "row": row}
	var here: Dictionary = world.call("orim_current_land") if world.has_method("orim_current_land") else {}
	if int(here.get("land_id", -1)) == int(row.land_id) and here.get("cell") is Array:
		var cell: Array = here.cell
		var b: Array = row.bounds
		if int(cell[0]) >= int(b[0]) and int(cell[0]) <= int(b[2]) and int(cell[1]) >= int(b[1]) and int(cell[1]) <= int(b[3]):
			return {"ok": false, "reason": "이미 이 지역에 있습니다", "row": row}
	var paid: Dictionary = gem_quote(world, int(row.price)) if int(row.currency_id) == GEM else PAYMENT.quote(world, int(row.price))
	if not paid.get("ok", false): return {"ok": false, "reason": str(paid.get("reason", "아데나가 부족합니다")), "row": row}
	return {"ok": true, "price": int(row.price), "changes": paid.changes, "row": row}

## The 다이아 price of a Hadin row: the bag's 다이아 stack after the debit,
## saved with the arrival through the same move save as an Adena price.
static func gem_quote(world: Node, amount: int) -> Dictionary:
	var protection: Dictionary = PAYMENT._save_protection(world)
	if not protection.is_empty(): return protection
	if amount < 0 or amount > PAYMENT.MAX_AMOUNT: return {"ok": false, "reason": "이동 비용은 0~100000000의 정수여야 합니다"}
	var bag: Variant = world.get("inventory")
	if not bag is Dictionary: return {"ok": false, "reason": "현재 소지품 상태 확인 필요"}
	var owned: Variant = (bag as Dictionary).get(DIAMOND, 0)
	if not (owned is int or (owned is float and float(owned) == floorf(float(owned)))) or int(owned) < 0: return {"ok": false, "reason": "현재 다이아 정수 상태 확인 필요"}
	if amount > int(owned): return {"ok": false, "reason": "이동 비용 다이아가 부족합니다"}
	if amount == 0: return {"ok": true, "changes": {}, "amount": 0}
	var next: Dictionary = (bag as Dictionary).duplicate(true)
	next[DIAMOND] = int(owned) - amount
	if int(next[DIAMOND]) == 0: next.erase(DIAMOND)
	return {"ok": true, "changes": {"inventory": next}, "amount": amount, "currency_id": GEM}
