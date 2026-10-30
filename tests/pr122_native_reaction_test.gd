extends SceneTree
## Actual Player/native clips; presentation never changes reaction/combat clocks.

var textures: Array[ImageTexture] = []

func _initialize() -> void:
	call_deferred("_run")

func _cache(record: Dictionary) -> void:
	var seen: Dictionary = {}
	for track: Dictionary in record.tracks:
		var path: String = "res://" + str(track.texture)
		if seen.has(path): continue
		seen[path] = true
		var source := Image.new()
		assert(source.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
		var texture := ImageTexture.create_from_image(source)
		texture.take_over_path(path)
		textures.append(texture)

func _spawn(profile: Resource) -> Node2D:
	var actor: Node2D = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	actor.set_transform_visual("", 1.0, profile)
	return actor

func _tick(actor: Node2D, delta: float, velocity: Vector2 = Vector2.ZERO) -> void:
	actor.motion.advance(delta, velocity)
	actor.motion.apply(actor.transform_sprite, actor.transform_sprite.get_meta("base_scale", Vector2.ONE))

func _invariants(actor: Node2D) -> String:
	return JSON.stringify([actor.position, actor.get_node("CollisionShape2D").transform,
		actor.class_sprite.sprite_frames.resource_path, actor.move_speed, actor.attack_speed_multiplier])

func _hit(profile: Resource, fps: int, direction: int, critical: bool, moving: bool) -> void:
	var actor: Node2D = await _spawn(profile)
	var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
	actor.motion.face(aim)
	_tick(actor, .2)
	var before := _invariants(actor)
	var sequence: int = actor.motion.sequence
	actor.motion.react(critical, -aim)
	var original_duration: float = .13 if critical else .085
	assert(is_equal_approx(actor.motion.hit_clock, original_duration))
	assert(is_equal_approx(actor.motion.hit_duration, original_duration))
	var seen: Dictionary = {}
	for tick: int in range(int(ceil(.5 * fps))):
		_tick(actor, 1.0 / fps, aim * profile.reference_speed if moving else Vector2.ZERO)
		assert(is_equal_approx(actor.motion.hit_clock, maxf(0.0, original_duration - float(tick + 1) / fps)))
		if str(actor.transform_sprite.animation) == "hit_" + str(direction):
			seen[actor.transform_sprite.frame] = true
		assert(_invariants(actor) == before and actor.motion.sequence == sequence)
	assert(seen.size() == 6, "Native hit must display all six phases at %dHz moving=%s critical=%s" % [fps, moving, critical])
	assert(not str(actor.transform_sprite.animation).begins_with("hit_"))
	actor.queue_free()
	await process_frame

func _turn_attack_death(profile: Resource, direction: int) -> void:
	var actor: Node2D = await _spawn(profile)
	var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
	actor.motion.face(-aim)
	_tick(actor, .2)
	actor.motion.face(aim)
	_tick(actor, 1.0 / 60.0)
	assert(str(actor.transform_sprite.animation) == "idle_" + str(direction))
	assert(actor.transform_sprite.frame == 0, "First turn sample uses the real idle at the new facing")
	assert(not actor.transform_sprite.sprite_frames.has_animation("turn_" + str(direction)))
	var before := _invariants(actor)
	var strikes: Array[int] = []
	actor.attack_strike.connect(func(id: int) -> void: strikes.append(id))
	actor.motion.react(false, -aim)
	var sequence: int = actor.start_combat_attack(actor.global_position + aim, .9, profile.motion_style)
	var released: bool = false
	for tick: int in range(90):
		if tick == 20: actor.motion.react(direction == 6, -aim)
		_tick(actor, 1.0 / 60.0)
		if not strikes.is_empty() and not released:
			assert(strikes == [sequence])
			assert(str(actor.transform_sprite.animation) == "attack_" + str(direction) and actor.transform_sprite.frame == 3)
			assert(absf(actor.motion.attack_elapsed - .9 * actor.motion.attack_hit_ratio) <= 1.0 / 60.0 + .0001)
			released = true
		assert(_invariants(actor) == before)
	assert(released and strikes == [sequence] and not str(actor.transform_sprite.animation).begins_with("hit_"))
	actor.motion.react(false, -aim)
	actor.motion.die()
	for tick: int in range(int(ceil((profile.death_duration + .2) * 60.0))):
		_tick(actor, 1.0 / 60.0)
		assert(str(actor.transform_sprite.animation) == "death_" + str(direction))
		assert(_invariants(actor) == before and strikes == [sequence])
	assert(actor.motion.state == "corpse" and actor.transform_sprite.frame == 5)
	assert(not actor.transform_sprite.sprite_frames.get_animation_loop(actor.transform_sprite.animation))
	actor.queue_free()
	await process_frame

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var scope: PackedStringArray = OS.get_environment("TWILIGHT_NATIVE_TEST_KEYS").split(",", false)
	var actors: int = 0
	var hit_cases: int = 0
	for key: String in register.actors:
		if key not in ["transform:393", "transform:267"] or (not scope.is_empty() and not scope.has(key)): continue
		var record: Dictionary = register.actors[key]
		_cache(record)
		var profile: Resource = load(record.native_profile)
		var catalog_candidate: Resource = profile.duplicate()
		catalog_candidate.remove_meta("twilight_native_locomotion_staging")
		assert(not catalog_candidate.has_meta("twilight_native_locomotion_staging"))
		for fps: int in [30, 60, 120]:
			for direction: int in [0, 6]:
				for critical: bool in [false, true]:
					for moving: bool in [false, true]:
						await _hit(catalog_candidate if direction == 6 else profile, fps, direction, critical, moving)
						hit_cases += 1
		for direction: int in [0, 6]: await _turn_attack_death(catalog_candidate if direction == 6 else profile, direction)
		actors += 1
		textures.clear()
		await process_frame
	assert(actors > 0 and hit_cases == actors * 24)
	print("PR122_NATIVE_REACTION_PASS actors=%d hit_cases=%d fps=30,60,120 headings=E,N catalog_candidate_without_profile_metadata=true moving_and_stationary=true all_six_phases=true hit_clock_combat_marker_collision_class_preserved=true turn_idle_death=true engine=%s approvals_added=0" % [actors, hit_cases, Engine.get_version_info().string])
	quit(0)
