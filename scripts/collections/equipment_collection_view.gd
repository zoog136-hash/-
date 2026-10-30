extends VBoxContainer
## Existing HUD workspace screen. Creates no test items and owns no inventory.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Art = preload("res://scripts/ui/item_icon_art.gd")
const Core = preload("res://scripts/collections/equipment_collection_service.gd")
const NativeList = preload("res://scripts/ui/native_touch_list.gd")
const Rows=preload("res://scripts/collections/collection_rows.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const TouchButton=preload("res://scripts/ui/native_touch_button.gd")
const ScrollButton=preload("res://scripts/growth/growth_touch_button.gd")
# Inspected official item-collection layout, not extracted artwork:
# https://lineagem-jp.com/guides/lm/guides/item_coll
var hud
var runtime
var rows: Array = []
var filtered: Array = []
var selected_id: String = ""
var query: LineEdit
var grade: OptionButton
var status: OptionButton
var favorites: CheckButton
var summary_label: Label
var list
var grade_column: HBoxContainer
var grade_buttons: Array[Button]=[]
var body: HBoxContainer
var detail_scroll: ScrollContainer
var detail: VBoxContainer
var tabs: HBoxContainer
var show_detail: bool = false
var candidates_list: ItemList
var picked_candidates: Array = []
var selected_slot_id: String=""
var detail_side: VBoxContainer
var registration_dock: VBoxContainer
var _snapshot: Dictionary={}
var _slot_cache: Dictionary={}

func configure(owner_hud: Node) -> void:
	hud = owner_hud
	runtime = hud.get_parent().equipment_collections
	rows = runtime.definitions()
	name = "EquipmentCollectionView"
	add_theme_constant_override("separation",6)
	var top := HBoxContainer.new()
	add_child(top)
	query = LineEdit.new()
	query.name = "CollectionSearch"
	query.placeholder_text = "컬렉션 · 장비 · 효과 검색"
	query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	query.custom_minimum_size.y = 38
	top.add_child(query)
	query.text_changed.connect(func(_text: String) -> void: _filter())
	grade = OptionButton.new()
	grade.name = "CollectionGrade"
	for value: String in ["전체 등급","일반","고급","희귀","영웅"]: grade.add_item(value)
	top.add_child(grade)
	grade.item_selected.connect(func(_index: int) -> void: _filter())
	var filters := HBoxContainer.new()
	add_child(filters)
	status = OptionButton.new()
	status.name = "CollectionStateFilter"
	for value: String in ["전체 상태","지원 컬렉션","미완성","완성","보류","등록 가능"]: status.add_item(value)
	filters.add_child(status)
	status.item_selected.connect(func(_index: int) -> void: _filter())
	favorites = CheckButton.new()
	favorites.text = "즐겨찾기"
	filters.add_child(favorites)
	favorites.toggled.connect(func(_enabled: bool) -> void: _filter())
	var space:=Control.new();space.size_flags_horizontal=Control.SIZE_EXPAND_FILL;filters.add_child(space)
	var totals: Button=UI.button("컬렉션 효과",_show_totals,Vector2(114,38))
	totals.name="CollectionAccumulatedEffects";totals.set_script(TouchButton);filters.add_child(totals)
	var reset: Button=UI.button("초기화",func() -> void:
		query.text="";grade.select(0);status.select(0);favorites.set_pressed_no_signal(false);_filter(),Vector2(60,38))
	reset.name="ResetCollectionFilters";reset.set_script(TouchButton);top.add_child(reset)
	summary_label = UI.label("",12,UI.MUTED)
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(summary_label)
	tabs = HBoxContainer.new()
	add_child(tabs)
	tabs.add_child(UI.button("목록",func() -> void: show_detail=false; _fit(),Vector2(100,34)))
	tabs.add_child(UI.button("선택 상세",func() -> void: show_detail=true; _fit(),Vector2(100,34)))
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	add_child(body)
	grade_column=HBoxContainer.new()
	grade_column.hide()
	grade_column.name="CollectionGradeTabs"
	grade_column.add_theme_constant_override("separation",2)
	top.add_child(grade_column);top.move_child(grade_column,0)
	for index: int in range(grade.item_count):
		var button: Button=UI.button("전체" if index==0 else grade.get_item_text(index),func() -> void:grade.select(index);_filter(),Vector2(58,38))
		button.set_script(TouchButton)
		button.toggle_mode=true
		Surfaces.card_tab(button)
		grade_column.add_child(button)
		grade_buttons.append(button)
	var listing:=VBoxContainer.new()
	listing.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	listing.size_flags_vertical=Control.SIZE_EXPAND_FILL
	listing.size_flags_stretch_ratio=2.0
	body.add_child(listing)
	var columns:=HBoxContainer.new();columns.name="CollectionColumnHeadings";listing.add_child(columns)
	for spec: Array in [["컬렉션 목록",.34],["컬렉션 효과",.23],["아이템",.43]]:
		var heading: Label=UI.label(spec[0],12,UI.MUTED)
		heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.size_flags_stretch_ratio=spec[1];columns.add_child(heading)
	list=Rows.new()
	list.name="EquipmentCollectionsList"
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio=1.65
	list.item_selected.connect(_select)
	list.material_selected.connect(func(index: int,sid: String) -> void:_select(index);_choose(selected_id,sid))
	list.favorite_requested.connect(_favorite)
	listing.add_child(list)
	list.configure(hud,self)
	detail_side=VBoxContainer.new()
	detail_side.name="CollectionItemInspector"
	detail_side.custom_minimum_size.x=244
	detail_side.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	detail_side.size_flags_vertical=Control.SIZE_EXPAND_FILL
	detail_side.size_flags_stretch_ratio=1.0
	body.add_child(detail_side)
	detail_scroll = ScrollContainer.new()
	detail_scroll.name = "CollectionDetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.0
	detail_scroll.add_theme_stylebox_override("panel",Surfaces.inset(6))
	detail_side.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",8)
	detail_scroll.add_child(detail)
	hud.workspace.register_scroll_drag(detail_scroll,detail)
	registration_dock=VBoxContainer.new()
	registration_dock.name="CollectionRegistrationDock"
	detail_side.add_child(registration_dock)
	resized.connect(_fit)
	_filter()
	call_deferred("_fit")

func _fit() -> void:
	if not is_instance_valid(tabs): return
	var compact: bool = size.x < 700
	tabs.visible = compact
	grade_column.visible=not compact
	grade.visible=not grade_column.visible
	list.get_parent().visible = not compact or not show_detail
	detail_side.visible = not compact or show_detail

func _matches(row: Dictionary) -> bool:
	var available: bool = bool(runtime.availability(str(row.id)).get("ok",false))
	var complete: bool = runtime.completed(str(row.id))
	if grade.selected > 0 and str(row.grade) != grade.get_item_text(grade.selected): return false
	if status.selected == 1 and not available: return false
	if status.selected == 2 and (complete or not available): return false
	if status.selected == 3 and not complete: return false
	if status.selected == 4 and available: return false
	if status.selected == 5:
		var ready: bool=false
		for requirement: Dictionary in row.requirements:ready=ready or bool(slot_state(row,requirement).ready)
		if complete or not ready:return false
	if favorites.button_pressed and not runtime.progress.favorites.has(str(row.id)): return false
	var search: String = Core.normalize_name(query.text).to_lower()
	if search.is_empty(): return true
	var text: String = str(row.name)+" "+str(row.get("raw_effects",""))
	for req: Dictionary in row.requirements: text += " "+str(req.name)
	return text.to_lower().contains(search)

func _filter(preserve_scroll: bool=false) -> void:
	var previous_scroll: float=list.get_v_scroll_bar().value
	_snapshot=runtime.snapshot();_slot_cache.clear()
	filtered.clear()
	list.clear()
	var overview: Dictionary = runtime.summary()
	summary_label.text = "완성 %d / %d · 지원 %d · 보류 %d · 영구 등록" % [overview.completed,overview.total,overview.available,overview.blocked]
	for row: Dictionary in rows:
		if not _matches(row): continue
		filtered.append(row)
		var done: int = 0
		var required: int = 0
		for req: Dictionary in row.requirements:
			done += runtime.slot_count(str(row.id),str(req.slot_id))
			required += int(req.quantity)
		var mark: String = "완성" if runtime.completed(str(row.id)) else ("%d/%d" % [done,required] if bool(runtime.availability(str(row.id)).get("ok",false)) else "보류")
		list.add_collection(row,mark,runtime.progress.favorites.has(str(row.id)))
	for index: int in range(grade_buttons.size()):
		var total: int=0
		var completed: int=0
		for row: Dictionary in rows:
			if index==0 or str(row.grade)==grade.get_item_text(index):
				total+=1
				if runtime.completed(str(row.id)):completed+=1
		grade_buttons[index].tooltip_text="완성 %d / %d" % [completed,total]
		grade_buttons[index].button_pressed=grade.selected==index
	var selected_index: int = -1
	for i: int in range(filtered.size()):
		if str(filtered[i].id) == selected_id: selected_index=i; break
	if selected_index < 0 and not filtered.is_empty(): selected_index=0
	if selected_index >= 0:
		list.select(selected_index)
		selected_id = str(filtered[selected_index].id)
		_render_detail()
	else:
		_clear_detail()
		detail.add_child(UI.label("해당 조건의 장비 컬렉션이 없습니다",13,UI.MUTED))
	if preserve_scroll:list.get_v_scroll_bar().set_deferred("value",previous_scroll)

func _select(index: int) -> void:
	if index < 0 or index >= filtered.size(): return
	selected_id = str(filtered[index].id)
	selected_slot_id=""
	list.select(index)
	show_detail = true
	_render_detail()
	_fit()

func _clear_detail() -> void:
	for child: Node in detail.get_children(): detail.remove_child(child); child.queue_free()
	for child: Node in registration_dock.get_children():registration_dock.remove_child(child);child.queue_free()
	candidates_list = null
	picked_candidates.clear()

func _favorite(index: int) -> void:
	if index<0 or index>=filtered.size():return
	var cid: String=str(filtered[index].id)
	if not runtime.set_favorite(cid,not runtime.progress.favorites.has(cid)):hud.show_message("즐겨찾기 저장 실패")
	_filter(true)

func slot_state(row: Dictionary,requirement: Dictionary) -> Dictionary:
	var key: String=str(requirement.slot_id)
	if _slot_cache.has(key):return _slot_cache[key]
	var count: int=runtime.slot_count(str(row.id),key)
	var available: bool=bool(runtime.availability(str(row.id)).get("ok",false))
	var candidates: Array=runtime.core.candidates(_snapshot,str(row.id),key) if available and count<int(requirement.quantity) else []
	var state: Dictionary={"registered":count,"quantity":int(requirement.quantity),"ready":not candidates.is_empty(),"complete":count>=int(requirement.quantity)}
	_slot_cache[key]=state
	return state

func decorate_material(button: Button,row: Dictionary,requirement: Dictionary,_edge: int) -> void:
	var state: Dictionary=slot_state(row,requirement)
	var source: Dictionary=runtime.icon_record(str(requirement.name))
	button.tooltip_text="%s %s\n등록 %d / %d · %s" % ["+%d" % int(requirement.enchant) if requirement.enchant!=null else "강화 미확인",requirement.name,state.registered,state.quantity,"등록 완료" if state.complete else "등록 가능한 실물 보유" if state.ready else "조건에 맞는 실물 없음"]
	var art:=TextureRect.new()
	art.name="CollectionRequiredItemArt"
	art.mouse_filter=Control.MOUSE_FILTER_IGNORE
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	button.add_child(art);art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.offset_left=3;art.offset_top=3;art.offset_right=-3;art.offset_bottom=-3
	UI.apply_item_visual(art,source,str(source.get("name",requirement.name)),hud.item_image_index.get("아이템",{}),"slot")
	if not state.ready and not state.complete:art.modulate=Color(.43,.43,.43,.65)
	if requirement.enchant!=null:
		var level: Label=UI.label("+%d" % int(requirement.enchant),11,Color("75b4dc"))
		button.add_child(level);level.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		level.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var count: Label=UI.label("등록" if state.complete else "%d/%d" % [state.registered,state.quantity],10,Color("8bd29c") if state.complete else UI.TEXT)
	button.add_child(count);count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;count.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
	button.set_meta("registered",state.registered);button.set_meta("ready",state.ready)
	if state.complete:button.add_theme_stylebox_override("normal",UI.slot_frame(Color("60826a")))

func _text(value: String, font_size: int = 13, color: Color = Color.WHITE) -> Label:
	var label: Label = UI.label(value,font_size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(label)
	return label

func _render_detail() -> void:
	_clear_detail()
	var row: Dictionary = runtime.core.resolve(selected_id)
	if row.is_empty(): return
	var selected: Dictionary={}
	for requirement: Dictionary in row.requirements:
		if str(requirement.slot_id)==selected_slot_id:selected=requirement
	if selected.is_empty():selected=row.requirements[0];selected_slot_id=str(selected.slot_id)
	_text("아이템 정보",13,UI.GOLD)
	var hero:=HBoxContainer.new();detail.add_child(hero)
	var art:=TextureRect.new()
	art.name="CollectionSelectedItemArt";art.custom_minimum_size=Vector2(64,70)
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var source: Dictionary=runtime.icon_record(str(selected.name))
	art.texture=Art.item_icon(source,str(source.get("name",selected.name)),hud.item_image_index.get("아이템",{}))
	hero.add_child(art)
	var title: Label=UI.label("%s %s" % ["+%d" % int(selected.enchant) if selected.enchant!=null else "",selected.name],14,UI.TEXT)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;hero.add_child(title)
	_text(str(row.name),12,UI.MUTED)
	_text(str(row.get("raw_effects","")),13,UI.GOLD)
	var state: Dictionary=slot_state(row,selected)
	_text("등록 %d / %d · %s" % [state.registered,state.quantity,"등록 완료" if state.complete else "등록 가능한 실물 보유" if state.ready else "조건에 맞는 실물 없음"],12,Color("8bd29c") if state.complete or state.ready else UI.MUTED)
	var description: String=str(source.get("desc",""))
	if not description.is_empty():_text(description,12,UI.MUTED)
	var available: Dictionary = runtime.availability(selected_id)
	if not bool(available.get("ok",false)):
		_text("보류: "+str(available.get("message","확인 필요")),12,Color("e8a077"))
	_text("필요 아이템 · %d종" % row.requirements.size(),12,UI.MUTED)
	var materials:=GridContainer.new()
	materials.name="CollectionAllMaterials";materials.columns=4
	materials.add_theme_constant_override("h_separation",5);materials.add_theme_constant_override("v_separation",5)
	detail.add_child(materials)
	for req: Dictionary in row.requirements:
		var sid: String=str(req.slot_id)
		var pick: Button=UI.button("",func() -> void:_choose(selected_id,sid),Vector2(46,48))
		pick.set_script(ScrollButton);pick.scroll_host=hud.workspace;pick.scroll_area=detail_scroll
		pick.name="Pick_"+sid.get_slice(":",2)
		pick.set_meta("collection_id",selected_id);pick.set_meta("slot_id",sid)
		pick.add_theme_stylebox_override("normal",UI.slot_frame())
		materials.add_child(pick);decorate_material(pick,row,req,40)
		pick.toggle_mode=true;pick.set_pressed_no_signal(sid==selected_slot_id)
	_text("등록한 실물 장비는 소모됩니다. 장착·잠금 장비는 제외됩니다.",11,UI.MUTED)
	var choose: Button=UI.button("등록 완료" if state.complete else "장비 선택",func() -> void:_choose(selected_id,selected_slot_id),Vector2(0,44))
	choose.name="ChooseCollectionEquipment";choose.set_script(TouchButton)
	choose.disabled=not bool(available.get("ok",false)) or state.complete
	Surfaces.action(choose);registration_dock.add_child(choose)
	detail_scroll.get_v_scroll_bar().set_deferred("value",0)

func _show_totals() -> void:
	_clear_detail();show_detail=true;_fit()
	_text("완성 컬렉션 누적 효과",14,UI.GOLD)
	var labels: Dictionary = {}
	for definition: Dictionary in rows:
		for effect: Dictionary in definition.effects: labels[Core.effect_code(effect)] = str(effect.label)
	if runtime.totals.is_empty(): _text("아직 활성화된 효과가 없습니다",12,UI.MUTED)
	for code: String in runtime.totals:
		_text("%s %s%s" % [str(labels.get(code,code)),("%+.2f" % float(runtime.totals[code])).trim_suffix("00").trim_suffix("."),"%" if code.ends_with(":percent") else ""],12,UI.TEXT)

func _choose(cid: String, sid: String) -> void:
	selected_id=cid;selected_slot_id=sid
	_snapshot=runtime.snapshot();_slot_cache.clear()
	_render_detail()
	show_detail=true;_fit()
	picked_candidates = runtime.candidates(cid,sid)
	_text("등록할 실물 장비 선택",15,UI.GOLD)
	if picked_candidates.is_empty():
		_text("조건에 맞는 미장착·잠금 해제 장비가 없습니다. 강화 수치와 장비 원본 ID도 검사합니다.",13,UI.MUTED)
		return
	candidates_list = NativeList.new()
	candidates_list.name = "CollectionCandidates"
	candidates_list.custom_minimum_size.y = 125
	detail.add_child(candidates_list)
	for item: Dictionary in picked_candidates:
		var index: int = candidates_list.add_item("+%d %s  · ID %s" % [int(item.enchant),Core.normalize_name(str(item.name)),item.instance_id])
		candidates_list.set_item_metadata(index,str(item.instance_id))
		candidates_list.set_item_tooltip(index,Core.normalize_name(str(item.name))+"\n원본 ID: "+str(item.source_id))
	var button := UI.button("선택 장비 등록",func() -> void:
		if hud.workspace.was_scroll_dragged(detail_scroll): return
		if candidates_list == null or candidates_list.get_selected_items().is_empty(): hud.show_message("등록할 장비를 먼저 선택하세요"); return
		var chosen: Dictionary = picked_candidates[candidates_list.get_selected_items()[0]]
		var request: Dictionary = runtime.request_for(cid,sid,[str(chosen.instance_id)])
		hud.confirm_action("장비 컬렉션 등록", "+%d %s\n실물 ID %s\n이 장비 1개가 영구히 소모됩니다." % [int(chosen.enchant),Core.normalize_name(str(chosen.name)),chosen.instance_id],"소모하고 등록",func(_count: int) -> void:
			var outcome: Dictionary = runtime.register(request)
			hud.show_message("컬렉션 완성" if bool(outcome.get("ok",false)) and bool(outcome.get("completed",false)) else ("장비 등록 완료" if bool(outcome.get("ok",false)) else str(outcome.get("message","등록 실패"))))
			if is_instance_valid(self) and is_inside_tree(): _filter(true)),Vector2(0,44))
	button.name = "RegisterCollectionItem"
	button.set_script(TouchButton);Surfaces.action(button)
	for previous: Node in registration_dock.get_children():registration_dock.remove_child(previous);previous.queue_free()
	registration_dock.add_child(button)
	detail_scroll.get_v_scroll_bar().set_deferred("value",detail_scroll.get_v_scroll_bar().max_value)
