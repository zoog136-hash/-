extends PanelContainer

signal navigate(section: String)
signal back_requested
signal closed
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Ornament = preload("res://scripts/ui/renewal_ornament.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")
var heading: Label
var subtitle: Label
var footer: Label
var content: Control
var navigation: Dictionary = {}
var title_dragging: bool = false
var title_dragged: bool = false
var title_drag_touch: int = -1
var title_drag_mouse: bool = false
var active_scroll: ScrollContainer
var active_scroll_touch: int = -1
var active_scroll_mouse: bool = false
var viewport_fitted: bool = false
var navigation_scroll: ScrollContainer
var navigation_separator: VSeparator
var compact_menu_button: Button
var teleport_button: Button
var back_button: Button
var header_crest: Label
var scroll_gestures: Dictionary = {}
var current_section: String = ""

func _ready() -> void:
	name = "RenewalWindow"
	theme = UI.make_theme()
	z_index = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",UI.chrome_panel(Color("201a17"),UI.BRONZE,8))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",5)
	add_child(layout)
	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size.y = 32
	layout.add_child(title_row)
	var titles := VBoxContainer.new()
	titles.name = "WorkspaceTitleDragArea"
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.mouse_filter = Control.MOUSE_FILTER_STOP
	titles.gui_input.connect(_on_title_drag_input)
	title_row.add_child(titles)
	heading = UI.label("",17,UI.TEXT)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(heading)
	subtitle = UI.label("",11,UI.MUTED)
	titles.add_child(subtitle)
	subtitle.hide()
	back_button = UI.button("← 뒤로",func() -> void: back_requested.emit(),Vector2(72,32))
	back_button.name = "BackWindow"
	back_button.tooltip_text = "이전 화면 · Esc"
	back_button.hide()
	title_row.add_child(back_button)
	compact_menu_button = UI.button("메뉴",func() -> void: navigate.emit("menu"),Vector2(54,32))
	compact_menu_button.name = "CompactMenuButton"
	compact_menu_button.hide()
	title_row.add_child(compact_menu_button)
	teleport_button = UI.button("지역 이동",func() -> void: navigate.emit("teleport"),Vector2(82,32))
	teleport_button.name = "MenuTeleportShortcut"
	teleport_button.tooltip_text = "기존 텔레포트 안내 · 비용과 이동 제한 유지"
	teleport_button.hide()
	title_row.add_child(teleport_button)
	var close := UI.button("",func() -> void: closed.emit(),Vector2(32,32))
	close.icon = UI.icon("close")
	close.tooltip_text = "닫기 · Esc"
	close.name = "CloseWindow"
	close.add_theme_stylebox_override("normal",UI.box(Color("542d24"),Color("957963"),3))
	title_row.add_child(close)
	layout.add_child(HSeparator.new())
	content = Control.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(content)
	footer = UI.label("",11,UI.MUTED)
	layout.add_child(footer)
	footer.hide()
	# Navigation belongs to the actual menu; content windows have no dashboard sidebar.
	get_viewport().size_changed.connect(fit_viewport)
	fit_viewport()
	hide()

# A drag starting on a Button is normally swallowed before ScrollContainer
# sees it. Forward native finger and mouse gestures from the button itself.
# Mouse wheel / scrollbar and ordinary taps remain handled by Godot.
func register_scroll_drag(scroll: ScrollContainer, target: Control) -> void:
	target.mouse_filter = Control.MOUSE_FILTER_PASS
	target.gui_input.connect(_on_scroll_drag_input.bind(scroll,target))

func was_scroll_dragged(scroll: ScrollContainer) -> bool:
	return bool((scroll_gestures.get(scroll.get_instance_id(), {}) as Dictionary).get("dragged", false))

func _on_scroll_drag_input(event: InputEvent, scroll: ScrollContainer, _target: Control) -> void:
	var key: int = scroll.get_instance_id()
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and not touch.canceled and active_scroll_touch == -1:
			active_scroll = scroll
			active_scroll_touch = touch.index
			scroll_gestures[key] = {"touch":touch.index,"mouse":false,"distance":0.0,"dragged":false}
		elif touch.index == active_scroll_touch and (not touch.pressed or touch.canceled):
			active_scroll_touch = -1
			active_scroll = null
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			active_scroll = scroll
			active_scroll_mouse = true
			scroll_gestures[key] = {"touch":-1,"mouse":true,"distance":0.0,"dragged":false}
		elif active_scroll == scroll:
			active_scroll_mouse = false
			active_scroll = null

func _scroll_gesture_motion(delta_y: float) -> void:
	if active_scroll == null or not is_instance_valid(active_scroll):
		return
	var key: int = active_scroll.get_instance_id()
	var gesture: Dictionary = scroll_gestures.get(key, {})
	gesture["distance"] = float(gesture.get("distance", 0.0)) + absf(delta_y)
	if float(gesture["distance"]) > 8.0:
		gesture["dragged"] = true
		_scroll_by_drag(active_scroll, delta_y)
		# Stop child buttons and the native ScrollContainer both processing a swipe.
		get_viewport().set_input_as_handled()
	scroll_gestures[key] = gesture

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	# Keep title/window and button-originated scroll drags captured after the
	# pointer leaves the original Control. Android drag events aren't guaranteed
	# to remain over the originating button.
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == title_drag_touch and title_dragging:
			position += drag.relative
			_keep_title_visible()
			get_viewport().set_input_as_handled()
		elif drag.index == active_scroll_touch:
			_scroll_gesture_motion(drag.relative.y)
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if not touch.pressed or touch.canceled:
			if touch.index == title_drag_touch:
				title_drag_touch = -1
				title_dragging = false
			if touch.index == active_scroll_touch:
				active_scroll_touch = -1
				active_scroll = null
	elif event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event
		if title_drag_mouse and title_dragging and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			position += motion.relative
			_keep_title_visible()
			get_viewport().set_input_as_handled()
		elif active_scroll_mouse and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_scroll_gesture_motion(motion.relative.y)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		title_drag_mouse = false
		if title_drag_touch == -1:
			title_dragging = false
		active_scroll_mouse = false
		active_scroll = null

