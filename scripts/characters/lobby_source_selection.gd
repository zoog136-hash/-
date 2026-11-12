extends RefCounted
## A private lobby-only selection; it never replaces the composed Main UI pack.
const PACK = preload("res://scripts/ui/original_ui/source_pack.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const FILES_INFO_SHA := "fefb29fb8126f106e4d127b59a81459efc576d5a6eab8456b4c4988ae390f4dc"

static func options(args: PackedStringArray, environment_root: String = "", environment_pin: String = "") -> Dictionary:
	var values: Dictionary = {}
	var requested: bool = false
	for argument: String in args:
		var key: String = "path" if argument.begins_with("--source-lobby=") else "sha256" if argument.begins_with("--source-lobby-sha256=") else ""
		if key.is_empty(): continue
		requested = true
		var value: String = argument.substr(argument.find("=")+1)
		if values.has(key) and values[key] != value: return _fail("conflicting_lobby_selection")
		values[key] = value
	var environment_selected: bool = not environment_root.is_empty() or not environment_pin.is_empty()
	if not requested and not environment_selected: return {"ok":true,"selected":false}
	if requested and (str(values.get("path","")).is_empty() or str(values.get("sha256","")).is_empty()): return _fail("lobby_selection_pair_required")
	if environment_selected and (environment_root.is_empty() or environment_pin.is_empty()): return _fail("lobby_selection_pair_required")
	if requested and environment_selected and (values.path != environment_root or values.sha256 != environment_pin): return _fail("conflicting_lobby_selection")
	var root: String = str(values.path) if requested else environment_root
	var pin: String = str(values.sha256) if requested else environment_pin
	if root != root.strip_edges() or not _pin(pin): return _fail("invalid_lobby_selection")
	return {"ok":true,"selected":true,"path":root,"sha256":pin}

static func selected_pack() -> Dictionary:
	return open_options(options(OS.get_cmdline_user_args(),OS.get_environment("TWILIGHT_SOURCE_LOBBY"),OS.get_environment("TWILIGHT_SOURCE_LOBBY_SHA256")))

static func open_options(selection: Dictionary) -> Dictionary:
	if not selection.get("ok",false) or not selection.get("selected",false): return selection.duplicate(true)
	var absolute: String = ProjectSettings.globalize_path(str(selection.get("path","")))
	if not absolute.is_absolute_path() or not _pin(str(selection.get("sha256",""))): return _fail("lobby_absolute_path_and_pin_required")
	var pack = PACK.new()
	var opened: Dictionary = pack.open(absolute,selection.sha256)
	if not opened.get("ok",false):
		opened["selected"] = true
		return opened
	var identity: Variant = pack.manifest.get("lobby_source")
	if not identity is Dictionary or identity.get("kind") != "twilight.source523.lobby-input.v1" or identity.get("source_snapshot") != "patch523" or identity.get("definition_sha256") != DEFINITIONS.SOURCE_SHA or identity.get("files_info_sha256") != FILES_INFO_SHA:
		pack.release_cache_leases()
		return _fail("verified_current523_lobby_provenance_required")
	return {"ok":true,"selected":true,"pack":pack,"rendered":false,"selection_mode":"separate_original_lobby_pack"}

static func _pin(value: String) -> bool:
	if value.length()!=64: return false
	for index: int in value.length():
		if not "0123456789abcdef".contains(value.substr(index,1)): return false
	return true

static func _fail(reason: String) -> Dictionary:
	return {"ok":false,"selected":true,"error":reason}
