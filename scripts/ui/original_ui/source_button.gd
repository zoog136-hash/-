extends Node2D
## Original state textures only. Inspection has no input or game callbacks.
var states: Dictionary={}
var current_state: String=""
func configure(pack: RefCounted, options: Dictionary) -> Dictionary:
	var widget: Dictionary=options.widgetOptions
	var extent:=Vector2(widget.size[0],widget.size[1])
	for state: String in ["normal","pressed","disabled"]:
		var reference: Dictionary=options[state+"Data"]
		var grayscale: bool=state=="disabled" and str(reference.path).is_empty()
		# Cocos Button::onPressStateChangedToDisabled uses the normal sprite
		# and its original gray shader when disabledData is unspecified.
		if grayscale:reference=options.normalData
		if str(reference.path).is_empty():return {"ok":false,"error":"original_button_state_unspecified:"+state}
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
		picture.name="Original_"+state
		if bool(widget.flipX):picture.scale.x=-1;picture.position.x=extent.x
		if bool(widget.flipY):picture.scale.y=-1;picture.position.y=0
		add_child(picture)
		states[state]=picture
	if not str(options.text).is_empty():
		var font: FontFile=pack.font(options.fontResource)
		if font==null:return {"ok":false,"error":"original_button_font_unavailable"}
		var title: String=str(options.text)
		for index: int in range(title.length()):
			if not title[index].strip_edges().is_empty() and not font.has_char(title.unicode_at(index)):return {"ok":false,"error":"original_button_glyph_missing"}
		var label=preload("res://scripts/ui/original_ui/source_text.gd").new()
		var text_options: Dictionary=options.duplicate(true)
		text_options.hAlignment=1
		text_options.vAlignment=1
		label.configure(font,text_options,extent)
		label.modulate=label.source_color(options.textColor)
		add_child(label)
	return set_source_state("normal" if bool(options.displaystate) else "disabled")
func set_source_state(state: String) -> Dictionary:
	if not states.has(state):return {"ok":false,"error":"unknown_original_button_state"}
	for key: String in states:states[key].visible=key==state
	current_state=state
	if state=="disabled":_armed=false
	return {"ok":true,"state":state,"inspection_only":not _activation.is_valid()}

# Invisible event rectangle uses the exact original extent; it adds no pixels.
signal activation_result(result: Dictionary)
var _activation: Callable
var _input_area: Control
var _armed: bool=false
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
	if _armed:
		_armed=false
		set_source_state("normal")
func _source_input(event: InputEvent) -> void:
	if current_state=="disabled" or not _activation.is_valid():return
	if not event is InputEventMouseButton or event.button_index!=MOUSE_BUTTON_LEFT:return
	if event.pressed:
		_armed=true
		set_source_state("pressed")
	else:
		var activate: bool=_armed and Rect2(Vector2.ZERO,_input_area.size).has_point(event.position)
		_armed=false
		set_source_state("normal")
		if activate:
			var result: Variant=_activation.call()
			activation_result.emit(result if result is Dictionary else {"ok":false,"error":"invalid_service_response"})
	_input_area.accept_event()

func _notification(what: int) -> void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and _armed:
		_armed=false
		set_source_state("normal")
