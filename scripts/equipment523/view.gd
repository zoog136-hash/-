extends VBoxContainer
## Equipment operations only emit requests; the host owns inventory and saves.

signal preview_requested(action: Dictionary)
signal commit_requested(action: Dictionary)
signal install_requested(path: String, sha256: String)

const KINDS: Array[String] = ["elemental_smith", "bless_reinforcement", "smelt", "spirit_smelt", "alchemy", "invoke_replacement", "sets"]
const KIND_NAMES: Array[String] = ["속성 세공", "축복 세공", "일반 제련", "정령 제련", "연금", "발동 스킬 교체", "장비 세트"]
const SOURCE_IMAGES = preload("res://scripts/ui/source523_image_assets.gd")

var _snapshot: Dictionary = {}
var _built: bool = false
var _refreshing: bool = false
var _waiting: bool = false
var _quoted_ok: bool = false
var _pending_action: Dictionary = {}
var _quoted_action: Dictionary = {}
var _kind: OptionButton
var _target: OptionButton
var _material: OptionButton
var _materials: ItemList
var _recipe: OptionButton
var _slot: SpinBox
var _status: Label
var _target_info: Label
var _material_info: Label
var _policy: Label
var _quote_text: Label
var _result: Label
var _sets: Label
var _confirm: CheckBox
var _preview: Button
var _commit: Button
var _target_box: VBoxContainer
var _single_box: VBoxContainer
var _multi_box: VBoxContainer
var _recipe_box: VBoxContainer
var _slot_box: VBoxContainer
var _operation_box: VBoxContainer
var _install_box: VBoxContainer
var _path: LineEdit
var _sha: LineEdit
var _install: Button
var _file_dialog: FileDialog


func _ready() -> void:
	_ensure_built()
	_render_snapshot()


func set_snapshot(data: Dictionary) -> void:
	_ensure_built()
	_snapshot = data.duplicate(true)
	_render_snapshot()


func show_quote(quoted: Dictionary) -> void:
	_ensure_built()
	if not _waiting or _pending_action != _action():
		return
	_waiting = false
	_quoted_ok = bool(quoted.get("ok", false))
	_confirm.set_pressed_no_signal(false)
	_confirm.disabled = not _quoted_ok
	_commit.disabled = true
	if not _quoted_ok:
		_quote_text.text = _error_text(quoted)
		_quoted_action.clear()
		_update_buttons()
		return
	_quoted_action = _pending_action.duplicate(true)
	var lines: Array[String] = ["이번에 소모하는 항목"]
	var gold: int = int(quoted.get("gold_cost", 0))
	lines.append("아데나 %s" % _number(gold))
	for entry: Variant in quoted.get("costs", []):
		if entry is Dictionary:
			lines.append("%s × %s" % [_source_name(str(entry.get("source_id", ""))), _number(int(entry.get("amount", 0)))])
	var consumed: Array = quoted.get("consume_instance_ids", [])
	if not consumed.is_empty():
		for physical: Variant in consumed:
			lines.append("%s × 1" % _physical_name(str(physical)))
		lines.append("선택한 연금 재료가 모두 사라집니다. 결과는 실행할 때 정해집니다.")
	else:
		if str(_quoted_action.get("kind", "")) == "invoke_replacement":
			lines.append("선택한 발동 슬롯의 기존 효과가 새 결과로 교체됩니다.")
		else:
			lines.append("이 작업의 기존 옵션은 모두 초기화된 뒤 새 결과로 교체됩니다.")
	var detail: String = str(quoted.get("detail", ""))
	if not detail.is_empty():
		lines.append(detail)
	var notes: String = str(_snapshot.get("policy_notes", ""))
	if not notes.is_empty():
		lines.append(notes)
	_quote_text.text = "\n".join(lines)
	_update_buttons()


