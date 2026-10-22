extends SceneTree
## Runtime-only fixture from an existing real S source. No art/catalog approval.
const MOTION = preload("res://scripts/animation/actor_motion.gd")
const PROFILE = preload("res://scripts/animation/animation_profile.gd")
var atlas: ImageTexture
var fixture: SpriteFrames
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

func _run() -> void:
	if not check(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"), "Use isolated test saves"):
		quit(1)
		return
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var original: Dictionary = register.actors["transform:393"]
	var south: Dictionary = {}
	for track: Dictionary in original.tracks:
		if track.role == "death" and track.direction == "S": south = track
	if not check(not south.is_empty(), "Existing validated S source must be present"):
		quit(1)
		return
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
	var profile: Resource = load(original.native_profile).duplicate()
	profile.profile_id = "runtime-only-S-death-contract-test"
	profile.frames_path = fixture.resource_path
	var before_saves := _save_snapshot()
	for direction: int in range(8):
		var world: Node = load("res://Main.tscn").instantiate()
		world.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(world)
		await process_frame
		world.save_timer = -10000.0
		world.player.set_physics_process(false)
		var before := _snapshot(world)
		world.player.set_transform_visual("res://assets/catalog/0a4de2a60525e7bdee76bd2d.png", 1.0, profile)
		var motion: MOTION = world.player.motion
		var sprite: AnimatedSprite2D = world.player.transform_sprite
		motion.face(Vector2.RIGHT.rotated(direction * PI / 4.0))
		motion.die()
		var seen: Dictionary = {}
		for step: int in range(121):
			motion.advance(1.0 / 120.0, Vector2(200, 100))
			motion.apply(sprite, Vector2.ONE)
			check(sprite.animation == &"death_2", "Every requested view must use real S death")
			seen[sprite.frame] = true
		check(seen.size() == 6, "One-shot death must visit all six source poses")
		check(sprite.frame == 5 and not sprite.is_playing(), "Death must stop on terminal frame")
		var held_texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		motion.face(Vector2.RIGHT.rotated((direction + 3) * PI / 4.0))
		check(motion.begin_attack(0.4, Vector2.LEFT) == -1, "Dead actor cannot attack")
		motion.advance(4.0, Vector2(200, 100))
		motion.apply(sprite, Vector2.ONE)
		check(motion.dead and motion.state == "corpse", "No automatic standing/movement recovery")
		check(motion.facing8 == direction and sprite.animation == &"death_2" and sprite.frame == 5, "Terminal death is irreversible")
		check(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) == held_texture, "Hold the actual terminal texture")
		check(is_equal_approx(sprite.modulate.a, 1.0), "Authored terminal pose stays visible until normal entity cleanup")
		check(_snapshot(world) == before and _save_snapshot() == before_saves, "Visual death must not alter gameplay/save state")
		world.queue_free()
		await process_frame
	# Preserve an existing E view even when S is available; no new art is added.
	var partial := fixture.duplicate() as SpriteFrames
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
	print("PR122_S_ONLY_DEATH_MAIN_RESULT directions=8 poses=6 fixture_override=1 art_approvals=0 failures=" + str(failures))
	quit(0 if failures == 0 else 1)
