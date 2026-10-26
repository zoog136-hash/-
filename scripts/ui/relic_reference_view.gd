extends VBoxContainer

const UI=preload("res://scripts/ui/renewal_theme.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const CardRules=preload("res://scripts/card_draw_fusion.gd")
const Visibility=preload("res://scripts/card_option_visibility.gd")
# Layout reference: https://static.inven.co.kr/column/2023/07/12/news/i8297953547.jpg
# Existing controls and transaction callbacks are borrowed, never duplicated.
var hud: Node
var active: bool=false
var homes: Array[Dictionary]=[]
var shared_column: Control
var header: HBoxContainer
var tab_buttons: Array[Button]=[]
var main_body: HBoxContainer
var grade_scroll: ScrollContainer
var middle: VBoxContainer
var search_row: HBoxContainer
var type_filter: OptionButton
var right_pane: VBoxContainer
var right_scroll: ScrollContainer
var right: VBoxContainer
var preview_stage: Control
var aura: TextureRect
var name_label: Label
var grade_label: Label
var option_rows: GridContainer
var summon_row: HBoxContainer
var option_note: Label
var status: Label
var fusion_scroll: ScrollContainer
var fusion_column: VBoxContainer
var compact_tabs: Control
var active_tab: int=0
var list_properties: Dictionary={}
var list_styles: Dictionary={}
var list_constants: Dictionary={}
var grade_separation: int=7
var grade_properties: Array[Dictionary]=[]
var window_style: StyleBox
var catalog_style: StyleBox
var window_separation: int
var old_collection_visible: bool
var selected_key: String=""
var page_key: String=""
var number_pattern: RegEx=RegEx.new()
var card_frames: Control
var preview_material: ShaderMaterial

func configure(controller: Node) -> void:
	hud=controller
	name="RelicReferenceView"
	theme=UI.make_theme()
	add_theme_constant_override("separation",6)
	shared_column=hud.catalog_panel.get_child(0)
	header=HBoxContainer.new()
	header.name="RelicHeaderTabs"
	header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(header)
	for title: String in ["성물","합성","성물 컬렉션"]:
		var index: int=tab_buttons.size()
		var button: Button=UI.button(title,func() -> void:_select_tab(index),Vector2(76 if index<2 else 116,32))
		button.name=["RelicListTab","RelicFusionTab","RelicCollectionTab"][index]
		button.toggle_mode=true
		header.add_child(button)
		tab_buttons.append(button)
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var shop: Button=UI.button("상점 바로가기",func() -> void:hud.open_shop(),Vector2(128,32))
	shop.name="RelicShopShortcut"
	shop.icon=load("res://assets/ui/shop.png")
	header.add_child(shop)
	compact_tabs=HBoxContainer.new()
	compact_tabs.name="RelicCompactTabs"
	for spec: Array in [[false,"성물 목록"],[true,"선택 상세"]]:
		var show_details: bool=spec[0]
		compact_tabs.add_child(UI.button(str(spec[1]),func() -> void:hud._set_catalog_detail_view(show_details),Vector2(115,32)))
	add_child(compact_tabs)
	main_body=HBoxContainer.new()
	main_body.name="RelicMainBody"
	main_body.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main_body.add_theme_constant_override("separation",12)
	add_child(main_body)
	grade_scroll=ScrollContainer.new()
	grade_scroll.name="RelicGradeScroll"
	grade_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	grade_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main_body.add_child(grade_scroll)
	middle=VBoxContainer.new()
	middle.name="RelicCardsPane"
	middle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main_body.add_child(middle)
	search_row=HBoxContainer.new()
	search_row.name="RelicSearchRow"
	middle.add_child(search_row)
	type_filter=OptionButton.new()
	type_filter.name="RelicTypeFilter"
	type_filter.custom_minimum_size=Vector2(92,32)
	type_filter.add_item("모든 유형")
	var types: Array[String]=[]
	for record: Dictionary in hud.catalog_data.get("성물",[]):
		var kind: String=str(record.get("type",""))
		if not kind.is_empty() and not types.has(kind):types.append(kind)
	for kind: String in types:type_filter.add_item(kind)
	type_filter.item_selected.connect(func(_index: int) -> void:hud._refresh_catalog_list(hud.catalog_search.text))
	search_row.add_child(type_filter)
	var reset: Button=UI.button("초기화",_reset_filters,Vector2(54,32))
	reset.name="RelicResetFilters"
	search_row.add_child(reset)
	right_pane=VBoxContainer.new()
	right_pane.name="RelicDetailsPane"
	right_pane.size_flags_vertical=Control.SIZE_EXPAND_FILL
	main_body.add_child(right_pane)
	right_scroll=ScrollContainer.new()
	right_scroll.name="RelicDetailsScroll"
	right_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right_pane.add_child(right_scroll)
	right=VBoxContainer.new()
	right.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	right.size_flags_vertical=Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation",10)
	right_scroll.add_child(right)
	var hero:=HBoxContainer.new()
	hero.name="RelicPreviewOptions"
	hero.size_flags_vertical=Control.SIZE_EXPAND_FILL
	hero.custom_minimum_size.y=235
	right.add_child(hero)
	preview_stage=Control.new()
	preview_stage.name="RelicGlowPreview"
	preview_stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	preview_stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	hero.add_child(preview_stage)
	aura=TextureRect.new()
	aura.mouse_filter=Control.MOUSE_FILTER_IGNORE
	aura.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	aura.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_stage.add_child(aura)
	aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var information:=VBoxContainer.new()
	information.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	information.size_flags_stretch_ratio=1.10
	hero.add_child(information)
	var title_row:=HBoxContainer.new()
	information.add_child(title_row)
	name_label=UI.label("",18)
	name_label.name="RelicSelectedName"
	name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_row.add_child(name_label)
	var lock:=TextureRect.new()
	lock.texture=UI.icon("lock")
	lock.custom_minimum_size=Vector2(20,20)
	lock.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.modulate=Color(1,1,1,.4)
	lock.tooltip_text="카드 잠금 미지원"
	title_row.add_child(lock)
	grade_label=UI.label("",13)
	grade_label.name="RelicSelectedGrade"
	information.add_child(grade_label)
	var gap:=Control.new()
	gap.custom_minimum_size.y=26
	information.add_child(gap)
	var sheet:=PanelContainer.new()
	sheet.size_flags_vertical=Control.SIZE_EXPAND_FILL
	sheet.add_theme_stylebox_override("panel",Surfaces.inset(8))
	information.add_child(sheet)
	var sheet_column:=VBoxContainer.new()
	sheet.add_child(sheet_column)
	var caption: Label=UI.label("성물 소환 옵션",13,UI.MUTED)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	sheet_column.add_child(caption)
	sheet_column.add_child(HSeparator.new())
	option_rows=GridContainer.new()
	option_rows.name="RelicOptionValues"
	option_rows.columns=2
	option_rows.add_theme_constant_override("h_separation",10)
	option_rows.add_theme_constant_override("v_separation",5)
	sheet_column.add_child(option_rows)
	option_note=UI.label("",10,UI.MUTED)
	option_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	sheet_column.add_child(option_note)
	summon_row=HBoxContainer.new()
	summon_row.name="RelicImmediateSummonRow"
	right_pane.add_child(summon_row)
	var scroll:=TextureRect.new()
	scroll.name="RelicSummonScrollIcon"
	scroll.texture=load("res://assets/ui/return.png")
	scroll.custom_minimum_size=Vector2(38,38)
	scroll.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	scroll.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	scroll.tooltip_text="성물 소환"
	summon_row.add_child(scroll)
	status=UI.label("",11,UI.MUTED)
	status.name="RelicAppliedStatus"
	right_pane.add_child(status)
	var footer:=HBoxContainer.new()
	footer.name="RelicFooterActions"
	right_pane.add_child(footer)
	for spec: Array in [["컬렉션 보기","성물 컬렉션 서비스 미지원"],["성물 등록","성물 빠른등록 서비스 미지원"]]:
		var button: Button=UI.button(str(spec[0]),Callable(),Vector2(0,38))
		button.name="RelicCollectionView" if spec[0]=="컬렉션 보기" else "RelicRegister"
		button.disabled=true
		button.tooltip_text=str(spec[1])
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		UI.primary_button(button)
		footer.add_child(button)
	tab_buttons[2].disabled=true
	tab_buttons[2].tooltip_text="성물 컬렉션 서비스 미지원"
	fusion_scroll=ScrollContainer.new()
	fusion_scroll.name="RelicExistingFusionPane"
	fusion_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	fusion_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(fusion_scroll)
	fusion_column=VBoxContainer.new()
	fusion_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fusion_scroll.add_child(fusion_column)
	fusion_column.add_child(UI.section("성물 카드 합성",18))
	fusion_column.add_child(UI.label("보유 중복 카드와 기존 합성 규칙을 사용합니다.",12,UI.MUTED))
	number_pattern.compile("[+-]?[0-9]")
	preview_material=ShaderMaterial.new()
	preview_material.shader=load("res://assets/effects/relic_glow.gdshader")
	card_frames=Control.new()
	card_frames.name="RelicCardFrames"
	card_frames.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card_frames.clip_contents=true
	hud.catalog_list.add_child(card_frames)
	card_frames.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_frames.draw.connect(_draw_card_frames)
	card_frames.hide()
	hud.catalog_list.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:card_frames.queue_redraw())
	hud.catalog_list.resized.connect(card_frames.queue_redraw)
	preview_stage.resized.connect(_fit_preview)
	resized.connect(fit_layout)
	middle.resized.connect(_fit_grid)
	for button: Button in hud.catalog_grade_buttons.values():
		button.gui_input.connect(func(event: InputEvent) -> void:
			if active:hud.workspace._on_scroll_drag_input(event,grade_scroll,button))
	hide()

