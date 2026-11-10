extends PanelContainer
## Original field placement confirmed by the official guide; native art stays private.
const SourceImages = preload("res://scripts/ui/source523_image_assets.gd")
var runtime
var body: VBoxContainer
var selected_weapon: int = 0
var target_weapon: int = 0
var prefix_level: int = 0
var progress_label: Label
var displayed_level: int = -1
var reset_payment: String = ""

func _payment_missing(reason: String, source: Dictionary) -> Dictionary:
	return {"status":"source_missing","source_status":reason,"reason":reason,"texture":null,"provenance":{},"payment_source":source}

func _ticket_image() -> Dictionary:
	if not SourceImages.selected(): return {}
	var definition: Dictionary = runtime.reset_ticket.definition
	var source: Dictionary = {"source_table":"Currency","source_id":1814,"source_field":"ID","related_table":"CurrencyUnitClass","related_field":"ClassID"}
	if definition.is_empty() or definition.get("currency", {}).get("ID") != 1814:
		return _payment_missing("source_mastery_ticket_definition_missing", source)
	var item: Dictionary = definition.get("item", {})
	var image: Dictionary = SourceImages.describe_item_class_row(item)
	image["payment_source"] = {"source_table":"ItemClass","source_id":item.get("ID"),"source_field":"IconID","currency_id":definition.currency.ID,"currency_link_id":definition.get("currency_link", {}).get("ID"),"currency_link_field":"ClassID","definition_sha256":runtime.reset_ticket.fingerprint}
	return image

func _charge_image(charge: Dictionary) -> Dictionary:
	if not SourceImages.selected(): return {}
	var value: Variant = charge.get("CurrencyID")
	var source: Dictionary = {"source_table":"Currency","source_id":value,"source_field":"AssetID"}
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floor(float(value)) or float(value) < 0:
		return _payment_missing("source_currency_identity_required", source)
	var currency_id: int = int(value)
	if currency_id == 1814: return _ticket_image()
	if currency_id == 1682:
		# _wallet uses this exact source material, not CurrencyID as ItemClass.ID.
		var material: Dictionary = runtime.core.operations.get("point_purchase", {}).get("material", {})
		var material_image: Dictionary = SourceImages.describe_item_class_row(material)
		material_image["payment_source"] = {"source_table":"ItemClass","source_id":material.get("ID"),"source_field":"IconID","currency_id":currency_id,"supplier":"core.operations.point_purchase.material"}
		return material_image
	if currency_id == 0: return _payment_missing("zero_sentinel", source)
	var row: Dictionary = runtime.core.find_row("Currency", currency_id)
	if row.is_empty(): return _payment_missing("source_currency_row_missing", source)
	if not row.has("AssetID"): return _payment_missing("source_currency_asset_field_missing", source)
	var currency_image: Dictionary = SourceImages.resolve_asset_value(row.AssetID)
	currency_image["payment_source"] = source
	return currency_image

func _payment_evidence(image: Dictionary) -> Dictionary:
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	return evidence

func _bind_payment_button(button: Button, image: Dictionary) -> void:
	button.icon = null
	for key: String in ["source523_image", "source523_image_status"]:
		if button.has_meta(key): button.remove_meta(key)
	if not SourceImages.selected() or image.is_empty(): return
	button.icon = image.get("texture") as Texture2D
	button.expand_icon = true
	button.set_meta("source523_image", _payment_evidence(image))
	button.set_meta("source523_image_status", str(image.get("source_status", image.get("status", image.get("reason", "")))))

func _bind_payment_option(choice: OptionButton, index: int, image: Dictionary) -> void:
	choice.set_item_icon(index, null)
	var images: Dictionary = choice.get_meta("source523_images", {}).duplicate(true)
	images.erase(index)
	if SourceImages.selected() and not image.is_empty():
		choice.set_item_icon(index, image.get("texture") as Texture2D)
		images[index] = _payment_evidence(image)
	if images.is_empty():
		if choice.has_meta("source523_images"): choice.remove_meta("source523_images")
	else: choice.set_meta("source523_images", images)

func update_progress() -> void:
	if not is_instance_valid(progress_label) or not runtime.core.levels.has(selected_weapon): return
	var entry: Dictionary = runtime.core.record(runtime.state,selected_weapon)
	var level: int = runtime.core.achieved_level(selected_weapon,entry.points)
	progress_label.text = "%s · Lv.%d · 숙련치 %s" % [runtime.weapon_name(selected_weapon),level,entry.points]
	if level != displayed_level:
		displayed_level = level
		call_deferred("refresh")

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

