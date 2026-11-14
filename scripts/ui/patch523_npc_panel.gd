extends CanvasLayer
## The same catalog used by live combat supplies the skill inspector.
const SKILL_BUFF_IMAGES = preload("res://scripts/ui/source523_skill_buff_images.gd")
const SourceImages = preload("res://scripts/ui/source523_image_assets.gd")
const NpcImages = preload("res://scripts/ui/source523_npc_images.gd")
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
var preview_action: int = 0
var effect_choices: OptionButton
var effect_action: OptionButton
var effect_choice_ids: Array[int] = [0]
var compat_status: Label
var extension_status: Label
var remaining_buff_ids: Array[int] = []
var remaining_buff_choice: OptionButton
var remaining_status: Label
var _open_button: Button

## The button sits on layer 120 above the HUD; hide it (and its status line)
## while an original 523 window is open so it does not cover that window.
func _hide_under_original_window() -> void:
	if not is_instance_valid(_open_button): return
	var covered: bool = false
	var hud: Node = get_parent().get_node_or_null("HUD") if get_parent() != null else null
	if hud != null:
		var controller = hud.get("original_main_ui_controller")
		if is_instance_valid(controller) and controller.has_method("any_window_open"):
			covered = bool(controller.any_window_open())
	if _open_button.visible == covered:
		_open_button.visible = not covered
		status.visible = not covered

