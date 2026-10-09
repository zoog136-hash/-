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
	var names: Array = slot_buttons.keys()
	if sort_mode == 1:
		names.sort_custom(func(a: String,b: String) -> bool:
			var ga: int = UI.GRADES.keys().find(str(_find_item_record(a).get("grade","일반")))
			var gb: int = UI.GRADES.keys().find(str(_find_item_record(b).get("grade","일반")))
			return a < b if ga == gb else ga > gb)
	elif sort_mode == 2:
		names.sort_custom(func(a: String,b: String) -> bool: return a < b if int(inventory[a]) == int(inventory[b]) else int(inventory[a]) > int(inventory[b]))
	else:
		names.sort()
	for index: int in range(names.size()):
		var item_name: String = str(names[index])
		var b: Button = slot_buttons[item_name]
		item_grid.move_child(b,index)
		var texture: Texture2D = UI.item_icon(_find_item_record(item_name),item_name,item_image_index.get("아이템",{}))
		b.icon = null
		b.text = ""
		b.custom_minimum_size = Vector2(96,98)
		var icon := TextureRect.new()
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(15,10)
		icon.size = Vector2(66,60)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var caption := UI.label(item_name.left(6)+"…" if item_name.length()>7 else item_name,11)
		caption.position = Vector2(4,75)
		caption.size = Vector2(88,19)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.clip_text = true
		b.add_child(caption)
		var badge := UI.label("+%d" % _enhance_level(item_name) if _enhance_level(item_name)>0 else "",12,UI.GOLD)
		badge.position = Vector2(5,2)
		b.add_child(badge)
		var count := UI.label("E" if _is_item_equipped(item_name) else "×%d" % int(inventory[item_name]),12,UI.GOLD if _is_item_equipped(item_name) else UI.TEXT)
		count.position = Vector2(52,3)
		count.size = Vector2(38,22)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(count)
	if weight_readout != null:
		var total: float = 0
		for item: String in inventory:
			total += float(_find_item_record(item).get("weight",0))*int(inventory[item])
		weight_readout.text = "보유 물품 무게  %.0f  ·  이름별 강화 정보 / 개체별 강화는 현재 버전 미연결" % total

func _refresh_detail(item_name: String) -> void:
	super._refresh_detail(item_name)
	var item: Dictionary = _find_item_record(item_name)
	detail_icon.texture=UI.item_icon(item,item_name,item_image_index.get("아이템",{}))
	var slot := str(item.get("slot",""))
	var worn: Dictionary = character_state.get("equipped_items",{})
	var current: Variant = worn.get(slot,{})
	if current is Dictionary and not current.is_empty() and str(current.get("name","")) != item_name:
		detail_text.text += "\n\n[color=#d8b878]착용 장비와 비교[/color]\n"+UI.safe(current.get("name",""))
		for pair: Array in [["atk","공격력"],["def","방어력"],["hit","명중"],["hpFlat","최대 HP"]]:
			var delta: int = int(item.get(pair[0],0))-int(current.get(pair[0],0))
			if delta != 0:
				detail_text.text += "\n%s  %s%d" % [pair[1],"+" if delta>0 else "",delta]
	var instances: Variant = character_state.get("item_instances",{})
	if instances is Dictionary:
		for id: Variant in instances:
			var entry: Variant = instances[id]
			if entry is Dictionary and str(entry.get("name","")) == item_name:
				detail_text.text += "\nID %s  ·  +%d" % [UI.safe(id),int(entry.get("enhance_level",entry.get("level",0)))]
	if _is_item_equipped(item_name):
		detail_action.tooltip_text = "장착 중 · 현재 게임 버전은 일반 장비 해제 동작을 제공하지 않습니다."
