extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("SPEED FAIL: " + message)

func _run() -> void:
	var main_scene: PackedScene = load("res://Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn could not be loaded")
		_finish()
		return

	var world: Node = main_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	world.set("equipped_catalog", {
		"변신": {"name":"속도 테스트 변신", "speed":1.25, "attackSpeed":190.0},
		"마법인형": {"name":"속도 테스트 인형", "speed":1.02, "attackSpeed":15.0},
		"성물": {"name":"속도 테스트 성물", "speed":1.01, "attackSpeed":2.0}
	})
	world.set("equipped_items", {
		"weapon": {"name":"속도 테스트 무기", "speed":1.01, "attackSpeed":3.0},
		"armor": {},
		"accessory": {}
	})

	var move_multiplier: float = float(world.call("_effective_move_speed_multiplier"))
	var expected_move: float = 1.25 * 1.02 * 1.01 * 1.01
	if absf(move_multiplier - expected_move) > 0.001:
		_fail("move-speed options were not stacked correctly")

	var attack_bonus: float = float(world.call("_effective_attack_speed_bonus_percent"))
	if absf(attack_bonus - 210.0) > 0.001:
		_fail("attack-speed options were not summed correctly")

	var attack_multiplier: float = float(world.call("_effective_attack_speed_multiplier"))
	if absf(attack_multiplier - 3.10) > 0.001:
		_fail("attack-speed multiplier is incorrect")

	var interval: float = float(world.call("_normal_attack_interval"))
	if interval >= 0.72 or interval <= 0.12:
		_fail("attack-speed option did not shorten normal attack interval")

	world.call("_refresh_speed_modifiers")
	var player: Node = world.get_node("Player")
	if absf(float(player.get("equipment_move_speed_multiplier")) - expected_move) > 0.001:
		_fail("player did not receive movement-speed multiplier")
	if absf(float(player.get("attack_speed_multiplier")) - 3.10) > 0.001:
		_fail("player did not receive attack-speed multiplier")

	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("SPEED_OPTION_SMOKE_OK: attack/move speed options validated")
		quit(0)
	else:
		print("SPEED_OPTION_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
