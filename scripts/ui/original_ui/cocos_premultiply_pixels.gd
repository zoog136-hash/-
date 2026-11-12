extends RefCounted
## Pixel conversion for owner-supplied RGBA8 images, separate from source-pack
## metadata production so unchanged UI metadata bakes keep their producer key.
## The original SourcePack.cocos_premultiply remains the reference/atlas path.

static func convert(original: Image) -> Image:
	var pixels: PackedByteArray=original.get_data()
	for at: int in range(0,pixels.size(),4):
		# decode/encode_u32 use explicit little-endian byte order. The two
		# separated red/blue lanes cannot carry into one another (255*256
		# fits in 16 bits). Preserve Cocos' (channel*(alpha+1))>>8 exactly;
		# Image.premultiply_alpha uses a different rounding rule.
		var rgba: int=pixels.decode_u32(at)
		var alpha_plus_one: int=(rgba>>24)+1
		var red_blue: int=(((rgba&0x00ff00ff)*alpha_plus_one)>>8)&0x00ff00ff
		var green: int=((((rgba>>8)&255)*alpha_plus_one)>>8)<<8
		pixels.encode_u32(at,red_blue|green|(rgba&0xff000000))
	return Image.create_from_data(original.get_width(),original.get_height(),false,Image.FORMAT_RGBA8,pixels)
