extends VBoxContainer
## 에스카로스 · 요정 숲 방어전 · 영지 퀘스트 window (world.content523).
## Plain controls: no original window CSB for these contents is in the 523
## UI add-on, and nothing is drawn in place of an original picture.
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Content = preload("res://scripts/content523/content523.gd")
var hud: Node
var scroll_host: ScrollContainer
var status: Label
var body: VBoxContainer
var last_result: Dictionary = {}

func configure(owner: Node, host: ScrollContainer = null) -> void:
	hud = owner
	scroll_host = host
	name = "Content523Panel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = UI.label("",14,UI.GOLD)
	status.name = "Content523Status"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)
	refresh()

func world() -> Node:
	return hud.get_parent() if hud != null else null

func _label(text: String, size: int = 14, color: Color = UI.TEXT) -> Label:
	var label: Label = UI.label(text,size,color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(label)
	return label

func _button(text: String, node_name: String, callback: Callable, enabled: bool = true) -> Button:
	var value: Button = UI.button(text,func() -> void:
		if scroll_host == null or hud == null or not hud.workspace.was_scroll_dragged(scroll_host): callback.call(),Vector2(0,42))
	value.name = node_name
	value.disabled = not enabled
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(value)
	if scroll_host != null and hud != null: hud.workspace.register_scroll_drag(scroll_host,value)
	return value

func _act(result: Dictionary) -> void:
	last_result = result
	var text: String = "완료" if result.get("ok",false) else str(result.get("reason","실패"))
	if result.has("reward"): text += " · " + str(result.reward)
	if result.has("granted"): text += " · " + ", ".join(result.granted)
	if hud != null and hud.has_method("show_message"): hud.show_message(text)
	refresh()
	status.text = text

func refresh() -> void:
	for child: Node in body.get_children(): child.queue_free()
	var w: Node = world()
	if w == null or w.get("content523") == null: _label("게임 연결 없음"); return
	var service: RefCounted = w.content523
	var m: Dictionary = Content.models()
	status.text = service.status_line() if not str(service.status_line()).is_empty() else "원본 523 표 기준 · 오프라인 1인"
	if not str(service.problem).is_empty(): _label("저장 보호: " + str(service.problem),14,UI.MUTED)
	_escaros(service,m.escaros)
	_elf(service,m.elf)
	_quests(service,m.tq)

func _escaros(service: RefCounted, model: Dictionary) -> void:
	_label("에스카로스",17,UI.GOLD)
	if not model.get("ok",false): _label(str(model.get("problem",""))); return
	var route: Dictionary = model.dungeon.teleport
	_label("입장: %s · %d레벨 · 아데나 %d · 원본 Land %s" % [str(model.dungeon.name),int(route.min_level),int(route.cost),str(route.land_name)])
	_button("에스카로스 입장","Escaros523Enter",func() -> void: _act(service.enter_escaros()))
	var at: Dictionary = service.here()
	for teleporter: Dictionary in model.teleporters:
		if not at.is_empty() and int(at.land_id) == int(teleporter.land_id):
			var r: Dictionary = teleporter.route
			_button("%s(%s) → %s (아데나 %d)" % [str(teleporter.name),str(teleporter.object_name),str(r.land_name),int(r.cost)],"Escaros523Teleport_%d" % int(teleporter.spawn_id),func() -> void: _act(service.use_teleporter(int(teleporter.spawn_id))))
	_label("오늘의 랜드마크 (그룹별 Prob 추첨)",15,UI.GOLD)
	for landmark: Dictionary in service.landmarks_view():
		var state_text: String = "조사 완료" if landmark.found else ("조사 가능" if landmark.near else ("%d칸" % int(landmark.distance) if int(landmark.distance) >= 0 else "다른 지역"))
		var reward: Dictionary = landmark.reward
		_button("[%s] %s (%d,%d) · %s %d · %s" % [str(landmark.group),str(landmark.name),int(landmark.cell[0]),int(landmark.cell[1]),"아인하사드" if str(reward.type) == "Einasad" else str(reward.type),int(reward.amount),state_text],
			"Escaros523Landmark_%d" % int(landmark.id),func() -> void: _act(service.examine_landmark(int(landmark.id))),landmark.near and not landmark.found)
	var touch: Dictionary = service.touchdowns()
	var parts: Array = []
	for artifact: Dictionary in model.artifacts:
		parts.append("%d라운드 %s(%d,%d) %d회" % [int(artifact.round),str(artifact.name),int(artifact.cell[0]),int(artifact.cell[1]),int(touch.get(str(int(artifact.id)),0))])
	_label("터치다운(아티팩트 %d칸 안 대기): %s · 라운드 일정·순위 보상·버프 지속 단위는 원본 표에 없어 미적용" % [int(model.artifacts[0].range) if not model.artifacts.is_empty() else 0,", ".join(parts)])

func _elf(service: RefCounted, model: Dictionary) -> void:
	_label("요정 숲 방어전",17,UI.GOLD)
	if not model.get("ok",false): _label(str(model.get("problem",""))); return
	for grade: Dictionary in model.grades:
		var r: Dictionary = grade.route
		var open: bool = int(grade.grade_no) == 0
		_button("%d단계 %s · %s · %d레벨 · 아데나 %d%s" % [int(grade.grade_no),str(grade.name),str(r.land_name),int(r.min_level),int(r.cost),"" if open else " · 승리 판정 규칙 없음"],
			"ElfForest523Enter_%d" % int(grade.id),func() -> void: _act(service.enter_elf(int(grade.id))),open)
	var chosen: int = int(service.state.elf.blessing)
	for blessing: Dictionary in model.blessings:
		_button("가호 %s%s (우위: %s)" % [str(blessing.title),(" · 선택됨" if int(blessing.id) == chosen else ""),str(blessing.advantage_title)],"ElfForest523Blessing_%d" % int(blessing.id),func() -> void: _act(service.choose_blessing(int(blessing.id))))
	_label("가호 효과(StatusEffect)·팀·승리·등급 상승 규칙은 원본 표에 없어 기록만 합니다. 승리 보상 %d단계는 받을 수 없습니다." % model.wins.size())

func _quests(service: RefCounted, model: Dictionary) -> void:
	_label("영지 퀘스트",17,UI.GOLD)
	if not model.get("ok",false): _label(str(model.get("problem",""))); return
	var progress: Dictionary = service.quest_progress()
	if not progress.is_empty():
		_label("진행 중: %s %d/%d · 남은 %d초" % [str(progress.area),int(progress.count),int(progress.need),int(progress.left)])
		_button("영지 퀘스트 완료","TerritoryQuest523Complete",func() -> void: _act(service.complete_quest()),bool(progress.done))
	for id: int in model.order:
		var quest: Dictionary = model.quests[id]
		if quest.box == [0,0,0,0]: continue
		var goal: String = ", ".join(quest.goals.map(func(g: Dictionary) -> String: return str(g.text)))
		if quest.playable:
			var key: String = str(id)
			var done: bool = int(service.state.tq.done.get(key,-1)) == service.period()
			_button("%s · %s · %d초%s" % [str(quest.land_name),goal,int(quest.timeout)," · 오늘 완료" if done else ""],"TerritoryQuest523Go_%d" % id,
				func() -> void: _act(service.travel({"land_id":int(quest.land_id),"box":quest.box,"targets":1,"other_prerequisites":[],"min_level":0,"max_level":0,"currency":1,"cost":0})),not done)
		else:
			_label("%s · %s · 오프라인 불가: %s" % [str(quest.land_name),goal,"; ".join(quest.reasons)])
