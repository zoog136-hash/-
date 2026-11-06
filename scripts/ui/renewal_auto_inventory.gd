extends VBoxContainer
## Shared cart controls embedded in the actual warehouse / buyback windows.
const TouchButton = preload("res://scripts/ui/native_touch_button.gd")
const UI = preload("res://scripts/ui/renewal_theme.gd")
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var host: Control
var world: Node
var hud: Node
var mode: String
var selected_label: Label
var keep: SpinBox
var select_button: Button
var remove_button: Button
var summary: Label
var target: Dictionary = {}
var selection_reference: String = ""

static func _button() -> Button:
	var button: Button = UI.button("",Callable(),Vector2(0,36))
	button.set_script(TouchButton)
	return button

func configure(screen: Control, operation: String) -> void:
	host = screen
	world = screen.world
	hud = screen.hud
	mode = operation
	name = "InventoryAutomation"
	var row := HBoxContainer.new()
	row.name = "AutoTargetActions"
	add_child(row)
	select_button = _button()
	select_button.name = "AutoSelect"
	select_button.text = "자동 대상 등록"
	select_button.pressed.connect(_select_target)
	row.add_child(select_button)
	remove_button = _button()
	remove_button.name = "AutoRemove"
	remove_button.text = "대상 해제"
	remove_button.pressed.connect(_remove_target)
	row.add_child(remove_button)
	keep = SpinBox.new()
	keep.name = "AutoKeep"
	keep.min_value = 0
	keep.max_value = 1000000
	keep.step = 1
	keep.prefix = "남길 수량 "
	keep.tooltip_text = "등록할 때 적용합니다. 0이면 선택한 소지 수량 전체를 담습니다."
	row.add_child(keep)
	selected_label = Label.new()
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_font_size_override("font_size",12)
	add_child(selected_label)
	var actions := HBoxContainer.new()
	actions.name = "AutoActions"
	add_child(actions)
	var fill: Button = _button()
	fill.name = "AutoFill"
	fill.text = "자동 담기 · 내역 확인"
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.pressed.connect(_fill)
	actions.add_child(fill)
	var clear: Button = _button()
	clear.name = "AutoClear"
	clear.text = "원본·정비"
	clear.pressed.connect(func() -> void: hud.open_inventory_automation_settings(mode))
	actions.add_child(clear)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size",12)
	add_child(summary)
	refresh()

func refresh() -> void:
	target = {}
	if mode == "sell" and host.selected >= 0 and host.selected < host.entries.size(): target = host.entries[host.selected]
	elif mode == "deposit" and host.mode.selected == 0 and host.selected_index >= 0 and host.selected_index < host.entries.size(): target = host.entries[host.selected_index]
	var reference: String = str(target.get("name",""))+"@@@"+str(target.get("instance_id","")) if not target.is_empty() else ""
	if reference != selection_reference:
		selection_reference = reference
		keep.value = 0
		for rule: Dictionary in world.inventory_automation.state.get(mode,[]):
			if str(rule.name)+"@@@"+str(rule.get("id","")) == reference: keep.value = int(rule.get("keep",0))
	select_button.disabled = target.is_empty()
	remove_button.disabled = target.is_empty()
	_refresh_target_image()
	keep.editable = not target.is_empty() and str(target.get("instance_id","")) == ""
	if not keep.editable: keep.value = 0
	if not target.is_empty():
		var chosen: bool = world.inventory_automation.contains(mode,str(target.name),str(target.get("instance_id","")))
		selected_label.text = "%s%s · %s" % [str(target.name)," ["+str(target.instance_id)+"]" if str(target.get("instance_id","")) != "" else "", "자동 대상" if chosen else "미등록"]
	else: selected_label.text = "소지품에서 자동 처리할 대상을 선택하세요."
	var rules: Array = world.inventory_automation.state.get(mode,[])
	var captions: Array[String] = []
	for rule: Dictionary in rules:
		captions.append(str(rule.name)+(" ["+str(rule.id)+"]" if str(rule.get("id","")) != "" else "")+" · 남김 %d" % int(rule.get("keep",0)))
	summary.text = "자동 %s %d항목 · 설정 저장됨\n%s\n%s" % ["보관" if mode == "deposit" else "판매",rules.size(),", ".join(captions) if not captions.is_empty() else "대상을 직접 등록하세요.","TWILIGHT 기존 매입가 적용 · 잠금/장착/귀속/퀘스트 보호" if mode == "sell" else "잠금/장착/퀘스트 보호 · 개별 장비 상태 보존"]
	# Keep long saved lists inspectable without pushing controls off small screens.
	summary.max_lines_visible = 3
	summary.tooltip_text = summary.text

