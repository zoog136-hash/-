extends "res://scripts/ui/lineage_side_ui.gd"

signal detailed_stats_requested

signal equipment_requested(item_name: String)
signal class_selection_requested
const UI = preload("res://scripts/ui/renewal_theme.gd")
const ReferenceSurfaces=preload("res://scripts/ui/reference_surfaces.gd")
var equipment_stage: Control
var paperdoll: TextureRect
var gear_icons: Dictionary = {}
var gear_badges: Dictionary = {}
var equipment_caption: Label
const EXTRA_SLOTS = [["pants","하의"],["shoulder","견갑"],["earring1","귀걸이 I"],["earring2","귀걸이 II"],["seal1","인장 I"],["seal2","인장 II"],["gaiters","각반"],["bracelet","팔찌"],["badge","휘장"],["crystal","수정"],["catalyst","카탈리스트"],["rune","룬"]]
var equipment_page_index: int = 0
var character_tabs: Control
var empty_slot_art: Dictionary={}
var item_art_bound: bool=false

func _ready() -> void:
	super._ready()
	theme = UI.make_theme()
	character_panel.add_theme_stylebox_override("panel",UI.box(Color(0,0,0,0),Color(0,0,0,0),0))
	var outer: VBoxContainer = character_panel.get_child(0)
	outer.add_theme_constant_override("separation",4)
	var header: HBoxContainer = outer.get_child(0)
	(header.get_child(0) as Label).text = ""
	(header.get_child(0) as Label).hide()
	(header.get_child(0) as Label).add_theme_font_size_override("font_size",14)
	(header.get_child(header.get_child_count()-1) as Control).hide()
	header.custom_minimum_size.y = 32
	tab_equipment.custom_minimum_size.y = 32
	tab_stats.custom_minimum_size.y = 32
	var change_class := UI.button("클래스",func() -> void: class_selection_requested.emit(),Vector2(64,32))
	change_class.name = "ChangeClassButton"
	header.add_child(change_class)
	character_tabs=header
	(outer.get_child(1) as Control).hide()
	var identity: HBoxContainer = outer.get_child(2)
	identity.hide()
	identity.custom_minimum_size.y = 40
	(identity.get_child(0) as Control).hide()
	(identity.get_child(2) as Control).hide()
	(identity.get_child(0) as Control).custom_minimum_size = Vector2(54,54)
	character_name.add_theme_font_size_override("font_size",17)
	character_level.hide()
	weight_bar.custom_minimum_size.y = 4
	weight_label.add_theme_font_size_override("font_size",11)
	var detail_button := UI.button("상세 스테이터스",func() -> void: detailed_stats_requested.emit(),Vector2(0,32))
	ReferenceSurfaces.action(detail_button)
	detail_button.name = "OpenDetailedStatus"
	outer.add_child(detail_button)
	_refresh_character()

func _build_equipment_page() -> Control:
	var page := HBoxContainer.new()
	page.add_theme_constant_override("separation",12)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(left)
	equipment_caption = UI.section("장착 장비",14)
	var page_row := HBoxContainer.new()
	left.add_child(page_row)
	equipment_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_row.add_child(equipment_caption)
	for page_index: int in range(2):
		var button := UI.button(str(page_index+1),func() -> void:
			equipment_page_index = page_index
			_layout_equipment(),Vector2(28,24))
		button.name = "EquipmentPage%d" % page_index
		button.tooltip_text = "기본 장비" if page_index == 0 else "추가 장비·장신구"
		page_row.add_child(button)
	equipment_stage = Control.new()
	equipment_stage.name = "EquipmentPaperdoll"
	equipment_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_stage.custom_minimum_size = Vector2.ZERO
	left.add_child(equipment_stage)
	var backdrop := Panel.new()
	backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel",ReferenceSurfaces.inset(0))
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
	for spec: Array in EQUIPMENT_SLOTS+EXTRA_SLOTS:
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
	left.move_child(page_row,left.get_child_count()-1)
	equipment_caption.hide()
	for button: Node in page_row.get_children():
		if button is Button:
			button.text="기본 장비" if button.name=="EquipmentPage0" else "추가 장비"
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			ReferenceSurfaces.action(button)
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
		equipment_stage.custom_minimum_size.x = 0)
	return page

func _build_stats_page() -> Control:
	var page: Control=super._build_stats_page()
	var column: VBoxContainer=page.get_child(0)
	var grid: GridContainer=column.get_child(1)
	grid.columns=2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	var rows: Array[Node]=grid.get_children()
	# The inspected guide pairs STR/INT, DEX/WIS and CON/CHA.
	for index: int in range(6):grid.move_child(rows[[0,3,1,4,2,5][index]],index)
	rows=grid.get_children()
	for index: int in range(rows.size()):
		var row: HBoxContainer=rows[index]
		var frame:=PanelContainer.new()
		frame.custom_minimum_size=Vector2(0,66)
		frame.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		frame.add_theme_stylebox_override("panel",ReferenceSurfaces.inset(6))
		grid.add_child(frame)
		grid.move_child(frame,index)
		row.reparent(frame)
		row.custom_minimum_size=Vector2.ZERO
		row.add_theme_constant_override("separation",4)
		var title: Label=row.get_child(0)
		title.custom_minimum_size.x=32
		title.add_theme_font_size_override("font_size",14)
		title.add_theme_color_override("font_color",UI.TEXT)
		var value: Label=row.get_child(1)
		value.custom_minimum_size.x=0
		value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		(row.get_child(2) as Button).custom_minimum_size=Vector2(28,28)
		(row.get_child(2) as Button).size_flags_vertical=Control.SIZE_SHRINK_CENTER
	var note: Label=column.get_child(2)
	note.text="기본·추가 수치는 각 능력치의 상세 안내에서 확인할 수 있습니다."
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	page.resized.connect(func() -> void:
		for frame: Control in grid.get_children():frame.custom_minimum_size.y=48 if page.size.y<280 else 66)
	return page

