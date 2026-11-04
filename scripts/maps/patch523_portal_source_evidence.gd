extends RefCounted
## Optional private research evidence. Never supplies travel or collision rules.
const ARCHIVE_SHA256 = "7fa773dfa1e040ba6afc9eed917b90f1a6bbca4cd64fbef44b0b85fe3697c71f"
const RECORDS = "target4_namespace/new50_target4_to_M_Land4_Aden_candidates.json"
const PROOFS = "target4_namespace/new50_fresh_original_record_and_source_proofs.json"
var loaded: bool = false
var problem: String = ""
var by_portal: Dictionary = {}

static func configured_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--patch523-map-evidence="): return arg.trim_prefix("--patch523-map-evidence=")
	return ""

static func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256); context.update(bytes)
	return context.finish().hex_encode()

func _fail(message: String) -> bool:
	loaded = false; by_portal.clear(); problem = message
	return false

func load_archive(path: String, catalog: RefCounted) -> bool:
	loaded = false; by_portal.clear(); problem = ""
	if catalog == null or not catalog.loaded: return _fail("원본 포탈 정의 연결 필요")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != ARCHIVE_SHA256:
		return _fail("인계 ZIP이 없거나 SHA256이 다릅니다")
	var zip := ZIPReader.new()
	if zip.open(path) != OK: return _fail("인계 ZIP을 읽을 수 없습니다")
	var files: PackedStringArray = zip.get_files()
	var inventory: Variant = JSON.parse_string(zip.read_file("DELIVERY_MANIFEST.json").get_string_from_utf8())
	if not inventory is Dictionary or not inventory.get("files") is Array:
		zip.close(); return _fail("인계 파일 목록 오류")
	var seen: Dictionary = {}
	for item: Variant in inventory.files:
		if not item is Dictionary or not item.get("path") is String:
			zip.close(); return _fail("인계 파일 항목 오류")
		var name: String = item.path
		if seen.has(name) or name not in files:
			zip.close(); return _fail("인계 파일 누락 또는 중복")
		var body: PackedByteArray = zip.read_file(name)
		if body.size() != item.get("bytes") or digest(body) != item.get("sha256"):
			zip.close(); return _fail("인계 파일 무결성 오류")
		seen[name] = true
	if seen.size() != 64 or files.size() != 65 or not seen.has(RECORDS) or not seen.has(PROOFS):
		zip.close(); return _fail("지원되지 않는 인계 파일 구성")
	var records: Variant = JSON.parse_string(zip.read_file(RECORDS).get_string_from_utf8())
	var proofs: Variant = JSON.parse_string(zip.read_file(PROOFS).get_string_from_utf8())
	zip.close()
	if not records is Array or not proofs is Array or records.size() != 50 or proofs.size() != 50:
		return _fail("행별 포탈 근거 구성 오류")
	var proof_index: Dictionary = {}
	for proof: Dictionary in proofs:
		var key: String = "%s@%d" % [proof.member, int(proof.source_byte_offset)]
		if proof_index.has(key): return _fail("중복 원문 위치")
		proof_index[key] = proof
	var sources: Dictionary = {}
	var selected: Dictionary = {}
	for row: Dictionary in records:
		if row.M_source_coordinate_exact_Portals.size() != 1: return _fail("포탈 대응이 유일하지 않습니다")
		var match_row: Dictionary = row.M_source_coordinate_exact_Portals[0]
		var portal: Dictionary = match_row.Portal
		var id: int = int(portal.ID)
		var lid: int = int(portal.SourceLandID)
		if selected.has(id): return _fail("중복 포탈 선언")
		if not sources.has(lid):
			var spec: Dictionary = catalog.manifest.lands.get(str(lid), {})
			if spec.get("file") != "lands/%d.json" % lid: return _fail("출발 지역 경로 불일치")
			var shard: Dictionary = catalog._object(catalog.root.path_join(spec.file), spec)
			if not shard.get("portals") is Array: return _fail("출발 지역 정의 누락")
			sources[lid] = shard
		var source: Dictionary = sources[lid]
		if source.get("land") != match_row.SourceLand: return _fail("출발 지역 선언 불일치")
		var declarations: Array = source.portals.filter(func(entry: Dictionary) -> bool: return entry.portal.ID == id)
		if declarations.size() != 1: return _fail("현재 포탈 선언 누락 또는 중복")
		var declaration: Dictionary = declarations[0]
		if declaration.portal != portal or declaration.target_territory != match_row.TargetTerritory or declaration.target_land != match_row.TargetLand:
			return _fail("현재 포탈·도착 영역 선언 불일치")
		var raw: Dictionary = row.raw_record
		var key: String = "%s@%d" % [raw.member, int(raw.source_byte_offset)]
		var proof: Dictionary = proof_index.get(key, {})
		if proof.is_empty() or proof.raw_record_hex != raw.raw_hex or digest(str(raw.raw_hex).hex_decode()) != proof.raw_record_sha256:
			return _fail("원문 기록 해시 불일치")
		if row.source_coordinate_candidate != [portal.SourceX, portal.SourceY] or row.direct_LandID_target_candidate_PortalIDs != [portal.ID]:
			return _fail("출발 좌표 대조 불일치")
		# Keep the JSON ID type for membership in a JSON-decoded Array.
		selected[id] = {"raw_record": raw.duplicate(true), "proof": proof.duplicate(true),
			"source_land_id": lid, "packed_target_candidate": row.signed_packed_target_coordinate_candidate.duplicate(),
			"packed_target_within_declared_territory": portal.ID in row.direct_LandID_candidate_target_containment_PortalIDs,
			"runtime_enabled": false, "scope": "RESEARCH_METADATA_ONLY; NOT_TRIGGER_ARRIVAL_OR_COLLISION"}
	by_portal = selected; loaded = true
	return true

func for_portal(id: int) -> Dictionary:
	return by_portal.get(id, {}).duplicate(true) if loaded else {}

func aden_count() -> int:
	return by_portal.values().filter(func(row: Dictionary) -> bool: return row.source_land_id == 4).size() if loaded else 0

static func display_lines(evidence: Dictionary) -> Array[String]:
	if evidence.is_empty(): return []
	var proof: Dictionary = evidence.proof
	var candidate: Array = evidence.packed_target_candidate
	var lines: Array[String] = ["", "원문 대조 근거: %s@%d" % [evidence.raw_record.member, int(evidence.raw_record.source_byte_offset)],
		"출발 좌표는 현재 포탈 선언과 일치합니다.", "도착 좌표 추정 후보: (%d, %d)" % [int(candidate[0]), int(candidate[1])]]
	lines.append("추정 후보가 선언 도착 영역 안에 있습니다." if evidence.packed_target_within_declared_territory else "주의: 추정 후보와 선언 도착 영역이 다릅니다. 선언값을 유지합니다.")
	lines.append("출처: 현행 DAT 해시·원문 검증 계열" if proof.current_DAT_SHA1_freshly_rehashed else "출처: 현행 선택 목록의 보존508 원문 · 현행 DAT 재해시 미확인")
	lines.append("원문 SHA256: " + str(proof.raw_record_sha256))
	lines.append("이 대조는 포탈 활성·트리거·도착 선택·통행 허가를 뜻하지 않습니다.")
	return lines
