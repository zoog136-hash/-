extends RefCounted
## Lightweight opt-in entry. No source loading or save routing without the flag.
const FIELD_PATH="res://scripts/maps/base508_game_field.gd"
const RENDERER_PATH="res://scripts/maps/base508_game_renderer.gd"
static var prepared:PlayableField
static var problem:String=""

static func enabled() -> bool:
	return "--base508-source-test" in OS.get_cmdline_user_args()

static func argument(prefix:String) -> String:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):return arg.trim_prefix(prefix)
	return ""

static func prepare() -> PlayableField:
	if not enabled():return null
	if prepared!=null:return prepared
	var pack_script=load("res://scripts/maps/base508_pack.gd")
	var pack=pack_script.new()
	if not pack.load_pack(argument("--base508-pack=")):problem=pack.error;return null
	var field_script=load(FIELD_PATH)
	var candidate=field_script.new()
	var mid:String=argument("--base508-legacy-map=")
	if mid.is_empty():mid="albino_01"
	if not candidate.configure_source(pack,argument("--base508-registration="),argument("--base508-legacy-reference="),mid,"--base508-legacy-review-population" in OS.get_cmdline_user_args()):
		problem="Source pack, registration, or existing reviewed navigation failed validation";return null
	var links_path: String = argument("--patch523-world-links=")
	var links_sha: String = argument("--patch523-world-links-sha256=")
	if not links_path.is_empty() or not links_sha.is_empty():
		if links_path.is_empty() or links_sha.is_empty() or not candidate.configure_world_links(links_path, links_sha):
			problem = "Cumulative523 world links failed Land/AssetPath/SHA256 validation"
			candidate.close()
			return null
	prepared=candidate
	return prepared

static func register_test_map(maps:Array, by_id:Dictionary) -> String:
	var candidate:PlayableField=prepare()
	if candidate==null:return ""
	var mid:String=str(candidate.data.map_id)
	if by_id.has(mid):problem="Test map ID already exists";return ""
	var record={"id":mid,"name":candidate.data.map_name,"tile_size_world":32,"width":ceili(candidate.bounds.end.x/32),"height":ceili(candidate.bounds.end.y/32),"source_test_only":true}
	maps.append(record);by_id[mid]=record
	return mid

static func owns(mid:String) -> bool:
	return enabled() and prepared!=null and str(prepared.data.map_id)==mid

static func field_for(mid:String) -> PlayableField:
	return prepared if owns(mid) else null
