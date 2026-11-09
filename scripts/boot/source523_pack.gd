extends Node
## Private LineageM 523 resource pack for the Android APK.
##
## Git and the APK carry code only. The user's own client resources are built
## outside the repository and packed into ZIP parts by
## tools/android/build_client523_resource_pack.py. Here the user picks those
## parts once from the phone's storage; their members are extracted unchanged
## into user://source523/. On every launch, before Main loads, the runtime
## readers are pointed at that directory: the same selections the desktop
## flags and the Termux bootstrap make (tables ZIP, image pack, UI pack, CSB
## icon selection, source maps and tiles, SP2 bank). Every reader still checks
## its own pins.
##
## Runs in exported builds, or on desktop only with an explicit
## --source523-pack=<extracted pack directory>.

const ROOT := "user://source523"
const SCHEMA := "twilight-client523-resource-pack-v1"
const PART_SCHEMA := "twilight-client523-resource-pack-part-v1"
const PART_INDEX := "source523_part.json"
const DESCRIPTOR_MEMBER := "source523_pack.json"
## Inside a part every entry sits under this folder; the part index is the
## first entry and the descriptor (part 1) the second, so ZIPReader finds them
## at once. Members are read after mounting the part as a resource pack (one
## indexing pass): a ZIPReader lookup per member is a linear scan, far too slow
## for 60,000 entries.
const PREFIX := "source523/"
const MOUNT := "res://source523/"
const TABLES_SHA := "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const TABLES_BYTES: int = 25031173
## Older fixed-path table readers (same list as the Termux bootstrap).
const TABLE_COPIES := ["user://growth96_definitions/source.zip","user://source_rules/death523.zip","user://title523/source.zip","user://source_rules/relic-patch523.zip"]
const BANK_SETTINGS := "user://current523_source_bank.json"
const MAP_SETTINGS := "user://current523_aden_play.cfg"
const GENERIC_MAP := "CURRENT523_GENERIC_S32_OWN_ALLOWLIST_V1"
const SECTIONS := {"bank":"manifest.json","images":"manifest.json","maps":"source523.json","tiles":"tilepack523.json","ui":"original_ui.json","ui_icons":"icon-selection.json","world_links":"manifest.json"}
## Add-ons extend an installed pack without reinstalling its parts.
const ADDON_SCHEMA := "twilight-client523-resource-addon-v1"
const ADDON_DESCRIPTOR := "source523_addon.json"
const ADDONS := "source523_addons.json"
const ADDON_SECTIONS := ["world_links","ui"]
## The add-on file that carries each section (what the installer asks for).
const ADDON_FILES := {"world_links":"twilight523-addon-world-links.zip","ui":"twilight523-addon-ui.zip"}
const ADDON_NAMES := {"world_links":"523 맵 이동 정의","ui":"원작 메인 화면(UI)"}
## 523 map travel definitions; 523 play mode needs them to enter a Land.
const WORLD_LINKS_SHA := "2de8cebbcf486e5c2afa3e471ddc0cceeebe20ab8389916291eb24a5739ffa90"
const DEFINITIONS = preload("res://scripts/maps/current523_source_definition_preferences.gd")
## Tests pin a fixture definitions manifest instead of the real one.
static var world_links_sha: String = WORLD_LINKS_SHA
const REQUIRED := ["bank","images","maps","tiles"]
const FRAME_BUDGET_MSEC: int = 30
const COPY_CHUNK: int = 16 * 1024 * 1024
const STYLE = preload("res://scripts/boot/boot_style.gd")

## Install target; tests use a scratch directory instead of ROOT.
var root: String = ROOT
## The runtime-pinned tables ZIP; tests substitute their fixture's pin.
var tables_sha: String = TABLES_SHA
var configured: bool = false
var problem: String = ""
var needed: bool = false
## The base pack is installed but an add-on it needs is missing.
var addon_needed: bool = false
var _layer: CanvasLayer
var _status: Label
var _choose: Button
var _later: Button
var _picker: FileDialog
var _queue: Array[String] = []
var _mounted: bool = false
var _copy_source: FileAccess
var _copy_target: FileAccess
var _copy_name: String = ""
var _copy_total: int = 0
var _copied: int = 0
var _incoming: String = ""
var _incoming_serial: int = 0
var _descriptor_bytes := PackedByteArray()
var _addon: Dictionary = {}
var _missing: Array[String] = []
var _index: Dictionary = {}
var _cursor: int = 0
var _verify: Array = []

