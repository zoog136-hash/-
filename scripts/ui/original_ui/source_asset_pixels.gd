extends RefCounted
## UI-only consumer of PR270's existing exact source-UI image resolver.
## Asset joins, exclusions and file identity remain with that owner. This
## adapter only carries its original pixels into the source renderer.
const OWNER_API="res://scripts/ui/source523_source_ui_images.gd"
const PMA_PIXELS=preload("res://scripts/ui/original_ui/cocos_premultiply_pixels.gd")
const PMA_CACHE=preload("res://scripts/ui/original_ui/source_asset_pma_cache.gd")
static var _pma_cache=PMA_CACHE.new()

static func resolve(reference: Dictionary) -> Dictionary:
	if not ResourceLoader.exists(OWNER_API):return {"ok":false,"error":"source_image_owner_api_unavailable"}
	var api: Script=load(OWNER_API)
	if api==null:return {"ok":false,"error":"source_image_owner_api_unavailable"}
	var result: Dictionary=api.resolve(reference.duplicate(true))
	if not result.get("handled",false):return {"ok":false,"error":"source_image_pack_not_selected"}
	return consume_owner_result(result)

static func consume_owner_result(owner_result: Dictionary) -> Dictionary:
	# The caller already invoked the existing image owner (for example its
	# field-world adapter). Reuse that exact result without another asset
	# join, pack reader or fallback. Only the existing Cocos upload conversion
	# below is shared with source-asset Sprite rendering.
	var result: Dictionary=owner_result.duplicate(true)
	if not result.get("ok",false):
		if result.get("status")=="source_dummy_excluded" and result.get("excluded_from_connection")==true:
			var excluded_evidence: Dictionary=result.duplicate(true)
			excluded_evidence.erase("texture")
			return {"ok":true,"texture":null,"excluded":true,"evidence":excluded_evidence}
		result["error"]=str(result.get("status","source_image_unavailable"))
		return result
	var original: Texture2D=result.get("texture")
	if original==null:return {"ok":false,"error":"source_image_original_texture_missing"}
	# Cocos PNG upload premultiplication is a renderer operation on the
	# existing decoded pixels, not replacement artwork or a source-file edit.
	# JPEG/BMP retain the owner's straight/opaque texture semantics.
	var evidence: Dictionary=result.duplicate(true)
	evidence.erase("texture")
	var format_value: String=str(result.get("provenance",{}).get("member",{}).get("format",""))
	if format_value not in ["PNG","JPEG","BMP"]:return {"ok":false,"error":"source_image_pixel_format_missing"}
	if format_value=="PNG" and not bool(original.get_meta("cocos_premultiplied",false)):
		var request: Dictionary=_pma_cache.request(original,evidence)
		if request.get("texture") is Texture2D:return {"ok":true,"texture":request.texture,"evidence":evidence}
		var source: Texture2D=original
		var image: Image=original.get_image()
		if image==null or image.is_empty():return {"ok":false,"error":"source_image_original_pixels_unavailable"}
		# Some renderers return their stored Image. Own the temporary pixels
		# before decompressing/converting an RGB/LA source to the upload format.
		image=image.duplicate() as Image
		if image.is_compressed() and image.decompress()!=OK:return {"ok":false,"error":"source_image_original_pixels_unavailable"}
		image.convert(Image.FORMAT_RGBA8)
		original=ImageTexture.create_from_image(PMA_PIXELS.convert(image))
		original.set_meta("cocos_premultiplied",true)
		original.set_meta("source523_original_asset",evidence)
		_pma_cache.remember(request,source,original,original.get_width()*original.get_height()*4)
		return {"ok":true,"texture":original,"evidence":evidence}
	original.set_meta("source523_original_asset",evidence)
	return {"ok":true,"texture":original,"evidence":evidence}
