extends SceneTree
## Actual newly authored S six plus all five existing 413 death views.
## Runtime-only candidate: no production selection or source quality approval.
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
var atlas: ImageTexture
var fixture: SpriteFrames
var failures := 0
var candidate_atlases: Dictionary = {}

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

func _add_candidate_clip(data: Dictionary, key: StringName, looped: bool, fps: float) -> void:
	check(data.actor == "transform:413" and data.production_connected == false, "Explicit unapproved 413 candidate only")
	var source_path: String = str(data.source_texture_path)
	if not check(FileAccess.get_sha256(source_path) == data.source_texture_sha256, "Exact new candidate PNG SHA required"):
		return
	var image := Image.load_from_file(source_path)
	if not check(not image.is_empty(), "Actual candidate PNG must load"):
		return
	var source_atlas := ImageTexture.create_from_image(image)
	candidate_atlases[str(key)] = source_atlas
	fixture.add_animation(key)
	fixture.set_animation_loop(key, looped)
	fixture.set_animation_speed(key, fps)
	for pose: Dictionary in data.frames:
		var texture := AtlasTexture.new()
		texture.atlas = source_atlas
		texture.region = Rect2(pose.region[0], pose.region[1], pose.region[2], pose.region[3])
		texture.margin = Rect2(pose.margin[0], pose.margin[1], pose.margin[2], pose.margin[3])
		texture.filter_clip = true
		check(texture.get_size() == Vector2(2560, 2560), "Candidate fixed physical C must be retained")
		fixture.add_frame(key, texture)

