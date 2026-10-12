extends SceneTree

const CRAFT = preload("res://scripts/crafting/expanded_crafting.gd")
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func plain_item() -> Dictionary:
	return {"name": "test_material", "level": 0, "element": "", "element_level": 0}

func _initialize() -> void:
	check(CRAFT._pristine(plain_item()), "plain +0 equipment remains a valid material")
	for blessing: Dictionary in [{"bless_state": "blessed"}, {"bless_state": "축복"}, {"blessed": true}, {"bless_state": "BLESSED"}]:
		var item: Dictionary = plain_item()
		item.merge(blessing, true)
		check(not CRAFT._pristine(item), "blessing must protect physical item: " + str(blessing))
	for changed: Dictionary in [{"level": 1}, {"element": "fire"}, {"element_level": 1}, {"record": {"custom": true}}, {"record": "invalid"}]:
		var item: Dictionary = plain_item()
		item.merge(changed, true)
		check(not CRAFT._pristine(item), "modified or malformed equipment stays protected: " + str(changed))
	# Explicit synthetic transaction fixture, not an assertion about source-game
	# costs or drop rates. Calls the production quote/execute implementation.
	var crafting = CRAFT.new()
	crafting.recipes = {
		"test_recipe": {
			"result": {"item": "test_output", "quantity": 1},
			"materials": [{"item": "test_material", "quantity": 1}],
			"adena": 5
		}
	}
	var records: Dictionary = {
		"test_material": {"slot": "weapon", "grade": "일반", "weight": 1},
		"test_output": {"slot": "weapon", "grade": "일반", "weight": 1}
	}
	var blessed: Dictionary = plain_item()
	blessed.merge({"bless_state": "blessed", "blessed": true}, true)
	var physical: Dictionary = {"1": blessed.duplicate(true)}
	var inventory: Dictionary = {"test_material": 1}
	var before_physical: Dictionary = physical.duplicate(true)
	var before_inventory: Dictionary = inventory.duplicate(true)
	var rejected: Dictionary = crafting.execute("test_recipe", 1, inventory, 100, records, physical, {}, 1, 100, 2)
	check(not bool(rejected.get("ok", false)), "only-blessed recipe must fail")
	check(physical == before_physical, "failed craft preserves blessed instance exactly")
	check(inventory == before_inventory, "failed craft preserves inventory exactly")
	physical = {"1": blessed.duplicate(true), "2": plain_item()}
	inventory = {"test_material": 2}
	var accepted: Dictionary = crafting.execute("test_recipe", 1, inventory, 100, records, physical, {}, 2, 100, 3)
	check(bool(accepted.get("ok", false)), "mixed material inventory can craft with plain item")
	check(physical.has("1") and physical.get("1", {}) == blessed, "lower sorted blessed ID must survive")
	check(not physical.has("2"), "plain ID must be the consumed material")
	check(physical.has("3") and str(physical.get("3", {}).get("name", "")) == "test_output", "output receives distinct physical ID")
	check(int(accepted.get("gold_after", -1)) == 95, "normal craft cost is unchanged")
	if failures.is_empty():
		print("MAIN_DEBUG_CRAFTING_BLESSING_OK")
	else:
		for failure: String in failures:
			print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
