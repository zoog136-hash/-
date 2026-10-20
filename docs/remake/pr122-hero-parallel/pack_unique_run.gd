extends SceneTree
## Lossless AtlasTexture registration only; never resize or repaint source art.
const FOLDER := "res://assets/actors/eight_direction/hero_parallel/baphomet_unique/r001/"

func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	assert(not FileAccess.file_exists(FOLDER + "RunSpriteFrames.tres"))
	var image := Image.new()
	assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(FOLDER + "source-run.png")) == OK)
	assert(image.get_width() % 6 == 0 and image.get_height() % 8 == 0)
	var cell := Vector2i(image.get_width() / 6, image.get_height() / 8)
	assert(cell == Vector2i(181, 181))
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(FOLDER + "source-run.png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var poses: Array = []
	for direction: int in range(8):
		var track := "run_" + str(direction)
		frames.add_animation(track)
		frames.set_animation_speed(track, 18.0)
		frames.set_animation_loop(track, true)
		var unique: Dictionary = {}
		for phase: int in range(6):
			var region := Rect2i(phase * cell.x, direction * cell.y, cell.x, cell.y)
			var digest := HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(image.get_region(region).get_data())
			var sha := digest.finish().hex_encode()
			assert(not unique.has(sha))
			unique[sha] = true
			var view := AtlasTexture.new()
			view.atlas = texture
			view.region = Rect2(region)
			view.margin = Rect2(37, 37, 75, 75)
			view.filter_clip = true
			frames.add_frame(track, view)
			poses.append({"direction": direction, "phase": phase, "source_region": [region.position.x, region.position.y, cell.x, cell.y], "source_rgba_sha256": sha})
	frames.set_meta("twilight_native_locomotion_staging", true)
	frames.set_meta("hero_parallel_candidate", true)
	frames.set_meta("scope", "RUN_ONLY_NEW_ART_QUALITY_HOLD_NOT_FULL_ACTOR")
	frames.set_meta("final_approved", false)
	assert(ResourceSaver.save(frames, FOLDER + "RunSpriteFrames.tres") == OK)
	var proof := {"engine": Engine.get_version_info().string, "source_sha256": FileAccess.get_sha256(FOLDER + "source-run.png"), "registration": "181px exact source cells; 37px top-left padding; 256px virtual canvas; no resampling", "roles": ["run"], "missing_roles": ["idle", "attack", "hit", "death"], "identity_contact_camera_approval": false, "final_approved": false, "frames": poses}
	var file := FileAccess.open(FOLDER + "registration.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(proof, "  ") + "\n")
	print("HERO_UNIQUE_RUN_PACK_PASS directions=8 poses=48 source_pixels_unchanged=true full_actor_approval=0")
	quit(0)
