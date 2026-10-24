extends Control
## Original procedural ornament. No original game image is included.
var stage: int = 0
var title: String = ""
var pulse: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(200,200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func reveal() -> void:
	pulse = 1.0
	var tween := create_tween()
	tween.tween_property(self,"pulse",0.0,0.65)
	tween.tween_callback(queue_redraw)

func _process(_delta: float) -> void:
	if pulse > 0: queue_redraw()

func _draw() -> void:
	var center := size/2
	var radius: float = minf(size.x,size.y)*0.40
	var gold := Color("dcc391")
	draw_circle(center,radius+15,Color("101923"))
	draw_arc(center,radius,0,TAU,100,Color("5d5268"),1.5,true)
	for i: int in range(30):
		var point := center+Vector2.from_angle(-PI/2+TAU*i/30.0)*radius
		draw_circle(point,6.0 if i%3==2 else 3.0,gold if i < stage else Color("3d3948"))
	var star := PackedVector2Array()
	for i: int in range(12):
		star.append(center+Vector2.from_angle(-PI/2+TAU*i/12.0)*radius*(0.53 if i%2==0 else 0.28))
	star.append(star[0])
	draw_polyline(star,Color("8daed4"),2,true)
	draw_arc(center,radius*(0.65+pulse*0.3),0,TAU,80,Color(gold,0.3+pulse*0.5),2,true)
	var font: Font = preload("res://assets/fonts/NotoSansKR.ttf")
	var caption: String = "%d / 30" % stage
	draw_string(font,center+Vector2(-font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x/2,8),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,22,gold)
