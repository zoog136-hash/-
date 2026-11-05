extends RefCounted
## Read-only source metadata for the original UI owner. No templates, pixels,
## native event IDs, eligibility decisions, presentation or transactions live here.

const MENU_ROUTES: Dictionary = {
	106: {"type":86,"asset":372566,"focus":"attendance"},
	116: {"type":96,"asset":372696,"focus":"pass"}
}
const CHALLENGE_KEY: String = "ALL_DUNGEON_TRYING_PAGE_ROOT"

static func project(source: Object, section: String, row: Dictionary, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"metadata_only":true,"domain":section,"row_id":row.get("id",""),"source_records":{},"asset_refs":{},"desc_refs":{},"native_fields":{}}
	if source == null or not row.get("id") is String: return result
	var key: String = row.id
	var parts: PackedStringArray = key.split(":")
	if section == "events":
		if parts.size() in [2,4] and parts[0] == "pass" and _positive(parts[1]):
			_pass(source,result,int(parts[1]),parts)
		elif parts.size() == 3 and parts[0] == "pass-quest" and _positive(parts[1]) and _positive(parts[2]):
			_pass(source,result,int(parts[1]),parts)
		elif parts.size() == 5 and parts[0] == "attendance" and _positive(parts[1]) and parts[2].is_valid_int() and _positive(parts[4]):
			_attendance(source,result,parts)
		elif parts.size() == 2 and parts[0] == "container" and _positive(parts[1]):
			_item(source,result,int(parts[1]))
		elif parts.size() == 2 and parts[0] == "pool" and _positive(parts[1]):
			var entities: Array = _find(source,"GotChaEntityView","GotChaClassID",int(parts[1]))
			if not entities.is_empty():
				_identity(result,"GotChaEntityView.GotChaClassID",int(parts[1]))
				# The page already exposes selected pool entities as individual rows.
				# Keep the group reference here instead of quadratically comparing and
				# duplicating every member of every pool on each source-menu opening.
				result["source_group"] = {"table":"GotChaEntityView","field":"GotChaClassID","value":int(parts[1])}
				result["source_member_count"] = entities.size()
		elif parts.size() == 2 and parts[0] in ["pool-entity","RouletteDisplayOfGachaProbability","RouletteDisplayOfMergeProbability"] and _positive(parts[1]):
			var table: String = "GotChaEntityView" if parts[0] == "pool-entity" else parts[0]
			var record: Dictionary = _row(source,table,int(parts[1]))
			if not record.is_empty():
				_identity(result,table,int(parts[1]))
				_add(result,table,record)
	elif section == "jade_grail":
		if parts.size() == 2 and parts[0] == "jade" and _positive(parts[1]):
			var item: Dictionary = _row(source,"ItemClass",int(parts[1]))
			if int(item.get("CategoryID",0)) == 10291: _item(source,result,int(parts[1]))
		elif key.begins_with("grail:"):
			var uid: String = key.trim_prefix("grail:")
			var instances: Variant = context.get("instances",{})
			if not uid.is_empty() and instances is Dictionary and instances.get(uid) is Dictionary:
				var physical: Dictionary = instances[uid]
				if physical.get("instance_id") == uid and _integer(physical.get("sourceID")):
					var item: Dictionary = _row(source,"ItemClass",int(physical.sourceID))
					if int(item.get("CategoryID",0)) == 10622:
						_item(source,result,int(physical.sourceID))
						result["instance_id"] = uid
						# The presentation context has no saved grace-prefix namespace.
						# Never turn a label, physical ID or arbitrary row field into one.
						for grace: Dictionary in _find(source,"ItemGrace","ItemCategoryID",10622):
							if grace.get("GradeID") == item.get("GradeID"): _add(result,"ItemGrace",grace)
	elif section == "challenge" and ((parts.size() == 2 and parts[0] == "challenge" and _positive(parts[1])) or (key == "challenge_active" and _integer(context.get("active_challenge_id")) and int(context.active_challenge_id) > 0)):
		var challenge_id: int = int(context.active_challenge_id) if key == "challenge_active" else int(parts[1])
		var challenge: Dictionary = _row(source,"Challenge",challenge_id)
		if not challenge.is_empty():
			_identity(result,"Challenge",challenge_id)
			_add(result,"Challenge",challenge)
			for field: String in ["MiniAssetID","FullAssetID","CutSceneAssetID"]: _asset_field(source,result,challenge,field)
			for reward: Dictionary in _find(source,"UIChallengeExtraRewardList","ChallengeID",challenge_id):
				_add(result,"UIChallengeExtraRewardList",reward)
				_asset_field(source,result,reward,"RewardIconID","UIChallengeExtraRewardList:%s:RewardIconID" % str(reward.get("ID","")))
	return result

