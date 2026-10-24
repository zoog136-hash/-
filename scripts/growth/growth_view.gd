extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Art = preload("res://scripts/growth/growth_art.gd")
const CardFace = preload("res://scripts/growth/growth_card_face.gd")
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
var last_reveal: Dictionary = {}
var action_dock: GridContainer
var chart: Control
var card_faces: Dictionary = {}
var diagram: Control

func configure(owner_hud: Node, section: String) -> void:
	hud = owner_hud
	runtime = hud.get_parent().growth
	mode = section
	selected = "eva" if mode == "emblems" else "joe"
	name = "GrowthView"
	resized.connect(queue_redraw)
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
	scroll.add_theme_stylebox_override("panel",UI.box(Color(0,0,0,.15),Color("746044"),8))
	add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	scroll.add_child(body)
	action_dock=GridContainer.new()
	action_dock.name="GrowthActionDock"
	action_dock.columns=4
	add_child(action_dock)
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
	for child: Node in action_dock.get_children(): action_dock.remove_child(child); child.queue_free()
	card_faces.clear()
	diagram=null; chart=null
	var balance: String="축복 포인트 %d  ·  수호석 %d" % [int(runtime.state.points),int(runtime.world.inventory.get("수호석",0))]
	if runtime.development: balance+="   |   개발용 근사 · 원작 수치 아님 · 별도 저장"
	_label(balance)
	var tabs := GridContainer.new()
	tabs.columns = 7 if mode == "emblems" else 6
	body.add_child(tabs)
	tabs.visible=mode=="emblems" or (runtime.state.pending.is_empty() and last_reveal.is_empty())
	var rows: Array = runtime.config.get(mode,[])
	for row: Dictionary in rows:
		var id: String = str(row.id)
		var button: Button = _button(str(row.name).replace("의 문양",""),func() -> void: _select(id),tabs)
		button.name = "GrowthTab_"+id
		button.add_theme_stylebox_override("normal",UI.tab_frame(id==selected))
		button.add_theme_font_size_override("font_size",14)
	if mode == "emblems": _emblem()
	else: _guardian()
	confirmation = VBoxContainer.new()
	confirmation.name = "GrowthConfirmation"
	body.add_child(confirmation)
	if mode!="guardians" or (runtime.state.pending.is_empty() and last_reveal.is_empty()):
		_button("축복 포인트 상점 · 열쇠 1개",func() -> void: _prepare("buy_key","",1))
		_button("축복의 성수(중) 사용",func() -> void: _prepare("holy_water","",1)).name = "GrowthHolyWater"
		_button("수호석 제작 · 일반 주문서",func() -> void: _prepare("craft_stone","",1))
		_button("수호석 제작 · 각인 주문서",func() -> void: _prepare("craft_stone_engraved","",1))
		_label("출처: NC 공식 문양/수호성 가이드 및 확률 안내 (2026-10-24 확인)\n전체 노드 복원·특화 옵션·미확인 전투 효과는 미완료입니다.")

func _select(id: String) -> void:
	if mode=="emblems" and selected!=id: runtime.rerolls.clear()
	selected=id
	last_reveal={}
	selected_node=""
	_refresh()

