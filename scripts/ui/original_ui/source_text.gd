extends Node2D
const FRAME_HITCH=preload("res://scripts/boot/frame_hitch_log.gd")
## Draw only the supplied font and serialized text. Explicit caller opt-in connects
## constrained source word wrapping; source placeholder strings are not game rules.
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
	if bool(options.get("_cocos_wrap",false)):
		if options.get("_type")!="TextOptions" or not bool(options.get("isCustomSize",false)) or bool(options.widgetOptions.get("ignoreSize",false)):return {"ok":false,"error":"original_constrained_custom_text_required_for_wrap"}
		var wrapped: Dictionary=preload("res://scripts/ui/original_ui/source_text_wrap.gd").lines(font,value,int(options.fontSize),size_value.x)
		if not wrapped.get("ok",false):return wrapped
		next_lines=wrapped.lines
		# The actual caller has no established original continuation/page
		# control for overflowing body text. Preserve its complete old owner.
		if next_lines.size()*font.get_height(int(options.fontSize))>size_value.y:return {"ok":false,"error":"original_dialogue_text_continuation_required"}
	elif next_lines.size()>1 and not bool(options.widgetOptions.get("ignoreSize",false)):
		var font_size: int=int(options.fontSize)
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
	# Only the top-level text changes. configure reads nested options and
	# commits its own deep snapshot after every font/layout guard succeeds.
	var started: int=FRAME_HITCH.now()
	var next: Dictionary=original_options.duplicate()
	next.text=value
	var result: Dictionary=configure(original_font,next,original_size)
	FRAME_HITCH.detail("ui.text_update",started)
	return result

func _draw() -> void:
	if original_font==null:return
	var hitch_started: int=FRAME_HITCH.now()
	var hitch_nested: int=FRAME_HITCH.nested()
	var font_size: int=int(original_options.fontSize)
	var line_height: float=original_font.get_height(font_size)
	# Korean-client line spacing (customProperty "linespacing"), 0 otherwise.
	var spacing: float=float(original_options.get("_line_spacing",0.0))
	var height: float=line_height*source_lines.size()+spacing*maxf(0.0,float(source_lines.size()-1))
	var y: float=-original_size.y+original_font.get_ascent(font_size)
	var constrained: bool=str(original_options.get("_type",""))=="TextOptions" and not bool(original_options.widgetOptions.get("ignoreSize",false)) and original_size.y>0.0
	if constrained and height>original_size.y:
		# LabelTextFormatter::createStringSprites truncates the available
		# height to whole source-font lines before vertical alignment.
		height=floorf(original_size.y/line_height)*line_height
	if int(original_options.vAlignment)==1:y+=(original_size.y-height)/2.0
	elif int(original_options.vAlignment)==2:y+=original_size.y-height
	var next_source_y: float=original_font.get_ascent(font_size)-y
	for text_value: String in source_lines:
		var x: float=0.0
		var alignment: int=int(original_options.hAlignment)
		# Left-aligned text starts at zero; its measured width is unused.
		if alignment==1 or alignment==2:
			var width: float=original_font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
			x=(original_size.x-width)/2.0 if alignment==1 else original_size.x-width
		var pos:=Vector2(x,y)
		if bool(original_options.shadowEnabled):
			var offset:=Vector2(original_options.shadowOffsetX,-float(original_options.shadowOffsetY))
			draw_string(original_font,pos+offset,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,source_color(original_options.shadowColor))
		if bool(original_options.outlineEnabled):
			draw_string_outline(original_font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,int(original_options.outlineSize),source_color(original_options.outlineColor))
		draw_string(original_font,pos,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color.WHITE)
		y+=line_height+spacing
		next_source_y-=line_height+spacing
		# The original formatter stops at a newline when the following line
		# would start below one common line height. It does not draw a new
		# substitute string or create a generic rectangular clipping rule.
		if constrained and next_source_y<line_height:break
	FRAME_HITCH.detail("ui.text_draw",hitch_started)
	FRAME_HITCH.add_self("ui_text_draw",hitch_started,hitch_nested)
static func source_color(value: Array) -> Color:
	return Color(float(value[1])/255.0,float(value[2])/255.0,float(value[3])/255.0,float(value[0])/255.0)