static func menu_route(source: Object, button_id: int) -> Dictionary:
	if not MENU_ROUTES.has(button_id): return _fail("source_menu_route_unknown")
	var expected: Dictionary = MENU_ROUTES[button_id]
	var button: Dictionary = _row(source,"MainMenuUIButtons",button_id)
	if button.get("ID") != button_id or button.get("MainMenuTypeID") != expected.type or button.get("AssetID") != expected.asset:
		return _fail("source_menu_join_mismatch")
	if button.get("IsVisible") != true: return _fail("source_menu_inactive")
	var result: Dictionary = {"ok":true,"metadata_only":true,"domain":"events","focus":expected.focus,"button_id":button_id,"source_records":{},"asset_refs":{},"desc_refs":{},"native_fields":{}}
	_add(result,"MainMenuUIButtons",button)
	_asset_field(source,result,button,"AssetID")
	if not result.asset_refs.has("AssetID") or result.asset_refs.AssetID.get("AssetType",{}).get("ID") != 101:
		return _fail("source_menu_asset_missing")
	return result

static func category_route(source: Object, key: String) -> Dictionary:
	if key != CHALLENGE_KEY: return _fail("source_category_route_unknown")
	var rows: Array = _find(source,"UIDungeonCategory","RootUITableKey",key)
	if rows.size() != 1 or rows[0].get("ID") != 14 or rows[0].get("DungeonCategoryID") != 21:
		return _fail("source_category_join_mismatch")
	var category: Dictionary = _row(source,"DungeonCategory",21)
	if category.get("ID") != 21 or category.get("Release") != true: return _fail("source_category_inactive")
	var result: Dictionary = {"ok":true,"metadata_only":true,"domain":"challenge","focus":"challenge","source_records":{},"asset_refs":{},"desc_refs":{},"native_fields":{"RootUITableKey":key}}
	_add(result,"UIDungeonCategory",rows[0])
	_add(result,"DungeonCategory",category)
	return result

static func _pass(source: Object, result: Dictionary, id: int, parts: PackedStringArray) -> void:
	var record: Dictionary = _row(source,"PassSystem",id)
	if record.is_empty(): return
	if parts[0] == "pass-quest":
		var links: Array = []
		for link: Dictionary in _find(source,"PassSystemQuest","QuestID",int(parts[2])):
			if link.get("PassSystemQuestListID") in [record.get("PassSystemQuestListID"),record.get("PassSystemDailyQuestListID")]: links.append(link)
		if links.is_empty(): return
		for link: Dictionary in links: _add(result,"PassSystemQuest",link)
	elif parts.size() == 4:
		if not _positive(parts[2]) or parts[3] not in ["true","false"]: return
		var tier: Dictionary = _row(source,"PassSystemLevel",int(parts[2]))
		if tier.get("PassSystemID") != id: return
		_add(result,"PassSystemLevel",tier)
	_identity(result,"PassSystem",id)
	_add(result,"PassSystem",record)
	for field: String in ["PassBackgroundAssetID","PassNameAssetID","PassRewardAssetID"]: _asset_field(source,result,record,field)
	if record.get("PassImageNode") is String: result.native_fields["PassImageNode"] = record.PassImageNode

