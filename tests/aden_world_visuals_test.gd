extends SceneTree
## Real Main/Compatibility renderer. Saves isolated by the invoking command.
const VISUAL = preload("res://scripts/maps/aden_world_visuals/chunk.gd")
const QA = preload("res://tests/qa_class_selection.gd")
var world: TwilightWorld
var failures: Array[String] = []
var checks: int = 0
var output: String = "user://aden-world-visuals"
var capture: bool = false
var overview: bool = false
var entrances_only: bool = false
var regions: Array[Dictionary] = []
var screenshots: Array[Dictionary] = []
var metrics: Dictionary = {}

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label);printerr("ADEN_WORLD_FAIL ",label)
func frames(n: int = 4) -> void:
	for i: int in range(n): await process_frame

func place(cell: Vector2i) -> Vector2i:
	var field: RemakePlayableField = world.field_map
	var actual: Vector2i = field.nearest_cell(field.cell_to_world(cell))
	if actual.x<0: return actual
	world.player.global_position = field.cell_to_world(actual)
	world.player.velocity = Vector2.ZERO;world.player.clear_click_path()
	world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
	field.collision_stream.refresh();world.field_renderer.refresh_visible()
	return actual

func picture(name: String, zoom_value: float = 1.0) -> void:
	world.hud._close_workspace();world.player.camera.zoom = Vector2.ONE*zoom_value
	world.player.camera.force_update_scroll();world.field_renderer.refresh_visible()
	await frames(6)
	if not capture: return
	check(DisplayServer.get_name() != "headless","real rendering display "+name)
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path: String = output+"/"+name+".png"
	check(root.get_texture().get_image().save_png(path)==OK,"actual PNG "+name)
	var c: Vector2i = world.field_map.world_to_cell(world.player.global_position)
	screenshots.append({"file":name+".png","cell":[c.x,c.y],"viewport":[root.size.x,root.size.y],"zoom":zoom_value,"camera_offset":[world.player.camera.position.x,world.player.camera.position.y]})

func inspect_site(site: Dictionary) -> void:
	var field: RemakePlayableField = world.field_map
	var seed := Vector2i(int(site.cell[0]),int(site.cell[1]))
	world.player.camera.position=Vector2(0,-32)
	var actual: Vector2i = place(seed)
	if actual.x<0:
		check(false,str(site.id)+" has no authoritative walking cell within source nearest-cell limit")
		regions.append({"id":site.id,"requested_cell":[seed.x,seed.y],"status":"FAIL_NO_SOURCE_LANDING"})
		return
	world.player.camera.zoom = Vector2.ONE;world.player.camera.force_update_scroll()
	for i: int in range(3): await physics_frame
	var row: Dictionary = {"id":site.id,"requested_cell":[seed.x,seed.y],"actual_cell":[actual.x,actual.y]}
	check(field.point_clear(world.player.global_position),str(site.id)+" source foot clearance")
	var start: Vector2 = world.player.global_position
	var target: Vector2 = start
	for distance: int in [6,4,2,1]:
		for heading: int in [0,2,4,6,1,3,5,7]:
			var end: Vector2 = field.cell_to_world(actual+field.DIRECTIONS[heading]*distance)
			if field.line_clear(start,end): target=end;break
		if target!=start:break
	check(target!=start,str(site.id)+" original walking corridor")
	if target!=start:
		world.player.set_touch_vector((target-start).normalized())
		var valid: bool = true
		for i: int in range(18):
			await physics_frame;valid = valid and field.walkable(world.player.global_position)
		world.player.set_touch_vector(Vector2.ZERO)
		row.moved_pixels = world.player.global_position.distance_to(start)
		check(row.moved_pixels>minf(10.0,start.distance_to(target)*.3) and valid,str(site.id)+" actual movement stays on source grid")
	# Query a real streamed physics edge near each site, with server sync.
	var edge_start := Vector2i(-1,-1);var edge_end := Vector2i(-1,-1)
	for radius: int in range(1,34):
		for dy: int in range(-radius,radius+1):
			for dx: int in [-radius,radius]:
				var c: Vector2i = actual+Vector2i(dx,dy)
				if not field.in_bounds(c) or not field.point_clear(field.cell_to_world(c)): continue
				for h: int in [0,2,4,6]:
					if not field.can_step(c,h): edge_start=c;edge_end=c+field.DIRECTIONS[h];break
				if edge_start.x>=0:break
			if edge_start.x>=0:break
		if edge_start.x>=0:break
	check(edge_start.x>=0,str(site.id)+" nearby source collision edge found")
	if edge_start.x>=0:
		place(edge_start)
		for i: int in range(3):await physics_frame
		var ray := PhysicsRayQueryParameters2D.create(field.cell_to_world(edge_start),field.cell_to_world(edge_end),4)
		check(not world.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(),str(site.id)+" real physics edge ray")
		var direction: Vector2 = (field.cell_to_world(edge_end)-world.player.global_position).normalized()
		world.player.set_touch_vector(direction)
		var valid: bool = true
		for i: int in range(12):await physics_frame;valid = valid and field.walkable(world.player.global_position)
		world.player.set_touch_vector(Vector2.ZERO)
		check(valid,str(site.id)+" physical edge push stays walkable")
		row.collision_edge = [[edge_start.x,edge_start.y],[edge_end.x,edge_end.y]]
	place(actual)
	var times: Array[float] = []
	for i: int in range(20):
		var begin: int = Time.get_ticks_usec();await process_frame
		times.append(float(Time.get_ticks_usec()-begin)/1000.0)
	times.sort();row.frame_ms_median=times[10];row.frame_ms_p95=times[18]
	row.visible_chunks=world.field_renderer.chunks.size()
	check(row.visible_chunks<=49,str(site.id)+" bounded graphics stream")
	for chunk: Node in world.field_renderer.chunks.values():check(chunk.get_meta("aden_world_visuals",false),str(site.id)+" new visual chunk")
	if site.has("camera_anchor"):
		var anchor := Vector2i(int(site.camera_anchor[0]),int(site.camera_anchor[1]))
		world.player.camera.position=field.cell_to_world(anchor)-world.player.global_position+Vector2(0,-160)
		row.inspection_scope=site.get("inspection_scope","")
	await picture(str(site.id)+"-play",float(site.get("zoom",1.0)))
	regions.append(row)
	print("ADEN_WORLD_REGION ",JSON.stringify(row))

