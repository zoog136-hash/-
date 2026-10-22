extends SceneTree
## Internal file-only art inspection; never changes production resources.
var cache: Dictionary = {}

func _raw(path: String) -> Image:
	if not cache.has(path):
		var image := Image.new()
		assert(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK)
		cache[path] = image
	return cache[path]

func _pose(frames: SpriteFrames, role: String, direction: int, phase: int) -> Image:
	var texture: AtlasTexture = frames.get_frame_texture(role + "_" + str(direction), phase)
	var image := Image.create(texture.get_width(), texture.get_height(), false, Image.FORMAT_RGBA8)
	image.blit_rect(_raw(texture.atlas.resource_path), Rect2i(texture.region), Vector2i(texture.margin.position))
	assert(image.get_width() == image.get_height())
	image.resize(256, 256, Image.INTERPOLATE_NEAREST)
	var crop := image.get_region(Rect2i(28, 12, 200, 200))
	return crop

func _initialize() -> void:
	var staging: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/pr122_hero_parallel_staging.json"))
	var out := "res://docs/remake/pr122-hero-parallel/evidence/visual-review-20261023/"
	DirAccess.make_dir_recursive_absolute(out)
	for sid: String in OS.get_environment("TWILIGHT_HERO_REVIEW_IDS").split(",", false):
		var entry: Dictionary = staging.actors["transform:" + sid]
		var frames: SpriteFrames = load(entry.frames)
		var roles: Array[String] = ["idle", "run", "attack", "hit", "death"]
		var phases := Image.create(1200, 1000, false, Image.FORMAT_RGBA8)
		phases.fill(Color("343840"))
		var headings := Image.create(1600, 1000, false, Image.FORMAT_RGBA8)
		headings.fill(Color("343840"))
		for row: int in range(5):
			var role := roles[row]
			var count := frames.get_frame_count(role + "_2")
			for phase: int in range(mini(6, count)):
				phases.blend_rect(_pose(frames, role, 2, phase), Rect2i(0, 0, 200, 200), Vector2i(phase * 200, row * 200))
			for direction: int in range(8):
				headings.blend_rect(_pose(frames, role, direction, 0), Rect2i(0, 0, 200, 200), Vector2i(direction * 200, row * 200))
		assert(phases.save_png(out + sid + "-S-all-action-phases.png") == OK)
		assert(headings.save_png(out + sid + "-eight-headings.png") == OK)
	print("HERO_INTERNAL_REVIEW_SHEETS_SAVED")
	quit()
