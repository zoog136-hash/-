extends VBoxContainer

# Presentation only. The authoritative runtime validates ownership, consumes
# spare cards / Adena, and persists a result before sending a fresh snapshot.
signal feed_requested(materials: Dictionary)
signal attempt_requested

const UI = preload("res://scripts/ui/renewal_theme.gd")
const TouchButton = preload("res://scripts/ui/native_touch_button.gd")
const TouchList = preload("res://scripts/ui/native_touch_list.gd")
const AwakeningBorder = preload("res://scripts/ui/option_awakening_border.gd")

var snapshot: Dictionary = {}
var selected_materials: Dictionary = {}
var pending_request: bool = false
var _pending_action: String = ""
var _settings: Dictionary = {}
var _highlighted_id: String = ""
var _material_rows: Dictionary = {}
var _review_action: String = ""
var _review_revision: int = -1
var _review_materials: Dictionary = {}
var _compact_materials: bool = false
var _built: bool = false

var _content_scroll: ScrollContainer
var _content_column: VBoxContainer
var _heading: Label
var _progress_text: Label
var _progress: ProgressBar
var _tabs: HBoxContainer
var _info_tab: Button
var _materials_tab: Button
var _main: HBoxContainer
var _info_scroll: ScrollContainer
var _info_content: VBoxContainer
var _compact_target: Label
var _target_art: TextureRect
var _border: Control
var _options: RichTextLabel
var _policy: Label
var _collections: RichTextLabel
var _materials_pane: VBoxContainer
var _material_title: Label
var _material_hint: Label
var _materials_list: ItemList
var _empty_materials: Label
var _quantity_caption: Label
var _decrease: Button
var _increase: Button
var _fill: Button
var _footer: VBoxContainer
var _selection_summary: Label
var _attempt_summary: Label
var _status: Label
var _clear: Button
var _feed: Button
var _attempt: Button
var _review: VBoxContainer
var _review_title: Label
var _review_text: RichTextLabel
var _review_cancel: Button
var _review_confirm: Button

func configure(value: Dictionary, settings: Dictionary = {}) -> void:
	_settings = settings.duplicate(true)
	_build()
	set_snapshot(value)

func set_snapshot(value: Dictionary) -> void:
	_build()
	var previous_id: String = str(snapshot.get("target_id", ""))
	var previous_category: String = str(snapshot.get("category", ""))
	var previous_revision: int = int(snapshot.get("revision", -1))
	var changed_revision: bool = int(value.get("revision", -1)) != previous_revision
	var changed_target: bool = previous_id != str(value.get("target_id", "")) or previous_category != str(value.get("category", ""))
	var canceled_review: bool = is_review_open() and not pending_request
	_cancel_review()
	pending_request = false
	_pending_action = ""
	snapshot = value.duplicate(true)
	if changed_target or changed_revision:
		selected_materials.clear()
		_highlighted_id = ""
	if changed_target:
		_compact_materials = false
		_content_scroll.scroll_vertical = 0
	_rebuild_materials()
	_render()
	if canceled_review:
		_status.text = "보유 정보가 바뀌어 확인을 취소했습니다. 내용을 다시 확인해 주세요."
	elif not bool(value.get("ok", false)):
		_status.text = str(value.get("error", "각성 정보를 확인할 수 없습니다."))

func apply_settings(settings: Dictionary) -> void:
	_settings = settings.duplicate(true)
	if is_instance_valid(_border):
		_border.apply_settings(_settings)

func is_review_open() -> bool:
	return not _review_action.is_empty()

func cancel_review() -> bool:
	if not is_review_open() or pending_request:
		return false
	_cancel_review()
	_render_controls()
	return true