func bind_item_art(hud: Node) -> void:
	if item_art_bound:return
	item_art_bound=true
	var world: Node=hud.get_parent()
	var images: Dictionary=hud.item_image_index.get("아이템",{})
	var wanted: Dictionary={"ring":true,"earring":true,"seal":true}
	for spec: Array in EQUIPMENT_SLOTS+EXTRA_SLOTS:wanted[spec[0]]=true
	for raw: Variant in hud.catalog_data.get("아이템",[]):
		if not raw is Dictionary:continue
		var record: Dictionary=raw
		var slot: String=world._equipment_slot_base(record)
		if not wanted.has(slot) or empty_slot_art.has(slot):continue
		var source: String=str(record.get("image_path",images.get(str(record.get("name","")),"")))
		if not source.begins_with("res://assets/") or not ResourceLoader.exists(source):continue
		var texture: Texture2D=UI.item_icon(record,str(record.get("name","")),images)
		if texture==null:continue
		empty_slot_art[slot]=texture
		for pair: Array in [["ring","ring1","ring2"],["earring","earring1","earring2"],["seal","seal1","seal2"]]:
			if slot==pair[0]:
				empty_slot_art[pair[1]]=texture
				empty_slot_art[pair[2]]=texture
		if empty_slot_art.size()>=27:break

func mount_window_header(window: Control) -> void:
	window.mount_header_filters(character_tabs)

func _layout_equipment() -> void:
	var extent: Vector2=equipment_stage.size
	var edge: float=minf(56,maxf(24,(extent.y-8)/6.0-2))
	var step: float=(extent.y-8)/6.0
	paperdoll.position=Vector2(edge+14,4)
	paperdoll.size=Vector2(maxf(0,extent.x-2*(edge+14)),maxf(0,extent.y-8))
	for key: String in equipment_buttons:
		var second: bool=EXTRA_SLOTS.any(func(spec: Array) -> bool:return spec[0]==key)
		equipment_buttons[key].visible=second==(equipment_page_index==1)
	var sides: Array=[
		["helmet","weapon","body","necklace","boots","tshirt"],
		["cloak","gloves","belt","ring1","ring2","offhand"]
	] if equipment_page_index==0 else [
		["shoulder","pants","gaiters","bracelet","badge","crystal"],
		["earring1","earring2","seal1","seal2","catalyst","rune"]
	]
	for side: int in range(2):
		for index: int in range(6):
			var key: String=sides[side][index]
			var button: Button=equipment_buttons[key]
			button.custom_minimum_size=Vector2(edge,edge)
			button.size=Vector2(edge,edge)
			button.position=Vector2(4 if side==0 else extent.x-edge-4,4+index*step)
			var icon: TextureRect=gear_icons[key]
			icon.position=Vector2(3,3)
			icon.size=Vector2(edge-6,edge-6)
			var caption: Label=button.get_child(1)
			caption.position=Vector2.ZERO
			caption.size=Vector2(edge,edge)
			caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
			caption.visible=button.disabled and icon.texture==null

func _refresh_character() -> void:
	super._refresh_character()
	if equipment_stage == null: return
	character_job.text = "Lv.%d  %s" % [int(character_state.get("level",1)),str(character_state.get("job_class",""))]
	for key: String in ["STR","DEX","CON","INT","WIS","CHA"]:
		var label: Label = stats_page.find_child(key+"Value",true,false)
		var base: int = int(character_state.get("base_attributes",{}).get(key.to_lower(),0))
		var total: int = int(character_state.get(key.to_lower(),0))
		if label != null:
			label.text = str(total)
			label.add_theme_font_size_override("font_size",17)
			label.tooltip_text = "최종 %d · 기본 %d + 추가 %+d" % [total,base,total-base]
	paperdoll.texture = character_preview.texture
	var filled: int = 0
	for spec: Array in EQUIPMENT_SLOTS+EXTRA_SLOTS:
		var key: String = str(spec[0])
		var button: Button = equipment_buttons[key]
		var record: Dictionary = character_state.get("equipped_items",{}).get(key,{})
		button.text = ""
		button.disabled = record.is_empty()
		var icon: TextureRect = gear_icons[key]
		var badge: Label = gear_badges[key]
		badge.text = ""
		if record.is_empty():
			UI.clear_item_visual(icon)
			icon.texture = empty_slot_art.get(key)
			icon.modulate = Color(.48,.48,.48,.42)
			button.tooltip_text = str(spec[1])+" · 미장착"
			button.add_theme_stylebox_override("normal",UI.slot_frame())
			continue
		filled += 1
		var grade: String = str(record.get("grade","일반"))
		var level: int = int(record.get("enhance_level",0))
		UI.apply_item_visual(icon,record,str(record.get("name","")),{},"equipment")
		icon.modulate = Color.WHITE
		badge.text = "+%d" % level if level > 0 else ""
		button.add_theme_stylebox_override("normal",UI.item_frame(grade))
		button.tooltip_text = "%s · %s · +%d\n클릭: 장비 선택 및 교체" % [_equipped_display_name(record),grade,level]
	equipment_caption.text = "장착 장비  %d / 24" % filled
	_layout_equipment()
