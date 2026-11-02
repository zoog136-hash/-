extends Node
## Byte-identical legacy catalog compatibility pack; not original-M art delivery.
signal progress(done: int, total: int)

const INDEX_PATH := "res://data/visuals/private_catalog_motion.json"
const INDEX_SHA := "24f8453861359922acfe94965bdc7a1f8f5b64a7b508f443d607e0572dd02331"
const ZIP_SHA := "62d29b7e79000ccc430772ec316b29145a44675dfed88742ff424df31d4184b3"
const ZIP_BYTES := 233627186
const STORE := "user://catalog_motion_versions"
const PREFIX := "assets/catalog_motion/"
static var _index: Dictionary = {}
var cancelled := false
var _stage := ""

static func index_data() -> Dictionary:
	if not _index.is_empty(): return _index
	if FileAccess.get_sha256(INDEX_PATH) != INDEX_SHA: return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not value is Dictionary or value.get("schema") != 1 or value.get("kind") != "twilight-private-catalog-motion": return {}
	if value.get("catalog_entries") != 723 or value.get("frame_count") != 41442 or value.get("bytes") != 233420026: return {}
	if not value.get("files") is Dictionary or value.files.size() != 723: return {}
	var total := 0
	for path: String in value.files:
		var row: Variant = value.files[path]
		if not safe_path(path) or not row is Dictionary or int(row.get("bytes", 0)) <= 0 or int(row.bytes) > 2 * 1024 * 1024: return {}
		var digest: String = str(row.get("sha256", ""))
		if digest.length() != 64 or not digest.is_valid_hex_number(false): return {}
		total += int(row.bytes)
	if total != 233420026: return {}
	_index = value
	return _index

static func safe_path(path: String) -> bool:
	return path.begins_with(PREFIX) and path.ends_with(".webp") and not path.contains("..") and not path.contains("\\") and not path.contains("//") and not path.contains(":")

static func active_root() -> String:
	if not DirAccess.dir_exists_absolute(STORE): return ""
	var best := ""
	var stamp := -1
	for name: String in DirAccess.get_directories_at(STORE):
		if name.begins_with("staging-") or name.contains("..") or name.contains("/"): continue
		var root: String = STORE.path_join(name)
		var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("installed.json"))) if FileAccess.file_exists(root.path_join("installed.json")) else null
		if not receipt is Dictionary or receipt.get("index_sha256") != INDEX_SHA or receipt.get("zip_sha256") != ZIP_SHA or receipt.get("files") != 723 or receipt.get("bytes") != 233420026: continue
		if FileAccess.get_sha256(root.path_join("catalog-index.json")) != INDEX_SHA: continue
		var when: int = int(receipt.get("activated_usec", 0))
		if when > stamp: best = root; stamp = when
	return best

static func embedded_complete() -> bool:
	var data: Dictionary = index_data()
	if data.is_empty(): return false
	for path: String in data.files:
		if not FileAccess.file_exists("res://" + path): return false
	return true

static func verified_file(path: String, row: Dictionary) -> bool:
	if not FileAccess.file_exists(path): return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return false
	var length := file.get_length()
	file.close()
	if length != int(row.bytes): return false
	return FileAccess.get_sha256(path) == str(row.sha256)

static func texture(logical_path: String) -> Texture2D:
	if not logical_path.begins_with("res://"): return null
	var relative: String = logical_path.trim_prefix("res://")
	var data: Dictionary = index_data()
	if not safe_path(relative) or data.is_empty() or not data.files.has(relative): return null
	var root: String = active_root()
	if root.is_empty(): return null
	var file: String = root.path_join(relative)
	if not verified_file(file, data.files[relative]): return null
	var image := Image.load_from_file(file)
	if image == null or image.is_empty(): return null
	return ImageTexture.create_from_image(image)

# Validate central-directory sizes before ZIPReader may allocate any entry.
static func validate_zip(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22: return false
	var length := file.get_length()
	var tail_size: int = mini(length, 65557)
	file.seek(length - tail_size)
	var tail := file.get_buffer(tail_size)
	var end := -1
	for at: int in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(at) == 0x06054b50 and at + 22 + tail.decode_u16(at + 20) == tail.size(): end = at; break
	if end < 0 or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0: return false
	var count: int = tail.decode_u16(end + 10)
	var size: int = tail.decode_u32(end + 12)
	var offset: int = tail.decode_u32(end + 16)
	if count != 724 or count != tail.decode_u16(end + 8) or size > 512 * 1024 or offset + size != length - tail_size + end: return false
	file.seek(offset)
	var central := file.get_buffer(size)
	file.close()
	if central.size() != size: return false
	var at := 0
	var found: Dictionary = {}
	for entry: int in range(count):
		if at + 46 > central.size() or central.decode_u32(at) != 0x02014b50: return false
		var flags: int = central.decode_u16(at + 8)
		var method: int = central.decode_u16(at + 10)
		var unpacked: int = central.decode_u32(at + 24)
		var name_size: int = central.decode_u16(at + 28)
		var record: int = 46 + name_size + central.decode_u16(at + 30) + central.decode_u16(at + 32)
		if record > central.size() - at or flags & 1 or method not in [0, 8] or central.decode_u32(at + 20) > 2 * 1024 * 1024 or central.decode_u32(at + 42) >= offset or (central.decode_u32(at + 38) >> 16) & 0xf000 == 0xa000: return false
		var name: String = central.slice(at + 46, at + 46 + name_size).get_string_from_utf8()
		if found.has(name): return false
		if name == "catalog-index.json":
			if unpacked != 97194: return false
		elif not safe_path(name) or not data.files.has(name) or unpacked != int(data.files[name].bytes): return false
		found[name] = true
		at += record
	return at == central.size() and found.size() == 724 and found.has("catalog-index.json")

func _cleanup() -> void:
	if _stage.is_empty() or not _stage.begins_with(STORE + "/staging-"): return
	_remove_tree(_stage)
	_stage = ""

static func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null: return
	for file: String in dir.get_files(): DirAccess.remove_absolute(path.path_join(file))
	for child: String in dir.get_directories(): _remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)