func activate() -> void:
	if active:return
	window_style=hud.workspace.get_theme_stylebox("panel")
	catalog_style=hud.catalog_panel.get_theme_stylebox("panel")
	window_separation=hud.workspace.content.get_parent().get_theme_constant("separation")
	hud.workspace.add_theme_stylebox_override("panel",Surfaces.inset(2))
	hud.workspace.content.get_parent().add_theme_constant_override("separation",2)
	hud.catalog_panel.add_theme_stylebox_override("panel",UI.box(Color(0,0,0,0),Color(0,0,0,0),0))
	var nodes: Array[Control]=[hud.catalog_grade_column,hud.catalog_body_left,hud.catalog_search,hud.catalog_preview,hud.catalog_equip_button,hud.catalog_clear_button,hud.card_controls]
	for node: Control in nodes:
		var props: Dictionary={}
		for key: String in ["custom_minimum_size","size_flags_horizontal","size_flags_vertical","anchor_left","anchor_top","anchor_right","anchor_bottom","offset_left","offset_top","offset_right","offset_bottom","visible","material"]:props[key]=node.get(key)
		homes.append({"node":node,"parent":node.get_parent(),"index":node.get_index(),"properties":props})
	for key: String in ["fixed_icon_size","fixed_column_width","max_columns","max_text_lines","icon_mode","same_column_width"]:list_properties[key]=hud.catalog_list.get(key)
	grade_separation=hud.catalog_grade_column.get_theme_constant("separation")
	for key: String in ["h_separation","v_separation"]:list_constants[key]=hud.catalog_list.get_theme_constant(key)
	for key: String in ["panel","selected","selected_focus"]:
		list_styles[key]={"override":hud.catalog_list.has_theme_stylebox_override(key),"style":hud.catalog_list.get_theme_stylebox(key)}
	for button: Button in hud.catalog_grade_buttons.values():
		grade_properties.append({"button":button,"minimum":button.custom_minimum_size,"vertical":button.size_flags_vertical,"font":button.get_theme_font_size("font_size"),"mouse":button.mouse_filter})
		button.mouse_filter=Control.MOUSE_FILTER_PASS
		button.size_flags_vertical=Control.SIZE_EXPAND_FILL
	old_collection_visible=hud.equipment_collection_button.visible
	hud.equipment_collection_button.hide()
	hud.catalog_grade_column.reparent(grade_scroll,false)
	hud.catalog_body_left.reparent(middle,false)
	hud.catalog_search.reparent(search_row,false)
	search_row.move_child(hud.catalog_search,1)
	hud.catalog_search.custom_minimum_size=Vector2(0,32)
	hud.catalog_search.placeholder_text="검색할 카드 이름을 입력하세요"
	hud.catalog_preview.reparent(preview_stage,false)
	hud.catalog_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.catalog_preview.custom_minimum_size=Vector2.ZERO
	hud.catalog_preview.offset_left=6;hud.catalog_preview.offset_right=-6
	hud.catalog_preview.offset_top=18;hud.catalog_preview.offset_bottom=-18
	hud.catalog_preview.material=preview_material
	hud.catalog_equip_button.reparent(summon_row,false)
	hud.catalog_equip_button.custom_minimum_size=Vector2(128,38)
	hud.catalog_clear_button.reparent(summon_row,false)
	hud.catalog_clear_button.text="해제"
	hud.catalog_clear_button.custom_minimum_size=Vector2(62,38)
	hud.catalog_clear_button.tooltip_text="현재 성물 적용 해제"
	hud.card_controls.reparent(fusion_column,false)
	shared_column.hide()
	active=true
	card_frames.show()
	show()
	hud.workspace.mount_header_filters(header)
	page_key="";selected_key=""
	_select_tab(0)
	refresh_state()
	call_deferred("fit_layout")

