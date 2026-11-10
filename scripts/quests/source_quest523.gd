extends RefCounted
## Private, data-only quest projection. Missing semantics fail closed per quest.
const USER_PATH = "user://quests_current523.json"
const DEV_PATH = "res://data/quests/private_current523.json"
const SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PAYLOAD_SHA = "2d11ecff4e695244220dc8e3a9b5707809f8bcfe34d7789a517880a6590bcb9a"
const MAX_BYTES = 16 * 1024 * 1024
const ITEM_BINDINGS = preload("res://scripts/quests/quest_item_bindings.gd")
const ORIGINAL_PROJECTION = preload("res://scripts/quests/source_quest523_projection.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const BOOT_LOG = preload("res://scripts/boot/boot_progress_log.gd")
const BAKE_NAME := "quest523_payload"
const SHARED = preload("res://scripts/resources/shared_values.gd")
const DUMMY = preload("res://scripts/quests/source_dummy523.gd")
## Lineage M style: only what the hot paths read (identity, title, category,
## period, blockers/exclusions, objective and the compact gate inputs) stays
## resident. Each quest's complete row (QuestView definition, joined goals,
## rewards with ItemClass rows, prerequisites, enhancements, description)
## lives in a device record bake and is read back on demand by full().
const RECORDS_NAME := "quest523_records"
const RECORDS_SCHEMA := 1
const HOT_RECORD := "__hot__"
## Key of the compact gate inputs on a row whose complete form is on storage.
const LAZY_KEY := "source_lazy_gate"
const CACHE_SIZE := 128
const LINKED_TYPES := [92,102,131,143,172,182,162,71,81]
var document: Dictionary = {}
var problem: String = "최신523 퀘스트 팩 미설치"
var quests: Array[Dictionary] = []
var class_ids: Dictionary = {}
var currency_ids: Dictionary = {}
var loaded_path: String = ""
var _records = null # BAKE.RecordFile while rows are materialized on demand.
var _cache: Dictionary = {} # Small LRU: quest id -> complete row.
var _bulk: PackedByteArray = PackedByteArray()

func load_pack() -> bool:
	var path: String = USER_PATH if FileAccess.file_exists(USER_PATH) else DEV_PATH
	if not FileAccess.file_exists(path): return _load_original()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		problem = "퀘스트 팩 파일을 읽을 수 없습니다"
		return false
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	return _load_payload(bytes,path)

func _load_original() -> bool:
	if not document.is_empty(): return not quests.is_empty() # No replacement of live input.
	# UNVERIFIED: only called when neither established private file exists.
	# Reproduce the old payload, never replace its fingerprint with archive SHA.
	# The payload is a pure function of the verified original and this code;
	# a later start reads this device's baked bytes (still checked against
	# PAYLOAD_SHA by _load_payload) instead of projecting the tables again.
	var bake_key: String = BAKE.producer_key(BAKE_NAME, "quest523", "payload:" + PAYLOAD_SHA, ORIGINAL_PROJECTION.SOURCE.verified_key())
	var baked: Dictionary = BAKE.read_payload(BAKE_NAME, bake_key)
	if not baked.is_empty() and _load_payload(baked.bytes,""): return true
	BOOT_LOG.mark("quest_cold_build")
	var projection = ORIGINAL_PROJECTION.new()
	var value: Dictionary = projection.build()
	if value.is_empty():
		problem = projection.problem
		return false
	var bytes: PackedByteArray = ORIGINAL_PROJECTION.encoded(value)
	projection = null
	value = {}
	if not _load_payload(bytes,""): return false
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(bytes)
	BAKE.write(BAKE_NAME, bake_key, {"bytes":bytes,"sha256":digest.finish().hex_encode(),"identity":ORIGINAL_PROJECTION.SOURCE.identity()})
	return true

func _load_payload(bytes: PackedByteArray, path: String) -> bool:
	if bytes.size() > MAX_BYTES:
		problem = "퀘스트 팩 파일을 읽을 수 없습니다"
		return false
	var text: String = bytes.get_string_from_utf8()
	if text.sha256_text() != PAYLOAD_SHA:
		problem = "퀘스트 팩 SHA-256 불일치"
		return false
	# The verified payload bytes (and this code) fully determine the records:
	# a later start reads the compact rows instead of parsing all 3,621 quests.
	if _open_records(PAYLOAD_SHA, path): return true
	var value: Variant = JSON.parse_string(text)
	text = ""
	if not value is Dictionary or not valid_document(value):
		problem = "퀘스트 팩 구조 오류"
		return false
	return _adopt(value, path, PAYLOAD_SHA)

## Completes the parsed, already verified document into quest rows.
func _adopt(value: Dictionary, path: String, payload_sha: String) -> bool:
	# Rewards repeat the same full ItemClass row in every quest that grants it
	# (765 distinct rows across 3,621 quests); share each distinct read-only
	# value once instead of one parsed copy per quest.
	var shared: Dictionary = {}
	for quest: Variant in value.quests:
		if quest is Dictionary: SHARED.intern(quest, shared, 6)
	shared = {}
	document = value
	loaded_path = path
	var start: int = quests.size()
	for link: Dictionary in document.currency_links:
		if int(link.UnitID)==4 and bool(link.ForGive) and not currency_ids.has(int(link.ClassID)): currency_ids[int(link.ClassID)] = int(link.CurrencyID)
	for raw: Dictionary in document.quests:
		# Rows are completed in place: the parsed document is private to this
		# loader and nothing reads its quest rows again, so a deep copy only
		# held all 3,621 quests twice.
		var row: Dictionary = raw
		# Original QuestType=3 is Common/[일반], not the retired demo's
		# daily bucket. The approved v1 data bytes stay immutable; original
		# TypeID, rather than that older presentation key, is authoritative.
		if int(row.definition.TypeID)==3: row.category="common"
		row["objective"] = {"kind":"source", "count":1, "target":""}
		row["rewards"] = {}
		row["min_level"] = 1
		for condition: Dictionary in row.prerequisites:
			if condition.type_name == "MinLevel": row.min_level = maxi(row.min_level, int(condition.Value))
		quests.append(row)
	for row: Dictionary in document.classes:
		class_ids[str(row.name)] = int(row.id)
	# Only the header, class names and evidence stay; quest rows live in
	# `quests` and the currency tables were consumed into currency_ids above.
	for key: String in ["quests","currency_links","currencies"]: document.erase(key)
	_bake_records(payload_sha, start)
	problem = ""
	return true

## Writes every complete row to a device record bake, then keeps only the
## compact form of each row resident. Any write/open failure keeps the
## complete rows resident (the previous behavior).
func _bake_records(payload_sha: String, start: int) -> void:
	var key: String = BAKE.producer_key(RECORDS_NAME, "quest523", "records:" + str(RECORDS_SCHEMA), payload_sha)
	if key.is_empty(): return
	var compact: Array[Dictionary] = []
	var hot: Array = []
	for at: int in range(start, quests.size()):
		var lean: Dictionary = _compact(quests[at])
		compact.append(lean)
		hot.append(quests[at] if lean.is_empty() else lean)
	var writer = BAKE.record_writer(RECORDS_NAME, key)
	if writer == null: return
	for at: int in range(start, quests.size()): writer.add(str(quests[at].id), quests[at])
	writer.add(HOT_RECORD, {"schema":RECORDS_SCHEMA,"payload_sha256":payload_sha,"quests":hot,"class_ids":class_ids,"currency_ids":currency_ids,"document":document})
	if not BAKE.finish_records(writer): return
	var records = BAKE.open_records(RECORDS_NAME, key)
	if records == null: return
	_records = records
	_cache.clear()
	var shared: Dictionary = {}
	for at: int in compact.size():
		if not compact[at].is_empty(): quests[start+at] = SHARED.intern(compact[at], shared, 3)

## Adopts the compact rows of a record bake made from these verified bytes.
func _open_records(payload_sha: String, path: String) -> bool:
	var records = BAKE.open_records(RECORDS_NAME, BAKE.producer_key(RECORDS_NAME, "quest523", "records:" + str(RECORDS_SCHEMA), payload_sha))
	if records == null or not records.has(HOT_RECORD): return false
	var hot: Variant = records.read(HOT_RECORD)
	if not hot is Dictionary or hot.get("schema") != RECORDS_SCHEMA or hot.get("payload_sha256") != payload_sha: return false
	if not hot.get("quests") is Array or hot.quests.size() != 3621 or not hot.get("class_ids") is Dictionary or not hot.get("currency_ids") is Dictionary or not hot.get("document") is Dictionary: return false
	for row: Variant in hot.quests:
		if not row is Dictionary or not row.get("id") is String: return false
		if row.has(LAZY_KEY) and not records.has(row.id): return false
	_records = records
	_cache.clear()
	document = hot.document
	loaded_path = path
	var shared: Dictionary = {}
	for row: Dictionary in hot.quests: quests.append(SHARED.intern(row, shared, 3))
	for id: Variant in hot.currency_ids:
		if not currency_ids.has(id): currency_ids[id] = hot.currency_ids[id]
	for name: Variant in hot.class_ids: class_ids[name] = hot.class_ids[name]
	problem = ""
	return true

static func _number(value: Variant) -> bool:
	return value is int or value is float or value is bool

## The resident form of a complete row: every field except the heavy source
## joins, plus exactly the values gate() reads from them. {} keeps the row
## complete (any shape gate() could not read identically).
static func _compact(row: Dictionary) -> Dictionary:
	for key: String in ["id","definition","prerequisites","goals","source_rewards","enhancements","blockers","excluded_reasons","starts_at","ends_at"]:
		if not row.has(key): return {}
	var definition: Variant = row.definition
	if not row.id is String or not definition is Dictionary or not row.prerequisites is Array or not row.goals is Array or not row.blockers is Array or not row.excluded_reasons is Array: return {}
	if not _number(definition.get("TypeID")): return {}
	for field: String in ["LimitWeeklyOpenTimeGroup","LimitHours","QuestResetType","MaxDailyRepeat"]:
		if definition.has(field) and not _number(definition[field]): return {}
	var lazy: Dictionary = {}
	var name_value: Variant = definition.get("Name")
	# QuestView rows match only the "[더미]" declaration (record scope).
	if name_value is String and (name_value as String).contains("[더미]"): lazy["dummy"] = {"ID":definition.get("ID",0),"Name":name_value}
	var after: String = ""
	if int(definition.TypeID) in LINKED_TYPES: after = "연계 콘텐츠의 획득 조건 확인 필요"
	elif int(definition.get("LimitWeeklyOpenTimeGroup",0)) != 0 or int(definition.get("LimitHours",0)) != 0: after = "원본 운영 시간 조건 확인 필요"
	elif int(definition.get("QuestResetType",0)) != 0 or int(definition.get("MaxDailyRepeat",0)) != 0: after = "원본 반복/초기화 규칙 확인 필요"
	lazy["after"] = after
	var conditions: Array = []
	for condition: Variant in row.prerequisites:
		if not condition is Dictionary or not condition.has("type_name") or not _number(condition.get("Value")): return {}
		conditions.append([str(condition.type_name), int(condition.Value)])
	lazy["prerequisites"] = conditions
	var levels: Array = []
	for goal: Variant in row.goals:
		if not goal is Dictionary or not goal.get("type_name") is String: return {}
		if goal.type_name != "Level": continue
		if not _number(goal.get("CharacterClassID")) or not goal.get("relation") is Dictionary or not _number(goal.get("Amount")): return {}
		if goal.relation.has("GoalPredicateTypeID") and not _number(goal.relation.GoalPredicateTypeID): return {}
		levels.append([int(goal.CharacterClassID), int(goal.relation.get("GoalPredicateTypeID",0)), int(goal.Amount)])
	lazy["level_goals"] = levels
	var lean: Dictionary = {}
	for key: Variant in row:
		if str(key) not in ["definition","prerequisites","goals","source_rewards","enhancements","description"]: lean[key] = row[key]
	lean[LAZY_KEY] = lazy
	return lean

## The complete row (QuestView definition, goals, rewards, prerequisites,
## enhancements, description) of `row`. Rows that are already complete,
## including injected/local rows, are returned unchanged. With cache=false a
## row is read without entering the small LRU (bulk scans).
func full(row: Dictionary, cache: bool = true) -> Dictionary:
	if not row.has(LAZY_KEY) or _records == null: return row
	var id: String = str(row.get("id",""))
	if _cache.has(id):
		var known: Dictionary = _cache[id]
		if cache:
			_cache.erase(id)
			_cache[id] = known
		return known
	var value: Dictionary = _read_record(id)
	if value.is_empty(): return row
	if cache:
		_cache[id] = value
		while _cache.size() > CACHE_SIZE: _cache.erase(_cache.keys()[0])
	return value

## An independent complete copy of `row` (what row.duplicate(true) of the
## resident complete row returned before).
func detached(row: Dictionary) -> Dictionary:
	if row.has(LAZY_KEY) and _records != null:
		var value: Dictionary = _read_record(str(row.get("id","")))
		if not value.is_empty(): return value
	return row.duplicate(true)

## Bulk scans (every UI row) read the record file once and decode in place;
## end_bulk() releases the buffer. Single reads seek the open file.
func begin_bulk() -> void:
	if _records == null: return
	var file: FileAccess = _records.file
	file.seek(0)
	_bulk = file.get_buffer(file.get_length())

func end_bulk() -> void:
	_bulk = PackedByteArray()

func _read_record(id: String) -> Dictionary:
	var value: Variant = null
	if _records.has(id):
		var at: int = int(_records.offsets[id])
		if not _bulk.is_empty() and at >= 0 and at + 4 <= _bulk.size() and at + 4 + int(_bulk.decode_u32(at)) <= _bulk.size():
			value = _bulk.decode_var(at + 4)
		else: value = _records.read(id)
	if not value is Dictionary or str(value.get("id","")) != id:
		push_error("퀘스트 원본 기록을 읽을 수 없습니다: "+id)
		return {}
	return value

static func valid_document(value: Dictionary) -> bool:
	if value.get("schema_version") != 2 or value.get("source_snapshot") != "patch523" or value.get("source_sha256") != SOURCE_SHA or value.get("provenance") != "verified_original_quest_projection": return false
	if not value.get("quests") is Array or value.quests.size() != 3621 or not value.get("classes") is Array: return false
	var seen: Dictionary = {}
	for raw: Variant in value.quests:
		if not raw is Dictionary: return false
		var id: String = str(raw.get("id", ""))
		if id != "m523:quest:"+str(int(raw.get("source_id",0))) or seen.has(id): return false
		seen[id] = true
		for key: String in ["prerequisites", "goals", "source_rewards", "enhancements", "blockers", "excluded_reasons"]:
			if not raw.get(key) is Array: return false
		if not raw.get("definition") is Dictionary: return false
	return true

static func install_zip(path: String) -> Dictionary:
	# Bounded central directory inspection before ZIPReader allocations.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2 * 1024 * 1024: return {"ok":false,"error":"퀘스트 팩 크기 오류"}
	var length: int = file.get_length()
	if length < 22: return {"ok":false,"error":"ZIP 구조 오류"}
	file.seek(length-22)
	var end: PackedByteArray = file.get_buffer(22)
	if end.decode_u32(0) != 0x06054b50 or end.decode_u16(4) != 0 or end.decode_u16(6) != 0 or end.decode_u16(8) != 2 or end.decode_u16(10) != 2 or end.decode_u16(20) != 0: return {"ok":false,"error":"퀘스트 ZIP 목록 오류"}
	var directory_offset: int = end.decode_u32(16)
	var directory_size: int = end.decode_u32(12)
	if directory_size > 2048 or directory_offset + directory_size != length-22: return {"ok":false,"error":"퀘스트 ZIP 경계 오류"}
	file.seek(directory_offset)
	var directory: PackedByteArray = file.get_buffer(directory_size)
	var at: int = 0
	var names: Dictionary = {}
	for i: int in range(2):
		if at+46 > directory.size() or directory.decode_u32(at) != 0x02014b50: return {"ok":false,"error":"퀘스트 ZIP 항목 오류"}
		var n: int = directory.decode_u16(at+28)
		var record_size: int = 46+n+directory.decode_u16(at+30)+directory.decode_u16(at+32)
		if at+record_size > directory.size(): return {"ok":false,"error":"퀘스트 ZIP 이름 오류"}
		var name: String = directory.slice(at+46,at+46+n).get_string_from_utf8()
		if name not in ["quest_pack.json","quests.json"] or names.has(name) or directory.decode_u16(at+8)&1 or directory.decode_u16(at+10) not in [0,8] or directory.decode_u32(at+24) > (4096 if name=="quest_pack.json" else MAX_BYTES) or directory.decode_u32(at+42) >= directory_offset: return {"ok":false,"error":"지원되지 않는 퀘스트 ZIP 항목"}
		names[name] = true
		at += record_size
	if at != directory.size(): return {"ok":false,"error":"퀘스트 ZIP 목록 손상"}
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return {"ok":false,"error":"ZIP 열기 실패"}
	var header: Variant = JSON.parse_string(zip.read_file("quest_pack.json").get_string_from_utf8())
	var payload: PackedByteArray = zip.read_file("quests.json")
	zip.close()
	if not header is Dictionary or header.get("kind") != "twilight-quests-current523" or header.get("schema") != 1 or header.get("source_sha256") != SOURCE_SHA or header.get("payload_sha256") != PAYLOAD_SHA or int(header.get("bytes",0)) != payload.size() or payload.get_string_from_utf8().sha256_text() != PAYLOAD_SHA: return {"ok":false,"error":"퀘스트 원본/해시 검증 실패"}
	var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())
	if not parsed is Dictionary or not valid_document(parsed): return {"ok":false,"error":"퀘스트 정의 검증 실패"}
	var result: Error = preload("res://scripts/skills/save_writer.gd").write_text(USER_PATH,payload.get_string_from_utf8())
	return {"ok":result==OK,"error":"퀘스트 팩 저장 실패 · 기존 파일 보존" if result!=OK else ""}

