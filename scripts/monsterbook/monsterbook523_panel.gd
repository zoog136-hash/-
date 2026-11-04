extends VBoxContainer
## Dedicated progress UI, separate from the existing monster catalog/browser.
const UI = preload("res://scripts/ui/renewal_theme.gd")
var world: Node
var book_service
var selected_id: int = 0
var visible_books: Array = []
var search: LineEdit
var history: CheckBox
var list: ItemList
var detail: VBoxContainer
var status: Label
var stage_scroll: ScrollContainer
var scroll_host: Node
var result: Label

func configure(host: Node) -> void:
	world = host
	book_service = world.get("monsterbook523")
	scroll_host = world.get("hud").get("workspace")
	name = "MonsterBook523Panel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var filters := HBoxContainer.new()
	add_child(filters)
	search = LineEdit.new()
	search.name = "MonsterBookSearch"
	search.placeholder_text = "몬스터 도감 검색"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(search)
	history = CheckBox.new()
	history.set_script(preload("res://scripts/ui/native_touch_button.gd"))
	history.name = "MonsterBookHistory"
	history.text = "과거 정의 포함"
	filters.add_child(history)
	status = UI.label("", 13)
	status.name = "MonsterBookStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	list = preload("res://scripts/ui/native_touch_list.gd").new()
	list.name = "MonsterBookList"
	list.custom_minimum_size.y = 110
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(list)
	var scroll := ScrollContainer.new()
	stage_scroll = scroll
	scroll.name = "MonsterBookStagesScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	detail = VBoxContainer.new()
	detail.name = "MonsterBookStages"
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail)
	result = UI.label("", 13, UI.GOLD)
	result.name = "MonsterBookActionResult"
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result)
	search.text_changed.connect(func(_text: String) -> void: refresh())
	history.toggled.connect(func(_enabled: bool) -> void: refresh())
	list.item_selected.connect(func(index: int) -> void:
		selected_id = int(visible_books[index].ID)
		show_selected())
	if book_service != null: book_service.changed.connect(refresh)
	refresh()

func refresh() -> void:
	list.clear()
	visible_books.clear()
	if book_service == null or not book_service.loaded():
		status.text = "몬스터 도감 자료가 필요합니다. 저장된 처치·등록·보상 기록은 유지됩니다."
		_clear_detail()
		return
	for book: Dictionary in book_service.books(not history.button_pressed):
		if not search.text.is_empty() and not str(book.Name).to_lower().contains(search.text.to_lower()):
			continue
		visible_books.append(book)
		list.add_item(str(book.Name) + (" · 대상 연결 없음" if int(book.NpcGroupID) == 0 else ""))
		list.set_item_metadata(list.item_count-1, int(book.ID))
		if int(book.ID) == selected_id:
			list.select(list.item_count - 1)
	status.text = "현재 대상 연결 도감 33개 · 전체 정의 557개 · 검색 결과 %d개" % visible_books.size()
	if list.get_selected_items().is_empty() and not visible_books.is_empty():
		selected_id = int(visible_books[0].ID)
		list.select(0)
	show_selected()

func _clear_detail() -> void:
	for child: Node in detail.get_children():
		detail.remove_child(child)
		child.queue_free()

func _text(value: String, color: Color = UI.TEXT) -> void:
	var label := UI.label(value, 13, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(label)

func _date(value: Dictionary) -> String:
	if value.is_empty(): return "확인 필요"
	return "%04d-%02d-%02d %02d:%02d" % [value.Year, value.Month, value.Day, value.Hour, value.Minute]

func _description(table: String, id: int) -> String:
	var raw: Dictionary = book_service.row(table, id)
	var desc: Dictionary = book_service.row("DescData_Korean", int(raw.get("DescID", 0)))
	return str(desc.get("Description", raw.get("Name", str(id))))

func show_selected() -> void:
	_clear_detail()
	if list.get_selected_items().is_empty():
		_text("검색 결과가 없습니다.")
		return
	var book: Dictionary = book_service.row("MonsterBook", selected_id)
	var period: Dictionary = book_service.raw_period(selected_id)
	_text(str(book.Name), UI.GOLD)
	_text("집계: %s ~ %s\n옵션 종료: %s · 원문 한국 날짜, 시간대 판정 대기" % [_date(period.StartDateTimeID), _date(period.CountingEndDateTimeID), _date(period.EndDateTimeID)], UI.MUTED)
	if int(book.NpcGroupID) == 0:
		_text("현재 대상 연결이 없는 과거 정의입니다. 기존 기록을 조회할 수 있습니다.", UI.MUTED)
	var progress: Dictionary = book_service.progress(selected_id)
	for stage: Dictionary in book_service.levels(selected_id):
		var level_id := int(stage.ID)
		var registered: bool = progress.get("registered", []).has(level_id)
		var claimed: bool = progress.get("claimed", []).has(level_id)
		_text("Lv.%d · 처치 %d / %d · %s · %s" % [int(stage.Level), int(progress.get("counts", {}).get(str(level_id), 0)), int(stage.Amount), "등록 완료" if registered else "미등록", "보상 수령 완료" if claimed else "보상 미수령"], UI.GOLD)
		var currency := _description("Currency", int(stage.CurrencyID)) if int(stage.CurrencyID) else "없음"
		_text("등록 비용: %s %d" % [currency, int(stage.CurrencyCost)])
		if stage.bonuses.is_empty(): _text("단계 옵션 없음", UI.MUTED)
		for bonus: Dictionary in stage.bonuses:
			var type: Dictionary = book_service.row("BonusType", int(bonus.BonusTypeID))
			var unit: Dictionary = book_service.row("Unit", int(type.get("UnitID", 0)))
			_text("옵션: %s · %s %s (원문 단위)" % [_description("BonusType", int(bonus.BonusTypeID)), str(bonus.Value), str(unit.get("Name", ""))])
		for reward: Dictionary in stage.rewards:
			var title := _description("RewardType", int(reward.RewardTypeID))
			if int(reward.RewardTypeID) == 2:
				title = _description("ItemClass", int(reward.RewardClassID))
			_text("보상: %s × %d" % [title, int(reward.Amount)])
		var actions := HBoxContainer.new()
		detail.add_child(actions)
		for action: String in ["register", "claim"]:
			var label: String = "등록" if action == "register" else "보상 받기"
			var button := UI.button(label, _request.bind(action, level_id), Vector2(112, 36))
			button.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
			button.scroll_host = scroll_host
			button.scroll_area = stage_scroll
			button.name = "MonsterBook_%s_%d" % [action, level_id]
			var reason: String = world.call("monsterbook_action_status", action, selected_id, level_id)
			button.disabled = not reason.is_empty()
			button.tooltip_text = reason
			actions.add_child(button)
			if not reason.is_empty():
				var note := UI.label(reason, 12, UI.MUTED)
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				detail.add_child(note)

func _request(action: String, level_id: int) -> void:
	if scroll_host.was_scroll_dragged(stage_scroll): return
	var outcome: Dictionary = world.call("request_monsterbook_action", action, selected_id, level_id)
	result.text = str(outcome.get("message", "처리를 완료하지 못했습니다."))
	show_selected()
