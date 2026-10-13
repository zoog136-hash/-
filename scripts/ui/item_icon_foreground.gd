extends RefCounted
## Display-only alpha for mythic/unique turns. Never rewrite source PNGs, apply
## a global black-key shader, or erase enclosed dark details of the item.
const MAX_CACHE: int = 128
const MAX_PIXELS: int = 1048576
const MATTE_TOLERANCE: float = 0.045
static var _cache: Dictionary = {}
static var _order: Array[int] = []

static func prepare(source: Texture2D) -> Dictionary:
	if source == null:
		return {"texture":null,"ready":false,"reason":"missing_texture","removed_pixels":0}
	var key: int = source.get_instance_id()
	if _cache.has(key):
		_order.erase(key)
		_order.append(key)
		return _cache[key]
	var cutout: Dictionary = extract(source.get_image())
	var display: Texture2D = source
	if bool(cutout.ready) and int(cutout.removed_pixels) > 0:
		display = ImageTexture.create_from_image(cutout.image)
	var result: Dictionary = {"texture":display,"source":source,"ready":cutout.ready,
		"reason":cutout.reason,"removed_pixels":cutout.removed_pixels}
	_cache[key] = result
	_order.append(key)
	while _order.size() > MAX_CACHE: _cache.erase(_order.pop_front())
	return result

static func _distance(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))

static func _neutral_dark(value: Color) -> bool:
	var high: float = maxf(value.r,maxf(value.g,value.b))
	var low: float = minf(value.r,minf(value.g,value.b))
	return high < 0.16 and high-low <= 0.02

static func _background(value: Color, key: Color) -> bool:
	if value.a <= 0.01: return true
	if _distance(value,key) <= MATTE_TOLERANCE: return true
	# Match the existing original-pack dark neutral vignette, not colored or
	# bright metal. Connectivity, rather than luminance alone, defines alpha.
	return _neutral_dark(key) and _neutral_dark(value)

static func extract(source: Image) -> Dictionary:
	var result: Dictionary = {"image":source,"ready":false,
		"reason":"opaque_background_review_required","removed_pixels":0}
	if source == null or source.is_empty():
		result.reason = "unreadable_pixels"
		return result
	var width: int = source.get_width()
	var height: int = source.get_height()
	if width*height > MAX_PIXELS or width < 2 or height < 2:
		result.reason = "unsupported_dimensions"
		return result
	var pixels: Image = source.duplicate() as Image
	if pixels.is_compressed() and pixels.decompress() != OK:
		result.reason = "unreadable_pixels"
		return result
	pixels.convert(Image.FORMAT_RGBA8)
	var corners: Array[Color] = [pixels.get_pixel(0,0),pixels.get_pixel(width-1,0),
		pixels.get_pixel(0,height-1),pixels.get_pixel(width-1,height-1)]
	var transparent_corners: int = 0
	for value: Color in corners:
		if value.a <= 0.01: transparent_corners += 1
	# Already-authored transparent art keeps its native pixels, including black
	# outlines. Do not run a dark-color key through an existing alpha silhouette.
	if transparent_corners >= 3:
		result.ready = true
		result.reason = "existing_alpha"
		return result
	var key := Color.TRANSPARENT
	var agreed: int = 0
	for candidate: Color in corners:
		if candidate.a < 0.95: continue
		var matches: int = 0
		for other: Color in corners:
			if other.a >= 0.95 and _background(other,candidate): matches += 1
		if matches > agreed:
			agreed = matches
			key = candidate
	# Complex/colored frames need a reviewed mask. Do not spin the opaque card
	# or guess at item pixels when there is no consistent outer matte.
	if agreed < 3: return result
	var pending: Array[int] = []
	for x: int in range(width):
		pending.append(x)
		pending.append((height-1)*width+x)
	for y: int in range(1,height-1):
		pending.append(y*width)
		pending.append(y*width+width-1)
	var visited := PackedByteArray()
	visited.resize(width*height)
	var removed: int = 0
	while not pending.is_empty():
		var index: int = pending.pop_back()
		if visited[index] != 0: continue
		visited[index] = 1
		var x: int = index % width
		var y: int = int(index / width)
		var value: Color = pixels.get_pixel(x,y)
		if not _background(value,key): continue
		if value.a > 0.0:
			value.a = 0.0
			pixels.set_pixel(x,y,value)
			removed += 1
		if x > 0: pending.append(index-1)
		if x+1 < width: pending.append(index+1)
		if y > 0: pending.append(index-width)
		if y+1 < height: pending.append(index+width)
	if removed == 0: return result
	var surviving: int = 0
	for y: int in range(height):
		for x: int in range(width):
			if pixels.get_pixel(x,y).a > 0.01: surviving += 1
	# A blank matte is not a successfully extracted item.
	if surviving < 4:
		result.reason = "no_foreground_found"
		return result
	result.image = pixels
	result.ready = true
	result.reason = "border_matte_removed"
	result.removed_pixels = removed
	return result

static func cache_size() -> int:
	return _cache.size()

static func clear_cache() -> void:
	_cache.clear()
	_order.clear()
