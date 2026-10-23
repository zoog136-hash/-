extends SceneTree
## Synthetic textures in memory only. No production clip is reviewed/applied.
const PLAYER: Script = preload("res://docs/remake/pr122-legendary-parallel/legendary_registered_clip_player_v01.gd")
const LIBRARY: Script = preload("res://docs/remake/pr122-legendary-parallel/legendary_revision_library_v01.gd")
var _player: Node2D
var _seen: Dictionary = {}
var _errors: Array[String] = []
var _expected_height: float = 300.0

func _initialize() -> void:
	Engine.max_fps = 120
	call_deferred("_run")

func _check() -> void:
	if _player.sprite.sprite_frames == null:
		return
	_seen[_player.sprite.frame] = true
	if not _player.frame_anchor_in_parent().is_equal_approx(Vector2.ZERO):
		_errors.append("Foot anchor moved on frame " + str(_player.sprite.frame))
	var body_height: float = 100.0 if _player.sprite.frame % 2 == 0 else 600.0
	if not is_equal_approx(body_height * _player.sprite.scale.y, _expected_height):
		_errors.append("Visible scale changed on frame " + str(_player.sprite.frame))

func _run() -> void:
	var scene: PackedScene = load("res://docs/remake/pr122-legendary-parallel/legendary_registered_clip_player_v01.tscn") as PackedScene
	var independent: Node = scene.instantiate()
	independent.free()
	var library: RefCounted = LIBRARY.new()
	if library == null:
		_errors.append("Standalone library cannot instantiate")
	_player = PLAYER.new()
	root.add_child(_player)
	_player.position = Vector2(230.0, 90.0)
	_player.scale = Vector2(2.0, 2.0)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"death_2")
	frames.set_animation_loop(&"death_2", false)
	frames.set_animation_speed(&"death_2", 12.0)
	var entries: Array = []
	for i: int in range(6):
		var native: bool = i % 2 == 0
		var dimensions := Vector2i(100, 160) if native else Vector2i(600, 960)
		var image: Image = Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		image.fill_rect(Rect2i(20, 40, 60, 100) if native else Rect2i(120, 240, 360, 600), Color.CORNFLOWER_BLUE)
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		frames.add_frame(&"death_2", texture, 1.0)
		entries.append({"index": i, "scale": [3.0, 3.0] if native else [0.5, 0.5],
			"anchor_in_texture": [50.0, 140.0] if native else [300.0, 840.0], "target_anchor": [0.0, 0.0]})
	_player._registration = {"frames": entries}
	_player._clip_role = "death"
	_player._clip_animation = &"death_2"
	_player.sprite.sprite_frames = frames
	_player.sprite.animation = &"death_2"
	_player.sprite.frame_changed.connect(_check)
	_player.play_clip()
	_check()
	for iteration: int in range(180):
		await process_frame
		if _player.is_terminal_held():
			break
	for iteration: int in range(8):
		await process_frame
	if _seen.size() != 6:
		_errors.append("Did not observe all six real frame changes")
	if not _player.is_terminal_held() or _player.sprite.frame != 5 or _player.sprite.is_playing():
		_errors.append("Death must play once and hold frame five")
	if _player.position != Vector2(230.0, 90.0) or _player.scale != Vector2(2.0, 2.0):
		_errors.append("Caller root transform was changed")
	if not _player.last_error.is_empty():
		_errors.append(_player.last_error)
	# The second pass is another synthetic case, not another production review.
	# Reproduce ActorMotion's256/original-canvas rule separately from semantic
	# calibration. Existing derivative padding must not enter its denominator.
	_seen.clear()
	_expected_height = 160.0
	for i: int in range(6):
		entries[i]["scale"] = [1.0, 1.0]
		entries[i]["original_virtual_canvas"] = [100.0, 160.0] if i % 2 == 0 else [600.0, 960.0]
	_player._registration = {"status": "RASTER_COORDINATE_PRESERVATION", "frames": entries}
	_player.play_clip()
	_check()
	for iteration: int in range(180):
		await process_frame
		if _player.is_terminal_held():
			break
	if _seen.size() != 6 or not _player.is_terminal_held():
		_errors.append("Existing canvas-normalization policy playback failed")
	print(JSON.stringify({"test": "SYNTHETIC_REGISTERED_PLAYER_ONLY", "seen_frames": _seen.size(),
		"errors": _errors, "runtime_canvas_policy": "PASS" if _errors.is_empty() else "FAIL", "production_clips_run": 0, "source_PNG_mutations": 0, "engine": Engine.get_version_info().get("string", "")}))
	quit(0 if _errors.is_empty() else 1)
