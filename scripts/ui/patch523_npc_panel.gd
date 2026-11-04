extends CanvasLayer
## The same catalog used by live combat supplies the skill inspector.
var service: RefCounted
var panel: PanelContainer
var selector: OptionButton
var attacks: ItemList
var detail: RichTextLabel
var status: Label
var environment_mode: bool = false
var ids: Array = []
var rows: Array = []
var effect_preview: Button
var effect_settings_status: Label
var preview_sprite: int = 0

func _ready() -> void:
	layer = 120
	var open := Button.new()
	open.name = "BossSkillsButton"
	open.text = "보스 기술"
	open.position = Vector2(18,150)
	open.pressed.connect(func() -> void:
		panel.visible = not panel.visible
		if panel.visible: refresh_npc())
	add_child(open)
	status = Label.new()
	status.position = Vector2(18,190)
	status.add_theme_color_override("font_color",Color("f5d49c"))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	panel = PanelContainer.new()
	panel.name = "BossSkillsPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("171b24ff"); style.border_color = Color("9d8054")
	style.set_border_width_all(2); style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel",style)
	var palette := Theme.new()
	for type: String in ["Label","Button","CheckButton","OptionButton","ItemList"]:
		palette.set_color("font_color",type,Color("eadfc8"))
	palette.set_color("default_color","RichTextLabel",Color("eadfc8"))
	panel.theme = palette
	add_child(panel)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var column := VBoxContainer.new(); column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(column)
	var top := HBoxContainer.new(); column.add_child(top)
	var title := Label.new(); title.text = "보스 기술 · 누적 523"; title.clip_text = true; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(title)
	var close := Button.new(); close.text = "닫기"; close.pressed.connect(panel.hide); top.add_child(close)
	var mode := OptionButton.new(); mode.name = "NpcSourceMode"; mode.add_item("보스 기술"); mode.add_item("지역 NPC 상태"); column.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void:
		environment_mode = index == 1
		fill_selector()
	)
	var combat_toggle := CheckButton.new(); combat_toggle.text = "전투에 해석된 효과만 적용"; combat_toggle.clip_text = true; combat_toggle.button_pressed = service.host_enabled
	combat_toggle.toggled.connect(func(enabled: bool) -> void:
		service.clear()
		service.host_enabled = enabled
	)
	column.add_child(combat_toggle)
	selector = OptionButton.new(); column.add_child(selector)
	selector.fit_to_longest_item = false; selector.clip_text = true
	selector.item_selected.connect(func(_index: int) -> void: refresh_npc())
	var note := Label.new()
	note.text = "전투 적용 시 현재 게임의 시간·범위·명중 규칙을 사용합니다.\nNextAttack 연결은 기존 전투 시계로 진행하며, 원본 AI·미해석 NextSpell·시각효과는 별도로 보류합니다."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	var effect_note := Label.new()
	effect_note.text = "원본 효과 팩 %d종 · 픽셀 해석·합성·기본 속도는 추정 설정입니다.\n명시된 SPR 속도가 있으면 우선하며 전투 시간·피해에는 영향을 주지 않습니다." % service.source_effects.records.size()
	effect_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(effect_note)
	var effect_toggle := CheckButton.new(); effect_toggle.name = "SourceEffectToggle"
	effect_toggle.text = "원본 효과 표시 · 추정 재생"; effect_toggle.button_pressed = service.source_effects.enabled
	effect_toggle.toggled.connect(func(value: bool) -> void:
		service.source_effects.enabled = value; persist_effect_settings())
	column.add_child(effect_toggle)
	var composition := CheckButton.new(); composition.name = "SourceEffectComposition"
	composition.text = "자체 계층 합성 · 동시 시작/1회 재생"; composition.clip_text = true
	composition.button_pressed = service.source_effects.compose_children
	composition.toggled.connect(func(value: bool) -> void:
		service.source_effects.compose_children = value; persist_effect_settings())
	column.add_child(composition)
	var knobs := HBoxContainer.new(); column.add_child(knobs)
	for spec: Array in [["속도", "fallback_fps",1.0,120.0,1.0],["투명도","opacity",0.0,1.0,.1],["크기","visual_scale",.25,2.0,.05]]:
		var stack := VBoxContainer.new(); knobs.add_child(stack)
		var label := Label.new(); label.text = spec[0]; stack.add_child(label)
		var spin := SpinBox.new(); spin.name = "Effect_"+str(spec[1])
		spin.min_value = spec[2]; spin.max_value = spec[3]; spin.step = spec[4]
		spin.value = service.source_effects.get(spec[1]); stack.add_child(spin)
		var property: String = spec[1]
		spin.value_changed.connect(func(value: float) -> void:
			service.source_effects.set(property,value); persist_effect_settings())
	var blend := OptionButton.new(); blend.name = "SourceEffectBlend"
	blend.add_item("추정 가산 합성"); blend.add_item("일반 알파 합성")
	blend.select(0 if service.source_effects.additive else 1)
	blend.item_selected.connect(func(index: int) -> void:
		service.source_effects.additive = index == 0; persist_effect_settings())
	column.add_child(blend)
	effect_preview = Button.new(); effect_preview.name = "SourceEffectPreview"; effect_preview.text = "선택 기술의 원본 효과 미리보기"
	effect_preview.pressed.connect(preview_effect); column.add_child(effect_preview)
	effect_settings_status = Label.new(); effect_settings_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(effect_settings_status)
	attacks = ItemList.new(); attacks.name = "AttackList"; attacks.custom_minimum_size.y = 170; column.add_child(attacks)
	attacks.item_selected.connect(show_attack)
	detail = RichTextLabel.new(); detail.name = "SkillDetails"; detail.bbcode_enabled = false
	detail.custom_minimum_size.y = 200; detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	panel.hide()
	fill_selector()

