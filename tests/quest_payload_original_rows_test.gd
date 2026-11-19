extends SceneTree
## The pinned quest payload is projected from unmodified original rows: the
## TestItem allow-list approximation (#625) must be off while it is built
## (2026-11-17: payload SHA mismatch, 0 quests, rebuilt on every start).
##   godot --headless --path <repo> --script res://tests/quest_payload_original_rows_test.gd
const ROWS = preload("res://scripts/resources/current523_definition_rows.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("QUEST_PAYLOAD_ROWS_FAIL: " + label)

func _initialize() -> void:
	var listed: int = ROWS.APPROX_TEST_ITEMS.keys()[0]
	check(ROWS.approximate_test_items, "the game rule is on by default")
	check(ROWS._view("ItemClass", {"ID": listed, "TestItem": true}).TestItem == false, "listed test items read as ordinary items in play")
	ROWS.approximate_test_items = false
	check(ROWS._view("ItemClass", {"ID": listed, "TestItem": true}).TestItem == true, "with the rule off the original row is unchanged")
	ROWS.approximate_test_items = true
	var quest: String = FileAccess.get_file_as_string("res://scripts/quests/source_quest523.gd")
	var off_at: int = quest.find("SOURCE.approximate_test_items = false")
	var build_at: int = quest.find("projection.build()")
	var restore_at: int = quest.find("SOURCE.approximate_test_items = approximate")
	check(off_at >= 0 and build_at > off_at and restore_at > build_at, "the quest projection is built with the rule off and restores it")
	check(FileAccess.get_file_as_string("res://scripts/quests/quest_service.gd").contains("problem = \"원본 퀘스트 불러오기 실패: \" + str(source.problem)"), "a quest pack failure names its cause")
	print("QUEST_PAYLOAD_ROWS_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
