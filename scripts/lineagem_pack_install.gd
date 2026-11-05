extends Node
## Offline, user-selected ZIP only. No network, save writes or old-pack deletion.
signal progress(done: int, total: int)
signal completed(result: Dictionary)
const STORE = "user://lineagem_base508_versions"
const LEGACY = "user://lineagem_base508"
const MONSTER_STORE = "user://lineagem_base508_monsters_versions"
const MONSTER_LEGACY = "user://lineagem_base508_monsters"
const MAX_FILES = 750000
const MAX_BYTES = 6 * 1024 * 1024 * 1024
const MAX_ENTRY = 64 * 1024 * 1024
const REQUIRED = ["manifest.json", "source_effect_bindings.json", "registered_effect_layers.json"]
static var _session_root: String = ""
static var _session_manifest: String = ""
static var _session_explicit: bool = false
static var _session_manifest_checked: bool = false
static var _session_manifest_problem: String = ""
static var _monster_session_root: String = ""
static var _base_roots: Dictionary = {}
var cancelled: bool = false
var busy: bool = false

static func safe_relative(path: String) -> bool:
	if path.is_empty() or path.length() > 240 or path.contains("\\") or path.contains(":") or path.begins_with("/"): return false
	for part: String in path.split("/", true):
		if part in ["", ".", ".."]: return false
	return true

static func active_root() -> String:
	# Freeze each component separately: installing must not mix live asset versions.
	if _session_root.is_empty():
		var selection: Dictionary = preview_selection(OS.get_cmdline_user_args())
		_session_explicit = selection.specified
		_session_manifest = selection.path
		_session_manifest_checked = false
		_session_root = _session_manifest.get_base_dir() if _session_explicit else _latest_root(STORE, LEGACY, false)
	return _session_root

static func preview_selection(arguments: PackedStringArray) -> Dictionary:
	var result: Dictionary = {"specified":false, "path":""}
	for argument: String in arguments:
		if argument.begins_with("--lineagem-original-preview="):
			result = {"specified":true, "path":argument.trim_prefix("--lineagem-original-preview=")}
	return result

static func active_manifest() -> String:
	var selected: String = active_root()
	return _session_manifest if _session_explicit else selected.path_join("manifest.json")

static func card_manifest_problem(value: Variant) -> String:
	if not value is Dictionary or value.get("schema") != 1 or not value.get("records") is Dictionary:
		return "원본 팩 선언이 손상됐거나 지원되지 않습니다."
	# Current IDs/consumers belong to base508. Another snapshot needs its own
	# registry/decoder; equal numeric sprite IDs never establish compatibility.
	if value.get("source_snapshot", "") != "base508":
		return "이 실행 경로는 base508 팩만 지원합니다. 다른 버전의 리소스를 섞지 않습니다."
	if value.get("mode", "") != "literal_body_shadow_inspection_only":
		return "지원되는 원본 캐릭터 팩이 아닙니다."
	return ""

static func active_manifest_problem() -> String:
	var path: String = active_manifest()
	if not _session_manifest_checked:
		_session_manifest_problem = "선택한 원본 팩이 없습니다." if path.is_empty() or not FileAccess.file_exists(path) else card_manifest_problem(JSON.parse_string(FileAccess.get_file_as_string(path)))
		_session_manifest_checked = true
	return _session_manifest_problem

static func monster_root() -> String:
	if _monster_session_root.is_empty(): _monster_session_root = _latest_root(MONSTER_STORE, MONSTER_LEGACY, true)
	return _monster_session_root

static func _latest_root(store: String, legacy: String, monsters: bool) -> String:
	var result: String = legacy
	var best: int = 0
	var directory := DirAccess.open(store)
	if directory != null:
		for name: String in directory.get_directories():
			if not name.begins_with("pack-") or not safe_relative(name): continue
			var root: String = store.path_join(name)
			var marker: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("installed.json"))) if FileAccess.file_exists(root.path_join("installed.json")) else null
			if not marker is Dictionary or marker.get("source_snapshot", "") != "base508": continue
			if monsters != (marker.get("component", "cards") == "monsters"): continue
			if int(marker.get("activated_usec", 0)) <= best: continue
			if not FileAccess.file_exists(root.path_join("manifest.json")): continue
			best = int(marker.activated_usec)
			result = root
	return result

