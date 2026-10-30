extends RefCounted
## Explicit overrides and installed user packs take precedence, even if damaged.
## Validation remains in source_map_runtime; never hide corruption by fallback.
const BUNDLED = "res://external_map_packs/source84_v3"
const USER = "user://source_maps_v3"

static func root_path() -> String:
	var configured: String = OS.get_environment("TWILIGHT_SOURCE_MAP_PACK")
	if not configured.is_empty(): return configured.trim_suffix("/")
	if FileAccess.file_exists(USER + "/index.json"): return USER
	if FileAccess.file_exists(BUNDLED + "/index.json"): return BUNDLED
	return USER
