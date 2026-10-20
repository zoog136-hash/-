extends RefCounted
class_name TwilightEquipmentCollectionService
## Equipment-only service. No implicit inventory rename, item creation or save I/O.
## Integrator supplies verified source IDs, explicit combat capabilities and one
## synchronous atomic writer for the WHOLE adapted game snapshot.

var _by_id: Dictionary = {}
var _aliases: Dictionary = {}
var _catalog: Dictionary = {}
var _by_name: Dictionary = {}
var _supported: Dictionary = {}
var _state: Dictionary = {}
var _writer: Callable
var _busy: bool = false
var last_error: String = ""

static func normalize_name(value: String) -> String:
	var marker: RegEx = RegEx.new()
	marker.compile("\\(\\s*각인\\s*\\)|\\[\\s*각인\\s*\\]|（\\s*각인\\s*）|(?<!\\S)각인(?!\\S)")
	var spaces: RegEx = RegEx.new()
	spaces.compile("\\s+")
	return spaces.sub(marker.sub(value, "", true), " ", true).strip_edges()

static func effect_code(effect: Dictionary) -> String:
	return str(effect.get("key", "")) + ":" + str(effect.get("unit", ""))

static func fresh_state() -> Dictionary:
	return {"schema_version": 2, "revision": 0, "gear": {}, "progress": {},
		"receipts": {}, "requests": {}, "favorites": [], "preserved_legacy": {}}

static func _integer(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) >= 0.0 and float(value) == floor(float(value))

func configure(definitions: Dictionary, catalog_rows: Array, supported_effects: Array) -> bool:
	_by_id.clear()
	_catalog.clear()
	_by_name.clear()
	_supported.clear()
	_aliases = definitions.get("source_aliases", {}).duplicate(true)
	last_error = ""
	for raw: Variant in definitions.get("collections", []):
		if not raw is Dictionary:
			return _configuration_error("잘못된 컬렉션 정의")
		var c: Dictionary = raw.duplicate(true)
		var cid: String = str(c.get("id", ""))
		if cid.is_empty() or _by_id.has(cid) or c.get("requirements", []).is_empty():
			return _configuration_error("컬렉션 ID 중복 또는 요구 재료 누락")
		var seen_slots: Dictionary = {}
		for req: Dictionary in c.get("requirements", []):
			var slot_id: String = str(req.get("slot_id", ""))
			var item_name: String = str(req.get("name", ""))
			if slot_id.is_empty() or seen_slots.has(slot_id) or item_name.is_empty():
				return _configuration_error("잘못된 슬롯 정의")
			if normalize_name(item_name) != item_name or not _integer(req.get("quantity")) or int(req.quantity) < 1:
				return _configuration_error("잘못된 장비명 또는 수량")
			if bool(c.get("data_ready", false)) and not _integer(req.get("enchant")):
				return _configuration_error("강화 무표기 항목은 보류해야 함")
			seen_slots[slot_id] = true
		if bool(c.get("data_ready", false)) and (c.get("effects", []).is_empty() or not c.get("review_reasons", []).is_empty()):
			return _configuration_error("검토 항목의 활성화 금지")
		for effect: Dictionary in c.get("effects", []):
			if not effect.get("value") is float and not effect.get("value") is int:
				return _configuration_error("효과 수치 오류")
			if not is_finite(float(effect.value)) or not str(effect.get("unit", "")) in ["flat", "percent"]:
				return _configuration_error("효과 단위 오류")
		_by_id[cid] = c
	for raw: Variant in catalog_rows:
		if not raw is Dictionary:
			return _configuration_error("아이템 카탈로그 형식 오류")
		var row: Dictionary = raw.duplicate(true)
		var source_id: String = str(row.get("source_id", ""))
		if source_id.is_empty() or _catalog.has(source_id) or not row.get("name") is String:
			return _configuration_error("아이템 원본 ID 누락/중복")
		_catalog[source_id] = row
		if str(row.get("kind", "")) == "equipment":
			_by_name[normalize_name(str(row.name))] = true
	for key: Variant in supported_effects:
		_supported[str(key)] = true
	return true

