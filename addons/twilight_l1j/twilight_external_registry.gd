extends RefCounted
class_name TwilightExternalRegistry
## Opt-in, read-only adapter for L1J conversion packs. Not an autoload.
## Does not replace saved item IDs, skills, maps, or game catalogs.
const A3_ITEMS := "res://data/l1j/registry/a3_items_normalized.json"
const GO_ITEMS := "res://data/l1j/registry/go_items_normalized.json"
const GO_NPCS := "res://data/l1j/registry/go_npcs_normalized.json"
const A2_VISUALS := "res://data/l1j/registry/a2_visuals_normalized.json"
var _by_source_id: Dictionary = {}
var _loaded_sources: Dictionary = {}

func load_source(source: String) -> int:
    var path: String = ""
    match source:
        "a3_items": path = A3_ITEMS
        "go_items": path = GO_ITEMS
        "go_npcs": path = GO_NPCS
        "a2_visuals": path = A2_VISUALS
        _: return -1
    if _loaded_sources.has(source):
        return int(_loaded_sources[source])
    if not FileAccess.file_exists(path):
        return 0
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (parsed is Array):
        return -1
    var count: int = 0
    for entry in parsed:
        if not (entry is Dictionary):
            continue
        var id: String = str(entry.get("canonical_candidate_id", ""))
        if id.is_empty() or not id.begins_with("ext:"):
            continue
        if _by_source_id.has(id):
            continue
        _by_source_id[id] = entry
        count += 1
    _loaded_sources[source] = count
    return count

func get_record(source_qualified_id: String) -> Dictionary:
    if not source_qualified_id.begins_with("ext:"):
        return {}
    var entry: Variant = _by_source_id.get(source_qualified_id, {})
    if entry is Dictionary:
        return (entry as Dictionary).duplicate(true)
    return {}

func get_inventory_icon_path(source_qualified_id: String) -> String:
    var texture_path: String = str(get_record(source_qualified_id).get("inventory_texture", ""))
    if texture_path.begins_with("res://assets/l1j/") and ResourceLoader.exists(texture_path):
        return texture_path
    return ""

func get_ground_icon_path(source_qualified_id: String) -> String:
    var texture_path: String = str(get_record(source_qualified_id).get("ground_texture", ""))
    if texture_path.begins_with("res://assets/l1j/") and ResourceLoader.exists(texture_path):
        return texture_path
    return ""
