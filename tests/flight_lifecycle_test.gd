extends SceneTree

const FLIGHTS = preload("res://scripts/animation/combat_flights.gd")
var callbacks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("_run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FLIGHT FAIL: " + label)

func _run() -> void:
	var manager: TwilightCombatFlights = FLIGHTS.new()
	var target: Node2D = Node2D.new()
	root.add_child(manager)
	root.add_child(target)
	await process_frame
	for i: int in range(256):
		manager.launch(Vector2(0, -24), target, "magic", func() -> void: callbacks += 1)
	manager._physics_process(0.02)
	check(callbacks == 256, "visual budget dropped real damage callbacks")
	check(manager.available.size() == 128 and manager.flights.is_empty(), "flight pool exceeds limit")
	check(not manager.is_physics_processing(), "empty flight system remains active")
	callbacks = 0
	for i: int in range(3):
		manager.launch(Vector2(0, -24), target, "magic", func() -> void:
			callbacks += 1
			manager.clear()
		)
	manager._physics_process(0.02)
	check(callbacks == 1 and manager.flights.is_empty(), "respawn/map-clear reentrancy ran stale callback")
	manager.queue_free()
	target.queue_free()
	await process_frame
	if failures == 0: print("FLIGHT_LIFECYCLE_OK logical_hits=256 visual_cap=64 reuse_cap=128")
	quit(0 if failures == 0 else 1)
