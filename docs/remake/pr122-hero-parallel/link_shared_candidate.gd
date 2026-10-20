extends SceneTree
## Add pending hero profiles to an immutable, already baked body/motion group.
const CATALOG = preload("res://scripts/animation/animation_catalog.gd")

func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	var recipe_name := OS.get_environment("TWILIGHT_HERO_RECIPE")
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/pr122-hero-parallel/recipes.json"))
	assert(recipes.has(recipe_name))
	var recipe: Dictionary = recipes[recipe_name]
	var folder := "res://assets/actors/eight_direction/hero_parallel/" + str(recipe.group) + "/" + str(recipe.revision) + "/"
	var frames: SpriteFrames = load(folder + "SpriteFrames.tres")
	assert(frames != null and frames.get_meta("hero_parallel_candidate", false))
	var proof: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "rig-proof.json"))
	assert(str(proof.source) == str(recipe.source) and FileAccess.get_sha256(str(recipe.source)) == str(proof.source_sha256))
	for direction: int in range(8):
		assert(frames.has_animation("run_" + str(direction)) and frames.get_frame_count("run_" + str(direction)) == 6)
		assert(not frames.has_animation("walk_" + str(direction)))
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog_v19.json"))["변신"]
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var count := 0
	for sid: String in recipe.targets:
		var key := "transform:" + sid
		assert(staging.actors.has(key) and not staging.actors[key].final_approved)
		var entry: Dictionary = staging.actors[key]
		if entry.has("frames"):
			assert(entry.frames == folder + "SpriteFrames.tres")
			continue
		var row: Dictionary = {}
		for item: Dictionary in catalog:
			if str(item.sourceId) == sid: row = item
		assert(not row.is_empty() and row.grade == "영웅")
		var profile: Resource = CATALOG.for_record("transform", row, row.image_path)
		assert(profile.frames_path == str(recipe.source), "Only the same current source body may share the bake")
		profile.frames_path = folder + "SpriteFrames.tres"
		profile.movement_fps = frames.get_animation_speed("run_0")
		profile.set_meta("hero_parallel_candidate", true)
		profile.set_meta("final_approved", false)
		var output := "res://assets/actors/eight_direction/hero_parallel/" + str(recipe.profile_prefix) + sid + "/" + str(recipe.revision) + "/NativeMotionProfile.tres"
		assert(not FileAccess.file_exists(output), "Preserve prior profiles")
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		assert(ResourceSaver.save(profile, output) == OK)
		entry.merge({"frames": folder + "SpriteFrames.tres", "native_profile": output, "rig": folder + "rig-proof.json", "source_donor": str(recipe.source_donor), "source_frames_sha256": str(proof.source_sha256), "new_run_poses": 0, "shared_run_poses": 48, "status": "SHARED_RUN_CANDIDATE_QUALITY_HOLD", "independent_validation": "NOT_RUN", "quality_holds": ["ORIGINAL_CHARACTER_IDENTITY", "ACTUAL_SHOE_CONTACT_AND_CADENCE_NOT_APPROVED", "PALETTE_WEAPON_IDENTITY_REVIEW"], "production_connected": false, "final_approved": false}, true)
		count += 1
	var file := FileAccess.open("res://data/pr122_hero_parallel_staging.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(staging, "  ") + "\n")
	print("HERO_SHARED_PROFILE_PASS added=%d art_writes=0 approvals=0" % count)
	quit(0)
