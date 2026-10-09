extends RefCounted
class_name TwilightEquipmentBlessing

# Base equipment blessing: per physical item; separate from blessed enchant scrolls.
# Original 2017 NC guide confirms common through legendary. Mythic and\n# unique are TWILIGHT extensions pending reliable contemporary option data.
# "유일" is a TWILIGHT extension, NOT a verified official option.
# Success rates are TWILIGHT placeholders until current NC numeric disclosure can
# be verified. Never describe these numbers as official probabilities.
const SUCCESS_CHANCES: Dictionary = {
	"일반": 60.0, "고급": 45.0, "희귀": 25.0, "영웅": 12.0,
	"전설": 6.0, "신화": 2.0, "유일": 1.0
}
const WEAPON_BONUSES: Dictionary = {
	"일반": {"hp":50}, "고급": {"capacity":200}, "희귀": {"accuracy":1},
	"영웅": {"damage":1}, "전설": {"damage":1}, "신화": {"damage":3},
	"유일": {"damage":5}
}
const ARMOR_BONUSES: Dictionary = {
	"일반": {"mr":1}, "고급": {"hp":30}, "희귀": {"capacity":100},
	"영웅": {"defense":1}, "전설": {"defense":1}, "신화": {"defense":3},
	"유일": {"defense":5}
}

static func success_chance(grade: String) -> float:
	return float(SUCCESS_CHANCES.get(grade, 0.0))

static func bonus_for(grade: String, kind: String) -> Dictionary:
	if kind == "weapon":
		return (WEAPON_BONUSES.get(grade, {}) as Dictionary).duplicate()
	if kind == "armor":
		return (ARMOR_BONUSES.get(grade, {}) as Dictionary).duplicate()
	return {}

static func effect_text(grade: String, kind: String) -> String:
	var bonus: Dictionary = bonus_for(grade, kind)
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
