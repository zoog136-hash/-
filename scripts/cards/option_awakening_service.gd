extends RefCounted
## Pure option-awakening rules. Preparation never changes the caller's cards,
## money, progression or RNG. The runtime commits one complete game save first.
const Cards = preload("res://scripts/card_draw_fusion.gd")
const CATEGORIES: Array[String] = ["변신", "마법인형", "성물"]
const GRADES: Array[String] = ["영웅", "전설", "신화", "유일"]
const MAX_COUNT: int = 1000000
const MAX_REVISION: int = 9007199254740000
const STAT_KEYS: Array[String] = [
	"hpFlat", "hpPct", "strFlat", "dexFlat", "intFlat", "weightBonus", "def",
	"attackSpeed", "moveSpeedPct", "xp", "blessing_consumption_reduction_pct",
	"skillCooldownPct", "damage_reduction_ignore", "meleeHit", "rangedHit", "magicHit",
	"potionHealFlat", "sp"
]
var problem: String = ""
var policy: Dictionary = {}
var definitions: Dictionary = {}
var catalog: Dictionary = {}
var probabilities: Dictionary = {}
var collections: Array = []
var unavailable: Array = []

static func fresh_state() -> Dictionary:
	return {"version": 1, "revision": 0, "rng_state": "", "cards": {"변신": {}, "마법인형": {}, "성물": {}}}

static func fresh_card() -> Dictionary:
	return {"experience": 0, "awakened": false, "attempts": 0, "failures": 0}

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "error": message}

func _configuration_error(message: String) -> bool:
	problem = message
	return false

