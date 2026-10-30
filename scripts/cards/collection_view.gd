extends VBoxContainer
## The 2023 official collection screen: grade sidebar, card/effect rows and
## accumulated effects. Uses existing card bitmaps; no registration or consumption.
## https://lineagem.plaync.com/guidebook/view?title=성물%20시스템 (collection image)
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const Cards=preload("res://scripts/card_draw_fusion.gd")
const Chrome=preload("res://scripts/ui/catalog_card_chrome.gd")
const Ownership=preload("res://scripts/ui/catalog_card_ownership.gd")
const TouchButton=preload("res://scripts/ui/native_touch_button.gd")
const ScrollButton=preload("res://scripts/growth/growth_touch_button.gd")
const ROW_HEIGHT: int=196
var hud: Node
var runtime
var category: String
var focus_card: String=""
var rows: Array=[]
var filtered: Array=[]
var cards: Dictionary={}
var grades: Array[Button]=[]
var selected_grade: String="전체"
var selected_card: String=""
var search: LineEdit
var state: OptionButton
var summary: Label
var list: ScrollContainer
var canvas: Control
var views: Array[PanelContainer]=[]
var totals_side: VBoxContainer
var totals_body: VBoxContainer
var body: HBoxContainer
var grade_side: ScrollContainer
var compact_tabs: HBoxContainer
var showing_effects: bool=false
var last_revision: int=-1
var last_spare_hash: int=0
var first: int=-1

func configure(owner_hud: Node,value: String,identity: String="") -> void:
	hud=owner_hud;runtime=hud.get_parent().card_collections
	category=value;focus_card=identity;name="NormalCardCollectionView"
	add_theme_constant_override("separation",6)
	for record: Dictionary in hud.catalog_data.get(category,[]):cards[Cards.card_id(record)]=record
	var tabs:=HBoxContainer.new();add_child(tabs)
	for index: int in range(3):
		var button: Button=_button([category,"합성",("인형" if category=="마법인형" else category)+" 컬렉션"][index])
		button.toggle_mode=true;button.button_pressed=index==2;Surfaces.card_tab(button)
		button.pressed.connect(func() -> void:
			if index==0:hud.open_catalog(category)
			elif index==1:hud.open_card_fusion(category))
		tabs.add_child(button)
	var space:=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;tabs.add_child(space)
	var shop: Button=_button("상점 바로가기");shop.icon=UI.icon("shop");shop.pressed.connect(func() -> void:hud.open_shop());tabs.add_child(shop)
	hud.workspace.mount_header_filters(tabs)
	var filters:=HBoxContainer.new();add_child(filters)
	state=OptionButton.new();state.name="NormalCollectionState"
	for label: String in ["전체","진행 중","미완성","완성","적용 보류"]:state.add_item(label)
	state.custom_minimum_size=Vector2(104,40);filters.add_child(state)
	state.item_selected.connect(func(_index: int) -> void:_filter())
	search=LineEdit.new();search.name="NormalCollectionSearch";search.placeholder_text="컬렉션 · 카드 · 효과 검색"
	search.custom_minimum_size.y=40;search.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(search)
	search.text_changed.connect(func(_text: String) -> void:_filter())
	var reset: Button=_button("초기화");filters.add_child(reset)
	reset.pressed.connect(func() -> void:
		search.text="";state.select(0);selected_grade="전체";focus_card="";_filter())
	summary=UI.label("",11,UI.MUTED);summary.name="NormalCollectionSummary";summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(summary)
	compact_tabs=HBoxContainer.new();add_child(compact_tabs)
	for label: String in ["컬렉션 목록","컬렉션 효과"]:
		var button: Button=_button(label);compact_tabs.add_child(button)
		button.pressed.connect(func() -> void:showing_effects=label=="컬렉션 효과";_fit())
	body=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",8);add_child(body)
	grade_side=ScrollContainer.new();grade_side.name="NormalCollectionGrades";grade_side.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(grade_side)
	var grade_column:=VBoxContainer.new();grade_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grade_side.add_child(grade_column)
	hud.workspace.register_scroll_drag(grade_side,grade_column)
	var choices: Array[String]=["전체","유일","신화","전설","영웅","희귀","고급","일반"]
	for grade: String in choices:
		var button: Button=_button(grade);button.set_script(ScrollButton);button.scroll_host=hud.workspace;button.scroll_area=grade_side
		Surfaces.grade_row(button)
		button.toggle_mode=true;button.custom_minimum_size=Vector2(80,46);button.set_meta("grade",grade)
		button.pressed.connect(func() -> void:selected_grade=grade;_filter())
		grade_column.add_child(button);grades.append(button)
	list=ScrollContainer.new();list.name="NormalCollectionRows";list.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.add_theme_stylebox_override("panel",Surfaces.card_surface());body.add_child(list)
	canvas=Control.new();canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;list.add_child(canvas)
	hud.workspace.register_scroll_drag(list,canvas)
	list.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:_show_rows())
	list.resized.connect(_show_rows)
	totals_side=VBoxContainer.new();totals_side.name="NormalCollectionEffects";body.add_child(totals_side)
	var heading: Label=UI.label("컬렉션 효과",16,UI.GOLD);heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;totals_side.add_child(heading)
	var columns: Label=UI.label("현재  |  확인된 최대",11,UI.MUTED);columns.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;totals_side.add_child(columns)
	var effects_scroll:=ScrollContainer.new();effects_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	effects_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;totals_side.add_child(effects_scroll)
	totals_body=VBoxContainer.new();totals_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;effects_scroll.add_child(totals_body)
	hud.workspace.register_scroll_drag(effects_scroll,totals_body)
	var policy: Label=UI.label("최초 획득 시 자동 반영\n카드 소모 없음\n합성 후에도 달성 유지",12,UI.MUTED);policy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;totals_side.add_child(policy)
	resized.connect(_fit)
	refresh();call_deferred("_fit")

