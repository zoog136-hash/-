extends RefCounted
## Private map data. PNG pixels and source cells remain distinct spaces.
const COORDINATE_CONTRACT = preload("res://scripts/maps/base508_contract.gd")
var root: String
var manifest: Dictionary = {}
var portals: Array = []
var geometry: Dictionary = {}
var confirmed_occupancy: Dictionary = {}
var npc_flags: Dictionary = {}
var npc_instances: Dictionary = {}
var npc_cells: Dictionary = {}
var npc_evidence: Array = []
var source_contract_data: Dictionary = {}
var error: String = ""
var loaded: bool = false

func safe_file(relative: String) -> String:
	if relative.is_empty() or relative.is_absolute_path() or relative.contains("..") or relative.contains(":"):
		return ""
	return root.path_join(relative)

func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path): return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func load_pack(path: String, requested_land_id: int=-1) -> bool:
	loaded = false
	root = path
	manifest = {}
	geometry.clear()
	portals.clear()
	confirmed_occupancy.clear()
	npc_flags.clear()
	npc_instances.clear()
	npc_cells.clear()
	npc_evidence.clear()
	source_contract_data.clear()
	var value: Variant = read_json(root.path_join("map.json"))
	if not value is Dictionary or value.get("edition", "") != "LineageM_base508":
		error = "Missing or unsupported base508 pack"
		return false
	manifest = value
	var portal_file: String = safe_file(str(manifest.get("portals_file", "")))
	if portal_file.is_empty() or FileAccess.get_sha256(portal_file) != str(manifest.get("portals_sha256", "")):
		error = "Portal table hash mismatch"
		return false
	var links: Variant = read_json(portal_file)
	if not links is Array:
		error = "Missing portal table"
		return false
	portals = links
	if manifest.has("npc_occupancy_file"):
		var evidence_file: String = safe_file(str(manifest.npc_occupancy_file))
		if evidence_file.is_empty() or FileAccess.get_sha256(evidence_file) != str(manifest.npc_occupancy_sha256):
			error = "NPC occupancy evidence hash mismatch"
			return false
		var evidence: Variant = read_json(evidence_file)
		if not evidence is Array:
			error = "Missing NPC occupancy evidence"
			return false
		npc_evidence = evidence
		for spawnpack: Dictionary in evidence:
			for record: Dictionary in spawnpack.classes:
				var class_id: int = int(record.view.NpcClassID)
				var flag: Variant = record.IsOccupyLandTile
				if npc_flags.has(class_id) and npc_flags[class_id] != flag:
					error = "Conflicting original NPC occupancy flags"
					return false
				npc_flags[class_id] = flag
	for row: Dictionary in manifest.get("geometry", []):
		var file: String = safe_file(str(row.file))
		if file.is_empty() or FileAccess.get_sha256(file) != str(row.sha256):
			error = "Geometry hash mismatch"
			return false
		var chunk: Variant = read_json(file)
		if not chunk is Dictionary or chunk.get("edition", "") != "LineageM_base508":
			error = "Invalid geometry"
			return false
		if chunk.get("origin", []) != row.origin:
			error = "Source geometry origin mismatch"
			return false
		geometry[Vector2i(int(row.origin[0]), int(row.origin[1]))] = chunk
	if manifest.has("source_contract_file"):
		var contract_file: String = safe_file(str(manifest.source_contract_file))
		if contract_file.is_empty() or FileAccess.get_sha256(contract_file) != str(manifest.source_contract_sha256):
			error = "Source coordinate contract SHA mismatch"
			return false
		var source_spec: Variant = read_json(contract_file)
		if not source_spec is Dictionary or not COORDINATE_CONTRACT.accepts_record(manifest,source_spec):
			error = "Source coordinate contract identity mismatch"
			return false
		var expected: Dictionary = COORDINATE_CONTRACT.describe(manifest)
		for key: String in ["source_cell_bounds","supplied_chunk_origins","display_grid_transform","display_visual_cell_center_offset","terrain_encoding"]:
			if not COORDINATE_CONTRACT.geometry_equal(source_spec.get(key),expected.get(key)):
				error = "Source coordinate contract geometry mismatch: " + key
				return false
			# Keep the canonical integer arrays for consumers after exact comparison.
			var canonical_value: Variant = expected[key]
			source_spec[key] = canonical_value.duplicate(true) if canonical_value is Array or canonical_value is Dictionary else canonical_value
		source_contract_data = source_spec
	error = ""
	loaded = true
	if requested_land_id>=0 and requested_land_id!=int(manifest.land.ID):
		if not select_land_context(requested_land_id):loaded=false;return false
	return true

func portal_destination(portal_id: int) -> Dictionary:
	if not loaded: return {}
	for portal: Dictionary in portals:
		if int(portal.ID) == portal_id:
			# Return original point/region. Never replace a region with its center.
			return portal.TargetTerritory.duplicate(true)
	return {}

func source_map_key() -> String:
	return COORDINATE_CONTRACT.map_key(manifest) if loaded else ""

func geographic_contract() -> Dictionary:
	if not loaded: return {}
	return source_contract_data.duplicate(true) if not source_contract_data.is_empty() else COORDINATE_CONTRACT.describe(manifest)

