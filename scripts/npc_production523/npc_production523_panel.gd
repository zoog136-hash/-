extends VBoxContainer
## Original 523 NPC production window in the existing workspace, opened from
## the 제작 window (the craft function a town NPC dialogue's last page opens).
## The original LuckyDefence HUD pads (Hud_Defense_AttackPad_*,
## Hud_Defense_Combination_*_Btn) are in-match HUD parts with no stand-alone
## window, so this panel only calls the service
## (docs/npc_production523_missing_rules.md).
const SERVICE = preload("res://scripts/npc_production523/npc_production523_service.gd")
const RULES = preload("res://scripts/npc_production523/npc_production523_rules.gd")
var hud: Node
var status: Label
var body: VBoxContainer
var scroll_host: ScrollContainer

static func open(owner_hud: Node) -> Node:
	owner_hud.call("_open_window","npc_production523","NPC 생산 (디펜스 유닛)","원본523 NpcProduction 소환·조합 · 원본 표에 있는 규칙만")
	var scroll := ScrollContainer.new()
	scroll.name = "NpcProduction523Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	owner_hud.workspace.mount(scroll)
	var view: Node = load("res://scripts/npc_production523/npc_production523_panel.gd").new()
	scroll.add_child(view)
	view.configure(owner_hud)
	return view

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
	name = "NpcProduction523Panel"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation",8)
	status = _label("",self)
	status.name = "NpcProductionStatus"
	body = VBoxContainer.new()
	body.name = "NpcProductionBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(body)
	refresh()

func world() -> Node:
	return hud.get_parent()

func refresh() -> void:
	for child: Node in body.get_children(): child.queue_free()
	var snapshot: Dictionary = SERVICE.snapshot(world())
	if not snapshot.installed:
		_label("원본 523 정의 ZIP이 설치되지 않아 NPC 생산을 보류합니다.",body)
		return
	var currency_name: String = str(snapshot.currency.get("currency_name","재화"))
	_label("%s %d · 원본 LuckyDefence 아군 유닛 소환·조합%s" % [currency_name,int(snapshot.currency_owned)," (※ 원본 523에서는 이 콘텐츠가 꺼져 있습니다 · ContentsControl LuckyDefence)" if snapshot.contents_enabled!=true else ""],body)
	_label("[소환] 비용을 내고 원본 NpcProductionGenerationOutput 확률로 유닛 1개. 확률 합계가 100%가 아니면 나머지는 실패(재화 소모).",body)
	for row: Dictionary in snapshot.summons:
		_button("%s · %s %d · 성공 %s (%d종)" % [str(row.name),currency_name,int(row.cost),str(row.chance),int(row.outputs)],"Summon_%d" % int(row.summon_id),body,_summon.bind(int(row.summon_id)),int(snapshot.currency_owned)>=int(row.cost) and not snapshot.save_blocked)
	_label("[보유 유닛]",body)
	if snapshot.units.is_empty(): _label("없음",body)
	for row: Dictionary in snapshot.units: _label("%s × %d" % [str(row.name),int(row.count)],body)
	_label("[조합] 원본 NpcProductionCombinationInput 유닛을 모두 소모해 결과 유닛 1개.",body)
	for row: Dictionary in snapshot.combinations:
		var box := VBoxContainer.new()
		body.add_child(box)
		_label("→ %s · 재료 %s" % [", ".join(row.outputs),", ".join(row.inputs)],box)
		_button("조합 %d" % int(row.combination_id),"Combine_%d" % int(row.combination_id),box,_combine.bind(int(row.combination_id)),bool(row.ready) and not snapshot.save_blocked)
	_label("[합성] " + " / ".join(snapshot.merges),body)

func _show(result: Dictionary) -> void:
	status.text = str(result.get("detail","")) if result.get("ok",false) else str(result.get("reason","실패"))
	if result.get("ok",false) and hud.has_method("append_log"): hud.append_log(status.text)
	refresh()

func _summon(summon_id: int) -> void:
	_show(SERVICE.summon(world(),summon_id))

func _combine(combination_id: int) -> void:
	_show(SERVICE.combine(world(),combination_id))