func _button(label: String) -> Button:
	var button: Button=UI.button(label,Callable(),Vector2(0,40));button.set_script(TouchButton);return button

func refresh() -> void:
	if runtime==null:return
	var spare_hash: int=hash(hud.card_collection_state.get("spare",{}).get(category,{}))
	var ownership_changed: bool=last_revision!=runtime.current_revision()
	if not ownership_changed and last_spare_hash==spare_hash:return
	last_spare_hash=spare_hash
	if ownership_changed:
		last_revision=runtime.revision;rows=runtime.snapshot(category,focus_card)
	var old_scroll: int=list.scroll_vertical
	_filter()
	if ownership_changed:_totals()
	list.set_deferred("scroll_vertical",old_scroll)

func _filter() -> void:
	filtered.clear()
	var needle: String=search.text.strip_edges().to_lower()
	var complete_count: int=0
	var active_count: int=0
	for row: Dictionary in rows:
		if bool(row.completed):complete_count+=1
		if bool(row.available):active_count+=1
		if selected_grade!="전체" and row.grade!=selected_grade:continue
		if state.selected==1 and (row.completed or int(row.met_count)==0):continue
		if state.selected==2 and row.completed:continue
		if state.selected==3 and not row.completed:continue
		if state.selected==4 and row.available:continue
		var haystack: String=str(row.name)+" "+str(row.raw_effects)
		for requirement: Dictionary in row.requirements:haystack+=" "+str(requirement.name)
		if not needle.is_empty() and not haystack.to_lower().contains(needle):continue
		filtered.append(row)
	for button: Button in grades:
		var grade: String=str(button.get_meta("grade"));var count: int=0;var done: int=0
		for row: Dictionary in rows:
			if grade=="전체" or row.grade==grade:
				count+=1
				if row.completed:done+=1
		button.text="%s\n(%d/%d)" % [grade,done,count];button.button_pressed=grade==selected_grade
	summary.text="완성 %d / 컬렉션 %d개" % [complete_count,rows.size()]
	if active_count<rows.size():summary.text+=" · 적용 보류 %d개" % (rows.size()-active_count)
	if not focus_card.is_empty():summary.text+=" · 선택 카드 포함 (초기화로 전체)"
	if filtered.is_empty():summary.text+=" · 해당하는 컬렉션 없음"
	canvas.custom_minimum_size.y=filtered.size()*ROW_HEIGHT
	list.scroll_vertical=0;first=-1;_show_rows()

