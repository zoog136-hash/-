extends PanelContainer

signal navigate(section: String)
signal closed
signal back_requested
const UI = preload("res://scripts/ui/renewal_theme.gd")
const Ornament = preload("res://scripts/ui/renewal_ornament.gd")
const SafeArea = preload("res://scripts/ui/safe_area.gd")
var heading: Label
var subtitle: Label
var footer: Label
var content: Control
var title_dragging: bool = false
var title_dragged: bool = false
var title_drag_touch: int = -1
var title_drag_mouse: bool = false
var active_scroll: ScrollContainer
var active_scroll_touch: int = -1
var active_scroll_mouse: bool = false
var viewport_fitted: bool = false
var compact_menu_button: Button
var header_crest: Label
var scroll_gestures: Dictionary = {}
var current_section: String = ""
var title_row: HBoxContainer
var back_button: Button
var footer_separator: HSeparator

# Gameplay tools share a right-hand drawer. Views that need a map or a
# character stage use the wider workspace; neither carries a second menu rail.
const DRAWER_SECTIONS := ["menu", "inventory", "skills", "buffs",
	"friends", "mail", "ranking", "events",
	"collection", "growth", "dialogue", "dungeon", "special_dungeon"]

func is_drawer() -> bool:
	return current_section in DRAWER_SECTIONS

func _ready() -> void:
	name = "RenewalWindow"
	theme = UI.make_theme()
	z_index = 150
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel",UI.chrome_panel(Color("0c0e13"),UI.BRONZE,12))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",8)
	add_child(layout)
	var accent := ColorRect.new()
	accent.name = "HeaderGoldRule"
	accent.color = UI.GOLD
	accent.custom_minimum_size.y = 2
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(accent)
	title_row = HBoxContainer.new()
	title_row.custom_minimum_size.y = 44
	title_row.add_theme_constant_override("separation",8)
	layout.add_child(title_row)
	back_button = UI.button("‹",func() -> void: back_requested.emit(),Vector2(40,40))
	back_button.name = "BackWindow"
	back_button.tooltip_text = "이전 화면 · Esc"
	title_row.add_child(back_button)
	header_crest = UI.label("✧",31,UI.GOLD)
	header_crest.name = "HeaderCrest"
	header_crest.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(header_crest)
	var titles := VBoxContainer.new()
	titles.name = "WorkspaceTitleDragArea"
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Grab only the title area. Close/nav controls keep their own pointer events.
	titles.mouse_filter = Control.MOUSE_FILTER_STOP
	titles.gui_input.connect(_on_title_drag_input)
	titles.add_theme_constant_override("separation",0)
	title_row.add_child(titles)
	heading = UI.label("TWILIGHT",20,UI.GOLD)
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(heading)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle = UI.label("황혼의 기록",11,UI.MUTED)
	subtitle.clip_text = true
	titles.add_child(subtitle)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact_menu_button = UI.button("☰",func() -> void: navigate.emit("menu"),Vector2(40,40))
	compact_menu_button.name = "CompactMenuButton"
	compact_menu_button.tooltip_text = "전체 메뉴"
	title_row.add_child(compact_menu_button)
	var close := UI.button("",func() -> void: closed.emit(),Vector2(40,40))
	close.icon = UI.icon("close")
	close.tooltip_text = "닫기 · Esc"
	close.name = "CloseWindow"
	close.add_theme_stylebox_override("normal",UI.tab_frame())
	title_row.add_child(close)
	layout.add_child(HSeparator.new())
	content = Control.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(content)
	footer_separator = HSeparator.new()
	layout.add_child(footer_separator)
	footer = UI.label("TWILIGHT  ·  황혼의 기사",11,UI.MUTED)
	footer.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(footer)
	var ornament := Ornament.new()
	ornament.name = "DecorativeFrame"
	add_child(ornament)
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var stretch: float = maxf(.01,get_viewport().get_final_transform().get_scale().x)
	scale = Vector2.ONE/maxf(.01,minf(1.0,stretch))
	var available: Rect2 = SafeArea.available(get_viewport())
	var viewport := available.size/scale
	var drawer: bool = is_drawer()
	footer.visible = not drawer and viewport.y >= 500
	footer_separator.visible = footer.visible
	subtitle.visible = not drawer and viewport.y >= 450
	(get_child(0) as VBoxContainer).add_theme_constant_override("separation",5 if viewport.y < 500 else 8)
	var preferred_width: float = 960.0
	var preferred_height: float = 560.0
	if drawer: preferred_width = 480.0
	elif current_section == "character": preferred_width = 900.0
	elif current_section in ["settings","auto","log","controls","info"]: preferred_width = 800.0
	elif current_section in ["map","class_select"]: preferred_width = 1160.0
	# Keep HUD shortcuts above, and both quickslot banks below, the drawer.
	var top: float = minf(82.0,viewport.y*.115)
	var bottom: float = minf(88.0,viewport.y*.125)
	if drawer: preferred_height = viewport.y-top-bottom
	var extent := Vector2(maxf(200.0,minf(preferred_width,viewport.x-24.0)),maxf(140.0,minf(preferred_height,viewport.y-top-bottom)))
	var compact: bool = viewport.x < 840.0
	compact_menu_button.visible = true
	header_crest.visible = not drawer and not compact
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = extent
	if not viewport_fitted or not title_dragged:
		position = available.position+(Vector2(viewport.x-extent.x-12.0,top) if drawer else Vector2((viewport.x-extent.x)*.5,top+(viewport.y-top-bottom-extent.y)*.5))*scale
	else:
		_keep_title_visible()
	viewport_fitted = true

func _keep_title_visible() -> void:
	var view: Rect2 = SafeArea.available(get_viewport())
	position.x = clampf(position.x, view.position.x,maxf(view.position.x,view.end.x-size.x*scale.x))
	position.y = clampf(position.y, view.position.y,maxf(view.position.y,view.end.y-size.y*scale.y))

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
	# Preserve the player's dragged position within the same kind of window.
	# Crossing between a wide screen and a gameplay drawer restores its anchor.
	if is_drawer() != (section in DRAWER_SECTIONS):
		title_dragged = false
	current_section = section
	heading.text = title
	subtitle.text = description
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
