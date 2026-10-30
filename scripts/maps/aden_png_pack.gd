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

func configure(_path: String, _field: OriginalPlayableField) -> bool:
	return reject("RETIRED_ADEN_PACK")

func region_for(key: Vector2i) -> Dictionary:
	var chunk := Rect2i(key*32,Vector2i(32,32))
	for region: Dictionary in regions:
		if (region.bounds as Rect2i).encloses(chunk): return region
	return {}
