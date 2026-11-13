extends VBoxContainer

const UI = preload("res://scripts/ui/renewal_theme.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var hud: Node
var selected_id := 0
var selected_level := 1
var content: VBoxContainer
var combat_status: Label
var status_clock := 0.0

func _bind_item_icon(button: Button, item_class_id: int, relation: Dictionary) -> void:
	button.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if button.has_meta(key): button.remove_meta(key)
	if not IMAGES.selected(): return
	var source_row: Dictionary = hud.get_parent().totems.row("ItemClass", item_class_id)
	var image_info: Dictionary = IMAGES.describe_item_class_row(source_row) if not source_row.is_empty() else IMAGES.describe_item_class(item_class_id)
	button.icon = image_info.get("texture") as Texture2D
	button.expand_icon = true
	var evidence: Dictionary = image_info.duplicate(true)
	evidence.erase("texture")
	evidence["presentation_relation"] = relation.duplicate(true)
	button.set_meta("source523_image", evidence)
	button.set_meta("source523_image_provenance", image_info.get("provenance", {}).duplicate(true))
	button.set_meta("source523_image_status", str(image_info.get("source_status", image_info.get("reason", ""))))

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(combat_status):return
	status_clock -= delta
	if status_clock > 0:return
	status_clock = 0.1
	combat_status.text = hud.get_parent().totem_combat.active_status(selected_id)

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
	var def: Dictionary = runtime.row("Totem",selected_id)
	# An id outside the installed Totem table (e.g. a stale tap) falls back to
	# the first row instead of reading a column of an empty record.
	if def.is_empty() and not runtime.rows("Totem").is_empty():
		selected_id = int(runtime.rows("Totem")[0].get("ID",0))
		def = runtime.row("Totem",selected_id)
	if def.is_empty():
		content.add_child(UI.label("토템 자료를 설치하면 진행도를 확인할 수 있습니다.",14))
		return
	var p: Dictionary = runtime.progress(selected_id)
	content.add_child(UI.label("%s · Lv.%d · 처치 %d / %d" % ["활성" if p.get("active",false) else "미활성",int(p.get("level",0)),int(p.get("kills",0)),int(def.get("ActivationKillCount",0))],15))
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
			_bind_item_icon(upgrade, material_id, {"source_table":"TotemMaterial","source_field":"ItemClassID","source_id":material.get("ID"),"presentation_role":"growth_material"})
			content.add_child(upgrade)
	else: content.add_child(UI.label("최고 레벨",14))
	var reset_id := selected_id
	var reset_quote: Dictionary = hud.get_parent().totem_actions.quote("reset",reset_id,301694,revision)
	var reset := UI.button("Lv.0 초기화 · 초기화 두루마리 × 1",func() -> void:
		hud.confirm_action("토템 초기화","선택한 토템의 레벨과 성장 옵션을 초기화합니다. 활성화·처치 진행도는 유지하며 재료는 환급되지 않습니다.","초기화",func(_count: int) -> void: hud.totem_action_requested.emit("reset",reset_id,301694,revision)))
	reset.name = "TotemReset_%d" % reset_id
	reset.disabled = not bool(reset_quote.ok)
	reset.tooltip_text = str(reset_quote.get("reason","다이아 결제는 지원하지 않습니다"))
	# The existing action provider registers this exact reset scroll from
	# ItemClass; the Totem ID and reset CurrencyID are separate namespaces.
	_bind_item_icon(reset, 301694, {"source_table":"ItemClass","presentation_role":"totem_reset_item"})
	content.add_child(reset)
	content.add_child(UI.label("TWILIGHT 성장 규칙 · 선택 재료 1종 사용 · 단계별 옵션 보존",12,UI.MUTED))
	var effect_info: Dictionary = {4:"오시리스 추가 물리 피해 · 시야 차단 2~3초",14:"제브레퀴 독 [자체 처리] · 물약 회복률 -15% · 2~3초",24:"포세이돈 흡수 [자체 용량] · 리덕션 +5 · 5초"}
	content.add_child(UI.label("Lv.10 · "+str(effect_info.get(selected_id,"")),12,UI.MUTED))
	combat_status = UI.label(hud.get_parent().totem_combat.active_status(selected_id),12)
	combat_status.name = "TotemCombatStatus"
	combat_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	combat_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(combat_status)
	_add_local_settings()
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
			_bind_item_icon(convert, int(recipe.outputs[0].ItemClassID), {"source_table":"ItemCraftOutputView","source_field":"ItemClassID","source_recipe_id":recipe_id,"presentation_role":"craft_result"})
			content.add_child(convert)
		else:
			for source_id in [3581,65291]:
				var recipe_id := int(recipe.view.ItemCraftID)
				var offer: Dictionary = hud.get_parent().totem_actions.quote("craft",recipe_id,source_id,revision)
				var craft := UI.button("%s로 제작 1회" % runtime.item_name(source_id),func() -> void: hud.totem_action_requested.emit("craft",recipe_id,source_id,revision))
				craft.name = "TotemCraft_%d_%d" % [recipe_id,source_id]
				craft.disabled = not bool(offer.ok)
				craft.tooltip_text = str(offer.get("reason","파편 25개 · 주문서 3장 · 아데나 100만"))
				for material_input: Dictionary in recipe.inputs:
					if int(material_input.ItemClassID) == source_id:
						_bind_item_icon(craft, source_id, {"source_table":"ItemCraftInput","source_field":"ItemClassID","source_recipe_id":recipe_id,"presentation_role":"craft_material"})
						break
				content.add_child(craft)

func _add_local_settings() -> void:
	var combat = hud.get_parent().totem_combat
	content.add_child(UI.label("자체 전투 설정 · 원본 서버 규칙 아님",14))
	content.add_child(UI.label("원본: 독 최대HP 3%·하한 750·상한 950 / 물약 회복률 -15%",12,UI.MUTED))
	content.add_child(UI.label("자체: 매 틱 비율 피해를 상하한에 제한 · 첫 틱은 한 주기 뒤",12,UI.MUTED))
	content.add_child(UI.label("보호막 용량은 자체 추정값 · 실제 최대HP 이하로 제한",12,UI.MUTED))
	var current: Dictionary = combat.settings()
	if current.is_empty() or not combat.policy.error.is_empty():
		content.add_child(UI.label("자체 설정 오류 · 원본에서 확인된 효과만 사용",12))
		return
	var venom := CheckButton.new()
	venom.text = "자체 독 피해 사용"
	venom.name = "TotemVenomEnabled"
	venom.button_pressed = bool(current.venom_enabled)
	content.add_child(venom)
	var interval := SpinBox.new()
	interval.name = "TotemVenomInterval"
	interval.min_value = 0.25
	interval.max_value = 10
	interval.step = 0.25
	interval.prefix = "자체 독 주기"
	interval.suffix = "초"
	interval.value = float(current.venom_interval)
	content.add_child(interval)
	var shield := CheckButton.new()
	shield.text = "자체 보호막 흡수 사용"
	shield.name = "TotemShieldEnabled"
	shield.button_pressed = bool(current.shield_enabled)
	content.add_child(shield)
	var capacity := SpinBox.new()
	capacity.name = "TotemShieldCapacity"
	capacity.min_value = 1
	capacity.max_value = 100000
	capacity.step = 1
	capacity.prefix = "자체 흡수 용량"
	capacity.value = int(current.shield_capacity)
	content.add_child(capacity)
	var token: String = combat.settings_token()
	var apply := UI.button("자체 설정 저장 · 다음 발동부터 적용",func() -> void:
		var next := current.duplicate(true)
		next.venom_enabled = venom.button_pressed
		next.venom_interval = interval.value
		next.shield_enabled = shield.button_pressed
		next.shield_capacity = int(capacity.value)
		var result: Dictionary = combat.apply_settings(next,token)
		if not result.ok:hud.show_message(str(result.reason)))
	apply.name = "TotemLocalSettingsSave"
	apply.disabled = combat.settings_blocked
	content.add_child(apply)
