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
const CRAFTING_DROPS_PATH: String = "res://data/monsters/twilight_crafting_drops.json"
const MATERIAL_DROP_RATE: float = 0.28
const BOSS_MATERIAL_DROP_RATE: float = 0.65

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
	return {"by_name":by_name, "equipment_by_grade":by_grade, "potions":potions, "crafting_drops":crafting_sources}

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

static func _pick_equipment(grade: String, monster_drops: Array[String], catalog: Dictionary, rng: RandomNumberGenerator, monster_name: String = "") -> String:
	var by_name: Dictionary = catalog.get("by_name", {})
	var grade_pools: Dictionary = catalog.get("equipment_by_grade", {})
	var exact: Array[String] = []
	var preferred_types: Dictionary = {}
	for item_name: String in monster_drops:
		if not by_name.has(item_name):
			continue
		var record: Dictionary = by_name[item_name] as Dictionary
		if not _is_equipment(record):
			continue
		preferred_types[str(record.get("type", ""))] = true
		if str(record.get("grade", "")) == grade:
			exact.append(item_name)
	if not exact.is_empty():
		return exact[rng.randi_range(0, exact.size() - 1)]
	# Local crafting equipment candidates are used only if the monster's existing
	# explicit drop entries have no item in this grade. Never dilute original
	# grade-specific equipment candidates.
	var crafting_sources: Dictionary = catalog.get("crafting_drops",{})
	var source: Dictionary = crafting_sources.get(monster_name,{})
	var crafting_equipment: Array[String] = []
	for raw_name: Variant in source.get("equipment_ingredients",[]):
		var candidate: String = str(raw_name)
		if by_name.has(candidate) and _is_equipment(by_name[candidate] as Dictionary) and str((by_name[candidate] as Dictionary).get("grade","")) == grade:
			crafting_equipment.append(candidate)
	if not crafting_equipment.is_empty():
		return crafting_equipment[rng.randi_range(0,crafting_equipment.size() - 1)]
	var pool: Array = grade_pools.get(grade, [])
	if pool.is_empty():
		return ""
	var related: Array[String] = []
	if not preferred_types.is_empty():
		for value: Variant in pool:
			var item_name: String = str(value)
			var record: Dictionary = by_name[item_name] as Dictionary
			if preferred_types.has(str(record.get("type", ""))):
				related.append(item_name)
	if not related.is_empty():
		return related[rng.randi_range(0, related.size() - 1)]
	# Monsters with only potion entries still have a small equipment drop chance.
	return str(pool[rng.randi_range(0, pool.size() - 1)])

# One independent resource roll. This never consumes an equipment/potion slot.
# Named source rows intentionally never claim original LineageM drop accuracy.
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
	# After the original rolls, so their RNG draw order and grade rates stay intact.
	var material_name: String = _pick_material(monster_name, is_boss, catalog, rng)
	if not material_name.is_empty():
		earned.append(material_name)
	return earned
