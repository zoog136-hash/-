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

static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _same_text(value: Variant, expected: String) -> bool:
	return value is String and value == expected

static func _scope_id(value: Variant, prefix: String) -> bool:
	if not value is String or not value.begins_with(prefix + ":"): return false
	var suffix: String = value.trim_prefix(prefix + ":")
	return not suffix.is_empty() and suffix.length() <= 16 and suffix.is_valid_int() and str(int(suffix)) == suffix and integer(int(suffix),1)

static func _sha256(value: Variant) -> bool:
	return value is String and value.length() == 64 and not value.begins_with("-") and not value.begins_with("+") and value.is_valid_hex_number(false)

static func _categories_problem(value: Variant, seen: Dictionary, required: bool) -> String:
	if not value is Array or (required and value.is_empty()): return "대표 서버 카테고리 목록 누락"
	for category: Variant in value:
		if not category is Dictionary or not integer(category.get("id"),1) or not _text(category.get("name")): return "대표 서버 카테고리 ID·이름 오류"
		var id: String = str(int(category.id))
		if seen.has(id): return "선택·제외 카테고리 중복"
		seen[id] = true
	return ""

static func _representative_problem(value: Dictionary, coverage: Dictionary, expected: Dictionary) -> String:
	if expected.size() != 1 or not _scope_id(expected.keys()[0],"server"): return "대표 서버는 공식 로컬 서버 1개여야 합니다"
	var selected_id: String = expected.keys()[0]
	if coverage.complete or not coverage.get("approximate") is bool or not coverage.approximate: return "대표 서버의 부분·근사 수집 선언 필요"
	if not value.get("test_fixture") is bool or value.test_fixture: return "대표 서버 실측은 test_fixture=false 선언 필요"
	var category_ids: Dictionary = {}
	var category_error: String = _categories_problem(coverage.get("selected_categories"),category_ids,true)
	if category_error.is_empty(): category_error = _categories_problem(coverage.get("omitted_categories"),category_ids,false)
	if not category_error.is_empty(): return category_error
	if not coverage.get("live_drift_recorded") is bool: return "실시간 매물 변동 관측 여부 누락"
	var proof: Variant = coverage.get("scope_proof")
	if not proof is Dictionary or not _same_text(proof.get("server_id"),selected_id) or not _scope_id(proof.get("world_id"),"world") or not https(proof.get("evidence_url")) or not _sha256(proof.get("sha256")): return "대표 서버·월드 연결의 실측 근거 오류"
	var survey: Variant = coverage.get("survey")
	if not survey is Dictionary or not _same_text(survey.get("scope"),"surveyed_candidates_only") or not _same_text(survey.get("metric"),"reported_local_catalog_group_count") or not _same_text(survey.get("selected_server_id"),selected_id): return "대표 서버의 조사 범위·로컬 매물 그룹 비교 기준 오류"
	if not survey.get("candidates") is Array or survey.candidates.is_empty(): return "대표 서버 조사 후보 누락"
	var candidates: Dictionary = {}
	var largest: int = 0
	var selected_count: int = -1
	for candidate: Variant in survey.candidates:
		if not candidate is Dictionary or not _scope_id(candidate.get("server_id"),"server") or not _scope_id(candidate.get("world_id"),"world"): return "조사 후보 서버·월드 ID 오류"
		if candidates.has(candidate.server_id): return "조사 후보 서버 중복"
		candidates[candidate.server_id] = true
		for field: String in ["reported_total","world_reported_total","local_group_count"]:
			if not integer(candidate.get(field),0): return "대표 서버 조사 수량 정수 오류"
		if int(candidate.local_group_count) != int(candidate.reported_total) - int(candidate.world_reported_total): return "로컬 매물 그룹 수는 전체·월드 조회 차이여야 합니다"
		if not https(candidate.get("evidence_url")) or not _sha256(candidate.get("sha256")) or not https(candidate.get("world_evidence_url")) or not _sha256(candidate.get("world_sha256")): return "조사 후보의 로컬·월드 응답 근거 오류"
		largest = maxi(largest,int(candidate.local_group_count))
		if candidate.server_id == selected_id:
			if candidate.world_id != proof.world_id: return "선택 서버의 공식 월드 연결 불일치"
			selected_count = int(candidate.local_group_count)
	if selected_count < 0 or selected_count != largest: return "선택 서버가 조사 후보 중 로컬 매물 그룹 최다가 아닙니다"
	return ""

