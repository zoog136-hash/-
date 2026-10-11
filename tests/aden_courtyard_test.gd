extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("COURTYARD_FAIL: "+label)
func capture(world: TwilightWorld, label: String, at: Vector2) -> void:
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(at))
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for i: int in range(6): await physics_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("user://aden-courtyard/"+label+".png")==OK,"capture "+label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://aden-courtyard")
	check(DisplayServer.get_name()!="headless","real rendering display")
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	preload("res://tests/legacy_aden_fixture.gd").install(world)
	world.hud.complete_class_selection();world.hud._close_workspace()
	world._set_map("aden_world",false)
	world.save_timer=-10000; world.set_process(false)
	world.player.set_physics_process(false);world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	var field_identity: PlayableField = world.field_map
	var materials: Array[ShaderMaterial]=world.field_renderer.courtyard_materials
	check(materials.size()==3,"three existing courtyard locations retained")
	var palette: Array[Color]=[]
	for material: ShaderMaterial in materials: palette.append(material.get_shader_parameter("palette"))
	world.field_renderer.set_visual_mode("classic")
	for i: int in range(materials.size()):
		check(materials[i].get_shader_parameter("palette")!=palette[i],"classic mode updates independent courtyard "+str(i))
	await capture(world,"02-village-classic",Vector2(2416,4112))
	world.field_renderer.set_visual_mode("twilight")
	for i: int in range(materials.size()):
		check(materials[i].get_shader_parameter("palette")==palette[i],"original palette restores on courtyard "+str(i))
	check(world.field_map==field_identity,"style switches preserve navigation identity")
	await capture(world,"03-ruins",Vector2(7960,2930))
	await capture(world,"04-north-courtyard",Vector2(10700,2010))
	world._set_map("oman_01",false)
	check(world.field_renderer.courtyard_materials.is_empty(),"non-Aden renderer keeps old ground behavior")
	var report: Dictionary={"checks":checks,"failures":failures,"platform":"Godot 4.7.2 Linux software OpenGL","scope":"three courtyard placements, classic/default style restoration, navigation identity, three real viewports, non-Aden scope"}
	var file:=FileAccess.open("user://aden-courtyard/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	print("COURTYARD_RESULT ",JSON.stringify(report))
	world.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
