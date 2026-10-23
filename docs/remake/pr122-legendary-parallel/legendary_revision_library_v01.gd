extends RefCounted
## Standalone runtime library. A viewer or a game can instantiate the same
## Node2D component. Original records are fallback only for unaffected slots.

const PLAYER: Script = preload("res://docs/remake/pr122-legendary-parallel/legendary_registered_clip_player_v01.gd")
var _baseline: Dictionary = {}
var _revisions: Dictionary = {}
var last_error: String = ""

func _slot(key: String, direction: String, role: String) -> String:
	return key + "|" + direction + "|" + role

func configure(staging_path: String, manifest_path: String) -> bool:
	_baseline.clear()
	_revisions.clear()
	last_error = ""
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(staging_path))
	if not raw is Dictionary:
		last_error = "Staging JSON unavailable"
		return false
	for actor: Dictionary in raw.get("actors", []):
		for draft: Dictionary in actor.get("drafts", []):
			_baseline[_slot(str(actor["key"]), str(draft["direction"]), str(draft["role"]))] = draft
	if manifest_path.is_empty():
		return true
	raw = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not raw is Dictionary:
		last_error = "Revision manifest unavailable"
		return false
	var required: Dictionary = {}
	for values: Array in raw.get("dependency_required_slots", []):
		required[_slot(str(values[0]), str(values[1]), str(values[2]))] = true
	for excluded: Dictionary in raw.get("excluded_slots", []):
		var values: Array = excluded["slot"]
		required.erase(_slot(str(values[0]), str(values[1]), str(values[2])))
	for revision: Dictionary in raw.get("revisions", []):
		var values: Array = revision["slot"]
		var slot: String = _slot(str(values[0]), str(values[1]), str(values[2]))
		if not required.has(slot) or _revisions.has(slot):
			last_error = "Unexpected/duplicate revision dependency: " + slot
			return false
		if FileAccess.get_sha256(str(revision.get("record", ""))) != str(revision.get("record_sha256", "")):
			last_error = "Revision record SHA mismatch: " + slot
			return false
		if not str(revision.get("registration_status", "")) in ["REVIEWED_ANCHORS_AND_SCALE", "RASTER_COORDINATE_PRESERVATION"] or str(revision.get("registration", "")).is_empty():
			last_error = "Revision registration not ready: " + slot
			return false
		if FileAccess.get_sha256(str(revision["registration"])) != str(revision.get("registration_sha256", "")):
			last_error = "Registration SHA mismatch: " + slot
			return false
		_revisions[slot] = revision
	if _revisions.size() != required.size():
		last_error = "Dependency closure incomplete; affected guard borrowers must be included or explicitly excluded"
		return false
	return true

func instantiate_clip(key: String, direction: String, role: String) -> Node2D:
	var slot: String = _slot(key, direction, role)
	var chosen: Dictionary = _revisions.get(slot, _baseline.get(slot, {}))
	if chosen.is_empty():
		last_error = "Missing slot: " + slot
		return null
	var player: Node2D = PLAYER.new()
	if not player.configure(str(chosen.get("record", "")), str(chosen.get("registration", ""))):
		last_error = str(player.last_error)
		player.free()
		return null
	return player
