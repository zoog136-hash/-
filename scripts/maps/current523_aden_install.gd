extends Node
## Fixed reviewed archive only. No game state, save or preference writes.
signal progress(stage: String, done: int, total: int)
signal finished(result: Dictionary)

const ARCHIVE_SHA256: String = "f926e1513c552b60ed5deb6c9b1fddf18a6e59ab4e916575b9dc88206b05f952"
const ARCHIVE_BYTES: int = 399316785
const FILE_COUNT: int = 6412
const PAYLOAD_BYTES: int = 452418162
const RAW_MANIFEST_SHA256: String = "2ae38fe09eba75653e4db476b70a9e3168cba18d8051cf302b177a1a7634e90a"
const TILE_MANIFEST_SHA256: String = "bcef2835c28acf1ec61af8ba9ef29753b693952e695beedcb1bce4f4c9ec3989"
const README_SHA256: String = "10caa6ba2a1d7ff4dfd7065d6a6341514ea58153de02addf032bebffdff230de"
const RAW_MANIFEST: String = "aden523-raw/aden523.json"
const TILE_MANIFEST: String = "aden523-tiles/tiles523.json"
const MAX_ENTRY: int = 16 * 1024 * 1024
const HASH_CHUNK: int = 256 * 1024
const FRAME_BUDGET_USEC: int = 4000

var busy: bool = false
var problem: String = ""
var last_result: Dictionary = {}
# Only these handoff fields are shared; every access is protected by _mutex.
var _mutex: Mutex = Mutex.new()
var _thread: Thread
var _cancel_requested: bool = false
var _pending_progress: Dictionary = {}
var _pending_result: Dictionary = {}
var _progress_revision: int = 0
var _emitted_revision: int = 0
var _generation: int = 0  # Main-thread callback reentrancy guard.
# The remaining state and all file handles belong exclusively to the worker.
var _worker_done: bool = false
var _worker_outcome: Dictionary = {}
var _worker_stage: String = ""
var _operation_id: String = ""
var _phase_times: Dictionary = {}
var _phase_steps: Dictionary = {}
var _timed_phase: String = ""
var _phase_started: int = 0
var _phase: String = ""
var _archive_path: String = ""
var _store: String = ""
var _final: String = ""
var _stage: String = ""
var _hash_file: FileAccess
var _hash: HashingContext
var _hashed: int = 0
var _archive_stamp: int = 0
var _zip: ZIPReader
var _raw: Dictionary = {}
var _tiles: Dictionary = {}
var _archive_names: PackedStringArray
var _archive_seen: Dictionary = {}
var _expected: Dictionary = {}
var _expected_dirs: Dictionary = {"": true}
var _names: Array[String] = []
var _index: int = 0
var _planned_bytes: int = 0
var _written: Array[String] = []
var _created_dirs: Array[String] = []
var _verify_root: String = ""
var _verify_file: FileAccess
var _verify_hash: HashingContext
var _verify_bytes: int = 0
var _reused: bool = false
var _scan_queue: Array[String] = []
var _scan_dir: DirAccess
var _scan_relative: String = ""
var _scan_seen: Dictionary = {}
var _scan_count: int = 0
var _cleanup_file: int = -1
var _cleanup_dir: int = -1
var _cleanup_problem: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


static func safe_relative(path: String) -> bool:
	if path.is_empty() or path.length() > 240 or path.contains("\\") or path.contains(":") or path.to_utf8_buffer().has(0) or path.begins_with("/"):
		return false
	for part: String in path.split("/", true):
		if part in ["", ".", ".."]:
			return false
	return true


static func _has_link(path: String) -> bool:
	var current: String = path
	for _depth: int in range(128):
		var parent: String = current.get_base_dir()
		if parent.is_empty() or parent == current:
			return false
		var directory := DirAccess.open(parent)
		if directory != null and directory.is_link(current.get_file()):
			return true
		current = parent
	return true


