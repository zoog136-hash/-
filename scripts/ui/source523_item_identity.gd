extends RefCounted
## Presentation-only original ItemClass identity of a bag/ground/log entry.
##
## Phone report 2026-11-20: some bag slots stayed empty, their tap name showed
## TWILIGHT's internal "[원본 보상] [방어구-망토] 마법 망토 (각인)" key and the
## log showed "공성 포인트 · 원본#195371". Those entries come from older
## suppliers (legacy name catalog rows such as "각인 장비 상자", held quest
## rewards keyed by ItemClass.Name, " · 원본#N" native keys) whose record has
## no image route. Here the entry is matched to its original ItemClass row
## (explicit ID first, then the exact original Korean item name from
## DescData_Korean) so the original icon, name and grade color can be shown.
## Nothing here grants, converts or saves anything.
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const NATIVE_SUFFIX := " · 원본#"
const HELD_PREFIX := "[원본 보상] "
const BLESS_SUFFIXES := {" · 축복":2, " · 저주":3}
static var _by_name: Dictionary = {}
static var _indexed_generation: int = -1
static var _cache: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) > 0.0

## " · 원본#N" / " · 축복" / "@@@instance" / "[원본 보상] " stripped: the
## text a player should read for an inventory key.
static func plain_text(text: String) -> String:
	var value: String = text.get_slice("@@@", 0)
	if value.begins_with(HELD_PREFIX): value = value.trim_prefix(HELD_PREFIX)
	var regex := RegEx.create_from_string(" · 원본#\\d+")
	value = regex.sub(value, "", true)
	return value

## Strip internal identity markers inside free text (logs, messages).
static func clean_message(text: String) -> String:
	if not text.contains(NATIVE_SUFFIX) and not text.contains(HELD_PREFIX) and not text.contains("@@@"): return text
	var value: String = RegEx.create_from_string(" · 원본#\\d+").sub(text, "", true)
	value = RegEx.create_from_string("@@@[0-9a-f]+").sub(value, "", true)
	return value.replace(HELD_PREFIX, "")

## Original ItemClass.ID for a record and/or inventory key, or -1.
static func item_class_id(record: Dictionary, key: String = "") -> int:
	var value: Variant = record.get("source_item_class_id")
	if _integer(value): return int(value)
	for id_value: Variant in [record.get("sourceId", ""), record.get("source_id", "")]:
		var text: String = str(id_value)
		if text.begins_with("m523:item:") and text.trim_prefix("m523:item:").is_valid_int(): return int(text.trim_prefix("m523:item:"))
	for text: String in [key.get_slice("@@@", 0), str(record.get("name", ""))]:
		var at: int = text.rfind(NATIVE_SUFFIX)
		if at >= 0:
			var digits: String = text.substr(at + NATIVE_SUFFIX.length()).get_slice(" ", 0)
			if digits.is_valid_int() and int(digits) > 0: return int(digits)
	var name: String = plain_text(key if not key.is_empty() else str(record.get("name", "")))
	for suffix: String in BLESS_SUFFIXES:
		if name.ends_with(suffix): name = name.trim_suffix(suffix)
	if name.is_empty(): return -1
	return by_name(name)

## Unique original ItemClass for an exact original Korean item name. Several
## rows with one name count only when they share one IconID (the same
## picture); the lowest ID is returned.
static func by_name(name: String) -> int:
	if _cache.has(name): return int(_cache[name])
	_ensure_index()
	var found: int = -1
	var candidates: Variant = _by_name.get(name)
	if candidates is Array and not candidates.is_empty():
		var icon: int = int(candidates[0][1])
		found = int(candidates[0][0])
		for pair: Array in candidates:
			if int(pair[1]) != icon: found = -1; break
			found = mini(found, int(pair[0]))
	_cache[name] = found
	return found

static func _ensure_index() -> void:
	var generation: int = SOURCE.cache_generation()
	if _indexed_generation == generation and not _by_name.is_empty(): return
	_by_name.clear()
	_cache.clear()
	_indexed_generation = generation
	if SOURCE.not_installed(): return
	var ids: Variant = SOURCE.column("ItemClass", "ID")
	var descs: Variant = SOURCE.column("ItemClass", "DescID")
	var identified: Variant = SOURCE.column("ItemClass", "IdentifiedDescID")
	var icons: Variant = SOURCE.column("ItemClass", "IconID")
	var tests: Variant = SOURCE.column("ItemClass", "TestItem")
	var count: int = ids.size()
	if descs.size() != count or icons.size() != count: return
	for index: int in count:
		if tests.size() == count and tests[index] == true: continue
		var desc: int = int(identified[index]) if identified.size() == count and _integer(identified[index]) else 0
		var text: String = _label(desc) if desc > 0 else ""
		if text.is_empty() and _integer(descs[index]): text = _label(int(descs[index]))
		if text.is_empty() or not _integer(icons[index]): continue
		if not _by_name.has(text): _by_name[text] = []
		_by_name[text].append([int(ids[index]), int(icons[index])])

static func _label(desc_id: int) -> String:
	return str(SOURCE.row("DescData_Korean", desc_id).get("Description", "")).strip_edges()

## The original ItemClass row (empty when not installed / unknown).
static func row(id: int) -> Dictionary:
	if id <= 0 or SOURCE.not_installed(): return {}
	var value: Dictionary = SOURCE.row("ItemClass", id)
	return value if value.get("ID") == id and value.get("TestItem") != true else {}