func configure(data: Dictionary, settings: Dictionary, source_catalog: Dictionary) -> bool:
	problem = ""
	definitions.clear()
	catalog.clear()
	probabilities.clear()
	collections.clear()
	unavailable.clear()
	if int(data.get("schema_version", 0)) != 1 or int(settings.get("schema_version", 0)) != 1:
		return _configuration_error("지원하지 않는 옵션 각성 설정 버전")
	if not data.get("cards", null) is Array or not settings.get("grades", null) is Dictionary:
		return _configuration_error("옵션 각성 데이터 형식 오류")
	policy = settings.duplicate(true)
	if not integer(policy.get("experience_required")) or int(policy.experience_required) < 1 or int(policy.experience_required) > 100000:
		return _configuration_error("각성 필요 경험치 설정 오류")
	if policy.get("feed_cost", -1) != 0 or policy.get("overflow", "") != "discard" or policy.get("pity_enabled", true) != false:
		return _configuration_error("지원하지 않는 각성 주입 비용·초과 경험치·보장 설정")
	if policy.get("target_requires_owned", false) != true or policy.get("consume_duplicates_only", false) != true:
		return _configuration_error("각성은 보유 카드와 중복 재료만 사용할 수 있습니다")
	for grade: String in GRADES:
		var rule: Variant = policy.grades.get(grade)
		if not rule is Dictionary or not rule.get("material_experience") is Dictionary or rule.material_experience.is_empty():
			return _configuration_error("각성 재료 경험치 설정 누락: " + grade)
		for material_grade: Variant in rule.material_experience:
			var amount: Variant = rule.material_experience[material_grade]
			if not Cards.GRADES.has(material_grade) or not integer(amount) or int(amount) < 1 or int(amount) > int(policy.experience_required):
				return _configuration_error("각성 재료 경험치 설정 오류: " + grade)
		for field: String in ["attempt_cost", "failure_refund_experience"]:
			if not integer(rule.get(field)) or int(rule[field]) < 0 or int(rule[field]) > MAX_REVISION:
				return _configuration_error("각성 비용·환급 설정 오류: " + grade)
		if int(rule.failure_refund_experience) >= int(policy.experience_required):
			return _configuration_error("각성 실패 환급은 필요 경험치보다 작아야 합니다")
	var provenance: Variant = data.get("provenance", {})
	if not provenance is Dictionary or not provenance.get("sources") is Dictionary:
		return _configuration_error("공식 각성 확률 출처 누락")
	for category: String in CATEGORIES:
		catalog[category] = {}
		definitions[category] = {}
		probabilities[category] = {}
		for raw: Variant in source_catalog.get(category, []):
			if not raw is Dictionary: continue
			var identity: String = Cards.card_id(raw)
			if identity.is_empty() or catalog[category].has(identity):
				return _configuration_error("카탈로그 카드 ID 누락 또는 중복: " + category)
			catalog[category][identity] = raw.duplicate(true)
		var source: Variant = provenance.sources.get(category)
		if not source is Dictionary or not source.get("success_probabilities") is Array:
			return _configuration_error("공식 각성 확률 누락: " + category)
		for row: Variant in source.success_probabilities:
			if not row is Dictionary: return _configuration_error("각성 확률 형식 오류")
			var grade: String = str(row.get("rarity", ""))
			var rate: Variant = row.get("probability_percent")
			if not GRADES.has(grade) or not (rate is float or rate is int) or not is_finite(float(rate)) or float(rate) <= 0.0 or float(rate) > 100.0 or probabilities[category].has(grade):
				return _configuration_error("각성 확률 범위 또는 등급 오류")
			probabilities[category][grade] = int(round(float(rate) * 100.0))
		if probabilities[category].size() != GRADES.size(): return _configuration_error("등급별 각성 확률 누락")
	var seen: Dictionary = {}
	for raw: Variant in data.cards:
		if not raw is Dictionary: return _configuration_error("각성 카드 정의 형식 오류")
		var row: Dictionary = raw
		var category: String = str(row.get("category", ""))
		var identity: String = str(row.get("id", ""))
		var grade: String = str(row.get("grade", ""))
		var composite: String = category + ":" + identity
		if not CATEGORIES.has(category) or not GRADES.has(grade) or identity.is_empty() or seen.has(composite):
			return _configuration_error("각성 카드 ID·분류·등급 오류")
		seen[composite] = true
		if not _valid_stats(row.get("stats")): return _configuration_error("미지원 각성 수치가 활성 옵션에 포함됨: " + identity)
		for field: String in ["bonus_options", "applied_options", "pending_options"]:
			if not row.get(field) is Array: return _configuration_error("각성 옵션 설명 형식 오류")
			for text: Variant in row[field]:
				if not text is String: return _configuration_error("각성 옵션 문자열 오류")
		var current: Dictionary = catalog[category].get(identity, {})
		if current.is_empty() or str(current.get("name", "")) != str(row.get("expected_name", "")) or str(current.get("grade", "")) != grade:
			unavailable.append({"category": category, "id": identity, "reason": "카탈로그 ID·이름·등급 확인 불가"})
			continue
		definitions[category][identity] = row.duplicate(true)
	for raw: Variant in data.get("collections", []):
		if not raw is Dictionary or not raw.get("requirements") is Array or raw.requirements.is_empty() or not _valid_stats(raw.get("stats")):
			return _configuration_error("각성 컬렉션 정의 오류")
		var row: Dictionary = raw.duplicate(true)
		row["available"] = true
		for requirement: Variant in row.requirements:
			if not requirement is Dictionary or not requirement.get("awakened") is bool:
				return _configuration_error("각성 컬렉션 조건 형식 오류")
			var category: String = str(requirement.get("category", ""))
			var identity: String = str(requirement.get("id", ""))
			var record: Dictionary = catalog.get(category, {}).get(identity, {})
			if record.is_empty() or str(record.get("name", "")) != str(requirement.get("name", "")) or str(record.get("grade", "")) != str(requirement.get("grade", "")):
				row.available = false
			if bool(requirement.awakened) and not definitions.get(category, {}).has(identity): row.available = false
		collections.append(row)
	return true