func _refresh_target_image() -> void:
	# The existing warehouse/sale row carries the same authoritative record
	# already used by its icon. Do not reconstruct an identity from its caption.
	select_button.icon = null
	if select_button.has_meta("source523_image"): select_button.remove_meta("source523_image")
	var record: Variant = target.get("record")
	if not record is Dictionary or not SOURCE_IMAGES.handles_item(record): return
	var image: Dictionary = SOURCE_IMAGES.describe_item(record,str(target.get("name","")))
	select_button.icon = image.get("texture") as Texture2D
	select_button.expand_icon = true
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	select_button.set_meta("source523_image",evidence)

func _report(result: Dictionary) -> void:
	if not result.get("ok",false): hud.show_message(str(result.get("reason","설정할 수 없습니다")))
	else: hud.show_message("자동 처리 설정 저장 완료")

func _select_target() -> void:
	refresh()
	if target.is_empty(): return
	_report(world.inventory_automation.set_target(mode,str(target.name),str(target.get("instance_id","")),true,int(keep.value)))
	selection_reference = ""
	refresh()

func _remove_target() -> void:
	refresh()
	if target.is_empty(): return
	_report(world.inventory_automation.set_target(mode,str(target.name),str(target.get("instance_id","")),false))
	selection_reference = ""
	refresh()

func _fill() -> void:
	var plan: Dictionary = world.inventory_automation.preview(mode)
	if not plan.get("ok",false):
		_report(plan)
		return
	var lines: Array[String] = []
	for entry: Dictionary in plan.cart:
		lines.append("%s%s ×%d%s" % [str(entry.name)," ["+str(entry.id)+"]" if str(entry.id) != "" else "",int(entry.quantity)," · %d 아데나 · %s" % [int(entry.payment),str(entry.get("price_basis",""))] if mode == "sell" else ""])
	for message: String in plan.skipped: lines.append("제외 · "+message)
	if plan.cart.is_empty():
		hud.show_message("처리할 아이템이 없습니다"+(" · "+" / ".join(plan.skipped) if not plan.skipped.is_empty() else ""))
		return
	if mode == "sell": lines.append("합계 %d 아데나 · 각 항목의 가격 근거 확인" % int(plan.payment))
	var stamp: String = plan.stamp
	_confirm("자동 %s 내역" % ("보관" if mode == "deposit" else "판매"),"\n".join(lines),"모두 맡기기" if mode == "deposit" else "모두 팔기",func(_amount: int) -> void:
		var result: Dictionary = world.inventory_automation.execute(mode,stamp)
		if not result.get("ok",false): _report(result)
		if is_instance_valid(host):
			host._refresh()
			refresh(),plan.cart)

func _confirm(title: String, description: String, action: String, accept: Callable, cart: Array = []) -> void:
	var root: Node = hud.get_node("Root")
	for dialog: Node in root.get_children():
		if dialog.name == "TwilightConfirmation" and not dialog.is_queued_for_deletion(): return
	if hud.pointer_transfer != null: hud.pointer_transfer.cancel()
	var dialog := preload("res://scripts/ui/auto_inventory_confirmation.gd").new()
	root.add_child(dialog)
	dialog.configure(title,description,action,accept)
	dialog.bind_source_cart(world,cart)
