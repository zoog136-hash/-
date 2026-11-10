extends RefCounted
# Equipment rates are per independent equipment roll, not guaranteed drops.
# Field monsters: 1 equipment roll. Bosses: 3 equipment rolls.
# Positive field weights and boss weights remain. Previously absent field grades
# reuse the existing game-wide boss grade rates instead of becoming a zero cap.
# Base508 source eligibility and exact drop provenance are separate from host weights.
# Each roll yields at most one equipment item; rolls may yield duplicate items.

const EQUIPMENT_GRADES = ["일반", "고급", "희귀", "영웅", "전설", "신화", "유일"]
const BOSS_EQUIPMENT_RATES = {"일반":0.001, "고급":0.001, "희귀":0.001, "영웅":0.01, "전설":0.002, "신화":0.00025, "유일":0.00001}
const NORMAL_EQUIPMENT_RATES = {
	"일반":0.001, "고급":0.001, "희귀":0.001, "영웅":0.00015,
	"전설": BOSS_EQUIPMENT_RATES["전설"],
	"신화": BOSS_EQUIPMENT_RATES["신화"],
	"유일": BOSS_EQUIPMENT_RATES["유일"],
}
const MAX_BOSS_EQUIPMENT_ROLLS: int = 3
const NORMAL_POTION_RATE: float = 0.45
const BOSS_POTION_RATE: float = 0.90
const NAMED_BOSSES = ["흑장로", "이프리트", "드레이크", "거대 드레이크"]
const L1J_REGISTRY_PATH = "res://data/monsters/l1j_drop_overrides.json"
const CRAFTING_DROPS_PATH: String = "res://data/monsters/twilight_crafting_drops.json"
const MATERIAL_DROP_RATE: float = 0.28
const BOSS_MATERIAL_DROP_RATE: float = 0.65
const BASE508_DROPS=preload("res://scripts/loot/base508_monster_drops.gd")
const SOURCE3_REVIEWED = preload("res://scripts/loot/source3_reviewed_drop.gd")
const CURRENCY_DROPS = preload("res://scripts/loot/currency_drops.gd")
const PATCH523_DROPS = preload("res://scripts/loot/patch523_monster_drops.gd")

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
	# Scrolls share equipment rarity rolls, but stay non-wearable stackable
	# consumables in inventory, warehouse and crafting transactions.
	if bool(record.get("crafting_scroll",false)):
		return bool(record.get("drop_as_equipment",false)) and str(record.get("slot","")) == "consumable"
	var slot: String = str(record.get("slot", ""))
	return not slot.is_empty() and slot not in ["currency", "consumable", "material"]

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
	var crafting_sources: Dictionary = {}
	if FileAccess.file_exists(CRAFTING_DROPS_PATH):
		var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(CRAFTING_DROPS_PATH))
		if source is Dictionary and int((source as Dictionary).get("schema_version",0)) == 1:
			var candidates: Variant = (source as Dictionary).get("monsters",{})
			if candidates is Dictionary:
				for raw_monster: Variant in (candidates as Dictionary).keys():
					var source_row: Variant = (candidates as Dictionary)[raw_monster]
					if not (source_row is Dictionary):
						continue
					var record: Dictionary = source_row as Dictionary
					var valid_materials: Array = []
					for raw_material: Variant in record.get("materials",[]):
						if not (raw_material is Dictionary):
							continue
						var item_name: String = str((raw_material as Dictionary).get("item",""))
						var weight: int = int((raw_material as Dictionary).get("weight",0))
						if by_name.has(item_name) and bool((by_name[item_name] as Dictionary).get("crafting_material",false)) and weight >= 1 and weight <= 100:
							valid_materials.append({"item":item_name,"weight":weight})
					var valid_equipment: Array[String] = []
					for raw_item: Variant in record.get("equipment_ingredients",[]):
						var item_name: String = str(raw_item)
						if by_name.has(item_name) and _is_equipment(by_name[item_name] as Dictionary):
							valid_equipment.append(item_name)
					if not valid_materials.is_empty() or not valid_equipment.is_empty():
						crafting_sources[str(raw_monster)] = {"materials":valid_materials,"equipment_ingredients":valid_equipment}
	return {"by_name":by_name, "equipment_by_grade":by_grade, "potions":potions, "l1j_monster_drops":overrides,
		"twilight_coverage_equipment":coverage_equipment, "twilight_coverage_potions":coverage_potions, "crafting_drops":crafting_sources,
		"source3_by_key":preload("res://scripts/loot/source3_item_links.gd").runtime_index(by_name)}

