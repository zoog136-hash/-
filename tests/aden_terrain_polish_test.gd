extends SceneTree
## Actual Main scene, isolated user data, before/after captures and GPU seam probe.
const COORD = preload("res://scripts/maps/world_coordinates.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0
var phase: String = OS.get_environment("ADEN_POLISH_PHASE")
var directory: String
var seam_delta: float = 0.0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("ADEN_POLISH_FAIL: "+label)

func capture(label: String, at: Vector2) -> void:
	world.player.clear_click_path()
	world.player.global_position = at
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for i: int in range(6): await physics_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"capture "+label)
	print("ADEN_CAPTURE ",phase," ",label, " at ",at)

func probe_seam() -> void:
	# x=6*430 is an actual old sampler wrap. Render a 2-world-pixel strip
	# magnified horizontally, so natural texture variation cannot hide the jump.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256,128)
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera2D.new()
	camera.position = Vector2(2580,3900)
	camera.zoom = Vector2(128,1)
	viewport.add_child(camera)
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(2578,3800),Vector2(2582,3800),Vector2(2582,4000),Vector2(2578,4000)])
	polygon.material = world.field_renderer._ground_material(1)
	viewport.add_child(polygon)
	for i: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	for y: int in range(128):
		var a: Color = img.get_pixel(120,y)
		var b: Color = img.get_pixel(136,y)
		seam_delta += (absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0/128.0
	check(img.save_png(directory+"/ground-seam-probe.png")==OK,"save actual GPU seam strip")
	if phase != "before": check(seam_delta<.02,"ground continuity across former texture wrap")
	viewport.queue_free()
	print("ADEN_GPU_SEAM mean_rgb_delta=",seam_delta)

func gameplay() -> void:
	var field: PlayableField = world.field_map
	world.player.set_physics_process(true)
	world.player.global_position = Vector2(3580,3640)
	world._set_click_destination(Vector2(3770,3560))
	for i: int in range(160): await physics_frame
	check(world.player.global_position.distance_to(Vector2(3770,3560))<12,"actual click movement")
	world.player.global_position = Vector2(5490,4300)
	world.player.set_touch_vector(Vector2.RIGHT)
	for i: int in range(130): await physics_frame
	world.player.set_touch_vector(Vector2.ZERO)
	check(world.player.global_position.x<5850,"actual manual motion blocked by river")
	check(world.field_physics.get_child_count()==field.blockers.size(),"physics footprints preserved")
	var route: PackedVector2Array = field.path(Vector2(2420,4100),Vector2(8150,3460))
	check(route.size()>2,"path to ruins across bridge")
	var route_clear: bool = not route.is_empty()
	for i: int in range(route.size()-1): route_clear = route_clear and field.line_clear(route[i],route[i+1])
	check(route_clear,"route avoids terrain collision and corner cutting")
	world.player.set_physics_process(false)
	await capture("04-canopy-before",Vector2(2416,4112))
	var occluder: Sprite2D
	for candidate: Node2D in world.field_renderer.faded:
		if str(candidate.get_meta("prop_kind","")) in ["oak","oak2","pine","birch"]:
			occluder = candidate as Sprite2D
			break
	check(occluder!=null,"foreground canopy present")
	if occluder!=null:
		var old_position: Vector2 = world.player.global_position
		world.player.global_position = occluder.position+Vector2(0,-95)
		world.field_renderer._process(.3)
		check(occluder.modulate.a<.8,"foreground fades behind canopy")
		world.player.global_position = occluder.position+Vector2(0,80)
		world.field_renderer._process(.3)
		check(is_equal_approx(occluder.modulate.a,1.0),"foreground recovers in front")
		world.player.global_position = old_position
	check(world.field_renderer.npc_visuals.size()==field.data.npc_spawn.size(),"all NPC sprites preserved")
	var shop: Dictionary = field.data.npc_spawn.filter(func(n: Dictionary) -> bool: return str(n.role)=="shop")[0]
	world.player.global_position = COORD.array_vector(shop.position)+Vector2(0,90)
	world._set_click_destination(COORD.array_vector(shop.position))
	check(world.hud.workspace.visible and world.hud.active_section=="shop","nearby NPC click opens real shop")
	world.hud._close_workspace()
	check(world.field_minimap.field==field,"minimap field identity")
	world._save_game(true)
	var saved_position: Vector2 = world.player.global_position
	world.player.global_position = Vector2(3580,3640)
	world._load_game(true)
	check(world.player.global_position.distance_to(saved_position)<1,"isolated save/load position")
	check(world.use_field_portal("oman_gate"),"inter-map portal works")
	check(world.active_map_id=="oman_01","portal destination")
	check(not bool(world.field_renderer._ground_material(1).get_shader_parameter("continuous_ground")),"dungeon keeps existing sampler")
	check(world.use_field_portal("aden_return"),"return portal works")
	check(world.active_map_id=="aden_world","returns to Aden")
	check(world.field_renderer.chunks.size()<25,"bounded streamed chunks")

func run() -> void:
	if phase.is_empty(): phase = "after"
	seed(8401)
	directory = "user://aden-polish/"+phase
	DirAccess.make_dir_recursive_absolute(directory)
	check(DisplayServer.get_name()!="headless","real rendering display")
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	preload("res://tests/legacy_aden_fixture.gd").install(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world._set_map("aden_world",false)
	world.save_timer = -10000
	world.set_process(false)
	world.player.set_auto_enabled(false)
	world.player.set_physics_process(false)
	world.field_population.set_process(false)
	for monster: Node in world.monsters_root.get_children(): monster.set_physics_process(false)
	await capture("01-village",Vector2(2416,4112))
	await capture("02-road",Vector2(3300,4370))
	await capture("03-bridge",Vector2(6180,3000))
	await probe_seam()
	if phase != "before": await gameplay()
	var report: Dictionary = {"phase":phase,"checks":checks,"failures":failures,"seam_mean_rgb_delta":seam_delta,"platform":"Godot 4.7.2 Linux software OpenGL","original_restored":false,"physical_devices_tested":false}
	var output := FileAccess.open(directory+"/result.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"  ")); output.close()
	print("ADEN_POLISH_RESULT ",JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
