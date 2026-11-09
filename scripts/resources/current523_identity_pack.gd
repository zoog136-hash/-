extends Node
## Exact, private identity subset. Identity is proven; decoded pixels/composition are estimates.
signal progress(done: int,total: int)
const BASE = preload("res://scripts/lineagem_base508.gd")
const SOURCE = preload("res://scripts/resources/current523_pack.gd")
const DECODER = preload("res://scripts/resources/current523_sp2_decoder.gd")
const ORIGINAL_SELECTION = preload("res://scripts/original_client/sprite_selection.gd")
const STORE = "user://current523_identity_versions"
const SETTINGS = "user://current523_identity_settings.json"
const MANIFEST = "manifest.json"
const ARCHIVE_BYTES = 22415929
const ARCHIVE_SHA = "77ac05a4e0e3b6af81f6ae94d30d6bdf2f18324223e52f47f03e794be69617b5"
const MANIFEST_SHA = "e03944ee863b429f702154453fa0f6e873044b20aa5be1c93bc7f80ead91873f"
const DEFAULTS = {"enabled":false,"root":"","fps":12.0,"alpha_policy":"opaque_samples","rgb_policy":"bit_replication","blend":"mix","opacity":1.0,"zoom":1.0}
static var revision: int = 0
static var _options: Dictionary = {}
static var _manifest_root: String = ""
static var _manifest: Dictionary = {}
static var _parsed: Dictionary = {}
static var _parse_order: Array[String] = []
static var settings_problem: String = ""
var busy: bool = false
var cancelled: bool = false

static func fail(message: String) -> Dictionary:
	return {"ok":false,"error":message,"previous_pack_preserved":true,"estimated":true}

static func _safe_root(path: String) -> bool:
	return path.begins_with(STORE + "/pack-") and not path.trim_prefix(STORE + "/").contains("/") and path.get_file().is_valid_filename()

static func manifest_at(path: String) -> Dictionary:
	if not _safe_root(path): return {}
	var target: String = path.path_join(MANIFEST)
	if not FileAccess.file_exists(target) or FileAccess.get_sha256(target) != MANIFEST_SHA: return {}
	if path == _manifest_root and not _manifest.is_empty(): return _manifest
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(target))
	if not value is Dictionary or value.get("schema") != 1 or value.get("snapshot") != "patch523" or value.get("mode") != "exact_identity_estimated_pixels": return {}
	if not value.get("members") is Dictionary or not value.get("cards") is Dictionary or not value.get("actors") is Dictionary: return {}
	_manifest_root = path
	_manifest = value
	return _manifest

static func latest_root() -> String:
	var directory := DirAccess.open(STORE)
	var latest: String = ""
	var stamp: int = 0
	if directory != null:
		for name: String in directory.get_directories():
			var path: String = STORE.path_join(name)
			if not _safe_root(path): continue
			var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("installed.json"))) if FileAccess.file_exists(path.path_join("installed.json")) else null
			if receipt is Dictionary and receipt.get("package_sha256") == ARCHIVE_SHA and int(receipt.get("activated_usec",0)) > stamp and not manifest_at(path).is_empty():
				stamp = int(receipt.activated_usec)
				latest = path
	return latest

static func _validate(values: Dictionary) -> Dictionary:
	var next: Dictionary = DEFAULTS.duplicate(true)
	for key: String in DEFAULTS:
		if values.has(key): next[key] = values[key]
	if not next.enabled is bool or not next.root is String: return fail("정체 연결 설정 형식이 다릅니다.")
	for key: String in ["alpha_policy","rgb_policy","blend"]:
		if not next[key] is String: return fail("정체 표시 정책 형식이 다릅니다.")
	if not next.alpha_policy in ["opaque_samples","index0_transparent"] or not next.rgb_policy in ["bit_replication","linear"] or not next.blend in ["mix","add","multiply"]: return fail("지원하지 않는 추정 표시 정책입니다.")
	for key: String in ["fps","opacity","zoom"]:
		if not next[key] is int and not next[key] is float: return fail("정체 표시 수치 형식이 다릅니다.")
		var limits: Array = {"fps":[1.0,60.0],"opacity":[0.0,1.0],"zoom":[0.25,8.0]}[key]
		if not is_finite(float(next[key])) or float(next[key]) < float(limits[0]) or float(next[key]) > float(limits[1]): return fail("정체 표시 수치 범위를 벗어났습니다.")
		next[key] = float(next[key])
	if not next.root.is_empty() and not _safe_root(next.root): return fail("검증된 정체 팩 폴더를 선택하세요.")
	if next.enabled and manifest_at(next.root).is_empty(): return fail("검증된 정체 팩이 없습니다. 이전 표시를 유지합니다.")
	return {"ok":true,"options":next}

