extends RefCounted
## GPU (VRAM) block compression for actor frames decoded at runtime from an
## installed external pack. Mobile MMORPGs keep character art in ASTC/ETC2;
## an uncompressed RGBA frame costs 4 bytes per pixel, ETC2/S3TC RGBA costs 1.
## Only actor body frames use this. UI, cards, icons and effects keep their
## exact original pixels. Set TWILIGHT_GPU_ACTOR_TEXTURES=0 to turn it off.
##
## Block formats need sides that are multiples of 4. Other sizes are padded
## with transparent pixels on the right/bottom and returned as an AtlasTexture
## whose region is the original size, so get_size(), offsets and anchors stay
## exactly as before.

const MIN_PIXELS: int = 32 * 32
static var enabled: bool = OS.get_environment("TWILIGHT_GPU_ACTOR_TEXTURES") != "0"
static var _mode: int = -2

static func compression_mode() -> int:
	if _mode != -2: return _mode
	_mode = -1
	if RenderingServer.has_os_feature("etc2"): _mode = Image.COMPRESS_ETC2
	elif RenderingServer.has_os_feature("s3tc"): _mode = Image.COMPRESS_S3TC
	return _mode

static func from_image(image: Image) -> Texture2D:
	if image == null or image.is_empty(): return null
	var mode: int = compression_mode() if enabled else -1
	if mode < 0 or image.is_compressed() or image.has_mipmaps() or image.get_width() * image.get_height() < MIN_PIXELS:
		return ImageTexture.create_from_image(image)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var padded_width: int = (width + 3) & ~3
	var padded_height: int = (height + 3) & ~3
	var work: Image = Image.create_empty(padded_width, padded_height, false, Image.FORMAT_RGBA8)
	var source: Image = image
	if source.get_format() != Image.FORMAT_RGBA8:
		source = image.duplicate() as Image
		source.convert(Image.FORMAT_RGBA8)
	work.blit_rect(source, Rect2i(0, 0, width, height), Vector2i.ZERO)
	# Transparent texels carry the neighbouring opaque colour, so a 4x4 block
	# on a silhouette edge does not average body colour with invisible black.
	work.fix_alpha_edges()
	if work.compress(mode, Image.COMPRESS_SOURCE_GENERIC) != OK or not work.is_compressed():
		return ImageTexture.create_from_image(image)
	var texture: ImageTexture = ImageTexture.create_from_image(work)
	if texture == null: return ImageTexture.create_from_image(image)
	texture.set_meta("gpu_bytes", work.get_data_size())
	if padded_width == width and padded_height == height: return texture
	var region := AtlasTexture.new()
	region.atlas = texture
	region.region = Rect2(0, 0, width, height)
	region.set_meta("gpu_bytes", work.get_data_size())
	return region

## Bytes the texture occupies, for owner caches that bound their memory.
static func bytes_of(texture: Texture2D, fallback: int) -> int:
	if texture != null and texture.has_meta("gpu_bytes"): return int(texture.get_meta("gpu_bytes"))
	return fallback
