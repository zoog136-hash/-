extends RefCounted
## Read-only access to the already supplied original definition archive.
## No installation, grants, aliases, saved ownership or generated media.
const SOURCE_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const SOURCE_BYTES: int = 25031173
const INSTALLED := "user://growth96_definitions/source.zip"
const EXISTING_ARCHIVES := [
	INSTALLED,"user://source_rules/death523.zip","user://title523/source.zip",
	# Exact existing original-ZIP receivers, after the original priorities.
	# tj/source523.gd::CACHE (its SHA is SOURCE_SHA).
	"user://tj523-source.zip",
	# cards/relic_spell_levels.gd::INSTALLED (same SHA and SOURCE_BYTES).
	"user://source_rules/relic-patch523.zip",
	# unconfirmed523/source523.gd::SOURCE_PATH (same SHA and SOURCE_BYTES).
	"user://unconfirmed523/source.zip",
	# skills/spell_group_conversion.gd::DEFAULT_SOURCE (same SOURCE_SHA).
	"user://sources/lineagem_patch523_all_content_validated_and_508_520_deltas.zip",
	# growth/half_elixir_runtime.gd::ROOT + source_for()'s saved SHA suffix.
	# Only this exact original identity is a candidate; no save is inspected or
	# rebound, and no other saved-SHA archive or derived pack is searched.
	"user://half_elixir523/packs/"+SOURCE_SHA+".zip",
]
const EXCLUDED_TABLES := ["BannedWord","BannedWordType","BannedWordData_Korean","PersonalAppellationBannedWordTypeList"]
static var _archive: ZIPReader
static var _archive_path := ""
static var _tables: Dictionary = {}
static var _relations: Dictionary = {}
static var _metadata: Dictionary = {}
static var _problem := ""
static var _not_installed := false

static func reset() -> void:
	if _archive != null: _archive.close()
	_archive = null
	_archive_path = ""
	_tables.clear()
	_relations.clear()
	_integer_fields.clear()
	_metadata.clear()
	_problem = ""
	_not_installed = false

static func problem() -> String:
	return _problem

## True only when no ZIP was named and none is present on disk. A ZIP that is
## present but unreadable, named empty, or has another identity is not this
## state: those stay problems that protect existing owned data.
static func not_installed() -> bool:
	_open()
	return _not_installed

static func _open() -> bool:
	_not_installed = false
	var explicit: bool = OS.has_environment("TWILIGHT_PATCH523_CONTENT")
	var path: String = OS.get_environment("TWILIGHT_PATCH523_CONTENT")
	if explicit and path.is_empty():
		if _archive != null: reset()
		_problem = "원본523 정의 ZIP 경로를 빈 값으로 명시했습니다. 다른 입력으로 우회하지 않습니다."
		return false
	if not explicit:
		for existing: String in EXISTING_ARCHIVES:
			if FileAccess.file_exists(existing):
				path = existing
				break
			# file_exists() can also be false for an inaccessible input. Only an
			# actual missing-file result permits the next original-ZIP receiver.
			var candidate := FileAccess.open(existing,FileAccess.READ)
			var candidate_error: Error = FileAccess.get_open_error()
			if candidate != null:
				candidate.close()
				path = existing
				break
			if candidate_error != ERR_FILE_NOT_FOUND:
				path = existing
				break
		if path.is_empty(): path = INSTALLED
	if _archive != null and path == _archive_path: return true
	if _archive != null: reset()
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		_not_installed = not explicit and open_error == ERR_FILE_NOT_FOUND
		_problem = "보유 원본523 정의 ZIP을 읽을 수 없습니다: "+error_string(open_error)+". 기존 정의와 소유 상태는 보존합니다."
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

