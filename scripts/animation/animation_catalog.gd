extends RefCounted
class_name TwilightAnimationCatalog

const PROFILE = preload("res://scripts/animation/animation_profile.gd")
const PROFILE_PATH = "res://data/combat_animation_profiles.json"
const VISUALS = preload("res://scripts/animation/visual_manifest.gd")
const PRESENTATION = preload("res://scripts/animation/presentation_catalog.gd")
const SOURCE_TRANSFORMS = preload("res://scripts/animation/source_transform_catalog.gd")
const MAX_FRAME_CACHE = 96
const MAX_FRAME_CACHE_BYTES = 96 * 1024 * 1024
static var records: Dictionary = {}
static var frame_cache: Dictionary = {}
static var frame_weak: Dictionary = {}
static var frame_order: Array[String] = []
static var frame_costs: Dictionary = {}
static var frame_cache_bytes: int = 0

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
	for property: String in ["frames_path", "layout", "motion_style", "movement_fps", "movement_cadence_width_ratio", "reference_speed", "attack_hit_ratio", "attack_hit_frame", "action_hit_frames", "attack_animation_speed", "floating", "dedicated_attack", "animation_names"]:
		if settings.has(property): result.set(property, settings[property])
	result.use_profile_hit_ratio = settings.has("attack_hit_ratio")
	for property: String in ["sprite_offset", "collision_offset", "projectile_origin", "hit_position", "shadow_size"]:
		var value: Variant = settings.get(property)
		if value is Array and value.size() == 2: result.set(property, Vector2(float(value[0]), float(value[1])))
	if not settings.has("attack_hit_ratio"): result.attack_hit_ratio = PROFILE.hit_ratio(result.motion_style)
	if not settings.has("movement_fps"): result.movement_fps = 7.0 if result.motion_style == "heavy" else 9.0
	var authored: Dictionary = VISUALS.record(key)
	if result.frames_path.is_empty() and not authored.is_empty() and ResourceLoader.exists(str(authored.get("atlas", ""))):
		# Keep gameplay hit ratios and attack clocks. Only pose/anchor metadata
		# belongs to the generated local atlas.
		result.frames_path = str(authored.atlas)
		result.layout = "authored4" if int(authored.get("directions", 1)) == 4 else "still"
		result.floating = bool(authored.get("floating", result.floating))
		result.motion_style = str(authored.get("motion_style", result.motion_style))
		result.attack_hit_frame = int(authored.get("attack_hit_frame", 3))
		result.movement_fps = float(authored.get("movement_fps", result.movement_fps))
		var anchor: Array = authored.get("sprite_offset", [0, result.sprite_offset.y])
		result.sprite_offset = Vector2(float(anchor[0]), float(anchor[1]))
	PRESENTATION.configure(result, kind, record)
	# Explicit sequential-art settings outrank the generic portrait rig. Native
	# poses already contain limb motion; moving/rotating the root adds foot slip.
	for property: String in ["pixel_scale", "native_width_ratio", "embedded_shadow", "authored_motion_weight", "hit_recoil", "death_duration", "body_kind"]:
		if settings.has(property): result.set(property, settings[property])
	if settings.has("color_tint"):
		var tint: Variant = settings.color_tint
		if tint is Array and tint.size() == 4:
			result.color_tint = Color(float(tint[0]),float(tint[1]),float(tint[2]),float(tint[3]))
		else:
			result.color_tint = Color.from_string(str(tint), Color.WHITE)
	SOURCE_TRANSFORMS.configure(result, kind, record)
	preload("res://scripts/monsters/reviewed_existing_visuals.gd").configure(result, kind, record)
	return result

static func frames(path: String, layout: String) -> SpriteFrames:
	var key: String = path + ":" + layout
	if frame_cache.has(key):
		frame_order.erase(key)
		frame_order.append(key)
		return frame_cache[key]
	# A live actor may still own a SpriteFrames after its strong lookup entry
	# expires. Reuse that exact resource instead of loading or generating it again.
	var existing: WeakRef=frame_weak.get(key)
	if existing!=null:
		var retained: SpriteFrames=existing.get_ref() as SpriteFrames
		if retained!=null:
			_cache_frames(key,retained)
			return retained
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
	# This bounds only strong lookup references. Active actors and Godot's own
	# resource cache are separate owners, so this is not a whole-game RAM cap.
	var textures: Dictionary = {}
	var bytes: int = 0
	for animation: String in result.get_animation_names():
		for index: int in range(result.get_frame_count(animation)):
			var texture: Texture2D = result.get_frame_texture(animation,index)
			while texture is AtlasTexture: texture = (texture as AtlasTexture).atlas
			if texture != null and not textures.has(texture.get_instance_id()):
				textures[texture.get_instance_id()] = true
				bytes += texture.get_width() * texture.get_height() * 4
	frame_cache_bytes -= int(frame_costs.get(key,0))
	frame_cache[key] = result
	frame_weak[key] = weakref(result)
	frame_costs[key] = bytes
	frame_cache_bytes += bytes
	frame_order.erase(key)
	frame_order.append(key)
	while frame_order.size() > 1 and (frame_order.size() > MAX_FRAME_CACHE or frame_cache_bytes > MAX_FRAME_CACHE_BYTES):
		var old: String = frame_order.pop_front()
		frame_cache_bytes -= int(frame_costs.get(old,0))
		frame_costs.erase(old)
		frame_cache.erase(old)
	if frame_weak.size()>MAX_FRAME_CACHE*4:
		for stale: String in frame_weak.keys():
			if (frame_weak[stale] as WeakRef).get_ref()==null:frame_weak.erase(stale)

static func release_region_frames() -> void:
	# Boss pages are region-specific and much larger than shared outfit sheets.
	# Weak lookup handles still find an actor-owned source during map turnover.
	for key: String in frame_cache.keys():
		if not key.contains("/monster_boss_repair/") and not key.contains("/boss_draft_first/"):continue
		frame_cache.erase(key)
		frame_order.erase(key)
		frame_cache_bytes-=int(frame_costs.get(key,0))
		frame_costs.erase(key)

static func first_texture(source: SpriteFrames) -> Texture2D:
	if source == null: return null
	for animation: String in source.get_animation_names():
		for index: int in range(source.get_frame_count(animation)):
			var texture: Texture2D = source.get_frame_texture(animation, index)
			if texture != null: return texture
	return null

static func frames_for_profile(profile: TwilightAnimationProfile, fallback: String) -> SpriteFrames:
	# Optional authored art must never remove an otherwise valid existing appearance.
	if profile.frames_path.get_extension() in ["tres", "res"] and ResourceLoader.exists(profile.frames_path):
		var authored: SpriteFrames = frames(profile.frames_path, profile.layout)
		if first_texture(authored) != null: return authored
	var from_manifest: SpriteFrames = VISUALS.catalog_frames(profile.profile_id)
	if from_manifest != null: return from_manifest
	if not profile.frames_path.is_empty() and ResourceLoader.exists(profile.frames_path):
		var authored: SpriteFrames = frames(profile.frames_path, profile.layout)
		if first_texture(authored) != null: return authored
	return frames(fallback, profile.layout)
