extends RefCounted
## Read-only access to the already supplied original definition archive.
## No installation, grants, aliases, saved ownership or generated media.
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const SOURCE_BYTES: int = 25031173
const INSTALLED := "user://growth96_definitions/source.zip"
const EXISTING_ARCHIVES := [INSTALLED,"user://source_rules/death523.zip","user://title523/source.zip"]
const EXCLUDED_TABLES := ["BannedWord","BannedWordType","BannedWordData_Korean","PersonalAppellationBannedWordTypeList"]
static var _archive: ZIPReader
static var _archive_path := ""
static var _tables: Dictionary = {}
static var _relations: Dictionary = {}
static var _metadata: Dictionary = {}
static var _problem := ""

static func reset() -> void:
	if _archive != null: _archive.close()
	_archive = null
	_archive_path = ""
	_tables.clear()
	_relations.clear()
	_metadata.clear()
	_problem = ""

static func problem() -> String:
	return _problem

static func _open() -> bool:
	var path: String = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	if path.is_empty():
		for existing: String in EXISTING_ARCHIVES:
			if FileAccess.file_exists(existing):
				path = existing
				break
		if path.is_empty(): path = INSTALLED
	if _archive != null and path == _archive_path: return true
	if _archive != null: reset()
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		_problem = "보유 원본523 정의 ZIP이 연결되지 않았습니다. 기존 정의와 소유 상태는 보존합니다."
		return false
	var size: int = file.get_length()
	file.close()
	if size != SOURCE_BYTES or FileAccess.get_sha256(path) != SOURCE_SHA:
		_problem = "원본523 정의 ZIP 정체가 다릅니다. 참조 관계를 추정하지 않습니다."
		return false
	var archive := ZIPReader.new()
	if archive.open(path) != OK:
		_problem = "원본523 정의 ZIP을 읽을 수 없습니다."
		return false
	_archive = archive
	_archive_path = path
	_problem = ""
	return true

static func identity() -> Dictionary:
	if not _open(): return {}
	return {"kind":"twilight.current523.original-definitions.v1","source_snapshot":"patch523","source_sha256":SOURCE_SHA,"source_bytes":SOURCE_BYTES}

static func archive_path() -> String:
	# Reuse existing whole-archive parsers without copying/installing another
	# input. Callers must retain their own parsing guards and never save this path.
	return _archive_path if _open() else ""

static func table_metadata(table: String) -> Dictionary:
	# Original index provenance for existing derived input formats. These are
	# input metadata, not a new table-use observation or a generated-pack hash.
	if table in EXCLUDED_TABLES or not table.is_valid_identifier() or not _open(): return {}
	if _metadata.is_empty():
		if not _archive.file_exists("index.json"): return {}
		var index: Variant = JSON.parse_string(_archive.read_file("index.json").get_string_from_utf8())
		if not index is Array: return {}
		for entry: Variant in index:
			if not entry is Dictionary or not entry.get("path") is String: continue
			_metadata[entry.path] = entry
	return _metadata.get("content/"+table+".json",{}).duplicate(true)

static func _raw_rows(table: String) -> Array:
	# User-excluded game word filters are never loaded through this reader.
	# The original archive and fixed inventory/byte denominators stay intact.
	if table in EXCLUDED_TABLES:
		_tables.erase(table)
		_problem = "사용자 제외 원본 표: "+table
		return []
	if not _open(): return []
	if _tables.has(table): return _tables[table]
	# Table names are member basenames, never paths or external references.
	if table.is_empty() or not table.is_valid_identifier():
		_problem = "원본 표 이름이 유효하지 않습니다."
		return []
	var member: String = "content/"+table+".json"
	if not _archive.file_exists(member):
		_problem = "원본 표가 없습니다: "+table
		return []
	var parsed: Variant = JSON.parse_string(_archive.read_file(member).get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("rows") is Array:
		_problem = "원본 표 구조를 읽을 수 없습니다: "+table
		return []
	for value: Variant in parsed.rows:
		if not value is Dictionary:
			_problem = "원본 행 구조가 다릅니다: "+table
			return []
	_tables[table] = parsed.rows
	return _tables[table]

static func rows(table: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in _raw_rows(table): result.append(value.duplicate(true))
	return result

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

static func related(table: String, foreign_key: String, id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source: Array = _raw_rows(table)
	if not _tables.has(table): return result
	var key: String = table+":"+foreign_key
	if not _relations.has(key):
		var groups: Dictionary = {}
		for value: Dictionary in source:
			if not _integer(value.get(foreign_key)):
				_problem = "원본 정수 참조가 없습니다: "+table+"."+foreign_key
				return result
			var identifier: String = str(int(value[foreign_key]))
			if not groups.has(identifier): groups[identifier] = []
			groups[identifier].append(value)
		_relations[key] = groups
	for value: Dictionary in _relations[key].get(str(id),[]): result.append(value.duplicate(true))
	return result

static func row(table: String, id: int) -> Dictionary:
	var matches: Array[Dictionary] = related(table,"ID",id)
	if matches.size()!=1:
		if matches.size()>1: _problem = "원본 ID가 중복됩니다: "+table+"#"+str(id)
		elif _tables.has(table): _problem = "원본 ID가 없습니다: "+table+"#"+str(id)
		return {}
	return matches[0]
