extends Control
## Thirty slots, ten milestone seals, a swept light and sequential stage reveal.
const Art = preload("res://scripts/growth/growth_art.gd")
const ROMAN = ["I","II","III","IV","V","VI","VII","VIII","IX","X"]
var stage: int = 0
var sigil_index: int = 0
var pulse: float = 0.0
var displayed_stage: float = -1
var time: float = 0.0
var animating: bool = false
func _ready() -> void:
	custom_minimum_size=Vector2(258,196)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func reveal(previous: int = -1) -> void:
	displayed_stage=float(maxi(0,stage-1) if previous<0 else previous)
	pulse=1; animating=true
	var tween:=create_tween()
	tween.tween_property(self,"displayed_stage",float(stage),.62).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self,"pulse",.35,.62)
	tween.tween_property(self,"pulse",0.0,.4)
	tween.tween_callback(func() -> void: animating=false; queue_redraw())
func _process(delta: float) -> void:
	time+=delta
	# At most one light pass per frame; no particles or gameplay mutations.
	queue_redraw()
func _draw() -> void:
	var center:=size/2-Vector2(0,7)
	var radius: float=minf(size.x,size.y)*.385
	var tint: Color=Art.COLORS[sigil_index]
	var shown: int=stage if displayed_stage<0 else int(floor(displayed_stage))
	var font: Font=preload("res://assets/fonts/NotoSansKR.ttf")
	for ring: int in range(5):
		draw_circle(center,radius*(.7+ring*.04),Color(tint,.016+sin(time*.8)*.003))
	draw_arc(center,radius,-PI/2,TAU-PI/2,100,Color("6f5e5f"),1,true)
	draw_arc(center,radius+4,-PI/2,-PI/2+TAU*shown/30.0,100,Color(tint,.45),1.5,true)
	draw_texture_rect(Art.sigil(sigil_index),Rect2(center-Vector2.ONE*radius*.91,Vector2.ONE*radius*1.82),false)
	for i: int in range(30):
		var point:=center+Vector2.from_angle(-PI/2+TAU*i/30.0)*radius
		var active: bool=i<shown
		var milestone: bool=i%3==2
		var extent: float=12 if milestone else 3
		if active:
			for glow: int in range(3): draw_circle(point,extent+6-glow*2,Color(tint,.035+glow*.025+pulse*.04))
		if milestone:
			var diamond:=PackedVector2Array([point+Vector2(0,-14),point+Vector2(14,0),point+Vector2(0,14),point+Vector2(-14,0)])
			draw_colored_polygon(diamond,Color("13212d") if active else Color("110f19"))
			draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),tint if active else Color("5c4c63"),1.4,true)
			var numeral: String=ROMAN[i/3]
			var text_width: float=font.get_string_size(numeral,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x
			draw_string(font,point+Vector2(-text_width/2,4),numeral,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e8e6ff") if active else Color("776875"))
		else:
			draw_circle(point,4,Color("16121e"))
			draw_circle(point,2.5,tint if active else Color("4e435b"))
	if pulse>0:
		draw_arc(center,radius*(1+(1-pulse)*.2),0,TAU,100,Color(tint,pulse*.7),2,true)
		var angle: float=-PI/2+TAU*displayed_stage/30.0
		var tip:=center+Vector2.from_angle(angle)*radius
		draw_circle(tip,8,Color(tint,pulse*.65))
		draw_circle(tip,3,Color(1,1,1,pulse))
	var caption: String="%d / 30" % shown
	draw_string(font,Vector2(center.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x/2,size.y-2),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("d9c8ae"))