static func _roll_equipment_grade(is_boss: bool, rng: RandomNumberGenerator) -> String:
	var rates: Dictionary = BOSS_EQUIPMENT_RATES if is_boss else NORMAL_EQUIPMENT_RATES
	return equipment_grade_for_draw(rates, rng.randf())

static func equipment_grade_for_draw(rates: Dictionary, roll: float) -> String:
	# A pure draw adapter permits exact boundary regression tests, including
	# the formerly unreachable field legendary/mythic/unique intervals.
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
		if _is_potion(record):
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
		if _is_potion(by_name[name_value] as Dictionary):
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

static func _pick_equipment_entry(grade: String, monster_drops: Array[String], catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "", monster_identity: Dictionary = {}, source_weights: Dictionary = {}) -> Dictionary:
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
	var original_grade_registered: bool = not candidates.is_empty()
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
	# Reuse the SAME per-grade equipment roll for crafting scrolls and
	# registered crafting ingredients. Never borrow a random global-grade item.
	if not original_grade_registered:
		var crafting_sources: Dictionary = catalog.get("crafting_drops", {})
		var crafting_entry: Dictionary = crafting_sources.get(monster_name, {})
		for raw_candidate: Variant in crafting_entry.get("equipment_ingredients", []):
			var candidate_name: String = str(raw_candidate)
			if not by_name.has(candidate_name):
				continue
			var candidate_record: Dictionary = by_name[candidate_name] as Dictionary
			if not _is_equipment(candidate_record) or str(candidate_record.get("grade", "일반")) != grade:
				continue
			var exists: bool = false
			for registered: Dictionary in candidates:
				if str(registered.get("item_name", "")) == candidate_name:
					exists = true
					break
			if not exists:
				candidates.append({"item_name":candidate_name, "weight":1, "min":1, "max":1})
	if candidates.is_empty():
		var reviewed: Dictionary = SOURCE3_REVIEWED.candidate(grade, by_name, monster_identity)
		if not reviewed.is_empty(): candidates.append(reviewed)
		else: candidates.append_array(SOURCE3_REVIEWED.EXTENSIONS.candidates(grade, by_name, monster_identity))
	if candidates.is_empty():
		return _missing(monster_name, grade)
	# Reweight only an existing successful-grade pool; preserve chance, count and quantity.
	if not source_weights.is_empty():
		var weighted: Array[Dictionary] = []
		var total: float = 0
		var changed: bool = false
		for item: Dictionary in candidates:
			var factor: float = float(source_weights.get(str(item.item_name),1.0))
			if not is_finite(factor) or factor <= 0: factor = 1
			changed = changed or not is_equal_approx(factor,1)
			var weight: float = float(item.weight)*factor
			weighted.append({"row":item,"weight":weight}); total += weight
		if changed:
			var draw: float = rng.randf()*total # One existing pool choice; fractions remain exact.
			var selected: Dictionary = weighted.back().row
			for entry: Dictionary in weighted:
				draw -= float(entry.weight)
				if draw <= 0:
					selected = entry.row; break
			var count: int = int(selected.min) if int(selected.min) == int(selected.max) else rng.randi_range(int(selected.min),int(selected.max))
			return {"item_name":str(selected.item_name),"quantity":count}
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

static func _pick_material(monster_name: String, is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator) -> String:
	var sources: Dictionary = catalog.get("crafting_drops",{})
	var entry: Dictionary = sources.get(monster_name,{})
	var rows: Array = entry.get("materials",[])
	if rows.is_empty():
		return ""
	var rate: float = BOSS_MATERIAL_DROP_RATE if is_boss else MATERIAL_DROP_RATE
	if rng.randf() >= rate:
		return ""
	var total_weight: int = 0
	for raw: Variant in rows:
		total_weight += int((raw as Dictionary).get("weight",0))
	if total_weight <= 0:
		return ""
	var needle: int = rng.randi_range(1,total_weight)
	for raw: Variant in rows:
		var record: Dictionary = raw as Dictionary
		needle -= int(record.get("weight",0))
		if needle <= 0:
			return str(record.get("item",""))
	return ""


