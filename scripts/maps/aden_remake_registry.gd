extends RefCounted
## Full, independently installed mainland. Uses exactly the existing Oman field,
## renderer, corner policy and source save-coordinate path, not authored polygons.
const ROOT: String = "res://data/map_remake/private/aden/"
const READ = preload("res://scripts/maps/source_travel.gd")
const FIELD = preload("res://scripts/maps/remake_field.gd")
const ARCHIVE_SHA: String = "2d25c6d5408aaf29443167c4c82c30b32d1a83b16039d988471ba0c832eb7d20"
const GRID_SHA: String = "c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4"
const WIDTH: int = 2048
const HEIGHT: int = 1536

static func installed() -> bool:
	return FileAccess.file_exists(ROOT+"index.json")

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	var number: float = float(value)
	return is_finite(number) and number == floorf(number) and number >= minimum and number <= maximum

static func pair(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

static func exact_pair(value: Variant, x: int, y: int) -> bool:
	# JSON numbers are floats. Array equality distinguishes numeric Variant
	# types in Godot, so compare the finite integer components explicitly.
	return pair(value) and integer(value[0],x,x) and integer(value[1],y,y)

static func valid_definition(value: Dictionary) -> bool:
	if value.get("schema") != 2 or value.get("map_id") != "aden_world" or value.get("source_map_id") != 4: return false
	if not exact_pair(value.get("origin"),32448,32064) or not exact_pair(value.get("dimensions"),WIDTH,HEIGHT): return false
	if value.get("source_sha256") != GRID_SHA or value.get("source_archive_sha256") != ARCHIVE_SHA: return false
	if value.get("pack_root") != ROOT.trim_suffix("/") or not bool(value.get("playable",false)): return false
	if value.get("corner_policy") != "no_corner_cut" or not integer(value.get("layout_revision"),2026101503,2147483647): return false
	if not value.get("map_name") is String or not value.get("rules") is Dictionary: return false
	if not pair(value.get("spawn_source")): return false
	if not integer(value.spawn_source[0],32448,34495) or not integer(value.spawn_source[1],32064,33599): return false
	var mapping: Variant = value.get("coordinate_mapping")
	if not mapping is Dictionary: return false
	if not exact_pair(mapping.get("basis_x"),24,-12) or not exact_pair(mapping.get("basis_y"),24,12) or not exact_pair(mapping.get("translation"),0,24576): return false
	for key: String in ["npc_spawns","monster_spawns","portals","getback","doors","terrain_chunks"]:
		if not value.get(key) is Array: return false
	var navigation: Variant = value.get("navigation")
	if not navigation is Dictionary or navigation.get("profile") != "A3_STATIC_EDGES": return false
	if not navigation.get("chunks") is Array or navigation.chunks.size() != 768: return false
	var seen: Dictionary = {}
	for row: Variant in navigation.chunks:
		if not row is Array or row.size() != 8: return false
		if not integer(row[0],0,31) or not integer(row[1],0,23): return false
		if row[2] != 64 or row[3] != 64 or row[4] != 0: return false
		if not integer(row[5],0,4194304) or not integer(row[6],1,4194304) or row[5]+row[6] > 4194304: return false
		if not row[7] is String or row[7].length() != 64: return false
		var key := Vector2i(int(row[0]),int(row[1]))
		if seen.has(key): return false
		seen[key] = true
	var gameplay: Variant = value.get("remake_gameplay")
	if not gameplay is Dictionary: return false
	for key: String in ["npc_spawn","portal","monster_spawn"]:
		if not gameplay.get(key) is Array: return false
		var ids: Dictionary = {}
		for record: Variant in gameplay[key]:
			if not record is Dictionary or not record.get("id") is String or str(record.id).is_empty(): return false
			if ids.has(record.id): return false
			ids[record.id] = true
	var exclusion: Variant = gameplay.get("entry_exclusion")
	if not exclusion is Dictionary or not pair(exclusion.get("center")): return false
	if not integer(exclusion.get("radius"),1,4096): return false
	for record: Dictionary in gameplay.npc_spawn:
		if not pair(record.get("position")) or not record.get("role") is String: return false
	for record: Dictionary in gameplay.portal:
		if not pair(record.get("position")) or not record.get("target_map") is String: return false
		if not integer(record.get("radius"),1,4096): return false
		if record.has("target_position") and not pair(record.target_position): return false
	for record: Dictionary in gameplay.monster_spawn:
		if not record.get("source_cells") is Array or record.source_cells.is_empty(): return false
		if not integer(record.get("max_count"),1,65536): return false
		if not record.get("rect") is Array or record.rect.size() != 4: return false
		for number: Variant in record.rect:
			if not (number is int or number is float) or not is_finite(float(number)): return false
		if record.rect[2] <= 0 or record.rect[3] <= 0: return false
		var previous: int = -1
		for cell: Variant in record.source_cells:
			if not integer(cell,0,WIDTH*HEIGHT-1) or int(cell) <= previous: return false
			previous = int(cell)
	return true

static func load_field() -> RemakePlayableField:
	var index: Dictionary = READ.read_object(ROOT+"index.json")
	if index.get("schema") != 1 or index.get("source_archive_sha256") != ARCHIVE_SHA or not index.get("maps") is Dictionary: return null
	var entry: Variant = index.maps.get("aden_world")
	if not entry is Dictionary or entry.get("path") != ROOT+"definitions/aden_world.json" or entry.get("grid_sha256") != GRID_SHA: return null
	if FileAccess.get_sha256(entry.path) != str(entry.get("sha256","")): return null
	var definition: Dictionary = READ.read_object(entry.path)
	if not valid_definition(definition): return null
	var field: RemakePlayableField = FIELD.new()
	if not field.configure_source(definition): field.close(); return null
	# Verify the whole original mainland before releasing the old active map.
	# OriginalPlayableField retains at most 64 decoded chunks, not all 768.
	for key: Vector2i in field.chunk_table:
		if field._chunk(key).is_empty(): field.close(); return null
	for group: String in ["npc_spawn","portal"]:
		for record: Dictionary in field.data[group]:
			var point := Vector2(record.position[0],record.position[1])
			if not field.walkable(point) or not field.point_clear(point): field.close(); return null
			if record.get("target_map") == "aden_world":
				if not pair(record.get("target_position")): field.close(); return null
				point = Vector2(record.target_position[0],record.target_position[1])
				if not field.walkable(point) or not field.point_clear(point): field.close(); return null
	return field
