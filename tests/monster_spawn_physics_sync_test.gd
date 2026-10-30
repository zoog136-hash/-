extends SceneTree

# Regression for the Aden arrival stall (2026-10-30). Monsters are kinematic
# bodies; spawning one at the origin and then moving it made the next physics
# step sweep its broadphase box across the whole map. Arriving on Aden (~360
# actors) during a physics callback produced ~350,000 collision pairs and a
# multi-minute step, which also timed out the regional CI shard. Every freshly
# spawned actor must already be at its spawn point in the physics server, and
# offscreen actors must not show their overhead name/HP on the first frame.
# Run with `-- --legacy-map-layouts` (as the regional suite does) for the
# crowded historical Aden population.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("MONSTER_SPAWN_SYNC FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world)
	world.save_timer = -10000
	await process_frame
	await process_frame
	# Arrive from inside a physics callback, the exact ordering that exposed it.
	await physics_frame
	world._set_map("aden_world", false)
	var monsters: Array[TwilightMonster] = []
	for node: Node in world.monsters_root.get_children():
		if node is TwilightMonster and not (node as TwilightMonster).dead: monsters.append(node)
	check(monsters.size() >= 100, "crowded field spawned its population (%d)" % monsters.size())
	var unsynced: int = 0
	var far_labels: int = 0
	for monster: TwilightMonster in monsters:
		var server: Transform2D = PhysicsServer2D.body_get_state(monster.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM)
		# A restored boss may be nudged within its leash after spawning; the
		# harmful case is a body still at the origin or on the previous map.
		if server.origin.distance_to(monster.global_position) > 1000.0: unsynced += 1
		if monster.global_position.distance_to(world.player.global_position) > monster.OVERHEAD_UI_DISTANCE and (monster.name_label.visible or monster.hp_bar.visible):
			far_labels += 1
	check(unsynced == 0, "%d spawned actors far from their spawn point in the physics server" % unsynced)
	check(far_labels == 0, "%d offscreen actors show overhead UI on their first frame" % far_labels)
	var started: int = Time.get_ticks_msec()
	await physics_frame
	await physics_frame
	var pairs: float = Performance.get_monitor(Performance.PHYSICS_2D_COLLISION_PAIRS)
	var elapsed: int = Time.get_ticks_msec() - started
	check(pairs < float(monsters.size()) * 20.0, "collision pairs stay local after arrival (%d for %d actors)" % [int(pairs), monsters.size()])
	print("MONSTER_SPAWN_SYNC_RESULT ", JSON.stringify({"failures":failures, "actors":monsters.size(), "pairs":int(pairs), "first_steps_ms":elapsed}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
