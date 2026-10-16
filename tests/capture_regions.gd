extends SceneTree

const CLASS_QA = preload("res://tests/qa_class_selection.gd")

# Exact GL screenshots and frame timings of real gameplay, not concept art.
const COORD = preload("res://scripts/maps/world_coordinates.gd")
const DETAIL_KINDS: Dictionary = {"domination_summit":"arch", "escaros_05":"obelisk", "albino_01":"crystal", "faith_04":"altar"}
# Oman 1F now uses authored ReferenceGeography, not the removed tomb prop.
# Photograph its current boss landmark anchor; retain all 37 required views.
const DETAIL_ANCHORS: Dictionary = {"oman_01":"boss"}
var capture_count: int = 0
var captured_files: Dictionary = {}
var failed: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _save_view(directory: String, filename: String, world: TwilightWorld, expected_map: String) -> void:
	if captured_files.has(filename):
		push_error("Duplicate gameplay capture: " + filename)
		failed = true
		return
	await RenderingServer.frame_post_draw
	if world.active_map_id != expected_map:
		push_error("Gameplay capture left "+expected_map+": "+filename+" is in "+world.active_map_id)
		failed = true
		return
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
		captured_files[filename] = true
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

func _aden_combat_point(world: TwilightWorld, preferred: Vector2) -> Vector2:
	# The old fixed point can be over 1000 px from every awake actor. A fast
	# renderer finishes its 180-frame sample while AUTO is still travelling.
	# Place this active-combat probe near a real spawned normal monster, with
	# valid terrain/line of sight, then let normal population waking and AI run.
	var candidates: Array[TwilightMonster] = []
	for monster: TwilightMonster in world.monsters_root.get_children():
		if not monster.dead and not monster.is_boss: candidates.append(monster)
	candidates.sort_custom(func(a: TwilightMonster, b: TwilightMonster) -> bool:
		return a.global_position.distance_squared_to(preferred) < b.global_position.distance_squared_to(preferred))
	for monster: TwilightMonster in candidates:
		for direction: int in range(8):
			var point: Vector2 = monster.global_position + Vector2.RIGHT.rotated(float(direction) * PI / 4.) * 180.
			point = world.field_map.cell_to_world(world.field_map.nearest_cell(point))
			if world.field_map.walkable(point) and world.field_map.point_clear(point) and not world.field_map.is_safe(point) and world.field_map.line_clear(point, monster.global_position):
				print("REGION_COMBAT_START ", monster.monster_name, " point=", point, " monster=", monster.global_position)
				return point
	return Vector2.INF

func _active_play_anchor(world: TwilightWorld, map_id: String) -> Vector2:
	if map_id != "aden_world":
		return COORD.array_vector(world.field_map.data["review_points"]["central"])
	# Aden expanded to a 48,000px world, so the old (3550, 4300) benchmark
	# position is no longer within the 2,100px monster wake distance of a
	# hunting region. Choose a real, spawned, non-boss actor from the map's
	# population instead of hard-coding an obsolete combat location.
	var picked: TwilightMonster = null
	var region_id: String = ""
	for slot: Dictionary in world.field_population.slots:
		var raw: Variant = slot.get("monster")
		var candidate: TwilightMonster = raw as TwilightMonster if is_instance_valid(raw) else null
		if not is_instance_valid(candidate) or candidate.dead:
			continue
		if str(slot.region.get("mode", "normal")) != "normal":
			continue
		if picked == null or str(slot.region.get("id", "")) == "forest":
			picked = candidate
			region_id = str(slot.region.get("id", ""))
		if region_id == "forest":
			break
	if picked == null:
		push_error("No spawned normal monster for Aden active-play validation")
		failed = true
		return COORD.array_vector(world.field_map.data["spawn_position"])
	var point: Vector2 = picked.home_position + Vector2(160.0, 0.0)
	if not world.field_map.walkable(point) or not world.field_map.point_clear(point) or world.field_map.is_safe(point):
		point = picked.home_position
	print("REGION_ACTIVE_ANCHOR ", map_id, " region=", region_id, " position=", point, " monster=", picked.home_position)
	return point

func _benchmark_play(world: TwilightWorld, map_id: String, directory: String) -> Dictionary:
	world.rng.seed = 20261008
	world._set_map(map_id,false)
	world.hp = world._effective_max_hp()
	# Static screenshot preparation explicitly disables monster physics and
	# the population controller. Restore both for the real active-play phase;
	# reloading the map alone does not reactivate pooled physics nodes.
	world.field_population.set_process(true)
	for monster: TwilightMonster in world.monsters_root.get_children():
		if not monster.dead: monster.set_physics_process(true)
	# Keep population, AI, physics, combat, HUD and chunk streaming active here.
	# The static screenshot phase above intentionally freezes monster AI.
	var point: Vector2 = _active_play_anchor(world, map_id)
	if map_id == "aden_world":
		point = _aden_combat_point(world, point)
		if not point.is_finite():
			push_error("No real spawned Aden monster has a valid combat probe approach")
			failed = true
			return {"map":map_id, "setup_failed":true}
	_aim(world,point)
	if map_id == "aden_world":
		var wake_distance: float = float(world.field_map.data["streaming"]["monster_sleep_distance"])
		var nearby_spawned: int = 0
		for monster: TwilightMonster in world.monsters_root.get_children():
			if not monster.dead and monster.global_position.distance_to(world.player.global_position) < wake_distance:
				nearby_spawned += 1
		if nearby_spawned == 0:
			push_error("No spawned Aden monster within wake distance at active-play anchor: " + str(world.player.global_position))
			failed = true
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
	await _save_view(directory,map_id+"-active-play",world,map_id)
	if active_monsters == 0 or world.active_map_id != map_id:
		push_error("Active-play probe did not remain active in "+map_id+" current_map="+world.active_map_id+" live_physics="+str(active_monsters)+" population_processing="+str(world.field_population.is_processing()))
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
		"initial_position":str(point), "aden_setup":"existing_spawn_approach" if map_id == "aden_world" else "existing_review_point",
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
		# Review points can overlap travel markers. Keep static shots on this
		# map; active-play probes below restore normal travel via _set_map.
		world.portal_cooldown = 10000
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
			await _save_view(directory,id+"-"+review,world,id)
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
		if DETAIL_ANCHORS.has(id):
			var anchor: Variant = world.field_map.data.get("review_points", {}).get(str(DETAIL_ANCHORS[id]))
			var geography: Node = world.field_renderer.terrain_root.get_node_or_null("Ground/ReferenceGeography")
			if not anchor is Array or anchor.size() != 2 or geography == null:
				push_error("Missing authored landmark anchor or geometry: " + id + "/" + str(DETAIL_ANCHORS[id]))
				failed = true
			else:
				_aim(world,COORD.array_vector(anchor))
				for i: int in range(25): await process_frame
				await _save_view(directory,id+"-landmark",world,id)
		elif DETAIL_KINDS.has(id):
			var landmark_found: bool = false
			for record: Dictionary in world.field_map.data["props"]:
				if str(record["kind"]) != str(DETAIL_KINDS[id]):
					continue
				landmark_found = true
				_aim(world,COORD.array_vector(record["position"])+Vector2(0,35))
				for i: int in range(25):
					await process_frame
				await _save_view(directory,id+"-landmark",world,id)
				break
			if not landmark_found:
				push_error("Missing gameplay landmark in "+id+": "+str(DETAIL_KINDS[id]))
				failed = true
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
