extends RefCounted
# Equipment rates are per independent equipment roll, not guaranteed drops.
# Field monsters: 1 equipment roll, at most Hero. Bosses: 3 equipment rolls,
# at most Unique. One separate potion roll per kill is preserved.
# Each roll yields at most one equipment item; rolls may yield duplicate items.

const EQUIPMENT_GRADES = ["일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]
const NORMAL_EQUIPMENT_RATES = {"일반":0.001, "고급":0.001, "희귀":0.001, "영웅":0.00015}
const BOSS_EQUIPMENT_RATES = {"일반":0.001, "고급":0.001, "희귀":0.001, "영웅":0.01, "전설":0.002, "신화":0.00025, "유일":0.00001}
const MAX_BOSS_EQUIPMENT_ROLLS: int = 3
const NORMAL_POTION_RATE: float = 0.45
const BOSS_POTION_RATE: float = 0.90
const NAMED_BOSSES = ["흑장로", "이프리트", "드레이크", "거대 드레이크"]

static func is_boss_record(record: Dictionary) -> bool:
	if record.has("is_boss"):
		return bool(record["is_boss"])
	if record.has("boss"):
		return bool(record["boss"])
	var monster_name: String = str(record.get("name", ""))
	var description: String = str(record.get("desc", ""))
	return description.contains("보스") or monster_name.ends_with("의 지배자") or monster_name in NAMED_BOSSES

static func _is_potion(record: Dictionary) -> bool:
	return str(record.get("slot", "")) == "consumable" and int(record.get("heal", 0)) > 0

static func _is_equipment(record: Dictionary) -> bool:
	var slot: String = str(record.get("slot", ""))
	return not slot.is_empty() and slot != "currency" and slot != "consumable"

static func build_catalog(items: Array) -> Dictionary:
	var by_name: Dictionary = {}
	var by_grade: Dictionary = {}
	var potions: Array[String] = []
	for grade: String in EQUIPMENT_GRADES:
		by_grade[grade] = []
	for value: Variant in items:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		var item_name: String = str(record.get("name", "")).strip_edges()
		if item_name.is_empty():
			continue
		by_name[item_name] = record
		if _is_potion(record):
			potions.append(item_name)
		elif _is_equipment(record):
			var grade: String = str(record.get("grade", "일반"))
			if by_grade.has(grade):
				(by_grade[grade] as Array).append(item_name)
	return {"by_name":by_name, "equipment_by_grade":by_grade, "potions":potions}

static func _roll_equipment_grade(is_boss: bool, rng: RandomNumberGenerator) -> String:
	var rates: Dictionary = BOSS_EQUIPMENT_RATES if is_boss else NORMAL_EQUIPMENT_RATES
	var roll: float = rng.randf()
	var cumulative: float = 0.0
	for grade: String in EQUIPMENT_GRADES:
		cumulative += float(rates.get(grade, 0.0))
		if roll < cumulative:
			return grade
	return ""

static func _pick_potion(monster_drops: Array[String], is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator) -> String:
	var by_name: Dictionary = catalog.get("by_name", {})
	var configured: Array[String] = []
	for item_name: String in monster_drops:
		if not by_name.has(item_name):
			continue
		var record: Dictionary = by_name[item_name] as Dictionary
		if _is_potion(record) and str(record.get("grade", "")) != "유일":
			configured.append(item_name)
	if not configured.is_empty():
		return configured[rng.randi_range(0, configured.size() - 1)]
	var fallback: String = "강력 HP 물약" if is_boss else "HP 물약"
	if by_name.has(fallback) and _is_potion(by_name[fallback] as Dictionary):
		return fallback
	var potions: Array = catalog.get("potions", [])
	for item_value: Variant in potions:
		var name_value: String = str(item_value)
		if str((by_name[name_value] as Dictionary).get("grade", "")) != "유일":
			return name_value
	return ""

# No cross-grade or catalog-wide fallback: a monster may only yield registered gear.
# Failed grade rolls remain failures. Missing grades are reported once per monster
# and grade so high-volume deterministic tests do not spam the console.
static var unavailable_grade_reports: Dictionary = {}

static func _pick_equipment(grade: String, monster_drops: Array[String], catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> String:
	var by_name: Dictionary = catalog.get("by_name", {})
	var exact: Array[String] = []
	for item_name: String in monster_drops:
		if not by_name.has(item_name):
			continue
		var item: Dictionary = by_name[item_name] as Dictionary
		if _is_equipment(item) and str(item.get("grade", "일반")) == grade:
			exact.append(item_name)
	if exact.is_empty():
		var report_id: String = (monster_name if not monster_name.is_empty() else "(unknown)") + ":" + grade
		if not unavailable_grade_reports.has(report_id):
			unavailable_grade_reports[report_id] = true
			push_warning("TWILIGHT_DROP_UNMAPPED_GRADE: " + report_id + " — skipped; no arbitrary substitution")
		return ""
	return exact[rng.randi_range(0, exact.size() - 1)]

static func roll(monster_drops: Array[String], is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> Array[String]:
	var earned: Array[String] = []
	var potion_rate: float = BOSS_POTION_RATE if is_boss else NORMAL_POTION_RATE
	if rng.randf() < potion_rate:
		var potion: String = _pick_potion(monster_drops, is_boss, catalog, rng)
		if not potion.is_empty():
			earned.append(potion)
	var equipment_roll_count: int = MAX_BOSS_EQUIPMENT_ROLLS if is_boss else 1
	for _attempt: int in range(equipment_roll_count):
		var equipment_grade: String = _roll_equipment_grade(is_boss, rng)
		if equipment_grade.is_empty():
			continue
		var equipment: String = _pick_equipment(equipment_grade, monster_drops, catalog, rng, monster_name)
		if not equipment.is_empty():
			earned.append(equipment)
	return earned
