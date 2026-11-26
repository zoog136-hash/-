extends RefCounted
## Original 523 background selection. The logical Land.ID owns this lookup;
## never use the numeric terrain directory or Land.BackgroundTypeId instead.
## describe() is metadata only. The terrain renderer may draw RenderType 11
## on original flagged floor slots, never as an unconditional camera background.
const DEFINITIONS = preload("res://scripts/resources/current523_definition_rows.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const RAW = preload("res://scripts/maps/current523_aden_pack.gd")
const TABLE := "MapBackgroundView"
const IMAGE_TYPE := 3
const PREFIX := "Image/MapBG/"
const DREAM_LAND := 22801
const DREAM_ASSET_PATH := "303/"
const DREAM_PRIVATE_DIR := "user://source523_map_bg/"
const DREAM_SHA := {
	"normal_cloud_sky.png":"92af0868a00a7b35724c9514a8b107b34b312d0f0c982f112c905c609d73292f",
	"normal_cloud.png":"ba51b07c3b4ea71e3cdc640fd09dc5fc2c3201f578b2f4559951f6c76ae8ccf7",
}
const DREAM_SIZE := {"normal_cloud_sky.png":Vector2i(384,384),"normal_cloud.png":Vector2i(768,768)}
const DREAM_BYTES := {"normal_cloud_sky.png":71845,"normal_cloud.png":179853}

## Exact 523 Map/303 floor refs whose original Tile/47.ti2 frames carry 0x08.
## All thirty admitted source chunks were checked. Never hide Tile47 as a
## whole, and never treat a cover/object with this same ref as a floor slot.
static func dream_floor_background(layer: int, ref: int) -> bool:
	return layer == -2 and (ref == ((47 << 8) | 199) or ref == ((47 << 8) | 202))

## Keep visual readiness separate from the metadata-only describe() call.
## The fallback is two strictly pinned private originals, not a UI substitute.
static func dream_layers(land_id: int, asset_path: String, private_dir: String=DREAM_PRIVATE_DIR) -> Dictionary:
	if land_id != DREAM_LAND or asset_path != DREAM_ASSET_PATH: return {}
	var result: Dictionary = resolve_layers(land_id)
	if result.get("ok",false) and result.get("render_type") == 11 \
		and result.sky.get("path") == PREFIX+"normal_cloud_sky.png" and result.cloud.get("path") == PREFIX+"normal_cloud.png" \
		and result.sky.get("sha256") == DREAM_SHA["normal_cloud_sky.png"] and result.cloud.get("sha256") == DREAM_SHA["normal_cloud.png"] \
		and result.sky.texture.get_size() == Vector2(384,384) and result.cloud.texture.get_size() == Vector2(768,768):
		return {"sky":result.sky.texture,"cloud":result.cloud.texture}
	var pair: Dictionary = {}
	for role: String in ["sky","cloud"]:
		var file: String = "normal_cloud_sky.png" if role=="sky" else "normal_cloud.png"
		var path: String = private_dir.path_join(file)
		if not FileAccess.file_exists(path) or FileAccess.get_size(path) != int(DREAM_BYTES[file]): return {}
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
		if RAW._hash(bytes) != DREAM_SHA[file]: return {}
		var image := Image.new()
		if image.load_png_from_buffer(bytes) != OK or image.get_size() != DREAM_SIZE[file]: return {}
		pair[role] = ImageTexture.create_from_image(image)
	return pair

static func describe(land_id: int) -> Dictionary:
	if land_id <= 0:
		return _failure("invalid_logical_land", land_id)
	if DEFINITIONS.identity().is_empty() or DEFINITIONS.row_count(TABLE) <= 0:
		return _failure("background_definitions_unavailable", land_id)
	var matches: Array[Dictionary] = DEFINITIONS.related(TABLE, "ID", land_id)
	if matches.is_empty():
		return _failure("background_not_declared", land_id)
	if matches.size() != 1:
		return _failure("background_ambiguous", land_id)
	var row: Dictionary = matches[0]
	if not _positive_int(row.get("RenderType")) or int(row.RenderType) not in [1, 11]:
		return _failure("background_render_type_unsupported", land_id)
	var render_type: int = int(row.RenderType)
	if DEFINITIONS.row("Land", land_id).is_empty():
		return _failure("background_land_unverified", land_id)
	if DEFINITIONS.row("AssetType", IMAGE_TYPE).get("Path") != PREFIX:
		return _failure("background_asset_type_unverified", land_id)
	var sky: Dictionary = _asset(row.get("SkyAssetId"))
	var cloud: Dictionary = _asset(row.get("CloudAssetId")) if render_type == 11 else {}
	if sky.is_empty() or (render_type == 11 and cloud.is_empty()):
		return _failure("background_asset_unverified", land_id)
	return {"ok": true, "land_id": land_id, "render_type": render_type, "sky": sky,
		"cloud": cloud, "draw_type_source": row.get("DrawType"), "draw_ready": false,
		"reason": "background_placement_and_floor_mask_not_validated"}

## Verify and load only the assets for a specific admitted Land. No calls on
## loading or per-frame paths until the compositor is independently validated.
static func resolve_layers(land_id: int) -> Dictionary:
	var binding: Dictionary = describe(land_id)
	if not binding.ok:
		return binding
	for role: String in ["sky", "cloud"]:
		var asset: Dictionary = binding[role]
		if asset.is_empty():
			continue
		var resolved: Dictionary = IMAGES.resolve_asset(int(asset.id), IMAGE_TYPE, str(asset.path))
		if not resolved.get("ok", false) or not resolved.get("texture") is Texture2D:
			return _failure("background_%s_unavailable:%s" % [role, resolved.get("status", "missing_texture")], land_id)
		asset["texture"] = resolved.texture
		asset["sha256"] = str(resolved.get("provenance",{}).get("member",{}).get("sha256",""))
	return binding

static func _asset(value: Variant) -> Dictionary:
	if not _positive_int(value):
		return {}
	var id: int = int(value)
	var matches: Array[Dictionary] = DEFINITIONS.related("AssetView", "AssetId", id)
	if matches.size() != 1 or matches[0].get("AssetTypeId") != IMAGE_TYPE:
		return {}
	var filename: Variant = matches[0].get("FilePath")
	if not filename is String or filename.is_empty() or filename.get_file() != filename or filename.contains("\\") or not filename.ends_with(".png"):
		return {}
	return {"id": id, "path": PREFIX + filename}

static func _positive_int(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) > 0.0 and float(value) <= 2147483647.0

static func _failure(reason: String, land_id: int) -> Dictionary:
	return {"ok": false, "reason": reason, "land_id": land_id, "draw_ready": false}
