extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("ITEM DB SLOT FAIL: " + message)

func _expected_slot(item_type: String, current_slot: String) -> String:
	var map: Dictionary = {
		"방패":"offhand", "가더":"offhand", "방패/가더":"offhand",
		"투구":"helmet", "티셔츠":"tshirt", "갑옷":"body", "하의":"pants", "망토":"cloak",
		"견갑":"shoulder", "각반":"gaiters", "장갑":"gloves", "신발":"boots",
		"벨트":"belt", "귀걸이":"earring", "반지":"ring", "인장":"seal", "팔찌":"bracelet",
		"목걸이":"necklace", "휘장":"badge", "수정":"crystal", "카탈리스트":"catalyst", "룬":"rune"
	}
	if current_slot == "weapon":
		return "weapon"
	return str(map.get(item_type, current_slot))

func _validate_file(path: String, label: String) -> void:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (value is Dictionary):
		_fail(label + " JSON parse failed")
		return
	var items_value: Variant = (value as Dictionary).get("아이템", [])
	if not (items_value is Array):
		_fail(label + " item array missing")
		return
	for entry: Variant in items_value as Array:
		if not (entry is Dictionary):
			continue
		var record: Dictionary = entry as Dictionary
		var item_type: String = str(record.get("type", ""))
		var slot: String = str(record.get("slot", ""))
		var expected: String = _expected_slot(item_type, slot)
		if slot != expected:
			_fail("%s %s: slot %s expected %s" % [label, str(record.get("name","")), slot, expected])
			if failures.size() >= 20:
				return
		if slot in ["armor", "accessory", "shield"]:
			_fail("%s %s still uses broad legacy slot %s" % [label, str(record.get("name","")), slot])
			if failures.size() >= 20:
				return

func _run() -> void:
	_validate_file("res://data/game_db_v17.json", "game_db")
	_validate_file("res://data/catalog_v19.json", "catalog")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("ITEM_DB_SLOT_SMOKE_OK: item databases use granular equipment slots")
		quit(0)
	else:
		print("ITEM_DB_SLOT_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
