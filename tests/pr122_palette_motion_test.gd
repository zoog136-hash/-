extends SceneTree

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures.append(label)
		print("PR122_PALETTE_FAIL: " + label)

func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_palette_finish_20261019.json"))
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG.PROFILE_PATH)).profiles
	var connection_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_monster_boss_runtime_connections.json"))
	var native_connections: Dictionary = {}
	for connection: Dictionary in connection_data.connections:
		check(not native_connections.has(connection.id), "unique reviewed native connection " + str(connection.id))
		native_connections[connection.id] = connection
	check(native_connections.size() == 19, "nineteen recorded native boss connections")
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	check(int(manifest.target_count) == 54, "all requested palette bindings present")
	check(int(manifest.new_native_art_approvals) == 0, "shared motion never promotes native art approval")
	for entry: Dictionary in manifest.entries:
		var key := str(entry.target)
		var kind := key.get_slice(":", 0)
		var identity := key.trim_prefix(kind + ":")
		var record := {"sourceId": identity} if kind == "transform" else {"name": identity}
		var saved := record.duplicate(true)
		var profile = CATALOG.for_record(kind, record)
		check(record == saved and profile.profile_id == key, "independent unchanged gameplay identity " + key)
		var published_replacement: bool = key in ["monster:얼음 여왕", "monster:알비노 유니콘"]
		var settings: Dictionary = raw.get(key, {})
		var proxy: Dictionary = settings.get("preserved_proxy_profile", {}) if published_replacement else settings
		# Preserve the old palette evidence even when one of the two explicitly
		# reviewed dedicated packs replaces its former runtime proxy.
		check(str(proxy.get("shared_visual_source", "")) == str(entry.source), "explicit preserved source " + key)
		check(str(proxy.get("frames_path", "")) == str(entry.frames_path), "recorded palette source " + key)
		check(str(proxy.get("color_tint", "")) == str(entry.color_tint), "recorded palette tint " + key)
		check(FileAccess.get_sha256(str(entry.frames_path)) == str(entry.frames_sha256), "unchanged donor bytes " + key)
		if published_replacement:
			var connection: Dictionary = native_connections.get(key, {})
			check(str(connection.get("status", "")) == "CONNECTED_REVIEWED" and bool(connection.get("formal_approval_history_unchanged", false)), "reviewed connection preserves approval history " + key)
			check(profile.frames_path == str(connection.get("frames", "")) and profile.frames_path != str(entry.frames_path), "recorded dedicated runtime source " + key)
			check(FileAccess.get_sha256(profile.frames_path) == str(connection.get("frames_sha256", "")), "exact published source bytes " + key)
			check(str(settings.get("shared_visual_source", "")).is_empty() and profile.color_tint == Color.WHITE, "dedicated source retains its own palette " + key)
		else:
			check(profile.frames_path == str(entry.frames_path), "runtime source " + key)
			check(profile.color_tint == Color.from_string(str(entry.color_tint), Color.WHITE), "runtime tint " + key)
		var frames: SpriteFrames = CATALOG.frames(profile.frames_path, profile.layout)
		if published_replacement:
			var connection: Dictionary = native_connections.get(key, {})
			var poses: int = 0
			for animation: StringName in frames.get_animation_names(): poses += frames.get_frame_count(animation)
			check(int(connection.get("required_clips", 0)) == 33 and frames.get_animation_names().size() == 33 and poses == int(connection.get("source_poses", 0)), "all published clips and source poses " + key)
			check(bool(frames.get_meta("twilight_native_locomotion_staging", false)) and bool(frames.get_meta("twilight_production_connected", false)) and not bool(frames.get_meta("twilight_detailed_completed", true)), "native source without new formal approval " + key)
		sprite.sprite_frames = frames
		var motion = MOTION.new()
		motion.profile = profile
		var roles: Array[String] = ["idle", "walk", "attack", "hit", "death"]
		if published_replacement: roles[1] = "run"
		for direction in range(8):
			if published_replacement:
				check(not frames.has_animation("walk_" + str(direction)) and frames.get_frame_count("run_" + str(direction)) == 6, "authored RUN-only source " + key)
			for role: String in roles:
				var track := role + "_" + str(2 if published_replacement and role == "death" else direction)
				check(frames.has_animation(track) and frames.get_frame_count(track) >= 2, "complete directional track " + key + " " + track)
				if not frames.has_animation(track): continue
				motion.facing8 = direction
				motion.state = role
				motion.dead = role == "death"
				motion.death_clock = profile.death_duration * 0.5
				motion.hit_clock = motion.hit_duration * 0.5
				motion.gait = 0.5
				motion.apply(sprite, Vector2.ONE)
				check(motion._resolved_key == track and str(sprite.animation) == track, "actual motion resolver " + key + " " + track)
				check(sprite.self_modulate == profile.color_tint, "actual sprite palette " + key + " " + track)
				for index in range(frames.get_frame_count(track)):
					var texture := frames.get_frame_texture(track, index)
					check(texture != null and texture.get_size().x > 0 and texture.get_size().y > 0, "usable source frame " + key + " " + track)
		# A later actor must be able to use the same cached source independently.
		var movement_track := "run_0" if published_replacement else "walk_0"
		var source_before := frames.get_frame_count(movement_track)
		profile.color_tint = Color.WHITE
		check(frames.get_frame_count(movement_track) == source_before, "palette does not mutate cached source " + key)
	print("PR122_PALETTE_MOTION_OK checks=%d profiles=54 native_approvals_added=0 failures=%d" % [assertions, failures.size()])
	sprite.queue_free()
	quit(0 if failures.is_empty() else 1)
