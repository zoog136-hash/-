extends RefCounted
## Read-only cumulative523 destination catalog. No world-coordinate inference.
const SOURCE_SHA256 = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"
const PACK_SHA256 = "a217eec940a84d8fa67e7ece99d3f8774b9b13b90aeebbd71e4140ff4ba11fef"
const PACK_BYTES = 136985
const PACK_NAME = "auto_hunting523.json"
var loaded: bool = false
var problem: String = "자동사냥 지역 자료를 설치해 주세요"
var _entries: Dictionary = {}
var _order: Array[int] = []
var _categories: Array = []

static func configured_directory() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--auto-hunt523-dir="):
			return arg.trim_prefix("--auto-hunt523-dir=")
	var configured: String = OS.get_environment("TWILIGHT_AUTO_HUNT523_DIR")
	return configured if not configured.is_empty() else "user://auto_hunting523"

func load_configured() -> bool:
	return load_pack(configured_directory())

func load_pack(directory: String) -> bool:
	# Stage replacement completely before publishing; a failed update retains the
	# already validated session catalog. Never save a path or source rows in saves.
	var path: String = directory.path_join(PACK_NAME)
	var stream := FileAccess.open(path, FileAccess.READ)
	if stream == null:
		problem = "자동사냥 지역 자료를 설치해 주세요"
		return false
	if stream.get_length() != PACK_BYTES:
		problem = "자동사냥 지역 자료의 크기가 다릅니다"
		return false
	var bytes: PackedByteArray = stream.get_buffer(PACK_BYTES)
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	if hashing.finish().hex_encode() != PACK_SHA256:
		problem = "자동사냥 지역 자료를 확인할 수 없습니다"
		return false
	var candidate: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not candidate is Dictionary or candidate.get("schema") != "twilight-auto-hunting523-v1" or candidate.get("source_zip_sha256") != SOURCE_SHA256:
		problem = "지원하지 않는 자동사냥 지역 자료입니다"
		return false
	var entries: Dictionary = {}
	var order: Array[int] = []
	# Exact payload pin authenticates all raw source fields and join multiplicity.
	for entry: Dictionary in candidate.entries:
		var id: int = int(entry.schedule.ID)
		entries[id] = entry
		order.append(id)
	_entries = entries
	_order = order
	_categories = candidate.categories
	loaded = true
	problem = ""
	return true

func categories() -> Array:
	return _categories.duplicate(true)

func list_destinations(category_id: int = -1) -> Array:
	var result: Array = []
	for id: int in _order:
		var entry: Dictionary = _entries[id]
		if category_id >= 0 and int(entry.category.ID) != category_id: continue
		result.append(destination(id))
	return result

func destination(schedule_id: int) -> Dictionary:
	if not _entries.has(schedule_id): return {}
	var result: Dictionary = _entries[schedule_id].duplicate(true)
	result["hunting_region_state"] = "UNSPECIFIED_SENTINEL" if result.schedule.TerritoryID == 0 else "EXPLICIT_REGION"
	# None of the 80 source menu rows gives a departure Land or actor position.
	result["source_land_specified"] = false
	result["live_activation"] = "UNVERIFIED"
	result["runtime_enabled"] = false
	return result

func request_definition(schedule_id: int, landing_link_id: int, level: int, wallet: int, gems: int = -1) -> Dictionary:
	if not loaded: return _blocked("PACK_UNAVAILABLE", problem)
	if not _entries.has(schedule_id): return _blocked("UNKNOWN_SCHEDULE", "자동사냥 지역을 다시 선택해 주세요")
	var entry: Dictionary = _entries[schedule_id]
	var selected: Dictionary = {}
	for landing: Dictionary in entry.destinations:
		if int(landing.link.ID) == landing_link_id:
			selected = landing
			break
	if selected.is_empty(): return _blocked("UNKNOWN_LANDING_LINK", "도착 지역을 다시 선택해 주세요")
	if not bool(entry.schedule.ServerScheduleEnable) or not bool(entry.category.IsWorking):
		return _blocked("DEFINITION_DISABLED", "이 지역의 자동사냥 이동은 비활성 상태입니다")
	var min_level: int = 0
	for condition: Dictionary in entry.prerequisites:
		if str(condition.type.Name) != "MinLevel":
			return _blocked("UNSUPPORTED_PREREQUISITE", "입장 조건을 확인할 수 없습니다")
		min_level = maxi(min_level, int(condition.definition.Value))
	if level < min_level:
		return _blocked("MIN_LEVEL", "%d레벨부터 입장할 수 있습니다" % min_level)
	var currency_id: int = int(entry.currency.ID)
	var is_adena: bool = currency_id == 1 and str(entry.currency.Name) == "Adena"
	var is_gem: bool = currency_id == 4 and str(entry.currency.Name) == "Gem" and gems >= 0
	if not is_adena and not is_gem:
		return _blocked("UNSUPPORTED_CURRENCY", "이동 재화를 확인할 수 없습니다")
	var cost: int = int(entry.teleport.TeleportCost)
	if is_adena and wallet < cost:
		return _blocked("INSUFFICIENT_ADENA", "이동에 필요한 아데나가 부족합니다")
	if is_gem and gems < cost:
		return _blocked("INSUFFICIENT_GEM", "이동에 필요한 다이아가 부족합니다 · 원본 Gem ID4")
	# Source eligibility is separate from a chosen TWILIGHT movement policy.
	var result: Dictionary = {"ok": true, "code": "SOURCE_COST_ELIGIBLE"}
	result["schedule_id"] = schedule_id
	result["landing_link_id"] = landing_link_id
	result["price"] = cost
	result["currency_id"] = currency_id
	result["currency_name"] = str(entry.currency.Name)
	result["currency_asset_id"] = int(entry.currency.AssetID)
	result["currency_label"] = "아데나" if is_adena else "다이아 (Gem ID4)"
	result["min_level"] = min_level
	result["recommend_level"] = int(entry.schedule.RecommendLevel)
	result["landing"] = selected.duplicate(true)
	result["hunting_territory"] = entry.hunting_territory.duplicate(true) if entry.hunting_territory is Dictionary else null
	return result

func assess_request(schedule_id: int, landing_link_id: int, level: int, wallet: int) -> Dictionary:
	var result: Dictionary = request_definition(schedule_id, landing_link_id, level, wallet)
	if not bool(result.get("ok", false)): return result
	result.ok = false
	result.code = "UNVERIFIED_ARRIVAL"
	result.reason = "도착 위치와 지역 이동 조건 확인 전에는 이동할 수 없습니다"
	return result

static func _blocked(code: String, reason: String) -> Dictionary:
	return {"ok": false, "code": code, "reason": reason}
