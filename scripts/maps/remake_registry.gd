extends RefCounted
## Existing 25 IDs only. An absent private pack keeps the existing project;
## a present, damaged install is rejected before changing maps or saved state.
const ROOT: String = "res://data/map_remake/private/"
const FIELD = preload("res://scripts/maps/remake_field.gd")
const READ = preload("res://scripts/maps/source_travel.gd")
const ARCHIVE_SHA: String = "2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20"
const AUTHORED = preload("res://scripts/maps/authored_remake_field.gd")

static func display_names() -> Dictionary:
	var names: Dictionary={}
	if "--legacy-map-layouts" in OS.get_cmdline_user_args(): return names
	var profiles: Dictionary=READ.read_object("res://data/maps/remake_render_profiles.json").get("maps",{})
	for id: String in profiles:
		if profiles[id].has("display_name"): names[id]=profiles[id].display_name
	return names

static func authored_field(definition: Dictionary) -> PlayableField:
	var profiles: Dictionary=READ.read_object("res://data/maps/remake_render_profiles.json").get("maps",{})
	var id: String=str(definition.get("map_id",""))
	if "--legacy-map-layouts" in OS.get_cmdline_user_args() or not profiles.has(id) or not definition.has("world_geometry"):
		var existing:=PlayableField.new();existing.configure(definition);return existing
	var field: AuthoredRemakeField=AUTHORED.new()
	field.configure_remake(definition,profiles[id])
	return field

static func installed(map_id: String) -> bool:
	if "--legacy-map-layouts" in OS.get_cmdline_user_args(): return false
	# A corrupt or partial installed index must not silently load an old layout.
	return map_id in ["oman_01","oman_02","oman_03","oman_04","oman_05","oman_06","oman_07","oman_08","oman_09","oman_10"] and FileAccess.file_exists(ROOT+"index.json")

static func load_field(map_id: String) -> RemakePlayableField:
	var index: Dictionary = READ.read_object(ROOT+"index.json")
	if int(index.get("schema",0))!=1 or index.get("source_archive_sha256")!=ARCHIVE_SHA or not index.get("maps") is Dictionary: return null
	if not index.maps.get(map_id) is Dictionary: return null
	var entry: Dictionary = index.get("maps",{}).get(map_id,{})
	if entry.is_empty() or str(entry.get("path","")) != ROOT+"definitions/"+map_id+".json": return null
	if FileAccess.get_sha256(entry.path) != str(entry.get("sha256","")): return null
	var definition: Dictionary = READ.read_object(entry.path)
	if not valid_definition(definition): return null
	if definition.get("map_id") != map_id or definition.get("source_sha256") != entry.get("grid_sha256"): return null
	if str(definition.get("pack_root",""))+"/" != ROOT or definition.get("source_archive_sha256") != index.get("source_archive_sha256"): return null
	var expected: Dictionary = READ.read_object("res://data/maps/remake_calibrations.json").get("maps",{}).get(map_id,{})
	if expected.is_empty(): return null
	for key: String in ["origin","dimensions","source_map_id"]:
		if definition.get(key)!=expected.get(key): return null
	if definition.source_sha256!=expected.grid_sha256: return null
	for key: String in ["basis_x","basis_y","translation"]:
		if definition.coordinate_mapping.get(key)!=expected.get(key): return null
	var field: RemakePlayableField = FIELD.new()
	if not field.configure_source(definition): field.close(); return null
	# A floor has nine small navigation chunks. Verify all of them before
	# releasing the current map, so corruption cannot appear halfway through.
	for key: Vector2i in field.chunk_table:
		if field._chunk(key).is_empty(): field.close(); return null
	return field

static func valid_definition(value: Dictionary) -> bool:
	if int(value.get("schema",0))!=2 or not value.get("navigation") is Dictionary or not value.get("remake_gameplay") is Dictionary or not value.get("coordinate_mapping") is Dictionary: return false
	if value.navigation.get("profile")!="A3_STATIC_EDGES" or not value.navigation.get("chunks") is Array: return false
	for key: String in ["origin","dimensions","spawn_source"]:
		if not value.get(key) is Array or value[key].size()!=2: return false
		for number: Variant in value[key]:
			if not (number is int or number is float) or not is_finite(float(number)): return false
	for row: Variant in value.navigation.chunks:
		if not row is Array or row.size()!=8: return false
		for i: int in range(7):
			if not (row[i] is int or row[i] is float) or not is_finite(float(row[i])) or float(row[i])<0 or float(row[i])!=floorf(float(row[i])): return false
		if row[2]<1 or row[2]>64 or row[3]<1 or row[3]>64 or str(row[7]).length()!=64: return false
	for key: String in ["npc_spawns","monster_spawns","portals","terrain_chunks","doors","getback"]:
		if not value.get(key) is Array: return false
	for key: String in ["npc_spawn","monster_spawn","portal"]:
		if not value.remake_gameplay.get(key) is Array: return false
	return value.get("rules") is Dictionary and value.remake_gameplay.get("entry_exclusion") is Dictionary
