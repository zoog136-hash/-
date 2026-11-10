extends RefCounted
## Frame hitch record for slow devices (the phone cannot be profiled here).
##
## Per-frame systems add their elapsed time to a named section with
## `add(section, now())` (two Time.get_ticks_usec() calls, no allocation once
## the section exists). FrameHitchProbe, the first node processed each frame,
## measures the whole previous frame (scripts + physics + drawing). A frame
## longer than THRESHOLD_USEC keeps its sections; the KEEP slowest frames go to
## user://frame_hitch.json (at most every FLUSH_USEC, and on quit/pause) and to
## logcat as "FRAME_HITCH {...}". The next start moves it to
## frame_hitch.prev.json so the loading screen can name what stalled last time.
const FILE_NAME := "frame_hitch.json"
const PREV_NAME := "frame_hitch.prev.json"
const PREFIX := "FRAME_HITCH "
const THRESHOLD_USEC: int = 100000
const KEEP: int = 12
const FLUSH_USEC: int = 5000000
## Korean labels for the loading screen; unknown sections show their key.
const LABELS: Dictionary = {
	"world":"월드 기타", "quests":"퀘스트", "hud":"HUD 갱신", "auto_hunt":"자동 사냥",
	"skills":"스킬", "loot":"드랍·줍기", "save":"저장", "field_triggers":"맵 이벤트",
	"monsters":"몬스터", "player":"캐릭터", "field_population":"몬스터 배치",
	"map_renderer":"지도 그리기", "map_objects":"맵 오브젝트", "monsterbook":"몬스터북",
	"companion":"동료", "buffs":"버프", "dungeon":"던전", "items":"아이템 자동 사용",
	"other":"그리기·엔진",
}

static var _dir: String = "user://"
static var _sections: Dictionary = {}
static var _frames: int = 0
static var _hitches: int = 0
static var _worst: Array = []
static var _last_frame: int = 0
static var _dirty: bool = false
static var _last_flush: int = 0
static var _started: bool = false
static var _previous: Dictionary = {}
static var enabled: bool = true
static var _nested: int = 0

static func now() -> int:
	return Time.get_ticks_usec()

static func add(section: String, started_usec: int) -> void:
	if not enabled: return
	var elapsed: int = Time.get_ticks_usec() - started_usec
	_nested += elapsed
	_sections[section] = int(_sections.get(section, 0)) + elapsed

## Time already given to sections; pass it to add_self() to exclude them.
static func nested() -> int:
	return _nested

## Adds the elapsed time minus whatever add() recorded since `nested_before`.
static func add_self(section: String, started_usec: int, nested_before: int) -> void:
	if not enabled: return
	var elapsed: int = Time.get_ticks_usec() - started_usec - (_nested - nested_before)
	_nested += maxi(0, elapsed)
	_sections[section] = int(_sections.get(section, 0)) + maxi(0, elapsed)

## Called once per frame, before any other node processes.
static func frame(map_id: String = "") -> void:
	if not enabled: return
	var at: int = Time.get_ticks_usec()
	if _last_frame > 0:
		_frames += 1
		var total: int = at - _last_frame
		if total >= THRESHOLD_USEC: _record(total, map_id)
	_last_frame = at
	_sections.clear()
	if _dirty and at - _last_flush >= FLUSH_USEC: flush()

static func _record(total: int, map_id: String) -> void:
	_hitches += 1
	var parts: Array = []
	var known: int = 0
	for key: String in _sections:
		var value: int = int(_sections[key])
		known += value
		if value >= 1000: parts.append([key, value / 1000])
	parts.append(["other", maxi(0, total - known) / 1000])
	parts.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var entry: Dictionary = {"ms":total / 1000, "sections":parts.slice(0, 6), "map":map_id,
		"at_s":int(Time.get_ticks_msec() / 1000), "frame":_frames}
	print(PREFIX + JSON.stringify(entry))
	var index: int = _worst.size()
	while index > 0 and int(_worst[index - 1].ms) < int(entry.ms): index -= 1
	if index < KEEP:
		_worst.insert(index, entry)
		if _worst.size() > KEEP: _worst.resize(KEEP)
	_dirty = true

static func summary() -> Dictionary:
	return {"schema":1, "frames":_frames, "hitches":_hitches, "threshold_ms":THRESHOLD_USEC / 1000,
		"worst":_worst.duplicate(true)}

static func flush() -> void:
	_last_flush = Time.get_ticks_usec()
	_dirty = false
	var path: String = _dir.path_join(FILE_NAME)
	var temporary: String = path + ".part"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(summary()))
	file.close()
	DirAccess.rename_absolute(temporary, path)

## Once per process start: keep the previous run's record for the loading screen.
static func start() -> void:
	if _started: return
	_started = true
	var path: String = _dir.path_join(FILE_NAME)
	if not FileAccess.file_exists(path): return
	var previous: String = _dir.path_join(PREV_NAME)
	DirAccess.remove_absolute(previous)
	DirAccess.rename_absolute(path, previous)
	_previous = read_previous()

static func read_previous() -> Dictionary:
	var path: String = _dir.path_join(PREV_NAME)
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 65536: return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary and value.get("schema") == 1 else {}

## One line for the loading screen, or "" when the last run had no hitch.
static func previous_line() -> String:
	var value: Dictionary = _previous if not _previous.is_empty() else read_previous()
	var worst: Array = value.get("worst", []) if value.get("worst") is Array else []
	if worst.is_empty() or not worst[0] is Dictionary: return ""
	var top: Dictionary = worst[0]
	var names: PackedStringArray = PackedStringArray()
	for part: Variant in top.get("sections", []):
		if part is Array and part.size() == 2 and int(part[1]) > 0 and names.size() < 3:
			names.append("%s %dms" % [str(LABELS.get(str(part[0]), str(part[0]))), int(part[1])])
	return "지난 실행 끊김 %d회 · 최대 %dms (%s)" % [int(value.get("hitches", worst.size())), int(top.get("ms", 0)), ", ".join(names)]

static func reset_for_test(directory: String) -> void:
	_dir = directory
	_sections.clear()
	_frames = 0
	_hitches = 0
	_worst.clear()
	_last_frame = 0
	_dirty = false
	_last_flush = 0
	_nested = 0
	_started = false
	_previous = {}
	enabled = true

## Test hook: pretend the previous frame started `usec_ago` microseconds ago.
static func backdate_frame_for_test(usec_ago: int) -> void:
	_last_frame = Time.get_ticks_usec() - usec_ago
