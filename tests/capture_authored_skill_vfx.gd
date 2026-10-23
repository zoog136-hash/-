extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("VFX capture needs actual Compatibility rendering")
		quit(1)
		return
	var output := OS.get_environment("TWILIGHT_VFX_CAPTURE_DIR")
	if output.is_empty(): output = "/tmp/twilight-vfx-frames"
	DirAccess.make_dir_recursive_absolute(output)
	var lab: Node2D = load("res://scenes/SkillVFXLab.tscn").instantiate()
	root.add_child(lab)
	lab.autoplay = false
	var serial := 0
	var all_skills := OS.get_cmdline_user_args().has("--all")
	var samples: Array[int] = []
	var report: Array[Dictionary] = []
	for index: int in range(lab.skill_names.size()):
		if all_skills:
			if lab.vfx.library.profiles[str(lab.ids[lab.skill_names[index]])].has("atlas"): samples.append(index)
		elif index < 12: samples.append(index)
	for sample: int in samples:
		lab.selected = sample
		lab.play_selected()
		for frame: int in range(36):
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			if picture.save_png(output.path_join("frame_%04d.png" % serial)) != OK:
				push_error("Cannot preserve actual VFX capture")
				quit(1)
				return
			serial += 1
			if frame == 12:
				picture.save_png(output.path_join("sample_%02d.png" % sample))
		report.append({"id":lab.current_id, "name":lab.skill_names[sample], "class":lab.current.get("class"), "preview_contacts":lab.hits})
	var metadata := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"frames":serial, "fps":30, "all_natural_effects":all_skills, "samples":report, "visual_fidelity_approval":"PENDING"}, "  "))
	metadata.close()
	# Eight actual sprite orientations, captured separately from the movie.
	lab.selected = 2
	for direction: int in range(8):
		lab.direction_index = direction
		lab.play_selected()
		for frame: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("direction_%d.png" % direction))
	print("AUTHORED_VFX_CAPTURE_OK frames=%d directions=8 renderer=%s" % [serial, RenderingServer.get_video_adapter_name()])
	quit(0)
