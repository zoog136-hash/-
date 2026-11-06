extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Art = preload("res://scripts/growth/growth_art.gd")
const CardFace = preload("res://scripts/growth/growth_card_face.gd")
const Diagram = preload("res://scripts/growth/growth_diagram.gd")
const Palette = preload("res://scripts/growth/growth_palette.gd")
const Surface = preload("res://scripts/growth/growth_surface.gd")
const IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const CLASS_IMAGES = preload("res://scripts/ui/source523_skill_buff_images.gd")
var hud
var runtime
var mode: String = "emblems"
var selected: String = "eva"
var selected_node: String = ""
var scroll: ScrollContainer
var body: VBoxContainer
var result: Label
var confirmation: VBoxContainer
var request: Dictionary = {}
var submitting: bool = false
var last_reveal: Dictionary = {}
var action_dock: GridContainer
var chart: Control
var card_faces: Dictionary = {}
var diagram: Control
var guardian_controls: Array=[]
var guardian_clock: float=0
var guardian_presentation: Node

func configure(owner_hud: Node, section: String) -> void:
	hud = owner_hud
	runtime = hud.get_parent().growth
	if section=="guardians":
		guardian_presentation=hud.get_parent().get_node_or_null("GuardianAuthoredPresentation")
		if guardian_presentation==null:
			guardian_presentation=preload("res://scripts/growth/guardian_authored_presentation.gd").new()
			hud.get_parent().add_child(guardian_presentation)
	mode = section
	selected = "eva" if mode == "emblems" else "joe"
	name = "GrowthView"
	theme = Palette.make_theme()
	add_theme_constant_override("separation",5)
	resized.connect(queue_redraw)
	resized.connect(_layout_density)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	result = UI.label("",14,UI.GOLD)
	result.name = "GrowthResult"
	result.visible = false
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result)
	scroll = ScrollContainer.new()
	scroll.name = "GrowthScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel",Palette.plate(Color(0,0,0,.12),Color("564838"),6))
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",6)
	scroll.add_child(body)
	action_dock=GridContainer.new()
	action_dock.name="GrowthActionDock"
	action_dock.columns=4
	add_child(action_dock)
	var close := preload("res://scripts/ui/native_touch_button.gd").new()
	close.text = "닫기"
	close.name = "GrowthClose"
	close.custom_minimum_size.y = 44
	close.add_theme_stylebox_override("normal",Palette.button(Color("172434")))
	close.pressed.connect(func() -> void: hud._close_workspace())
	add_child(close)
	_refresh()

func _label(text: String, parent: Node = null) -> Label:
	if parent == null: parent = body
	var out := UI.label(text,14)
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(out)
	return out

func _copy(text: String, parent: Node, font_size: int = 13, color: Color = Palette.MUTED) -> Label:
	var label: Label=_label(text,parent)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	if parent is HBoxContainer: label.autowrap_mode=TextServer.AUTOWRAP_OFF
	return label

func _balance() -> void:
	var strip:=HBoxContainer.new()
	strip.name="GrowthBalance"
	body.add_child(strip)
	for text: String in ["축복 포인트 %d" % int(runtime.state.points),"수호석 %d" % int(runtime.world.inventory.get("수호석",0))]:
		_copy(text,strip,14,Palette.GOLD)
	strip.set_meta("original_balance_icons",{"status":"source_icon_roles_pending"})
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	strip.add_child(spacer)
	if runtime.development: _copy("개발용 근사 · 원작 수치 아님 · 별도 저장",strip,12,Color("d5b99a"))

func _layout_density() -> void:
	if is_instance_valid(diagram):
		diagram.custom_minimum_size=Vector2(270,214 if size.y<500 else 306)
	for index: int in card_faces:
		var face: Control=card_faces[index]
		if is_instance_valid(face): face.get_parent().custom_minimum_size=Vector2(132,184) if size.y<500 else Vector2(164,230)

func _button(text: String, action: Callable, parent: Node = null) -> Button:
	if parent == null: parent = body
	var out := preload("res://scripts/growth/growth_touch_button.gd").new()
	out.scroll_host = hud.workspace
	out.scroll_area = scroll
	out.text = text
	out.custom_minimum_size.y = 48
	out.pressed.connect(func() -> void:
		if not submitting and not hud.workspace.was_scroll_dragged(scroll): action.call())
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(out)
	return out

func _source_item_image(item_class_id: int) -> Dictionary:
	var row: Dictionary = runtime.source523.data.get("items", {}).get(str(item_class_id), {})
	return IMAGES.describe_item_class_row(row) if not row.is_empty() else IMAGES.describe_item_class(item_class_id)

