extends RefCounted

# Creates a display texture from each original codex image; no source files change.
const DATA_PATH = "res://data/item_icon_art_profiles_v1.json"
static var cache: Dictionary = {}
static var cache_keys: Array[String] = []
static var profiles: Dictionary = {}
static var profile_loaded: bool = false

static func item_icon(record: Dictionary, name: String, index: Dictionary) -> Texture2D:
	# PR46 retains per-source-ID images. Always prefer the selected record.
	var path: String = str(record.get("image_path", ""))
	if path.is_empty():
		path = str(index.get(name, ""))
	return render(path, str(record.get("grade", "일반")), name)

static func render(path: String, grade: String = "일반", name: String = "") -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var source: Texture2D = load(path) as Texture2D
	if source == null or not path.begins_with("res://assets/catalog/"):
		return source
	if not profile_loaded:
		profile_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			profiles = parsed
	var key: String = path + "|" + grade + "|" + name
	if cache.has(key):
		return cache[key] as Texture2D
	var image: Image = source.get_image()
	if image == null or image.is_empty():
		return source
	var grade_options: Dictionary = (profiles.get("color_grades", {}) as Dictionary).get(grade, {})
	var accent_text: String = str((profiles.get("accent_overrides", {}) as Dictionary).get(name, grade_options.get("accent", "c8a976")))
	var texture: Texture2D = _compose(image, Color(accent_text), float(grade_options.get("glow", 0.2)))
	if cache_keys.size() >= 320:
		cache.erase(cache_keys.pop_front())
	cache_keys.append(key)
	cache[key] = texture
	return texture

static func _compose(original: Image, accent: Color, glow: float) -> Texture2D:
	var canvas: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var gold: Color = Color("b79560")
	for y: int in range(96):
		for x: int in range(96):
			var distance: float = Vector2(x - 47.5, y - 47.5).length()
			var strength: float = pow(clampf(1.0 - distance / 68.0, 0.0, 1.0), 2.0)
			var color: Color = Color("0c1117").lerp(accent.darkened(0.76), strength * (0.22 + glow))
			if (x == 2 or x == 93) and y >= 2 and y <= 93 or (y == 2 or y == 93) and x >= 2 and x <= 93:
				color = gold
			elif (x == 5 or x == 90) and y >= 5 and y <= 90 or (y == 5 or y == 90) and x >= 5 and x <= 90:
				color = color.lerp(accent, 0.4)
			var cx: int = mini(x, 95 - x)
			var cy: int = mini(y, 95 - y)
			if cx >= 7 and cx <= 17 and cy >= 7 and cy <= 17 and (cx == 7 or cy == 7):
				color = gold
			canvas.set_pixel(x, y, color)
	var art: Image = original.duplicate() as Image
	art.convert(Image.FORMAT_RGBA8)
	art.resize(78, 78, Image.INTERPOLATE_LANCZOS)
	art.adjust_bcs(0.025, 1.16, 1.08)
	for y: int in range(78):
		for x: int in range(78):
			var pixel: Color = art.get_pixel(x, y)
			var light: float = maxf(pixel.r, maxf(pixel.g, pixel.b))
			var alpha: float = pixel.a * clampf((light - 0.025) / 0.22, 0.0, 1.0)
			if alpha <= 0.01:
				continue
			var behind: Color = canvas.get_pixel(x + 9, y + 9)
			canvas.set_pixel(x + 9, y + 9, behind.lerp(pixel, alpha))
	return ImageTexture.create_from_image(canvas)