static func _normalized_store_root(path: String) -> String:
	if path.is_empty() or path.length() > 1024 or path.contains("\\") or path.to_utf8_buffer().has(0) or path.begins_with("res://"):
		return ""
	var relative: String = path.trim_prefix("user://") if path.begins_with("user://") else path
	if ".." in relative.split("/", true) or "." in relative.split("/", true):
		return ""
	if not path.begins_with("user://") and not path.is_absolute_path():
		return ""
	var root: String = ProjectSettings.globalize_path("user://").simplify_path().trim_suffix("/")
	var absolute: String = ProjectSettings.globalize_path(path).simplify_path().trim_suffix("/")
	if not absolute.begins_with(root + "/") or not safe_relative(absolute.trim_prefix(root + "/")):
		return ""
	return absolute


static func safe_store_root(path: String) -> String:
	var absolute: String = _normalized_store_root(path)
	if absolute.is_empty() or _has_link(absolute):
		return ""
	if FileAccess.file_exists(absolute) and not DirAccess.dir_exists_absolute(absolute):
		return ""
	return absolute


func start(zip_path: String, store_root: String = "user://current523_aden_resources") -> bool:
	if busy:
		problem = "원본 팩 설치가 이미 진행 중입니다."
		return false
	problem = ""
	last_result = {}
	if not is_inside_tree() or is_queued_for_deletion():
		return _reject_start("설치기를 게임에 연결한 뒤 다시 시도해 주세요.")
	var requested_store: String = _normalized_store_root(store_root)
	if requested_store.is_empty():
		return _reject_start("안전한 전용 사용자 설치 폴더가 아닙니다.")
	if zip_path.is_empty() or zip_path.to_utf8_buffer().has(0) or (not zip_path.is_absolute_path() and not zip_path.begins_with("user://") and not zip_path.begins_with("res://")):
		return _reject_start("설치 ZIP 경로가 유효하지 않습니다.")
	var request: Dictionary = {"archive": ProjectSettings.globalize_path(zip_path).simplify_path(),
		"store": requested_store, "id": str(Time.get_ticks_usec()) + "-" + str(get_instance_id())}
	_mutex.lock()
	_cancel_requested = false
	_pending_progress.clear(); _pending_result.clear(); _progress_revision = 0
	_mutex.unlock()
	_emitted_revision = 0
	_generation += 1
	var operation: int = _generation
	_thread = Thread.new()
	busy = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	progress.emit("archive_sha256", 0, ARCHIVE_BYTES)
	# A synchronous callback may cancel, queue-free or detach this node.
	if operation != _generation:
		return false
	if not busy or not is_inside_tree() or is_queued_for_deletion():
		if busy:
			_thread = null
			_accept_result({"ok": false, "problem": "설치기가 닫혀 설치를 중단했습니다.", "cancelled": true,
				"written_files": 0, "stage_root": "", "cleanup_complete": true, "previous_packs_preserved": true}, false)
		return false
	if _is_cancel_requested():
		_thread = null
		_accept_result({"ok": false, "problem": "설치를 중단했습니다. 기존 팩은 유지됩니다.",
			"cancelled": true, "written_files": 0, "stage_root": "", "cleanup_complete": true,
			"previous_packs_preserved": true}, true)
		return true
	if _thread.start(_worker_run.bind(request)) != OK:
		_thread = null
		busy = false
		set_process(false)
		return _reject_start("백그라운드 설치 작업을 시작하지 못했습니다.")
	return true


func cancel() -> void:
	if busy:
		_mutex.lock()
		_cancel_requested = true
		_mutex.unlock()


func _reject_start(message: String) -> bool:
	problem = message
	last_result = {"ok": false, "problem": message, "cancelled": false, "previous_packs_preserved": true}
	return false


