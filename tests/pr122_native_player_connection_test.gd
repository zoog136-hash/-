extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animation_authoring_sources.json"))
	var references: Dictionary = {}
	for target: Dictionary in sources.targets:
		if register.actors.has(target.key):
			references[target.key] = target.reference.path
	var actor: Node2D = load("res://scenes/Player.tscn").instantiate()
	root.add_child(actor)
	await process_frame
	actor.set_physics_process(false)
	var original_position: Vector2 = actor.position
	var original_collision: Transform2D = actor.get_node("CollisionShape2D").transform
	var original_class_frames: SpriteFrames = actor.class_sprite.sprite_frames
	var original_sequence: int = actor.motion.sequence
	var checked: int = 0
	for key: String in register.actors:
		var record: Dictionary = register.actors[key]
		var profile: Resource = load(record.native_profile)
		actor.motion.advance(0.0, Vector2.ZERO)
		actor.set_transform_visual(references[key], 1.0, profile)
		assert(actor.transform_active and actor.transform_sprite.visible and not actor.class_sprite.visible)
		assert(actor.motion.profile == profile)
		assert(actor.transform_sprite.sprite_frames.resource_path == record.frames)
		var sprite: AnimatedSprite2D = actor.transform_sprite
		assert(sprite.sprite_frames.has_animation(sprite.animation))
		for track: Dictionary in record.tracks:
			var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
			var velocity: Vector2 = Vector2.RIGHT.rotated(float(direction) * PI / 4.0) * profile.reference_speed
			velocity *= 0.6 if track.role == "walk" else 1.25
			var seen: Dictionary = {}
			for tick: int in range(120):
				actor.motion.advance(1.0 / 60.0, velocity)
				actor.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
				assert(actor.motion.state == track.role and actor.motion.facing8 == direction)
				assert(str(sprite.animation) == track.animation and not sprite.flip_h)
				assert(sprite.self_modulate == Color.WHITE)
				var foot: Vector2 = Vector2(0, float(record.foot[1]) - float(record.canvas_size[1]) / 2.0)
				assert((sprite.position + foot * sprite.scale).is_equal_approx(Vector2.ZERO))
				seen[sprite.frame] = true
			assert(seen.size() == 6)
			checked += 1
		# An unavailable idle remains unavailable. Form switching/idle never
		# synthesizes it from a walk, run, portrait, or a different creature.
		var previous_animation: StringName = sprite.animation
		actor.motion.advance(1.0, Vector2.ZERO)
		actor.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
		assert(sprite.animation == previous_animation)
		for missing: String in record.missing_locomotion:
			assert(not sprite.sprite_frames.has_animation(missing))
			var role: String = missing.get_slice("_", 0)
			var heading: int = int(missing.get_slice("_", 1))
			var unavailable_velocity: Vector2 = Vector2.RIGHT.rotated(float(heading) * PI / 4.0) * profile.reference_speed
			unavailable_velocity *= 0.6 if role == "walk" else 1.25
			actor.motion.advance(1.0 / 60.0, unavailable_velocity)
			actor.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
			assert(actor.motion._resolved_key.is_empty())
			assert(sprite.animation == previous_animation)
		assert(actor.position == original_position)
		assert(actor.get_node("CollisionShape2D").transform == original_collision)
		assert(actor.motion.sequence == original_sequence)
		assert(actor.class_sprite.sprite_frames == original_class_frames)
	actor.clear_transform_visual()
	assert(not actor.transform_active and actor.class_sprite.visible)
	assert(actor.class_sprite.sprite_frames == original_class_frames)
	actor.queue_free()
	await process_frame
	assert(checked == 9)
	print("PR122_NATIVE_PLAYER_CONNECTION_PASS actors=2 clips=9 native_phases=54 position_collision_class_combat_sequence_preserved=true engine=%s production_catalog_switches=0 approvals_added=0" % Engine.get_version_info().string)
	quit(0)