func deactivate() -> void:
	if not active:return
	active=false
	hud.workspace.add_theme_stylebox_override("panel",window_style)
	hud.catalog_panel.add_theme_stylebox_override("panel",catalog_style)
	hud.workspace.content.get_parent().add_theme_constant_override("separation",window_separation)
	card_frames.hide()
	for home: Dictionary in homes:
		var node: Control=home.node
		node.reparent(home.parent,false)
		home.parent.move_child(node,mini(int(home.index),home.parent.get_child_count()-1))
		for key: String in home.properties:node.set(key,home.properties[key])
	homes.clear()
	for key: String in list_properties:hud.catalog_list.set(key,list_properties[key])
	hud.catalog_grade_column.add_theme_constant_override("separation",grade_separation)
	for key: String in list_constants:hud.catalog_list.add_theme_constant_override(key,list_constants[key])
	for key: String in list_styles:
		if list_styles[key].override:hud.catalog_list.add_theme_stylebox_override(key,list_styles[key].style)
		else:hud.catalog_list.remove_theme_stylebox_override(key)
	for state: Dictionary in grade_properties:
		state.button.custom_minimum_size=state.minimum
		state.button.size_flags_vertical=state.vertical
		state.button.mouse_filter=state.mouse
		state.button.add_theme_font_size_override("font_size",state.font)
	grade_properties.clear()
	hud.equipment_collection_button.visible=old_collection_visible
	hud.catalog_clear_button.text="현재 적용 해제"
	hud.catalog_search.placeholder_text="이름 · 종류 검색"
	for index: int in range(hud.catalog_results.size()):
		var record: Dictionary=hud.catalog_results[index]
		hud.catalog_list.set_item_text(index,str(record.get("name","")))
		hud.catalog_list.set_item_custom_bg_color(index,Color(UI.grade(str(record.get("grade","일반"))),.08))
	shared_column.show()
	hide()

