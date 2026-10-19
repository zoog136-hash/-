extends SceneTree
## No rendering, capture, catalog switch, source alias, or approval operation.
## PNGs enter the resource cache losslessly so no full-project import is needed.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var register: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_native_locomotion_staging.json"))
	var checked_tracks: int = 0
	var checked_poses: int = 0
	var scope: PackedStringArray = OS.get_environment("TWILIGHT_NATIVE_TEST_KEYS").split(",", false)
	for key: String in register.actors:
		if not scope.is_empty() and not scope.has(key): continue
		var actor: Dictionary = register.actors[key]
		assert(not actor.production_connected and not actor.detailed_completed)
		var textures: Array[ImageTexture] = []
		for track: Dictionary in actor.tracks:
			var image: Image = Image.load_from_file("res://" + str(track.texture))
			assert(image != null and not image.is_empty())
			var texture: ImageTexture = ImageTexture.create_from_image(image)
			texture.take_over_path("res://" + str(track.texture))
			textures.append(texture)
		var frames: SpriteFrames = load(actor.frames) as SpriteFrames
		assert(frames != null)
		assert(frames.get_animation_names().size() == int(actor.native_track_count))
		assert(frames.get_meta("twilight_canvas_size") == Vector2(1024, 1024))
		var sprite := AnimatedSprite2D.new()
		root.add_child(sprite)
		sprite.sprite_frames = frames
		var track_index: int = 0
		for track: Dictionary in actor.tracks:
			var animation := StringName(track.animation)
			assert(frames.has_animation(animation))
			var looping: bool = track.role in ["idle", "walk", "run"]
			assert(frames.get_frame_count(animation) == 6 and frames.get_animation_loop(animation) == looping)
			for phase: int in range(6):
				var atlas := frames.get_frame_texture(animation, phase) as AtlasTexture
				var pose: Dictionary = track.geometry.frames[phase]
				var rect: Array = pose.region
				var margin: Array = pose.margin
				assert(atlas != null and atlas.atlas == textures[track_index])
				assert(atlas.region == Rect2(rect[0], rect[1], rect[2], rect[3]))
				assert(atlas.margin == Rect2(margin[0], margin[1], margin[2], margin[3]))
				assert(atlas.get_size() == Vector2(1024, 1024) and atlas.filter_clip)
				checked_poses += 1
			sprite.stop()
			sprite.play(animation)
			var seen: Dictionary = {}
			for tick: int in range(80):
				await process_frame
				seen[sprite.frame] = true
			assert(seen.size() == 6 and sprite.is_playing() == looping)
			if not looping: assert(sprite.frame == 5)
			assert(sprite.animation == animation)
			checked_tracks += 1
			track_index += 1
		for missing: String in actor.missing_locomotion:
			assert(not frames.has_animation(missing))
		for role: String in actor.missing_dedicated_roles:
			for direction: int in range(8):
				var name: String = role + "_" + str(direction)
				if not actor.has("missing_dedicated_by_direction") or actor.missing_dedicated_by_direction[role].has(name):
					assert(not frames.has_animation(name))
		sprite.queue_free()
		await process_frame
	print("PR122_NATIVE_RESOURCE_PASS tracks=%d poses=%d approvals_added=0 engine=%s" % [checked_tracks, checked_poses, Engine.get_version_info().string])
	quit(0)
