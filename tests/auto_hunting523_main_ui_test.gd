extends SceneTree
## Production Main/HUD selection and rejection must preserve live and saved state.
const QA = preload("res://tests/qa_class_selection.gd")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("AUTO_HUNT523_MAIN_FAIL: ", message)

func run() -> void:
	var scene := load("res://Main.tscn") as PackedScene
	check(scene != null, "production Main scene loads")
	if scene == null:
		quit(1)
		return
	var world = scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "actual class confirmation and game startup")
	world.player.set_physics_process(false)
	world.gold = 987654
	world.player.auto_enabled = true
	var map_id: String = world.active_map_id
	var position: Vector2 = world.player.global_position
	check(world._save_game(true) == OK, "isolated production save")
	var save_path: String = world.save_path()
	var saved_sha: String = FileAccess.get_sha256(save_path)
	var inventory: String = JSON.stringify(world.inventory)
	var instances: String = JSON.stringify(world.item_instances)
	world._update_hud()
	# Same route as the existing AUTO menu tile, not a detached mock window.
	world.hud._navigate("auto")
	await process_frame
	check(world.hud.active_section == "auto", "existing menu route opens AUTO")
	var view: Node = world.hud.find_child("AutoHuntingDestinations", true, false)
	check(view != null and view.is_visible_in_tree(), "destination UI mounted in visible production AUTO window")
	var actual: bool = not OS.get_environment("TWILIGHT_AUTO_HUNT523_DIR").is_empty()
	if view != null:
		if actual:
			check(view.entries.size() == 80, "production UI receives eighty actual source entries")
			check(view.regions.item_count == 80, "all regions selectable")
			var links: int = 0
			for i: int in range(view.entries.size()):
				view.regions.select(i)
				view.regions.item_selected.emit(i)
				var entry: Dictionary = view.entries[i]
				check(view.landings.item_count == entry.destinations.size(), "UI retains landing multiplicity")
				check(view.details.text.contains(str(int(entry.teleport.TeleportCost))), "source cost shown")
				for j: int in range(entry.destinations.size()):
					links += 1
					view.landings.select(j)
					view.landings.item_selected.emit(j)
					check(not view.status.text.is_empty(), "selection exposes assessment result")
			check(links == 87, "all87 landing selections exercised through UI signals")
			view.regions.select(0)
			view.regions.item_selected.emit(0)
			check(view.status.text.contains("이동"), "unverified movement explanation visible")
		else:
			check(view.entries.is_empty(), "missing pack shows install state instead of fixture regions")
	var assessment: Dictionary = world.auto_hunting_movement_assessment(4, 662)
	check(not assessment.ok, "production world refuses unverified movement")
	check(world.active_map_id == map_id and world.player.global_position == position, "map and position preserved")
	check(world.gold == 987654, "gold not charged")
	check(world.player.auto_enabled, "combat AUTO unchanged")
	check(JSON.stringify(world.inventory) == inventory and JSON.stringify(world.item_instances) == instances, "inventory and physical equipment preserved")
	check(FileAccess.get_sha256(save_path) == saved_sha, "no save write during browsing or rejected movement")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture=") and not DisplayServer.get_name() == "headless":
			await process_frame
			await RenderingServer.frame_post_draw
			var target: String = arg.trim_prefix("--capture=")
			check(root.get_texture().get_image().save_png(target) == OK, "actual AUTO screen captured")
	print("AUTO_HUNT523_MAIN_RESULT ", JSON.stringify({"checks": checks, "failures": failures, "actual523": actual}))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
