extends RefCounted

# TWILIGHT's own midnight-metal visual language, inspired by the functional
# hierarchy of Lineage M: compact gold-framed panels, inset item slots and
# legible parchment copy. No source-game textures are bundled.
const ITEM_ART = preload("res://scripts/ui/item_icon_art.gd")

const GOLD = Color("e2c187")
const BRONZE = Color("786342")
const TEXT = Color("f0e8d9")
const MUTED = Color("afa28d")
const SLATE = Color("101114")
const DEEP = Color("0b0b0e")
const RAISED = Color("24201a")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const GRADES = {"일반":Color("ddd6c5"),"고급":Color("79bf83"),"희귀":Color("73b4ee"),"영웅":Color("e97772"),"전설":Color("bc89e3"),"신화":Color("e5be60"),"유일":Color("66dfc2")}

static func grade(value: String) -> Color:
	return GRADES.get(value, TEXT)

static func box(bg: Color = Color(0.035,0.035,0.044,0.97), border: Color = BRONZE, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	s.shadow_color = Color(0,0,0,0.40)
	s.shadow_size = 4
	s.shadow_offset = Vector2(0,2)
	return s

static func chrome_panel(bg: Color = Color("0c0d11"), rim: Color = GOLD, margin: int = 12) -> StyleBoxFlat:
	var s := box(bg, rim, margin)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.shadow_size = 9
	s.shadow_color = Color(0,0,0,.55)
	return s

static func slot_frame(rim: Color = BRONZE, active: bool = false) -> StyleBoxFlat:
	var s := box(Color("29251d") if active else Color("16171a"), GOLD if active else rim, 3)
	s.set_corner_radius_all(1)
	s.shadow_size = 0
	return s

static func tab_frame(active: bool = false) -> StyleBoxFlat:
	var s := box(Color("463620") if active else Color("17171b"), GOLD if active else Color("3e3529"), 7)
	s.set_corner_radius_all(1)
	s.shadow_size = 0
	if active:
		s.border_width_bottom = 2
	return s

static func _divider(vertical: bool) -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = Color("755d3c")
	line.thickness = 1
	line.vertical = vertical
	return line

static func make_theme() -> Theme:
	var t := Theme.new()
	var readable := FontVariation.new()
	readable.base_font = FONT
	# Font axes use integer OpenType tags (wght), not string keys.
	readable.variation_opentype = {2003265652:500.0}
	t.default_font = readable
	t.default_font_size = 14

	for type: String in ["Label","Button","CheckButton","LineEdit","OptionButton","ItemList","TextEdit"]:
		t.set_color("font_color",type,TEXT)
		t.set_color("font_disabled_color",type,MUTED)
	for type: String in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,tab_frame())
		t.set_stylebox("hover",type,box(Color("302a20"),GOLD,7))
		t.set_stylebox("pressed",type,tab_frame(true))
		t.set_stylebox("hover_pressed",type,tab_frame(true))
		t.set_stylebox("disabled",type,box(Color("121317"),Color("40392e"),7))
		var focus := box(Color(0,0,0,0),GOLD,0)
		focus.set_border_width_all(2)
		focus.shadow_size = 0
		t.set_stylebox("focus",type,focus)
		t.set_color("font_hover_color",type,Color.WHITE)
		t.set_color("font_pressed_color",type,GOLD)
		t.set_color("font_focus_color",type,GOLD)
		t.set_constant("icon_max_width",type,26)

	t.set_stylebox("panel","PanelContainer",chrome_panel())
	t.set_stylebox("panel","Panel",chrome_panel())
	t.set_stylebox("panel","PopupMenu",chrome_panel(Color("101014"),BRONZE,6))
	t.set_stylebox("normal","LineEdit",box(Color("0b1015"),Color("4d463b"),8))
	t.set_stylebox("focus","LineEdit",box(Color("121a20"),GOLD,8))
	t.set_stylebox("normal","TextEdit",box(Color("0b1015"),BRONZE,7))
	t.set_stylebox("focus","TextEdit",box(Color("111922"),GOLD,7))
	t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_color("caret_color","LineEdit",GOLD)
	t.set_color("selection_color","LineEdit",Color("574222"))
	t.set_stylebox("panel","ItemList",box(Color("111216"),BRONZE,6))
	t.set_stylebox("selected","ItemList",slot_frame(GOLD,true))
	t.set_stylebox("selected_focus","ItemList",slot_frame(GOLD,true))
	t.set_stylebox("hovered","ItemList",slot_frame(Color("97805c")))
	t.set_stylebox("panel","ScrollContainer",box(Color("0e0f12"),Color("42382d"),2))
	t.set_stylebox("panel","TabContainer",chrome_panel(Color("101116"),BRONZE,6))
	t.set_stylebox("tab_selected","TabBar",tab_frame(true))
	t.set_stylebox("tab_unselected","TabBar",tab_frame())
	t.set_stylebox("tab_hovered","TabBar",box(Color("302a20"),GOLD,7))
	t.set_stylebox("background","ProgressBar",slot_frame(Color("3b3328")))
	t.set_stylebox("fill","ProgressBar",box(Color("a98950"),GOLD,0))
	t.set_stylebox("separator","HSeparator",_divider(false))
	t.set_stylebox("separator","VSeparator",_divider(true))
	t.set_color("default_color","RichTextLabel",TEXT)
	t.set_color("font_selected_color","RichTextLabel",GOLD)
	t.set_font_size("normal_font_size","RichTextLabel",14)
	t.set_font_size("bold_font_size","RichTextLabel",14)
	t.set_constant("separation","VBoxContainer",7)
	t.set_constant("separation","HBoxContainer",7)
	t.set_constant("h_separation","GridContainer",6)
	t.set_constant("v_separation","GridContainer",6)
	var track := box(Color("0e0f12"),Color("25201c"),0)
	track.shadow_size = 0
	t.set_stylebox("scroll","VScrollBar",track)
	t.set_stylebox("grabber","VScrollBar",slot_frame(BRONZE))
	t.set_stylebox("grabber_highlight","VScrollBar",slot_frame(GOLD,true))
	t.set_stylebox("grabber_pressed","VScrollBar",slot_frame(GOLD,true))
	return t

static func label(value: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(value: String, action: Callable, min_size: Vector2 = Vector2(0,40)) -> Button:
	var b := Button.new()
	b.text = value
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if action.is_valid():
		b.pressed.connect(action)
	return b

static func rich(value: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.text = value
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r

static func safe(value: Variant) -> String:
	return str(value).replace("[","[lb]")

static func item_icon(record: Dictionary, item_name: String, images: Dictionary) -> Texture2D:
	var polished: Texture2D = ITEM_ART.item_icon(record, item_name, images)
	if polished != null:
		return polished
	var path := str(images.get(item_name,record.get("image_path","")))
	if path!="" and ResourceLoader.exists(path): return load(path) as Texture2D
	# Starting items do not all have an extracted catalog image. Reuse UI art.
	var file := "bag.png"
	if item_name.contains("물약"): file="potionRed.png"
	elif item_name.contains("잎"): file="leaf.png"
	elif item_name.contains("주문서"): file="quest.png"
	elif str(record.get("slot",""))=="weapon": file="attack.png"
	elif str(record.get("slot","")) not in ["","consumable"]: file="shield.png"
	elif item_name in ["화살","총알"]: file="attack.png"
	return load("res://assets/ui/"+file) as Texture2D
