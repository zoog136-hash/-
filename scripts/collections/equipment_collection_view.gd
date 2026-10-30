extends VBoxContainer
## Existing HUD workspace screen. Creates no test items and owns no inventory.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Art = preload("res://scripts/ui/item_icon_art.gd")
const Core = preload("res://scripts/collections/equipment_collection_service.gd")
const NativeList = preload("res://scripts/ui/native_touch_list.gd")
const Rows=preload("res://scripts/collections/collection_rows.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
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
var grade_column: VBoxContainer
var grade_buttons: Array[Button]=[]
var body: HBoxContainer
var detail_scroll: ScrollContainer
var detail: VBoxContainer
var tabs: HBoxContainer
var show_detail: bool = false
var candidates_list: ItemList
var picked_candidates: Array = []

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
	for value: String in ["전체 상태","진행 가능","미완성","완성","보류"]: status.add_item(value)
	filters.add_child(status)
	status.item_selected.connect(func(_index: int) -> void: _filter())
	favorites = CheckButton.new()
	favorites.text = "즐겨찾기"
	filters.add_child(favorites)
	favorites.toggled.connect(func(_enabled: bool) -> void: _filter())
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
	grade_column=VBoxContainer.new()
	grade_column.hide()
	grade_column.custom_minimum_size.x=108
	body.add_child(grade_column)
	for index: int in range(grade.item_count):
		var button: Button=UI.button("전체" if index==0 else grade.get_item_text(index),func() -> void:grade.select(index);_filter(),Vector2(0,54))
		button.toggle_mode=true
		Surfaces.grade_row(button)
		grade_column.add_child(button)
		grade_buttons.append(button)
	list=Rows.new()
	list.name="EquipmentCollectionsList"
	list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.size_flags_vertical=Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio=1.65
	list.item_selected.connect(_select)
	body.add_child(list)
	list.configure(hud)
	detail_scroll = ScrollContainer.new()
	detail_scroll.name = "CollectionDetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_stretch_ratio = 1.0
	detail_scroll.add_theme_stylebox_override("panel",Surfaces.inset(6))
	body.add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation",8)
	detail_scroll.add_child(detail)
	resized.connect(_fit)
	_filter()
	call_deferred("_fit")

func _fit() -> void:
	if not is_instance_valid(tabs): return
	var compact: bool = size.x < 660
	tabs.visible = compact
	grade_column.visible=not compact and size.y>=420
	grade.visible=not grade_column.visible
	list.visible = not compact or not show_detail
	detail_scroll.visible = not compact or show_detail

func _matches(row: Dictionary) -> bool:
	var available: bool = bool(runtime.availability(str(row.id)).get("ok",false))
	var complete: bool = runtime.completed(str(row.id))
	if grade.selected > 0 and str(row.grade) != grade.get_item_text(grade.selected): return false
	if status.selected == 1 and not available: return false
	if status.selected == 2 and (complete or not available): return false
	if status.selected == 3 and not complete: return false
	if status.selected == 4 and available: return false
	if favorites.button_pressed and not runtime.progress.favorites.has(str(row.id)): return false
	var search: String = Core.normalize_name(query.text).to_lower()
	if search.is_empty(): return true
	var text: String = str(row.name)+" "+str(row.get("raw_effects",""))
	for req: Dictionary in row.requirements: text += " "+str(req.name)
	return text.to_lower().contains(search)

func _filter() -> void:
	filtered.clear()
	list.clear()
	var overview: Dictionary = runtime.summary()
	summary_label.text = "장비 %d개 · 진행 가능 %d · 완성 %d · 보류 %d | 각인 구분 없음 · 요구 강화 일치" % [overview.total,overview.available,overview.completed,overview.blocked]
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
		grade_buttons[index].text="%s\n(%d/%d)" % ["전체" if index==0 else grade.get_item_text(index),completed,total]
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

func _select(index: int) -> void:
	if index < 0 or index >= filtered.size(): return
	selected_id = str(filtered[index].id)
	list.select(index)
	show_detail = true
	_render_detail()
	_fit()

func _clear_detail() -> void:
	for child: Node in detail.get_children(): detail.remove_child(child); child.queue_free()
	candidates_list = null
	picked_candidates.clear()

func _text(value: String, font_size: int = 13, color: Color = Color.WHITE) -> Label:
	var label: Label = UI.label(value,font_size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(label)
	return label

func _render_detail() -> void:
	_clear_detail()
	var row: Dictionary = runtime.core.resolve(selected_id)
	if row.is_empty(): return
	_text(str(row.name),18,UI.grade(str(row.grade)))
	_text(str(row.get("raw_effects","")),14,UI.GOLD)
	var favorite := UI.button("★ 즐겨찾기 해제" if runtime.progress.favorites.has(selected_id) else "☆ 즐겨찾기 추가",func() -> void:
		if hud.workspace.was_scroll_dragged(detail_scroll): return
		if not runtime.set_favorite(selected_id,not runtime.progress.favorites.has(selected_id)): hud.show_message("즐겨찾기 저장 실패")
		_filter(),Vector2(140,34))
	detail.add_child(favorite)
	hud.workspace.register_scroll_drag(detail_scroll,favorite)
	var available: Dictionary = runtime.availability(selected_id)
	if not bool(available.get("ok",false)):
		_text("보류: "+str(available.get("message","확인 필요")),13,Color("e8a077"))
	_text("등록한 장비는 소모됩니다. 장착·잠금 장비는 등록할 수 없습니다.",12,UI.MUTED)
	for req: Dictionary in row.requirements:
		var slot := HBoxContainer.new()
		detail.add_child(slot)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(44,44)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var source: Dictionary = runtime.icon_record(str(req.name))
		icon.texture = Art.item_icon(source,str(source.get("name",req.name)),hud.get_parent().catalog_image_index.get("아이템",{}))
		slot.add_child(icon)
		var label: Label = UI.label("%s %s\n등록 %d / %d" % ["+%d" % int(req.enchant) if req.enchant != null else "강화 미확인",req.name,runtime.slot_count(selected_id,str(req.slot_id)),int(req.quantity)],13,UI.TEXT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.add_child(label)
		var cid: String = selected_id
		var sid: String = str(req.slot_id)
		var pick := UI.button("장비 선택",func() -> void:
			if not hud.workspace.was_scroll_dragged(detail_scroll): _choose(cid,sid),Vector2(94,40))
		pick.name = "Pick_"+sid.get_slice(":",2)
		pick.disabled = not bool(available.get("ok",false)) or runtime.slot_count(cid,sid) >= int(req.quantity)
		slot.add_child(pick)
		hud.workspace.register_scroll_drag(detail_scroll,pick)
	detail.add_child(HSeparator.new())
	_text("완성 컬렉션 누적 효과",14,UI.GOLD)
	var labels: Dictionary = {}
	for definition: Dictionary in rows:
		for effect: Dictionary in definition.effects: labels[Core.effect_code(effect)] = str(effect.label)
	if runtime.totals.is_empty(): _text("아직 활성화된 효과가 없습니다",12,UI.MUTED)
	for code: String in runtime.totals:
		_text("%s %s%s" % [str(labels.get(code,code)),("%+.2f" % float(runtime.totals[code])).trim_suffix("00").trim_suffix("."),"%" if code.ends_with(":percent") else ""],12,UI.TEXT)

func _choose(cid: String, sid: String) -> void:
	_render_detail()
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
		candidates_list.set_item_tooltip(index,"원본 보관명: "+str(item.name)+"\n원본 ID: "+str(item.source_id))
	var button := UI.button("선택 장비 등록",func() -> void:
		if hud.workspace.was_scroll_dragged(detail_scroll): return
		if candidates_list == null or candidates_list.get_selected_items().is_empty(): hud.show_message("등록할 장비를 먼저 선택하세요"); return
		var chosen: Dictionary = picked_candidates[candidates_list.get_selected_items()[0]]
		var request: Dictionary = runtime.request_for(cid,sid,[str(chosen.instance_id)])
		hud.confirm_action("장비 컬렉션 등록", "+%d %s\n실물 ID %s\n이 장비 1개가 영구히 소모됩니다." % [int(chosen.enchant),Core.normalize_name(str(chosen.name)),chosen.instance_id],"소모하고 등록",func(_count: int) -> void:
			var outcome: Dictionary = runtime.register(request)
			hud.show_message("컬렉션 완성" if bool(outcome.get("ok",false)) and bool(outcome.get("completed",false)) else ("장비 등록 완료" if bool(outcome.get("ok",false)) else str(outcome.get("message","등록 실패"))))
			if is_instance_valid(self) and is_inside_tree(): _filter()),Vector2(150,40))
	button.name = "RegisterCollectionItem"
	detail.add_child(button)
	hud.workspace.register_scroll_drag(detail_scroll,button)
	detail_scroll.get_v_scroll_bar().set_deferred("value",detail_scroll.get_v_scroll_bar().max_value)