func _ready() -> void:
	layer = 120
	# The world stops processing while an original window is open; this
	# check must keep running to hide the button over that window.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var open := Button.new()
	open.name = "BossSkillsButton"
	open.text = "보스 기술"
	open.position = Vector2(18,150)
	open.pressed.connect(func() -> void:
		panel.visible = not panel.visible
		if panel.visible: refresh_npc())
	add_child(open)
	_open_button = open
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
	var scroll := ScrollContainer.new(); scroll.name = "BossSkillsScroll"; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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
	var combat_toggle := CheckButton.new(); combat_toggle.name = "BossCombatToggle"; combat_toggle.text = "전투에 해석된 효과만 적용"; combat_toggle.clip_text = true; combat_toggle.button_pressed = service.host_enabled
	combat_toggle.toggled.connect(func(enabled: bool) -> void:
		service.clear()
		service.host_enabled = enabled
	)
	column.add_child(combat_toggle)
	selector = OptionButton.new(); column.add_child(selector)
	selector.fit_to_longest_item = false; selector.clip_text = true
	selector.item_selected.connect(func(_index: int) -> void: refresh_npc())
	var note := Label.new()
	note.text = "전투 적용 시 현재 게임의 시간·범위·명중 규칙을 사용합니다.\nNextAttack은 기존 시계로 진행합니다. 일부 NextSpell·지면·소환은 아래 자체 규칙을 별도로 켜면 실행합니다."
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
	var direction_row := HBoxContainer.new(); column.add_child(direction_row)
	var direction_label := Label.new(); direction_label.text = "원문 그룹/방향(추정)"; direction_row.add_child(direction_label)
	var direction := SpinBox.new(); direction.name = "SourceEffectDirection"; direction.min_value = 0; direction.max_value = 7; direction.step = 1; direction.value = service.source_effects.source_direction; direction_row.add_child(direction)
	direction.value_changed.connect(func(value: float) -> void:
		service.source_effects.source_direction = int(value); persist_effect_settings())
	for spec: Array in [["호스트 방향 연동 · 물리 대응은 추정","follow_host_facing"],["단일 명시 액션 자동 선택 · 발동은 추정","single_action_fallback"]]:
		var toggle := CheckButton.new(); toggle.name = "SourceEffect_"+str(spec[1]); toggle.text = spec[0]; toggle.clip_text = true
		toggle.button_pressed = service.source_effects.get(spec[1]); column.add_child(toggle)
		var property: String = spec[1]
		toggle.toggled.connect(func(value: bool) -> void:
			service.source_effects.set(property,value); persist_effect_settings())
	effect_choices = OptionButton.new(); effect_choices.name = "SourceEffectChoice"
	effect_choices.add_item("효과 원문 검토 · 전투 발동과 별도")
	var source_ids: Array[int] = []
	for key: String in service.source_effects.records: source_ids.append(int(key))
	source_ids.sort()
	for id: int in source_ids:
		effect_choice_ids.append(id); effect_choices.add_item("원문 Sprite %d" % id)
	effect_choices.item_selected.connect(func(index: int) -> void: set_preview_sprite(effect_choice_ids[index]))
	column.add_child(effect_choices)
	effect_action = OptionButton.new(); effect_action.name = "SourceEffectAction"; column.add_child(effect_action)
	effect_preview = Button.new(); effect_preview.name = "SourceEffectPreview"; effect_preview.text = "선택 기술의 원본 효과 미리보기"
	effect_preview.pressed.connect(preview_effect); column.add_child(effect_preview)
	effect_settings_status = Label.new(); effect_settings_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(effect_settings_status)
	var compat_open := Button.new(); compat_open.name = "BossCompatOpen"; compat_open.text = "TWILIGHT 자체 보스 규칙 설정"; column.add_child(compat_open)
	var compat_box := VBoxContainer.new(); compat_box.hide(); column.add_child(compat_box)
	compat_open.pressed.connect(func() -> void: compat_box.visible = not compat_box.visible)
	var compat_note := Label.new()
	compat_note.text = "원문 지연·피해·간격은 우선합니다. 범위·수명·발동 조건·소환 구성은 자체 규칙입니다.\n소환은 현재 지역의 기존 일반 몬스터를 사용하며 EXP·아이템·재화를 지급하지 않습니다."
	compat_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; compat_box.add_child(compat_note)
	for spec: Array in [["자체 후속·지면·소환 켜기","enabled"],["원문 TestSpell을 자체 검증에 허용","allow_test_definitions"],["자체 발동 조건: 호스트 명중 판정 통과","trigger_on_hit"],["자체 범위: 정사각형 (끄면 원)","ground_box"],["자체 반복 피해 · 원문 간격 우선","ground_repeat"],["자체 장판 중첩 허용 (상한8)","ground_stack"],["중단 시 예약 후속 취소","cancel_on_interrupt"]]:
		var toggle := CheckButton.new(); toggle.name = "BossCompat_"+str(spec[1]); toggle.text = spec[0]; toggle.clip_text = true
		toggle.button_pressed = service.compatibility.get(spec[1]); compat_box.add_child(toggle)
		var property: String = spec[1]
		toggle.toggled.connect(func(value: bool) -> void:
			service.clear(); service.compatibility.set(property,value); persist_compat_settings())
	for spec: Array in [["자체 지면 반경(px)","ground_radius",16,320,1],["자체 지면 수명(초)","ground_seconds",.1,30,.1],["자체 소환 수(상한4)","summon_count",1,4,1],["자체 소환 수명(초)","summon_seconds",1,120,1]]:
		var row := HBoxContainer.new(); compat_box.add_child(row)
		var label := Label.new(); label.text = spec[0]; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.clip_text = true; row.add_child(label)
		var spin := SpinBox.new(); spin.name = "BossCompat_"+str(spec[1]); spin.min_value = spec[2]; spin.max_value = spec[3]; spin.step = spec[4]
		spin.value = service.compatibility.get(spec[1]); row.add_child(spin)
		var property: String = spec[1]
		spin.value_changed.connect(func(value: float) -> void:
			service.clear(); service.compatibility.set(property,int(value) if property == "summon_count" else value); persist_compat_settings())
	compat_status = Label.new(); compat_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; compat_box.add_child(compat_status)
	var extra_open := Button.new(); extra_open.name = "BossExtensionsOpen"; extra_open.text = "회복·상태·지역 NPC 규칙"; column.add_child(extra_open)
	var extra := VBoxContainer.new(); extra.hide(); column.add_child(extra)
	extra_open.pressed.connect(func() -> void: extra.visible = not extra.visible)
	var extra_note := Label.new(); extra_note.text = "원문 제한·치유 감소를 소비합니다. 독 간격·회복 대상·해제 범위·반사 결합식은 자체 설정입니다.\n지역 자동 적용은 실제 source map/Land/원문 영역이 일치할 때만 합니다. 자체 문맥은 선택한 한 버프를 현재 필드의 지정 반경에 연결합니다."; extra_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; extra.add_child(extra_note)
	for spec: Array in [["자체 회복·해제·독·NPC 버프 실행","enabled"],["자체 역치유 허용 · 물약에는 적용하지 않음","reverse_healing"],["NPC 환경 버프 소비 켜기","environment_enabled"],["일치하는 원문 Land/영역 자동 소비","native_regions"],["자체 카운터 확률·감소·반사 결합식","reaction_enabled"]]:
		var toggle := CheckButton.new(); toggle.name = "BossExt_"+str(spec[1]); toggle.text = spec[0]; toggle.clip_text = true; toggle.button_pressed = service.extensions.get(spec[1]); extra.add_child(toggle)
		var property: String = spec[1]
		toggle.toggled.connect(func(value: bool) -> void:
			if not update_extension(property,value): toggle.set_pressed_no_signal(not value))
	var target := OptionButton.new(); target.name = "BossExt_heal_target"; target.add_item("자체 회복 대상: 플레이어 · 원문 Enemy 축"); target.add_item("자체 회복 대상: 시전자"); target.add_item("자체 회복 대상: 현재 선택 NPC"); target.select(service.extensions.heal_target); extra.add_child(target)
	target.item_selected.connect(func(value: int) -> void:
		if not update_extension("heal_target",value): target.select(service.extensions.heal_target))
	for spec: Array in [["자체 독 간격(초)","poison_interval",.1,10,.1],["자체 문맥 반경(px)","own_radius",16,2048,16],["자체 반사 배율","reaction_scale",0,10,.1]]:
		var row := HBoxContainer.new(); extra.add_child(row)
		var label := Label.new(); label.text = spec[0]; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
		var spin := SpinBox.new(); spin.name = "BossExt_"+str(spec[1]); spin.min_value = spec[2]; spin.max_value = spec[3]; spin.step = spec[4]; spin.value = service.extensions.get(spec[1]); row.add_child(spin)
		var property: String = spec[1]
		spin.value_changed.connect(func(value: float) -> void:
			if not update_extension(property,value): spin.set_value_no_signal(service.extensions.get(property)))
	var bind := Button.new(); bind.name = "BossEnvironmentBind"; bind.text = "선택 지역 버프를 현재 필드/내 위치에 자체 연결"; extra.add_child(bind)
	bind.pressed.connect(bind_environment)
	var unbind := Button.new(); unbind.name = "BossEnvironmentUnbind"; unbind.text = "자체 지역 문맥 해제"; extra.add_child(unbind)
	unbind.pressed.connect(func() -> void: update_extension("own_attribute",0))
	var dismiss := Button.new(); dismiss.name = "BossEnvironmentDispel"; dismiss.text = "선택 NPC 환경 버프 해제 · 자체 재진입 정책"; extra.add_child(dismiss)
	dismiss.pressed.connect(func() -> void:
		extension_status.text = "해제됨 · 영역 이탈 후 재진입하면 다시 부여" if service.extensions.dismiss(service.world.selected_monster) else "해제 가능한 현재 NPC 버프 없음")
	extension_status = Label.new(); extension_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; extra.add_child(extension_status)
	build_remaining_controls(column)
	attacks = ItemList.new(); attacks.name = "AttackList"; attacks.custom_minimum_size.y = 170; column.add_child(attacks)
	attacks.item_selected.connect(show_attack)
	detail = RichTextLabel.new(); detail.name = "SkillDetails"; detail.bbcode_enabled = false
	detail.custom_minimum_size.y = 200; detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(detail)
	panel.hide()
	fill_selector()