static func declared_exclusion(table: String, row: Dictionary, scope: String = "record") -> Dictionary:
	# PR269 owns the original declarations. Its optional SPI never substitutes
	# local names, ID lists or heuristics when that owner module is unavailable.
	var path: String = "res://scripts/quests/source_dummy523.gd"
	if not ResourceLoader.exists(path): return {}
	var owner: Resource = load(path)
	if owner == null or not owner.has_method("evidence"): return {}
	var evidence: Variant = owner.call("evidence",table,row.duplicate(true),scope)
	if not evidence is Dictionary or evidence.get("source_sha256") != SOURCE_SHA or evidence.get("excluded_from_connection") != true: return {}
	return evidence.duplicate(true)

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

# Parsed original tables are kept column-packed. A JSON row dictionary costs
# about 1.2 KB in Godot (Bonus alone, 217,916 rows, was ~255 MB), and the game
# loads ~150 tables at start: the dictionaries alone passed 3 GB and Android
# killed the process for LOW_MEMORY. Columns of numbers are PackedFloat64Array
# (JSON numbers are floats, so callers see exactly the same values and types),
# strings PackedStringArray, everything else a plain Array. Each call still
# returns fresh dictionaries, as the previous duplicate(true) did.
static func _store(table: String) -> Dictionary:
	# User-excluded game word filters are never loaded through this reader.
	# The original archive and fixed inventory/byte denominators stay intact.
	if table in EXCLUDED_TABLES:
		_tables.erase(table)
		_problem = "사용자 제외 원본 표: "+table
		return {}
	if not _open(): return {}
	if _tables.has(table): return _tables[table]
	# Table names are member basenames, never paths or external references.
	if table.is_empty() or not table.is_valid_identifier():
		_problem = "원본 표 이름이 유효하지 않습니다."
		return {}
	var member: String = "content/"+table+".json"
	if not _archive.file_exists(member):
		_problem = "원본 표가 없습니다: "+table
		return {}
	var parsed: Variant = JSON.parse_string(_archive.read_file(member).get_string_from_utf8())
	if not parsed is Dictionary or not parsed.get("rows") is Array:
		_problem = "원본 표 구조를 읽을 수 없습니다: "+table
		return {}
	var source: Array = parsed.rows
	for value: Variant in source:
		if not value is Dictionary:
			_problem = "원본 행 구조가 다릅니다: "+table
			return {}
	_tables[table] = _pack(source)
	return _tables[table]

static func _pack(source: Array) -> Dictionary:
	var count: int = source.size()
	if count == 0: return {"count": 0, "columns": PackedStringArray(), "data": []}
	var columns: PackedStringArray = PackedStringArray((source[0] as Dictionary).keys())
	for value: Dictionary in source:
		if value.size() != columns.size(): return {"count": count, "rows": source}
		for column: String in columns:
			if not value.has(column): return {"count": count, "rows": source}
	var data: Array = []
	for column: String in columns:
		var kind: int = typeof(source[0][column])
		for value: Dictionary in source:
			if typeof(value[column]) != kind:
				kind = TYPE_NIL
				break
		if kind == TYPE_FLOAT:
			var numbers := PackedFloat64Array()
			numbers.resize(count)
			for index: int in count: numbers[index] = source[index][column]
			data.append(numbers)
		elif kind == TYPE_STRING:
			var texts := PackedStringArray()
			texts.resize(count)
			for index: int in count: texts[index] = source[index][column]
			data.append(texts)
		else:
			var values: Array = []
			values.resize(count)
			for index: int in count: values[index] = source[index][column]
			data.append(values)
	return {"count": count, "columns": columns, "data": data}

static func _row_at(store: Dictionary, index: int) -> Dictionary:
	if store.has("rows"): return (store.rows[index] as Dictionary).duplicate(true)
	var result: Dictionary = {}
	var columns: PackedStringArray = store.columns
	for column_index: int in columns.size():
		var value: Variant = store.data[column_index][index]
		result[columns[column_index]] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result

