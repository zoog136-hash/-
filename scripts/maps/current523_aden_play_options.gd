extends RefCounted
## Explicit local navigation choice. M raw attributes are never passability.
const PATH = "user://current523_aden_play.cfg"
const NONE = "NONE"
const LEGACY = "TWILIGHT_ADEN_NAVIGATION_V1"
const SOURCE = "CURRENT523_S32_OWN_ALLOWLIST_V1"
const GENERIC = "CURRENT523_GENERIC_S32_OWN_ALLOWLIST_V1"
const SOURCE_WORDS: Array[int] = [0,4,8,12,32]
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
	if profile not in [NONE, LEGACY, SOURCE, GENERIC]: return {}
	result.navigation_profile = profile
	for key: String in ["offset_x", "offset_y"]:
		var number: Variant = value.get(key, 0)
		if not (number is int or number is float) or not is_finite(float(number)) or floorf(float(number)) != float(number) or absf(float(number)) > OFFSET_LIMIT: return {}
		result[key] = int(number)
	for key: String in ["raw_root", "tile_root"]:
		var path: Variant = value.get(key, "")
		if not path is String or path.length() > 4096 or path.to_utf8_buffer().has(0): return {}
		result[key] = path.strip_edges()
	if result.enabled and (profile not in [LEGACY,SOURCE,GENERIC] or result.raw_root.is_empty() or result.tile_root.is_empty()): return {}
	if profile in [SOURCE,GENERIC]:
		var search_limit: Variant=value.get("path_search_limit",8192)
		if not (search_limit is int or search_limit is float) or not is_finite(float(search_limit)) or float(search_limit)!=floorf(float(search_limit)) or search_limit<1 or search_limit>65536: return {}
		result.path_search_limit=int(search_limit)
		var words: Variant = value.get("allowed_raw_words", SOURCE_WORDS.duplicate())
		if not words is Array or words.is_empty() or words.size()>256: return {}
		result.allowed_raw_words = []
		for word: Variant in words:
			if not (word is int or word is float) or not is_finite(float(word)) or float(word)!=floorf(float(word)) or word<0 or word>=65535: return {}
			if not result.allowed_raw_words.has(int(word)): result.allowed_raw_words.append(int(word))
		result.allowed_raw_words.sort()
		var point: Variant = value.get("source_position", [])
		if not point is Array or point.size() not in [0,2]: return {}
		for number: Variant in point:
			if not (number is int or number is float) or not is_finite(float(number)) or number<0 or number>=65536: return {}
		result.source_position = point.duplicate()
		var contract: Variant = value.get("portal_contract", "")
		if not contract is String or contract.length()>4096 or contract.to_utf8_buffer().has(0): return {}
		result.portal_contract = contract.strip_edges()
	if profile == GENERIC:
		for key: String in ["source_manifest_sha256","tile_manifest_sha256"]:
			var digest: Variant = value.get(key,"")
			if not digest is String or digest.length()!=64 or not digest.is_valid_hex_number(false): return {}
			result[key]=digest.to_lower()
		var land: Variant=value.get("native_land_id",-1)
		if not (land is int or land is float) or not is_finite(float(land)) or float(land)!=floorf(float(land)) or land<0 or land>2147483647: return {}
		result.native_land_id=int(land)
	return result

static func read() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK: return defaults()
	var value: Dictionary = defaults()
	for key: String in value: value[key] = config.get_value("play", key, value[key])
	if value.navigation_profile in [SOURCE,GENERIC]:
		for key: String in ["allowed_raw_words","source_position","portal_contract","path_search_limit"]:
			value[key] = config.get_value("play",key,8192 if key=="path_search_limit" else (SOURCE_WORDS.duplicate() if key=="allowed_raw_words" else ([] if key=="source_position" else "")))
	if value.navigation_profile == GENERIC:
		for key: String in ["source_manifest_sha256","tile_manifest_sha256","native_land_id"]:
			value[key]=config.get_value("play",key,-1 if key=="native_land_id" else "")
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
