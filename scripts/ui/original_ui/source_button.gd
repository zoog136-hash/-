extends Node2D
## Original state textures only. Inspection has no input or game callbacks.
var states: Dictionary={}
var current_state: String=""
var _pressed_uses_normal: bool=false
var _extent: Vector2
var _title: Node2D
func configure(pack: RefCounted, options: Dictionary, omit_invisible_title: bool=false) -> Dictionary:
	var widget: Dictionary=options.widgetOptions
	if omit_invisible_title and not _whole_zero(widget.get("alpha")):return {"ok":false,"error":"source_title_omission_requires_original_zero_alpha"}
	var extent:=Vector2(widget.size[0],widget.size[1])
	_extent=extent
	_pressed_uses_normal=str(options.pressedData.path).is_empty()
	for state: String in ["normal","pressed","disabled"]:
		var reference: Dictionary=options[state+"Data"]
		var grayscale: bool=state=="disabled" and str(reference.path).is_empty()
		# Cocos Button::onPressStateChangedToDisabled uses the normal sprite
		# and its original gray shader when disabledData is unspecified.
		if grayscale or (state=="pressed" and _pressed_uses_normal):reference=options.normalData
		if str(reference.path).is_empty():
			# An explicitly empty original state draws no background pixels.
			var empty:=Control.new()
			empty.size=extent
			empty.position=Vector2(0,-extent.y)
			empty.mouse_filter=Control.MOUSE_FILTER_IGNORE
			empty.set_meta("original_empty_state",true)
			add_child(empty)
			states[state]=empty
			continue
		var texture: Texture2D=pack.texture(reference,true)
		if texture==null:return {"ok":false,"error":"original_button_texture_missing:"+state}
		var picture: Control
		if bool(options.scale9Enabled):
			var nine=preload("res://scripts/ui/original_ui/source_scale9.gd").new()
			var result: Dictionary=nine.configure(texture,extent,options.capInsets,grayscale)
			if not result.ok:nine.free();return result
			picture=nine
		else:
			var flat:=TextureRect.new()
			flat.texture=texture
			flat.material=preload("res://scripts/ui/original_ui/source_material.gd").original_default(texture,grayscale)
			if flat.material==null:flat.free();return {"ok":false,"error":"original_material_unavailable"}
			flat.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			flat.stretch_mode=TextureRect.STRETCH_SCALE
			flat.size=extent
			picture=flat
		picture.position=Vector2(0,-extent.y)
		picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
		if state=="pressed" and _pressed_uses_normal:
			# UIButton uses normal renderer scale + its original 0.1 zoom.
			picture.pivot_offset=extent/2.0
			if bool(options.scale9Enabled):picture.scale=Vector2(1.1,1.1)
			else:
				if extent.x<=0 or extent.y<=0:picture.free();return {"ok":false,"error":"original_button_zoom_extent_invalid"}
				picture.scale=Vector2.ONE+texture.get_size()*0.1/extent
		picture.name="Original_"+state
		if bool(widget.flipX):
			picture.scale.x*=-1
			if picture.pivot_offset==Vector2.ZERO:picture.position.x=extent.x
		if bool(widget.flipY):
			picture.scale.y*=-1
			if picture.pivot_offset==Vector2.ZERO:picture.position.y=0
		add_child(picture)
		states[state]=picture
	# Only the renderer may supply this after proving original alpha stays zero.
	set_meta("source_title_omitted_for_original_zero_alpha",omit_invisible_title)
	if not omit_invisible_title and not str(options.text).is_empty():
		var font: FontFile=pack.font(options.fontResource)
		if font==null and str(options.fontResource.get("path","")).is_empty() and pack.has_method("declared_system_font"):
			font=pack.declared_system_font(str(options.get("fontName","")))
		if font==null:return {"ok":false,"error":"original_button_font_unavailable"}
		var title: String=str(options.text)
		for index: int in range(title.length()):
			if not title[index].strip_edges().is_empty() and not font.has_char(title.unicode_at(index)):return {"ok":false,"error":"original_button_glyph_missing"}
		var label=preload("res://scripts/ui/original_ui/source_text.gd").new()
		_title=label
		var text_options: Dictionary=options.duplicate(true)
		text_options.hAlignment=1
		text_options.vAlignment=1
		var text_result: Dictionary=label.configure(font,text_options,extent)
		if not text_result.ok:label.free();_title=null;return text_result
		label.modulate=label.source_color(options.textColor)
		label.set_meta("source_title_base_color",label.modulate)
		add_child(label)
	return set_source_state("normal" if bool(options.displaystate) else "disabled")
