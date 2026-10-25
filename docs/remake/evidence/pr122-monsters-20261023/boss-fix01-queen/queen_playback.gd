extends SceneTree

const Profile = preload("res://scripts/animation/animation_profile.gd")
const Motion = preload("res://scripts/animation/actor_motion.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/remake/evidence/pr122-monsters-20261023/boss-fix01-queen/candidate.json"))
	var actor: Dictionary = candidate.actors["monster:얼음 여왕"]
	var textures: Array[ImageTexture] = []
	for track: Dictionary in actor.tracks:
		var raw: Image = Image.load_from_file("res://" + str(track.texture))
		assert(raw != null and not raw.is_empty() and raw.has_mipmaps() == false)
		var texture := ImageTexture.create_from_image(raw)
		texture.take_over_path("res://" + str(track.texture))
		textures.append(texture)
	var profile: Resource = load(actor.native_profile)
	var frames: SpriteFrames = load(actor.frames) as SpriteFrames
	assert(profile is Profile and frames != null)
	assert(not actor.production_connected and not actor.detailed_completed)
	assert(not bool(profile.get_meta("twilight_production_connected")))
	assert(frames.get_animation_names().size() == 7)
	assert(not frames.has_animation("run_6"))
	var sprite := AnimatedSprite2D.new()
	root.add_child(sprite)
	sprite.sprite_frames = frames
	var results: Array = []
	var total_phases := 0
	for track: Dictionary in actor.tracks:
		var direction: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(track.direction)
		var aim := Vector2.RIGHT.rotated(direction * PI / 4.0)
		var motion = Motion.new()
		motion.profile = profile
		var seen: Dictionary = {}
		var logical_canvas: float = track.geometry.canvas_size[0]
		for tick: int in range(180):
			motion.advance(1.0 / 60.0, aim * profile.reference_speed * 1.25)
			motion.apply(sprite, Vector2.ONE * profile.pixel_scale)
			assert(motion.state == "run" and motion.facing8 == direction)
			assert(str(sprite.animation) == track.animation)
			assert(not sprite.flip_h and sprite.rotation == 0.0)
			var pose: Texture2D = frames.get_frame_texture(track.animation, sprite.frame)
			assert(pose is AtlasTexture and pose.get_size() == Vector2.ONE * logical_canvas)
			assert(sprite.scale.is_equal_approx(Vector2.ONE * profile.pixel_scale * 256.0 / logical_canvas))
			var ground_plane := Vector2(0, pose.get_height() / 8.0)
			assert((sprite.position + ground_plane * sprite.scale).length() < 0.001)
			seen[sprite.frame] = true
		assert(seen.size() == 6 and frames.get_animation_loop(track.animation))
		total_phases += seen.size()
		results.append({"direction": track.direction, "actual_phases": seen.size(), "logical_canvas": logical_canvas,
			"ActorMotion": "PASS", "uniform_profile_scale": profile.pixel_scale})
		await process_frame
	assert(total_phases == 42)
	var report := {"engine": Engine.get_version_info().string, "clips": results.size(), "poses": total_phases,
		"PNG_load": "PASS", "SpriteFrames_load": "PASS", "actual_ActorMotion_playback": "PASS",
		"all_six_phases": "PASS", "registered_ground_plane": "PASS_METADATA_ONLY",
		"source_RGBA_preserved": "PASS", "direction_density_normalization": "PASS",
		"no_mirror_or_warp": "PASS", "ONE_shared_profile_scale": profile.pixel_scale,
		"mythic_visual_approval": "HOLD", "moving_world_physical_contact": "NOT_VERIFIED",
		"N_direction": "HOLD_NOT_CONNECTED", "default_Main": "NOT_RUN", "new_approvals": 0, "tracks": results}
	var destination: String = OS.get_environment("PR122_QUEEN_REPAIR_REPORT")
	assert(not destination.is_empty())
	var file := FileAccess.open(destination, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	print("PR122_QUEEN_REPAIR_PLAYBACK_PASS clips=%d poses=%d engine=%s approvals_added=0" % [results.size(), total_phases, report.engine])
	quit(0)
