extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
const Touch = preload("res://scripts/ui/inventory_settings_touch.gd")
var hud: Node
var world: Node
var service
var mode: String
var held_choice: OptionButton
var held_options: Array[Dictionary] = []
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
var automatic_status: Label
var resume_auto: CheckBox
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
	held_choice = OptionButton.new()
	held_choice.name = "Inventory523HeldIdentity"
	held_choice.item_selected.connect(func(_index: int) -> void: _update_held_selection())
	add_child(held_choice)
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
	_label("AUTO 중 게임 날짜당 1회 정비 · 현재 로컬 경로 · 이동 비용0 / 보관 비용0")
	resume_auto = CheckBox.new()
	resume_auto.set_script(Touch)
	resume_auto.name = "MaintenanceResumeAuto"
	resume_auto.text = "도착 정비 후 기존 AUTO 사냥 재개"
	resume_auto.button_pressed = bool(settings.get("automatic",{}).get("resume_auto",false))
	add_child(resume_auto)
	var automatic_start: Button = _button("자동 정비 켜기 · 대상·비용 확인",_enable_automatic)
	automatic_start.name = "MaintenanceAutomaticEnable"
	add_child(automatic_start)
	var automatic_stop: Button = _button("자동 정비 끄기",func() -> void: _report(service.maintenance.disable_automatic()); _refresh_maintenance())
	automatic_stop.name = "MaintenanceAutomaticDisable"
	add_child(automatic_stop)
	automatic_status = _label("")
	automatic_status.name = "MaintenanceAutomaticInfo"
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
	if list.has_meta("source523_images"): list.remove_meta("source523_images")
	source_rows.clear()
	selected = -1
	var data: Dictionary = service.source_rules.document
	var registration: Dictionary = service.refresh_catalog()
	source_status.text = service.source_rules.problem if data.is_empty() else "523 실제 등록 ID 연결 보관%d/84행·매입%d/25행 · 확인 가격11종" % [int(registration.get("deposit",0)),int(registration.get("sell",0))]
	if not data.is_empty(): source_status.text += "\n원본 규칙상 허용 보관%d/매입%d · 소지·잠금은 별도 검사" % [int(registration.get("deposit_allowed",0)),int(registration.get("sell_allowed",0))]
	var pending: Array[String] = []
	for missing: Dictionary in registration.get("missing",[]):
		if int(missing.id) in [235,237,313,385] and not pending.has(str(int(missing.id))): pending.append(str(int(missing.id)))
	pending.sort()
	if not pending.is_empty(): source_status.text += "\n원본 정의 확인 · 공급자 카탈로그 등록 대기: "+", ".join(pending)
	source_only.set_pressed_no_signal(bool(service.state.get("source_only",false)))
	for row: Dictionary in data.get("storage_rows" if mode == "deposit" else "sell_rows",[]):
		source_rows.append(row)
		var definition: Dictionary = service.source_rules.definition(str(int(row.ItemClassID)))
		list.add_item("#%d %s%s" % [int(row.ItemClassID),str(definition.label)," · 축복ID%d" % int(row.ItemBlessCodeID) if mode == "deposit" else ""])
		_bind_option_image(list,list.item_count-1,int(row.ItemClassID))
	if not source_rows.is_empty(): list.select(0); _select(0)
	else:
		_clear_register_image()
		details.text = "원본 규칙을 설치하면 전체 정의와 정확한 ID 연결을 확인할 수 있습니다."
		register.disabled = true
		price_action.disabled = true
	_refresh_maintenance()

func _held_matches(row: Dictionary) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	var wanted: int = int(row.ItemClassID)
	var bless: int = int(row.get("ItemBlessCodeID",1))
	for raw: Variant in world.inventory:
		var name: String = str(raw)
		if int(world.inventory[raw]) <= 0: continue
		var record: Dictionary = world._find_catalog_item_record(name)
		var resolved: Dictionary = service.source_rules.resolve(record)
		if not resolved.is_empty() and int(resolved.item.id) == wanted and int(resolved.bless) == bless and service.source_rules.eligible(resolved,mode): matches.append(record)
	return matches

func _select(index: int) -> void:
	if index < 0 or index >= source_rows.size(): return
	selected = index
	var row: Dictionary = source_rows[index]
	var id: String = str(int(row.ItemClassID))
	var item: Dictionary = service.source_rules.definition(id)
	held_options = _held_matches(row)
	held_choice.clear()
	held_choice.add_item("소지한 정확한 아이템 키를 선택하세요")
	if held_choice.has_meta("source523_images"): held_choice.remove_meta("source523_images")
	for record: Dictionary in held_options:
		held_choice.add_item(str(record.name)+" · "+_registered_key(record))
		_bind_option_image(held_choice,held_choice.item_count-1,int(row.ItemClassID))
	if held_options.size() == 1: held_choice.select(1)
	held_choice.visible = not item.virtual
	var held: Dictionary = _chosen_held()
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
	_bind_register_image(held)
	category_action.visible = mode == "sell" and bool(item.virtual)
	details.text = "#%s %s\n%s" % [id,str(item.label),"범주 선택자 · 실제 아이템 등록 안 함" if item.virtual else "원본 TestItem · 자동 처리 보류" if item.test_item else ("소지: "+str(held.name) if not held.is_empty() else "일치하는 소지품 없음 · 이름 추정 연결 안 함")]
	if mode == "sell" and not item.virtual: details.text += "\n매입 %d 아데나 · %s" % [unit,"원본·공개 확인값" if not policy.is_empty() else "자체값(수정 가능)"]

func _source_item_image(item_class_id: int) -> Dictionary:
	return SOURCE_IMAGES.describe_item_class(item_class_id) if SOURCE_IMAGES.selected() else {}

