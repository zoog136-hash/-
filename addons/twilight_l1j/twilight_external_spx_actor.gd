extends RefCounted
class_name TwilightExternalSPXActor

# Explicitly reviewed local-only assets. Never infer a character class, monster
# name or other source identity from a numeric filename.
const PREFIX := "res://assets/external_spx/actors/"
const ACTOR_IDS := ["21624", "21653"]
const ROLES := ["idle", "walk", "attack", "hit"]
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
