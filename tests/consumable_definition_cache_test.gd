extends SceneTree

const RULES = preload("res://scripts/consumable_rules.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("CONSUMABLE_DEFINITION_CACHE_FAIL: ", label)

func _initialize() -> void:
	for record: Dictionary in RULES.records():
		check(RULES.definition(record.name) == record, "unchanged definition " + str(record.name))
	check(RULES.definition(" 드래곤의 루비 (각인) ") == RULES.definition("드래곤의 루비"), "name normalization")
	var food: Dictionary = RULES.definition("힘센 한우 스테이크")
	var expected: Dictionary = food.duplicate(true)
	food.buff.melee_damage = -999
	food.classes.clear()
	check(RULES.definition("힘센 한우 스테이크") == expected, "nested caller mutations stay isolated")
	for record: Dictionary in RULES.records():
		record.clear()
	check(RULES.definition("힘센 한우 스테이크") == expected, "public catalog mutations stay isolated")
	check(RULES.definition("존재하지 않는 소모품").is_empty(), "unknown item")
	print("CONSUMABLE_DEFINITION_CACHE_RESULT ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
