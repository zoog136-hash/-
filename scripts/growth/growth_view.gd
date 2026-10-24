extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Diagram = preload("res://scripts/growth/growth_diagram.gd")
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
var diagram: Control

func configure(owner_hud: Node, section: String) -> void:
	hud = owner_hud
	runtime = hud.get_parent().growth
	mode = section
	selected = "eva" if mode == "emblems" else "joe"
	name = "GrowthView"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	result = UI.label("",14,UI.GOLD)
	result.name = "GrowthResult"
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(result)
	scroll = ScrollContainer.new()
	scroll.name = "GrowthScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	scroll.add_child(body)
	var close := preload("res://scripts/ui/native_touch_button.gd").new()
	close.text = "닫기"
	close.name = "GrowthClose"
	close.custom_minimum_size.y = 44
	close.pressed.connect(func() -> void: hud._close_workspace())
	add_child(close)
	_refresh()

func _label(text: String, parent: Node = null) -> Label:
	if parent == null: parent = body
	var out := UI.label(text,14)
	out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(out)
	return out

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

func _refresh() -> void:
	request = {}
	for child: Node in body.get_children(): body.remove_child(child); child.queue_free()
	_label("축복 포인트 %d  ·  수호석 %d\n로컬 저장 · 미확인 비용/효과는 잠금 표시" % [int(runtime.state.points),int(runtime.world.inventory.get("수호석",0))])
	var tabs := GridContainer.new()
	tabs.columns = 7 if mode == "emblems" else 6
	body.add_child(tabs)
	var rows: Array = runtime.config.get(mode,[])
	for row: Dictionary in rows:
		var id: String = str(row.id)
		var button: Button = _button(str(row.name).replace("의 문양",""),func() -> void: selected=id; selected_node=""; _refresh(),tabs)
		button.name = "GrowthTab_"+id
		button.modulate = UI.GOLD if id == selected else Color.WHITE
	if mode == "emblems": _emblem()
	else: _guardian()
	confirmation = VBoxContainer.new()
	confirmation.name = "GrowthConfirmation"
	body.add_child(confirmation)
	_button("축복의 성수(중) 사용",func() -> void: _prepare("holy_water","",1)).name = "GrowthHolyWater"
	_button("수호석 제작 · 일반 주문서",func() -> void: _prepare("craft_stone","",1))
	_button("수호석 제작 · 각인 주문서",func() -> void: _prepare("craft_stone_engraved","",1))
	_label("출처: NC 공식 문양/수호성 가이드 및 확률 안내 (2026-10-24 확인)\n전체 노드 복원·특화 옵션·미확인 전투 효과는 미완료입니다.")

func _emblem() -> void:
	var row: Dictionary = runtime.emblem(selected)
	var p: Dictionary = runtime.progress(selected)
	var overview := HBoxContainer.new()
	body.add_child(overview)
	diagram = Diagram.new()
	diagram.stage = int(p.stage)
	overview.add_child(diagram)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.add_child(info)
	_label("%s · %d단계 · 강화 %d / 20회\n강화 사용 포인트 %d (초기화 시 환급)" % [str(row.name),int(p.stage),int(p.attempts),int(p.spent)],info)
	var odds: Array = runtime.probabilities(selected)
	_label("+1 %.2f%%    +2 %.2f%%    +3 %.2f%%" % [float(odds[0]),float(odds[1]),float(odds[2])],info)
	_label("현재 적용: "+_effect_text(row.effects[int(p.stage)]),info)
	_label("다음 단계: "+_effect_text(row.effects[mini(30,int(p.stage)+1)]),info)
	_label("미적용: "+", ".join(row.deferred_effects),info)
	var actions := GridContainer.new()
	actions.columns = 2
	body.add_child(actions)
	for pair: Array in [["enhance","문양 강화 1회",1],["enhance","문양 강화 5회",5],["reroll","확률 변경",1],["reset","강화 초기화",1]]:
		var action: String = str(pair[0])
		var count: int = int(pair[2])
		var offer: Dictionary = runtime.quote(action,selected,count)
		var b := _button(str(pair[1]),func() -> void: _prepare(action,selected,count),actions)
		b.name = "GrowthAction_"+action+str(count)
		b.tooltip_text = str(offer.message)
		b.disabled = not bool(offer.ok)
		_label(str(pair[1])+": "+str(offer.message))
	_label("절대 옵션 I~V · 2026-03-18 확정 강화 추가")
	_label("확정 강화 열쇠 비용: "+str(row.absolute_key_costs)+" · 열쇠 1개 = 1,000 축복 포인트")
	var absolute := _button("열쇠 · 절대 옵션 확정 강화",func() -> void: pass)
	absolute.disabled = true
	_label("30단계 필요 · 확률 강화 성공률 10% 확인 · 전체 효과/환급 규칙 미확인으로 두 경로 모두 잠금")

