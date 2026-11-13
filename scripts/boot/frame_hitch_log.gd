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
	"hud_main":"원작 HUD", "npcs":"NPC",
	"other":"그리기·엔진",
}

static var _dir: String = "user://"
static var _sections: Dictionary = {}
## Inclusive sub-operation timings, separate from the exclusive section totals.
## Each row keeps [total usec, calls, longest call usec] for this frame only.
static var _details: Dictionary = {}
static var _counters: Dictionary = {}
static var _slow_spawn: Dictionary = {}
static var _build: Dictionary = {}
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

## Diagnose a single long spawn/cache miss without double-counting its parent.
static func detail(operation: String, started_usec: int) -> void:
	if not enabled: return
	var elapsed: int = maxi(0, Time.get_ticks_usec() - started_usec)
	if not _details.has(operation): _details[operation] = [0, 0, 0]
	var row: Array = _details[operation]
	row[0] += elapsed
	row[1] += 1
	row[2] = maxi(int(row[2]), elapsed)

static func count(operation: String, amount: int = 1) -> void:
	if not enabled: return
	_counters[operation] = int(_counters.get(operation, 0)) + amount

## One bounded, scalar-only setup sample, not a copy of an actor/source record.
static func slow_spawn(sample: Dictionary) -> void:
	if not enabled or int(sample.get("usec",0)) < THRESHOLD_USEC: return
	if int(sample.usec) > int(_slow_spawn.get("usec",0)):
		_slow_spawn = sample.duplicate(true)

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
	_details.clear()
	_counters.clear()
	_slow_spawn = {}
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
	var details: Array = []
	for operation: String in _details:
		var row: Array = _details[operation]
		if int(row[0]) >= 1000:
			details.append([operation, int(row[0]) / 1000, int(row[1]), int(row[2]) / 1000])
	details.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	if not details.is_empty(): entry["details"] = details
	if not _counters.is_empty(): entry["counters"] = _counters.duplicate()
	if not _slow_spawn.is_empty(): entry["slow_spawn"] = _slow_spawn.duplicate(true)
	print(PREFIX + JSON.stringify(entry))
	var index: int = _worst.size()
	while index > 0 and int(_worst[index - 1].ms) < int(entry.ms): index -= 1
	if index < KEEP:
		_worst.insert(index, entry)
		if _worst.size() > KEEP: _worst.resize(KEEP)
	_dirty = true

static func summary() -> Dictionary:
	return {"schema":1, "build":_build.duplicate(), "frames":_frames, "hitches":_hitches, "threshold_ms":THRESHOLD_USEC / 1000,
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
	# Mounted update-pack identity at probe startup, not the next launch's label.
	var info := FileAccess.open("res://build_info.json",FileAccess.READ)
	if info != null and info.get_length() <= 4096:
		var identity: Variant = JSON.parse_string(info.get_as_text())
		if identity is Dictionary:
			for key: String in ["version_name","commit"]:
				if identity.get(key) is String: _build[key] = str(identity[key]).left(80)
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
	var line: String = "지난 실행 끊김 %d회 · 최대 %dms (%s)" % [int(value.get("hitches", worst.size())), int(top.get("ms", 0)), ", ".join(names)]
	# The slowest frame's operation details ([name, total ms, count, max ms]),
	# so a photo of the loading screen names what inside a section stalled.
	var details: PackedStringArray = PackedStringArray()
	for part: Variant in top.get("details", []):
		if part is Array and part.size() >= 3 and int(part[1]) > 0 and details.size() < 3:
			details.append("%s %dms×%d" % [str(part[0]), int(part[1]), int(part[2])])
	if not details.is_empty(): line += " · 세부 " + ", ".join(details)
	var spawn: Variant = top.get("slow_spawn",{})
	if spawn is Dictionary and spawn.get("phases_usec") is Dictionary:
		var phases: Array = []
		for key: String in spawn.phases_usec: phases.append([key,int(spawn.phases_usec[key])])
		phases.sort_custom(func(a: Array,b: Array) -> bool: return int(a[1]) > int(b[1]))
		var labels: PackedStringArray = []
		for part: Array in phases.slice(0,2): labels.append("%s %dms" % [part[0],int(part[1])/1000])
		line += " · 단일 NPC %d setup %s" % [int(spawn.get("npc",-1)),", ".join(labels)]
	return line

static func reset_for_test(directory: String) -> void:
	_dir = directory
	_sections.clear()
	_details.clear()
	_counters.clear()
	_slow_spawn = {}
	_build = {}
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
