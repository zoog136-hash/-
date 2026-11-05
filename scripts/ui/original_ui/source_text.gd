extends Node2D
## Draw only the supplied font and serialized text with explicit source line breaks. The caller must
## bind live values separately; source placeholder strings are not game rules.
var original_font: FontFile
var original_options: Dictionary={}
var original_size: Vector2
var source_lines: PackedStringArray
func configure(font: FontFile, options: Dictionary, size_value: Vector2) -> Dictionary:
	if font==null:return {"ok":false,"error":"original_font_unavailable"}
	var value: String=str(options.text)
	for index: int in range(value.length()):
		if not value[index].strip_edges().is_empty() and not font.has_char(value.unicode_at(index)):return {"ok":false,"error":"original_font_glyph_missing"}
	var next_lines: PackedStringArray=value.split("\n",true)
	if next_lines.size()>1 and not bool(options.widgetOptions.get("ignoreSize",false)):
		var font_size: int=int(options.fontSize)
		if font.get_height(font_size)*next_lines.size()>size_value.y:return {"ok":false,"error":"original_multiline_height_requires_clipping"}
		for line: String in next_lines:
			if font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>size_value.x:return {"ok":false,"error":"original_multiline_requires_word_wrap"}
	# Commit display data only after the original-font/layout guards succeed.
	original_font=font
	original_options=options.duplicate(true)
	original_size=size_value
	source_lines=next_lines
	queue_redraw()
	return {"ok":true}

func set_source_text(value: String) -> Dictionary:
	var next: Dictionary=original_options.duplicate(true)
	next.text=value
	return configure(original_font,next,original_size)

func _draw() -> void:
	if original_font==null:return
	var font_size: int=int(original_options.fontSize)
	var line_height: float=original_font.get_height(font_size)
	var height: float=line_height*source_lines.size()
	var y: float=-original_size.y+original_font.get_ascent(font_size)
	if int(original_options.vAlignment)==1:y+=(original_size.y-height)/2.0
	elif int(original_options.vAlignment)==2:y+=original_size.y-height
	for text_value: String in source_lines:
		var width: float=original_font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var x: float=0.0
		if int(original_options.hAlignment)==1:x=(original_size.x-width)/2.0
		elif int(original_options.hAlignment)==2:x=original_size.x-width
		var pos:=Vector2(x,y)
		if bool(original_options.shadowEnabled):
			var offset:=Vector2(original_options.shadowOffsetX,-float(original_options.shadowOffsetY))
			draw_string(original_font,pos+offset,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,source_color(original_options.shadowColor))
		if bool(original_options.outlineEnabled):
			draw_string_outline(original_font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,int(original_options.outlineSize),source_color(original_options.outlineColor))
		draw_string(original_font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
		y+=line_height
static func source_color(value: Array) -> Color:
	return Color(float(value[1])/255.0,float(value[2])/255.0,float(value[3])/255.0,float(value[0])/255.0)
