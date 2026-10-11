extends SceneTree
## Matched before/after real-game cameras across every existing TWILIGHT map.
var checks: int = 0
var failures: Array[String] = []
var phase: String = "after"
var output: String
var world: TwilightWorld
var captures: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ROAD_RENDER_FAIL: " + label)

func freeze_actors() -> void:
	world.set_process(false)
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children():
		monster.set_physics_process(false)

func capture(id: String, label: String, requested: Vector2, zoom_value: float) -> void:
	var field: PlayableField = world.field_map
	var cell: Vector2i = field.nearest_cell(requested)
	check(cell.x >= 0, id + " camera destination is reachable")
	if cell.x < 0: return
	world.player.global_position = field.cell_to_world(cell)
	world.player.camera.zoom = Vector2.ONE * zoom_value
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for i: int in range(6): await physics_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	check(img != null and not img.is_empty(), id + " real rendered viewport")
	if img == null or img.is_empty(): return
	var filename: String = id + "-" + label + ".jpg"
	check(img.save_jpg(output + "/" + filename, 0.88) == OK, id + " screenshot saved")
	captures.append({"map": id, "file": filename, "position": [world.player.global_position.x, world.player.global_position.y], "zoom": zoom_value})
	check(field.walkable(world.player.global_position), id + " camera/player location walkable")
	check(world.field_renderer.chunks.size() < 25, id + " streamed scenery remains bounded")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("ROAD_RENDER_SKIP: requires an actual OpenGL display; no screenshots claimed")
		quit(0)
		return
	output = "res://docs/playable-maps-20261011/road-mesh-evidence/" + phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	seed(8402)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.save_timer = -10000
	world.max_hp = 1000000
	world.hp = 1000000
	var entries: Array = [{"map_id": "aden_world"}]
	entries.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")))
	var index: int = 0
	for entry: Dictionary in entries:
		var id: String = str(entry.map_id)
		seed(8402 + index)
		var started: int = Time.get_ticks_msec()
		world._set_map(id, false)
		world.portal_cooldown = 10000
		world.hud._close_workspace()
		freeze_actors()
		var load_ms: int = Time.get_ticks_msec() - started
		var field: PlayableField = world.field_map
		if phase == "after":
			var network: Node = world.field_renderer.terrain_root.get_node_or_null("Road/RoadNetwork")
			check(network != null and network.get_child_count() > 0, id + " new roads integrated in game")
			if network != null:
				for child: Node in network.get_children():
					check(child is MeshInstance2D, id + " roads use actual triangle meshes")
			if id == "aden_world":
				var plazas: int = 0
				for child: Node in world.field_renderer.terrain_root.get_node("GroundDetail").get_children():
					if child is MeshInstance2D: plazas += 1
				check(plazas == 3, "all three Aden courtyard meshes mounted")
		var roads: Array = field.data.roads
		var first: Array = roads[0].points
		var a := Vector2(first[0][0], first[0][1])
		var b := Vector2(first[1][0], first[1][1])
		await capture(id, "route", a.lerp(b, 0.5), 0.78)
		var junction: Vector2 = b
		var seen: Dictionary = {}
		var found: bool = false
		for road: Dictionary in roads:
			for point: Array in road.points:
				var p := Vector2(point[0], point[1])
				if seen.has(p) and not found:
					junction = p
					found = true
				seen[p] = true
		await capture(id, "junction", junction, 1.0)
		print("ROAD_RENDER_MAP ", id, " phase=", phase, " load_ms=", load_ms)
		index += 1
	check(index == 25 and captures.size() == 50, "two actual cameras in all 25 maps")
	var report: Dictionary = {"phase": phase, "engine": Engine.get_version_info().string,
		"display": DisplayServer.get_name(), "checks": checks, "failures": failures,
		"captures": captures, "scope": "25 maps, two road cameras/zooms each; not a full-world sweep or device acceptance"}
	var file := FileAccess.open(output + "/result.json", FileAccess.WRITE)
	check(file != null, "report writable")
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	world.queue_free()
	await process_frame
	print("ROAD_RENDER_OK " if failures.is_empty() else "ROAD_RENDER_FAILED ", JSON.stringify({"checks": checks, "failures": failures, "captures": captures.size(), "phase": phase}))
	quit(0 if failures.is_empty() else 1)
