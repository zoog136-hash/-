extends RefCounted

const UI = preload("res://scripts/ui/renewal_theme.gd")
const CardRules=preload("res://scripts/card_draw_fusion.gd")
const CARD_BACKDROP=preload("res://assets/ui/fusion_background_painted.png")

# The inspected 2023 card menus use the same restrained blue/black material.
# Reuse the existing original raster; this does not restyle other screens.
static func card_surface(margin: int=0) -> StyleBoxTexture:
	var style:=StyleBoxTexture.new()
	style.texture=CARD_BACKDROP
	style.modulate_color=Color(.24,.30,.36,1)
	for side: int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,margin)
	return style

static func card_tab(button: Button) -> void:
	for state: String in ["normal","hover","pressed","hover_pressed"]:
		var chosen: bool=state in ["pressed","hover_pressed"]
		var plate: StyleBoxFlat=UI.box(Color(.07,.10,.13,.72 if chosen else .22),Color("b2ac91") if chosen else Color("37424a"),5)
		plate.shadow_size=0
		plate.border_width_left=0;plate.border_width_top=0;plate.border_width_right=0
		plate.border_width_bottom=2 if chosen else 1
		button.add_theme_stylebox_override(state,plate)
	button.add_theme_color_override("font_color",Color("dddeda"))
	button.add_theme_color_override("font_pressed_color",Color("e5dac1"))
	var disabled: StyleBoxFlat=UI.box(Color(.05,.08,.10,.18),Color("253039"),5)
	disabled.set_border_width_all(0);disabled.border_width_bottom=1;disabled.shadow_size=0
	button.add_theme_stylebox_override("disabled",disabled)

# Surfaces for the inspected Korean LineageM guide screens. These are original
# controls/materials, not extracted game textures or purported original colors.
# https://lineagem.plaync.com/guidebook/view?title=메뉴%20및%20UI%20소개
static func inset(margin: int = 8) -> StyleBoxTexture:
	return UI.MATERIAL.from_flat(UI.box(Color("101c28"),Color("354454"),margin),true)

static func action(button: Button) -> void:
	button.add_theme_stylebox_override("normal",UI.MATERIAL.from_flat(UI.box(Color("243d56"),Color("536a7d"),7)))
	button.add_theme_stylebox_override("hover",UI.MATERIAL.from_flat(UI.box(Color("304c67"),Color("9aacae"),7)))
	button.add_theme_stylebox_override("pressed",UI.MATERIAL.from_flat(UI.box(Color("172b3f"),Color("8799a6"),7),true))
	button.add_theme_color_override("font_color",Color("ece8dd"))

static func grade_row(button: Button) -> void:
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.custom_minimum_size=Vector2(0,54)
	button.add_theme_font_size_override("font_size",15)
	for state: String in ["normal","hover","pressed"]:
		var style: StyleBoxFlat=UI.box(Color("27313a") if state=="pressed" else Color("1d2832"),Color("36434e"),5)
		style.border_width_left=4 if state=="pressed" else 1
		if state=="pressed":style.border_color=Color("c2c8c7")
		button.add_theme_stylebox_override(state,UI.MATERIAL.from_flat(style,state=="pressed"))

static func catalog(hud: Node) -> void:
	var grades: Control=hud.get("catalog_grade_column")
	grades.custom_minimum_size.x=180
	for button: Button in (hud.get("catalog_grade_buttons") as Dictionary).values():grade_row(button)
	var listing: ItemList=hud.get("catalog_list")
	listing.add_theme_stylebox_override("panel",inset(5))
	var actions: ScrollContainer=hud.get("catalog_body_actions")
	actions.add_theme_stylebox_override("panel",inset(8))
	action(hud.get("catalog_equip_button"))

static func refresh_grade_counts(hud: Node) -> void:
	if not str(hud.get("catalog_category")) in ["변신","마법인형","성물"]:
		for grade: String in hud.get("catalog_grade_buttons"):(hud.get("catalog_grade_buttons")[grade] as Button).text=grade
		return
	var owned: Dictionary=(hud.get("card_collection_state") as Dictionary).get("owned",{}).get(hud.get("catalog_category"),{})
	var records: Array=(hud.get("catalog_data") as Dictionary).get(hud.get("catalog_category"),[])
	var totals: Dictionary={}
	var counts: Dictionary={}
	var seen: Dictionary={}
	for raw: Variant in records:
		if not raw is Dictionary:continue
		var record: Dictionary=raw
		var identity: String=CardRules.card_id(record)
		if identity.is_empty() or seen.has(identity):continue
		seen[identity]=true
		var grade: String=str(record.get("grade","일반"))
		totals[grade]=int(totals.get(grade,0))+1
		totals["전체"]=int(totals.get("전체",0))+1
		if owned.has(identity):
			counts[grade]=int(counts.get(grade,0))+1
			counts["전체"]=int(counts.get("전체",0))+1
	for grade: String in hud.get("catalog_grade_buttons"):
		(hud.get("catalog_grade_buttons")[grade] as Button).text="%s\n(%d/%d)" % [grade,int(counts.get(grade,0)),int(totals.get(grade,0))]
