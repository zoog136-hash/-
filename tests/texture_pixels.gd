extends RefCounted
## CPU pixels of a texture for checks, including GPU-compressed (VRAM) atlases.
## Large actor sheets import as ETC2; Texture2D.get_image() then returns a
## compressed image, and AtlasTexture.get_image() cannot crop one. Decompress
## the atlas first and crop the region like AtlasTexture.get_image() does
## (whole atlas for an empty region; margins are not added), recursively.

static func image_of(texture: Texture2D) -> Image:
	if texture == null: return null
	if texture is AtlasTexture:
		var atlas_texture := texture as AtlasTexture
		var atlas: Image = image_of(atlas_texture.atlas)
		if atlas == null or atlas.is_empty(): return atlas
		var region := Rect2i(atlas_texture.region)
		if region.size.x <= 0 or region.size.y <= 0: return atlas
		return atlas.get_region(region)
	var image: Image = texture.get_image()
	if image != null and image.is_compressed():
		image = image.duplicate() as Image
		image.decompress()
	return image
