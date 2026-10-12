extends SceneTree
## Real game HUD and detailed map use the same collision pathways as the world.
var world: TwilightWorld
var captures: Array[Dictionary]=[]
var target_map: String=""
const OUTPUT: String="res://docs/hunting-paths-20261012/evidence/ui/"

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="): target_map=arg.trim_prefix("--map=")
	call_deferred("run")

func capture(id: String, label: String) -> void:
	for i: int in range(3): await process_frame
	await RenderingServer.frame_post_draw
	var img: Image=root.get_texture().get_image()
	var name: String=id+"-"+label+".jpg"
	if img==null or img.is_empty() or img.save_jpg(OUTPUT+name,.91)!=OK:
		push_error("HUNTING_MAP_UI_FAILED "+name)
		quit(1)
		return
	captures.append({"map_id":id,"view":label,"file":name})
	print("HUNTING_MAP_UI_CAPTURED ",name)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Hunting map UI capture requires OpenGL")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	world=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.set_process(false)
	world.save_timer=-10000
	var entries: Array=[{"map_id":"aden_world"}]
	entries.append_array(JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH)))
	for entry: Dictionary in entries:
		var id: String=str(entry.map_id)
		if not target_map.is_empty() and id!=target_map: continue
		world._set_map(id,false)
		world.portal_cooldown=10000
		world.player.set_physics_process(false)
		world.field_population.set_process(false)
		for actor: Node in world.monsters_root.get_children(): actor.set_physics_process(false)
		world.hud._close_workspace()
		var sector: Dictionary=world.field_map.data.monster_spawn[0]
		world.player.global_position=Vector2(sector.rect[0]+sector.rect[2]*.5,sector.rect[1]+sector.rect[3]*.5)
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		world.field_renderer.refresh_visible()
		await capture(id,"hud")
		world.hud.toggle_map()
		await capture(id,"map")
	if not target_map.is_empty():
		var previous: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUTPUT+"captures.json"))
		var combined: Dictionary={}
		for record: Dictionary in previous.captures: combined[str(record.map_id)+"/"+str(record.view)]=record
		for record: Dictionary in captures: combined[str(record.map_id)+"/"+str(record.view)]=record
		captures.clear()
		for entry: Dictionary in entries:
			for label: String in ["hud","map"]: captures.append(combined[str(entry.map_id)+"/"+label])
	var file := FileAccess.open(OUTPUT+"captures.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"captures":captures},"  "))
	file.close()
	world.queue_free()
	await process_frame
	print("HUNTING_MAP_UI_OK ",captures.size())
	quit(0)
