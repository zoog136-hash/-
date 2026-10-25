from pathlib import Path
L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01');s=(L/'new_413_S_death_actual_main_player_candidate_raw_dependencies_test.gd').read_text();s=s.replace('var failures := 0','var failures := 0\nvar candidate_atlases: Dictionary = {}');s=s.replace('var source_path: String = "res://" + str(candidate.source_texture_repo_path)','var source_path: String = str(candidate.source_texture_path)');s=s.replace('(death_[0-7])','(death_[0-7]|idle_[24]|run_2|attack_2)');s=s.replace('if track.role != "death": continue','if track.role != "death" and str(track.animation) not in ["idle_2", "idle_4"]: continue');s=s.replace('\t\tpreserved_death_views += 1','\t\tif track.role == "death": preserved_death_views += 1')
helper='''func _add_candidate_clip(data: Dictionary, key: StringName, looped: bool, fps: float) -> void:
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

'''
s=s.replace('func _run() -> void:',helper+'func _run() -> void:');needle='\tfixture.take_over_path("res://tests/runtime_only_413_new_S_candidate_fixture.tres")';assert needle in s
setup='''	candidate_atlases["death_2"] = atlas
	var w_attack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PR122_W_ATTACK_GEOMETRY")))
	var s_run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("PR122_S_RUN_GEOMETRY")))
	check(playback.has("attack_2") and playback.has("run_2"), "Use the existing production action clocks")
	_add_candidate_clip(w_attack, &"attack_4", false, float(playback["attack_2"].speed))
	_add_candidate_clip(s_run, &"run_2", true, float(playback["run_2"].speed))
	fixture.take_over_path("res://tests/runtime_only_413_three_new_actual_source_candidates.tres")'''
s=s.replace(needle,setup);s=s.replace('runtime-only-413-new-S-candidate-test','runtime-only-413-three-actual-source-candidates-test');s=s.replace('\t\t\tseen[sprite.frame] = true','\t\t\tseen[sprite.frame] = true\n\t\t\tif expected == &"death_2":\n\t\t\t\tvar actual_texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture\n\t\t\t\tcheck(actual_texture != null and actual_texture.atlas == atlas, "Play the actual new S PNG, never a legacy death alias")')
extra='''	# Fresh actual Main/Player for the new W attack; all five real death inputs remain in the same fixture.
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
'''
needle='\tvar result := {';assert s.count(needle)==1;s=s.replace(needle,extra+needle);s=s.replace('"status": "PASS" if failures == 0 else "FAIL",','"runtime_status": "PASS" if failures == 0 else "FAIL", "scope": "ACTUAL_MAIN_PLAYER_CANDIDATE_VISUAL_REPLAY_ONLY_SOURCE_QUALITY_HOLD", "W_attack": attack_result, "S_run": run_result, "W_attack_source_sha256": w_attack.source_texture_sha256, "S_run_source_sha256": s_run.source_texture_sha256,');s=s.replace('MYTHIC413_NEW_S_REAL_MAIN_DEATH_8_INPUTS_RESULT existing_death_views_preserved=5 new_S_candidates=1 fixture_override=1 actor_approvals=0 failures=','MYTHIC413_THREE_ACTUAL_SOURCE_MAIN_PLAYER_RESULT death_inputs=8 existing_death_views=5 attack_poses=6 run_poses=6 fixture_override=1 actor_approvals=0 failures=')
out=L/'three_413_actual_source_candidates_main_player_test.gd'
with out.open('x') as f:f.write(s)
print('three_actual_source_candidates_main_player_test_prepared')
