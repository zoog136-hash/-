extends RefCounted
## Presentation overrides confined to the two growth workspaces.
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const TEXT = Color("eee5d3")
const MUTED = Color("aa9f91")
const GOLD = Color("dec28a")
const RIM = Color("665341")

static func plate(fill: Color, rim: Color = RIM, margin: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(1)
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin
	box.shadow_size = 0
	return box

static func button(fill: Color = Color("302126")) -> StyleBoxFlat:
	var box := plate(fill, Color("866a4b"), 6)
	box.border_width_top = 2
	box.border_width_bottom = 2
	return box

static func tab(active: bool) -> StyleBoxFlat:
	var box := plate(Color("29212a") if active else Color(.02,.02,.03,.58), GOLD if active else Color("433744"), 4)
	box.border_width_left = 0
	box.border_width_right = 0
	box.border_width_top = 0
	box.border_width_bottom = 2 if active else 1
	return box

static func make_theme() -> Theme:
	var theme := Theme.new()
	var readable := FontVariation.new()
	readable.base_font = FONT
	readable.variation_opentype = {2003265652:500.0}
	theme.default_font = readable
	theme.default_font_size = 14
	for type: String in ["Label", "Button"]:
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_outline_color", type, Color.TRANSPARENT)
		theme.set_constant("outline_size", type, 0)
		theme.set_color("font_shadow_color", type, Color(0,0,0,.75))
		theme.set_constant("shadow_offset_y", type, 1)
	theme.set_stylebox("normal", "Button", button())
	theme.set_stylebox("hover", "Button", button(Color("46323a")))
	theme.set_stylebox("pressed", "Button", button(Color("5c4350")))
	theme.set_stylebox("disabled", "Button", plate(Color("14151b"), Color("423c3b"), 6))
	theme.set_color("font_disabled_color", "Button", Color("827b77"))
	theme.set_color("font_hover_color", "Button", Color("fff2d3"))
	theme.set_color("font_pressed_color", "Button", GOLD)
	var focus := plate(Color.TRANSPARENT, GOLD, 0)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_constant("separation", "VBoxContainer", 6)
	theme.set_constant("separation", "HBoxContainer", 8)
	return theme
