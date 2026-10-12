extends SceneTree
## Actual Main scene and identical terrain cameras for baseline/current revisions.
var phase: String = "after"
var failures: Array[String] = []
var checks: int = 0
var captures: Array[Dictionary] = []
var performance: Array[Dictionary] = []
var world: TwilightWorld
var output: String

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("SURFACE_RENDER_FAIL: "+label)

func capture(map_id: String, label: String, requested: Vector2, zoom_value: float) -> void:
	var field: PlayableField = world.field_map
	var cell: Vector2i = field.nearest_cell(requested)
	check(cell.x>=0,map_id+" camera has a reachable cell")
	if cell.x<0: return
	world.player.global_position = field.cell_to_world(cell)
	world.player.camera.zoom = Vector2.ONE*zoom_value
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	for i: int in range(6): await physics_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	check(img!=null and not img.is_empty(),map_id+" real viewport")
	if img==null or img.is_empty(): return
	var filename: String = map_id+"-"+label+".jpg"
	check(img.save_jpg(output+"/"+filename,.9)==OK,map_id+" screenshot written")
	var camera_center: Vector2 = world.player.camera.get_screen_center_position()
	captures.append({"map":map_id,"file":filename,"position":[world.player.global_position.x,world.player.global_position.y],"camera_center":[camera_center.x,camera_center.y],"zoom":zoom_value,"viewport":[img.get_width(),img.get_height()]})
	check(field.walkable(world.player.global_position),map_id+" walkable camera destination")
	if label=="middle":
		var times: Array[float] = []
		for i: int in range(12):
			var started: int = Time.get_ticks_usec()
			await process_frame
			times.append(float(Time.get_ticks_usec()-started)/1000.0)
		times.sort()
		performance.append({"map":map_id,"frame_interval_ms_median":times[times.size()/2],"static_memory_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"visible_chunks":world.field_renderer.chunks.size()})

func run() -> void:
	if DisplayServer.get_name()=="headless":
		print("SURFACE_RENDER_SKIP: actual OpenGL display required")
		quit(0)
		return
	output = "res://docs/playable-maps-20261011/terrain-surface-evidence/"+phase
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	seed(8403)
	world = load("res://Main.tscn").instantiate()
	root.add_child(world)
	world.hud.complete_class_selection()
	world.hud._close_workspace()
	world.max_hp = 1000000
	world.hp = 1000000
	world.save_timer = -10000
	var entries: Array = [{"map_id":"aden_world"}]
	entries.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/field_index.json")))
	for entry: Dictionary in entries:
		var id: String = str(entry.map_id)
		var load_started: int = Time.get_ticks_usec()
		world._set_map(id,false)
		var load_ms: float = float(Time.get_ticks_usec()-load_started)/1000.0
		world.portal_cooldown = 10000
		world.set_process(false)
		world.player.set_auto_enabled(false)
		world.player.set_physics_process(false)
		world.player.hide()
		world.field_population.set_process(false)
		for actor: Node2D in world.monsters_root.get_children():
			actor.set_physics_process(false)
		world.monsters_root.hide()
		world.hud.hide()
		var field: PlayableField = world.field_map
		if phase=="after":
			for material: ShaderMaterial in world.field_renderer.ground_materials.values():
				check(bool(material.get_shader_parameter("terrain_variation")),id+" stochastic ground active")
				check(material.get_shader_parameter("terrain") is Texture2D,id+" real terrain atlas loaded")
				var variation: Texture2D = material.get_shader_parameter("terrain_variation_map")
				check(variation!=null and variation.get_width()==128,id+" shared variation texture loaded")
			var coverage: Node = world.field_renderer.terrain_root.get_node_or_null("Ground/TerrainCoverage")
			var layers: Array = coverage.get_children() if coverage!=null else []
			if field.data.has("world_geometry"):
				check(world.field_renderer.terrain_root.get_node_or_null("Ground/ReferenceGeography")!=null,id+" explicit map geometry replaces stochastic layout")
			for layer: MeshInstance2D in layers:
				check(bool(layer.material.get_shader_parameter("regional_mix")),id+" regional edge breakup active")
				check(layer.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()>0,id+" compact indexed ground")
				var palette: Color = layer.material.get_shader_parameter("palette")
				world.field_renderer.set_visual_mode("classic")
				check(layer.material.get_shader_parameter("palette")!=palette,id+" terrain follows visual mode")
				world.field_renderer.set_visual_mode("twilight")
				check(layer.material.get_shader_parameter("palette")==palette,id+" terrain restores palette")
		var regions: Array = field.data.regions
		var selected: Array = [regions[0],regions[regions.size()/2],regions[-1]]
		for i: int in range(3):
			var point: Array = selected[i].center
			await capture(id,["entry","middle","far"][i],Vector2(point[0],point[1]),.72 if i==1 else 1.0)
		performance[-1]["load_ms"] = load_ms
		print("SURFACE_RENDER_MAP ",id," phase=",phase," load_ms=",load_ms)
	check(captures.size()==75,"three terrain cameras in all 25 maps")
	var report: Dictionary = {"phase":phase,"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"checks":checks,"failures":failures,"captures":captures,"performance":performance,"scope":"actual Main terrain-only viewports, three sampled areas per map; HUD and moving actors hidden; not full-map gameplay or device acceptance"}
	var file := FileAccess.open(output+"/result.json",FileAccess.WRITE)
	check(file!=null,"report writable")
	if file!=null:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	world.queue_free()
	await process_frame
	print("SURFACE_RENDER_OK " if failures.is_empty() else "SURFACE_RENDER_FAILED ",JSON.stringify({"checks":checks,"failures":failures,"captures":captures.size(),"phase":phase}))
	quit(0 if failures.is_empty() else 1)
