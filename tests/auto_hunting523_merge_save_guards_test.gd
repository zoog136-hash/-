extends SceneTree
## Exercise the real save seam shared by movement and the newer main services.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("AUTO_HUNT_MERGE_FAIL: ", label)

func snapshot(world: Node) -> Dictionary:
	# Godot JSON reloads numbers as floats; compare the complete saved values
	# in that representation while still requiring the exact durable file hash.
	return {"gold": world.gold, "inventory": JSON.parse_string(JSON.stringify(world.inventory, "", true, true)),
		"instances": JSON.parse_string(JSON.stringify(world.item_instances, "", true, true)), "position": world.player.global_position,
		"sha": FileAccess.get_sha256(world.save_path())}

func run() -> void:
	var world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual Main startup")
	world.player.set_physics_process(false)
	if is_instance_valid(world.field_population): world.field_population.set_process(false)
	world.level = 99
	world.gold = 1234567
	check(world._save_game(true) == OK, "baseline save with newer services")
	check(world.auto_hunting_set_local_settings({"enabled": true, "end_inclusive": true,
		"search_order": "center_first", "gem_wallet_enabled": false, "allow_entry_area": false}).ok,
		"explicit movement policy")
	var quote: Dictionary = world.auto_hunting_movement_assessment(174, 882)
	check(quote.ok, "existing Aden destination passes production checks")
	if not quote.ok:
		world.queue_free()
		await process_frame
		quit(1)
		return
	var before: Dictionary = snapshot(world)
	for service: RefCounted in [world.source_dungeon_runs, world.dungeon_play]:
		service.save_blocked = true
		check(world.auto_hunting_move(174, 882).code == "SAVE_FAILED",
			"newer dungeon save guard rejects movement")
		check(snapshot(world) == before and not world.auto_hunting_move_in_progress,
			"guard failure preserves save, position, items and currency; releases movement lock")
		service.save_blocked = false
	for override: Dictionary in [{"source_dungeon523": {}}, {"source_dungeon_play": {}},
		{"inventory_automation": {"version": -1}}]:
		check(world._save_game(true, override) != OK, "newer malformed transaction rejected")
		check(snapshot(world) == before, "invalid transaction preserves durable and live state")
	var moved: Dictionary = world.auto_hunting_move(174, 882)
	check(moved.ok and world.player.global_position == quote.destination,
		"movement succeeds after guards restored")
	check(world.gold == int(before.gold) - int(quote.price), "only exact original fee charged once")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world.save_path()))
	for key: String in ["source_dungeon523", "source_dungeon_play", "inventory_automation"]:
		check(saved.has(key) and not saved[key].is_empty(), "movement save retains newer service: " + key)
	var after: Dictionary = snapshot(world)
	world._load_game(true)
	var restored: Dictionary = snapshot(world)
	for key: String in after:
		if restored[key] != after[key]:
			print("AUTO_HUNT_MERGE_RELOAD_DIFF ", key, " ", JSON.stringify({"saved": after[key], "restored": restored[key]}))
	check(restored == after, "combined movement and service save survives real reload unchanged")
	print("AUTO_HUNT_MERGE_RESULT ", JSON.stringify({"checks": checks, "failures": failures}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
