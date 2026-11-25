extends RefCounted
## Shared original atlas rotation/trim reconstruction. No resized/replacement art.

const PMA_PIXELS = preload("res://scripts/ui/original_ui/cocos_premultiply_pixels.gd")
## Only the pack opts immutable, verified pages in. The proof belongs to
## that decoded page and covers its packed rectangle, independent of rotation.
const OPAQUE_CROPS := &"twilight_verified_opaque_atlas_crops"

static func decode(page: Image, spec: Dictionary, premultiply: bool = false) -> Dictionary:
	for field: String in ["rect", "source_rect", "source_size"]:
		if not spec.get(field) is Array:
			return {"error":"invalid_frame_spec"}
	if spec.rect.size()!=4 or spec.source_rect.size()!=4 or spec.source_size.size()!=2:
		return {"error":"invalid_frame_spec"}
	var rect: Array=spec.rect
	var packed_size:=Vector2i(rect[3],rect[2]) if spec.get("rotated",false) else Vector2i(rect[2],rect[3])
	var region:=Rect2i(Vector2i(rect[0],rect[1]),packed_size)
	if page==null or packed_size.x<=0 or packed_size.y<=0 or not Rect2i(Vector2i.ZERO,page.get_size()).encloses(region):
		return {"error":"frame_out_of_page"}
	var trimmed: Image=page.get_region(region)
	if spec.get("rotated",false): trimmed.rotate_90(COUNTERCLOCKWISE)
	var source_rect: Array=spec.source_rect
	if trimmed.get_size()!=Vector2i(source_rect[2],source_rect[3]):
		return {"error":"trim_size_mismatch"}
	var canvas:=Vector2i(spec.source_size[0],spec.source_size[1])
	var target:=Rect2i(Vector2i(source_rect[0],source_rect[1]),trimmed.get_size())
	if canvas.x<=0 or canvas.y<=0 or canvas.x>16384 or canvas.y>16384 or not Rect2i(Vector2i.ZERO,canvas).encloses(target):
		return {"error":"trim_out_of_canvas"}
	# Restored padding is transparent black in either pixel mode. Convert
	# the packed content before allocating the full-size sprite canvas.
	if premultiply:
		var known_opaque: Dictionary = page.get_meta(OPAQUE_CROPS, {})
		if not known_opaque.has(region):
			var converted: Image = PMA_PIXELS.convert(trimmed, true)
			if is_same(trimmed, converted): known_opaque[region] = true
			trimmed = converted
	# get_region() already owns its pixels. A full-size RGBA8 crop can go
	# straight to the caller, including after rotation, without a second image.
	if target.position==Vector2i.ZERO and target.size==canvas and trimmed.get_format()==Image.FORMAT_RGBA8 and not trimmed.has_mipmaps():
		return {"error":"","image":trimmed}
	var result:=Image.create(canvas.x,canvas.y,false,Image.FORMAT_RGBA8)
	result.blit_rect(trimmed,Rect2i(Vector2i.ZERO,trimmed.get_size()),target.position)
	return {"error":"", "image":result}
