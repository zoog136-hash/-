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

func _require(condition: bool, message: String = "Native default Main check failed") -> bool:
	if not condition:
		push_error("PR122_DEFAULT_MAIN_CHECK_FAILED: " + message)
		quit(1)
		return false
	return true

func _same_hit_frame_maps(actual: Variant, expected: Variant) -> bool:
	if not actual is Dictionary or not expected is Dictionary:
		return false
	if actual.size() != expected.size():
		return false
	for role: Variant in expected:
		if not actual.has(role):
			return false
		var left: Variant = actual[role]
		var right: Variant = expected[role]
		# JSON represents numbers as float; TRES retains integer literals.
		# Accept identical integer frame indices only, with exactly the same keys.
		if not (typeof(left) in [TYPE_INT, TYPE_FLOAT]) or not (typeof(right) in [TYPE_INT, TYPE_FLOAT]):
			return false
		var a := float(left)
		var b := float(right)
		if not is_finite(a) or not is_finite(b) or a < 0.0 or a > 5.0 or b < 0.0 or b > 5.0:
			return false
		if a != floorf(a) or b != floorf(b) or int(a) != int(b):
			return false
	return true

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
	if not _require(matches.size() == 1, "Exactly one real Main catalog record must identify Halpas"):
		return {}
	return matches[0]

func _prepare_resources(record: Dictionary) -> Resource:
	if not _require(int(record.native_track_count) == 48 and int(record.native_pose_count) == 288):
		return null
	if not _require(FileAccess.get_sha256(record.frames) == str(record.frames_sha256)):
		return null
	if not _require(FileAccess.get_sha256(record.native_profile) == str(record.native_profile_sha256)):
		return null
	var selected: Dictionary = {}
	for track: Dictionary in record.tracks:
		var animation := str(track.animation)
		if not _require(not selected.has(animation), "Each role and direction must have one native track"):
			return null
		selected[animation] = track
		if not _require(track.geometry.frames.size() == 6):
			return null
		# Real PNG bytes replace only their own resource cache entries, as in the
		# existing headless native tests. No catalog, profile or frame is replaced.
		var path := "res://" + str(track.texture).trim_prefix("res://")
		var image := Image.load_from_file(path)
		if not _require(image != null and not image.is_empty(), "Registered PNG must actually exist"):
			return null
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path(path)
		retained_textures.append(texture)
	if not _require(selected.size() == 48):
		return null
	var frames: SpriteFrames = load(record.frames)
	if not _require(frames.get_animation_names().size() == 48):
		return null
	for direction: int in range(8):
		for role: String in ROLES:
			var animation := role + "_" + str(direction)
			if not _require(selected.has(animation) and frames.has_animation(animation)):
				return null
			var track: Dictionary = selected[animation]
			if not _require(str(track.direction) == DIRECTIONS[direction] and str(track.role) == role):
				return null
			if not _require(frames.get_frame_count(animation) == 6):
				return null
			if not _require(frames.get_animation_loop(animation) == (role in ["idle", "walk", "run"])):
				return null
			for pose: int in range(6):
				var texture: AtlasTexture = frames.get_frame_texture(animation, pose) as AtlasTexture
				if not _require(texture != null and texture.atlas != null):
					return null
				if not _require(texture.atlas.resource_path == "res://" + str(track.texture).trim_prefix("res://")):
					return null
	var native: Resource = load(record.native_profile)
	if not _require(native != null and str(native.profile_id) == KEY):
		return null
	if not _require(str(native.frames_path) == str(record.frames) and native.layout == "directional8"):
		return null
	if not _require(native.color_tint == Color.WHITE and native.hit_frame_for("attack") == 3):
		return null
	return native

func _assert_default_connection(world: Node, record: Dictionary, native: Resource) -> bool:
	var player: Node = world.player
	var sprite: AnimatedSprite2D = player.transform_sprite
	if not _require(player.transform_active and player.motion.profile == player.transform_profile):
		return false
	if not _require(player.motion.profile.profile_id == KEY):
		return false
	if not _require(player.motion.profile.frames_path == str(record.frames)):
		return false
	if not _require(sprite.sprite_frames.resource_path == str(record.frames)):
		return false
	if not _require(sprite.sprite_frames == load(record.frames)):
		return false
	if not _require(sprite.visible and not player.class_sprite.visible):
		return false
	if not _require(not player.spx_sprite.visible and not player.spx_effect_sprite.visible):
		return false
	if not _require(player.motion.profile.color_tint == Color.WHITE and sprite.self_modulate == Color.WHITE):
		return false
	for property: String in ["layout", "motion_style", "movement_fps", "reference_speed",
		"pixel_scale", "native_width_ratio", "embedded_shadow", "authored_motion_weight",
		"hit_recoil", "death_duration", "body_kind", "floating", "sprite_offset",
		"attack_hit_frame", "action_hit_frames", "attack_animation_speed", "use_profile_hit_ratio"]:
		var expected: Variant = native.get(property)
		var actual: Variant = player.motion.profile.get(property)
		var equal: bool = actual == expected
		if property == "action_hit_frames":
			equal = _same_hit_frame_maps(actual, expected)
		elif expected is float:
			equal = is_equal_approx(float(actual), float(expected))
		elif expected is Vector2:
			equal = (actual as Vector2).is_equal_approx(expected)
		if not _require(equal, "Default profile mismatch: " + property):
			return false
	# When the flag is false, attack_hit_ratio is an unused serialized value;
	# marker_for() is the authoritative existing combat timing in both profiles.
	if not _require(is_equal_approx(player.motion.profile.marker_for(native.motion_style), native.marker_for(native.motion_style))):
		return false
	return true

