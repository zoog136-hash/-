extends RefCounted

# Plain flat surfaces. The former self-drawn SVG metal/cloth 9-slice textures
# were removed (user rule 2026-11-17: no self-made images). Panels keep a
# single flat colour so text and buttons stay readable and tappable.
static func window_frame() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17130f")
	style.border_color = Color("44392c")
	style.set_border_width_all(1)
	for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_content_margin(side,14)
	return style

static func from_flat(base: StyleBoxFlat, _inset: bool = false) -> StyleBoxFlat:
	return base.duplicate() as StyleBoxFlat