func matches_type(record: Dictionary) -> bool:
	return type_filter.selected==0 or str(record.get("type",""))==type_filter.get_item_text(type_filter.selected)

func _reset_filters() -> void:
	type_filter.select(0)
	hud.catalog_grade_filter="전체"
	hud.rarity_filter.select(0)
	for key: String in hud.catalog_grade_buttons:hud.catalog_grade_buttons[key].button_pressed=key=="전체"
	hud.catalog_search.text=""
	hud._refresh_catalog_list("")

func _select_tab(index: int) -> void:
	active_tab=index
	for i: int in range(tab_buttons.size()):tab_buttons[i].button_pressed=i==index
	main_body.visible=index==0
	fusion_scroll.visible=index==1
	fit_layout()

func fit_layout() -> void:
	if not active:return
	var compact: bool=size.x<640
	compact_tabs.visible=compact and active_tab==0
	grade_scroll.visible=not compact
	hud.catalog_grade_column.show()
	hud.catalog_grade_column.custom_minimum_size.x=0
	grade_scroll.custom_minimum_size.x=clampf(size.x*.135,96,176)
	hud.catalog_grade_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud.catalog_grade_column.size_flags_vertical=Control.SIZE_EXPAND_FILL
	hud.catalog_grade_column.add_theme_constant_override("separation",3)
	for button: Button in hud.catalog_grade_buttons.values():
		button.custom_minimum_size.y=42 if size.y<500 else 54
		button.add_theme_font_size_override("font_size",12 if size.y<500 else 15)
	right_pane.custom_minimum_size.x=0 if compact else clampf(size.x*.40,248,500)
	right_pane.size_flags_horizontal=Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	middle.visible=not compact or not hud.catalog_details_active
	right_pane.visible=not compact or hud.catalog_details_active
	hud.catalog_body_left.show()
	hud.catalog_body_left.custom_minimum_size.x=0
	hud.catalog_body_left.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud.catalog_body_left.size_flags_vertical=Control.SIZE_EXPAND_FILL
	hud.catalog_count.hide()
	preview_stage.custom_minimum_size.x=108 if size.x<1000 else 176
	_fit_grid()
	_fit_preview()
	for label: Label in option_rows.get_children():
		label.add_theme_font_size_override("font_size",11 if size.x<1000 else 12)
		if label.name.begins_with("RelicOptionValue"):label.custom_minimum_size.x=40 if size.x<1000 else 72