static func _safe_relative(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > 1024: return false
	if value.contains("\\") or value.contains(":") or value.begins_with("/"): return false
	for part: String in value.split("/"):
		if part in ["", ".", ".."]: return false
	return true

static func _sha(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

## Reads and checks an extracted pack descriptor. No hashing here: readers pin.
static func read_descriptor(path: String, tables_sha: String = TABLES_SHA) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 2 or file.get_length() > 1024 * 1024: return {"ok":false,"reason":"source523_pack_descriptor_missing"}
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not value is Dictionary or value.get("schema") != SCHEMA or value.get("cumulative_version") != 523: return {"ok":false,"reason":"source523_pack_descriptor_schema"}
	if not _sha(value.get("pack_id")): return {"ok":false,"reason":"source523_pack_id"}
	var tables: Variant = value.get("tables")
	if not tables is Dictionary or not _safe_relative(tables.get("path")) or tables.get("sha256") != tables_sha: return {"ok":false,"reason":"source523_pack_tables"}
	for section: String in SECTIONS:
		if not value.has(section):
			if section in REQUIRED: return {"ok":false,"reason":"source523_pack_section_missing:" + section}
			continue
		var entry: Variant = value[section]
		if not entry is Dictionary or not _safe_relative(entry.get("root")) or not _sha(entry.get("manifest_sha256")): return {"ok":false,"reason":"source523_pack_section:" + section}
		if entry.get("manifest") != str(entry.root) + "/" + str(SECTIONS[section]): return {"ok":false,"reason":"source523_pack_manifest_path:" + section}
		if section == "world_links" and str(entry.manifest_sha256).to_lower() != world_links_sha: return {"ok":false,"reason":"source523_pack_world_links_pin"}
	var land: Variant = value.get("start_land_id", 4)
	if not (land is int or land is float) or float(land) != floorf(float(land)) or land < 0: return {"ok":false,"reason":"source523_pack_start_land"}
	return {"ok":true,"descriptor":value}

## Sections added by installed add-ons, validated like descriptor sections.
static func read_addons(base: String) -> Dictionary:
	var path: String = base.path_join(ADDONS)
	if not FileAccess.file_exists(path) or FileAccess.get_size(path) > 64 * 1024: return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var result: Dictionary = {}
	if not value is Dictionary: return result
	for section: String in ADDON_SECTIONS:
		var entry: Variant = value.get(section)
		if not entry is Dictionary or not _safe_relative(entry.get("root")) or not _sha(entry.get("manifest_sha256")): continue
		if entry.get("manifest") != str(entry.root) + "/" + str(SECTIONS[section]): continue
		if section == "world_links" and str(entry.manifest_sha256).to_lower() != world_links_sha: continue
		result[section] = entry
	return result

## True when the pack (with its add-ons) supplies the 523 travel definitions.
static func has_world_links(descriptor: Dictionary, addons: Dictionary) -> bool:
	return descriptor.has("world_links") or addons.has("world_links")

## Add-on sections neither the pack nor its installed add-ons supply.
static func missing_addons(descriptor: Dictionary, addons: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	for section: String in ADDON_SECTIONS:
		if not descriptor.has(section) and not addons.has(section): missing.append(section)
	return missing

## The selections for an extracted pack at absolute directory `base`.
static func selections(base: String, descriptor: Dictionary, addons: Dictionary = {}) -> Dictionary:
	var tables: String = base.path_join(descriptor.tables.path)
	var environment: Dictionary = {"TWILIGHT_PATCH523_CONTENT":tables,
		"TWILIGHT_SOURCE523_IMAGES":base.path_join(descriptor.images.root),
		"TWILIGHT_SOURCE523_IMAGES_SHA256":str(descriptor.images.manifest_sha256).to_lower()}
	# The original main HUD pack: in the pack itself or from the UI add-on.
	var ui: Variant = descriptor.get("ui", addons.get("ui"))
	if ui is Dictionary:
		environment.TWILIGHT_SOURCE_UI = base.path_join(ui.root)
		environment.TWILIGHT_SOURCE_UI_SHA256 = str(ui.manifest_sha256).to_lower()
	if descriptor.has("ui_icons"):
		# The selection names its CSB icon pack relative to its own folder.
		environment.TWILIGHT_SOURCE523_UI_ICONS = base.path_join(descriptor.ui_icons.manifest)
		environment.TWILIGHT_SOURCE523_UI_ICONS_SHA256 = str(descriptor.ui_icons.manifest_sha256).to_lower()
	var bank: Dictionary = {"schema":1,"enabled":true,"source_snapshot":"patch523","tables_zip":tables,
		"manifest_path":base.path_join(descriptor.bank.manifest),"manifest_sha256":str(descriptor.bank.manifest_sha256).to_lower()}
	var maps: Dictionary = {"raw_root":base.path_join(descriptor.maps.root),"tile_root":base.path_join(descriptor.tiles.root),
		"source_manifest_sha256":str(descriptor.maps.manifest_sha256).to_lower(),"tile_manifest_sha256":str(descriptor.tiles.manifest_sha256).to_lower()}
	var result: Dictionary = {"environment":environment,"bank":bank,"maps":maps,"start_land_id":int(descriptor.get("start_land_id",4)),"tables":tables}
	var links: Variant = descriptor.get("world_links", addons.get("world_links"))
	if links is Dictionary: result["definitions"] = {"directory":base.path_join(links.root),"manifest_sha256":str(links.manifest_sha256).to_lower()}
	return result

## Applies selections: process environment, bank JSON, map cfg, table copies.
static func apply(selected: Dictionary) -> Dictionary:
	for key: String in selected.environment:
		OS.set_environment(key, str(selected.environment[key]))
	var bank_text: String = JSON.stringify(selected.bank, "\t", true) + "\n"
	if not FileAccess.file_exists(BANK_SETTINGS) or FileAccess.get_file_as_string(BANK_SETTINGS) != bank_text:
		var bank_file := FileAccess.open(BANK_SETTINGS, FileAccess.WRITE)
		if bank_file == null: return {"ok":false,"reason":"source523_pack_bank_settings_unwritable"}
		bank_file.store_string(bank_text)
		bank_file.close()
	var config := ConfigFile.new()
	var error: Error = config.load(MAP_SETTINGS)
	if error != OK and error != ERR_FILE_NOT_FOUND: config = ConfigFile.new()
	var same_source: bool = config.get_value("play","source_manifest_sha256","") == selected.maps.source_manifest_sha256 and config.get_value("play","tile_manifest_sha256","") == selected.maps.tile_manifest_sha256
	for key: String in selected.maps:
		config.set_value("play", key, selected.maps[key])
	if not same_source:
		# A cursor saved against other source bytes is never adopted.
		config.set_value("play","enabled",true)
		config.set_value("play","navigation_profile",GENERIC_MAP)
		config.set_value("play","native_land_id",selected.start_land_id)
		config.set_value("play","source_position",[])
	if config.save(MAP_SETTINGS) != OK: return {"ok":false,"reason":"source523_pack_map_settings_unwritable"}
	if selected.has("definitions"):
		var stored: Dictionary = DEFINITIONS.read()
		if not stored.get("ok", false) or not stored.get("configured", false) or stored.get("directory") != selected.definitions.directory:
			if DEFINITIONS.write(selected.definitions.directory, selected.definitions.manifest_sha256) != OK: return {"ok":false,"reason":"source523_pack_definitions_unwritable"}
	for copy_path: String in TABLE_COPIES:
		var existing := FileAccess.open(copy_path, FileAccess.READ)
		if existing != null and existing.get_length() == TABLES_BYTES:
			existing.close()
			continue
		existing = null
		DirAccess.make_dir_recursive_absolute(copy_path.get_base_dir())
		if DirAccess.copy_absolute(selected.tables, copy_path) != OK: return {"ok":false,"reason":"source523_pack_table_copy_failed"}
	return {"ok":true}

static func _requested_root() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source523-pack="): return argument.trim_prefix("--source523-pack=")
	return ""

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var requested: String = _requested_root()
	var exported: bool = OS.has_feature("template")
	if requested.is_empty() and not exported: return
	var base: String = requested if not requested.is_empty() else ProjectSettings.globalize_path(ROOT)
	var read: Dictionary = read_descriptor(base.path_join("source523_pack.json"))
	if not read.ok:
		needed = exported and requested.is_empty()
		if not requested.is_empty(): problem = read.reason
		return
	var addons: Dictionary = read_addons(base)
	var applied: Dictionary = apply(selections(base, read.descriptor, addons))
	configured = applied.ok
	addon_needed = configured and exported and requested.is_empty() and not missing_addons(read.descriptor, addons).is_empty()
	_missing = missing_addons(read.descriptor, addons)
	if not configured:
		problem = applied.reason
		push_error("원본 리소스 팩을 연결하지 못했습니다: " + problem)

func _ready() -> void:
	set_process(false)
	if needed or addon_needed: _show_installer.call_deferred()

func _actor_pack_needed() -> bool:
	var actor: Node = get_node_or_null("/root/ActorPack")
	return actor != null and bool(actor.get("needed"))

func _show_installer() -> void:
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 127
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_layer)
	var box: VBoxContainer = STYLE.installer_frame(_layer)
	box.add_child(STYLE.label("원본 리소스 팩 설치", 26, STYLE.GOLD))
	_status = STYLE.label("", 20)
	box.add_child(_status)
	_choose = STYLE.button("리소스 팩(.zip) 선택")
	_choose.pressed.connect(func() -> void: _picker.popup_centered_ratio(0.8))
	box.add_child(_choose)
	_later = STYLE.button("나중에 (추가 리소스 없이 시작)", false, 52)
	_later.pressed.connect(_close_installer)
	# The game has no older pictures to start with: only a missing add-on can
	# be postponed, never the pack itself.
	_later.visible = addon_needed and not needed
	box.add_child(_later)
	_picker = FileDialog.new()
	_picker.title = "TWILIGHT 원본 리소스 팩"
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_picker.use_native_dialog = true
	_picker.filters = PackedStringArray(["*.zip;TWILIGHT 원본 리소스 팩;application/zip"])
	_picker.files_selected.connect(_queue_parts)
	_picker.file_selected.connect(func(path: String) -> void: _queue_parts(PackedStringArray([path])))
	_layer.add_child(_picker)
	_status.text = _waiting_text()

func _close_installer() -> void:
	if _layer != null: _layer.queue_free()
	_layer = null
	if not _actor_pack_needed(): get_tree().paused = false

func _state() -> Dictionary:
	if not FileAccess.file_exists(root.path_join("installed_parts.json")): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("installed_parts.json")))
	if not value is Dictionary or not _sha(value.get("pack_id")) or not value.get("done") is Array: return {}
	# JSON numbers come back as floats; part numbers are compared as ints.
	var done: Array = []
	for part: Variant in value.done:
		if (part is int or part is float) and not done.has(int(part)): done.append(int(part))
	return {"pack_id":value.pack_id,"parts":int(value.get("parts",0)),"done":done}

