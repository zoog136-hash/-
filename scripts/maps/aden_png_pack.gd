extends RefCounted
## Optional local artwork only. The source field, source saves and actor scale
## never change. A candidate survey cannot enable gameplay by naming itself a pack.
const PNG_SHA := "9ce95ca285f9bee72bab355c5015779122dd354fd26e73d9664a355bf9c86be3"
const GRID_SHA := "c22aa61ed083a3680230c659202503d7afaef30cb41b86d4655e9f843c81a7c4"
const MAX_ERROR_WORLD: float = 4.0
var regions: Array[Dictionary] = []
var root_path: String = ""
var rejection: String = "NOT_INSTALLED"
var textures: Dictionary = {}
var verified_png_decodes: int = 0 # Per-configure measured unique PNG validations.
var review_active: bool = false

static func pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and finite_numbers(value)

static func finite_numbers(value: Array) -> bool:
	for number: Variant in value:
		if not (number is int or number is float) or not is_finite(float(number)): return false
	return true

static func matrix(value: Variant) -> Transform2D:
	if not value is Array or value.size() != 6 or not finite_numbers(value): return Transform2D(Vector2.ZERO,Vector2.ZERO,Vector2.ZERO)
	# Row-major 2x3, always maps existing world pixels to original PNG pixels.
	return Transform2D(Vector2(value[0],value[3]),Vector2(value[1],value[4]),Vector2(value[2],value[5]))

static func safe_file(name: Variant) -> bool:
	return name is String and not name.is_empty() and not name.is_absolute_path() and not ":" in name and not ".." in name and not "\\" in name

func reject(reason: String) -> bool:
	regions.clear(); textures.clear(); rejection = reason
	return false

func configure(path: String, field: OriginalPlayableField) -> bool:
	regions.clear(); textures.clear(); verified_png_decodes = 0; root_path = path
	if path.is_empty(): return reject("NOT_INSTALLED")
	if str(field.data.map_id) != "aden_world" or str(field.definition.source_sha256) != GRID_SHA: return reject("SOURCE_GRID_MISMATCH")
	var manifest_path: String = path.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path): return reject("MANIFEST_MISSING")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not value is Dictionary or value.get("schema") != 1 or value.get("map_id") != "aden_world": return reject("INVALID_MANIFEST")
	if value.get("original_png_sha256") != PNG_SHA or value.get("source_grid_sha256") != GRID_SHA: return reject("IDENTITY_MISMATCH")
	if value.get("source_definition_sha256") != FileAccess.get_sha256("res://data/map_remake/private/aden/definitions/aden_world.json"): return reject("DEFINITION_MISMATCH")
	if not value.get("regions") is Array or value.regions.is_empty(): return reject("NO_REVIEWED_REGIONS")
	# Memoize only verified dimensions inside this configure call. Never retain
	# decoded images or upload textures before a chunk becomes visible.
	var verified_layer_sizes: Dictionary = {}
	for row: Variant in value.regions:
		if not row is Dictionary or row.get("status") != "VERIFIED" or row.get("collision_status") != "VERIFIED" or row.get("occlusion_status") != "VERIFIED": return reject("REGION_NOT_VERIFIED")
		if not row.get("control_points") is Array or row.control_points.size() < 5: return reject("INSUFFICIENT_CONTROL_POINTS")
		var transform: Transform2D = matrix(row.get("world_to_image"))
		if absf(transform.determinant()) < .000001: return reject("SINGULAR_TRANSFORM")
		var unique: Dictionary = {}
		for anchor: Variant in row.control_points:
			if not anchor is Dictionary or anchor.get("status") != "VERIFIED" or not pair(anchor.get("world")) or not pair(anchor.get("image")): return reject("UNVERIFIED_CONTROL_POINT")
			var point := Vector2(anchor.world[0],anchor.world[1])
			if unique.has(point): return reject("DUPLICATE_CONTROL_POINT")
			unique[point] = true
			var expected := Vector2(anchor.image[0],anchor.image[1])
			if (transform.affine_inverse()*expected).distance_to(point) > MAX_ERROR_WORLD: return reject("CONTROL_POINT_RESIDUAL")
		# Reject collinear surveys; five points on one road do not fix a 2D map.
		var points: Array = unique.keys()
		var area: float = 0.0
		for i: int in range(1,points.size()-1): area = maxf(area,absf((points[i]-points[0]).cross(points[i+1]-points[0])))
		if area < 576.0: return reject("DEGENERATE_SURVEY")
		var rect: Variant = row.get("source_rect")
		if not rect is Array or rect.size() != 4 or not finite_numbers(rect): return reject("INVALID_REGION")
		for number: Variant in rect:
			if float(number) != floorf(float(number)): return reject("FRACTIONAL_REGION")
		var bounds := Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3]))
		if bounds.size.x <= 0 or bounds.size.y <= 0 or not Rect2i(0,0,field.width,field.height).encloses(bounds): return reject("REGION_OUTSIDE_SOURCE")
		if not pair(row.get("image_origin")) or not row.get("cuts") is Array: return reject("INVALID_LAYER_METADATA")
		for cut: Variant in row.cuts:
			if not cut is Dictionary or not pair(cut.get("image_origin")) or not pair(cut.get("foot_world")): return reject("INVALID_CUT")
		var ground_size: Vector2 = Vector2.ZERO
		for layer: Dictionary in [row]+row.cuts:
			if not safe_file(layer.get("file")) or not layer.get("sha256") is String: return reject("INVALID_LAYER_PATH")
			var file: String = root_path.path_join(layer.file)
			var expected_sha: String = str(layer.sha256)
			var dimensions: Vector2 = Vector2.ZERO
			if verified_layer_sizes.has(file):
				var verified: Dictionary = verified_layer_sizes[file]
				if str(verified.sha256) != expected_sha: return reject("LAYER_HASH_MISMATCH")
				dimensions = verified.size
			else:
				if not FileAccess.file_exists(file) or FileAccess.get_sha256(file) != expected_sha: return reject("LAYER_HASH_MISMATCH")
				var image := Image.new()
				if image.load(file) != OK or image.is_empty() or image.get_width()>2048 or image.get_height()>2048: return reject("INVALID_LAYER_IMAGE")
				verified_png_decodes += 1
				dimensions = Vector2(image.get_width(),image.get_height())
				verified_layer_sizes[file] = {"sha256":expected_sha,"size":dimensions}
			if ground_size == Vector2.ZERO: ground_size = dimensions
		# The existing PNG chunk renderer creates/shares the GPU texture on first
		# display. Geometry uses the independently SHA-verified image dimensions.
		var coverage := Rect2(Vector2(row.image_origin[0],row.image_origin[1]),ground_size)
		for corner: Vector2i in [bounds.position,Vector2i(bounds.end.x,bounds.position.y),bounds.end,Vector2i(bounds.position.x,bounds.end.y)]:
			var point: Vector2 = transform*field.coordinates.grid_to_world(corner.x,corner.y)
			if not coverage.grow(.01).has_point(point): return reject("GROUND_DOES_NOT_COVER_SOURCE_REGION")
		var record: Dictionary = row.duplicate(true)
		record["transform"] = transform
		record["bounds"] = bounds
		regions.append(record)
	rejection = ""
	return true

func region_for(key: Vector2i) -> Dictionary:
	var chunk := Rect2i(key*32,Vector2i(32,32))
	for region: Dictionary in regions:
		if (region.bounds as Rect2i).encloses(chunk): return region
	return {}
