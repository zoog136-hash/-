extends SceneTree
## PR84: actual Main scene, all map IDs, renderer mesh and real viewport evidence.
var failures: Array[String] = []
var checks: int = 0
var ids: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("WORLD_TERRAIN_FAIL: " + label)
func run() -> void:
	var entries: Array = [{"map_id":"aden_world"}]
	entries.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")))
	var output := "res://docs/playable-maps-20261011/terrain-coverage-evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output + "/screenshots"))
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.max_hp = 1000000
	world.hp = 1000000
	world.save_timer = -10000
	var captures: Array[String] = []
	for entry: Dictionary in entries:
		var map_id: String = str(entry["map_id"])
		world._set_map(map_id, false)
		world.hud._close_workspace()
		var renderer: FieldRenderer = world.field_renderer
		var coverage: Node = renderer.terrain_root.get_node_or_null("Ground/TerrainCoverage")
		check(coverage != null, map_id + " full-world terrain layer exists")
		if coverage != null:
			check(coverage.get_child_count() == 2, map_id + " two regional materials")
			for child: Node in coverage.get_children():
				check(child is MeshInstance2D, map_id + " actual mesh geometry")
				if child is MeshInstance2D:
					var mesh: ArrayMesh = (child as MeshInstance2D).mesh as ArrayMesh
					check(mesh != null, map_id + " mesh allocated")
					if mesh != null:
						var array: Array = mesh.surface_get_arrays(0)
						var positions: PackedVector2Array = array[Mesh.ARRAY_VERTEX]
						var colors: PackedColorArray = array[Mesh.ARRAY_COLOR]
						check(positions.size() == colors.size() and positions.size() >= 6, map_id + " vertex colors")
						check(positions.has(world.field_map.bounds.position), map_id + " covers map start")
						check(positions.has(world.field_map.bounds.end), map_id + " covers map end")
						var a_min: float = 1.0
						var a_max: float = 0.0
						for color: Color in colors:
							a_min = minf(a_min, color.a)
							a_max = maxf(a_max, color.a)
						check(a_max > a_min, map_id + " spatial terrain changes")
		check(world.field_map.walkable(world.player.global_position), map_id + " player spawn walkable")
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		renderer.refresh_visible()
		for i: int in range(5):
			await physics_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			check(img != null and not img.is_empty(), map_id + " rendered viewport")
			if img != null and not img.is_empty():
				check(img.save_png(output + "/screenshots/" + map_id + ".png") == OK, map_id + " PNG saved")
				captures.append(map_id)
		ids.append(map_id)
	check(ids.size() == 25, "all 25 regions evaluated")
	var report: Dictionary = {"maps":ids,"captures":captures,"checks":checks,"failures":failures,
		"display":DisplayServer.get_name(),"original_restored":false,
		"scope":"whole-map biome mesh, spawn, viewport only, NOT full-map gameplay"}
	var file: FileAccess = FileAccess.open(output + "/result.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
		file.close()
	world.queue_free()
	await process_frame
	print("WORLD_TERRAIN_OK " if failures.is_empty() else "WORLD_TERRAIN_FAILED ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
