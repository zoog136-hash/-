extends SceneTree
## Candidate replay only. Never adopts the unreviewed art into production.
const MOTION = preload("res://scripts/animation/actor_motion.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> bool:
	if not value:
		push_error(message)
		failures += 1
	return value

func _snapshot(world: Node) -> String:
	return JSON.stringify([world.hp, world.gold, world.inventory, world.equipped_items,
		world.player.position, world.player.get_node("CollisionShape2D").transform,
		world.player.collision_layer, world.player.collision_mask])

func _save_snapshot() -> String:
	var result: Array = []
	for path: String in ["user://twilight_v20_save.json", "user://twilight_ui_settings.cfg"]:
		result.append(FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT")
	return JSON.stringify(result)

func _add_clip(fixture: SpriteFrames, key: StringName, atlas: ImageTexture, poses: Array,
		looped: bool, fps: float) -> void:
	fixture.add_animation(key)
	fixture.set_animation_loop(key, looped)
	fixture.set_animation_speed(key, fps)
	for pose: Dictionary in poses:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(pose.region[0], pose.region[1], pose.region[2], pose.region[3])
		texture.margin = Rect2(pose.margin[0], pose.margin[1], pose.margin[2], pose.margin[3])
		texture.filter_clip = true
		fixture.add_frame(key, texture)

func _run() -> void:
	if not check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"), "Isolated saves required"):
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PR122_W_RUN_GEOMETRY")))
	if not check(data.actor == "transform:413" and not data.production_connected and data.source_visual_status == "HOLD_NOT_REVIEWED", "Explicit unapproved candidate only"):
		quit(1)
		return
	var source_path: String = str(data.source_texture_path)
	if not check(FileAccess.get_sha256(source_path) == data.source_texture_sha256, "Exact new six-pose W source SHA required"):
		quit(1)
		return
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var original: Dictionary = register.actors["transform:413"]
	var playback_regex := RegEx.new()
	playback_regex.compile('"loop": (true|false),\\s*"name": &"(idle_4|run_4)",\\s*"speed": ([0-9.]+)')
	var playback: Dictionary = {}
	for row: RegExMatch in playback_regex.search_all(FileAccess.get_file_as_string(str(original.frames))):
		playback[row.get_string(2)] = {"loop": row.get_string(1) == "true", "speed": row.get_string(3).to_float()}
	if not check(playback.has("idle_4") and playback.has("run_4") and bool(playback["run_4"].loop), "Retain production W clocks"):
		quit(1)
		return
	var fixture := SpriteFrames.new()
	fixture.remove_animation("default")
	fixture.set_meta("twilight_native_locomotion_staging", true)
	# Match the retained staged frame canvas metadata; no visual scale override.
	fixture.set_meta("twilight_canvas_size", Vector2(1024, 1024))
	for track: Dictionary in original.tracks:
		if str(track.animation) != "idle_4": continue
		var idle_atlas := ImageTexture.create_from_image(Image.load_from_file("res://" + str(track.texture)))
		_add_clip(fixture, &"idle_4", idle_atlas, track.geometry.frames, bool(playback["idle_4"].loop), float(playback["idle_4"].speed))
	var atlas := ImageTexture.create_from_image(Image.load_from_file(source_path))
	_add_clip(fixture, &"run_4", atlas, data.frames, true, float(playback["run_4"].speed))
	check(fixture.get_frame_count("run_4") == 6, "Six newly authored poses required")
	for index: int in range(6):
		check(fixture.get_frame_texture("run_4", index).get_size() == Vector2(2560, 2560), "Fixed physical canvas retained")
	fixture.take_over_path("res://tests/runtime_only_413_W_own_native_run_candidate.tres")
	var profile: Resource = load(original.native_profile).duplicate()
	profile.profile_id = "runtime-only-413-W-own-native-six-run-candidate"
	profile.frames_path = fixture.resource_path
	var before_saves := _save_snapshot()
	var world: Node = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	world.player.set_physics_process(false)
	var before := _snapshot(world)
	world.player.set_transform_visual("res://assets/catalog/e82707989c7744b45919684b.png", 1.0, profile)
	var motion: MOTION = world.player.motion
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	motion.face(Vector2.LEFT)
	var reached: Dictionary = {}
	var previous := -1
	var wraps := 0
	for step: int in range(360):
		motion.advance(1.0/240.0, Vector2.LEFT*240.0)
		motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
		check(sprite.animation == &"run_4", "W input must select the actual new W run")
		if sprite.animation != &"run_4": continue
		reached[sprite.frame] = true
		if previous>sprite.frame: wraps += 1
		previous = sprite.frame
		var actual := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame) as AtlasTexture
		check(actual != null and actual.atlas == atlas, "Candidate must never alias the legacy W source")
	check(reached.size() == 6 and wraps>=2, "Visit every new pose across repeated cycles")
	motion.advance(0.5,Vector2.ZERO)
	motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
	check(sprite.animation == &"idle_4", "Stopping returns to the preserved W idle")
	check(_snapshot(world) == before and _save_snapshot() == before_saves, "Visual playback must preserve gameplay and saves")
	var result := {"actor":"transform:413", "direction":"W", "role":"run",
		"runtime_status":"PASS" if failures == 0 else "FAIL", "failures":failures,
		"poses_reached":reached.size(), "cycle_wraps":wraps,
		"source_texture_sha256":data.source_texture_sha256,
		"used_actual_new_candidate_atlas":true, "returned_to_preserved_W_idle":sprite.animation == &"idle_4",
		"resource_fps":float(playback["run_4"].speed), "fixture_override":true,
		"gameplay_and_save_unchanged":_snapshot(world) == before and _save_snapshot() == before_saves,
		"source_visual_status":"HOLD_NOT_REVIEWED", "world_foot_contact":"NOT_RUN_HOLD",
		"production_connected":false, "actor_approvals_added":0}
	if not OS.get_environment("PR122_W_CONTACT_POINTS").is_empty():
		result["world_foot_contact_probe"] = _contact_probe(world, motion, sprite)
	result["runtime_status"] = "PASS" if failures == 0 else "FAIL"
	result["failures"] = failures
	var output := FileAccess.open(OS.get_environment("PR122_RUNTIME_PROOF_PATH"),FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t")+"\n")
	output.close()
	print("MYTHIC413_W_OWN_NATIVE_RUN_CANDIDATE poses="+str(reached.size())+" wraps="+str(wraps)+" failures="+str(failures)+" approvals_added=0")
	quit(0 if failures == 0 else 1)

func _contact_probe(world: Node, motion: MOTION, sprite: AnimatedSprite2D) -> Dictionary:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PR122_W_CONTACT_POINTS")))
	var original_position: Vector2 = world.player.position
	var samples: Dictionary = {}
	motion.gait = 0.0
	var step_dt := 1.0 / 1250.0
	for step: int in range(650):
		if step > 0: world.player.position += Vector2.LEFT * 210.0 * step_dt
		motion.advance(step_dt if step > 0 else 0.0, Vector2.LEFT * 210.0)
		motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
		check(sprite.animation == &"run_4", "Contact probe must use actual candidate W run")
		var key := str(sprite.frame)
		if meta.points.has(key) and not samples.has(key):
			var point: Array = meta.points[key].local
			var at := sprite.to_global(Vector2(float(point[0]), float(point[1])))
			samples[key] = {"world": [at.x,at.y], "time": step * step_dt,
				"sprite_scale": [sprite.scale.x,sprite.scale.y], "rotation":sprite.rotation,
				"native_original_texel":meta.points[key].native_original_texel}
	var pairs: Array = []
	for pair: Dictionary in meta.pairs:
		var a: Dictionary = samples[str(int(pair.phases[0]))]
		var b: Dictionary = samples[str(int(pair.phases[1]))]
		pairs.append({"side":pair.side, "phases":pair.phases,
			"world_dx": float(b.world[0])-float(a.world[0]),
			"world_dy": float(b.world[1])-float(a.world[1]),
			"elapsed":float(b.time)-float(a.time)})
	var bound := OS.get_environment("PR122_W_CONTACT_MAX_SLIP")
	if not bound.is_empty():
		for pair: Dictionary in pairs:
			check(absf(float(pair.world_dx)) <= bound.to_float() and absf(float(pair.world_dy)) <= bound.to_float(), "Original ground texel must remain within the declared measured slip bound")
	world.player.position = original_position
	motion.advance(0.5,Vector2.ZERO)
	motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
	return {"scope":meta.scope, "samples":samples, "contact_pairs":pairs,
		"status":"MEASURED_ONLY_NOT_VISUAL_APPROVAL", "world_translation_speed":210.0,
		"frame_rendering_performed":false, "collision_physics_tested":false}
