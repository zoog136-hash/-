extends SceneTree
## Dedicated actions exercise the actual Player's existing motion controller.
## No rendering, capture, synthetic action alias or production catalog change.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var scope: PackedStringArray = OS.get_environment("TWILIGHT_NATIVE_TEST_KEYS").split(",", false)
	var textures: Array[ImageTexture] = []
	var checked: int = 0
	var expected: int = 0
	for key: String in register.actors:
		if not scope.is_empty() and not scope.has(key): continue
		var record: Dictionary = register.actors[key]
		for track: Dictionary in record.tracks:
			var texture := ImageTexture.create_from_image(Image.load_from_file("res://" + str(track.texture)))
			texture.take_over_path("res://" + str(track.texture))
			textures.append(texture)
			if track.role not in ["walk", "run"]: expected += 1
		var profile: Resource = load(record.native_profile)
		for track: Dictionary in record.tracks:
			var role: String = track.role
			if role in ["walk", "run"]: continue
			var actor: Node2D = load("res://scenes/Player.tscn").instantiate()
			root.add_child(actor)
			await process_frame
			actor.set_physics_process(false)
			var original_position: Vector2 = actor.position
			var original_collision: Transform2D = actor.get_node("CollisionShape2D").transform
			var original_class_frames: SpriteFrames = actor.class_sprite.sprite_frames
			actor.set_transform_visual("", 1.0, profile)
			var sprite: AnimatedSprite2D = actor.transform_sprite
			var motion: RefCounted = actor.motion
			var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
			var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
			motion.face(aim)
			motion.advance(0.25, Vector2.ZERO)
			var strikes: Array[int] = []
			motion.strike.connect(func(id: int) -> void: strikes.append(id))
			var sequence: int = -1
			var duration: float = 0.9
			match role:
				"attack": sequence = motion.begin_attack(duration, aim, profile.motion_style)
				"hit": motion.react(false, Vector2.ZERO)
				"death": motion.die(); duration = profile.death_duration
				"idle": duration = 1.5
				_: assert(false, "Unregistered dedicated action")
			var seen: Dictionary = {}
			var released: bool = false
			for tick: int in range(int(ceil((duration + 0.5) * 120.0))):
				motion.advance(1.0 / 120.0, Vector2.ZERO)
				motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
				if str(sprite.animation) == track.animation:
					seen[sprite.frame] = true
					assert(not sprite.flip_h and sprite.rotation == 0.0)
					var foot := Vector2(0, float(record.foot[1]) - float(record.canvas_size[1]) / 2.0)
					assert((sprite.position + foot * sprite.scale).is_equal_approx(Vector2.ZERO))
				if role == "attack" and not strikes.is_empty() and not released:
					assert(strikes == [sequence])
					assert(str(sprite.animation) == track.animation and sprite.frame == 3)
					assert(absf(motion.attack_elapsed - duration * motion.attack_hit_ratio) <= 1.0 / 120.0 + 0.0001)
					released = true
			assert(seen.size() == 6, "Every dedicated native phase must be presented")
			if role == "attack": assert(released and strikes == [sequence])
			else: assert(strikes.is_empty())
			if role == "death": assert(motion.state == "corpse" and sprite.frame == 5)
			assert(actor.position == original_position)
			assert(actor.get_node("CollisionShape2D").transform == original_collision)
			assert(actor.class_sprite.sprite_frames == original_class_frames)
			checked += 1
			actor.queue_free()
			await process_frame
	assert(expected > 0 and checked == expected)
	print("PR122_NATIVE_ACTION_PASS clips=%d all_six_phases=true attack_marker_frame=3 authoritative_clock_preserved=true native_foot_collision_class_preserved=true engine=%s approvals_added=0" % [checked, Engine.get_version_info().string])
	quit(0)
