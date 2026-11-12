extends RefCounted
## Creation eligibility comes from the verified installed 523 definitions.
## 13 slots is a local account policy, not a count inferred from Class rows.
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const JOB_NAMES := {1:"기사",2:"요정",3:"마법사",4:"다크엘프",5:"투사",7:"광전사",8:"군주",34:"총사",52:"암흑기사",81:"신성검사",94:"사신",111:"뇌신",142:"마검사"}
const STAT_FIELDS := {"str":"InitStatStr","dex":"InitStatDex","con":"InitStatCon","wis":"InitStatWis","cha":"InitStatCha","int":"InitStatInt","lfe":"InitStatLfe","dth":"InitStatDth"}
var problem: String = ""
var classes: Array[Dictionary] = []
var account_slots: Array[Dictionary] = []
var deck_scope: Dictionary = {}
var source_identity: Dictionary = {}

func configure() -> bool:
	classes.clear()
	problem = ""
	source_identity = DEFINITIONS.identity()
	if source_identity.get("kind") != "twilight.current523.original-definitions.v1" or source_identity.get("source_snapshot") != "patch523" or source_identity.get("source_sha256") != DEFINITIONS.SOURCE_SHA or source_identity.get("source_bytes") != DEFINITIONS.SOURCE_BYTES:
		problem = "캐릭터 생성에는 검증된 원본523 정의가 필요합니다. " + DEFINITIONS.problem()
		return false
	var tables: Dictionary = {}
	for table: String in ["Class","ClassAssets","Gender","AccountSlot","BuffCardDeck"]:
		tables[table] = DEFINITIONS.rows(table)
		if tables[table].is_empty():
			problem = "원본523 %s 정의가 없어 캐릭터 생성을 보류합니다." % table
			return false
	return _configure_rows(tables)

## Pure relation validation also used by synthetic unit fixtures, never an
## alternate on-device install route. Production calls configure() above.
func _configure_rows(tables: Dictionary) -> bool:
	classes.clear()
	account_slots.clear()
	deck_scope.clear()
	problem = ""
	var genders: Dictionary = {}
	for row: Dictionary in tables.get("Gender", []):
		if _uint(row.get("ID")) and int(row.ID) in [1,2]:
			if genders.has(int(row.ID)): return _fail("원본 성별 ID 중복")
			genders[int(row.ID)] = row
	var seen: Dictionary = {}
	for row: Dictionary in tables.get("Class", []):
		if row.get("CanCreateClient") != true: continue
		if not _uint(row.get("ID")) or not JOB_NAMES.has(int(row.ID)): return _fail("지원되지 않는 원본 직업 ID")
		var id: int = int(row.ID)
		if seen.has(id): return _fail("원본 직업 ID 중복")
		seen[id] = true
		var stats: Dictionary = {}
		for key: String in STAT_FIELDS:
			if not _uint(row.get(STAT_FIELDS[key])): return _fail("원본 초기 능력치 오류")
			stats[key] = int(row[STAT_FIELDS[key]])
		var allowed: Array[int] = []
		var assets: Dictionary = {}
		for candidate: Dictionary in tables.get("ClassAssets", []):
			if candidate.get("ClassID") != id: continue
			if not _uint(candidate.get("GenderID")) or not genders.has(int(candidate.GenderID)): return _fail("직업 그림의 성별 참조 오류")
			var gender: int = int(candidate.GenderID)
			if assets.has(gender): return _fail("직업·성별 그림 연결 중복")
			var sprite: Variant = row.get("MaleSpriteID" if gender == 1 else "FemaleSpriteID")
			if not _uint(sprite) or int(sprite) <= 0: return _fail("직업·성별 원본 스프라이트 참조 오류")
			allowed.append(gender)
			assets[gender] = candidate.duplicate(true)
		if allowed.is_empty(): return _fail("생성 가능한 직업의 성별 그림 연결 없음")
		allowed.sort()
		classes.append({"id":id,"name":JOB_NAMES[id],"genders":allowed,"stats":stats,"source":row.duplicate(true),"assets":assets})
	if classes.is_empty(): return _fail("생성 가능한 원본 직업 없음")
	for row: Dictionary in tables.get("AccountSlot", []):
		if not _uint(row.get("ID")) or not _uint(row.get("AccountSlotTypeID")) or not _uint(row.get("Value")): return _fail("원본 계정 슬롯 정의 오류")
		account_slots.append(row.duplicate(true))
	if account_slots.is_empty(): return _fail("원본 계정 슬롯 정의 없음")
	for row: Dictionary in tables.get("BuffCardDeck", []):
		if not _uint(row.get("ID")) or not row.get("CharacterBased") is bool: return _fail("원본 카드 보유 범위 오류")
		if deck_scope.has(int(row.ID)): return _fail("원본 카드 덱 ID 중복")
		deck_scope[int(row.ID)] = row.CharacterBased
	for id: int in [1,2,98]:
		if deck_scope.get(id) != false: return _fail("변신·인형·성물의 계정 보유 근거 불일치")
	if deck_scope.get(41) != true: return _fail("스킬의 캐릭터 보유 근거 불일치")
	return true

func profile(id: int, gender: int) -> Dictionary:
	if not problem.is_empty(): return {}
	for row: Dictionary in classes:
		if row.id == id and gender in row.genders:
			var out: Dictionary = row.duplicate(true)
			out["class_id"] = id
			out["gender_id"] = gender
			out["job_class"] = row.name
			out["class_assets"] = row.assets[gender].duplicate(true)
			return out
	return {}

func job_name(id: int) -> String:
	return str(JOB_NAMES.get(id,"알 수 없는 직업"))

func _fail(message: String) -> bool:
	problem = message
	classes.clear()
	return false

static func _uint(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0 and float(value) <= 2147483647