func _emblem() -> void:
	var row: Dictionary = runtime.emblem(selected)
	var p: Dictionary = runtime.progress(selected)
	var overview := HBoxContainer.new()
	body.add_child(overview)
	diagram = Diagram.new()
	diagram.stage = int(p.stage)
	diagram.sigil_index = Art.index(selected)
	overview.add_child(diagram)
	var panel:=PanelContainer.new()
	panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel",UI.box(Color(0.015,.018,.035,.8),Color("55465d"),10))
	overview.add_child(panel)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(info)
	_label("%s · %d단계 · 강화 %d / 20회\n강화 사용 포인트 %d (초기화 시 환급)" % [str(row.name),int(p.stage),int(p.attempts),int(p.spent)],info)
	var odds: Array = runtime.probabilities(selected)
	var odds_row:=HBoxContainer.new()
	info.add_child(odds_row)
	for index: int in range(3):
		var column:=VBoxContainer.new()
		column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		odds_row.add_child(column)
		_label("+%d  %.2f%%" % [index+1,float(odds[index])],column)
		var bar:=ProgressBar.new()
		bar.custom_minimum_size=Vector2(40,5)
		bar.show_percentage=false; bar.value=float(odds[index])
		bar.add_theme_stylebox_override("background",UI.box(Color("24202c"),Color.TRANSPARENT,0))
		bar.add_theme_stylebox_override("fill",UI.box([Color("d9d5d5"),Color("42adf5"),Color("d95469")][index],Color.TRANSPARENT,0))
		column.add_child(bar)
	_label("현재 적용: "+_effect_text(row.effects[int(p.stage)]),info)
	_label("다음 단계: "+_effect_text(row.effects[mini(30,int(p.stage)+1)]),info)
	_label("미적용: "+", ".join(row.deferred_effects))
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
		b.add_theme_stylebox_override("normal",UI.box(tint.darkened(.3),UI.BRONZE,4))
		b.add_theme_stylebox_override("pressed",UI.box(tint.lightened(.15),UI.GOLD,4))
		b.name = "GrowthAction_"+action+str(count)
		b.tooltip_text = str(offer.message)
		b.disabled = not bool(offer.ok)
		_label(str(pair[1])+": "+str(offer.message))
	_label("절대 옵션 I~V · 2026-03-18 확정 강화 추가")
	_label("확정 강화 열쇠 비용: "+str(row.absolute_key_costs)+" · 열쇠 1개 = 1,000 축복 포인트")
	var absolute := _button("열쇠 · 절대 옵션 확정 강화",func() -> void: _prepare("absolute",selected,1))
	absolute.disabled = not runtime.quote("absolute",selected).ok
	_label("절대 옵션 %d / 5 · %s" % [int(p.get("absolute",0)),str(runtime.quote("absolute",selected).message)])
	_label("30단계 필요 · 확률 강화 성공률 10% 확인 · 전체 효과/환급 규칙 미확인으로 일반 플레이 잠금 / 개발 모드 확정 강화 지원")

func _effect_text(effects: Dictionary) -> String:
	var mapping: Dictionary = {"max_hp:flat":"HP","max_mp:flat":"MP","ac:flat":"AC","mr:flat":"MR","sp:flat":"SP","weight_bonus:flat":"무게","experience_bonus:percent":"경험치 %","potion_flat:flat":"물약 회복량","potion_percent:percent":"물약 회복률 %","damage_reduction:flat":"리덕션","potion_cooldown:percent":"물약 쿨타임 감소 %","blessing_consumption:percent":"축복 소모 감소 %","incoming_reduction:percent":"피해 감소 %","mp_regeneration:flat":"MP 회복","blessing_charge:percent":"축복 충전 %"}
	var parts: Array[String] = []
	for key: String in effects:
		if float(effects[key]) != 0: parts.append("%s %+d" % [str(mapping.get(key,key)),int(effects[key])])
	return "없음" if parts.is_empty() else " · ".join(parts)

func _guardian() -> void:
	if not runtime.state.pending.is_empty() or not last_reveal.is_empty():
		_card_selection()
		return
	_label("대표: "+str(runtime.node(runtime.state.representative).get("name","미설정")))
	_label("노드 선택 → 활성화 → 카드 → 대표 설정 · 원본 배치는 미확인")
	for group: Dictionary in runtime.config.guardians:
		if group.id != selected: continue
		chart = preload("res://scripts/growth/growth_constellation.gd").new()
		body.add_child(chart)
		chart.configure(runtime,group.nodes,hud,scroll,selected_node,_show_node)
		if runtime.development: _label("개발용 연결도 · 1회 수호석 1개 / 카드 3장 / 노드당 HP 5 · 원작값 아님")
		if not selected_node.is_empty(): _node_detail(runtime.node(selected_node))

