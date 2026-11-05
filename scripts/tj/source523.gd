extends RefCounted
## The source ZIP stays private. Only the parser and field relationships ship in Git.
const SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const TABLES = ["PlayerValueReturn", "TJCouponHistory", "TJCouponHistoryMapping", "ItemClass", "ItemBonus", "Bonus", "TJCouponSeason", "ServerLimit", "DateTimes_Korean", "BuffCard", "BuffCardRuleMergeView", "BonusApplicationType", "BonusType", "BuffCardDeck", "DescData_Korean", "Grade", "Unit", "BuffCardOptionAwakenValue", "BuffCardOptionAwakenGroup", "BuffCardOptionAwakenLevelBonus"]
const CACHE = "user://tj523-source.zip"
static var problem: String = ""
static func failed(reason: String) -> Dictionary:
	problem = reason
	return {}
static func archive_identity() -> Dictionary:
	return {"kind":"twilight.current523.original-definitions.v1","source_snapshot":"patch523","source_sha256":SHA,"source_bytes":25031173}
static func exclusion_evidence(table: String, row: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Only an actual source boolean or the owning declaration SPI excludes a row.
	# Missing flags and names never substitute for an original declaration.
	if typeof(row.get("TestItem")) == TYPE_BOOL and bool(row.TestItem):
		result.append({"table":table,"source_id":row.get("ID"),"field":"TestItem","value":true,"source_sha256":SHA,"excluded_from_connection":true})
	var declared: Dictionary = DEFINITIONS.declared_exclusion(table,row)
	if not declared.is_empty(): result.append(declared)
	return result
static func rows(zip: ZIPReader, table: String) -> Array:
	var name: String = "content/" + table + ".json"
	if not zip.file_exists(name): return []
	var value: Variant = JSON.parse_string(zip.read_file(name).get_string_from_utf8())
	return value.get("rows", []) if value is Dictionary else []
static func keyed(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value: Dictionary in values: result[str(int(value.ID))] = value
	return result
static func load_zip(path: String) -> Dictionary:
	problem = ""
	if not FileAccess.file_exists(path): return failed("TJ 원문 ZIP 파일을 찾거나 읽을 수 없습니다.")
	if FileAccess.get_sha256(path) != SHA: return failed("TJ 원문 ZIP의 고정 SHA가 일치하지 않습니다.")
	var zip := ZIPReader.new()
	var open_error: Error = zip.open(path)
	if open_error != OK: return failed("TJ 원문 ZIP을 열지 못했습니다: "+str(open_error))
	var count := 0
	for name: String in zip.get_files():
		if name.begins_with("content/") and name.ends_with(".json"): count += 1
	if count != 1065: zip.close(); return failed("TJ 원문 ZIP의 전체 1065표 구성이 일치하지 않습니다.")
	var data: Dictionary = {}
	for table: String in TABLES:
		data[table] = rows(zip, table)
		if data[table].is_empty(): zip.close(); return failed("TJ 필수 원문 표를 읽지 못했습니다: "+table)
	zip.close()
	var profiles: Dictionary = {}
	for row: Dictionary in data.PlayerValueReturn:
		if int(row.BuffCardDeckID) in [1, 2, 41, 98]: profiles[str(int(row.ID))] = row
	var counts: Dictionary={}
	for table: String in data:counts[table]=data[table].size()
	var types: Dictionary=keyed(data.BonusType)
	var units: Dictionary=keyed(data.Unit)
	if str(units.get(str(int(types.get("6604",{}).get("UnitID",-1))),{}).get("Name",""))!="PlayerValueReturn":return failed("TJ PlayerValueReturn 원문 단위 연결이 일치하지 않습니다.")
	var bonuses: Dictionary = keyed(data.Bonus)
	var items: Dictionary = keyed(data.ItemClass)
	var coupons: Dictionary = {}
	for link: Dictionary in data.ItemBonus:
		var bonus: Dictionary = bonuses.get(str(int(link.BonusID)), {})
		if int(bonus.get("BonusTypeID", -1)) != 6604 or not profiles.has(str(int(bonus.Value))): continue
		var id: String = str(int(link.ItemClassID))
		coupons[id] = {"item":items[id], "profile":profiles[str(int(bonus.Value))], "effects":[]}
	for link: Dictionary in data.ItemBonus:
		var id: String = str(int(link.ItemClassID))
		if coupons.has(id): coupons[id].effects.append(bonuses[str(int(link.BonusID))])
	# Keep the fixed parser guard over every original row before admission.
	if profiles.size() != 10 or coupons.size() != 139: return failed("TJ 전체 원문의 10개 프로필 또는 139개 쿠폰 연결이 일치하지 않습니다.")
	var active_coupons: Dictionary = {}
	var excluded_coupons: Dictionary = {}
	for id: String in coupons:
		var evidence: Array[Dictionary] = exclusion_evidence("ItemClass",coupons[id].item)
		if evidence.is_empty(): active_coupons[id] = coupons[id]
		else: excluded_coupons[id] = {"raw":coupons[id],"evidence":evidence,"excluded_from_connection":true}
	var raw_cards: Dictionary = keyed(data.BuffCard)
	var active_cards: Dictionary = {}
	var excluded_cards: Dictionary = {}
	for id: String in raw_cards:
		var evidence: Array[Dictionary] = exclusion_evidence("BuffCard",raw_cards[id])
		if evidence.is_empty(): active_cards[id] = raw_cards[id]
		else: excluded_cards[id] = {"raw":raw_cards[id],"evidence":evidence,"excluded_from_connection":true}
	var linked_bonuses: Dictionary={}
	for link: Dictionary in data.BuffCardOptionAwakenLevelBonus:
		var key: String=str(int(link.BonusID))
		if bonuses.has(key):linked_bonuses[key]=bonuses[key]
	return {"profiles":profiles, "coupons":active_coupons, "histories":data.TJCouponHistory, "mappings":data.TJCouponHistoryMapping, "seasons":data.TJCouponSeason, "servers":data.ServerLimit, "dates":keyed(data.DateTimes_Korean), "cards":active_cards, "merge_rules":data.BuffCardRuleMergeView,"all_return_definitions":data.PlayerValueReturn,"source_table_counts":counts,"awakening_values":keyed(data.BuffCardOptionAwakenValue),"awakening_groups":keyed(data.BuffCardOptionAwakenGroup),"awakening_links":keyed(data.BuffCardOptionAwakenLevelBonus),"awakening_bonuses":linked_bonuses,"raw_coupons":coupons,"raw_cards":raw_cards,"excluded_coupons":excluded_coupons,"excluded_cards":excluded_cards,"sourceInputIdentity":archive_identity(),"source_definition_archive":archive_identity(),"source_snapshot":"patch523","source_provenance":{"input_role":"original_definition_archive","parser":"tj.source523.load_zip","fixed_raw_profiles":10,"fixed_raw_coupons":139}}
static func install(path: String) -> Dictionary:
	var data: Dictionary = load_zip(path)
	if data.is_empty(): return {}
	if FileAccess.file_exists(CACHE) and FileAccess.get_sha256(CACHE) == SHA: return data
	var temporary: String = CACHE + ".staging"
	if DirAccess.copy_absolute(path, temporary) != OK: return {}
	if FileAccess.get_sha256(temporary) != SHA:
		DirAccess.remove_absolute(temporary)
		return {}
	if DirAccess.rename_absolute(temporary, CACHE) != OK: return {}
	return data
