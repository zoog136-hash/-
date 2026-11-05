extends VBoxContainer
## Historical PR264 custom Godot form, retained only for presentation audits.
## This is not original Lineage UI and must not be mounted by production code.
var runtime
var section: String = "events"
var page_index: int = 0
var search_text: String = ""
var body: VBoxContainer
var status: Label
var picker: FileDialog
var choice_panel: VBoxContainer
const PAGE_SIZE: int = 30
const LABELS: Dictionary = {"events": "출석 · 패스 · 룰렛", "jade_grail": "용옥 · 성배 은총", "challenge": "시련 던전"}

func configure(service, initial_section: String = "events") -> void:
	runtime = service
	section = initial_section if LABELS.has(initial_section) else "events"
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	var tabs := OptionButton.new()
	toolbar.add_child(tabs)
	for key: String in LABELS:
		tabs.add_item(LABELS[key])
		tabs.set_item_metadata(tabs.item_count - 1, key)
		if key == section:
			tabs.select(tabs.item_count - 1)
	tabs.item_selected.connect(func(index: int) -> void:
		section = str(tabs.get_item_metadata(index))
		page_index = 0
		refresh())
	var install := Button.new()
	install.text = "원본523 ZIP 설치"
	toolbar.add_child(install)
	install.pressed.connect(_select_zip)
	_button(toolbar, "새로고침", func() -> void: refresh(true))
	var search := LineEdit.new()
	search.placeholder_text = "이름 · 원본 ID 검색"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(search)
	search.text_changed.connect(func(value: String) -> void:
		search_text = value
		page_index = 0
		refresh())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var scrolling := ScrollContainer.new()
	scrolling.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scrolling.custom_minimum_size = Vector2(500, 330)
	add_child(scrolling)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scrolling.add_child(body)
	refresh()

func refresh(preserve_selection: bool = false) -> void:
	if not is_instance_valid(body) or not is_instance_valid(runtime):
		return
	var retained: VBoxContainer
	if preserve_selection and is_instance_valid(choice_panel) and not choice_panel.is_queued_for_deletion() and choice_panel.get_parent() == body:
		retained = choice_panel
		body.remove_child(retained)
	else:
		choice_panel = null
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	var content: Dictionary = runtime.page(section)
	status.text = str(content.get("title", LABELS[section])) + "\n" + "\n".join(PackedStringArray(content.get("notes", [])))
	var rows: Array = []
	for row: Dictionary in content.get("rows", []):
		var text_value: String = str(row.get("label", "")) + " " + str(row.get("detail", "")) + " " + str(row.get("id", ""))
		if search_text.is_empty() or text_value.to_lower().contains(search_text.to_lower()):
			rows.append(row)
	if section in ["events", "challenge"]:
		rows = usable_first(rows)
	page_index = clampi(page_index, 0, maxi(0, int((rows.size() - 1) / PAGE_SIZE)))
	var pages := HBoxContainer.new()
	body.add_child(pages)
	_button(pages, "이전", func() -> void:
		page_index = maxi(0, page_index - 1)
		refresh()).disabled = page_index == 0
	var count := Label.new()
	count.text = "%d개 · %d / %d" % [rows.size(), page_index + 1, maxi(1, ceili(float(rows.size()) / PAGE_SIZE))]
	pages.add_child(count)
	_button(pages, "다음", func() -> void:
		page_index += 1
		refresh()).disabled = (page_index + 1) * PAGE_SIZE >= rows.size()
	for index: int in range(page_index * PAGE_SIZE, mini(rows.size(), (page_index + 1) * PAGE_SIZE)):
		var row: Dictionary = rows[index]
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 5)
		body.add_child(card)
		var title := Label.new()
		title.text = str(row.get("label", row.get("id", "")))
		title.add_theme_font_size_override("font_size", 18)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(title)
		var detail := Label.new()
		detail.text = str(row.get("detail", ""))
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(detail)
		for action: Dictionary in row.get("actions", []):
			# Bind the displayed domain and request. Tabs may change before a
			# selection or confirmation is completed.
			var button := _button(card, str(action.get("label", "선택")), _choose.bind(row.duplicate(true), action.duplicate(true), section))
			button.disabled = bool(action.get("disabled", false))
		card.add_child(HSeparator.new())
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "표시할 보유 항목이나 현재 이용 가능한 항목이 없습니다."
		body.add_child(empty)
	if is_instance_valid(retained):
		body.add_child(retained)
		body.move_child(retained,mini(1,body.get_child_count()-1))

