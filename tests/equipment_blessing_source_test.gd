extends SceneTree
## Blessing success follows the original current523 BlessSuccessRate rows when
## the original definitions are installed, and is labelled a TWILIGHT
## placeholder otherwise. Absence never counts as a source validation.

const BLESSING = preload("res://scripts/equipment_blessing.gd")
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _initialize() -> void:
	var scope: String = "CURRENT523_NOT_INSTALLED" if DEFINITIONS.not_installed() else "CURRENT523_INSTALLED"
	if scope == "CURRENT523_INSTALLED":
		var rows: Array[Dictionary] = DEFINITIONS.rows("BlessSuccessRate")
		check(not rows.is_empty(), "original BlessSuccessRate rows load")
		var general: Dictionary = {}
		var holy: Dictionary = {}
		for row: Dictionary in rows:
			if int(row.ItemCategoryID) == 0: general[int(row.GradeID)] = float(row.Rate) / 10000.0
			elif int(row.ItemCategoryID) == 10622: holy[int(row.GradeID)] = float(row.Rate) / 10000.0
		for grade_id: int in [1, 2, 3, 4, 5, 32, 52]:
			var grade: String = str(preload("res://scripts/catalog_grade_policy.gd").QUALITY_GRADES[grade_id])
			check(is_equal_approx(BLESSING.success_chance(grade), float(general.get(grade_id, -1.0))), "general rate for " + grade)
			check(BLESSING.success_basis(grade).begins_with("원본523"), "original basis for " + grade)
		# A HolyGrail item uses its own category rows.
		var holy_class: int = 0
		for row: Dictionary in DEFINITIONS.rows("ItemClass"):
			if int(row.get("ItemCategoryID", 0)) == 10622 and int(row.get("GradeID", 0)) == 3:
				holy_class = int(row.ID)
				break
		if holy_class > 0:
			check(is_equal_approx(BLESSING.success_chance("희귀", {"source_item_class_id": holy_class}), float(holy[3])), "HolyGrail category rate")
		check(BLESSING.roll_succeeds("일반", float(general[1]) - 0.01) and not BLESSING.roll_succeeds("일반", float(general[1])), "roll uses the original boundary")
	else:
		check(BLESSING.success_basis("일반") == "TWILIGHT 임시값", "absent original is labelled placeholder")
		check(is_equal_approx(BLESSING.success_chance("일반"), 60.0), "absent original keeps the existing balance")
	print("EQUIPMENT_BLESSING_SOURCE_RESULT ", JSON.stringify({"scope": scope, "failures": failures}))
	if failures.is_empty(): print("EQUIPMENT_BLESSING_SOURCE_OK")
	else:
		for failure: String in failures: print("EQUIPMENT_BLESSING_SOURCE_FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