func _process(_delta: float) -> void:
	var operation: int = _generation
	_mutex.lock()
	var report: Dictionary = _pending_progress.duplicate(true)
	var result: Dictionary = _pending_result.duplicate(true)
	var revision: int = _progress_revision
	_mutex.unlock()
	if revision != _emitted_revision and not report.is_empty():
		_emitted_revision = revision
		progress.emit(str(report.stage), int(report.done), int(report.total))
		if operation != _generation or not busy or not is_inside_tree() or is_queued_for_deletion():
			return
	if not result.is_empty():
		if _thread != null and _thread.is_started():
			_thread.wait_to_finish()
		_thread = null
		_accept_result(result, true)
	elif _thread != null and _thread.is_started() and not _thread.is_alive():
		_thread.wait_to_finish(); _thread = null
		_mutex.lock()
		result = _pending_result.duplicate(true)
		_mutex.unlock()
		if result.is_empty():
			result = _joined_failure_result("설치 작업이 결과를 남기지 못했습니다.", false)
		_accept_result(result, true)


func _is_cancel_requested() -> bool:
	_mutex.lock()
	var requested: bool = _cancel_requested
	_mutex.unlock()
	return requested


func _report_progress(stage: String, done: int, total: int) -> void:
	_mutex.lock()
	_pending_progress = {"stage": stage, "done": done, "total": total}
	_progress_revision += 1
	_mutex.unlock()


func _worker_run(request: Dictionary) -> void:
	_worker_done = false; _worker_outcome = {}; _worker_stage = ""
	_archive_path = str(request.archive); _store = str(request.store); _operation_id = str(request.id)
	_expected.clear(); _expected_dirs = {"": true}; _names.clear()
	_written.clear(); _created_dirs.clear(); _scan_seen.clear(); _scan_queue.clear()
	_raw.clear(); _tiles.clear(); _archive_names.clear(); _archive_seen.clear()
	_hashed = 0; _index = 0; _planned_bytes = 0; _stage = ""
	_cleanup_problem = ""; _reused = false
	_phase_times = {}; _phase_steps = {}; _timed_phase = ""; _phase_started = Time.get_ticks_usec()
	_final = _store.path_join("523-" + ARCHIVE_SHA256)
	if safe_store_root(_store) != _store:
		_fail("안전한 전용 사용자 설치 폴더가 아닙니다.")
		return
	if _has_link(_archive_path):
		_fail("링크된 설치 ZIP은 사용할 수 없습니다.")
		return
	_hash_file = FileAccess.open(_archive_path, FileAccess.READ)
	if _hash_file == null:
		_fail("설치 ZIP을 읽지 못했습니다.")
		return
	if _hash_file.get_length() != ARCHIVE_BYTES:
		_fail("이 버전의 아덴 원본 ZIP과 크기가 다릅니다.")
		return
	_archive_stamp = FileAccess.get_modified_time(_archive_path)
	_hash = HashingContext.new()
	if _hash.start(HashingContext.HASH_SHA256) != OK:
		_fail("원본 ZIP 검사를 시작하지 못했습니다.")
		return
	_phase = "archive_sha256"
	var began: int = Time.get_ticks_usec()
	while not _worker_done:
		if _is_cancel_requested() and _phase != "cleanup":
			_fail("설치를 중단했습니다. 기존 팩은 유지됩니다.", true)
			if _worker_done:
				break
		if _timed_phase != _phase:
			_record_phase_time()
			_timed_phase = _phase
			_phase_started = Time.get_ticks_usec()
		_phase_steps[_phase] = int(_phase_steps.get(_phase, 0)) + 1
		match _phase:
			"archive_sha256": _hash_archive_step()
			"open_archive": _open_archive()
			"manifest_raw": _read_manifest(false)
			"manifest_tiles": _read_manifest(true)
			"plan_raw": _plan_raw_step()
			"plan_tiles": _plan_tile_step()
			"archive_inventory": _archive_inventory_step()
			"prepare": _prepare_destination()
			"scan_existing": _scan_existing_step()
			"extract": _extract_step()
			"verify", "reuse_verify": _verify_step()
			"publish": _publish()
			"cleanup": _cleanup_step()
			_: _fail("알 수 없는 설치 단계입니다.")
		if Time.get_ticks_usec() - began >= FRAME_BUDGET_USEC:
			OS.delay_msec(1)
			began = Time.get_ticks_usec()