func _process(_delta: float) -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(900,size.x-24),minf(650,size.y-24))
	panel.position = (size-panel.size)*.5
	var lines: PackedStringArray = []
	for buff: Dictionary in service.player_buffs.values():
		lines.append("%s · %.1f초" % [service.catalog.row("BuffClass",int(buff.id)).get("Name","상태"),float(buff.remaining)])
	status.text = "\n".join(lines)

func fill_selector() -> void:
	selector.clear()
	ids = []
	for source_id: Variant in service.catalog.content.get("boss_npc_ids",[]): ids.append(int(source_id))
	if environment_mode:
		ids.clear()
		for entry: Dictionary in service.catalog.content.tables.get("LandAttribute",{}).values():
			var id: int = int(entry.row.LandID)
			if not ids.has(id): ids.append(id)
		ids.sort()
	for id: Variant in ids:
		selector.add_item(str(service.catalog.row("Land" if environment_mode else "NpcClass",int(id)).get("Name",id)))
	refresh_npc()

func refresh_npc() -> void:
	if selector == null or ids.is_empty(): return
	attacks.clear()
	if environment_mode:
		rows = service.catalog.environment_buffs(int(ids[maxi(0,selector.selected)]))
		for binding: Dictionary in rows: attacks.add_item(str(binding.buff.source.get("Name","NPC 상태")) + " · 범위·적용 조건 확인 필요")
		if not rows.is_empty(): attacks.select(0); show_attack(0)
		return
	rows = service.catalog.owned("NpcAttack",int(ids[maxi(0,selector.selected)]))
	for attack: Dictionary in rows:
		var spell: Dictionary = service.catalog.row("SpellClass",int(attack.get("SpellID",0)))
		attacks.add_item(str(spell.get("Name","기본 공격")) + " · " + service.support_reason(attack))
	if not rows.is_empty(): attacks.select(0); show_attack(0)

func append_chain(chain: Dictionary, lines: PackedStringArray, depth: int = 0) -> PackedStringArray:
	if not chain.has("source"): lines.append("후속 연결: " + str(chain.get("pending","미확인"))); return lines
	var spell: Dictionary = chain.source
	lines.append(("후속 기술: " if depth > 0 else "기술: ") + str(spell.Name))
	for edge: Dictionary in chain.get("bonuses",[]):
		lines.append("  %s: %s (%s)" % [edge.type.get("Name","미확인"),str(edge.bonus.get("Value","?")),edge.unit.get("Name","단위 미확인")])
		if int(edge.bonus.get("BonusApplicationTypeID",0)) != 0:
			lines.append("  적용 조건: %s / 대상: %s" % [str(edge.bonus.BonusApplicationTypeID),str(edge.bonus.BonusApplicationTargetID)])
		if edge.type.get("Name") == "BuffClassID":
			var buff: Dictionary = service.catalog.buff_details(int(edge.bonus.Value))
			lines.append("상태: " + str(buff.source.get("Name","미확인")))
			if not buff.group.is_empty(): lines.append("공유 그룹 %s · 중첩 %s · 우선순위 규칙 %s" % [str(buff.group.ID),str(buff.group.get("IsAllowOverlap",false)),str(buff.group.get("IsAllowPriority",false))])
			for bonus: Dictionary in buff.bonuses:
				lines.append("  %s: %s" % [bonus.type.get("Name","미확인"),str(bonus.bonus.get("Value","?"))])
			for invoke: Dictionary in buff.invokes:
				lines.append("  방어반응: 유형 %s / 주문 여부 %s · 최종식 해석 대기" % [str(invoke.source.get("AttackTypeID","?")),str(invoke.source.get("BySpellAttack","?"))])
			for state: Dictionary in buff.statuses:
				lines.append("  상태 표시 ID %s · 속성 %s" % [str(state.id),str(state.attributes)])
	for field: String in ["CasterEffectSpriteID","EffectSpriteID","EffectExplosionSpriteID","SuccessEffectSpriteID","FailEffectSpriteID"]:
		if int(spell.get(field,0)) > 0: lines.append("%s: %s" % [field,str(spell[field])])
	for next: Dictionary in chain.get("next",[]): lines = append_chain(next.spell,lines,depth+1)
	return lines

