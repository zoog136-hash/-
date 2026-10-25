extends SceneTree
## Optional narrow engine test. Not executed by the direct authoring environment.
const PREVIEW := "res://assets/actors/eight_direction/palette_alias_pr122/Preview.tscn"
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var scene: PackedScene = load(PREVIEW) as PackedScene
	if scene == null:
		push_error("Preview scene did not load")
		quit(1)
		return
	var instance: Node = scene.instantiate()
	root.add_child(instance)
	await process_frame
	instance.set_process(false)
	var red: Node = instance.get_node("Red")
	var blue: Node = instance.get_node("Blue")
	var red_sprite: AnimatedSprite2D = red.get("sprite") as AnimatedSprite2D
	var blue_sprite: AnimatedSprite2D = blue.get("sprite") as AnimatedSprite2D
	if red_sprite == null or blue_sprite == null:
		push_error("Locked source was unavailable or changed")
		quit(1)
		return
	var frames: SpriteFrames = red_sprite.sprite_frames
	_check(frames == blue_sprite.sprite_frames, "Name/color previews must share immutable frames")
	_check(red_sprite.self_modulate != blue_sprite.self_modulate, "Per-instance colors must differ")
	_check(red.get_meta("target_id") != blue.get_meta("target_id"), "IDs must stay distinct")
	_check(not bool(red.get_meta("production_ready")), "Preview cannot claim production approval")
	var before: Color = blue_sprite.self_modulate
	red_sprite.self_modulate = Color.WHITE
	_check(blue_sprite.self_modulate == before, "One instance changed another")
	var seen: Array[int] = []
	red_sprite.frame_changed.connect(func() -> void: seen.append(red_sprite.frame))
	var counts: Dictionary = {"idle": 2, "walk": 3, "attack": 3, "hit": 2, "death": 3}
	for action in counts:
		for direction in range(8):
			var track := StringName("%s_%d" % [action, direction])
			_check(frames.has_animation(track), "Missing " + str(track))
			if not frames.has_animation(track):
				continue
			_check(frames.get_frame_count(track) == int(counts[action]), "Unexpected source frame count")
			var duration: float = 0.0
			for frame in range(frames.get_frame_count(track)):
				duration += frames.get_frame_duration(track, frame)
				var texture: Texture2D = frames.get_frame_texture(track, frame)
				_check(texture != null and texture.get_width() > 0, "Missing source texture")
			seen.clear()
			seen.append(0)
			red.call("play_track", track)
			blue.call("play_track", track)
			await create_timer(duration / maxf(frames.get_animation_speed(track), 0.001) + 0.05).timeout
			for frame in range(frames.get_frame_count(track)):
				_check(seen.has(frame), "Frame was not observed during playback: " + str(track))
	_check(not bool(red.call("play_track", &"run_0")), "Missing run must not become fake walk")
	print(JSON.stringify({"test":"pr122_palette_alias_smoke", "checks":checks, "failures":failures,
		"original_identity_approval":false, "main_integration":false}))
	quit(0 if failures == 0 else 1)
