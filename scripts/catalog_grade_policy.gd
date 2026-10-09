extends RefCounted
class_name TwilightCatalogGradePolicy

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
		if original not in ["일반", "고급", "희귀"]:
			continue
		var inferred: String = inferred_grade(record)
		if inferred.is_empty():
			continue
		record["grade_original"] = original
		record["grade"] = inferred
		record["grade_evidence"] = "inven_original_artwork_filename"
		corrected += 1
	return corrected
