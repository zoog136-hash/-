extends SceneTree

const GATE = preload("res://scripts/deferred_save_gate.gd")

func _initialize() -> void:
	call_deferred("run")

func _gate_checks(failures: Array[String]) -> void:
	var gate = GATE.new(10.0)
	if gate.pending() or gate.tick(1.0): failures.append("idle gate fired")
	gate.request()
	gate.request()
	if not gate.pending(): failures.append("request did not open a window")
	if gate.tick(9.0): failures.append("gate fired before its window")
	gate.request()
	# A later request must not extend the window: unsaved data stays <= interval old.
	if not gate.tick(1.0): failures.append("gate did not fire at the window end")
	if gate.pending() or gate.tick(100.0): failures.append("gate fired twice for one window")
	if gate.fires != 1 or gate.requests != 3: failures.append("gate counters %d/%d" % [gate.fires, gate.requests])
	gate.request()
	gate.cancel()
	if gate.pending() or gate.tick(100.0): failures.append("cancel left a pending save")

func run() -> void:
	var failures: Array[String] = []
	_gate_checks(failures)
	if "--gate-only" in OS.get_cmdline_user_args():
		print("DEFERRED_SAVE_GATE_RESULT ", JSON.stringify({"failures":failures}))
		quit(0 if failures.is_empty() else 1)
		return
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate() as TwilightWorld
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	world.player.set_physics_process(false)
	for monster: Node in world.monsters_root.get_children():
		monster.set_process(false)
		monster.set_physics_process(false)
	var writer = world.equipment_collections
	if world.deferred_save_enabled: failures.append("headless suites must keep synchronous saves")
	# Exercise the on-device behaviour explicitly.
	world.deferred_save_enabled = true
	if world._save_game(true) != OK: failures.append("baseline durable save")
	var baseline_writes: int = writer.save_writes
	world.gold += 17
	for index: int in range(5): world._request_deferred_save()
	if writer.save_writes != baseline_writes: failures.append("deferred request wrote synchronously")
	if not world.deferred_save.pending(): failures.append("deferred request was not queued")
	if world.deferred_save.tick(world.DEFERRED_SAVE_SECONDS - 0.5): failures.append("deferred save fired early")
	if world.deferred_save.tick(1.0): world._save_game(true)
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	if writer.save_writes != baseline_writes + 1 or int(disk.get("gold", -1)) != world.gold:
		failures.append("five deferred requests did not make exactly one durable write")
	# An immediate (transaction) save already contains queued changes.
	world.gold += 5
	world._request_deferred_save()
	if world._save_game(true) != OK: failures.append("immediate save failed")
	if world.deferred_save.pending(): failures.append("immediate save left a redundant deferred save")
	# A staged override does not commit live state, so the queued save must survive it.
	world.gold += 3
	world._request_deferred_save()
	if world._save_game(true, {"gold": world.gold}) != OK: failures.append("staged save failed")
	if not world.deferred_save.pending(): failures.append("staged override cancelled a live-state save")
	# Backgrounding the app flushes the queue.
	world.gold += 9
	world._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	disk = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	if int(disk.get("gold", -1)) != world.gold or world.deferred_save.pending():
		failures.append("pause notification did not flush pending changes")
	if FileAccess.file_exists(world.save_path() + ".tmp"): failures.append("atomic writer left a temporary save")
	print("DEFERRED_SAVE_GATE_RESULT ", JSON.stringify({"failures":failures, "writes":writer.save_writes}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
