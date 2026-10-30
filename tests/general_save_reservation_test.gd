extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures: Array[String] = []
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
	if world._save_game(true) != OK:failures.append("baseline durable save")
	var baseline_writes: int = writer.save_writes
	var baseline_skips: int = writer.skipped_identical_saves
	var baseline_json_builds: int = writer.payload_json_builds
	for index: int in range(3):world._request_general_save()
	if not world.general_save_pending or writer.save_writes != baseline_writes:failures.append("autosave committed before deferred reservation")
	await process_frame
	if world.general_save_pending or writer.save_writes != baseline_writes or writer.skipped_identical_saves != baseline_skips + 1 or writer.payload_json_builds != baseline_json_builds:
		failures.append("same snapshot reservations did not coalesce and skip")
	world.gold += 71
	for index: int in range(3):world._request_general_save()
	await process_frame
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	if writer.save_writes != baseline_writes + 1 or int(disk.get("gold",-1)) != world.gold:
		failures.append("changed reservations did not make one durable write")
	var saved_gold: int = world.gold
	var staged_gold: int = saved_gold + 43
	world._request_general_save()
	if world._save_game(true,{"gold":staged_gold}) != OK:failures.append("important transaction did not commit immediately")
	disk = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	if int(disk.get("gold",-1)) != staged_gold or world.gold != saved_gold:failures.append("staged transaction changed live state or waited for debounce")
	world.gold = staged_gold
	var committed_writes: int = writer.save_writes
	var committed_json_builds: int = writer.payload_json_builds
	await process_frame
	if writer.save_writes != committed_writes or writer.payload_json_builds != committed_json_builds or int((JSON.parse_string(FileAccess.get_file_as_string(world.save_path())) as Dictionary).get("gold",-1)) != staged_gold:
		failures.append("older reserved save overwrote committed transaction")
	var durable_hash: String = FileAccess.get_sha256(world.save_path())
	writer.test_save_writer = func(_path: String, _data: Dictionary) -> Error: return ERR_CANT_CREATE
	if world._save_game(true,{"gold":staged_gold+99}) == OK or FileAccess.get_sha256(world.save_path()) != durable_hash or world.gold != staged_gold:
		failures.append("failed important write changed disk or live state")
	writer.test_save_writer = Callable()
	if world._save_game(true,{"gold":staged_gold+99}) != OK:failures.append("save did not recover after transient writer failure")
	if FileAccess.file_exists(world.save_path()+".tmp"):failures.append("atomic writer left a temporary save")
	print("GENERAL_SAVE_RESERVATION_RESULT ",JSON.stringify({"failures":failures,"writes":writer.save_writes,"skips":writer.skipped_identical_saves,"revision_skips":writer.skipped_revision_saves,"json_builds":writer.payload_json_builds}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
