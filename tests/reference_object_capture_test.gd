extends SceneTree
## Identical cameras on the saved structure and the object-placement pass.
var phase: String = "after"
var world: TwilightWorld
var captures: Array[Dictionary] = []
var output: String

const VIEWS: Array = [
	["gludio", [10400,16320]], ["gludio_entry", [11250,16320]],
	["kent", [19720,11440]], ["giran", [25840,9240]],
	["aden", [44800,8480]], ["heine", [41200,14600]],
	["oren", [30200,2160]], ["weldan", [21360,6000]],
	["windawood", [19520,19160]], ["silver_knight", [28640,16360]],
	["fire_village", [6200,11000]], ["elf_village", [9760,7680]],
	["elf_forest", [6480,7920]], ["eastern_forest", [36000,7400]],
	["dragon_valley", [14500,3450]], ["heine_bank", [38560,13040]],
	["desert", [20400,17600]]
]

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	call_deferred("run")

func capture(id: String, label: String, position: Vector2, zoom: float, actors: bool) -> void:
	world.player.visible = actors
	world.monsters_root.hide()
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
	if img == null or img.is_empty() or img.save_jpg(output+"/"+filename,.93) != OK:
		push_error("OBJECT_CAPTURE_FAILED "+filename)
		quit(1)
	captures.append({"map_id":id,"label":label,"file":filename,"position":[position.x,position.y],"zoom":zoom,
		"camera_center":[world.player.camera.get_screen_center_position().x,world.player.camera.get_screen_center_position().y],
		"visible_chunks":world.field_renderer.chunks.size(),"visible_props":world.field_renderer.visible_props})
	print("OBJECT_CAPTURED ",filename)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("REFERENCE_OBJECT_CAPTURE_SKIP: OpenGL display required")
		quit(0)
		return
	output = "res://docs/object-placement-20261011/evidence/"+phase
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
		world.field_population.set_process(false)
		for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
		var bounds: Rect2 = world.field_map.bounds
		await capture(id,"whole",bounds.get_center(),minf(1240.0/bounds.size.x,650.0/bounds.size.y),false)
		if id == "aden_world":
			for view: Array in VIEWS: await capture(id,str(view[0]),Vector2(view[1][0],view[1][1]),.78,true)
		elif id == "oman_01":
			await capture(id,"entrance",Vector2(2736,3424),.78,true)
			await capture(id,"western_rail",Vector2(1640,2100),.78,true)
			await capture(id,"central",Vector2(4688,2640),.78,true)
	var file := FileAccess.open(output+"/captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"phase":phase,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"captures":captures},"  "))
	file.close()
	world.queue_free()
	await process_frame
	print("REFERENCE_OBJECT_CAPTURE_OK ",captures.size())
	quit(0)
