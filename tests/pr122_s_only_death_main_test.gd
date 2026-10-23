extends SceneTree
## Runtime-only fixture from an existing real S source. No art/catalog approval.
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
var atlas: ImageTexture
var fixture: SpriteFrames
var failures := 0
var staged_textures: Array[ImageTexture] = []

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

func _check_main_attack(profile: Resource, record: Dictionary) -> void:
	var key := StringName(OS.get_environment("TWILIGHT_NATIVE_MAIN_ACTION"))
	var expected_sha := OS.get_environment("TWILIGHT_NATIVE_MAIN_EXPECTED_SOURCE_SHA")
	var texture_path := ""
	for track: Dictionary in record.tracks:
		if str(track.animation) == str(key): texture_path = "res://" + str(track.texture)
	if not check(not texture_path.is_empty() and FileAccess.get_sha256(texture_path) == expected_sha, "Exact selected new action source required"):
		return
	check(fixture.has_animation(key) and not fixture.get_animation_loop(key), "New attack is a real one-shot clip")
	var duration := float(fixture.get_frame_count(key)) / fixture.get_animation_speed(key)
	check(is_equal_approx(duration, 0.42), "Retain the authored W attack clock")
	var world: Node = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	world.player.set_physics_process(false)
	var before := _snapshot(world)
	var before_saves := _save_snapshot()
	var old_class_frames: SpriteFrames = world.player.class_sprite.sprite_frames
	world.player.set_transform_visual("res://assets/catalog/e82707989c7744b45919684b.png",1.0,profile)
	var motion: MOTION = world.player.motion
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	motion.face(Vector2.LEFT)
	var strikes: Array[int] = []
	motion.strike.connect(func(id: int) -> void: strikes.append(id))
	var sequence: int = motion.begin_attack(duration,Vector2.LEFT,profile.motion_style)
	var seen: Dictionary = {}
	var marker_checked := false
	for tick: int in range(int(ceil((duration+0.4)*240.0))):
		motion.advance(1.0/240.0,Vector2.ZERO)
		motion.apply(sprite,sprite.get_meta("base_scale",Vector2.ONE))
		if sprite.animation == key:
			seen[sprite.frame] = true
			var actual := sprite.sprite_frames.get_frame_texture(key,sprite.frame) as AtlasTexture
			check(actual != null and actual.atlas.resource_path == texture_path,"Use the selected new W source rather than an alias")
		if not strikes.is_empty() and not marker_checked:
			check(strikes == [sequence] and sprite.animation == key and sprite.frame == 3,"One authoritative hit marker at native strike frame 3")
			marker_checked = true
	check(seen.size() == 6 and strikes == [sequence] and marker_checked,"Six poses and one strike event required")
	check(sprite.animation == &"idle_4" and motion.state == "idle","One-shot attack returns to preserved W idle")
	check(_snapshot(world) == before and _save_snapshot() == before_saves,"Visual action preserves gameplay and saves")
	check(world.player.class_sprite.sprite_frames == old_class_frames,"Preserve class animation resources")
	var proof_path := OS.get_environment("PR122_ACTION_RUNTIME_PROOF")
	if not proof_path.is_empty():
		var output := FileAccess.open(proof_path,FileAccess.WRITE)
		output.store_string(JSON.stringify({"actor":"transform:413","animation":str(key),"actual_staged_profile":true,"fixture_override":false,"source_sha256":expected_sha,"poses_reached":seen.size(),"marker_count":strikes.size(),"returned_to_idle":sprite.animation == &"idle_4","failures":failures,"gameplay_and_saves_unchanged":_snapshot(world) == before and _save_snapshot() == before_saves,"source_visual_status":"HOLD_NOT_REVIEWED","production_connected":false,"actor_approvals_added":0},"\t")+"\n")
		output.close()
	print("PR122_NATIVE_MAIN_ATTACK_PASS poses="+str(seen.size())+" markers="+str(strikes.size())+" failures="+str(failures)+" approvals_added=0")
	world.queue_free()
	await process_frame