func _process(_delta: float) -> void:
	_hide_under_original_window()
	var size: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(900,size.x-24),minf(650,size.y-24))
	panel.position = (size-panel.size)*.5
	var lines: PackedStringArray = []
	for buff: Dictionary in service.player_buffs.values():
		lines.append("%s · %.1f초" % [service.catalog.row("BuffClass",int(buff.id)).get("Name","상태"),float(buff.remaining)])
	status.text = "\n".join(lines)
	if service.compatibility.enabled:
		status.text += "\nTWILIGHT 자체 규칙 · 후속%d / 지면%d / 소환%d" % [service.compatibility.waiting.size(),service.compatibility.zones.size(),service.compatibility.summons.size()]
	if service.extensions.environment_enabled: status.text += "\nNPC 지역 버프 소비: %d개체 · 자체 문맥 %s" % [service.extensions.active.size(),str(service.extensions.own_attribute)]

func fill_selector() -> void:
	selector.clear()
	if selector.has_meta("source523_npc_images"): selector.remove_meta("source523_npc_images")
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
		if not environment_mode: _bind_npc_illustration(selector.item_count - 1,int(id))
	refresh_npc()

func _bind_npc_illustration(index: int, npc_id: int) -> void:
	if not SourceImages.selected(): return
	var image: Dictionary = NpcImages.resolve(service.catalog,npc_id)
	selector.set_item_icon(index,image.get("texture") as Texture2D)
	selector.expand_icon = true
	var originals: Dictionary = selector.get_meta("source523_npc_images",{})
	originals[str(npc_id)] = NpcImages.evidence(image)
	selector.set_meta("source523_npc_images",originals)

