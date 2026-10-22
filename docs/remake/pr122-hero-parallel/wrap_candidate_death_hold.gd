extends SceneTree
## Opt-in wrapper resources. Existing artwork, clips and profiles stay immutable.
const BASE := "res://assets/actors/eight_direction/hero_parallel/death_hold_review/"

func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var mapped: Dictionary = {}
	var count := 0
	for sid: String in ["179", "182", "231", "260", "11", "7", "197", "276"]:
		var entry: Dictionary = staging.actors["transform:" + sid]
		assert(not entry.final_approved)
		var original_frames := str(entry.frames)
		assert(not original_frames.begins_with(BASE), "Do not wrap an existing wrapper")
		var original_profile := str(entry.native_profile)
		if not mapped.has(original_frames):
			var source: SpriteFrames = load(original_frames)
			var copy: SpriteFrames = source.duplicate(true)
			for direction: int in range(8):
				var track := "death_" + str(direction)
				assert(source.has_animation(track) and copy.get_frame_count(track) == source.get_frame_count(track))
			copy.set_meta("pr122_hero_hold_final_death_frame", true)
			copy.set_meta("pr122_hero_motion_source_directory", str(entry.rig).get_base_dir())
			var key := "transform_" + sid
			var path := BASE + key + "/r001/SpriteFrames.tres"
			assert(not FileAccess.file_exists(path))
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			assert(ResourceSaver.save(copy, path) == OK)
			mapped[original_frames] = path
		var profile: Resource = load(original_profile).duplicate(true)
		profile.frames_path = str(mapped[original_frames])
		var output := BASE + "profiles/" + sid + "/r001/NativeMotionProfile.tres"
		assert(not FileAccess.file_exists(output))
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		assert(ResourceSaver.save(profile, output) == OK)
		entry["death_hold_review_source"] = {"frames": original_frames, "native_profile": original_profile, "prior_main_validation_report": entry.get("main_validation_report", ""), "runtime_patch_applied_to_branch": false}
		entry.frames = str(mapped[original_frames])
		entry.native_profile = output
		entry.independent_validation = "NOT_RUN_WITH_REVIEW_WRAPPER"
		entry.erase("main_validation_report")
		count += 1
	var file := FileAccess.open("res://data/pr122_hero_parallel_staging.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(staging, "  ") + "\n")
	print("HERO_DEATH_HOLD_WRAPPER_PASS actors=%d source_groups=%d original_asset_writes=0 runtime_patch_applied=false" % [count, mapped.size()])
	quit(0)
