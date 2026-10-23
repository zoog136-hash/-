extends RefCounted
class_name TwilightSkillVFXLibrary

## Bounded, pinned atlas cache. Visual admission never gates a combat event.
const PATH := "res://data/skills/authored_vfx.json"
const MAX_ATLASES := 12
var profiles: Dictionary = {}
var preview_profiles: Dictionary = {}
var entries: Dictionary = {}
var clock: int = 0
var denied: int = 0

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		profiles = parsed.get("profiles", {})
		preview_profiles = parsed.get("preview_profiles", {})

func profile_for(id: String) -> Dictionary:
	var visited: Dictionary = {}
	while (profiles.has(id) or preview_profiles.has(id)) and not visited.has(id):
		visited[id] = true
		var profile: Dictionary = profiles.get(id, preview_profiles.get(id, {}))
		if not profile.has("inherits_visual"): return profile
		id = str(profile.inherits_visual)
	return {}

func acquire(id: String) -> Dictionary:
	var profile := profile_for(id)
	var path := str(profile.get("atlas", ""))
	if path.is_empty(): return {}
	clock += 1
	if not entries.has(path):
		if entries.size() >= MAX_ATLASES:
			var victim := ""
			var oldest := 2147483647
			for key: String in entries:
				if int(entries[key].users) == 0 and int(entries[key].stamp) < oldest:
					victim = key
					oldest = int(entries[key].stamp)
			if victim.is_empty():
				denied += 1
				return {}
			entries.erase(victim)
		if not ResourceLoader.exists(path): return {}
		var atlas := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if atlas == null: return {}
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for phase: String in profile.clips:
			var clip: Dictionary = profile.clips[phase]
			frames.add_animation(phase)
			frames.set_animation_speed(phase, 1000.0)
			frames.set_animation_loop(phase, bool(clip.loop))
			var first := int(clip.first)
			for index: int in range(clip.durations_ms.size()):
				var texture := AtlasTexture.new()
				texture.atlas = atlas
				texture.region = Rect2(((first + index) % 8) * 128, floori(float(first + index) / 8.0) * 128, 128, 128)
				texture.filter_clip = true
				frames.add_frame(phase, texture, float(clip.durations_ms[index]))
		entries[path] = {"frames":frames, "users":0, "stamp":clock}
	entries[path].users += 1
	entries[path].stamp = clock
	return {"frames":entries[path].frames, "key":path, "profile":profile}

func release(key: String) -> void:
	if entries.has(key): entries[key].users = maxi(0, int(entries[key].users) - 1)

func trim() -> void:
	for key: String in entries.keys():
		if int(entries[key].users) == 0: entries.erase(key)

func resident_rgba_bytes() -> int:
	return entries.size() * 1024 * 1024 * 4