func _save_state(value: Dictionary) -> void:
	var file := FileAccess.open(root.path_join("installed_parts.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value))
		file.close()

func _waiting_text() -> String:
	if addon_needed:
		var names: Array[String] = []
		var files: Array[String] = []
		for section: String in _missing:
			names.append(str(ADDON_NAMES[section]))
			files.append(str(ADDON_FILES[section]))
		return "원본 리소스 팩은 설치되어 있습니다.\n추가 리소스가 더 필요합니다: %s\n%s 을(를) 선택하세요.\n(조각을 다시 받을 필요는 없습니다)" % [", ".join(names), ", ".join(files)]
	var state: Dictionary = _state()
	if int(state.get("parts", 0)) > 0:
		return "원본 리소스 팩 설치 중: %d / %d 조각 완료.\n남은 조각(twilight523-resources-*.zip)을 선택하세요." % [state.get("done", []).size(), int(state.parts)]
	return "게임을 시작하려면 원본 리소스 팩이 필요합니다.\ntwilight523-resources-*.zip 조각을 모두 선택하세요.\n(한 번에 여러 개, 또는 하나씩 선택할 수 있습니다)"

func _queue_parts(paths: PackedStringArray) -> void:
	for path: String in paths: _queue.append(path)
	_choose.disabled = true
	_later.disabled = true
	DirAccess.make_dir_recursive_absolute(root)
	_next_part()

func _fail_part(message: String) -> void:
	_release_part()
	_queue.clear()
	set_process(false)
	_status.text = message + "\n\n" + _waiting_text()
	_choose.disabled = false
	_later.disabled = false

## A mounted pack stays mapped until restart; later parts replace its names.
## Its local copy is no longer read and is removed.
func _release_part() -> void:
	_mounted = false
	_copy_source = null
	if _copy_target != null: _copy_target.close()
	_copy_target = null
	set_process(false)
	if not _incoming.is_empty() and FileAccess.file_exists(_incoming): DirAccess.remove_absolute(_incoming)
	_incoming = ""

func _next_part() -> void:
	if _queue.is_empty():
		_finish_or_wait()
		return
	# Like ActorPack, the picked file (often a content URI) is first copied into
	# app storage; the ZIP is then read and mounted from a plain local file.
	var picked: String = _queue.pop_front()
	_copy_source = FileAccess.open(picked, FileAccess.READ)
	if _copy_source == null:
		_fail_part("파일을 열 수 없습니다 (%s): %s" % [error_string(FileAccess.get_open_error()), picked.get_file()])
		return
	_copy_name = picked.get_file()
	_incoming_serial += 1
	_incoming = root.path_join("incoming-%d.zip" % _incoming_serial)
	_copy_target = FileAccess.open(_incoming, FileAccess.WRITE)
	if _copy_target == null:
		_copy_source = null
		_fail_part("앱 저장소에 쓸 수 없습니다 (저장 공간을 확인하세요).")
		return
	_copy_total = int(_copy_source.get_length())
	_copied = 0
	set_process(true)

func _copy_step() -> void:
	var chunk: PackedByteArray = _copy_source.get_buffer(mini(COPY_CHUNK, _copy_total - _copied))
	_copy_target.store_buffer(chunk)
	_copied += chunk.size()
	_status.text = "조각 가져오는 중 (%s): %d / %d MB" % [_copy_name, _copied >> 20, _copy_total >> 20]
	if not chunk.is_empty() and _copied < _copy_total: return
	var complete: bool = _copied == _copy_total and _copy_target.get_error() == OK
	_copy_source = null
	_copy_target.close()
	_copy_target = null
	set_process(false)
	if not complete:
		_fail_part("조각을 가져오지 못했습니다. 저장 공간을 확인하세요: " + _copy_name)
		return
	_open_part(_incoming)

func _open_part(path: String) -> void:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		_fail_part("ZIP을 열 수 없습니다: " + _copy_name)
		return
	if not reader.file_exists(PREFIX + PART_INDEX):
		reader.close()
		_fail_part("TWILIGHT 리소스 팩 조각이 아닙니다: " + _copy_name)
		return
	var index: Variant = JSON.parse_string(reader.read_file(PREFIX + PART_INDEX).get_string_from_utf8())
	_descriptor_bytes = reader.read_file(PREFIX + DESCRIPTOR_MEMBER) if reader.file_exists(PREFIX + DESCRIPTOR_MEMBER) else PackedByteArray()
	var addon_bytes: PackedByteArray = reader.read_file(PREFIX + ADDON_DESCRIPTOR) if reader.file_exists(PREFIX + ADDON_DESCRIPTOR) else PackedByteArray()
	reader.close()
	if not index is Dictionary or index.get("schema") != PART_SCHEMA or not _sha(index.get("pack_id")) or not index.get("members") is Array \
			or not (index.get("part") is float or index.get("part") is int) or not (index.get("parts") is float or index.get("parts") is int) \
			or int(index.part) < 1 or int(index.part) > int(index.parts):
		_fail_part("리소스 팩 조각 정보가 다릅니다: " + _copy_name)
		return
	if index.get("addon") == true:
		# An add-on never touches the installed pack's parts or descriptor.
		var addon: Dictionary = read_addon(addon_bytes, index)
		if addon.is_empty():
			_fail_part("추가 리소스 정보가 다릅니다: " + _copy_name)
			return
		if not ProjectSettings.load_resource_pack(path, true):
			_fail_part("추가 리소스를 읽을 수 없습니다: " + _copy_name)
			return
		_addon = addon
		_mounted = true
		_index = index
		_cursor = 0
		set_process(true)
		return
	var state: Dictionary = _state()
	if state.get("pack_id") != index.pack_id:
		# A different pack replaces the active one; its descriptor goes first.
		if FileAccess.file_exists(root.path_join(DESCRIPTOR_MEMBER)): DirAccess.remove_absolute(root.path_join(DESCRIPTOR_MEMBER))
		state = {"pack_id":index.pack_id,"parts":int(index.parts),"done":[]}
		_save_state(state)
	if state.done.has(int(index.part)):
		_release_part()
		_next_part()
		return
	# Names are unique across one pack's parts; the folder exists only in parts.
	if not ProjectSettings.load_resource_pack(path, true):
		_fail_part("조각을 읽을 수 없습니다: " + _copy_name)
		return
	_mounted = true
	_index = index
	_cursor = 0
	set_process(true)

func _process(_delta: float) -> void:
	if _copy_source != null:
		_copy_step()
		return
	if not _verify.is_empty():
		_verify_step()
		return
	if not _mounted: return
	var started: int = Time.get_ticks_msec()
	var members: Array = _index.members
	while _cursor < members.size() and Time.get_ticks_msec() - started < FRAME_BUDGET_MSEC:
		var entry: Variant = members[_cursor]
		if not entry is Array or entry.size() != 2 or not _safe_relative(entry[0]):
			_fail_part("리소스 팩 조각의 파일 목록이 잘못되었습니다.")
			return
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(MOUNT + str(entry[0]))
		if bytes.size() != int(entry[1]):
			_fail_part("조각의 파일이 손상되었습니다: " + str(entry[0]))
			return
		var target: String = root.path_join(entry[0])
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var file := FileAccess.open(target, FileAccess.WRITE)
		if file == null:
			_fail_part("앱 저장소에 쓸 수 없습니다 (저장 공간을 확인하세요).")
			return
		file.store_buffer(bytes)
		file.close()
		_cursor += 1
	_status.text = "%d / %d 조각 설치 중: %d / %d 파일" % [int(_index.part), int(_index.parts), _cursor, members.size()]
	if _cursor < members.size(): return
	if _index.get("addon") == true:
		_finish_addon()
		return
	if int(_index.part) == 1:
		if _descriptor_bytes.is_empty():
			_fail_part("1번 조각에 팩 설명 파일이 없습니다.")
			return
		var pending := FileAccess.open(root.path_join("source523_pack.pending.json"), FileAccess.WRITE)
		if pending == null:
			_fail_part("앱 저장소에 쓸 수 없습니다.")
			return
		pending.store_buffer(_descriptor_bytes)
		pending.close()
	_release_part()
	var state: Dictionary = _state()
	state.done.append(int(_index.part))
	_save_state(state)
	_next_part()

## The add-on descriptor when it belongs to `index` and names only known,
## pinned sections; else {}.
static func read_addon(bytes: PackedByteArray, index: Dictionary) -> Dictionary:
	if bytes.is_empty() or bytes.size() > 256 * 1024: return {}
	var value: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not value is Dictionary or value.get("schema") != ADDON_SCHEMA or value.get("cumulative_version") != 523 or value.get("addon_id") != index.get("pack_id"): return {}
	if not value.get("sections") is Dictionary or value.sections.is_empty(): return {}
	for section: Variant in value.sections:
		var entry: Variant = value.sections[section]
		if not section in ADDON_SECTIONS or not entry is Dictionary or not _safe_relative(entry.get("root")) or not _sha(entry.get("manifest_sha256")): return {}
		if entry.get("manifest") != str(entry.root) + "/" + str(SECTIONS[section]): return {}
		if section == "world_links" and str(entry.manifest_sha256).to_lower() != world_links_sha: return {}
	return value

func _finish_addon() -> void:
	var addon: Dictionary = _addon
	_addon = {}
	_release_part()
	for section: String in addon.sections:
		var entry: Dictionary = addon.sections[section]
		if FileAccess.get_sha256(root.path_join(entry.manifest)) != str(entry.manifest_sha256).to_lower():
			_fail_part("설치한 추가 리소스가 설명과 다릅니다: " + section)
			return
	var merged: Dictionary = {}
	var current: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join(ADDONS))) if FileAccess.file_exists(root.path_join(ADDONS)) else {}
	if current is Dictionary: merged = current
	for section: String in addon.sections: merged[section] = addon.sections[section]
	var pending := FileAccess.open(root.path_join(ADDONS + ".pending"), FileAccess.WRITE)
	if pending == null:
		_fail_part("앱 저장소에 쓸 수 없습니다.")
		return
	pending.store_string(JSON.stringify(merged, "\t", true))
	pending.close()
	if DirAccess.rename_absolute(root.path_join(ADDONS + ".pending"), root.path_join(ADDONS)) != OK:
		_fail_part("추가 리소스 기록을 저장하지 못했습니다.")
		return
	for section: String in addon.sections: _missing.erase(section)
	addon_needed = not _missing.is_empty()
	if not _queue.is_empty():
		_next_part()
		return
	if addon_needed:
		# Another add-on is still missing: ask for it now; restart after it.
		_status.text = "추가 리소스 설치 완료.\n\n" + _waiting_text()
		_choose.disabled = false
		# What was just installed takes effect after a restart.
		_later.text = "앱 닫기 (나머지는 나중에)"
		_later.disabled = false
		for connection: Dictionary in _later.pressed.get_connections():
			_later.pressed.disconnect(connection.callable)
		_later.pressed.connect(func() -> void: get_tree().quit())
		return
	_status.text = "추가 리소스 설치 완료.\n앱을 완전히 닫고 다시 실행하세요.\n(설치에 쓴 zip은 지워도 됩니다)"
	_offer_quit()