func _failure(message: String) -> Dictionary:
	_cleanup()
	return {"ok":false, "error":message, "previous_pack_preserved":true}

func available_space() -> int:
	var storage := DirAccess.open("user://")
	return storage.get_space_left() if storage != null else 0

func install_zip(path: String) -> Dictionary:
	cancelled = false
	var data: Dictionary = index_data()
	if data.is_empty(): return _failure("표시팩 검증 목록이 올바르지 않습니다.")
	var input := FileAccess.open(path, FileAccess.READ)
	if input == null: return _failure("ZIP 파일을 열 수 없습니다.")
	var input_size := input.get_length()
	input.close()
	if input_size != ZIP_BYTES or FileAccess.get_sha256(path) != ZIP_SHA: return _failure("ZIP 크기 또는 SHA256이 다릅니다.")
	if not validate_zip(path, data): return _failure("지원되는 안전한 표시팩 ZIP이 아닙니다.")
	if available_space() < 233420026 + 723 * 4096 + 64 * 1024 * 1024: return _failure("기존 팩과 별도로 새 팩을 저장할 공간이 부족합니다.")
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return _failure("ZIP 파일을 읽을 수 없습니다.")
	var index_bytes: PackedByteArray = zip.read_file("catalog-index.json")
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256); hashing.update(index_bytes)
	if hashing.finish().hex_encode() != INDEX_SHA: zip.close(); return _failure("표시팩 목록이 손상됐습니다.")
	var stamp: int = int(Time.get_unix_time_from_system() * 1000000)
	var id: String = str(stamp) + "-" + str(Time.get_ticks_usec())
	_stage = STORE.path_join("staging-" + id)
	if DirAccess.make_dir_recursive_absolute(_stage) != OK: zip.close(); return _failure("임시 설치 폴더 생성 실패.")
	var index_file := FileAccess.open(_stage.path_join("catalog-index.json"), FileAccess.WRITE)
	if index_file == null: zip.close(); return _failure("목록 저장 실패.")
	index_file.store_buffer(index_bytes); index_file.flush(); index_file.close()
	var done := 0
	for relative: String in data.files:
		if cancelled: zip.close(); return _failure("설치를 중단했습니다. 기존 팩과 세이브는 유지됩니다.")
		var row: Dictionary = data.files[relative]
		var bytes: PackedByteArray = zip.read_file(relative)
		hashing.start(HashingContext.HASH_SHA256); hashing.update(bytes)
		if bytes.size() != int(row.bytes) or hashing.finish().hex_encode() != str(row.sha256): zip.close(); return _failure("표시 파일 검사 실패.")
		var output: String = _stage.path_join(relative)
		if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK: zip.close(); return _failure("저장 폴더 생성 실패.")
		var writer := FileAccess.open(output, FileAccess.WRITE)
		if writer == null: zip.close(); return _failure("파일 쓰기 실패.")
		writer.store_buffer(bytes); writer.flush()
		var error: Error = writer.get_error()
		writer.close()
		if error != OK or FileAccess.get_sha256(output) != str(row.sha256): zip.close(); return _failure("저장 공간 또는 파일 무결성 오류.")
		done += 1
		if done % 16 == 0: progress.emit(done, 723); await get_tree().process_frame
	zip.close()
	var receipt := FileAccess.open(_stage.path_join("installed.json"), FileAccess.WRITE)
	if receipt == null: return _failure("설치 영수증 저장 실패.")
	receipt.store_string(JSON.stringify({"index_sha256":INDEX_SHA, "zip_sha256":ZIP_SHA, "files":723, "bytes":233420026, "activated_usec":stamp}))
	receipt.flush()
	var receipt_error: Error = receipt.get_error()
	receipt.close()
	if receipt_error != OK: return _failure("설치 영수증 기록 오류.")
	var destination: String = STORE.path_join("version-" + id)
	if DirAccess.rename_absolute(_stage, destination) != OK: return _failure("설치 전환 실패.")
	_stage = ""
	progress.emit(done, 723)
	return {"ok":true, "root":destination, "files":done, "bytes":233420026, "previous_pack_preserved":true}