func _configuration_error(message: String) -> bool:
	last_error = message
	_by_id.clear()
	return false

func resolve(id: String) -> Dictionary:
	return _by_id.get(str(_aliases.get(id, id)), {}).duplicate(true)

func definitions() -> Array:
	return _by_id.values().duplicate(true)

func availability(id: String) -> Dictionary:
	var c: Dictionary = resolve(id)
	if c.is_empty():
		return _error("unknown_collection", "알 수 없는 컬렉션")
	if not bool(c.get("data_ready", false)):
		return _error("review", " / ".join(c.get("review_reasons", [])))
	for req: Dictionary in c.requirements:
		if not _by_name.has(str(req.name)):
			return _error("unbound_item", "게임 장비 ID 미매칭: " + str(req.name))
	for effect: Dictionary in c.effects:
		if not _supported.has(effect_code(effect)):
			return _error("unsupported_effect", "게임 효과 미연결: " + str(effect.raw))
	return {"ok": true}

func validate_state(state: Dictionary) -> String:
	if int(state.get("schema_version", -1)) != 2 or not _integer(state.get("revision")):
		return "저장 버전/리비전 오류. 원본 저장을 변경하지 않습니다."
	for key: String in ["gear", "progress", "receipts", "requests"]:
		if not state.get(key) is Dictionary:
			return "저장 구조 손상: " + key
	var used: Dictionary = {}
	for raw_cid: Variant in state.progress:
		var cid: String = str(raw_cid)
		var slots: Variant = state.progress[raw_cid]
		if not slots is Dictionary:
			return "진행도 슬롯 형식 오류"
		var c: Dictionary = _by_id.get(cid, {})
		for raw_sid: Variant in slots:
			var sid: String = str(raw_sid)
			var ids: Variant = slots[raw_sid]
			if not ids is Array:
				return "영수증 목록 형식 오류"
			var req: Dictionary = _requirement(c, sid)
			if not c.is_empty() and (req.is_empty() or ids.size() > int(req.quantity)):
				return "알 수 없는 슬롯 또는 초과 수량"
			for raw_id: Variant in ids:
				var item_id: String = str(raw_id)
				if used.has(item_id) or not state.receipts.has(item_id) or state.gear.has(item_id):
					return "중복 사용 또는 누락된 실물 장비 영수증"
				used[item_id] = true
				var receipt: Variant = state.receipts[item_id]
				if not receipt is Dictionary:
					return "영수증 형식 오류"
				if str(receipt.get("instance_id", "")) != item_id or str(receipt.get("collection_id", "")) != cid or str(receipt.get("slot_id", "")) != sid:
					return "영수증 대상 불일치"
				if not req.is_empty() and (str(receipt.get("canonical_name", "")) != str(req.name) or receipt.get("enchant") != req.enchant):
					return "영수증 장비/강화 조건 불일치"
	for raw_id: Variant in state.receipts:
		if not used.has(str(raw_id)):
			return "슬롯에 연결되지 않은 영수증"
	for raw_id: Variant in state.gear:
		var item: Variant = state.gear[raw_id]
		if not item is Dictionary:
			return "실물 장비 형식 오류"
		if str(item.get("instance_id", "")) != str(raw_id) or not item.get("name") is String or not item.get("source_id") is String:
			return "실물 장비 ID/이름 오류"
		if not _integer(item.get("enchant")) or not item.get("equipped") is bool or not item.get("locked") is bool or item.get("quantity") != 1:
			return "실물 장비 강화/장착/잠금/수량 정보 오류"
	return ""

