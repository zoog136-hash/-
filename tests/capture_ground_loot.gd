extends SceneTree

const OUTPUT: String = "user://ground-loot-review"
var world: TwilightWorld
var captures: int = 0
var failed: bool = false

func _initialize() -> void: call_deferred("_run")

func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	if pixels == null or pixels.is_empty() or pixels.save_png(OUTPUT + "/" + name_value + ".png") != OK:
		failed = true
		push_error("Ground loot render missing " + name_value)
	else:
		captures += 1
		print("GROUND_LOOT_CAPTURE ", name_value)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	world = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.save_timer = -10000
	world.field_population.set_process(false)
	world._clear_monsters()
	world._clear_drops()
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(Vector2(3550,4300)))
	world.player.camera.zoom = Vector2.ONE
	world.player.camera.position = Vector2(0,-110)
	world.player.camera.position_smoothing_enabled = false
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var caption_layer := CanvasLayer.new()
	caption_layer.layer = 19
	root.add_child(caption_layer)
	var samples: Array[Button] = []
	for index: int in range(7):
		var grade: String = TwilightDropVisual.GRADES[index]
		var item_name: String = str(world.loot_catalog["equipment_by_grade"][grade][0])
		var where: Vector2 = world.player.global_position + Vector2(float(index - 3) * 105, -20)
		var view: Button = world._spawn_ground_drop(item_name, where)
		samples.append(view)
	for i: int in range(20): await process_frame
	for view: Button in samples:
		var label := Label.new()
		label.text = str(view.get_meta("grade"))
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", TwilightDropVisual.grade_color(label.text))
		label.position = WorldCoordinates.world_to_screen(root, view.get_meta("world_position")) + Vector2(-22, 22)
		caption_layer.add_child(label)
	await capture("01-seven-grades")
	samples[6].pressed.emit()
	await process_frame
	await capture("02-manual-selection")
	world.loot_pickup.cancel()
	caption_layer.queue_free()
	world._clear_drops()
	var where: Vector2 = world.player.global_position + Vector2(260,0)
	var view: Button = world._spawn_ground_drop(str(world.loot_catalog["equipment_by_grade"]["희귀"][0]), where)
	world.player.set_auto_enabled(true)
	for i: int in range(12):
		world._process(1.0 / 60.0)
		await physics_frame
	await capture("03-auto-approach")
	print("GROUND_LOOT_RENDER_OK captures=",captures," directory=",ProjectSettings.globalize_path(OUTPUT))
	world.queue_free()
	await process_frame
	quit(1 if failed or captures != 3 else 0)
