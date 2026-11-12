extends SceneTree
## Standalone check of the frame hitch record (no Main, no original data).
##   godot --headless --path <repo> --script res://tests/frame_hitch_log_test.gd
const HITCH = preload("res://scripts/boot/frame_hitch_log.gd")
const DIR := "user://frame_hitch_test"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FRAME_HITCH_LOG_FAIL: " + label)

func _initialize() -> void:
	_run.call_deferred()

func _clean() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for name: String in [HITCH.FILE_NAME, HITCH.PREV_NAME, HITCH.FILE_NAME + ".part"]:
		DirAccess.remove_absolute(DIR.path_join(name))

func _section(name: String, usec: int) -> void:
	HITCH.add(name, HITCH.now() - usec)

func _run() -> void:
	_clean()
	HITCH.reset_for_test(DIR)
	HITCH.frame("aden_world")
	# A fast frame is not recorded.
	_section("quests", 5000)
	HITCH.backdate_frame_for_test(20000)
	HITCH.frame("aden_world")
	check(HITCH.summary().hitches == 0 and HITCH.summary().frames == 1, "a 20 ms frame is not a hitch")
	# A slow frame keeps its sections, largest first, plus the unexplained rest.
	_section("quests", 180000)
	_section("monsters", 40000)
	_section("monsters", 10000)
	_section("hud", 500)
	HITCH.detail("spawn.setup", HITCH.now() - 120000)
	HITCH.detail("spawn.setup", HITCH.now() - 30000)
	HITCH.count("sp2.disk_miss")
	HITCH.count("sp2.layer_validate", 8)
	HITCH.backdate_frame_for_test(300000)
	HITCH.frame("aden_world")
	var summary: Dictionary = HITCH.summary()
	check(summary.hitches == 1 and summary.worst.size() == 1, "a 300 ms frame is recorded")
	var worst: Dictionary = summary.worst[0]
	check(int(worst.ms) >= 300 and worst.map == "aden_world", "the frame time and map are kept")
	check(worst.sections[0] == ["quests", 180] and worst.sections.has(["monsters", 50]), "sections are summed and sorted")
	var detail: Array = worst.get("details", [])[0]
	check(detail[0] == "spawn.setup" and int(detail[1]) >= 150 and int(detail[1]) <= 155 and detail[2] == 2 and int(detail[3]) >= 120 and int(detail[3]) <= 125, "inclusive detail keeps total, calls and longest single call")
	check(worst.get("counters", {}) == {"sp2.disk_miss":1, "sp2.layer_validate":8}, "operation counts belong to the recorded frame")
	var ordered: bool = true
	for index: int in range(1, worst.sections.size()):
		if int(worst.sections[index - 1][1]) < int(worst.sections[index][1]): ordered = false
	check(ordered, "sections are listed slowest first")
	var other: int = -1
	for part: Array in worst.sections:
		check(part[0] != "hud", "sections under 1 ms are left out")
		if part[0] == "other": other = int(part[1])
	check(other >= 69 and other <= 75, "the unexplained remainder is reported as other")
	# Sections reset every frame.
	HITCH.backdate_frame_for_test(150000)
	HITCH.frame("aden_world")
	check(HITCH.summary().worst[1].sections[0][0] == "other", "a new frame starts with no sections")
	check(not HITCH.summary().worst[1].has("details") and not HITCH.summary().worst[1].has("counters"), "details and counts reset with sections every frame")
	# add_self excludes nested sections.
	var started: int = HITCH.now() - 100000
	var nested: int = HITCH.nested()
	_section("quests", 60000)
	HITCH.add_self("world", started, nested)
	HITCH.backdate_frame_for_test(200000)
	HITCH.frame("x")
	var nested_entry: Dictionary = {}
	for entry: Dictionary in HITCH.summary().worst:
		if entry.map == "x": nested_entry = entry
	var by_name: Dictionary = {}
	for part: Array in nested_entry.sections: by_name[part[0]] = int(part[1])
	check(by_name.get("quests") == 60 and by_name.get("world", 0) >= 39 and by_name.get("world", 0) <= 45, "world time excludes its nested sections")
	# Only the KEEP slowest frames are kept, slowest first.
	for index: int in 20:
		HITCH.backdate_frame_for_test(100000 + index * 10000)
		HITCH.frame("many")
	var kept: Array = HITCH.summary().worst
	check(kept.size() == HITCH.KEEP, "the record keeps KEEP frames")
	var sorted: bool = true
	for index: int in range(1, kept.size()):
		if int(kept[index - 1].ms) < int(kept[index].ms): sorted = false
	check(sorted and int(kept[0].ms) >= 300, "kept frames are slowest first")
	check(HITCH.summary().hitches == 23, "every hitch is counted")
	# Flush, then a new start moves the record to .prev for the loading screen.
	HITCH.flush()
	check(FileAccess.file_exists(DIR.path_join(HITCH.FILE_NAME)) and not FileAccess.file_exists(DIR.path_join(HITCH.FILE_NAME + ".part")), "flush writes the record atomically")
	HITCH.reset_for_test(DIR)
	HITCH.start()
	check(FileAccess.file_exists(DIR.path_join(HITCH.PREV_NAME)) and not FileAccess.file_exists(DIR.path_join(HITCH.FILE_NAME)), "start keeps the last run as .prev")
	var line: String = HITCH.previous_line()
	check(line.begins_with("지난 실행 끊김 23회 · 최대 "), "the loading line names count and worst frame: " + line)
	check(line.contains("퀘스트 180ms") and line.contains("몬스터 50ms"), "the loading line names the slowest sections in Korean")
	HITCH.start()
	check(FileAccess.file_exists(DIR.path_join(HITCH.PREV_NAME)), "a second start in the same run keeps .prev")
	# No previous record: no line.
	_clean()
	HITCH.reset_for_test(DIR)
	HITCH.start()
	check(HITCH.previous_line().is_empty(), "no record, no loading line")
	# Disabled: nothing is measured.
	HITCH.enabled = false
	_section("quests", 500000)
	HITCH.detail("disabled", HITCH.now() - 500000)
	HITCH.count("disabled")
	HITCH.frame("off")
	check(HITCH.summary().hitches == 0, "disabled records nothing")
	HITCH.enabled = true
	HITCH.frame("enabled")
	HITCH.backdate_frame_for_test(200000)
	HITCH.frame("enabled")
	check(not HITCH.summary().worst[0].has("details") and not HITCH.summary().worst[0].has("counters"), "disabled detail/count calls leave no pending data")
	_clean()
	print("FRAME_HITCH_LOG_RESULT " + JSON.stringify({"checks":checks, "failures":failures}))
	quit(0 if failures.is_empty() else 1)