func _run() -> void:
	if not check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"), "Use isolated test saves"):
		quit(1)
		return
	var geometry_path := OS.get_environment("PR122_CANDIDATE_GEOMETRY")
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	if not check(candidate.actor == "transform:413" and candidate.production_connected == false, "Explicit unapproved 413 candidate fixture only"):
		quit(1)
		return
	var source_path: String = str(candidate.source_texture_path)
	if not check(FileAccess.get_sha256(source_path) == candidate.source_texture_sha256, "Exact newly authored S atlas required"):
		quit(1)
		return
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var original: Dictionary = register.actors["transform:413"]
	fixture = SpriteFrames.new()
	fixture.remove_animation("default")
	var preserved_death_views := 0
	var playback_regex := RegEx.new()
	playback_regex.compile('"loop": (true|false),\\s*"name": &"(death_[0-7]|idle_[24]|run_2|attack_2)",\\s*"speed": ([0-9.]+)')
	var playback: Dictionary = {}
	for match_row: RegExMatch in playback_regex.search_all(FileAccess.get_file_as_string(str(original.frames))):
		playback[match_row.get_string(2)] = {"loop": match_row.get_string(1) == "true", "speed": match_row.get_string(3).to_float()}
	for track: Dictionary in original.tracks:
		if track.role != "death" and str(track.animation) not in ["idle_2", "idle_4"]: continue
		var key := StringName(str(track.animation))
		if not check(playback.has(str(key)), "Exact current death resource flags must be readable"):
			quit(1)
			return
		var existing_atlas := ImageTexture.create_from_image(Image.load_from_file("res://" + str(track.texture)))
		fixture.add_animation(key)
		fixture.set_animation_loop(key, bool(playback[str(key)].loop))
		fixture.set_animation_speed(key, float(playback[str(key)].speed))
		for pose: Dictionary in track.geometry.frames:
			var kept := AtlasTexture.new()
			kept.atlas = existing_atlas
			kept.region = Rect2(pose.region[0], pose.region[1], pose.region[2], pose.region[3])
			kept.margin = Rect2(pose.margin[0], pose.margin[1], pose.margin[2], pose.margin[3])
			kept.filter_clip = true
			fixture.add_frame(key, kept)
		if track.role == "death": preserved_death_views += 1
	check(preserved_death_views == 5 and not fixture.has_animation("death_2"), "Preserve all five current real death views before adding candidate S")
	atlas = ImageTexture.create_from_image(Image.load_from_file(source_path))
	fixture.add_animation("death_2")
	fixture.set_animation_loop("death_2", false)
	fixture.set_animation_speed("death_2", 6.0 / 0.65)
	fixture.set_meta("twilight_native_locomotion_staging", true)
	for pose: Dictionary in candidate.frames:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(pose.region[0], pose.region[1], pose.region[2], pose.region[3])
		texture.margin = Rect2(pose.margin[0], pose.margin[1], pose.margin[2], pose.margin[3])
		texture.filter_clip = true
		check(texture.get_size() == Vector2(2560, 2560), "Retain the candidate fixed physical C")
		fixture.add_frame("death_2", texture)
	candidate_atlases["death_2"] = atlas
	var w_attack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PR122_W_ATTACK_GEOMETRY")))
	var s_run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PR122_S_RUN_GEOMETRY")))
	check(playback.has("attack_2") and playback.has("run_2"), "Use the existing production action clocks")
	_add_candidate_clip(w_attack, &"attack_4", false, float(playback["attack_2"].speed))
	_add_candidate_clip(s_run, &"run_2", true, float(playback["run_2"].speed))
	fixture.take_over_path("res://tests/runtime_only_413_three_new_actual_source_candidates.tres")
	var profile: Resource = load(original.native_profile).duplicate()
	profile.profile_id = "runtime-only-413-three-actual-source-candidates-test"
	profile.frames_path = fixture.resource_path
	var direction_results: Array = []
	var before_saves := _save_snapshot()
	for direction: int in range(8):
		var requested := StringName("death_" + str(direction))
		var expected := requested if fixture.has_animation(requested) else &"death_2"
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
		motion.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
		motion.die()
		var seen: Dictionary = {}
		for step: int in range(121):
			motion.advance(1.0 / 120.0, Vector2(200, 100))
			motion.apply(sprite, Vector2.ONE)
			check(sprite.animation == expected, "Use an existing requested death view, otherwise the real new S candidate")
			seen[sprite.frame] = true
			if expected == &"death_2":
				var actual_texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
				check(actual_texture != null and actual_texture.atlas == atlas, "Play the actual new S PNG, never a legacy death alias")
		check(seen.size() == 6, "One-shot death must visit all six source poses")
		check(sprite.frame == 5 and not sprite.is_playing(), "Death must stop on terminal frame")
		var held_texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		motion.face(Vector2.RIGHT.rotated((direction + 3) * PI / 4.0))
		check(motion.begin_attack(0.4, Vector2.LEFT) == -1, "Dead actor cannot attack")
		motion.advance(4.0, Vector2(200, 100))
		motion.apply(sprite, Vector2.ONE)
		check(motion.dead and motion.state == "corpse", "No automatic standing/movement recovery")
		check(motion.facing8 == direction and sprite.animation == expected and sprite.frame == 5, "Terminal death is irreversible")
		check(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) == held_texture, "Hold the actual terminal texture")
		check(is_equal_approx(sprite.modulate.a, 1.0), "Authored terminal pose stays visible until normal entity cleanup")
		check(_snapshot(world) == before and _save_snapshot() == before_saves, "Visual death must not alter gameplay/save state")
		direction_results.append({"input_direction": direction, "played": str(expected), "poses_reached": seen.size(), "held_frame": sprite.frame, "visible_terminal": is_equal_approx(sprite.modulate.a, 1.0), "used_new_S_candidate": expected == &"death_2"})
		world.queue_free()
		await process_frame
	# Fresh actual Main/Player for the new W attack; all five real death inputs remain in the same fixture.
	var attack_world: Node = load("res://Main.tscn").instantiate()
	attack_world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(attack_world)
	await process_frame
	attack_world.save_timer = -10000.0
	attack_world.player.set_physics_process(false)
	var attack_before := _snapshot(attack_world)
	attack_world.player.set_transform_visual("res://assets/catalog/e82707989c7744b45919684b.png", 1.0, profile)
	var attack_motion: MOTION = attack_world.player.motion
	var attack_sprite: AnimatedSprite2D = attack_world.player.transform_sprite
	attack_motion.face(Vector2.LEFT)
	attack_motion.apply(attack_sprite, Vector2.ONE)
	var attack_seconds := 6.0 / float(playback["attack_2"].speed)
	check(attack_motion.begin_attack(attack_seconds, Vector2.LEFT) >= 0, "Actual alive Player motion must accept the W attack")
	var attack_seen: Dictionary = {}
	for step: int in range(int(ceil((attack_seconds + 0.25) * 240.0))):
		attack_motion.advance(1.0 / 240.0, Vector2.ZERO)
		attack_motion.apply(attack_sprite, Vector2.ONE)
		if attack_sprite.animation == &"attack_4":
			attack_seen[attack_sprite.frame] = true
			var actual := attack_sprite.sprite_frames.get_frame_texture(attack_sprite.animation, attack_sprite.frame) as AtlasTexture
			check(actual != null and actual.atlas == candidate_atlases["attack_4"], "Play the actual new W attack, never an old action alias")
	check(attack_seen.size() == 6 and attack_sprite.animation == &"idle_4", "W attack visits all six real poses once and returns to existing W idle")
	check(not fixture.get_animation_loop("attack_4"), "New attack resource remains one-shot")
	check(_snapshot(attack_world) == attack_before and _save_snapshot() == before_saves, "W candidate visual playback preserves gameplay/save state")
	var attack_result := {"poses_reached": attack_seen.size(), "returned_to_existing_W_idle": attack_sprite.animation == &"idle_4", "used_actual_new_candidate_atlas": true, "resource_seconds": attack_seconds, "authored_source_seconds": w_attack.resource_role_seconds, "combat_event_validation": "NOT_PERFORMED_VISUAL_ONLY"}
	attack_world.queue_free()
	await process_frame
	# Fresh actual Main/Player for the repaired S run; no new WALK is introduced.
	var run_world: Node = load("res://Main.tscn").instantiate()
	run_world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(run_world)
	await process_frame
	run_world.save_timer = -10000.0
	run_world.player.set_physics_process(false)
	var run_before := _snapshot(run_world)
	run_world.player.set_transform_visual("res://assets/catalog/e82707989c7744b45919684b.png", 1.0, profile)
	var run_motion: MOTION = run_world.player.motion
	var run_sprite: AnimatedSprite2D = run_world.player.transform_sprite
	run_motion.face(Vector2.DOWN)
	var run_seen: Dictionary = {}
	var previous := -1
	var wraps := 0
	for step: int in range(360):
		run_motion.advance(1.0 / 240.0, Vector2.DOWN * 240.0)
		run_motion.apply(run_sprite, Vector2.ONE)
		check(run_sprite.animation == &"run_2", "S running input must play the real repaired S run")
		if run_sprite.animation == &"run_2":
			run_seen[run_sprite.frame] = true
			if previous > run_sprite.frame: wraps += 1
			previous = run_sprite.frame
			var actual := run_sprite.sprite_frames.get_frame_texture(run_sprite.animation, run_sprite.frame) as AtlasTexture
			check(actual != null and actual.atlas == candidate_atlases["run_2"], "Play the actual new S run rather than the held legacy source")
	check(run_seen.size() == 6 and wraps > 0 and fixture.get_animation_loop("run_2"), "S run must visit and repeat all six actual source poses")
	run_motion.advance(0.5, Vector2.ZERO)
	run_motion.apply(run_sprite, Vector2.ONE)
	check(run_sprite.animation == &"idle_2", "Stopping returns to the preserved S idle")
	check(_snapshot(run_world) == run_before and _save_snapshot() == before_saves, "S candidate visual playback preserves gameplay/save state")
	var run_result := {"poses_reached": run_seen.size(), "wraps": wraps, "returned_to_existing_S_idle": run_sprite.animation == &"idle_2", "used_actual_new_candidate_atlas": true, "resource_fps": float(playback["run_2"].speed), "foot_world_contact_validation": "HOLD_NOT_PERFORMED_VISUAL_REPLAY_ONLY"}
	run_world.queue_free()
	await process_frame
	var result := {"runtime_status": "PASS" if failures == 0 else "FAIL", "scope": "ACTUAL_MAIN_PLAYER_CANDIDATE_VISUAL_REPLAY_ONLY_SOURCE_QUALITY_HOLD", "W_attack": attack_result, "S_run": run_result, "W_attack_source_sha256": w_attack.source_texture_sha256, "S_run_source_sha256": s_run.source_texture_sha256, "actor": "transform:413", "existing_death_views_preserved": preserved_death_views, "existing_deaths_reconstructed_from_current_selected_textures_and_geometry": true, "fixture_subset": "five_existing_deaths_and_two_existing_idles_plus_three_new_actual_candidates", "new_S_source_atlas_sha256": candidate.source_texture_sha256, "directions": direction_results, "failures": failures, "fixture_override": true, "production_connected": false, "source_visual_status": "HOLD_NOT_REVIEWED", "actor_approvals_added": 0, "gameplay_and_save_unchanged": _save_snapshot() == before_saves}
	var output := FileAccess.open(OS.get_environment("PR122_RUNTIME_PROOF_PATH"), FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t") + "\n")
	output.close()
	print("MYTHIC413_THREE_ACTUAL_SOURCE_MAIN_PLAYER_RESULT death_inputs=8 existing_death_views=5 attack_poses=6 run_poses=6 fixture_override=1 actor_approvals=0 failures=" + str(failures))
	quit(0 if failures == 0 else 1)