func _present(world: Node, delta: float, velocity: Vector2) -> bool:
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	world.player.motion.advance(delta, velocity)
	world.player.motion.apply(sprite, sprite.get_meta("base_scale", Vector2.ONE))
	if not _require(sprite.self_modulate == Color.WHITE, "Authored native colors must not receive palette tint"):
		return false
	if not _require(not sprite.flip_h, "Every view must use its authored directional art"):
		return false
	return true

func _check_live_tracks(world: Node, native: Resource, before: String) -> bool:
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	var strikes: Array[int] = []
	world.player.attack_strike.connect(func(sequence: int) -> void: strikes.append(sequence))
	for direction: int in range(8):
		var aim := Vector2.RIGHT.rotated(float(direction) * PI / 4.0)
		for role: String in ["idle", "walk", "run", "attack", "hit"]:
			if not _present(world, 1.5, Vector2.ZERO):
				return false
			world.player.motion.face(aim)
			var velocity := Vector2.ZERO
			var sequence: int = -1
			var strike_start := strikes.size()
			match role:
				"walk": velocity = aim * float(native.reference_speed) * 0.6
				"run": velocity = aim * float(native.reference_speed) * 1.25
				"attack":
					sequence = world.player.start_combat_attack(world.player.global_position + aim, 0.9, native.motion_style)
					if not _require(sequence >= 0):
						return false
				"hit": world.player.motion.react(false, Vector2.ZERO)
			var animation := role + "_" + str(direction)
			var seen: Dictionary = {}
			var released := false
			for tick: int in range(240):
				if not _present(world, STEP, velocity):
					return false
				if str(sprite.animation) == animation:
					seen[sprite.frame] = true
				if role == "attack" and strikes.size() > strike_start and not released:
					if not _require(strikes.size() == strike_start + 1 and strikes.back() == sequence):
						return false
					if not _require(str(sprite.animation) == animation and sprite.frame == 3):
						return false
					released = true
			if not _require(seen.size() == 6, "Real default Main must present all six phases: " + animation):
				return false
			if not _require((strikes.size() == strike_start + 1 and released) if role == "attack" else strikes.size() == strike_start):
				return false
			if not _require(_invariants(world) == before):
				return false
			checked_tracks[animation] = seen.size()
	return true

func _check_death(world: Node, native: Resource, direction: int, before: String) -> bool:
	var sprite: AnimatedSprite2D = world.player.transform_sprite
	var strikes: Array[int] = []
	world.player.attack_strike.connect(func(sequence: int) -> void: strikes.append(sequence))
	world.player.motion.face(Vector2.RIGHT.rotated(float(direction) * PI / 4.0))
	world.player.motion.die()
	var animation := "death_" + str(direction)
	var seen: Dictionary = {}
	for tick: int in range(int(ceil((float(native.death_duration) + 0.2) / STEP))):
		if not _present(world, STEP, Vector2.ZERO):
			return false
		if not _require(str(sprite.animation) == animation):
			return false
		seen[sprite.frame] = true
	if not _require(seen.size() == 6 and world.player.motion.state == "corpse" and sprite.frame == 5):
		return false
	if not _present(world, 0.05, Vector2.ZERO):
		return false
	if not _require(str(sprite.animation) == animation and sprite.frame == 5 and not sprite.is_playing()):
		return false
	if not _require(strikes.is_empty() and _invariants(world) == before):
		return false
	checked_tracks[animation] = seen.size()
	return true

func _run() -> void:
	if not _require(OS.get_environment("XDG_DATA_HOME").trim_suffix("/").get_file().begins_with("twilight-test-"), "Use isolated test save data"):
		return
	var requested := OS.get_environment("TWILIGHT_NATIVE_MAIN_KEY")
	if not _require(requested.is_empty() or requested == KEY):
		return
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REGISTER_PATH))
	var record: Dictionary = register.actors[KEY]
	var native: Resource = _prepare_resources(record)
	if not _require(native != null, "Native resource preparation failed"):
		return
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
		if not _require(not source.is_empty(), "Exact default catalog record is required"):
			return
		if not _require(source.get("animation_profile", {}) is Dictionary):
			return
		if not _require(str(source.get("animation_profile", {}).get("frames_path", "")) == str(record.frames), "Real default catalog must already reference the native frames"):
			return
		var catalog_before := JSON.stringify(world.catalog_db)
		if death_direction == 0:
			catalog_reference = catalog_before
		else:
			if not _require(catalog_before == catalog_reference):
				return
		var before := _invariants(world)
		world._apply_transform_visual(source)
		if not _assert_default_connection(world, record, native):
			return
		if not _require(_invariants(world) == before and JSON.stringify(world.catalog_db) == catalog_before):
			return
		if death_direction == 0:
			if not _check_live_tracks(world, native, before):
				return
		if not _check_death(world, native, death_direction, before):
			return
		if not _require(JSON.stringify(world.catalog_db) == catalog_before and _save_invariants() == saves_before):
			return
		world.queue_free()
		await process_frame
		if not _require(_save_invariants() == saves_before):
			return
	if not _require(checked_tracks.size() == 48):
		return
	var poses := 0
	for count: int in checked_tracks.values():
		poses += count
	if not _require(poses == 288):
		return
	print("PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:393 tracks=48 poses=288 candidate_injection=0")
	quit(0)