func refresh_npc() -> void:
	if selector == null or ids.is_empty(): return
	attacks.clear()
	if environment_mode:
		rows = service.catalog.environment_buffs(int(ids[maxi(0,selector.selected)]))
		for binding: Dictionary in rows:
			var image: Dictionary = SKILL_BUFF_IMAGES.describe_buff_class_row(binding.buff.source)
			var index: int = attacks.add_item(str(binding.buff.source.get("Name","NPC 상태")) + " · 범위·적용 조건 확인 필요",image.get("texture") as Texture2D)
			attacks.set_item_metadata(index,{"source523_buff_image":SKILL_BUFF_IMAGES.evidence(image)})
		if not rows.is_empty(): attacks.select(0); show_attack(0)
		return
	rows = service.catalog.owned("NpcAttack",int(ids[maxi(0,selector.selected)]))
	for attack: Dictionary in rows:
		var spell: Dictionary = service.catalog.row("SpellClass",int(attack.get("SpellID",0)))
		var image: Dictionary = SKILL_BUFF_IMAGES.describe_spell_class_row(spell)
		var index: int = attacks.add_item(str(spell.get("Name","기본 공격")) + " · " + service.support_reason(attack),image.get("texture") as Texture2D)
		attacks.set_item_metadata(index,{"source523_skill_image":SKILL_BUFF_IMAGES.evidence(image)})
	if not rows.is_empty(): attacks.select(0); show_attack(0)

