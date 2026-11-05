extends RefCounted
class_name TwilightEquipmentBlessing

# Base equipment blessing: per physical item; separate from blessed enchant scrolls.
# Current523 ItemBlessBonus and NC blessing-option disclosure agree. IsTest
# rows (unique armor/accessory) are excluded from the active source table.
# Success rates are TWILIGHT placeholders until current NC numeric disclosure can
# be verified. Never describe these numbers as official probabilities.
const SUCCESS_CHANCES: Dictionary = {
	"일반": 60.0, "고급": 45.0, "희귀": 25.0, "영웅": 12.0,
	"전설": 6.0, "신화": 2.0, "유일": 1.0
}
const WEAPON_BONUSES: Dictionary = {
	"일반": {"hp":50}, "고급": {"capacity":200}, "희귀": {"accuracy":1},
	"영웅": {"damage":1}, "전설": {"damage":1}, "신화":{"damage":3}, "유일":{"damage":6}
}
const ARMOR_BONUSES: Dictionary = {
	"일반": {"mr":1}, "고급": {"hp":30}, "희귀": {"capacity":100},
	"영웅": {"defense":1}, "전설": {"defense":1}, "신화":{"defense":3}
}
const ACCESSORY_BONUSES: Dictionary = {"일반":{"hp":5},"고급":{"hp":10},"희귀":{"hp":20},
	"영웅":{"potion_heal_pct":1},"전설":{"potion_heal_pct":2},"신화":{"potion_heal_pct":3}}
const SOURCE: String="https://probability.plaync.com/lineagem/view?probCategoryId=6656e1b796b3cf5ad823b7bb"

static func success_chance(grade: String) -> float:
	var settings: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/crafting/patch523_enhancement_policy.json"))
	var value: float=float(settings.get("blessing_success_pct",SUCCESS_CHANCES).get(grade,0.0)) if settings is Dictionary else float(SUCCESS_CHANCES.get(grade,0.0))
	return clampf(value,0.0,100.0)

static func bonus_for(grade: String, kind: String, record: Dictionary = {}) -> Dictionary:
	if record.get("patch523_blessing_bonus") is Dictionary:
		return record.patch523_blessing_bonus.duplicate(true)
	if kind == "weapon":
		return (WEAPON_BONUSES.get(grade, {}) as Dictionary).duplicate()
	if kind == "armor":
		return (ARMOR_BONUSES.get(grade, {}) as Dictionary).duplicate()
	if kind == "accessory": return (ACCESSORY_BONUSES.get(grade,{}) as Dictionary).duplicate()
	return {}

static func effect_text(grade: String, kind: String, record: Dictionary = {}) -> String:
	var bonus: Dictionary = bonus_for(grade, kind, record)
	if bonus.is_empty():
		return ""
	if bonus.has("damage"):
		return "추가 대미지 +%d" % int(bonus["damage"])
	if bonus.has("accuracy"):
		return "무기 명중 +%d" % int(bonus["accuracy"])
	if bonus.has("hp"):
		return "최대 HP +%d" % int(bonus["hp"])
	if bonus.has("capacity"):
		return "무게 보너스 +%d" % int(bonus["capacity"])
	if bonus.has("defense"):
		return "AC -%d" % int(bonus["defense"])
	if bonus.has("mr"):
		return "MR %+d" % int(bonus["mr"])
	if bonus.has("potion_heal_pct"): return "물약 회복률 +%.2f%%" % float(bonus.potion_heal_pct)
	return ""

static func is_blessed(physical: Dictionary, record: Dictionary) -> bool:
	if str(physical.get("bless_state", "")).to_lower() in ["blessed", "축복"]:
		return true
	if bool(physical.get("blessed", false)):
		return true
	if str(record.get("bless_state", "")).to_lower() in ["blessed", "축복"]:
		return true
	return bool(record.get("blessed", false)) or str(record.get("name", "")).begins_with("축복받은 ")

static func roll_succeeds(grade: String, roll_percent: float) -> bool:
	return success_chance(grade) > 0.0 and roll_percent < success_chance(grade)
