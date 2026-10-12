extends SceneTree
## Capture the actual game renderer at full-map and playable-camera scales.
var phase: String = "after"
var output: String = ""
var world: TwilightWorld
var captures: Array[Dictionary] = []

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	call_deferred("run")

func capture(id: String, label: String, position: Vector2, zoom: float) -> void:
	world.player.global_position = position
	world.player.camera.position = Vector2.ZERO
	world.player.camera.zoom = Vector2.ONE * zoom
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for i: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var filename: String = id + "-" + label + ".jpg"
	if img == null or img.is_empty() or img.save_jpg(output + "/" + filename, .92) != OK:
		push_error("STRUCTURE_CAPTURE_FAILED " + filename)
		quit(1)
	captures.append({"map_id":id,"label":label,"file":filename,"position":[position.x,position.y],"zoom":zoom,
		"camera_center":[world.player.camera.get_screen_center_position().x,world.player.camera.get_screen_center_position().y],
		"bounds":world.field_map.data.bounds,"visible_chunks":world.field_renderer.chunks.size()})

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("WORLD_STRUCTURE_CAPTURE_SKIP: OpenGL display required")
		quit(0)
		return
	output = "res://docs/world-structure-20261011/evidence/" + phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.hud.hide()
	world.set_process(false)
	world.save_timer = -10000
	var entries: Array = [{"map_id":"aden_world"}]
	entries.append_array(JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH)))
	for entry: Dictionary in entries:
		var id: String = str(entry.map_id)
		world._set_map(id,false)
		world.portal_cooldown = 10000
		world.player.set_physics_process(false)
		world.player.hide()
		world.field_population.set_process(false)
		world.monsters_root.hide()
		for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
		var field: PlayableField = world.field_map
		var fit: float = minf(1240.0/field.bounds.size.x,650.0/field.bounds.size.y)
		await capture(id,"whole",field.bounds.get_center(),fit)
		if id in ["aden_world","oman_01"]:
			world.player.show()
			world.monsters_root.show()
			await capture(id,"entry",Vector2(field.data.spawn_position[0],field.data.spawn_position[1]),.78)
			world.hud.show()
			world.hud.toggle_map()
			for i: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			if root.get_texture().get_image().save_jpg(output+"/"+id+"-map-ui.jpg",.92)!=OK:
				push_error("STRUCTURE_MAP_UI_CAPTURE_FAILED "+id)
			world.hud._close_workspace()
			world.hud.hide()
			world.monsters_root.hide()
		print("STRUCTURE_CAPTURED ",id," ",phase)
	var file := FileAccess.open(output+"/captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase":phase,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"captures":captures},"  "))
	file.close()
	world.queue_free()
	await process_frame
	print("WORLD_STRUCTURE_CAPTURE_OK ",captures.size())
	quit(0)
