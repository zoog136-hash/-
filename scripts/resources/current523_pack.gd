extends Node
## Private, exact current-M input. Standard PNG use and raw SP2 storage are distinct.
signal progress(done: int, total: int)
const STORE = "user://lineagem_current523_versions"
const ARCHIVE_BYTES = 76907660
const ARCHIVE_SHA = "b6f665d03e84e7cd01b3dd15b60d94091b3ff762cdc58fcfd820c724aa622182"
const REGISTRY = "results/all989_actual_current_M_SP2_registry.json"
const REGISTRY_SHA = "8e22a6b5a2a9cc32a5f5cced0c6d0fb090127c7d7bdb1ba49acfb06615685247"
const IMAGES = {
	"forge_map_icon":{"member":"validated_PNGs/Map_Icon_Forge.png", "sha256":"2bd7f18187b289e5781b84ffb843ba23c48842ee02323daaefd3f700b3d8d121", "bytes":3817, "size":[60,60]},
	"normal_cloud":{"member":"validated_PNGs/normal_cloud.png", "sha256":"ba51b07c3b4ea71e3cdc640fd09dc5fc2c3201f578b2f4559951f6c76ae8ccf7", "bytes":179853, "size":[768,768]}
}
static var _selected: String = ""
static var _selection_frozen: bool = false
static var _textures: Dictionary = {}
var busy: bool = false
var cancelled: bool = false

static func root_path() -> String:
	if _selection_frozen: return _selected
	_selection_frozen = true
	_selected = latest_root()
	return _selected

static func latest_root() -> String:
	var selected: String = ""
	var best: int = 0
	var directory := DirAccess.open(STORE)
	if directory != null:
		for name: String in directory.get_directories():
			if not name.begins_with("pack-"): continue
			var candidate: String = STORE.path_join(name)
			var receipt: Dictionary = info(candidate)
			if int(receipt.get("activated_usec",0)) > best:
				best = int(receipt.activated_usec)
				selected = candidate
	return selected

static func info(path: String = "") -> Dictionary:
	var selected: String = root_path() if path.is_empty() else path
	if not selected.begins_with(STORE + "/pack-") or selected.trim_prefix(STORE + "/").contains("/"): return {}
	var receipt_path: String = selected.path_join("installed.json")
	if not FileAccess.file_exists(receipt_path): return {}
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(receipt_path))
	if not receipt is Dictionary or receipt.get("source_snapshot") != "patch523" or receipt.get("package_sha256") != ARCHIVE_SHA: return {}
	if receipt.get("standard_pngs") != 2 or receipt.get("raw_sp2_files") != 989 or receipt.get("sprite_playback") != false: return {}
	return receipt

static func texture(key: String, preview_root: String = "") -> Texture2D:
	if not IMAGES.has(key): return null
	var selected: String = root_path() if preview_root.is_empty() else preview_root
	if info(selected).is_empty(): return null
	var spec: Dictionary = IMAGES[key]
	var path: String = selected.path_join(spec.member)
	if _textures.has(path): return _textures[path]
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != spec.sha256: return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty() or image.get_width() != int(spec["size"][0]) or image.get_height() != int(spec["size"][1]): return null
	var result := ImageTexture.create_from_image(image)
	_textures[path] = result
	return result