func _offer_quit() -> void:
	_choose.text = "앱 닫기"
	_choose.disabled = false
	_later.visible = false
	for connection: Dictionary in _choose.pressed.get_connections():
		_choose.pressed.disconnect(connection.callable)
	_choose.pressed.connect(func() -> void: get_tree().quit())

func _finish_or_wait() -> void:
	var state: Dictionary = _state()
	if state.get("done", []).size() < int(state.get("parts", 0)) or not FileAccess.file_exists(root.path_join("source523_pack.pending.json")):
		_status.text = _waiting_text()
		_choose.disabled = false
		_later.disabled = false
		return
	var read: Dictionary = read_descriptor(root.path_join("source523_pack.pending.json"), tables_sha)
	if not read.ok or read.descriptor.pack_id != state.pack_id:
		_fail_part("팩 설명 파일이 조각과 맞지 않습니다.")
		return
	_verify = [["tables", read.descriptor.tables.path, tables_sha]]
	for section: String in SECTIONS:
		if read.descriptor.has(section):
			_verify.append([section, read.descriptor[section].manifest, read.descriptor[section].manifest_sha256])
	_status.text = "설치한 원본 확인 중..."
	set_process(true)

func _verify_step() -> void:
	var item: Array = _verify.pop_front()
	if FileAccess.get_sha256(root.path_join(item[1])) != str(item[2]).to_lower():
		_verify.clear()
		set_process(false)
		_fail_part("설치한 원본이 팩 설명과 다릅니다: " + str(item[0]))
		return
	if not _verify.is_empty(): return
	set_process(false)
	DirAccess.rename_absolute(root.path_join("source523_pack.pending.json"), root.path_join(DESCRIPTOR_MEMBER))
	_status.text = "원본 리소스 팩 설치 완료.\n앱을 완전히 닫고 다시 실행하세요.\n(설치에 쓴 zip 조각은 지워도 됩니다)"
	_offer_quit()
