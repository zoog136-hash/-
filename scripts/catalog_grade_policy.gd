extends RefCounted
class_name TwilightCatalogGradePolicy

const QUALITY_GRADES: Dictionary = {
	1:"일반", 2:"고급", 3:"희귀", 4:"영웅", 5:"전설", 32:"신화", 52:"유일"
}
const VERIFIED_EVIDENCE: String = "inven_item_quality"

# The original item extraction mapped unknown rarity to "일반".
# Restore only ranks explicitly encoded in the ORIGINAL equipment artwork
# filename; icon cues are a conservative inference, not a verified item-page
# rarity. Leave materials and other ambiguous items unchanged.
const EQUIPMENT_SLOTS: Array[String] = [
	"weapon", "offhand", "helmet", "tshirt", "body", "pants", "cloak",
	"shoulder", "gaiters", "gloves", "boots", "necklace", "earring",
	"ring", "belt", "bracelet", "badge", "seal", "crystal", "catalyst", "rune"
]

static func inferred_grade(record: Dictionary) -> String:
	# Explicit source quality always outranks an artwork filename. Quality 42
	# is not one of Inven's seven rarity labels: do not turn it into a hero
	# because a cash/event item's icon happens to contain that word.
	if record.has("sourceQuality"):
		return str(QUALITY_GRADES.get(int(record.sourceQuality), ""))
	if not EQUIPMENT_SLOTS.has(str(record.get("slot", ""))):
		return ""
	var image_filename: String = str(record.get("sourceImageUrl", "")).get_file().get_basename().to_lower()
	var tokens: PackedStringArray = image_filename.split("_")
	if tokens.has("legend"):
		return "전설"
	if tokens.has("hero"):
		return "영웅"
	return ""

static func apply(records: Array) -> int:
	var corrected: int = 0
	for value: Variant in records:
		if not (value is Dictionary):
			continue
		var record: Dictionary = value as Dictionary
		var original: String = str(record.get("grade", ""))
		if not record.has("sourceQuality") and original not in ["일반", "고급", "희귀"]:
			continue
		var inferred: String = inferred_grade(record)
		if inferred.is_empty():
			continue
		if original != inferred and not record.has("grade_original"):
			record["grade_original"] = original
		record["grade"] = inferred
		record["grade_evidence"] = VERIFIED_EVIDENCE if record.has("sourceQuality") else "inven_original_artwork_filename"
		if original != inferred: corrected += 1
	return corrected

static func _source_indexes(catalog_items: Array, gameplay_items: Array) -> Dictionary:
	var by_id: Dictionary = {}
	for value: Variant in catalog_items:
		if value is Dictionary and not str(value.get("sourceId", "")).is_empty():
			by_id[str(value.sourceId)] = value
	var legacy: Dictionary = {}
	for value: Variant in gameplay_items:
		if value is Dictionary and value.get("grade_evidence", "") == VERIFIED_EVIDENCE:
			legacy[str(value.get("name", ""))] = value
	return {"by_id":by_id, "legacy":legacy}

static func _verified_source(saved: Dictionary, indexes: Dictionary) -> Dictionary:
	var source_id: String = str(saved.get("sourceId", ""))
	var source: Dictionary = indexes.by_id.get(source_id, {}) if not source_id.is_empty() else indexes.legacy.get(str(saved.get("name", "")), {})
	if source.is_empty() or str(source.get("name", "")) != str(saved.get("name", "")): return {}
	if str(source.get("slot", "")) != str(saved.get("slot", "")): return {}
	if source.get("grade_evidence", "") != VERIFIED_EVIDENCE: return {}
	if not QUALITY_GRADES.has(int(source.get("sourceQuality", 0))): return {}
	return source

static func _copy_grade(saved: Dictionary, source: Dictionary) -> int:
	var grade: String = str(QUALITY_GRADES[int(source.sourceQuality)])
	var changed: bool = str(saved.get("grade", "")) != grade
	if changed:
		if not saved.has("grade_original"): saved["grade_original"] = str(saved.get("grade", ""))
		saved["grade"] = grade
	saved["sourceQuality"] = int(source.sourceQuality)
	saved["grade_evidence"] = VERIFIED_EVIDENCE
	return 1 if changed else 0

static func synchronize_saved_grades(catalog_items: Array, gameplay_items: Array, physical: Dictionary, equipped: Dictionary, stored: Dictionary) -> int:
	# Run once after loading a save, not per frame. The old physical snapshot
	# takes precedence in inventory UI, so fixing only the encyclopedia leaves
	# already-owned items incorrectly colored. Change grade metadata only.
	var indexes: Dictionary = _source_indexes(catalog_items, gameplay_items)
	var records: Array = equipped.values()
	for source: Dictionary in [physical, stored]:
		for value: Variant in source.values():
			if value is Dictionary and value.get("record", {}) is Dictionary:
				records.append(value.get("record", {}))
	var corrected: int = 0
	for value: Variant in records:
		if not (value is Dictionary) or value.is_empty(): continue
		var saved: Dictionary = value
		var source: Dictionary = _verified_source(saved, indexes)
		if not source.is_empty(): corrected += _copy_grade(saved, source)
	return corrected

static func synchronize_ground_grades(catalog_items: Array, gameplay_items: Array, ground: Array) -> int:
	# Called on the manager's validated COPY, before any floor view is created.
	# Player-dropped equipment stores both display and physical snapshots; the
	# latter is restored verbatim on pickup and must receive the same repair.
	var indexes: Dictionary = _source_indexes(catalog_items, gameplay_items)
	var corrected: int = 0
	for value: Variant in ground:
		if not (value is Dictionary): continue
		var drop: Dictionary = value
		var item_name: String = str(drop.get("item_name", ""))
		var visible: Variant = drop.get("item_record", {})
		if visible is Dictionary and str(visible.get("name", "")) == item_name:
			var source: Dictionary = _verified_source(visible, indexes)
			if not source.is_empty():
				corrected += _copy_grade(visible, source)
				drop["grade"] = visible.grade
		var payload: Variant = drop.get("physical_item", {})
		if not (payload is Dictionary): continue
		var physical: Variant = payload.get("data", {})
		if not (physical is Dictionary) or str(physical.get("name", "")) != item_name: continue
		var saved: Variant = physical.get("record", {})
		if not (saved is Dictionary) or str(saved.get("name", "")) != item_name: continue
		var source: Dictionary = _verified_source(saved, indexes)
		if not source.is_empty(): corrected += _copy_grade(saved, source)
	return corrected
