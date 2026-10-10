extends RefCounted
class_name TwilightL1JSourceMapCatalog
## Private map pack, independent of the game's active fields and save schema.
## Only explicitly sourced A3 edge rules can create navigation. Other revisions
## remain inspectable byte grids until their movement rules are separately verified.
const NAV = preload("res://addons/twilight_l1j/twilight_source_navigation.gd")
var _records: Dictionary = {}
var raw_directory: String = ""

func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))

func _pair(value: Variant, positive: bool) -> bool:
	if not value is Array or value.size() != 2: return false
	for number: Variant in value:
		if not _integer(number): return false
		if positive and (number < 1 or number > 4096): return false
		if not positive and (number < -2147480000 or number > 2147480000): return false
	return true

func load_catalog(path: String = "res://data/l1j/recovered_maps/source_maps.json") -> bool:
	_records.clear()
	raw_directory = ""
	if not FileAccess.file_exists(path): return false
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not document is Dictionary or document.get("schema",0) != 1 or not document.get("maps") is Array: return false
	if document.maps.is_empty() or document.maps.size() > 10000: return false
	var validated: Dictionary = {}
	var digest := RegEx.new()
	digest.compile("^[0-9a-f]{64}$")
	for row: Variant in document.maps:
		if not row is Dictionary or not _integer(row.get("map_id")): return false
		var map_id: int = int(row.map_id)
		if map_id < 0 or map_id > 99999 or validated.has(map_id): return false
		if not _pair(row.get("dimensions"),true): return false
		if row.get("source_origin") != null and not _pair(row.source_origin,false): return false
		if not row.get("row_major_sha256") is String or digest.search(row.row_major_sha256) == null: return false
		if row.get("raw_file") != "raw/%d.bin" % map_id: return false
		if row.get("navigation_rules") not in ["A3_STATIC_EDGES","UNVERIFIED_OTHER_REVISION"]: return false
		validated[map_id] = row.duplicate(true)
	_records = validated
	raw_directory = path.get_base_dir().path_join("raw")
	return true

func map_ids() -> Array[int]:
	var result: Array[int] = []
	for map_id: int in _records: result.append(map_id)
	result.sort()
	return result

func record(map_id: int) -> Dictionary:
	return _records[map_id].duplicate(true) if _records.has(map_id) else {}

func create_navigation(map_id: int, projection: Transform2D) -> TwilightL1JSourceNavigation:
	if not _records.has(map_id): return null
	var row: Dictionary = _records[map_id]
	if row.navigation_rules != "A3_STATIC_EDGES" or row.source_origin == null: return null
	var path: String = raw_directory.path_join("%d.bin" % map_id)
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != row.row_major_sha256: return null
	var size := Vector2i(int(row.dimensions[0]),int(row.dimensions[1]))
	var origin := Vector2i(int(row.source_origin[0]),int(row.source_origin[1]))
	var navigation: TwilightL1JSourceNavigation = NAV.new()
	return navigation if navigation.configure(map_id,size,origin,projection,raw_directory) else null
