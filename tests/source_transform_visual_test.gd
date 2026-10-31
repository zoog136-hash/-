extends SceneTree
const TexturePixels = preload("res://tests/texture_pixels.gd")

const CATALOG = preload("res://scripts/animation/animation_catalog.gd")
const SOURCE = preload("res://scripts/animation/source_transform_catalog.gd")
const MOTION = preload("res://scripts/animation/actor_motion.gd")
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func check(value: bool, detail: String) -> void:
	if not value:
		failures.append(detail)
		print("SOURCE_TRANSFORM_FAIL " + detail)

func _run() -> void:
	var db: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE.MANIFEST_PATH))
	var reviewed: Dictionary = manifest.entries
	var count: int = 0
	for record: Dictionary in db["변신"]:
		var key: String = "transform:" + str(record.sourceId)
		SOURCE.entries = {"disabled": {}}
		var baseline: Resource = CATALOG.for_record("transform", record)
		SOURCE.entries = reviewed
		var profile: Resource = CATALOG.for_record("transform", record)
		for property: String in ["layout", "motion_style", "movement_fps", "movement_cadence_width_ratio", "reference_speed", "attack_hit_ratio", "attack_hit_frame", "action_hit_frames", "attack_animation_speed", "collision_offset", "projectile_origin", "hit_position", "shadow_size", "death_duration", "use_profile_hit_ratio"]:
			check(profile.get(property) == baseline.get(property), key + " preserved " + property)
		for direction: int in range(8):
			var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
			check(profile.projectile_offset(aim) == baseline.projectile_offset(aim), key + " projectile " + str(direction))
		if not reviewed.has(key):
			check(profile.frames_path == baseline.frames_path, "unselected identity preserved " + key)
			continue
		count += 1
		var entry: Dictionary = reviewed[key]
		check(record.grade == entry.grade and profile.frames_path == entry.frames_path, key + " exact catalog connection")
		var frames: SpriteFrames = CATALOG.frames_for_profile(profile, "")
		var motion: RefCounted = MOTION.new()
		motion.profile = profile
		for direction: int in range(8):
			motion.facing8 = direction
			for role: String in ["idle", "walk", "run", "turn", "attack", "ranged_attack", "cast", "special", "hit", "death", "corpse", "recovery", "summon", "despawn"]:
				var animation := role + "_" + str(direction)
				check(frames.has_animation(animation) and frames.get_frame_count(animation) > 0, key + " complete same-model " + animation)
				motion.state = role
				motion._resolve_frames(frames)
				check(not motion._resolved_key.is_empty(), key + " state resolved " + animation)
		var foot: Vector2 = Vector2(float(entry.foot_in_canvas[0]), float(entry.foot_in_canvas[1]))
		var bounds: Array = entry.canvas_original_grid
		var center := Vector2(float(bounds[2]-bounds[0]), float(bounds[3]-bounds[1])) * 0.5
		check((profile.sprite_offset + (foot-center)*Vector2(0.90,1.0)*profile.pixel_scale).is_zero_approx(), key + " foot remains actor root")
		for file: String in entry.files_sha256:
			check(FileAccess.get_sha256(profile.frames_path.get_base_dir()+"/"+file) == entry.files_sha256[file], key + " runtime SHA " + file)
		for path: String in entry.get("shared_files_sha256", {}):
			check(FileAccess.get_sha256(path) == entry.shared_files_sha256[path], key + " shared original SHA " + path)
		if entry.get("reuse_without_png_copy", false):
			var originals: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/reviewed_source_monsters.json"))
			for source_record: Dictionary in originals.records:
				if str(source_record.source_npc_id) != str(entry.source_npc_id): continue
				var source_frames: SpriteFrames = load(source_record.animation_profile.frames_path)
				for role: String in ["idle", "walk", "run", "attack", "hit", "death"]:
					for facing: int in range(8):
						var track: String = role + "_" + str(facing)
						check(frames.get_frame_count(track) == source_frames.get_frame_count(track), key + " reused sequence " + track)
						for index: int in range(frames.get_frame_count(track)):
							check(TexturePixels.image_of(frames.get_frame_texture(track,index)).get_data() == TexturePixels.image_of(source_frames.get_frame_texture(track,index)).get_data(), key + " reused frame pixels " + track)
							check(frames.get_frame_duration(track,index) == source_frames.get_frame_duration(track,index), key + " reused frame timing " + track)
	check(count == reviewed.size() and count >= 8, "all individually reviewed connections")
	SOURCE.entries = reviewed
	print("SOURCE_TRANSFORM_VISUAL_RESULT entries=" + str(count) + " failures=" + str(failures.size()) + " headings=[3,4,5,6,7,0,1,2]")
	quit(0 if failures.is_empty() else 1)
