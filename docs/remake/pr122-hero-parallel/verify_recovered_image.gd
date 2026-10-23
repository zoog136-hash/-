extends SceneTree
## Real generated PNG probe; S-only resource is never counted as a full actor.
func _initialize() -> void:
	assert(Engine.get_version_info().string.begins_with("4.7.2"))
	var folder := "res://assets/actors/eight_direction/hero_parallel/death_155/probe_r001/"
	var image := Image.new()
	assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(folder+"source-run-S.png")) == OK)
	assert(image.get_size() == Vector2i(1536,1024))
	var texture := ImageTexture.create_from_image(image)
	texture.take_over_path(folder+"source-run-S.png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("run_2")
	frames.set_animation_speed("run_2",18.0)
	var hashes: Dictionary = {}
	for phase: int in range(6):
		var region := Rect2i((phase%3)*512,(phase/3)*512,512,512)
		var canvas := image.get_region(region)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(canvas.get_data())
		var sha := digest.finish().hex_encode()
		assert(not hashes.has(sha))
		hashes[sha] = true
		var view := AtlasTexture.new()
		view.atlas = texture
		view.region = region
		view.filter_clip = true
		frames.add_frame("run_2",view)
	assert(ResourceSaver.save(frames,folder+"RunSouthProbe.tres") == OK)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.play("run_2")
	for phase: int in range(6):
		sprite.frame = phase
		assert(sprite.frame == phase and sprite.sprite_frames.get_frame_texture("run_2",phase) != null)
	sprite.free()
	print("HERO_RECOVERED_PNG_GODOT_PASS actual_png=true split_cells=6 spriteframes_connected=true full_actor_approved=false")
	quit()