func append_chain(chain: Dictionary, lines: PackedStringArray, depth: int = 0) -> PackedStringArray:
	if not chain.has("source"): lines.append("후속 연결: " + str(chain.get("pending","미확인"))); return lines
	var spell: Dictionary = chain.source
	lines.append(("후속 기술: " if depth > 0 else "기술: ") + str(spell.Name))
	lines.append("원문 MP 소모 %d · %s / 자체 실행은 검증된 방출 시 한 번 차감" % [int(spell.get("MPCost",0)),str(service.catalog.row("Unit",int(spell.get("MPCostUnit",0))).get("Name","단위 미확정"))])
	for edge: Dictionary in chain.get("bonuses",[]):
		lines.append("  %s: %s (%s)" % [edge.type.get("Name","미확인"),str(edge.bonus.get("Value","?")),edge.unit.get("Name","단위 미확인")])
		if int(edge.bonus.get("BonusApplicationTypeID",0)) != 0:
			lines.append("  원문 적용: %s / 값: %s" % [str(service.catalog.row("BonusApplicationType",int(edge.bonus.BonusApplicationTypeID)).get("Name",edge.bonus.BonusApplicationTypeID)),str(edge.bonus.BonusApplicationTargetID)])
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
	set_preview_sprite(0)
	if environment_mode:
		var environment_lines: PackedStringArray = [str(attack.buff.source.get("Name","NPC 상태")),"영역 %s · %s" % [str(attack.attribute.TerritoryID),str(attack.territory.get("Name","랜드 전체 조건"))],"방어 반응 조건 · 최종 수식/적용 시점은 해석 대기"]
		for invoke: Dictionary in attack.buff.invokes:
			var kind: Dictionary = service.catalog.row("AttackType",int(invoke.source.get("AttackTypeID",0)))
			environment_lines.append("%s · 주문 여부 %s · 원문 부여값 %s" % [str(kind.get("Name",invoke.source.get("AttackTypeID",0))),str(invoke.source.get("BySpellAttack",false)),str(invoke.edge.bonus.get("Value",0))])
		for bonus: Dictionary in attack.buff.bonuses:
			if bonus.type.get("Name") != "InvokeOption": environment_lines.append("%s: %s (%s)" % [str(bonus.type.get("Name","미확인")),str(bonus.bonus.get("Value",0)),str(bonus.unit.get("Name","단위 미확인"))])
		environment_lines.append("실제 Land/원문 영역 일치 또는 별도 선택한 자체 문맥에서만 소비합니다. 원문 %d · 자체 필드 %s / 반경 %.0fpx" % [int(attack.attribute.ID),service.extensions.own_map,service.extensions.own_radius])
		environment_lines.append("기존 피해/AC/MR/카운터 소비. HP/STR/DEX/EXP/속도·개별 아이템 가중치와 특수 반응 분류는 별도 자체 설정에서 선택합니다.")
		detail.text = "\n".join(environment_lines)
		return
	var lines: PackedStringArray = [service.support_reason(attack)]
	var npc_id: int = int(ids[maxi(0,selector.selected)])
	lines.append("AI 원문 ID: %d · 호스트 공격 그래프 시작점 %d개" % [int(service.catalog.ai_evidence(npc_id).native_ai_id_raw),service.catalog.attack_roots(npc_id).size()])
	if bool(attack.get("IsSpell",false)):
		var spell: Dictionary = service.catalog.row("SpellClass",int(attack.SpellID))
		set_preview_sprite(service.source_effects.first_sprite(spell))
		lines = append_chain(service.catalog.spell_chain(int(attack.SpellID)),lines)
		if bool(spell.get("TestSpell",false)): lines.append("원문 TestSpell=true · 자체 검증 허용 선택과 별도 보존")
		if service.compatibility.handles(spell):
			lines.append("TWILIGHT 자체 규칙 · 범위 %.0fpx / 지면 %.1f초 / 중첩 %s / 소환 %d개 %.1f초" % [service.compatibility.ground_radius,service.compatibility.ground_seconds,str(service.compatibility.ground_stack),service.compatibility.summon_count,service.compatibility.summon_seconds])
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

func update_extension(property: String, value: Variant) -> bool:
	var old: Variant = service.extensions.get(property)
	service.extensions.set(property,value)
	var result: Error = service.extensions.save_settings()
	if result != OK: service.extensions.set(property,old)
	else:
		service.extensions.active.clear(); service.extensions.incoming.clear(); service.extensions.suppressed.clear()
		if property == "enabled" and not bool(value): service.extensions.actor_buffs.clear()
	extension_status.text = "자체 설정 저장됨 · 기존 세이브와 별도" if result == OK else "저장 실패 · 기존 설정으로 원복"
	if selector != null: refresh_npc()
	return result == OK

func _remaining_choice_image(choice: OptionButton, index: int, image: Dictionary) -> void:
	choice.set_item_icon(index, null)
	var images: Dictionary = choice.get_meta("source523_images", {}).duplicate(true)
	images.erase(index)
	if SourceImages.selected() and not image.is_empty():
		choice.set_item_icon(index, image.get("texture") as Texture2D)
		images[index] = SKILL_BUFF_IMAGES.evidence(image)
	if images.is_empty():
		if choice.has_meta("source523_images"): choice.remove_meta("source523_images")
	else: choice.set_meta("source523_images", images)

