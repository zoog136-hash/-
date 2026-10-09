extends "res://scripts/ui/lineage_side_ui.gd"

signal equipment_requested(item_name: String)
signal class_selection_requested
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Stage = preload("res://scripts/ui/renewal_stage.gd")
var equipment_stage: Control
var paperdoll: TextureRect
var gear_icons: Dictionary = {}
var gear_badges: Dictionary = {}
var equipment_caption: Label

func _ready() -> void:
	super._ready()
	theme = UI.make_theme()
	character_panel.add_theme_stylebox_override("panel",UI.box(Color("101219"),UI.BRONZE,8))
	var outer: VBoxContainer = character_panel.get_child(0)
	var header: HBoxContainer = outer.get_child(0)
	(header.get_child(0) as Label).text = "장비 정보"
	(header.get_child(0) as Label).add_theme_font_size_override("font_size",14)
	(header.get_child(header.get_child_count()-1) as Control).hide()
	header.custom_minimum_size.y = 36
	var change_class := UI.button("클래스",func() -> void: class_selection_requested.emit(),Vector2(80,34))
	change_class.name = "ChangeClassButton"
	header.add_child(change_class)
	var identity: HBoxContainer = outer.get_child(2)
	identity.custom_minimum_size.y = 60
	(identity.get_child(0) as Control).custom_minimum_size = Vector2(54,54)
	character_name.add_theme_font_size_override("font_size",17)
	_refresh_character()

func _build_equipment_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation",12)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(left)
	equipment_caption = UI.section("장착 장비",14)
	left.add_child(equipment_caption)
	equipment_stage = Control.new()
	equipment_stage.name = "EquipmentPaperdoll"
	equipment_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_stage.custom_minimum_size = Vector2(350,260)
	left.add_child(equipment_stage)
	var backdrop := Stage.new()
	equipment_stage.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paperdoll = TextureRect.new()
	paperdoll.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paperdoll.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paperdoll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_stage.add_child(paperdoll)
	equipment_grid = GridContainer.new()
	equipment_grid.name = "EquipmentCompatibilityGrid"
	equipment_grid.hide()
	page.add_child(equipment_grid)
	for spec: Array in EQUIPMENT_SLOTS:
		var key: String = str(spec[0])
		var button := UI.button("",func() -> void:
			var record: Dictionary = character_state.get("equipped_items",{}).get(key,{})
			if not record.is_empty():
				var reference: String = str(record.get("name",""))
				var id: String = str(record.get("instance_id",""))
				equipment_requested.emit(reference+("@@@"+id if id != "" else "")),Vector2(56,54))
		button.name = "Equipment_"+key
		button.add_theme_stylebox_override("normal",UI.slot_frame())
		button.add_theme_stylebox_override("disabled",UI.slot_frame())
		equipment_stage.add_child(button)
		equipment_buttons[key] = button
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(9,2)
		icon.size = Vector2(38,35)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		gear_icons[key] = icon
		var title := UI.label(str(spec[1]),9,UI.MUTED)
		title.position = Vector2(0,38)
		title.size = Vector2(56,14)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(title)
		var badge := UI.label("",10,UI.GOLD)
		badge.position = Vector2(3,0)
		button.add_child(badge)
		gear_badges[key] = badge
	equipment_stage.resized.connect(_layout_equipment)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 235
	page.add_child(right)
	right.add_child(UI.section("능력치 상세",16))
	right.add_child(HSeparator.new())
	stat_summary = UI.rich("")
	stat_summary.fit_content = false
	stat_summary.scroll_active = true
	stat_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stat_summary.add_theme_font_size_override("normal_font_size",13)
	right.add_child(stat_summary)
	page.resized.connect(func() -> void:
		right.visible = page.size.x >= 620
		equipment_stage.custom_minimum_size.x = 0 if page.size.x < 620 else 350)
	return page

func _layout_equipment() -> void:
	var extent: Vector2 = equipment_stage.size
	paperdoll.position = Vector2(62,5)
	paperdoll.size = Vector2(maxf(0,extent.x-124),maxf(0,extent.y-65))
	var sides: Array = [["helmet","weapon","body","boots"],["necklace","offhand","cloak","gloves"]]
	for side: int in range(2):
		for i: int in range(4):
			var button: Button = equipment_buttons[sides[side][i]]
			button.position = Vector2(6 if side == 0 else extent.x-62,5+i*57)
			button.size = Vector2(56,54)
	for i: int in range(4):
		var button: Button = equipment_buttons[["tshirt","belt","ring1","ring2"][i]]
		button.position = Vector2((extent.x-236)*.5+i*60,extent.y-57)
		button.size = Vector2(56,54)

func _refresh_character() -> void:
	super._refresh_character()
	if equipment_stage == null: return
	paperdoll.texture = character_preview.texture
	var filled: int = 0
	for spec: Array in EQUIPMENT_SLOTS:
		var key: String = str(spec[0])
		var button: Button = equipment_buttons[key]
		var record: Dictionary = character_state.get("equipped_items",{}).get(key,{})
		button.text = ""
		button.disabled = record.is_empty()
		var icon: TextureRect = gear_icons[key]
		var badge: Label = gear_badges[key]
		badge.text = ""
		if record.is_empty():
			icon.texture = UI.icon("attack" if key == "weapon" else "character")
			icon.modulate = Color(1,1,1,.18)
			button.tooltip_text = str(spec[1])+" · 미장착"
			button.add_theme_stylebox_override("normal",UI.slot_frame())
			continue
		filled += 1
		var grade: String = str(record.get("grade","일반"))
		var level: int = int(record.get("enhance_level",0))
		icon.texture = UI.item_icon(record,str(record.get("name","")),{})
		icon.modulate = Color.WHITE
		badge.text = "+%d" % level if level > 0 else ""
		button.add_theme_stylebox_override("normal",UI.item_frame(grade))
		button.tooltip_text = "%s · %s · +%d\n클릭: 장비 선택 및 교체" % [_equipped_display_name(record),grade,level]
	equipment_caption.text = "장착 장비  %d / 12" % filled
	_layout_equipment()
