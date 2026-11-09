extends VBoxContainer
## Dedicated progress UI, separate from the existing monster catalog/browser.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const SOURCE_ITEMS = preload("res://scripts/monsterbook/monsterbook523_items.gd")
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
var choice_item: String = ""
var owned_controls: Dictionary = {}

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
	owned_controls.clear()
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
	var book_runtime: Variant = world.get("monsterbook523_runtime") if world != null else null
	if book_runtime != null and book_service.has_method("local_period"):
		period = book_service.local_period(selected_id, book_runtime.local.source_clock())
	_text(str(book.Name), UI.GOLD)
	var turn_note: String = " · 로컬 순환 %d회차" % int(period.rotation) if int(period.get("rotation", 0)) > 0 else ""
	_text("집계: %s ~ %s\n옵션 종료: %s · 한국 날짜 표기%s" % [_date(period.StartDateTimeID), _date(period.CountingEndDateTimeID), _date(period.EndDateTimeID), turn_note], UI.MUTED)
	if int(book.NpcGroupID) == 0:
		_text("현재 대상 연결이 없는 과거 정의입니다. 기존 기록을 조회할 수 있습니다.", UI.MUTED)
	var progress: Dictionary = book_service.progress(selected_id)
	var live: RefCounted = world.get("monsterbook523_runtime")
	if live.action_authority == Callable(live.local,"action_receipt"):
		var phase: String = live.local.window_problem(selected_id)
		_text("자동 집계 중 · 기존 게임의 인정 처치 기준" if phase.is_empty() else phase, UI.GOLD)
		var saved: Dictionary = book_service.export_state().books.get(str(selected_id),{})
		if not saved.is_empty() and saved.get("current_epoch","") != live.local.epoch(selected_id): _text("이전 기간 기록 · 이번 기간 첫 인정 처치에서 새로 집계합니다",UI.MUTED)
	if progress.has("kill_count"): _text("이번 기간 총 인정 처치: %d" % int(progress.kill_count))
	if not live.pending_deaths.is_empty(): _text("저장 재시도 대기 중 · 보상 상태는 변경하지 않습니다",UI.MUTED)
	if live.action_authority == Callable(live.local,"action_receipt"):
		_text("게임 다이아: %d · 도감 즉시 완료용" % live.economy.gems())
		var rate: int = int(live.economy.BALANCE.data.adena_per_internal_gem)
		_text("자체 설정: 1 다이아 = %d 아데나 · EXP는 기존 성수 균형 비율로 환산" % rate,UI.MUTED)
		var count_policy: String = str(progress.get("counter_policy",live.economy.settings.get("natural_counter_mode","per_stage")))
		var bonus_policy: String = str(progress.get("bonus_policy",live.economy.settings.get("bonus_mode","cumulative")))
		_text("TWILIGHT 호환 규칙 · 처치: %s / 옵션: %s" % [{"per_stage":"단계별 목표","cumulative":"총처치 누적","manual":"첫 단계·확정 판정"}.get(count_policy,count_policy),{"cumulative":"달성 단계 누적","latest":"최고 단계","manual":"수동 선택"}.get(bonus_policy,bonus_policy)],UI.MUTED)
		var exchange := UI.button("다이아 10개 교환 · %d 아데나" % (10*rate),_exchange,Vector2(240,36))
		exchange.name = "MonsterBookExchange"
		exchange.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
		exchange.scroll_host = scroll_host
		exchange.scroll_area = stage_scroll
		exchange.disabled = not live.local.window_problem(selected_id).is_empty() or world.gold < 10*rate
		detail.add_child(exchange)
	_owned_items(live)
	if progress.get("bonus_policy","") == "manual" and not progress.get("registered",[]).is_empty() and live.economy.settings.get("bonus_mode") in ["cumulative","latest"]:
		var first_id: int = int(progress.registered[0])
		var auto_button := _owned_button("설정대로 자동 옵션 적용",_request.bind("auto_effects",first_id))
		auto_button.name = "MonsterBookAutoEffects"
		auto_button.disabled = not world.monsterbook_action_status("auto_effects",selected_id,first_id).is_empty()
	for stage: Dictionary in book_service.levels(selected_id):
		var level_id := int(stage.ID)
		var registered: bool = progress.get("registered", []).has(level_id)
		var claimed: bool = progress.get("claimed", []).has(level_id)
		_text("Lv.%d · 처치 %d / %d · %s · %s" % [int(stage.Level), int(progress.get("counts", {}).get(str(level_id), 0)), int(stage.Amount), "등록 완료" if registered else "미등록", "보상 수령 완료" if claimed else "보상 미수령"], UI.GOLD)
		var currency := _description("Currency", int(stage.CurrencyID)) if int(stage.CurrencyID) else "없음"
		_text("원본 즉시 완료 비용: %s %d · 일반 처치 달성은 무료" % [currency, int(stage.CurrencyCost)])
		if stage.bonuses.is_empty(): _text("단계 옵션 없음", UI.MUTED)
		for bonus: Dictionary in stage.bonuses:
			var type: Dictionary = book_service.row("BonusType", int(bonus.BonusTypeID))
			var unit: Dictionary = book_service.row("Unit", int(type.get("UnitID", 0)))
			_text("옵션: %s · %s %s (원문 단위)" % [_description("BonusType", int(bonus.BonusTypeID)), str(bonus.Value), str(unit.get("Name", ""))])
			var pending_bonus: String = live.bonus_status(bonus)
			if not pending_bonus.is_empty(): _text(pending_bonus,UI.MUTED)
		if not stage.bonuses.is_empty(): _text("옵션 적용 중" if progress.get("effective_levels",[]).has(level_id) else "직접 선택하면 이 단계만 적용하는 수동 모드로 전환합니다",UI.MUTED)
		for reward: Dictionary in stage.rewards:
			var title := _description("RewardType", int(reward.RewardTypeID))
			if int(reward.RewardTypeID) == 2:
				title = _description("ItemClass", int(reward.RewardClassID))
			var paid: bool = book_service.reward_claimed(selected_id, level_id, int(reward.ID))
			_text("보상: %s × %d · %s" % [title, int(reward.Amount), "수령 완료" if paid else "미수령"])
			if int(reward.RewardTypeID) == 1 and live.action_authority == Callable(live.local,"action_receipt"):
				_text("TWILIGHT 자체 환산 EXP: %d" % live.economy.experience_amount(reward),UI.MUTED)
			if not paid and live.action_authority == Callable(live.local,"action_receipt"):
				var pending: String = live.items.reward_problem(reward)
				if not pending.is_empty(): _text(pending, UI.MUTED)
		var actions := HBoxContainer.new()
		detail.add_child(actions)
		var stage_actions: Array = ["register","claim","instant"] if int(stage.CurrencyCost) > 0 else ["register","claim"]
		if not stage.bonuses.is_empty(): stage_actions.append("effects")
		for action: String in stage_actions:
			var label: String = "옵션 적용" if action == "effects" else ("즉시 완료 · %d" % int(stage.CurrencyCost) if action == "instant" else ("달성 기록" if action == "register" else "보상 받기"))
			var button := UI.button(label, _request.bind(action, level_id), Vector2(112, 36))
			button.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
			button.scroll_host = scroll_host
			button.scroll_area = stage_scroll
			button.name = "MonsterBook_%s_%d" % [action, level_id]
			if action == "claim" and stage.rewards.size() == 1:
				var only_reward: Dictionary = stage.rewards[0]
				var reward_type: Dictionary = book_service.row("RewardType", int(only_reward.get("RewardTypeID", 0)))
				if reward_type.get("Name") == "Item":
					var reward_item_id: int = int(only_reward.get("RewardClassID", 0))
					_button_item_image(button, book_service.row("ItemClass", reward_item_id), _description("ItemClass", reward_item_id))
			var reason: String = world.call("monsterbook_action_status", action, selected_id, level_id)
			button.disabled = not reason.is_empty()
			button.tooltip_text = reason
			actions.add_child(button)
			if not reason.is_empty():
				var note := UI.label(reason, 12, UI.MUTED)
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				detail.add_child(note)


