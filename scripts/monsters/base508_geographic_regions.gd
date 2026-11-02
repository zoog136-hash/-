extends RefCounted
## Region metadata, confirmed display instances and movement are separate states.
const PATH = "res://data/lineagem_base508/maps/base508_land_48962_npc_regions.json"
const ROSTER = preload("res://scripts/monsters/base508_source_roster.gd")
const VIEW = preload("res://scripts/monsters/base508_monster_view.gd")
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if value is Dictionary and value.get("source_snapshot", "") == "base508": _data = value
	return _data
static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
static func identity(record: Dictionary) -> bool:
	var c: Dictionary = data().get("coordinate_contract", {})
	if c.is_empty() or not integer(record.get("land_id")): return false
	for field: String in ["map_key", "asset_path", "coordinate_space"]:
		if record.get(field) != c.get(field): return false
	return record.get("edition", "") == "LineageM_base508" and int(record.land_id) == int(c.land_id)
static func same_geometry(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return is_finite(float(a)) and is_finite(float(b)) and float(a) == float(b)
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not same_geometry(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same_geometry(a[key],b[key]): return false
		return true
	return typeof(a) == typeof(b) and a == b
static func region(source_key: String) -> Dictionary:
	for row: Dictionary in data().get("rows", []):
		if row.source_key == source_key: return row.duplicate(true)
	return {}
static func regions_for_map(map_pack: Object) -> Array:
	if map_pack == null or not map_pack.has_method("geographic_contract") or not map_pack.has_method("npc_territory_records"): return []
	var contract: Dictionary = map_pack.call("geographic_contract")
	if not identity(contract): return []
	for field: String in ["source_cell_bounds", "supplied_chunk_origins", "display_grid_transform", "display_visual_cell_center_offset", "terrain_encoding"]:
		if not same_geometry(contract.get(field),data().coordinate_contract.get(field)): return []
	var result: Array = []
	var originals: Array = map_pack.call("npc_territory_records")
	for original: Dictionary in originals:
		if not identity(original): continue
		var candidates: Array = []
		for row: Dictionary in data().get("rows", []):
			var same: bool = true
			for field: String in ["npc_class_id", "spawn_pack_id", "class_view_row_id", "territory_id", "npc_level_contextual", "is_spawn_raw", "server_limit_set_id_raw", "probability_raw"]:
				if not integer(original.get(field)) or int(original[field]) != int(row[field]): same = false
			var bounds: Variant = original.get("source_bounds")
			if not bounds is Array or bounds.size() != 4: same = false
			else:
				for index: int in range(4):
					if not integer(bounds[index]) or int(bounds[index]) != int(row.source_bounds[index]): same = false
			if same: candidates.append(row)
		if candidates.size() == 1: result.append(candidates[0].duplicate(true))
	return result
static func source_cell_supplied(cell: Vector2i) -> bool:
	for origin: Array in data().get("coordinate_contract", {}).get("supplied_chunk_origins", []):
		if Rect2i(Vector2i(int(origin[0]), int(origin[1])),Vector2i(64,64)).has_point(cell): return true
	return false
static func _interior(row: Dictionary, cell: Vector2i) -> bool:
	var b: Array = row.source_bounds
	if int(b[0]) == int(b[2]) and int(b[1]) == int(b[3]): return cell == Vector2i(int(b[0]),int(b[1]))
	# Boundary inclusion is unproven; do not turn a profiling rectangle into a rule.
	return cell.x > int(b[0]) and cell.x < int(b[2]) and cell.y > int(b[1]) and cell.y < int(b[3])
static func display_position(cell: Vector2i, policy: String) -> Vector2:
	if policy not in ["source_grid_anchor", "visual_cell_center"]: return Vector2.INF
	var t: Dictionary = data().coordinate_contract.display_grid_transform
	var d: Vector2 = Vector2(cell)-Vector2(t.source_origin[0],t.source_origin[1])
	var point := Vector2(t.translation[0],t.translation[1])+Vector2(t.basis_x[0],t.basis_x[1])*d.x+Vector2(t.basis_y[0],t.basis_y[1])*d.y
	return point+Vector2(24,12) if policy == "visual_cell_center" else point
static func create_confirmed_visual(map_pack: Object, source_key: String, instance_id: String, source_cell: Vector2i, placement_confirmed: Variant, display_policy: String, manifest_path: String = "", allow_contextual: bool = false) -> Dictionary:
	if not placement_confirmed is bool or not placement_confirmed or instance_id.is_empty(): return {"ok":false,"reason":"explicit_actual_instance_confirmation_required"}
	var selected: Dictionary = {}
	for row: Dictionary in regions_for_map(map_pack):
		if row.source_key == source_key: selected = row
	if selected.is_empty(): return {"ok":false,"reason":"source_map_region_identity_mismatch"}
	if not source_cell_supplied(source_cell) or not _interior(selected,source_cell): return {"ok":false,"reason":"source_cell_outside_known_interior_or_boundary_unresolved"}
	var point: Vector2 = display_position(source_cell,display_policy)
	if not point.is_finite(): return {"ok":false,"reason":"explicit_display_anchor_policy_required"}
	var record: Dictionary = ROSTER.visual_record(source_key,manifest_path,allow_contextual)
	if record.is_empty(): return {"ok":false,"reason":"source_model_or_context_not_ready"}
	var view := VIEW.new()
	if not view.configure(record,str(record.source_m_asset_manifest_path)):
		view.free(); return {"ok":false,"reason":"source_view_load_failed"}
	if not map_pack.has_method("register_source_npc_instance") or not bool(map_pack.call("register_source_npc_instance",instance_id,selected,source_cell,true)):
		view.free(); return {"ok":false,"reason":"original_occupancy_contract_rejected_instance"}
	view.position = point
	return {"ok":true,"view":view,"instance_id":instance_id,"source_key":source_key,"source_cell":source_cell,"display_policy":display_policy,"original_engine_foot_anchor_verified":false,"movement_enabled":false,"movement_reason":"terrain_height_navigation_unverified","scope":"CALLER_CONFIRMED_DISPLAY_ONLY"}
static func remove_visual(map_pack: Object, instance: Dictionary) -> void:
	if map_pack != null and map_pack.has_method("unregister_npc_occupancy"): map_pack.call("unregister_npc_occupancy",str(instance.get("instance_id", "")))
	var node: Variant = instance.get("view")
	if is_instance_valid(node): node.free()
	instance.clear()
