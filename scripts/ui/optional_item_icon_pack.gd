extends RefCounted
## Optional, separately installed third-party icons. The public repository
## contains IDs and hashes only; NEVER use family/name aliases to override art.
const MANIFEST: String = "res://data/optional_item_icons_15.json"
const ROOT: String = "res://assets/original_items/inventory/"
static var _loaded: bool = false
static var _entries: Dictionary = {}
static var _verified: Dictionary = {}

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST):
		return
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (manifest is Dictionary) or int(manifest.get("version", 0)) != 1:
		return
	for value: Variant in manifest.get("items", []):
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		var name_value: String = str(entry.get("name", ""))
		if name_value.is_empty() or _entries.has(name_value):
			continue
		_entries[name_value] = entry

static func lookup(record: Dictionary, item_name: String) -> Dictionary:
	_ensure()
	# Never borrow a name-based image for a real sourceId or an ambiguous record.
	if not str(record.get("sourceId", "")).is_empty():
		return {}
	var entry: Dictionary = _entries.get(item_name, {})
	if entry.is_empty():
		return {}
	if str(record.get("name", item_name)) != item_name:
		return {}
	if str(record.get("type", "")) != str(entry.get("type", "")):
		return {}
	if str(record.get("slot", "")) != str(entry.get("slot", "")):
		return {}
	var icon_id: int = int(entry.get("icon_id", 0))
	if icon_id <= 0:
		return {}
	var path: String = ROOT + str(icon_id) + ".png"
	var expected: String = str(entry.get("sha256", "")).to_lower()
	if expected.length() != 64 or not expected.is_valid_hex_number(false):
		return {}
	if _verified.has(item_name):
		return _verified[item_name]
	if not FileAccess.file_exists(path):
		return {}
	if FileAccess.get_sha256(path).to_lower() != expected:
		return {}
	var answer: Dictionary = {"path": path, "icon_id": icon_id, "sha256": expected}
	_verified[item_name] = answer
	return answer