func gate(row: Dictionary, context: Dictionary, claimed: Dictionary, now: int) -> String:
	var lazy: Variant = row.get(LAZY_KEY)
	if lazy is Dictionary: return _gate_compact(row, lazy, context, claimed, now)
	if not preload("res://scripts/quests/source_dummy523.gd").evidence("QuestView",row.get("definition",{})).is_empty():return "원본 더미 선언 퀘스트 연결 제외"
	if not row.excluded_reasons.is_empty(): return str(row.excluded_reasons[0])
	if not row.blockers.is_empty(): return str(row.blockers[0])
	if row.starts_at == null or row.ends_at == null: return "원본 운영 기간 해석 보류"
	if now < int(row.starts_at): return "시작 전"
	if now > int(row.ends_at): return "기간 종료"
	var definition: Dictionary = row.definition
	if int(definition.TypeID) in [92,102,131,143,172,182,162,71,81]: return "연계 콘텐츠의 획득 조건 확인 필요"
	if int(definition.get("LimitWeeklyOpenTimeGroup",0)) != 0 or int(definition.get("LimitHours",0)) != 0: return "원본 운영 시간 조건 확인 필요"
	# The client dump does not contain the QuestResetType enum contract. Never
	# guess IDs from an unrelated reset table and accidentally farm rewards.
	if int(definition.get("QuestResetType",0)) != 0 or int(definition.get("MaxDailyRepeat",0)) != 0: return "원본 반복/초기화 규칙 확인 필요"
	for condition: Dictionary in row.prerequisites:
		var amount: int = int(condition.Value)
		match str(condition.type_name):
			"MinLevel":
				if int(context.get("level",1)) < amount: return "레벨 %d부터 이용" % amount
			"MaxLevel":
				if int(context.get("level",1)) > amount: return "최대 레벨 %d 제한" % amount
			"MinLevelByCharacterMaxLevel":
				if int(context.get("max_level",context.get("level",1))) < amount: return "최고 레벨 %d 필요" % amount
			"Class":
				if int(context.get("class_id",-1)) != amount: return "직업 조건 미충족"
			"ClassNot":
				if int(context.get("class_id",-1)) < 0 or int(context.get("class_id",-1)) == amount: return "직업 조건 미충족"
			"Quest":
				if not claimed.has("m523:quest:"+str(amount)): return "선행 퀘스트 %d 필요" % amount
			"CreateCharacter":
				# A live local character satisfies source CreateCharacter=1.
				if amount != 1: return "캐릭터 생성 조건 확인 필요"
			_: return "선행 조건 미연결: "+str(condition.type_name)
	# Level achievements encode their level in Goal rather than Prerequisite.
	# The user's automatic-completion rule skips performance objectives, while
	# preserving level/class eligibility. Never award level96 rewards at86.
	for goal: Dictionary in row.goals:
		if goal.type_name != "Level": continue
		var character: int = int(goal.CharacterClassID)
		if character != 0 and int(context.get("class_id",-1)) < 0: return "직업별 레벨 조건 확인 필요"
		if character != 0 and character != int(context.get("class_id",-1)): continue
		if int(goal.relation.get("GoalPredicateTypeID",0)) != 1 or int(goal.Amount) < 1: return "원본 레벨 목표 조건 해석 보류"
		if int(context.get("level",1)) < int(goal.Amount): return "레벨 %d부터 이용" % int(goal.Amount)
	return ""

