extends ScrollContainer

signal item_selected(index: int)
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const ROW_HEIGHT: int=114
var item_count: int:
	get:return entries.size()
var entries: Array[Dictionary]=[]
var views: Array[Button]=[]
var canvas: Control
var hud: Node
var selected: int=-1
var first: int=-1

func configure(owner_hud: Node) -> void:
	hud=owner_hud
	horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	canvas=Control.new()
	canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	add_child(canvas)
	get_v_scroll_bar().value_changed.connect(func(_value: float) -> void:_show_rows())
	resized.connect(_show_rows)

func clear() -> void:
	entries.clear()
	selected=-1
	first=-1
	canvas.custom_minimum_size.y=0
	for view: Button in views:view.hide()

func add_collection(record: Dictionary, mark: String, favorite: bool) -> void:
	entries.append({"record":record,"mark":mark,"favorite":favorite})
	canvas.custom_minimum_size.y=entries.size()*ROW_HEIGHT
	first=-1

func select(index: int) -> void:
	selected=index
	first=-1
	_show_rows()

func _show_rows() -> void:
	if not is_instance_valid(canvas) or size.y<1:return
	var start: int=maxi(0,floori(get_v_scroll_bar().value/ROW_HEIGHT))
	var count: int=ceili(size.y/ROW_HEIGHT)+2
	while views.size()<count:
		var button: Button=UI.button("",Callable(),Vector2(0,ROW_HEIGHT-4))
		button.pressed.connect(func() -> void:
			if not hud.workspace.was_scroll_dragged(self):item_selected.emit(int(button.get_meta("row_index",-1))))
		canvas.add_child(button)
		hud.workspace.register_scroll_drag(self,button)
		views.append(button)
	var changed: bool=first!=start
	first=start
	for offset: int in range(views.size()):
		var index: int=start+offset
		var button: Button=views[offset]
		button.visible=offset<count and index<entries.size()
		if not button.visible:continue
		button.position=Vector2(0,index*ROW_HEIGHT)
		button.size=Vector2(maxf(1,size.x-14),ROW_HEIGHT-4)
		if changed or button.get_meta("row_index",-1)!=index or not is_equal_approx(float(button.get_meta("row_width",-1)),button.size.x):_fill(button,index)

func _fill(button: Button, index: int) -> void:
	button.set_meta("row_index",index)
	button.set_meta("row_width",button.size.x)
	for child: Node in button.get_children():button.remove_child(child);child.queue_free()
	var data: Dictionary=entries[index]
	var record: Dictionary=data.record
	var active: bool=index==selected
	button.add_theme_stylebox_override("normal",UI.MATERIAL.from_flat(UI.box(Color("173243") if active else Color("111b24"),Color("4c8292") if active else Color("34404a"),4),true))
	button.tooltip_text=str(record.name)+"\n"+str(record.get("raw_effects",""))
	var column:=VBoxContainer.new()
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left=6;column.offset_right=-6;column.offset_top=5;column.offset_bottom=-5
	column.add_theme_constant_override("separation",5)
	button.add_child(column)
	var heading:=HBoxContainer.new()
	heading.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_child(heading)
	var title: Label=UI.label(("★ " if data.favorite else "")+str(record.name),13,UI.grade(str(record.grade)))
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title)
	heading.add_child(UI.label(str(data.mark),11,UI.MUTED))
	var icons:=HBoxContainer.new()
	icons.mouse_filter=Control.MOUSE_FILTER_IGNORE
	icons.add_theme_constant_override("separation",3)
	column.add_child(icons)
	var requirements: Array=record.requirements
	var edge: float=minf(44,maxf(20,(button.size.x-16-3*(requirements.size()-1))/maxi(1,requirements.size())))
	for raw: Variant in record.requirements:
		var requirement: Dictionary=raw
		var frame:=PanelContainer.new()
		frame.custom_minimum_size=Vector2(edge,edge)
		frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel",UI.slot_frame())
		icons.add_child(frame)
		var art:=TextureRect.new()
		art.custom_minimum_size=Vector2(edge-6,edge-6)
		art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter=Control.MOUSE_FILTER_IGNORE
		var source: Dictionary=hud.get_parent().equipment_collections.icon_record(str(requirement.name))
		UI.apply_item_visual(art,source,str(source.get("name",requirement.name)),hud.item_image_index.get("아이템",{}),"slot")
		frame.add_child(art)
		if requirement.enchant!=null:
			var level: Label=UI.label("+%d" % int(requirement.enchant),11,Color("68b9e0"))
			level.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			level.vertical_alignment=VERTICAL_ALIGNMENT_BOTTOM
			frame.add_child(level)
	var effect: Label=UI.label(str(record.get("raw_effects","")),11,UI.GOLD)
	effect.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(effect)