static func options() -> Dictionary:
	if not _options.is_empty(): return _options.duplicate(true)
	_options = DEFAULTS.duplicate(true)
	if FileAccess.file_exists(SETTINGS):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
		if value is Dictionary and value.get("schema") == 1 and value.get("options") is Dictionary:
			var checked: Dictionary = _validate(value.options)
			if checked.ok: _options = checked.options
			else: settings_problem = str(checked.error)
		else: settings_problem = "정체 표시 설정을 읽지 못해 기본 표시를 사용합니다."
	return _options.duplicate(true)

static func save_options(values: Dictionary) -> Dictionary:
	var checked: Dictionary = _validate(values)
	if not checked.ok: return checked
	if checked.options.enabled:
		var integrity: Dictionary = _validate_members(str(checked.options.root),manifest_at(str(checked.options.root)).members.keys())
		if not integrity.ok: return integrity
	var temporary: String = SETTINGS + ".tmp-" + str(Time.get_ticks_usec())
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return fail("정체 설정을 저장하지 못했습니다. 이전 설정을 유지합니다.")
	file.store_string(JSON.stringify({"schema":1,"options":checked.options}))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary,SETTINGS) != OK: return fail("정체 설정 전환 실패. 이전 설정과 외형을 유지합니다.")
	_options = checked.options
	_parsed.clear()
	_parse_order.clear()
	settings_problem = ""
	revision += 1
	return {"ok":true,"options":_options.duplicate(true),"estimated":true}

static func load_actor(profile_key: String,context: Dictionary) -> Dictionary:
	var selected_options: Dictionary = options()
	if not selected_options.enabled: return fail("정체 자동 표시 꺼짐")
	var manifest: Dictionary = manifest_at(str(selected_options.root))
	if manifest.is_empty(): return fail("정체 팩 누락·변경 · 기본 표시 유지")
	var binding: Dictionary = manifest.cards.get(profile_key,{})
	if binding.is_empty() or not profile_key.begins_with("transform:m508:1:"): return fail("정확한 ID 연결이 확인되지 않은 변신입니다.")
	var source_id: String = profile_key.trim_prefix("transform:")
	var original: Dictionary = BASE.canonical({"source":"lineagem_base508","sourceId":source_id})
	if original.get("source_original_card",{}) != binding.get("source_original_card",null): return fail("원본 카드 정의가 다른 팩입니다. ID를 추정하지 않습니다.")
	var selected: Dictionary = BASE.select_visual_key(profile_key,context)
	if selected.get("status") != "selected": return fail("원본 변신의 직업·성별·선택 문맥이 필요합니다.")
	var sprite_id: int = int(selected.get("sprite_id",0))
	var permitted: bool = false
	for candidate: Variant in binding.get("sprite_ids",[]):
		if (candidate is int or candidate is float) and is_finite(float(candidate)) and float(candidate) == float(sprite_id): permitted = true
	if not permitted: return fail("이 원본 변형의 정확한 파일 연결이 없습니다.")
	var actor: Dictionary = manifest.actors.get("sprite:" + str(sprite_id),{})
	if int(actor.get("source_sprite_id",0)) != sprite_id: return fail("정체 팩 배우 연결이 다릅니다.")
	var selected_actor: Dictionary = actor.duplicate(true)
	var weapon: int = int(context.get("source_weapon_type",0))
	if weapon != 0:
		var profile: Dictionary = actor.get("weapon_profiles",{}).get(str(weapon),{})
		if profile.is_empty(): return fail("이 변신·무기의 원문 동작 연결이 없습니다. 이전 표시를 유지합니다.")
		var roles: Dictionary = {}
		for role: String in profile.get("roles",{}):
			var compact: Dictionary = profile.roles[role]
			var expanded: Dictionary = compact.duplicate(true)
			expanded.erase("tokens")
			expanded.erase("layers")
			var directions: Array = []
			for direction: int in range(8):
				var frames: Array = []
				for token: Array in compact.tokens:
					# C06: u16(word0 + direction) -> file group and in-file direction (original-client contract adapter).
					var group: Dictionary = ORIGINAL_SELECTION.sp2_group(int(token[0]), int(compact.declared_flag) == 1, direction)
					var layers: Array = []
					for layer: Dictionary in compact.layers:
						layers.append({"member":ORIGINAL_SELECTION.primary_name(int(layer.source_sprite_id),group.file_b),"group_bit":group.direction,"frame_index":int(token[1]),"kind":str(layer.kind),"source_sprite_id":int(layer.source_sprite_id)})
					frames.append({"duration_ticks":int(token[2]),"layers":layers})
				directions.append(frames)
			expanded["directions"] = directions
			roles[role] = expanded
		selected_actor["roles"] = roles
		selected_actor["source_weapon_policy"] = "TWILIGHT 기본 무기 액션 선택 · 특수/변형 동작 제외"
	selected_actor["source_weapon_type"] = weapon
	return {"ok":true,"actor":selected_actor,"identity_verified":true,"estimated":true}