func _action_image(action: String, id: String, offer: Dictionary = {}) -> Dictionary:
	if not IMAGES.selected() or runtime.development: return {}
	if action == "recharge":
		var instance: Dictionary = runtime.world.item_instances.get(id, {})
		var recharge: Dictionary = runtime.source523.recharge(instance)
		if not recharge.is_empty(): return _source_item_image(int(recharge.item_id))
	elif action == "reset":
		# The quote identifies the exact physical source material it will consume.
		# A scroll name or a symbol/group ID cannot provide an ItemClass identity.
		var instance: Dictionary = runtime.world.item_instances.get(str(offer.get("consume_instance", "")), {})
		if runtime.source523.reset_material(instance):
			return IMAGES.describe_item_class_row(instance.record.source_original_item)
	elif action == "guardian_cast" and runtime.guardian_source.has_node(id):
		# Use the same native spell reward as the existing guardian_cast caller.
		var rewards: Array = runtime.guardian_rewards(id)
		if not rewards.is_empty() and rewards[0].get("spell") is Dictionary:
			return CLASS_IMAGES.describe_spell_class_row(rewards[0].spell, "IconID")
	return {}

func _bind_action_image(button: Button, action: String, id: String, offer: Dictionary = {}) -> void:
	button.icon = null
	for key: String in ["source523_image", "source523_image_provenance", "source523_image_status"]:
		if button.has_meta(key): button.remove_meta(key)
	var image_info: Dictionary = _action_image(action, id, offer)
	if image_info.is_empty(): return
	button.icon = image_info.get("texture") as Texture2D
	button.expand_icon = true
	var evidence: Dictionary = image_info.duplicate(true)
	evidence.erase("texture")
	evidence["presentation_action"] = action
	button.set_meta("source523_image", evidence)
	button.set_meta("source523_image_provenance", image_info.get("provenance", {}).duplicate(true))
	button.set_meta("source523_image_status", str(image_info.get("source_status", image_info.get("reason", ""))))

func _refresh() -> void:
	request = {}
	for child: Node in body.get_children(): body.remove_child(child); child.queue_free()
	for child: Node in action_dock.get_children(): action_dock.remove_child(child); child.queue_free()
	card_faces.clear()
	guardian_controls.clear()
	diagram=null; chart=null
	_balance()
	var tabs := GridContainer.new()
	tabs.columns = 7 if mode == "emblems" else 6
	body.add_child(tabs)
	tabs.visible=mode=="emblems" or (runtime.state.pending.is_empty() and last_reveal.is_empty())
	var rows: Array = runtime.config.get(mode,[])
	for row: Dictionary in rows:
		var id: String = str(row.id)
		var button: Button = _button(str(row.name).replace("의 문양",""),func() -> void: _select(id),tabs)
		button.name = "GrowthTab_"+id
		button.custom_minimum_size.y=40
		button.add_theme_stylebox_override("normal",Palette.tab(id==selected))
		button.add_theme_stylebox_override("hover",Palette.tab(true))
		button.add_theme_stylebox_override("pressed",Palette.tab(true))
		button.add_theme_color_override("font_color",Palette.GOLD if id==selected else Palette.MUTED)
		button.add_theme_font_size_override("font_size",14)
	if mode == "emblems": _emblem()
	else:
		_guardian_presentation_settings()
		_guardian()
	confirmation = VBoxContainer.new()
	confirmation.name = "GrowthConfirmation"
	body.add_child(confirmation)
	if mode!="guardians" or (runtime.state.pending.is_empty() and last_reveal.is_empty()):
		_button("축복 포인트 상점 · 열쇠 1개",func() -> void: _prepare("buy_key","",1))
		if runtime.development:
			_button("축복의 성수(중) 사용",func() -> void: _prepare("holy_water","",1)).name = "GrowthHolyWater"
		else:
			var usable_recharges: int = 0
			for instance_id: String in runtime.world.item_instances:
				var recharge: Dictionary = runtime.source523.recharge(runtime.world.item_instances[instance_id])
				if recharge.is_empty(): continue
				var owned_id: String = instance_id
				var recharge_button: Button = _button("%s 사용 · 축복 포인트 +%d" % [str(recharge.name),int(recharge.amount)],func() -> void: _prepare("recharge",owned_id,1))
				recharge_button.name = "GrowthRecharge_"+owned_id
				_bind_action_image(recharge_button, "recharge", owned_id)
				usable_recharges += 1
			if usable_recharges == 0: _label("사용 가능한 축복 포인트 충전 재료가 없습니다.")
		_button("수호석 제작 · 일반 주문서",func() -> void: _prepare("craft_stone","",1))
		_button("수호석 제작 · 각인 주문서",func() -> void: _prepare("craft_stone_engraved","",1))
		_label("출처: 누적523 수호성 테이블·원본 도움말 / 문양 공식 가이드\n능력치는 상시 적용 · 발동 스킬은 분류별 지정 / 사용 스킬은 스킬 특수 탭" if mode=="guardians" and not runtime.development else "문양: 누적 523 원본 단계·비용·옵션 연결\n조건부 효과·서버별 가용성·저장/복구와 일일 초기화 제한은 미확정입니다." if not runtime.development else "개발용 근사 설정 · 일반 저장과 분리")
	call_deferred("_layout_density")

