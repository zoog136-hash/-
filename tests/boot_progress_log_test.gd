extends SceneTree
## Standalone check of the boot progress record (no Main, no original data).
## Uses its own directory under user:// (default user://zz_boot_progress_probe)
## and a probe bake name, both removed afterwards. Run:
##   godot --headless --path <repo> --script res://tests/boot_progress_log_test.gd
const LOG = preload("res://scripts/boot/boot_progress_log.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
const DIR := "user://zz_boot_progress_probe"
const PROBE := "zz_boot_progress_probe"
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func lines(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path): return PackedStringArray()
	return FileAccess.get_file_as_string(path).split("\n", false)

func field(line: String, key: String) -> String:
	for part: String in line.split(" ", false):
		if part.begins_with(key + "="): return part.trim_prefix(key + "=")
	return ""

func last_with(path: String, needle: String) -> String:
	var found: String = ""
	for line: String in lines(path):
		if line.contains(needle): found = line
	return found

func wipe(directory: String) -> void:
	if not DirAccess.dir_exists_absolute(directory): return
	for name: String in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)

func _init() -> void:
	wipe(DIR)
	DirAccess.make_dir_recursive_absolute(DIR)
	var current: String = DIR.path_join(LOG.FILE_NAME)
	var previous: String = DIR.path_join(LOG.PREV_NAME)
	var over: String = DIR.path_join(LOG.OVER_NAME)

	# --- run 1: format, nesting, flush while the writer is still open ---------
	LOG.reset_for_test(DIR)
	var outer: int = LOG.begin("stage_a", {"table": "Item Class:1"})
	var inner: int = LOG.begin("stage_b")
	check(LOG.current_stage() == "stage_b", "innermost stage is current")
	LOG.end("stage_b", inner, {"rows": 12})
	check(LOG.current_stage() == "stage_a", "end pops the named stage")
	# The file is still open by the recorder: another reader sees every line
	# (flushed per line), which is what survives an abrupt kill.
	var run1: PackedStringArray = lines(current)
	check(run1.size() == 3, "each event is one flushed line (%d)" % run1.size())
	var first: String = run1[0] if run1.size() > 0 else ""
	check(field(first, "ev") == "begin" and field(first, "stage") == "stage_a" and field(first, "cur") == "stage_a", "begin line names stage and current stage")
	check(field(first, "table") == "Item_Class.1", "values lose spaces and colons")
	check(not first.contains("ERROR:"), "line cannot carry the CI error pattern")
	check(field(first, "static_kb") != "" and field(first, "physical_kb") != "" and field(first, "objects") != "", "memory fields at each boundary")
	if OS.get_name() in ["Linux", "Android"]: check(field(first, "vmrss_kb").is_valid_int() and field(first, "vmhwm_kb").is_valid_int(), "VmRSS/VmHWM from /proc/self/status")
	var ended: String = run1[2] if run1.size() > 2 else ""
	check(field(ended, "ev") == "end" and field(ended, "ms").is_valid_int() and field(ended, "rows") == "12" and field(ended, "cur") == "stage_a", "end line has elapsed ms and fields")
	check(int(field(run1[2] if run1.size() > 2 else "", "seq")) == 3, "sequence numbers increase")
	LOG.begin("stage_c")
	LOG.mark("alive", {"map": "aden_world"})
	LOG.mark("touch", {"at": "SkillButton"})
	# Run 1 "dies" inside stage_c (no end, no close by the game).

	# --- run 2: rotation keeps the previous run and its unfinished stage ------
	LOG.reset_for_test(DIR)
	check(LOG.previous_unfinished() == "stage_c", "previous run's open stage is reported (%s)" % LOG.previous_unfinished())
	check(lines(previous).size() == 6 and field(lines(previous)[3], "stage") == "stage_c", "previous run moved to prev file intact")
	var last: Dictionary = LOG.previous_last_fields()
	check(last.get("ev") == "touch" and last.get("at") == "SkillButton", "the previous run's last record is the last touch")
	var end_line: String = LOG.previous_end_line()
	check(end_line.begins_with("지난 실행 마지막 기록 ") and end_line.contains("터치 SkillButton"), "the loading line names the last action: " + end_line)
	if OS.get_name() in ["Linux", "Android"]: check(end_line.contains("앱 메모리 ") and end_line.contains("MB(최대 "), "the loading line names app memory: " + end_line)
	check(end_line.contains("기기 여유 "), "the loading line names free device memory")
	var engine_only: String = "run=x seq=1 t=9000 ev=alive stage=- map=m cur=- static_kb=204800 static_max_kb=307200 available_kb=-1"
	FileAccess.open(previous, FileAccess.WRITE).store_line(engine_only)
	check(LOG.previous_end_line() == "지난 실행 마지막 기록 9초: 게임 중(m) · 엔진 메모리 200MB(최대 300MB)", "without /proc values the engine memory is shown: " + LOG.previous_end_line())
	var with_breakdown := FileAccess.open(previous, FileAccess.WRITE)
	with_breakdown.store_line("run=x seq=1 t=5000 ev=alive stage=- map=m sp2_parsed_mb=310 sp2_parsed_n=42 sp2_texture_mb=120 sp2_texture_n=40 nodes=900 resources=5000 tables=60 cur=- static_kb=1024000 static_max_kb=1200000 tex_kb=204800 available_kb=-1")
	with_breakdown.store_line("run=x seq=2 t=7000 ev=touch stage=- at=world cur=- static_kb=1048576 static_max_kb=1200000 available_kb=-1")
	with_breakdown.close()
	var broken_down: String = LOG.previous_end_line()
	check(broken_down.begins_with("지난 실행 마지막 기록 7초: 터치 world · 엔진 메모리 1024MB"), "the last line is still the last touch: " + broken_down)
	check(broken_down.contains("몬스터 그림 해석 310MB(42) · 그림 텍스처 120MB(40) · GPU 텍스처 200MB · 노드 900 · 리소스 5000 · 원본 표 60"), "the latest heartbeat names what holds memory: " + broken_down)
	var with_world := FileAccess.open(previous, FileAccess.WRITE)
	with_world.store_line("run=x seq=1 t=5000 ev=alive stage=- map=m sp2_parsed_mb=1 sp2_parsed_n=2 sp2_texture_mb=3 sp2_texture_n=4 nodes=5 resources=6 tables=7 objects=8000 actors=40 r_raw_chunks=9 r_frame_commands=10 r_frame_atlases=11 r_static_tails=12 cur=- static_kb=1024 available_kb=-1")
	with_world.close()
	check(LOG.previous_end_line().ends_with("· 객체 8000 · 몬스터 40 · 지도 조각 9/명령 10/아틀라스 11/정적 12"), "the heartbeat names objects, actors and map renderer caches: " + LOG.previous_end_line())
	LOG.mark("boot_done")
	check(lines(current).size() == 1, "new run starts a new file")

	# --- run 3: only one previous run is kept --------------------------------
	LOG.reset_for_test(DIR)
	check(LOG.previous_unfinished() == "", "finished previous run reports no open stage")
	check(LOG.previous_end_line().contains("완료 ") or LOG.previous_end_line().contains("boot_done"), "a finished previous run still names its last record")
	var kept: PackedStringArray = lines(previous)
	check(kept.size() == 1 and field(kept[0], "ev") == "boot_done", "prev holds only the last run")

	# --- cap: files stay under the cap, latest line always in current ---------
	LOG.reset_for_test(DIR, 2048)
	for index: int in 60: LOG.mark("filler", {"n": index})
	var size_current: int = FileAccess.get_file_as_bytes(current).size()
	var size_over: int = FileAccess.get_file_as_bytes(over).size()
	check(size_current > 0 and size_current <= 2048, "current file under cap (%d)" % size_current)
	check(size_over > 0 and size_over <= 2048, "earlier part kept once under cap (%d)" % size_over)
	check(field(last_with(current, "ev=filler"), "n") == "59", "latest line is in current file")
	LOG.reset_for_test(DIR)
	LOG.mark("after_cap")
	check(not FileAccess.file_exists(over), "new run drops the over file")

	# --- progress: coarse rows only ---------------------------------------------
	for row: int in 12001: LOG.progress("big_loop", row)
	var counted: int = 0
	for line: String in lines(current): if field(line, "ev") == "rows": counted += 1
	check(counted == 12000 / LOG.ROW_STEP, "row counter logs every ROW_STEP rows (%d)" % counted)

	# --- reason vocabulary ----------------------------------------------------
	for reason: String in LOG.REASONS: check(LOG.normalize_reason(reason) == reason, "reason kept: " + reason)
	check(LOG.normalize_reason("weird reason") == "other", "unknown reason becomes other")
	for reason: String in ["missing", "no_key", "key_changed", "schema_changed", "corrupt", "verify_fail", "write_fail"]: check(reason in LOG.REASONS, "vocabulary has " + reason)
	LOG.cache("probe", "hit")
	check(field(last_with(current, "ev=cache"), "result") == "hit", "hit result")
	LOG.cache("probe", "key_changed")
	var miss: String = last_with(current, "ev=cache")
	check(field(miss, "result") == "miss" and field(miss, "reason") == "key_changed", "miss result with reason")

	# --- real bake cache lookups log their reasons ----------------------------
	BAKE.clear(PROBE)
	check(BAKE.read(PROBE, "") == null and field(last_with(current, "stage=" + PROBE), "reason") == "no_key", "bake no_key")
	check(BAKE.read(PROBE, "k1") == null and field(last_with(current, "stage=" + PROBE), "reason") == "missing", "bake missing")
	check(BAKE.write(PROBE, "k1", {"v": 1}), "probe bake written")
	var write_line: String = last_with(current, "stage=" + PROBE)
	check(field(write_line, "ev") == "io" and field(write_line, "op") == "write" and field(write_line, "reason") == "ok", "bake write ok logged")
	check(BAKE.read(PROBE, "k1") is Dictionary and field(last_with(current, "stage=" + PROBE), "reason") == "hit", "bake hit")
	check(BAKE.read(PROBE, "k2") == null and field(last_with(current, "stage=" + PROBE), "reason") == "key_changed", "bake key_changed")
	var meta_path: String = BAKE.ROOT + "/" + PROBE + ".json"
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	var schema_meta: Dictionary = meta.duplicate()
	schema_meta["schema"] = "old.schema"
	var meta_file := FileAccess.open(meta_path, FileAccess.WRITE)
	meta_file.store_string(JSON.stringify(schema_meta))
	meta_file.close()
	check(BAKE.read(PROBE, "k1") == null and field(last_with(current, "stage=" + PROBE), "reason") == "schema_changed", "bake schema_changed")
	meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
	meta_file.store_string("[1]")
	meta_file.close()
	check(BAKE.read(PROBE, "k1") == null and field(last_with(current, "stage=" + PROBE), "reason") == "corrupt", "bake corrupt meta")
	meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
	meta_file.store_string(JSON.stringify(meta))
	meta_file.close()
	var data_file := FileAccess.open(BAKE.data_path(PROBE), FileAccess.READ_WRITE)
	data_file.seek(0)
	data_file.store_8(255)
	data_file.close()
	check(BAKE.read(PROBE, "k1") == null and field(last_with(current, "stage=" + PROBE), "reason") == "verify_fail", "bake verify_fail")
	check(BAKE.verified_file(PROBE, "k1") == "" and field(last_with(current, "stage=" + PROBE), "reason") == "verify_fail", "file bake verify_fail")
	BAKE.clear(PROBE)
	if DirAccess.dir_exists_absolute(BAKE.ROOT) and DirAccess.get_files_at(BAKE.ROOT).is_empty() and DirAccess.get_directories_at(BAKE.ROOT).is_empty(): DirAccess.remove_absolute(BAKE.ROOT)

	# --- a file that cannot be opened never stops callers ----------------------
	LOG.reset_for_test(DIR.path_join("missing_dir/deeper"))
	var started: int = LOG.begin("no_file_stage")
	LOG.cache("probe", "missing")
	LOG.io("probe", "write", "write_fail")
	LOG.progress("no_file_stage", LOG.ROW_STEP)
	LOG.end("no_file_stage", started)
	check(LOG.current_stage() == "" and started > 0, "recorder keeps working without a file")
	check(not DirAccess.dir_exists_absolute(DIR.path_join("missing_dir")), "no directory is created for the record")

	LOG.reset_for_test("user://")
	wipe(DIR)
	print("BOOT_PROGRESS_LOG_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