func _exchange() -> void:
	if scroll_host.was_scroll_dragged(stage_scroll): return
	var outcome: Dictionary = world.monsterbook523_runtime.economy.exchange(10)
	result.text = str(outcome.message)
	show_selected()

func _owned_button(text: String, callback: Callable) -> Button:
	var button := UI.button(text,callback,Vector2(180,36))
	button.set_script(preload("res://scripts/growth/growth_touch_button.gd"))
	button.scroll_host = scroll_host
	button.scroll_area = stage_scroll
	detail.add_child(button)
	return button

func _button_item_image(button: Button, source_row: Dictionary, title: String) -> void:
	if not SOURCE_IMAGES.selected(): return
	var image: Dictionary = SOURCE_IMAGES.describe_item_class_row(source_row,title)
	button.icon = image.get("texture") as Texture2D
	button.expand_icon = true
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	button.set_meta("source523_item_image",evidence)

func _owned_items(live: RefCounted) -> void:
	var saved: Dictionary = book_service.export_state()
	for name: String in saved.get("source_items",{}):
		var record: Dictionary = saved.source_items[name]
		var quantity: int = int(world.inventory.get(name,0))
		var expired: int = int(saved.get("expired_items",{}).get(name,{}).get("quantity",0))
		if quantity <= 0 and expired <= 0: continue
		_text("보상 보유: %s × %d" % [name,quantity],UI.GOLD)
		if record.has("source_delete_clock"): _text("원본 아이템 삭제: " + str(record.source_delete_clock),UI.MUTED)
		if expired > 0: _text("삭제 처리된 수량 %d · 수령·사용·소유 이력 보존" % expired,UI.MUTED)
		if quantity <= 0: continue
		var action: Dictionary = live.item_use.spec(record)
		if action.has("error"):
			_text(str(action.error),UI.MUTED)
			continue
		var label: String = "구성품 선택" if action.kind == "select" else "1개 사용 · " + str(action.label)
		var callback: Callable = _choose_owned.bind(name) if action.kind == "select" else _use_owned.bind(name,0)
		var button := _owned_button(label,callback)
		button.name = "MonsterBookUse_%d" % int(record.source_item_class_id)
		if SOURCE_ITEMS.valid_record(name,record):
			_button_item_image(button,record.source_original,name)
		owned_controls[name] = button
		if choice_item == name and action.kind == "select":
			for reward: Dictionary in action.choices:
				var title: String = _description("ItemClass",int(reward.RewardClassID))
				var choice := _owned_button("%s ×%d 선택" % [title,int(reward.Amount)],_use_owned.bind(name,int(reward.ID)))
				choice.name = "MonsterBookChoice_%d" % int(reward.ID)
				if int(reward.get("RewardTypeID",0)) == 2:
					_button_item_image(choice,book_service.row("ItemClass",int(reward.RewardClassID)),title)
	var latest: Array = saved.get("item_actions",{}).get("last_results",[])
	if not latest.is_empty():
		_text("최근 아이템 사용 결과 · " + str(saved.item_actions.get("last_policy","")),UI.GOLD)
		for entry: Dictionary in latest:
			if entry.kind == "card": _text("%s · %s%s" % [str(entry.name),str(entry.get("grade",""))," · 카드 정의 연결 대기(소유 기록 보존)" if not world.card_draw_fusion.known_ids.get(str(entry.get("category","")),{}).has(str(entry.get("identity",""))) else ""])
			elif entry.kind == "points": _text("축복 포인트 +%d" % int(entry.amount))
			else: _text("%s ×%d" % [str(entry.name),int(entry.amount)])

func _choose_owned(name: String) -> void:
	if scroll_host.was_scroll_dragged(stage_scroll): return
	choice_item = name
	show_selected()
	call_deferred("_scroll_owned",name)

func _use_owned(name: String, choice: int) -> void:
	if scroll_host.was_scroll_dragged(stage_scroll): return
	var outcome: Dictionary = world.monsterbook523_runtime.item_use.use(name,choice)
	result.text = str(outcome.message)
	if outcome.ok: choice_item = ""
	show_selected()
	call_deferred("_scroll_owned",name)

func focus_owned_item(name: String) -> void:
	show_selected()
	call_deferred("_scroll_owned",name)

func _scroll_owned(name: String) -> void:
	# Rebuilt controls must complete layout before ScrollContainer can find them.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(owned_controls.get(name)): stage_scroll.ensure_control_visible(owned_controls[name])

func _request(action: String, level_id: int) -> void:
	if scroll_host.was_scroll_dragged(stage_scroll): return
	var outcome: Dictionary = world.call("request_monsterbook_action", action, selected_id, level_id)
	result.text = str(outcome.get("message", "처리를 완료하지 못했습니다."))
	show_selected()