func _bind_option_image(control: Control, index: int, item_class_id: int) -> void:
	var image: Dictionary = _source_item_image(item_class_id)
	control.call("set_item_icon",index,image.get("texture") as Texture2D)
	if image.is_empty(): return
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	var images: Dictionary = control.get_meta("source523_images",{})
	images[index] = evidence
	control.set_meta("source523_images",images)

func _clear_register_image() -> void:
	register.icon = null
	if register.has_meta("source523_image"): register.remove_meta("source523_image")

func _bind_register_image(record: Dictionary) -> void:
	_clear_register_image()
	if record.is_empty() or not SOURCE_IMAGES.selected(): return
	var identity: Dictionary = service.source_rules.resolve(record)
	if identity.is_empty(): return
	var image: Dictionary = _source_item_image(int(identity.item.id))
	register.icon = image.get("texture") as Texture2D
	register.expand_icon = true
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	register.set_meta("source523_image",evidence)

func _chosen_held() -> Dictionary:
	return held_options[held_choice.selected-1] if held_choice.selected > 0 and held_choice.selected <= held_options.size() else {}

func _registered_key(record: Dictionary) -> String:
	return "shop523:item:"+str(int(record.source523_shop_item_id))+" · 일반 축복ID1" if record.get("source") == "twilight-shop523-consumable" else str(record.get("sourceId",""))

func _update_held_selection() -> void:
	var held: Dictionary = _chosen_held()
	register.disabled = held.is_empty()
	_bind_register_image(held)
	keep.value = 0
	if held.is_empty(): return
	for target: Dictionary in service.state.get(mode,[]):
		if target.name == held.name and str(target.get("id","")) == "": keep.value = int(target.get("keep",0))
	details.text = "선택한 소지 키: "+str(held.name)+" · "+_registered_key(held)+"\n각인 표기와 축복 키·동일 이름의 다른 ID는 합치지 않습니다."

func _register() -> void:
	if selected < 0: return
	var item: Dictionary = _chosen_held()
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
	var automatic: Dictionary = settings.get("automatic",{})
	var day: int = preload("res://scripts/quests/quest_service.gd").korean_daily_key(service.maintenance._now())
	automatic_status.text = "자동 정비 %s · 게임 날짜 %d · 오늘 %s\n재접속 후 AUTO를 직접 켜야 합니다. 새 장비 ID는 추가하지 않습니다." % ["켜짐" if automatic.get("enabled",false) else "꺼짐",day,"실행 시작됨" if int(automatic.get("last_started_day",-1)) >= day else "미실행"]
	maintenance_status.text = service.maintenance.status if service.maintenance.status != "" else ("예약됨 · 재확인 필요" if settings.armed else "정비 예약 없음")
	if local_portals.is_empty(): maintenance_status.text += "\n현재 맵에 확인된 이동진이 없습니다. 원본 M 이동은 기존 이동 작업의 검증이 필요합니다."

func _enable_automatic() -> void:
	if portal_choice.selected < 0 or portal_choice.selected >= local_portals.size(): hud.show_message("검증된 이동진을 선택해주세요"); return
	var plan: Dictionary = service.maintenance.preview(store.button_pressed,sell.button_pressed)
	if not plan.get("ok",false): _report(plan); return
	var id: String = str(local_portals[portal_choice.selected].id)
	var do_store: bool = store.button_pressed
	var do_sell: bool = sell.button_pressed
	var seconds: int = int(timeout.value)
	var resume: bool = resume_auto.button_pressed
	var lines: Array[String] = ["TWILIGHT 현재 맵의 기존 이동진 · 원본 M/NPC 좌표 재현 아님", "보관 → 판매 · 이동 비용0 / 보관 비용0", "AUTO 사냥 중 등록 대상이 있으면 게임 날짜당 1회 보행·정비합니다. 게임 날짜는 기존 한국05시 기준입니다.", "등록한 스택은 도착 당시 남길 수량을 유지합니다. 새 장비 ID는 추가하지 않습니다.", "기존 1회 예약은 대체합니다. 대상·가격·모드 변경 시 꺼지고, 실패/재접속 후 재확인이 필요합니다.", "도착 후 AUTO 재개: "+("켜짐" if resume else "꺼짐")]
	for entry: Dictionary in plan.cart: lines.append("%s%s ×%d · %d 아데나" % [entry.name," ["+entry.id+"]" if entry.id != "" else "",int(entry.quantity),int(entry.payment)])
	for skipped: String in plan.skipped: lines.append("제외 · "+skipped)
	lines.append("현재 예상 판매 수입 %d 아데나 · 보관대상%d/판매대상%d" % [int(plan.payment),service.state.deposit.size() if do_store else 0,service.state.sell.size() if do_sell else 0])
	var stamp: String = str(plan.stamp)
	_confirm("자동 정비 대상·비용 확인","\n".join(lines),"자동 정비 켜기",func(_amount: int) -> void:
		if stamp != service._stamp("maintenance"): hud.show_message("대상·상태가 변경됐습니다. 다시 확인해주세요"); return
		_report(service.maintenance.arm(id,do_store,do_sell,seconds,false,{"setup":true,"resume_auto":resume}))
		_refresh_maintenance(),plan.cart)

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

func _confirm(title: String, description: String, action: String, accept: Callable, cart: Array = []) -> void:
	var root: Node = hud.get_node("Root")
	for child: Node in root.get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return
	if hud.pointer_transfer != null: hud.pointer_transfer.cancel()
	var dialog := preload("res://scripts/ui/auto_inventory_confirmation.gd").new()
	root.add_child(dialog)
	dialog.configure(title,description,action,accept)
	dialog.bind_source_cart(world,cart)
