extends VBoxContainer
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Touch = preload("res://scripts/ui/inventory_settings_touch.gd")
const CATEGORY = preload("res://scripts/warehouse/equipment_category_selection.gd")
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")
var hud: Node
var world: Node
var service
var category
var config: Dictionary
var selector: OptionButton
var enabled: CheckBox
var grade: OptionButton
var slot: OptionButton
var marking: OptionButton
var max_enchant: SpinBox
var permit_custom: CheckBox
var candidates_box: VBoxContainer
var status: Label
var scroll: ScrollContainer
var selected_targets: Dictionary = {}
var candidate_buttons: Dictionary = {}
var candidates: Array[Dictionary] = []
var slot_keys: Array = CATEGORY.SLOTS.keys()

func button(text: String, callback: Callable, name_: String = "") -> Button:
	var node: Button = UI.button(text,callback,Vector2(0,38))
	node.set_script(Touch)
	node.inventory_scroll = scroll
	node.name = name_ if name_ != "" else "CategoryAction"
	return node
func label(text: String) -> Label:
	var node: Label = UI.label(text,12,UI.TEXT)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node
func checkbox(text: String) -> CheckBox:
	var node := CheckBox.new()
	node.text = text
	node.set_script(Touch)
	node.inventory_scroll = scroll
	return node

func configure(controller: Node, selector_id: int) -> void:
	hud = controller
	world = hud.get_parent()
	service = world.inventory_automation
	category = service.equipment_categories
	config = category.settings(selector_id)
	for target: Dictionary in config.targets: selected_targets[target.id] = target.duplicate(true)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	body.add_child(label("원본의 네 항목은 판매 분류용 표시입니다. 아래 등급·슬롯·강화·표기 조건은 TWILIGHT 자체 설정입니다. 새로 얻은 장비는 자동 체크하지 않습니다. 저장하면 이전 자체 범주 ID를 이번 선택으로 교체하며 별도 자동 대상은 유지합니다."))
	selector = OptionButton.new()
	selector.name = "EquipmentCategoryOrigin"
	for id: int in CATEGORY.SELECTORS:
		selector.add_item(CATEGORY.SELECTORS[id].label,id)
		if id == selector_id: selector.select(selector.item_count-1)
	selector.item_selected.connect(func(_index: int) -> void:
		config = category.settings(selector.get_selected_id())
		selected_targets.clear()
		for target: Dictionary in config.targets: selected_targets[target.id] = target.duplicate(true)
		_restore_filters()
		_refresh())
	body.add_child(selector)
	enabled = checkbox("TWILIGHT 자체 범주 선택 사용 · 현재 소지 ID만")
	enabled.name = "EquipmentCategoryEnabled"
	body.add_child(enabled)
	grade = OptionButton.new()
	grade.name = "EquipmentCategoryGrade"
	for value: String in CATEGORY.GRADES: grade.add_item(value)
	body.add_child(label("자체 조건 · 정확한 등급 / 장비 슬롯 / 각인·보호 표기 / 강화 상한"))
	body.add_child(grade)
	slot = OptionButton.new()
	slot.name = "EquipmentCategorySlot"
	slot.add_item("장비 슬롯을 직접 선택하세요")
	for value: String in slot_keys: slot.add_item(CATEGORY.SLOTS[value])
	body.add_child(slot)
	marking = OptionButton.new()
	marking.name = "EquipmentCategoryMarking"
	for value: String in ["각인·보호 표기 없는 항목","각인·귀속·거래제한 표기 항목","모두 보기 (기존 보호 유지)"]: marking.add_item(value)
	body.add_child(marking)
	max_enchant = SpinBox.new()
	max_enchant.name = "EquipmentCategoryEnchant"
	max_enchant.min_value = 0
	max_enchant.max_value = 20
	max_enchant.step = 1
	max_enchant.prefix = "자체 강화 상한 +"
	body.add_child(max_enchant)
	permit_custom = checkbox("이 자체 범주를 위해 원본 ID 전용 모드 해제 허용")
	permit_custom.name = "EquipmentCategoryPermitCustom"
	permit_custom.visible = bool(service.state.get("source_only",false))
	body.add_child(permit_custom)
	body.add_child(label("잠금·장착·귀속·각인·퀘스트·거래제한은 해제하지 않습니다. 이미 따로 등록한 장비는 기존 남김 규칙을 유지합니다. 각 ID는 1개씩 판매합니다."))
	status = label("")
	body.add_child(status)
	body.add_child(button("소지 목록 새로 확인",_refresh,"EquipmentCategoryRefresh"))
	candidates_box = VBoxContainer.new()
	candidates_box.name = "EquipmentCategoryCandidates"
	body.add_child(candidates_box)
	body.add_child(button("선택 ID·조건 저장 · 판매 안 함",func() -> void: _preview(false),"EquipmentCategoryActivate"))
	body.add_child(button("전체 판매 카트 확인",func() -> void: _preview(true),"EquipmentCategoryCart"))
	body.add_child(button("자체 범주 해제 · 별도 대상 유지",func() -> void:
		_report(category.disable())
		config = category.settings(selector.get_selected_id())
		selected_targets.clear()
		_restore_filters()
		_refresh(),"EquipmentCategoryDisable"))
	body.add_child(button("원본·정비로 돌아가기",func() -> void: hud.open_inventory_automation_settings("sell")))
	_restore_filters()
	for control: OptionButton in [grade,slot,marking]:
		control.item_selected.connect(func(_index: int) -> void: selected_targets.clear(); _refresh())
	max_enchant.value_changed.connect(func(_value: float) -> void: selected_targets.clear(); _refresh())
	_refresh()