func _run() -> void:
	if not check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"), "Use isolated test saves"):
		quit(1)
		return
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var staged_key := OS.get_environment("TWILIGHT_NATIVE_DEATH_ACTOR")
	var actual_staged := not staged_key.is_empty()
	var actor_key := staged_key if actual_staged else "transform:393"
	var original: Dictionary = register.actors[actor_key]
	var south: Dictionary = {}
	for track: Dictionary in original.tracks:
		if track.role == "death" and track.direction == "S": south = track
	if not check(not south.is_empty(), "Existing validated S source must be present"):
		quit(1)
		return
	var profile: Resource
	if actual_staged:
		for track: Dictionary in original.tracks:
			var image_texture := ImageTexture.create_from_image(Image.load_from_file("res://" + str(track.texture)))
			image_texture.take_over_path("res://" + str(track.texture))
			staged_textures.append(image_texture)
		fixture = load(original.frames) as SpriteFrames
		profile = load(original.native_profile)
	else:
		atlas = ImageTexture.create_from_image(Image.load_from_file("res://" + str(south.texture)))
		fixture = SpriteFrames.new()
		fixture.remove_animation("default")
		fixture.add_animation("death_2")
		fixture.set_animation_loop("death_2", false)
		fixture.set_animation_speed("death_2", 6.0 / 0.65)
		fixture.set_meta("twilight_native_locomotion_staging", true)
		for pose: Dictionary in south.geometry.frames:
			var texture := AtlasTexture.new()
			texture.atlas = atlas
			texture.region = Rect2(pose.region[0], pose.region[1], pose.region[2], pose.region[3])
			texture.margin = Rect2(pose.margin[0], pose.margin[1], pose.margin[2], pose.margin[3])
			texture.filter_clip = true
			fixture.add_frame("death_2", texture)
		# Cache-only fixture path; no approved SpriteFrames or catalog is modified.
		fixture.take_over_path("res://tests/runtime_only_s_death_fixture.tres")
		profile = load(original.native_profile).duplicate()
		profile.profile_id = "runtime-only-S-death-contract-test"
		profile.frames_path = fixture.resource_path
	if actual_staged and not OS.get_environment("TWILIGHT_NATIVE_MAIN_ACTION").is_empty():
		await _check_main_attack(profile,original)
		quit(0 if failures == 0 else 1)
		return
	var before_saves := _save_snapshot()
	var direction_results: Array = []
	for direction: int in range(8):
		var requested := StringName("death_" + str(direction))
		var expected := requested if actual_staged and fixture.has_animation(requested) else &"death_2"
		var world: Node = load("res://Main.tscn").instantiate()
		world.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(world)
		await process_frame
		world.save_timer = -10000.0
		world.player.set_physics_process(false)
		var before := _snapshot(world)
		world.player.set_transform_visual("res://assets/catalog/e82707989c7744b45919684b.png" if actual_staged else "res://assets/catalog/0a4de2a60525e7bdee76bd2d.png", 1.0, profile)
		var motion: MOTION = world.player.motion
		var sprite: AnimatedSprite2D = world.player.transform_sprite
		motion.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
		motion.die()
		var seen: Dictionary = {}
		for step: int in range(121):
			motion.advance(1.0 / 120.0, Vector2(200, 100))
			motion.apply(sprite, Vector2.ONE)
			check(sprite.animation == expected, "Preserve existing death direction; use real S for missing directions")
			seen[sprite.frame] = true
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
		direction_results.append({"input":direction,"resolved":str(expected),"poses_reached":seen.size(),"terminal_frame":sprite.frame,"corpse_held":motion.dead and motion.state == "corpse"})
		world.queue_free()
		await process_frame
	# Preserve an existing E view even when S is available; no new art is added.
	var partial := fixture.duplicate() as SpriteFrames
	if not partial.has_animation("death_0"):
		partial.add_animation("death_0")
		partial.set_animation_loop("death_0", false)
		for pose: int in range(6): partial.add_frame("death_0", fixture.get_frame_texture("death_2", pose))
	var test_motion := MOTION.new()
	test_motion.profile = profile
	test_motion.face(Vector2.RIGHT)
	test_motion.die()
	test_motion._resolve_frames(partial)
	check(test_motion._resolved_key == "death_0", "An existing requested directional clip must win")
	var missing := SpriteFrames.new()
	missing.set_meta("twilight_native_locomotion_staging", true)
	missing.add_animation("idle_2")
	missing.add_frame("idle_2", fixture.get_frame_texture("death_2", 0))
	test_motion._resolve_frames(missing)
	check(test_motion._resolved_key.is_empty(), "No fake death by aliasing idle/movement")
	var proof_path := OS.get_environment("PR122_DEATH_RUNTIME_PROOF")
	if not proof_path.is_empty():
		var proof := FileAccess.open(proof_path,FileAccess.WRITE)
		proof.store_string(JSON.stringify({"actor":actor_key,"actual_staged_profile":actual_staged,"directions":direction_results,"failures":failures,"source_visual_status":"HOLD_NOT_REVIEWED" if actual_staged else "EXISTING_APPROVAL_PRESERVED","actor_approvals_added":0,"gameplay_and_saves_unchanged":_save_snapshot() == before_saves},"\t")+"\n")
		proof.close()
	print("PR122_S_ONLY_DEATH_MAIN_RESULT directions=8 poses=6 actual_staged=" + str(actual_staged) + " art_approvals=0 failures=" + str(failures))
	quit(0 if failures == 0 else 1)
