extends Control
## Generated original raster medallion + live metal ring, milestone gems and glow.
const Art = preload("res://scripts/growth/growth_art.gd")
var stage: int = 0
var sigil_index: int = 0
var pulse: float = 0.0
func _ready() -> void:
	custom_minimum_size = Vector2(240,220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func reveal() -> void:
	pulse = 1.0
	var tween := create_tween()
	tween.tween_property(self,"pulse",0.0,0.9)
	tween.tween_callback(queue_redraw)
func _process(_delta: float) -> void:
	if pulse > 0: queue_redraw()
func _draw() -> void:
	var center := size/2-Vector2(0,10)
	var radius: float = minf(size.x,size.y)*0.39
	var tint: Color = Art.COLORS[sigil_index]
	for ring: int in range(5):
		draw_arc(center,radius+float(ring)*2,0,TAU,100,Color("baa476").darkened(float(ring)*.15),1.0,true)
	draw_texture_rect(Art.sigil(sigil_index),Rect2(center-Vector2.ONE*radius*.87,Vector2.ONE*radius*1.74),false)
	for i: int in range(30):
		var point := center+Vector2.from_angle(-PI/2+TAU*i/30.0)*radius
		var active: bool = i < stage
		var large: bool = i%3==2
		if active:
			for glow: int in range(3): draw_circle(point,10-glow*2,Color(tint,.08+glow*.04+pulse*.08))
		draw_circle(point,7 if large else 4,Color("261d2b"))
		draw_arc(point,7 if large else 4,0,TAU,12,Color("b8a16f"),1,true)
		draw_circle(point,5 if large else 2,tint if active else Color("4b4258"))
	if pulse > 0: draw_arc(center,radius*(1+pulse*.2),0,TAU,100,Color(tint,pulse*.8),3,true)
	var font: Font = preload("res://assets/fonts/NotoSansKR.ttf")
	var caption: String = "%d / 30" % stage
	draw_string(font,Vector2(center.x-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x/2,size.y-9),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ecd8ae"))
