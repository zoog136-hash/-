extends RefCounted
class_name TwilightExternalSPXActor

# Explicitly reviewed local-only assets. Never infer a character class, monster
# name or other source identity from a numeric filename.
const PREFIX := "res://assets/external_spx/actors/"
const ACTOR_IDS := ["21624", "21653"]
const ROLES := ["idle", "walk", "attack", "hit"]
static var _cache: Dictionary = {}

static func available(id: String) -> bool:
	return frames(id) != null

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
