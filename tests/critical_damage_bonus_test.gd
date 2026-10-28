extends SceneTree

const INVEN = preload("res://scripts/inven_option_adapter.gd")
var failures: Array[String] = []

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("CRITICAL_DAMAGE_FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main_scene: PackedScene = load("res://Main.tscn") as PackedScene
	if main_scene == null:
		_check(false, "Cannot load Main.tscn")
		_finish()
		return
	var world: Node = main_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	world.set("equipped_items", {})
	world.call("_invalidate_equipment_static")
	world.set("equipped_catalog", {"변신": {}, "마법인형": {}, "성물": {}})
	world.call("_invalidate_equipment_static")
	var original_melee_rate: int = int(world.call("_player_critical_rate", "melee"))
	var original_ranged_rate: int = int(world.call("_player_critical_rate", "ranged"))

	_check(int(world.call("_critical_damage", 100)) == 150, "baseline critical hit uses 1.5x")
	_check(int(world.call("_player_critical_damage", 100, "melee")) == 150, "no melee bonus retains 1.5x")
	_check(int(world.call("_player_critical_damage", 100, "ranged")) == 150, "no ranged bonus retains 1.5x")

	world.set("equipped_items", {
		"weapon": {"name": "__crit_test_blade__", "atk": 0, "melee_critical_damage": 12, "ranged_critical_damage": 3},
		"ring1": {"name": "__crit_test_ring__", "atk": 0, "melee_critical_damage": 6}
	})
	world.call("_invalidate_equipment_static")
	world.set("equipped_catalog", {
		"변신": {"name": "__crit_test_transform__", "melee_critical_damage": 4, "ranged_critical_damage": 2},
		"마법인형": {"name": "__crit_test_doll__", "ranged_critical_damage": 7},
		"성물": {}
	})
	world.call("_invalidate_equipment_static")
	# 100 * 1.5 + (12 + 6 + 4) = 172. Bonuses are not multiplied by 1.5.
	_check(int(world.call("_player_critical_damage", 100, "melee")) == 172, "flat melee bonus added after base crit")
	_check(int(world.call("_player_critical_damage", 100, "ranged")) == 162, "ranged bonus is independent of melee")
	_check(int(world.call("_player_critical_damage", 100, "magic")) == 150, "magic crit unchanged")
	_check(int(world.call("_critical_damage", 100)) == 150, "monster/shared crit unaffected by player bonuses")
	_check(int(world.call("_player_critical_rate", "melee")) == original_melee_rate, "melee crit chance unaffected")
	_check(int(world.call("_player_critical_rate", "ranged")) == original_ranged_rate, "ranged crit chance unaffected")

	var from_source: Dictionary = INVEN.annotate({
		"source": "inven",
		"name": "__crit_test_source_item__",
		"sourceOptions": ["근거리 치명타 대미지 +9", "원거리 치명타 대미지 +5"]
	})
	_check(int(from_source.get("melee_critical_damage", 0)) == 9, "Inven melee option parsed")
	_check(int(from_source.get("ranged_critical_damage", 0)) == 5, "Inven ranged option parsed")
	world.set("equipped_catalog", {"변신": {}, "마법인형": {}, "성물": {}})
	world.call("_invalidate_equipment_static")
	world.set("equipped_items", {"weapon": from_source})
	world.call("_invalidate_equipment_static")
	_check(int(world.call("_player_critical_damage", 100, "melee")) == 159, "source melee option reaches damage")
	_check(int(world.call("_player_critical_damage", 100, "ranged")) == 155, "source ranged option reaches damage")
	_check(int(world.call("_player_critical_damage", 101, "melee")) == 161, "round base crit then add flat option")

	world.set("equipped_items", {})
	world.call("_invalidate_equipment_static")
	_check(int(world.call("_player_critical_damage", 100, "melee")) == 150, "unequip clears critical bonus immediately")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("CRITICAL_DAMAGE_OK: flat critical bonuses, style isolation and source options")
		quit(0)
	else:
		print("CRITICAL_DAMAGE_FAILED: %d failure(s)" % failures.size())
		quit(1)