## gate() for a compact row: the same checks in the same order, reading the
## values _compact() took from the definition, prerequisites and goals.
func _gate_compact(row: Dictionary, lazy: Dictionary, context: Dictionary, claimed: Dictionary, now: int) -> String:
	if lazy.has("dummy") and not DUMMY.evidence("QuestView",lazy.dummy).is_empty(): return "원본 더미 선언 퀘스트 연결 제외"
	if not row.excluded_reasons.is_empty(): return str(row.excluded_reasons[0])
	if not row.blockers.is_empty(): return str(row.blockers[0])
	if row.starts_at == null or row.ends_at == null: return "원본 운영 기간 해석 보류"
	if now < int(row.starts_at): return "시작 전"
	if now > int(row.ends_at): return "기간 종료"
	if not str(lazy.after).is_empty(): return str(lazy.after)
	for condition: Array in lazy.prerequisites:
		var amount: int = int(condition[1])
		match str(condition[0]):
			"MinLevel":
				if int(context.get("level",1)) < amount: return "레벨 %d부터 이용" % amount
			"MaxLevel":
				if int(context.get("level",1)) > amount: return "최대 레벨 %d 제한" % amount
			"MinLevelByCharacterMaxLevel":
				if int(context.get("max_level",context.get("level",1))) < amount: return "최고 레벨 %d 필요" % amount
			"Class":
				if int(context.get("class_id",-1)) != amount: return "직업 조건 미충족"
			"ClassNot":
				if int(context.get("class_id",-1)) < 0 or int(context.get("class_id",-1)) == amount: return "직업 조건 미충족"
			"Quest":
				if not claimed.has("m523:quest:"+str(amount)): return "선행 퀘스트 %d 필요" % amount
			"CreateCharacter":
				if amount != 1: return "캐릭터 생성 조건 확인 필요"
			_: return "선행 조건 미연결: "+str(condition[0])
	for goal: Array in lazy.level_goals:
		var character: int = int(goal[0])
		if character != 0 and int(context.get("class_id",-1)) < 0: return "직업별 레벨 조건 확인 필요"
		if character != 0 and character != int(context.get("class_id",-1)): continue
		if int(goal[1]) != 1 or int(goal[2]) < 1: return "원본 레벨 목표 조건 해석 보류"
		if int(context.get("level",1)) < int(goal[2]): return "레벨 %d부터 이용" % int(goal[2])
	return ""

