extends RefCounted
## Mobile-only visual texture reduction. Source PNGs, original coordinates,
## collision/physics, navigation, spawn points and save IDs never change.
## Pass --mobile-map-quality on desktop to preview the Android rendering.
const TARGET_SCALE: float = 0.85
const OMAN_IDS: Array[String] = [
	"oman_01", "oman_02", "oman_03", "oman_04", "oman_05",
	"oman_06", "oman_07", "oman_08", "oman_09", "oman_10"
]

static func target_scale(map_id: String) -> float:
	return TARGET_SCALE if map_id in OMAN_IDS or map_id in ["domination_summit", "escaros_world"] else 1.0

static func scale_for(map_id: String) -> float:
	if OS.has_feature("mobile") or "--mobile-map-quality" in OS.get_cmdline_user_args():
		return target_scale(map_id)
	return 1.0

static func output_size(source_size: Vector2i, scale: float) -> Vector2i:
	return Vector2i(maxi(1, roundi(float(source_size.x) * scale)),
		maxi(1, roundi(float(source_size.y) * scale)))

static func pixel_count(source_size: Vector2i, scale: float) -> int:
	var size: Vector2i = output_size(source_size, scale)
	return size.x * size.y

static func pixel_ratio(source_size: Vector2i, render_size: Vector2i) -> Vector2:
	if source_size.x < 1 or source_size.y < 1: return Vector2.ONE
	return Vector2(float(render_size.x) / float(source_size.x),
		float(render_size.y) / float(source_size.y))

static func resize_image(image: Image, scale: float) -> void:
	if image == null or image.is_empty() or scale >= 1.0: return
	var size: Vector2i = output_size(image.get_size(), scale)
	if size != image.get_size():
		# Downsample decoded visuals only, then let the GPU filter up smoothly.
		# Never rewrite or rehash the source PNG pack.
		image.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