static func digest(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not data.is_empty(): context.update(data)
	return context.finish().hex_encode()

static func fail(message: String) -> Dictionary:
	return {"ok":false,"error":message,"previous_pack_preserved":true}

func install_zip(path: String) -> Dictionary:
	if busy: return fail("설치가 이미 진행 중입니다.")
	busy = true
	cancelled = false
	root_path() # Every consumer retains its current version until restart.
	var result: Dictionary = await _install(path)
	busy = false
	return result

func _install(path: String) -> Dictionary:
	progress.emit(0, 992)
	await get_tree().process_frame
	if cancelled: return fail("523 설치를 중단했습니다. 이전 팩과 세이브는 유지됩니다.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != ARCHIVE_BYTES: return fail("현행523 원문·표준 PNG 연결 묶음 ZIP을 선택하세요.")
	file.close()
	if FileAccess.get_sha256(path) != ARCHIVE_SHA: return fail("523 원문 묶음의 SHA-256이 다릅니다. 기존 팩을 유지합니다.")
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return fail("523 ZIP을 열지 못했습니다.")
	var registry_bytes: PackedByteArray = zip.read_file(REGISTRY)
	if digest(registry_bytes) != REGISTRY_SHA: return fail("523 원문 목록 검사 실패.")
	var rows: Variant = JSON.parse_string(registry_bytes.get_string_from_utf8())
	if not rows is Array or rows.size() != 989: return fail("523 원문 파일 수가 다릅니다.")
	var total: int = registry_bytes.size()
	var members: Dictionary = {REGISTRY:{"bytes":registry_bytes.size(),"sha256":REGISTRY_SHA}}
	for spec: Dictionary in IMAGES.values():
		members[spec.member] = spec
		total += int(spec.bytes)
	for row: Variant in rows:
		if not row is Dictionary: return fail("523 원문 목록 형식 오류.")
		var member: String = str(row.get("canonical_package_member",""))
		var name: String = member.trim_prefix("selected_originals/Sprite/")
		if not member.begins_with("selected_originals/Sprite/") or not name.is_valid_filename() or name.contains("/") or not name.ends_with(".sp2") or members.has(member): return fail("523 원문 경로 오류.")
		var size: int = int(row.get("bytes",0))
		if size <= 0 or size > 2 * 1024 * 1024: return fail("523 원문 크기 오류.")
		members[member] = {"bytes":size,"sha256":str(row.sha256)}
		total += size
	var storage := DirAccess.open("user://")
	if storage == null or storage.get_space_left() < total + 16 * 1024 * 1024: return fail("설치 공간이 부족합니다. 기존 팩과 별도의 공간이 필요합니다.")
	var stamp: int = int(Time.get_unix_time_from_system() * 1000000)
	var directory := DirAccess.open(STORE)
	if directory != null:
		for name: String in directory.get_directories():
			var receipt: Dictionary = info(STORE.path_join(name))
			stamp = maxi(stamp,int(receipt.get("activated_usec",0))+1)
	var suffix: String = str(stamp) + "-" + str(Time.get_ticks_usec())
	var stage: String = STORE.path_join("staging-" + suffix)
	if DirAccess.make_dir_recursive_absolute(stage) != OK: return fail("523 임시 폴더를 만들지 못했습니다.")
	var done: int = 0
	var last_yield: int = Time.get_ticks_msec()
	for member: String in members:
		if cancelled: return fail("523 설치를 중단했습니다. 이전 팩과 세이브는 유지됩니다.")
		var bytes: PackedByteArray = zip.read_file(member)
		var spec: Dictionary = members[member]
		if bytes.size() != int(spec.bytes) or digest(bytes) != spec.sha256: return fail("523 파일 검사 실패: " + member)
		if member.begins_with("validated_PNGs/"):
			var image := Image.new()
			if image.load_png_from_buffer(bytes) != OK or image.get_width() != int(spec["size"][0]) or image.get_height() != int(spec["size"][1]): return fail("523 PNG 검사 실패: " + member)
		var target: String = stage.path_join(member)
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return fail("523 설치 폴더 생성 실패.")
		var output := FileAccess.open(target, FileAccess.WRITE)
		if output == null: return fail("523 파일 저장 실패.")
		output.store_buffer(bytes)
		output.flush()
		var error: Error = output.get_error()
		output.close()
		if error != OK: return fail("523 파일 쓰기 오류.")
		done += 1
		if Time.get_ticks_msec() - last_yield >= 40:
			progress.emit(done,members.size())
			await get_tree().process_frame
			last_yield = Time.get_ticks_msec()
	zip.close()
	if cancelled: return fail("523 설치를 중단했습니다. 이전 팩과 세이브는 유지됩니다.")
	var receipt: Dictionary = {"schema":1,"source_snapshot":"patch523","package_sha256":ARCHIVE_SHA,"standard_pngs":2,"raw_sp2_files":989,"sprite_playback":false,"files":done,"bytes":total,"activated_usec":stamp}
	var marker := FileAccess.open(stage.path_join("installed.json"), FileAccess.WRITE)
	if marker == null: return fail("523 설치 기록 저장 실패.")
	marker.store_string(JSON.stringify(receipt))
	marker.flush()
	var marker_error: Error = marker.get_error()
	marker.close()
	if marker_error != OK: return fail("523 설치 기록 쓰기 오류.")
	var final_path: String = STORE.path_join("pack-" + suffix)
	if DirAccess.rename_absolute(stage,final_path) != OK: return fail("523 설치 전환 실패.")
	progress.emit(done,members.size())
	return {"ok":true,"root":final_path,"standard_pngs":2,"raw_sp2_files":989,"sprite_playback":false,"restart_required":true}