func _effect_text(effects: Dictionary) -> String:
	var mapping: Dictionary = {"max_hp:flat":"HP","max_mp:flat":"MP","ac:flat":"AC","mr:flat":"MR","sp:flat":"SP","weight_bonus:flat":"무게","experience_bonus:percent":"경험치 %","potion_flat:flat":"물약 회복량","potion_percent:percent":"물약 회복률 %","damage_reduction:flat":"리덕션"}
	var parts: Array[String] = []
	for key: String in effects:
		if float(effects[key]) != 0: parts.append("%s %+d" % [str(mapping.get(key,key)),int(effects[key])])
	return "없음" if parts.is_empty() else " · ".join(parts)

func _guardian() -> void:
	_label("대표: "+str(runtime.state.representative if not runtime.state.representative.is_empty() else "미설정"))
	if not runtime.state.pending.is_empty():
		_label("수호성 찾기 · 카드 선택 대기\n닫아도 이미 지불한 도전과 결과는 저장됩니다.")
		var cards := GridContainer.new()
		cards.columns = 3
		body.add_child(cards)
		for index: int in range(int(runtime.state.pending.cards)):
			var b := _button("✦\n카드 %d" % (index+1),func() -> void: _prepare("choose","",index),cards)
			b.name = "GuardianCard_"+str(index)
			b.disabled = runtime.state.searches[runtime.state.pending.node].failed.has(index)
			if b.disabled: b.text = "실패"
	_label("스킬 슬롯 목록 · 원본 노드 연결/배치는 미확인입니다.\n선행 슬롯 → 활성화 확인 → 카드 선택 → 결과 → 대표 설정")
	for group: Dictionary in runtime.config.guardians:
		if group.id != selected: continue
		for row: Dictionary in group.nodes:
			var id: String = str(row.id)
			var caption: String = ("◆ " if runtime.state.nodes.has(id) else "◇ ")+str(row.name)
			_button(caption,func() -> void: selected_node=id; _show_node(id)).name = "GuardianNode_"+id
			if selected_node == id: _node_detail(row)

func _show_node(id: String) -> void:
	selected_node = id
	_refresh()

func _node_detail(row: Dictionary) -> void:
	var chance: Variant = row.get("proc_percent")
	_label("발동 확률: "+("미확인" if chance == null else str(chance)+"%")+" · 피해/회복 수치 미확인")
	var id: String = str(row.id)
	for action: String in ["activate","representative"]:
		var offer: Dictionary = runtime.quote(action,id)
		var b := _button("활성화" if action == "activate" else "대표 설정",func() -> void: _prepare(action,id,1))
		b.disabled = not bool(offer.ok)
		_label(str(offer.message))

func _prepare(action: String, id: String, count: int) -> void:
	if submitting: return
	var offer: Dictionary = runtime.quote(action,id,count)
	result.text = str(offer.message)
	if not offer.ok: return
	request = {"action":action,"id":id,"count":count,"revision":int(offer.revision)}
	for child: Node in confirmation.get_children(): confirmation.remove_child(child); child.queue_free()
	_label(str(offer.message)+"\n진행하시겠습니까?",confirmation)
	_button("확인",_confirm,confirmation).name = "GrowthConfirm"
	_button("취소",func() -> void: request={}; _refresh(); result.text="취소됨 · 재료 차감 없음",confirmation).name = "GrowthCancel"
	# Bring confirmation into view on short landscape Android windows.
	call_deferred("_scroll_confirmation")

func _scroll_confirmation() -> void:
	if is_instance_valid(confirmation) and confirmation.get_child_count()>0: scroll.ensure_control_visible(confirmation)

func _confirm() -> void:
	if submitting or request.is_empty(): return
	submitting = true
	var current: Dictionary = request.duplicate()
	request = {}
	var response: Dictionary = runtime.execute(current.action,current.id,int(current.count),int(current.revision))
	_refresh()
	result.text = str(response.message)
	if response.ok and is_instance_valid(diagram): diagram.reveal()
	# A second release in this frame cannot create another transaction.
	call_deferred("_release_submit")

func _release_submit() -> void:
	submitting = false