## Rows whose integer `field` is a key of `ids`, in original table order.
## Same rows as filtering rows(table), without building the whole table.
static func rows_matching(table: String, field: String, ids: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var store: Dictionary = _store(table)
	if store.is_empty() or ids.is_empty(): return result
	if store.has("rows"):
		for index: int in int(store.count):
			var value: Variant = (store.rows[index] as Dictionary).get(field)
			if _integer(value) and ids.has(int(value)): result.append(_row_at(store, index))
		return result
	var position: int = (store.columns as PackedStringArray).find(field)
	if position < 0: return result
	var column: Variant = store.data[position]
	for index: int in int(store.count):
		var value: Variant = column[index]
		if _integer(value) and ids.has(int(value)): result.append(_row_at(store, index))
	return result

## Row count and one fresh row by position, for streaming a table in order
## without materializing every row at once.
static func row_count(table: String) -> int:
	return int(_store(table).get("count", 0))

static func row_at(table: String, index: int) -> Dictionary:
	var store: Dictionary = _store(table)
	if index < 0 or index >= int(store.get("count", 0)): return {}
	return _row_at(store, index)

## One column's values in table order (a copy-on-write packed array when the
## column is uniform); empty when the field is not a column of every row.
static func column(table: String, field: String) -> Variant:
	var store: Dictionary = _store(table)
	if store.is_empty(): return []
	if store.has("rows"):
		var values: Array = []
		for value: Dictionary in store.rows:
			if not value.has(field): return []
			values.append(value[field])
		return values
	var position: int = (store.columns as PackedStringArray).find(field)
	return store.data[position] if position >= 0 else []

static func rows(table: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var store: Dictionary = _store(table)
	for index: int in int(store.get("count", 0)): result.append(_row_at(store, index))
	return result

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value)) and absf(float(value))<=9007199254740991.0

## True when every row has an integer value in `field` (so related() indexes it).
static var _integer_fields: Dictionary = {}
static func integer_field(table: String, field: String) -> bool:
	var key: String = table + ":" + field
	if _integer_fields.has(key) and _tables.has(table): return _integer_fields[key]
	_integer_fields[key] = _integer_column(table, field)
	return _integer_fields[key]

static func _integer_column(table: String, field: String) -> bool:
	var store: Dictionary = _store(table)
	if store.is_empty() or store.has("rows"): return false
	var position: int = (store.columns as PackedStringArray).find(field)
	if position < 0: return false
	var column: Variant = store.data[position]
	if not column is PackedFloat64Array: return false
	for value: float in column:
		if not _integer(value): return false
	return true

static func related(table: String, foreign_key: String, id: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var store: Dictionary = _store(table)
	if not _tables.has(table): return result
	var key: String = table+":"+foreign_key
	if not _relations.has(key):
		var groups: Dictionary = {}
		var column: Variant = null
		if not store.has("rows"):
			var position: int = (store.columns as PackedStringArray).find(foreign_key)
			if position >= 0: column = store.data[position]
		for index: int in int(store.count):
			var value: Variant = column[index] if column != null else (store.rows[index] as Dictionary).get(foreign_key) if store.has("rows") else null
			if not _integer(value):
				_problem = "원본 정수 참조가 없습니다: "+table+"."+foreign_key
				return result
			var identifier: int = int(value)
			if not groups.has(identifier): groups[identifier] = []
			(groups[identifier] as Array).append(index)
		for identifier: int in groups: groups[identifier] = PackedInt32Array(groups[identifier])
		_relations[key] = groups
	for index: int in _relations[key].get(id, PackedInt32Array()): result.append(_row_at(store, index))
	return result

static func row(table: String, id: int) -> Dictionary:
	var matches: Array[Dictionary] = related(table,"ID",id)
	if matches.size()!=1:
		if matches.size()>1: _problem = "원본 ID가 중복됩니다: "+table+"#"+str(id)
		elif _tables.has(table): _problem = "원본 ID가 없습니다: "+table+"#"+str(id)
		return {}
	return matches[0]
