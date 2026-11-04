extends RefCounted
## Explicit local navigation choice. M raw attributes are never passability.
const PATH = "user://current523_aden_play.cfg"
const NONE = "NONE"
const LEGACY = "TWILIGHT_ADEN_NAVIGATION_V1"
const GRID_SHA256 = "30229ce7fd95656519ff73a47515ac2ac277983022ebc262b084c134a2b80d53"
const LAYOUT_REVISION = 2026102904
const OFFSET_LIMIT = 48

static func defaults() -> Dictionary:
	return {"enabled":false, "navigation_profile":NONE, "offset_x":0, "offset_y":0, "raw_root":"", "tile_root":""}

static func validate(value: Dictionary) -> Dictionary:
	var result: Dictionary = defaults()
	if not value.get("enabled", false) is bool: return {}
	result.enabled = value.get("enabled", false)
	var profile: Variant = value.get("navigation_profile", NONE)
	if profile not in [NONE, LEGACY]: return {}
	result.navigation_profile = profile
	for key: String in ["offset_x", "offset_y"]:
		var number: Variant = value.get(key, 0)
		if not (number is int or number is float) or not is_finite(float(number)) or floorf(float(number)) != float(number) or absf(float(number)) > OFFSET_LIMIT: return {}
		result[key] = int(number)
	for key: String in ["raw_root", "tile_root"]:
		var path: Variant = value.get(key, "")
		if not path is String or path.length() > 4096 or path.to_utf8_buffer().has(0): return {}
		result[key] = path.strip_edges()
	if result.enabled and (profile != LEGACY or result.raw_root.is_empty() or result.tile_root.is_empty()): return {}
	return result

static func read() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK: return defaults()
	var value: Dictionary = defaults()
	for key: String in value: value[key] = config.get_value("play", key, value[key])
	var checked: Dictionary = validate(value)
	return defaults() if checked.is_empty() else checked

static func write(value: Dictionary) -> Error:
	var checked: Dictionary = validate(value)
	if checked.is_empty(): return ERR_INVALID_PARAMETER
	var config := ConfigFile.new()
	var error: Error = config.load(PATH)
	if error != OK and error != ERR_FILE_NOT_FOUND: return error
	for key: String in checked: config.set_value("play", key, checked[key])
	var temporary: String = PATH + ".pending-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	error = config.save(temporary)
	if error == OK: error = DirAccess.rename_absolute(temporary, PATH)
	if error != OK: DirAccess.remove_absolute(temporary)
	return error

static func qualify(world: Node) -> String:
	if world == null or str(world.get("active_map_id")) != "aden_world": return "기존 TWILIGHT 아덴 본토에서만 실험 플레이를 사용할 수 있습니다."
	if not is_instance_valid(world.get("player")) or not world.get("player") is Node2D: return "현재 캐릭터의 이동 준비가 끝나지 않았습니다."
	var field: Variant = world.get("field_map")
	if not field is RemakePlayableField or not bool(field.get_meta("source_map84", false)): return "현재 지역의 검증된 이동 필드가 없습니다."
	var definition: Dictionary = field.definition
	if definition.get("source_map_id") != 4 or definition.get("source_sha256") != GRID_SHA256 or definition.get("layout_revision") != LAYOUT_REVISION:
		return "실험 통행 설정과 현재 아덴 필드의 검증 정보가 다릅니다."
	var coordinates: OriginalMapCoordinates = field.coordinates
	if not coordinates.valid or coordinates.basis_x != Vector2(24, -12) or coordinates.basis_y != Vector2(24, 12): return "현재 지역의 표시 좌표가 지원하는 자체 설정과 다릅니다."
	return ""
