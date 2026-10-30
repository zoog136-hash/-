extends Node

const UI=preload("res://scripts/ui/renewal_theme.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Visibility=preload("res://scripts/card_option_visibility.gd")
# Directly inspected LineageM screens; no source-game texture extraction.
# https://www.inven.co.kr/board/lineagem/5019/488524
# https://www.inven.co.kr/board/lineagem/5056/20468
var hud: Node
var active: bool=false
var category: String=""
var active_tab: int=0
var saved_detail: bool=false
var header: HBoxContainer
var tabs: Array[Button]=[]
var sheet: ScrollContainer
var name_label: Label
var grade_label: Label
var ownership: Label
var applied: Label
var options: GridContainer
var note: Label
var caption: Label
var information: VBoxContainer
var main_body: Control
var search_row: Control
var fusion: ScrollContainer
var fusion_column: VBoxContainer
var controls_home: Node
var controls_index: int
var detail_visible: bool
var collection_visible: bool
var selected_key: String=""
var number_pattern:=RegEx.new()
var art_column: VBoxContainer
var apply_row: HBoxContainer
var footer_actions: HBoxContainer
var presentation_homes: Array[Dictionary]=[]
var catalog_style: StyleBox
var list_text_lines: int
var list_font_size: int
var roster_key: String=""

func configure(controller: Node) -> void:
	hud=controller
	name="CompanionDetailView"
	var column: Control=hud.catalog_panel.get_child(0)
	main_body=hud.catalog_grade_column.get_parent()
	search_row=hud.catalog_search.get_parent()
	header=HBoxContainer.new()
	header.name="CompanionHeaderTabs"
	header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_child(header)
	header.hide()
	for title: String in ["변신","합성","변신 컬렉션"]:
		var index: int=tabs.size()
		var button: Button=UI.button(title,func() -> void:select_tab(index),Vector2(88 if index<2 else 132,32))
		button.toggle_mode=true
		button.name=["CompanionListTab","CompanionFusionTab","CompanionCollectionTab"][index]
		Surfaces.card_tab(button)
		header.add_child(button)
		tabs.append(button)
	tabs[2].disabled=true
	tabs[2].tooltip_text="카드 컬렉션은 현재 플레이 빌드에서 지원하지 않습니다"
	var space:=Control.new()
	space.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.add_child(space)
	var shop: Button=UI.button("상점 바로가기",func() -> void:hud.open_shop(),Vector2(128,32))
	shop.name="CompanionShopShortcut"
	shop.icon=load("res://assets/ui/shop.png")
	header.add_child(shop)
	sheet=ScrollContainer.new()
	sheet.name="CompanionOptionsScroll"
	sheet.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	sheet.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	sheet.size_flags_vertical=Control.SIZE_EXPAND_FILL
	sheet.add_theme_stylebox_override("panel",Surfaces.inset(8))
	hud.catalog_detail.get_parent().add_child(sheet)
	sheet.hide()
	information=VBoxContainer.new()
	information.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	information.add_theme_constant_override("separation",8)
	sheet.add_child(information)
	hud.workspace.register_scroll_drag(sheet,information)
	name_label=UI.label("",18)
	name_label.name="CompanionSelectedName"
	name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	information.add_child(name_label)
	grade_label=UI.label("",13)
	grade_label.name="CompanionSelectedGrade"
	information.add_child(grade_label)
	ownership=UI.label("",12,UI.MUTED)
	ownership.name="CompanionOwnedState"
	ownership.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	information.add_child(ownership)
	applied=UI.label("",12,UI.MUTED)
	applied.name="CompanionAppliedState"
	applied.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	information.add_child(applied)
	information.add_child(HSeparator.new())
	caption=UI.label("옵션 정보",13,UI.MUTED)
	caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	information.add_child(caption)
	options=GridContainer.new()
	options.name="CompanionOptionValues"
	options.columns=2
	options.add_theme_constant_override("h_separation",8)
	options.add_theme_constant_override("v_separation",7)
	information.add_child(options)
	hud.workspace.register_scroll_drag(sheet,options)
	note=UI.label("",11,UI.MUTED)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	information.add_child(note)
	# The guide has an option sheet below the name/grade, rather than a
	# full-height opaque inspector around the whole preview row.
	sheet.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	var plate:=PanelContainer.new();plate.name="CompanionOptionPlate"
	plate.custom_minimum_size.y=188
	plate.add_theme_stylebox_override("panel",Surfaces.inset(8))
	information.add_child(plate)
	var values:=VBoxContainer.new();values.add_theme_constant_override("separation",8);plate.add_child(values)
	caption.reparent(values);options.reparent(values);note.reparent(values)
	fusion=ScrollContainer.new()
	fusion.name="CompanionExistingFusionPane"
	fusion.size_flags_vertical=Control.SIZE_EXPAND_FILL
	fusion.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(fusion)
	fusion.hide()
	fusion_column=VBoxContainer.new()
	fusion_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fusion_column.add_theme_constant_override("separation",12)
	fusion.add_child(fusion_column)
	var title: Label=UI.section("중복 카드 합성",18)
	fusion_column.add_child(title)
	fusion_column.add_child(UI.label("보유 중복 카드를 재료로 사용합니다.",13,UI.MUTED))
	number_pattern.compile("[+-]?[0-9]")
	art_column=VBoxContainer.new()
	art_column.name="CompanionPreviewColumn"
	art_column.size_flags_vertical=Control.SIZE_EXPAND_FILL
	hud.catalog_preview.get_parent().add_child(art_column)
	art_column.hide()
	apply_row=HBoxContainer.new();apply_row.name="CompanionImmediateApplyRow"
	art_column.add_child(apply_row)
	ownership.reparent(art_column)
	footer_actions=HBoxContainer.new();footer_actions.name="CompanionManagementActions"
	hud.catalog_body_actions.get_child(0).add_child(footer_actions)
	for spec: Array in [["컬렉션 보기","카드 컬렉션 서비스 미지원"],["변신 등록","카드 빠른등록 서비스 미지원"]]:
		var button: Button=UI.button(str(spec[0]),Callable(),Vector2(0,44))
		button.name="CompanionCollectionView" if spec[0]=="컬렉션 보기" else "CompanionQuickRegister"
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.disabled=true;button.tooltip_text=str(spec[1]);UI.primary_button(button)
		footer_actions.add_child(button)
	footer_actions.hide()

func activate(value: String) -> void:
	category=value
	active=true
	selected_key=""
	roster_key=""
	catalog_style=hud.catalog_panel.get_theme_stylebox("panel")
	hud.catalog_panel.add_theme_stylebox_override("panel",Surfaces.card_surface())
	list_text_lines=hud.catalog_list.max_text_lines
	list_font_size=hud.catalog_list.get_theme_font_size("font_size")
	for control: Control in [hud.catalog_preview,hud.catalog_equip_button,hud.catalog_clear_button,hud.option_awakening_button]:
		var props: Dictionary={}
		for key: String in ["custom_minimum_size","size_flags_horizontal","size_flags_vertical","anchor_left","anchor_top","anchor_right","anchor_bottom","offset_left","offset_top","offset_right","offset_bottom"]:props[key]=control.get(key)
		presentation_homes.append({"node":control,"parent":control.get_parent(),"index":control.get_index(),"properties":props})
	hud.catalog_preview.reparent(art_column,false);art_column.move_child(hud.catalog_preview,0)
	art_column.get_parent().move_child(art_column,0)
	hud.catalog_equip_button.reparent(apply_row,false)
	hud.catalog_equip_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	hud.catalog_clear_button.reparent(apply_row,false)
	hud.catalog_clear_button.custom_minimum_size=Vector2(60,44)
	hud.catalog_clear_button.text="해제"
	hud.option_awakening_button.reparent(footer_actions,false)
	footer_actions.move_child(hud.option_awakening_button,0)
	hud.option_awakening_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var right: Control=hud.catalog_body_actions.get_child(0)
	right.move_child(footer_actions,1)
	art_column.show();footer_actions.show()
	(footer_actions.find_child("CompanionQuickRegister",true,false) as Button).text="변신 등록" if category=="변신" else "인형 등록"
	detail_visible=hud.catalog_detail.visible
	collection_visible=hud.equipment_collection_button.visible
	hud.catalog_detail.hide()
	# Preserve main's implemented, explicitly named equipment route. The
	# separate card-collection tab/footer still stay disabled.
	hud.equipment_collection_button.visible=collection_visible
	sheet.show()
	controls_home=hud.card_controls.get_parent()
	controls_index=hud.card_controls.get_index()
	hud.card_controls.reparent(fusion_column,false)
	tabs[0].text=category
	tabs[2].text=("변신" if category=="변신" else "인형")+" 컬렉션"
	caption.text="옵션 정보" if category=="변신" else "인형 소환 옵션"
	header.show()
	hud.workspace.mount_header_filters(header)
	active_tab=0
	select_tab(0)
	refresh()

func deactivate() -> void:
	if not active:return
	select_tab(0)
	active=false
	art_column.hide();footer_actions.hide()
	footer_actions.get_parent().move_child(footer_actions,footer_actions.get_parent().get_child_count()-1)
	for home: Dictionary in presentation_homes:
		var control: Control=home.node
		control.reparent(home.parent,false)
		home.parent.move_child(control,mini(int(home.index),home.parent.get_child_count()-1))
		for key: String in home.properties:control.set(key,home.properties[key])
	presentation_homes.clear()
	hud.catalog_panel.add_theme_stylebox_override("panel",catalog_style)
	hud.catalog_list.max_text_lines=list_text_lines
	hud.catalog_list.add_theme_font_size_override("font_size",list_font_size)
	hud._refresh_option_awakening_markers()
	sheet.hide()
	header.hide()
	fusion.hide()
	main_body.show()
	search_row.show()
	hud.catalog_detail.visible=detail_visible
	hud.equipment_collection_button.visible=collection_visible
	hud.card_controls.reparent(controls_home,false)
	controls_home.move_child(hud.card_controls,mini(controls_index,controls_home.get_child_count()-1))
	# The shared catalog owns these captions in other sections.
	hud.catalog_list_tab.text="아이템 목록"
	hud.catalog_clear_button.text="현재 적용 해제"

func select_tab(index: int) -> void:
	# Use the integration branch's existing fusion screen when it is present.
	# This branch otherwise exposes the original controls without new rules.
	if index==1 and hud.has_method("open_card_fusion"):
		hud.call("open_card_fusion",category)
		return
	if index==1 and active_tab==0:
		saved_detail=hud.catalog_details_active
		hud.catalog_details_active=false
	elif index==0 and active_tab==1:hud.catalog_details_active=saved_detail
	active_tab=index
	for i: int in range(tabs.size()):tabs[i].button_pressed=i==index
	main_body.visible=index==0
	search_row.visible=index==0
	fusion.visible=index==1
	hud.workspace.set_back_available(index==1 or hud.navigation_memory.has_history())
	hud._fit_catalog_browser_layout()

func fit_layout() -> void:
	if not active:return
	if active_tab==1:
		hud.catalog_view_tabs.hide()
		hud.collection_status.hide()
	else:hud.catalog_list_tab.text=category+" 목록"
	var compact: bool=hud.workspace.content.size.x<1040
	# Full-size guide view has one tab bar; the existing list/detail controls
	# remain available on phones, without repeating fusion/awakening entries.
	hud.catalog_view_tabs.visible=compact and active_tab==0
	hud.card_fusion_tab.hide();hud.card_awakening_tab.hide()
	art_column.custom_minimum_size.x=150 if compact else 180
	hud.catalog_preview.custom_minimum_size.x=0
	hud.catalog_preview.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer_actions.visible=active_tab==0
	information.add_theme_constant_override("separation",2 if compact else 8)
	options.add_theme_constant_override("v_separation",3 if compact else 7)
	name_label.add_theme_font_size_override("font_size",16 if compact else 18)
	applied.hide()
	for label: Label in options.get_children():
		label.add_theme_font_size_override("font_size",12 if compact else 13)
		if label.name.begins_with("CompanionOptionValue"):label.custom_minimum_size.x=54 if compact else 66

func refresh() -> void:
	if not active:return
	var record: Dictionary=hud.selected_catalog_record
	if hud.catalog_results.is_empty():record={}
	var identity: String=Cards.card_id(record)
	var key: String=category+identity+str(hash(record.get("sourceOptions",[])))
	if key!=selected_key:
		selected_key=key
		fill_options(record)
	var state: Dictionary=hud.card_collection_state
	var owned: bool=(state.get("owned",{}).get(category,{}) as Dictionary).has(identity)
	var duplicates: int=int(state.get("spare",{}).get(category,{}).get(identity,0))
	ownership.text="보유 %d장 · 중복 %d장" % [(1 if owned else 0)+duplicates,duplicates] if not record.is_empty() else "검색 조건에 맞는 카드가 없습니다"
	var equipped: Dictionary=hud.character_state.get("equipped",{}).get(category,{})
	var selected: bool=not record.is_empty() and str(equipped.get("name",""))==str(record.get("name",""))
	applied.text=("현재 변신 중" if category=="변신" else "현재 소환 중") if selected else "미적용"
	applied.visible=not record.is_empty()
	if not record.is_empty():ownership.text+=" · "+applied.text
	hud.catalog_equip_button.text="카드 선택" if record.is_empty() else ("현재 "+("변신 중" if category=="변신" else "소환 중") if selected else ("즉시 변신" if category=="변신" else "즉시 소환"))
	fit_layout()
	decorate_roster()

func decorate_roster(force: bool=false) -> void:
	if not active:return
	var signature: String=category+str(hud.catalog_icon_generation)+str(hash(hud.card_collection_state))+str(hash(hud.option_awakening_state))
	if signature==roster_key and not force:return
	roster_key=signature
	var owned: Dictionary=hud.card_collection_state.get("owned",{}).get(category,{})
	var spare: Dictionary=hud.card_collection_state.get("spare",{}).get(category,{})
	hud.catalog_list.max_text_lines=1
	hud.catalog_list.add_theme_font_size_override("font_size",1)
	for index: int in range(hud.catalog_results.size()):
		var record: Dictionary=hud.catalog_results[index]
		var identity: String=Cards.card_id(record)
		var duplicates: int=int(spare.get(identity,0))
		var copies: int=(1 if owned.has(identity) else 0)+duplicates
		var awakened: bool=bool(hud._option_awakening_card_state(category,record).get("awakened",false))
		hud.catalog_list.set_item_text(index," ")
		hud.catalog_list.set_item_metadata(index,identity)
		hud.catalog_list.set_item_tooltip(index,("[각성] " if awakened else "")+str(record.name)+" · "+str(record.grade)+"\n보유 %d장 · 중복 %d장 · %s" % [copies,duplicates,identity])
	hud.catalog_list.force_update_list_size()
	if is_instance_valid(hud.catalog_card_chrome):hud.catalog_card_chrome.refresh()

func fill_options(record: Dictionary) -> void:
	for child: Node in options.get_children():options.remove_child(child);child.queue_free()
	var grade: String=str(record.get("grade","일반"))
	name_label.text=str(record.get("name","카드를 선택하세요"))
	name_label.add_theme_color_override("font_color",UI.grade(grade))
	grade_label.text=grade+" · "+str(record.get("type","")) if not record.is_empty() else ""
	grade_label.add_theme_color_override("font_color",UI.grade(grade))
	var unsupported: bool=false
	for raw: Variant in record.get("sourceOptions",[]):
		var option: String=str(raw).replace("PVP","PVE").replace("PvP","PvE")
		if option.contains("손상") or option.contains("저주"):continue
		var result: RegExMatch=number_pattern.search(option)
		var split: int=result.get_start() if result!=null else option.length()
		var title: Label=UI.label(option.substr(0,split).strip_edges(),13)
		title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		options.add_child(title)
		var suffix: String=Visibility.suffix(category,option,record)
		unsupported=unsupported or not suffix.is_empty()
		var value: Label=UI.label(option.substr(split)+(" *" if not suffix.is_empty() else ""),13,UI.MUTED if not suffix.is_empty() else UI.TEXT)
		value.name="CompanionOptionValue"
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		value.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		value.tooltip_text=option+suffix
		value.mouse_filter=Control.MOUSE_FILTER_PASS
		options.add_child(value)
		hud.workspace.register_scroll_drag(sheet,value)
	note.text="* 미지원 특수효과" if unsupported else ""
	note.visible=unsupported