func _record_phase_time() -> void:
	if not _timed_phase.is_empty():
		_phase_times[_timed_phase] = float(_phase_times.get(_timed_phase, 0.0)) + float(Time.get_ticks_usec() - _phase_started) / 1000.0


func _hash_archive_step() -> void:
	var count: int = mini(HASH_CHUNK, ARCHIVE_BYTES - _hashed)
	var bytes: PackedByteArray = _hash_file.get_buffer(count)
	if bytes.size() != count or _hash.update(bytes) != OK:
		_fail("원본 ZIP을 검사하는 중 읽기 오류가 발생했습니다.")
		return
	_hashed += bytes.size()
	_report_progress("archive_sha256", _hashed, ARCHIVE_BYTES)
	if _hashed == ARCHIVE_BYTES:
		var digest: String = _hash.finish().hex_encode()
		_hash = null
		if digest != ARCHIVE_SHA256:
			_fail("검증된 현행523 아덴 원본 ZIP과 SHA256이 다릅니다.")
			return
		_phase = "open_archive"


func _open_archive() -> void:
	if _has_link(_archive_path) or _hash_file.get_length() != ARCHIVE_BYTES or FileAccess.get_modified_time(_archive_path) != _archive_stamp:
		_fail("검사 중 설치 ZIP이 변경되었습니다.")
		return
	_zip = ZIPReader.new()
	if _zip.open(_archive_path) != OK:
		_fail("검증된 ZIP을 열지 못했습니다.")
		return
	_hash_file.close(); _hash_file = null
	_archive_names = _zip.get_files()
	if _archive_names.size() != FILE_COUNT:
		_fail("아덴 원본 ZIP의 파일 수가 다릅니다.")
		return
	if not _add_expected("README.txt", 640, README_SHA256):
		return
	_phase = "manifest_raw"
	_report_progress("manifest_validation", 0, 2)


func _read_manifest(tiles: bool) -> void:
	var relative: String = TILE_MANIFEST if tiles else RAW_MANIFEST
	var size: int = 5113969 if tiles else 1392476
	var digest: String = TILE_MANIFEST_SHA256 if tiles else RAW_MANIFEST_SHA256
	var bytes: PackedByteArray = _zip.read_file(relative)
	if bytes.size() != size or _sha(bytes) != digest:
		_fail("아덴 원본 팩 선언의 크기 또는 해시가 다릅니다.")
		return
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	var rows: Variant = parsed.get("tiles" if tiles else "members") if parsed is Dictionary else null
	if not parsed is Dictionary or parsed.get("schema") != 1 or parsed.get("edition") != "LineageM" or parsed.get("cumulative_version") != 523 or parsed.get("land_id") != 4 or parsed.get("asset_path") != "Aden/" or not rows is Array or rows.size() != (2866 if tiles else 677):
		_fail("현행523 아덴 선언이 아닙니다.")
		return
	if not _add_expected(relative, size, digest):
		return
	if tiles:
		_tiles = parsed
		_index = 0
		_phase = "plan_raw"
	else:
		_raw = parsed
		_phase = "manifest_tiles"
	_report_progress("manifest_validation", 2 if tiles else 1, 2)


func _add_expected(relative: String, size: Variant, digest: Variant) -> bool:
	if not safe_relative(relative) or _expected.has(relative) or not _uint(size, MAX_ENTRY) or int(size) <= 0 or not _valid_sha(digest):
		_fail("설치 파일 경로·크기·해시 목록이 유효하지 않습니다.")
		return false
	_expected[relative] = {"bytes": int(size), "sha256": digest}
	_planned_bytes += int(size)
	var directory: String = relative.get_base_dir()
	while not directory.is_empty():
		_expected_dirs[directory] = true
		directory = directory.get_base_dir()
	return true


