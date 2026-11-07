extends Node
## Install-time selection bridge. Register this as the first autoload.
## It runs before Main is instantiated and before lazy source readers cache input.
## Original pixels, source manifests and game saves are never changed here.
const POINTER = "res://twilight_private_install.json"
const MAP_SETTINGS = "user://current523_aden_play.cfg"
const MAP_STATIC_SETTINGS = "user://current523_map_static_spr.cfg"
const MAP_DEFINITIONS_SETTINGS = "user://current523_source_definitions.cfg"
const MAP_SP2_REGISTRY = "results/all989_actual_current_M_SP2_registry.json"
const MAP_SP2_REGISTRY_SHA = "8e22a6b5a2a9cc32a5f5cced0c6d0fb090127c7d7bdb1ba49acfb06615685247"
const SPR_MANIFEST = "results/all_current_global_declarations.json"
const SPR_MANIFEST_SHA = "91bbf7d8e63a8407ad5489a0dbb228f9da50a5e1183e7b6960e9916db8ccd5ea"
const SPR_TEXT_SHA = "4426a6a7ec09c61152d04575b829b84846b342275c35ddad4ce9498759de285a"
const SPR_GRAPH_SHA = "8e54942a4c51f5f166c8fc9861f2ec7c1a2bf5f07db315600bd0d291cba1d487"
const MAP_DEFINITIONS_SHA = "2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const BANK_SETTINGS = "user://current523_source_bank.json"
const GENERIC_MAP = "CURRENT523_GENERIC_S32_OWN_ALLOWLIST_V1"
const TABLES_BYTES: int = 25031173
const TABLES_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const TABLE_INSTALL_PATHS = ["user://growth96_definitions/source.zip","user://source_rules/death523.zip","user://title523/source.zip","user://source_rules/relic-patch523.zip"]
const MAX_DESCRIPTOR_BYTES: int = 2 * 1024 * 1024
var _problem: String = ""
var _base: String = ""

func _init() -> void:
	if not FileAccess.file_exists(POINTER): return
	var result: Dictionary = _prepare()
	if not result.get("ok",false):
		push_error("비공개 원본 자동 연결을 적용하지 못했습니다: " + _problem)
		return
	if not _commit_writes(result.writes):
		push_error("비공개 원본 설정을 적용하지 못했습니다: " + _problem)
		return
	for key: String in result.environment:
		OS.set_environment(key,str(result.environment[key]))
	print("비공개 원본 경로 설정 준비 완료. 실제 게임 사용과 Android 동작은 별도 확인이 필요합니다.")

func _fail(reason: String) -> Dictionary:
	_problem = reason
	return {"ok":false}

