extends RefCounted
## UNVERIFIED: memory-only port of tools/build_quest523_pack.py:build.
## Existing projection, exclusions, and Korean clock policy; no quest execution.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const TABLES = ["QuestView","QuestType","QuestLevel","QuestPrerequisite","Prerequisite","PrerequisiteType","QuestGoal","Goal","GoalType","QuestReward","Reward","RewardType","QuestRewardEnhancement","RewardEnhancement","ItemClass","DescData_Korean","DateTimes_Korean","Class","StartingQuest","Currency","CurrencyUnitClass"]
var problem: String = ""
var _tables: Dictionary = {}
var _indexes: Dictionary = {}
var _evidence: Dictionary = {}
var _descriptions: Dictionary = {}

func _text(id: int) -> String:
	# The original compiler uses only selected title/scenario/goal/class IDs.
	# Preserve its final-row semantics without a general description feature.
	if not _descriptions.has(id):
		var matches: Array[Dictionary] = SOURCE.related("DescData_Korean","ID",id)
		_descriptions[id] = "" if matches.is_empty() else str(matches[-1].get("Description",""))
	return _descriptions[id]

func _timestamp(id: int) -> Variant:
	var row: Dictionary = _indexes.DateTimes_Korean.get(id,{})
	if row.is_empty(): return null
	var date: Dictionary = {"year":int(row.Year),"month":int(row.Month),"day":int(row.Day),"hour":int(row.Hour),"minute":int(row.Minute),"second":0}
	if date.year < 1 or date.year > 9999 or date.month < 1 or date.month > 12 or date.day < 1 or date.day > 31 or date.hour < 0 or date.hour > 23 or date.minute < 0 or date.minute > 59:
		problem = "기존 퀘스트 projection의 원본 날짜가 유효하지 않습니다"
		return null
	var raw: int = Time.get_unix_time_from_datetime_dict(date)
	var back: Dictionary = Time.get_datetime_dict_from_unix_time(raw)
	for key: String in date:
		if back.get(key) != date[key]:
			problem = "기존 퀘스트 projection의 원본 날짜가 유효하지 않습니다"
			return null
	# Same labelled TWILIGHT UTC+09:00 policy as the existing Python compiler;
	# DateTimes_Korean itself declares no timezone.
	return raw-9*3600

func _read() -> bool:
	if SOURCE.identity().get("source_sha256") != SOURCE.SOURCE_SHA:
		problem = "보유 원본523 정의 ZIP이 필요합니다"
		return false
	for name: String in TABLES:
		var meta: Dictionary = SOURCE.table_metadata(name)
		if meta.is_empty(): problem = "퀘스트 원본 메타데이터가 없습니다: "+name; return false
		_evidence[name] = {"rows":meta.get("row_count"),"sha256":meta.get("sha256")}
		var rows: Array = [] if name == "DescData_Korean" else SOURCE.rows(name)
		if name != "DescData_Korean" and rows.size() != int(meta.get("row_count",-1)):
			problem = "퀘스트 원본 표를 읽을 수 없습니다: "+name
			return false
		_tables[name] = rows
		var index: Dictionary = {}
		for row: Dictionary in rows:
			if row.has("ID"): index[int(row.ID)] = row
		_indexes[name] = index
	if _indexes.QuestView.size() != _tables.QuestView.size():
		problem = "퀘스트 원본 ID가 중복됩니다"
		return false
	return true