func npc_territory_records() -> Array:
	var records: Array = []
	if not loaded: return records
	for spawnpack: Dictionary in npc_evidence:
		for reference: Dictionary in spawnpack.TerritoryReferences:
			var territory: Dictionary = reference.Territory
			if int(territory.LandID) != int(manifest.land.ID): continue
			for original: Dictionary in spawnpack.classes:
				var view: Dictionary = original.view
				records.append({"edition":"LineageM_base508","map_key":source_map_key(),"land_id":int(manifest.land.ID),"asset_path":manifest.land.AssetPath,"coordinate_space":COORDINATE_CONTRACT.SPACE,
					"npc_class_id":int(view.NpcClassID),"spawn_pack_id":int(view.NpcSpawnPackID),"class_view_row_id":int(view.ID),"npc_level_contextual":view.NpcLevel,
					"is_spawn_raw":view.IsSpawn,"server_limit_set_id_raw":view.ServerLimitSetID,"probability_raw":reference.Probability,
					"territory_id":int(territory.ID),"source_bounds":[territory.StartX,territory.StartY,territory.EndX,territory.EndY],
					"placement_status":"CLIENT_TERRITORY_ONLY","runtime_confirmed_source_cell":null})
	return records

func register_source_npc_instance(instance_id: String, record: Dictionary, source_cell: Vector2i, placement_confirmed: Variant) -> bool:
	if not loaded or not placement_confirmed is bool or not placement_confirmed or not COORDINATE_CONTRACT.accepts_record(manifest,record): return false
	var class_id: Variant = record.get("npc_class_id")
	if not (class_id is int or class_id is float) or not is_finite(float(class_id)) or float(class_id) != floorf(float(class_id)): return false
	return register_npc_occupancy(instance_id,int(class_id),source_cell)

func collision_state(source_cell: Vector2i) -> String:
	if not loaded: return "UNKNOWN_TERRAIN"
	if confirmed_occupancy.has(source_cell) or npc_cells.has(source_cell): return "BLOCKED_CONFIRMED_OBJECT"
	return "UNKNOWN_TERRAIN"

func register_npc_occupancy(instance_id: String, class_id: int, source_cell: Vector2i) -> bool:
	# Called only when an actual instance has a confirmed source cell. The original
	# spawn regions alone never create instances or occupied rectangles.
	var flag: Variant = npc_flags.get(class_id)
	if not loaded or instance_id.is_empty() or not flag is bool or not flag: return false
	var chunk_origin := Vector2i(floori(float(source_cell.x)/64)*64, floori(float(source_cell.y)/64)*64)
	if not geometry.has(chunk_origin): return false
	unregister_npc_occupancy(instance_id)
	npc_instances[instance_id] = source_cell
	if not npc_cells.has(source_cell): npc_cells[source_cell] = {}
	npc_cells[source_cell][instance_id] = true
	return true

func unregister_npc_occupancy(instance_id: String) -> void:
	if not npc_instances.has(instance_id): return
	var cell: Vector2i = npc_instances[instance_id]
	npc_instances.erase(instance_id)
	npc_cells[cell].erase(instance_id)
	if npc_cells[cell].is_empty(): npc_cells.erase(cell)

func portal_links_at(source_cell: Vector2i) -> Array:
	var result: Array = []
	if not loaded: return result
	for portal: Dictionary in portals:
		if int(portal.SourceLandID) == int(manifest.land.ID) and source_cell == Vector2i(int(portal.SourceX), int(portal.SourceY)):
			result.append(portal.duplicate(true))
	return result

func can_enter(source_cell: Vector2i) -> bool:
	# Review camera movement is independent of actor movement. Unknown is not open.
	return collision_state(source_cell) == "OPEN_CONFIRMED"

func raw_attribute(source_half_x: int, source_y: int) -> int:
	if not loaded: return -1
	var origin := Vector2i(floori(float(source_half_x)/128.0)*64, floori(float(source_y)/64.0)*64)
	if not geometry.has(origin): return -1
	var bytes := Marshalls.base64_to_raw(str(geometry[origin].attribute_u16le))
	var offset: int = ((source_y-origin.y)*128+(source_half_x-origin.x*2))*2
	if offset < 0 or offset+2 > bytes.size(): return -1
	return bytes.decode_u16(offset)

func select_land_context(land_id: int) -> bool:
	if not loaded or not manifest.has("land_contexts_file"):error="Shared Land context unavailable";return false
	var path:String=safe_file(str(manifest.land_contexts_file))
	if path.is_empty() or FileAccess.get_sha256(path)!=str(manifest.land_contexts_sha256):error="Shared Land context SHA mismatch";return false
	var contexts:Variant=read_json(path)
	if not contexts is Array:return false
	for context:Dictionary in contexts:
		if int(context.land.ID)!=land_id:continue
		if context.land.AssetPath!=manifest.land.AssetPath:error="Shared Land context AssetPath mismatch";return false
		var flags:Dictionary={}
		for spawnpack:Dictionary in context.npc_evidence:
			for entry:Dictionary in spawnpack.classes:
				var cid:int=int(entry.view.NpcClassID)
				if flags.has(cid) and flags[cid]!=entry.IsOccupyLandTile:return false
				flags[cid]=entry.IsOccupyLandTile
		manifest=manifest.duplicate(true);manifest.land=context.land.duplicate(true)
		portals=context.portals.duplicate(true);npc_evidence=context.npc_evidence.duplicate(true);npc_flags=flags
		manifest.report.portal_links_preserved=portals.size()
		manifest.report.portal_regions_preserved=portals.filter(func(p:Dictionary)->bool:return not bool(p.TargetIsPoint)).size()
		manifest.report.npc_spawnpack_evidence=npc_evidence.size()
		manifest.report.npc_classes_with_occupancy_true=flags.values().filter(func(flag:Variant)->bool:return flag is bool and flag).size()
		manifest.report.earth_object_placement_evidence=context.earth_object_evidence.size()
		manifest.report.confirmed_object_occupied_cells=0
		manifest.selected_earth_object_evidence=context.earth_object_evidence.duplicate(true)
		confirmed_occupancy.clear();npc_instances.clear();npc_cells.clear();source_contract_data.clear()
		return true
	error="Requested LandID has no shared context";return false