static func _validate_members(path: String,members: Array) -> Dictionary:
	var manifest: Dictionary = manifest_at(path)
	if manifest.is_empty(): return fail("정체 팩 명세가 누락되거나 변경됐습니다.")
	for member: String in members:
		var spec: Dictionary = manifest.members.get(member,{})
		if spec.is_empty(): return fail("정체 원문 명세가 없습니다.")
		var target: String = path.path_join(str(spec.path))
		if not FileAccess.file_exists(target) or FileAccess.get_sha256(target) != spec.sha256: return fail("정체 원문 누락·해시 변경 · 기본 표시 복구")
	return {"ok":true}

static func validate_actor_files(actor: Dictionary) -> Dictionary:
	var required: Dictionary = {}
	for track: Dictionary in actor.get("roles",{}).values():
		for frames: Array in track.get("directions",[]):
			for frame: Dictionary in frames:
				for layer: Dictionary in frame.get("layers",[]): required[str(layer.member)] = true
	return _validate_members(str(options().root),required.keys())

static func render_layer(layer: Dictionary,display_options: Dictionary) -> Dictionary:
	var selected_options: Dictionary = options()
	var manifest: Dictionary = manifest_at(str(selected_options.root))
	var member: String = str(layer.get("member",""))
	var spec: Dictionary = manifest.get("members",{}).get(member,{})
	if spec.is_empty(): return fail("정체 프레임의 원문이 없습니다.")
	var path: String = str(selected_options.root).path_join(str(spec.path))
	# Check actual bytes even when the parsed object is cached: corruption restores the baseline.
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != spec.sha256: return fail("정체 프레임 해시 변경 · 기본 표시 복구")
	if not _parsed.has(member):
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if bytes.size() != int(spec.bytes): return fail("정체 프레임 크기가 다릅니다.")
		var parsed: Dictionary = DECODER.parse(bytes)
		if not parsed.ok: return parsed
		# At most three parsed source files, also bounded by 32MiB decompressed bytes.
		var budget: int = parsed.body.size()
		for cached: Dictionary in _parsed.values(): budget += cached.body.size()
		while not _parse_order.is_empty() and (_parsed.size() >= 3 or budget > 32 * 1024 * 1024):
			var oldest: String = _parse_order.pop_front()
			budget -= _parsed[oldest].body.size()
			_parsed.erase(oldest)
		_parsed[member] = parsed
		_parse_order.append(member)
	var value: Dictionary = _parsed[member]
	var group_index: int = -1
	for index: int in range(value.groups.size()):
		if int(value.groups[index].bit) == int(layer.get("group_bit",-1)): group_index = index
	if group_index < 0: return fail("정체 프레임의 방향 비트가 없습니다.")
	return DECODER.render(value,group_index,int(layer.get("frame_index",-1)),display_options)

