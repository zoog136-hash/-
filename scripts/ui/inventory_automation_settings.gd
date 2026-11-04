extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Touch = preload("res://scripts/ui/inventory_settings_touch.gd")
var hud: Node
var world: Node
var service
var mode: String
var source_status: Label
var source_only: CheckBox
var list: ItemList
var details: Label
var register: Button
var fallback: SpinBox
var category_action: Button
var price_action: Button
var keep: SpinBox
var store: CheckBox
var sell: CheckBox
var timeout: SpinBox
var portal_choice: OptionButton
var maintenance_status: Label
var file_dialog: FileDialog
var source_rows: Array = []
var local_portals: Array = []
var selected: int = -1

func _button(caption: String, callback: Callable) -> Button:
	var button: Button = UI.button(caption,callback,Vector2(0,36))
	button.set_script(Touch)
	return button

func _label(text: String) -> Label:
	var label: Label = UI.label(text,12,UI.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label

func configure(controller: Node, operation: String) -> void:
	hud = controller
	world = hud.get_parent()
	service = world.inventory_automation
	mode = operation
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	# Build in a temporary column, then mount it in the scroll container.
	source_status = _label("")
	var install: Button = _button("523 원본 규칙 ZIP 설치",_choose_file)
	install.name = "Inventory523Install"
	add_child(install)
	source_only = CheckBox.new()
	source_only.set_script(Touch)
	source_only.text = "원본 ID·축복이 맞는 자동 대상만 처리"
	source_only.button_pressed = bool(service.state.get("source_only",false))
	source_only.toggled.connect(func(enabled: bool) -> void:
		var result: Dictionary = service.set_source_only(enabled)
		_report(result)
		source_only.set_pressed_no_signal(bool(service.state.get("source_only",false))))
	add_child(source_only)
	var selection := OptionButton.new()
	selection.add_item("원본 보관 대상")
	selection.add_item("원본 판매 대상")
	selection.selected = 0 if mode == "deposit" else 1
	selection.item_selected.connect(func(index: int) -> void:
		mode = "deposit" if index == 0 else "sell"
		_refresh())
	add_child(selection)
	list = ItemList.new()
	list.name = "Inventory523Candidates"
	list.set_script(preload("res://scripts/ui/native_touch_list.gd"))
	list.custom_minimum_size.y = 150
	list.item_selected.connect(_select)
	add_child(list)
	category_action = _button("TWILIGHT 자체 범주 · 현재 장비 ID 직접 선택",func() -> void:
		if selected >= 0: hud.open_equipment_category_settings(int(source_rows[selected].ItemClassID)))
	category_action.name = "InventoryEquipmentCategory"
	category_action.hide()
	add_child(category_action)
	details = _label("")
	var row := HBoxContainer.new()
	add_child(row)
	keep = SpinBox.new()
	keep.min_value = 0
	keep.max_value = 1000000
	keep.step = 1
	keep.prefix = "남길 수량 "
	row.add_child(keep)
	register = _button("선택한 소지품 등록",_register)
	register.name = "Inventory523Register"
	row.add_child(register)
	fallback = SpinBox.new()
	fallback.min_value = 0
	fallback.max_value = 1000000000
	fallback.step = 1
	fallback.prefix = "미확인 매입가 자체값 "
	add_child(fallback)
	price_action = _button("자체값 저장 · 확인된 원본가는 유지",_save_price)
	add_child(price_action)
	_label("가방 정비 → 기존 이동진 이용 (TWILIGHT 자체 동작)")
	_label("현재 가방/창고 메뉴 거래를 사용합니다. 원본 M의 창고 NPC 좌표·스케줄 활성화를 추정하지 않습니다.")
	var settings: Dictionary = service.maintenance.settings()
	store = CheckBox.new()
	store.set_script(Touch)
	store.text = "먼저 자동 보관"
	store.button_pressed = settings.deposit
	add_child(store)
	sell = CheckBox.new()
	sell.set_script(Touch)
	sell.text = "이어서 자동 판매"
	sell.button_pressed = settings.sell
	add_child(sell)
	portal_choice = OptionButton.new()
	portal_choice.name = "MaintenancePortal"
	add_child(portal_choice)
	timeout = SpinBox.new()
	timeout.min_value = 1
	timeout.max_value = 600
	timeout.step = 1
	timeout.value = settings.timeout_seconds
	timeout.prefix = "자체 대기 제한(초) "
	add_child(timeout)
	var start: Button = _button("한 번 정비 예약 · 이동진으로 걷기",_arm)
	start.name = "MaintenanceStart"
	add_child(start)
	add_child(_button("정비 예약 취소",func() -> void: _report(service.maintenance.cancel()); _refresh_maintenance()))
	maintenance_status = _label("")
	add_child(_button("현재 보관/판매 대상 설정 비우기",func() -> void: _report(service.clear(mode)); _refresh()))
	add_child(_button("창고/판매로 돌아가기",func() -> void:
		if mode == "deposit": hud.open_warehouse()
		else: hud.open_item_sell()))
	var controls: Array[Node] = get_children().duplicate()
	for control: Node in controls:
		if control != scroll: control.reparent(body)
	for button: Node in body.find_children("*","Button",true,false):
		if button.get_script() == Touch: button.inventory_scroll = scroll
	_refresh()

func _report(result: Dictionary) -> void:
	hud.show_message("설정 저장 완료" if result.get("ok",false) else str(result.get("reason","설정할 수 없습니다")))

func _choose_file() -> void:
	file_dialog = FileDialog.new()
	file_dialog.name = "Inventory523FileDialog"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.zip","TWILIGHT 523 원본 규칙")
	file_dialog.file_selected.connect(func(path: String) -> void:
		_report(service.source_rules.install_zip(path))
		_refresh()
		file_dialog.queue_free())
	file_dialog.canceled.connect(func() -> void: file_dialog.queue_free())
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(.85)

func _refresh() -> void:
	list.clear()
	source_rows.clear()
	selected = -1
	var data: Dictionary = service.source_rules.document
	source_status.text = service.source_rules.problem if data.is_empty() else "523 원본 보관84행·매입25행 · 현재 도감 정확 ID 연결43/9행 · 확인 가격11종"
	source_only.set_pressed_no_signal(bool(service.state.get("source_only",false)))
	for row: Dictionary in data.get("storage_rows" if mode == "deposit" else "sell_rows",[]):
		source_rows.append(row)
		var definition: Dictionary = service.source_rules.definition(str(int(row.ItemClassID)))
		list.add_item("#%d %s%s" % [int(row.ItemClassID),str(definition.label)," · 축복ID%d" % int(row.ItemBlessCodeID) if mode == "deposit" else ""])
	if not source_rows.is_empty(): list.select(0); _select(0)
	else:
		details.text = "원본 규칙을 설치하면 전체 정의와 정확한 ID 연결을 확인할 수 있습니다."
		register.disabled = true
		price_action.disabled = true
	_refresh_maintenance()

func _held(row: Dictionary) -> Dictionary:
	var wanted: int = int(row.ItemClassID)
	var bless: int = int(row.get("ItemBlessCodeID",1))
	for raw: Variant in world.inventory:
		var name: String = str(raw)
		if int(world.inventory[raw]) <= 0: continue
		var record: Dictionary = world._find_catalog_item_record(name)
		var resolved: Dictionary = service.source_rules.resolve(record)
		if not resolved.is_empty() and int(resolved.item.id) == wanted and int(resolved.bless) == bless and service.source_rules.eligible(resolved,mode): return record
	return {}

func _select(index: int) -> void:
	if index < 0 or index >= source_rows.size(): return
	selected = index
	var row: Dictionary = source_rows[index]
	var id: String = str(int(row.ItemClassID))
	var item: Dictionary = service.source_rules.definition(id)
	var held: Dictionary = _held(row)
	keep.value = 0
	for target: Dictionary in service.state.get(mode,[]):
		if not held.is_empty() and target.name == held.name and str(target.get("id","")) == "":
			keep.value = int(target.get("keep",0))
			break
	var policy: Dictionary = item.price
	var unit: int = int(policy.get("adena",service.state.get("native_prices",{}).get(id,preload("res://scripts/shop/local_buyback.gd").GRADE_BUYBACK.get(str(item.grade),0))))
	fallback.prefix = "원본·공개 확인 매입가 " if not policy.is_empty() else "미확인 매입가 자체값 "
	fallback.value = unit
	fallback.visible = mode == "sell" and not item.virtual
	price_action.visible = fallback.visible
	fallback.editable = mode == "sell" and item.merchant_auto and not item.virtual and policy.is_empty()
	price_action.disabled = not fallback.editable
	register.disabled = held.is_empty()
	category_action.visible = mode == "sell" and bool(item.virtual)
	details.text = "#%s %s\n%s" % [id,str(item.label),"범주 선택자 · 실제 아이템 등록 안 함" if item.virtual else "원본 TestItem · 자동 처리 보류" if item.test_item else ("소지: "+str(held.name) if not held.is_empty() else "일치하는 소지품 없음 · 이름 추정 연결 안 함")]
	if mode == "sell" and not item.virtual: details.text += "\n매입 %d 아데나 · %s" % [unit,"원본·공개 확인값" if not policy.is_empty() else "자체값(수정 가능)"]

func _register() -> void:
	if selected < 0: return
	var item: Dictionary = _held(source_rows[selected])
	if item.is_empty(): return
	_report(service.set_target(mode,str(item.name),"",true,int(keep.value)))
	_refresh()

func _save_price() -> void:
	if selected < 0: return
	_report(service.set_native_price(str(int(source_rows[selected].ItemClassID)),int(fallback.value)))
	_select(selected)

func _refresh_maintenance() -> void:
	portal_choice.clear()
	local_portals = service.maintenance.portals()
	var settings: Dictionary = service.maintenance.settings()
	for index: int in range(local_portals.size()):
		portal_choice.add_item(str(local_portals[index].get("name",local_portals[index].id)))
		if str(local_portals[index].id) == str(settings.portal_id): portal_choice.selected = index
	maintenance_status.text = service.maintenance.status if service.maintenance.status != "" else ("예약됨 · 재확인 필요" if settings.armed else "정비 예약 없음")
	if local_portals.is_empty(): maintenance_status.text += "\n현재 맵에 확인된 이동진이 없습니다. 원본 M 이동은 기존 이동 작업의 검증이 필요합니다."

func _arm() -> void:
	if portal_choice.selected < 0 or portal_choice.selected >= local_portals.size():
		hud.show_message("확인된 이동진을 선택해주세요")
		return
	var plan: Dictionary = service.maintenance.preview(store.button_pressed,sell.button_pressed)
	if not plan.get("ok",false): _report(plan); return
	var id: String = str(local_portals[portal_choice.selected].id)
	_confirm("로컬 이동진 한 번 정비","선택 대상에 남길 수량을 유지하며 보관 → 판매 순서로 처리합니다.\n이동 중 새로 얻은 선택 스택도 포함됩니다. 장비는 선택한 고유 ID만 처리합니다.\n설정 변경·취소·실패·시계 역행 시 중지하고, 재시작 후에는 다시 확인해야 합니다.","예약하고 걷기",func(_amount: int) -> void:
		var result: Dictionary = service.maintenance.arm(id,store.button_pressed,sell.button_pressed,int(timeout.value))
		_report(result)
		if result.get("ok",false): hud._close_workspace()
		else: _refresh_maintenance())

func _confirm(title: String, description: String, action: String, accept: Callable) -> void:
	var root: Node = hud.get_node("Root")
	for child: Node in root.get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return
	if hud.pointer_transfer != null: hud.pointer_transfer.cancel()
	var dialog := preload("res://scripts/ui/auto_inventory_confirmation.gd").new()
	root.add_child(dialog)
	dialog.configure(title,description,action,accept)