func _select(id: String) -> void:
	if mode=="emblems" and selected!=id: runtime.rerolls.clear()
	selected=id
	last_reveal={}
	selected_node=""
	_refresh()

func _emblem() -> void:
	var row: Dictionary = runtime.emblem(selected)
	var p: Dictionary = runtime.progress(selected)
	var policy: Dictionary=runtime.Combat.policy
	_label("자체 전투 근사 %s · 죽음 1당 피해 %.1f / 감소무시 배율 %.1f / 연속피격 %dms" % ["켜짐" if runtime.Combat.estimates() else "꺼짐",float(policy.death_damage_per_point),float(policy.ignore_percent_damage_scale),int(policy.damage_damp_window_ms)]).name="GrowthLocalCombatPolicy"
	_label("자체 근사: 보스 연사 방어 · 돌진을 아머 브레이크로 처리 · 광역의 피해감소 무시 %.1f%%" % float(policy.npc_ignore_percent_by_boss_kind.get("nova",0)))
	if selected=="eva":
		_button("기억 장소 · 순간이동 조종",func() -> void: runtime.travel.open()).name="GrowthRememberedLocations"
	var overview := HBoxContainer.new()
	body.add_child(overview)
	diagram = Diagram.new()
	diagram.stage = int(p.stage)
	diagram.sigil_index = Art.index(selected)
	diagram.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	diagram.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	diagram.size_flags_stretch_ratio=.85
	overview.add_child(diagram)
	var panel:=Surface.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	overview.add_child(panel)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(info)
	var heading:=HBoxContainer.new()
	info.add_child(heading)
	_copy(str(row.name),heading,19,Palette.GOLD).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_copy("%d단계" % int(p.stage),heading,19,Art.COLORS[Art.index(selected)])
	_copy("강화 %d / 20회   ·   초기화 환급 %d 포인트" % [int(p.attempts),int(p.spent)],info,12)
	var odds: Array = runtime.probabilities(selected)
	var odds_row:=HBoxContainer.new()
	info.add_child(odds_row)
	for index: int in range(3):
		var column:=VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		odds_row.add_child(column)
		_copy("+%d 단계" % (index+1),column,12)
		_copy("완료" if int(p.stage)>=30 else "%.2f%%" % float(odds[index]),column,17,[Color("ded8cc"),Color("68bce8"),Color("e27989")][index])
		var bar:=ProgressBar.new()
		bar.custom_minimum_size=Vector2(40,5)
		bar.show_percentage=false; bar.value=0.0 if int(p.stage)>=30 else float(odds[index])
		bar.add_theme_stylebox_override("background",UI.box(Color("24202c"),Color.TRANSPARENT,0))
		bar.add_theme_stylebox_override("fill",UI.box([Color("d9d5d5"),Color("42adf5"),Color("d95469")][index],Color.TRANSPARENT,0))
		column.add_child(bar)
	_copy("현재 적용",info,12,Palette.GOLD)
	var effects_grid:=GridContainer.new()
	effects_grid.columns=2
	info.add_child(effects_grid)
	var effects: Dictionary=row.effects[int(p.stage)].duplicate(true)
	if not runtime.development:
		var absolute_effects: Dictionary = runtime.source523.absolute_effects(selected,p.get("absolute_grades",[]))
		for key: String in absolute_effects: effects[key] = float(effects.get(key,0))+float(absolute_effects[key])
		var grade_names: Array[String] = []
		var deferred_grades: Array[String] = []
		for grade: Variant in p.get("absolute_grades",[]):
			if runtime.source523.absolute_block(selected,int(grade)).is_empty(): grade_names.append(["I","II","III","IV","V"][int(grade)-1])
			else: deferred_grades.append(["I","II","III","IV","V"][int(grade)-1])
		if not grade_names.is_empty(): _copy("절대 옵션 "+", ".join(grade_names)+" 적용",info,13,Color("d6ead9")).name = "GrowthAbsoluteStatus"
		if not deferred_grades.is_empty(): _copy("절대 옵션 "+", ".join(deferred_grades)+" 보유 · 효과 연결 보류",info,13,Palette.MUTED)
	var visible_effects: int=0
	for key: String in effects:
		if float(effects[key])==0: continue
		_copy(_effect_text({key:effects[key]}),effects_grid,13,Color("d6ead9")).size_flags_horizontal=Control.SIZE_EXPAND_FILL
		visible_effects+=1
	if visible_effects==0: _copy("없음",effects_grid,13,Palette.MUTED).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_copy("최대 단계 달성 · 일반 강화 완료" if int(p.stage)>=30 else "다음 단계 · "+_effect_text(row.effects[int(p.stage)+1]),info,12,Palette.MUTED)
	_label("미적용: "+", ".join(row.deferred_effects) if not row.deferred_effects.is_empty() else "일반 옵션: 연결 가능한 효과 적용")
	var actions: GridContainer=action_dock
	for pair: Array in [["enhance","문양 강화 1회",1],["enhance","문양 강화 5회",5],["reroll","확률 변경",1],["reset","강화 초기화",1]]:
		var action: String = str(pair[0])
		var count: int = int(pair[2])
		var offer: Dictionary = runtime.quote(action,selected,count)
		var suffix: String=""
		if offer.ok: suffix="\n"+("%s 포인트" % int(offer.points) if int(offer.points)>0 else "두루마리 1장")
		var b := _button(str(pair[1])+suffix,func() -> void: _prepare(action,selected,count),actions)
		b.add_theme_font_size_override("font_size",14)
		var tint:=Color("203e60") if action=="reroll" else Color("583a28") if action=="reset" else Color("592b2d")
		b.add_theme_stylebox_override("normal",Palette.button(tint.darkened(.3)))
		b.add_theme_stylebox_override("hover",Palette.button(tint))
		b.add_theme_stylebox_override("pressed",Palette.button(tint.lightened(.15)))
		b.name = "GrowthAction_"+action+str(count)
		b.tooltip_text = str(offer.message)
		b.disabled = not bool(offer.ok)
		_bind_action_image(b, action, selected, offer)
		_label(str(pair[1])+": "+str(offer.message))
	if not runtime.development:
		_label(runtime.history.status(selected))
		for action: String in ["save_emblem","restore_emblem"]:
			var offer: Dictionary=runtime.quote(action,selected)
			var history_button:=_button("강화 정보 보관 · 자체 정책" if action=="save_emblem" else "보관 기록 복구 · 자체 정책",func() -> void: _prepare(action,selected,1))
			history_button.name="GrowthHistory_"+action
			history_button.disabled=not offer.ok
			history_button.tooltip_text=str(offer.message)
			_label(str(offer.message))
	_label("절대 옵션 I~V · 30단계 완성 후 강화")
	if runtime.development:
		var absolute := _button("열쇠 · 절대 옵션 확정 강화",func() -> void: _prepare("absolute",selected,1))
		absolute.disabled = not runtime.quote("absolute",selected).ok
		_label("개발용 절대 옵션 %d / 5 · HP +5" % int(p.get("absolute",0)))
	else:
		var native_grades: Array = p.get("absolute_grades",[])
		var absolute_grid := GridContainer.new()
		absolute_grid.columns = 2
		body.add_child(absolute_grid)
		for grade: int in range(1,6):
			var native_grade: int = grade
			var payment: Dictionary = runtime.source523.absolute(selected,grade).payment
			for action: String in ["absolute_chance","absolute"]:
				var native_action: String = action
				var offer: Dictionary = runtime.quote(action,selected,grade)
				var caption: String = "절대 %d · %d 포인트 (%.1f%%)" % [grade,int(payment.OpenCost),float(payment.OpenProbability)/10000.0] if action=="absolute_chance" else "절대 %d · 열쇠 %d개 확정" % [grade,int(payment.ForceOpenCost)]
				var button: Button = _button(caption,func() -> void: _prepare(native_action,selected,native_grade),absolute_grid)
				button.disabled = not bool(offer.ok)
				button.tooltip_text = str(offer.message)
				button.name = "GrowthAbsolute_"+action+str(grade)
		for line: String in runtime.source523.options_text(selected,int(p.stage),native_grades): _label(line)
		_label("절대 옵션은 I부터 순서대로 개방합니다. 미연결 효과가 있는 등급은 보류합니다.")

