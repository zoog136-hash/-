extends PanelContainer
## Native art and the four-color/Slot1/2 placement are not reconstructed here.
var runtime
var body: VBoxContainer
var selected_weapon: int = 0
var target_weapon: int = 0
var prefix_level: int = 0

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

func operation_button(id: String, title: String, action: String, weapon: int, target: int = 0, prefix: int = 0) -> void:
	var quote: Dictionary = runtime.quote(action,weapon,target,prefix)
	var button := Button.new()
	button.name = id
	button.text = title
	button.disabled = not quote.ok
	if not quote.ok:
		button.tooltip_text = runtime.reason_text(str(quote.reason))
		line(button.tooltip_text)
	else:
		var charge: Dictionary = quote.charge
		var price: String = "%s %d" % [runtime.currency_name(int(charge.CurrencyID)),int(charge.Cost)]
		line("비용: %s · 보유 %d" % [price,runtime.balance(int(charge.CurrencyID))])
		if action == "change": line("기본 %d + 옵션 추가 %d" % [int(charge.BaseCost),int(charge.AdditionalCost)])
		button.pressed.connect(func() -> void:
			var warning: String = ""
			if action == "change": warning = "\n출발 숙련치와 미선택 옵션은 사라집니다. 선택한 범위의 옵션은 목표 옵션을 대체하며 잠금은 초기화됩니다.\n원시 누적 숙련치 합산으로 처리합니다. 이전 저장은 별도로 보존합니다.\n반복 구매 조건 확인 전 이 저장에서 첫 교체만 허용합니다."
			elif action == "reset": warning = "\n확률100%인 기존 값은 유지하고 잠금 없는 네 색상을 재결정합니다."
			else: warning = "\n구매 주기 초기화 시각이 확인되기 전까지 이 저장의 첫 5회만 구매할 수 있습니다."
			runtime.world.hud.confirm_action(title,price+warning,"실행",func(_count: int) -> void:
				var result: Dictionary = runtime.execute(action,weapon,target,prefix,quote.before)
				runtime.world.hud.show_message(title+" 완료" if result.ok else runtime.reason_text(str(result.get("reason","실패"))))))
	body.add_child(button)

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
	selector.item_selected.connect(func(index: int) -> void: selected_weapon = selector.get_item_id(index); target_weapon = 0; prefix_level = 0; refresh())
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
			var supported: bool = str(type.Name) in ["MeleeHit","RangeHit","MeleeDamage","RangeDamage","MagicDamage","HPPlus","MPPlus","MagicResist","AttackSpeedBonus","MeleeCritical","RangeCritical","MagicCritical"]
			var equipped: bool = runtime.core.normalize_weapon(runtime.world._mastery_actual_weapon_type()) == weapon
			var status: String = "레벨 미달" if int(row.level) > level else (("적용" if equipped else "무기 장착 시 적용") if supported else "현재 게임 미적용")
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
		operation_button("MasteryReset","고정 옵션 색상 재설정","reset",weapon)
	line("목표 무기 옵션 미리보기")
	for purchase: Dictionary in runtime.core.tables.MasteryPointPurchaseView:
		line("원본 숙련치 구매량 %d" % int(purchase.PointAmount))
	for payment: Dictionary in runtime.core.tables.MasteryPointPayment:
		line("구매 %d회: %s %d" % [int(payment.Count),runtime.currency_name(int(payment.CurrencyID)),int(payment.Cost)])
	line("확인된 구매 횟수 %d/5 · 초기화 시각 확인 전 자동 초기화 없음" % int(runtime.state.get("purchase_count",0)))
	operation_button("MasteryPointPurchase","숙련치 구매","purchase",selected_weapon)
	var target := OptionButton.new()
	target.name = "MasteryTransferTarget"
	var class_id: int = runtime.world.BASE508.source_class_id(runtime.world.job_class)
	for row: Dictionary in runtime.core.tables.ClassChangeMasteryWeaponType:
		if int(row.ToCharacterClass) != class_id: continue
		var base: int = int(row.ToWeaponType)
		target.add_item(runtime.weapon_name(base),base)
		if target_weapon == base: target.select(target.item_count-1)
		elif target_weapon == 0 and base != selected_weapon: target.select(target.item_count-1)
	if target.item_count > 0:
		target_weapon = target.get_selected_id()
		target.item_selected.connect(func(index: int) -> void: target_weapon = target.get_item_id(index); refresh())
		body.add_child(target)
		var owned: Dictionary = runtime.core.record(runtime.state,selected_weapon)
		var prefix := OptionButton.new()
		prefix.name = "MasteryTransferPrefix"
		prefix.add_item("옵션 제외 · 숙련치만 합산",0)
		var available: int = runtime.core.achieved_level(selected_weapon,owned.points)
		prefix_level = mini(prefix_level,available)
		for level: int in range(1,available+1): prefix.add_item("1~%d레벨 옵션 포함" % level,level)
		prefix.select(prefix_level)
		prefix.item_selected.connect(func(index: int) -> void: prefix_level = prefix.get_item_id(index); refresh())
		body.add_child(prefix)
		for option: Dictionary in owned.options:
			var row: Dictionary = runtime.core.options[int(option.group_id)][target_weapon]
			var bonus: Dictionary = runtime.core.bonuses[int(row.BonusID)]
			line("목표 Lv.%d · %s" % [int(row.level),runtime.bonus_text(bonus)]).set_meta("mastery_bonus_type",str(runtime.core.types[int(bonus.BonusTypeID)].Name))
	else:
		target.free()
		line("현재 클래스의 숙련 교체 대상이 없습니다")
	line("교체 후 색상·수치 유지 / 잠금 초기화. 교체에 쓰는 원래 숙련치·옵션은 초기화됩니다.")
	operation_button("MasteryTransfer","로컬 숙련 교체","change",selected_weapon,target_weapon,prefix_level)
	line("숙련 교체는 원시 누적 숙련치를 그대로 합산합니다. 반복 구매 조건 확인 전 이 저장에서 첫 교체만 허용합니다. 변동 값·잠금 재설정은 네 슬롯 값 대응 확인이 필요합니다.")
