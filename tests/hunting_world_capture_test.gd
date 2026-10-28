extends SceneTree
## Actual OpenGL renders; both passes read the same saved camera manifest.
var phase: String = "after"
var target_map: String = ""
var world: Variant = null  # Loaded from Main.tscn at test runtime, not editor class-scan time.
var captures: Array[Dictionary] = []
const BASE: String = "res://docs/hunting-paths-20261012/evidence/"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
		if arg.begins_with("--map="): target_map = arg.trim_prefix("--map=")
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("HUNTING_CAPTURE_SKIP: OpenGL display required")
		quit(0)
		return
	var output: String = BASE+phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.hud.hide()
	world.set_process(false)
	world.save_timer = -10000
	var cameras: Array = []
	if phase == "before":
		var entries: Array = [{"map_id":"aden_world"}]
		entries.append_array(JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH)))
		for entry: Dictionary in entries:
			var id: String = str(entry.map_id)
			var definition: Dictionary
			if id == "aden_world": definition = world.maps_by_id[id].field_definition
			else: definition = JSON.parse_string(FileAccess.get_file_as_string(entry.path))
			var b: Array = definition.bounds
			var whole_zoom: float=roundf(minf(1240.0/b[2],650.0/b[3])*1000000.0)/1000000.0
			cameras.append({"map_id":id,"label":"whole","position":[b[0]+b[2]*.5,b[1]+b[3]*.5],"zoom":whole_zoom})
			var hunting: Dictionary = definition.monster_spawn[0]
			var rect: Array = hunting.rect
			cameras.append({"map_id":id,"label":"hunting","position":[rect[0]+rect[2]*.5,rect[1]+rect[3]*.5],"zoom":.65})
			var edge: Array = definition.spawn_position.duplicate()
			if id == "aden_world": edge = [6860,6800]
			elif id == "oman_01": edge = [1640,2100]
			elif str(definition.family) in ["oman","faith","albino"]:
				edge = [definition.spawn_position[0]-560,definition.spawn_position[1]-450]
			else: edge = [700,700]
			cameras.append({"map_id":id,"label":"boundary","position":edge,"zoom":.65})
		var file := FileAccess.open(BASE+"cameras.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(cameras,"  ",true,true))
		file.close()
	else:
		cameras = JSON.parse_string(FileAccess.get_file_as_string(BASE+"cameras.json"))
	var active: String = ""
	for view: Dictionary in cameras:
		if not target_map.is_empty() and str(view.map_id)!=target_map: continue
		if active != str(view.map_id):
			active = str(view.map_id)
			world._set_map(active,false)
			world.portal_cooldown = 10000
			world.player.set_physics_process(false)
			world.field_population.set_process(false)
			for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
		world.player.visible = str(view.label) != "whole"
		world.monsters_root.hide()
		world.player.global_position = Vector2(view.position[0],view.position[1])
		world.player.camera.position = Vector2.ZERO
		world.player.camera.zoom = Vector2.ONE * float(view.zoom)
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.field_renderer.refresh_visible()
		if bool(world.field_renderer.get_meta("native_png", false)):
			if not await world.field_renderer.settle_visible():
				push_error("HUNTING_CAPTURE_FAILED: visible original PNGs did not finish loading");quit(1);return
		for i: int in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var filename: String = active+"-"+str(view.label)+".jpg"
		var img: Image = root.get_texture().get_image()
		if img == null or img.is_empty() or img.save_jpg(output+"/"+filename,.92) != OK:
			push_error("HUNTING_CAPTURE_FAILED "+filename)
			quit(1)
			return
		var record: Dictionary = view.duplicate(true)
		record["file"] = filename
		record["camera_center"] = [world.player.camera.get_screen_center_position().x,world.player.camera.get_screen_center_position().y]
		record["camera_zoom"] = [world.player.camera.zoom.x,world.player.camera.zoom.y]
		record["visible_chunks"] = world.field_renderer.chunks.size()
		record["visible_props"] = world.field_renderer.visible_props
		captures.append(record)
		print("HUNTING_CAPTURED ",filename)
	if not target_map.is_empty():
		var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output+"/captures.json"))
		var combined: Dictionary={}
		for record: Dictionary in previous.captures: combined[str(record.map_id)+"/"+str(record.label)]=record
		for record: Dictionary in captures: combined[str(record.map_id)+"/"+str(record.label)]=record
		captures.clear()
		for view: Dictionary in cameras: captures.append(combined[str(view.map_id)+"/"+str(view.label)])
	var manifest := FileAccess.open(output+"/captures.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"phase":phase,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"captures":captures},"  ",true,true))
	manifest.close()
	world.queue_free()
	await process_frame
	print("HUNTING_CAPTURE_OK ",captures.size())
	quit(0)
