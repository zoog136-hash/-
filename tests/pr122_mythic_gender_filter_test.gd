extends SceneTree

const POLICY = preload("res://scripts/mythic_gender_filter.gd")
const CATALOG = "res://data/catalog_v19.json"
const EXCLUDED_IDS = ["131", "410", "132", "134", "136", "138", "140", "142", "161", "345", "258", "283"]
const KEPT_IDS = ["130", "212", "133", "135", "137", "139", "141", "411", "346", "174", "412", "413"]

func _initialize() -> void:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
    assert(parsed is Dictionary, "catalog must parse")
    var catalog: Dictionary = parsed as Dictionary
    var original: Array = catalog.get("변신", []) as Array
    var original_count := original.size()
    POLICY.filter_catalog(catalog)
    var filtered: Array = catalog.get("변신", []) as Array
    assert(filtered.size() == original_count - 12, "exactly 12 variants must be excluded")
    var ids: Dictionary = {}
    for raw: Variant in filtered:
        if raw is Dictionary:
            ids[str((raw as Dictionary).get("sourceId", ""))] = true
    for id: String in EXCLUDED_IDS:
        assert(not ids.has(id), "excluded mythic variant leaked: " + id)
    for id: String in KEPT_IDS:
        assert(ids.has(id), "required mythic variant missing: " + id)
    POLICY.filter_catalog(catalog)
    assert((catalog.get("변신", []) as Array).size() == filtered.size(), "filter must be idempotent")
    print("PR122_MYTHIC_GENDER_FILTER_OK: %d -> %d" % [original_count, filtered.size()])
    quit(0)