## The original Korean item name (IdentifiedDescID, else DescID).
static func original_name(id: int) -> String:
	var source: Dictionary = row(id)
	if source.is_empty(): return ""
	var text: String = _label(int(source.get("IdentifiedDescID", 0))) if _integer(source.get("IdentifiedDescID")) else ""
	if text.is_empty() and _integer(source.get("DescID")): text = _label(int(source.DescID))
	return text

## The name a player reads: the original name when the entry has an original
## identity, else the key without internal markers.
static func display_name(record: Dictionary, key: String) -> String:
	var id: int = item_class_id(record, key)
	var text: String = original_name(id) if id > 0 else ""
	if text.is_empty():
		text = str(record.get("source_display_name", ""))
	if text.is_empty(): text = plain_text(key if not key.is_empty() else str(record.get("name", "")))
	return text

## Original GradeID of the entry (0 when unknown).
static func grade_id(record: Dictionary, key: String) -> int:
	if _integer(record.get("source_grade_id")): return int(record.source_grade_id)
	var source: Dictionary = row(item_class_id(record, key))
	return int(source.get("GradeID", 0)) if _integer(source.get("GradeID")) else 0

static func reset() -> void:
	_by_name.clear()
	_cache.clear()
	_indexed_generation = -1

## Original acquisition message (UITextData_Korean 16771
## "%param%(을)(를) 획득하였습니다." / 16781 "%param% {0}개를 획득하였습니다.")
## with the Korean object particle chosen from the name's last syllable.
const ACQUIRE_ONE := 16771
const ACQUIRE_MANY := 16781

static func acquire_text(name: String, quantity: int) -> String:
	var plain: String = plain_text(name)
	var template: String = "" if SOURCE.not_installed() else str(SOURCE.row("UITextData_Korean", ACQUIRE_ONE if quantity <= 1 else ACQUIRE_MANY).get("Description", "")).strip_edges()
	if template.is_empty() or not template.contains("%param%"):
		return "%s ×%d 획득" % [plain, quantity] if quantity > 1 else "%s 획득" % plain
	return particles(template.replace("%param%", plain).replace("{0}", str(quantity)), plain)

## Resolves "(을)(를)", "(이)(가)", "(은)(는)", "(과)(와)" after `word`.
static func particles(text: String, word: String) -> String:
	var batchim: bool = false
	if not word.is_empty():
		var code: int = word.unicode_at(word.length() - 1)
		if code >= 0xAC00 and code <= 0xD7A3: batchim = (code - 0xAC00) % 28 != 0
		elif String.chr(code).is_valid_int(): batchim = String.chr(code) in ["0","1","3","6","7","8"]
	for pair: Array in [["(을)(를)","을","를"],["(이)(가)","이","가"],["(은)(는)","은","는"],["(과)(와)","과","와"]]:
		text = text.replace(pair[0], pair[1] if batchim else pair[2])
	return text

## Developer/verification wording in a player message ("검증된 … 미설치",
## "… 연결 대기", owner/receipt/SHA terms). Release screens show the original
## generic notice (UITextData_Korean 16572 "지금은 이용할 수 없습니다.")
## instead; debug and twilight_dev_ui builds keep the full text.
const UNAVAILABLE := 16572
const DEVELOPER_WORDS: Array[String] = ["검증", "검수", "미설치", "연결 대기", "미연결", "영수증", "소유자", "owner", "TWILIGHT", "source", "SHA", "ABI", "DTO", "원문", "정의 미등록", "입력 확인", "원본#", "UI 팩", "정의 ZIP", "원본 팩", "리소스 팩"]
## Build/version tags inside ordinary text ("원본523 제작 · 장검"): release
## screens drop the tag and keep the sentence.
const BUILD_TAG := "(원본|최신|현재)\\s?523\\s*(·\\s*)?|\\b(patch|current|client)523\\b"
## "523" naming the data version (not a number such as damage 523).
const VERSION_WORD := "(?<![0-9])523 ?(아덴|원본|리소스|캐릭터|지도|팩|UI|표|정의|이전|교체|데이터|SP2|기준)"

static func developer_wording(text: String) -> bool:
	for word: String in DEVELOPER_WORDS:
		if text.contains(word): return true
	return RegEx.create_from_string(VERSION_WORD).search(text) != null

static func strip_build_tags(text: String) -> String:
	if not text.contains("523"): return text
	var value: String = RegEx.create_from_string(BUILD_TAG).sub(text, "", true).strip_edges()
	while value.begins_with("·"): value = value.trim_prefix("·").strip_edges()
	while value.ends_with("·"): value = value.trim_suffix("·").strip_edges()
	return value

## Secondary text (window subtitles, notes): developer wording disappears on
## release screens instead of becoming a notice.
static func screen_note(text: String, developer: bool = preload("res://scripts/boot/build_flags.gd").developer_ui()) -> String:
	var value: String = clean_message(text)
	if developer: return value
	value = strip_build_tags(value)
	return "" if developer_wording(value) else value

static func screen_text(text: String, developer: bool = preload("res://scripts/boot/build_flags.gd").developer_ui()) -> String:
	var value: String = clean_message(text)
	if developer: return value
	value = strip_build_tags(value)
	if not developer_wording(value): return value
	var notice: String = "" if SOURCE.not_installed() else str(SOURCE.row("UITextData_Korean", UNAVAILABLE).get("Description", "")).strip_edges()
	return notice if not notice.is_empty() else "지금은 이용할 수 없습니다."