func install_state(state: Dictionary, writer: Callable) -> bool:
	last_error = validate_state(state)
	if not last_error.is_empty():
		return false
	_state = state.duplicate(true)
	_writer = writer
	return true

func state() -> Dictionary:
	return _state.duplicate(true)

func _requirement(collection: Dictionary, slot_id: String) -> Dictionary:
	for req: Dictionary in collection.get("requirements", []):
		if str(req.get("slot_id", "")) == slot_id:
			return req
	return {}

func candidate_reason(item: Dictionary, req: Dictionary) -> String:
	if item.is_empty():
		return "소유하지 않은 장비"
	if bool(item.get("equipped", false)):
		return "장착 중인 장비"
	if bool(item.get("locked", false)):
		return "잠긴 장비"
	var source: Dictionary = _catalog.get(str(item.get("source_id", "")), {})
	if source.is_empty() or str(source.get("kind", "")) != "equipment":
		return "검증된 장비 원본 ID 없음"
	if normalize_name(str(item.get("name", ""))) != normalize_name(str(source.name)):
		return "장비명과 원본 ID 불일치"
	if normalize_name(str(item.name)) != str(req.get("name", "")):
		return "다른 장비"
	if item.get("enchant") != req.get("enchant"):
		return "요구 강화 수치 불일치"
	return ""

func candidates(snapshot: Dictionary, cid: String, slot_id: String) -> Array:
	var out: Array = []
	if not bool(availability(cid).get("ok", false)):
		return out
	var req: Dictionary = _requirement(resolve(cid), slot_id)
	if req.is_empty():
		return out
	for item: Dictionary in snapshot.get("gear", {}).values():
		if candidate_reason(item, req).is_empty() and not snapshot.get("receipts", {}).has(str(item.instance_id)):
			out.append(item.duplicate(true))
	return out

func complete(snapshot: Dictionary, cid: String) -> bool:
	if not snapshot.get("progress",{}).has(str(_aliases.get(cid,cid))): return false
	var c: Dictionary = resolve(cid)
	if c.is_empty() or not bool(availability(cid).get("ok", false)):
		return false
	var slots: Dictionary = snapshot.get("progress", {}).get(str(c.id), {})
	var seen: Dictionary = {}
	for req: Dictionary in c.requirements:
		var ids: Array = slots.get(str(req.slot_id), [])
		if ids.size() != int(req.quantity):
			return false
		for raw_id: Variant in ids:
			var item_id: String = str(raw_id)
			if seen.has(item_id) or snapshot.get("gear", {}).has(item_id):
				return false
			seen[item_id] = true
			var receipt: Dictionary = snapshot.get("receipts", {}).get(item_id, {})
			var source: Dictionary = _catalog.get(str(receipt.get("source_id", "")), {})
			if source.is_empty() or str(source.get("kind", "")) != "equipment":
				return false
			if str(receipt.get("collection_id", "")) != str(c.id) or str(receipt.get("slot_id", "")) != str(req.slot_id):
				return false
			if normalize_name(str(source.name)) != str(req.name) or str(receipt.get("canonical_name", "")) != str(req.name) or receipt.get("enchant") != req.enchant:
				return false
	return true

func bonuses(snapshot: Dictionary) -> Dictionary:
	var error: String = validate_state(snapshot)
	if not error.is_empty():
		last_error = error
		return {}
	var total: Dictionary = {}
	for c: Dictionary in _by_id.values():
		if complete(snapshot, str(c.id)):
			for effect: Dictionary in c.effects:
				var key: String = effect_code(effect)
				total[key] = float(total.get(key, 0.0)) + float(effect.value)
	return total

