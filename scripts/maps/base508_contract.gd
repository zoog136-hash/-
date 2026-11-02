extends RefCounted
## Display projection is explicit; raw source cells remain the shared identity.
const SPACE: String = "LINEAGEM_WORLD_SOURCE_CELLS_V1"

static func map_key(manifest: Dictionary) -> String:
	return "base508_land_%d" % int(manifest.land.ID)

static func describe(manifest: Dictionary) -> Dictionary:
	var origins: Array = []
	var minimum := Vector2i(2147483647,2147483647)
	var maximum := Vector2i(-2147483647,-2147483647)
	for row: Dictionary in manifest.get("geometry", []):
		var origin := Vector2i(int(row.origin[0]),int(row.origin[1]))
		origins.append([origin.x,origin.y])
		minimum = minimum.min(origin)
		maximum = maximum.max(origin+Vector2i(63,63))
	if origins.is_empty(): return {}
	return {"schema":1,"edition":"LineageM_base508","map_key":map_key(manifest),"land_id":int(manifest.land.ID),"asset_path":manifest.land.AssetPath,
		"coordinate_space":SPACE,"source_cell_bounds":[minimum.x,minimum.y,maximum.x,maximum.y],"supplied_chunk_origins":origins,
		"terrain_encoding":"S32_INTERLEAVED_U16_HALF_CELL_ATTRIBUTES; not L1J per-cell direction bytes",
		"display_grid_transform":manifest.art.get("source_to_png_transform"),"display_visual_cell_center_offset":[24,12],
		"original_engine_actor_foot_anchor":"UNVERIFIED; explicit renderer policy required","height":"UNKNOWN","terrain_collision":"UNKNOWN_BLOCKED","legacy_map_aliases":[]}

static func supplied_cell(manifest: Dictionary, source: Vector2i) -> bool:
	for row: Dictionary in manifest.get("geometry", []):
		var origin := Vector2i(int(row.origin[0]),int(row.origin[1]))
		if Rect2i(origin,Vector2i(64,64)).has_point(source): return true
	return false

static func accepts_record(manifest: Dictionary, record: Dictionary) -> bool:
	var land: Variant = record.get("land_id")
	if not (land is int or land is float) or not is_finite(float(land)) or float(land) != floorf(float(land)): return false
	return record.get("edition", "") == "LineageM_base508" and record.get("coordinate_space", "") == SPACE and record.get("map_key", "") == map_key(manifest) and int(land) == int(manifest.land.ID) and record.get("asset_path", "") == manifest.land.AssetPath

static func geometry_equal(a: Variant, b: Variant) -> bool:
	# JSON numeric arrays decode as floats; compare exact numeric values without
	# allowing strings or booleans to masquerade as source coordinates.
	if (a is int or a is float) and (b is int or b is float):
		return is_finite(float(a)) and is_finite(float(b)) and float(a) == float(b)
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in range(a.size()):
			if not geometry_equal(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not geometry_equal(a[key],b[key]): return false
		return true
	return typeof(a) == typeof(b) and a == b

static func grid_anchor(manifest: Dictionary, source: Vector2) -> Vector2:
	var mapping: Variant = manifest.art.get("source_to_png_transform")
	if not mapping is Dictionary or not source.is_finite(): return Vector2.INF
	var delta := source-Vector2(mapping.source_origin[0],mapping.source_origin[1])
	return Vector2(mapping.translation[0],mapping.translation[1])+Vector2(mapping.basis_x[0],mapping.basis_x[1])*delta.x+Vector2(mapping.basis_y[0],mapping.basis_y[1])*delta.y

static func visual_cell_center(manifest: Dictionary, source: Vector2) -> Vector2:
	# Center of the rendered 48x24 cell. This is not a verified M actor-foot rule.
	return grid_anchor(manifest,source)+Vector2(24,12)

static func source_from_grid_anchor(manifest: Dictionary, pixel: Vector2) -> Vector2:
	var mapping: Variant=manifest.art.get("source_to_png_transform")
	if not mapping is Dictionary or not pixel.is_finite(): return Vector2.INF
	var bx:=Vector2(mapping.basis_x[0],mapping.basis_x[1])
	var by:=Vector2(mapping.basis_y[0],mapping.basis_y[1])
	var determinant: float=bx.x*by.y-bx.y*by.x
	if is_zero_approx(determinant): return Vector2.INF
	var p:=pixel-Vector2(mapping.translation[0],mapping.translation[1])
	return Vector2(mapping.source_origin[0],mapping.source_origin[1])+Vector2((p.x*by.y-p.y*by.x)/determinant,(bx.x*p.y-bx.y*p.x)/determinant)