func _plan_raw_step() -> void:
	var value: Variant = _raw.members[_index]
	if not value is Dictionary or not value.get("member") is String or value.get("path") != "originals/" + str(value.member) or value.get("source_path") != value.member:
		_fail("S32 원문 경로 선언이 다릅니다.")
		return
	if not _add_expected("aden523-raw/" + str(value.path), value.get("bytes"), value.get("sha256")):
		return
	_index += 1
	if _index == 677:
		_index = 0
		_phase = "plan_tiles"


func _plan_tile_step() -> void:
	var value: Variant = _tiles.tiles[_index]
	if not value is Dictionary or not _uint(value.get("tile_id"), 16777215):
		_fail("TI2 원문 번호 선언이 다릅니다.")
		return
	var member: String = "Tile/" + str(int(value.tile_id)) + ".ti2"
	if value.get("member") != member or value.get("original_path") != "originals/" + member or value.get("atlas_path") != "atlases/" + str(int(value.tile_id)) + ".png":
		_fail("TI2·PNG 경로 선언이 다릅니다.")
		return
	if not _add_expected("aden523-tiles/" + str(value.original_path), value.get("source_bytes"), value.get("source_sha256")) or not _add_expected("aden523-tiles/" + str(value.atlas_path), value.get("atlas_bytes"), value.get("atlas_sha256")):
		return
	_index += 1
	if _index == 2866:
		if _expected.size() != FILE_COUNT or _planned_bytes != PAYLOAD_BYTES:
			_fail("선언된 전체 파일 수 또는 설치 용량이 다릅니다.")
			return
		_raw.clear(); _tiles.clear()
		_index = 0
		_phase = "archive_inventory"


func _archive_inventory_step() -> void:
	var relative: String = _archive_names[_index]
	if not safe_relative(relative) or not _expected.has(relative) or _archive_seen.has(relative):
		_fail("ZIP 안에 선언되지 않았거나 중복된 경로가 있습니다.")
		return
	_names.append(relative)
	_archive_seen[relative] = true
	_index += 1
	if _index == FILE_COUNT:
		_index = 0
		_phase = "prepare"
		_report_progress("inventory", FILE_COUNT, FILE_COUNT)


func _prepare_destination() -> void:
	if safe_store_root(_store) != _store:
		_fail("설치 폴더가 검사 중 변경되었습니다.")
		return
	if DirAccess.dir_exists_absolute(_final):
		if _has_link(_final):
			_fail("기존 버전 폴더가 링크되어 있습니다.")
			return
		_reused = true
		_verify_root = _final
		_scan_queue = [""]
		_scan_seen.clear(); _scan_count = 0
		_phase = "scan_existing"
		return
	if FileAccess.file_exists(_final) or _has_link(_final):
		_fail("기존 설치 위치를 덮어쓸 수 없습니다.")
		return
	var storage := DirAccess.open(ProjectSettings.globalize_path("user://"))
	if storage == null or storage.get_space_left() < PAYLOAD_BYTES + FILE_COUNT * 4096 + 32 * 1024 * 1024:
		_fail("새 팩을 안전하게 설치할 여유 공간이 부족합니다.")
		return
	if DirAccess.make_dir_recursive_absolute(_store) != OK or _has_link(_store):
		_fail("전용 설치 폴더를 만들지 못했습니다.")
		return
	_stage = _store.path_join("staging-523-" + _operation_id)
	if FileAccess.file_exists(_stage) or DirAccess.dir_exists_absolute(_stage) or _has_link(_stage):
		_stage = ""
		_fail("고유한 임시 설치 폴더를 만들지 못했습니다.")
		return
	if DirAccess.make_dir_absolute(_stage) != OK:
		_stage = ""
		_fail("임시 설치 폴더 생성에 실패했습니다.")
		return
	_created_dirs.append(_stage)
	_worker_stage = _stage
	_index = 0
	_phase = "extract"
	_report_progress("extract", 0, FILE_COUNT)


