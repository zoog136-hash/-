extends SceneTree

const RULES = preload("res://scripts/consumable_rules.gd")
const SOURCE = preload("res://scripts/resources/current523_definition_rows.gd")
const QUERIES = preload("res://scripts/resources/current523_consumable_queries.gd")
const BAKE = preload("res://scripts/resources/current523_bake_cache.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		printerr("CONSUMABLE_DEFINITION_CACHE_FAIL: ", label)

func check_source_territories(path: String) -> void:
	OS.set_environment("TWILIGHT_PATCH523_CONTENT", path)
	SOURCE.reset()
	if SOURCE.verified_key().is_empty():
		check(false, "verified original archive")
		return
	var zip := ZIPReader.new()
	if zip.open(path) != OK:
		check(false, "territory test source")
		return
	var expected: Dictionary = SOURCE._read_consumable_territories(zip.read_file("content/Territories.json"))
	var raw_craft: Variant = JSON.parse_string(zip.read_file("content/ItemCraftInput.json").get_string_from_utf8())
	zip.close()
	if not raw_craft is Dictionary or not raw_craft.get("rows") is Array:
		check(false, "raw craft inputs")
		return
	var cook_ids: Dictionary = {}
	for input: Dictionary in raw_craft.rows: cook_ids[int(input.ItemClassID)] = true
	var expected_inputs := PackedInt32Array(cook_ids.keys())
	expected_inputs.sort()
	if expected_inputs.is_empty():
		check(false, "original craft input IDs")
		return
	var ids: Dictionary = {}
	for id: int in expected: ids[id] = true
	var key: String = QUERIES.consumable_territory_bake_key()
	# Persist a valid container with incomplete source rows to require the
	# original fallback. The direct item path must leave the bake alone.
	var incomplete: Dictionary = {int(expected.keys()[0]): expected.values()[0]} if not expected.is_empty() else {}
	check(BAKE.write(QUERIES.CONSUMABLE_TERRITORY_BAKE, key, incomplete), "incomplete bake fixture")
	var first: Array[Dictionary] = QUERIES.territories(ids)
	check(not expected.is_empty() and first == expected.values(), "fallback keeps source order and the original rows")
	check(BAKE.read(QUERIES.CONSUMABLE_TERRITORY_BAKE, key) == incomplete, "gameplay never publishes the bake")
	var craft_key: String = QUERIES.craft_input_bake_key()
	var broken := PackedInt32Array()
	broken.resize(expected_inputs.size())
	broken.fill(expected_inputs[0])
	check(BAKE.write(QUERIES.CRAFT_INPUT_IDS_BAKE, craft_key, broken), "full-size repeated craft IDs fixture")
	check(QUERIES.item_craft_input_declared(expected_inputs[-1]) and not QUERIES.item_craft_input_declared(expected_inputs[-1] + 1), "rejects malformed cache and reads the original craft inputs")
	check(BAKE.read(QUERIES.CRAFT_INPUT_IDS_BAKE, craft_key) == broken, "gameplay never publishes the craft membership bake")
	SOURCE.reset()
	QUERIES.prepare()
	check(BAKE.read(QUERIES.CONSUMABLE_TERRITORY_BAKE, key) == expected, "persisted original subset")
	check(BAKE.read(QUERIES.CRAFT_INPUT_IDS_BAKE, craft_key) == expected_inputs, "persisted all original craft input IDs")
	SOURCE.reset()
	QUERIES.prepare()
	var restored: Array[Dictionary] = QUERIES.territories(ids)
	check(restored == first, "fresh source session reads the same derived rows")
	if not restored.is_empty(): restored[0]["StartX"] = -999
	check(QUERIES.territories(ids) == first, "caller cannot mutate the cache")

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
	for value: String in OS.get_cmdline_user_args():
		if value.begins_with("--source-zip="):
			check_source_territories(value.trim_prefix("--source-zip="))
	print("CONSUMABLE_DEFINITION_CACHE_RESULT ", JSON.stringify({"failures": failures}))
	quit(0 if failures.is_empty() else 1)
