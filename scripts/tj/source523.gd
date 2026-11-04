extends RefCounted
## The source ZIP stays private. Only the parser and field relationships ship in Git.
const SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const TABLES = ["PlayerValueReturn", "TJCouponHistory", "TJCouponHistoryMapping", "ItemClass", "ItemBonus", "Bonus", "TJCouponSeason", "ServerLimit", "DateTimes_Korean", "BuffCard", "BuffCardRuleMergeView", "BonusApplicationType", "BonusType", "BuffCardDeck", "DescData_Korean", "Grade", "Unit", "BuffCardOptionAwakenValue", "BuffCardOptionAwakenGroup", "BuffCardOptionAwakenLevelBonus"]
const CACHE = "user://tj523-source.zip"
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
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SHA: return {}
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return {}
	var count := 0
	for name: String in zip.get_files():
		if name.begins_with("content/") and name.ends_with(".json"): count += 1
	if count != 1065: zip.close(); return {}
	var data: Dictionary = {}
	for table: String in TABLES:
		data[table] = rows(zip, table)
		if data[table].is_empty(): zip.close(); return {}
	zip.close()
	var profiles: Dictionary = {}
	for row: Dictionary in data.PlayerValueReturn:
		if int(row.BuffCardDeckID) in [1, 2, 41, 98]: profiles[str(int(row.ID))] = row
	var counts: Dictionary={}
	for table: String in data:counts[table]=data[table].size()
	var types: Dictionary=keyed(data.BonusType)
	var units: Dictionary=keyed(data.Unit)
	if str(units.get(str(int(types.get("6604",{}).get("UnitID",-1))),{}).get("Name",""))!="PlayerValueReturn":return {}
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
	if profiles.size() != 10 or coupons.size() != 139: return {}
	var linked_bonuses: Dictionary={}
	for link: Dictionary in data.BuffCardOptionAwakenLevelBonus:
		var key: String=str(int(link.BonusID))
		if bonuses.has(key):linked_bonuses[key]=bonuses[key]
	return {"profiles":profiles, "coupons":coupons, "histories":data.TJCouponHistory, "mappings":data.TJCouponHistoryMapping, "seasons":data.TJCouponSeason, "servers":data.ServerLimit, "dates":keyed(data.DateTimes_Korean), "cards":keyed(data.BuffCard), "merge_rules":data.BuffCardRuleMergeView,"all_return_definitions":data.PlayerValueReturn,"source_table_counts":counts,"awakening_values":keyed(data.BuffCardOptionAwakenValue),"awakening_groups":keyed(data.BuffCardOptionAwakenGroup),"awakening_links":keyed(data.BuffCardOptionAwakenLevelBonus),"awakening_bonuses":linked_bonuses}
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