func _scan_existing_step() -> void:
	if _scan_dir == null:
		if _scan_queue.is_empty():
			if _scan_seen.size() != FILE_COUNT:
				_fail("기존 버전에 필요한 파일이 누락되었습니다.")
				return
			_index = 0; _phase = "reuse_verify"
			_report_progress(_phase, 0, FILE_COUNT)
			return
		_scan_relative = _scan_queue.pop_back()
		var path: String = _final.path_join(_scan_relative)
		if _has_link(path):
			_fail("기존 버전에 링크된 경로가 있습니다.")
			return
		_scan_dir = DirAccess.open(path)
		if _scan_dir == null:
			_fail("기존 버전의 파일 목록을 읽지 못했습니다.")
			return
		_scan_dir.include_hidden = true
		_scan_dir.include_navigational = false
		if _scan_dir.list_dir_begin() != OK:
			_fail("기존 버전의 파일 목록을 읽지 못했습니다.")
			return
	var name: String = _scan_dir.get_next()
	if name.is_empty():
		_scan_dir.list_dir_end(); _scan_dir = null
		return
	var relative: String = name if _scan_relative.is_empty() else _scan_relative.path_join(name)
	_scan_count += 1
	if _scan_count > FILE_COUNT + _expected_dirs.size() or _scan_dir.is_link(name):
		_fail("기존 버전에 허용되지 않은 파일 또는 링크가 있습니다.")
		return
	if _scan_dir.current_is_dir():
		if not _expected_dirs.has(relative):
			_fail("기존 버전에 선언되지 않은 폴더가 있습니다.")
			return
		_scan_queue.append(relative)
	else:
		if not _expected.has(relative):
			_fail("기존 버전에 선언되지 않은 파일이 있습니다.")
			return
		_scan_seen[relative] = true


func _make_stage_parents(relative: String) -> bool:
	return _make_relative_parents(_stage, relative, _created_dirs)


static func _make_relative_parents(root_path: String, relative: String, created_dirs: Array[String]) -> bool:
	# Caller checks the root's complete ancestry. Check each relative component
	# once here; extraction rechecks the complete target immediately before open.
	if not safe_relative(relative):
		return false
	var directory := DirAccess.open(root_path)
	if directory == null:
		return false
	var current: String = root_path
	for part: String in relative.get_base_dir().split("/", false):
		if directory.is_link(part) or directory.file_exists(part):
			return false
		var child: String = current.path_join(part)
		if not directory.dir_exists(part):
			if directory.make_dir(part) != OK:
				return false
			created_dirs.append(child)
		if directory.change_dir(part) != OK:
			return false
		current = child
	return true


func _extract_step() -> void:
	var relative: String = _names[_index]
	var expected: Dictionary = _expected[relative]
	if _has_link(_stage) or not _make_stage_parents(relative):
		_fail("임시 설치 경로를 안전하게 만들지 못했습니다.")
		return
	var target: String = _stage.path_join(relative)
	var bytes: PackedByteArray = _zip.read_file(relative)
	if bytes.size() != int(expected.bytes) or _sha(bytes) != str(expected.sha256):
		_fail("ZIP 원문 파일의 해시가 다릅니다: " + relative)
		return
	if _has_link(target) or FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
		_fail("임시 설치 파일을 덮어쓸 수 없습니다.")
		return
	_written.append(target)
	var output := FileAccess.open(target, FileAccess.WRITE)
	if output == null:
		_fail("임시 파일 저장에 실패했습니다: " + relative)
		return
	output.store_buffer(bytes); output.flush()
	var error: Error = output.get_error()
	output.close()
	if error != OK:
		_fail("설치 공간 또는 파일 쓰기 오류가 발생했습니다.")
		return
	_index += 1
	_report_progress("extract", _index, FILE_COUNT)
	if _index == FILE_COUNT:
		_zip.close(); _zip = null
		_verify_root = _stage
		_index = 0; _phase = "verify"
		_report_progress("verify", 0, FILE_COUNT)