static func _attendance(source: Object, result: Dictionary, parts: PackedStringArray) -> void:
	var version: Dictionary = _row(source,"AttendanceVersion",int(parts[1]))
	if version.is_empty() or version.get("Version") != int(parts[2]) or version.get("ServiceRegionCode") != parts[3]: return
	var rewards: Array = []
	for reward: Dictionary in _find(source,"AttendanceReward","AttendanceVersionID",int(parts[1])):
		if reward.get("RewardIndex") == int(parts[4]): rewards.append(reward)
	if rewards.is_empty(): return
	_identity(result,"AttendanceVersion",int(parts[1]))
	_add(result,"AttendanceVersion",version)
	result["reward_index"] = int(parts[4])
	# Preserve every server alternative; the backend owns eligibility and choice.
	for reward: Dictionary in rewards: _add(result,"AttendanceReward",reward)

static func _item(source: Object, result: Dictionary, id: int) -> void:
	var item: Dictionary = _row(source,"ItemClass",id)
	if item.is_empty(): return
	_identity(result,"ItemClass",id)
	_add(result,"ItemClass",item)
	var category: Dictionary = _row(source,"ItemCategory",int(item.get("CategoryID",0)))
	if not category.is_empty(): _add(result,"ItemCategory",category)
	var icon: Dictionary = _row(source,"Icon",int(item.get("IconID",0)))
	if not icon.is_empty():
		_add(result,"Icon",icon)
		_asset_field(source,result,icon,"AssetID","IconID")
	for link: Dictionary in _find(source,"ItemBonus","ItemClassID",id):
		_add(result,"ItemBonus",link)
		var bonus: Dictionary = _row(source,"Bonus",int(link.get("BonusID",0)))
		if not bonus.is_empty(): _add(result,"Bonus",bonus)

static func _asset_field(source: Object, result: Dictionary, record: Dictionary, field: String, key: String = "") -> void:
	if not _integer(record.get(field)): return
	var id: int = int(record[field])
	if id <= 0: return
	var assets: Array = _find(source,"AssetView","AssetId",id)
	if assets.size() != 1: return
	var asset: Dictionary = assets[0]
	var type: Dictionary = _row(source,"AssetType",int(asset.get("AssetTypeId",0)))
	if type.is_empty() or not type.get("Path") is String or not asset.get("FilePath") is String: return
	result.asset_refs[field if key.is_empty() else key] = {"asset_id":id,"AssetView":asset.duplicate(true),"AssetType":type.duplicate(true),"declared_path":str(type.Path)+str(asset.FilePath)}

static func _add(result: Dictionary, table: String, record: Dictionary) -> void:
	var copy: Dictionary = record.duplicate(true)
	if not result.source_records.has(table): result.source_records[table] = copy
	elif result.source_records[table] is Array:
		if not result.source_records[table].has(copy): result.source_records[table].append(copy)
	elif result.source_records[table] != copy: result.source_records[table] = [result.source_records[table],copy]
	for field: String in record:
		if (field.ends_with("DescID") or field.ends_with("DescId")) and _integer(record[field]):
			result.desc_refs["%s:%s:%s" % [table,str(record.get("ID","")),field]] = int(record[field])

static func _identity(result: Dictionary, table: String, id: int) -> void:
	result["source_namespace"] = table
	result["source_id"] = id

static func _row(source: Object, table: String, id: int) -> Dictionary:
	if source == null or not source.has_method("row"): return {}
	var found: Variant = source.call("row",table,id)
	return found if found is Dictionary else {}

static func _find(source: Object, table: String, field: String, value: Variant) -> Array:
	if source == null or not source.has_method("find_rows"): return []
	var found: Variant = source.call("find_rows",table,field,value)
	return found if found is Array else []

static func _positive(value: String) -> bool:
	return value.is_valid_int() and str(int(value)) == value and int(value) > 0

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == float(int(value)) and int(value) >= 0

static func _fail(code: String) -> Dictionary:
	return {"ok":false,"code":code}
