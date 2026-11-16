extends RefCounted
## Original 523 map picture and Korean name of a current523 Land.
## UIMapWorld (LandID, DescID, MapImageInfoID) -> UIMapImageInfo (ImageID,
## Ratio, BaseLoc, BasePixel) -> AssetView/AssetType (the original
## "Image/Map/W_*.png" bytes from the installed image pack). Nothing is drawn,
## generated or substituted: without the picture the caller keeps its own view.
## Placement uses the same OWN registration as the world-map click owner
## (current523_world_map_coordinates.gd): Ratio is field canvas units per image
## pixel along the field canvas axes and BaseLoc names a cell centre, so the
## whole picture covers world Rect2(W(BaseLoc) - BasePixel*Ratio, size*Ratio).
const DEF = preload("res://scripts/resources/current523_definition_rows.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const POLICY: String = "OWN_SOURCE_CELL_CENTER_FIELD_RATIO_V1"
## Display copy for the minimap only: the original picture is shrunk on the
## device (no new pixels) so a 3200 px map does not stay resident at full size.
const MINIMAP_MAX_EDGE: int = 1024
const EXCLUDED_NAME_TAGS: Array[String] = ["[테스트]"]
static var _cache: Dictionary = {}

static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

## The Land's UIMapWorld row that carries a picture (lowest ID), or {}.
static func world_row(land_id: int) -> Dictionary:
	if land_id < 0 or DEF.row_count("UIMapWorld") <= 0: return {}
	var best: Dictionary = {}
	for row: Dictionary in DEF.related("UIMapWorld", "LandID", land_id):
		var name: String = str(row.get("Name", ""))
		var tagged: bool = false
		for tag: String in EXCLUDED_NAME_TAGS: tagged = tagged or name.contains(tag)
		if tagged or not _integer(row.get("MapImageInfoID")) or int(row.MapImageInfoID) <= 0: continue
		var info: Dictionary = DEF.row("UIMapImageInfo", int(row.MapImageInfoID))
		if info.is_empty() or not _integer(info.get("ImageID")) or int(info.ImageID) <= 0 or float(info.get("Ratio", 0.0)) <= 0.0: continue
		if best.is_empty() or int(row.ID) < int(best.ID): best = row
	return best

## Original Korean name of the Land (UIMapWorld.DescID -> DescData_Korean), or "".
static func korean_name(land_id: int) -> String:
	if land_id < 0 or DEF.row_count("UIMapWorld") <= 0: return ""
	var rows: Array[Dictionary] = DEF.related("UIMapWorld", "LandID", land_id)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.ID) < int(b.ID))
	for row: Dictionary in rows:
		if not _integer(row.get("DescID")) or int(row.DescID) <= 0: continue
		var text: String = str(DEF.row("DescData_Korean", int(row.DescID)).get("Description", "")).strip_edges()
		var tagged: bool = false
		for tag: String in EXCLUDED_NAME_TAGS: tagged = tagged or text.contains(tag) or str(row.get("Name", "")).contains(tag)
		if not text.is_empty() and not tagged: return text
	return ""

## World rectangle covered by an image of `size` pixels for this field.
static func world_rect(coordinates: Object, info: Dictionary, size: Vector2) -> Rect2:
	if coordinates == null or not coordinates.get("valid") or size.x <= 0 or size.y <= 0: return Rect2()
	for key: String in ["Ratio", "BaseLocX", "BaseLocY", "BasePixelX", "BasePixelY"]:
		if not (info.get(key) is int or info.get(key) is float): return Rect2()
	var ratio: float = float(info.Ratio)
	if ratio <= 0.0: return Rect2()
	var anchor: Vector2 = coordinates.components_to_world([float(info.BaseLocX) + 0.5, float(info.BaseLocY) + 0.5])
	if not anchor.is_finite(): return Rect2()
	return Rect2(anchor - Vector2(float(info.BasePixelX), float(info.BasePixelY)) * ratio, size * ratio)

## Original image pixel of a world point for a UIMapWorld row (same OWN
## registration as world_rect), or Vector2.INF.
static func image_pixel(coordinates: Object, world_id: int, point: Vector2) -> Vector2:
	var world: Dictionary = DEF.row("UIMapWorld", world_id) if DEF.row_count("UIMapWorld") > 0 else {}
	if world.is_empty() or not _integer(world.get("MapImageInfoID")): return Vector2.INF
	var info: Dictionary = DEF.row("UIMapImageInfo", int(world.MapImageInfoID))
	var rect: Rect2 = world_rect(coordinates, info, Vector2.ONE)
	if not rect.has_area() or not point.is_finite(): return Vector2.INF
	return (point - rect.position) / float(info.Ratio)