func show_result(result: Dictionary) -> void:
	_ensure_built()
	_invalidate_quote()
	if bool(result.get("ok", false)):
		var detail: String = str(result.get("detail", ""))
		_result.text = "작업을 적용했습니다." if detail.is_empty() else "작업 결과\n" + detail
		var output: Variant = result.get("output", {})
		if output is Dictionary and not output.is_empty():
			_result.text += "\n획득: %s × %s" % [_source_name(str(output.get("source_id", ""))), _number(int(output.get("amount", 1)))]
	else:
		_result.text = _error_text(result)
	_update_buttons()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	name = "Equipment523View"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_add_label(body, "장비 세공 · 제련 · 연금", "Title")
	_status = _add_label(body, "규칙팩을 확인하고 있습니다.", "PackStatus")
	_kind = _option(body, "OperationKind")
	for index: int in KIND_NAMES.size():
		_kind.add_item(KIND_NAMES[index], index)
	_kind.item_selected.connect(_selection_changed)
	_policy = _add_label(body, "", "PolicyNotes")
	_recipe_box = _group(body, "연금 종류")
	_recipe = _option(_recipe_box, "AlchemyRecipe")
	_recipe.add_item("일반 연금", 63)
	_recipe.add_item("질서의 연금", 113)
	_recipe.item_selected.connect(_selection_changed)
	_target_box = _group(body, "대상 장비")
	_target = _option(_target_box, "TargetEquipment")
	_target.item_selected.connect(_selection_changed)
	_target_info = _add_label(_target_box, "장비를 선택하세요.", "TargetDetails")
	_single_box = _group(body, "소모품 한 종류 선택")
	_material = _option(_single_box, "OperationMaterial")
	_material.item_selected.connect(_selection_changed)
	_material_info = _add_label(_single_box, "실제 소모량은 비용 확인 후 표시됩니다.", "MaterialDetails")
	_multi_box = _group(body, "연금 재료 선택 (장착·잠금 해제된 개체 3~6개)")
	_materials = ItemList.new()
	_materials.name = "AlchemyMaterials"
	_materials.select_mode = ItemList.SELECT_MULTI
	_materials.custom_minimum_size.y = 180
	_materials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_materials.allow_reselect = true
	_materials.item_selected.connect(_selection_changed)
	_materials.multi_selected.connect(_multi_selected)
	_multi_box.add_child(_materials)
	_add_label(_multi_box, "여러 재료를 선택하세요. 같은 이름의 장비도 각 개체를 따로 셉니다. 선택한 이름은 아래에서 확인할 수 있습니다.", "AlchemyHelp")
	_slot_box = _group(body, "변경할 발동 슬롯")
	_slot = SpinBox.new()
	_slot.name = "InvokeSlot"
	_slot.min_value = 1
	_slot.max_value = 99
	_slot.step = 1
	_slot.value = 3
	_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot.value_changed.connect(_slot_changed)
	_slot_box.add_child(_slot)
	_add_label(_slot_box, "장비에서 변경 가능한 슬롯 번호를 선택하세요. 비용 확인에서 사용 가능 여부를 알려드립니다.", "InvokeHelp")
	_operation_box = VBoxContainer.new()
	_operation_box.name = "OperationConfirmation"
	_operation_box.add_theme_constant_override("separation", 8)
	body.add_child(_operation_box)
	_preview = _button(_operation_box, "비용과 변경 내용 확인", "PreviewOperation")
	_preview.pressed.connect(_request_preview)
	_quote_text = _add_label(_operation_box, "선택 후 비용과 변경 내용을 확인하세요.", "QuoteDetails")
	_confirm = CheckBox.new()
	_confirm.name = "ConfirmConsumption"
	_confirm.text = "소모 항목과 기존 옵션 변경을 확인했습니다."
	_confirm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.disabled = true
	_confirm.toggled.connect(_confirmation_changed)
	_operation_box.add_child(_confirm)
	_commit = _button(_operation_box, "확인한 내용으로 1회 실행", "CommitOperation")
	_commit.disabled = true
	_commit.pressed.connect(_request_commit)
	var cancel := _button(_operation_box, "취소", "CancelOperation")
	cancel.pressed.connect(_cancel)
	_sets = _add_label(body, "", "EquipmentSetDetails")
	_result = _add_label(body, "", "OperationResult")
	var install_toggle := _button(body, "규칙팩 설치 / 변경", "TogglePackInstall")
	_install_box = VBoxContainer.new()
	_install_box.name = "PackInstallation"
	_install_box.visible = false
	_install_box.add_theme_constant_override("separation", 8)
	body.add_child(_install_box)
	install_toggle.pressed.connect(func() -> void: _install_box.visible = not _install_box.visible)
	_add_label(_install_box, "기기에 받은 규칙팩 파일과 검증값을 입력하세요. 기본 규칙팩을 먼저 설치한 뒤 효과 보완팩도 같은 방법으로 설치합니다.", "PackInstallHelp")
	_path = LineEdit.new()
	_path.name = "PackFilePath"
	_path.placeholder_text = "규칙팩 또는 효과 보완팩 파일 경로"
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_install_box.add_child(_path)
	var browse := _button(_install_box, "파일 선택", "BrowsePackFile")
	browse.pressed.connect(_browse_pack)
	_sha = LineEdit.new()
	_sha.name = "PackSha256"
	_sha.placeholder_text = "제공된 SHA-256 검증값 (64자리)"
	_sha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_install_box.add_child(_sha)
	_install = _button(_install_box, "선택한 규칙팩 설치", "InstallPack")
	_install.disabled = true
	_install.pressed.connect(_request_install)
	_path.text_changed.connect(_install_input_changed)
	_sha.text_changed.connect(_install_input_changed)
	_file_dialog = FileDialog.new()
	_file_dialog.name = "PackFileDialog"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.json ; 규칙팩 JSON"])
	_file_dialog.file_selected.connect(_pack_selected)
	add_child(_file_dialog)