func _restore_filters() -> void:
	enabled.set_pressed_no_signal(bool(config.enabled))
	grade.select(CATEGORY.GRADES.find(config.grade))
	slot.select(slot_keys.find(config.slot)+1 if config.slot != "" else 0)
	marking.select(int(config.marking))
	max_enchant.set_value_no_signal(float(config.max_enchant))
	permit_custom.set_pressed_no_signal(false)

func selection() -> Dictionary:
	var next: Dictionary = config.duplicate(true)
	next["enabled"] = enabled.button_pressed
	next["grade"] = grade.get_item_text(grade.selected)
	next["slot"] = "" if slot.selected == 0 else str(slot_keys[slot.selected-1])
	next["marking"] = marking.selected
	next["max_enchant"] = int(max_enchant.value)
	next["targets"] = []
	for id: String in selected_targets: next.targets.append(selected_targets[id].duplicate(true))
	return next

func _refresh() -> void:
	for child: Node in candidates_box.get_children(): candidates_box.remove_child(child); child.queue_free()
	candidate_buttons.clear()
	# Listing is available before activation; activation remains a separate,
	# explicit user choice. Invalid/no slot produces an empty list.
	var filters: Dictionary = selection()
	filters["enabled"] = false
	filters["targets"] = []
	candidates = category.candidates(filters)
	var found: Dictionary = {}
	for entry: Dictionary in candidates:
		found[entry.id] = true
		var control: CheckBox = checkbox("ID %s · %s/%s · +%d %s · %d 아데나%s" % [entry.id,entry.grade,CATEGORY.SLOTS[entry.slot],int(entry.level),entry.name,int(entry.payment)," · "+entry.reason if not entry.ok else ""])
		control.name = "EquipmentID_"+entry.id
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.clip_text = true
		control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		control.custom_minimum_size.y = 40
		control.tooltip_text = control.text+"\n"+entry.price_basis
		control.disabled = not entry.ok
		control.set_pressed_no_signal(selected_targets.has(entry.id))
		_bind_candidate_image(control,str(entry.id))
		control.toggled.connect(func(checked: bool) -> void:
			if checked: selected_targets[entry.id] = {"name":entry.name,"id":entry.id,"identity":entry.identity}
			else: selected_targets.erase(entry.id)
			_status())
		candidates_box.add_child(control)
		candidate_buttons[entry.id] = control
	# Saved missing IDs remain explicit stale entries until the user unchecks
	# them or changes/refreshes their selection; never substitute another ID.
	var stale: Array = []
	for id: String in selected_targets:
		if not found.has(id): stale.append(id)
	for raw: Variant in stale:
		var id: String = str(raw)
		var remove: Button = button("소지/조건 불일치 ID "+id+" · 선택에서 제외",func() -> void: selected_targets.erase(id); _refresh())
		candidates_box.add_child(remove)
	_status()