func _fit() -> void:
	if not is_instance_valid(list):return
	var compact: bool=size.x<760
	compact_tabs.visible=compact
	grade_side.custom_minimum_size.x=80 if compact else 104
	for button: Button in grades:
		button.custom_minimum_size.y=44 if size.y<500 else 54
		button.add_theme_font_size_override("font_size",12 if size.y<500 else 14)
	grade_side.visible=not compact or not showing_effects
	list.visible=not compact or not showing_effects
	totals_side.visible=not compact or showing_effects
	totals_side.custom_minimum_size.x=0 if compact else clampf(size.x*.24,200,300)
	totals_side.size_flags_horizontal=Control.SIZE_EXPAND_FILL if compact else Control.SIZE_FILL
	first=-1;_show_rows()

func _show_rows() -> void:
	if not is_instance_valid(canvas) or list.size.y<1 or not list.visible:return
	var start: int=maxi(0,floori(list.get_v_scroll_bar().value/ROW_HEIGHT))
	var count: int=ceili(list.size.y/ROW_HEIGHT)+1
	while views.size()<count:
		var panel:=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_PASS;canvas.add_child(panel);views.append(panel)
		hud.workspace.register_scroll_drag(list,panel)
	while views.size()>count:
		var unused: PanelContainer=views.pop_back();canvas.remove_child(unused);unused.queue_free()
	var changed: bool=first!=start;first=start
	for offset: int in range(views.size()):
		var index: int=start+offset;var panel: PanelContainer=views[offset]
		panel.visible=offset<count and index<filtered.size()
		if not panel.visible:continue
		panel.position=Vector2(0,index*ROW_HEIGHT);panel.size=Vector2(maxf(1,list.size.x-14),ROW_HEIGHT-5)
		if changed or panel.get_meta("index",-1)!=index or not is_equal_approx(float(panel.get_meta("width",-1)),panel.size.x):_fill(panel,index)

func _fill(panel: PanelContainer,index: int) -> void:
	panel.set_meta("index",index);panel.set_meta("width",panel.size.x)
	for child: Node in panel.get_children():panel.remove_child(child);child.queue_free()
	var row: Dictionary=filtered[index]
	panel.set_meta("collection_id",row.id);panel.set_meta("completed",row.completed)
	panel.add_theme_stylebox_override("panel",Surfaces.card_surface(5))
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",4);panel.add_child(column)
	var plate:=PanelContainer.new();plate.add_theme_stylebox_override("panel",UI.MATERIAL.from_flat(UI.box(Color("20323c") if row.completed else Color("172026"),Color("3c6571") if row.completed else Color("303c43"),4),true));column.add_child(plate)
	var heading:=HBoxContainer.new();plate.add_child(heading)
	var header: Label=UI.label("%s  (%d/%d)  %s" % [row.name,row.met_count,row.requirements.size(),"완성" if row.completed else "적용 보류" if not row.available else "미완성"],13,Color("82becb") if row.completed else UI.TEXT)
	header.name="NormalCollectionTitle";header.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;header.max_lines_visible=2;header.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(header)
	var effects: Label=UI.label(str(row.raw_effects).replace("\n"," · "),11,UI.GOLD if row.available else UI.MUTED)
	effects.name="NormalCollectionReward";effects.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effects.max_lines_visible=2
	effects.custom_minimum_size.x=clampf(panel.size.x*.30,130,240);effects.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;heading.add_child(effects)
	var material_row:=HBoxContainer.new();material_row.add_theme_constant_override("separation",4);column.add_child(material_row)
	var card_width: float=clampf((panel.size.x-20-4*(row.requirements.size()-1))/maxi(1,row.requirements.size()),45,88)
	for requirement: Dictionary in row.requirements:_card(material_row,requirement,card_width)
	if not row.available:
		panel.tooltip_text="자동 적용 보류: "+_reasons(row.problems)+"\n"+str(row.source.url)
	else:panel.tooltip_text="최초 획득 자동 완성 · 카드 소모 없음\n"+str(row.source.url)

