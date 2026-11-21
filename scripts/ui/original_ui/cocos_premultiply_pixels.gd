extends RefCounted
## Pixel conversion for owner-supplied RGBA8 images, separate from source-pack
## metadata production so unchanged UI metadata bakes keep their producer key.
## Used by both source-pack atlas frames and owner-provided RGBA8 images.

static func convert(original: Image) -> Image:
	var pixels: PackedByteArray=original.get_data()
	# A native alpha scan is cheaper than visiting every pixel in script on
	# fully opaque backgrounds. The output still owns a separate image.
	var working_size: int=0 if original.detect_alpha()==Image.ALPHA_NONE else pixels.size()
	for at: int in range(0,working_size,4):
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
