extends RefCounted
class_name TwilightAnimationCatalog

const PROFILE = preload("res://scripts/animation/animation_profile.gd")
const PROFILE_PATH = "res://data/combat_animation_profiles.json"
const MAX_FRAME_CACHE = 96
static var records: Dictionary = {}
static var frame_cache: Dictionary = {}
static var frame_order: Array[String] = []

static func for_record(kind: String, record: Dictionary, resource: String = "") -> TwilightAnimationProfile:
	if records.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
		if parsed is Dictionary: records = parsed.get("profiles", {})
	var key: String = kind + ":" + str(record.get("sourceId", record.get("name", "base")))
	var result: TwilightAnimationProfile = PROFILE.new()
	result.profile_id = key
	result.resource_path_hint = resource
	result.layout = "directional4" if resource.begins_with("res://assets/directional/") else "still"
	result.sprite_offset = Vector2(0, -55 if kind == "transform" else (-64 if kind == "relic" else (-15 if kind == "monster" else -26)))
	result.reference_speed = 210.0 if kind == "transform" else (90.0 if kind == "monster" else 180.0)
	var settings: Dictionary = records.get(key, {})
	if record.get("animation_profile", {}) is Dictionary:
		settings = settings.duplicate(true)
		settings.merge(record.get("animation_profile", {}), true)
	for property: String in ["frames_path", "layout", "motion_style", "movement_fps", "reference_speed", "attack_hit_ratio", "attack_hit_frame", "attack_animation_speed", "floating", "dedicated_attack", "animation_names"]:
		if settings.has(property): result.set(property, settings[property])
	result.use_profile_hit_ratio = settings.has("attack_hit_ratio")
	for property: String in ["sprite_offset", "collision_offset", "projectile_origin", "hit_position", "shadow_size"]:
		var value: Variant = settings.get(property)
		if value is Array and value.size() == 2: result.set(property, Vector2(float(value[0]), float(value[1])))
	if not settings.has("attack_hit_ratio"): result.attack_hit_ratio = PROFILE.hit_ratio(result.motion_style)
	if not settings.has("movement_fps"): result.movement_fps = 7.0 if result.motion_style == "heavy" else 9.0
	return result

static func frames(path: String, layout: String) -> SpriteFrames:
	var key: String = path + ":" + layout
	if frame_cache.has(key):
		frame_order.erase(key)
		frame_order.append(key)
		return frame_cache[key]
	var result: SpriteFrames = SpriteFrames.new()
	result.remove_animation("default")
	if path.is_empty() or not ResourceLoader.exists(path): return result
	if path.get_extension() in ["tres", "res"]:
		var authored: SpriteFrames = load(path) as SpriteFrames
		if authored != null:
			_cache_frames(key, authored)
			return authored
	var texture: Texture2D = load(path) as Texture2D
	if texture == null: return result
	var names: Array[String] = ["still"]
	var columns: int = 1
	if layout == "directional4":
		names = ["dir_down", "dir_up", "dir_left", "dir_right"]
		columns = 4
	elif layout == "directional8":
		names = ["dir_0", "dir_1", "dir_2", "dir_3", "dir_4", "dir_5", "dir_6", "dir_7"]
		columns = 4
	elif layout == "class5":
		names = ["walk_down", "walk_up", "walk_left", "walk_right", "attack"]
		columns = 5
	var cell: Vector2 = texture.get_size() / Vector2(columns, names.size())
	for row: int in range(names.size()):
		var name_value: String = names[row]
		result.add_animation(name_value)
		result.set_animation_speed(name_value, 9.0)
		for column: int in range(columns):
			if layout == "still":
				result.add_frame(name_value, texture)
			else:
				var atlas: AtlasTexture = AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(Vector2(column, row) * cell, cell)
				result.add_frame(name_value, atlas)
	result.set_meta("twilight_generated_sheet", true)
	_cache_frames(key, result)
	return result

static func _cache_frames(key: String, result: SpriteFrames) -> void:
	frame_cache[key] = result
	frame_order.append(key)
	while frame_order.size() > MAX_FRAME_CACHE:
		frame_cache.erase(frame_order.pop_front())

static func first_texture(source: SpriteFrames) -> Texture2D:
	if source == null: return null
	for animation: String in source.get_animation_names():
		for index: int in range(source.get_frame_count(animation)):
			var texture: Texture2D = source.get_frame_texture(animation, index)
			if texture != null: return texture
	return null

static func frames_for_profile(profile: TwilightAnimationProfile, fallback: String) -> SpriteFrames:
	# Optional authored art must never remove an otherwise valid existing appearance.
	if not profile.frames_path.is_empty() and ResourceLoader.exists(profile.frames_path):
		var authored: SpriteFrames = frames(profile.frames_path, profile.layout)
		if first_texture(authored) != null: return authored
	return frames(fallback, profile.layout)
