extends RefCounted
## Explicit user estimates. Raw source bytes and base508 consumers stay separate.
const PACK = preload("res://scripts/resources/current523_pack.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const PARSE_CACHE = preload("res://scripts/resources/sp2_parse_cache.gd")
const SETTINGS = "user://current523_estimated_playback.json"
const DEFAULTS = {"enabled":false,"member":"Sprite/85-0.sp2","group_bit":0,"fps":12.0,"alpha_policy":"opaque_samples","rgb_policy":"bit_replication","blend":"mix","opacity":1.0,"zoom":1.0,"loop":true,"world_enabled":false,"world_target":"sample","world_x":96.0,"world_y":0.0}
static var revision: int = 0
static var _options: Dictionary = {}
static var _source_root: String = ""
static var _rows: Array[Dictionary] = []
static var _index: Dictionary = {}
static var _cached_member: String = ""
static var _parsed: Dictionary = {}
static var settings_problem: String = ""

static func source_root() -> String:
	if _source_root.is_empty():
		_source_root = PACK.root_path()
		if _source_root.is_empty(): _source_root = PACK.latest_root()
	return _source_root

static func _error(message: String) -> Dictionary:
	return {"ok":false,"error":message,"estimated":true}

static func members() -> Array[Dictionary]:
	if not _rows.is_empty(): return _rows.duplicate(true)
	var selected: String = source_root()
	if selected.is_empty() or PACK.info(selected).is_empty(): return []
	var path: String = selected.path_join(PACK.REGISTRY)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != PACK.REGISTRY_SHA: return []
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Array or value.size() != 989: return []
	var rows: Array[Dictionary] = []
	var index: Dictionary = {}
	for row: Variant in value:
		if not row is Dictionary: return []
		var member: String = str(row.get("member", ""))
		var canonical: String = str(row.get("canonical_package_member", ""))
		if not member.begins_with("Sprite/") or not member.trim_prefix("Sprite/").is_valid_filename() or member.trim_prefix("Sprite/").contains("/") or canonical != "selected_originals/" + member or index.has(member): return []
		rows.append(row)
		index[member] = row
	_rows = rows
	_index = index
	return _rows.duplicate(true)

static func load_member(member: String) -> Dictionary:
	if members().is_empty() or not _index.has(member): return _error("설치된 523 원문에서 파일을 찾지 못했습니다.")
	var row: Dictionary = _index[member]
	if _cached_member == member and not _parsed.is_empty(): return {"ok":true,"parsed":_parsed,"source_row":row.duplicate(true),"estimated":true}
	var path: String = source_root().path_join(row.canonical_package_member)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _error("523 원문 파일을 읽지 못했습니다.")
	var length: int = file.get_length()
	if length != int(row.bytes) or length <= 0 or length > 2 * 1024 * 1024: return _error("523 원문 크기가 다릅니다.")
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	if PACK.digest(bytes) != row.sha256: return _error("523 원문 해시가 다릅니다. 추정 재생을 중단합니다.")
	var parsed: Dictionary = PARSE_CACHE.parse(bytes)
	if not bool(parsed.get("ok", false)): return _error(str(parsed.get("error", "SP2 구조를 읽지 못했습니다.")))
	_cached_member = member
	_parsed = parsed
	return {"ok":true,"parsed":_parsed,"source_row":row.duplicate(true),"estimated":true}

static func _validate(values: Dictionary) -> Dictionary:
	var result: Dictionary = DEFAULTS.duplicate(true)
	for key: String in DEFAULTS:
		if values.has(key): result[key] = values[key]
	for key: String in ["enabled", "loop", "world_enabled"]:
		if not result[key] is bool: return _error("추정 재생 설정 형식이 다릅니다: " + key)
	for key: String in ["member", "alpha_policy", "rgb_policy", "blend", "world_target"]:
		if not result[key] is String: return _error("추정 재생 설정 형식이 다릅니다: " + key)
	if not result.alpha_policy in ["opaque_samples", "index0_transparent"] or not result.rgb_policy in ["bit_replication", "linear"] or not result.blend in ["mix", "add", "multiply"]: return _error("지원하지 않는 추정 표시 정책입니다.")
	if not result.world_target in ["sample", "player"]: return _error("추정 표시 대상이 잘못됐습니다.")
	if not result.group_bit is int and not result.group_bit is float: return _error("저장 그룹 설정이 잘못됐습니다.")
	var group_value: float = float(result.group_bit)
	if not is_finite(group_value) or group_value < 0.0 or group_value > 7.0 or group_value != floorf(group_value): return _error("저장 그룹은 0~7이어야 합니다.")
	result.group_bit = int(result.group_bit)
	for key: String in ["fps", "opacity", "zoom", "world_x", "world_y"]:
		if not result[key] is int and not result[key] is float: return _error("추정 수치 설정이 잘못됐습니다: " + key)
		var value: float = float(result[key])
		var limits: Array = {"fps":[1.0,60.0],"opacity":[0.0,1.0],"zoom":[0.25,8.0],"world_x":[-1024.0,1024.0],"world_y":[-1024.0,1024.0]}[key]
		if not is_finite(value) or value < float(limits[0]) or value > float(limits[1]): return _error("추정 수치 범위를 벗어났습니다: " + key)
		result[key] = value
	if not result.member.begins_with("Sprite/") or not result.member.ends_with(".sp2") or not result.member.trim_prefix("Sprite/").is_valid_filename() or result.member.trim_prefix("Sprite/").contains("/"): return _error("추정 재생 파일명이 잘못됐습니다.")
	return {"ok":true,"options":result}

static func options() -> Dictionary:
	if not _options.is_empty(): return _options.duplicate(true)
	_options = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(SETTINGS):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if value is Dictionary and value.get("schema") == 1 and value.get("mode") == "estimated_SP2_not_native_M" and value.get("options") is Dictionary:
			var checked: Dictionary = _validate(value.options)
			if checked.ok: _options = checked.options
			else: settings_problem = str(checked.error)
		else: settings_problem = "추정 설정 기록을 읽지 못해 사용하지 않습니다."
	return _options.duplicate(true)

static func save_options(values: Dictionary) -> Dictionary:
	var checked: Dictionary = _validate(values)
	if not checked.ok: return checked
	var next: Dictionary = checked.options
	if next.enabled:
		var loaded: Dictionary = load_member(next.member)
		if not loaded.ok: return loaded
		var found: bool = false
		for group: Dictionary in loaded.parsed.groups:
			if int(group.bit) == int(next.group_bit) and not group.frames.is_empty(): found = true
		if not found: return _error("선택한 저장 그룹에 프레임이 없습니다.")
	var temporary: String = SETTINGS + ".tmp-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _error("추정 설정을 저장하지 못했습니다. 이전 설정을 유지합니다.")
	file.store_string(JSON.stringify({"schema":1,"mode":"estimated_SP2_not_native_M","options":next}))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary,SETTINGS) != OK: return _error("추정 설정 전환에 실패했습니다. 이전 설정을 유지합니다.")
	_options = next
	settings_problem = ""
	revision += 1
	return {"ok":true,"options":_options.duplicate(true),"estimated":true}
