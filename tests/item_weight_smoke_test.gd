extends SceneTree

const DB_PATH := "res://data/game_db_v17.json"
const RULES_PATH := "res://data/item_weight_rules.json"

var failures: Array[String] = []

func _initialize() -> void:
	_run()

func _fail(message: String) -> void:
	failures.append(message)
	print("ITEM WEIGHT FAIL: " + message)

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_fail("missing file: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		_fail("invalid JSON: " + path)
		return {}
	return parsed

func _run() -> void:
	var db_variant: Variant = _load_json(DB_PATH)
	var rules_variant: Variant = _load_json(RULES_PATH)
	if not (db_variant is Dictionary) or not (rules_variant is Dictionary):
		_finish()
		return

	var db: Dictionary = db_variant as Dictionary
	var rules: Dictionary = rules_variant as Dictionary
	var items: Array = db.get("아이템", []) as Array
	var type_defaults: Dictionary = rules.get("type_defaults", {}) as Dictionary
	var overrides: Dictionary = rules.get("overrides", {}) as Dictionary

	if items.is_empty():
		_fail("item database is empty")

	var weighted_count := 0
	for entry: Variant in items:
		if not (entry is Dictionary):
			_fail("non-dictionary item record")
			continue
		var item: Dictionary = entry as Dictionary
		var name := str(item.get("name", ""))
		var item_type := str(item.get("type", ""))
		if not item.has("weight"):
			_fail("missing weight: " + name)
			continue
		var weight_variant: Variant = item.get("weight")
		if not (weight_variant is int or weight_variant is float):
			_fail("non-numeric weight: " + name)
			continue
		var weight := int(weight_variant)
		if weight < 0:
			_fail("negative weight: " + name)

		var expected := -1
		if overrides.has(name):
			expected = int(overrides[name])
		elif type_defaults.has(item_type):
			expected = int(type_defaults[item_type])
		else:
			_fail("no rule for type: %s (%s)" % [item_type, name])
			continue
		if weight != expected:
			_fail("weight mismatch: %s got=%d expected=%d" % [name, weight, expected])
		weighted_count += 1

	if weighted_count != items.size():
		_fail("weighted item count mismatch: %d/%d" % [weighted_count, items.size()])

	for currency_name: String in ["아데나"]:
		for entry: Variant in items:
			if entry is Dictionary and str((entry as Dictionary).get("name", "")) == currency_name:
				if int((entry as Dictionary).get("weight", -1)) != 0:
					_fail(currency_name + " must have zero weight")
				break

	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("ITEM_WEIGHT_SMOKE_OK: all database items have deterministic weights")
		quit(0)
	else:
		print("ITEM_WEIGHT_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
