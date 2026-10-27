extends PanelContainer
## Own stone/metal finish over existing original growth art; no game state.
const Palette = preload("res://scripts/growth/growth_palette.gd")
var rim: Color = Palette.RIM

func _ready() -> void:
	add_theme_stylebox_override("panel", Palette.plate(Color(.025,.023,.035,.9), rim, 10))
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 16 or size.y < 16: return
	draw_line(Vector2(2,2),Vector2(size.x-2,2),Color("9b7e59"),1)
	draw_line(Vector2(3,size.y-3),Vector2(size.x-3,size.y-3),Color(0,0,0,.8),2)
	for i: int in range(3,int(size.y)-3,4):
		var alpha: float=.012+.008*sin(float(i)*1.73)
		draw_line(Vector2(4,i),Vector2(size.x-4,i),Color(.65,.57,.48,alpha),1)
	for corner: Vector2 in [Vector2(5,5),Vector2(size.x-5,5),Vector2(5,size.y-5),Vector2(size.x-5,size.y-5)]:
		draw_circle(corner,1.4,Color("a18760"),true,-1,true)