func _choose(row: Dictionary, action: Dictionary, displayed_section: String = "") -> void:
	var selected_section: String = section if displayed_section.is_empty() else displayed_section
	var request: Dictionary = action.get("request", {}).duplicate(true)
	var requirements: Array = action.get("required_choices", [])
	if requirements.is_empty():
		_confirm(row, action, request, selected_section)
		return
	if is_instance_valid(choice_panel):
		choice_panel.queue_free()
	choice_panel = VBoxContainer.new()
	body.add_child(choice_panel)
	body.move_child(choice_panel, mini(1, body.get_child_count() - 1))
	var panel: VBoxContainer = choice_panel
	var title := Label.new()
	title.text = "보상을 직접 선택하세요"
	panel.add_child(title)
	var lists: Array = []
	for requirement: Dictionary in requirements:
		var label := Label.new()
		var minimum: int = int(requirement.get("min_count", requirement.get("count", 1)))
		var maximum: int = int(requirement.get("max_count", requirement.get("count", 1)))
		label.text = "%s · %s개 선택" % [str(requirement.get("label", "보상")), str(minimum) if minimum == maximum else "%d~%d" % [minimum, maximum]]
		panel.add_child(label)
		var list := ItemList.new()
		list.select_mode = ItemList.SELECT_MULTI
		list.custom_minimum_size = Vector2(440, 160)
		panel.add_child(list)
		for option: Dictionary in requirement.get("options", []):
			list.add_item(str(option.get("label", option.get("value", ""))))
			list.set_item_metadata(list.item_count - 1, option.get("value"))
		lists.append({"list": list, "requirement": requirement})
	_button(panel, "선택 확인", func() -> void:
		var selected_request: Dictionary = request.duplicate(true)
		var chosen_labels: Array[String] = []
		for entry: Dictionary in lists:
			var list: ItemList = entry.list
			var selected: PackedInt32Array = list.get_selected_items()
			var minimum: int = int(entry.requirement.get("min_count", entry.requirement.get("count", 1)))
			var maximum: int = int(entry.requirement.get("max_count", entry.requirement.get("count", 1)))
			if selected.size() < minimum or selected.size() > maximum:
				status.text = "선택 개수를 확인하세요"
				return
			var values: Array = []
			for index: int in selected:
				values.append(list.get_item_metadata(index))
				chosen_labels.append(list.get_item_text(index))
			var key: String = str(entry.requirement.get("key", "selection"))
			if key.begins_with("selection."):
				if not selected_request.has("selection"):
					selected_request.selection = {}
				selected_request.selection[key.trim_prefix("selection.")] = values
			else:
				selected_request[key] = values
		_confirm(row, action, selected_request, selected_section, chosen_labels))
	_button(panel, "취소", func() -> void:
		if is_instance_valid(panel):
			panel.queue_free())

func _confirm(row: Dictionary, action: Dictionary, request: Dictionary, displayed_section: String = "", chosen_labels: Array[String] = []) -> void:
	if not is_instance_valid(runtime) or not is_instance_valid(runtime.world):
		return
	var selected_section: String = section if displayed_section.is_empty() else displayed_section
	var revision: int = int(runtime.state.revision)
	var expected: String = runtime.fingerprint()
	var ctx: Dictionary = runtime.context()
	var description: String = str(row.get("detail", ""))
	if not chosen_labels.is_empty():
		description += "\n\n선택 보상: " + ", ".join(chosen_labels)
	var costs: Array = action.get("costs", [])
	for cost: Dictionary in costs:
		description += "\n비용: %d · %s %d" % [int(cost.get("amount", 0)), "재화" if cost.get("kind") == "currency" else "아이템", int(cost.get("id", 0))]
	description += "\n\n아데나 보유: %d\n확인 시 표시된 조건·비용을 다시 검사하고 보상과 함께 저장합니다." % int(ctx.get("currencies", {}).get("1", 0))
	var selected_request: Dictionary = request.duplicate(true)
	runtime.world.hud.confirm_action(str(action.get("label", "확인")), description, "확인", func(_count: int = 1) -> void:
		if not is_instance_valid(self) or is_queued_for_deletion() or not is_instance_valid(runtime) or not is_instance_valid(runtime.world):
			return
		var result: Dictionary = runtime.execute(selected_section, selected_request, revision, expected)
		runtime.world.hud.show_message("처리·저장 완료" if bool(result.get("ok", false)) else str(result.get("error", "처리 실패")))
		refresh())

func _select_zip() -> void:
	if is_instance_valid(picker):
		picker.queue_free()
	picker = FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.zip ; 원본523 공통 ZIP"])
	add_child(picker)
	picker.file_selected.connect(func(path: String) -> void:
		var result: Dictionary = runtime.source.install_zip(path)
		status.text = "원본523 설치 완료 · 게임을 완전히 종료한 후 다시 실행하세요." if bool(result.get("ok", false)) else "설치 실패 · 기존 팩 보존: " + str(result.get("error", "")))
	picker.popup_centered_ratio(0.75)

func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 38
	parent.add_child(button)
	button.pressed.connect(callback)
	return button

static func usable_first(rows: Array) -> Array:
	# Stable presentation partition: retain every row and each group's source order.
	var available: Array = []
	var remaining: Array = []
	for row: Dictionary in rows:
		var usable: bool = false
		for action: Variant in row.get("actions",[]):
			if action is Dictionary and not bool(action.get("disabled",false)):
				usable = true
				break
		if usable: available.append(row)
		else: remaining.append(row)
	available.append_array(remaining)
	return available
