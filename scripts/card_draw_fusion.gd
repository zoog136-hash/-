extends RefCounted
class_name TwilightCardDrawFusion

# TWILIGHT's user-selected, locally configured rules. All values are on a
# 10,000-point scale so grades are never reweighted by the card population.
const CATEGORIES: Array[String] = ["변신", "마법인형", "성물"]
const GRADES: Array[String] = ["일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]
const DRAW_ORDER: Array[String] = ["고급", "희귀", "영웅", "전설"]
const DRAW_WEIGHTS: Dictionary = {"고급": 9359, "희귀": 550, "영웅": 90, "전설": 1}
const FUSION_NEXT: Dictionary = {
	"일반": "고급", "고급": "희귀", "희귀": "영웅",
	"영웅": "전설", "전설": "신화", "신화": "유일"
}
const FUSION_WEIGHTS: Dictionary = {
	"일반": 3500, "고급": 1700, "희귀": 1200,
	"영웅": 1100, "전설": 1100, "신화": 10000
}
const FUSION_MATERIALS: Dictionary = {
	"일반": 4, "고급": 4, "희귀": 4,
	"영웅": 4, "전설": 2, "신화": 4
}
const PITY_GRADES: Array[String] = ["희귀", "영웅"]
const PITY_LIMIT: int = 20
const PACK_SIZE: int = 11

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var pools: Dictionary = {} # category -> grade -> [{id, record}, ...]
var known_ids: Dictionary = {} # category -> id -> grade
var owned: Dictionary = {} # category -> id -> true (permanently unlocked)
var spare: Dictionary = {} # category -> id -> duplicate count (consumable)
var pity: Dictionary = {} # category -> source grade -> consecutive accumulated failures

func _init() -> void:
	rng.randomize()

static func card_id(record: Dictionary) -> String:
	var source_id: String = str(record.get("sourceId", "")).strip_edges()
	if not source_id.is_empty():
		return "source:" + source_id
	var name_value: String = str(record.get("name", "")).strip_edges()
	if name_value.is_empty():
		return ""
	# Older records lacking sourceId use a deterministic, namespaced fallback.
	return "fallback:" + str(record.get("grade", "")) + ":" + name_value + ":" + str(record.get("type", ""))

func configure(catalog: Dictionary) -> void:
	pools.clear()
	known_ids.clear()
	owned.clear()
	spare.clear()
	pity.clear()
	for category: String in CATEGORIES:
		var grade_pools: Dictionary = {}
		for grade: String in GRADES:
			grade_pools[grade] = []
		var identities: Dictionary = {}
		var raw_category: Variant = catalog.get(category, [])
		if raw_category is Array:
			for raw: Variant in raw_category as Array:
				if not (raw is Dictionary):
					continue
				var record: Dictionary = raw as Dictionary
				var grade: String = str(record.get("grade", ""))
				var identity: String = card_id(record)
				if not GRADES.has(grade) or identity.is_empty() or identities.has(identity):
					continue
				identities[identity] = grade
				var grade_cards: Array = grade_pools[grade] as Array
				grade_cards.append({"id": identity, "record": record})
		pools[category] = grade_pools
		known_ids[category] = identities
		owned[category] = {}
		spare[category] = {}
		pity[category] = {"희귀": 0, "영웅": 0}

# Debug-playtest seeding: the canonical catalog is the source of truth, not
# a hand-maintained list. Existing duplicates are never reduced or compounded.
# The world only calls this in the isolated, explicitly gated playtest save.
func grant_full_collection_for_playtest(minimum_spare: int = 10) -> Dictionary:
	var guaranteed_spare: int = clampi(minimum_spare, 0, 1000000)
	var category_counts: Dictionary = {}
	for category: String in CATEGORIES:
		var unlocked: Dictionary = owned[category] as Dictionary
		var duplicates: Dictionary = spare[category] as Dictionary
		var identities: Dictionary = known_ids[category] as Dictionary
		for identity: String in identities:
			unlocked[identity] = true
			if guaranteed_spare > 0:
				duplicates[identity] = maxi(guaranteed_spare, int(duplicates.get(identity, 0)))
		category_counts[category] = identities.size()
	return category_counts

func can_draw(category: String) -> bool:
	if not CATEGORIES.has(category):
		return false
	var grade_pools: Dictionary = pools.get(category, {}) as Dictionary
	for grade: String in DRAW_ORDER:
		var cards: Array = grade_pools.get(grade, []) as Array
		if cards.is_empty():
			return false # Never silently redistribute an unavailable rarity.
	return true

func _roll_draw_grade() -> String:
	var roll: int = rng.randi_range(0, 9999)
	var upper: int = 0
	for grade: String in DRAW_ORDER:
		upper += int(DRAW_WEIGHTS[grade])
		if roll < upper:
			return grade
	return "" # The weights must total 10,000; a bad table fails closed.

func _sample_card(category: String, grade: String) -> Dictionary:
	var grade_pools: Dictionary = pools.get(category, {}) as Dictionary
	var cards: Array = grade_pools.get(grade, []) as Array
	if cards.is_empty():
		return {}
	return cards[rng.randi_range(0, cards.size() - 1)] as Dictionary

func _receive(category: String, entry: Dictionary) -> Dictionary:
	var identity: String = str(entry.get("id", ""))
	var record: Dictionary = entry.get("record", {}) as Dictionary
	var unlocked: Dictionary = owned[category] as Dictionary
	var extras: Dictionary = spare[category] as Dictionary
	var is_new: bool = not unlocked.has(identity)
	if is_new:
		unlocked[identity] = true
	else:
		extras[identity] = int(extras.get(identity, 0)) + 1
	return {
		"id": identity, "name": str(record.get("name", "")),
		"grade": str(record.get("grade", "")), "new": is_new
	}

func draw_pack(category: String) -> Dictionary:
	return draw_cards(category, PACK_SIZE)

func draw_cards(category: String, count: int) -> Dictionary:
	# Valid counts are exactly the supported ticket sizes; validation precedes mutation.
	if count != 1 and count != PACK_SIZE:
		return {"ok": false, "error": "지원하지 않는 뽑기권 수량"}
	if not can_draw(category):
		return {"ok": false, "error": "추첨할 등급 카드가 부족합니다"}
	var results: Array = []
	for _index: int in range(count):
		var grade: String = _roll_draw_grade()
		var card: Dictionary = _sample_card(category, grade)
		if card.is_empty():
			return {"ok": false, "error": "등급 카드 추첨 실패"}
		results.append(_receive(category, card))
	return {"ok": true, "category": category, "results": results}

# Total displayed copies include the permanently unlocked card as well as
# spendable duplicates. Exported owned/spare schema is unchanged.
func total_count(category: String, identity: String) -> int:
	if not CATEGORIES.has(category):
		return 0
	if not (known_ids.get(category, {}) as Dictionary).has(identity):
		return 0
	var permanent: Dictionary = owned.get(category, {}) as Dictionary
	var duplicates: Dictionary = spare.get(category, {}) as Dictionary
	return (1 if permanent.has(identity) else 0) + maxi(0, int(duplicates.get(identity, 0)))

func category_totals(category: String) -> Dictionary:
	if not CATEGORIES.has(category):
		return {"unique": 0, "total": 0, "spare": 0}
	var permanent: Dictionary = owned.get(category, {}) as Dictionary
	var duplicates: Dictionary = spare.get(category, {}) as Dictionary
	var duplicate_count: int = 0
	for identity: String in permanent:
		duplicate_count += maxi(0, int(duplicates.get(identity, 0)))
	return {"unique": permanent.size(), "total": permanent.size() + duplicate_count, "spare": duplicate_count}

func spare_count(category: String, grade: String) -> int:
	if not CATEGORIES.has(category) or not GRADES.has(grade):
		return 0
	var identities: Dictionary = known_ids[category] as Dictionary
	var extras: Dictionary = spare[category] as Dictionary
	var count: int = 0
	for identity: String in identities:
		if str(identities[identity]) == grade:
			count += maxi(0, int(extras.get(identity, 0)))
	return count

func fuse(category: String, grade: String) -> Dictionary:
	if not CATEGORIES.has(category) or not FUSION_NEXT.has(grade):
		return {"ok": false, "error": "지원하지 않는 합성입니다"}
	var target_grade: String = str(FUSION_NEXT[grade])
	var grade_pools: Dictionary = pools[category] as Dictionary
	if (grade_pools.get(grade, []) as Array).is_empty() or (grade_pools.get(target_grade, []) as Array).is_empty():
		return {"ok": false, "error": "합성 재료 또는 결과 등급 카드가 없습니다"}
	var required: int = int(FUSION_MATERIALS[grade])
	var material_ids: Array[String] = []
	var extras: Dictionary = spare[category] as Dictionary
	for raw_card: Variant in grade_pools.get(grade, []) as Array:
		var identity: String = str((raw_card as Dictionary).get("id", ""))
		var available: int = maxi(0, int(extras.get(identity, 0)))
		for _count: int in range(mini(available, required - material_ids.size())):
			material_ids.append(identity)
		if material_ids.size() >= required:
			break
	if material_ids.size() < required:
		return {"ok": false, "error": "%s 중복 카드 %d장이 필요합니다" % [grade, required]}
	var success: bool = rng.randi_range(0, 9999) < int(FUSION_WEIGHTS[grade])
	var outcome_grade: String = target_grade if success else grade
	var selected: Dictionary = _sample_card(category, outcome_grade)
	if selected.is_empty():
		return {"ok": false, "error": "합성 결과를 추첨할 수 없습니다"}
	# All validation and randomness have completed before materials are spent.
	for identity: String in material_ids:
		var remaining: int = int(extras.get(identity, 0)) - 1
		if remaining <= 0:
			extras.erase(identity)
		else:
			extras[identity] = remaining
	var awarded: Dictionary = _receive(category, selected)
	var bonus: Dictionary = {}
	var counter: Dictionary = pity[category] as Dictionary
	if not success and PITY_GRADES.has(grade):
		var failures: int = int(counter.get(grade, 0)) + 1
		if failures >= PITY_LIMIT:
			# The target pool was validated above; compensation is additional
			# to the normal same-grade failure result.
			bonus = _receive(category, _sample_card(category, target_grade))
			counter[grade] = 0
		else:
			counter[grade] = failures
	return {
		"ok": true, "category": category, "from_grade": grade,
		"to_grade": outcome_grade, "success": success, "consumed": required,
		"result": awarded, "pity_reward": bonus,
		"pity_progress": int(counter.get(grade, 0))
	}

func export_state() -> Dictionary:
	return {
		"version": 1,
		"owned": owned.duplicate(true),
		"spare": spare.duplicate(true),
		"pity": pity.duplicate(true)
	}

func import_state(input: Variant) -> void:
	for category: String in CATEGORIES:
		owned[category] = {}
		spare[category] = {}
		pity[category] = {"희귀": 0, "영웅": 0}
	if not (input is Dictionary):
		return
	var state: Dictionary = input as Dictionary
	var raw_owned: Variant = state.get("owned", {})
	var raw_spare: Variant = state.get("spare", {})
	var raw_pity: Variant = state.get("pity", {})
	if not (raw_owned is Dictionary) or not (raw_spare is Dictionary) or not (raw_pity is Dictionary):
		return
	for category: String in CATEGORIES:
		var saved_owned: Variant = (raw_owned as Dictionary).get(category, {})
		var saved_spare: Variant = (raw_spare as Dictionary).get(category, {})
		var saved_pity: Variant = (raw_pity as Dictionary).get(category, {})
		var unlocked: Dictionary = owned[category] as Dictionary
		var extras: Dictionary = spare[category] as Dictionary
		var known: Dictionary = known_ids[category] as Dictionary
		if saved_owned is Dictionary:
			for identity: String in known:
				if (saved_owned as Dictionary).get(identity, false) == true:
					unlocked[identity] = true
		if saved_spare is Dictionary:
			for identity: String in unlocked:
				var count: int = clampi(int((saved_spare as Dictionary).get(identity, 0)), 0, 1000000)
				if count > 0:
					extras[identity] = count
		if saved_pity is Dictionary:
			var counter: Dictionary = pity[category] as Dictionary
			for grade: String in PITY_GRADES:
				counter[grade] = clampi(int((saved_pity as Dictionary).get(grade, 0)), 0, PITY_LIMIT - 1)
