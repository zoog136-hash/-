extends SceneTree
## Runtime actor-frame GPU compression keeps size, anchors and visible pixels.
## Needs a real renderer for the compressed path (headless reports no format and
## must fall back to the exact uncompressed texture).

const GPU = preload("res://scripts/resources/gpu_actor_texture.gd")
const PIXELS = preload("res://tests/texture_pixels.gd")
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func _frame(width: int, height: int) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	for y: int in height:
		for x: int in width:
			var inside: bool = absf(x - width * .5) < width * .35 and absf(y - height * .5) < height * .4
			image.set_pixel(x, y, Color(float(x) / width, float(y) / height, .4, 1.0) if inside else Color(0, 0, 0, 0))
	return image

func _initialize() -> void:
	var mode: int = GPU.compression_mode()
	var compressed_expected: bool = mode >= 0
	for size: Vector2i in [Vector2i(64, 96), Vector2i(97, 121), Vector2i(130, 61)]:
		var source: Image = _frame(size.x, size.y)
		var texture: Texture2D = GPU.from_image(source)
		check(texture != null, "texture created %s" % size)
		check(Vector2i(texture.get_size()) == size, "size unchanged %s -> %s" % [size, texture.get_size()])
		var pixels: Image = PIXELS.image_of(texture)
		check(pixels != null and pixels.get_size() == size, "pixels readable %s" % size)
		var worst_alpha: float = 0.0
		var worst_color: float = 0.0
		var total_color: float = 0.0
		var opaque: int = 0
		for y: int in size.y:
			for x: int in size.x:
				var a: Color = source.get_pixel(x, y)
				var b: Color = pixels.get_pixel(x, y)
				worst_alpha = maxf(worst_alpha, absf(a.a - b.a))
				if a.a > .5:
					var d: float = maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
					worst_color = maxf(worst_color, d); total_color += d; opaque += 1
		check(worst_alpha <= .02, "transparency kept %s (%.3f)" % [size, worst_alpha])
		var mean_color: float = total_color / maxf(1.0, opaque)
		print("GPU_ACTOR_TEXTURE_ERROR %s worst=%.3f mean=%.4f" % [size, worst_color, mean_color])
		check(worst_color <= .2 and mean_color <= .03, "colour close %s (worst %.3f mean %.4f)" % [size, worst_color, mean_color])
		var expected: int = ((size.x + 3) & ~3) * ((size.y + 3) & ~3) if compressed_expected else size.x * size.y * 4
		check(GPU.bytes_of(texture, size.x * size.y * 4) == expected, "byte charge %s" % size)
		if not compressed_expected: check(pixels.get_data() == source.get_data(), "uncompressed fallback is exact %s" % size)
	var tiny: Texture2D = GPU.from_image(_frame(16, 16))
	check(tiny is ImageTexture and GPU.bytes_of(tiny, 1024) == 1024, "tiny frames stay uncompressed")
	GPU.enabled = false
	var off: Texture2D = GPU.from_image(_frame(64, 64))
	check(off is ImageTexture and PIXELS.image_of(off).get_data() == _frame(64, 64).get_data(), "disabled switch keeps exact pixels")
	GPU.enabled = true
	print("GPU_ACTOR_TEXTURE_RESULT ", JSON.stringify({"mode": mode, "compressed": compressed_expected, "failures": failures}))
	if failures.is_empty(): print("GPU_ACTOR_TEXTURE_OK")
	else:
		for f: String in failures: print("GPU_ACTOR_TEXTURE_FAIL: ", f)
	quit(0 if failures.is_empty() else 1)