func show_attack(index: int) -> void:
	if index < 0 or index >= rows.size(): return
	attacks.ensure_current_is_visible()
	var attack: Dictionary = rows[index]
	preview_sprite = 0; effect_preview.disabled = true
	if environment_mode:
		var environment_lines: PackedStringArray = [str(attack.buff.source.get("Name","NPC 상태")),"영역 %s · %s" % [str(attack.attribute.TerritoryID),str(attack.territory.get("Name","랜드 전체 조건"))],"방어 반응 조건 · 최종 수식/적용 시점은 해석 대기"]
		for invoke: Dictionary in attack.buff.invokes:
			var kind: Dictionary = service.catalog.row("AttackType",int(invoke.source.get("AttackTypeID",0)))
			environment_lines.append("%s · 주문 여부 %s · 원문 부여값 %s" % [str(kind.get("Name",invoke.source.get("AttackTypeID",0))),str(invoke.source.get("BySpellAttack",false)),str(invoke.edge.bonus.get("Value",0))])
		for bonus: Dictionary in attack.buff.bonuses:
			if bonus.type.get("Name") != "InvokeOption": environment_lines.append("%s: %s (%s)" % [str(bonus.type.get("Name","미확인")),str(bonus.bonus.get("Value",0)),str(bonus.unit.get("Name","단위 미확인"))])
		environment_lines.append("Territory 범위와 입퇴장 처리가 확인될 때까지 자동 부여하지 않습니다.")
		detail.text = "\n".join(environment_lines)
		return
	var lines: PackedStringArray = [service.support_reason(attack)]
	var npc_id: int = int(ids[maxi(0,selector.selected)])
	lines.append("AI 원문 ID: %d · 호스트 공격 그래프 시작점 %d개" % [int(service.catalog.ai_evidence(npc_id).native_ai_id_raw),service.catalog.attack_roots(npc_id).size()])
	if bool(attack.get("IsSpell",false)):
		var spell: Dictionary = service.catalog.row("SpellClass",int(attack.SpellID))
		preview_sprite = service.source_effects.first_sprite(spell)
		effect_preview.disabled = preview_sprite <= 0
		lines = append_chain(service.catalog.spell_chain(int(attack.SpellID)),lines)
	else: lines.append("원문 기본 공격: %s + %sd%s" % [str(attack.get("DiceBonus",0)),str(attack.get("DiceCount",0)),str(attack.get("DiceSpots",0))])
	var chain: Dictionary = service.catalog.attack_chain(npc_id,int(attack.ID))
	while chain.has("next"):
		chain = chain.next
		if chain.has("source"):
			lines.append("NextAttack → %d · %s" % [int(chain.source.ID),service.support_reason(chain.source)])
		else: lines.append("NextAttack → %d · %s" % [int(chain.get("id",0)),str(chain.get("pending","미확인"))])
	lines.append("실행 중인 게임 전투 규칙을 사용하며, 원본의 미확인 확률·시간·범위·후속 발동은 별도입니다.")
	detail.text = "\n".join(lines)

func persist_effect_settings() -> void:
	if effect_settings_status == null: return
	var result: Error = service.source_effects.save_settings()
	effect_settings_status.text = "효과 설정 저장됨 · 성장/재화 저장과 별도" if result == OK else "효과 설정 저장 실패 · 현재 세션에만 적용"

func preview_effect() -> void:
	if preview_sprite <= 0: return
	if not service.source_effects.enabled:
		effect_settings_status.text = "추정 재생을 켜면 확인한 원본 프레임을 표시합니다."; return
	if service.effects.size() >= 16: return
	var effect: Node2D = service.source_effects.make_effect(preview_sprite,0,service.remaining_effect_bytes())
	if effect == null:
		effect_settings_status.text = "계층 합성 설정·효과 메모리 한도·원본 팩 파일을 확인하세요."; return
	service.world.player.add_child(effect)
	effect.global_position = service.world.player.global_position
	service.effects.append(effect)
	effect_settings_status.text = "원본 효과 %d · 추정 재생 중" % preview_sprite
	panel.hide()
