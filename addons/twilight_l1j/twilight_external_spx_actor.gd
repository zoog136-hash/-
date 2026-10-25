extends RefCounted
class_name TwilightExternalSPXActor

# Explicitly reviewed local-only assets. Never infer a character class, monster
# name or other source identity from a numeric filename.
const PREFIX := "res://assets/external_spx/actors/"
const ACTOR_IDS := ["21624", "21653"]
const ROLES := ["idle", "walk", "attack", "hit"]
# Two explicitly unapproved visual comparison candidates. Never infer production identity.
const TRANSFORM_REVIEW_CANDIDATES := {"transform:142":"21624", "transform:411":"21653"}
static var _cache: Dictionary = {}

static func actor_metadata(id: String) -> Dictionary:
	if not ACTOR_IDS.has(id): return {}
	var path := "res://data/external_spx/actors_manifest.json"
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return {}
	var actors: Variant = parsed.get("actors", {})
	if not actors is Dictionary: return {}
	var value: Variant = actors.get(id, {})
	return value as Dictionary if value is Dictionary else {}

static func review_transform_source(profile_id: String) -> String:
	return str(TRANSFORM_REVIEW_CANDIDATES.get(profile_id, ""))

# Reject partial or synthetic four-role art. Only full local chain-sword poses.
static func chain_review_available(id: String) -> bool:
	if not ACTOR_IDS.has(id): return false
	var metadata: Dictionary = actor_metadata(id)
	var canvas: Variant = metadata.get("canvas", [])
	var foot: Variant = metadata.get("foot_pixel", [])
	if not (canvas is Array and (canvas as Array).size() == 2): return false
	if not (foot is Array and (foot as Array).size() == 2): return false
	if float(metadata.get("reference_body_height", 0.0)) <= 0.0: return false
	var source: SpriteFrames = frames(id)
	if source == null: return false
	for role: String in ROLES:
		for direction: int in range(8):
			var animation: String = role + "_chain_" + str(direction)
			if not source.has_animation(animation): return false
			if source.get_frame_count(animation) < 2: return false
			for frame: int in range(source.get_frame_count(animation)):
				if source.get_frame_texture(animation, frame) == null: return false
	return true

static func available(id: String) -> bool:
	return frames(id) != null

static func effects_frames(id: String) -> SpriteFrames:
	if not ACTOR_IDS.has(id): return null
	var key: String = id + ":effects"
	if _cache.has(key): return _cache[key]
	var path: String = PREFIX + id + "/EffectsFrames.tres"
	if not ResourceLoader.exists(path): return null
	var loaded: SpriteFrames = load(path) as SpriteFrames
	var body: SpriteFrames = frames(id)
	if loaded == null or body == null: return null
	for animation: String in body.get_animation_names():
		if not loaded.has_animation(animation) or loaded.get_frame_count(animation) != body.get_frame_count(animation): return null
		if not is_equal_approx(loaded.get_animation_speed(animation), body.get_animation_speed(animation)): return null
		if loaded.get_animation_loop(animation) != body.get_animation_loop(animation): return null
		for index in range(body.get_frame_count(animation)):
			if not is_equal_approx(loaded.get_frame_duration(animation,index), body.get_frame_duration(animation,index)): return null
	_cache[key] = loaded
	return loaded

static func frames(id: String) -> SpriteFrames:
	if not ACTOR_IDS.has(id): return null
	if _cache.has(id): return _cache[id]
	var path: String = PREFIX + id + "/SpriteFrames.tres"
	if not ResourceLoader.exists(path): return null
	var loaded: SpriteFrames = load(path) as SpriteFrames
	if loaded == null: return null
	for role: String in ROLES:
		for direction: int in range(8):
			var animation: String = role + "_" + str(direction)
			if not loaded.has_animation(animation): return null
			var count: int = loaded.get_frame_count(animation)
			if count < 2 or count > 40: return null
			for frame: int in range(count):
				if loaded.get_frame_texture(animation, frame) == null: return null
	_cache[id] = loaded
	return loaded

static func clear_cache() -> void:
	_cache.clear()