func _effect_text(effects: Dictionary) -> String:
	var mapping: Dictionary = {"max_hp:flat":"HP","max_mp:flat":"MP","ac:flat":"AC","mr:flat":"MR","sp:flat":"SP","weight_bonus:flat":"무게","experience_bonus:percent":"경험치 %","potion_flat:flat":"물약 회복량","potion_percent:percent":"물약 회복률 %","damage_reduction:flat":"리덕션","potion_cooldown:percent":"물약 쿨타임 감소 %","blessing_consumption:percent":"축복 소모 감소 %","incoming_reduction:percent":"피해 감소 %","mp_regeneration:flat":"MP 회복","blessing_charge:percent":"축복 충전 %"}
	mapping.merge({"melee_hit:flat":"근거리 명중","ranged_hit:flat":"원거리 명중","magic_hit:flat":"마법 명중","melee_damage:flat":"근거리 대미지","ranged_damage:flat":"원거리 대미지","magic_damage:flat":"마법 대미지","str:flat":"STR","dex:flat":"DEX","con:flat":"CON","int:flat":"INT","wis:flat":"WIS","melee_critical_rate:percent":"근거리 치명타 %","ranged_critical_rate:percent":"원거리 치명타 %","melee_critical_damage:flat":"근거리 치명타 대미지","ranged_critical_damage:flat":"원거리 치명타 대미지","magic_critical_damage:flat":"마법 치명타 대미지","pve_damage_reduction:flat":"PvE 리덕션"})
	mapping.merge({"magic_heal:percent":"회복 마법량 %","hp_drain:flat":"HP 흡수","life:flat":"생명","critical_reduction:flat":"치명타 리덕션","stunned_reduction:flat":"스턴 상태 리덕션","low_hp_reduction:percent":"HP 30% 이하 피해 감소 %","stun_hit:percent":"스턴 적중 %","stun_resistance:percent":"스턴 내성 %","fear_resistance:percent":"공포 내성 %","melee_critical_damage:flat":"근거리 치명타 대미지","ranged_critical_damage:flat":"원거리 치명타 대미지","magic_critical_damage:flat":"마법 치명타 대미지"})
	mapping["teleport_control:flag"]="순간이동 조종"
	mapping.merge({"pve_damage_reduction:flat":"PVE 리덕션","pve_damage_reduction:percent":"PVE 피해 감소 %","pve_melee_damage:flat":"PVE 근거리 대미지","pve_ranged_damage:flat":"PVE 원거리 대미지","pve_magic_damage:flat":"PVE 마법 대미지"})
	mapping.merge({"veil_proc:percent":"실렌 장막 발동 %","melee_reduction_ignore:flat":"단독 근거리 리덕션 무시","ranged_reduction_ignore:flat":"단독 원거리 리덕션 무시","magic_reduction_ignore:flat":"단독 마법 리덕션 무시","pve_reduction_ignore:flat":"PVE 리덕션 무시","melee_evasion_ignore:flat":"단독 근거리 회피 무시","ranged_evasion_ignore:flat":"단독 원거리 회피 무시","local_death:flat":"자체 죽음","local_damage_damp:percent":"자체 연속피격 감소 %","local_ignore:percent":"자체 감소 무시 %","local_melee_ignore:percent":"자체 근거리 감소 무시 %","local_ranged_ignore:percent":"자체 원거리 감소 무시 %","local_magic_ignore:percent":"자체 마법 감소 무시 %","local_rapid_reduction:flat":"자체 보스 연사 리덕션","local_armorbreak_melee:percent":"자체 돌진 피해 감소 %","local_armorbreak_dark:percent":"자체 암흑 피해 감소 %","local_armorbreak_magic:percent":"자체 마법 피해 감소 %","local_reduction_efficiency:percent":"자체 감소 효율 %"})
	var parts: Array[String] = []
	for key: String in effects:
		if key.begins_with("local_") and not runtime.Combat.estimates():continue
		if float(effects[key]) != 0: parts.append("%s %+d" % [str(mapping.get(key,key)),int(effects[key])])
	return "없음" if parts.is_empty() else " · ".join(parts)