func build_remaining_controls(column: VBoxContainer) -> void:
	var open := Button.new(); open.name = "BossRemainingOpen"; open.text = "추가 능력치·드랍·전체 해제 자체 정책"; column.add_child(open)
	var box := VBoxContainer.new(); box.hide(); column.add_child(box)
	open.pressed.connect(func() -> void: box.visible = not box.visible)
	var note := Label.new(); note.text = "확인한 NPC/영역 또는 선택한 자체 문맥에서만 소비합니다. HP 진입은 최대치만 늘리고 회복하지 않으며 이탈 시 현재 HP를 상한에 맞춥니다. STR/DEX 환산·드랍 가중치 단위·미대응 버프 해제는 자체 정책입니다. 드랍 횟수·등급 확률·수량은 유지합니다."; note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(note)
	for spec: Array in [["지역 HP·STR·DEX·EXP·속도 소비","stats_enabled"],["기존 성공 등급의 대상 아이템 선택 가중치","drops_enabled"]]:
		var toggle := CheckButton.new(); toggle.name = "BossRemaining_"+str(spec[1]); toggle.text = spec[0]; toggle.button_pressed = service.extensions.remaining.get(spec[1]); box.add_child(toggle)
		var key: String = spec[1]
		toggle.toggled.connect(func(value: bool) -> void:
			if not update_remaining(key,value): toggle.set_pressed_no_signal(not value))
	for spec: Array in [["자체 STR→근접 피해","strength_damage",0,10,1],["자체 STR→근접 명중","strength_accuracy",0,10,1],["자체 DEX→원거리 피해","dexterity_damage",0,10,1],["자체 DEX→원거리 명중","dexterity_accuracy",0,10,1],["자체 드랍 가중치 단위(raw/값)","drop_divisor",1,1000000,1]]:
		var row := HBoxContainer.new(); box.add_child(row)
		var label := Label.new(); label.text = spec[0]; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; label.clip_text = true; row.add_child(label)
		var spin := SpinBox.new(); spin.name = "BossRemaining_"+str(spec[1]); spin.min_value = spec[2]; spin.max_value = spec[3]; spin.step = spec[4]; spin.value = service.extensions.remaining.get(spec[1]); row.add_child(spin)
		var key: String = spec[1]
		spin.value_changed.connect(func(value: float) -> void:
			if not update_remaining(key,value): spin.set_value_no_signal(service.extensions.remaining.get(key)))
	remaining_buff_choice = OptionButton.new(); remaining_buff_choice.name = "BossRemainingBuff"; remaining_buff_choice.fit_to_longest_item = false; remaining_buff_choice.clip_text = true; remaining_buff_choice.expand_icon = true; box.add_child(remaining_buff_choice)
	var environment_ids: Dictionary = {}
	for source: Dictionary in service.catalog.content.tables.get("LandAttribute",{}).values(): environment_ids[int(source.row.Value)] = true
	for entry: Dictionary in service.catalog.content.tables.get("BuffClass",{}).values():
		var profile: String = "전체 환경 보너스" if environment_ids.has(int(entry.row.ID)) else "개별 드랍 보너스만"
		var drop_profile: bool = false
		for bonus: Dictionary in service.catalog.buff_details(int(entry.row.ID)).bonuses:
			if bonus.type.get("Name") == "NpcSingleItemDropProbabilityMultiple": drop_profile = true
		if not environment_ids.has(int(entry.row.ID)) and not drop_profile: continue
		remaining_buff_ids.append(int(entry.row.ID)); remaining_buff_choice.add_item("%s %d · %s" % [profile,int(entry.row.ID),str(entry.row.Name)])
		_remaining_choice_image(remaining_buff_choice, remaining_buff_choice.item_count - 1, SKILL_BUFF_IMAGES.describe_buff_class_row(entry.row))
	var bind := Button.new(); bind.name = "BossRemainingBind"; bind.text = "이 원문 버프를 현재 필드/내 위치에 자체 연결"; box.add_child(bind)
	bind.pressed.connect(func() -> void:
		var p = service.extensions.remaining; var old: Array = [p.own_buff,p.own_map,p.own_center]
		if remaining_buff_choice.selected < 0 or not p.bind_current(remaining_buff_ids[remaining_buff_choice.selected]): return
		if service.extensions.save_settings() != OK: p.own_buff = old[0]; p.own_map = old[1]; p.own_center = old[2]; remaining_status.text = "저장 실패 · 문맥 원복"
		else: remaining_status.text = "자체 버프 %d · %s · 반경 %.0fpx" % [p.own_buff,p.own_map,service.extensions.own_radius])
	var clear := Button.new(); clear.text = "추가 자체 버프 문맥 해제"; clear.name = "BossRemainingUnbind"; box.add_child(clear); clear.pressed.connect(func() -> void: update_remaining("own_buff",0))
	var special := OptionButton.new(); special.name = "BossRemainingSpecial"; special.fit_to_longest_item = false; special.clip_text = true
	special.add_item("반응 분류: 기존 채널"); special.add_item("자체 반응 태그42 Dark · 피해식 유지"); special.add_item("자체 반응 태그72 MeleeMagic · 피해식 유지"); special.select([0,42,72].find(service.extensions.remaining.special_type)); box.add_child(special)
	special.item_selected.connect(func(index: int) -> void:
		if not update_remaining("special_type",[0,42,72][index]): special.select([0,42,72].find(service.extensions.remaining.special_type)))
	var cancel := OptionButton.new(); cancel.name = "BossRemainingCancel"; cancel.fit_to_longest_item = false; cancel.clip_text = true
	cancel.add_item("캔슬: 원문 대응 버프만"); cancel.add_item("자체 캔슬: 지정 호스트 버프"); cancel.add_item("자체 캔슬: 모든 적격 호스트 버프"); cancel.select(service.extensions.remaining.host_cancel_mode); box.add_child(cancel)
	cancel.item_selected.connect(func(index: int) -> void:
		if not update_remaining("host_cancel_mode",index): cancel.select(service.extensions.remaining.host_cancel_mode))
	for spec: Array in [["캔슬 지정 버프 이름(쉼표)","selected_host_buffs"],["자체 취소 면역 버프 이름(쉼표)","protected_host_buffs"]]:
		var input := LineEdit.new(); input.name = "BossRemaining_"+str(spec[1]); input.placeholder_text = spec[0]; input.text = ",".join(service.extensions.remaining.get(spec[1])); box.add_child(input)
		var key: String = spec[1]
		input.text_submitted.connect(func(value: String) -> void:
			var names: Array = []
			for name: String in value.split(",",false):
				if not name.strip_edges().is_empty(): names.append(name.strip_edges())
			if not update_remaining(key,names): input.text = ",".join(service.extensions.remaining.get(key)))
	var target := OptionButton.new(); target.name = "BossRemainingItemID"; target.expand_icon = true; box.add_child(target)
	var targets: Array[int] = []
	for entry: Dictionary in service.catalog.content.tables.get("BuffClass",{}).values():
		for bonus: Dictionary in service.catalog.buff_details(int(entry.row.ID)).bonuses:
			if bonus.type.get("Name") == "NpcSingleItemDropProbabilityMultiple" and not targets.has(int(bonus.bonus.BonusApplicationTargetID)):
				var item_class_id: int = int(bonus.bonus.BonusApplicationTargetID)
				targets.append(item_class_id); target.add_item("원문 ItemClass %d" % item_class_id)
				var image: Dictionary = {}
				if SourceImages.selected():
					var source_row: Dictionary = service.catalog.row("ItemClass", item_class_id)
					image = SourceImages.describe_item_class_row(source_row) if not source_row.is_empty() else SourceImages.describe_item_class(item_class_id)
				_remaining_choice_image(target, target.item_count - 1, image)
	var item := LineEdit.new(); item.name = "BossRemainingItemName"; item.placeholder_text = "명시 연결할 현재 게임 아이템의 정확한 이름"; box.add_child(item)
	var map_item := Button.new(); map_item.name = "BossRemainingMapItem"; map_item.text = "선택 원문 아이템과 현재 카탈로그를 자체 연결"; box.add_child(map_item)
	map_item.pressed.connect(func() -> void:
		if target.selected < 0 or not service.world.loot_catalog.get("by_name",{}).has(item.text): remaining_status.text = "현재 카탈로그의 정확한 아이템 이름이 필요합니다"; return
		var bindings: Dictionary = service.extensions.remaining.item_bindings.duplicate(true); bindings[str(targets[target.selected])] = item.text; update_remaining("item_bindings",bindings))
	remaining_status = Label.new(); remaining_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(remaining_status)