func _scroll_by_drag(scroll: ScrollContainer, delta_y: float) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var max_scroll: int = maxi(0,ceili(bar.max_value-bar.page))
	scroll.scroll_vertical = clampi(scroll.scroll_vertical-roundi(delta_y),0,max_scroll)

func fit_viewport() -> void:
	var stretch: float = maxf(.01,get_viewport().get_final_transform().get_scale().x)
	scale = Vector2.ONE/maxf(.01,minf(1.0,stretch))
	var available: Rect2 = SafeArea.available(get_viewport())
	var viewport: Vector2 = available.size/scale
	var shelf: bool = current_section in ["inventory","skills","menu","quickbind"]
	var left: bool = current_section in ["character","stats","warehouse","sell"]
	var fullscreen: bool = current_section in ["변신","마법인형","성물","shop","map","class_select","아이템","emblems","guardians"]
	var width: float = 378 if shelf or left else 840
	var height: float = minf(508,viewport.y-150)
	if current_section == "menu": width = 450
	if current_section == "inventory" and get_meta("expanded",false): width = 692
	if current_section == "detailed_status": width = 680
	if fullscreen:
		width = viewport.x
		height = viewport.y
	elif not shelf and not left: height = minf(568,viewport.y-100)
	if current_section in ["character","stats"]: height = minf(610,viewport.y-100)
	if current_section == "detailed_status": height = minf(508,viewport.y-110)
	width = maxf(1,minf(width,viewport.x-12 if not fullscreen else viewport.x))
	height = minf(viewport.y,maxf(220,height))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(width,height)
	# Keep PR91 reference widths; translate anchors into the usable viewport.
	if shelf: position = Vector2(viewport.x-width-12, minf(82,maxf(0,viewport.y-height-110)))*scale
	elif left: position = Vector2(12,minf(82,maxf(0,viewport.y-height-12)))*scale
	elif fullscreen: position = Vector2.ZERO
	else: position = Vector2((viewport.x-width)*.5,maxf(0,(viewport.y-height-80)*.5))*scale
	if current_section == "detailed_status": position = Vector2(minf(402,viewport.x-width-12),82)*scale
	position += available.position
	_clamp_to_safe_area(available)
	subtitle.hide()
	footer.hide()
	viewport_fitted = true

func _clamp_to_safe_area(available: Rect2) -> void:
	position.x = clampf(position.x,available.position.x,maxf(available.position.x,available.end.x-size.x*scale.x))
	position.y = clampf(position.y,available.position.y,maxf(available.position.y,available.end.y-size.y*scale.y))

func _keep_title_visible() -> void:
	var available: Rect2 = SafeArea.available(get_viewport())
	if available != get_viewport_rect():
		_clamp_to_safe_area(available)
		return
	var view: Vector2 = get_viewport_rect().size
	position.x = clampf(position.x, minf(0.0,(140.0-size.x)*scale.x),maxf(0.0,view.x-140.0*scale.x))
	position.y = clampf(position.y, 0.0,maxf(0.0,view.y-64.0*scale.y))

func _on_title_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			title_drag_mouse = true
			title_dragging = true
			title_dragged = true
			accept_event()
		else:
			title_drag_mouse = false
			if title_drag_touch == -1:
				title_dragging = false
	elif event is InputEventMouseMotion and title_drag_mouse and title_dragging:
		# Native motions are handled by _input before GUI dispatch. Retain this
		# path for direct title-gui_input calls and legacy playtest regression.
		position += event.relative
		_keep_title_visible()
		accept_event()
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and not touch.canceled and title_drag_touch == -1:
			title_drag_touch = touch.index
			title_dragging = true
			title_dragged = true
			accept_event()
		elif not touch.pressed and touch.index == title_drag_touch:
			title_drag_touch = -1
			title_dragging = false
	elif event is InputEventScreenDrag and title_dragging and event.index == title_drag_touch:
		position += event.relative
		_keep_title_visible()
		accept_event()

func open(section: String, title: String, description: String) -> void:
	current_section = section
	title_dragged = false
	heading.text = title
	subtitle.text = description
	var can_navigate: bool = not navigate.get_connections().is_empty()
	compact_menu_button.visible = can_navigate and section not in ["menu","class_select"]
	teleport_button.visible = can_navigate and section == "menu"
	for key: String in navigation:
		(navigation[key] as Button).button_pressed = key == section
	show()
	fit_viewport()

func set_back_available(enabled: bool) -> void:
	if is_instance_valid(back_button):
		back_button.visible = enabled

func clear() -> void:
	active_scroll = null
	active_scroll_touch = -1
	active_scroll_mouse = false
	title_dragging = false
	title_drag_touch = -1
	title_drag_mouse = false
	scroll_gestures.clear()
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()

func mount(control: Control) -> void:
	if control.get_parent() != null:
		control.reparent(content)
	else:
		content.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func column() -> VBoxContainer:
	var v := VBoxContainer.new()
	mount(v)
	return v