func _fit_preview() -> void:
	if not active:return
	var inset: float=maxf(8,preview_stage.size.x*.12)
	hud.catalog_preview.offset_left=inset
	hud.catalog_preview.offset_right=-inset

func _fit_grid() -> void:
	if not active or middle.size.x<1:return
	var width: int=maxi(50,floori((middle.size.x-48)/4.0))
	hud.catalog_list.max_columns=4
	hud.catalog_list.fixed_column_width=width
	hud.catalog_list.fixed_icon_size=Vector2i(maxi(38,width-8),maxi(40,width+4))
	hud.catalog_list.max_text_lines=1
	hud.catalog_list.add_theme_constant_override("h_separation",4)
	hud.catalog_list.add_theme_constant_override("v_separation",6)
	hud.catalog_list.add_theme_stylebox_override("panel",UI.box(Color("050d14"),Color("263e4c"),3))
	var selected: StyleBoxFlat=UI.box(Color("142633"),UI.GOLD,4)
	hud.catalog_list.add_theme_stylebox_override("selected",selected)
	hud.catalog_list.add_theme_stylebox_override("selected_focus",selected)

func refresh_state(force_cards: bool=false) -> void:
	if not active:return
	var owned: Dictionary=hud.card_collection_state.get("owned",{}).get("성물",{})
	var spare: Dictionary=hud.card_collection_state.get("spare",{}).get("성물",{})
	var signature: String=str(hud.catalog_icon_generation)+":"+str(hash(owned))+":"+str(hash(spare))
	if force_cards or signature!=page_key:
		page_key=signature
		for index: int in range(hud.catalog_results.size()):
			var record: Dictionary=hud.catalog_results[index]
			var identity: String=CardRules.card_id(record)
			var quantity: int=(1 if owned.has(identity) else 0)+int(spare.get(identity,0))
			hud.catalog_list.set_item_text(index," ")
			hud.catalog_list.set_item_tooltip(index,str(record.get("name",""))+" · "+str(record.get("grade",""))+" · "+str(record.get("type",""))+"\n보유 "+str(quantity)+" · 원본 ID "+str(record.get("sourceId","")))
			hud.catalog_list.set_item_custom_bg_color(index,Color(UI.grade(str(record.get("grade","일반"))),.17))
	card_frames.queue_redraw()
	var record: Dictionary={} if hud.catalog_results.is_empty() else hud.selected_catalog_record
	var key: String=CardRules.card_id(record)+":"+str(hash(record.get("sourceOptions",[])))
	if key!=selected_key:
		selected_key=key
		_fill_options(record)
	hud.catalog_equip_button.text="현재 소환 중" if hud.catalog_equip_button.disabled and not record.is_empty() else "즉시 소환"
	status.text="현재 적용: "+str(hud.character_state.get("equipped",{}).get("성물",{}).get("name","없음"))

