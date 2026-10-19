extends SceneTree
## Real default catalog -> Main -> Player, with no candidate/profile injection.
## Run only after reviewed native resources have been connected to that catalog.

const KEY := "transform:393"
const REGISTER_PATH := "res://data/pr122_native_locomotion_staging.json"
const MAIN_PATH := "res://Main.tscn"
const DIRECTIONS := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
const ROLES := ["idle", "walk", "run", "attack", "hit", "death"]
const STEP := 1.0 / 120.0

var retained_textures: Array[ImageTexture] = []
var checked_tracks: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _invariants(world: Node) -> String:
	var collision: CollisionShape2D = world.player.get_node("CollisionShape2D")
	return JSON.stringify([world.hp, world.gold, world.inventory, world.equipped_items,
		world.equipped_catalog, world._normal_attack_interval(), world._current_weapon_type(),
		world.player.class_index, world.player.class_sprite.sprite_frames.resource_path,
		world.player.position, world.player.global_position, collision.transform,
		collision.shape.get_rect(), collision.disabled, world.player.collision_layer,
		world.player.collision_mask, world.player.move_speed, world.player.click_move_speed,
		world.player.attack_speed_multiplier, world.player.equipment_move_speed_multiplier,
		world.player.skill_speed_multiplier])

func _optional_file_sha(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "ABSENT"

func _save_invariants() -> String:
	return JSON.stringify([
		_optional_file_sha("user://twilight_v20_save.json"),
		_optional_file_sha("user://twilight_ui_settings.cfg")])

func _catalog_record(world: Node) -> Dictionary:
	var matches: Array[Dictionary] = []
	for item: Dictionary in world.catalog_db.get("변신", []):
		if "transform:" + str(item.get("sourceId", "")) == KEY:
			matches.append(item)
	assert(matches.size() == 1, "Exactly one real Main catalog record must identify Halpas")
	return matches[0]

func _prepare_resources(record: Dictionary) -> Resource:
	assert(int(record.native_track_count) == 48 and int(record.native_pose_count) == 288)
	assert(FileAccess.get_sha256(record.frames) == str(record.frames_sha256))
	assert(FileAccess.get_sha256(record.native_profile) == str(record.native_profile_sha256))
	var selected: Dictionary = {}
	for track: Dictionary in record.tracks:
		var animation := str(track.animation)
		assert(not selected.has(animation), "Each role and direction must have one native track")
		selected[animation] = track
		assert(track.geometry.frames.size() == 6)
		# Real PNG bytes replace only their own resource cache entries, as in the
		# existing headless native tests. No catalog, profile or frame is replaced.
		var path := "res://" + str(track.texture).trim_prefix("res://")
		var image := Image.load_from_file(path)
		assert(image != null and not image.is_empty(), "Registered PNG must actually exist")
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path(path)
		retained_textures.append(texture)
	assert(selected.size() == 48)
	var frames: SpriteFrames = load(record.frames)
	assert(frames.get_animation_names().size() == 48)
	for direction: int in range(8):
		for role: String in ROLES:
			var animation := role + "_" + str(direction)
			assert(selected.has(animation) and frames.has_animation(animation))
			var track: Dictionary = selected[animation]
			assert(str(track.direction) == DIRECTIONS[direction] and str(track.role) == role)
			assert(frames.get_frame_count(animation) == 6)
			assert(frames.get_animation_loop(animation) == (role in ["idle", "walk", "run"]))
			for pose: int in range(6):
				var texture: AtlasTexture = frames.get_frame_texture(animation, pose) as AtlasTexture
				assert(texture != null and texture.atlas != null)
				assert(texture.atlas.resource_path == "res://" + str(track.texture).trim_prefix("res://"))
	var native: Resource = load(record.native_profile)
	assert(native != null and str(native.profile_id) == KEY)
	assert(str(native.frames_path) == str(record.frames) and native.layout == "directional8")
	assert(native.color_tint == Color.WHITE and native.hit_frame_for("attack") == 3)
	return native

func _assert_default_connection(world: Node, record: Dictionary, native: Resource) -> void:
	var player: Node = world.player
	var sprite: AnimatedSprite2D = player.transform_sprite
	assert(player.transform_active and player.motion.profile == player.transform_profile)
	assert(player.motion.profile.profile_id == KEY)
	assert(player.motion.profile.frames_path == str(record.frames))
	assert(sprite.sprite_frames.resource_path == str(record.frames))
	assert(sprite.sprite_frames == load(record.frames))
	assert(sprite.visible and not player.class_sprite.visible)
	assert(not player.spx_sprite.visible and not player.spx_effect_sprite.visible)
	assert(player.motion.profile.color_tint == Color.WHITE and sprite.self_modulate == Color.WHITE)
	for property: String in ["layout", "motion_style", "movement_fps", "reference_speed",
		"pixel_scale", "native_width_ratio", "embedded_shadow", "authored_motion_weight",
		"hit_recoil", "death_duration", "body_kind", "floating", "sprite_offset",
		"attack_hit_frame", "action_hit_frames", "attack_animation_speed", "use_profile_hit_ratio"]:
		var expected: Variant = native.get(property)
		var actual: Variant = player.motion.profile.get(property)
		var equal: bool = actual == expected
		if expected is float:
			equal = is_equal_approx(float(actual), float(expected))
		elif expected is Vector2:
			equal = (actual as Vector2).is_equal_approx(expected)
		assert(equal, "Default profile mismatch: " + property)
	# When the flag is false, attack_hit_ratio is an unused serialized value;
	# marker_for() is the authoritative existing combat timing in both profiles.
	assert(is_equal_approx(player.motion.profile.marker_for(native.motion_style), native.marker_for(native.motion_style)))

func _present(world: Node, delta: float, velocity: Vector2) -> void:
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	world.player.motion.advance(delta, velocity)
	world.player.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
	assert(sprite.self_modulate == Color.WHITE, "Authored native colors must not receive palette tint")
	assert(not sprite.flip_h, "Every view must use its authored directional art")

func _check_live_tracks(world: Node, native: Resource, before: String) -> void:
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	var strikes: Array[int] = []
	world.player.attack_strike.connect(func(sequence: int) -> void: strikes.append(sequence))
	for direction: int in range(8):
		var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
		for role: String in ["idle", "walk", "run", "attack", "hit"]:
			_present(world, 1.5, Vector2.ZERO)
			world.player.motion.face(aim)
			var velocity := Vector2.ZERO
			var sequence: int = -1
			var strike_start := strikes.size()
			match role:
				"walk": velocity = aim * float(native.reference_speed) * 0.6
				"run": velocity = aim * float(native.reference_speed) * 1.25
				"attack":
					sequence = world.player.start_combat_attack(world.player.global_position + aim, 0.9, native.motion_style)
					assert(sequence >= 0)
				"hit": world.player.motion.react(false, Vector2.ZERO)
			var animation := role + "_" + str(direction)
			var seen: Dictionary = {}
			var released := false
			for tick: int in range(240):
				_present(world, STEP, velocity)
				if str(sprite.animation) == animation:
					seen[sprite.frame] = true
				if role == "attack" and strikes.size() > strike_start and not released:
					assert(strikes.size() == strike_start + 1 and strikes.back() == sequence)
					assert(str(sprite.animation) == animation and sprite.frame == 3)
					released = true
			assert(seen.size() == 6, "Real default Main must present all six phases: " + animation)
			assert((strikes.size() == strike_start + 1 and released) if role == "attack" else strikes.size() == strike_start)
			assert(_invariants(world) == before)
			checked_tracks[animation] = seen.size()

func _check_death(world: Node, native: Resource, direction: int, before: String) -> void:
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	var strikes: Array[int] = []
	world.player.attack_strike.connect(func(sequence: int) -> void: strikes.append(sequence))
	world.player.motion.face(Vector2.RIGHT.rotated(float(direction) * PI / 4.0))
	world.player.motion.die()
	var animation := "death_" + str(direction)
	var seen: Dictionary = {}
	for tick: int in range(int(ceil((float(native.death_duration) + 0.2) / STEP))):
		_present(world, STEP, Vector2.ZERO)
		assert(str(sprite.animation) == animation)
		seen[sprite.frame] = true
	assert(seen.size() == 6 and world.player.motion.state == "corpse" and sprite.frame == 5)
	_present(world, 0.05, Vector2.ZERO)
	assert(str(sprite.animation) == animation and sprite.frame == 5 and not sprite.is_playing())
	assert(strikes.is_empty() and _invariants(world) == before)
	checked_tracks[animation] = seen.size()

func _run() -> void:
	assert(OS.get_environment("XDG_DATA_HOME").trim_suffix("/").get_file().begins_with("twilight-test-"), "Use isolated test save data")
	var requested := OS.get_environment("TWILIGHT_NATIVE_MAIN_KEY")
	assert(requested.is_empty() or requested == KEY)
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTER_PATH))
	var record: Dictionary = register.actors[KEY]
	var native: Resource = _prepare_resources(record)
	var saves_before := _save_invariants()
	var catalog_reference := ""
	# Death is irreversible. Instantiate a fresh real Main for each direction;
	# never clear internal motion.dead or inject a replacement actor/profile.
	for death_direction: int in range(8):
		var world: Node = load(MAIN_PATH).instantiate()
		world.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(world)
		await process_frame
		world.save_timer = -10000.0
		var source: Dictionary = _catalog_record(world)
		assert(source.get("animation_profile", {}) is Dictionary)
		assert(str(source.get("animation_profile", {}).get("frames_path", "")) == str(record.frames), "Real default catalog must already reference the native frames")
		var catalog_before := JSON.stringify(world.catalog_db)
		if death_direction == 0:
			catalog_reference = catalog_before
		else:
			assert(catalog_before == catalog_reference)
		var before := _invariants(world)
		world._apply_transform_visual(source)
		_assert_default_connection(world, record, native)
		assert(_invariants(world) == before and JSON.stringify(world.catalog_db) == catalog_before)
		if death_direction == 0:
			_check_live_tracks(world, native, before)
		_check_death(world, native, death_direction, before)
		assert(JSON.stringify(world.catalog_db) == catalog_before and _save_invariants() == saves_before)
		world.queue_free()
		await process_frame
		assert(_save_invariants() == saves_before)
	assert(checked_tracks.size() == 48)
	var poses := 0
	for count: int in checked_tracks.values():
		poses += count
	assert(poses == 288)
	print("PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:393 tracks=48 poses=288 candidate_injection=0")
	quit(0)