func _render_snapshot() -> void:
	_refreshing = true
	var selected_target: String = _selected_id(_target)
	var selected_material: String = _selected_id(_material)
	var selected_materials: Array[String] = []
	for index: int in _materials.get_selected_items():
		selected_materials.append(str(_materials.get_item_metadata(index)))
	_target.clear()
	_material.clear()
	_materials.clear()
	for list in [_target, _material, _materials]:
		if list.has_meta("source523_images"): list.remove_meta("source523_images")
	_target.expand_icon = true
	_material.expand_icon = true
	_target.add_item("장비를 선택하세요")
	_target.set_item_metadata(0, "")
	_material.add_item("소모품을 선택하세요")
	_material.set_item_metadata(0, "")
	var entries: Array = _snapshot.get("targets", [])
	for value: Variant in entries:
		if not value is Dictionary:
			continue
		var info: Dictionary = value
		var physical: String = str(info.get("instance_id", ""))
		if physical.is_empty() or int(info.get("quantity", info.get("amount", 1))) < 1:
			continue
		var caption: String = _item_caption(info)
		_target.add_item(caption)
		var ti: int = _target.item_count - 1
		_target.set_item_metadata(ti, physical)
		_target.set_item_tooltip(ti, caption)
		_bind_source_item_image(_target, ti, info)
		if physical == selected_target:
			_target.select(ti)
		if bool(info.get("locked", false)) or bool(info.get("equipped", false)):
			continue
		_material.add_item(caption)
		var mi: int = _material.item_count - 1
		_material.set_item_metadata(mi, physical)
		_material.set_item_tooltip(mi, caption)
		_bind_source_item_image(_material, mi, info)
		if physical == selected_material:
			_material.select(mi)
		_materials.add_item(caption)
		var ai: int = _materials.item_count - 1
		_materials.set_item_metadata(ai, physical)
		_materials.set_item_tooltip(ai, caption)
		_bind_source_item_image(_materials, ai, info)
		if selected_materials.has(physical):
			_materials.select(ai, false)
	_status.text = str(_snapshot.get("status", "규칙팩 준비 완료" if _snapshot.get("pack_ready", false) else "규칙팩을 설치하면 사용할 수 있습니다."))
	_policy.text = str(_snapshot.get("policy_notes", ""))
	_refreshing = false
	_invalidate_quote()
	_render_selection()
	_render_sets()
	_update_buttons()