func _card_selection() -> void:
	var pending: bool=not runtime.state.pending.is_empty()
	var node_id: String=str(runtime.state.pending.node if pending else last_reveal.node)
	var search: Dictionary=runtime.state.searches[node_id]
	var count: int=int(search.cards)
	_label("수호성 찾기 · "+str(runtime.node(node_id).name))
	_label("카드를 선택해주세요 · 남은 선택지 %d / %d" % [count-search.failed.size(),count] if pending else "선택 결과 · %s" % ("슬롯 개방 성공" if last_reveal.won else "실패 · 선택한 카드는 다음 도전에서 제외"))
	_label("이번 도전 비용은 이미 차감됐습니다. 선택 전 닫아도 대기 상태가 저장됩니다." if pending else "결과와 실패 카드 이력이 저장됐습니다.")
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
		cards.add_theme_constant_override("h_separation",12)
		centered.add_child(cards)
		for index: int in range(count):
			var b:=_button("",func() -> void: _choose_card(index),cards)
			b.name="GuardianCard_"+str(index)
			b.custom_minimum_size=Vector2(120,172)
			b.add_theme_stylebox_override("normal",UI.box(Color(0,0,0,.1),Color("493d52"),3))
			var face:=CardFace.new()
			card_faces[index]=face
			face.failed=search.failed.has(index)
			face.selected=not pending and int(last_reveal.index)==index
			face.success=face.selected and bool(last_reveal.won)
			b.add_child(face)
			face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			face.offset_bottom=-24
			b.disabled=not pending or face.failed
			var caption:=UI.label("실패 · 제외" if face.failed else "개방 성공" if face.success else "카드 %d" % (index+1),14,UI.GOLD)
			caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.add_child(caption)
			caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			caption.offset_top=-23
			caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if not pending:
		if not last_reveal.won:
			_button("다시 도전 · 비용 확인",func() -> void: _prepare("activate",node_id,1)).name="GuardianRetry"
		_button("수호성 목록",func() -> void: last_reveal={}; _refresh()).name="GuardianReturn"

func _choose_card(index: int) -> void:
	if submitting: return
	var offer: Dictionary=runtime.quote("choose","",index)
	if not offer.ok: return
	request={"action":"choose","id":"","count":index,"revision":int(offer.revision)}
	_confirm()

func _show_node(id: String) -> void:
	last_reveal={}
	selected_node = id
	_refresh()

func _node_detail(row: Dictionary) -> void:
	_label(str(row.name))
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
	var previous_stage: int=int(runtime.progress(selected).stage) if mode=="emblems" else 0
	var pending_node: String = str(runtime.state.pending.get("node",""))
	var response: Dictionary = runtime.execute(current.action,current.id,int(current.count),int(current.revision))
	if response.ok and current.action=="choose":
		last_reveal={"node":pending_node,"index":int(current.count),"won":runtime.state.nodes.has(pending_node)}
	elif response.ok and current.action=="activate": last_reveal={}
	_refresh()
	result.visible = current.action!="choose"
	result.text = str(response.message)
	if response.ok and current.action in ["enhance","absolute"] and is_instance_valid(diagram): diagram.reveal(previous_stage)
	if response.ok and current.action in ["choose","representative"] and is_instance_valid(chart): chart.reveal()
	# A second release in this frame cannot create another transaction.
	if response.ok and current.action in ["enhance","absolute"]:
		# Only presentation waits. Close/back always remains available.
		var timer:=get_tree().create_timer(1.3)
		timer.timeout.connect(_release_submit)
	else: call_deferred("_release_submit")

func _release_submit() -> void:
	submitting = false

func _draw() -> void:
	draw_texture_rect(Art.BACKDROP,Rect2(Vector2.ZERO,size),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(.01,.012,.025,.45))