func prepare_registration(snapshot: Dictionary, request: Dictionary) -> Dictionary:
	var error: String = validate_state(snapshot)
	if not error.is_empty():
		return _error("invalid_save", error)
	var c: Dictionary = resolve(str(request.get("collection_id", "")))
	if c.is_empty():
		return _error("unknown_collection", "컬렉션을 찾을 수 없습니다")
	var request_id: String = str(request.get("request_id", ""))
	var slot_id: String = str(request.get("slot_id", ""))
	if request_id.strip_edges().is_empty() or not request.get("instance_ids") is Array:
		return _error("invalid_request", "요청 ID 또는 장비 목록 오류")
	var ids: Array = request.instance_ids.duplicate()
	var sorted_ids: Array = ids.duplicate()
	sorted_ids.sort()
	var payload: Dictionary = {"collection_id": str(c.id), "slot_id": slot_id, "instance_ids": sorted_ids}
	if snapshot.requests.has(request_id):
		if snapshot.requests[request_id] != payload:
			return _error("request_collision", "같은 요청 ID에 다른 장비가 지정됨")
		return {"ok": true, "already_applied": true, "state": snapshot.duplicate(true), "completed": complete(snapshot, str(c.id))}
	if request.get("expected_revision") != snapshot.revision:
		return _error("stale_state", "인벤토리가 변경되었습니다. 다시 선택하세요")
	var ready: Dictionary = availability(str(c.id))
	if not bool(ready.get("ok", false)):
		return ready
	var req: Dictionary = _requirement(c, slot_id)
	if req.is_empty():
		return _error("unknown_slot", "해당 컬렉션의 슬롯이 아닙니다")
	var prior: Array = snapshot.progress.get(str(c.id), {}).get(slot_id, [])
	if ids.is_empty():
		return _error("empty_selection", "등록 장비를 선택하세요")
	if prior.size() + ids.size() > int(req.quantity):
		return _error("slot_full", "이미 등록했거나 요구 수량을 초과했습니다")
	var seen: Dictionary = {}
	for raw_id: Variant in ids:
		var item_id: String = str(raw_id)
		if seen.has(item_id):
			return _error("duplicate_instance", "동일한 실물 장비 중복 선택")
		seen[item_id] = true
		if snapshot.receipts.has(item_id):
			return _error("already_consumed", "이미 사용한 실물 장비")
		var reason: String = candidate_reason(snapshot.gear.get(item_id, {}), req)
		if not reason.is_empty():
			return _error("ineligible_item", reason)
	var next: Dictionary = snapshot.duplicate(true)
	if not next.progress.has(str(c.id)):
		next.progress[str(c.id)] = {}
	next.progress[str(c.id)][slot_id] = prior.duplicate()
	for raw_id: Variant in ids:
		var item_id: String = str(raw_id)
		var item: Dictionary = next.gear[item_id]
		next.receipts[item_id] = {"instance_id": item_id, "source_id": str(item.source_id), "original_name": str(item.name),
			"canonical_name": str(req.name), "enchant": item.enchant, "collection_id": str(c.id), "slot_id": slot_id,
			"request_id": request_id, "registered_at": str(request.get("timestamp", Time.get_datetime_string_from_system(true)))}
		next.progress[str(c.id)][slot_id].append(item_id)
		next.gear.erase(item_id)
	next.requests[request_id] = payload
	next.revision = int(next.revision) + 1
	error = validate_state(next)
	if not error.is_empty():
		return _error("invalid_save", error)
	return {"ok": true, "already_applied": false, "state": next, "completed": complete(next, str(c.id))}

func register(request: Dictionary) -> Dictionary:
	if _busy:
		return _error("busy", "이전 등록을 저장 중입니다")
	_busy = true
	var result: Dictionary = prepare_registration(_state, request)
	if not bool(result.get("ok", false)) or bool(result.get("already_applied", false)):
		_busy = false
		return result
	if not _writer.is_valid() or _writer.call(result.state.duplicate(true), int(_state.revision)) != true:
		_busy = false
		return _error("save_failed", "저장 실패. 장비와 컬렉션 진행도는 그대로입니다")
	_state = result.state.duplicate(true)
	_busy = false
	return result

static func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