func _bind_source_item_image(list, index: int, info: Dictionary) -> void:
	if not SOURCE_IMAGES.selected(): return
	var record: Variant = info.get("record")
	if not record is Dictionary: return
	var source_id: Variant = info.get("source_id")
	if not SOURCE_IMAGES.PACK._integer(source_id) or int(source_id) <= 0 or SOURCE_IMAGES.item_class_id(record) != int(source_id): return
	var image: Dictionary = SOURCE_IMAGES.describe_item(record,str(info.get("name","")))
	list.set_item_icon(index,image.get("texture") as Texture2D)
	var evidence: Dictionary = image.duplicate(true)
	evidence.erase("texture")
	evidence["equipment_instance_id"] = str(info.get("instance_id",""))
	var images: Dictionary = list.get_meta("source523_images",{})
	images[index] = evidence
	list.set_meta("source523_images",images)


func _render_selection() -> void:
	var kind: String = _current_kind()
	var alchemy: bool = kind == "alchemy"
	var sets: bool = kind == "sets"
	_target_box.visible = not alchemy and not sets
	_single_box.visible = not alchemy and not sets
	_multi_box.visible = alchemy
	_recipe_box.visible = alchemy
	_slot_box.visible = kind == "invoke_replacement"
	_operation_box.visible = not sets
	_sets.visible = sets
	_target_info.text = _physical_details(_selected_id(_target))
	if alchemy:
		var names: Array[String] = []
		for index: int in _materials.get_selected_items():
			names.append(_physical_name(str(_materials.get_item_metadata(index))))
		_quote_text.text = "선택한 재료 %d / 6개\n%s" % [names.size(), "\n".join(names)]
	else:
		_material_info.text = _physical_details(_selected_id(_material))


func _render_sets() -> void:
	var lines: Array[String] = ["장착 중인 장비의 세트 효과"]
	for line: Variant in _snapshot.get("set_runtime_lines",[]):
		if line is String: lines.append(line)
	var details: Array = _snapshot.get("set_details", [])
	if details.is_empty():
		lines.append("현재 장착한 세트 구성품이 없습니다.")
	for value: Variant in details:
		if not value is Dictionary:
			continue
		var entry: Dictionary = value
		if entry.has("error"):
			lines.append(str(entry.error))
			continue
		lines.append("\n%s · %d종 장착" % [str(entry.get("name", "장비 세트")), int(entry.get("count", 0))])
		var threshold: int = int(entry.get("threshold", 0))
		lines.append("적용 조건: %d종 충족" % threshold if threshold > 0 else "세트 효과에 필요한 구성을 더 장착하세요.")
		if entry.has("description"):
			lines.append(str(entry.description))
		for effect: Variant in entry.get("effects", []):
			if effect is String:
				lines.append(effect)
			elif effect is Dictionary and effect.has("description"):
				lines.append(str(effect.description))
		if not entry.get("unconnected_bonus_ids", []).is_empty() or int(entry.get("unconnected_buff_id", 0)) != 0:
			lines.append("일부 세트 효과는 아직 적용되지 않습니다.")
		if int(entry.get("siege_zone_buff_id",0)) > 0:
			lines.append("영예 효과는 적용 가능한 공성 지역에서 유지됩니다.")
	_sets.text = "\n".join(lines)


func _action() -> Dictionary:
	var material_ids: Array[String] = []
	if _current_kind() == "alchemy":
		for index: int in _materials.get_selected_items():
			material_ids.append(str(_materials.get_item_metadata(index)))
	else:
		var material: String = _selected_id(_material)
		if not material.is_empty():
			material_ids.append(material)
	return {"kind": _current_kind(), "target_id": "" if _current_kind() == "alchemy" else _selected_id(_target),
		"material_ids": material_ids, "recipe_type": _recipe.get_selected_id(), "slot": int(_slot.value)}


func _request_preview() -> void:
	if _preview.disabled:
		return
	_invalidate_quote()
	_pending_action = _action().duplicate(true)
	_waiting = true
	_quote_text.text = "비용과 적용 가능 여부를 확인하고 있습니다."
	_update_buttons()
	preview_requested.emit(_pending_action.duplicate(true))


