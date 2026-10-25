extends SceneTree
## New native candidates through the existing Main transformation API.
## No screenshots, catalog replacement, old subject reruns or approval changes.

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _invariants(world: Node) -> String:
	return JSON.stringify([world.hp, world.gold, world.inventory, world.equipped_items,
		world.equipped_catalog, world._normal_attack_interval(), world._current_weapon_type(),
		world.player.position, world.player.get_node("CollisionShape2D").transform,
		world.player.class_sprite.sprite_frames.resource_path, world.player.move_speed,
		world.player.attack_speed_multiplier, world.player.equipment_move_speed_multiplier])

func _run() -> void:
	assert(OS.get_environment("XDG_DATA_HOME").get_file().begins_with("twilight-test-"))
	var key := OS.get_environment("TWILIGHT_NATIVE_MAIN_KEY")
	assert(not key.is_empty())
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var record: Dictionary = register.actors[key]
	assert(int(record.native_track_count) == 48 and int(record.native_pose_count) == 288)
	var textures: Array[ImageTexture] = []
	for track: Dictionary in record.tracks:
		var texture := ImageTexture.create_from_image(Image.load_from_file("res://" + str(track.texture)))
		texture.take_over_path("res://" + str(track.texture))
		textures.append(texture)
	var native: Resource = load(record.native_profile)
	var world: Node = load("res://Main.tscn").instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.save_timer = -10000.0
	var source: Dictionary = {}
	for item: Dictionary in world.catalog_db.get("변신", []):
		if "transform:" + str(item.get("sourceId", "")) == key:
			source = item
			break
	assert(not source.is_empty(), "Actual Main catalog contains exact logical character")
	var catalog_before := JSON.stringify(source)
	var prior: Resource = CATALOG.for_record("transform", source)
	var candidate := source.duplicate(true)
	var settings: Dictionary = {}
	for property: String in ["frames_path", "layout", "motion_style", "movement_fps", "reference_speed",
		"pixel_scale", "native_width_ratio", "embedded_shadow", "authored_motion_weight", "hit_recoil",
		"death_duration", "body_kind", "floating", "attack_hit_frame", "action_hit_frames", "attack_animation_speed"]:
		settings[property] = native.get(property)
	settings.sprite_offset = [native.sprite_offset.x, native.sprite_offset.y]
	settings.color_tint = native.color_tint.to_html()
	if native.use_profile_hit_ratio: settings.attack_hit_ratio = native.attack_hit_ratio
	candidate.animation_profile = settings
	var before := _invariants(world)
	world._apply_transform_visual(candidate)
	assert(world.player.transform_active and world.player.motion.profile.profile_id == key)
	assert(world.player.motion.profile.frames_path == native.frames_path)
	assert(world.player.motion.profile.use_profile_hit_ratio == prior.use_profile_hit_ratio)
	assert(is_equal_approx(world.player.motion.profile.attack_hit_ratio, prior.attack_hit_ratio))
	assert(is_equal_approx(world.player.motion.profile.death_duration, prior.death_duration))
	assert(_invariants(world) == before and JSON.stringify(source) == catalog_before)
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	var strikes: Array[int] = []
	world.player.attack_strike.connect(func(id: int) -> void: strikes.append(id))
	var checked: int = 0
	for direction: int in range(8):
		var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
		world.player.motion.face(aim)
		for role: String in ["idle", "walk", "run", "attack", "hit"]:
			world.player.motion.advance(1.5, Vector2.ZERO)
			var velocity := Vector2.ZERO
			var sequence: int = -1
			var strike_start := strikes.size()
			match role:
				"walk": velocity = aim * 126.0
				"run": velocity = aim * 262.5
				"attack": sequence = world.player.start_combat_attack(world.player.global_position + aim, 0.9, native.motion_style)
				"hit": world.player.motion.react(false, Vector2.ZERO)
			var seen: Dictionary = {}
			var released := false
			for tick: int in range(240):
				world.player.motion.advance(1.0 / 120.0, velocity)
				world.player.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
				if str(sprite.animation) == role + "_" + str(direction): seen[sprite.frame] = true
				if role == "attack" and strikes.size() > strike_start and not released:
					assert(strikes.size() == strike_start + 1 and strikes.back() == sequence)
					assert(str(sprite.animation) == "attack_" + str(direction) and sprite.frame == 3)
					released = true
			assert(seen.size() == 6, "Actual Main must present all six authored phases: " + role)
			assert((strikes.size() == strike_start + 1 and released) if role == "attack" else strikes.size() == strike_start)
			assert(_invariants(world) == before)
			checked += 1
	world.player.motion.face(Vector2.RIGHT)
	world.player.motion.die()
	var death_seen: Dictionary = {}
	for tick: int in range(int(ceil((native.death_duration + 0.2) * 120.0))):
		world.player.motion.advance(1.0 / 120.0, Vector2.ZERO)
		world.player.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
		if str(sprite.animation) == "death_0": death_seen[sprite.frame] = true
	assert(death_seen.size() == 6 and world.player.motion.state == "corpse" and sprite.frame == 5)
	assert(_invariants(world) == before and JSON.stringify(source) == catalog_before)
	print("PR122_NATIVE_MAIN_PASS key=%s native_clips=48 directional_cases=%d plus_death=true authoritative_clock_inventory_collision_preserved=true catalog_replacements=0 approvals_added=0" % [key, checked])
	world.queue_free()
	await process_frame
	quit(0)
