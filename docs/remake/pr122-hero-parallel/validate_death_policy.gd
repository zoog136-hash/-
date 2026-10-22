extends SceneTree
## Real Main/Player death lifecycle, including the new single-S source aliases.
const CLASS_QA = preload("res://tests/qa_class_selection.gd")
const POLICY = preload("res://docs/remake/pr122-hero-parallel/shared_death_policy.gd")
const EVIDENCE_ROOT := "res://docs/remake/pr122-hero-parallel/evidence/death-south-20261022/"
const ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
var checks := 0
var failed := false
var evidence := EVIDENCE_ROOT

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("HERO_DEATH_POLICY_FAIL " + message)

func _signature(frames: SpriteFrames, track: String) -> String:
	var data: Array = [frames.get_animation_loop(track), frames.get_animation_speed(track)]
	for phase: int in range(frames.get_frame_count(track)):
		var texture: AtlasTexture = frames.get_frame_texture(track, phase)
		data.append([texture.atlas.resource_path, texture.region, texture.margin, frames.get_frame_duration(track, phase)])
	return JSON.stringify(data)

func _fingerprint(world: Node) -> String:
	return JSON.stringify([world.hp, world.gold, world.inventory, world.equipped_items, world.equipped_catalog,
		world._normal_attack_interval(), world.player.move_speed, world.player.attack_speed_multiplier,
		world.player.equipment_move_speed_multiplier, world.player.get_node("CollisionShape2D").transform])

func _input(aim: Vector2) -> void:
	for action: String in ACTIONS: Input.action_release(action)
	if aim.x < -.1: Input.action_press("move_left")
	if aim.x > .1: Input.action_press("move_right")
	if aim.y < -.1: Input.action_press("move_up")
	if aim.y > .1: Input.action_press("move_down")