func _request_commit() -> void:
	if _commit.disabled or not _confirm.button_pressed or not _quoted_ok or _quoted_action != _action():
		return
	var action: Dictionary = _quoted_action.duplicate(true)
	_invalidate_quote()
	_quote_text.text = "확인한 작업을 실행하고 있습니다."
	_update_buttons()
	commit_requested.emit(action)


func _cancel() -> void:
	_invalidate_quote()
	_result.text = "취소했습니다."
	_update_buttons()


func _selection_changed(_index: int) -> void:
	if _refreshing:
		return
	_invalidate_quote()
	_render_selection()
	_update_buttons()


func _multi_selected(_index: int, _selected: bool) -> void:
	_selection_changed(0)


func _slot_changed(_value: float) -> void:
	_selection_changed(0)


func _confirmation_changed(_pressed: bool) -> void:
	_update_buttons()


func _invalidate_quote() -> void:
	_waiting = false
	_quoted_ok = false
	_pending_action.clear()
	_quoted_action.clear()
	_confirm.set_pressed_no_signal(false)
	_confirm.disabled = true
	_commit.disabled = true
	_quote_text.text = "선택 후 비용과 변경 내용을 확인하세요."


func _update_buttons() -> void:
	var action: Dictionary = _action()
	for button: Button in [_preview, _commit]:
		button.icon = null
		if button.has_meta("source523_image"): button.remove_meta("source523_image")
	if _current_kind() not in ["alchemy", "sets"] and SOURCE_IMAGES.selected() and _target.selected >= 0:
		var images: Dictionary = _target.get_meta("source523_images",{})
		var evidence: Dictionary = images.get(_target.selected,{})
		if not evidence.is_empty() and evidence.get("equipment_instance_id") == action.target_id:
			for button: Button in [_preview, _commit]:
				button.icon = _target.get_item_icon(_target.selected)
				button.expand_icon = true
				button.set_meta("source523_image",evidence.duplicate(true))
	var ready: bool = bool(_snapshot.get("pack_ready", false)) and not _waiting
	var valid: bool = not str(action.target_id).is_empty() and action.material_ids.size() == 1
	if _current_kind() == "alchemy":
		valid = action.material_ids.size() >= 3 and action.material_ids.size() <= 6
	if _current_kind() == "sets":
		valid = false
	_preview.disabled = not ready or not valid
	_commit.disabled = not ready or not _quoted_ok or not _confirm.button_pressed or _quoted_action != action


func _current_kind() -> String:
	return KINDS[clampi(_kind.selected, 0, KINDS.size() - 1)]


func _selected_id(option: OptionButton) -> String:
	return "" if option.selected < 0 else str(option.get_item_metadata(option.selected))


func _physical_details(physical: String) -> String:
	for value: Variant in _snapshot.get("targets", []):
		if value is Dictionary and str(value.get("instance_id", "")) == physical:
			var info: Dictionary = value
			var states: Array[String] = []
			if bool(info.get("equipped", false)):
				states.append("장착 중")
			if bool(info.get("locked", false)):
				states.append("잠금")
			if int(info.get("element_level", 0)) > 0:
				var elements: Array[String] = ["없음", "불", "물", "바람", "땅"]
				var element: int = int(info.get("element_type", 0))
				states.append("%s 속성 %d단" % [elements[element] if element >= 0 and element < elements.size() else "미확인", int(info.element_level)])
			return "%s\n보유 %s개%s" % [_item_caption(info), _number(int(info.get("quantity", info.get("amount", 1)))), " · " + " · ".join(states) if not states.is_empty() else ""]
	return "항목을 선택하세요."


func _item_caption(info: Dictionary) -> String:
	var title: String = str(info.get("name", "이름 미확인"))
	var level: int = int(info.get("level", 0))
	return "+%d %s%s" % [level, title, " [잠금]" if bool(info.get("locked", false)) else ""]


