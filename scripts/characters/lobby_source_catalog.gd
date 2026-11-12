extends RefCounted
## Resolves only verified definition relationships. A resolved path is neither
## installed pixels nor a successful Spine/CSB renderer or original placement.
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const MAX_SOURCE_ID: int = 2147483647
const SOURCE_SCOPE := "VERIFIED_OWNED_523_DEFINITIONS_NOT_RENDERING"
const TEST_SCOPE := "SYNTHETIC_RELATION_TEST_NOT_ORIGINAL_DELIVERY"
var problem: String = ""
## Unit-test seam only; production leaves this null and uses DEFINITIONS.
var test_reader: Object
var _reader_id: int = -1
var _relations: Dictionary = {}
var _resolved: Dictionary = {}
var _identity: Dictionary = {}

func clear_cache() -> void:
	_relations.clear()
	_resolved.clear()
	_identity.clear()

func resolve(class_id: Variant, gender_id: Variant) -> Dictionary:
	problem = ""
	if not _uint(class_id, 1) or not _uint(gender_id, 1) or int(gender_id) not in [1, 2]:
		return _failure("invalid_request", "원본 로비의 직업·성별 ID가 올바르지 않습니다.")
	var active_reader: int = test_reader.get_instance_id() if test_reader != null else 0
	if active_reader != _reader_id:
		clear_cache()
		_reader_id = active_reader
	var identity_result: Dictionary = _verify_identity()
	if not identity_result.ok:
		clear_cache()
		return _failure("invalid_source_identity", identity_result.problem)
	_identity = identity_result.identity
	var key: String = "%d:%d" % [int(class_id), int(gender_id)]
	if _resolved.has(key): return _resolved[key].duplicate(true)
	var class_result: Dictionary = _unique("Class", "ID", int(class_id))
	if class_result.status != "resolved": return _failure(class_result.status, "원본 로비 직업 정의를 하나로 확인하지 못했습니다. " + str(class_result.get("problem", "")))
	var source_class: Dictionary = class_result.row
	if not source_class.get("CanCreateClient") is bool or source_class.CanCreateClient != true:
		return _failure("class_not_creatable", "생성 불가 원본 직업의 로비를 사용하지 않습니다.")
	var gender_result: Dictionary = _unique("Gender", "ID", int(gender_id))
	if gender_result.status != "resolved": return _failure(gender_result.status, "원본 로비 성별 정의를 하나로 확인하지 못했습니다.")
	var candidates: Dictionary = _related("ClassAssets", "ClassID", int(class_id))
	if not candidates.ok: return _failure("invalid_reference", candidates.problem)
	var by_gender: Dictionary = {}
	for value: Variant in candidates.rows:
		var row: Dictionary = value
		if not _uint(row.get("GenderID"), 1) or int(row.GenderID) not in [1, 2]: return _failure("invalid_reference", "원본 ClassAssets 성별 참조가 올바르지 않습니다.")
		var id: int = int(row.GenderID)
		if by_gender.has(id): return _failure("duplicate_reference", "원본 ClassAssets 직업·성별 연결이 중복됩니다.")
		by_gender[id] = row
	if not by_gender.has(int(gender_id)): return _failure("missing_reference", "정확한 직업·성별의 원본 로비 연결이 없습니다.")
	var assets: Dictionary = by_gender[int(gender_id)]
	for field: String in ["LobbySpineID", "LobbyBackEffectFile", "LobbyFrontEffectFile"]:
		if not _uint(assets.get(field), 1 if field == "LobbySpineID" else 0): return _failure("invalid_reference", "원본 ClassAssets.%s 참조가 올바르지 않습니다." % field)
	var spine: Dictionary = _spine(int(assets.LobbySpineID))
	var back: Dictionary = _asset(int(assets.LobbyBackEffectFile), 101)
	var front: Dictionary = _asset(int(assets.LobbyFrontEffectFile), 101)
	var result: Dictionary = {"ok": true, "status": "resolved", "problem": "", "class_id": int(class_id), "gender_id": int(gender_id), "source_identity": _identity.duplicate(true), "class_source": source_class.duplicate(true), "class_assets": assets.duplicate(true), "spine": spine, "back_effect": back, "front_effect": front, "missing": [], "synthetic": test_reader != null, "scope": TEST_SCOPE if test_reader != null else SOURCE_SCOPE}
	for role: String in ["spine", "back_effect", "front_effect"]:
		var layer: Dictionary = result[role]
		if layer.status in ["invalid_reference", "duplicate_reference"]:
			result.ok = false
			result.status = layer.status
			result.problem = str(layer.get("problem", "원본 로비 연결 오류"))
		elif layer.status == "missing_reference":
			result.missing.append({"role": role, "table": layer.get("table", ""), "field": layer.get("field", ""), "id": layer.get("id", 0), "asset_id": layer.get("asset_id", 0)})
	if not result.ok:
		problem = result.problem
		return result
	_resolved[key] = result.duplicate(true)
	return result