static func trusted_root(path: String) -> bool:
	if path == LEGACY: return true
	if not path.begins_with(STORE + "/pack-"): return false
	var name: String = path.trim_prefix(STORE + "/")
	return safe_relative(name) and not name.contains("/")

static func base_root(root: String) -> String:
	if _base_roots.has(root): return str(_base_roots[root])
	var marker_path: String = root.path_join("installed.json")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker_path)) if FileAccess.file_exists(marker_path) else null
	var base: String = str(value.get("base_root", "")) if value is Dictionary else ""
	if not trusted_root(base) or base == root: base = ""
	_base_roots[root] = base
	return base

static func resolve_file(root: String, relative: String, depth: int = 0) -> String:
	if root.is_empty() or not safe_relative(relative) or depth > 4: return ""
	var candidate: String = root.path_join(relative)
	if FileAccess.file_exists(candidate): return candidate
	var base: String = base_root(root)
	return resolve_file(base, relative, depth + 1) if not base.is_empty() else candidate

static func sha(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	if not data.is_empty(): context.update(data)
	return context.finish().hex_encode()

func install_zip(path: String) -> Dictionary:
	if busy: return {"ok":false, "error":"설치가 이미 진행 중입니다."}
	busy = true
	cancelled = false
	# Resolve and freeze current assets before any install work.
	active_root()
	monster_root()
	var result: Dictionary = await _install(path)
	busy = false
	completed.emit(result)
	return result

# Bound central-directory sizes before ZIPReader allocates an entry. The supported
# bundle has <4096 outer entries, no ZIP64/encryption/symlinks, <=64MiB per blob.
# Source pixels remain individual files inside bounded inventory/data shards.
static func validate_zip(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok":false}
	var length: int = file.get_length()
	if length < 22 or length > 3 * 1024 * 1024 * 1024: return {"ok":false}
	var tail_size: int = mini(length, 65557)
	file.seek(length - tail_size)
	var tail: PackedByteArray = file.get_buffer(tail_size)
	var end: int = -1
	for at: int in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(at) == 0x06054b50 and at + 22 + tail.decode_u16(at + 20) == tail.size():
			end = at
			break
	if end < 0 or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0: return {"ok":false}
	var count: int = tail.decode_u16(end + 10)
	var directory_size: int = tail.decode_u32(end + 12)
	var directory_offset: int = tail.decode_u32(end + 16)
	if count == 0 or count > 4096 or count != tail.decode_u16(end + 8) or directory_size > 2 * 1024 * 1024 or directory_offset + directory_size != length - tail_size + end: return {"ok":false}
	file.seek(directory_offset)
	var central: PackedByteArray = file.get_buffer(directory_size)
	if central.size() != directory_size: return {"ok":false}
	var offset: int = 0
	var entries: Dictionary = {}
	for index: int in range(count):
		if offset + 46 > central.size() or central.decode_u32(offset) != 0x02014b50: return {"ok":false}
		var flags: int = central.decode_u16(offset + 8)
		var method: int = central.decode_u16(offset + 10)
		var size: int = central.decode_u32(offset + 24)
		var name_size: int = central.decode_u16(offset + 28)
		var record_size: int = 46 + name_size + central.decode_u16(offset + 30) + central.decode_u16(offset + 32)
		if offset + record_size > central.size() or flags & 1 or method not in [0, 8] or size > MAX_ENTRY or central.decode_u32(offset + 20) > MAX_ENTRY or central.decode_u32(offset + 42) >= directory_offset: return {"ok":false}
		var name: String = central.slice(offset + 46, offset + 46 + name_size).get_string_from_utf8()
		var mode: int = (central.decode_u32(offset + 38) >> 16) & 0xf000
		if not safe_relative(name) or entries.has(name) or mode == 0xa000: return {"ok":false}
		if name != "pack.json" and not name.begins_with("inventory/") and not name.begins_with("payload/"): return {"ok":false}
		if name == "pack.json" and size > 1024 * 1024: return {"ok":false}
		if name.begins_with("inventory/") and size > 2 * 1024 * 1024: return {"ok":false}
		entries[name] = size
		offset += record_size
	return {"ok":offset == central.size() and entries.has("pack.json"), "entries":entries}

func _install(path: String) -> Dictionary:
	var checked: Dictionary = validate_zip(path)
	if not checked.ok: return _failure("지원되는 안전한 설치 ZIP이 아니거나 파일이 손상됐습니다.")
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return _failure("ZIP 파일을 열지 못했습니다.")
	var header_bytes: PackedByteArray = zip.read_file("pack.json")
	if header_bytes.size() > 1024 * 1024: return _failure("설치 목록이 너무 큽니다.")
	var header: Variant = JSON.parse_string(header_bytes.get_string_from_utf8())
	if not header is Dictionary or int(header.get("schema", 0)) != 2 or header.get("kind", "") not in ["twilight-lineagem-offline-runtime", "twilight-lineagem-offline-runtime-addon", "twilight-lineagem-offline-monsters"] or header.get("source_snapshot", "") != "base508": return _failure("지원되는 base508 설치 팩이 아닙니다.")
	var is_monsters: bool = header.kind == "twilight-lineagem-offline-monsters"
	var store: String = MONSTER_STORE if is_monsters else STORE
	var required: Array = ["manifest.json"] if is_monsters else REQUIRED
	var is_addon: bool = header.kind == "twilight-lineagem-offline-runtime-addon"
	var base: String = active_root() if is_addon else ""
	if is_addon:
		var accepted_bases: Array = [str(header.get("base_manifest_sha256", ""))]
		var alternatives: Variant = header.get("compatible_base_manifest_sha256", [])
		if not alternatives is Array or alternatives.size() > 4: return _failure("증분 기반 목록 오류")
		for fingerprint: Variant in alternatives:
			if not fingerprint is String or fingerprint.length() != 64 or not fingerprint.is_valid_hex_number(false): return _failure("증분 기반 해시 오류")
			accepted_bases.append(fingerprint)
		if not trusted_root(base) or not FileAccess.file_exists(base.path_join("manifest.json")) or not FileAccess.get_sha256(base.path_join("manifest.json")) in accepted_bases:
			return _failure("먼저 이 증분에 맞는 원본 v2 전체팩을 설치하고 게임을 다시 실행하세요.")
		var ancestor: String = base
		for depth: int in range(4): ancestor = base_root(ancestor) if not ancestor.is_empty() else ""
		if not ancestor.is_empty(): return _failure("증분 연결이 너무 깊습니다. 전체팩 설치가 필요합니다.")
	var total: int = int(header.get("files", 0))
	var expected_bytes: int = int(header.get("bytes", 0))
	var chunks: Variant = header.get("chunks", [])
	if total <= 0 or total > MAX_FILES or expected_bytes <= 0 or expected_bytes > MAX_BYTES or not chunks is Array or chunks.is_empty() or chunks.size() > 2048: return _failure("설치 팩 크기 또는 목록이 유효하지 않습니다.")
	if not is_monsters and (int(header.get("sprite_records", 0)) != 743 or int(header.get("card_definitions", 0)) != 701): return _failure("이 게임 버전의 701종 팩이 아닙니다.")
	var storage := DirAccess.open("user://")
	if storage == null or storage.get_space_left() < expected_bytes + total * 4096 + 64 * 1024 * 1024: return _failure("설치 공간이 부족합니다. 기존 팩과 별도로 새 팩 공간이 필요합니다.")
	var stamp: int = int(Time.get_unix_time_from_system() * 1000000)
	var versions := DirAccess.open(store)
	if versions != null:
		for name: String in versions.get_directories():
			var marker_path: String = store.path_join(name).path_join("installed.json")
			if not FileAccess.file_exists(marker_path): continue
			var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(marker_path))
			if previous is Dictionary: stamp = maxi(stamp, int(previous.get("activated_usec", 0)) + 1)
	var id: String = str(stamp) + "-" + str(Time.get_ticks_usec())
	var stage: String = store.path_join("staging-" + id)
	if DirAccess.make_dir_recursive_absolute(stage) != OK: return _failure("임시 설치 폴더를 만들지 못했습니다.")
	progress.emit(0, total)
	await get_tree().process_frame
	var done: int = 0
	var written: int = 0
	var last_yield: int = Time.get_ticks_msec()
	var found: Dictionary = {}
	for chunk: Variant in chunks:
		if not chunk is Dictionary or not str(chunk.get("path", "")).begins_with("inventory/") or not safe_relative(str(chunk.get("path", ""))) or int(chunk.get("bytes", 0)) > 2 * 1024 * 1024: return _failure("검사 목록 경로가 유효하지 않습니다.")
		if int(checked.entries.get(str(chunk.path), -1)) != int(chunk.get("bytes", -2)): return _failure("검사 목록 크기가 다릅니다.")
		var chunk_bytes: PackedByteArray = zip.read_file(str(chunk.path))
		if chunk_bytes.size() != int(chunk.get("bytes", -1)) or sha(chunk_bytes) != str(chunk.get("sha256", "")): return _failure("검사 목록이 손상됐습니다.")
		var rows: Variant = JSON.parse_string(chunk_bytes.get_string_from_utf8())
		if not rows is Array or rows.is_empty() or rows.size() > 1024 or rows.size() != int(chunk.get("count", -1)): return _failure("파일 목록이 유효하지 않습니다.")
		var payload_path: String = str(chunk.get("payload", ""))
		if not payload_path.begins_with("payload/") or not safe_relative(payload_path) or int(chunk.get("payload_bytes", 0)) > MAX_ENTRY: return _failure("데이터 묶음이 유효하지 않습니다.")
		if int(checked.entries.get(payload_path, -1)) != int(chunk.get("payload_bytes", -2)): return _failure("데이터 묶음 크기가 다릅니다.")
		var payload: PackedByteArray = zip.read_file(payload_path)
		if payload.size() != int(chunk.get("payload_bytes", -1)) or sha(payload) != str(chunk.get("payload_sha256", "")): return _failure("데이터 묶음이 손상됐습니다.")
		var offset: int = 0
		for row: Variant in rows:
			if cancelled: return _failure("설치를 중단했습니다. 기존 팩과 세이브는 유지됩니다.")
			if not row is Dictionary: return _failure("잘못된 파일 기록입니다.")
			var relative: String = str(row.get("path", ""))
			var size: int = int(row.get("bytes", -1))
			if not safe_relative(relative) or relative in ["installed.json", "installed.tmp"] or size < 0 or size > MAX_ENTRY: return _failure("안전하지 않은 파일 경로 또는 크기입니다.")
			var target: String = stage.path_join(relative)
			if FileAccess.file_exists(target): return _failure("중복 파일 경로입니다.")
			if int(row.get("offset", -1)) != offset or offset + size > payload.size(): return _failure("데이터 위치가 유효하지 않습니다.")
			var bytes: PackedByteArray = payload.slice(offset, offset + size)
			offset += size
			if bytes.size() != size or sha(bytes) != str(row.get("sha256", "")): return _failure("파일 검사 실패: " + relative)
			if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK: return _failure("설치 폴더 생성 실패.")
			var output := FileAccess.open(target, FileAccess.WRITE)
			if output == null: return _failure("파일 저장 실패: " + relative)
			output.store_buffer(bytes)
			output.flush()
			var error: Error = output.get_error()
			output.close()
			if error != OK: return _failure("저장 공간 또는 파일 쓰기 오류.")
			done += 1
			written += size
			if done > total or written > expected_bytes: return _failure("파일 수 또는 용량이 선언과 다릅니다.")
			if relative in required: found[relative] = true
			if Time.get_ticks_msec() - last_yield >= 40:
				progress.emit(done, total)
				await get_tree().process_frame
				last_yield = Time.get_ticks_msec()
		if offset != payload.size(): return _failure("데이터 묶음의 길이가 다릅니다.")
	zip.close()
	if done != total or written != expected_bytes or found.size() != required.size(): return _failure("필수 파일 또는 전체 파일 수가 일치하지 않습니다.")
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(stage.path_join("manifest.json")))
	if not manifest is Dictionary or int(manifest.get("schema", 0)) != 1 or manifest.get("source_snapshot", "") != "base508" or not manifest.get("records", {}) is Dictionary: return _failure("런타임 선언이 유효하지 않습니다.")
	if is_monsters:
		var old_manifest_path: String = monster_root().path_join("manifest.json")
		if FileAccess.file_exists(old_manifest_path):
			var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(old_manifest_path))
			if old is Dictionary and old.get("source_snapshot", "") == "base508" and old.get("records") is Dictionary:
				for old_id: String in old.records:
					if not manifest.records.has(old_id): return _failure("새 몬스터 팩에 기존 개체가 누락되어 이전 팩을 유지합니다.")
		var validation_error: String = validate_monster_payload(stage, manifest, header)
		if not validation_error.is_empty(): return _failure(validation_error)
	else:
		var sprite_count: int = 0
		for key: String in manifest.records:
			if key.begins_with("sprite:"): sprite_count += 1
		if sprite_count != 743 or manifest.get("card_bindings", {}).size() != 701: return _failure("카드 또는 외형 정의 수가 다릅니다.")
		for record: Variant in manifest.records.values():
			if not record is Dictionary or not safe_relative(str(record.get("manifest", ""))) or not (FileAccess.file_exists(stage.path_join(str(record.manifest))) or (is_addon and FileAccess.file_exists(resolve_file(base, str(record.manifest))))): return _failure("캐릭터 선언이 누락됐습니다.")
	var final_path: String = store.path_join("pack-" + id)
	if DirAccess.rename_absolute(stage, final_path) != OK: return _failure("설치 폴더 전환 실패.")
	var receipt: Dictionary = {"schema":1,"source_snapshot":"base508","release_id":str(header.get("release_id", "")),"activated_usec":stamp,"files":done,"bytes":written,"pack_header_sha256":sha(header_bytes),"base_root":base,"component":"monsters" if is_monsters else "cards"}
	var marker := FileAccess.open(final_path.path_join("installed.tmp"), FileAccess.WRITE)
	if marker == null: return _failure("설치 완료 기록 저장 실패.")
	marker.store_string(JSON.stringify(receipt))
	marker.flush()
	var marker_error: Error = marker.get_error()
	marker.close()
	if marker_error != OK or DirAccess.rename_absolute(final_path.path_join("installed.tmp"), final_path.path_join("installed.json")) != OK: return _failure("설치 완료 기록 전환 실패.")
	progress.emit(done, total)
	return {"ok":true,"root":final_path,"files":done,"restart_required":true}