func _guardian() -> void:
	if not runtime.state.pending.is_empty() or not last_reveal.is_empty():
		_card_selection()
		return
	_copy("수호성 · 능력치 상시 적용 / 발동 스킬은 분류별 지정" if not runtime.development else "대표 수호성 · "+str(runtime.node(runtime.state.representative).get("name","미설정")),body,17,Palette.GOLD)
	_copy("슬롯 선택 → 비용 확인 → 카드 직접 선택 · 좌우로 움직여 연결도 확인" if not runtime.development else "개발용 수호성 연결도",body)
	for group: Dictionary in runtime.config.guardians:
		if group.id != selected: continue
		var board := ScrollContainer.new()
		board.name = "GuardianSourceBoard"
		board.custom_minimum_size.y = 580 if not runtime.development else 340
		board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		body.add_child(board)
		if not runtime.development:
			var rep: String = runtime.guardian_representative(int(group.category_id))
			_label("분류 발동 스킬: "+str(runtime.node(rep).get("name","미설정")))
			if int(group.server_limit_set_id)!=0: _label("서버별 제공 조건 확인 중 · 이 분류는 개방 보류")
		chart = preload("res://scripts/growth/growth_constellation.gd").new()
		board.add_child(chart)
		chart.configure(runtime,group.nodes,hud,scroll,selected_node,_show_node)
		if runtime.development: _label("개발용 연결도 · 1회 수호석 1개 / 카드 3장 / 노드당 HP 5 · 원작값 아님")
		if not selected_node.is_empty(): _node_detail(runtime.node(selected_node))
		if not runtime.development:
			_label("이 분류의 기록된 수호석 지출 %d · 게임 다이아 %d" % [runtime.guardian_spent(int(group.category_id)),int(runtime.world.inventory.get("다이아",0))])
			if OS.is_debug_build():_label("개발 검증 전용 다이아 %d · 게임 재화와 별도" % int(runtime.state.get("guardian_wallet",{}).get("4",0)))
			_guardian_action("guardian_reset",str(group.id),"이 분류 초기화 · 기록된 수호석 환급")
			_guardian_action("guardian_buy_coins","","명예 코인 재료 상점 · 10개")
			_button("수호성 원본 UI551 자료 설치" if not preload("res://scripts/growth/guardian_media.gd").installed() else "원본 광원 설치됨 · 다시 선택",_open_guardian_media).name="GuardianInstallOriginalMedia"
			if OS.is_debug_build():_guardian_action("guardian_debug_gems","","개발 검증용 다이아 +%d" % int(runtime.guardian_local_rules.development.gem_grant))

