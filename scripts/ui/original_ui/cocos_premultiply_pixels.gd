extends RefCounted
## Pixel conversion for owner-supplied RGBA8 images, separate from source-pack
## metadata production so unchanged UI metadata bakes keep their producer key.
## Used by both source-pack atlas frames and owner-provided RGBA8 images.

static func convert(original: Image, reuse_opaque: bool = false) -> Image:
	var pixels: PackedByteArray=original.get_data()
	if original.detect_alpha() == Image.ALPHA_NONE and _fully_opaque(original, pixels):
		if reuse_opaque: return original
		return Image.create_from_data(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8,pixels)
	for at: int in range(0,pixels.size(),4):
		# decode/encode_u32 use explicit little-endian byte order. The two
		# separated red/blue lanes cannot carry into one another (255*256
		# fits in 16 bits). Preserve Cocos' (channel*(alpha+1))>>8 exactly;
		# Image.premultiply_alpha uses a different rounding rule.
		var rgba: int=pixels.decode_u32(at)
		# Both words are already the exact desired output: opaque pixels keep
		# their RGB, and a transparent black pixel already has zero RGB.
		if rgba>=0xff000000 or rgba==0:continue
		var alpha_plus_one: int=(rgba>>24)+1
		var red_blue: int=(((rgba&0x00ff00ff)*alpha_plus_one)>>8)&0x00ff00ff
		var green: int=((((rgba>>8)&255)*alpha_plus_one)>>8)<<8
		pixels.encode_u32(at,red_blue|green|(rgba&0xff000000))
	return Image.create_from_data(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8,pixels)

## Godot treats alpha 254 as opaque. Only 254 and 255 are possible after
## ALPHA_NONE on RGBA8. Search for 254 in the alpha lane; RGB can also
## contain 254, so bound the number of script calls on bright images.
static func _fully_opaque(original: Image, pixels: PackedByteArray) -> bool:
	var start: int = 0
	for _candidate: int in 64:
		var at: int = pixels.find(254, start)
		if at < 0: return true
		if at % 4 == 3: return false
		start = at + 1
	return original.detect_used_channels() not in [Image.USED_CHANNELS_LA, Image.USED_CHANNELS_RGBA]