static func roll_detailed(monster_drops: Array[String], is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "", monster_identity: Dictionary = {}, map_id: Variant = "", source_weights: Dictionary = {}, quest_eligibility: Dictionary = {}) -> Array[Dictionary]:
	# Preserve the prior base508 seventh-argument API and current map/weights API.
	if map_id is Dictionary:
		if not quest_eligibility.is_empty():return []
		quest_eligibility=map_id;map_id=""
	elif not map_id is String:return []
	if PATCH523_DROPS.native(monster_identity):
		return roll_patch523(PATCH523_DROPS.candidates(monster_identity, catalog), is_boss, rng)
	var earned: Array[Dictionary] = []
	if BASE508_DROPS.native(monster_identity):
		var source: Dictionary=BASE508_DROPS.candidates(monster_identity,catalog,quest_eligibility)
		var potion_rate_native: float=BOSS_POTION_RATE if is_boss else NORMAL_POTION_RATE
		if rng.randf()<potion_rate_native:
			var selected: Dictionary=BASE508_DROPS.pick(source,"potion","",rng)
			if not selected.is_empty(): earned.append(selected)
		for attempt: int in range(MAX_BOSS_EQUIPMENT_ROLLS if is_boss else 1):
			var grade: String=_roll_equipment_grade(is_boss,rng)
			if grade.is_empty(): continue
			var selected: Dictionary=BASE508_DROPS.pick(source,"equipment",grade,rng)
			if not selected.is_empty(): earned.append(selected)
		if rng.randf()<(BOSS_MATERIAL_DROP_RATE if is_boss else MATERIAL_DROP_RATE):
			var selected: Dictionary=BASE508_DROPS.pick(source,"material","",rng)
			if not selected.is_empty(): earned.append(selected)
		return earned
	# Pre-November drop tables are not used in the game (user decision
	# 2026-11-10): a monster without original 523/508 drop rows drops nothing.
	if not bool(catalog.get("legacy_drops_allowed", false)):
		return earned
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
		var equipment: Dictionary = _pick_equipment_entry(equipment_grade, monster_drops, catalog, rng, monster_name, monster_identity,source_weights)
		if not equipment.is_empty():
			earned.append(equipment)
	# One independent resource roll, after gear/potions; all loot remains on ground.
	var material_name: String = _pick_material(monster_name, is_boss, catalog, rng)
	if not material_name.is_empty():
		earned.append({"item_name":material_name, "quantity":1})
	# Reuse the existing material chance, with no change to old gear/potion rolls.
	var currency_rate: float = BOSS_MATERIAL_DROP_RATE if is_boss else MATERIAL_DROP_RATE
	earned.append_array(CURRENCY_DROPS.roll(monster_drops, monster_name, map_id, catalog, rng, currency_rate))
	return earned

static func roll_patch523(groups: Dictionary, is_boss: bool, rng: RandomNumberGenerator) -> Array[Dictionary]:
	# Same host chances and number/order of potion/gear/material rolls.
	# No name fallback, extra chance for duplicate source rows or inferred currency.
	var earned: Array[Dictionary] = []
	var potion_rate: float = BOSS_POTION_RATE if is_boss else NORMAL_POTION_RATE
	if rng.randf() < potion_rate:
		var potion: Dictionary = PATCH523_DROPS.pick(groups, "potion", "", rng)
		if not potion.is_empty(): earned.append(potion)
	for attempt: int in range(MAX_BOSS_EQUIPMENT_ROLLS if is_boss else 1):
		var grade: String = _roll_equipment_grade(is_boss, rng)
		if grade.is_empty(): continue
		var equipment: Dictionary = PATCH523_DROPS.pick(groups, "equipment", grade, rng)
		if not equipment.is_empty(): earned.append(equipment)
	if rng.randf() < (BOSS_MATERIAL_DROP_RATE if is_boss else MATERIAL_DROP_RATE):
		var material: Dictionary = PATCH523_DROPS.pick(groups, "material", "", rng)
		if not material.is_empty(): earned.append(material)
	# Same additional currency chance and plain configured-row quantity=1 as
	# currency_drops.gd. Membership is explicit; no global currency fallback.
	if rng.randf() < (BOSS_MATERIAL_DROP_RATE if is_boss else MATERIAL_DROP_RATE):
		var currency: Dictionary = PATCH523_DROPS.pick(groups, "currency", "", rng)
		if not currency.is_empty(): earned.append(currency)
	return earned

static func roll(monster_drops: Array[String], is_boss: bool, catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> Array[String]:
	var earned: Array[String] = []
	for entry: Dictionary in roll_detailed(monster_drops, is_boss, catalog, rng, monster_name):
		earned.append(str(entry["item_name"]))
	return earned