func _build() -> void:
	if _built:
		return
	_built = true
	name = "OptionAwakeningView"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_content_scroll = ScrollContainer.new()
	_content_scroll.name = "AwakeningContentScroll"
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.custom_minimum_size.y = 64
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_content_scroll)
	_content_column = VBoxContainer.new()
	_content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_column.add_theme_constant_override("separation", 8)
	_content_scroll.add_child(_content_column)
	_heading = UI.section("옵션 각성", 18)
	_heading.name = "AwakeningTarget"
	_content_column.add_child(_heading)
	_progress_text = UI.label("", 13, UI.TEXT)
	_progress_text.name = "AwakeningExperienceText"
	_content_column.add_child(_progress_text)
	_progress = ProgressBar.new()
	_progress.name = "AwakeningExperience"
	_progress.custom_minimum_size.y = 16
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.add_theme_stylebox_override("background", UI.box(UI.SLATE, UI.BRONZE, 0))
	_progress.add_theme_stylebox_override("fill", UI.box(Color("977643"), UI.GOLD, 0))
	_content_column.add_child(_progress)
	_tabs = HBoxContainer.new()
	_tabs.name = "AwakeningCompactTabs"
	_info_tab = _button("각성 정보", _set_compact_tab.bind(false))
	_materials_tab = _button("중복 재료", _set_compact_tab.bind(true))
	_tabs.add_child(_info_tab)
	_tabs.add_child(_materials_tab)
	_content_column.add_child(_tabs)
	_main = HBoxContainer.new()
	_main.name = "AwakeningBody"
	_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_theme_constant_override("separation", 14)
	_content_column.add_child(_main)
	_info_scroll = ScrollContainer.new()
	_info_scroll.name = "AwakeningInfoScroll"
	_info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_info_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_scroll.size_flags_stretch_ratio = 0.85
	_main.add_child(_info_scroll)
	_info_content = VBoxContainer.new()
	_info_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_content.add_theme_constant_override("separation", 10)
	_info_scroll.add_child(_info_content)
	_compact_target = _wrapped_label("", 13, UI.GOLD)
	_compact_target.name = "AwakeningCompactTarget"
	_compact_target.hide()
	_info_content.add_child(_compact_target)
	var art_center := CenterContainer.new()
	art_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_content.add_child(art_center)
	_target_art = TextureRect.new()
	_target_art.name = "AwakeningTargetPreview"
	_target_art.custom_minimum_size = Vector2(132, 164)
	_target_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_center.add_child(_target_art)
	_border = AwakeningBorder.new()
	_border.name = "AwakeningTargetBorder"
	_target_art.add_child(_border)
	_border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_options = UI.rich("")
	_options.name = "AwakeningOptions"
	_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_content.add_child(_options)
	_policy = _wrapped_label("", 12, UI.MUTED)
	_policy.name = "AwakeningPolicy"
	_info_content.add_child(_policy)
	_collections = UI.rich("")
	_collections.name = "AwakeningCollectionProgress"
	_collections.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_content.add_child(_collections)
	_materials_pane = VBoxContainer.new()
	_materials_pane.name = "AwakeningMaterialsPane"
	_materials_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main.add_child(_materials_pane)
	_material_title = UI.section("경험치 재료 · 중복 카드", 15)
	_materials_pane.add_child(_material_title)
	_material_hint = _wrapped_label("최초 획득 카드는 보존됩니다. 재료를 고른 뒤 수량을 지정해 주세요.", 12, UI.MUTED)
	_materials_pane.add_child(_material_hint)
	_materials_list = TouchList.new()
	_materials_list.name = "AwakeningMaterials"
	_materials_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_materials_list.custom_minimum_size.y = 80
	_materials_list.max_columns = 1
	_materials_list.fixed_icon_size = Vector2i(44, 58)
	_materials_list.icon_mode = ItemList.ICON_MODE_LEFT
	_materials_list.max_text_lines = 3
	_materials_list.add_theme_constant_override("v_separation", 8)
	_materials_list.add_theme_font_size_override("font_size", 13)
	_materials_list.item_selected.connect(_select_material)
	_materials_pane.add_child(_materials_list)
	_empty_materials = _wrapped_label("사용할 수 있는 중복 카드가 없습니다.", 13, UI.MUTED)
	_empty_materials.name = "AwakeningEmptyMaterials"
	_materials_pane.add_child(_empty_materials)
	_quantity_caption = _wrapped_label("재료를 선택해 주세요.", 13, UI.TEXT)
	_quantity_caption.name = "AwakeningMaterialQuantity"
	_materials_pane.add_child(_quantity_caption)
	var quantity_row := HBoxContainer.new()
	_materials_pane.add_child(quantity_row)
	_decrease = _button("−", _change_material_count.bind(-1))
	_decrease.name = "AwakeningMaterialDecrease"
	_decrease.custom_minimum_size.x = 48
	_decrease.size_flags_horizontal = Control.SIZE_FILL
	_increase = _button("+", _change_material_count.bind(1))
	_increase.name = "AwakeningMaterialIncrease"
	_increase.custom_minimum_size.x = 48
	_increase.size_flags_horizontal = Control.SIZE_FILL
	_fill = _button("필요 수량 선택", _fill_material_count)
	_fill.name = "AwakeningMaterialFill"
	quantity_row.add_child(_decrease)
	quantity_row.add_child(_increase)
	quantity_row.add_child(_fill)
	_footer = VBoxContainer.new()
	_footer.name = "AwakeningActions"
	add_child(_footer)
	_selection_summary = _wrapped_label("", 13, UI.TEXT)
	_selection_summary.name = "AwakeningMaterialSummary"
	_footer.add_child(_selection_summary)
	_attempt_summary = _wrapped_label("", 13, UI.GOLD)
	_attempt_summary.name = "AwakeningAttemptSummary"
	_footer.add_child(_attempt_summary)
	_status = _wrapped_label("", 12, UI.MUTED)
	_status.name = "AwakeningStatus"
	_footer.add_child(_status)
	var actions := HBoxContainer.new()
	actions.name = "AwakeningActionButtons"
	_footer.add_child(actions)
	_clear = _button("선택 해제", _clear_materials)
	_clear.name = "AwakeningClearMaterials"
	_feed = _button("경험치 주입", _open_review.bind("feed"))
	_feed.name = "AwakeningFeed"
	_attempt = _button("각성 시도", _open_review.bind("attempt"))
	_attempt.name = "AwakeningAttempt"
	actions.add_child(_clear)
	actions.add_child(_feed)
	actions.add_child(_attempt)
	_review = VBoxContainer.new()
	_review.name = "AwakeningConfirmation"
	_review.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_review.add_theme_constant_override("separation", 10)
	add_child(_review)
	_review_title = UI.section("", 18)
	_review.add_child(_review_title)
	var review_scroll := ScrollContainer.new()
	review_scroll.name = "AwakeningConfirmationScroll"
	review_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	review_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	review_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review.add_child(review_scroll)
	_review_text = UI.rich("")
	_review_text.name = "AwakeningConfirmationDetails"
	_review_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_review_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	review_scroll.add_child(_review_text)
	var review_buttons := HBoxContainer.new()
	_review.add_child(review_buttons)
	_review_cancel = _button("취소", cancel_review)
	_review_cancel.name = "AwakeningConfirmCancel"
	_review_confirm = _button("확인", _confirm_review)
	_review_confirm.name = "AwakeningConfirmCommit"
	review_buttons.add_child(_review_cancel)
	review_buttons.add_child(_review_confirm)
	_review.hide()
	resized.connect(_reflow)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_reflow")