func _fill_options(record: Dictionary) -> void:
	for child: Node in option_rows.get_children():option_rows.remove_child(child);child.queue_free()
	var grade: String=str(record.get("grade","일반"))
	var tint: Color=UI.grade(grade)
	name_label.text=str(record.get("name","성물을 선택하세요"))
	name_label.add_theme_color_override("font_color",tint)
	grade_label.text=grade+" · "+str(record.get("type",""))
	grade_label.add_theme_color_override("font_color",tint)
	hud.catalog_preview.material=preview_material
	preview_material.set_shader_parameter("aura_color",tint)
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([0,.38,1])
	gradient.colors=PackedColorArray([Color(tint,.33),Color(tint,.16),Color(tint,0)])
	var texture:=GradientTexture2D.new()
	texture.width=192;texture.height=192
	texture.gradient=gradient
	texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
	aura.texture=texture
	var unsupported: bool=false
	for raw: Variant in record.get("sourceOptions",[]):
		var option: String=str(raw).replace("PVP","PVE").replace("PvP","PvE")
		if option.contains("손상") or option.contains("저주"):continue
		var result: RegExMatch=number_pattern.search(option)
		var split: int=result.get_start() if result!=null else option.length()
		var title: Label=UI.label(option.substr(0,split).strip_edges(),11 if size.x<1000 else 12,UI.TEXT)
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		option_rows.add_child(title)
		var suffix: String=Visibility.suffix("성물",option,record)
		unsupported=unsupported or not suffix.is_empty()
		var value: Label=UI.label(option.substr(split)+(" *" if not suffix.is_empty() else ""),11 if size.x<1000 else 12,UI.MUTED if not suffix.is_empty() else UI.TEXT)
		value.tooltip_text=option+suffix
		value.mouse_filter=Control.MOUSE_FILTER_PASS
		value.name="RelicOptionValue"
		value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size.x=40 if size.x<1000 else 72
		option_rows.add_child(value)
	option_note.text="* 미지원 특수효과" if unsupported else ""
	option_note.visible=unsupported

func _draw_card_frames() -> void:
	if not active:return
	var owned: Dictionary=hud.card_collection_state.get("owned",{}).get("성물",{})
	var spare: Dictionary=hud.card_collection_state.get("spare",{}).get("성물",{})
	var chosen: PackedInt32Array=hud.catalog_list.get_selected_items()
	for index: int in range(hud.catalog_results.size()):
		var rect: Rect2=hud.catalog_list.get_item_rect(index)
		rect.position.y-=hud.catalog_list.get_v_scroll_bar().value
		if not Rect2(Vector2.ZERO,hud.catalog_list.size).intersects(rect):continue
		var record: Dictionary=hud.catalog_results[index]
		var tint: Color=UI.grade(str(record.get("grade","일반")))
		card_frames.draw_rect(rect.grow(-1),UI.GOLD if chosen.has(index) else tint.darkened(.58),false,1)
		card_frames.draw_rect(rect.grow(-3),Color(0,0,0,.75),false,1)
		var id: String=CardRules.card_id(record)
		var count: int=(1 if owned.has(id) else 0)+int(spare.get(id,0))
		if count>0:card_frames.draw_string(UI.FONT,Vector2(rect.position.x+6,rect.end.y-5),str(count),HORIZONTAL_ALIGNMENT_RIGHT,maxf(1,rect.size.x-12),14,UI.TEXT)
