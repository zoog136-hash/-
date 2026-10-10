extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")

# Exact GL screenshots and frame timings of real gameplay, not concept art.
const COORD = preload("res://scripts/maps/world_coordinates.gd")
const DETAIL_KINDS: Dictionary = {"oman_01":"tomb", "domination_summit":"arch", "escaros_05":"obelisk", "albino_01":"crystal", "faith_04":"altar"}
var capture_count: int = 0
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _save_view(directory: String, filename: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	if screenshot == null or screenshot.is_empty():
		push_error("Empty gameplay capture: "+filename)
		failed = true
		return
	# Compact previews from the actual 1280x720 viewport, not mockups.
	screenshot.resize(800,450,Image.INTERPOLATE_LANCZOS)
	if screenshot.save_png(directory+"/"+filename+".png") != OK:
		push_error("Cannot save gameplay capture: "+filename)
		failed = true
	else:
		capture_count += 1

func _aim(world: TwilightWorld, point: Vector2) -> void:
	world.player.global_position = world.field_map.cell_to_world(world.field_map.nearest_cell(point))
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()

func _validate_cache(renderer: FieldRenderer) -> void:
	if renderer.landmark_cache == null:
		return
	var pixels: Image = renderer.landmark_cache.get_texture().get_image()
	if pixels == null or pixels.is_empty():
		push_error("Landmark cache has no rendered pixels")
		failed = true
		return
	for key: String in renderer.landmark_textures:
		var texture: AtlasTexture = renderer.landmark_textures[key]
		var cell: Image = pixels.get_region(Rect2i(texture.region))
		if cell.get_used_rect().size.y < 8:
			push_error("Empty baked landmark: "+key)
			failed = true
	if renderer.landmark_cache.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		push_error("Landmark atlas continues rendering after its initial frame")
		failed = true

func _benchmark_play(world: TwilightWorld, map_id: String, directory: String) -> Dictionary:
	world.rng.seed = 20261008
	world._set_map(map_id,false)
	world.hp = world._effective_max_hp()
	# Keep population, AI, physics, combat, HUD and chunk streaming active here.
	# The static screenshot phase above intentionally freezes monster AI.
	var point: Vector2 = Vector2(3550,4300) if map_id == "aden_world" else COORD.array_vector(world.field_map.data["review_points"]["central"])
	_aim(world,point)
	world.player.set_auto_enabled(true)
	var frames: Array[float] = []
	var process_ms: Array[float] = []
	var physics_ms: Array[float] = []
	var peak_calls: int = 0
	var active_monsters: int = 0
	var distance: float = 0.0
	var previous: Vector2 = world.player.global_position
	var xp_before: int = world.experience
	var target_seen_frames: int = 0
	var damage_hits_before: int = 0
	for existing_monster: TwilightMonster in world.monsters_root.get_children():
		damage_hits_before += existing_monster.damage_hit_count
	for i: int in range(210):
		var start: int = Time.get_ticks_usec()
		await process_frame
		if i >= 30 and is_instance_valid(world.auto_target) and not world.auto_target.dead:
			target_seen_frames += 1
		if i >= 30:
			frames.append(float(Time.get_ticks_usec()-start)/1000.0)
			process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000.0)
			physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
			peak_calls = maxi(peak_calls,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			distance += previous.distance_to(world.player.global_position)
		if i>=30 and i%30 == 0:
			var awake: int = 0
			for monster: TwilightMonster in world.monsters_root.get_children():
				if monster.is_physics_processing():
					awake += 1
			active_monsters = maxi(active_monsters,awake)
		previous = world.player.global_position
	await _save_view(directory,map_id+"-active-play")
	if active_monsters == 0 or world.active_map_id != map_id:
		push_error("Active-play probe did not remain active in "+map_id)
		failed = true
	world.player.set_auto_enabled(false)
	world.player.clear_click_path()
	var damage_hits_after: int = 0
	for active_monster: TwilightMonster in world.monsters_root.get_children():
		damage_hits_after += active_monster.damage_hit_count
	var player_landed_hits: int = maxi(0, damage_hits_after - damage_hits_before)
	if distance < 1.0:
		print("REGION_AUTO_STATIONARY ", map_id, " target_frames=", target_seen_frames,
			" damage_hits=", player_landed_hits, " active_monsters=", active_monsters)
	frames.sort()
	process_ms.sort()
	physics_ms.sort()
	var report: Dictionary = {"map":map_id, "mode":"active_auto_hunt", "frames":frames.size(),
		"median_ms":frames[frames.size()/2], "p95_ms":frames[int(frames.size()*.95)],
		"process_p95_ms":process_ms[int(process_ms.size()*.95)], "physics_p95_ms":physics_ms[int(physics_ms.size()*.95)],
		"peak_draw_calls":peak_calls, "active_monsters":active_monsters,
		"distance_world_pixels":snappedf(distance,.1), "xp_gained":world.experience-xp_before,
		"auto_target_frames":target_seen_frames, "player_landed_hits":player_landed_hits}
	print("ACTIVE_PLAY ",JSON.stringify(report))
	return report

func _run() -> void:
	var world: TwilightWorld = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	if not CLASS_QA.enter_game(world):
		push_error("Rendered gameplay class confirmation failed")
		quit(1)
		return
	# Class confirmation can leave the character/equipment workspace open.
	# Dismiss it before rendering maps; otherwise most of the 37 screenshots
	# photograph a UI overlay instead of playable scenery.
	var workspace: Control = world.hud.get("workspace") as Control
	if workspace != null and workspace.visible:
		world.hud.call("_close_workspace")
		if workspace.visible:
			push_error("World-region capture is obscured by an open workspace")
			failed = true
	world.save_timer=-10000
	var directory: String = "user://world-regions-review"
	DirAccess.make_dir_recursive_absolute(directory)
	var timing: Array[float] = []
	for id: String in ["oman_01","oman_10","domination_summit","escaros_01","escaros_02","escaros_03","escaros_04","escaros_05","albino_01","albino_02","albino_03","albino_04","faith_01","faith_04"]:
		world.rng.seed = 20261008
		world._set_map(id,false)
		if world.field_renderer.landmark_cache != null:
			print("LANDMARK_CACHE ",id," cells=",world.field_renderer.landmark_textures.size()," size=",world.field_renderer.landmark_cache.size)
		world.field_population.set_process(false)
		for monster: TwilightMonster in world.monsters_root.get_children():
			monster.set_physics_process(false)
		for review: String in ["entrance","central"]:
			var point: Vector2 = Vector2(float(world.field_map.data["review_points"][review][0]),float(world.field_map.data["review_points"][review][1]))
			_aim(world,point)
			for i: int in range(25):
				var start: int = Time.get_ticks_usec()
				await process_frame
				if i>6:
					timing.append(float(Time.get_ticks_usec()-start)/1000.0)
			await _save_view(directory,id+"-"+review)
			if review == "entrance":
				_validate_cache(world.field_renderer)
				if id == "oman_01":
					world.field_renderer.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
					if world.field_renderer.landmark_cache.render_target_update_mode != SubViewport.UPDATE_ONCE:
						push_error("Landmark cache was not scheduled after application resume")
						failed = true
					await RenderingServer.frame_post_draw
					_validate_cache(world.field_renderer)
			print("REGION_CAPTURE ",id," ",review," calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," props=",world.field_renderer.visible_props)
		if DETAIL_KINDS.has(id):
			for record: Dictionary in world.field_map.data["props"]:
				if str(record["kind"]) != str(DETAIL_KINDS[id]):
					continue
				_aim(world,COORD.array_vector(record["position"])+Vector2(0,35))
				for i: int in range(25):
					await process_frame
				await _save_view(directory,id+"-landmark")
				break
	timing.sort()
	print("REGION_RENDER median_ms=",timing[timing.size()/2]," p95_ms=",timing[int(timing.size()*.95)])
	var report: Dictionary = {"adapter":RenderingServer.get_video_adapter_name(), "os":OS.get_name(), "frame_cap":Engine.max_fps,
		"viewport":[1280,720], "static_render":{"median_ms":timing[timing.size()/2],"p95_ms":timing[int(timing.size()*.95)]},
		"note":"Desktop GL probe; not an Android device FPS guarantee.", "active_play":[]}
	for id: String in ["aden_world","oman_10","albino_04","faith_04"]:
		report["active_play"].append(await _benchmark_play(world,id,directory))
	report["captures"] = capture_count
	if capture_count != 37:
		push_error("Expected 37 gameplay captures, got "+str(capture_count))
		failed = true
	var file: FileAccess = FileAccess.open(directory+"/performance.json",FileAccess.WRITE)
	if file == null:
		push_error("Cannot save performance report")
		failed = true
	else:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	print("REGION_CAPTURE_COUNT ",capture_count)
	print("REGION_CAPTURE_DIRECTORY ",ProjectSettings.globalize_path(directory))
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)
