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
	var preview: Dictionary = runtime.level_preview(selected_id,selected_level)
	content.add_child(UI.label("성장 재료",14))
	for material: Dictionary in preview.materials:
		content.add_child(UI.label("%s × %d" % [runtime.item_name(int(material.ItemClassID)),int(material.Amount)],12))
	content.add_child(UI.label("재료 대체와 강화 절차 확인 전에는 재료가 소모되지 않습니다.",12,UI.MUTED))
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
	var disabled := UI.button("강화 절차 확인 대기",func() -> void: pass)
	disabled.disabled = true
	content.add_child(disabled)
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
	content.add_child(UI.label("제작 재료 안내 · 제작 실행 연결 대기",12,UI.MUTED))