func _verify_identity() -> Dictionary:
	var value: Variant
	if test_reader != null:
		if not test_reader.has_method("identity") or not test_reader.has_method("related"):
			return {"ok": false, "problem": "로비 테스트 reader의 identity/related 계약이 없습니다."}
		value = test_reader.call("identity")
	else:
		value = DEFINITIONS.identity()
	if not value is Dictionary or value.get("kind") != "twilight.current523.original-definitions.v1" or value.get("source_snapshot") != "patch523" or value.get("source_sha256") != DEFINITIONS.SOURCE_SHA or not _uint(value.get("source_bytes"), 1) or int(value.source_bytes) != DEFINITIONS.SOURCE_BYTES:
		return {"ok": false, "problem": "로비 연결에는 검증된 원본523 정의가 필요합니다."}
	return {"ok": true, "identity": value.duplicate(true)}

func _related(table: String, field: String, id: int) -> Dictionary:
	var key: String = "%s:%s:%d" % [table, field, id]
	if _relations.has(key): return _relations[key].duplicate(true)
	var value: Variant = test_reader.call("related", table, field, id) if test_reader != null else DEFINITIONS.related(table, field, id)
	if not value is Array: return {"ok": false, "problem": "원본 %s 관계 결과가 배열이 아닙니다." % table}
	for raw: Variant in value:
		if not raw is Dictionary or not _uint(raw.get(field)) or int(raw[field]) != id:
			return {"ok": false, "problem": "원본 %s.%s 관계 행이 올바르지 않습니다." % [table, field]}
	var result: Dictionary = {"ok": true, "rows": value.duplicate(true)}
	_relations[key] = result.duplicate(true)
	return result

func _unique(table: String, field: String, id: int) -> Dictionary:
	var relation: Dictionary = _related(table, field, id)
	if not relation.ok: return {"ok": false, "status": "invalid_reference", "table": table, "field": field, "id": id, "problem": relation.problem}
	if relation.rows.size() > 1: return {"ok": false, "status": "duplicate_reference", "table": table, "field": field, "id": id, "problem": "원본 %s.%s #%d 참조가 중복됩니다." % [table, field, id]}
	if relation.rows.is_empty(): return {"ok": false, "status": "missing_reference", "table": table, "field": field, "id": id, "problem": "원본 %s.%s #%d 참조가 없습니다." % [table, field, id]}
	return {"ok": true, "status": "resolved", "row": relation.rows[0]}

