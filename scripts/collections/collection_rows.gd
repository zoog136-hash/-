extends ScrollContainer

signal item_selected(index: int)
signal material_selected(index: int, slot_id: String)
signal favorite_requested(index: int)
const UI=preload("res://scripts/ui/renewal_theme.gd")
const Surfaces=preload("res://scripts/ui/reference_surfaces.gd")
const TouchButton=preload("res://scripts/growth/growth_touch_button.gd")
const ROW_HEIGHT: int=90
var item_count: int:
	get:return entries.size()
var entries: Array[Dictionary]=[]
var views: Array[Button]=[]
var canvas: Control
var hud: Node
var selected: int=-1
var first: int=-1
var presenter: Node

func configure(owner_hud: Node, owner_presenter: Node=null) -> void:
	hud=owner_hud
	presenter=owner_presenter
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
		var button: Button=_button()
		button.custom_minimum_size=Vector2(0,ROW_HEIGHT-4)
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
	button._cancel_touch()
	button.set_meta("row_index",index)
	button.set_meta("row_width",button.size.x)
	for child: Node in button.get_children():button.remove_child(child);child.queue_free()
	var data: Dictionary=entries[index]
	var record: Dictionary=data.record
	var active: bool=index==selected
	button.add_theme_stylebox_override("normal",UI.MATERIAL.from_flat(UI.box(Color("193b3b") if active else Color("13191d"),Color("6b8980") if active else Color("303738"),4),true))
	button.tooltip_text=str(record.name)+"\n"+str(record.get("raw_effects",""))
	var line:=HBoxContainer.new()
	line.mouse_filter=Control.MOUSE_FILTER_PASS
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left=5;line.offset_right=-5;line.offset_top=6;line.offset_bottom=-6
	line.add_theme_constant_override("separation",6)
	button.add_child(line)
	var favorite: Button=_button()
	favorite.name="FavoriteCollection"
	favorite.text="★" if data.favorite else "☆"
	favorite.custom_minimum_size=Vector2(44,44)
	favorite.add_theme_font_size_override("font_size",21)
	favorite.add_theme_color_override("font_color",UI.GOLD if data.favorite else UI.MUTED)
	for state: String in ["normal","hover","pressed"]:favorite.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	favorite.pressed.connect(func() -> void:favorite_requested.emit(index))
	line.add_child(favorite)
	var available_width: float=maxf(1,button.size.x-72)
	var title_column:=VBoxContainer.new()
	title_column.custom_minimum_size.x=floorf(available_width*.30)
	title_column.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	title_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	line.add_child(title_column)
	var title: Label=UI.label(str(record.name),12,UI.TEXT)
	title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	title.max_lines_visible=2
	title.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	title_column.add_child(title)
	var mark: Label=UI.label(str(data.mark),11,Color("84b38a") if data.mark=="완성" else UI.MUTED)
	title_column.add_child(mark)
	var effect: Label=UI.label(str(record.get("raw_effects","")),12,UI.GOLD)
	effect.custom_minimum_size.x=floorf(available_width*.23)
	effect.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	effect.max_lines_visible=3
	effect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	line.add_child(effect)
	var icons:=HBoxContainer.new()
	icons.size_flags_vertical=Control.SIZE_SHRINK_CENTER
	icons.mouse_filter=Control.MOUSE_FILTER_PASS
	icons.add_theme_constant_override("separation",3)
	line.add_child(icons)
	var requirements: Array=record.requirements
	var capacity: int=maxi(1,floori((available_width*.47)/47.0))
	var shown: int=requirements.size() if requirements.size()<=capacity else maxi(0,capacity-1)
	for number: int in range(shown):
		var requirement: Dictionary=requirements[number]
		var frame: Button=_button()
		frame.name="CollectionMaterial_"+str(number)
		frame.custom_minimum_size=Vector2(44,44)
		frame.set_meta("collection_id",str(record.id));frame.set_meta("slot_id",str(requirement.slot_id))
		frame.add_theme_stylebox_override("normal",UI.slot_frame())
		frame.pressed.connect(func() -> void:material_selected.emit(index,str(requirement.slot_id)))
		icons.add_child(frame)
		if is_instance_valid(presenter):presenter.decorate_material(frame,record,requirement,38)
	if shown<requirements.size():
		var more: Button=_button()
		more.name="MoreCollectionMaterials";more.text="+%d" % (requirements.size()-shown)
		more.custom_minimum_size=Vector2(44,44)
		more.tooltip_text="선택 상세에서 모든 재료 %d종 보기" % requirements.size()
		more.pressed.connect(func() -> void:material_selected.emit(index,str(requirements[shown].slot_id)))
		icons.add_child(more)

func _button() -> Button:
	var button: Button=UI.button("",Callable(),Vector2.ZERO)
	button.set_script(TouchButton)
	button.scroll_host=hud.workspace;button.scroll_area=self
	return button