func _run() -> void:
	_check(Engine.get_version_info().string.begins_with("4.7.2"), "engine")
	_check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"), "isolated saves")
	var suffix := OS.get_environment("TWILIGHT_HERO_EVIDENCE_SUFFIX")
	_check(suffix.is_empty() or suffix.is_valid_identifier(), "safe evidence suffix")
	if not suffix.is_empty():
		evidence = "res://docs/remake/pr122-hero-parallel/evidence/" + suffix + "/"
	DirAccess.make_dir_recursive_absolute(evidence)
	var ids := OS.get_environment("TWILIGHT_HERO_DEATH_TEST_IDS").split(",", false)
	if ids.is_empty(): ids = PackedStringArray(["179", "182", "231", "260", "11", "7", "197", "276"])
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	_check(staging.animation_policy.new_death_authored_directions == ["S"], "new S-only authoring policy")
	var south: SpriteFrames = load("res://assets/actors/eight_direction/hero_parallel/maid_anna_276/r001/DeathSouth.tres")
	_check(south.get_animation_names().size() == 1 and south.has_animation("death_2"), "one real S source clip")
	_check(south.get_frame_count("death_2") == 6 and not south.get_animation_loop("death_2"), "six unique S source frames, no loop")
	var world: Node = load("res://Main.tscn").instantiate()
	root.add_child(world)
	_check(CLASS_QA.enter_game(world), "actual Main gameplay entry")
	world.hud._close_workspace()
	await process_frame
	# Keep collision objects in the real physics space; stop callbacks only.
	world.set_process(false)
	world.set_physics_process(false)
	for child: Node in world.find_children("*", "", true, false):
		child.set_process(false)
		child.set_physics_process(false)
	world.save_timer = -10000.0
	var player: Node = world.player
	player.camera.make_current()
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	world.field_renderer.refresh_visible()
	var start: Vector2 = player.position
	var strikes: Array[int] = []
	player.attack_strike.connect(func(sequence: int) -> void: strikes.append(sequence))
	var results: Array = []
	var snapshots := Image.create(960, 1280, false, Image.FORMAT_RGBA8)
	var captured := 0
	for sid: String in ids:
		var key := "transform:" + sid
		var entry: Dictionary = staging.actors[key]
		var profile: Resource = load(entry.native_profile)
		var frames: SpriteFrames = load(entry.frames)
		if entry.has("death_hold_review_source"):
			_check(bool(frames.get_meta("pr122_hero_hold_final_death_frame", false)), "historical review wrapper provenance retained")
		else:
			_check(bool(frames.get_meta("hero_parallel_candidate", false)), "new exact-target candidate provenance retained")
		var shared := int(frames.get_meta("hero_shared_death_source_direction", -1)) == 2
		_check(shared == (sid == "276"), "only newly authored maid source uses S aliases")
		if shared:
			_check(_signature(frames, "death_2") == _signature(south, "death_2"), "canonical S source preserved")
		else:
			var copy: SpriteFrames = frames.duplicate(true)
			var before := _signature(copy, "death_0")
			var result := POLICY.install_new_south_death(copy, south, "unused")
			_check(result.status == "PRESERVED_EXISTING" and _signature(copy, "death_0") == before, "existing multi-direction library cannot be replaced")
		var reference := str(entry.reference)
		var cases: Array = []
		for direction: int in range(8):
			player.motion.dead = false # Explicit reset between independent cases.
			player.position = start
			player.velocity = Vector2.ZERO
			player.set_transform_visual(reference, 1.0, profile)
			_check(player.transform_active and player.transform_sprite.sprite_frames.resource_path == profile.frames_path, "real imported candidate, no fallback")
			var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
			_input(aim)
			for tick: int in range(2):
				await physics_frame
				player._physics_process(1.0 / 60.0)
			for action: String in ACTIONS: Input.action_release(action)
			_check(player.motion.facing8 == direction, "real eight-direction keyboard heading")
			player.position = start
			player.velocity = Vector2.ZERO
			var fingerprint := _fingerprint(world)
			var strike_count := strikes.size()
			player.start_combat_attack(player.global_position + aim, .9, profile.motion_style)
			player.motion.advance(1.0 / 240.0, Vector2.ZERO)
			player.motion.die()
			var sprite: AnimatedSprite2D = player.transform_sprite
			var track := "death_" + str(direction)
			var count := frames.get_frame_count(track)
			_check(count >= 2 and not frames.get_animation_loop(track), "nonlooping death clip")
			if shared:
				_check(_signature(frames, track) == _signature(frames, "death_2"), "every input uses the same S source")
				for phase: int in range(count):
					_check(frames.get_frame_texture(track, phase) == frames.get_frame_texture("death_2", phase), "shared texture references, no duplicated direction art")
			var seen: Dictionary = {}
			var last := -1
			var resets := 0
			for tick: int in range(720):
				player.motion.advance(1.0 / 240.0, Vector2.ZERO)
				if tick % 37 == 0:
					var clock: float = player.motion.death_clock
					player.motion.die()
					_check(is_equal_approx(player.motion.death_clock, clock), "repeat death request cannot restart")
				player.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
				_check(str(sprite.animation) == track, "death stays selected")
				if sprite.frame < last: resets += 1
				var first_phase := not seen.has(sprite.frame)
				seen[sprite.frame] = true
				last = sprite.frame
				if shared and first_phase and DisplayServer.get_name() != "headless":
					await process_frame
					await RenderingServer.frame_post_draw
					var image := root.get_texture().get_image()
					var center: Vector2 = sprite.get_global_transform_with_canvas().origin
					_check(root.get_visible_rect().has_point(center), "shared death visible in real Main")
					snapshots.blit_rect(image, Rect2i(Vector2i(center) - Vector2i(80, 80), Vector2i(160, 160)), Vector2i(sprite.frame * 160, direction * 160))
					captured += 1
			_check(seen.size() == count and resets == 0 and last == count - 1, "one forward playback, no looping")
			for tick: int in range(1800):
				player.motion.advance(1.0 / 60.0, aim * profile.reference_speed)
				if tick % 60 == 0: player.motion.die()
				player.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
				_check(player.motion.dead and str(sprite.animation) == track and sprite.frame == count - 1, "30-second final-frame hold, no automatic standing")
			_check(sprite.is_visible_in_tree() and sprite.modulate.a > 0.0, "corpse remains visible")
			_check(strikes.size() == strike_count, "death cancels pending attack without ghost strike")
			_check(_fingerprint(world) == fingerprint, "collision transform, speed, battle stats and inventory unchanged")
			cases.append({"input_direction": direction, "runtime_track": track, "unique_phases_played": seen.size(), "source_passes": 1, "frame_resets": resets, "held_final_frame": last, "hold_seconds": 30, "shared_s_source": shared})
		# Upstream now holds every real authored death, including original art.
		var control: Resource = profile.duplicate(true)
		var original: Dictionary = entry.get("death_hold_review_source", {})
		if original.is_empty():
			var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(entry.rig))
			original = {"frames": proof.source}
		control.frames_path = str(original.frames)
		player.motion.dead = false
		player.set_transform_visual(reference, 1.0, control)
		player.motion.die()
		player.motion.advance(33.0, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale", Vector2.ONE))
		_check(player.transform_sprite.modulate.a > 0.0, "upstream also holds original authored death art")
		results.append({"id": key, "frames_sha256": FileAccess.get_sha256(entry.frames), "native_profile_sha256": FileAccess.get_sha256(entry.native_profile), "shared_s_only_new_art": shared, "original_authored_death_hold_control": "PASS", "cases": cases})
	# Exercise the upstream fallback with the ONE-TRACK S resource itself,
	# independently of the full candidate's eight retained resource aliases.
	var direct_cases: Array = []
	for direction: int in range(8):
		var direct: Resource = load(staging.actors["transform:276"].native_profile).duplicate(true)
		direct.frames_path = "res://assets/actors/eight_direction/hero_parallel/maid_anna_276/r001/DeathSouth.tres"
		player.motion.dead = false
		player.set_transform_visual(staging.actors["transform:276"].reference, 1.0, direct)
		player.motion.advance(.1, Vector2.ZERO)
		player.motion.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
		player.motion.die()
		var seen: Dictionary = {}
		var last := -1
		for tick: int in range(720):
			player.motion.advance(1.0 / 240.0, Vector2.ZERO)
			player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale", Vector2.ONE))
			_check(str(player.transform_sprite.animation) == "death_2" and player.transform_sprite.frame >= last, "single-track S fallback for every heading")
			last = player.transform_sprite.frame
			seen[last] = true
		_check(seen.size() == 6 and last == 5, "single S source played once to terminal pose")
		var facing: int = player.motion.facing8
		player.motion.face(Vector2.LEFT)
		_check(player.motion.facing8 == facing, "upstream freezes dead facing")
		player.motion.advance(30.0, Vector2.ZERO)
		player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale", Vector2.ONE))
		_check(player.transform_sprite.frame == 5 and player.transform_sprite.modulate.a > 0.0, "single S terminal pose remains visible")
		direct_cases.append({"input_direction": direction, "runtime_track": "death_2", "unique_phases": seen.size(), "last_frame": last})
	var legacy: Resource = load(staging.actors["transform:276"].native_profile).duplicate(true)
	legacy.profile_id = "" # Avoid the transform manifest substituting authored death art.
	legacy.frames_path = ""
	legacy.layout = "still"
	legacy.animation_names.clear()
	player.motion.dead = false
	player.set_transform_visual(staging.actors["transform:276"].reference, 1.0, legacy)
	player.motion.advance(.1, Vector2.ZERO)
	player.motion.die()
	player.motion.advance(33.0, Vector2.ZERO)
	player.motion.apply(player.transform_sprite, player.transform_sprite.get_meta("base_scale", Vector2.ONE))
	_check(is_zero_approx(player.transform_sprite.modulate.a), "non-authored portrait fallback retains fade")
	if DisplayServer.get_name() != "headless":
		_check(captured == (48 if ids.has("276") else 0), "all six S frames rendered for eight real input headings")
		var prefix := "overlay-" if OS.get_environment("TWILIGHT_HERO_RUNTIME_REVIEW") == "1" else "feature-"
		_check(snapshots.save_webp(evidence + prefix + "Main-shared-S-death-eight-inputs.webp", false) == OK, "lossless Main file proof")
	var review := OS.get_environment("TWILIGHT_HERO_RUNTIME_REVIEW") == "1"
	var report := {"schema": "hero-death-policy-main-v2", "engine": Engine.get_version_info().string, "display": DisplayServer.get_name(), "status": "FAIL" if failed else "TECHNICAL_PASS_QUALITY_HOLD", "checks": checks, "actors": results, "input_cases": ids.size() * 8, "single_track_south_input_cases": direct_cases, "non_authored_fade_control": "PASS", "main_rendered_phase_references": captured, "new_death_unique_source_poses": 6, "new_death_source_directions": 1, "new_final_approvals": 0, "default_game_connections": 0, "runtime_scope": "ISOLATED_REVIEW_OVERLAY" if review else "FEATURE_BRANCH_UPSTREAM_ALIGNED_RUNTIME", "runtime_source_sha256": FileAccess.get_sha256("res://scripts/animation/actor_motion.gd"), "authoritative_upstream_runtime": true, "local_opt_in_patch_superseded": true}
	_json_report(report)
	world.queue_free()
	await process_frame
	print("HERO_DEATH_POLICY_%s actors=%d input_cases=%d checks=%d new_death_directions=1 final_approvals=0" % ["FAIL" if failed else "PASS", ids.size(), ids.size() * 8, checks])
	quit(1 if failed else 0)

func _json_report(report: Dictionary) -> void:
	var suffix := "headless" if DisplayServer.get_name() == "headless" else "opengl"
	var prefix := "overlay-" if OS.get_environment("TWILIGHT_HERO_RUNTIME_REVIEW") == "1" else "feature-"
	var file := FileAccess.open(evidence + prefix + "main-death-policy-" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
