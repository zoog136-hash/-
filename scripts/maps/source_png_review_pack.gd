extends RefCounted
## Real source PNGs in a local pack. Candidate geometry is available only in an
## explicit, non-saving review session, never silently accepted as a restoration.
const OLD_PACK = preload("res://scripts/maps/aden_png_pack.gd")
const LAYOUT = preload("res://scripts/maps/png_review_layout.gd")
const FOOTPRINTS = preload("res://scripts/maps/png_manual_footprints.gd")
var regions: Array[Dictionary] = []
var root_path: String = ""
var textures: Dictionary = {}
var rejection: String = "NOT_INSTALLED"
var review_active: bool = false
var review_spawn: Vector2 = Vector2.INF
var review_layout: Dictionary = {}
var ground_sampler: String = "nearest"
var manual_footprints: RefCounted

func reject(reason: String) -> bool:
	regions.clear(); textures.clear(); rejection = reason
	review_active = false; review_spawn = Vector2.INF
	review_layout.clear()
	manual_footprints = null
	return false

func configure(path: String, field: OriginalPlayableField) -> bool:
	regions.clear();textures.clear();review_active = false;review_spawn = Vector2.INF
	review_layout.clear()
	manual_footprints = null
	root_path = path.path_join(str(field.data.map_id))
	var manifest: String = root_path.path_join("manifest.json")
	if not FileAccess.file_exists(manifest): return reject("NOT_INSTALLED")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/png_map_sources.json")).maps
	var id: String = str(field.data.map_id)
	if not catalog.has(id) or not value is Dictionary or value.get("schema") != 2 or value.get("map_id") != id: return reject("INVALID_IDENTITY")
	var expected: Dictionary = catalog[id]
	if value.get("png_sha256") != expected.png_sha256 or value.get("png_size") != expected.png_size or value.get("source_map_id") != field.definition.source_map_id or field.definition.source_map_id != expected.source_map_id or value.get("source_grid_sha256") != field.definition.source_sha256: return reject("SOURCE_MISMATCH")
	# These packs contain honest composite PNG chunks. Occlusion/collision review
	# is incomplete, so they cannot activate in an ordinary saved game.
	if value.get("status") != "REVIEW_REQUIRED" or not "--png-review" in OS.get_cmdline_user_args(): return reject("REVIEW_SESSION_REQUIRED")
	if not value.get("regions") is Array or value.regions.is_empty(): return reject("NO_REGIONS")
	if not OLD_PACK.pair(value.get("review_spawn_cell")): return reject("INVALID_REVIEW_SPAWN")
	var cell := Vector2i(value.review_spawn_cell[0],value.review_spawn_cell[1])
	review_spawn = field.cell_to_world(cell)
	if not field.point_clear(review_spawn): return reject("BLOCKED_REVIEW_SPAWN")
	if not value.get("manual_footprints",[]) is Array: return reject("INVALID_MANUAL_FOOTPRINTS")
	var footprints: RefCounted = FOOTPRINTS.new()
	if not footprints.configure(value.get("manual_footprints",[])): return reject("INVALID_MANUAL_FOOTPRINTS")
	if not footprints.point_clear(review_spawn,4.0): return reject("BLOCKED_REVIEW_SPAWN")
	ground_sampler = str(value.get("ground_sampler","nearest"))
	if not ground_sampler in ["nearest","linear"]: return reject("INVALID_SAMPLER")
	if not value.get("review_placements",{}) is Dictionary: return reject("INVALID_REVIEW_LAYOUT")
	var prepared: Dictionary = LAYOUT.prepare(field,review_spawn,value.get("review_placements",{}))
	if prepared.is_empty(): return reject("INVALID_REVIEW_LAYOUT")
	for category: String in ["npc_spawn","portal"]:
		for record: Dictionary in prepared[category]:
			if not footprints.point_clear(Vector2(record.position[0],record.position[1]),4.0): return reject("REVIEW_LAYOUT_IN_MANUAL_FOOTPRINT")
	var cut_ids: Dictionary = {}
	for row: Variant in value.regions:
		if not row is Dictionary or not OLD_PACK.safe_file(row.get("file")) or not OLD_PACK.pair(row.get("image_origin")): return reject("INVALID_REGION")
		var rect: Variant = row.get("source_rect")
		if not rect is Array or rect.size() != 4 or not OLD_PACK.finite_numbers(rect): return reject("INVALID_BOUNDS")
		for number: Variant in rect:
			if float(number) != floorf(float(number)): return reject("INVALID_BOUNDS")
		var bounds := Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3]))
		if bounds.size != Vector2i(32,32) or not Rect2i(0,0,field.width,field.height).encloses(bounds) or bounds.position.x%32 != 0 or bounds.position.y%32 != 0: return reject("INVALID_BOUNDS")
		var mapping: Transform2D = OLD_PACK.matrix(row.get("world_to_image"))
		if absf(mapping.determinant()) < .000001: return reject("INVALID_TRANSFORM")
		if not row.get("cuts") is Array: return reject("INVALID_CUTS")
		for layer: Variant in [row]+row.cuts:
			if not layer is Dictionary or not OLD_PACK.safe_file(layer.get("file")) or not OLD_PACK.pair(layer.get("image_origin")): return reject("INVALID_LAYER")
			var file: String = root_path.path_join(layer.file)
			if not FileAccess.file_exists(file) or FileAccess.get_sha256(file) != layer.get("sha256"): return reject("IMAGE_HASH_MISMATCH")
			var image := Image.new()
			if image.load(file) != OK or image.is_empty() or maxi(image.get_width(),image.get_height()) > 2048: return reject("INVALID_IMAGE")
			if layer != row and not OLD_PACK.pair(layer.get("foot_world")): return reject("INVALID_CUT_FOOT")
			if layer != row:
				if not layer.get("id") is String or cut_ids.has(layer.id): return reject("DUPLICATE_CUT")
				cut_ids[layer.id] = true
				var foot := Vector2(layer.foot_world[0],layer.foot_world[1])
				var owner: Vector2i = field.world_to_cell(foot)
				if not bounds.has_point(owner): return reject("CUT_OWNER_MISMATCH")
				if layer.has("foot_image"):
					if not OLD_PACK.pair(layer.foot_image) or (mapping*foot).distance_to(Vector2(layer.foot_image[0],layer.foot_image[1])) > .05: return reject("CUT_FOOT_PROJECTION")
			if layer == row:
				var coverage := Rect2(Vector2(layer.image_origin[0],layer.image_origin[1]),image.get_size())
				for corner: Vector2i in [bounds.position,Vector2i(bounds.end.x,bounds.position.y),bounds.end,Vector2i(bounds.position.x,bounds.end.y)]:
					if not coverage.grow(.01).has_point(mapping*field.coordinates.grid_to_world(corner.x,corner.y)): return reject("PNG_DOES_NOT_COVER_CHUNK")
		var record: Dictionary = row.duplicate(true)
		record["transform"] = mapping; record["bounds"] = bounds
		regions.append(record)
	var spawn_covered: bool = false
	for row: Dictionary in regions:
		spawn_covered = spawn_covered or row.bounds.has_point(cell)
	if not spawn_covered: return reject("REVIEW_SPAWN_OUTSIDE_PNG")
	review_layout = prepared
	manual_footprints = footprints if not footprints.polygons.is_empty() else null
	review_active = true; rejection = ""
	return true

func apply_layout(field: RemakePlayableField) -> void:
	if not review_active: return
	field.png_review_footprints = manual_footprints
	LAYOUT.apply(field,review_spawn,review_layout)
	if manual_footprints != null: field.collision_stream.add_png_review_footprints(manual_footprints)

func region_for(key: Vector2i) -> Dictionary:
	for row: Dictionary in regions:
		if row.bounds.position == key*32: return row
	return {}