func set_source_state(state: String) -> Dictionary:
	if not states.has(state):return {"ok":false,"error":"unknown_original_button_state"}
	for key: String in states:states[key].visible=key==state
	current_state=state
	if _title!=null:
		var zoom: float=1.1 if state=="pressed" and _pressed_uses_normal else 1.0
		_title.scale=Vector2(zoom,zoom)
		_title.position=Vector2(_extent.x/2.0,-_extent.y/2.0)*(1.0-zoom)
	if state=="disabled":
		_armed=false
		_mouse_captured=false
		_mouse_emulated=false
		_native_touch_index=-1
	return {"ok":true,"state":state,"inspection_only":not _activation.is_valid()}

# Invisible event rectangle uses the exact original extent; it adds no pixels.
signal activation_result(result: Dictionary)
var _activation: Callable
var _input_area: Control
var _armed: bool=false
var _mouse_captured: bool=false
var _mouse_emulated: bool=false
var _native_touch_index: int=-1
var _native_input_seen: bool=false
func bind_activation(callback: Callable, extent: Vector2, source_touch: bool) -> void:
	_activation=callback
	_input_area=Control.new()
	_input_area.position=Vector2(0,-extent.y)
	_input_area.size=extent
	_input_area.mouse_filter=Control.MOUSE_FILTER_STOP if source_touch else Control.MOUSE_FILTER_IGNORE
	_input_area.gui_input.connect(_source_input)
	_input_area.mouse_exited.connect(_source_exit)
	add_child(_input_area)
func _source_exit() -> void:
	# A mouse exit is not a different native finger's movement. Native drag
	# disarming uses that captured finger's actual viewport point instead.
	if _native_touch_index>=0:return
	if _armed:
		_armed=false
		set_source_state("normal")

func handle_native_touch(event: InputEvent, viewport_position: Vector2) -> Dictionary:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return {"handled":false,"activated":false}
	if event.index<0:return {"handled":false,"activated":false}
	_native_input_seen=true
	var captured: bool=_native_touch_index>=0 and event.index==_native_touch_index
	if not viewport_position.is_finite() or not _input_available():
		if captured:cancel_native_touch()
		return {"handled":captured,"activated":false}
	if event is InputEventScreenTouch:
		if event.canceled:
			if captured:cancel_native_touch()
			return {"handled":captured,"activated":false}
		if event.pressed:
			# Duplicate global/router + GUI delivery cannot rearm a finger
			# that has left the button. Only one input owns the pressed state.
			if captured:return {"handled":true,"activated":false}
			# Some platforms deliver the emulated mouse press first. Transfer
			# only that identified emulation to native input, never a real mouse.
			if _mouse_captured and _mouse_emulated:
				_mouse_captured=false
				_mouse_emulated=false
				_armed=false
				set_source_state("normal")
			if _native_touch_index>=0 or _mouse_captured or not _hit_viewport(viewport_position):return {"handled":false,"activated":false}
			_native_touch_index=event.index
			_armed=true
			set_source_state("pressed")
			return {"handled":true,"activated":false}
		if not captured:return {"handled":false,"activated":false}
		var activate: bool=_armed and _hit_viewport(viewport_position)
		cancel_native_touch()
		if activate:return {"handled":true,"activated":true,"result":_dispatch_activation()}
		return {"handled":true,"activated":false}
	if not captured:return {"handled":false,"activated":false}
	if _armed and not _hit_viewport(viewport_position):
		_armed=false
		set_source_state("normal")
	return {"handled":true,"activated":false}

