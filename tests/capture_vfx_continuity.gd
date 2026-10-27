extends SceneTree
# Deterministic presentation fixture; real combat is checked separately in Main.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := OS.get_environment("TWILIGHT_CONTINUITY_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	var stage := Node2D.new()
	root.add_child(stage)
	RenderingServer.set_default_clear_color(Color("19201d"))
	for point: Vector2 in [Vector2(460, 420), Vector2(790, 340)]:
		var actor = load("res://scenes/Player.tscn").instantiate()
		stage.add_child(actor)
		actor.camera.enabled = false
		actor.position = point + Vector2(0, 24)
		actor.set_physics_process(false)
	var script_path := "res://scripts/skills/skill_vfx.gd"
	if OS.get_environment("TWILIGHT_CONTINUITY_BASELINE") == "1": script_path = "res://tests/_vfx_before.gd"
	var vfx = load(script_path).new()
	stage.add_child(vfx)
	vfx.use_private_sources = false
	vfx.emit_skill("lm_ec6fd92ac55c73e9", "impact", Vector2(790,300), Vector2(460,420), {"ground_point":Vector2(790,364)})
	vfx.set_process(false)
	for phase: String in ["impact", "aftermath"]:
		if phase == "aftermath": vfx._process(float(vfx.live[0].ttl) + .02)
		vfx.set_process(false)
		vfx._seek_layers(vfx.live[0], .08)
		for layer: AnimatedSprite2D in vfx.live[0].layers.get_children(): layer.pause()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(phase + ".png"))
	var active_nodes: int = vfx.get_child_count()
	var samples: Array[float] = []
	for index: int in range(120):
		var before := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		samples.append((Time.get_ticks_usec() - before) / 1000.0)
	vfx.clear()
	var report := {"fixture":"chain impact to ground dust, two existing Player actors; no damage", "renderer":RenderingServer.get_video_adapter_name(), "vfx_root_direct_children":active_nodes, "after_clear_live":vfx.live.size(), "after_clear_atlas_bytes":vfx.library.resident_rgba_bytes(), "frames":samples.size(), "android":"NOT_RUN"}
	samples.sort()
	report["median_frame_ms"] = samples[60]
	report["p95_frame_ms"] = samples[114]
	var file := FileAccess.open(output.path_join("metrics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	stage.queue_free()
	await process_frame
	quit()