func _verify_step() -> void:
	if _index == FILE_COUNT:
		_phase = "publish"
		return
	var relative: String = _names[_index]
	var expected: Dictionary = _expected[relative]
	if _verify_file == null:
		var path: String = _verify_root.path_join(relative)
		if _has_link(path):
			_fail("검증할 파일에 링크가 있습니다: " + relative)
			return
		_verify_file = FileAccess.open(path, FileAccess.READ)
		if _verify_file == null or _verify_file.get_length() != int(expected.bytes):
			_fail("설치 파일의 크기가 다릅니다: " + relative)
			return
		_verify_hash = HashingContext.new()
		if _verify_hash.start(HashingContext.HASH_SHA256) != OK:
			_fail("설치 파일 검증을 시작하지 못했습니다.")
			return
		_verify_bytes = 0
	var count: int = mini(HASH_CHUNK, int(expected.bytes) - _verify_bytes)
	var bytes: PackedByteArray = _verify_file.get_buffer(count)
	if bytes.size() != count or _verify_hash.update(bytes) != OK:
		_fail("설치 파일을 다시 읽지 못했습니다: " + relative)
		return
	_verify_bytes += bytes.size()
	if _verify_bytes == int(expected.bytes):
		var digest: String = _verify_hash.finish().hex_encode()
		_verify_file.close(); _verify_file = null; _verify_hash = null
		if digest != str(expected.sha256):
			_fail("설치 파일 SHA256이 다릅니다. 기존 버전을 유지합니다: " + relative)
			return
		_index += 1
		_report_progress("reuse_verify" if _reused else "verify", _index, FILE_COUNT)


func _publish() -> void:
	if safe_store_root(_store) != _store or _has_link(_verify_root):
		_fail("설치 위치가 검사 중 변경되었습니다.")
		return
	if not _reused:
		if FileAccess.file_exists(_final) or DirAccess.dir_exists_absolute(_final) or _has_link(_final):
			_fail("검사 중 같은 버전의 설치 위치가 생겼습니다. 덮어쓰지 않습니다.")
			return
		if DirAccess.rename_absolute(_stage, _final) != OK:
			_fail("검증된 설치 폴더를 게시하지 못했습니다.")
			return
		_stage = ""
	var result: Dictionary = {"ok": true, "raw_root": _final.path_join("aden523-raw"),
		"tile_root": _final.path_join("aden523-tiles"), "root": _final,
		"archive_sha256": ARCHIVE_SHA256, "files": FILE_COUNT, "bytes": PAYLOAD_BYTES,
		"reused": _reused, "cancelled": false, "game_save_modified": false}
	_complete(result)


func _fail(message: String, was_cancelled: bool = false) -> void:
	_close_handles()
	_worker_outcome = {"ok": false, "problem": message, "cancelled": was_cancelled, "previous_packs_preserved": true}
	_cleanup_file = _written.size() - 1
	_cleanup_dir = _created_dirs.size() - 1
	_phase = "cleanup"
	if _stage.is_empty():
		_complete(_worker_outcome)
	else:
		_report_progress("cleanup", 0, _written.size() + _created_dirs.size())


func _cleanup_step() -> void:
	if _cleanup_file >= 0:
		_remove_owned(_written[_cleanup_file], false)
		_cleanup_file -= 1
	elif _cleanup_dir >= 0:
		_remove_owned(_created_dirs[_cleanup_dir], true)
		_cleanup_dir -= 1
	else:
		if not _cleanup_problem.is_empty():
			_worker_outcome["cleanup_pending"] = _stage
			_worker_outcome["cleanup_problem"] = _cleanup_problem
		_stage = ""
		_complete(_worker_outcome)
		return
	_report_progress("cleanup", _written.size() + _created_dirs.size() - _cleanup_file - _cleanup_dir - 2, _written.size() + _created_dirs.size())