func reward_plan(row: Dictionary, context: Dictionary) -> Dictionary:
	if row.has(LAZY_KEY):
		row = full(row)
		if row.has(LAZY_KEY): return {"ok":false,"error":"퀘스트 원본 기록을 읽을 수 없습니다"}
	# QuestRewardEnhancement is an optional paid boost. The original base
	# Reward rows are granted; automatic completion never spends diamonds.
	# NC confirmation: 2019-01-30 patch notes, additional diamond consumption.
	var result: Dictionary = {"ok":true,"adena":0,"exp":0,"items":[],"quests":[],"pending_use":[],"ui_requests":[],"source_dummy_rewards":[],"optional_enhancement_unused":not row.enhancements.is_empty()}
	for reward: Dictionary in row.source_rewards:
		var character: int = int(reward.CharacterClassID)
		if character != 0 and int(context.get("class_id",-1)) < 0: return {"ok":false,"error":"직업별 보상 판별 대기"}
		if character != 0 and character != int(context.get("class_id",-1)): continue
		if bool(reward.ClanOnly): return {"ok":false,"error":"혈맹 전용 보상 제외"}
		if int(reward.RewardEnhancementTypeID) != 1:
			if int(reward.RewardEnhancementTypeID) in [11,21] and not row.enhancements.is_empty(): continue
			return {"ok":false,"error":"원본 보상 강화 유형 확인 필요"}
		var amount: int = int(reward.Amount)
		if amount < 0 or amount > 9007199254740991: return {"ok":false,"error":"보상 수량 오류"}
		match str(reward.type_name):
			"Exp": result.exp += amount
			"Item":
				var original: Dictionary = reward.get("source_item",{})
				var excluded: Dictionary=preload("res://scripts/quests/source_dummy523.gd").item_evidence(original)
				if not excluded.is_empty():
					result.source_dummy_rewards.append({"reward_id":int(reward.ID),"item_class_id":int(reward.RewardClassID),"evidence":excluded})
					continue # Explicit user exclusion, not a granted/used source item.
				if _currency_id(int(reward.RewardClassID)) == 1: result.adena += amount
				else:
					var coin_name: String = str(original.get("Name","")).trim_prefix("[화폐] ")
					var coins: Dictionary = context.get("currency_items",{})
					if _currency_id(int(reward.RewardClassID)) > 0 and coins.has(coin_name) and str(coins[coin_name].get("slot","")) == "currency":
						result.items.append({"record":coins[coin_name].duplicate(true),"quantity":amount,"stack_only":true,"source_reward_id":int(reward.ID)})
						continue
					var binding: Dictionary = ITEM_BINDINGS.resolve(reward,context.get("source_items",{}),context.get("source_item_consumer",Callable()))
					var record: Dictionary = binding.record
					var provider: Callable = context.get("quest_item_provider",Callable())
					if record.is_empty() and provider.is_valid() and (not context.has("received_native_rewards") or context.received_native_rewards.has(str(int(reward.ID)))):
						var native: Dictionary = provider.call(reward)
						if not native.is_empty():
							result.items.append({"record":native.record,"quantity":amount,"source_reward_id":int(reward.ID),"source_bless_code_id":int(reward.ItemBlessCodeID),"native_supplier":true,"pack_sha256":native.pack_sha256})
							continue
					if record.is_empty():
						# Keep an exact native item in the real inventory with its
						# pinned identity. It cannot masquerade as usable legacy
						# equipment/consumables with the same display name.
						var label: String = str(original.get("Name",""))
						if label.is_empty(): return {"ok":false,"error":"원본 아이템 이름 누락"}
						if amount > 10000: return {"ok":false,"error":"원본 보상 수량의 개체 저장 연결 필요"}
						record = {"name":"[원본 보상] "+label,"source_display_name":label,"slot":"quest_reward","type":"원본 보상 보관","grade":"미확인","source":"lineagem_patch523","source_snapshot":"patch523","sourceId":"m523:item:"+str(int(reward.RewardClassID)),"source_item_class_id":int(reward.RewardClassID),"source_original_item":original.duplicate(true),"source_pending_use":true,"quest_item":true,"weight":0,"droppable":false,"sellable":false,"desc":"원본 ID·수량을 보존한 보상입니다. 장착·사용 기능 연결 전까지 보관합니다."}
						result.pending_use.append(label)
						record["source_bless_code_id"] = int(reward.ItemBlessCodeID)
						record["source_use_immediately"] = bool(reward.UseImmediately)
						record["source_reward_id"] = int(reward.ID)
						record["source_binding_problem"] = str(binding.reason)
					result.items.append({"record":record.duplicate(true),"quantity":amount,"source_reward_id":int(reward.ID),"source_bless_code_id":int(reward.ItemBlessCodeID)})
			"NoReward": pass
			"QuickSlotReg":
				# Tutorial registration is a UI default, not an item quantity.
				# Preserve its original parameters without overwriting the user's
				# 50 existing bindings or guessing how source values 100+ map.
				result.ui_requests.append({"reward_id":int(reward.ID),"class_id":int(reward.RewardClassID),"raw_amount":amount})
			# Quest rewards unlock ownership, never waive a child's prerequisites.
			"Quest": result.quests.append(int(reward.RewardClassID))
			_: return {"ok":false,"error":"보상 미연결: "+str(reward.type_name)}
	return result

func _currency_id(item_id: int) -> int:
	return int(currency_ids.get(item_id,0))
