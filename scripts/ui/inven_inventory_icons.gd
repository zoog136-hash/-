extends RefCounted
## Inventory-only artwork. Visual aliases NEVER change a gameplay sourceId/name.
const MANIFEST: String = "res://data/inven_inventory_icons.json"
static var _loaded: bool = false
static var _entries: Dictionary = {}
static var _verified: Dictionary = {}

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(MANIFEST):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not (data is Dictionary) or int(data.get("schema", 0)) != 1 or data.get("scope", "") != "inventory_only":
		return
	for value: Variant in data.get("items", []):
		if not (value is Dictionary):
			continue
		var entry: Dictionary = value
		var item_name: String = str(entry.get("name", ""))
		if not item_name.is_empty() and not _entries.has(item_name):
			_entries[item_name] = entry

static func lookup(record: Dictionary, item_name: String) -> Dictionary:
	_ensure()
	if not str(record.get("sourceId", "")).is_empty():
		return {}
	if str(record.get("name", item_name)) != item_name:
		return {}
	var entry: Dictionary = _entries.get(item_name, {})
	if entry.is_empty():
		return {}
	if str(record.get("type", "")) != str(entry.get("type", "")):
		return {}
	if str(record.get("slot", "")) != str(entry.get("slot", "")):
		return {}
	var kind: String = str(entry.get("match_kind", ""))
	if kind not in ["exact_name", "visual_alias"]:
		return {}
	var source: Dictionary = entry.get("art_source", {})
	if kind == "exact_name" and str(source.get("name", "")) != item_name:
		return {}
	var path: String = str(entry.get("path", ""))
	if not (path.begins_with("res://assets/catalog/") or path.begins_with("res://assets/inven_inventory/")):
		return {}
	if not path.ends_with(".png") or ".." in path or "\\" in path:
		return {}
	var digest: String = str(entry.get("sha256", ""))
	if digest.length() != 64 or not digest.is_valid_hex_number(false):
		return {}
	var key: String = path + ":" + digest
	if not _verified.has(key):
		if FileAccess.file_exists(path):
			_verified[key] = FileAccess.get_sha256(path) == digest
		else:
			# Exported PCKs can contain the imported texture without the raw PNG.
			# CI verifies the packaged input bytes before export.
			_verified[key] = ResourceLoader.exists(path)
	if not bool(_verified[key]):
		return {}
	return entry.duplicate(true)
