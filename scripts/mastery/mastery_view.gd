extends PanelContainer
## Native art and the four-color/Slot1/2 placement are not reconstructed here.
var runtime
var body: VBoxContainer
var selected_weapon: int = 0
var target_weapon: int = 0

func _ready() -> void:
	name = "WeaponMastery523"
	position = Vector2(170,95)
	custom_minimum_size = Vector2(540,440)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055,0.045,0.035,0.98)
	panel.border_color = Color(0.65,0.52,0.28)
	panel.set_border_width_all(2)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	add_theme_stylebox_override("panel",panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540,440)
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

func line(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color",Color(0.95,0.91,0.8))
	label.add_theme_font_size_override("font_size",17)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 510
	body.add_child(label)
	return label

func refresh() -> void:
	if body == null: return
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var close := Button.new()
	close.text = "무기 숙련 · 닫기"
	close.pressed.connect(hide)
	body.add_child(close)
	if not runtime.enabled:
		line(runtime.problem)
		return
	var selector := OptionButton.new()
	selector.name = "MasteryWeaponSelect"
	var selected_index: int = 0
	for weapon: int in runtime.core.levels:
		var title: String = runtime.weapon_name(weapon)
		selector.add_item(title,weapon)
		if selected_weapon == weapon: selected_index = selector.item_count-1
	selector.select(selected_index)
	selected_weapon = selector.get_selected_id()
	selector.item_selected.connect(func(index: int) -> void: selected_weapon = selector.get_item_id(index); refresh())
	body.add_child(selector)
	for weapon: int in [selected_weapon]:
		var entry: Dictionary = runtime.core.record(runtime.state,weapon)
		var level: int = runtime.core.achieved_level(weapon,entry.points)
		line("%s · Lv.%d · 숙련치 %s" % [runtime.weapon_name(weapon),level,entry.points])
		if level < 8:
			line("다음 레벨 누적 숙련치 %d" % int(runtime.core.levels[weapon][level].CumulativePoint))
		for option: Dictionary in entry.options:
			var row: Dictionary = runtime.core.options[int(option.group_id)][weapon]
			var bonus: Dictionary = runtime.core.bonuses[int(row.BonusID)]
			var type: Dictionary = runtime.core.types[int(bonus.BonusTypeID)]
			var supported: bool = str(type.Name) in ["MeleeHit","RangeHit","MeleeDamage","RangeDamage","MagicDamage","HPPlus","MPPlus","MagicResist"]
			var status: String = "레벨 미달" if int(row.level) > level else ("적용" if supported else "현재 게임 미적용")
			line("Lv.%d · %s · %s" % [int(row.level),runtime.bonus_text(bonus),status])
		for level_key: String in entry.colors:
			line("Lv.%s 색상" % level_key)
			var locks: Array = entry.locks.get(level_key,[false,false,false,false])
			for slot: int in 4:
				var toggle := CheckButton.new()
				toggle.name = "MasteryLock_%s_%d" % [level_key,slot]
				toggle.text = "색상 %d · %d번 잠금" % [int(entry.colors[level_key][slot]),slot+1]
				toggle.button_pressed = locks[slot]
				toggle.toggled.connect(func(locked: bool) -> void: runtime.set_color_lock(weapon,int(level_key),slot,locked))
				body.add_child(toggle)
		var quote: Dictionary = runtime.core.reset_quote(runtime.state,weapon)
		if not entry.options.is_empty():
			line("재설정 비용: %s %d · 티켓 수 %d" % [runtime.currency_name(int(quote.get("CurrencyID",0))),int(quote.get("Cost",0)),int(quote.get("TicketAmount",0))])
		var reset := Button.new()
		reset.name = "MasteryReset"
		reset.text = "옵션 재설정 · 슬롯 대응 확인 필요"
		reset.disabled = true
		reset.tooltip_text = "원본 Slot1/2와 네 색상 슬롯의 대응이 확인되어야 재추첨·결제할 수 있습니다"
		body.add_child(reset)
	line("목표 무기 옵션 미리보기")
	for purchase: Dictionary in runtime.core.tables.MasteryPointPurchaseView:
		line("원본 숙련치 구매량 %d" % int(purchase.PointAmount))
	for payment: Dictionary in runtime.core.tables.MasteryPointPayment:
		line("구매 %d회: %s %d" % [int(payment.Count),runtime.currency_name(int(payment.CurrencyID)),int(payment.Cost)])
	var buy := Button.new()
	buy.name = "MasteryPointPurchase"
	buy.text = "숙련치 구매 · 원본 재료 연결 확인 필요"
	buy.disabled = true
	buy.tooltip_text = "원본 Currency/ItemClass와 현재 실제 인벤토리의 확정 매핑 및 구매 횟수 초기화 규칙이 필요합니다"
	body.add_child(buy)
	var target := OptionButton.new()
	target.name = "MasteryTransferTarget"
	var class_id: int = runtime.world.BASE508.source_class_id(runtime.world.job_class)
	for row: Dictionary in runtime.core.tables.ClassChangeMasteryWeaponType:
		if int(row.ToCharacterClass) != class_id: continue
		var base: int = int(row.ToWeaponType)
		target.add_item(runtime.weapon_name(base),base)
		if target_weapon == base: target.select(target.item_count-1)
	if target.item_count > 0:
		target_weapon = target.get_selected_id()
		target.item_selected.connect(func(index: int) -> void: target_weapon = target.get_item_id(index); refresh())
		body.add_child(target)
		var owned: Dictionary = runtime.core.record(runtime.state,selected_weapon)
		for option: Dictionary in owned.options:
			var row: Dictionary = runtime.core.options[int(option.group_id)][target_weapon]
			var bonus: Dictionary = runtime.core.bonuses[int(row.BonusID)]
			line("목표 Lv.%d · %s" % [int(row.level),runtime.bonus_text(bonus)]).set_meta("mastery_bonus_type",str(runtime.core.types[int(bonus.BonusTypeID)].Name))
	else:
		target.free()
		line("현재 클래스의 숙련 교체 대상이 없습니다")
	line("교체 후 색상·수치 유지 / 잠금 초기화. 교체에 쓰는 원래 숙련치·옵션은 초기화됩니다.")
	var transfer := Button.new()
	transfer.name = "MasteryTransfer"
	transfer.text = "숙련 교체 · 환산·추가 재화 확인 필요"
	transfer.disabled = true
	transfer.tooltip_text = "서버 점수 환산과 추가 비용 재화가 미확정입니다. 미리보기는 상태를 바꾸지 않습니다"
	body.add_child(transfer)
	line("성장 지급·재설정·교체는 확인된 지급/결제 결과를 저장한 뒤 반영합니다. 색상 슬롯과 옵션의 대응 및 서버 환산식은 미확정입니다.")
