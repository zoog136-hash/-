extends RefCounted
class_name TwilightEquipmentBlessing
const NATIVE_FIELDS = preload("res://scripts/loot/current523_native_fields.gd")

# Base equipment blessing: per physical item; separate from blessed enchant scrolls.
# Current523 ItemBlessBonus and NC blessing-option disclosure agree. IsTest
# rows (unique armor/accessory) are excluded from the active source table.
# Success rates come from the installed original 523 BlessSuccessRate table
# (Rate per 1,000,000 by target ItemCategoryID and GradeID). SUCCESS_CHANCES are
# TWILIGHT placeholders used only while no original is installed; never
# describe them as official probabilities.
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const RATE_DENOMINATOR: float = 1000000.0
const SOURCE_BASIS: String = "원본 523 축복 성공률"
const PLACEHOLDER_BASIS: String = "TWILIGHT 임시값 · 원본 미설치"
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

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)==floorf(float(value))

## The original GradeID of a target: its own source_grade_id, otherwise the one
## Grade row whose Korean label is its grade; 0 when neither resolves.
static func source_grade_id(grade: String, record: Dictionary = {}) -> int:
	if record.get("source_m_native_item",false) and _integer(record.get("source_grade_id")) and int(record.source_grade_id)>0: return int(record.source_grade_id)
	var found: Array = []
	for row: Dictionary in DEFINITIONS.rows("Grade"):
		if not _integer(row.get("ID")) or not _integer(row.get("DescID")): continue
		if str(DEFINITIONS.row("DescData_Korean",int(row.DescID)).get("Description","")).strip_edges()==grade: found.append(int(row.ID))
	return int(found[0]) if found.size()==1 else 0

## The original BlessSuccessRate row for a target: the row for its own
## ItemCategoryID when the original has one, otherwise the ItemCategoryID 0
## row of its grade. {} while no original is installed; ok=false when the
## original has no rate for this target (it cannot be blessed).
static func source_rate(grade: String, record: Dictionary = {}) -> Dictionary:
	if DEFINITIONS.not_installed() or DEFINITIONS.identity().is_empty(): return {}
	var grade_id: int = source_grade_id(grade, record)
	var full: Dictionary = NATIVE_FIELDS.full(record)
	var category: int = int(full.get("source_category_id",0)) if record.get("source_m_native_item",false) and _integer(full.get("source_category_id")) else 0
	var specific: Array = []; var general: Array = []
	for row: Dictionary in DEFINITIONS.rows("BlessSuccessRate"):
		if not _integer(row.get("GradeID")) or int(row.GradeID)!=grade_id or not _integer(row.get("ItemCategoryID")): continue
		if category>0 and int(row.ItemCategoryID)==category: specific.append(row)
		elif int(row.ItemCategoryID)==0: general.append(row)
	var chosen: Array = specific if not specific.is_empty() else general
	if grade_id<=0 or chosen.size()!=1 or not _integer(chosen[0].get("Rate")) or int(chosen[0].Rate)<0 or int(chosen[0].Rate)>int(RATE_DENOMINATOR):
		return {"ok":false,"grade_id":grade_id,"category_id":category}
	return {"ok":true,"row":chosen[0],"grade_id":grade_id,"category_id":int(chosen[0].ItemCategoryID),"rate":int(chosen[0].Rate),"percent":float(chosen[0].Rate)*100.0/RATE_DENOMINATOR}

## Success percent for blessing a target. A scroll whose original
## GuaranteeBlessProb is set always succeeds.
static func success_chance(grade: String, record: Dictionary = {}, guaranteed: bool = false) -> float:
	if guaranteed: return 100.0
	var source: Dictionary = source_rate(grade, record)
	if not source.is_empty(): return clampf(float(source.get("percent",0.0)),0.0,100.0) if source.ok else 0.0
	var settings: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/crafting/patch523_enhancement_policy.json"))
	var value: float=float(settings.get("blessing_success_pct",SUCCESS_CHANCES).get(grade,0.0)) if settings is Dictionary else float(SUCCESS_CHANCES.get(grade,0.0))
	return clampf(value,0.0,100.0)

## Where the shown success percent comes from.
static func success_basis(grade: String, record: Dictionary = {}, guaranteed: bool = false) -> String:
	if guaranteed: return "원본 축복 확정 주문서"
	var source: Dictionary = source_rate(grade, record)
	if source.is_empty(): return PLACEHOLDER_BASIS
	return SOURCE_BASIS if source.ok else "원본 축복 성공률 없음"

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

static func roll_succeeds(grade: String, roll_percent: float, record: Dictionary = {}, guaranteed: bool = false) -> bool:
	var chance: float = success_chance(grade, record, guaranteed)
	return chance > 0.0 and roll_percent < chance