static func validate(value: Variant) -> String:
	if not value is Dictionary or not _same_text(value.get("schema"),"twilight.frozen-exchange.v1"): return "거래소 스냅샷 형식 오류"
	var reset: Variant = value.get("reset")
	if not _same_text(value.get("price_policy"),"frozen_once") or not reset is Dictionary or not _same_text(reset.get("timezone"),"Asia/Seoul") or not integer(reset.get("hour"),5,5): return "고정 가격·한국 05시 초기화 정책 오류"
	if not https(value.get("source_url")) or not value.get("listings") is Array or not value.get("coverage") is Dictionary: return "거래소 출처·수집 범위 누락"
	var coverage: Dictionary = value.coverage
	if not value.has("captured_at") or not coverage.get("complete") is bool: return "수집 시각·완료 여부 누락"
	if not coverage.get("scope") is String or coverage.scope not in ["all_servers","representative_server"] or not coverage.get("expected_server_ids") is Array or not coverage.get("completed_server_ids") is Array: return "거래소 수집 범위 오류"
	if _same_text(value.get("status"),"not_captured"):
		return "" if coverage.scope == "all_servers" and value.get("captured_at") == null and not coverage.complete and coverage.expected_server_ids.is_empty() and coverage.completed_server_ids.is_empty() and value.listings.is_empty() else "미수집 상태에 임의 상품·수집 범위가 있습니다"
	if not _same_text(value.get("status"),"captured"): return "실측 수집 상태 오류"
	if coverage.scope == "all_servers" and not coverage.complete: return "전체 서버 실측 수집이 완료되지 않았습니다"
	var expected: Dictionary = {}
	for id: Variant in coverage.expected_server_ids:
		if not _text(id) or expected.has(id): return "서버 ID 중복·누락"
		expected[id] = true
	var completed: Dictionary = {}
	for id: Variant in coverage.completed_server_ids:
		if not id is String or completed.has(id) or not expected.has(id): return "완료 서버 목록 불일치"
		completed[id] = true
	if expected.is_empty() or completed.size() != expected.size(): return "선언한 수집 서버 누락"
	var known_markets: Dictionary = expected.duplicate()
	if coverage.scope == "representative_server":
		var representative_error: String = _representative_problem(value,coverage,expected)
		if not representative_error.is_empty(): return representative_error
		known_markets[coverage.scope_proof.world_id] = true
	var captured: Variant = value.get("captured_at")
	if not captured is String or captured.length() != 20 or not captured.ends_with("Z") or captured.substr(10,1) != "T" or Time.get_datetime_string_from_unix_time(Time.get_unix_time_from_datetime_string(captured.trim_suffix("Z"))) + "Z" != captured: return "수집 시각은 UTC ISO8601이어야 합니다"
	var seen: Dictionary = {}
	for item: Variant in value.listings:
		if not item is Dictionary: return "거래 상품 행 오류"
		for field: String in ["server_id","listing_id","item_name"]:
			if not _text(item.get(field)): return "상품 식별자·이름 누락"
		if not known_markets.has(item.server_id) or seen.has(key(item)): return "상품 서버·월드 범위 불일치·등록 ID 중복"
		seen[key(item)] = true
		for field: String in ["item_class_id","bundle_size","bundle_price","initial_bundles"]:
			if not integer(item.get(field),1): return "상품 정수 범위 오류: " + field
		if not integer(item.get("currency_unit_id"),34,34) or not integer(item.get("currency_class_id"),2,2): return "확인되지 않은 거래 재화"
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
