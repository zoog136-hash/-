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
const L1J_REGISTRY_PATH = "res://data/monsters/l1j_drop_overrides.json"

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
	var overrides: Dictionary = {}
	if FileAccess.file_exists(L1J_REGISTRY_PATH):
		var raw_overrides: Variant = JSON.parse_string(FileAccess.get_file_as_string(L1J_REGISTRY_PATH))
		if raw_overrides is Dictionary:
			var declared: Variant = (raw_overrides as Dictionary).get("monsters", {})
			if declared is Dictionary:
				overrides = declared as Dictionary
	# Supplemental TWILIGHT gameplay-balance assignments are intentionally separate
	# from the source-audited L1J drop overrides. No extra rarity rolls occur.
	var coverage_equipment: Dictionary = {}
	var coverage_potions: Dictionary = {}
	if FileAccess.file_exists("res://data/monsters/twilight_drop_coverage.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/twilight_drop_coverage.json"))
		if parsed is Dictionary and int((parsed as Dictionary).get("schema_version", 0)) == 1:
			var balance: Dictionary = parsed as Dictionary
			if balance.get("equipment", {}) is Dictionary:
				coverage_equipment = balance["equipment"] as Dictionary
			if balance.get("potions", {}) is Dictionary:
				coverage_potions = balance["potions"] as Dictionary
	return {"by_name":by_name, "equipment_by_grade":by_grade, "potions":potions, "l1j_monster_drops":overrides,
		"twilight_coverage_equipment":coverage_equipment, "twilight_coverage_potions":coverage_potions}

static func _roll_equipment_grade(is_boss: bool, rng: RandomNumberGenerator) -> String:
	var rates: Dictionary = BOSS_EQUIPMENT_RATES if is_boss else NORMAL_EQUIPMENT_RATES
	var roll: float = rng.randf()
	var cumulative: float = 0.0
	for grade: String in EQUIPMENT_GRADES:
		cumulative += float(rates.get(grade, 0.0))
		if roll < cumulative:
			return grade
	return ""