func _valid_stats(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key: Variant in value:
		if not STAT_KEYS.has(key) or not (value[key] is int or value[key] is float) or not is_finite(float(value[key])) or float(value[key]) < 0.0:
			return false
	return true

func definition(category: String, identity: String) -> Dictionary:
	return definitions.get(category, {}).get(identity, {}).duplicate(true)

func card_progress(state: Dictionary, category: String, identity: String) -> Dictionary:
	return state.get("cards", {}).get(category, {}).get(identity, fresh_card()).duplicate(true)

func owned(card_state: Dictionary, category: String, identity: String) -> bool:
	return card_state.get("owned", {}).get(category, {}).get(identity, false) == true

func awakened(state: Dictionary, category: String, identity: String) -> bool:
	return definitions.get(category, {}).has(identity) and bool(card_progress(state, category, identity).awakened)

func validate_state(value: Variant, card_state: Variant = null) -> String:
	if not value is Dictionary: return "각성 저장 형식 오류"
	var state: Dictionary = value
	if not integer(state.get("version")) or int(state.version) != 1: return "지원하지 않는 각성 저장 버전"
	if not integer(state.get("revision")) or int(state.revision) < 0 or int(state.revision) >= MAX_REVISION: return "각성 저장 revision 오류"
	if not state.get("rng_state", "") is String: return "각성 난수 저장 형식 오류"
	var rng_text: String = str(state.get("rng_state", ""))
	if not rng_text.is_empty() and (not rng_text.is_valid_int() or str(int(rng_text)) != rng_text): return "각성 난수 저장 값 오류"
	if not state.get("cards") is Dictionary: return "각성 카드 저장 형식 오류"
	for category: String in CATEGORIES:
		if not state.cards.get(category) is Dictionary: return "각성 분류 저장 누락"
	if card_state != null and (not card_state is Dictionary or not card_state.get("owned", {}) is Dictionary): return "각성 카드 보유 저장 형식 오류"
	for category: Variant in state.cards:
		if not category is String or not state.cards[category] is Dictionary: return "각성 분류 저장 형식 오류"
		for identity: Variant in state.cards[category]:
			var entry: Variant = state.cards[category][identity]
			if not identity is String or identity.is_empty() or not entry is Dictionary or not entry.get("awakened") is bool: return "각성 진행 저장 형식 오류"
			for field: String in ["experience", "attempts", "failures"]:
				if not integer(entry.get(field)) or int(entry[field]) < 0 or int(entry[field]) > MAX_COUNT: return "각성 진행 수치 오류"
			if int(entry.experience) > int(policy.experience_required) or int(entry.failures) > int(entry.attempts): return "각성 경험치·시도 횟수 범위 오류"
			if bool(entry.awakened) and int(entry.experience) != 0: return "완료된 각성 카드의 경험치 저장 오류"
			# Unknown IDs/fields survive same-version round trips but never confer a
			# bonus. Known progress must remain attached to a permanent base unlock.
			if card_state != null and definitions.get(category, {}).has(identity):
				var category_owned: Variant = card_state.get("owned", {}).get(category, {})
				if not category_owned is Dictionary or category_owned.get(identity, false) != true: return "미보유 카드의 각성 진행 저장 오류"
	return ""

func normalized_state(value: Dictionary) -> Dictionary:
	# JSON parses numeric fields as doubles. Normalize only this schema's integer
	# fields; unknown future metadata (including fractional values) is retained.
	var out: Dictionary = value.duplicate(true)
	out.version = int(out.version)
	out.revision = int(out.revision)
	for category: String in out.cards:
		for identity: String in out.cards[category]:
			for field: String in ["experience", "attempts", "failures"]:
				out.cards[category][identity][field] = int(out.cards[category][identity][field])
	return out

func view(state: Dictionary, card_state: Dictionary, gold: int, category: String, identity: String) -> Dictionary:
	if not problem.is_empty(): return fail("configuration", problem)
	var row: Dictionary = definition(category, identity)
	if row.is_empty(): return fail("unavailable", "이 카드는 현재 옵션 각성을 지원하지 않습니다")
	var entry: Dictionary = card_progress(state, category, identity)
	var rule: Dictionary = policy.grades[row.grade]
	var is_owned: bool = owned(card_state, category, identity)
	var material_rows: Array = []
	var spares: Dictionary = card_state.get("spare", {}).get(category, {})
	for material_id: String in catalog[category]:
		var record: Dictionary = catalog[category][material_id]
		var grade: String = str(record.get("grade", ""))
		var count: int = int(spares.get(material_id, 0))
		if not rule.material_experience.has(grade) or count <= 0 or not owned(card_state, category, material_id): continue
		material_rows.append({"id": material_id, "record": record.duplicate(true), "spare": count, "experience_per_card": int(rule.material_experience[grade])})
	var required: int = int(policy.experience_required)
	var attempt_cost: int = int(rule.attempt_cost)
	return {
		"ok": true, "category": category, "target_id": identity, "target_record": catalog[category][identity].duplicate(true),
		"revision": int(state.revision), "owned": is_owned, "awakened": bool(entry.awakened),
		"experience": int(entry.experience), "required_experience": required, "materials": material_rows,
		"material_experience": rule.material_experience.duplicate(true), "success_chance_pct": float(probabilities[category][row.grade]) / 100.0,
		"attempt_cost": attempt_cost, "gold": gold, "failure_refund_experience": int(rule.failure_refund_experience),
		"can_feed": is_owned and not bool(entry.awakened) and int(entry.experience) < required and not material_rows.is_empty(),
		"can_awaken": is_owned and not bool(entry.awakened) and int(entry.experience) == required and gold >= attempt_cost,
		"bonus_options": row.bonus_options.duplicate(), "applied_options": row.applied_options.duplicate(), "pending_options": row.pending_options.duplicate(),
		"policy_note": "TWILIGHT 설정: 재료 경험치·시도 비용·실패 환급. 성공 확률과 추가 능력치는 공식 공시 기준.",
		"attempts": int(entry.attempts), "failures": int(entry.failures), "pity_enabled": false,
		"collections": collection_views(state, card_state)
	}

func _can_prepare(state: Dictionary, card_state: Dictionary, gold: int, category: String, identity: String) -> Dictionary:
	if not problem.is_empty(): return fail("configuration", problem)
	var error: String = validate_state(state, card_state)
	if not error.is_empty(): return fail("invalid_state", error)
	if definition(category, identity).is_empty(): return fail("unavailable", "이 카드는 현재 옵션 각성을 지원하지 않습니다")
	if not owned(card_state, category, identity): return fail("not_owned", "먼저 대상 카드를 획득해야 합니다")
	if awakened(state, category, identity): return fail("already_awakened", "이미 각성한 카드입니다")
	if gold < 0: return fail("invalid_gold", "아데나 저장 값 오류")
	return {"ok": true}

func prepare_feed(state: Dictionary, card_state: Dictionary, gold: int, category: String, identity: String, materials: Dictionary) -> Dictionary:
	var guard: Dictionary = _can_prepare(state, card_state, gold, category, identity)
	if not bool(guard.ok): return guard
	var entry: Dictionary = card_progress(state, category, identity)
	var required: int = int(policy.experience_required)
	if int(entry.experience) >= required: return fail("full", "각성 경험치가 이미 가득 찼습니다")
	if materials.is_empty(): return fail("empty_materials", "중복 재료 카드를 선택하세요")
	var rule: Dictionary = policy.grades[definitions[category][identity].grade]
	var extras: Variant = card_state.get("spare", {}).get(category, {})
	if not extras is Dictionary: return fail("invalid_inventory", "중복 카드 저장 형식 오류")
	var experience: int = 0
	var consumed: int = 0
	for material_id: Variant in materials:
		var count: Variant = materials[material_id]
		if not material_id is String or not integer(count) or int(count) < 1 or int(count) > MAX_COUNT:
			return fail("invalid_quantity", "재료 수량은 양의 정수여야 합니다")
		var record: Dictionary = catalog[category].get(material_id, {})
		var grade: String = str(record.get("grade", ""))
		if record.is_empty() or not rule.material_experience.has(grade): return fail("invalid_material", "같은 종류의 허용 등급 카드만 주입할 수 있습니다")
		if not owned(card_state, category, material_id) or not integer(extras.get(material_id, 0)) or int(extras.get(material_id, 0)) < int(count):
			return fail("insufficient_materials", "선택한 중복 카드가 부족합니다")
		consumed += int(count)
		if consumed > MAX_COUNT: return fail("invalid_quantity", "선택한 재료 수량이 너무 많습니다")
		experience += int(rule.material_experience[grade]) * int(count)
	var next_state: Dictionary = state.duplicate(true)
	var next_cards: Dictionary = card_state.duplicate(true)
	for material_id: String in materials:
		var remaining: int = int(next_cards.spare[category][material_id]) - int(materials[material_id])
		if remaining == 0: next_cards.spare[category].erase(material_id)
		else: next_cards.spare[category][material_id] = remaining
	var gained: int = mini(required - int(entry.experience), experience)
	entry.experience = int(entry.experience) + gained
	next_state.cards[category][identity] = entry
	next_state.revision = int(next_state.revision) + 1
	return {"ok": true, "state": next_state, "card_state": next_cards, "gold": gold, "consumed_materials": consumed, "gained_experience": gained, "discarded_experience": experience - gained}

func prepare_awaken(state: Dictionary, card_state: Dictionary, gold: int, category: String, identity: String, roll: int) -> Dictionary:
	var guard: Dictionary = _can_prepare(state, card_state, gold, category, identity)
	if not bool(guard.ok): return guard
	var entry: Dictionary = card_progress(state, category, identity)
	if int(entry.experience) != int(policy.experience_required): return fail("experience_needed", "경험치 100%를 채운 뒤 각성할 수 있습니다")
	var row: Dictionary = definitions[category][identity]
	var rule: Dictionary = policy.grades[row.grade]
	if gold < int(rule.attempt_cost): return fail("insufficient_gold", "각성 시도에 필요한 아데나가 부족합니다")
	if roll < 0 or roll >= 10000: return fail("invalid_roll", "각성 확률 계산 오류")
	if int(entry.attempts) >= MAX_COUNT: return fail("attempt_limit", "각성 시도 기록 한도에 도달했습니다")
	var success: bool = roll < int(probabilities[category][row.grade])
	entry.attempts = int(entry.attempts) + 1
	entry.awakened = success
	entry.experience = 0 if success else int(rule.failure_refund_experience)
	if not success: entry.failures = int(entry.failures) + 1
	var next_state: Dictionary = state.duplicate(true)
	next_state.cards[category][identity] = entry
	next_state.revision = int(next_state.revision) + 1
	return {"ok": true, "state": next_state, "card_state": card_state.duplicate(true), "gold": gold - int(rule.attempt_cost), "success": success, "consumed_gold": int(rule.attempt_cost), "refunded_experience": int(entry.experience)}

func collection_views(state: Dictionary, card_state: Dictionary) -> Array:
	var out: Array = []
	for row: Dictionary in collections:
		var complete: bool = bool(row.available)
		var result: Dictionary = row.duplicate(true)
		for requirement: Dictionary in result.requirements:
			var category: String = str(requirement.category)
			var identity: String = str(requirement.id)
			var met: bool = owned(card_state, category, identity) and (not bool(requirement.awakened) or awakened(state, category, identity))
			requirement["met"] = met
			complete = complete and met
		result["completed"] = complete
		out.append(result)
	return out
