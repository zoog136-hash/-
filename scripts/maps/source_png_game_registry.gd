extends RefCounted
## Ordinary Oman rendering over the unchanged A3 field. A PNG is not a claim
## that every source obstacle/foreground has been visually reviewed.
const LEGACY=preload("res://scripts/maps/legacy_layout_policy.gd")
const RECEIPT="res://data/maps/oman_png_pack.json"
const BUNDLED="res://external_map_packs/oman_png_v1"
const LAYERS=preload("res://scripts/maps/source_png_review_pack.gd")
const IDS: Array[String]=["oman_01","oman_02","oman_03","oman_04","oman_05","oman_06","oman_07","oman_08","oman_09","oman_10"]
static var seen: bool=false

static func root_path() -> String:
	var configured: String=OS.get_environment("TWILIGHT_OMAN_PNG_PACK")
	if not configured.is_empty():return configured.trim_suffix("/")
	return BUNDLED if FileAccess.file_exists(BUNDLED+"/index.json") else "user://oman_png_maps"

static func requested(id: String) -> bool:
	if not id in IDS:return false
	for flag: String in ["--legacy-map-layouts","--png-review","--no-native-png-auto"]:
		if LEGACY.active(flag):return false
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(RECEIPT))
	if receipt is Dictionary and receipt.get("bundled_required",false)==true:return true
	return seen or not OS.get_environment("TWILIGHT_OMAN_PNG_PACK").is_empty() or FileAccess.file_exists(root_path()+"/index.json")

static func attach(field: RemakePlayableField) -> bool:
	var id: String=str(field.data.map_id)
	if not id in IDS:return false
	var receipt: Variant=JSON.parse_string(FileAccess.get_file_as_string(RECEIPT))
	if not receipt is Dictionary:return false
	var root: String=root_path()
	if not FileAccess.file_exists(root+"/index.json") or FileAccess.get_sha256(root+"/index.json")!=receipt.get("index_sha256",""):return false
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(root+"/index.json"))
	if not index is Dictionary or index.get("schema")!=1 or not index.get("maps") is Dictionary:return false
	var entry: Dictionary=index.maps.get(id,{})
	if entry.get("manifest")!=id+"/manifest.json" or FileAccess.get_sha256(root+"/"+id+"/manifest.json")!=entry.get("sha256",""):return false
	var pack: RefCounted=LAYERS.new()
	if not pack.configure_ordinary(root,field):return false
	field.png_game_pack=pack
	seen=true
	return true