static func validate_monster_payload(root: String, manifest: Dictionary, header: Dictionary) -> String:
	if manifest.get("kind", "") != "base508_monster_pack": return "지원되는 원본 몬스터 팩이 아닙니다."
	var boss_vfx_error:String=validate_boss_vfx_payload(root,manifest)
	if not boss_vfx_error.is_empty(): return boss_vfx_error
	var ids: Variant = header.get("npc_ids", [])
	if not ids is Array or ids.is_empty() or ids.size() > 9470 or manifest.records.size() != ids.size(): return "몬스터 개체 목록이 유효하지 않습니다."
	var local: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lineagem_base508/monster_bindings.json"))
	if not local is Dictionary or local.get("source_snapshot", "") != "base508": return "몬스터 연결 코드 업데이트가 필요합니다."
	var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/lineagem_base508/monster_batch02/runtime_registry.json")) if FileAccess.file_exists("res://data/lineagem_base508/monster_batch02/runtime_registry.json") else {}
	var definitions: Array = local.get("bindings", []).duplicate(true)
	if extra is Dictionary and extra.get("source_snapshot", "") == "base508":
		definitions.append_array(extra.get("source_id_records", []))
	var catalog = preload("res://scripts/monsters/base508_authoritative_catalog.gd")
	var seen_ids: Dictionary = {}
	var pixels: Dictionary = {}
	var checked_models: Dictionary = {}
	for value: Variant in ids:
		var id: int = int(value)
		if id <= 0 or seen_ids.has(id): return "몬스터 ID가 잘못되거나 중복됐습니다."
		seen_ids[id] = true
		var actor: Variant = manifest.records.get(str(id))
		if not actor is Dictionary or int(actor.get("npc_id", -1)) != id: return "몬스터 원본 ID가 일치하지 않습니다."
		var matched: bool = false
		for binding: Dictionary in definitions:
			if int(binding.npc_id) != id: continue
			var same: bool = true
			for field: String in ["sprite_id", "spawn_view_id", "territory_link_id", "land_id"]:
				if int(actor.get(field, -1)) != int(binding.get(field, -2)): same = false
			if same: matched = true
		var source_row: Dictionary = catalog.npc(id)
		var profile: Dictionary=actor.get("source_actor_profile",{})
		var visual_only: bool=profile.get("contract","")=="base508_source_action_capabilities_v1" and not bool(profile.get("host_combat_ready",true)) and not bool(source_row.get("source_TestNPC",true)) and profile.get("source_category",{})==source_row.get("source_category",{})
		if not matched and (source_row.is_empty() or (not catalog.enemy_eligible(id, true) and not visual_only) or int(actor.get("sprite_id", -1)) != int(source_row.sprite_id)): return "이 몬스터 문맥에 맞는 게임 코드 업데이트가 필요합니다."
		if actor.has("spawn_view_id"):
			var primary_key: String = catalog.context_key(id, int(actor.get("spawn_view_id", -1)), int(actor.get("territory_link_id", -1)))
			var primary: Dictionary = catalog.source_record(primary_key)
			if primary.is_empty() or int(primary.source_m_context.land.ID) != int(actor.get("land_id", -1)): return "몬스터 기본 출현 문맥이 일치하지 않습니다."
		if actor.has("source_contexts"):
			if not actor.source_contexts is Array or actor.source_contexts.is_empty(): return "몬스터 출현 문맥 목록이 유효하지 않습니다."
			for context: Variant in actor.source_contexts:
				if not context is Dictionary: return "몬스터 출현 문맥이 유효하지 않습니다."
				var context_key: String = "lineagem_base508:npc:%d:spawn:%d:territory:%d" % [id, int(context.get("spawn_view_id", -1)), int(context.get("territory_link_id", -1))]
				if catalog.source_record(context_key).is_empty(): return "등록되지 않은 몬스터 출현 문맥입니다."
		var model_key: String = str(int(actor.get("sprite_id", -1))) + ":" + str(actor.get("tracks_ref", "")) + ":" + str(actor.get("tracks_sha256", ""))
		if actor.has("tracks_ref") and checked_models.has(model_key): continue
		var tracks: Variant = actor.get("tracks")
		var capability_contract: int=0
		var partial_direction_contract: int=0
		if actor.has("tracks_ref"):
			var model_path: String = str(actor.tracks_ref)
			if not safe_relative(model_path) or not model_path.begins_with("actors/") or not model_path.ends_with(".json"): return "몬스터 동작 경로가 유효하지 않습니다."
			if FileAccess.get_sha256(root.path_join(model_path)) != str(actor.get("tracks_sha256", "")): return "몬스터 동작 파일 검사 실패"
			var model: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(model_path)))
			if not model is Dictionary or int(model.get("source_sprite_id", -1)) != int(actor.get("sprite_id", -2)): return "몬스터 동작 외형이 일치하지 않습니다."
			tracks = model.get("tracks")
			capability_contract=int(model.get("source_capability_contract",0))
			partial_direction_contract=int(model.get("source_partial_direction_contract",0))
			if capability_contract not in [0,1]: return "지원되지 않는 원본 동작 계약입니다."
			if partial_direction_contract not in [0,1] or (partial_direction_contract==1 and (capability_contract!=1 or bool(profile.get("host_combat_ready",false)))): return "단일 원본 방향을 일반 전투8방향으로 처리할 수 없습니다."
		if not tracks is Dictionary: return "몬스터 동작 목록이 유효하지 않습니다."
		if capability_contract==1 and bool(profile.get("host_combat_ready",false)):
			for required_role: String in ["idle","walk","attack"]:
				if not tracks.has(required_role): return "전투에 필요한 원본 동작이 없습니다."
		var roles: Array=tracks.keys() if capability_contract==1 else ["idle", "walk", "attack", "hit", "death"]
		if roles.is_empty(): return "원본에 연결 가능한 동작이 없습니다."
		for role: String in roles:
			var track: Variant = tracks.get(role)
			if not track is Dictionary or not track.get("directions") is Array or track.directions.size() != 8: return "몬스터 동작 또는8방향이 누락됐습니다."
			var has_source_direction: bool=false
			for frames: Variant in track.directions:
				if not frames is Array or frames.size() > 4096: return "몬스터 프레임 목록이 유효하지 않습니다."
				if frames.is_empty():
					if partial_direction_contract==1: continue
					return "몬스터 프레임 목록이 유효하지 않습니다."
				has_source_direction=true
				var ticks: float = 0.0
				for frame: Variant in frames:
					if not frame is Dictionary or float(frame.get("source_ticks", -1)) < 0.0 or not frame.get("layers") is Array or frame.layers.is_empty() or frame.layers.size() > 8: return "몬스터 원본 프레임이 유효하지 않습니다."
					ticks += float(frame.source_ticks)
					for layer: Variant in frame.layers:
						if not layer is Dictionary: return "몬스터 픽셀 레이어가 유효하지 않습니다."
						var offset: Variant = layer.get("offset")
						if not offset is Array or offset.size() != 2: return "몬스터 원본 offset이 유효하지 않습니다."
						for coordinate: Variant in offset:
							if typeof(coordinate) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(coordinate)): return "몬스터 원본 offset이 유효하지 않습니다."
						var relative: String = str(layer.get("path", ""))
						var packet: bool = layer.get("codec", "") == "base508_sp2_v1"
						var valid_path: bool = (relative.begins_with("sp2/") and relative.ends_with(".bin")) if packet else (relative.begins_with("pixels/") and relative.ends_with(".png"))
						if not safe_relative(relative) or not valid_path: return "몬스터 픽셀 경로가 유효하지 않습니다."
						if packet and (int(layer.get("source_direction_bit", -1)) not in range(8) or int(layer.get("source_frame_index", -1)) not in range(256)): return "몬스터 원본 프레임 주소가 유효하지 않습니다."
						var hash: String = str(layer.get("sha256", ""))
						if pixels.has(relative):
							if pixels[relative] != hash: return "같은 몬스터 픽셀의 해시가 서로 다릅니다."
						else:
							if hash.length() != 64 or not FileAccess.file_exists(root.path_join(relative)) or FileAccess.get_sha256(root.path_join(relative)) != hash: return "몬스터 픽셀 검사 실패: " + relative
							pixels[relative] = hash
				if ticks <= 0.0 and not (capability_contract==1 and bool(track.get("source_static_zero_duration",false)) and frames.size()==1): return "몬스터 원본 시간값이 유효하지 않습니다."
			if not has_source_direction: return "실제 원본 방향 프레임이 없습니다."
		checked_models[model_key] = true
	return ""