func _remove_owned(path: String, directory: bool) -> void:
	if _stage.is_empty() or (path != _stage and not path.begins_with(_stage + "/")):
		return
	if _has_link(path):
		_cleanup_problem = "링크된 임시 경로는 따라가지 않고 보존했습니다."
		return
	if (DirAccess.dir_exists_absolute(path) if directory else FileAccess.file_exists(path)) and DirAccess.remove_absolute(path) != OK:
		_cleanup_problem = "일부 임시 설치 파일을 지우지 못했습니다."


func _close_handles() -> void:
	if _hash_file != null:
		_hash_file.close(); _hash_file = null
	if _verify_file != null:
		_verify_file.close(); _verify_file = null
	if _zip != null:
		_zip.close(); _zip = null
	if _scan_dir != null:
		_scan_dir.list_dir_end(); _scan_dir = null
	_hash = null; _verify_hash = null


func _complete(result: Dictionary) -> void:
	_close_handles()
	_record_phase_time()
	var outcome: Dictionary = result.duplicate(true)
	outcome["written_files"] = _written.size()
	outcome["stage_root"] = _worker_stage
	outcome["cleanup_complete"] = _cleanup_problem.is_empty()
	outcome["phase_msec"] = _phase_times.duplicate(true)
	outcome["phase_steps"] = _phase_steps.duplicate(true)
	_worker_done = true
	_phase = ""
	_expected.clear(); _expected_dirs.clear(); _archive_names.clear(); _archive_seen.clear()
	_raw.clear(); _tiles.clear(); _names.clear(); _written.clear(); _created_dirs.clear()
	_scan_queue.clear(); _scan_seen.clear()
	_mutex.lock()
	_pending_result = outcome
	_mutex.unlock()


func _accept_result(result: Dictionary, notify: bool) -> void:
	busy = false
	set_process(false)
	last_result = result.duplicate(true)
	problem = "" if bool(result.get("ok", false)) else str(result.get("problem", "설치를 완료하지 못했습니다."))
	if notify:
		finished.emit(last_result.duplicate(true))


func _exit_tree() -> void:
	if not busy and _thread == null:
		return
	_generation += 1
	_mutex.lock()
	_cancel_requested = true
	_mutex.unlock()
	var worker_started: bool = _thread != null and _thread.is_started()
	if worker_started:
		_thread.wait_to_finish()
	_thread = null
	_mutex.lock()
	var result: Dictionary = _pending_result.duplicate(true)
	_mutex.unlock()
	if result.is_empty():
		if worker_started:
			result = _joined_failure_result("설치기가 닫혀 설치를 중단했습니다.", true)
		else:
			result = {"ok": false, "problem": "설치기가 닫혀 설치를 중단했습니다.", "cancelled": true,
				"previous_packs_preserved": true, "written_files": 0, "stage_root": "", "cleanup_complete": true}
	# A fully verified version may have been published before cancellation arrived.
	_accept_result(result, false)


func _joined_failure_result(message: String, was_cancelled: bool) -> Dictionary:
	# Called only after wait_to_finish: the worker can no longer touch this state.
	_close_handles()
	var pending: String = _stage if not _stage.is_empty() else _worker_stage
	var remains: bool = not pending.is_empty() and (DirAccess.dir_exists_absolute(pending) or FileAccess.file_exists(pending) or _has_link(pending))
	var result: Dictionary = {"ok": false, "problem": message, "cancelled": was_cancelled,
		"previous_packs_preserved": true, "written_files": _written.size(), "stage_root": pending,
		"cleanup_complete": not remains}
	if remains:
		result["cleanup_pending"] = pending
		result["cleanup_problem"] = "작업 스레드가 정상 결과 없이 종료되어 임시 폴더를 보존했습니다."
	return result


static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


static func _uint(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= 0 and float(value) <= maximum


static func _valid_sha(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for c: String in value:
		if not c in "0123456789abcdef":
			return false
	return true