func build() -> Dictionary:
	problem = ""
	_tables.clear(); _indexes.clear(); _evidence.clear(); _descriptions.clear()
	if not _read(): return {}
	var links: Dictionary = {}
	for table: String in ["QuestPrerequisite","QuestGoal","QuestReward","QuestRewardEnhancement"]:
		var groups: Dictionary = {}
		for row: Dictionary in _tables[table]:
			var id: int = int(row.QuestID)
			if not groups.has(id): groups[id] = []
			groups[id].append(row)
		links[table] = groups
	var quests: Array = []
	for original: Dictionary in _tables.QuestView:
		var id: int = int(original.ID)
		var title: String = _text(int(original.TitleDescID))
		var row: Dictionary = {"id":"m523:quest:"+str(id),"source_id":original.ID,
			"title":title if not title.is_empty() else "퀘스트 "+str(id),"description":_text(int(original.ScenarioDescID)),"definition":original,
			"category":"main" if original.TypeID == 1 else "achievement" if int(original.TypeID) in [4,46,121] else "daily" if original.TypeID == 3 else "other",
			"type_name":_indexes.QuestType.get(int(original.TypeID),{}).get("Name","Unknown"),
			"starts_at":_timestamp(int(original.StartTime)),"ends_at":_timestamp(int(original.EndTime)),
			"prerequisites":[],"goals":[],"source_rewards":[],"enhancements":[],"blockers":[]}
		for relation_type: Array in [["QuestPrerequisite","Prerequisite","PrerequisiteID","prerequisites"],["QuestGoal","Goal","GoalID","goals"],["QuestReward","Reward","RewardID","source_rewards"],["QuestRewardEnhancement","RewardEnhancement","RewardEnhancementID","enhancements"]]:
			for relation: Dictionary in links[relation_type[0]].get(id,[]):
				var value: Variant = _indexes[relation_type[1]].get(int(relation[relation_type[2]]))
				if value == null:
					row.blockers.append("원본 참조 누락: "+str(relation_type[1])+":"+str(int(relation[relation_type[2]])))
				else:
					var joined: Dictionary = value.duplicate()
					joined.relation = relation
					row[relation_type[3]].append(joined)
		for condition: Dictionary in row.prerequisites:
			condition.type_name = _indexes.PrerequisiteType.get(int(condition.PrerequisiteTypeID),{}).get("Name","Unknown")
		for goal: Dictionary in row.goals:
			goal.type_name = _indexes.GoalType.get(int(goal.GoalTypeID),{}).get("Name","Unknown")
			goal.description = _text(int(goal.DescID))
		for reward: Dictionary in row.source_rewards:
			reward.type_name = _indexes.RewardType.get(int(reward.RewardTypeID),{}).get("Name","Unknown")
			if reward.RewardTypeID == 2:
				var item: Variant = _indexes.ItemClass.get(int(reward.RewardClassID))
				if item == null: row.blockers.append("원본 아이템 참조 누락: "+str(int(reward.RewardClassID)))
				else: reward.source_item = item
		var excluded: Array[String] = []
		if original.TypeID == 31: excluded.append("혈맹 퀘스트 제외")
		# Exactly the existing compiler's excluded systems; no new dummy scan,
		# type heuristic, policy, or exclusion count is introduced.
		for goal: Dictionary in row.goals:
			var type_name: String = str(goal.type_name)
			for word: String in ["clan","siege","pet","arena","ziggurat"]:
				if type_name.to_lower().contains(word):
					var reason: String = "제외 시스템 목표: "+type_name
					if not excluded.has(reason): excluded.append(reason)
					break
		excluded.sort(); row.excluded_reasons = excluded
		quests.append(row)
	if not problem.is_empty(): return {}
	var classes: Array = []
	for original: Dictionary in _tables.Class:
		classes.append({"id":original.ID,"name":_text(int(original.DescID)),"source_name":original.Name})
	return {"schema_version":2,"source_snapshot":"patch523","source_sha256":SOURCE.SOURCE_SHA,
		"provenance":"verified_original_quest_projection","quests":quests,"classes":classes,
		"starting_quests":_tables.StartingQuest,"currency_links":_tables.CurrencyUnitClass,"currencies":_tables.Currency,"tables":_evidence}

static func _canonical(value: Variant) -> String:
	if value == null: return "null"
	if value is bool: return "true" if value else "false"
	if value is int: return str(value)
	if value is float:
		if not is_finite(value): return ""
		if value == floorf(value) and absf(value) <= 9007199254740991.0: return str(int(value))
		return JSON.stringify(value)
	if value is String: return JSON.stringify(value)
	if value is Array:
		var parts: PackedStringArray = []
		for element: Variant in value: parts.append(_canonical(element))
		return "["+",".join(parts)+"]"
	if value is Dictionary:
		# Keys sort as text, like the Python compiler's sort_keys. Rows built
		# with `row.name = ...` carry StringName keys, and a StringName sorts
		# by identity rather than text, so the order (and the pinned payload
		# SHA) depended on what else the process had interned.
		var keys := PackedStringArray()
		for key: Variant in value: keys.append(str(key))
		keys.sort()
		var parts: PackedStringArray = []
		for key: String in keys: parts.append(JSON.stringify(key)+":"+_canonical(value[key]))
		return "{"+",".join(parts)+"}"
	return ""

static func encoded(candidate: Dictionary) -> PackedByteArray:
	# The quest compiler has no trailing newline (unlike the dungeon pack).
	return _canonical(candidate).to_utf8_buffer()

