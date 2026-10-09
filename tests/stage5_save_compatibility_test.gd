extends SceneTree

# Stage 5 legacy-save + cross-system persistence validation.
# Runs only in tools/test_project.py's isolated XDG_DATA_HOME; never touches player saves.
const SAVE_PATH: String = "user://twilight_v20_save.json"
var failures: Array[String] = []
var assertions: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures.append(description)
		print("STAGE5_SAVE_FAIL: " + description)

func _write_save(data: String) -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(data)
	file.close()
	return true

func _sword_ids(world: Node) -> Array[String]:
	var names: Array[String] = []
	var instances: Dictionary = world.get("item_instances") as Dictionary
	for raw: Variant in instances.keys():
		var item: Variant = instances[raw]
		if item is Dictionary and str((item as Dictionary).get("name", "")) == "낡은 장검":
			names.append(str(raw))
	names.sort()
	return names

func _run() -> void:
	var packed: PackedScene = load("res://Main.tscn") as PackedScene
	if packed == null:
		_check(false, "Main.tscn can load")
		_finish()
		return
	var world: Node = packed.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set("save_timer", -10000.0)
	world.call("_save_game", true)
	var loaded: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(loaded is Dictionary, "Current-format save is JSON")
	if not (loaded is Dictionary):
		world.queue_free()
		await process_frame
		_finish()
		return
	var legacy: Dictionary = (loaded as Dictionary).duplicate(true)

	# Emulate a V20-era name-keyed save, including a removed cleansing potion.
	legacy["inventory"] = {
		"낡은 장검": 2,
		"무기 마법 주문서 (각인)": 4,
		"HP 물약": 11,
		"해독제": 3,
		"상태이상 해제 물약": 1
	}
	legacy["equipped_items"] = {}
	legacy["enhancement_levels"] = {"낡은 장검": 4}
	legacy["consumable_state"] = {
		"elemental_enchants": {"낡은 장검": {"element": "fire", "level": 2}},
		"elixirs_used": 2,
		"half_elixirs_used": 1,
		"permanent_damage_bonuses": {"melee_damage": 1, "ranged_damage": 0, "magic_damage": 0}
	}
	legacy["gold"] = 7777
	legacy["hp_recovery_elapsed"] = 7.0
	legacy["mp_recovery_elapsed"] = 11.0
	legacy.erase("item_instances")
	legacy.erase("next_item_instance_id")
	legacy.erase("experience")
	legacy["exp"] = 77
	_check(_write_save(JSON.stringify(legacy)), "Can write isolated legacy save")
	world.call("_load_game", true)
	var ids: Array[String] = _sword_ids(world)
	var instances: Dictionary = world.get("item_instances") as Dictionary
	var inventory: Dictionary = world.get("inventory") as Dictionary
	var service: Node = world.get("consumable_service") as Node
	_check(ids.size() == 2, "Legacy inventory gains exactly two physical sword IDs")
	_check(int(world.get("gold")) == 7777, "Legacy gold survives")
	_check(int(world.get("experience")) == 77, "Legacy exp alias survives")
	_check(not inventory.has("해독제") and not inventory.has("상태이상 해제 물약"), "Removed cleansers do not resurrect")
	_check(int(inventory.get("HP 물약", 0)) == 11, "Unrelated consumable counts survive")
	_check(is_equal_approx(float(world.get("hp_recovery_elapsed")), 7.0), "HP timer survives")
	_check(is_equal_approx(float(world.get("mp_recovery_elapsed")), 11.0), "MP timer survives")
	if ids.size() == 2:
		var elemental_count: int = 0
		for id: String in ids:
			var item: Dictionary = instances[id] as Dictionary
			_check(int(item.get("level", -1)) == 4, "Name-based legacy enchant migrated to a physical copy " + id)
			if int(item.get("element_level", 0)) == 2 and str(item.get("element", "")) == "fire":
				elemental_count += 1
		_check(elemental_count == 1, "Legacy elemental enchant migrates onto exactly one copy")
	if service != null:
		var service_data: Dictionary = service.call("export_state") as Dictionary
		_check(int(service_data.get("elixirs_used", 0)) == 2, "Elixir usage restored")
		_check(int(service_data.get("half_elixirs_used", 0)) == 1, "Half-elixir usage restored")
		var bonuses: Dictionary = service_data.get("permanent_damage_bonuses", {}) as Dictionary
		_check(int(bonuses.get("melee_damage", 0)) == 1, "Permanent consumable damage restored")

	# New third copy must not inherit legacy +4 or elemental upgrades.
	inventory["낡은 장검"] = 3
	world.call("_sync_item_instances")
	var new_ids: Array[String] = _sword_ids(world)
	_check(new_ids.size() == 3, "Third physical sword obtains a new ID")
	var fresh_ids: Array[String] = []
	for id: String in new_ids:
		if not ids.has(id):
			fresh_ids.append(id)
	_check(fresh_ids.size() == 1, "Only one physical ID allocated on pickup")
	if fresh_ids.size() == 1:
		var fresh: Dictionary = (world.get("item_instances") as Dictionary)[fresh_ids[0]] as Dictionary
		_check(int(fresh.get("level", -1)) == 0, "Newly dropped copy must start at +0")
		_check(int(fresh.get("element_level", -1)) == 0, "Newly dropped copy must have no elemental upgrade")

	world.call("_save_game", true)
	var current_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_check(current_data is Dictionary, "Modern save written after legacy migration")
	if current_data is Dictionary:
		var current: Dictionary = current_data as Dictionary
		_check((current.get("item_instances", {}) as Dictionary).size() >= 3, "New save persists physical item records")
		_check(current.has("consumable_state") and current.has("ground_drops"), "Modern save persists consumables and world drops")
	world.call("_load_game", true)
	_check(_sword_ids(world) == new_ids, "Repeated save/load preserves exact physical IDs")
	_check(int((world.get("inventory") as Dictionary).get("낡은 장검", 0)) == 3, "Repeated save/load preserves physical count")
	if fresh_ids.size() == 1 and (world.get("item_instances") as Dictionary).has(fresh_ids[0]):
		_check(int(((world.get("item_instances") as Dictionary)[fresh_ids[0]] as Dictionary).get("level", -1)) == 0, "Save/load does not spread an older enchant to new copy")

	# Malformed save should not replace a healthy in-memory character.
	var preserved_gold: int = int(world.get("gold"))
	_check(_write_save("{this-is-not-json"), "Can stage a corrupted save in isolated test directory")
	world.call("_load_game", true)
	_check(int(world.get("gold")) == preserved_gold, "Invalid JSON save does not destroy active character")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("STAGE5_SAVE_COMPATIBILITY_OK %d checks" % assertions)
		quit(0)
	else:
		print("STAGE5_SAVE_COMPATIBILITY_FAILED %d/%d" % [failures.size(), assertions])
		quit(1)