func _sha(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for offset: int in value.length():
		if not "0123456789abcdefABCDEF".contains(value.substr(offset,1)): return false
	return true

func _integer(value: Variant, maximum: int = 2147483647) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= 0 and value <= maximum

func _absolute(value: Variant) -> String:
	if not value is String or value.is_empty() or value.length() > 4096 or value.to_utf8_buffer().has(0): return ""
	var path: String = value
	if path.begins_with("res://") or path.begins_with("user://"):
		path = ProjectSettings.globalize_path(path)
	elif not path.is_absolute_path():
		path = _base.path_join(path)
	path = path.simplify_path()
	return path if path.is_absolute_path() else ""

func _json_file(path: String, maximum: int = MAX_DESCRIPTOR_BYTES) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() < 2 or file.get_length() > maximum:
		return _fail("필요한 원본 설정 또는 manifest를 읽을 수 없습니다.")
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not value is Dictionary: return _fail("원본 설정 또는 manifest의 JSON 형식이 다릅니다.")
	return {"ok":true,"value":value}

func _pinned(path: String, pin: Variant) -> bool:
	if path.is_empty() or not _sha(pin) or not FileAccess.file_exists(path):
		_problem = "필요한 원본 manifest 경로와 SHA256이 준비되지 않았습니다."
		return false
	if FileAccess.get_sha256(path) != str(pin).to_lower():
		_problem = "원본 manifest가 공식 인계 SHA256과 다릅니다."
		return false
	return true

func _prepare() -> Dictionary:
	_base = ProjectSettings.globalize_path("res://")
	var read: Dictionary = _json_file(POINTER)
	if not read.get("ok",false): return read
	var descriptor: Dictionary = read.value
	if descriptor.get("schema") != 1: return _fail("자동 설치 설정 schema가 다릅니다.")
	if descriptor.has("descriptor_path") or descriptor.has("descriptor_sha256"):
		var target: String = _absolute(descriptor.get("descriptor_path"))
		if not _pinned(target,descriptor.get("descriptor_sha256")): return {"ok":false}
		read = _json_file(target)
		if not read.get("ok",false): return read
		descriptor = read.value
		_base = target.get_base_dir()
		if descriptor.get("schema") != 1: return _fail("비공개 인계 설정 schema가 다릅니다.")
	var environment: Dictionary = {}
	var writes: Array[Dictionary] = []
	var prepared_main_ui_selected: bool = false
	if descriptor.has("tables_zip"):
		var tables: String = _absolute(descriptor.tables_zip)
		if not _pinned(tables,TABLES_SHA): return {"ok":false}
		var table_file := FileAccess.open(tables,FileAccess.READ)
		if table_file == null or table_file.get_length() != TABLES_BYTES:
			return _fail("공식 원본523 정의 ZIP의 바이트 크기가 다릅니다.")
		table_file.close()
		environment.TWILIGHT_PATCH523_CONTENT = tables
		# Current readers share this original archive environment. Retain these
		# same-byte copies for older fixed-path consumers; current source readers
		# need only the one ZIP above, never a generated or substituted pack.
		for installed: String in TABLE_INSTALL_PATHS:
			if descriptor.get("legacy_table_copies",true) == false: break
			if FileAccess.file_exists(installed) and FileAccess.get_sha256(installed) == TABLES_SHA: continue
			writes.append({"path":installed,"source":tables,"source_sha256":TABLES_SHA})
	if descriptor.has("images"):
		if not descriptor.images is Dictionary: return _fail("이미지 선택 설정 형식이 다릅니다.")
		var image: Dictionary = descriptor.images
		var image_root: String = _absolute(image.get("root"))
		if image_root.is_empty(): return _fail("원본 이미지 팩의 명시적 경로가 없습니다.")
		if not _pinned(image_root.path_join("manifest.json"),image.get("manifest_sha256")): return {"ok":false}
		environment.TWILIGHT_SOURCE523_IMAGES = image_root
		environment.TWILIGHT_SOURCE523_IMAGES_SHA256 = str(image.manifest_sha256).to_lower()
	if descriptor.has("main_ui"):
		if not descriptor.main_ui is Dictionary: return _fail("메인 원본 UI 선택 설정 형식이 다릅니다.")
		var ui_selection: Dictionary = _prepare_main_ui(descriptor.main_ui)
		if not ui_selection.get("ok",false): return ui_selection
		environment.merge(ui_selection.environment)
		prepared_main_ui_selected = ui_selection.selected_input
	if descriptor.has("world_map"):
		if not descriptor.world_map is Dictionary: return _fail("월드 지도 선택 설정 형식이 다릅니다.")
		var world_map_request: Dictionary = descriptor.world_map.duplicate(true)
		if not prepared_main_ui_selected: world_map_request.ready_for_fresh_install = false
		var world_map_write: Dictionary = _prepare_world_map(world_map_request)
		if not world_map_write.get("ok",false): return world_map_write
		if world_map_write.has("write"): writes.append(world_map_write.write)
	if descriptor.has("ui_icons"):
		if not descriptor.ui_icons is Dictionary: return _fail("원본 UI 아이콘 선택 설정 형식이 다릅니다.")
		var icons: Dictionary = descriptor.ui_icons
		var selection: String = _absolute(icons.get("path"))
		if not _pinned(selection,icons.get("sha256")): return {"ok":false}
		read = _json_file(selection)
		if not read.get("ok",false): return read
		var selected: Dictionary = read.value
		if selected.get("schema") != "source523-original-ui-icon-selection-v1" or not selected.get("packs") is Array or selected.packs.is_empty():
			return _fail("공식 원본 UI 아이콘 선택 계약이 다릅니다.")
		for request: Variant in selected.packs:
			if not request is Dictionary or not request.get("root") is String or request.root.is_empty():
				return _fail("원본 UI 부분 팩의 명시적 경로가 없습니다.")
			var pack_root: String = str(request.root)
			if pack_root.begins_with("res://") or pack_root.begins_with("user://"):
				pack_root = ProjectSettings.globalize_path(pack_root)
			elif not pack_root.is_absolute_path():
				pack_root = selection.get_base_dir().path_join(pack_root)
			if not _pinned(pack_root.simplify_path().path_join("original_ui.json"),request.get("manifest_sha256")): return {"ok":false}
		environment.TWILIGHT_SOURCE523_UI_ICONS = selection
		environment.TWILIGHT_SOURCE523_UI_ICONS_SHA256 = str(icons.sha256).to_lower()
	if descriptor.has("maps"):
		if not descriptor.maps is Dictionary: return _fail("원본 맵 설정 형식이 다릅니다.")
		var map_write: Dictionary = _prepare_maps(descriptor.maps)
		if not map_write.get("ok",false): return map_write
		if map_write.has("write"): writes.append(map_write.write)
	if descriptor.has("map_static_spr"):
		if not descriptor.map_static_spr is Dictionary: return _fail("맵 배치 SPR 설정 형식이 다릅니다.")
		var static_write: Dictionary = _prepare_map_static_spr(descriptor.map_static_spr)
		if not static_write.get("ok",false): return static_write
		if static_write.has("write"): writes.append(static_write.write)
	if descriptor.has("map_definitions"):
		if not descriptor.map_definitions is Dictionary: return _fail("원본 맵 정의 설정 형식이 다릅니다.")
		var definitions_write: Dictionary = _prepare_map_definitions(descriptor.map_definitions)
		if not definitions_write.get("ok",false): return definitions_write
		if definitions_write.has("write"): writes.append(definitions_write.write)
	if descriptor.has("source_bank"):
		if not descriptor.source_bank is Dictionary: return _fail("원본 Sprite 은행 설정 형식이 다릅니다.")
		var bank_write: Dictionary = _prepare_bank(descriptor.source_bank)
		if not bank_write.get("ok",false): return bank_write
		if bank_write.has("write"): writes.append(bank_write.write)
	# A desktop user's explicit existing selection retains precedence. A paired
	# mismatch fails before any setting file or process environment is changed.
	for key: String in environment:
		var existing: String = OS.get_environment(key)
		if not existing.is_empty() and existing != str(environment[key]):
			return _fail("이미 명시적으로 선택한 원본 경로와 자동 설치 설정이 충돌합니다: " + key)
	return {"ok":true,"writes":writes,"environment":environment}

func _prepare_main_ui(value: Dictionary) -> Dictionary:
	var root: String = _absolute(value.get("root"))
	if root.is_empty(): return _fail("메인 원본 UI 팩의 명시적 경로가 없습니다.")
	var explicit_root: String = OS.get_environment("TWILIGHT_SOURCE_UI")
	var explicit_pin: String = OS.get_environment("TWILIGHT_SOURCE_UI_SHA256")
	var explicit_choice: bool = not explicit_root.is_empty() or not explicit_pin.is_empty()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-ui="):
			explicit_choice = true
			explicit_root = argument.trim_prefix("--source-ui=")
		elif argument.begins_with("--source-ui-sha256="):
			explicit_choice = true
			explicit_pin = argument.trim_prefix("--source-ui-sha256=")
	# Preserve even a partial explicit pair; never complete it with an unrelated
	# default pin/root. The existing selection owner reports invalid pairs.
	var matches_input: bool = _absolute(explicit_root) == root and explicit_pin.to_lower() == str(value.get("manifest_sha256","")).to_lower()
	if explicit_choice and not matches_input:
		print("기존 명시 원본 UI 선택을 보존했습니다. 설치 기본 선택으로 교체하지 않습니다.")
		return {"ok":true,"environment":{},"selected_input":false}
	var manifest: String = root.path_join("original_ui.json")
	if not _pinned(manifest,value.get("manifest_sha256")): return {"ok":false}
	var read: Dictionary = _json_file(manifest,128 * 1024 * 1024)
	if not read.get("ok",false): return read
	var document: Dictionary = read.value
	if document.get("schema") != "twilight-original-ui-v1" or not document.get("scenes") is Dictionary or not document.get("files") is Dictionary or not document.get("atlases") is Dictionary:
		return _fail("메인 원본 UI 팩의 공개 계약이 다릅니다.")
	if not document.get("blockers") is Array or not document.blockers.is_empty():
		return _fail("메인 원본 UI 팩에 미해결 입력이 있습니다.")
	if value.has("expected_composition"):
		var expected: Variant = value.expected_composition
		var composition: Variant = document.get("selection_contract")
		if not expected is Dictionary or not composition is Dictionary: return _fail("정식 결합 UI 선택 계약이 없습니다.")
		for key: String in ["schema","mode","extends_manifest_sha256"]:
			if composition.get(key) != expected.get(key): return _fail("정식 결합 UI 선택 계약이 인계와 다릅니다.")
		if not composition.has("retained_base_files") or not composition.has("retained_base_node_scopes"):
			return _fail("기존 원본 UI 보존 선언이 없습니다.")
		# Retention metadata stays opaque under the original manifest hash.
	var environment: Dictionary = {}
	if not explicit_choice:
		environment.TWILIGHT_SOURCE_UI = root
		environment.TWILIGHT_SOURCE_UI_SHA256 = str(value.manifest_sha256).to_lower()
	return {"ok":true,"environment":environment,"selected_input":true}

func _land_available(document: Dictionary, land_id: int) -> bool:
	if not document.get("logical_lands") is Array: return false
	for entry: Variant in document.logical_lands:
		if not entry is Dictionary or not entry.get("declaration") is Dictionary: continue
		if entry.declaration.get("ID") != land_id: continue
		# Existing runtime applies the full original/content admission policy.
		# The bridge cannot auto-enable a source-declared excluded destination.
		return entry.get("excluded_content") is Array and entry.excluded_content.is_empty()
	return false

func _prepare_maps(value: Dictionary) -> Dictionary:
	var raw_root: String = _absolute(value.get("raw_root"))
	var tile_root: String = _absolute(value.get("tile_root"))
	if raw_root.is_empty() or tile_root.is_empty(): return _fail("원본 맵과 타일 경로가 없습니다.")
	if not _pinned(raw_root.path_join("source523.json"),value.get("source_manifest_sha256")): return {"ok":false}
	if not _pinned(tile_root.path_join("tilepack523.json"),value.get("tile_manifest_sha256")): return {"ok":false}
	var read: Dictionary = _json_file(raw_root.path_join("source523.json"),24 * 1024 * 1024)
	if not read.get("ok",false): return read
	var source: Dictionary = read.value
	if source.get("schema") != 1 or source.get("kind") != "current523_s32_source_pack" or source.get("edition") != "LineageM" or source.get("cumulative_version") != 523:
		return _fail("전체 current523 원본 맵 카탈로그가 아닙니다.")
	var config := ConfigFile.new()
	var error: Error = config.load(MAP_SETTINGS)
	if error != OK and error != ERR_FILE_NOT_FOUND: return _fail("기존 원본 맵 설정을 읽을 수 없어 보존했습니다.")
	var old: Dictionary = {}
	if config.has_section("play"):
		for key: String in config.get_section_keys("play"):
			old[key] = config.get_value("play",key)
	var same_source: bool = old.get("source_manifest_sha256") == str(value.source_manifest_sha256).to_lower() and old.get("tile_manifest_sha256") == str(value.tile_manifest_sha256).to_lower()
	var land: int = -1
	if same_source and _integer(old.get("native_land_id")) and _land_available(source,int(old.native_land_id)):
		land = int(old.native_land_id)
	elif value.has("native_land_id"):
		if not _integer(value.native_land_id) or not _land_available(source,int(value.native_land_id)):
			return _fail("지정된 원본 Land가 카탈로그에 없거나 제외 대상입니다.")
		land = int(value.native_land_id)
	# Root/pin preparation does not authorize guessing a destination or cursor.
	if land < 0: return _fail("원본 맵의 초기 native_land_id가 공식 설치 설정에 없습니다.")
	var next: Dictionary = {"raw_root":raw_root,"tile_root":tile_root,"source_manifest_sha256":str(value.source_manifest_sha256).to_lower(),"tile_manifest_sha256":str(value.tile_manifest_sha256).to_lower(),"native_land_id":land}
	if not same_source:
		next.enabled = true
		next.navigation_profile = GENERIC_MAP
		# No source_position is created. Existing source runtime owns entry choice.
		# A saved cursor from a different source identity must not be adopted.
		next.source_position = []
	var changed: bool = false
	for key: String in next:
		if not old.has(key) or old[key] != next[key]: changed = true
		config.set_value("play",key,next[key])
	if not changed: return {"ok":true}
	return {"ok":true,"write":{"path":MAP_SETTINGS,"bytes":config.encode_to_text().to_utf8_buffer()}}

func _declaration_root(path: String) -> String:
	if DirAccess.dir_exists_absolute(path.path_join("SPR_reference_closure")):
		return path.path_join("SPR_reference_closure")
	return path

func _prepare_map_static_spr(value: Dictionary) -> Dictionary:
	var root: String = _absolute(value.get("source_root"))
	var declared: String = _absolute(value.get("declaration_path"))
	if root.is_empty() or declared.is_empty(): return _fail("989 맵 SPR와 원문 선언의 경로가 없습니다.")
	if not _sha(value.get("registry_sha256")) or str(value.registry_sha256).to_lower() != MAP_SP2_REGISTRY_SHA:
		return _fail("989 맵 SPR registry의 공식 고정 SHA256이 다릅니다.")
	if not _sha(value.get("declaration_manifest_sha256")) or str(value.declaration_manifest_sha256).to_lower() != SPR_MANIFEST_SHA:
		return _fail("30개 원문 SPR 선언의 공식 고정 SHA256이 다릅니다.")
	var registry: String = root.path_join(MAP_SP2_REGISTRY)
	if value.has("registry_path") and _absolute(value.registry_path) != registry:
		return _fail("989 맵 SPR registry의 고정 상대 경로가 다릅니다.")
	declared = _declaration_root(declared)
	if not _pinned(registry,MAP_SP2_REGISTRY_SHA): return {"ok":false}
	if not _pinned(declared.path_join(SPR_MANIFEST),SPR_MANIFEST_SHA): return {"ok":false}
	if not _pinned(declared.path_join("results/all_current_text_integrity.json"),SPR_TEXT_SHA): return {"ok":false}
	if not _pinned(declared.path_join("results/complete_source_reference_graph.json"),SPR_GRAPH_SHA): return {"ok":false}
	return _prepare_selection_config(MAP_STATIC_SETTINGS,"display",{"source_root":root,"declaration_path":declared},["source_root","declaration_path"])

func _prepare_map_definitions(value: Dictionary) -> Dictionary:
	var directory: String = _absolute(value.get("directory"))
	if directory.is_empty(): return _fail("원본 world-links 정의 폴더가 없습니다.")
	if not _sha(value.get("manifest_sha256")) or str(value.manifest_sha256).to_lower() != MAP_DEFINITIONS_SHA:
		return _fail("world-links 원본 정의의 공식 고정 SHA256이 다릅니다.")
	if not _pinned(directory.path_join("manifest.json"),MAP_DEFINITIONS_SHA): return {"ok":false}
	return _prepare_selection_config(MAP_DEFINITIONS_SETTINGS,"definitions",{"directory":directory,"manifest_sha256":MAP_DEFINITIONS_SHA},["manifest_sha256"],16384)

func _prepare_selection_config(path: String, section: String, next: Dictionary, identity_keys: Array, maximum: int = 0) -> Dictionary:
	if maximum > 0 and FileAccess.file_exists(path):
		var previous := FileAccess.open(path,FileAccess.READ)
		if previous == null or previous.get_length() < 1 or previous.get_length() > maximum:
			return _fail("기존 원본 연결 설정 크기가 공개 계약과 달라 보존했습니다.")
		previous.close()
	var config := ConfigFile.new()
	var error: Error = config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND: return _fail("기존 원본 연결 설정을 읽을 수 없어 보존했습니다.")
	var same_identity: bool = error == OK
	for key: String in identity_keys:
		if config.get_value(section,key,null) != next[key]: same_identity = false
	var enabled: Variant = config.get_value(section,"enabled",true)
	if not enabled is bool: return _fail("기존 원본 연결의 활성 상태가 잘못되어 보존했습니다.")
	next.enabled = enabled if same_identity else true
	var changed: bool = false
	for key: String in next:
		if config.get_value(section,key,null) != next[key]: changed = true
		config.set_value(section,key,next[key])
	if not changed: return {"ok":true}
	var bytes: PackedByteArray = config.encode_to_text().to_utf8_buffer()
	if maximum > 0 and bytes.size() > maximum: return _fail("새 원본 연결 설정이 공개 크기 한도를 넘었습니다.")
	return {"ok":true,"write":{"path":path,"bytes":bytes}}

func _world_map_prerequisites(value: Dictionary) -> bool:
	# Evidence describes the actual installed source bytes, not assumed PR merges.
	if value.get("ready_for_fresh_install",false) != true: return false
	if not value.has("enabled") or not value.enabled is bool: return false
	var code: Variant = value.get("code_contract")
	var inputs: Variant = value.get("input_contract")
	if not code is Dictionary or code.get("ready") != true or not code.get("files") is Dictionary or code.files.is_empty(): return false
	if not inputs is Dictionary or inputs.get("ready") != true or not inputs.get("files") is Dictionary or inputs.files.is_empty(): return false
	if code.get("requires_mouse_emulation",false) and not bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch",false)): return false
	for key: String in ["main_ui_manifest","image_manifest","image_dummy"]:
		if not inputs.files.has(key): return false
	var offers: Variant = value.get("offered_worlds")
	if not offers is Dictionary or offers.is_empty(): return false
	for land: String in offers:
		if not offers[land] is Dictionary or not _integer(offers[land].get("world_id")) or int(offers[land].world_id) <= 0: return false
		if not inputs.files.has("world_image:"+str(int(offers[land].world_id))): return false
	for name: String in code.files:
		if name != "project.godot" and not name.begins_with("scripts/"): return false
		if name.contains(":") or name.contains("\\") or name.split("/").has(".."): return false
		if not _pinned(ProjectSettings.globalize_path("res://"+name),code.files[name]): return false
	for key: String in inputs.files:
		var entry: Variant = inputs.files[key]
		if not entry is Dictionary or not _pinned(_absolute(entry.get("path")),entry.get("sha256")): return false
	return true

func _prepare_world_map(value: Dictionary) -> Dictionary:
	var settings: String = "user://current523_world_map.cfg"
	# A preexisting selection, including malformed or disabled data, belongs to
	# the user. Do not read, normalize, relocate or overwrite any of its bytes.
	if FileAccess.file_exists(settings) or DirAccess.dir_exists_absolute(settings): return {"ok":true}
	var user_directory := DirAccess.open("user://")
	if user_directory != null and user_directory.is_link("current523_world_map.cfg"): return {"ok":true}
	if not _world_map_prerequisites(value):
		print("월드 지도 자동 연결 대기: 설치 코드와 원본 입력의 계약이 준비되면 새 설정을 생성합니다. 기존 설정은 보존합니다.")
		# Do not create a disabled placeholder: a later compatible update must be
		# able to activate this still-absent cfg without replacing user settings.
		return {"ok":true}
	var contract: String = _absolute(value.get("contract_path"))
	var contract_pin: Variant = value.get("contract_sha256")
	if not _pinned(contract,contract_pin): return {"ok":false}
	var file := FileAccess.open(contract,FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > 4 * 1024 * 1024:
		return _fail("월드 지도 원본 관계 파일의 공개 크기 한도와 접근 상태를 확인하세요.")
	var document: Variant = JSON.parse_string(file.get_as_text().trim_prefix(String.chr(0xfeff)))
	file.close()
	if not document is Dictionary or not document.get("image_infos") is Array:
		return _fail("월드 지도 원본 관계 문서의 image_infos 계약이 다릅니다.")
	var enabled: Variant = value.enabled
	if not enabled is bool: return _fail("월드 지도 연결의 활성 선택은 명시적인 bool이어야 합니다.")
	var offered: Variant = value.get("offered_worlds")
	if not offered is Dictionary: return _fail("월드 지도는 명시적으로 공급된 Land별 World 선택이 필요합니다.")
	var offers: Dictionary = {}
	for land: Variant in offered:
		if not land is String or not land.is_valid_int() or str(land.to_int()) != land or not _integer(land.to_int()):
			return _fail("월드 지도 offer의 Land ID는 정확한 10진수 String이어야 합니다.")
		var offer: Variant = offered[land]
		if not offer is Dictionary or not _integer(offer.get("world_id")) or int(offer.world_id) == 0:
			return _fail("월드 지도 offer에는 명시적인 양의 UIMapWorld.ID가 필요합니다.")
		var selected: Dictionary = {"world_id":int(offer.world_id)}
		if offer.has("label"):
			if not offer.label is String or offer.label.is_empty():
				return _fail("명시한 월드 지도 label은 실제 비어 있지 않은 String이어야 합니다.")
			selected.label = offer.label
		# Omitting label leaves the exact source World's Name lookup to its
		# existing owner. The bridge never creates a display name or first offer.
		offers[land] = selected
	var policy: Variant = value.get("coordinate_policy","OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1")
	if policy != "OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1":
		return _fail("월드 지도의 기존 자체 좌표 정책만 연결할 수 있습니다.")
	var ratio: Variant = value.get("ratio_scale",1.0)
	if not (ratio is int or ratio is float) or not is_finite(float(ratio)) or ratio <= 0 or ratio > 1000000:
		return _fail("월드 지도 ratio_scale이 기존 자체 정책 범위를 벗어났습니다.")
	var anchor: Variant = value.get("source_anchor_offset",[0.5,0.5])
	if not anchor is Array or anchor.size() != 2:
		return _fail("월드 지도 source_anchor_offset에는 원본 셀 기준 두 수가 필요합니다.")
	for number: Variant in anchor:
		if not (number is int or number is float) or not is_finite(float(number)) or absf(float(number)) > 1:
			return _fail("월드 지도 source_anchor_offset이 기존 자체 정책 범위를 벗어났습니다.")
	var config := ConfigFile.new()
	config.set_value("world_map","enabled",enabled)
	config.set_value("world_map","contract_path",contract)
	config.set_value("world_map","contract_sha256",str(contract_pin).to_lower())
	config.set_value("world_map","offered_worlds",offers)
	config.set_value("world_map","coordinate_policy",policy)
	config.set_value("world_map","ratio_scale",float(ratio))
	config.set_value("world_map","source_anchor_offset",anchor.duplicate())
	return {"ok":true,"write":{"path":settings,"bytes":config.encode_to_text().to_utf8_buffer(),"create_only":true}}

func _prepare_bank(value: Dictionary) -> Dictionary:
	# Settings and explicit CLI selections belong to the user even when disabled
	# or malformed. Never relocate/replace them while adopting a new bank.
	if _settings_path_exists(BANK_SETTINGS): return {"ok":true}
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--current523-source-bank-config="): return {"ok":true}
	var code: Variant = value.get("code_contract")
	if value.get("ready_for_fresh_install") != true or not code is Dictionary or code.get("ready") != true or not code.get("files") is Dictionary or code.files.is_empty():
		print("Sprite 은행 자동 연결 대기: 원본 준비와 설치 대상 소비 코드 통합은 별도입니다. 기존 설정은 보존합니다.")
		return {"ok":true}
	for name: String in code.files:
		if not name.begins_with("scripts/") or name.contains(":") or name.contains("\\") or name.split("/").has(".."):
			return _fail("Sprite 은행 소비 코드의 경로 계약이 다릅니다.")
		if not _pinned(ProjectSettings.globalize_path("res://"+name),code.files[name]): return {"ok":false}
	if value.get("schema") != 1 or value.get("enabled") != true or value.get("source_snapshot") != "patch523":
		return _fail("원본 Sprite 은행의 공개 설정 계약이 다릅니다.")
	var inputs: Variant = value.get("input_files")
	if not inputs is Dictionary or not inputs.has("manifest"): return _fail("Sprite 은행의 원본 입력 근거가 없습니다.")
	for name: String in inputs:
		var entry: Variant = inputs[name]
		if not entry is Dictionary or not _pinned(_absolute(entry.get("path")),entry.get("sha256")): return {"ok":false}
	var result: Dictionary = {"schema":1,"enabled":true,"source_snapshot":"patch523"}
	for key: String in ["tables_zip","manifest_path"]:
		result[key] = _absolute(value.get(key))
		if str(result[key]).is_empty(): return _fail("원본 Sprite 은행의 경로가 없습니다.")
	if not _pinned(result.tables_zip,TABLES_SHA): return {"ok":false}
	if not _pinned(result.manifest_path,value.get("manifest_sha256")): return {"ok":false}
	result.manifest_sha256 = str(value.manifest_sha256).to_lower()
	if value.has("overlay_whitelist_path") or value.has("overlay_whitelist_sha256"):
		result.overlay_whitelist_path = _absolute(value.get("overlay_whitelist_path"))
		if not _pinned(result.overlay_whitelist_path,value.get("overlay_whitelist_sha256")): return {"ok":false}
		result.overlay_whitelist_sha256 = str(value.overlay_whitelist_sha256).to_lower()
	return {"ok":true,"write":{"path":BANK_SETTINGS,"bytes":(JSON.stringify(result,"\t",true)+"\n").to_utf8_buffer(),"create_only":true}}

func _cleanup_pending(staged: Array[Dictionary]) -> void:
	for item: Dictionary in staged:
		if FileAccess.file_exists(item.temporary): DirAccess.remove_absolute(item.temporary)

func _settings_path_exists(path: String) -> bool:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path): return true
	var directory := DirAccess.open(path.get_base_dir())
	return directory != null and directory.is_link(path.get_file())

func _commit_writes(writes: Array) -> bool:
	var staged: Array[Dictionary] = []
	# Stage and preserve every old configuration before publishing any replacement.
	for write: Dictionary in writes:
		var path: String = ProjectSettings.globalize_path(str(write.path))
		if write.get("create_only",false) and _settings_path_exists(path): continue
		var suffix: String = str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
		var item: Dictionary = {"path":path,"temporary":path+".private-source-pending-"+suffix,"backup":"","existed":FileAccess.file_exists(path),"create_only":bool(write.get("create_only",false))}
		if DirAccess.dir_exists_absolute(path):
			_problem = "설정 파일 위치에 기존 폴더가 있어 보존했습니다."
			_cleanup_pending(staged)
			return false
		var parent_error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		if parent_error != OK:
			_problem = "원본 설정 폴더를 준비할 수 없습니다."
			_cleanup_pending(staged)
			return false
		staged.append(item)
		var write_error: Error = OK
		if write.has("source"):
			write_error = DirAccess.copy_absolute(str(write.source),item.temporary)
			if write_error == OK and FileAccess.get_sha256(item.temporary) != str(write.source_sha256): write_error = ERR_FILE_CORRUPT
		else:
			var file := FileAccess.open(item.temporary,FileAccess.WRITE)
			if file == null:
				write_error = FileAccess.get_open_error()
			else:
				file.store_buffer(write.bytes)
				file.flush()
				write_error = file.get_error()
				file.close()
		if write_error != OK:
			_problem = "새 원본 설정의 임시 저장이 실패했습니다."
			_cleanup_pending(staged)
			return false
		if item.create_only: item.written_sha256 = FileAccess.get_sha256(item.temporary)
		if item.existed:
			item.backup = path + ".before-private-source-" + suffix
			if FileAccess.file_exists(item.backup) or DirAccess.copy_absolute(path,item.backup) != OK:
				_problem = "기존 원본 설정의 백업을 만들 수 없어 변경하지 않았습니다."
				_cleanup_pending(staged)
				return false
	var committed: Array[Dictionary] = []
	for item: Dictionary in staged:
		if item.create_only and _settings_path_exists(item.path):
			DirAccess.remove_absolute(item.temporary)
			continue
		if DirAccess.rename_absolute(item.temporary,item.path) == OK:
			committed.append(item)
			continue
		_problem = "원본 설정 활성화가 실패했습니다."
		for previous: Dictionary in committed:
			if previous.existed:
				var restore: String = previous.path + ".private-source-restore-" + str(Time.get_ticks_usec())
				if DirAccess.copy_absolute(previous.backup,restore) != OK or DirAccess.rename_absolute(restore,previous.path) != OK:
					_problem += " 이전 설정 자동 복구도 실패했습니다. before-private-source 백업을 보존했습니다."
			elif previous.create_only and FileAccess.get_sha256(previous.path) != str(previous.written_sha256):
				_problem += " 다른 프로세스가 변경한 월드 지도 설정은 보존했습니다."
			elif DirAccess.remove_absolute(previous.path) != OK:
				_problem += " 새 설정 일부가 남았습니다."
		_cleanup_pending(staged)
		return false
	return true
