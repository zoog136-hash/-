extends SceneTree
## Verify the existing unbound track without inventing a movement sizing profile.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var actor: Dictionary = register.actors["transform:399"]
	assert(not actor.has("native_profile") and not actor.production_connected and not actor.detailed_completed)
	assert(actor.tracks.size() == 1 and actor.tracks[0].role == "idle" and actor.tracks[0].direction == "S")
	var path: String = "res://" + str(actor.tracks[0].texture)
	assert(FileAccess.get_sha256(path) == actor.tracks[0].source_sha256)
	var image := Image.new()
	assert(image.load(path) == OK)
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(path)
	var frames: SpriteFrames = load(actor.frames)
	assert(frames.get_animation_names().size() == 1 and frames.has_animation("idle_2"))
	assert(frames.get_frame_count("idle_2") == 6)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	root.add_child(sprite)
	sprite.play("idle_2")
	var seen: Dictionary = {}
	var until: int = Time.get_ticks_msec() + 1500
	while Time.get_ticks_msec() < until:
		await process_frame
		seen[sprite.frame] = true
	assert(seen.size() == 6)
	var result := {"id": "transform:399", "clip": "idle_2", "clips": 1, "poses": 6,
		"observed_phases": seen.keys(), "frames_sha256": FileAccess.get_sha256(actor.frames),
		"source_sha256": FileAccess.get_sha256(path), "engine_playback": true,
		"actual_Main": false, "profile_created": false, "default_connection": false,
		"scale_and_foot_integration": "BLOCKED_NO_AUTHORED_WALK_OR_RUN_REFERENCE",
		"final_quality_approval": false}
	var output := FileAccess.open(OS.get_environment("BOSS_DEFAULT_MAIN_OUTPUT").path_join("unbound-idle.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t")+"\n")
	print("UNBOUND_IDLE_TRACK_PASS " + JSON.stringify(result))
	sprite.queue_free()
	await process_frame
	quit(0)
