extends Node2D
## Read-only legacy-tint preview. NOT a completed masked-palette asset.

const INDEX := "res://data/pr122_palette_alias_parallel/preview_targets.json"
const PROFILES := "res://data/combat_animation_profiles.json"
@export var target_id: String = ""
var sprite: AnimatedSprite2D
var source_frames: SpriteFrames
var last_error: String = ""

func _fail(message: String) -> void:
	last_error = message
	push_error("PR122 palette preview: " + message)

func _ready() -> void:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	var catalogue: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
	if not index is Dictionary or not catalogue is Dictionary:
		_fail("Missing index or catalogue")
		return
	var entry: Dictionary = {}
	for item in index.get("entries", []):
		if item is Dictionary and item.get("target", "") == target_id:
			entry = item
			break
	var profiles: Dictionary = catalogue.get("profiles", {})
	if entry.is_empty() or not profiles.has(target_id):
		_fail("Unknown target: " + target_id)
		return
	var profile: Dictionary = profiles[target_id]
	for field in ["name", "frames_path", "color_tint"]:
		if profile.get(field, "") != entry.get(field, ""):
			_fail("Target changed; refresh preview instead of overriding: " + field)
			return
	var frames_path: String = entry["frames_path"]
	if FileAccess.get_sha256(frames_path) != index.get("source_frames_sha256", ""):
		_fail("Source frames changed or are missing")
		return
	source_frames = load(frames_path) as SpriteFrames
	if source_frames == null:
		_fail("Source is not SpriteFrames")
		return
	sprite = AnimatedSprite2D.new()
	sprite.name = "ReadOnlyPreviewSprite"
	sprite.sprite_frames = source_frames
	# Keep colour local to this instance; never change the shared SpriteFrames,
	# texture, material, source profile or game combat timing.
	sprite.self_modulate = Color.from_string(entry["color_tint"], Color.WHITE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var offset_values: Array = profile.get("sprite_offset", [0.0, 0.0])
	sprite.offset = Vector2(float(offset_values[0]), float(offset_values[1]))
	var pixel_scale: float = float(profile.get("pixel_scale", 1.0))
	sprite.scale = Vector2.ONE * pixel_scale
	add_child(sprite)
	set_meta("target_id", target_id)
	set_meta("production_ready", false)
	var label := Label.new()
	label.text = str(entry["name"]) + "\n" + target_id + " | PREVIEW / HOLD"
	label.position = Vector2(-115.0, 135.0)
	add_child(label)
	play_track(&"idle_0")

func play_track(track: StringName) -> bool:
	if sprite == null or not source_frames.has_animation(track):
		return false  # Missing run is NOT silently replaced by walk.
	sprite.stop()
	sprite.play(track)
	return true