static func _pick_potion(monster_drops: Array[String], is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> String:
	var by_name: Dictionary = catalog.get("by_name", {})
	var configured: Array[String] = []
	for item_name: String in monster_drops:
		if not by_name.has(item_name):
			continue
		var record: Dictionary = by_name[item_name] as Dictionary
		if _is_potion(record) and str(record.get("grade", "")) != "유일":
			configured.append(item_name)
	# One existing potion roll (45% field / 90% boss). Extra catalog potions
	# share that roll as rare weighted alternatives; never an extra drop roll.
	var supplemental: Dictionary = catalog.get("twilight_coverage_potions", {})
	var potion_rows: Variant = supplemental.get(monster_name, [])
	if potion_rows is Array and not (potion_rows as Array).is_empty():
		var choices: Array[Dictionary] = []
		for configured_name: String in configured:
			choices.append({"item_name":configured_name, "weight":100000})
		if choices.is_empty():
			var default_name: String = "강력 HP 물약" if is_boss else "HP 물약"
			if by_name.has(default_name) and _is_potion(by_name[default_name] as Dictionary):
				choices.append({"item_name":default_name, "weight":100000})
		for raw_row: Variant in potion_rows:
			if not (raw_row is Dictionary):
				continue
			var row: Dictionary = raw_row as Dictionary
			var name_value: String = str(row.get("item_name", ""))
			if not by_name.has(name_value) or configured.has(name_value):
				continue
			var item: Dictionary = by_name[name_value] as Dictionary
			if not _is_potion(item):
				continue
			if str(item.get("grade", "")) == "유일" and not is_boss:
				continue
			var weight: int = clampi(int(row.get("weight", 0)), 0, 1000000)
			if weight > 0:
				choices.append({"item_name":name_value, "weight":weight})
		var total_weight: int = 0
		for choice: Dictionary in choices:
			total_weight += int(choice["weight"])
		if total_weight > 0:
			var draw: int = rng.randi_range(1, total_weight)
			for choice: Dictionary in choices:
				draw -= int(choice["weight"])
				if draw <= 0:
					return str(choice["item_name"])
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

# Strict candidate resolution. L1J IDs are mapped explicitly by the importer;
# never infer an equivalence from a translated or similar-sounding monster name.
static var unavailable_grade_reports: Dictionary = {}

static func _missing(monster_name: String, grade: String) -> Dictionary:
	var report_id: String = (monster_name if not monster_name.is_empty() else "(unknown)") + ":" + grade
	if not unavailable_grade_reports.has(report_id):
		unavailable_grade_reports[report_id] = true
		push_warning("TWILIGHT_DROP_UNMAPPED_GRADE: " + report_id + " — skipped; no arbitrary substitution")
	return {}

static func _pick_equipment_entry(grade: String, monster_drops: Array[String], catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> Dictionary:
	var by_name: Dictionary = catalog.get("by_name", {})
	var mapped: Dictionary = catalog.get("l1j_monster_drops", {})
	var candidates: Array[Dictionary] = []
	# A registered monster uses only its declared mapped items. Missing grades
	# do not fallback to legacy monsters' drops or the global catalog.
	if mapped.has(monster_name):
		var mapped_entries: Variant = mapped[monster_name]
		if mapped_entries is Array:
			for raw: Variant in mapped_entries:
				if not (raw is Dictionary):
					continue
				var row: Dictionary = raw as Dictionary
				var item_name: String = str(row.get("item_name", ""))
				if not by_name.has(item_name):
					continue
				var item: Dictionary = by_name[item_name] as Dictionary
				if not _is_equipment(item) or str(item.get("grade", "일반")) != grade:
					continue
				var weight: int = clampi(int(row.get("weight", 1)), 1, 1000000)
				var min_count: int = clampi(int(row.get("min", 1)), 1, 10000)
				var max_count: int = clampi(int(row.get("max", 1)), min_count, 10000)
				candidates.append({"item_name":item_name, "weight":weight, "min":min_count, "max":max_count})
	# Keep TWILIGHT's own explicitly registered per-monster items, even when
	# a partial L1J source mapping exists for this monster. Never substitute
	# items from a global grade list or an unrelated monster.
	for item_name: String in monster_drops:
		if not by_name.has(item_name):
			continue
		var item: Dictionary = by_name[item_name] as Dictionary
		if not _is_equipment(item) or str(item.get("grade", "일반")) != grade:
			continue
		var duplicate: bool = false
		for candidate: Dictionary in candidates:
			if str(candidate["item_name"]) == item_name:
				duplicate = true
				break
		if not duplicate:
			candidates.append({"item_name":item_name, "weight":1, "min":1, "max":1})
	# Add balance-only assignments after original L1J and pre-existing
	# per-monster entries. Never borrow an item from the global grade catalog.
	var supplemental: Dictionary = catalog.get("twilight_coverage_equipment", {})
	var balance_rows: Variant = supplemental.get(monster_name, [])
	if balance_rows is Array:
		for raw_row: Variant in balance_rows:
			if not (raw_row is Dictionary):
				continue
			var row: Dictionary = raw_row as Dictionary
			var item_name: String = str(row.get("item_name", ""))
			if not by_name.has(item_name):
				continue
			var item: Dictionary = by_name[item_name] as Dictionary
			if not _is_equipment(item) or str(item.get("grade", "일반")) != grade:
				continue
			var duplicate: bool = false
			for candidate: Dictionary in candidates:
				if str(candidate["item_name"]) == item_name:
					duplicate = true
					break
			if not duplicate:
				candidates.append({"item_name":item_name, "weight":clampi(int(row.get("weight", 100)), 1, 1000000), "min":1, "max":1})
	if candidates.is_empty():
		return _missing(monster_name, grade)
	var total_weight: int = 0
	for item: Dictionary in candidates:
		total_weight += int(item["weight"])
	var choice: int = rng.randi_range(1, total_weight)
	for item: Dictionary in candidates:
		choice -= int(item["weight"])
		if choice <= 0:
			var count: int = int(item["min"]) if int(item["min"]) == int(item["max"]) else rng.randi_range(int(item["min"]), int(item["max"]))
			return {"item_name":str(item["item_name"]), "quantity":count}
	return {}

# Compatibility wrapper for existing callers and tests.
static func _pick_equipment(grade: String, monster_drops: Array[String], catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> String:
	return str(_pick_equipment_entry(grade, monster_drops, catalog, rng, monster_name).get("item_name", ""))

static func roll_detailed(monster_drops: Array[String], is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> Array[Dictionary]:
	var earned: Array[Dictionary] = []
	var potion_rate: float = BOSS_POTION_RATE if is_boss else NORMAL_POTION_RATE
	if rng.randf() < potion_rate:
		var potion: String = _pick_potion(monster_drops, is_boss, catalog, rng, monster_name)
		if not potion.is_empty():
			earned.append({"item_name":potion, "quantity":1})
	var equipment_roll_count: int = MAX_BOSS_EQUIPMENT_ROLLS if is_boss else 1
	for _attempt: int in range(equipment_roll_count):
		var equipment_grade: String = _roll_equipment_grade(is_boss, rng)
		if equipment_grade.is_empty():
			continue
		var equipment: Dictionary = _pick_equipment_entry(equipment_grade, monster_drops, catalog, rng, monster_name)
		if not equipment.is_empty():
			earned.append(equipment)
	return earned

static func roll(monster_drops: Array[String], is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> Array[String]:
	var earned: Array[String] = []
	for entry: Dictionary in roll_detailed(monster_drops, is_boss, catalog, rng, monster_name):
		earned.append(str(entry["item_name"]))
	return earned
