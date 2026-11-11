extends VBoxContainer
## 용해 (축복의 가루) and 질서의 연금 window in the existing workspace. The
## original Refine/Enchant_All CSB windows are not bound yet (see
## docs/bless_refine523_missing_rules.md); this panel only calls the service.
const SERVICE = preload("res://scripts/refine523/bless_refine523_service.gd")
var hud: Node
var status: Label
var body: VBoxContainer
var selected: Dictionary = {}
var scroll_host: ScrollContainer

func _label(text: String, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(text: String, node_name: String, parent: Node, callback: Callable, enabled: bool = true) -> Button:
	var value := Button.new()
	value.name = node_name
	value.text = text
	value.disabled = not enabled
	value.custom_minimum_size.y = 42
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.pressed.connect(func() -> void:
		if scroll_host == null or not hud.workspace.was_scroll_dragged(scroll_host): callback.call())
	parent.add_child(value)
	if scroll_host != null: hud.workspace.register_scroll_drag(scroll_host,value)
	return value

func configure(owner_hud: Node) -> void:
	hud = owner_hud
	scroll_host = get_parent() as ScrollContainer
	name = "BlessRefine523Panel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	status = _label("",self)
	status.name = "BlessRefineStatus"
	body = VBoxContainer.new()
	body.name = "BlessRefineBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)
	refresh()

func world() -> Node:
	return hud.get_parent()

func refresh() -> void:
	for child: Node in body.get_children(): child.queue_free()
	var snapshot: Dictionary = SERVICE.snapshot(world())
	if not snapshot.installed:
		_label("원본 523 정의 ZIP이 설치되지 않아 용해·질서의 연금을 보류합니다.",body)
		return
	_label("상급 축복의 가루 %d · 아데나 %d" % [int(snapshot.powder),int(snapshot.gold)],body)
	_label("[용해] 원본 BlessPowderAmount(등급·강화 수치)만큼 축복의 가루를 얻습니다. 상급·최상급 용해는 원본 표에 촉매 소모량·계산식이 없어 보류합니다.",body)
	for row: Dictionary in snapshot.dissolve:
		if not row.ok: continue
		var check := CheckBox.new()
		check.name = "Dissolve_" + str(row.uid)
		check.text = "%s → 축복의 가루 %d" % [row.label,int(row.amount)]
		check.button_pressed = selected.has(row.uid)
		check.toggled.connect(func(on: bool) -> void:
			if on: selected[row.uid] = true
			else: selected.erase(row.uid))
		body.add_child(check)
	_button("선택한 장비 용해","DissolveSelected",body,_dissolve)
	_label("[질서의 연금] 대상 장비 + 상급 축복의 가루(원본 최소·최대 등록 수량) + 아데나. 실패해도 대상 장비는 돌아오고 재료·아데나는 소모됩니다.%s" % ("" if snapshot.refine_contents_enabled==true else " ※ 원본 523에서는 이 콘텐츠가 꺼져 있습니다(ContentsControl Refine)."),body)
	for row: Dictionary in snapshot.refine:
		var box := VBoxContainer.new()
		body.add_child(box)
		_label("%s → +%d %s · 아데나 %d" % [row.label,int(row.output_enchant),str(row.output_name),int(row.cost)],box)
		var line := HBoxContainer.new()
		box.add_child(line)
		_button("최소 %d개 (%s)" % [int(row.min),str(row.min_percent)],"RefineMin_" + str(row.uid),line,_refine.bind(str(row.uid),"min"),int(snapshot.powder)>=int(row.min))
		_button("최대 %d개 (%s)" % [int(row.max),str(row.max_percent)],"RefineMax_" + str(row.uid),line,_refine.bind(str(row.uid),"max"),int(snapshot.powder)>=int(row.max))
	if snapshot.refine.is_empty(): _label("가방에 질서의 연금 대상 장비가 없습니다.",body)

func _show(result: Dictionary) -> void:
	status.text = str(result.get("detail","")) if result.get("ok",false) else str(result.get("reason","실패"))
	if result.get("ok",false) and hud.has_method("append_log"): hud.append_log(status.text)
	refresh()

func _dissolve() -> void:
	var ids: Array = selected.keys()
	selected.clear()
	_show(SERVICE.dissolve(world(),ids))

func _refine(uid: String, mode: String) -> void:
	_show(SERVICE.refine(world(),uid,mode))