func _spine(id: int) -> Dictionary:
	var source: Dictionary = _unique("UISpine", "ID", id)
	if source.status != "resolved":
		source["uispine_id"] = id
		source["asset_id"] = 0
		source["path"] = ""
		return source
	var row: Dictionary = source.row
	if not _uint(row.get("AssetID"), 1) or not _number(row.get("OffsetX")) or not _number(row.get("OffsetY")) or not row.get("Flip") is bool:
		return {"ok": false, "status": "invalid_reference", "uispine_id": id, "asset_id": row.get("AssetID", 0), "path": "", "problem": "원본 UISpine 자산·오프셋·반전 값이 올바르지 않습니다."}
	var result: Dictionary = _asset(int(row.AssetID), 22)
	result["uispine_id"] = id
	result["offset_x"] = row.OffsetX
	result["offset_y"] = row.OffsetY
	result["flip"] = row.Flip
	if not result.has("evidence"): result["evidence"] = {}
	result.evidence["uispine"] = row.duplicate(true)
	return result

func _asset(id: int, expected_type: int) -> Dictionary:
	if id == 0: return {"ok": true, "status": "optional_zero", "asset_id": 0, "asset_type_id": 0, "path": "", "evidence": {}}
	var source: Dictionary = _unique("AssetView", "AssetId", id)
	if source.status != "resolved":
		source["asset_id"] = id
		source["path"] = ""
		return source
	var row: Dictionary = source.row
	if not _uint(row.get("AssetTypeId"), 1) or int(row.AssetTypeId) != expected_type or not row.get("FilePath") is String:
		return {"ok": false, "status": "invalid_reference", "asset_id": id, "path": "", "problem": "원본 로비 자산 종류 또는 파일 경로 형식이 올바르지 않습니다.", "evidence": {"asset_view": row.duplicate(true)}}
	var type_result: Dictionary = _unique("AssetType", "ID", int(row.AssetTypeId))
	if type_result.status != "resolved":
		type_result["asset_id"] = id
		type_result["asset_type_id"] = int(row.AssetTypeId)
		type_result["path"] = ""
		return type_result
	var asset_type: Dictionary = type_result.row
	var error: String = _path_problem(asset_type.get("Path"), row.FilePath)
	if not error.is_empty(): return {"ok": false, "status": "invalid_reference", "asset_id": id, "asset_type_id": int(row.AssetTypeId), "path": "", "problem": error, "evidence": {"asset_view": row.duplicate(true), "asset_type": asset_type.duplicate(true)}}
	return {"ok": true, "status": "resolved", "asset_id": id, "asset_type_id": int(row.AssetTypeId), "path": str(asset_type.Path) + str(row.FilePath), "evidence": {"asset_view": row.duplicate(true), "asset_type": asset_type.duplicate(true)}}

static func _path_problem(prefix: Variant, file: Variant) -> String:
	if not prefix is String or not file is String or prefix.is_empty() or file.is_empty() or not prefix.ends_with("/") or file.ends_with("/") or prefix.begins_with("/") or file.begins_with("/"):
		return "원본 로비 자산의 상대 경로가 올바르지 않습니다."
	var path: String = prefix + file
	if path != path.strip_edges() or "\\" in path or ":" in path or "%" in path or "?" in path or "#" in path:
		return "원본 로비 자산의 경로 이탈·URI 표기를 거부합니다."
	for index: int in path.length():
		var code: int = path.unicode_at(index)
		if code < 32 or code == 127: return "원본 로비 자산 경로에 제어 문자가 있습니다."
	var pieces: PackedStringArray = path.split("/", true)
	for piece: String in pieces:
		if piece in ["", ".", ".."] or piece != piece.strip_edges(): return "원본 로비 자산의 경로 이탈·정규화 대체를 거부합니다."
	return ""

func _failure(status: String, message: String) -> Dictionary:
	problem = message
	return {"ok": false, "status": status, "problem": message, "source_identity": _identity.duplicate(true), "spine": {}, "back_effect": {}, "front_effect": {}, "missing": [], "synthetic": test_reader != null, "scope": TEST_SCOPE if test_reader != null else SOURCE_SCOPE}

static func _uint(value: Variant, minimum: int = 0) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= MAX_SOURCE_ID

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
