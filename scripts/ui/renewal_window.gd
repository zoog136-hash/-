extends PanelContainer

signal navigate(section: String)
signal closed
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Ornament = preload("res://scripts/ui/renewal_ornament.gd")
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
var scroll_gestures: Dictionary = {}

func _ready() -> void:
	name = "RenewalWindow"
	theme = UI.make_theme()
	z_index = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",UI.box(Color(0.03,0.04,0.05,.98),UI.GOLD,16))
	var layout := VBoxContainer.new()
	add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	var titles := VBoxContainer.new()
	titles.name = "WorkspaceTitleDragArea"
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Grab only the title area. Close/nav controls keep their own pointer events.
	titles.mouse_filter = Control.MOUSE_FILTER_STOP
	titles.gui_input.connect(_on_title_drag_input)
	titles.add_theme_constant_override("separation",0)
	title_row.add_child(titles)
	heading = UI.label("TWILIGHT",24,UI.GOLD)
	titles.add_child(heading)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle = UI.label("황혼의 기록",12,UI.MUTED)
	titles.add_child(subtitle)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var close := UI.button("닫기  Esc",func() -> void: closed.emit(),Vector2(106,42))
	close.name = "CloseWindow"
	title_row.add_child(close)
	layout.add_child(HSeparator.new())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body)
	navigation_scroll = ScrollContainer.new()
	navigation_scroll.name = "WorkspaceNavigationScroll"
	navigation_scroll.custom_minimum_size.x = 132
	navigation_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	navigation_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	navigation_scroll.scroll_deadzone = 8
	body.add_child(navigation_scroll)
	var nav := VBoxContainer.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.mouse_filter = Control.MOUSE_FILTER_PASS
	navigation_scroll.add_child(nav)
	for pair: Array in [["character","캐릭터 · 장비"],["class_select","클래스 선택"],["inventory","인벤토리"],["skills","스킬 · 성장"],["변신","변신"],["마법인형","마법인형"],["성물","성물"],["아이템","아이템 도감"],["map","월드맵"],["quest","퀘스트"],["shop","잡화 상점"],["enhance","장비 강화"],["auto","자동사냥"],["settings","설정"],["log","전투 기록"]]:
		var id := str(pair[0])
		var b := UI.button(str(pair[1]),func() -> void:
			if not was_scroll_dragged(navigation_scroll):
				navigate.emit(id),Vector2(124,36))
		b.toggle_mode = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size",12)
		b.name = "Nav_"+id
		nav.add_child(b)
		register_scroll_drag(navigation_scroll,b)
		navigation[id] = b
	body.add_child(VSeparator.new())
	content = Control.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(content)
	layout.add_child(HSeparator.new())
	footer = UI.label("TWILIGHT  ·  황혼의 기사",11,UI.MUTED)
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(footer)
	var ornament := Ornament.new()
	add_child(ornament)
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
	var viewport := get_viewport_rect().size
	var extent := Vector2(maxf(200.0,minf(1160.0,viewport.x-48.0)),maxf(140.0,minf(642.0,viewport.y-48.0)))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = extent
	if not viewport_fitted or not title_dragged:
		position = (viewport-extent)*0.5
	else:
		_keep_title_visible()
	viewport_fitted = true

func _keep_title_visible() -> void:
	var view: Vector2 = get_viewport_rect().size
	# Keep a usable title/grab area visible even when a large desktop window
	# is intentionally dragged partially outside the viewport.
	position.x = clampf(position.x, minf(0.0,140.0-size.x),maxf(0.0,view.x-140.0))
	position.y = clampf(position.y, 0.0,maxf(0.0,view.y-64.0))

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
	heading.text = title
	subtitle.text = description
	for key: String in navigation:
		(navigation[key] as Button).button_pressed = key == section
	show()
	fit_viewport()

func clear() -> void:
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