func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg=="--capture":capture=true
		if arg=="--overview":overview=true
		if arg=="--entrances-only":entrances_only=true
	DirAccess.make_dir_recursive_absolute(output);root.size=Vector2i(1280,720)
	world=load("res://Main.tscn").instantiate();root.add_child(world)
	check(QA.enter_game(world),"actual Main character selection")
	world.save_timer=-100000;world.set_process(false);world.field_population.set_process(false)
	for mob: Node in world.monsters_root.get_children():mob.set_physics_process(false)
	if not world.field_map is RemakePlayableField:check(false,"Aden original field active");finish();return
	var field: RemakePlayableField = world.field_map
	check(field.width==2048 and field.height==1536 and field.chunk_table.size()==768,"entire original grid and 768 navigation chunks")
	check(VISUAL.applies(field,Vector2i.ZERO),"new full-map visual layer initialized")
	if entrances_only:
		var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/aden_world_visuals/source_structures.json"))
		for i: int in range(structures.entrance_visuals.size()):
			var site: Dictionary = structures.entrance_visuals[i]
			await inspect_site({"id":"source-entry-%02d-map-%d" % [i,int(site.target_source_map_id)],"cell":site.source_cell})
		metrics.scope="entrance visual sites only; all-chunk sweep is in the separate full-world report"
		finish();return
	# Every source navigation chunk is decompressed/verified by production code.
	var verified_nav: int = 0
	for y: int in range(24):
		for x: int in range(32):
			var c := Vector2i(x*64+32,y*64+32)
			field.value_at(c,false);field.value_at(c,true)
			if field.nav_cache.has(Vector2i(x,y)):verified_nav+=1
	check(verified_nav==768,"all navigation chunk loads")
	metrics.navigation_chunks=verified_nav
	var sites: Array = VISUAL.manifest.towns.duplicate(true)
	var extra: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/aden_world_visuals/inspection_sites.json"))
	if extra is Array:sites.append_array(extra)
	for site: Dictionary in sites:await inspect_site(site)
	# Exercise every 32x32 visual chunk with production build, not a fixture.
	var started: int = Time.get_ticks_usec();var built: int = 0;var sprites: int = 0
	var full_nodes: Array[Node2D] = []
	world.player.set_physics_process(false)
	for y: int in range(48):
		for x: int in range(64):
			var chunk: Node2D = VISUAL.new();chunk.y_sort_enabled=true
			world.field_renderer.add_child(chunk);chunk.build(field,Vector2i(x,y),null,{},false)
			sprites+=chunk.get_child_count()-1;built+=1
			if overview:full_nodes.append(chunk)
			else:chunk.free()
		await process_frame
	metrics.all_visual_chunks=built;metrics.all_visual_sprite_nodes=sprites
	metrics.all_chunk_build_ms=float(Time.get_ticks_usec()-started)/1000.0
	check(built==3072,"all full-grid visual chunks build in engine")
	if overview:
		# QA-only overview renders every actual chunk. Production stays capped49.
		world.field_renderer.set_process(false)
		world.hud.hide()
		for chunk: Node in world.field_renderer.chunks.values():chunk.hide()
		world.player.camera.zoom=Vector2.ONE*.0145
		world.player.camera.global_position=field.bounds.get_center()
		world.player.camera.reset_smoothing();world.player.camera.force_update_scroll()
		await frames(12)
		if capture:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output+"/aden-entire-world.png")==OK,"actual full-world Godot overview PNG")
		for node: Node2D in full_nodes:node.free()
	metrics.peak_stream_build_ms=float(world.field_renderer.stream_build_usec)/1000.0
	check(field.nav_cache.size()<=field.CACHE_LIMIT,"bounded navigation cache after entire-grid sweep")
	finish()

func finish() -> void:
	var report: Dictionary = {"status":"PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,
		"engine":Engine.get_version_info().string,"display":DisplayServer.get_name(),"renderer":RenderingServer.get_video_adapter_name(),
		"regions":regions,"screenshots":screenshots,"metrics":metrics,
		"android_device":"NOT_RUN","android_gpu_performance":"NOT_RUN","exact_original_camera":"NOT_RUN",
		"continuous_end_to_end_walk":"NOT_RUN","latest_m_all_objects_identified":"NOT_RUN",
		"scope":"Actual Main entrance visual sites; target scenes/triggers are not implemented by this test." if entrances_only else "Actual Main; site movement and physics rays/push; all navigation loads; all visual builds. Overview is QA-only all-chunk render, not normal streaming performance."}
	var file := FileAccess.open(output+"/runtime.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ADEN_WORLD_RESULT ",JSON.stringify(report))
	if is_instance_valid(world):world.queue_free()
	quit(0 if failures.is_empty() else 1)