func _card(parent: Node,requirement: Dictionary,width: float) -> void:
	var key: String=str(requirement.id);var record: Dictionary=cards.get(key,{})
	var acquired: bool=bool(requirement.met)
	var column:=VBoxContainer.new();column.custom_minimum_size.x=width;column.mouse_filter=Control.MOUSE_FILTER_PASS;parent.add_child(column)
	var button: Button=_button("");button.set_script(ScrollButton);button.scroll_host=hud.workspace;button.scroll_area=list
	button.name="NormalCollectionCard";button.custom_minimum_size=Vector2(width,112);button.set_meta("card_id",key);button.set_meta("permanent_owned",acquired)
	button.tooltip_text=str(requirement.name)+" · "+("보유" if acquired else "각성 조건 확인 필요" if requirement.awakened else "미보유")
	column.add_child(button)
	if record.is_empty():
		button.text="카드\n매칭 필요";button.disabled=true
	else:
		var rank: int=maxi(0,Chrome.GRADES.find(str(record.get("grade","일반"))))
		var art:=TextureRect.new();art.name="NormalCollectionCardArt";art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture=Ownership.icon_for(record,acquired);art.modulate=Color.WHITE if acquired else Ownership.UNOWNED_ICON_TINT
		button.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if acquired:
			var aura:=ColorRect.new();aura.mouse_filter=Control.MOUSE_FILTER_IGNORE
			aura.material=Chrome.material_for(rank,true,false,bool(hud.get_parent().presentation_settings.get("reduced_motion",false)),str(hud.get_parent().presentation_settings.get("effect_detail","full"))=="low")
			button.add_child(aura);aura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var metal:=TextureRect.new();metal.mouse_filter=Control.MOUSE_FILTER_IGNORE;metal.texture=Chrome.texture_for(rank)
		metal.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;metal.material=Chrome.material_for(rank,false,false,bool(hud.get_parent().presentation_settings.get("reduced_motion",false)))
		metal.modulate=Color.WHITE if acquired else Ownership.UNOWNED_FRAME_TINT
		button.add_child(metal);metal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var copies: int=(1 if acquired else 0)+int(hud.card_collection_state.get("spare",{}).get(category,{}).get(key,0))
		if copies>1:
			var amount: Label=UI.label(str(copies),11)
			amount.name="NormalCollectionCardCopies";amount.mouse_filter=Control.MOUSE_FILTER_IGNORE
			amount.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;amount.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
			amount.add_theme_color_override("font_outline_color",Color.BLACK);amount.add_theme_constant_override("outline_size",3)
			button.add_child(amount);amount.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);amount.offset_right=-5;amount.offset_bottom=-3
		button.pressed.connect(func() -> void:selected_card=key;summary.text=str(requirement.name)+" · "+("최초 획득 완료" if acquired else "미보유")+" · 중복 카드 소모와 무관")
	var title: Label=UI.label(str(requirement.name),10,UI.TEXT if acquired else UI.MUTED)
	title.custom_minimum_size.x=width;title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.max_lines_visible=2;column.add_child(title)

func _totals() -> void:
	for child: Node in totals_body.get_children():totals_body.remove_child(child);child.queue_free()
	var active: Dictionary={};var possible: Dictionary={};var labels: Dictionary={}
	for row: Dictionary in rows:
		if not row.available:continue
		for effect: Dictionary in row.effects:
			var key: String=str(effect.key)+":"+str(effect.unit)
			possible[key]=float(possible.get(key,0))+float(effect.value)
			if row.completed:active[key]=float(active.get(key,0))+float(effect.value)
			var pattern:=RegEx.new();pattern.compile("\\s*[+-]?[0-9]+(?:\\.[0-9]+)?%?$")
			labels[key]=pattern.sub(str(effect.label),"").strip_edges()
	for key: String in possible:
		var line:=HBoxContainer.new();totals_body.add_child(line)
		var label: Label=UI.label(str(labels[key]),11,UI.TEXT);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;line.add_child(label)
		var unit: String="%" if key.ends_with(":percent") else ""
		var value: Label=UI.label("%s%s | %s%s" % [_number(float(active.get(key,0))),unit,_number(float(possible[key])),unit],11,UI.GOLD)
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;line.add_child(value)
	if possible.is_empty():totals_body.add_child(UI.label("확인된 적용 효과 없음",12,UI.MUTED))

func _number(value: float) -> String:
	return ("+" if value>0 else "")+(str(int(value)) if value==floorf(value) else String.num(value,2))

func _reasons(problems: Array) -> String:
	var out: Array[String]=[]
	for raw: Variant in problems:
		var code: String=str(raw)
		var label: String="카드 매칭 누락" if code.begins_with("card_unmapped:") else "각성 조건 별도" if code=="awakening_collection_separate" else "현재 전투 효과 미지원" if code.begins_with("effect_unsupported:") else "출처 버전 확인 필요"
		if not out.has(label):out.append(label)
	return " · ".join(out)
