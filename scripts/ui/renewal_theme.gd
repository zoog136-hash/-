extends RefCounted

# TWILIGHT's own midnight-metal visual language, inspired by the functional
# hierarchy of Lineage M: compact gold-framed panels, inset item slots and
# legible parchment copy. No source-game textures are bundled.
const ITEM_ART = preload("res://scripts/ui/item_icon_art.gd")
const ICONS = preload("res://scripts/ui/renewal_icons.gd")
const MATERIAL = preload("res://scripts/ui/renewal_material_style.gd")
const NATIVE_TEXT=preload("res://scripts/ui/native_touch_text.gd")
static var source_icon_cache: Dictionary = {}
static var recess_style: StyleBoxTexture

const GOLD = Color("dcc391")
const BRONZE = Color("766452")
const TEXT = Color("f0e8d9")
const MUTED = Color("afa28d")
const SLATE = Color("101114")
const DEEP = Color("15130f")
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
	s.set_corner_radius_all(0)
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
	s.border_width_left = 1
	s.border_width_top = 2
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.shadow_size = 9
	s.shadow_color = Color(0,0,0,.55)
	return s

static func screen_frame() -> StyleBoxTexture:
	return MATERIAL.window_frame()

static func primary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal",MATERIAL.from_flat(box(Color("493822"),Color("b69a65"),7)))
	button.add_theme_stylebox_override("hover",MATERIAL.from_flat(box(Color("5b4629"),GOLD,7)))
	button.add_theme_stylebox_override("pressed",MATERIAL.from_flat(box(Color("302414"),GOLD,7),true))
	button.add_theme_color_override("font_color",Color("f7e8c9"))

static func slot_frame(rim: Color = BRONZE, active: bool = false) -> StyleBoxFlat:
	var s := box(Color("29251e") if active else Color("0c0b09"), rim, 3)
	s.set_corner_radius_all(1)
	s.shadow_size = 0
	return s

static func item_frame(grade_name: String, active: bool = false) -> StyleBoxFlat:
	var tint := grade(grade_name)
	var s := slot_frame(BRONZE if grade_name == "일반" and not active else tint,active)
	s.bg_color = Color("111317").lerp(tint,.055)
	s.border_width_bottom = 2
	s.shadow_size = 3 if grade_name in ["희귀","영웅","전설","신화","유일"] else 0
	s.shadow_color = Color(tint,.18)
	return s

static func slot_recess() -> StyleBoxTexture:
	# The grid draws consecutive recesses with this one shared texture before
	# any item art. No extra per-slot CanvasItem or per-frame allocation.
	if recess_style == null:
		recess_style = MATERIAL.from_flat(box(Color("0c0b09"),Color("42372b"),0),true)
	return recess_style

static func menu_tile(active: bool = false) -> StyleBoxFlat:
	var style := box(Color("2b241b") if active else Color(0.065,0.054,0.042,0.3),Color("7a6547") if active else Color(0.40,0.32,0.23,0.36),0)
	style.shadow_size = 0
	style.border_width_top = 1 if active else 0
	style.border_width_left = 1 if active else 0
	style.border_width_right = 1 if active else 0
	return style
static func icon(kind: String) -> Texture2D:
	if kind == "attack":
		if not source_icon_cache.has(kind):source_icon_cache[kind]=load("res://assets/ui/attack_sword_painted.png")
		return source_icon_cache[kind]
	# Service navigation shares one embossed symbol family. Item/skill art
	# continues through its existing record-based resolvers below.
	if ICONS.PATHS.has(str(ICONS.ALIASES.get(kind,kind))): return ICONS.texture(kind)
	var files: Dictionary = {"inventory":"bag","shop":"shop","skills":"skill","settings":"settings","auto":"macro","map":"teleport","attack":"attack","return":"return","enhance":"sword"}
	if files.has(kind):
		if source_icon_cache.has(kind): return source_icon_cache[kind]
		var path: String = "res://assets/ui/"+str(files[kind])+".png"
		if ResourceLoader.exists(path):
			var source: Texture2D = load(path) as Texture2D
			if source != null:
				source_icon_cache[kind] = source
				return source
	return ICONS.texture(kind)