func _card_selection() -> void:
	var pending: bool=not runtime.state.pending.is_empty()
	var node_id: String=str(runtime.state.pending.node if pending else last_reveal.node)
	var search: Dictionary=runtime.state.searches[node_id]
	var count: int=int(search.cards)
	var title: Label=_copy("✦  수호성 찾기  ✦",body,22,Palette.GOLD)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var subtitle: Label=_copy(str(runtime.node(node_id).name),body,14,Palette.TEXT)
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var provenance: Label=_copy("원본 카드 장식 연결 대기 · 번호와 결과로 선택",body,12,Palette.MUTED)
	provenance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var status: Label=_copy("카드를 선택해주세요 · 남은 선택지 %d / %d" % [count-search.failed.size(),count] if pending else "슬롯 개방 성공" if last_reveal.won else "개방 실패 · 선택한 카드는 다음 도전에서 제외",body,14,Palette.GOLD if pending else Color("9bdfdb") if last_reveal.won else Color("d59a9b"))
	status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var centered:=HBoxContainer.new()
	body.add_child(centered)
	for side: int in range(2):
		var spacer:=Control.new()
		spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		centered.add_child(spacer)
		if side==1: break
		var cards:=GridContainer.new()
		cards.name="GuardianCards"
		cards.columns=mini(3,count)
		cards.add_theme_constant_override("h_separation",16)
		centered.add_child(cards)
		for index: int in range(count):
			var b:=_button("",func() -> void: _choose_card(index),cards)
			b.name="GuardianCard_"+str(index)
			b.custom_minimum_size=Vector2(132,184)
			for state: String in ["normal","hover","pressed","disabled","focus"]:
				b.add_theme_stylebox_override(state,Palette.plate(Color.TRANSPARENT,Color.TRANSPARENT,0))
			var face:=CardFace.new()
			card_faces[index]=face
			face.failed=search.failed.has(index)
			face.selected=not pending and int(last_reveal.index)==index
			face.success=face.selected and bool(last_reveal.won)
			face.authored_art=false
			b.mouse_entered.connect(func() -> void: face.set_interaction(true))
			b.mouse_exited.connect(func() -> void: face.set_interaction(false))
			b.feedback_changed.connect(face.set_interaction)
			b.add_child(face)
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			face.offset_bottom=-24
			b.disabled=not pending or face.failed
			var caption:=UI.label("선택 불가 · 실패" if face.failed else "개방 성공" if face.success else "선택 가능 %d" % (index+1),13,Palette.MUTED if face.failed else Palette.GOLD)
			caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.add_child(caption)
			caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			caption.offset_top=-23
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var detail: Label=_copy(("카드 선택 시 수호석 %d개 소모 · 닫아도 선택 대기 상태가 저장됩니다." % int(runtime.node(node_id).cost) if runtime.guardian_source.has_node(node_id) else "이번 도전 비용 차감 완료 · 닫아도 선택 대기 상태가 저장됩니다.") if pending else "결과와 실패 카드 이력 저장 완료",body,12)
	detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not pending:
		action_dock.columns=2
		if not last_reveal.won:
			_button("다시 도전 · 비용 확인",func() -> void: _prepare("activate",node_id,1),action_dock).name="GuardianRetry"
		_button("수호성 목록",func() -> void: last_reveal={}; _refresh(),action_dock).name="GuardianReturn"

func _choose_card(index: int) -> void:
	if submitting: return
	var offer: Dictionary=runtime.quote("choose","",index)
	if not offer.ok:
		result.visible=true; result.text=str(offer.message)
		return
	if runtime.guardian_source.has_node(str(runtime.state.pending.node)):
		_prepare("choose","",index)
		return
	request={"action":"choose","id":"","count":index,"revision":int(offer.revision)}
	_confirm()

func _show_node(id: String) -> void:
	last_reveal={}
	selected_node = id
	_refresh()

