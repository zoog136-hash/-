extends RefCounted

# Original 9-slice metal/cloth study, not a sampled Lineage M texture.
# Built once per palette; no per-frame Image/ImageTexture construction.
static var textures: Dictionary = {}

static func from_flat(base: StyleBoxFlat, inset: bool = false) -> StyleBoxTexture:
	var key := base.bg_color.to_html()+":"+base.border_color.to_html()+":"+str(inset)
	if not textures.has(key):
		var fill := base.bg_color.to_html(false)
		var rim := base.border_color.to_html(false)
		var upper := "#000000" if inset else "#e2d6ba"
		var lower := "#b8a78e" if inset else "#000000"
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">'
		var top: String = base.bg_color.darkened(.30).to_html(false) if inset else base.bg_color.lightened(.065).to_html(false)
		var bottom: String = base.bg_color.lightened(.015).to_html(false) if inset else base.bg_color.darkened(.24).to_html(false)
		svg += '<defs><linearGradient id="surface" x2="0" y2="1"><stop stop-color="#%s"/><stop offset="0.45" stop-color="#%s"/><stop offset="1" stop-color="#%s"/></linearGradient></defs>' % [top,fill,bottom]
		svg += '<rect width="32" height="32" fill="url(#surface)"/><rect x="0.5" y="0.5" width="31" height="31" fill="none" stroke="#%s"/>' % rim
		svg += '<path d="M2 29V2H29" fill="none" stroke="%s" stroke-opacity="0.26"/><path d="M3 29H29V3" fill="none" stroke="%s" stroke-opacity="0.32"/>' % [upper,lower]
		svg += '<path d="M4 5H28 M4 9H28 M4 17H28 M4 25H28" stroke="#d7c8aa" stroke-opacity="0.025"/><path d="M4 6H28 M4 14H28 M4 22H28 M4 27H28" stroke="#000000" stroke-opacity="0.045"/>'
		svg += '</svg>'
		var image := Image.new()
		if image.load_svg_from_string(svg) == OK:
			textures[key] = ImageTexture.create_from_image(image)
	var result := StyleBoxTexture.new()
	result.texture = textures.get(key)
	result.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	result.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		result.set_texture_margin(side,4)
		result.set_content_margin(side,base.get_content_margin(side))
	result.modulate_color.a = base.bg_color.a
	return result