func operation_button(id: String, title: String, action: String, weapon: int, target: int = 0, prefix: int = 0, payment: String = "currency") -> void:
	var quote: Dictionary = runtime.quote(action,weapon,target,prefix,payment)
	var button := Button.new()
	button.name = id
	button.text = title
	button.disabled = not quote.ok
	if not quote.ok:
		button.tooltip_text = runtime.reason_text(str(quote.reason))
		line(button.tooltip_text)
	else:
		var charge: Dictionary = quote.charge
		var payment_image: Dictionary = _charge_image(charge)
		_bind_payment_button(button, payment_image)
		var price: String = "%s %d" % [runtime.currency_name(int(charge.CurrencyID)),int(charge.Cost)]
		line("비용: %s · 보유 %d" % [price,runtime.balance(int(charge.CurrencyID))])
		if action == "reset" and not quote.frozen_levels.is_empty(): line("자체 범위: 부분 보유 레벨 %s는 보존하고, 완전한 보유 레벨만 변경합니다" % str(quote.frozen_levels))
		button.pressed.connect(func() -> void:
			var warning: String = ""
			if action == "reset": warning = "\n잠기지 않은 종류·수치 슬롯의 색상과 수치를 원본 확률로 재결정합니다. 수치 슬롯을 잠그면 해당 옵션 수치도 보존합니다."
			elif action == "acquire": warning = "\n두 옵션 수치와 네 색상을 추첨합니다. 최초 획득 비용은 자체 설정입니다."
			elif action == "repair": warning = "\n자체 복구: 원본 결과가 하나로 확정되는 누락 값만 복원합니다. 기존 수치·색상·잠금은 바꾸거나 재추첨하지 않습니다. 기존 저장을 별도로 보존합니다."
			else: warning = "\n무기 통합 하루 5회. 로컬 초기화 시각은 자체 설정입니다."
			if action == "reset" and not quote.frozen_levels.is_empty(): warning += "\n자체 범위: 부분 보유 레벨 %s는 재추첨하지 않습니다. 변경 대상의 잠금 수로 원본 비용을 계산합니다." % str(quote.frozen_levels)
			var dialog = runtime.world.hud.confirm_action(title,price+warning,"실행",func(_count: int) -> void:
				var result: Dictionary = runtime.execute(action,weapon,target,prefix,quote.before,payment)
				runtime.world.hud.show_message(title+" 완료" if result.ok else runtime.reason_text(str(result.get("reason","실패")))))
			var confirm_button: Variant = dialog.get("confirm_button") if is_instance_valid(dialog) else null
			if confirm_button is Button: _bind_payment_button(confirm_button, payment_image))
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
	if not runtime.balance_error.is_empty():
		line(runtime.balance_error)
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
		progress_label = line("%s · Lv.%d · 숙련치 %s" % [runtime.weapon_name(weapon),level,entry.points])
		displayed_level = level
		if level < 8:
			line("다음 레벨 누적 숙련치 %d" % int(runtime.core.levels[weapon][level].CumulativePoint))
		var partial: Dictionary = runtime.core.partial_status(runtime.state,weapon)
		if not partial.frozen.is_empty():
			line("부분 보유 레벨 %s · 확인되지 않은 값과 색상은 보존합니다" % str(partial.frozen)).set_meta("mastery_partial_state",true)
			for repair: Dictionary in partial.repairs: line("자체 복구 가능: Lv.%d 옵션%d · 원본 고정 결과" % [int(repair.level),int(repair.slot)])
			operation_button("MasteryRepair","부분 옵션 복구","repair",weapon)
		for claim_level: int in range(1,level+1):
			if runtime.core._owned_slots(entry,weapon,claim_level).is_empty() and not entry.colors.has(str(claim_level)):
				operation_button("MasteryAcquire_%d" % claim_level,"Lv.%d 옵션 획득" % claim_level,"acquire",weapon,0,claim_level)
		for option: Dictionary in entry.options:
			var row: Dictionary = runtime.core.options[int(option.group_id)][weapon]
			var bonus: Dictionary = runtime.core.bonuses[int(row.BonusID)]
			var type: Dictionary = runtime.core.types[int(bonus.BonusTypeID)]
			var supported: bool = runtime.effect_supported(str(type.Name))
			var equipped: bool = runtime.core.normalize_weapon(runtime.world._mastery_actual_weapon_type()) == weapon
			var status: String = "레벨 미달" if int(row.level) > level else (("적용" if equipped else "무기 장착 시 적용") if supported else "현재 게임 미적용")
			line("Lv.%d · %s · %s%s" % [int(row.level),runtime.bonus_text(bonus),status,runtime.application_note(str(type.Name))])
		for level_key: String in entry.colors:
			line("Lv.%s 색상" % level_key)
			var colors: Array = entry.colors[level_key]
			if colors[0] == colors[1] and colors[0] == colors[2] and colors[0] == colors[3]:
				var matching: Dictionary = runtime.core.matching_bonus(weapon,int(colors[0]))
				var status: String = "옵션 일부만 보유" if runtime.core._owned_slots(entry,weapon,int(level_key)).size() != 2 else ("레벨 미달" if int(level_key) > level else ("적용" if runtime.core.normalize_weapon(runtime.world._mastery_actual_weapon_type()) == weapon else "무기 장착 시 적용"))
				if not matching.is_empty(): line("%s 매칭 · %s · %s" % [runtime.grade_name(int(colors[0])),runtime.bonus_text(matching),status]).set_meta("mastery_matching_level",int(level_key))
			var locks: Array = entry.locks.get(level_key,[false,false,false,false])
			for slot: int in 4:
				var toggle := CheckButton.new()
				toggle.name = "MasteryLock_%s_%d" % [level_key,slot]
				toggle.text = "%s · %s · 잠금" % [["옵션1 종류","옵션1 수치","옵션2 종류","옵션2 수치"][slot],runtime.grade_name(int(entry.colors[level_key][slot]))]
				toggle.add_theme_color_override("font_color",{2:Color.LIME_GREEN,3:Color.DEEP_SKY_BLUE,4:Color.TOMATO,5:Color.MEDIUM_ORCHID}.get(int(entry.colors[level_key][slot]),Color.WHITE))
				toggle.button_pressed = locks[slot]
				toggle.toggled.connect(func(locked: bool) -> void: runtime.set_color_lock(weapon,int(level_key),slot,locked))
				body.add_child(toggle)
		var quote: Dictionary = runtime.core.reroll_availability(runtime.state,weapon,str(runtime.balance_config.partial_reroll))
		if quote.ok: line("재설정 대상의 잠금 %d칸 · 원본 비용 기준" % int(quote.charge.LockSlotCount))
		if reset_payment.is_empty(): reset_payment = str(runtime.balance_config.reset_payment_default)
		var payment := OptionButton.new()
		payment.name = "MasteryResetPayment"
		payment.expand_icon = true
		payment.add_item("재화로 지불 · 원본 아데나/다이아",0)
		payment.add_item("숙련 옵션 변경 티켓으로 지불",1)
		var currency_charge: Variant = quote.get("charge")
		_bind_payment_option(payment, 0, _charge_image(currency_charge) if currency_charge is Dictionary and currency_charge.has("CurrencyID") else {})
		_bind_payment_option(payment, 1, _ticket_image() if not runtime.reset_ticket.definition.is_empty() else {})
		payment.select(1 if reset_payment == "ticket" else 0)
		payment.item_selected.connect(func(index: int) -> void: reset_payment = "ticket" if index == 1 else "currency"; refresh())
		body.add_child(payment)
		line("선택한 수단 하나만 소모합니다. 부족해도 다른 재화로 자동 전환하지 않습니다.")
		operation_button("MasteryReset","숙련 옵션 재설정","reset",weapon,0,0,reset_payment)
	line("목표 무기 옵션 미리보기")
	for purchase: Dictionary in runtime.core.tables.MasteryPointPurchaseView:
		line("원본 숙련치 구매량 %d" % int(purchase.PointAmount))
	for payment: Dictionary in runtime.core.tables.MasteryPointPayment:
		line("구매 %d회: %s %d" % [int(payment.Count),runtime.currency_name(int(payment.CurrencyID)),int(payment.Cost)])
	var usage: Dictionary = runtime.core.purchase_usage(runtime.state,runtime.purchase_period())
	line("오늘 구매 %d/5 · 총 구매 %d회" % [int(usage.count),int(runtime.state.get("purchase_count",0))])
	line("자체 설정: 일반 명중당 %d점 · 일일 기준 UTC%+d %02d시 · 최초 옵션 비용 %d" % [int(runtime.balance_config.get("normal_hit_points",0)),int(runtime.balance_config.get("purchase_day_utc_offset_hours",9)),int(runtime.balance_config.get("purchase_day_reset_hour",5)),int(runtime.balance_config.get("acquire_cost",0))])
	operation_button("MasteryPointPurchase","숙련치 구매","purchase",selected_weapon)
	line("구매·수치·색상 가중치·재설정·교체 비용은 원본을 사용합니다. 색상 추첨 방식은 자체 설정이며 원작과의 동일성은 미확인입니다.")