func _node_detail(row: Dictionary) -> void:
	_label(str(row.name))
	var id: String = str(row.id)
	var source: bool = runtime.guardian_source.has_node(id)
	if source:
		var level: int = runtime.guardian_level(id)
		_label("1회 수호석 %d개 · 카드 %d장 · Lv.%d / %d" % [int(row.cost),int(row.cards),level,int(row.max_level)])
		var previous: Array[String] = []
		for prerequisite: String in row.prerequisites: previous.append(str(runtime.node(prerequisite).name))
		_label("선행: "+("없음" if previous.is_empty() else " → ".join(previous)))
		_label("능력치: "+_effect_text(runtime.guardian_source.effects(id,level)))
		var detail: String = runtime.guardian_source.detail(id,level)
		if not detail.is_empty(): _label(detail)
		var compatibility: String=runtime.guardian_combat.pve_numeric_detail(id)
		if not compatibility.is_empty():_label(compatibility).name="GuardianPveNumericCompatibility"
		if int(row.max_level)>level:
			_label("다음 강화: "+runtime.guardian_source.detail(id,level+1))
	else:
		var chance: Variant = row.get("proc_percent")
		_label("발동 확률: "+("미확인" if chance == null else str(chance)+"%")+" · 피해/회복 수치 미확인")
	var actions: Array[String] = ["activate","representative"]
	if source and int(row.max_level)>0: actions.append("guardian_enchant")
	if source and row.kind=="active":actions.append("guardian_cast")
	for action: String in actions:
		var offer: Dictionary = runtime.quote(action,id)
		var title: String = "활성화" if action == "activate" else "수호성 강화" if action == "guardian_enchant" else "사용 스킬 시전" if action=="guardian_cast" else "분류 발동 스킬 지정" if source else "대표 설정"
		var b := _button(title,func() -> void: _prepare(action,id,1))
		b.name = "GuardianAction_"+action
		b.disabled = not bool(offer.ok)
		_bind_action_image(b, action, id, offer)
		var hint: Label=_label(str(offer.message))
		guardian_controls.append({"button":weakref(b),"hint":weakref(hint),"action":action,"id":id})

func _prepare(action: String, id: String, count: int) -> void:
	if submitting: return
	var offer: Dictionary = runtime.quote(action,id,count)
	result.visible = true
	result.text = str(offer.message)
	if not offer.ok: return
	if action == "choose":
		for index: int in range(int(runtime.state.pending.cards)):
			var card: Button = find_child("GuardianCard_"+str(index),true,false)
			if card != null:
				card.modulate=Color.WHITE if index==count else Color(.6,.6,.7)
				card_faces[index].selected=index==count
				card_faces[index].queue_redraw()
	request = {"action":action,"id":id,"count":count,"revision":int(offer.revision),"day":int(offer.get("day",-1))}
	for child: Node in confirmation.get_children(): confirmation.remove_child(child); child.queue_free()
	_label(str(offer.message)+"\n진행하시겠습니까?",confirmation)
	var confirm_button: Button = _button("확인",_confirm,confirmation)
	confirm_button.name = "GrowthConfirm"
	_bind_action_image(confirm_button, action, id, offer)
	_button("취소",func() -> void: request={}; _refresh(); result.text="취소됨 · 재료 차감 없음",confirmation).name = "GrowthCancel"
	# Bring confirmation into view on short landscape Android windows.
	call_deferred("_scroll_confirmation")

func _scroll_confirmation() -> void:
	# Scroll after the new confirmation has participated in container layout.
	# A deferred call alone can still see the previous scrollbar maximum.
	if not is_inside_tree(): return
	await get_tree().process_frame
	if is_instance_valid(confirmation) and is_instance_valid(scroll) and confirmation.get_child_count()>0:
		var button: Control=confirmation.find_child("GrowthConfirm",true,false)
		scroll.ensure_control_visible(button if button != null else confirmation)

