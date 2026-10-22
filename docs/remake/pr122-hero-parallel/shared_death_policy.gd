extends RefCounted
## Hero authoring only. Runtime remains the existing exact-role resolver.
const SOUTH := 2

static func install_new_south_death(frames: SpriteFrames, south_source: SpriteFrames, source_path: String) -> Dictionary:
	var existing: Array[StringName] = []
	for name: StringName in frames.get_animation_names():
		if str(name).begins_with("death_"): existing.append(name)
	# Never shrink, replace, delete or alias an already authored death library.
	if not existing.is_empty():
		return {"status": "PRESERVED_EXISTING", "existing_tracks": existing.size(), "new_source_directions": 0}
	assert(south_source.get_animation_names().size() == 1)
	assert(south_source.has_animation("death_2"))
	assert(not south_source.get_animation_loop("death_2"))
	var count := south_source.get_frame_count("death_2")
	assert(count >= 2)
	for direction: int in range(8):
		var track := "death_" + str(direction)
		frames.add_animation(track)
		frames.set_animation_loop(track, false)
		frames.set_animation_speed(track, south_source.get_animation_speed("death_2"))
		for phase: int in range(count):
			# Shared object references, not eight copies of authored death pixels.
			frames.add_frame(track, south_source.get_frame_texture("death_2", phase), south_source.get_frame_duration("death_2", phase))
	frames.set_meta("hero_shared_death_source_direction", SOUTH)
	frames.set_meta("hero_shared_death_source_path", source_path)
	frames.set_meta("hero_shared_death_unique_authored_poses", count)
	frames.set_meta("hero_death_policy", "NEW_S_ONLY_20261022")
	return {"status": "NEW_SOUTH_SOURCE_SHARED", "runtime_aliases": 8, "new_source_directions": 1, "unique_source_poses": count}