func install_zip(path: String) -> Dictionary:
	if busy: return fail("정체 팩 설치 중입니다.")
	busy = true
	cancelled = false
	var result: Dictionary = await _install(path)
	busy = false
	return result

func _install(path: String) -> Dictionary:
	progress.emit(0,1)
	await get_tree().process_frame
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() != ARCHIVE_BYTES: return fail("검증된523 정체 연결 팩 ZIP을 선택하세요.")
	file.close()
	if FileAccess.get_sha256(path) != ARCHIVE_SHA: return fail("정체 팩 SHA-256이 다릅니다. 이전 팩을 유지합니다.")
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return fail("정체 팩을 열지 못했습니다.")
	var manifest_bytes: PackedByteArray = zip.read_file(MANIFEST)
	if SOURCE.digest(manifest_bytes) != MANIFEST_SHA: return fail("정체 팩 명세 해시가 다릅니다.")
	var manifest: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not manifest is Dictionary or not manifest.get("members") is Dictionary: return fail("정체 팩 명세 형식 오류")
	var members: Dictionary = {MANIFEST:{"bytes":manifest_bytes.size(),"sha256":MANIFEST_SHA}}
	var total: int = manifest_bytes.size()
	for member: String in manifest.members:
		var spec: Dictionary = manifest.members[member]
		if not member.begins_with("Sprite/") or not member.trim_prefix("Sprite/").is_valid_filename() or member.trim_prefix("Sprite/").contains("/") or not member.ends_with(".sp2") or spec.get("path") != "raw/" + member: return fail("정체 원문 경로 오류")
		if int(spec.get("bytes",0)) <= 0 or int(spec.bytes) > DECODER.MAX_INPUT_BYTES: return fail("정체 원문 크기 오류")
		members[spec.path] = spec
		total += int(spec.bytes)
	var storage := DirAccess.open("user://")
	if storage == null or storage.get_space_left() < total + 16 * 1024 * 1024: return fail("정체 팩 별도 설치 공간이 부족합니다.")
	var stamp: int = int(Time.get_unix_time_from_system() * 1000000)
	var stage: String = STORE.path_join("staging-" + str(stamp) + "-" + str(Time.get_ticks_usec()))
	if DirAccess.make_dir_recursive_absolute(stage) != OK: return fail("정체 임시 폴더 생성 실패")
	var done: int = 0
	for member: String in members:
		if cancelled: return fail("정체 설치 중단 · 이전 팩과 세이브 유지")
		var bytes: PackedByteArray = zip.read_file(member)
		var spec: Dictionary = members[member]
		if bytes.size() != int(spec.bytes) or SOURCE.digest(bytes) != spec.sha256: return fail("정체 파일 무결성 오류: " + member)
		var target: String = stage.path_join(member)
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return fail("정체 파일 폴더 생성 실패")
		var output := FileAccess.open(target,FileAccess.WRITE)
		if output == null: return fail("정체 파일 저장 실패")
		output.store_buffer(bytes)
		output.flush()
		var error: Error = output.get_error()
		output.close()
		if error != OK: return fail("정체 파일 쓰기 실패")
		done += 1
		progress.emit(done,members.size())
		if done % 8 == 0: await get_tree().process_frame
	zip.close()
	if cancelled: return fail("정체 설치 중단 · 이전 팩 유지")
	var marker := FileAccess.open(stage.path_join("installed.json"),FileAccess.WRITE)
	if marker == null: return fail("정체 설치 기록 저장 실패")
	marker.store_string(JSON.stringify({"schema":1,"package_sha256":ARCHIVE_SHA,"activated_usec":stamp,"files":done,"bytes":total}))
	marker.flush()
	var marker_error: Error = marker.get_error()
	marker.close()
	if marker_error != OK: return fail("정체 설치 기록 쓰기 실패")
	var final_path: String = STORE.path_join(stage.get_file().replace("staging-","pack-"))
	if DirAccess.rename_absolute(stage,final_path) != OK: return fail("정체 설치 전환 실패")
	return {"ok":true,"root":final_path,"files":done,"identity_verified":true,"estimated":true}