func _physical_name(physical: String) -> String:
	for value: Variant in _snapshot.get("targets", []):
		if value is Dictionary and str(value.get("instance_id", "")) == physical:
			return _item_caption(value)
	return "선택한 재료"


func _source_name(source: String) -> String:
	for value: Variant in _snapshot.get("targets", []):
		if value is Dictionary and str(value.get("source_id", "")) == source:
			return str(value.get("name", "재료"))
	return "아이템 %s" % source


func _error_text(data: Dictionary) -> String:
	var message: String = str(data.get("error", data.get("detail", "작업을 진행할 수 없습니다.")))
	var messages: Dictionary = {
		"recipe_disabled": "현재 사용할 수 없는 연금 종류입니다.",
		"explicit_alchemy_policy_required": "연금 평가와 비용 설정을 먼저 확인하세요. 미확인 원본 규칙은 현재 설정으로 구분합니다.",
		"explicit_server_limit_policy_required": "이 연금에 사용할 결과 범위 설정이 필요합니다.",
		"unsupported_server_limit": "현재 설정에서 지원하지 않는 연금 결과 범위입니다.",
		"player_level_too_low": "연금을 사용할 수 있는 캐릭터 레벨에 도달하지 않았습니다.",
		"invalid_material_count": "연금 재료를 3~6개 선택하세요.",
		"missing_or_duplicate_material": "선택한 재료가 없거나 같은 개체를 중복 선택했습니다.",
		"material_equipped_or_locked": "장착 중이거나 잠긴 장비는 연금 재료로 사용할 수 없습니다.",
		"unknown_material_item": "선택한 재료의 원본 아이템 정보를 확인할 수 없습니다.",
		"material_grade_too_low": "이 연금에서 요구하는 등급 이상의 재료를 선택하세요.",
		"material_not_allowed_by_recipe": "이 연금에 사용할 수 없는 재료가 포함되어 있습니다.",
		"material_grade_slots_unsatisfied": "선택한 연금 종류의 재료 등급 구성을 충족하지 못했습니다.",
		"no_result_pool_for_evaluation": "현재 재료 평가에 맞는 연금 결과가 없습니다. 재료나 평가 설정을 확인하세요.",
		"ambiguous_or_invalid_result_pool": "현재 재료의 연금 결과 확률을 확정할 수 없습니다. 재료나 규칙팩을 확인하세요."
	}
	if messages.has(message):
		return str(messages[message])
	# Internal failure codes are kept out of the player-facing flow.
	if message.is_valid_identifier() and message.contains("_"):
		return "선택한 항목이나 현재 설정으로 작업할 수 없습니다. 재료·장비 조건과 규칙팩을 확인하세요."
	return "작업을 진행할 수 없습니다." if message.is_empty() else message


func _number(value: int) -> String:
	var digits: String = str(value)
	var result: String = ""
	for index: int in digits.length():
		if index > 0 and (digits.length() - index) % 3 == 0:
			result += ","
		result += digits[index]
	return result


func _install_input_changed(_text: String) -> void:
	_install.disabled = _path.text.strip_edges().is_empty() or not _valid_sha(_sha.text.strip_edges())


func _valid_sha(value: String) -> bool:
	if value.length() != 64:
		return false
	for index: int in value.length():
		if not value[index].to_lower() in "0123456789abcdef":
			return false
	return true


func _request_install() -> void:
	if _install.disabled:
		return
	_invalidate_quote()
	_update_buttons()
	install_requested.emit(_path.text.strip_edges(), _sha.text.strip_edges().to_lower())


func _browse_pack() -> void:
	_file_dialog.popup_centered_ratio(0.85)


func _pack_selected(path: String) -> void:
	_path.text = path
	_install_input_changed("")


func _add_label(parent: Node, text: String, node_name: String = "") -> Label:
	var label := Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _group(parent: Node, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	_add_label(box, title)
	return box


func _option(parent: Node, node_name: String) -> OptionButton:
	var option := OptionButton.new()
	option.name = node_name
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.fit_to_longest_item = false
	option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(option)
	return option


func _button(parent: Node, title: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button