static func section(value: String, font_size: int = 16) -> Label:
	var l := label(value,font_size,GOLD)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func tab_frame(active: bool = false) -> StyleBoxTexture:
	var s := box(Color("342b20") if active else Color("211c17"), Color("b69b6e") if active else Color("514637"), 7)
	s.set_corner_radius_all(1)
	s.shadow_size = 0
	if active:
		s.border_width_bottom = 2
	return MATERIAL.from_flat(s,active)

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
	readable.variation_opentype = {2003265652:550.0}
	t.default_font = readable
	t.default_font_size = 14

	for type: String in ["Label","Button","CheckButton","LineEdit","OptionButton","ItemList","TextEdit"]:
		t.set_color("font_color",type,TEXT)
		t.set_color("font_disabled_color",type,MUTED)
	for type: String in ["Button","OptionButton"]:
		t.set_stylebox("normal",type,tab_frame())
		t.set_stylebox("hover",type,MATERIAL.from_flat(box(Color("302a20"),BRONZE.lightened(.22),7)))
		t.set_stylebox("pressed",type,tab_frame(true))
		t.set_stylebox("hover_pressed",type,tab_frame(true))
		t.set_stylebox("disabled",type,MATERIAL.from_flat(box(Color("181817"),Color("403b34"),7),true))
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
	t.set_stylebox("normal","LineEdit",MATERIAL.from_flat(box(Color("10100f"),Color("4d463b"),8),true))
	t.set_stylebox("focus","LineEdit",MATERIAL.from_flat(box(Color("181713"),GOLD,8),true))
	t.set_stylebox("normal","TextEdit",box(Color("0b1015"),BRONZE,7))
	t.set_stylebox("focus","TextEdit",box(Color("111922"),GOLD,7))
	t.set_color("font_placeholder_color","LineEdit",MUTED)
	t.set_color("caret_color","LineEdit",GOLD)
	t.set_color("selection_color","LineEdit",Color("574222"))
	var list_panel := MATERIAL.from_flat(box(Color("12100d"),Color("514233"),6),true)
	# Tall lists need one shallow surface, rather than repeating button seams.
	list_panel.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	t.set_stylebox("panel","ItemList",list_panel)
	t.set_stylebox("selected","ItemList",slot_frame(GOLD,true))
	t.set_stylebox("selected_focus","ItemList",slot_frame(GOLD,true))
	t.set_stylebox("hovered","ItemList",slot_frame(Color("97805c")))
	t.set_stylebox("panel","ScrollContainer",box(Color("0e0f12"),Color("42382d"),2))
	t.set_stylebox("panel","TabContainer",chrome_panel(Color("101116"),BRONZE,6))
	t.set_stylebox("tab_selected","TabBar",tab_frame(true))
	t.set_stylebox("tab_unselected","TabBar",tab_frame())
	t.set_stylebox("tab_hovered","TabBar",MATERIAL.from_flat(box(Color("302a20"),BRONZE.lightened(.22),7)))
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
	t.set_stylebox("panel","ScrollContainer",box(Color("0e0f12"),Color("42382d"),2))
	t.set_stylebox("panel","AcceptDialog",chrome_panel())
	t.set_stylebox("panel","Window",chrome_panel())
	t.set_stylebox("slider","HSlider",slot_frame(BRONZE))
	t.set_stylebox("grabber_area","HSlider",box(Color("8f7044"),GOLD,0))
	t.set_stylebox("grabber_area_highlight","HSlider",box(GOLD,GOLD,0))
	t.set_color("font_outline_color","Label",Color(0,0,0,.75))
	t.set_constant("outline_size","Label",1)
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
	b.pressed.connect(func() -> void:
		if not b.is_inside_tree() or b.disabled: return
		var audio: Node = b.get_tree().get_first_node_in_group("presentation_audio")
		if audio != null: audio.call("play_ui","button"))
	return b

static func rich(value: String) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.set_script(NATIVE_TEXT)
	r.bbcode_enabled = true
	r.text = value
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r

static func safe(value: Variant) -> String:
	return str(value).replace("[","[lb]")

static func item_icon(record: Dictionary, item_name: String, images: Dictionary) -> Texture2D:
	return preload("res://scripts/ui/item_visual_resolver.gd").texture(record,item_name,images)

static func apply_item_visual(view: TextureRect, record: Dictionary, item_name: String, images: Dictionary = {}, context: String = "slot") -> void:
	preload("res://scripts/ui/item_visual.gd").apply(view,record,item_name,images,context)

static func clear_item_visual(view: TextureRect) -> void:
	preload("res://scripts/ui/item_visual.gd").clear(view)

static func set_reduced_motion(enabled: bool) -> void:
	preload("res://scripts/ui/item_visual.gd").set_reduced_motion(enabled)

# Display-only grouping; callers retain integer IDs/prices/quantities.
static func number_text(value: int) -> String:
	var digits: String = str(absi(value))
	var grouped: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length()-index)%3 == 0: grouped += ","
		grouped += digits[index]
	return ("-" if value < 0 else "")+grouped
