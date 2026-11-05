extends RefCounted
## UNVERIFIED: only the existing NPC compiler's input relationships.
## No audit execution/report, availability rule, stock authority, or transaction.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const TABLES = ["MerchantGoods","Unit","EarthObjectUnit","EarthObjectClass","EarthObjectCategory","EarthObjectDialogActions","DialogActionType","EarthObjectSpawn","EarthObjectAttribute","EarthObjectAttributeType","UIMapEarthObjectInfo","Currency","CurrencyUnitClass","ContentsResetScheduleType","ConstantData","DateTimes_Korean","ServerLimit","ItemBlessCode"]
const METADATA_ONLY = ["EarthObjectCategory","UIMapEarthObjectInfo","CurrencyUnitClass","DateTimes_Korean","ServerLimit"]
var problem: String = ""

static func _group(rows: Array, field: String) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows:
		var id: int = int(row[field])
		if not result.has(id): result[id] = []
		result[id].append(row)
	return result

static func _index(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows: result[int(row.ID)] = row
	return result

static func _names(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in rows: result[str(int(row.ID))] = row.Name
	return result

static func _truthy(value: Variant) -> bool:
	if value == null: return false
	if value is bool: return value
	if value is int or value is float: return value != 0
	if value is String or value is Array or value is Dictionary: return not value.is_empty()
	return true

func build(shop_sha256: String) -> Dictionary:
	problem = ""
	if shop_sha256.length() != 64 or not shop_sha256.is_valid_hex_number(false):
		problem = "현재 상점 모델의 실제 SHA256이 필요합니다"
		return {}
	if SOURCE.identity().get("source_sha256") != SOURCE.SOURCE_SHA:
		problem = "보유 원본523 정의 ZIP이 필요합니다"
		return {}
	var tables: Dictionary = {}; var evidence: Dictionary = {}
	for name: String in TABLES:
		var meta: Dictionary = SOURCE.table_metadata(name)
		if meta.is_empty(): problem = "NPC 원본 메타데이터가 없습니다: "+name; return {}
		evidence[name] = {"member":meta.get("path"),"bytes":meta.get("bytes"),"sha256":meta.get("sha256"),"rows":meta.get("row_count")}
		# Existing evidence for unused inputs remains metadata only. In
		# particular, UIMap count/order never creates a spawn foreign key.
		if name in METADATA_ONLY: continue
		var rows: Array[Dictionary] = SOURCE.rows(name)
		if rows.size() != int(meta.get("row_count",-1)): problem = "NPC 원본 표를 읽을 수 없습니다: "+name; return {}
		tables[name] = rows
	var units: Dictionary = _names(tables.Unit)
	if units.get("25") != "MerchantsID" or units.get("201") != "CurrencyID":
		problem = "원본 Unit이 상점·재화 참조를 선언하지 않습니다"
		return {}
	if _names(tables.DialogActionType).get("1") != "SellList":
		problem = "원본 대화 동작이 SellList를 선언하지 않습니다"
		return {}
	var objects: Dictionary = _index(tables.EarthObjectClass)
	var currencies: Dictionary = _index(tables.Currency)
	var object_units: Dictionary = _group(tables.EarthObjectUnit,"EarthObjectClassID")
	var actions: Dictionary = _group(tables.EarthObjectDialogActions,"EarthObjectClassID")
	var spawns: Dictionary = _group(tables.EarthObjectSpawn,"EarthObjectClassID")
	var attributes: Dictionary = _group(tables.EarthObjectAttribute,"EarthObjectClassID")
	var attribute_types: Dictionary = _names(tables.EarthObjectAttributeType)
	var goods: Dictionary = _group(tables.MerchantGoods,"MerchantsID")
	var references: Dictionary = {}
	for row: Dictionary in tables.EarthObjectUnit:
		if row.UnitID != 25: continue
		var merchant: int = int(row.Value)
		if not references.has(merchant): references[merchant] = []
		references[merchant].append(row)
	var merchant_ids: Array = goods.keys(); merchant_ids.sort()
	var merchants: Array = []
	for merchant_id: int in merchant_ids:
		var offers: Array = goods[merchant_id]
		var links: Array = []
		for link: Dictionary in references.get(merchant_id,[]):
			var object_id: int = int(link.EarthObjectClassID)
			var object: Variant = objects.get(object_id)
			var currency_set: Dictionary = {}
			for row: Dictionary in object_units.get(object_id,[]):
				if row.UnitID == 201: currency_set[int(row.Value)] = true
			var currency_ids: Array = currency_set.keys(); currency_ids.sort()
			var currency_names: Array = []
			for id: int in currency_ids: currency_names.append(currencies.get(id,{}).get("Name"))
			var sell_ids: Array = []
			for action: Dictionary in actions.get(object_id,[]):
				if action.EarthActionTypeID == 1: sell_ids.append(action.ID)
			var spawn_rows: Array = []
			for spawn: Dictionary in spawns.get(object_id,[]):
				var selected: Dictionary = {}
				for key: String in ["ID","Name","ServerLimitSetID","SpawnManually","WarTaxOn","SiegeTaxOn","TerritoriesID"]: selected[key] = spawn[key]
				spawn_rows.append(selected)
			var attribute_rows: Array = []
			for attribute: Dictionary in attributes.get(object_id,[]):
				attribute_rows.append({"id":attribute.EarthObjectAttributeTypeID,"name":attribute_types.get(str(int(attribute.EarthObjectAttributeTypeID))),"value":attribute.Value})
			links.append({"earth_object_id":object_id,"merchant_link_row_id":link.ID,
				"name":object.Name if object is Dictionary else null,"object_defined":object != null,
				"currency_ids":currency_ids,"currency_names":currency_names,
				"currency_defined_and_unique":currency_ids.size() == 1 and currencies.has(currency_ids[0]),
				"sell_action_row_ids":sell_ids,"spawns":spawn_rows,"attributes":attribute_rows})
		var blockers: Array = []
		if links.is_empty(): blockers.append("MISSING_MERCHANT_TO_EARTH_OBJECT_REFERENCE")
		else:
			var chain: bool = false
			for link: Dictionary in links:
				if link.object_defined and link.currency_defined_and_unique and not link.sell_action_row_ids.is_empty() and not link.spawns.is_empty(): chain = true
			if not chain: blockers.append("INCOMPLETE_OBJECT_CURRENCY_ACTION_OR_SPAWN_CHAIN")
		var goods_ids: Array = []; var zero_hours: Array = []; var refresh_types: Dictionary = {}
		var count_limit: bool = false; var server_stock: bool = false; var clan: bool = false; var cards: bool = false
		for offer: Dictionary in offers:
			goods_ids.append(offer.ID)
			if offer.LimitStartHour == 0 and offer.LimitEndHour == 0: zero_hours.append(offer.ID)
			if offer.LimitCount > 0: count_limit = true; refresh_types[int(offer.LimitCountRefreshTypeID)] = true
			if offer.LimitServerCount > 0: server_stock = true
			for key: String in ["ClanLevelMin","LimitMinClanLevel","DaysAfterClanJoin","LimitDaysAfterClanJoin","LimitClanMemberRank"]:
				if _truthy(offer[key]): clan = true
			if _truthy(offer.LimitBuffCardID) or _truthy(offer.LimitRepeatedBuyCardID): cards = true
		if not zero_hours.is_empty(): blockers.append("UNVERIFIED_ZERO_HOUR_EXECUTION_RULE")
		if count_limit: blockers.append("LIMIT_REFRESH_NAMESPACE_AND_COUNTER_SCOPE_REQUIRE_IMPLEMENTATION")
		if server_stock: blockers.append("SERVER_SHARED_STOCK_AUTHORITY_UNAVAILABLE")
		if clan: blockers.append("CLAN_CONDITIONS_PRESENT_BUT_EXCLUDED_FROM_THIS_GAME_SCOPE")
		if cards: blockers.append("CARD_QUALIFICATION_RULES_NOT_IMPLEMENTED")
		var refresh_ids: Array = refresh_types.keys(); refresh_ids.sort()
		merchants.append({"merchant_id":merchant_id,"goods_ids":goods_ids,"zero_hour_goods_ids":zero_hours,"object_links":links,
			"refresh_type_ids_with_count_limit":refresh_ids,"blockers":blockers,"activation_authorized":false})
	var constants: Dictionary = {}
	for row: Dictionary in tables.ConstantData:
		if row.Name in ["ContentsRefreshHour","ContentsRefreshMinute","ContentsRefreshSecond"]: constants[row.Name] = row.Value
	# These are declarations in separate namespaces. No reset-type equivalence
	# or UIMap row-count/order-to-spawn mapping is inferred from them.
	return {"schema":"twilight.source523.npc-definitions.v1","revision":2,"patch":523,
		"source_zip_sha256":SOURCE.SOURCE_SHA,"shop_pack_sha256":shop_sha256,"delivery":"PRIVATE_LOCAL_ONLY","evidence":evidence,
		"source_semantics":{"item_bless_codes":_names(tables.ItemBlessCode),"reset_schedule_types":_names(tables.ContentsResetScheduleType),"refresh_constants":constants},
		"merchants":merchants}

