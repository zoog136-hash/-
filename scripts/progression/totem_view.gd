extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
var hud: Node
var selected_id := 0
var selected_level := 1
var content: VBoxContainer

func configure(owner_hud: Node) -> void:
	hud = owner_hud
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var runtime = hud.get_parent().totems
	if not runtime.available():
		add_child(UI.label("토템 자료를 설치하면 진행도를 확인할 수 있습니다.",14))
		return
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for def: Dictionary in runtime.rows("Totem"):
		var id := int(def.ID)
		if selected_id == 0: selected_id = id
		tabs.add_child(UI.button(runtime.description(int(def.DescID)),func() -> void:
			selected_id = id
			_refresh()))
	var selector := OptionButton.new()
	for level in range(1,11): selector.add_item("Lv.%d 성장 정보" % level)
	selector.item_selected.connect(func(index: int) -> void:
		selected_level = index+1
		_refresh())
	add_child(selector)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 280
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	_refresh()

func _refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var runtime = hud.get_parent().totems
	var p: Dictionary = runtime.progress(selected_id)
	var def: Dictionary = runtime.row("Totem",selected_id)
	content.add_child(UI.label("%s · Lv.%d · 처치 %d / %d" % ["활성" if p.active else "미활성",int(p.level),int(p.kills),int(def.ActivationKillCount)],15))
	content.add_child(UI.label("공명 · 총 Lv.%d · 대미지 리덕션 무시 %.1f%%" % [runtime.resonance().total_level,100.0*runtime.resonance().pierce_reduction_fraction],13))
	content.add_child(UI.label("현재 지역 경험치 보너스 +%.1f%%" % (100.0*hud.get_parent().totem_map_experience()),12))
	content.add_child(UI.label("적용 옵션 · AC -%d · MR +%d · 리덕션 +%d" % [runtime.bonus("ArmorClass"),runtime.bonus("MagicResist"),runtime.bonus("DamageReduction")],12))
	var acquired: Dictionary = {}
	for stage: Dictionary in p.selected.values():
		for bonus_id: Variant in stage.values():
			var effect: Dictionary = runtime.typed_bonus(int(bonus_id))
			var key := str(effect.type.Name)
			if not acquired.has(key): acquired[key] = effect
			else: acquired[key].bonus.Value = int(acquired[key].bonus.Value)+int(effect.bonus.Value)
	var acquired_text := PackedStringArray()
	for key: String in acquired:
		var effect: Dictionary = acquired[key]
		var scalar := float(effect.bonus.Value)
		var denominator := float(effect.ui_unit.get("Denominator",0))
		if denominator > 0: scalar /= denominator
		if key == "ArmorClass": scalar = -scalar
		acquired_text.append("%s %.2f%s" % [runtime.description(int(effect.type.DescID)),scalar,"%" if int(effect.type.UnitID) == 3 else ""])
	var acquired_label := UI.label("획득 옵션 · "+(" · ".join(acquired_text) if not acquired_text.is_empty() else "없음"),12)
	acquired_label.name = "TotemAcquiredOptions"
	acquired_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(acquired_label)
	var preview: Dictionary = runtime.level_preview(selected_id,selected_level)
	content.add_child(UI.label("성장 재료",14))
	for material: Dictionary in preview.materials:
		content.add_child(UI.label("%s × %d" % [runtime.item_name(int(material.ItemClassID)),int(material.Amount)],12))
	content.add_child(UI.label("성장 정보는 미리보기입니다. 실제 강화는 현재 레벨의 다음 단계에 도전합니다.",12,UI.MUTED))
	content.add_child(UI.label("슬롯별 옵션 후보",14))
	var pool_number := 0
	for slot: String in preview.option_pools:
		pool_number += 1
		content.add_child(UI.label("옵션 후보군 %d" % pool_number,13,UI.MUTED))
		var total := 0
		for candidate: Dictionary in preview.option_pools[slot]: total += int(candidate.source.Probability)
		for candidate: Dictionary in preview.option_pools[slot]:
			var bonus: Dictionary = candidate.bonus
			var scalar := float(bonus.bonus.Value)
			var denominator := float(bonus.ui_unit.get("Denominator",0))
			var suffix := ""
			if denominator > 0:
				scalar /= denominator
				suffix = "%" if str(bonus.type.get("Name","")).contains("Percent") or int(bonus.type.get("UnitID",0)) == 3 else ""
			content.add_child(UI.label("%s %.2f%s · 후보 비중 %.1f%%" % [runtime.description(int(bonus.type.get("DescID",0))),scalar,suffix,100.0*float(candidate.source.Probability)/float(total)],12))
	var revision: int = runtime.revision
	if int(p.level) < 10:
		var next: Dictionary = runtime.level_preview(selected_id,int(p.level)+1)
		content.add_child(UI.label("다음 성장 Lv.%d · 성공 확률 %.1f%%" % [int(p.level)+1,100.0*float(next.success_fraction)],14))
		for material: Dictionary in next.materials:
			var material_id := int(material.ItemClassID)
			var id := selected_id
			var offer: Dictionary = hud.get_parent().totem_actions.quote("upgrade",id,material_id,revision)
			var upgrade := UI.button("%s × %d로 강화" % [runtime.item_name(material_id),int(material.Amount)],func() -> void: hud.totem_action_requested.emit("upgrade",id,material_id,revision))
			upgrade.name = "TotemUpgrade_%d_%d" % [id,material_id]
			upgrade.disabled = not bool(offer.ok)
			upgrade.tooltip_text = str(offer.get("reason","선택한 강화석만 소모 · 실패 시 레벨·옵션 유지"))
			content.add_child(upgrade)
	else: content.add_child(UI.label("최고 레벨",14))
	var reset_id := selected_id
	var reset_quote: Dictionary = hud.get_parent().totem_actions.quote("reset",reset_id,301694,revision)
	var reset := UI.button("Lv.0 초기화 · 초기화 두루마리 × 1",func() -> void:
		hud.confirm_action("토템 초기화","선택한 토템의 레벨과 성장 옵션을 초기화합니다. 활성화·처치 진행도는 유지하며 재료는 환급되지 않습니다.","초기화",func(_count: int) -> void: hud.totem_action_requested.emit("reset",reset_id,301694,revision)))
	reset.name = "TotemReset_%d" % reset_id
	reset.disabled = not bool(reset_quote.ok)
	reset.tooltip_text = str(reset_quote.get("reason","다이아 결제는 지원하지 않습니다"))
	content.add_child(reset)
	content.add_child(UI.label("TWILIGHT 성장 규칙 · 선택 재료 1종 사용 · 단계별 옵션 보존",12,UI.MUTED))
	content.add_child(UI.label("Lv.10 일부 효과 적용 · 시야 감소·독 주기·보호막 흡수량은 미지원",12,UI.MUTED))
	content.add_child(UI.label("강화석 제작 정보",14))
	var stone_ids: Array = []
	for material: Dictionary in preview.materials: stone_ids.append(int(material.ItemClassID))
	for recipe: Dictionary in runtime.recipes():
		if not stone_ids.has(int(recipe.view.ItemClassID)): continue
		content.add_child(UI.label("%s × %d" % [runtime.item_name(int(recipe.view.ItemClassID)),int(recipe.view.Amount)],13))
		var slots: Dictionary = {}
		for input: Dictionary in recipe.inputs:
			var slot := str(int(input.SlotIndex))
			if not slots.has(slot): slots[slot] = []
			slots[slot].append("%s × %d" % [runtime.item_name(int(input.ItemClassID)),int(input.Amount)])
		for choices: Array in slots.values():
			content.add_child(UI.label(" / ".join(PackedStringArray(choices)),12))
		if recipe.inputs.size() == 1 and recipe.outputs.size() == 1:
			var recipe_id := int(recipe.view.ItemCraftID)
			var quote: Dictionary = hud.get_parent().totem_conversion_quote(recipe_id)
			var convert := UI.button("각인 강화석으로 전환 × 1",func() -> void: hud.totem_conversion_requested.emit(recipe_id))
			convert.name = "TotemConvert_%d" % recipe_id
			convert.disabled = not bool(quote.ok)
			convert.tooltip_text = str(quote.get("reason","일반 강화석 1개 소모"))
			content.add_child(convert)
		else:
			for source_id in [3581,65291]:
				var recipe_id := int(recipe.view.ItemCraftID)
				var offer: Dictionary = hud.get_parent().totem_actions.quote("craft",recipe_id,source_id,revision)
				var craft := UI.button("%s로 제작 1회" % runtime.item_name(source_id),func() -> void: hud.totem_action_requested.emit("craft",recipe_id,source_id,revision))
				craft.name = "TotemCraft_%d_%d" % [recipe_id,source_id]
				craft.disabled = not bool(offer.ok)
				craft.tooltip_text = str(offer.get("reason","파편 25개 · 주문서 3장 · 아데나 100만"))
				content.add_child(craft)
