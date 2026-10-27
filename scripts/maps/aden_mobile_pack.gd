extends RefCounted
## Immutable deployment receipt. Raw .bin payloads bypass texture re-import and
## decode one bounded visible asset at a time through NativePngRenderer.
const ROOT="res://assets/maps/aden_world_mobile/"
const RECEIPT="res://data/maps/aden_mobile_pack.json"
static var cached: Dictionary={}
static func pack() -> Dictionary:
	if "--legacy-aden-world-art" in OS.get_cmdline_user_args() or not OS.get_environment("TWILIGHT_ADEN_FAITH_PNG_PACK").is_empty():return {}
	if not cached.is_empty():return cached
	if not FileAccess.file_exists(RECEIPT):return {}
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(RECEIPT))
	if not receipt is Dictionary or FileAccess.get_sha256(ROOT+"manifest.json")!=receipt.get("manifest_sha256",""):return {}
	var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	if not value is Dictionary or value.get("map_id")!="aden_world" or value.get("status")!="READY_WITH_EXISTING_NAVIGATION":return {}
	for row: Dictionary in value.ground+value.assets.values()+[value.overview]:
		var name: String=str(row.file)
		if name.contains("..") or not name.ends_with(".webp.bin") or not FileAccess.file_exists(ROOT+name):return {}
		if row.size[0]<1 or row.size[1]<1 or row.size[0]>2048 or row.size[1]>2048:return {}
	cached=value;return cached
