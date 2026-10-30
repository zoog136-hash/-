extends RefCounted

## Similar substitute art is visual-only. Missing private pack preserves fallback.
const ROOT := "res://assets/external_spx/similar_skills/"
var bindings: Dictionary = {}
var effects: Dictionary = {}
const MAX_RGBA_BYTES := 32 * 1024 * 1024
var cache: Dictionary = {}

func release(key: String) -> void:
	if cache.has(key): cache[key].users = maxi(0, int(cache[key].users) - 1)

func resident_bytes() -> int:
	var total := 0
	for entry: Dictionary in cache.values(): total += int(entry.bytes)
	return total

func trim() -> void:
	for key: String in cache.keys():
		if int(cache[key].users) == 0: cache.erase(key)

func _init() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/similar_effects.json"))
	if data is Dictionary: bindings = data.get("bindings", {})
	if FileAccess.file_exists(ROOT + "manifest.json"):
		var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
		if manifest is Dictionary: effects = manifest.get("effects", {})

func binding_for(id: String) -> Dictionary:
	var visited: Dictionary = {}
	while bindings.has(id) and not visited.has(id):
		visited[id] = true
		var entry: Dictionary = bindings[id]
		if not entry.has("inherits_visual"): return entry
		id = str(entry.inherits_visual)
	return {}

func layout_for(id: String, phase: String) -> Dictionary:
	return effects.get(str(binding_for(id).get("phases", {}).get(phase, "")), {})

func frames_for(id: String, phase: String) -> SpriteFrames:
	var key := str(binding_for(id).get("phases", {}).get(phase, ""))
	if not effects.has(key): return null
	if cache.has(key):
		cache[key].users += 1
		return cache[key].frames as SpriteFrames
	var entry: Dictionary = effects[key]
	var path := ROOT + str(entry.atlas)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(entry.sha256): return null
	var image := Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) != OK: return null
	if image.get_width() * image.get_height() > 16777216: return null
	var cost := image.get_width() * image.get_height() * 4
	if cost > MAX_RGBA_BYTES: return null
	while cache.size() >= 8 or resident_bytes() + cost > MAX_RGBA_BYTES:
		var victim := ""
		for candidate: String in cache:
			if int(cache[candidate].users) == 0:
				victim = candidate
				break
		if victim.is_empty(): return null
		cache.erase(victim)
	var atlas := ImageTexture.create_from_image(image)
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(&"source")
	frames.set_animation_loop(&"source", false)
	frames.set_animation_speed(&"source", float(entry.fps))
	for i: int in range(int(entry.count)):
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2((i % int(entry.columns)) * int(entry.width), floori(float(i) / float(entry.columns)) * int(entry.height), int(entry.width), int(entry.height))
		texture.filter_clip = true
		frames.add_frame(&"source", texture)
	# Pin live resources; admission failure falls back without affecting combat.
	cache[key] = {"frames":frames, "bytes":cost, "users":1}
	return frames