func _button(caption: String, callback: Callable) -> Button:
	var button := TouchButton.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button

func _wrapped_label(value: String, font_size: int, color: Color) -> Label:
	var label := UI.label(value, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _rebuild_materials() -> void:
	_material_rows.clear()
	_materials_list.clear()
	var valid_selection: Dictionary = {}
	for raw: Variant in snapshot.get("materials", []):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw as Dictionary
		var id: String = str(entry.get("id", ""))
		var spare: int = maxi(0, int(entry.get("spare", 0)))
		if id.is_empty() or spare <= 0:
			continue
		_material_rows[id] = entry
		var count: int = clampi(int(selected_materials.get(id, 0)), 0, spare)
		if count > 0:
			valid_selection[id] = count
		var record: Dictionary = entry.get("record", {}) as Dictionary
		var icon: Texture2D = _texture(record)
		var index: int = _materials_list.add_item("", icon)
		_materials_list.set_item_metadata(index, id)
		_materials_list.set_item_custom_fg_color(index, UI.grade(str(record.get("grade", "일반"))))
		if id == _highlighted_id:
			_materials_list.select(index)
	selected_materials = valid_selection
	if not _material_rows.has(_highlighted_id):
		_highlighted_id = ""
	if bool(snapshot.get("awakened", false)) or int(snapshot.get("experience", 0)) >= _required_experience():
		selected_materials.clear()
	_refresh_material_rows()

func _render() -> void:
	var record: Dictionary = snapshot.get("target_record", {}) as Dictionary
	var grade_name: String = str(record.get("grade", ""))
	var awakened: bool = bool(snapshot.get("awakened", false))
	_heading.text = "%s · %s%s" % [str(snapshot.get("category", "")), str(record.get("name", "옵션 각성")), "  [각성]" if awakened else ""]
	_heading.add_theme_color_override("font_color", UI.grade(grade_name))
	_compact_target.text = "%s · %s · %s" % [str(record.get("name", "")), grade_name, "각성 완료" if awakened else "경험치 %d / %d" % [int(snapshot.get("experience", 0)), _required_experience()]]
	_progress.max_value = _required_experience()
	_progress.value = _required_experience() if awakened else int(snapshot.get("experience", 0))
	_progress_text.text = "각성 완료" if awakened else "각성 경험치 %d / %d · 100%% 충전 후 각성 시도" % [int(snapshot.get("experience", 0)), _required_experience()]
	_target_art.texture = _texture(record)
	_target_art.tooltip_text = str(record.get("name", ""))
	_border.configure(grade_name, awakened, _settings)
	var lines := PackedStringArray()
	lines.append("[b]%s 등급 · 옵션 각성[/b]" % UI.safe(grade_name))
	lines.append("성공 확률 %s%% · 시도 비용 %s 아데나" % [_percent(float(snapshot.get("success_chance_pct", 0.0))), _number(int(snapshot.get("attempt_cost", 0)))])
	lines.append("보유 아데나 %s" % _number(int(snapshot.get("gold", 0))))
	lines.append("실패 시 경험치 %d / %d 환급\n" % [int(snapshot.get("failure_refund_experience", 0)), _required_experience()])
	var bonuses: Array = snapshot.get("bonus_options", []) as Array
	var applied: Array = snapshot.get("applied_options", []) as Array
	var pending: Array = snapshot.get("pending_options", []) as Array
	if bonuses.is_empty():
		lines.append("각성 옵션 정보가 없습니다.")
	else:
		for option: Variant in bonuses:
			var suffix: String = ""
			if pending.has(option):
				suffix = " [color=#afa28d](효과 미지원)[/color]"
			elif awakened and applied.has(option):
				suffix = " [color=#79bf83](적용 가능)[/color]"
			lines.append("• " + UI.safe(str(option)) + suffix)
	if not pending.is_empty():
		lines.append("\n[color=#afa28d]미지원 효과는 전투 능력치에 반영되지 않습니다.[/color]")
	_options.text = "\n".join(lines)
	_policy.text = str(snapshot.get("policy_note", "경험치·비용·실패 환급은 TWILIGHT 설정값입니다."))
	_render_collections()
	_empty_materials.visible = _material_rows.is_empty()
	_attempt_summary.text = "성공 확률 %s%% · 시도 비용 %s 아데나 · 보유 %s" % [_percent(float(snapshot.get("success_chance_pct", 0.0))), _number(int(snapshot.get("attempt_cost", 0))), _number(int(snapshot.get("gold", 0)))]
	_status.text = _availability_text()
	_render_controls()
	_reflow()

func _render_collections() -> void:
	var rows: Array = snapshot.get("collections", []) as Array
	_collections.visible = not rows.is_empty()
	if rows.is_empty():
		_collections.text = ""
		return
	var lines := PackedStringArray()
	lines.append("\n[b]지원 각성 컬렉션 · %d개[/b]" % rows.size())
	lines.append("조건 충족 시 자동 적용 · 카드 소모 없음\n")
	for raw: Variant in rows:
		if not raw is Dictionary:
			continue
		var row: Dictionary = raw as Dictionary
		var requirements: Array = row.get("requirements", []) as Array
		var met_count: int = 0
		var requirements_text := PackedStringArray()
		for requirement: Dictionary in requirements:
			var met: bool = bool(requirement.get("met", false))
			if met:
				met_count += 1
			requirements_text.append("%s %s%s" % ["✓" if met else "·", str(requirement.get("name", "")), " [각성]" if bool(requirement.get("awakened", false)) else " 보유"])
		var completed: bool = bool(row.get("completed", false))
		lines.append("[b]%s[/b] · %s" % [UI.safe(str(row.get("name", ""))), "[color=#79bf83]완료[/color]" if completed else "%d / %d" % [met_count, requirements.size()]])
		lines.append(UI.safe(" / ".join(requirements_text)))
		var bonuses := PackedStringArray()
		for option: Variant in row.get("bonus_options", []):
			bonuses.append(str(option))
		lines.append("[color=#dcc391]%s[/color]\n" % UI.safe(" · ".join(bonuses)))
	_collections.text = "\n".join(lines)

func _render_controls() -> void:
	var locked: bool = pending_request or is_review_open()
	var entry: Dictionary = _material_rows.get(_highlighted_id, {}) as Dictionary
	var selected: int = int(selected_materials.get(_highlighted_id, 0))
	var spare: int = int(entry.get("spare", 0))
	var may_feed: bool = bool(snapshot.get("can_feed", false))
	_decrease.disabled = locked or selected <= 0
	_increase.disabled = locked or not may_feed or entry.is_empty() or selected >= spare or _selected_experience() >= _remaining_experience()
	_fill.disabled = _increase.disabled
	_clear.disabled = locked or selected_materials.is_empty()
	_feed.disabled = locked or not may_feed or selected_materials.is_empty()
	_attempt.disabled = locked or not bool(snapshot.get("can_awaken", false))
	_materials_list.mouse_filter = Control.MOUSE_FILTER_IGNORE if locked else Control.MOUSE_FILTER_STOP
	_materials_list.focus_mode = Control.FOCUS_NONE if locked else Control.FOCUS_ALL
	_review_confirm.disabled = pending_request
	_review_cancel.disabled = pending_request
	_feed.text = "처리 중…" if pending_request and _pending_action == "feed" else "경험치 주입"
	_attempt.text = "처리 중…" if pending_request and _pending_action == "attempt" else "각성 시도"
	var count: int = 0
	for raw: Variant in selected_materials.values():
		count += int(raw)
	var xp: int = _selected_experience()
	var gained: int = mini(xp, _remaining_experience())
	_selection_summary.text = "선택 %d장 · 경험치 +%d → %d / %d" % [count, gained, int(snapshot.get("experience", 0)) + gained, _required_experience()]
	if xp > gained:
		_selection_summary.text += " · 초과 %d 소멸" % (xp - gained)
	if entry.is_empty():
		_quantity_caption.text = "재료를 선택해 주세요."
	else:
		var record: Dictionary = entry.get("record", {}) as Dictionary
		_quantity_caption.text = "%s · 선택 %d / 중복 %d장 · 1장당 +%d XP" % [str(record.get("name", "")), selected, spare, int(entry.get("experience_per_card", 0))]
	_refresh_material_rows()

func _refresh_material_rows() -> void:
	for index: int in range(_materials_list.item_count):
		var id: String = str(_materials_list.get_item_metadata(index))
		var entry: Dictionary = _material_rows.get(id, {}) as Dictionary
		var record: Dictionary = entry.get("record", {}) as Dictionary
		var count: int = int(selected_materials.get(id, 0))
		_materials_list.set_item_text(index, "%s · %s · 중복 %d장 · +%d XP%s" % [str(record.get("name", "")), str(record.get("grade", "")), int(entry.get("spare", 0)), int(entry.get("experience_per_card", 0)), " · 선택 %d장" % count if count > 0 else ""])
		_materials_list.set_item_tooltip(index, "%s\n중복 카드만 소모됩니다." % str(record.get("name", "")))

func _select_material(index: int) -> void:
	if pending_request or is_review_open() or index < 0 or index >= _materials_list.item_count:
		return
	_highlighted_id = str(_materials_list.get_item_metadata(index))
	_render_controls()

func _change_material_count(delta: int) -> void:
	if pending_request or is_review_open() or not bool(snapshot.get("can_feed", false)):
		return
	var entry: Dictionary = _material_rows.get(_highlighted_id, {}) as Dictionary
	if entry.is_empty():
		return
	var current: int = int(selected_materials.get(_highlighted_id, 0))
	if delta > 0 and _selected_experience() >= _remaining_experience():
		return
	var next: int = clampi(current + delta, 0, int(entry.get("spare", 0)))
	if next == 0:
		selected_materials.erase(_highlighted_id)
	else:
		selected_materials[_highlighted_id] = next
	_render_controls()

func _fill_material_count() -> void:
	if pending_request or is_review_open() or not bool(snapshot.get("can_feed", false)):
		return
	var entry: Dictionary = _material_rows.get(_highlighted_id, {}) as Dictionary
	var per_card: int = int(entry.get("experience_per_card", 0))
	if entry.is_empty() or per_card <= 0:
		return
	var current: int = int(selected_materials.get(_highlighted_id, 0))
	var remaining: int = maxi(0, _remaining_experience() - _selected_experience())
	var needed: int = int(ceil(float(remaining) / float(per_card)))
	var next: int = mini(int(entry.get("spare", 0)), current + needed)
	if next > 0:
		selected_materials[_highlighted_id] = next
	_render_controls()

func _clear_materials() -> void:
	if pending_request or is_review_open():
		return
	selected_materials.clear()
	_render_controls()

func _open_review(action: String) -> void:
	if pending_request or is_review_open() or not bool(snapshot.get("owned", false)):
		return
	if action == "feed" and (not bool(snapshot.get("can_feed", false)) or selected_materials.is_empty()):
		return
	if action == "attempt" and not bool(snapshot.get("can_awaken", false)):
		return
	_review_action = action
	_review_revision = int(snapshot.get("revision", -1))
	_review_materials = selected_materials.duplicate(true)
	var record: Dictionary = snapshot.get("target_record", {}) as Dictionary
	var lines := PackedStringArray()
	lines.append("[b]%s · %s[/b]\n" % [UI.safe(str(snapshot.get("category", ""))), UI.safe(str(record.get("name", "")))])
	if action == "feed":
		_review_title.text = "재료 주입 확인"
		for id: String in _review_materials:
			var entry: Dictionary = _material_rows.get(id, {}) as Dictionary
			var material: Dictionary = entry.get("record", {}) as Dictionary
			lines.append("• %s (%s) × %d장" % [UI.safe(str(material.get("name", ""))), UI.safe(str(material.get("grade", ""))), int(_review_materials[id])])
		var xp: int = _selected_experience()
		var gained: int = mini(xp, _remaining_experience())
		lines.append("\n각성 경험치: %d → %d / %d" % [int(snapshot.get("experience", 0)), int(snapshot.get("experience", 0)) + gained, _required_experience()])
		if xp > gained:
			lines.append("[color=#e97772]초과 경험치 %d는 소멸합니다.[/color]" % (xp - gained))
		lines.append("\n확인하면 위 중복 카드가 즉시 소모됩니다.\n최초 획득 카드는 보존되며, 각성 시도는 경험치 주입 후 별도로 진행합니다.")
		_review_confirm.text = "재료 소모 · 경험치 주입"
	else:
		_review_title.text = "옵션 각성 확인"
		lines.append("성공 확률: [b]%s%%[/b]" % _percent(float(snapshot.get("success_chance_pct", 0.0))))
		lines.append("소모 비용: [b]%s 아데나[/b]" % _number(int(snapshot.get("attempt_cost", 0))))
		lines.append("보유 아데나: %s" % _number(int(snapshot.get("gold", 0))))
		lines.append("\n각성에 실패해도 시도 비용은 소모됩니다.\n실패 시 경험치 %d / %d가 환급됩니다.\n이미 주입한 재료는 다시 소모하지 않습니다." % [int(snapshot.get("failure_refund_experience", 0)), _required_experience()])
		lines.append("\n" + UI.safe(str(snapshot.get("policy_note", "경험치·비용·실패 환급은 TWILIGHT 설정값입니다."))))
		_review_confirm.text = "아데나 소모 · 각성 시도"
	_review_text.text = "\n".join(lines)
	_review_confirm.disabled = false
	_review_cancel.disabled = false
	_content_scroll.hide()
	_tabs.hide()
	_footer.hide()
	_review.show()
	_render_controls()

func _confirm_review() -> void:
	if pending_request or not is_review_open():
		return
	if _review_revision != int(snapshot.get("revision", -1)):
		cancel_review()
		_status.text = "보유 정보가 바뀌었습니다. 다시 확인해 주세요."
		return
	var action: String = _review_action
	if action == "feed":
		if not bool(snapshot.get("can_feed", false)) or _review_materials.is_empty():
			cancel_review()
			return
		for id: String in _review_materials:
			var entry: Dictionary = _material_rows.get(id, {}) as Dictionary
			var count: int = int(_review_materials[id])
			if entry.is_empty() or count <= 0 or count > int(entry.get("spare", 0)):
				cancel_review()
				_status.text = "재료 수량이 바뀌었습니다. 다시 선택해 주세요."
				return
	elif not bool(snapshot.get("can_awaken", false)):
		cancel_review()
		return
	# Lock before emitting: a second mouse/touch/keyboard release cannot submit
	# another transaction while the world is applying this one.
	pending_request = true
	_pending_action = action
	_render_controls()
	_review_confirm.text = "처리 중…"
	if action == "feed":
		feed_requested.emit(_review_materials.duplicate(true))
	else:
		attempt_requested.emit()

func _cancel_review() -> void:
	_review_action = ""
	_review_revision = -1
	_review_materials.clear()
	if _built:
		_review.hide()
		_content_scroll.show()
		_footer.show()
		_reflow()

func _reflow() -> void:
	if not _built or is_review_open():
		return
	var compact: bool = size.x < 720.0
	_tabs.visible = compact
	_info_scroll.visible = not compact or not _compact_materials
	_materials_pane.visible = not compact or _compact_materials
	var short_view: bool = size.y < 470.0
	var tiny_view: bool = size.y < 380.0
	var fixed_tabs: bool = tiny_view and compact
	add_theme_constant_override("separation", 4 if fixed_tabs else 8)
	if fixed_tabs and _tabs.get_parent() != self:
		_tabs.reparent(self)
		move_child(_tabs, 0)
	elif not fixed_tabs and _tabs.get_parent() != _content_column:
		_tabs.reparent(_content_column)
		_content_column.move_child(_tabs, _main.get_index())
	_heading.visible = not fixed_tabs
	_progress_text.visible = not fixed_tabs
	_progress.visible = not fixed_tabs
	_compact_target.visible = fixed_tabs
	_materials_tab.text = "중복 재료 · %d/%d" % [int(snapshot.get("experience", 0)), _required_experience()] if fixed_tabs else "중복 재료"
	_material_title.visible = not (tiny_view and compact)
	_material_hint.visible = not (tiny_view and compact)
	_materials_pane.add_theme_constant_override("separation", 2 if fixed_tabs else 4)
	_materials_list.custom_minimum_size.y = 66 if tiny_view else 80
	_status.visible = not short_view
	_attempt_summary.visible = not tiny_view and (not short_view or _remaining_experience() == 0)
	_selection_summary.visible = not tiny_view and not bool(snapshot.get("awakened", false)) and _remaining_experience() > 0
	_info_tab.add_theme_stylebox_override("normal", UI.tab_frame(not _compact_materials))
	_materials_tab.add_theme_stylebox_override("normal", UI.tab_frame(_compact_materials))

func _set_compact_tab(materials: bool) -> void:
	_compact_materials = materials
	_reflow()
	if materials and size.y < 380.0:
		call_deferred("_show_short_materials")
	else:
		_content_scroll.scroll_vertical = 0

func _show_short_materials() -> void:
	# The game preserves its landscape aspect in a portrait window. With only
	# a short active viewport, prioritize a real material row plus the quantity
	# controls; the persistent footer keeps only the 48px transaction actions.
	await get_tree().process_frame
	if is_instance_valid(_content_scroll) and _compact_materials and not is_review_open():
		_content_scroll.scroll_vertical = int(_content_column.size.y)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree() and is_review_open() and not pending_request:
		_cancel_review()

func _availability_text() -> String:
	if not str(snapshot.get("blocked_reason", "")).is_empty():
		return str(snapshot.blocked_reason)
	if bool(snapshot.get("awakened", false)):
		return "각성이 완료된 카드입니다. 적용 중인 카드의 지원 옵션이 반영됩니다."
	if not bool(snapshot.get("owned", false)):
		return "획득한 영웅 이상 카드만 각성할 수 있습니다."
	if _remaining_experience() > 0:
		return "중복 재료를 주입해 경험치를 100%까지 채워 주세요."
	if int(snapshot.get("gold", 0)) < int(snapshot.get("attempt_cost", 0)):
		return "각성 경험치가 충전되었습니다. 시도할 아데나가 부족합니다."
	return "각성 경험치가 충전되었습니다. 비용과 확률을 확인한 뒤 각성을 시도하세요."

func _selected_experience() -> int:
	var total: int = 0
	for id: String in selected_materials:
		var entry: Dictionary = _material_rows.get(id, {}) as Dictionary
		total += int(selected_materials[id]) * int(entry.get("experience_per_card", 0))
	return total

func _required_experience() -> int:
	return maxi(1, int(snapshot.get("required_experience", 100)))

func _remaining_experience() -> int:
	return maxi(0, _required_experience() - int(snapshot.get("experience", 0)))

func _texture(record: Dictionary) -> Texture2D:
	var path: String = str(record.get("image_path", ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null

func _percent(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func _number(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result
