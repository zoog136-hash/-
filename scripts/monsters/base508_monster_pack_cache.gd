extends RefCounted
## Shared immutable pack metadata and prepared tracks. Actor clocks remain local.
const POLICY = preload("res://scripts/animation/source_playback_policy.gd")
static var _packs: Dictionary = {}
static var _tracks: Dictionary = {}
static var _verified_pixels: Dictionary = {}
static var _models: Dictionary = {}
static func manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var signature: String = str(FileAccess.get_modified_time(path)) + ":" + str(_file_size(path))
	var cached: Dictionary = _packs.get(path, {})
	if str(cached.get("signature", "")) == signature: return cached.data
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or value.get("source_snapshot", "") != "base508" or value.get("kind", "") != "base508_monster_pack": return {}
	if _packs.size() >= 4 and not _packs.has(path): _packs.erase(_packs.keys()[0])
	_packs[path] = {"signature":signature,"data":value}
	return value
static func prepared_tracks(path: String, actor_id: int, actor: Dictionary, mode: String) -> Dictionary:
	var signature: String = str(_packs.get(path, {}).get("signature", ""))
	var key: String = path + ":" + signature + ":" + str(int(actor.get("sprite_id", actor_id))) + ":" + mode
	if not _tracks.has(key):
		if _tracks.size() >= 8: _tracks.erase(_tracks.keys()[0])
		_tracks[key] = POLICY.tracks(actor, "monster", mode)
	return _tracks[key]
static func verify_pixel(path: String, expected_sha256: String) -> bool:
	var key: String = path + ":" + expected_sha256
	if _verified_pixels.has(key): return true
	if expected_sha256.length() != 64 or not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != expected_sha256: return false
	_verified_pixels[key] = true
	return true
static func clear() -> void:
	_packs.clear()
	_tracks.clear()
	_verified_pixels.clear()
	_models.clear()

static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else -1

static func actor(path: String, npc_id: int) -> Dictionary:
	var value: Dictionary = manifest(path).get("records", {}).get(str(npc_id), {})
	if value.is_empty() or not value.has("tracks_ref"): return value
	var relative: String = str(value.tracks_ref)
	if not relative.begins_with("actors/") or not relative.ends_with(".json") or ".." in relative.split("/") or relative.contains(":") or relative.contains("\\"): return {}
	var full: String = path.get_base_dir().path_join(relative)
	var expected: String = str(value.get("tracks_sha256", ""))
	var key: String = full + ":" + expected
	if not _models.has(key):
		if expected.length() != 64 or FileAccess.get_sha256(full) != expected: return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(full))
		if not parsed is Dictionary: return {}
		if _models.size() >= 8: _models.erase(_models.keys()[0])
		_models[key] = parsed
	var model: Dictionary = _models[key]
	if int(model.get("source_sprite_id", -1)) != int(value.get("sprite_id", -2)): return {}
	var result: Dictionary = value.duplicate(false)
	for field: String in ["tracks", "body_id", "shadow_ids", "clothes_ids", "source_sprite_id"]:
		result[field] = model.get(field)
	return result
