extends "res://scripts/ui/lineage_inventory_ui.gd"

const UI = preload("res://scripts/ui/renewal_theme.gd")
var sort_mode: int = 0
var inventory_fingerprint: String = ""
var weight_readout: Label

func _ready() -> void:
	super._ready()
	theme = UI.make_theme()
	inventory_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.add_theme_stylebox_override("panel",UI.box(Color("11171d"),UI.BRONZE,10))
	var header: HBoxContainer = inventory_panel.get_child(0).get_child(0)
	# Shared window owns close. Keep the original grid/details/data contract.
	(header.get_child(0) as Label).text = "소지품"
	(header.get_child(header.get_child_count()-1) as Button).hide()
	var sorter := OptionButton.new()
	sorter.name = "InventorySort"
	for label: String in ["이름순","등급순","수량순"]:
		sorter.add_item(label)
	sorter.item_selected.connect(func(index: int) -> void: sort_mode=index; _refresh_inventory_grid())
	header.add_child(sorter)
	search_line.custom_minimum_size.x = 160
	detail_panel.custom_minimum_size.x = 288
	for b: Button in tab_buttons.values():
		b.custom_minimum_size.x = 82
	weight_readout = UI.label("",11,UI.MUTED)
	(inventory_panel.get_child(0) as VBoxContainer).add_child(weight_readout)

func _find_item_record(item_name: String) -> Dictionary:
	var instance_id: String = _ref_instance_id(item_name)
	if instance_id != "":
		var all_instances: Variant = character_state.get("item_instances", {})
		if all_instances is Dictionary:
			var item_data: Variant = (all_instances as Dictionary).get(instance_id, {})
			if item_data is Dictionary:
				var identified: Variant = (item_data as Dictionary).get("record", {})
				if identified is Dictionary and not (identified as Dictionary).is_empty() and str((identified as Dictionary).get("name", "")) == _base_item_name(item_name):
					return identified as Dictionary
	return super._find_item_record(item_name)

func _icon_for_reference(record: Dictionary, name_value: String, item_reference: String) -> Texture2D:
	if _ref_instance_id(item_reference) != "" and str(record.get("sourceId", "")) != "":
		var path: String = str(record.get("image_path", ""))
		if path != "" and ResourceLoader.exists(path):
			return load(path) as Texture2D
	return UI.item_icon(record, name_value, item_image_index.get("아이템", {}))

func _grade_color(value: String) -> Color:
	return UI.grade(value)

func set_inventory(value: Dictionary) -> void:
	if inventory == value:
		return
	super.set_inventory(value)

func set_character_state(value: Dictionary) -> void:
	var fingerprint := JSON.stringify([value.get("gold",0),value.get("equipped_items",{}),value.get("enhancement_levels",{}),value.get("item_instances",{})])
	character_state = value.duplicate(true)
	if fingerprint == inventory_fingerprint:
		return
	inventory_fingerprint = fingerprint
	gold_label.text = "아데나  "+_format_number(int(value.get("gold",0)))
	_refresh_inventory_grid()
	if selected_item != "":
		_refresh_detail(selected_item)

func _refresh_inventory_grid() -> void:
	super._refresh_inventory_grid()
	var references: Array = slot_buttons.keys()
	if sort_mode == 1:
		references.sort_custom(func(a: String, b: String) -> bool:
			var left_name: String = _base_item_name(a)
			var right_name: String = _base_item_name(b)
			var left_grade: int = UI.GRADES.keys().find(str(_find_item_record(a).get("grade", "일반")))
			var right_grade: int = UI.GRADES.keys().find(str(_find_item_record(b).get("grade", "일반")))
			return a < b if left_grade == right_grade else left_grade > right_grade)
	elif sort_mode == 2:
		references.sort_custom(func(a: String, b: String) -> bool:
			var left_count: int = 1 if _ref_instance_id(a) != "" else int(inventory.get(_base_item_name(a), 0))
			var right_count: int = 1 if _ref_instance_id(b) != "" else int(inventory.get(_base_item_name(b), 0))
			return a < b if left_count == right_count else left_count > right_count)
	else:
		references.sort()
	for index: int in range(references.size()):
		var reference: String = str(references[index])
		var item_name: String = _base_item_name(reference)
		var button: Button = slot_buttons[reference] as Button
		item_grid.move_child(button, index)
		var record: Dictionary = _find_item_record(reference)
		var texture: Texture2D = _icon_for_reference(record, item_name, reference)
		button.icon = null
		button.text = ""
		button.custom_minimum_size = Vector2(96, 98)
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(15, 10)
		icon.size = Vector2(66, 60)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		var shown_name: String = _display_item_name(record, reference)
		var caption := UI.label(shown_name.left(6) + "…" if shown_name.length() > 7 else shown_name, 11)
		caption.position = Vector2(4, 75)
		caption.size = Vector2(88, 19)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.clip_text = true
		button.add_child(caption)
		var level: int = _enhance_level(reference)
		var badge := UI.label("+%d" % level if level > 0 else "", 12, UI.GOLD)
		badge.position = Vector2(5, 2)
		button.add_child(badge)
		var equipped: bool = _is_item_equipped(reference)
		var amount: int = 1 if _ref_instance_id(reference) != "" else int(inventory.get(item_name, 0))
		var count := UI.label("E" if equipped else "×%d" % amount, 12, UI.GOLD if equipped else UI.TEXT)
		count.position = Vector2(52, 3)
		count.size = Vector2(38, 22)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_child(count)
		if _ref_instance_id(reference) != "":
			button.tooltip_text += " · 개체 ID:" + _ref_instance_id(reference)
	if weight_readout != null:
		var current_weight: float = float(character_state.get("current_weight", 0))
		var max_weight: float = float(character_state.get("max_weight", character_state.get("carrying_capacity", 0)))
		weight_readout.text = "현재 무게 %.0f / %.0f · 장비별 강화·속성은 개체 ID별 보존" % [current_weight, max_weight]

func _refresh_detail(item_reference: String) -> void:
	super._refresh_detail(item_reference)
	var item_name: String = _base_item_name(item_reference)
	var selected_id: String = _ref_instance_id(item_reference)
	var item: Dictionary = _find_item_record(item_reference)
	detail_icon.texture = _icon_for_reference(item, item_name, item_reference)
	var slot: String = str(item.get("slot", ""))
	var worn: Dictionary = character_state.get("equipped_items", {})
	var current: Variant = worn.get(slot, {})
	if current is Dictionary and not (current as Dictionary).is_empty() and str((current as Dictionary).get("name", "")) != item_name:
		detail_text.text += "\n\n[color=#d8b878]착용 장비와 비교[/color]\n" + UI.safe((current as Dictionary).get("name", ""))
		for pair: Array in [["atk", "공격력"], ["def", "방어력"], ["hit", "명중"], ["hpFlat", "최대 HP"]]:
			var delta: int = int(item.get(pair[0], 0)) - int((current as Dictionary).get(pair[0], 0))
			if delta != 0:
				detail_text.text += "\n%s  %s%d" % [pair[1], "+" if delta > 0 else "", delta]
	if selected_id != "":
		detail_text.text += "\n[color=#d8b878]선택한 장비 ID: %s[/color]" % UI.safe(selected_id)
	if _is_item_equipped(item_reference):
		detail_action.tooltip_text = "선택된 장비 개체가 장착 중입니다. 현재 게임은 일반 장비 해제를 제공하지 않습니다."
	else:
		detail_action.tooltip_text = ""
