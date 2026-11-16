extends SceneTree
## 523 tile atlases: off-main-thread GPU block compression swaps the same
## texture object; size, cell geometry and transparent cells are kept.
##   godot --headless --path <repo> --script res://tests/current523_tile_gpu_test.gd
const TILE_GPU = preload("res://scripts/maps/current523_tile_gpu.gd")
const GPU = preload("res://scripts/resources/gpu_actor_texture.gd")
var checks: int = 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("CURRENT523_TILE_GPU_FAIL: " + label)

## 16x16 cells of 24 px: solid colours, every third cell fully transparent.
func atlas(seed: int) -> Image:
	var image := Image.create_empty(384, 384, false, Image.FORMAT_RGBA8)
	for cell: int in 256:
		var colour := Color8((cell * 37 + seed) % 256, (cell * 91) % 256, (cell * 13 + 50) % 256, 0 if cell % 3 == 0 else 255)
		image.fill_rect(Rect2i((cell % 16) * 24, (cell / 16) * 24, 24, 24), colour)
	return image

func _initialize() -> void:
	_run.call_deferred()

func _drain(gpu: RefCounted) -> void:
	var deadline: int = Time.get_ticks_msec() + 20000
	while gpu.pending() > 0 and Time.get_ticks_msec() < deadline:
		gpu.pump()
		await process_frame

func _run() -> void:
	var mode: int = TILE_GPU.mode()
	if mode < 0:
		print("CURRENT523_TILE_GPU_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "skipped": "no block compression on this renderer"}))
		quit(0)
		return
	var gpu := TILE_GPU.new()
	var source: Image = atlas(0)
	var reference: Image = source.duplicate()
	var texture := ImageTexture.create_from_image(source)
	gpu.queue(texture, source)
	check(texture.get_size() == Vector2(384, 384) and texture.get_format() == Image.FORMAT_RGBA8, "the atlas is usable uncompressed at once")
	await _drain(gpu)
	check(gpu.pending() == 0 and gpu.compressed == 1, "the worker finishes and the main thread swaps it")
	check(texture.get_size() == Vector2(384, 384) and int(texture.get_meta("gpu_bytes", 0)) == 384 * 384, "same texture object, same size, 1 byte per pixel")
	check(texture.get_format() in [Image.FORMAT_ETC2_RGBA8, Image.FORMAT_DXT5], "the texture now holds block-compressed pixels: %d" % texture.get_format())
	# The queued image is the one the worker compressed and the texture took.
	var shown: Image = source
	check(shown.is_compressed() and shown.get_format() == texture.get_format(), "the swapped pixels are the worker's compressed copy")
	if shown.is_compressed():
		var back: Image = shown.duplicate()
		back.decompress()
		back.convert(Image.FORMAT_RGBA8)
		var alpha_kept: bool = true
		var colour_close: bool = true
		for cell: int in 256:
			var at := Vector2i((cell % 16) * 24 + 12, (cell / 16) * 24 + 12)
			var edge := Vector2i((cell % 16) * 24, (cell / 16) * 24)
			var want: Color = reference.get_pixelv(at)
			for point: Vector2i in [at, edge, edge + Vector2i(23, 23)]:
				var got: Color = back.get_pixelv(point)
				alpha_kept = alpha_kept and absf(got.a - want.a) < 0.02
				if want.a > 0.5: colour_close = colour_close and absf(got.r - want.r) < 0.09 and absf(got.g - want.g) < 0.09 and absf(got.b - want.b) < 0.09
		check(alpha_kept, "transparent and opaque 24 px cells keep their alpha up to the cell edges")
		check(colour_close, "cell colours survive block compression without bleeding into neighbours")
	# Bounded queue: decoded copies waiting for a worker are capped. Queue
	# without pumping so no worker can finish (and free a slot) mid-loop: the
	# bound and the drop count are then exact instead of timing dependent.
	await _drain(gpu)
	var dropped_before: int = gpu.dropped
	var many: Array = []
	var extra: int = TILE_GPU.MAX_RUNNING + 5
	for index: int in TILE_GPU.MAX_WAITING + extra:
		var image: Image = atlas(index)
		var item := ImageTexture.create_from_image(image)
		many.append(item)
		gpu.queue(item, image, false)
	check(gpu.pending() == TILE_GPU.MAX_WAITING and gpu.dropped - dropped_before == extra, "waiting copies are bounded")
	gpu.pump()
	check(gpu.pending() <= TILE_GPU.MAX_WAITING + TILE_GPU.MAX_RUNNING, "pumping keeps the running + waiting bound")
	await _drain(gpu)
	var all_sized: bool = true
	for item: ImageTexture in many: all_sized = all_sized and item.get_size() == Vector2(384, 384)
	check(all_sized and gpu.pending() == 0, "dropped atlases simply stay RGBA8")
	# Disabled or unsupported: nothing is queued.
	GPU.enabled = false
	var plain := ImageTexture.create_from_image(atlas(1))
	gpu.queue(plain, atlas(1))
	check(gpu.pending() == 0 and not plain.has_meta("gpu_bytes"), "switched off keeps RGBA8")
	GPU.enabled = true
	var odd := Image.create_empty(30, 30, false, Image.FORMAT_RGBA8)
	gpu.queue(ImageTexture.create_from_image(odd), odd)
	check(gpu.pending() == 0, "a non-multiple-of-4 image is not queued")
	gpu.finish()
	print("CURRENT523_TILE_GPU_RESULT " + JSON.stringify({"checks": checks, "failures": failures, "mode": mode}))
	quit(0 if failures.is_empty() else 1)
