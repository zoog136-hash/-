extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("GROUND_DROP_FAIL: " + message)

func _run() -> void:
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	if scene == null:
		_check(false, "Main.tscn cannot load")
		_finish()
		return
	var world: Node = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	var player: TwilightPlayer = world.get("player") as TwilightPlayer
	var drops: Node = world.get("drops_root") as Node
	var inventory: Dictionary = world.get("inventory") as Dictionary
	world.call("_clear_drops")
	var initial_count: int = int(inventory.get("HP 물약", 0))
	var drop: Button = world.call("_spawn_ground_drop", "HP 물약", player.global_position) as Button
	_check(is_instance_valid(drop) and drops.get_child_count() == 1, "visible ground item is not spawned")
	_check(int(inventory.get("HP 물약", 0)) == initial_count, "ground item was prematurely granted to inventory")
	_check(not bool(drop.is_queued_for_deletion()), "ground item expired before pickup")
	drop.pressed.emit()
	_check(int(inventory.get("HP 물약", 0)) == initial_count + 1, "click did not collect item within pickup radius")
	_check(drops.get_child_count() == 0, "picked-up ground item was not removed")
	_check(not bool(world.call("_collect_ground_drop", drop)), "item could be picked up twice")
	await process_frame

	var far_point: Vector2 = Vector2.ZERO
	for radius: int in [200, 155, 250]:
		for angle_index: int in range(24):
			var trial: Vector2 = player.global_position + Vector2.from_angle(float(angle_index) * TAU / 24.0) * float(radius)
			if not bool(world.call("_is_walkable_world", trial)):
				continue
			var path: PackedVector2Array = world.call("find_world_path", player.global_position, trial) as PackedVector2Array
			if path.size() < 2:
				continue
			far_point = trial
			break
		if far_point != Vector2.ZERO:
			break
	_check(far_point != Vector2.ZERO, "could not find distant reachable item target")
	if far_point != Vector2.ZERO:
		var distant: Button = world.call("_spawn_ground_drop", "HP 물약", far_point) as Button
		var before_click: int = int(inventory.get("HP 물약", 0))
		distant.pressed.emit()
		_check(int(inventory.get("HP 물약", 0)) == before_click, "distant click bypassed pickup radius")
		_check(is_instance_valid(world.get("pending_ground_pickup")), "distant click did not start walking to item")
		var manual_path: PackedVector2Array = player.get("click_path") as PackedVector2Array
		_check(not manual_path.is_empty(), "manual pickup did not plan a path")
		player.global_position = far_point
		world.call("_tick_manual_ground_pickup")
		_check(int(inventory.get("HP 물약", 0)) == before_click + 1, "manual walk-to-pickup failed")
		_check(drops.get_child_count() == 0, "manual item was not removed")
		player.clear_click_path()

	# AUTO pickup must reach the ground item from a ranged kill, then award only
	# once the player is within pickup distance.
	var auto_origin: Vector2 = player.global_position
	if far_point != Vector2.ZERO:
		player.global_position = far_point
	var auto_drop: Button = world.call("_spawn_ground_drop", "HP 물약", player.global_position + Vector2(13, 0)) as Button
	var auto_before: int = int(inventory.get("HP 물약", 0))
	_check(bool(world.call("_run_auto_ground_pickup")), "AUTO did not find nearby ground drop")
	_check(int(inventory.get("HP 물약", 0)) == auto_before + 1, "AUTO ground pickup did not grant loot")
	_check(drops.get_child_count() == 0, "AUTO collected item was not removed")
	player.global_position = auto_origin

	# Explicit save/reload-style snapshot must preserve dropped items without
	# granting anything to inventory or duplicating entries.
	var ground_at_save: Vector2 = player.global_position
	var snapshot_item: Button = world.call("_spawn_ground_drop", "HP 물약", ground_at_save) as Button
	_check(is_instance_valid(snapshot_item), "snapshot ground drop could not be created")
	var before_snapshot: int = int(inventory.get("HP 물약", 0))
	var snapshot: Array = world.call("_ground_drops_snapshot") as Array
	_check(snapshot.size() == 1, "ground item missing from save snapshot")
	world.call("_clear_drops")
	_check(drops.get_child_count() == 0, "clear drops left stale items")
	world.call("_restore_ground_drops", snapshot)
	_check(drops.get_child_count() == 1, "saved drop was not restored")
	_check(int(inventory.get("HP 물약", 0)) == before_snapshot, "restoring drop incorrectly changed inventory")

	# A real boss loot roll must generate ground items, not direct grants.
	world.call("_clear_drops")
	var mons: Node = world.get("monsters_root") as Node
	var monster_scene: PackedScene = load("res://scenes/Monster.tscn") as PackedScene
	var dummy: TwilightMonster = monster_scene.instantiate() as TwilightMonster
	mons.add_child(dummy)
	dummy.setup({"name":"검증 보스", "lv":1, "hp":1000, "is_boss":true, "drop":["HP 물약"]}, player, world, null)
	dummy.global_position = player.global_position
	var loot_before: int = int(inventory.get("HP 물약", 0))
	for attempt: int in range(8):
		world.call("_roll_drop", dummy)
		if drops.get_child_count() > 0:
			break
	_check(drops.get_child_count() > 0, "boss roll produced no visible ground item")
	_check(int(inventory.get("HP 물약", 0)) == loot_before, "boss roll directly deposited item in inventory")
	world.call("_clear_drops")
	world.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("GROUND_DROP_SMOKE_OK: manual/auto/loot/snapshot pickup validated")
		quit(0)
	else:
		print("GROUND_DROP_SMOKE_FAILED: %d failure(s)" % failures.size())
		quit(1)
