extends RefCounted

const ITEM_ART = preload("res://scripts/ui/item_icon_art.gd")

const GOLD = Color("d8b878")
const BRONZE = Color("796344")
const TEXT = Color("eee5d4")
const MUTED = Color("a99e89")
const SLATE = Color("12171b")
const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const GRADES = {"일반":Color("ddd6c5"),"고급":Color("79bf83"),"희귀":Color("73b4ee"),"영웅":Color("e97772"),"전설":Color("bc89e3"),"신화":Color("e5be60"),"유일":Color("66dfc2")}

static func grade(value: String) -> Color:
	return GRADES.get(value, TEXT)

static func box(bg: Color = Color(0.035,0.045,0.055,0.96), border: Color = BRONZE, margin: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	s.shadow_color = Color(0,0,0,0.32)
	s.shadow_size = 5
	return s

static func make_theme() -> Theme:
	var t := Theme.new()
	var readable := FontVariation.new()
	readable.base_font = FONT
	# Font axes use integer OpenType tags (wght), not string keys.
	readable.variation_opentype = {2003265652:500.0}
	t.default_font = readable
	t.default_font_size = 14
	for type: String in ["Label","Button","CheckButton","LineEdit","OptionButton","ItemList"]:
		t.set_color("font_color",type,TEXT)
		t.set_color("font_disabled_color",type,MUTED)
	for type: String in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,box(Color("1b2025"),BRONZE,8))
		t.set_stylebox("hover",type,box(Color("34302a"),GOLD,8))
		t.set_stylebox("pressed",type,box(Color("493821"),GOLD,8))
		t.set_stylebox("disabled",type,box(Color("161a1e"),Color("454039"),8))
		var focus := box(Color(0,0,0,0),GOLD,0)
		focus.set_border_width_all(2)
		t.set_stylebox("focus",type,focus)
		t.set_color("font_hover_color",type,Color.WHITE)
		t.set_constant("icon_max_width",type,26)
	t.set_stylebox("panel","PanelContainer",box())
	t.set_stylebox("panel","Panel",box())
	t.set_stylebox("normal","LineEdit",box(Color("0e1318"),BRONZE,8))
	t.set_stylebox("focus","LineEdit",box(Color("151c23"),GOLD,8))
	t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_stylebox("panel","ItemList",box(Color("11161b"),BRONZE,6))
	t.set_stylebox("selected","ItemList",box(Color("473620"),GOLD,6))
	t.set_color("default_color","RichTextLabel",TEXT)
	t.set_font_size("normal_font_size","RichTextLabel",14)
	t.set_font_size("bold_font_size","RichTextLabel",14)
	t.set_constant("separation","VBoxContainer",8)
	t.set_constant("separation","HBoxContainer",8)
	t.set_constant("h_separation","GridContainer",8)
	t.set_constant("v_separation","GridContainer",8)
	t.set_stylebox("scroll","VScrollBar",box(Color("0d1116"),Color("222a31"),0))
	t.set_stylebox("grabber","VScrollBar",box(BRONZE,GOLD,0))
	t.set_stylebox("grabber_highlight","VScrollBar",box(GOLD,GOLD,0))
	t.set_stylebox("grabber_pressed","VScrollBar",box(GOLD,GOLD,0))
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