func _confirm() -> void:
	if submitting or request.is_empty(): return
	submitting = true
	var current: Dictionary = request.duplicate()
	request = {}
	var previous_stage: int=int(runtime.progress(selected).stage) if mode=="emblems" else 0
	var pending_node: String = str(runtime.state.pending.get("node",""))
	var response: Dictionary = runtime.execute(current.action,current.id,int(current.count),int(current.revision),int(current.get("day",-1)))
	if response.ok and current.action=="choose":
		last_reveal={"node":pending_node,"index":int(current.count),"won":runtime.state.nodes.has(pending_node)}
	elif response.ok and current.action=="activate": last_reveal={}
	_refresh()
	result.visible = current.action!="choose"
	result.text = str(response.message)
	if response.ok and current.action=="activate":
		for face: Control in card_faces.values():preload("res://scripts/growth/guardian_timeline.gd").play(face,"open")
	elif response.ok and current.action=="choose" and card_faces.has(int(current.count)):
		preload("res://scripts/growth/guardian_timeline.gd").play(card_faces[int(current.count)],"success" if last_reveal.won else "failure")
	elif response.ok and current.action=="guardian_enchant":
		preload("res://scripts/growth/guardian_timeline.gd").play(result,"success" if str(response.message).contains("강화 성공") else "failure")
		if str(response.message).contains("강화 성공") and is_instance_valid(chart):chart.play_original_enchant(str(current.id))
	if response.ok and current.action in ["enhance","absolute"] and is_instance_valid(diagram): diagram.reveal(previous_stage)
	if response.ok and current.action in ["choose","representative"] and is_instance_valid(chart): chart.reveal()
	if response.ok and mode=="guardians":
		var cue: String=""
		match str(current.action):
			"activate":cue="open"
			"choose":cue="success" if last_reveal.won else "failure"
			"guardian_enchant":cue="success" if str(response.message).contains("강화 성공") else "failure"
			"representative":cue="representative"
			"guardian_reset":cue="reset"
		if not cue.is_empty():guardian_presentation.play_confirmed(cue)
	# A second release in this frame cannot create another transaction.
	if response.ok and current.action in ["enhance","absolute"]:
		# Only presentation waits. Close/back always remains available.
		var timer:=get_tree().create_timer(1.3)
		timer.timeout.connect(_release_submit)
	else: call_deferred("_release_submit")

func _release_submit() -> void:
	submitting = false

func _guardian_presentation_settings() -> void:
	_copy("TWILIGHT 자체 카드 표시·효과음 · 원본 아님 (원본 광원은 별도 유지)",body,12,Palette.MUTED).name="GuardianAuthoredNotice"
	var settings:=HBoxContainer.new()
	body.add_child(settings)
	var prefs: Dictionary=guardian_presentation.preferences
	for entry: Array in [["cards","자체 카드",not bool(prefs.cards)],["sounds","자체 효과음",not bool(prefs.sounds)],["volume","음량",((floori(float(prefs.volume)/25.0)+1)*25)%125]]:
		var key: String=entry[0]
		var next: Variant=entry[2]
		var text: String=str(entry[1])+": "+(str(prefs.volume)+"%" if key=="volume" else "켜짐" if prefs[key] else "꺼짐")
		_button(text,func() -> void:_save_guardian_presentation(key,next),settings).name="GuardianPresentation_"+key

func _save_guardian_presentation(key: String,value: Variant) -> void:
	var saved: bool=guardian_presentation.save_preference(key,value)
	_refresh();result.visible=true
	result.text="TWILIGHT 자체 표현 설정 저장됨" if saved else "표현 설정 저장 실패 · 이전 설정 유지"

func _draw() -> void:
	set_meta("original_growth_background",{"status":"source_background_role_pending"})
	draw_rect(Rect2(Vector2.ZERO,size),Color(.01,.012,.025,.45))
	var tint: Color=Art.COLORS[Art.index(selected)] if mode=="emblems" else Color("4e82a9")
	for layer: int in range(8):
		var radius: float=minf(size.x*.4,size.y*.65)-layer*12
		if radius>0: draw_circle(size*Vector2(.38,.46),radius,Color(tint,.012))

func _guardian_action(action: String,id: String,title: String) -> void:
	var button: Button=_button(title,func() -> void:_prepare(action,id,1))
	button.name="GuardianAction_"+action
	var quote: Dictionary=runtime.quote(action,id)
	button.disabled=not quote.ok
	var hint: Label=_label(str(quote.message))
	guardian_controls.append({"button":weakref(button),"hint":weakref(hint),"action":action,"id":id})

func _process(delta: float) -> void:
	guardian_clock-=delta
	if guardian_clock>0 or runtime==null:return
	guardian_clock=.25
	for entry: Dictionary in guardian_controls:
		var button: Button=entry.button.get_ref()
		var hint: Label=entry.hint.get_ref()
		if not is_instance_valid(button) or not is_instance_valid(hint):continue
		var quote: Dictionary=runtime.quote(entry.action,entry.id)
		button.disabled=not quote.ok or submitting
		hint.text=str(quote.message)

func _open_guardian_media() -> void:
	var dialog:=FileDialog.new()
	dialog.name="GuardianOriginalMediaFile"
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.filters=PackedStringArray(["*.zip ; UI551 원본 ZIP / 광원 팩","*.dat ; 원본 UI128.dat"])
	dialog.title="수호성 원본 UI551 ZIP 또는 UI128.dat 선택"
	for button: Button in [dialog.get_ok_button(),dialog.get_cancel_button()]:button.set_script(preload("res://scripts/ui/native_touch_button.gd"))
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:_install_guardian_media(path);dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered_ratio(.8)
func _install_guardian_media(path: String) -> void:
	var installed: Dictionary=preload("res://scripts/growth/guardian_media.gd").install(path)
	_refresh();result.visible=true;result.text=str(installed.message)
