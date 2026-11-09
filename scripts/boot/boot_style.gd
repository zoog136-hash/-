extends RefCounted
## Opaque look shared by the loading screen and the pack installers.
## The installers draw over the game; translucent default panels made their
## buttons hard to see, so everything here is fully opaque and high contrast.
const BACKDROP := "res://assets/boot/twilight_loading.png"
const GOLD := Color("f0d38c")
const TEXT := Color("fff6e0")
const MUTED := Color("cdbf9f")
const PANEL := Color(0.06, 0.05, 0.10, 0.94)

static func backdrop() -> Control:
	# A TextureRect when the image is in the build, else a plain dark fill.
	var texture: Texture2D = load(BACKDROP) as Texture2D if ResourceLoader.exists(BACKDROP) else null
	if texture == null:
		var fill := ColorRect.new()
		fill.color = Color("0b0a16")
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fill.mouse_filter = Control.MOUSE_FILTER_STOP
		return fill
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_STOP
	return picture

static func box(radius: int, fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func panel() -> PanelContainer:
	var value := PanelContainer.new()
	value.add_theme_stylebox_override("panel", box(14, PANEL, Color(GOLD, 0.55)))
	return value

static func label(text: String = "", size: int = 22, color: Color = TEXT) -> Label:
	var value := Label.new()
	value.text = text
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	value.add_theme_constant_override("outline_size", 4)
	return value

## A solid button: gold for the main action, dark with a gold edge otherwise.
static func button(text: String, primary: bool = true, height: int = 68) -> Button:
	var value := Button.new()
	value.text = text
	value.custom_minimum_size = Vector2(420, height)
	value.add_theme_font_size_override("font_size", 26 if primary else 22)
	var normal: Color = Color("c9963f") if primary else Color("2a2236")
	var hover: Color = Color("e0ad55") if primary else Color("3a3048")
	var pressed: Color = Color("a8792d") if primary else Color("1f1a29")
	var edge: Color = Color("ffe3a1") if primary else GOLD
	value.add_theme_stylebox_override("normal", box(12, normal, edge))
	value.add_theme_stylebox_override("hover", box(12, hover, edge))
	value.add_theme_stylebox_override("pressed", box(12, pressed, edge))
	value.add_theme_stylebox_override("focus", box(12, Color(0, 0, 0, 0), Color.WHITE, 3))
	value.add_theme_stylebox_override("disabled", box(12, Color("3b3640"), Color("6d6676")))
	var ink: Color = Color("1b1208") if primary else TEXT
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		value.add_theme_color_override(state, ink)
	value.add_theme_color_override("font_disabled_color", Color("a9a2b2"))
	return value

static func progress_bar() -> ProgressBar:
	var value := ProgressBar.new()
	value.custom_minimum_size = Vector2(560, 18)
	value.show_percentage = false
	value.add_theme_stylebox_override("background", box(9, Color(0.02, 0.02, 0.05, 0.85), Color(GOLD, 0.45), 1))
	var fill := box(9, GOLD, Color("ffe9b5"), 1)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	value.add_theme_stylebox_override("fill", fill)
	return value

## The full-screen installer frame: backdrop, then a centered opaque panel.
## Returns the VBox to fill.
static func installer_frame(layer: CanvasLayer) -> VBoxContainer:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(root)
	root.add_child(backdrop())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 330
	root.add_child(center)
	var frame := panel()
	frame.custom_minimum_size = Vector2(720, 0)
	center.add_child(frame)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	frame.add_child(column)
	return column