func cancel_native_touch() -> void:
	if _native_touch_index<0:return
	_native_touch_index=-1
	_armed=false
	if current_state=="pressed":set_source_state("normal")

func _source_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not is_instance_valid(_input_area):return
		# GUI events use the existing input Control's local coordinates;
		# the public router API takes viewport coordinates explicitly.
		var viewport_point: Vector2=_input_area.get_global_transform_with_canvas()*event.position
		var native: Dictionary=handle_native_touch(event,viewport_point)
		if native.handled:_input_area.accept_event()
		return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT:return
	if not _input_available():return
	# Emulated mouse delivery after the native release must not dispatch a
	# second activation. Real mouse input keeps its original independent path.
	if _native_touch_index>=0 or (_native_input_seen and event.device==InputEvent.DEVICE_ID_EMULATION):
		_input_area.accept_event()
		return
	var viewport_point: Vector2=_input_area.get_global_transform_with_canvas()*event.position
	if event.pressed:
		if not _hit_viewport(viewport_point):return
		_mouse_captured=true
		_mouse_emulated=event.device==InputEvent.DEVICE_ID_EMULATION
		_armed=true
		set_source_state("pressed")
	else:
		var activate: bool=_mouse_captured and _armed and _hit_viewport(viewport_point)
		_mouse_captured=false
		_mouse_emulated=false
		_armed=false
		set_source_state("normal")
		if activate:_dispatch_activation()
	_input_area.accept_event()

func _input_available() -> bool:
	return current_state!="disabled" and _activation.is_valid() and is_visible_in_tree() and is_instance_valid(_input_area) and _input_area.is_visible_in_tree() and _input_area.mouse_filter!=Control.MOUSE_FILTER_IGNORE

func _hit_viewport(point: Vector2) -> bool:
	if not _control_contains(_input_area,point):return false
	# Walk through Node2D wrappers too: every original clipping Control
	# ancestor participates, not only a consecutive run of Control parents.
	var ancestor: Node=_input_area.get_parent()
	while ancestor!=null:
		if ancestor is Control and ancestor.clip_contents and not _control_contains(ancestor,point):return false
		ancestor=ancestor.get_parent()
	return true

static func _control_contains(control: Control, point: Vector2) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree():return false
	var transform_value: Transform2D=control.get_global_transform_with_canvas()
	var determinant: float=transform_value.determinant()
	if not is_finite(determinant) or is_zero_approx(determinant):return false
	var local: Vector2=transform_value.affine_inverse()*point
	return local.is_finite() and Rect2(Vector2.ZERO,control.size).has_point(local)

func _dispatch_activation() -> Dictionary:
	var result: Variant=_activation.call()
	var response: Dictionary=result if result is Dictionary else {"ok":false,"error":"invalid_service_response"}
	activation_result.emit(response)
	return response

func _notification(what: int) -> void:
	if what==NOTIFICATION_EXIT_TREE or (what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		cancel_native_touch()
		_mouse_captured=false
		_mouse_emulated=false
		_armed=false
		if current_state=="pressed":set_source_state("normal")

func set_source_display(color: Color) -> void:
	preload("res://scripts/ui/original_ui/source_material.gd").bind_tree_display(self,color)
	for child: Node in get_children():
		if child.has_meta("source_title_base_color"):child.modulate=color*child.get_meta("source_title_base_color")

## Pack JSON numbers arrive as floats: an original integer field equals 0.
static func _whole_zero(value: Variant) -> bool:
	return (typeof(value)==TYPE_INT or (typeof(value)==TYPE_FLOAT and value==floorf(value))) and int(value)==0
