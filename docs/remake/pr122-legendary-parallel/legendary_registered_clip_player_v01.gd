extends Node2D
## Runtime component, not a viewer adjustment. Root transform belongs to caller;
## the child gets scale+offset synchronously on every AnimatedSprite2D frame.
## Metadata must contain reviewed anatomical anchors/scale, not bbox guesses.

const ALLOWED_ASSETS: String = "res://assets/actors/eight_direction/legendary_parallel/"

var sprite: AnimatedSprite2D
var _textures: Array[ImageTexture] = []
var _registration: Dictionary = {}
var _clip_role: String = ""
var _clip_animation: StringName = &""
var _terminal_held: bool = false
var last_error: String = ""

func _init() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.name = "RegisteredSprite"
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	sprite.frame_changed.connect(_apply_frame_registration)
	sprite.animation_changed.connect(_apply_frame_registration)
	sprite.animation_finished.connect(_finished)

func _fail(message: String) -> bool:
	last_error = message
	sprite.pause()
	return false

func _uri(value: String) -> String:
	return value if value.begins_with("res://") else "res://" + value

func configure(record_path: String, registration_path: String = "") -> bool:
	last_error = ""
	sprite.pause()
	sprite.sprite_frames = null
	_textures.clear()
	_registration.clear()
	_terminal_held = false
	record_path = _uri(record_path)
	if not record_path.begins_with(ALLOWED_ASSETS):
		return _fail("Record outside legendary prefix")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(record_path))
	if not parsed is Dictionary:
		return _fail("Record JSON unavailable: " + record_path)
	var record: Dictionary = parsed
	_clip_role = str(record.get("role", ""))
	var direction_index: int = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"].find(str(record.get("direction", "")))
	if direction_index < 0 or not _clip_role in ["idle", "run", "attack", "hit", "death"]:
		return _fail("Record direction/role invalid")
	_clip_animation = StringName(_clip_role + "_" + str(direction_index))
	if not registration_path.is_empty():
		parsed = JSON.parse_string(FileAccess.get_file_as_string(_uri(registration_path)))
		if not parsed is Dictionary:
			return _fail("Registration metadata unavailable")
		_registration = parsed
		if str(_registration.get("record_sha256", "")) != FileAccess.get_sha256(record_path):
			return _fail("Registration is pinned to another record")
		if str(_registration.get("status", "")) != "REVIEWED_ANCHORS_AND_SCALE":
			return _fail("Registration requires reviewed anchors and scale")
		if _registration.get("frames", []).size() != 6:
			return _fail("Registration requires six frame transforms")
	elif str(record.get("frame_registration_status", "")) == "REVIEWED_METADATA_REQUIRED":
		return _fail("Corrected clip has no reviewed registration metadata")
	var sources: Array = record.get("source_files", [])
	if sources.is_empty():
		sources = [{"path": record.get("source", ""), "sha256": record.get("source_sha256", "")}]
	for source: Dictionary in sources:
		var path: String = _uri(str(source.get("path", "")))
		if not path.begins_with(ALLOWED_ASSETS) or FileAccess.get_sha256(path) != str(source.get("sha256", "")):
			return _fail("Source path/SHA mismatch: " + path)
		var image: Image = Image.load_from_file(path)
		if image == null or image.is_empty():
			return _fail("Source PNG cannot load")
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		texture.take_over_path(path)
		_textures.append(texture)
	var frames_path: String = _uri(str(record.get("output_spriteframes", "")))
	if not frames_path.begins_with(ALLOWED_ASSETS) or FileAccess.get_sha256(frames_path) != str(record.get("output_spriteframes_sha256", "")):
		return _fail("SpriteFrames path/SHA mismatch")
	var frames: SpriteFrames = ResourceLoader.load(frames_path, "SpriteFrames", ResourceLoader.CACHE_MODE_IGNORE) as SpriteFrames
	if frames == null or not frames.has_animation(_clip_animation) or frames.get_frame_count(_clip_animation) != 6:
		return _fail("Exact six-frame animation unavailable")
	if frames.get_animation_loop(_clip_animation) != (_clip_role in ["idle", "run"]):
		return _fail("Loop/once mismatch")
	sprite.sprite_frames = frames
	sprite.animation = _clip_animation
	sprite.frame = 0
	_apply_frame_registration()
	return last_error.is_empty()

func play_clip() -> void:
	if sprite.sprite_frames == null or not last_error.is_empty():
		return
	_terminal_held = false
	sprite.stop()
	sprite.frame = 0
	_apply_frame_registration()
	sprite.play(_clip_animation)

func _apply_frame_registration() -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return
	if _registration.is_empty():
		sprite.scale = Vector2.ONE
		sprite.offset = Vector2.ZERO
		sprite.position = Vector2.ZERO
		return
	var entries: Array = _registration.get("frames", [])
	if sprite.frame >= entries.size():
		_fail("Frame registration missing")
		return
	var entry: Dictionary = entries[sprite.frame]
	var scale_values: Array = entry.get("scale", [])
	var anchor_values: Array = entry.get("anchor_in_texture", [])
	var target_values: Array = entry.get("target_anchor", [0.0, 0.0])
	if int(entry.get("index", -1)) != sprite.frame or scale_values.size() != 2 or anchor_values.size() != 2 or target_values.size() != 2:
		_fail("Invalid frame transform metadata")
		return
	var factor := Vector2(float(scale_values[0]), float(scale_values[1]))
	var anchor := Vector2(float(anchor_values[0]), float(anchor_values[1]))
	var target := Vector2(float(target_values[0]), float(target_values[1]))
	if not factor.is_finite() or not anchor.is_finite() or not target.is_finite() or factor.x <= 0.0 or factor.y <= 0.0 or not is_equal_approx(factor.x, factor.y):
		_fail("Registration must use finite positive uniform scale")
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null:
		_fail("Frame texture unavailable")
		return
	# Godot draws centered texture coordinates at offset-size/2. Therefore the
	# reviewed anchor maps exactly to target, independently of source dimensions.
	sprite.scale = factor
	sprite.offset = texture.get_size() * 0.5 - anchor
	sprite.position = target

func _finished() -> void:
	if _clip_role == "death" and sprite.sprite_frames != null:
		sprite.pause()
		sprite.frame = sprite.sprite_frames.get_frame_count(_clip_animation) - 1
		_apply_frame_registration()
		_terminal_held = true

func is_terminal_held() -> bool:
	return _terminal_held

func frame_anchor_in_parent() -> Vector2:
	if _registration.is_empty() or sprite.sprite_frames == null:
		return Vector2.INF
	var entry: Dictionary = _registration["frames"][sprite.frame]
	var values: Array = entry["anchor_in_texture"]
	var anchor := Vector2(float(values[0]), float(values[1]))
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	return sprite.position + (sprite.offset - texture.get_size() * 0.5 + anchor) * sprite.scale
