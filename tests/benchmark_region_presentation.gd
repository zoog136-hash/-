extends SceneTree
## Real OpenGL UI input + bounded cosmetic workload. No target-device FPS claim.
const QA = preload("res://tests/qa_class_selection.gd")
var failures: Array[String] = []
var samples: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); printerr("REGION_PRESENTATION_FAIL: ",label)

func click(button: Control, scroll: ScrollContainer) -> void:
	scroll.ensure_control_visible(button)
	await process_frame
	await process_frame
	var point: Vector2 = button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame

func run() -> void:
	check(DisplayServer.get_name() != "headless", "actual renderer required")
	var extent: String = OS.get_environment("TWILIGHT_QA_SIZE")
	if extent == "960x540": root.size = Vector2i(960,540)
	var world: TwilightWorld = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -100000.0
	check(QA.enter_game(world), "Main/class confirmation")
	world.player.set_physics_process(false)
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["마법인형"][0]
	world.doll_motion.configure(record,str(record.image_path),world.get_node("Companion"),world.companion_sprite,world.player)
	world.doll_motion.update(0.5,world.get_node("Companion"),world.companion_sprite,world.player)
	var viewports: Array[Vector2i] = [Vector2i(1280,720),Vector2i(960,540)]
	if extent == "960x540": viewports = [Vector2i(960,540)]
	for viewport: Vector2i in viewports:
		root.size = viewport
		world.hud.open_settings_info(true)
		await process_frame
		await process_frame
		var ui: Node = world.hud.find_child("RenewalSettings",true,false)
		check(ui != null, "settings panel opened at " + str(viewport))
		if ui == null: quit(1); return
		var scroll: ScrollContainer = ui.find_child("SettingsScroll",true,false)
		await click(ui.region_override,scroll)
		check(ui.region_override.button_pressed, "real pointer enables regional scope " + str(viewport))
		await click(ui.hide_doll,scroll)
		check(world.presentation_settings.hide_doll and not world.get_node("Companion").visible, "real pointer hides doll " + str(viewport))
		await click(ui.limit_effect_count,scroll)
		check(world.presentation_settings.limit_effect_count, "real pointer enables count budget " + str(viewport))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://region-settings-%dx%d.png" % [viewport.x,viewport.y])
		await click(ui.region_override,scroll)
		check(not world.presentation_settings.hide_doll and not world.presentation_settings.limit_effect_count, "real pointer restores global preferences " + str(viewport))
	root.size = Vector2i(1280,720)
	# Stop background AI/physics for comparable cost samples after UI input.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	# Time the real follower with an existing legacy sprite bank. No synthetic art.
	world.doll_motion.configure(record,str(record.image_path),world.get_node("Companion"),world.companion_sprite,world.player)
	check(world.doll_motion.enabled, "real legacy doll bank available for CPU sample")
	for hidden: bool in [false,true,false]:
		world.doll_motion.set_presentation_hidden(hidden,world.get_node("Companion"),world.companion_sprite,world.player)
		var timings: Array[int] = []
		for repeat: int in range(7):
			var started: int = Time.get_ticks_usec()
			for i: int in range(10000):
				world.doll_motion.update(1.0/60.0,world.get_node("Companion"),world.companion_sprite,world.player)
			timings.append(Time.get_ticks_usec()-started)
		timings.sort()
		samples.append({"kind":"follower","hidden":hidden,"median_us_per_10000":timings[3]})
	# Remove world from rendering while metering the same frozen effect records.
	world.hide()
	world.hud.hide()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var fx := preload("res://scripts/animation/combat_vfx.gd").new()
	layer.add_child(fx)
	for i: int in range(128): fx.impact(Vector2(160+(i%16)*60,180+(i/16)*35),Vector2.RIGHT,"slash",i%4 == 0)
	for i: int in range(16): fx.number(Vector2(160+i*60,140),"321",Color.WHITE)
	fx.ring(Vector2(640,360),90,Color.BLUE)
	fx.set_process(false)
	var before: String = JSON.stringify(fx.active)
	for budget: int in [160,24,160]:
		fx.impact_visual_limit = budget
		var timings: Array[int] = []
		for i: int in range(65):
			var started: int = Time.get_ticks_usec()
			fx.queue_redraw()
			await RenderingServer.frame_post_draw
			if i >= 5: timings.append(Time.get_ticks_usec()-started)
		timings.sort()
		check(fx.impact_draws == mini(128,budget), "drawn impact budget %d" % budget)
		check(JSON.stringify(fx.active) == before, "budget preserves every impact/number/ring record")
		samples.append({"kind":"OpenGL_redraw","budget":budget,"impacts_drawn":fx.impact_draws,"detailed":fx.detailed_draws,
			"records":fx.active.size(),"median_us":timings[30],"p95_us":timings[57],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
		root.get_texture().get_image().save_png("user://effects-%d.png" % budget)
	fx.clear()
	check(fx.active.is_empty() and fx.available.size() == fx.CAPACITY,"pool returns every record")
	var report: Dictionary = {"viewports":viewports,"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"samples":samples,"failures":failures,
		"limits":"CPU microbenchmark and software OpenGL frozen effects only; no Android/Windows FPS or native doll pack verification"}
	var output := FileAccess.open("user://region-presentation-benchmark.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	print("REGION_PRESENTATION_BENCHMARK ",JSON.stringify(report))
	layer.queue_free()
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