func update_remaining(key: String, value: Variant) -> bool:
	var p = service.extensions.remaining; var old: Variant = p.get(key)
	p.set(key,value)
	var error: Error = service.extensions.save_settings()
	if error != OK: p.set(key,old)
	remaining_status.text = "자체 설정 저장됨 · 원본/등급 확률/드랍 횟수 유지" if error == OK else "저장 실패 · 실행 값 원복"
	return error == OK

func bind_environment() -> void:
	if not environment_mode or rows.is_empty(): extension_status.text = "지역 NPC 상태에서 원문 한 행을 선택하세요"; return
	var selected: PackedInt32Array = attacks.get_selected_items()
	if selected.is_empty(): return
	var old: Array = [service.extensions.own_attribute,service.extensions.own_map,service.extensions.own_center]
	if not service.extensions.bind_current(int(rows[selected[0]].attribute.ID)): extension_status.text = "실제 현재 필드가 필요합니다"; return
	if service.extensions.save_settings() != OK:
		service.extensions.own_attribute = old[0]; service.extensions.own_map = old[1]; service.extensions.own_center = old[2]; extension_status.text = "저장 실패 · 기존 문맥으로 원복"
	else:
		service.extensions.active.clear(); service.extensions.suppressed.clear()
		extension_status.text = "자체 문맥 연결됨 · NPC 환경 버프 소비를 켜면 현재 필드/반경에서 적용"

