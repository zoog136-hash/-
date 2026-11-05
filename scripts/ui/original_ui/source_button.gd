extends Node2D
## Original state textures only. Inspection has no input or game callbacks.
var states: Dictionary={}
var current_state: String=""
func configure(pack: RefCounted, options: Dictionary) -> Dictionary:
	var widget: Dictionary=options.widgetOptions
	var extent:=Vector2(widget.size[0],widget.size[1])
	for state: String in ["normal","pressed","disabled"]:
		var reference: Dictionary=options[state+"Data"]
		if str(reference.path).is_empty():return {"ok":false,"error":"original_button_state_unspecified:"+state}
		var texture: Texture2D=pack.texture(reference)
		if texture==null:return {"ok":false,"error":"original_button_texture_missing:"+state}
		var picture: Control
		if bool(options.scale9Enabled):
			var nine=preload("res://scripts/ui/original_ui/source_scale9.gd").new()
			var result: Dictionary=nine.configure(texture,extent,options.capInsets)
			if not result.ok:nine.free();return result
			picture=nine
		else:
			var flat:=TextureRect.new()
			flat.texture=texture
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
	return {"ok":true,"state":state,"inspection_only":true}