## {ok, texture, world_rect, world_id, image_info_id, path} for the field's
## Land, or {ok:false, reason}. The texture is a shrunk display copy.
static func minimap_image(field: Object) -> Dictionary:
	if field == null or not bool(field.get_meta("current523_source_field", false)) or not field.get("data") is Dictionary:
		return {"ok": false, "reason": "current523_source_field_required"}
	var land_id: int = int(field.data.get("source_land_id", -1))
	var world: Dictionary = world_row(land_id)
	if world.is_empty(): return {"ok": false, "reason": "original_map_picture_not_declared", "land_id": land_id}
	var info: Dictionary = DEF.row("UIMapImageInfo", int(world.MapImageInfoID))
	var assets: Array[Dictionary] = DEF.related("AssetView", "AssetId", int(info.ImageID)) if DEF.row_count("AssetView") > 0 else ([] as Array[Dictionary])
	var asset: Dictionary = assets[0] if assets.size() == 1 else {}
	var type: Dictionary = DEF.row("AssetType", int(asset.get("AssetTypeId", -1))) if not asset.is_empty() else {}
	var path: String = str(type.get("Path", "")) + str(asset.get("FilePath", ""))
	if asset.is_empty() or type.is_empty(): return {"ok": false, "reason": "original_map_asset_row_missing", "image_id": int(info.ImageID)}
	var key: String = "%d:%d:%s" % [int(world.ID), int(info.ID), path]
	var texture: Texture2D = null
	var source_size := Vector2.ZERO
	if _cache.has(key) and is_instance_valid(_cache[key].texture) and _cache[key].pack == IMAGES.active():
		texture = _cache[key].texture
		source_size = _cache[key].source_size
	else:
		var decoded: Dictionary = _decode_original(int(info.ImageID), int(asset.AssetTypeId), path)
		if not decoded.get("ok", false):
			return {"ok": false, "reason": "original_map_picture_unavailable:" + str(decoded.get("reason", "")), "path": path}
		var image: Image = decoded.image
		source_size = Vector2(image.get_size())
		var longest: float = maxf(source_size.x, source_size.y)
		if longest > MINIMAP_MAX_EDGE:
			var scale: float = float(MINIMAP_MAX_EDGE) / longest
			image.resize(maxi(1, roundi(source_size.x * scale)), maxi(1, roundi(source_size.y * scale)), Image.INTERPOLATE_BILINEAR)
		texture = ImageTexture.create_from_image(image)
		_cache.clear()
		_cache[key] = {"texture": texture, "source_size": source_size, "pack": IMAGES.active()}
	var rect: Rect2 = world_rect(field.get("coordinates"), info, source_size)
	if not rect.has_area(): return {"ok": false, "reason": "original_map_registration_invalid"}
	return {"ok": true, "texture": texture, "world_rect": rect, "world_id": int(world.ID), "image_info_id": int(info.ID),
		"path": path, "source_size": source_size, "coordinate_policy": POLICY, "native_image_info_formula_confirmed": false}

## Verified original bytes of one map asset decoded for the minimap copy only.
## The pack's own checks (typed AssetView row, verified status, declared path,
## member size/SHA) run first; the full-size picture is not admitted to the
## shared icon texture cache (it would take most of its 32 MB budget).
static func _decode_original(asset_id: int, asset_type: int, path: String) -> Dictionary:
	var pack: Variant = IMAGES.active()
	if not pack is RefCounted: return {"ok": false, "reason": "source523_image_pack_not_selected"}
	for method: String in ["_has_asset", "_asset", "_has_member", "_member", "_bytes"]:
		if not pack.has_method(method): return {"ok": false, "reason": "image_pack_reader_api_missing"}
	if not pack.call("_has_asset", asset_id): return {"ok": false, "reason": "missing_asset_key"}
	var row: Dictionary = pack.call("_asset", asset_id)
	if int(row.get("asset_type_id", -1)) != asset_type or str(row.get("path", "")) != path or str(row.get("status", "")) != "verified_original":
		return {"ok": false, "reason": "asset_not_verified_original"}
	if not pack.call("_has_member", path): return {"ok": false, "reason": "missing_current_member"}
	var member: Dictionary = pack.call("_member", path)
	var checked: Dictionary = pack.call("_bytes", {"path": member.get("file", ""), "bytes": member.get("plain_bytes", -1), "sha256": member.get("sha256", "")})
	if not checked.get("ok", false): return {"ok": false, "reason": str(checked.get("status", "original_bytes_unverified"))}
	var image := Image.new()
	var error: Error = ERR_FILE_UNRECOGNIZED
	match str(member.get("format", "")):
		"PNG": error = image.load_png_from_buffer(checked.bytes)
		"JPEG": error = image.load_jpg_from_buffer(checked.bytes)
		"BMP": error = image.load_bmp_from_buffer(checked.bytes)
	if error != OK or image.is_empty() or image.get_width() != int(member.get("width", -1)) or image.get_height() != int(member.get("height", -1)):
		return {"ok": false, "reason": "original_image_decode_failed"}
	return {"ok": true, "image": image}

## Original UIMapArea zones of the Land (village/dungeon/field/spot names from
## DescData_Korean over their Territories rectangle), smallest first.
static var _areas: Dictionary = {}

static func areas(land_id: int) -> Array:
	if _areas.has(land_id): return _areas[land_id]
	var result: Array = []
	var world: Dictionary = world_row(land_id)
	if not world.is_empty() and DEF.row_count("UIMapArea") > 0:
		for row: Dictionary in DEF.related("UIMapArea", "WorldID", int(world.ID)):
			if row.get("IsHide") == true or not _integer(row.get("TerritoryID")) or not _integer(row.get("DescID")): continue
			var territory: Dictionary = DEF.row("Territories", int(row.TerritoryID))
			if territory.is_empty() or int(territory.get("LandID", -1)) != land_id: continue
			var text: String = str(DEF.row("DescData_Korean", int(row.DescID)).get("Description", "")).strip_edges()
			if text.is_empty(): continue
			var box := Rect2i(int(territory.StartX), int(territory.StartY), int(territory.EndX) - int(territory.StartX) + 1, int(territory.EndY) - int(territory.StartY) + 1)
			if box.size.x < 1 or box.size.y < 1: continue
			result.append({"rect": box, "name": text, "area_id": int(row.ID), "type_id": int(row.get("TypeID", 0))})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rect.get_area() < b.rect.get_area())
	_areas[land_id] = result
	return result

## Smallest original zone {rect, name, area_id, type_id} at a source cell, or {}.
static func area_at(land_id: int, cell: Vector2i) -> Dictionary:
	for area: Dictionary in areas(land_id):
		if (area.rect as Rect2i).has_point(cell): return area
	return {}

static func clear_cache() -> void:
	_cache.clear()
	_areas.clear()