static func _boss_vfx_hash(root:String,relative:String,hash_value:Variant,prefix:String) -> bool:
	if not safe_relative(relative) or not relative.begins_with(prefix) or not hash_value is String or hash_value.length()!=64:return false
	for index:int in range(hash_value.length()):
		if not hash_value.substr(index,1) in "0123456789abcdef":return false
	return FileAccess.file_exists(root.path_join(relative)) and FileAccess.get_sha256(root.path_join(relative))==hash_value

static func validate_boss_vfx_payload(root:String,manifest:Dictionary) -> String:
	# Optional private effects. Incomplete declared source compositions are
	# retained, while every included file and frame reference must be intact.
	if not manifest.has("boss_vfx"):return ""
	var reference:Variant=manifest.boss_vfx
	if not reference is Dictionary or reference.get("path","")!="boss_vfx/boss_vfx.json":return "보스 효과 목록 경로가 유효하지 않습니다."
	if not _boss_vfx_hash(root,reference.path,reference.get("sha256"),"boss_vfx/"):return "보스 효과 목록 해시 검사 실패"
	var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join(reference.path)))
	if not data is Dictionary or data.get("kind","")!="base508_boss_literal_sp2_effects" or data.get("source_snapshot","")!="base508":return "지원되는 원본 보스 효과가 아닙니다."
	var models:Variant=data.get("models");var sources:Variant=data.get("source_files")
	if not models is Dictionary or models.is_empty() or models.size()>9470 or not sources is Dictionary or sources.is_empty() or sources.size()>50000:return "보스 효과 파일 목록이 유효하지 않습니다."
	var packets:Dictionary={}
	for source:Variant in sources.values():
		if not source is Dictionary or not source.get("path") is String:return "보스 효과 픽셀 참조가 유효하지 않습니다."
		var relative:String=source.path;var hash_value:Variant=source.get("sha256")
		if not relative.ends_with(".bin") or not _boss_vfx_hash(root,"boss_vfx/"+relative,hash_value,"boss_vfx/sp2/"):return "보스 효과 픽셀 검사 실패: "+relative
		if packets.has(relative) and packets[relative]!=hash_value:return "보스 효과 픽셀 해시가 서로 다릅니다."
		packets[relative]=hash_value
	for key:Variant in models:
		if not key is String or not key.is_valid_int() or int(key)<=0 or str(int(key))!=key:return "보스 효과 원본 ID가 유효하지 않습니다."
		var model_reference:Variant=models[key]
		if not model_reference is Dictionary or not model_reference.get("path") is String:return "보스 효과 동작 참조가 유효하지 않습니다."
		var relative:String=model_reference.path
		if not relative.ends_with(".json") or not _boss_vfx_hash(root,"boss_vfx/"+relative,model_reference.get("sha256"),"boss_vfx/effects/"):return "보스 효과 동작 검사 실패"
		var model:Variant=JSON.parse_string(FileAccess.get_file_as_string(root.path_join("boss_vfx/"+relative)))
		if not model is Dictionary or model.get("source_snapshot","")!="base508" or model.get("source_sprite_id",-1)!=float(int(key)):return "보스 효과 원본 외형이 일치하지 않습니다."
		var tracks:Variant=model.get("tracks")
		if not tracks is Dictionary or tracks.is_empty():return "보스 효과 동작 목록이 유효하지 않습니다."
		for track:Variant in tracks.values():
			if not track is Dictionary or track.get("source_sprite_id",-1)!=float(int(key)) or track.get("source_action_id",-1)!=0.0:return "보스 효과 원본 동작이 일치하지 않습니다."
			var directions:Variant=track.get("directions")
			if not directions is Array or directions.size()!=8:return "보스 효과 방향 목록이 유효하지 않습니다."
			var has_frame:bool=false
			for frames:Variant in directions:
				if not frames is Array or frames.size()>4096:return "보스 효과 프레임 목록이 유효하지 않습니다."
				for frame:Variant in frames:
					has_frame=true
					if not frame is Dictionary or not frame.get("layers") is Array or frame.layers.is_empty() or frame.layers.size()>8:return "보스 효과 레이어가 유효하지 않습니다."
					for layer:Variant in frame.layers:
						if not layer is Dictionary or not layer.get("path") is String or layer.get("codec","")!="base508_sp2_v1":return "보스 효과 원본 픽셀 참조가 유효하지 않습니다."
						if not packets.has(layer.path) or packets[layer.path]!=layer.get("sha256"):return "목록에 없는 보스 효과 픽셀입니다."
			if not has_frame:return "보스 효과 원본 프레임이 없습니다."
	return ""

func _failure(message: String) -> Dictionary:
	return {"ok":false,"error":message,"previous_pack_preserved":true}
