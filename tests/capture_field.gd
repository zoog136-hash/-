extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")

# Run on a real GL display (or Xvfb), not --headless. Writes user://field-review/.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not CLASS_QA.enter_game(world):
		push_error("Rendered gameplay class confirmation failed")
		quit(1)
		return
	world._set_map("aden_world",false)
	world.save_timer = -10000
	var directory: String = "user://field-review"
	DirAccess.make_dir_recursive_absolute(directory)
	var scenes: Dictionary = {
		"01-village":Vector2(2240,4090),
		"02-meadow":Vector2(3300,4370),
		"03-bridge":Vector2(6180,3000),
		"04-ruins":Vector2(7960,2930),
		"05-forest":Vector2(2880,2130)
	}
	var frame_samples: Array[float] = []
	for title: String in scenes:
		world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(scenes[title]))
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.field_renderer.refresh_visible()
		for i: int in range(45):
			var start: int = Time.get_ticks_usec()
			await process_frame
			if i > 8:
				frame_samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		image.save_png(directory+"/"+title+".png")
		print("CAPTURE ",title," ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," calls / ",world.field_renderer.visible_props," props")
	print("CAPTURE_DIRECTORY ",ProjectSettings.globalize_path(directory))
	frame_samples.sort()
	print("RENDER_FRAME median_ms=",frame_samples[frame_samples.size()/2]," p95_ms=",frame_samples[int(frame_samples.size()*.95)])
	world.queue_free()
	await process_frame
	quit()
