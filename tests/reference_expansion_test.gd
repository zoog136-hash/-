extends SceneTree
## Real Main scene and rendered captures; reference styling is not restoration.
var failures: Array[String] = []
var checked: Array[String] = []
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); printerr("REFERENCE_EXPANSION_FAIL: "+label)
func run() -> void:
	var world: TwilightWorld=load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection(); world.hud._close_workspace()
	world.max_hp=1000000; world.hp=1000000; world.save_timer=-10000
	DirAccess.make_dir_recursive_absolute("user://reference-expansion")
	var maps: Array=[{"map_id":"aden_world"}]
	maps.append_array(JSON.parse_string(FileAccess.get_file_as_string(world.FIELD_INDEX_PATH)))
	for entry: Dictionary in maps:
		var id: String=str(entry.map_id)
		world._set_map(id,false)
		world.hud._close_workspace()
		var renderer: FieldRenderer=world.field_renderer
		check(not renderer.reference_profile.is_empty(),id+" explicit visual profile")
		check(renderer.terrain.resource_path=="res://assets/maps/reference_expansion_v2/terrain.png",id+" production atlas")
		check(world.field_map.walkable(world.player.global_position),id+" spawn navigation")
		check(world.field_minimap.field==world.field_map,id+" minimap identity")
		for material: ShaderMaterial in renderer.ground_materials.values():
			check(float(material.get_shader_parameter("atlas_grid"))==4.0,id+" new atlas UV mapping")
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		renderer.refresh_visible()
		for i: int in range(5): await physics_frame
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			var img: Image=root.get_texture().get_image()
			check(img!=null and not img.is_empty(),id+" viewport rendered")
			if img!=null: check(img.save_png("user://reference-expansion/"+id+".png")==OK,id+" viewport saved")
		checked.append(id)
		print("REFERENCE_MAP ",id)
	check(checked.size()==25,"all 25 TWILIGHT maps rendered separately")
	var report: Dictionary={"maps":checked,"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"original_restored":false,"scope":"render/atlas/spawn/minimap; gameplay verified separately"}
	var file=FileAccess.open("user://reference-expansion/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "));file.close()
	world.queue_free();await process_frame
	print("REFERENCE_EXPANSION_OK " if failures.is_empty() else "REFERENCE_EXPANSION_FAIL: ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