func _bind_candidate_image(control: CheckBox, instance_id: String) -> void:
	if not SOURCE_IMAGES.selected(): return
	# Candidate IDs are physical instance keys. Only the same saved item's
	# preserved record can supply an original ItemClass presentation.
	var physical: Variant = world.item_instances.get(instance_id)
	if not physical is Dictionary or not physical.get("record") is Dictionary: return
	var record: Dictionary = physical.record
	if not SOURCE_IMAGES.handles_item(record): return
	var image: Dictionary = SOURCE_IMAGES.describe_item(record)
	control.icon = image.get("texture") as Texture2D
	control.expand_icon = true
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	evidence["physical_instance_id"] = instance_id
	control.set_meta("source523_image",evidence)

func _status() -> void:
	status.text = "현재 조건 %d개 · 직접 선택 %d개\n기존 자동 판매 대상도 최종 카트에 함께 표시됩니다. 전체 내역·수량·가격을 확인해주세요." % [candidates.size(),selected_targets.size()]

func _preview(sale: bool) -> void:
	var snapshot: Dictionary = selection().duplicate(true)
	var allow_custom: bool = permit_custom.button_pressed
	var plan: Dictionary = category.preview(snapshot,allow_custom)
	if not plan.get("ok",false): _report(plan); return
	var lines: Array[String] = ["TWILIGHT 자체 범주 · %s / %s / 강화 +%d 이하\n이전 자체 범주 ID는 교체합니다. 별도 자동 대상 + 지금 직접 선택한 ID의 전체 카트입니다." % [snapshot.grade,CATEGORY.SLOTS[snapshot.slot],int(snapshot.max_enchant)]]
	if service.state.get("source_only",false): lines.append("확인 시 원본 ID 전용 모드를 해제합니다.")
	for entry: Dictionary in plan.cart: lines.append("%s%s ×%d · %d 아데나 · %s" % [entry.name," ["+entry.id+"]" if entry.id != "" else "",int(entry.quantity),int(entry.payment),entry.price_basis])
	for skipped: String in plan.skipped: lines.append("제외 · "+skipped)
	lines.append("합계 %d 아데나" % int(plan.payment))
	if not sale: lines.append("이번 확인은 대상·조건 저장만 합니다. 아이템은 판매하지 않습니다.")
	var stamp: String = plan.stamp
	var dialog := preload("res://scripts/ui/auto_inventory_confirmation.gd").new()
	for child: Node in hud.get_node("Root").get_children():
		if child.name == "TwilightConfirmation" and not child.is_queued_for_deletion(): return
	if hud.pointer_transfer != null: hud.pointer_transfer.cancel()
	hud.get_node("Root").add_child(dialog)
	dialog.configure("자체 범주 판매 내역" if sale else "자체 범주 대상 확인","\n".join(lines),"모두 팔기" if sale else "선택 ID·조건 저장",func(_amount: int) -> void:
		var result: Dictionary = category.execute(snapshot,stamp,allow_custom) if sale else category.activate(snapshot,stamp,allow_custom)
		_report(result)
		if result.get("ok",false):
			config = category.settings(int(snapshot.selector_id))
			selected_targets.clear()
			for target: Dictionary in config.targets: selected_targets[target.id] = target.duplicate(true)
			_restore_filters()
			permit_custom.visible = bool(service.state.get("source_only",false))
		_refresh())
	dialog.bind_source_cart(world,plan.cart)

func _report(result: Dictionary) -> void:
	hud.show_message("판매 완료" if result.get("ok",false) and result.has("cart") else "조건·ID 저장 완료" if result.get("ok",false) else str(result.get("reason","처리할 수 없습니다")))
