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
	var requested_land:int=int(argument("--base508-land=")) if not argument("--base508-land=").is_empty() else -1
	if not pack.load_pack(argument("--base508-pack="),requested_land):problem=pack.error;return null
	if "--base508-source-edge-review" in OS.get_cmdline_user_args():
		var edge_script=load("res://scripts/maps/base508_source_edge_field.gd")
		var edge_candidate=edge_script.new()
		var review_entry:Dictionary={}
		var catalog_path:String=argument("--base508-entry-catalog=")
		if not catalog_path.is_empty():
			var catalog:Variant=JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
			if not catalog is Dictionary:problem="Invalid source entry catalog";return null
			for row:Dictionary in catalog.get("maps",[]):
				if int(row.land)!=int(pack.manifest.land.ID) or row.status!="READY_FOR_GRAPH_REVIEW":continue
				for entry:Dictionary in row.entries:
					if str(entry.kind)+":"+str(int(entry.id))==argument("--base508-review-entry="):
						if not review_entry.is_empty():problem="Ambiguous source entry";return null
						review_entry=row.duplicate(true);review_entry.selected=entry
			if review_entry.is_empty():problem="Explicit source entry not found";return null
		if not edge_candidate.configure_edges(pack,argument("--base508-tables="),review_entry):
			problem="Original source identity, arrival or edge profile rejected";return null
		prepared=edge_candidate
		return prepared
	var field_script=load(FIELD_PATH)
	var candidate=field_script.new()
	var mid:String=argument("--base508-legacy-map=")
	if mid.is_empty():mid="albino_01"
	if not candidate.configure_source(pack,argument("--base508-registration="),argument("--base508-legacy-reference="),mid,"--base508-legacy-review-population" in OS.get_cmdline_user_args()):
		problem="Source pack, registration, or existing reviewed navigation failed validation";return null
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