func persist_compat_settings() -> void:
	if compat_status == null: return
	compat_status.text = "자체 보스 규칙 저장됨 · 기존 세이브와 별도" if service.compatibility.save_settings() == OK else "저장 실패 · 현재 세션에만 적용"
	if not environment_mode:
		var selected: PackedInt32Array = attacks.get_selected_items()
		for i: int in rows.size():
			var spell: Dictionary = service.catalog.row("SpellClass",int(rows[i].get("SpellID",0)))
			attacks.set_item_text(i,str(spell.get("Name","기본 공격"))+" · "+service.support_reason(rows[i]))
		if not rows.is_empty(): show_attack(int(selected[0]) if not selected.is_empty() else 0)

func set_preview_sprite(id: int) -> void:
	preview_sprite = id; preview_action = 0
	if effect_choices != null: effect_choices.select(maxi(0,effect_choice_ids.find(id)))
	if effect_action != null:
		effect_action.clear()
		if id > 0 and service.source_effects.records.has(str(id)):
			preview_action = int(service.source_effects.records[str(id)].source_action_id)
			effect_action.add_item("확인한 원문 액션 %d · 미리보기에서 명시 선택" % preview_action)
	if effect_preview != null:
		effect_preview.disabled = id <= 0
		effect_preview.text = "선택 원문 효과 미리보기 · 전투 발동과 별도"

func preview_effect() -> void:
	if preview_sprite <= 0: return
	if not service.source_effects.enabled:
		effect_settings_status.text = "추정 재생을 켜면 확인한 원본 프레임을 표시합니다."; return
	if service.effects.size() >= 16: return
	var effect: Node2D = service.source_effects.make_effect(preview_sprite,preview_action,service.remaining_effect_bytes(),int(service.world.player.facing8))
	if effect == null:
		effect_settings_status.text = "계층 합성 설정·효과 메모리 한도·원본 팩 파일을 확인하세요."; return
	service.world.player.add_child(effect)
	effect.global_position = service.world.player.global_position
	service.effects.append(effect)
	effect_settings_status.text = "원본 효과 %d · 추정 재생 중" % preview_sprite
	panel.hide()
