extends Node2D
## Draw only the supplied font and serialized single-line text. The caller must
## bind live values separately; source placeholder strings are not game rules.
var original_font: FontFile
var original_options: Dictionary={}
var original_size: Vector2
func configure(font: FontFile, options: Dictionary, size_value: Vector2) -> void:
	original_font=font
	original_options=options.duplicate(true)
	original_size=size_value
	queue_redraw()
func _draw() -> void:
	if original_font==null:return
	var text_value: String=str(original_options.text)
	var font_size: int=int(original_options.fontSize)
	var width: float=original_font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var height: float=original_font.get_height(font_size)
	var x: float=0.0
	if int(original_options.hAlignment)==1:x=(original_size.x-width)/2.0
	elif int(original_options.hAlignment)==2:x=original_size.x-width
	var y: float=-original_size.y+original_font.get_ascent(font_size)
	if int(original_options.vAlignment)==1:y+=(original_size.y-height)/2.0
	elif int(original_options.vAlignment)==2:y+=original_size.y-height
	var pos:=Vector2(x,y)
	if bool(original_options.shadowEnabled):
		var offset:=Vector2(original_options.shadowOffsetX,-float(original_options.shadowOffsetY))
		draw_string(original_font,pos+offset,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,source_color(original_options.shadowColor))
	if bool(original_options.outlineEnabled):
		draw_string_outline(original_font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,int(original_options.outlineSize),source_color(original_options.outlineColor))
	draw_string(original_font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
static func source_color(value: Array) -> Color:
	return Color(float(value[1])/255.0,float(value[2])/255.0,float(value[3])/255.0,float(value[0])/255.0)
