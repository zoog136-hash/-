extends SceneTree
## 변신·마법인형·성물 목록의 Btn_Sort2 "등급순" follows the original grade
## sidebar (Change_WinTotal_Class: 유일, 신화, 전설, 영웅, 희귀, 고급, 일반):
## a 유일 card is first, not after 일반 (user list 2026-11-26 #11).
##   godot --headless --path <repo> --script res://tests/change_grade_sort_order_test.gd
const CHANGE = preload("res://scripts/ui/original_ui/source_main_change_window.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CHANGE_GRADE_SORT_FAIL: " + label)

func _initialize() -> void:
	var records: Array[Dictionary] = [
		{"name":"버그베어","grade":"일반"},{"name":"지배자","grade":"유일"},{"name":"흑기사","grade":"고급"},
		{"name":"도펠겡어","grade":"신화"},{"name":"이벤트 카드","grade":"이벤트"},{"name":"아툰","grade":"전설"},
		{"name":"경비병","grade":"영웅"},{"name":"다크 나이트","grade":"희귀"}]
	var grades: Array[String] = []
	for record: Dictionary in CHANGE.ordered(records, 1): grades.append(str(record.grade))
	check(str(grades) == str(["유일","신화","전설","영웅","희귀","고급","일반","이벤트"]), "등급순 is the original sidebar order: " + str(grades))
	var sidebar: Array[String] = []
	for grade: String in CHANGE.SIDEBAR:
		if grade != "전체": sidebar.append(grade)
	var ranked: Array = CHANGE.GRADE_RANK.keys()
	ranked.sort_custom(func(a: String, b: String) -> bool: return int(CHANGE.GRADE_RANK[a]) < int(CHANGE.GRADE_RANK[b]))
	check(str(ranked) == str(sidebar), "every sidebar grade is ranked in sidebar order")
	check(CHANGE.ordered(records, 0) == records, "전체 keeps the list's own order")
	var names: Array[String] = []
	for record: Dictionary in CHANGE.ordered(records, 2): names.append(str(record.name))
	var sorted_names: Array[String] = names.duplicate()
	sorted_names.sort()
	check(str(names) == str(sorted_names), "이름순 sorts by name")
	print("CHANGE_GRADE_SORT_RESULT " + JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
