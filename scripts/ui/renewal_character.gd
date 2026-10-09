extends "res://scripts/ui/lineage_side_ui.gd"

signal equipment_requested(item_name: String)
const UI = preload("res://scripts/ui/renewal_theme.gd")

func _ready() -> void:
	super._ready()
	theme=UI.make_theme()
	character_panel.add_theme_stylebox_override("panel",UI.box(Color("11171d"),UI.BRONZE,10))
	var header: HBoxContainer = character_panel.get_child(0).get_child(0)
	(header.get_child(header.get_child_count()-1) as Control).hide()
	equipment_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	# Additional equipment sets have no gameplay implementation.
	equipment_grid.get_parent().get_child(2).hide()
	for key: String in equipment_buttons:
		var button: Button = equipment_buttons[key]
		button.custom_minimum_size=Vector2(104,56)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.expand_icon=true
		button.add_theme_constant_override("icon_max_width",30)
		button.pressed.connect(func() -> void:
			var worn: Dictionary = character_state.get("equipped_items",{}).get(key,{})
			if not worn.is_empty(): equipment_requested.emit(str(worn.get("name",""))))

func _refresh_character() -> void:
	super._refresh_character()
	if character_panel==null: return
	for key: String in equipment_buttons:
		var button: Button = equipment_buttons[key]
		var record: Dictionary = character_state.get("equipped_items",{}).get(key,{})
		button.disabled=record.is_empty()
		if record.is_empty(): continue
		var grade := str(record.get("grade","일반"))
		var level := int(record.get("enhance_level",0))
		button.text=button.text.replace("\n","\n+%d " % level) if level>0 else button.text
		button.add_theme_stylebox_override("normal",UI.box(Color("1b2025"),UI.grade(grade),6))
		button.add_theme_color_override("font_color",UI.grade(grade))
		button.tooltip_text="%s · %s · +%d\n클릭: 보유 아이템 상세정보" % [record.get("name",""),grade,level]
		var path := str(record.get("image_path",""))
		button.icon=load(path) as Texture2D if path!="" and ResourceLoader.exists(path) else null
	if character_state.has("current_weight") and not character_state.has("max_weight"):
		weight_label.text="보유 무게 %.0f · 적재 한도 미연결" % float(character_state.current_weight)
		weight_bar.hide()
