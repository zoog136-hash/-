extends SceneTree
const QA = preload("res://tests/qa_class_selection.gd")
const SUPPLY_WORLD = preload("res://tests/regional_return_supply_world_fixture.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("TWILIGHT_REGIONAL_RETURN_TEST") != "1" or OS.get_environment("XDG_DATA_HOME").is_empty():
		printerr("REGIONAL_RETURN_TEST_REQUIRES_ISOLATED_XDG_PROFILE");quit(2);return
	var world = load("res://Main.tscn").instantiate()
	world.set_script(SUPPLY_WORLD)
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	var failures: Array[String] = []
	if not world.supply_problem.is_empty():failures.append(world.supply_problem)
	if not QA.enter_game(world):failures.append("startup")
	world.player.set_physics_process(false)
	var key: String = str(world.supply_record.get("name", ""))
	if world.active_map_id != "source_70" or world.source_save_blocked:failures.append("saved island startup")
	var guarded_current_source: bool = world.field_map is OriginalPlayableField and bool(world.field_map.get_meta("source_map84",false))
	var expected_base_count: int = 2 if guarded_current_source else 1
	var expected_target_count: int = 3 if guarded_current_source else 2
	var expected_slot: String = key if guarded_current_source else "잊혀진 귀환 주문서 (각인)"
	if int(world.inventory.get(key, 0)) != expected_base_count or str(world.quickslots[0].get("id", "")) != key:failures.append("exact supplier key preserved")
	if str(world.hud.quickslot_entries[0].get("id", "")) != expected_slot:failures.append("guarded source or host projection after startup registration")
	if int(world.inventory.get("잊혀진 귀환 주문서 (각인)", 0)) != expected_target_count:failures.append("target count preserved")
	world._on_quickslot_pressed(0)
	if int(world.inventory.get("잊혀진 귀환 주문서 (각인)", 0)) != (expected_target_count if guarded_current_source else expected_target_count-1) or int(world.inventory.get(key, 0)) != expected_base_count or world.active_map_id != "source_70":failures.append("restart guard or consumer key separation")
	print("REGIONAL_SUPPLY_RESTART_RESULT ", JSON.stringify({"failures":failures,"scope":"new process with verified supplier catalogue fixture, not production supplier execution"}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
