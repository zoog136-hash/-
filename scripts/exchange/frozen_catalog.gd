extends RefCounted
## A frozen observed listing is not a static ItemClass price or an average.
const PATH: String = "res://data/exchange/frozen_snapshot.json"
const LIMIT: int = 9007199254740991
var snapshot: Dictionary = {}
var sha256: String = ""
var problem: String = ""
var _listings: Dictionary = {}

static func integer(value: Variant, minimum: int = 0, maximum: int = LIMIT) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func https(value: Variant) -> bool:
	if not value is String or not value.begins_with("https://"): return false
	var whitespace := RegEx.new(); whitespace.compile("\\s")
	if whitespace.search(value) != null: return false
	var authority: String = value.substr(8).get_slice("/",0).get_slice("?",0).get_slice("#",0)
	if authority.is_empty() or authority.contains("@"): return false
	if authority.begins_with("["):
		return authority.contains("]") and authority.find("]") > 1
	return not authority.get_slice(":",0).is_empty()

static func key(row: Dictionary) -> String:
	# JSON array encoding avoids delimiter collisions between server/listing IDs.
	return JSON.stringify([row.server_id,row.listing_id])

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("schema") != "twilight.frozen-exchange.v1": return "거래소 스냅샷 형식 오류"
	var reset: Variant = value.get("reset")
	if value.get("price_policy") != "frozen_once" or not reset is Dictionary or reset.get("timezone") != "Asia/Seoul" or not integer(reset.get("hour"),5,5): return "고정 가격·한국 05시 초기화 정책 오류"
	if not https(value.get("source_url")) or not value.get("listings") is Array or not value.get("coverage") is Dictionary: return "거래소 출처·수집 범위 누락"
	var coverage: Dictionary = value.coverage
	if not value.has("captured_at") or not coverage.get("complete") is bool: return "수집 시각·완료 여부 누락"
	if coverage.get("scope") != "all_servers" or not coverage.get("expected_server_ids") is Array or not coverage.get("completed_server_ids") is Array: return "전체 서버 수집 범위 오류"
	if value.get("status") == "not_captured":
		return "" if value.get("captured_at") == null and coverage.get("complete") == false and coverage.expected_server_ids.is_empty() and coverage.completed_server_ids.is_empty() and value.listings.is_empty() else "미수집 상태에 임의 상품·수집 범위가 있습니다"
	if value.get("status") != "captured" or coverage.get("complete") != true: return "전체 서버 실측 수집이 완료되지 않았습니다"
	var expected: Dictionary = {}
	for id: Variant in coverage.expected_server_ids:
		if not id is String or id.strip_edges().is_empty() or expected.has(id): return "서버 ID 중복·누락"
		expected[id] = true
	var completed: Dictionary = {}
	for id: Variant in coverage.completed_server_ids:
		if not id is String or completed.has(id) or not expected.has(id): return "완료 서버 목록 불일치"
		completed[id] = true
	if expected.is_empty() or completed.size() != expected.size(): return "전체 서버 누락"
	var captured: Variant = value.get("captured_at")
	if not captured is String or captured.length() != 20 or not captured.ends_with("Z") or captured.substr(10,1) != "T" or Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_datetime_string(captured.trim_suffix("Z"))) + "Z" != captured: return "수집 시각은 UTC ISO8601이어야 합니다"
	var seen: Dictionary = {}
	for item: Variant in value.listings:
		if not item is Dictionary: return "거래 상품 행 오류"
		for field: String in ["server_id","listing_id","item_name"]:
			if not item.get(field) is String or item[field].strip_edges().is_empty(): return "상품 식별자·이름 누락"
		if not expected.has(item.server_id) or seen.has(key(item)): return "상품 서버 불일치·등록 ID 중복"
		seen[key(item)] = true
		for field: String in ["item_class_id","bundle_size","bundle_price","initial_bundles"]:
			if not integer(item.get(field),1): return "상품 정수 범위 오류: " + field
		if item.get("currency_unit_id") != 34 or item.get("currency_class_id") != 2: return "확인되지 않은 거래 재화"
		if not integer(item.get("enchant"),0,255) or not integer(item.get("element_level"),0,255) or not item.get("element") is String or not item.get("attributes") is Dictionary or not https(item.get("evidence_url")): return "상품 변형·실측 근거 누락"
		if int(item.initial_bundles) > LIMIT / int(item.bundle_size) or int(item.initial_bundles) > LIMIT / int(item.bundle_price): return "상품 묶음 합계 범위 초과"
	return ""

func load_snapshot(path: String = PATH) -> bool:
	snapshot.clear(); _listings.clear(); sha256 = ""
	if not FileAccess.file_exists(path): problem = "거래소 실측 스냅샷 파일 없음"; return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 256 * 1024 * 1024: problem = "거래소 파일 접근·크기 오류"; return false
	var raw: PackedByteArray = file.get_buffer(file.get_length())
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	problem = validate(parsed)
	if not problem.is_empty(): return false
	snapshot = parsed.duplicate(true)
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256); digest.update(raw)
	sha256 = digest.finish().hex_encode()
	for row: Dictionary in snapshot.listings: _listings[key(row)] = row
	return true

func captured() -> bool:
	return problem.is_empty() and snapshot.get("status") == "captured"

func rows() -> Array:
	return snapshot.get("listings",[]).duplicate(true)

func listing(id: String) -> Dictionary:
	return _listings.get(id,{}).duplicate(true)
