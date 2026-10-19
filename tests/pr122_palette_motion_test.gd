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
		check(str(raw[key].shared_visual_source) == str(entry.source), "explicit source " + key)
		check(profile.frames_path == str(entry.frames_path), "runtime source " + key)
		check(FileAccess.get_sha256(profile.frames_path) == str(entry.frames_sha256), "unchanged donor bytes " + key)
		check(profile.color_tint == Color.from_string(str(entry.color_tint), Color.WHITE), "runtime tint " + key)
		var frames: SpriteFrames = CATALOG.frames(profile.frames_path, profile.layout)
		sprite.sprite_frames = frames
		var motion = MOTION.new()
		motion.profile = profile
		for direction in range(8):
			for role: String in ["idle", "walk", "attack", "hit", "death"]:
				var track := role + "_" + str(direction)
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
		var source_before := frames.get_frame_count("walk_0")
		profile.color_tint = Color.WHITE
		check(frames.get_frame_count("walk_0") == source_before, "palette does not mutate cached source " + key)
	print("PR122_PALETTE_MOTION_OK checks=%d profiles=54 native_approvals_added=0 failures=%d" % [assertions, failures.size()])
	sprite.queue_free()
	quit(0 if failures.is_empty() else 1)
