extends Node2D
## Original ScrollView inner-container fields. The declared caller owns its
## original drag/bounce/inertia behavior; this adapter invents no substitute.
var content: Node2D
var original_inner_size: Vector2
var _extent: Vector2
var _input_area: Control
var _input_callback: Callable

func configure(options: Dictionary, extent: Vector2) -> void:
	_extent=extent
	original_inner_size=Vector2(maxf(extent.x,float(options.innerSize[0])),maxf(extent.y,float(options.innerSize[1])))
	content=Node2D.new()
	content.name="SourceOriginalScrollContent"
	# ScrollView::onSizeChanged begins at the original top-left position.
	content.position=Vector2(0,original_inner_size.y-extent.y)
	add_child(content)

func set_source_position(position_value: Vector2) -> Dictionary:
	if content==null or not position_value.is_finite():return {"ok":false,"error":"source_scroll_position_invalid"}
	# Input is the caller's original Cocos position, including source bounce
	# motion when applicable. Do not replace it with Godot scrolling physics.
	content.position=Vector2(position_value.x,-position_value.y)
	return {"ok":true}

func bind_input(callback: Callable) -> void:
	_input_callback=callback
	_input_area=Control.new()
	_input_area.position=Vector2(0,-_extent.y)
	_input_area.size=_extent
	_input_area.mouse_filter=Control.MOUSE_FILTER_STOP
	_input_area.gui_input.connect(_forward_input)
	add_child(_input_area)

func _forward_input(event: InputEvent) -> void:
	if _input_callback.is_valid():_input_callback.call(event)
	_input_area.accept_event()

func input_control() -> Control:
	# Existing caller may register its actual GUI event in viewport space.
	# Exposing this original extent adds no pan physics or click policy.
	return _input_area
